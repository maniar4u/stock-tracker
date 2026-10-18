import Foundation

/// Everything the UI is allowed to reach, assembled once at launch. Views see use cases and ports, never the
/// coordinator, the repository implementation or the transport.
@MainActor
struct AppDependencies {
    let repository: any StockRepositoryProtocol
    let feedStatus: any FeedStatusProviding
    let startFeed: any StartFeedUseCase
    let stopFeed: any StopFeedUseCase
    let retryFeed: any RetryFeedUseCase
    let applySceneActivity: any ApplySceneActivityUseCase
    let handleNetworkPathChange: any HandleNetworkPathChangeUseCase
    let networkObserver: FeedNetworkObserver

    var feedControls: FeedControls {
        FeedControls(status: feedStatus, start: startFeed, stop: stopFeed, retry: retryFeed)
    }
}
