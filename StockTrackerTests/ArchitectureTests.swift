import Foundation
import XCTest

/// Layer rules enforced on the source itself. Merging the Domain package into the app target removed the compiler's
/// guard rail; these checks put it back, so a stray import fails CI instead of surviving review.
final class ArchitectureTests: XCTestCase {
    private let sources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("StockTracker")

    private func imports(inLayer layer: String) throws -> [(file: String, module: String)] {
        let directory = sources.appendingPathComponent(layer)
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil))
        var found: [(String, String)] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("import ") || trimmed.hasPrefix("@testable import ") else { continue }
                found.append((url.lastPathComponent, String(trimmed.split(separator: " ").last ?? "")))
            }
        }
        return found
    }

    func testDomainDependsOnNothingButFoundation() throws {
        for (file, module) in try imports(inLayer: "Domain") {
            XCTAssertEqual(module, "Foundation", "Domain/\(file) imports \(module); the domain must stay framework-free")
        }
    }

    func testPresentationNeverReachesIntoDataOrTransportFrameworks() throws {
        let forbidden: Set = ["SwiftData", "StockSocketKit", "Network"]
        for (file, module) in try imports(inLayer: "Presentation") {
            XCTAssertFalse(forbidden.contains(module), "Presentation/\(file) imports \(module); go through a domain port")
        }
    }
}
