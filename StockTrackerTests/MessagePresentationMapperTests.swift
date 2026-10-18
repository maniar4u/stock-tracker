import XCTest

@testable import StockTracker

final class MessagePresentationMapperTests: XCTestCase {
    func testPersistenceFailedUsesPersistenceCopy() {
        let mapped = MessagePresentationMapper.map(failure: .persistenceFailed)
        XCTAssertEqual(mapped.title, MessagePresentation.persistenceFailure.title)
        XCTAssertEqual(mapped.showsRetry, true)
    }
}
