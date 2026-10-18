//
//  QuotePersistenceScheduler.swift
//  StockTracker
//

import Foundation

/// Write-behind persistence for live quotes: collects the newest quote per symbol, writes them in one batch after a
/// short window, and retries after a failure without ever involving the live feed.
///
/// Rules (tested in `QuotePersistenceSchedulerTests`):
/// 1. Quotes arriving inside the window are written together; the newest quote per symbol wins.
/// 2. A failed write keeps the rows (unless a newer quote replaced them), flags `isDegraded`, and retries later.
/// 3. A successful write clears `isDegraded`.
/// 4. `flushNow` writes immediately and cancels any waiting timer, so Stop never leaves rows behind.
@MainActor
final class QuotePersistenceScheduler {
    private let store: any QuoteStoring
    private let logging: Logging
    private let sleep: @MainActor (Duration) async throws -> Void
    private let flushWindow: Duration
    private let retryDelay: Duration
    private var pending: [String: StockQuote] = [:]
    private var timer: Task<Void, Never>?

    /// True while writes keep failing. Live prices are unaffected; only the offline cache is out of date.
    private(set) var isDegraded = false

    init(
        store: any QuoteStoring,
        logging: Logging,
        flushWindow: Duration = QuoteStreamPresentationTiming.persistFlushWindow,
        retryDelay: Duration = QuoteStreamPresentationTiming.persistRetryDelay,
        sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.store = store
        self.logging = logging
        self.flushWindow = flushWindow
        self.retryDelay = retryDelay
        self.sleep = sleep
    }

    deinit { timer?.cancel() }

    func enqueue(_ quotes: [StockQuote]) {
        for quote in quotes { pending[quote.symbol] = quote }
        scheduleFlush(after: flushWindow)
    }

    /// Writes everything pending now (stop, retry, terminal failure) and cancels the waiting timer.
    func flushNow() async {
        timer?.cancel()
        timer = nil
        await writePending()
    }

    private func scheduleFlush(after delay: Duration) {
        guard !pending.isEmpty, timer == nil else { return }
        let sleep = sleep
        timer = Task { @MainActor [weak self] in
            do {
                try await sleep(delay)
                try Task.checkCancellation()
            } catch { return }
            await self?.timerFired()
        }
    }

    private func timerFired() async {
        timer = nil
        // Disk trouble must not interrupt live prices: keep the newest rows and try again later.
        if await writePending() == false { scheduleFlush(after: retryDelay) }
    }

    /// Returns true when nothing is left unsaved.
    @discardableResult
    private func writePending() async -> Bool {
        let batch = Array(pending.values)
        pending.removeAll()
        guard !batch.isEmpty else { return true }
        do {
            try await store.upsert(batch)
            isDegraded = false
            return true
        } catch {
            logging.log(.error, "Persist failure \(error.localizedDescription)")
            // Put the rows back unless a newer tick for the same symbol arrived while the write was in flight.
            for quote in batch where pending[quote.symbol] == nil { pending[quote.symbol] = quote }
            isDegraded = true
            return false
        }
    }
}
