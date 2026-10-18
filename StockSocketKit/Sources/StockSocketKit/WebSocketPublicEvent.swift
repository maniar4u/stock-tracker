//
//  WebSocketPublicEvent.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import Foundation

public enum WebSocketPublicEvent: Equatable, Sendable {
    case serverClosed(code: Int, reason: String?)
    case connected
    case disconnected(userInitiated: Bool)
    case reconnectScheduled(attempt: Int)
    /// One decoded frame: a snapshot with an entry per symbol (a lone legacy object arrives as a batch of one).
    case decodedBatch([EchoStockPayload])
    case transportFailure(WebSocketTransportFailure)
}

public enum WebSocketTransportFailure: Equatable, Sendable {
    case heartbeatTimedOut
    case sendTimedOut
    /// The link is alive but no decodable data arrived within the stale-data window.
    case staleData
    case closedByServer(code: Int)
    case handshakeFailed
    case closedUnexpectedly
    case decodingFailed
    case cancelled
}
