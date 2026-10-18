//
//  FeedConnectionState+Presentation.swift
//  StockTracker
//

import Foundation

extension FeedConnectionState {
    var statusText: LocalizedStringResource {
        switch self {
        case .connected: return "connection.connected"
        case .connecting: return "connection.connecting"
        case .reconnecting: return "connection.reconnecting"
        case .failed: return "connection.failed"
        case .stopped: return "connection.stopped"
        case .idle: return "connection.idle"
        }
    }
}
