import Foundation

/// The user asked to stop live prices. Stop always wins over any start still in flight.
@MainActor
protocol StopFeedUseCase {
    func execute() async
}

struct DefaultStopFeedUseCase: StopFeedUseCase {
    let session: any FeedSessionControlling

    func execute() async {
        await session.stop()
    }
}
