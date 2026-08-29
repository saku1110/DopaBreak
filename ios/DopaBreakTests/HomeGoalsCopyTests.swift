import Foundation
import XCTest

final class HomeGoalsCopyTests: XCTestCase {
    private let languages = ["ja", "en", "ko"]

    func testHomeGoalActionsAreTranslatedInEverySupportedLanguage() throws {
        let strings = try localizableStrings()

        for key in ["home.goal.add", "home.goal.edit"] {
            let localizations = try localizations(for: key, in: strings)
            for language in languages {
                let stringUnit = try stringUnit(for: language, in: localizations)
                XCTAssertEqual(stringUnit["state"] as? String, "translated", "\(key) \(language)")
                XCTAssertFalse(
                    (stringUnit["value"] as? String ?? "").isEmpty,
                    "\(key) \(language) must have a value"
                )
            }
        }
    }

    func testOnboardingGoalNoteHasNoGoalLimitCopy() throws {
        let strings = try localizableStrings()
        let localizations = try localizations(for: "onboarding.goal.multi_note", in: strings)
        let forbiddenExpressions = ["1つまで", "one goal", "up to 1", "1개", "한 개"]

        for language in languages {
            let stringUnit = try stringUnit(for: language, in: localizations)
            let value = try XCTUnwrap(stringUnit["value"] as? String)
            let normalized = value.lowercased()
            for expression in forbiddenExpressions {
                XCTAssertFalse(
                    normalized.contains(expression),
                    "\(language) must not contain the limit expression \(expression)"
                )
            }
        }
    }

    func testOnboardingGoalTitleBreaksAtTheMeaningBoundary() throws {
        let strings = try localizableStrings()
        let localizations = try localizations(for: "onboarding.goal.title", in: strings)
        let japanese = try stringUnit(for: "ja", in: localizations)

        XCTAssertEqual(
            japanese["value"] as? String,
            "取り戻した時間で\n何をしたいですか？"
        )
    }

    func testHomeBlockSettingsActionUsesLandingSectionVocabularyInEveryLanguage() throws {
        let strings = try localizableStrings()
        let localizations = try localizations(for: "home.targets.block_settings", in: strings)
        let expected = [
            "ja": "止める強さを設定する",
            "en": "Set limit level",
            "ko": "제한 강도 설정하기"
        ]

        for language in languages {
            let stringUnit = try stringUnit(for: language, in: localizations)
            XCTAssertEqual(stringUnit["state"] as? String, "translated", language)
            XCTAssertEqual(stringUnit["value"] as? String, expected[language], language)
        }
    }

    private func localizableStrings() throws -> [String: Any] {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let catalogURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("DopaBreak/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let catalog = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        return try XCTUnwrap(catalog["strings"] as? [String: Any])
    }

    private func localizations(
        for key: String,
        in strings: [String: Any]
    ) throws -> [String: Any] {
        let entry = try XCTUnwrap(strings[key] as? [String: Any], key)
        return try XCTUnwrap(entry["localizations"] as? [String: Any], key)
    }

    private func stringUnit(
        for language: String,
        in localizations: [String: Any]
    ) throws -> [String: Any] {
        let localization = try XCTUnwrap(localizations[language] as? [String: Any], language)
        return try XCTUnwrap(localization["stringUnit"] as? [String: Any], language)
    }
}
