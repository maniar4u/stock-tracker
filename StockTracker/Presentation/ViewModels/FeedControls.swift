import Foundation

/// What the list screen needs from the feed: the read-only status plus the three user commands.
/// Commands are use cases (execute-only); the status is a query port.
@MainActor
struct FeedControls {
    let status: any FeedStatusProviding
    let start: any StartFeedUseCase
    let stop: any StopFeedUseCase
    let retry: any RetryFeedUseCase
}
