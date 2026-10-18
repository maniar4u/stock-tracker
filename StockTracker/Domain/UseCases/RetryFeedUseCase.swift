import Foundation

/// The user retried after a failure: replace the run with a fresh one.
@MainActor
protocol RetryFeedUseCase {
    func execute() async
}

struct DefaultRetryFeedUseCase: RetryFeedUseCase {
    let session: any FeedSessionControlling
    let repository: any StockRepositoryProtocol

    func execute() async {
        repository.resetQuoteOrdering()
        await session.retry()
    }
}
