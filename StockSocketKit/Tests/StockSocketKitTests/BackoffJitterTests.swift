import XCTest
@testable import StockSocketKit

final class BackoffJitterTests: XCTestCase {
    func testConfiguredJitterNeverExceedsMaximumDelay() {
        let policy = ExponentialBackoffPolicy(initialNanoseconds: 1_000, multiplier: 2,
                                              maxNanoseconds: 1_000, jitterRatio: 1)
        for _ in 0..<100 {
            XCTAssertLessThanOrEqual(policy.delayNanoseconds(forAttempt: 50), 1_000)
        }
    }
}
