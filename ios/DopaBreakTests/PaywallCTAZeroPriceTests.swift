import XCTest

@testable import DopaBreak

final class PaywallCTAZeroPriceTests: XCTestCase {
    func testCTAUsesDurationAndZeroPriceWhenBothAreAvailable() {
        let text = IntroOfferDisplayPolicy.ctaText(
            durationText: "7日間",
            zeroPriceText: "¥0"
        )

        XCTAssertEqual(text, "7日間 ¥0で始める")
        XCTAssertTrue(text?.contains("7日間") == true, text ?? "nil")
        XCTAssertTrue(text?.contains("¥0") == true, text ?? "nil")
    }

    func testCTAReturnsNilForUnusableZeroPrice() {
        for zeroPrice in [nil, "", "   ", "¥"] as [String?] {
            XCTAssertNil(
                IntroOfferDisplayPolicy.ctaText(
                    durationText: "7日間",
                    zeroPriceText: zeroPrice
                )
            )
        }
    }

    func testCTAReturnsNilWithoutDuration() {
        XCTAssertNil(
            IntroOfferDisplayPolicy.ctaText(
                durationText: nil,
                zeroPriceText: "¥0"
            )
        )
    }

    func testCatalogHasTranslatedPositionalArgumentsInEveryLanguage() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("DopaBreak/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let catalog = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        let entry = try XCTUnwrap(
            strings["paywall.action.start_zero_price"] as? [String: Any]
        )
        let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any])

        for language in ["ja", "en", "ko"] {
            let localization = try XCTUnwrap(
                localizations[language] as? [String: Any],
                "\(language): localization is missing"
            )
            let stringUnit = try XCTUnwrap(
                localization["stringUnit"] as? [String: Any],
                "\(language): stringUnit is missing"
            )
            XCTAssertEqual(stringUnit["state"] as? String, "translated", language)
            let value = try XCTUnwrap(stringUnit["value"] as? String, language)
            XCTAssertTrue(value.contains("%1$@"), "\(language): %1$@ is missing")
            XCTAssertTrue(value.contains("%2$@"), "\(language): %2$@ is missing")
        }
    }
}
