import XCTest

/// Unit tests for the home-screen widget quota logic (spec 055 plan D-6).
/// `WidgetQuotaDisplay.swift` is compiled into this test target too.
final class WidgetQuotaDisplayTests: XCTestCase {
    func testBeforeResetShowsUsedOverLimit() {
        let quota = WidgetQuotaDisplay.resolve(used: 3, limit: 10, resetAtMs: 2000, nowMs: 1000)
        XCTAssertEqual(quota.used, 3)
        XCTAssertEqual(quota.limit, 10)
        XCTAssertEqual(WidgetQuotaDisplay.format(quota), "3 / 10")
    }

    func testAtOrAfterResetShowsFreshDay() {
        let atReset = WidgetQuotaDisplay.resolve(used: 8, limit: 10, resetAtMs: 1000, nowMs: 1000)
        XCTAssertEqual(atReset.used, 0)
        XCTAssertEqual(atReset.limit, 10)

        let afterReset = WidgetQuotaDisplay.resolve(used: 8, limit: 10, resetAtMs: 1000, nowMs: 5000)
        XCTAssertEqual(afterReset.used, 0)
        XCTAssertEqual(WidgetQuotaDisplay.format(afterReset), "0 / 10")
    }

    func testUsedIsClampedIntoRange() {
        let quota = WidgetQuotaDisplay.resolve(used: 99, limit: 10, resetAtMs: 2000, nowMs: 1000)
        XCTAssertEqual(quota.used, 10)
    }
}
