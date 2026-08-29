import XCTest
@testable import DopaBreak

final class SettingsFocusRequestConsumptionTests: XCTestCase {
    func testPendingRequestWaitsForVisibilityThenConsumesExactlyOnce() {
        var pendingRequest = true

        XCTAssertFalse(
            SettingsFocusRequestConsumption.consume(
                isSettingsVisible: false,
                pendingRequest: &pendingRequest
            )
        )
        XCTAssertTrue(pendingRequest)

        XCTAssertTrue(
            SettingsFocusRequestConsumption.consume(
                isSettingsVisible: true,
                pendingRequest: &pendingRequest
            )
        )
        XCTAssertFalse(pendingRequest)

        XCTAssertFalse(
            SettingsFocusRequestConsumption.consume(
                isSettingsVisible: true,
                pendingRequest: &pendingRequest
            )
        )
    }
}
