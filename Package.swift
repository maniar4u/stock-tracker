// swift-tools-version: 6.2
import PackageDescription

// Host-side tests compile the same app logic and tests as Xcode. No copied implementation.
let package = Package(
    name: "StockTrackerVerification",
    platforms: [.macOS(.v15), .iOS(.v18)],
    dependencies: [
        .package(path: "StockSocketKit"),
    ],
    targets: [
        .target(
            name: "StockTracker",
            dependencies: ["StockSocketKit"],
            path: "StockTracker",
            exclude: ["Assets.xcassets", "Config", "Resources", "Localizable.xcstrings", "StockTrackerApp.swift",
                      "Presentation/Views", "Presentation/Support/StockNavigationRoute.swift",
                      "Presentation/Support/SortOption+Presentation.swift", "Presentation/Support/StockPalette.swift",
                      "Presentation/Support/StockPaletteEnvironment.swift", "Composition/ApplicationBootstrap.swift"],
            sources: ["Domain", "Data", "Infrastructure", "Composition/FeedTransportConfiguration.swift",
                      "Composition/FeedTransportTuning.swift",
                      "Presentation/ViewModels", "Presentation/Support/CurrencyFormatting.swift",
                      "Presentation/Support/StockUIModels.swift", "Presentation/Support/MessagePresentation.swift",
                      "Presentation/Support/MessagePresentationMapper.swift"],
            swiftSettings: [.defaultIsolation(MainActor.self), .swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "StockTrackerTests",
            dependencies: ["StockTracker", "StockSocketKit"],
            path: "StockTrackerTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
