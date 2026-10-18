//
//  SortOption+Presentation.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 03/05/2026.
//

import Foundation

extension SortField {
    var title: LocalizedStringResource {
        switch self {
        case .price: return "sort.field.price"
        case .priceChange: return "sort.field.price_change"
        }
    }
}

extension SortDirection {
    var title: LocalizedStringResource {
        switch self {
        case .ascending: return "sort.direction.ascending"
        case .descending: return "sort.direction.descending"
        }
    }
}
