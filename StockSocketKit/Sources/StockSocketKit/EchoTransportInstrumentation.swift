//
//  EchoTransportInstrumentation.swift
//  StockSocketKit
//
//  Created by Muhammad Ali Maniar on 01/05/2026.
//

import Foundation

public typealias EchoTLSAuthenticationChallengeHandler = (
    URLAuthenticationChallenge,
    @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
) -> Void

/// Customizes TLS authentication for the WebSocket `URLSession`.
///
/// `Sendable` is unchecked because `URLAuthenticationChallenge` handling runs on `URLSession`'s delegate queue
/// while session state lives on `EchoWebSocketSession`; callers must treat the handler as queue-confined.
public struct EchoTLSHooks: @unchecked Sendable {
    public var onAuthenticationChallenge: EchoTLSAuthenticationChallengeHandler?

    public init(
        onAuthenticationChallenge: EchoTLSAuthenticationChallengeHandler? = nil
    ) {
        self.onAuthenticationChallenge = onAuthenticationChallenge
    }
}

/// Optional instrumentation hooks placed on the websocket driver (handshake timing, backoff, teardown, loss).
public struct EchoTransportMetrics: Sendable {
    public var onReconnectSleep: (@Sendable (_ attemptCounter: Int, _ delayNanos: UInt64) -> Void)?

    public var onHandshakeCompleted: (@Sendable (_ success: Bool) -> Void)?

    public var onTerminalTransportFailure: (@Sendable (WebSocketTransportFailure) -> Void)?

    /// An undecodable frame was discarded.
    public var onFrameDropped: (@Sendable () -> Void)?

    /// The consumer's stream buffer was full and an event was discarded.
    public var onEventDropped: (@Sendable (WebSocketPublicEvent) -> Void)?

    /// The link stayed silent past the stale-data window and is being replaced.
    public var onStaleData: (@Sendable () -> Void)?

    /// Milliseconds from starting a connection attempt to the first decoded frame on it.
    public var onTimeToFirstTick: (@Sendable (_ milliseconds: Int) -> Void)?

    public init(
        onReconnectSleep: (@Sendable (Int, UInt64) -> Void)? = nil,
        onHandshakeCompleted: (@Sendable (Bool) -> Void)? = nil,
        onTerminalTransportFailure: (@Sendable (WebSocketTransportFailure) -> Void)? = nil,
        onFrameDropped: (@Sendable () -> Void)? = nil,
        onEventDropped: (@Sendable (WebSocketPublicEvent) -> Void)? = nil,
        onStaleData: (@Sendable () -> Void)? = nil,
        onTimeToFirstTick: (@Sendable (Int) -> Void)? = nil
    ) {
        self.onReconnectSleep = onReconnectSleep
        self.onHandshakeCompleted = onHandshakeCompleted
        self.onTerminalTransportFailure = onTerminalTransportFailure
        self.onFrameDropped = onFrameDropped
        self.onEventDropped = onEventDropped
        self.onStaleData = onStaleData
        self.onTimeToFirstTick = onTimeToFirstTick
    }
}
