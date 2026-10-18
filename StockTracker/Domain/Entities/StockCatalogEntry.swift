//
//  StockCatalogEntry.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 02/05/2026.
//

import Foundation

nonisolated struct StockCatalogEntry: Equatable, Hashable, Sendable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let companyName: String
    let descriptionText: String

}
