import XCTest

@testable import DopaBreak

/// プランカードの導入オファー表記（「7日間 ¥0」）の組み立てと退避を確かめる。
/// 通貨記号はStoreKitの価格書式が決めるため、ここでは記号をリテラルで固定しないことを併せて検証する。
final class IntroOfferDisplayTests: XCTestCase {
    private let duration = "7日間"

    // MARK: - 表記の型の選択

    func testUsesZeroPriceWhenDurationAndZeroPriceAreBothAvailable() {
        XCTAssertEqual(
            IntroOfferDisplayPolicy.planCardStyle(durationText: duration, zeroPriceText: "¥0"),
            .durationWithZeroPrice(duration: duration, zeroPrice: "¥0")
        )
    }

    func testKeepsForeignCurrencySymbolFromStoreKit() {
        // 日本語UIでも米国ストアの利用者はUSDで請求される。書式が返した記号をそのまま使う。
        XCTAssertEqual(
            IntroOfferDisplayPolicy.planCardStyle(durationText: duration, zeroPriceText: "$0"),
            .durationWithZeroPrice(duration: duration, zeroPrice: "$0")
        )
        XCTAssertEqual(
            IntroOfferDisplayPolicy.planCardStyle(durationText: "7일", zeroPriceText: "₩0"),
            .durationWithZeroPrice(duration: "7일", zeroPrice: "₩0")
        )
    }

    func testTrimsSurroundingWhitespaceFromFormattedValues() {
        XCTAssertEqual(
            IntroOfferDisplayPolicy.planCardStyle(durationText: " 7日間 ", zeroPriceText: " ¥0 "),
            .durationWithZeroPrice(duration: duration, zeroPrice: "¥0")
        )
    }

    func testFallsBackToDurationOnlyWhenZeroPriceIsMissing() {
        XCTAssertEqual(
            IntroOfferDisplayPolicy.planCardStyle(durationText: duration, zeroPriceText: nil),
            .durationOnly(duration: duration)
        )
    }

    func testFallsBackToDurationOnlyWhenZeroPriceIsBlank() {
        XCTAssertEqual(
            IntroOfferDisplayPolicy.planCardStyle(durationText: duration, zeroPriceText: "   "),
            .durationOnly(duration: duration)
        )
    }

    func testFallsBackToDurationOnlyWhenZeroPriceHasNoDigits() {
        // 書式化が崩れて記号だけになった値は金額として読めないので使わない。
        XCTAssertEqual(
            IntroOfferDisplayPolicy.planCardStyle(durationText: duration, zeroPriceText: "¥"),
            .durationOnly(duration: duration)
        )
    }

    func testFallsBackToUnspecifiedWhenDurationIsMissing() {
        XCTAssertEqual(
            IntroOfferDisplayPolicy.planCardStyle(durationText: nil, zeroPriceText: "¥0"),
            .unspecified
        )
    }

    func testFallsBackToUnspecifiedWhenDurationIsBlank() {
        XCTAssertEqual(
            IntroOfferDisplayPolicy.planCardStyle(durationText: "  ", zeroPriceText: "¥0"),
            .unspecified
        )
    }

    // MARK: - ゼロ価格の受け入れ判定

    func testNormalizedZeroPriceAcceptsEveryCurrencyFormat() {
        for value in ["¥0", "$0", "₩0", "0 €", "US$0"] {
            XCTAssertEqual(IntroOfferDisplayPolicy.normalizedZeroPriceText(value), value)
        }
    }

    func testNormalizedZeroPriceRejectsUnusableValues() {
        for value in [nil, "", "   ", "¥", "—"] as [String?] {
            XCTAssertNil(IntroOfferDisplayPolicy.normalizedZeroPriceText(value))
        }
    }

    // MARK: - 組み立てた文字列

    func testTextCarriesBothDurationAndZeroPrice() {
        // 言語ごとに語順が違うため、順序ではなく両方が欠けないことを見る。
        let text = IntroOfferDisplayPolicy.planCardText(durationText: duration, zeroPriceText: "$0")
        XCTAssertTrue(text.contains(duration), text)
        XCTAssertTrue(text.contains("$0"), text)
        XCTAssertFalse(text.contains("¥"), text)
    }

    func testTextKeepsDurationWhenZeroPriceIsUnavailable() {
        let text = IntroOfferDisplayPolicy.planCardText(durationText: duration, zeroPriceText: nil)
        XCTAssertTrue(text.contains(duration), text)
    }

    func testTextStaysReadableWhenDurationIsUnavailable() {
        let text = IntroOfferDisplayPolicy.planCardText(durationText: nil, zeroPriceText: "¥0")
        XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertFalse(text.contains("%"), text)
    }

    // MARK: - カタログの書式

    func testCatalogFormatKeepsBothArgumentsInEveryLanguage() {
        for language in ["ja", "en", "ko"] {
            guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
                  let bundle = Bundle(path: path) else {
                XCTFail("\(language).lproj が見つからない")
                continue
            }
            let key = "store.intro_offer.zero_price"
            let format = bundle.localizedString(forKey: key, value: nil, table: nil)
            XCTAssertNotEqual(format, key, "\(language): カタログにキーがない")
            let text = String(format: format, duration, "¥0")
            XCTAssertTrue(text.contains(duration), "\(language): 期間が落ちた -> \(text)")
            XCTAssertTrue(text.contains("¥0"), "\(language): ゼロ価格が落ちた -> \(text)")
            XCTAssertFalse(text.contains("%"), "\(language): 位置指定子が残った -> \(text)")
        }
    }

    func testJapaneseCatalogFormatHasNoPunctuation() {
        guard let path = Bundle.main.path(forResource: "ja", ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return XCTFail("ja.lproj が見つからない")
        }
        let format = bundle.localizedString(
            forKey: "store.intro_offer.zero_price",
            value: nil,
            table: nil
        )
        XCTAssertFalse(format.contains("、"))
        XCTAssertFalse(format.contains("。"))
    }
}
