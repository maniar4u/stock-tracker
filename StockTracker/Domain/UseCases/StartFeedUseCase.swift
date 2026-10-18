import Foundation

/// The user asked for live prices.
@MainActor
protocol StartFeedUseCase {
    func execute() async
}

struct DefaultStartFeedUseCase: StartFeedUseCase {
    let session: any FeedSessionControlling
    let status: any FeedStatusProviding
    let repository: any StockRepositoryProtocol

    /// Idempotent. A new explicit run starts a fresh ordering window and keeps cached quotes on screen.
    func execute() async {
        guard !status.isStreamingRequested else { return }
        repository.resetQuoteOrdering()
        await session.start()
    }
}
