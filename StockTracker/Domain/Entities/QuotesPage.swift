//
//  QuotesPage.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 02/05/2026.
//

import Foundation

nonisolated struct QuotesPage: Equatable, Sendable {
    let quotes: [StockQuote]
    let nextCursor: String?

}
