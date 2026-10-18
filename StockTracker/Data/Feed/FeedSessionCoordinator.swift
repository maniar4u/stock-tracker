import Foundation

/// Owns the life of the current feed run: build a session, consume its events, retire it exactly once.
/// It holds state, so it is a port implementation, not a use case. Use cases decide when to call it;
/// feed adapters own transport details; the repository owns quotes.
///
/// Invariants (each is covered by `FeedSessionCoordinatorTests` / `FeedLifecycleTests`):
/// 1. At most one run is current. `run == nil` means the user is not streaming.
/// 2. Every run is retired exactly once, through the single `cleanupTask` chain.
/// 3. Work that resumes after a suspension point re-checks `isCurrent`, so a superseded run can never publish
///    state or attach a session to a newer run.
/// 4. A new run starts only after the previous run's cleanup has finished.
@MainActor
final class FeedSessionCoordinator: FeedSessionControlling, FeedStatusProviding {
    /// Identity token for one start-to-retire span. It stays comparable while construction or transport
    /// calls suspend; Stop and Retry replace it synchronously.
    private final class Run {
        var session: (any PriceFeed)?
        var consumer: Task<Void, Never>?
    }

    private let repository: any StockRepositoryProtocol
    private let feedBuilder: ([String]) async -> any PriceFeed
    private let connectionFanOut = BroadcastFanOut<FeedConnectionState>()
    private var run: Run?
    private var cleanupTask: Task<Void, Never>?
    private var sceneIsActive = true

    var isStreamingRequested: Bool { run != nil }
    private(set) var currentConnectionState: FeedConnectionState = .idle

    init(repository: any StockRepositoryProtocol, feedBuilder: @escaping ([String]) async -> any PriceFeed) {
        self.repository = repository
        self.feedBuilder = feedBuilder
    }

    isolated deinit {
        run?.consumer?.cancel()
        connectionFanOut.finishAll()
    }

    // MARK: FeedStatusProviding

    func connectionEvents() -> AsyncStream<FeedConnectionState> { connectionFanOut.makeStream() }

    // MARK: FeedSessionControlling

    func start() async {
        guard !Task.isCancelled, run == nil else { return }
        await beginRun()
    }

    func stop() async {
        retireCurrentRun()
        emit(.stopped)
        await cleanupTask?.value
    }

    func retry() async {
        guard !Task.isCancelled else { return }
        retireCurrentRun()
        await beginRun()
    }

    func reconnect() async {
        await run?.session?.reconnect()
    }

    func setSceneActive(_ isActive: Bool) async {
        sceneIsActive = isActive
        await run?.session?.setSuspended(!isActive)
    }

    // MARK: Run lifecycle

    private func beginRun() async {
        let thisRun = Run()
        run = thisRun
        emit(.connecting)
        await cleanupTask?.value
        await mount(thisRun)
        // A cancelled caller must not leave a run behind.
        if Task.isCancelled, run === thisRun { await stop() }
    }

    /// Builds the session and starts consuming it. Every await below can be overtaken by Stop or Retry, so each
    /// result is checked before it is attached; a session that lost the race is stopped here and never published.
    private func mount(_ thisRun: Run) async {
        guard isCurrent(thisRun) else { return }
        let symbols = await repository.catalog().map(\.symbol)
        guard isCurrent(thisRun) else { return }

        let session = await feedBuilder(symbols)
        guard await keep(session, ifCurrent: thisRun) else { return }
        thisRun.session = session

        let stream = await session.events()
        guard await keep(session, ifCurrent: thisRun) else { return }

        // The scene may change while the session is being told its state; repeat until they agree.
        var applied: Bool
        repeat {
            applied = sceneIsActive
            await session.setSuspended(!applied)
            guard await keep(session, ifCurrent: thisRun) else { return }
        } while applied != sceneIsActive

        thisRun.consumer = consume(stream, from: session, in: thisRun)
    }

    /// True while `thisRun` is still current; otherwise stops the orphaned session and returns false.
    private func keep(_ session: any PriceFeed, ifCurrent thisRun: Run) async -> Bool {
        if isCurrent(thisRun) { return true }
        await session.stop()
        return false
    }

    private func consume(_ stream: AsyncStream<PriceFeedEvent>, from session: any PriceFeed,
                         in thisRun: Run) -> Task<Void, Never> {
        // Weak on purpose: the task must not keep the coordinator or the run alive.
        Task { @MainActor [weak self, weak thisRun] in
            guard let thisRun, self?.isCurrent(thisRun) == true else { return }
            await session.start()
            guard self?.isCurrent(thisRun) == true else {
                await session.stop()
                return
            }
            for await event in stream {
                guard let self, self.isCurrent(thisRun) else { break }
                if await self.handle(event, in: thisRun) == .runEnded { return }
            }
            // The stream ended without a terminal event.
            guard let self else {
                await session.stop() // The coordinator was released; nobody else will stop the session.
                return
            }
            if self.isCurrent(thisRun) {
                await self.finish(thisRun, with: .failed(reason: .transportUnavailable))
            }
        }
    }

    private enum EventOutcome { case keepGoing, runEnded }

    private func handle(_ event: PriceFeedEvent, in thisRun: Run) async -> EventOutcome {
        switch event {
        case let .quotes(quotes):
            repository.apply(quotes)
            return .keepGoing
        case let .connection(state):
            guard case .failed = state else {
                emit(state)
                return .keepGoing
            }
            await finish(thisRun, with: state)
            return .runEnded
        }
    }

    private func isCurrent(_ thisRun: Run) -> Bool {
        run === thisRun && !Task.isCancelled
    }

    /// Ends `thisRun` because of a failure it reported itself, then publishes that state.
    private func finish(_ thisRun: Run, with state: FeedConnectionState) async {
        guard run === thisRun else { return }
        // The caller is this run's own consumer and awaits cleanup below; it must not cancel itself mid-cleanup.
        thisRun.consumer = nil
        retireCurrentRun()
        emit(state)
        await cleanupTask?.value
    }

    /// The only place a run is retired. Shutdowns join one chain, so Stop and the next Start/Retry await it.
    private func retireCurrentRun() {
        guard let retiring = run else { return }
        run = nil
        retiring.consumer?.cancel()
        let previousCleanup = cleanupTask
        let session = retiring.session
        let repository = repository
        cleanupTask = Task {
            await previousCleanup?.value
            await session?.stop()
            await repository.flushPendingQuotes()
        }
    }

    private func emit(_ state: FeedConnectionState) {
        currentConnectionState = state
        connectionFanOut.yield(state)
    }
}
