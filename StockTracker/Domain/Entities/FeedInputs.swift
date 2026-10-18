import Foundation

nonisolated enum ApplicationSceneActivity: Sendable {
    case active
    case inactive
}

nonisolated struct FeedNetworkPath: Equatable, Sendable {
    let isSatisfied: Bool
    let interfaces: [String]
}
