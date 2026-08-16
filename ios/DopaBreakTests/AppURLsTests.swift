import Foundation
import XCTest
@testable import DopaBreak

final class AppURLsTests: XCTestCase {
    func testJapaneseLanguagesMapToJaSuffix() {
        XCTAssertEqual(AppURLs.legalLanguageSuffix(preferredLanguages: ["ja"]), "ja")
        XCTAssertEqual(AppURLs.legalLanguageSuffix(preferredLanguages: ["ja-JP"]), "ja")
    }

    func testKoreanLanguagesMapToKoSuffix() {
        XCTAssertEqual(AppURLs.legalLanguageSuffix(preferredLanguages: ["ko"]), "ko")
        XCTAssertEqual(AppURLs.legalLanguageSuffix(preferredLanguages: ["ko-KR"]), "ko")
    }

    func testEnglishAndUnsupportedLanguagesFallBackToEnSuffix() {
        XCTAssertEqual(AppURLs.legalLanguageSuffix(preferredLanguages: ["en"]), "en")
        XCTAssertEqual(AppURLs.legalLanguageSuffix(preferredLanguages: ["en-US"]), "en")
        XCTAssertEqual(AppURLs.legalLanguageSuffix(preferredLanguages: ["fr"]), "en")
        XCTAssertEqual(AppURLs.legalLanguageSuffix(preferredLanguages: []), "en")
    }

    func testSecondPreferenceWinsWhenFirstLanguageIsUnsupported() {
        XCTAssertEqual(
            AppURLs.legalLanguageSuffix(preferredLanguages: ["fr-FR", "ja-JP"]),
            "ja"
        )
        XCTAssertEqual(
            AppURLs.legalLanguageSuffix(preferredLanguages: ["de-DE", "ko-KR", "ja-JP"]),
            "ko"
        )
    }

    func testSimilarLookingLanguageCodesDoNotFalseMatch() {
        // kok (Konkani) must not prefix-match ko (Korean).
        XCTAssertEqual(AppURLs.legalLanguageSuffix(preferredLanguages: ["kok"]), "en")
    }

    func testLegalPagesShareOneLanguageSuffixAndBase() {
        let suffix = AppURLs.legalLanguageSuffix(
            preferredLanguages: Locale.preferredLanguages
        )

        XCTAssertEqual(
            AppURLs.terms.absoluteString,
            "https://saku1110.github.io/dopabreak-legal/terms-\(suffix).html"
        )
        XCTAssertEqual(
            AppURLs.privacy.absoluteString,
            "https://saku1110.github.io/dopabreak-legal/privacy-\(suffix).html"
        )
        XCTAssertEqual(
            AppURLs.support.absoluteString,
            "https://saku1110.github.io/dopabreak-legal/support-\(suffix).html"
        )
    }
}
