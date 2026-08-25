import CoreGraphics
import XCTest

@testable import DopaBreak

final class DeviceSideButtonGeometryTests: XCTestCase {
    func testIPhone16ProUsesModelGeometryAndCameraControl() {
        let geometry = DeviceSideButtonGeometry.resolve(
            modelIdentifier: "iPhone17,1",
            screenSize: CGSize(width: 402, height: 874),
            screenHeight: 874
        )

        XCTAssertEqual(geometry.top, 0.3044 * 874)
        XCTAssertEqual(geometry.length, 0.1222 * 874)
        XCTAssertTrue(geometry.hasCameraControl)
    }

    func testIPhone15UsesModelGeometryWithoutCameraControl() {
        let geometry = DeviceSideButtonGeometry.resolve(
            modelIdentifier: "iPhone15,4",
            screenSize: CGSize(width: 393, height: 852),
            screenHeight: 852
        )

        XCTAssertEqual(geometry.top, 0.2924 * 852)
        XCTAssertEqual(geometry.length, 0.1255 * 852)
        XCTAssertFalse(geometry.hasCameraControl)
    }

    func testIPhoneSEThirdGenerationUsesModelGeometry() {
        let geometry = DeviceSideButtonGeometry.resolve(
            modelIdentifier: "iPhone14,6",
            screenSize: CGSize(width: 375, height: 667),
            screenHeight: 667
        )

        XCTAssertEqual(geometry.top, 0.1167 * 667)
        XCTAssertEqual(geometry.length, 0.1021 * 667)
        XCTAssertFalse(geometry.hasCameraControl)
    }

    func testUnknownIdentifierUsesNewestMatchingScreenSizeWithoutCameraControl() {
        let geometry = DeviceSideButtonGeometry.resolve(
            modelIdentifier: "iPhone99,9",
            screenSize: CGSize(width: 393, height: 852),
            screenHeight: 852
        )

        XCTAssertEqual(geometry.top, 0.3063 * 852)
        XCTAssertEqual(geometry.length, 0.1255 * 852)
        XCTAssertFalse(geometry.hasCameraControl)
    }

    func testUnknownIdentifierAndSizeUseFaceIDMedianFallback() {
        let geometry = DeviceSideButtonGeometry.resolve(
            modelIdentifier: "iPhone99,9",
            screenSize: .zero,
            screenHeight: 874
        )

        XCTAssertEqual(geometry.top, 0.2793 * 874)
        XCTAssertEqual(geometry.length, 0.1223 * 874)
        XCTAssertFalse(geometry.hasCameraControl)
    }

    func testCurrentNormalizesLandscapeBoundsToPortraitGeometry() {
        let geometry = DeviceSideButtonGeometry.current(
            environment: [:],
            screenBounds: CGRect(x: 0, y: 0, width: 852, height: 393),
            machineIdentifier: "iPhone99,9"
        )

        XCTAssertEqual(geometry.top, 0.3063 * 852)
        XCTAssertEqual(geometry.length, 0.1255 * 852)
        XCTAssertFalse(geometry.hasCameraControl)
    }

    func testCurrentPrefersSimulatorModelIdentifier() {
        let geometry = DeviceSideButtonGeometry.current(
            environment: ["SIMULATOR_MODEL_IDENTIFIER": "iPhone17,1"],
            screenBounds: CGRect(x: 0, y: 0, width: 874, height: 402),
            machineIdentifier: "iPhone14,6"
        )

        XCTAssertEqual(geometry.top, 0.3044 * 874)
        XCTAssertEqual(geometry.length, 0.1222 * 874)
        XCTAssertTrue(geometry.hasCameraControl)
    }
}
