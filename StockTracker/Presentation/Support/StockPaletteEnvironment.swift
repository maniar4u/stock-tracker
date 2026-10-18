//
//  StockPaletteEnvironment.swift
//  StockTracker
//
//  Created by Muhammad Ali Maniar on 03/05/2026.
//

import SwiftUI

extension EnvironmentValues {
    @Entry var stockPalette = StockPalette.palette(for: .light)
}
