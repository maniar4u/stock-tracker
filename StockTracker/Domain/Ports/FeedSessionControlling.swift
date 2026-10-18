import Foundation

/// The stateful side of a live feed: it owns the current run (session, consumer task, cleanup chain).
/// Use cases decide *whether* and *when*; an implementation of this port knows *how*.
@MainActor
protocol FeedSessionControlling: AnyObject {
    func start() async
    func stop() async
    func retry() async
    /// Replace the current link through the transport's own retry policy. No effect when no run is active.
    func reconnect() async
    func setSceneActive(_ isActive: Bool) async
}
