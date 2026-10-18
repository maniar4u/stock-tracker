//
//  QuoteStoring.swift
//  StockTracker
//

import Foundation
import SwiftData

/// Durable quote storage. Everything is async and `Sendable`, so the repository never touches SwiftData on the
/// main actor and tests can swap in a failing or in-memory double.
nonisolated protocol QuoteStoring: Sendable {
    func loadAll() async throws -> [String: StockQuote]
    func upsert(_ quotes: [StockQuote]) async throws
    func page(limit: Int, cursor: String?) async throws -> QuotesPage
    func hasAny() async throws -> Bool
}

/// SwiftData-backed store. `@ModelActor` gives it its own serial executor and `ModelContext`, so reads and
/// writes run off the main thread and are serialized with each other.
@ModelActor
actor SwiftDataQuoteStore: QuoteStoring {
    func loadAll() throws -> [String: StockQuote] {
        try PersistedQuoteAccess.quotesBySymbol(context: modelContext)
    }

    func upsert(_ quotes: [StockQuote]) throws {
        try PersistedQuoteWriter.upsertBatch(quotes: quotes, context: modelContext)
    }

    func page(limit: Int, cursor: String?) throws -> QuotesPage {
        try PersistedQuoteAccess.quotesPage(context: modelContext, limit: limit, cursor: cursor)
    }

    func hasAny() throws -> Bool {
        try PersistedQuoteAccess.hasAnyQuotes(context: modelContext)
    }
}
