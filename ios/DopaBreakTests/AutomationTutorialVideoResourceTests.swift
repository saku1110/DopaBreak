import XCTest

@testable import DopaBreak

final class AutomationTutorialVideoResourceTests: XCTestCase {
    func testJapaneseUsesJapaneseVideo() {
        XCTAssertEqual(
            automationTutorialVideoResourceName(for: "ja"),
            "automation-tutorial-ja"
        )
    }

    func testKoreanUsesKoreanVideo() {
        XCTAssertEqual(
            automationTutorialVideoResourceName(for: "ko"),
            "automation-tutorial-ko"
        )
    }

    func testEnglishUsesEnglishVideo() {
        XCTAssertEqual(
            automationTutorialVideoResourceName(for: "en"),
            "automation-tutorial-en"
        )
    }

    func testUnknownLanguageFallsBackToEnglishVideo() {
        XCTAssertEqual(
            automationTutorialVideoResourceName(for: "fr"),
            "automation-tutorial-en"
        )
    }

    func testNilLanguageFallsBackToEnglishVideo() {
        XCTAssertEqual(
            automationTutorialVideoResourceName(for: nil),
            "automation-tutorial-en"
        )
    }

    func testUppercaseJapaneseUsesJapaneseVideo() {
        XCTAssertEqual(
            automationTutorialVideoResourceName(for: "JA"),
            "automation-tutorial-ja"
        )
    }
}
