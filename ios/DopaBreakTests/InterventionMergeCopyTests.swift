import Foundation
import XCTest

final class InterventionMergeCopyTests: XCTestCase {
    private let expectedValues: [String: [String: String]] = [
        "intervention.usage_summary.attempt_line": [
            "ja": "今日開こうとした回数　%lld回",
            "en": "Tried to open today · %lld",
            "ko": "오늘 열려고 한 횟수 · %lld회"
        ],
        "intervention.usage_summary.cancelled_line": [
            "ja": "今日開かなかった回数　%lld回",
            "en": "Didn't open today · %lld",
            "ko": "오늘 열지 않은 횟수 · %lld회"
        ],
        "intervention.usage_summary.attempt_label": [
            "ja": "開こうとした回数",
            "en": "Tried to open",
            "ko": "열려고 한 횟수"
        ],
        "intervention.usage_summary.cancelled_label": [
            "ja": "開かなかった",
            "en": "Didn't open",
            "ko": "열지 않음"
        ],
        "intervention.usage_summary.count_value": [
            "ja": "%lld回",
            "en": "%lld times",
            "ko": "%lld회"
        ],
        "intervention.goal.action.edit": [
            "ja": "変える",
            "en": "Edit",
            "ko": "바꾸기"
        ],
        "intervention.usage_summary.eyebrow_ja": [
            "ja": "今日のSNS",
            "en": "Today",
            "ko": "오늘"
        ],
        "intervention.goal.eyebrow_ja": [
            "ja": "あなたの目標",
            "en": "Your goal",
            "ko": "나의 목표"
        ],
        "intervention.usage_summary.action.cancel": [
            "ja": "開かない",
            "en": "Don't open",
            "ko": "열지 않기"
        ],
        "intervention.usage_summary.action.open": [
            "ja": "開く",
            "en": "Open",
            "ko": "열기"
        ],
        "intervention.usage_summary.action.choose_duration": [
            "ja": "開く時間を選ぶ",
            "en": "Choose access time",
            "ko": "열어 둘 시간 선택"
        ]
    ]

    private let approvedManualLineBreaks: Set<String> = [
        "DopaBreak/Localizable.xcstrings::onboarding.apps.empty_selection_message::en",
        "DopaBreak/Localizable.xcstrings::onboarding.apps.empty_selection_message::ko",
        "DopaBreak/Localizable.xcstrings::onboarding.goal.title::ja",
        "DopaBreak/Localizable.xcstrings::onboarding.welcome.title::ja",
        "DopaBreak/Localizable.xcstrings::paywall.legal.auto_renew::en",
        "DopaBreak/Localizable.xcstrings::paywall.legal.auto_renew::ja",
        "DopaBreak/Localizable.xcstrings::paywall.legal.auto_renew::ko",
        "DopaBreak/Localizable.xcstrings::intervention.duration.title::en",
        "DopaBreak/Localizable.xcstrings::intervention.duration.title::ja",
        "DopaBreak/Localizable.xcstrings::intervention.duration.title::ko",
        "DopaBreak/Localizable.xcstrings::intervention.intent.title::en",
        "DopaBreak/Localizable.xcstrings::intervention.intent.title::ja",
        "DopaBreak/Localizable.xcstrings::intervention.intent.title::ko"
    ]

    func testMergedInterventionCopyIsTranslatedInEverySupportedLanguage() throws {
        let strings = try localizableStrings()

        for (key, expectedByLanguage) in expectedValues {
            let entry = try XCTUnwrap(strings[key] as? [String: Any], key)
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], key)
            for (language, expectedValue) in expectedByLanguage {
                let localization = try XCTUnwrap(
                    localizations[language] as? [String: Any],
                    "\(key) \(language)"
                )
                let stringUnit = try XCTUnwrap(
                    localization["stringUnit"] as? [String: Any],
                    "\(key) \(language)"
                )
                XCTAssertEqual(stringUnit["state"] as? String, "translated", "\(key) \(language)")
                XCTAssertEqual(stringUnit["value"] as? String, expectedValue, "\(key) \(language)")
            }
        }
    }

    func testMergedScreenDoesNotUseEnglishEyebrowsAsDefaultValues() throws {
        let mergedScreenSource = try mergedScreenSource()

        XCTAssertFalse(mergedScreenSource.contains("defaultValue: \"USAGE SUMMARY\""))
        XCTAssertFalse(mergedScreenSource.contains("defaultValue: \"YOUR GOAL\""))
        XCTAssertTrue(mergedScreenSource.contains("intervention.usage_summary.eyebrow_ja"))
        XCTAssertTrue(mergedScreenSource.contains("intervention.goal.eyebrow_ja"))
    }

    func testMergedUsageCountsCannotWrapAwayFromTheirUnits() throws {
        let mergedScreenSource = try mergedScreenSource()

        XCTAssertFalse(mergedScreenSource.contains("Text(usageAttemptLine)"))
        XCTAssertFalse(mergedScreenSource.contains("Text(usageCancelledLine)"))
        XCTAssertTrue(mergedScreenSource.contains("Text(usageAttemptCountValue)"))
        XCTAssertTrue(mergedScreenSource.contains("Text(usageCancelledCountValue)"))
        XCTAssertTrue(mergedScreenSource.contains("ViewThatFits(in: .horizontal)"))
        XCTAssertTrue(mergedScreenSource.contains(".accessibilityLabel(usageAttemptLine)"))
        XCTAssertTrue(mergedScreenSource.contains(".accessibilityLabel(usageCancelledLine)"))
    }

    func testDecisionScreenIsMergedIntoUsageSummary() throws {
        let viewSource = try String(contentsOf: interventionFlowViewURL(), encoding: .utf8)
        let modelSource = try String(
            contentsOf: projectURL("DopaBreak/InterventionFlowModel.swift"),
            encoding: .utf8
        )
        let mergedScreenSource = try mergedScreenSource()

        XCTAssertFalse(viewSource.contains("private var decisionScreen"))
        XCTAssertFalse(viewSource.contains("intervention.decision.title"))
        XCTAssertFalse(modelSource.contains("case decision"))
        XCTAssertTrue(mergedScreenSource.contains("flow.chooseCancel()"))
        XCTAssertTrue(mergedScreenSource.contains("flow.chooseOpen()"))
    }

    func testTimedNotificationsAreRemovedFromTheInterventionFlow() throws {
        let viewSource = try String(contentsOf: interventionFlowViewURL(), encoding: .utf8)
        let modelSource = try String(
            contentsOf: projectURL("DopaBreak/InterventionFlowModel.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(modelSource.contains("UNTimeIntervalNotificationTrigger"))
        XCTAssertFalse(modelSource.contains("scheduleTimeUpNotification"))
        XCTAssertFalse(modelSource.contains("scheduleMidSessionCheckIn"))
        XCTAssertFalse(modelSource.contains("notificationsAuthorized"))
        XCTAssertFalse(viewSource.contains("notificationMessage"))
        XCTAssertTrue(modelSource.contains("recordCatalogOpen(durationSeconds: duration.seconds)"))
        XCTAssertTrue(modelSource.contains("private func proceedToOpenOrDurationSelection() {\n        stage = .durationSelection"))
    }

    func testUsageTimeAlertUIAndMonitorNotificationsAreRemoved() throws {
        let settingsSource = try String(
            contentsOf: projectURL("DopaBreak/SettingsNotificationsView.swift"),
            encoding: .utf8
        )
        let monitorSource = try String(
            contentsOf: projectURL("MonitorExtension/DeviceActivityMonitorExtension.swift"),
            encoding: .utf8
        )
        let paywallSource = try String(
            contentsOf: projectURL("DopaBreak/PaywallView.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(settingsSource.contains("settings.usage_watch"))
        XCTAssertFalse(settingsSource.contains("FamilyActivityPicker"))
        XCTAssertFalse(monitorSource.contains("eventDidReachThreshold"))
        XCTAssertFalse(monitorSource.contains("UNNotificationRequest"))
        XCTAssertFalse(monitorSource.contains("usagewatch"))
        XCTAssertFalse(paywallSource.contains("paywall.feature.usage_watch"))
        XCTAssertFalse(paywallSource.contains("paywall.feature.gate_settings"))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: projectURL("DopaBreak/Usage" + "WatchController.swift").path
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: projectURL(
                    "Packages/DopaBreakCore/Sources/DopaBreakCore/Services/Usage"
                        + "WatchPolicy.swift"
                ).path
            )
        )
    }

    func testManualLineBreaksOnlyAppearAtReviewedSemanticBoundaries() throws {
        let catalogPaths = [
            "DopaBreak/Localizable.xcstrings",
            "MonitorExtension/Localizable.xcstrings",
            "ShieldActionExtension/Localizable.xcstrings",
            "ShieldConfigExtension/Localizable.xcstrings",
            "WidgetsExtension/Localizable.xcstrings"
        ]
        var actualBreaks = Set<String>()

        for catalogPath in catalogPaths {
            let data = try Data(contentsOf: projectURL(catalogPath))
            let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])

            for (key, rawEntry) in strings {
                guard let entry = rawEntry as? [String: Any],
                      let localizations = entry["localizations"] as? [String: Any] else {
                    continue
                }
                for (language, localization) in localizations {
                    for value in localizedValues(in: localization) where value.contains("\n") {
                        actualBreaks.insert("\(catalogPath)::\(key)::\(language)")
                        let nonemptyLines = value
                            .components(separatedBy: "\n")
                            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                        XCTAssertFalse(
                            nonemptyLines.contains { ["回", "회", "분", "times"].contains($0) },
                            "単位だけの改行は禁止: \(catalogPath) \(key) \(language)"
                        )
                    }
                }
            }
        }

        XCTAssertEqual(actualBreaks, approvedManualLineBreaks)
    }

    private func localizableStrings() throws -> [String: Any] {
        let data = try Data(contentsOf: projectURL("DopaBreak/Localizable.xcstrings"))
        let catalog = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        return try XCTUnwrap(catalog["strings"] as? [String: Any])
    }

    private func interventionFlowViewURL() -> URL {
        projectURL("DopaBreak/InterventionFlowView.swift")
    }

    private func mergedScreenSource() throws -> String {
        let source = try String(contentsOf: interventionFlowViewURL(), encoding: .utf8)
        let mergedStart = try XCTUnwrap(
            source.range(of: "// MARK: - 反射的な目的の利用状況 + 目標 + 判断")
        )
        let mergedEnd = try XCTUnwrap(
            source.range(of: "// MARK: - S-04 理由", range: mergedStart.upperBound..<source.endIndex)
        )
        return String(source[mergedStart.lowerBound..<mergedEnd.lowerBound])
    }

    private func localizedValues(in object: Any) -> [String] {
        if let value = object as? String {
            return [value]
        }
        if let values = object as? [Any] {
            return values.flatMap(localizedValues(in:))
        }
        if let values = object as? [String: Any] {
            return values.values.flatMap(localizedValues(in:))
        }
        return []
    }

    private func projectURL(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
    }
}
