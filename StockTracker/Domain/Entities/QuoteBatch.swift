import Foundation

/// The quotes that changed together in one feed frame. Consumers refresh once per batch, not once per symbol.
nonisolated struct QuoteBatch: Equatable, Sendable {
    let quotes: [StockQuote]

    func contains(symbol: String) -> Bool {
        quotes.contains { $0.symbol == symbol }
    }
}
