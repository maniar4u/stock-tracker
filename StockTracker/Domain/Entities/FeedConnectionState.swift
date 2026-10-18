//
//  FeedConnectionState.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 02/05/2026.
//

import Foundation

nonisolated enum FeedConnectionState: Equatable, Sendable {
    case idle
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case stopped
    case failed(reason: FeedFailure)
}

nonisolated enum FeedFailure: Equatable, Sendable {
    case transportUnavailable
    case decodingFailed
    case closedByServer
    case cancelled
    case persistenceFailed
}
