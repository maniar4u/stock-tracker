//
//  StockRepositoryProtocol.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 02/05/2026.
//

import Foundation

@MainActor
protocol StockRepositoryProtocol: AnyObject {
    /// Saving quotes for offline use keeps failing. Live prices are unaffected; only the cache is out of date.
    var isPersistenceDegraded: Bool { get }

    func catalog() async -> [StockCatalogEntry]

    /// Paged persisted quotes ascending by symbol. `cursor` is the prior page's opaque `nextCursor` (empty same as nil).
    func persistedQuotesSnapshot(limit: Int, cursor: String?) async throws -> QuotesPage
    func hasPersistedQuotes() async throws -> Bool
    /// One element per feed frame, holding every quote that frame changed.
    func quoteBatches() -> AsyncStream<QuoteBatch>
    func currentMergedQuotes() -> [StockQuote]

    /// Merge valid domain quotes and publish a single batch. Returns the accepted quote count.
    @discardableResult func apply(_ quotes: [StockQuote]) -> Int
    /// A new explicit feed run starts a fresh ordering window while retaining cached quotes.
    func resetQuoteOrdering()
    func flushPendingQuotes() async
}
