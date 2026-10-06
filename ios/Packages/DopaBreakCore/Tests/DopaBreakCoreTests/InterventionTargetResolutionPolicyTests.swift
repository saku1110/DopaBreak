import XCTest
@testable import DopaBreakCore

final class InterventionTargetResolutionPolicyTests: XCTestCase {
    func testValidRequestedTargetWinsEvenWhenItIsNotSelected() {
        XCTAssertEqual(
            InterventionTargetResolutionPolicy.resolve(
                requested: "youtube",
                selected: ["instagram"]
            ),
            .target(catalogID: "youtube")
        )
    }

    func testOmittedRequestResolvesSingleSelectedTarget() {
        XCTAssertEqual(
            InterventionTargetResolutionPolicy.resolve(
                requested: nil,
                selected: ["instagram"]
            ),
            .target(catalogID: "instagram")
        )
    }

    func testOmittedRequestWithMultipleTargetsDoesNotGuess() {
        XCTAssertEqual(
            InterventionTargetResolutionPolicy.resolve(
                requested: nil,
                selected: ["youtube", "instagram", "x"]
            ),
            .none
        )
    }

    func testOmittedRequestWithNoSelectedTargetsResolvesNone() {
        XCTAssertEqual(
            InterventionTargetResolutionPolicy.resolve(requested: nil, selected: []),
            .none
        )
    }

    func testUnknownRequestedTargetResolvesNone() {
        XCTAssertEqual(
            InterventionTargetResolutionPolicy.resolve(
                requested: "unknown-app",
                selected: ["instagram"]
            ),
            .none
        )
    }

    func testOmittedRequestWithMultipleValidTargetsDoesNotGuess() {
        XCTAssertEqual(
            InterventionTargetResolutionPolicy.resolve(
                requested: nil,
                selected: ["unknown-app", "youtube", "instagram", "youtube"]
            ),
            .none
        )
    }

    func testOmittedRequestWithOneValidSelectedTargetResolvesIt() {
        XCTAssertEqual(
            InterventionTargetResolutionPolicy.resolve(
                requested: nil,
                selected: ["unknown-app", "instagram"]
            ),
            .target(catalogID: "instagram")
        )
    }

    func testOmittedRequestWithOnlyUnknownSelectedTargetsResolvesNone() {
        XCTAssertEqual(
            InterventionTargetResolutionPolicy.resolve(
                requested: nil,
                selected: ["unknown-app", "also-unknown"]
            ),
            .none
        )
    }
}
