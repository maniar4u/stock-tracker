import Foundation

/// Adapts the platform's raw path updates into "what changed": it drops repeats and flags the first update,
/// then hands each real change to the use case, which owns the recovery policy.
@MainActor
struct FeedNetworkObserver {
    let updates: @Sendable () -> AsyncStream<FeedNetworkPath>

    func observeChanges(using handle: any HandleNetworkPathChangeUseCase) async {
        var previousPath: FeedNetworkPath?
        for await path in updates() {
            guard !Task.isCancelled else { return }
            guard path != previousPath else { continue }
            let initial = previousPath == nil
            previousPath = path
            await handle.execute(path, isInitial: initial)
        }
    }
}
