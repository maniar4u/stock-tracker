import Foundation

/// The device's network route changed.
@MainActor
protocol HandleNetworkPathChangeUseCase {
    func execute(_ path: FeedNetworkPath, isInitial: Bool) async
}

struct DefaultHandleNetworkPathChangeUseCase: HandleNetworkPathChangeUseCase {
    let session: any FeedSessionControlling
    let status: any FeedStatusProviding

    /// Reconnects only a feed the user is currently running, and only onto a usable route that is a change.
    /// It never starts a stopped or failed feed: recovery after a terminal failure is an explicit user Retry.
    func execute(_ path: FeedNetworkPath, isInitial: Bool) async {
        guard path.isSatisfied, !isInitial, status.isStreamingRequested else { return }
        await session.reconnect()
    }
}
