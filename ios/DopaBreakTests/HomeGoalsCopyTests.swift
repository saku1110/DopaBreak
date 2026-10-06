import Foundation
import XCTest
import UIKit
@testable import DopaBreak

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

    /// Protect the actual 375pt content width at the design font size, including localized phrases.
    func testOnboardingDisplayCopyFitsAtDesignSizeWithoutMidPhraseBreaks() throws {
        let strings = try localizableStrings()
        let keys = [
            "onboarding.goal.title",
            "onboarding.goal.lead",
            "onboarding.goal.multi_note",
            "onboarding.apps.title",
            "onboarding.apps.lead",
            "onboarding.self_check.title",
            "onboarding.self_check.privacy_note",
            "onboarding.aimless.title",
            "onboarding.regret.title",
            "onboarding.regret.lead",
            "onboarding.mode.title",
            "onboarding.mode.lead",
            "onboarding.automation.title",
            "onboarding.automation.lead",
            "onboarding.automation.privacy_note",
            "onboarding.notification.title",
            "onboarding.notification.lead",
            "onboarding.summary.title.pending",
            "onboarding.summary.lead",
            "onboarding.summary.footer",
            "onboarding.summary.block_setup_note",
            "onboarding.block_setup.title",
            "onboarding.block_setup.lead.deep_focus",
            "onboarding.block_setup.lead.night",
            "onboarding.ready.title.pending",
            "onboarding.ready.body",
            "onboarding.ready.body.pending",
            "onboarding.recovery.disclaimer",
            "onboarding.result.disclaimer",
            "onboarding.result.lifetime",
            "onboarding.recovery.lead",
            "onboarding.result.lead",
            "onboarding.goal.helper",
            "onboarding.welcome.tagline",
            "onboarding.self_check.hint",
            "onboarding.apps.free_limit_note",
            "onboarding.automation.confirmed.title",
            "onboarding.summary.title",
            "onboarding.ready.title"
        ]
        for key in keys {
            let localizations = try localizations(for: key, in: strings)
            let isTitle = (key.hasSuffix(".title") || key.contains(".title.pending")) && key != "onboarding.aimless.title"
            let font = UIFont.systemFont(ofSize: isTitle ? 34 : 16, weight: isTitle ? .black : .semibold)
            for language in languages {
                let value = try XCTUnwrap(try stringUnit(for: language, in: localizations)["value"] as? String)
                    .replacingOccurrences(of: "%1$@", with: "23:00")
                    .replacingOccurrences(of: "%2$@", with: "7:00")
                    .replacingOccurrences(of: "%@", with: "6.5")
                XCTAssertFalse(value.contains("\n"), key)
                let phrases = DopaDisplayText.phrases(value)
                XCTAssertLessThanOrEqual(phrases.count, 2, key)
                func width(_ text: String) -> CGFloat {
                    ceil((text as NSString).size(withAttributes: [.font: font]).width)
                }
                let plainWidth = width(DopaDisplayText.plainText(value))
                if plainWidth > 335 {
                    XCTAssertEqual(phrases.count, 2, "\(key) \(language): needs shortening or a semantic boundary (\(plainWidth)pt)")
                    for phrase in phrases {
                        XCTAssertLessThanOrEqual(width(phrase), 335, "\(key) \(language): \(phrase)")
                    }
                }
            }
        }
    }

    func testDisplayCopyRemovesOnlyOptionalBreakAndProtectsKoreanWords() {
        let text = "목표를\u{200B} 잠금 화면에"
        XCTAssertEqual(DopaDisplayText.plainText(text), "목표를 잠금 화면에")
        XCTAssertEqual(DopaDisplayText.phrases(text), ["목표를", "잠금 화면에"])
        XCTAssertEqual(DopaDisplayText.protectingWords("하고 싶나요?", language: "ko"),
                       "하\u{2060}고 싶\u{2060}나\u{2060}요\u{2060}?")
    }

    func testJapanesePlainTextKeepsPhraseSeparators() throws {
        XCTAssertEqual(DopaDisplayText.plainText("最初の文\u{200B}次の文"), "最初の文 次の文")
        let strings = try localizableStrings()
        for key in ["automation.lead", "automation.privacy_note", "block_setup.later_note",
                    "notification.lead", "ready.body.pending"] {
            let translations = try localizations(for: "onboarding." + key, in: strings)
            let value = try XCTUnwrap(try stringUnit(for: "ja", in: translations)["value"] as? String)
            let phrases = DopaDisplayText.phrases(value)
            XCTAssertEqual(phrases.count, 2, key)
            XCTAssertEqual(DopaDisplayText.plainText(value), phrases[0] + " " + phrases[1], key)
            XCTAssertFalse(DopaDisplayText.plainText(value).contains(phrases[0] + phrases[1]), key)
        }
    }

    func testOnboardingGoalHeadingInThreeLanguages() throws {
        let localizations = try localizations(for: "onboarding.goal.title", in: localizableStrings())
        let expected = ["ja": "取り戻す%lld日で\u{200B}何をする？", "en": "%lld days back.\u{200B}What will you do?", "ko": "되찾는 %lld일로\u{200B}무엇을 할까요?"]
        for language in languages {
            let value = try stringUnit(for: language, in: localizations)["value"] as? String
            XCTAssertEqual(value, expected[language])
            XCTAssertFalse(value?.contains("\n") ?? true)
        }
    }

    func testHomeBlockSettingsActionUsesLandingSectionVocabularyInEveryLanguage() throws {
        let strings = try localizableStrings()
        let localizations = try localizations(for: "home.targets.block_settings", in: strings)
        let expected = [
            "ja": "ブロックを設定する",
            "en": "Set up blocking",
            "ko": "차단 설정하기"
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
