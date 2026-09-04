import DopaBreakCore
import CoreText
import SwiftUI
import UIKit
import XCTest
@testable import DopaBreak

@MainActor
final class LockThemeLiveActivityViewTests: XCTestCase {
    private let markerThemes: [LockTheme] = [
        .e1, .gaming, .kpop, .kawaiiPink, .note, .blueprint, .retroPop
    ]

    private struct LocaleFixture {
        let identifier: String
        let goalSets: [[String]]
    }

    func testAppModelInitializationMigratesStoredLockThemeValue() throws {
        let suiteName = "LockThemeLiveActivityViewTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("sumi", forKey: "lockThemeRawValue")

        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LockThemeLiveActivityViewTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: containerURL) }

        _ = AppModel(
            containerProvider: LockThemeTestContainer(url: containerURL),
            settingsStore: SettingsStore(userDefaults: defaults),
            automaticallyRefreshEntitlement: false,
            scheduleNotificationsOnInit: false
        )

        XCTAssertEqual(defaults.string(forKey: "lockThemeRawValue"), LockTheme.gaming.rawValue)
    }

    func testWidgetContentStateRoundTripsAndResolvesLegacyThemeValues() throws {
        let mappings: [(String, LockTheme)] = [
            ("sumi", .gaming),
            ("shinrin", .monochrome),
            ("yozora", .liquidGlass),
            ("future-theme", .e1)
        ]

        for (rawValue, expectedTheme) in mappings {
            let state = DopaBreakActivityAttributes.ContentState(
                goalTitles: ["SNSを開かない"],
                todayCancelledCount: 2,
                todayAttemptCount: 3,
                themeRawValue: rawValue
            )
            let restored = try JSONDecoder().decode(
                DopaBreakActivityAttributes.ContentState.self,
                from: JSONEncoder().encode(state)
            )

            XCTAssertEqual(restored.themeRawValue, rawValue)
            XCTAssertEqual(LockTheme(migratingRawValue: restored.themeRawValue), expectedTheme)
        }
    }

    func testEveryThemeWithLongGoalTitlesFitsWithin160Points() {
        let longTitle = "40文字を超える長い目標タイトルでもロック画面の高さを超えず三件すべてが安全に収まることを確認する"
        XCTAssertGreaterThan(longTitle.count, 40)

        for theme in LockTheme.allCases {
            let view = LockThemeLiveActivityView(
                theme: theme,
                goalTitles: [longTitle, longTitle, longTitle],
                cancelledCount: 12,
                attemptCount: 15,
                isMeasuring: true
            )
            .frame(width: 393)
            let controller = UIHostingController(rootView: view)
            let measured = controller.sizeThatFits(
                in: CGSize(width: 393, height: CGFloat.greatestFiniteMagnitude)
            )

            XCTAssertLessThanOrEqual(measured.height, 160, "\(theme) measured \(measured.height)pt")
            XCTAssertGreaterThanOrEqual(
                measured.height,
                LockThemeLiveActivityView.maximumHeight - 4,
                "\(theme) leaves a \(LockThemeLiveActivityView.maximumHeight - measured.height)pt letterbox"
            )
        }
    }

    func testEveryThemeWithFourAndFiveLongGoalsFitsWithoutVerticalTextCompression() throws {
        let longTitle = "通知に反応する前に深呼吸して本当に必要な行動か落ち着いて考えてから次の行動を選ぶ"
        let card = CGRect(x: 0, y: 0, width: 393, height: LockThemeLiveActivityView.maximumHeight)

        for count in 4...5 {
            let titles = Array(repeating: longTitle, count: count)
            for theme in LockTheme.allCases {
                let frames = try renderedLayoutFrames(theme: theme, titles: titles)
                for index in 0..<count {
                    let frame = try XCTUnwrap(frames[.goal(index)], "Missing goal \(index) for \(theme), count \(count)")
                    XCTAssertTrue(card.insetBy(dx: -0.5, dy: -0.5).contains(frame), "\(theme), count \(count): \(frame)")
                    XCTAssertGreaterThanOrEqual(
                        frame.height,
                        8,
                        "\(theme), count \(count), goal \(index) was vertically compressed to \(frame.height)pt"
                    )
                }

                let measured = UIHostingController(
                    rootView: LockThemeLiveActivityView(
                        theme: theme,
                        goalTitles: titles,
                        cancelledCount: 12,
                        attemptCount: 15,
                        isMeasuring: true
                    )
                    .frame(width: card.width)
                ).sizeThatFits(in: CGSize(width: card.width, height: .greatestFiniteMagnitude))
                XCTAssertEqual(measured.height, card.height, accuracy: 0.5, "\(theme), count \(count)")
            }
        }
    }

    func testAdaptiveDensityUsesApprovedTypographyIncreases() {
        XCTAssertEqual(LockThemeLiveActivityView.maximumGoals, 5)
        XCTAssertEqual(LockSurfaceCoordinator.liveActivityGoalLimit, 5)
        XCTAssertEqual(LockThemeLiveActivityView.goalFontIncrease(forGoalCount: 1), 5)
        XCTAssertEqual(LockThemeLiveActivityView.goalFontIncrease(forGoalCount: 2), 4)
        XCTAssertEqual(LockThemeLiveActivityView.goalFontIncrease(forGoalCount: 3), 3)
        XCTAssertEqual(LockThemeLiveActivityView.goalFontIncrease(forGoalCount: 4), 0)
        XCTAssertEqual(LockThemeLiveActivityView.goalFontIncrease(forGoalCount: 5), -2)
        XCTAssertEqual(LockThemeLiveActivityView.summaryFontIncrease(forGoalCount: 1), 1.5)
        XCTAssertEqual(LockThemeLiveActivityView.summaryFontIncrease(forGoalCount: 2), 1.5)
        XCTAssertEqual(LockThemeLiveActivityView.summaryFontIncrease(forGoalCount: 3), 1)
        XCTAssertEqual(LockThemeLiveActivityView.summaryFontIncrease(forGoalCount: 4), 0.5)
        XCTAssertEqual(LockThemeLiveActivityView.summaryFontIncrease(forGoalCount: 5), 0)
        XCTAssertGreaterThanOrEqual(LockThemeLiveActivityView.e1GoalMinimumHeight(forGoalCount: 1), 60)
        XCTAssertEqual(LockThemeLiveActivityView.e1GoalMinimumHeight(forGoalCount: 2), 46.34375, accuracy: 0.01)
        XCTAssertEqual(
            LockThemeLiveActivityView.e1GoalMinimumHeight(forGoalCount: 3),
            UIFont.systemFont(ofSize: 18, weight: .bold).lineHeight + 2,
            accuracy: 0.01
        )
        XCTAssertEqual(
            LockThemeLiveActivityView.e1GoalMinimumHeight(forGoalCount: 4),
            UIFont.systemFont(ofSize: 15, weight: .bold).lineHeight + 2,
            accuracy: 0.01
        )
        XCTAssertEqual(
            LockThemeLiveActivityView.e1GoalMinimumHeight(forGoalCount: 5),
            UIFont.systemFont(ofSize: 13, weight: .bold).lineHeight + 2,
            accuracy: 0.01
        )
    }

    func testEveryThemeUsesAtLeast120PointsOfTypographyAndFitsWithOneGoal() throws {
        try assertEveryThemeFitsSupportedDensity(
            titles: ["英語で商談できる自分になる"]
        )
    }

    func testEveryThemeUsesAtLeast120PointsOfTypographyAndFitsWithTwoGoals() throws {
        try assertEveryThemeFitsSupportedDensity(
            titles: [
                "英語で商談できる自分になる",
                "朝のランニングを習慣にする"
            ]
        )
    }

    func testEveryGoalMarkerAlignsWithRenderedCapHeightCenterForAllSupportedDensities() throws {
        let title = "HHHHHHHH"

        for theme in markerThemes {
            for count in 1...LockThemeLiveActivityView.maximumGoals {
                var renderedImage: UIImage?
                let frames = try renderedLayoutFrames(
                    theme: theme,
                    titles: Array(repeating: title, count: count),
                    locale: Locale(identifier: "en_US"),
                    imageObserver: { renderedImage = $0 }
                )
                let image = try XCTUnwrap(renderedImage)
                let colors = markerTestColors(for: theme)

                for index in 0..<count {
                    let markerFrame = try XCTUnwrap(
                        frames[.goalMarker(index)],
                        "Missing goal marker for \(theme), count \(count), row \(index)"
                    )
                    let textFrame = try XCTUnwrap(
                        frames[.goal(index)],
                        "Missing goal text for \(theme), count \(count), row \(index)"
                    )
                    let markerCrop = independentMarkerCrop(theme: theme, markerFrame: markerFrame)
                    let markerInk = try XCTUnwrap(
                        inkBounds(in: image, crop: markerCrop, matching: colors.marker),
                        "Missing rendered marker ink for \(theme), count \(count), row \(index)"
                    )
                    let expectedFont = goalUIFont(for: theme, goalCount: count, locale: Locale(identifier: "en_US"))
                    let capInk = try XCTUnwrap(
                        inkBounds(
                            in: image,
                            crop: textFrame,
                            matching: colors.text,
                            minimumInkHeight: expectedFont.capHeight * 0.6,
                            channelTolerance: 96
                        ),
                        "Missing rendered cap ink for \(theme), count \(count), row \(index)"
                    )
                    let delta = markerInk.midY - capInk.midY
                    print("MARKER_DELTA latin theme=\(theme.rawValue) count=\(count) row=\(index) delta=\(delta)")
                    XCTAssertEqual(
                        markerInk.midY,
                        capInk.midY,
                        accuracy: 0.75,
                        "Marker ink is not cap-height centered for \(theme), count \(count), row \(index): marker=\(markerInk), cap=\(capInk)"
                    )
                }
            }
        }
    }

    func testLongJapaneseThreeGoalMarkersAlignAfterTextScaling() throws {
        let titles = [
            "通知に反応する前に深呼吸して本当に必要な行動か落ち着いて考える",
            "英語で自分の考えを説明できるよう毎日声に出して練習を続ける",
            "夜はスマートフォンを別の部屋に置いて明日の予定を紙に書いて眠る"
        ]
        let locale = Locale(identifier: "ja_JP")

        for theme in markerThemes {
            var renderedImage: UIImage?
            let frames = try renderedLayoutFrames(
                theme: theme,
                titles: titles,
                locale: locale,
                imageObserver: { renderedImage = $0 }
            )
            let image = try XCTUnwrap(renderedImage)
            let colors = markerTestColors(for: theme)
            let expectedFont = goalUIFont(for: theme, goalCount: titles.count, locale: locale)

            for index in titles.indices {
                let markerFrame = try XCTUnwrap(frames[.goalMarker(index)])
                let textFrame = try XCTUnwrap(frames[.goal(index)])
                let markerInk = try XCTUnwrap(
                    inkBounds(
                        in: image,
                        crop: independentMarkerCrop(theme: theme, markerFrame: markerFrame),
                        matching: colors.marker
                    )
                )
                let textInk = try XCTUnwrap(
                    inkBounds(
                        in: image,
                        crop: referenceTextCrop(theme: theme, textFrame: textFrame, goalCount: titles.count),
                        matching: colors.text,
                        minimumInkHeight: expectedFont.capHeight * 0.6,
                        channelTolerance: 96
                    )
                )
                let delta = markerInk.midY - textInk.midY
                print("MARKER_DELTA japanese theme=\(theme.rawValue) count=3 row=\(index) delta=\(delta)")
                XCTAssertEqual(
                    markerInk.midY,
                    textInk.midY,
                    accuracy: 0.75,
                    "Scaled Japanese marker is not visually centered for \(theme), row \(index): marker=\(markerInk), text=\(textInk)"
                )
            }
        }
    }

    func testEveryThemeRendersOperationalCopyInJapaneseEnglishAndKoreanWithoutTruncationOrClipping() throws {
        let fixtures = [
            LocaleFixture(identifier: "ja", goalSets: [
                ["読書する", "早く寝る", "散歩する"],
                ["朝のランニングを続ける", "英語を毎日練習する", "本を30分読む"],
                ["英語で商談できる自分になる", "朝のランニングを習慣にする", "夜はスマホを置いて本を読む"]
            ]),
            LocaleFixture(identifier: "en", goalSets: [
                ["Read", "Sleep early", "Take a walk"],
                ["Practice English every day", "Keep up my morning runs", "Read for thirty minutes"],
                ["Become confident speaking English", "Make morning runs a lasting habit", "Put my phone down and read at night"]
            ]),
            LocaleFixture(identifier: "ko", goalSets: [
                ["독서하기", "일찍 자기", "산책하기"],
                ["매일 영어 연습하기", "아침 달리기 계속하기", "30분 동안 책 읽기"],
                ["영어로 자신 있게 대화하는 사람 되기", "아침 달리기를 꾸준한 습관으로 만들기", "밤에는 휴대폰을 놓고 책 읽기"]
            ])
        ]
        let appBundle = Bundle(for: AppDelegate.self)
        let card = CGRect(x: 0, y: 0, width: 393, height: LockThemeLiveActivityView.maximumHeight)
        var renderedCount = 0

        for fixture in fixtures {
            let bundle = try localizedBundle(language: fixture.identifier, in: appBundle)
            let locale = Locale(identifier: fixture.identifier)
            for goals in fixture.goalSets {
                for theme in LockTheme.allCases {
                    let frames = try renderedLayoutFrames(
                        theme: theme,
                        titles: goals,
                        localizationBundle: bundle,
                        locale: locale
                    )
                    let cardBounds = try XCTUnwrap(frames[.cardBounds], "Missing card bounds for \(theme)/\(fixture.identifier)")
                    let contentBounds = try XCTUnwrap(frames[.contentBounds], "Missing content bounds for \(theme)/\(fixture.identifier)")
                    XCTAssertEqual(cardBounds.minX, card.minX, accuracy: 0.5, "\(theme)/\(fixture.identifier)")
                    XCTAssertEqual(cardBounds.minY, card.minY, accuracy: 0.5, "\(theme)/\(fixture.identifier)")
                    XCTAssertEqual(cardBounds.width, card.width, accuracy: 0.5, "\(theme)/\(fixture.identifier)")
                    XCTAssertEqual(cardBounds.height, card.height, accuracy: 0.5, "\(theme)/\(fixture.identifier)")
                    XCTAssertTrue(card.insetBy(dx: -0.5, dy: -0.5).contains(contentBounds), "Content crossed card for \(theme)/\(fixture.identifier): \(contentBounds)")

                    let textElements: [LockThemeLayoutElement] = [
                        .eyebrow,
                        .goal(0), .goal(1), .goal(2),
                        .cancelledSummary, .attemptedSummary
                    ]
                    for element in textElements {
                        let frame = try XCTUnwrap(frames[element], "Missing \(element) for \(theme)/\(fixture.identifier)")
                        XCTAssertGreaterThan(frame.width, 0, "Collapsed \(element) for \(theme)/\(fixture.identifier)")
                        XCTAssertGreaterThan(frame.height, 0, "Collapsed \(element) for \(theme)/\(fixture.identifier)")
                        XCTAssertTrue(card.insetBy(dx: -0.5, dy: -0.5).contains(frame), "Text crossed card for \(theme)/\(fixture.identifier): \(element)=\(frame)")
                    }
                    let conservativeGoalFont = UIFont.monospacedSystemFont(ofSize: 19, weight: .black)
                    for (index, title) in goals.enumerated() {
                        let frame = try XCTUnwrap(frames[.goal(index)])
                        let minimumUntruncatedWidth = singleLineWidth(title, font: conservativeGoalFont) * 0.5
                        XCTAssertGreaterThanOrEqual(
                            frame.width,
                            minimumUntruncatedWidth,
                            "Goal would exceed its 0.5 minimum scale for \(theme)/\(fixture.identifier): \(title)"
                        )
                    }

                    let measured = UIHostingController(
                        rootView: LockThemeLiveActivityView(
                            theme: theme,
                            goalTitles: goals,
                            cancelledCount: 12,
                            attemptCount: 15,
                            isMeasuring: true,
                            localizationBundle: bundle,
                            locale: locale
                        )
                        .frame(width: card.width)
                    ).sizeThatFits(in: CGSize(width: card.width, height: .greatestFiniteMagnitude))
                    XCTAssertEqual(measured.height, card.height, accuracy: 0.5, "\(theme)/\(fixture.identifier) measured \(measured.height)pt")
                    renderedCount += 1
                }
            }
        }

        XCTAssertEqual(renderedCount, 90)
    }

    func testGamingAndNoteFontSelectionUsesDisplayLocale() {
        let expectations: [(LockTheme, String, DopaBreakBundledFont)] = [
            (.gaming, "ja", .dotGothic16),
            (.gaming, "en", .dotGothic16),
            (.gaming, "ko", .galmuri11),
            (.note, "ja", .zenKurenaido),
            (.note, "en", .zenKurenaido),
            (.note, "ko", .nanumPenScript)
        ]

        for (theme, localeIdentifier, expectedFont) in expectations {
            XCTAssertEqual(
                LockThemeFontPolicy.bundledFont(
                    for: theme,
                    locale: Locale(identifier: localeIdentifier)
                ),
                expectedFont,
                "Unexpected font for \(theme)/\(localeIdentifier)"
            )
        }
    }

    func testKoreanGamingAndNoteLinesResolveEveryGlyphToTheirThemeFont() throws {
        XCTAssertEqual(
            DopaBreakFontRegistrar.registerBundledFonts(resourceBundleURL: Bundle.main.bundleURL),
            Set(DopaBreakBundledFont.allCases.map(\.rawValue))
        )
        let appBundle = Bundle(for: AppDelegate.self)
        let koreanBundle = try localizedBundle(language: "ko", in: appBundle)
        let samples: [(LockTheme, DopaBreakBundledFont, String)] = [
            (.gaming, .galmuri11, "30분 독서하기 × 15"),
            (.note, .nanumPenScript, "30분 독서하기 × 15")
        ]

        for (theme, expectedFont, line) in samples {
            var renderedImage: UIImage?
            _ = try renderedLayoutFrames(
                theme: theme,
                titles: ["30분 독서하기", "아침 달리기 계속하기", "영어 연습하기"],
                localizationBundle: koreanBundle,
                locale: Locale(identifier: "ko_KR"),
                imageObserver: { renderedImage = $0 }
            )
            let attachment = XCTAttachment(image: try XCTUnwrap(renderedImage))
            attachment.name = "\(theme)-ko-393x160"
            attachment.lifetime = .keepAlways
            add(attachment)

            let selectedFont = try XCTUnwrap(
                LockThemeFontPolicy.bundledFont(for: theme, locale: Locale(identifier: "ko_KR"))
            )
            XCTAssertEqual(selectedFont, expectedFont)
            XCTAssertEqual(
                resolvedPostScriptNames(in: line, requestedFont: selectedFont.rawValue),
                [expectedFont.rawValue],
                "CoreText used a fallback font within the Korean \(theme) line"
            )
        }
    }

    func testJapaneseAndEnglishLinesKeepTheirExistingThemeFonts() throws {
        let samples: [(LockTheme, String, DopaBreakBundledFont, String)] = [
            (.gaming, "ja", .dotGothic16, "30分読書する"),
            (.gaming, "en", .dotGothic16, "Read for 30 minutes"),
            (.note, "ja", .zenKurenaido, "30分読書する"),
            (.note, "en", .zenKurenaido, "Read for 30 minutes")
        ]

        for (theme, localeIdentifier, expectedFont, line) in samples {
            let selectedFont = try XCTUnwrap(
                LockThemeFontPolicy.bundledFont(
                    for: theme,
                    locale: Locale(identifier: localeIdentifier)
                )
            )
            XCTAssertEqual(selectedFont, expectedFont)
            XCTAssertEqual(
                resolvedPostScriptNames(in: line, requestedFont: selectedFont.rawValue),
                [expectedFont.rawValue],
                "CoreText changed the \(theme)/\(localeIdentifier) theme font"
            )
        }
    }

    func testBlueprintEnglishTitleBlockKeepsTextClearOfOuterBorderAndDivider() throws {
        let appBundle = Bundle(for: AppDelegate.self)
        let bundle = try localizedBundle(language: "en", in: appBundle)
        var renderedImage: UIImage?
        let frames = try renderedLayoutFrames(
            theme: .blueprint,
            titles: ["Become confident speaking English", "Make morning runs a lasting habit", "Put my phone down and read at night"],
            localizationBundle: bundle,
            locale: Locale(identifier: "en"),
            imageObserver: { renderedImage = $0 }
        )
        let cancelledCell = try XCTUnwrap(frames[.blueprintCancelledCell])
        let cancelledText = try XCTUnwrap(frames[.blueprintCancelledText])
        let attemptedCell = try XCTUnwrap(frames[.blueprintAttemptedCell])
        let attemptedText = try XCTUnwrap(frames[.blueprintAttemptedText])
        let minimumInset: CGFloat = 4

        XCTAssertGreaterThanOrEqual(cancelledText.minX - cancelledCell.minX, minimumInset)
        XCTAssertGreaterThanOrEqual(cancelledCell.maxX - cancelledText.maxX, minimumInset)
        XCTAssertGreaterThanOrEqual(attemptedText.minX - attemptedCell.minX, minimumInset)
        XCTAssertGreaterThanOrEqual(attemptedCell.maxX - attemptedText.maxX, minimumInset)

        let attachment = XCTAttachment(image: try XCTUnwrap(renderedImage))
        attachment.name = "blueprint-en-393x160"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testNoteEnglishAttemptSummaryRendersWithBalancedMultiplicationSign() throws {
        let appBundle = Bundle(for: AppDelegate.self)
        let bundle = try localizedBundle(language: "en", in: appBundle)
        var renderedImage: UIImage?
        let frames = try renderedLayoutFrames(
            theme: .note,
            titles: ["Become confident speaking English", "Make morning runs a lasting habit", "Put my phone down and read at night"],
            localizationBundle: bundle,
            locale: Locale(identifier: "en"),
            imageObserver: { renderedImage = $0 }
        )
        let attemptedFrame = try XCTUnwrap(frames[.attemptedSummary])
        XCTAssertTrue(CGRect(x: 0, y: 0, width: 393, height: 160).contains(attemptedFrame))

        let attachment = XCTAttachment(image: try XCTUnwrap(renderedImage))
        attachment.name = "note-en-393x160"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testE1LongThreeGoalLayoutHasPositiveGapsAndClearDivider() throws {
        let longGoals = [
            "通知に反応する前に深呼吸して本当に必要な行動か考える",
            "英語で自分の考えを落ち着いて説明できるよう毎日練習する",
            "夜はスマートフォンを置いて明日の予定を紙に書いてから眠る"
        ]
        let frames = try renderedLayoutFrames(theme: .e1, titles: longGoals)
        let goalFrames = try (0..<3).map { index in
            try XCTUnwrap(frames[.goal(index)], "Missing rendered text frame for e1 goal \(index)")
        }
        let rowFrames = try (0..<3).map { index in
            try XCTUnwrap(frames[.e1Goal(index)], "Missing rendered row frame for e1 goal \(index)")
        }
        let dividerFrame = try XCTUnwrap(frames[.e1Divider], "Missing rendered e1 divider frame")
        let summaryFrame = try XCTUnwrap(frames[.e1Summary], "Missing rendered e1 summary frame")

        for (current, next) in zip(goalFrames, goalFrames.dropFirst()) {
            XCTAssertGreaterThanOrEqual(
                next.minY - current.maxY,
                1,
                "Rendered e1 goal rows overlap or have no positive gap: \(current), \(next)"
            )
        }
        XCTAssertGreaterThanOrEqual(
            dividerFrame.minY - goalFrames[2].maxY,
            1,
            "Rendered e1 divider intersects the final goal: \(goalFrames[2]), \(dividerFrame)"
        )
        XCTAssertGreaterThanOrEqual(
            dividerFrame.minY - rowFrames[2].maxY,
            1,
            "Rendered e1 divider intersects the final row frame: \(rowFrames[2]), \(dividerFrame)"
        )
        XCTAssertGreaterThanOrEqual(
            summaryFrame.minY - dividerFrame.maxY,
            1,
            "Rendered e1 summary touches or intersects the divider: \(dividerFrame), \(summaryFrame)"
        )
    }

    func testE1SupportedGoalCountsKeepRowsDividerAndSummarySeparated() throws {
        let shortTitle = "朝のランニングを続ける"
        let longTitle = "通知に反応する前に深呼吸して本当に必要な行動か考える"

        for title in [shortTitle, longTitle] {
            for count in 1...LockThemeLiveActivityView.maximumGoals {
                let frames = try renderedLayoutFrames(
                    theme: .e1,
                    titles: Array(repeating: title, count: count)
                )
                let goals = try (0..<count).map { index in
                    try XCTUnwrap(frames[.goal(index)], "Missing e1 goal text \(index) for count \(count)")
                }
                let rows = try (0..<count).map { index in
                    try XCTUnwrap(frames[.e1Goal(index)], "Missing e1 goal row \(index) for count \(count)")
                }
                let divider = try XCTUnwrap(frames[.e1Divider])
                let summary = try XCTUnwrap(frames[.e1Summary])

                for (current, next) in zip(goals, goals.dropFirst()) {
                    XCTAssertGreaterThanOrEqual(next.minY - current.maxY, 1)
                }
                XCTAssertGreaterThanOrEqual(divider.minY - goals[count - 1].maxY, 1)
                XCTAssertGreaterThanOrEqual(divider.minY - rows[count - 1].maxY, 1)
                XCTAssertGreaterThanOrEqual(summary.minY - divider.maxY, 1)
            }
        }
    }

    func testE1ThreeGoalTextKeepsAtLeastTenPointsOfVisibleInk() throws {
        let goals = ["英語で商談できる自分になる", "朝のランニングを続ける", "読書を30分する"]
        var renderedImage: UIImage?
        let frames = try renderedLayoutFrames(theme: .e1, titles: goals) { renderedImage = $0 }
        let image = try XCTUnwrap(renderedImage)

        for index in goals.indices {
            let row = try XCTUnwrap(frames[.goal(index)])
            let inkHeight = textInkHeight(in: image, row: row)
            XCTAssertGreaterThanOrEqual(
                inkHeight,
                10,
                "e1 goal \(index) rendered only \(inkHeight)pt of visible text ink"
            )
        }
    }

    func testThreeGoalSpacingNeverExceedsRenderedGoalRowHeight() throws {
        let titles = ["朝のランニングを続ける", "英語を毎日練習する", "本を30分読む"]

        for theme in LockTheme.allCases {
            let frames = try renderedLayoutFrames(theme: theme, titles: titles)
            let goals = try titles.indices.map { index in
                try XCTUnwrap(frames[.goal(index)], "Missing goal \(index) for \(theme)")
            }
            for (current, next) in zip(goals, goals.dropFirst()) {
                let gap = next.minY - current.maxY
                XCTAssertGreaterThanOrEqual(gap, 0, "\(theme) has overlapping goal rows: \(gap)pt")
                XCTAssertLessThanOrEqual(
                    gap,
                    current.height,
                    "\(theme) goal spacing \(gap)pt exceeds its \(current.height)pt rendered row height"
                )
            }
        }
    }

    func testFiveGoalTextKeepsAtLeastEightPointsOfVisibleInkForEveryTheme() throws {
        let titles = Array(repeating: "HHHHHHHH", count: 5)

        for theme in LockTheme.allCases {
            var renderedImage: UIImage?
            let frames = try renderedLayoutFrames(theme: theme, titles: titles) { renderedImage = $0 }
            let image = try XCTUnwrap(renderedImage)
            let textColor = goalTextColor(for: theme)

            for index in titles.indices {
                let frame = try XCTUnwrap(frames[.goal(index)], "Missing goal \(index) for \(theme)")
                let ink = try XCTUnwrap(
                    inkBounds(in: image, crop: frame, matching: textColor, channelTolerance: 72),
                    "Missing goal ink for \(theme), row \(index)"
                )
                XCTAssertGreaterThanOrEqual(
                    ink.height,
                    8,
                    "\(theme) goal \(index) rendered only \(ink.height)pt of visible ink"
                )
            }
        }
    }

    func testThreeThroughFiveGoalsKeepAtLeastSixPointsBelowSummary() throws {
        let title = "朝のランニングを続ける"
        let cardBottom = LockThemeLiveActivityView.maximumHeight

        for count in 3...5 {
            for theme in LockTheme.allCases {
                let frames = try renderedLayoutFrames(
                    theme: theme,
                    titles: Array(repeating: title, count: count)
                )
                let summaryBottom = max(
                    try XCTUnwrap(frames[.cancelledSummary]).maxY,
                    try XCTUnwrap(frames[.attemptedSummary]).maxY
                )
                XCTAssertGreaterThanOrEqual(
                    cardBottom - summaryBottom,
                    6,
                    "\(theme), count \(count) leaves only \(cardBottom - summaryBottom)pt below its summary"
                )
            }
        }
    }

    func testEveryThemeRendersOneCardInsetOfHorizontalContentPadding() throws {
        XCTAssertEqual(LockThemeLiveActivityView.cardInset, 16)
        let width: CGFloat = 393

        for theme in LockTheme.allCases {
            let frames = try renderedLayoutFrames(
                theme: theme,
                titles: ["英語で商談できる自分になる", "朝のランニングを続ける", "読書を30分する"]
            )
            let content = try XCTUnwrap(frames[.contentBounds], "Missing content bounds for \(theme)")
            let expectedLeading: CGFloat = theme == .note ? 46 : LockThemeLiveActivityView.cardInset
            XCTAssertEqual(content.minX, expectedLeading, accuracy: 0.5, "\(theme) leading padding")
            XCTAssertEqual(
                width - content.maxX,
                LockThemeLiveActivityView.cardInset,
                accuracy: 0.5,
                "\(theme) trailing padding"
            )
        }
    }

    func testEveryThemePaintsToEachCanvasEdge() {
        let size = CGSize(width: 393, height: LockThemeLiveActivityView.maximumHeight)
        let edgePoints = [
            CGPoint(x: size.width / 2, y: 1),
            CGPoint(x: size.width / 2, y: size.height - 2),
            CGPoint(x: 1, y: size.height / 2),
            CGPoint(x: size.width - 2, y: size.height / 2)
        ]

        for theme in LockTheme.allCases {
            let controller = UIHostingController(
                rootView: LockThemeLiveActivityView(
                    theme: theme,
                    goalTitles: ["英語で商談できる自分になる", "朝のランニングを続ける", "読書を30分する"],
                    cancelledCount: 12,
                    attemptCount: 15
                )
                .frame(width: size.width)
                .ignoresSafeArea()
            )
            controller.view.backgroundColor = .clear
            let window = UIWindow(frame: CGRect(origin: .zero, size: size))
            window.backgroundColor = .clear
            window.rootViewController = controller
            window.isHidden = false
            window.layoutIfNeeded()

            let format = UIGraphicsImageRendererFormat()
            format.opaque = false
            format.scale = 1
            let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
                controller.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
            }

            for point in edgePoints {
                XCTAssertGreaterThan(
                    alpha(at: point, in: image),
                    0,
                    "\(theme) did not paint canvas edge at \(point)"
                )
            }
            window.isHidden = true
            window.rootViewController = nil
        }
    }

    private struct MarkerTestColors {
        let marker: UIColor
        let text: UIColor
    }

    private func markerTestColors(for theme: LockTheme) -> MarkerTestColors {
        switch theme {
        case .e1:
            return MarkerTestColors(marker: UIColor(red: 184 / 255, green: 1, blue: 61 / 255, alpha: 1),
                                    text: UIColor(red: 244 / 255, green: 242 / 255, blue: 236 / 255, alpha: 1))
        case .gaming:
            return MarkerTestColors(marker: UIColor(red: 0, green: 229 / 255, blue: 1, alpha: 1),
                                    text: UIColor(red: 234 / 255, green: 234 / 255, blue: 242 / 255, alpha: 1))
        case .kpop:
            return MarkerTestColors(marker: UIColor(red: 238 / 255, green: 52 / 255, blue: 137 / 255, alpha: 1),
                                    text: UIColor(red: 35 / 255, green: 31 / 255, blue: 38 / 255, alpha: 1))
        case .kawaiiPink:
            return MarkerTestColors(marker: UIColor(red: 242 / 255, green: 94 / 255, blue: 137 / 255, alpha: 1),
                                    text: UIColor(red: 68 / 255, green: 43 / 255, blue: 49 / 255, alpha: 1))
        case .note:
            return MarkerTestColors(marker: UIColor(red: 90 / 255, green: 81 / 255, blue: 66 / 255, alpha: 1),
                                    text: UIColor(red: 59 / 255, green: 52 / 255, blue: 40 / 255, alpha: 1))
        case .blueprint:
            return MarkerTestColors(marker: .white, text: .white)
        case .retroPop:
            return MarkerTestColors(marker: UIColor(red: 232 / 255, green: 99 / 255, blue: 43 / 255, alpha: 1),
                                    text: UIColor(red: 74 / 255, green: 51 / 255, blue: 32 / 255, alpha: 1))
        default:
            XCTFail("Unexpected marker theme \(theme)")
            return MarkerTestColors(marker: .clear, text: .clear)
        }
    }

    private func goalTextColor(for theme: LockTheme) -> UIColor {
        switch theme {
        case .e1:
            return UIColor(red: 244 / 255, green: 242 / 255, blue: 236 / 255, alpha: 1)
        case .gaming:
            return UIColor(red: 234 / 255, green: 234 / 255, blue: 242 / 255, alpha: 1)
        case .asagiri:
            return UIColor(red: 31 / 255, green: 37 / 255, blue: 47 / 255, alpha: 1)
        case .monochrome:
            return UIColor(red: 18 / 255, green: 18 / 255, blue: 18 / 255, alpha: 1)
        case .liquidGlass, .blueprint:
            return .white
        case .kpop:
            return UIColor(red: 35 / 255, green: 31 / 255, blue: 38 / 255, alpha: 1)
        case .kawaiiPink:
            return UIColor(red: 68 / 255, green: 43 / 255, blue: 49 / 255, alpha: 1)
        case .note:
            return UIColor(red: 59 / 255, green: 52 / 255, blue: 40 / 255, alpha: 1)
        case .retroPop:
            return UIColor(red: 74 / 255, green: 51 / 255, blue: 32 / 255, alpha: 1)
        }
    }

    private func inkBounds(
        in image: UIImage,
        crop: CGRect,
        matching color: UIColor,
        minimumInkHeight: CGFloat? = nil,
        channelTolerance: Int = 48
    ) -> CGRect? {
        guard let cgImage = image.cgImage else {
            XCTFail("Unable to inspect rendered marker image")
            return nil
        }
        var targetRed: CGFloat = 0
        var targetGreen: CGFloat = 0
        var targetBlue: CGFloat = 0
        var targetAlpha: CGFloat = 0
        guard color.getRed(&targetRed, green: &targetGreen, blue: &targetBlue, alpha: &targetAlpha) else {
            XCTFail("Unable to resolve marker test color")
            return nil
        }

        var bytes = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
        guard let context = CGContext(
            data: &bytes,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: cgImage.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Unable to normalize rendered marker image")
            return nil
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

        let target = [targetRed, targetGreen, targetBlue].map { UInt8(round($0 * 255)) }
        let minX = max(0, Int(floor(crop.minX)))
        let maxX = min(cgImage.width - 1, Int(ceil(crop.maxX)) - 1)
        let minY = max(0, Int(floor(crop.minY)))
        let maxY = min(cgImage.height - 1, Int(ceil(crop.maxY)) - 1)
        guard minX <= maxX, minY <= maxY else { return nil }

        var inkMinX = cgImage.width
        var inkMaxX = -1
        var inkMinY = cgImage.height
        var inkMaxY = -1
        for y in minY...maxY {
            for x in minX...maxX {
                let offset = (y * cgImage.width + x) * 4
                guard bytes[offset + 3] >= 128 else { continue }
                let matches = (0..<3).allSatisfy {
                    abs(Int(bytes[offset + $0]) - Int(target[$0])) <= channelTolerance
                }
                guard matches else { continue }
                inkMinX = min(inkMinX, x)
                inkMaxX = max(inkMaxX, x)
                inkMinY = min(inkMinY, y)
                inkMaxY = max(inkMaxY, y)
            }
        }
        guard inkMaxX >= inkMinX, inkMaxY >= inkMinY else { return nil }
        let bounds = CGRect(
            x: inkMinX,
            y: inkMinY,
            width: inkMaxX - inkMinX + 1,
            height: inkMaxY - inkMinY + 1
        )
        if let minimumInkHeight, bounds.height < minimumInkHeight {
            XCTFail("Rendered reference ink is too short to be valid: height=\(bounds.height), minimum=\(minimumInkHeight), crop=\(crop)")
            return nil
        }
        return bounds
    }

    /// e1は目標1〜2件のときだけ2行を許すため、その場合に限り1行目の帯へ絞る。
    /// 3件以上は1行描画なので枠をそのまま使う（半分に切るとグリフが欠ける）。
    private func referenceTextCrop(theme: LockTheme, textFrame: CGRect, goalCount: Int) -> CGRect {
        guard theme == .e1, goalCount <= 2 else { return textFrame }
        return CGRect(
            x: textFrame.minX,
            y: textFrame.minY,
            width: textFrame.width,
            height: textFrame.height / 2
        )
    }

    private func independentMarkerCrop(theme: LockTheme, markerFrame: CGRect) -> CGRect {
        switch theme {
        case .gaming, .note, .blueprint:
            return markerFrame.insetBy(dx: 0, dy: -6)
        default:
            return markerFrame
        }
    }

    private func goalUIFont(for theme: LockTheme, goalCount: Int, locale: Locale) -> UIFont {
        let increase = LockThemeLiveActivityView.goalFontIncrease(forGoalCount: goalCount)
        switch theme {
        case .e1:
            return .systemFont(ofSize: 15 + increase, weight: .bold)
        case .gaming:
            return bundledUIFont(for: .gaming, size: 15.5 + increase, locale: locale, fallbackWeight: .regular)
        case .kpop:
            return .systemFont(ofSize: 15 + increase, weight: .black)
        case .kawaiiPink:
            return UIFont(name: "HiraMaruProN-W4", size: 13 + increase)
                ?? .systemFont(ofSize: 13 + increase, weight: .bold)
        case .note:
            return bundledUIFont(for: .note, size: 15.5 + increase, locale: locale, fallbackWeight: .semibold)
        case .blueprint:
            return .systemFont(ofSize: 14.5 + increase, weight: .bold)
        case .retroPop:
            return UIFont(name: "HiraMaruProN-W4", size: 15 + increase)
                ?? .systemFont(ofSize: 15 + increase, weight: .bold)
        default:
            XCTFail("Unexpected marker theme \(theme)")
            return .systemFont(ofSize: 15)
        }
    }

    private func bundledUIFont(
        for theme: LockTheme,
        size: CGFloat,
        locale: Locale,
        fallbackWeight: UIFont.Weight
    ) -> UIFont {
        guard let font = LockThemeFontPolicy.bundledFont(for: theme, locale: locale),
              let name = DopaBreakFontRegistrar.registeredName(for: font),
              let registeredFont = UIFont(name: name, size: size) else {
            return .systemFont(ofSize: size, weight: fallbackWeight)
        }
        return registeredFont
    }

    private func alpha(at point: CGPoint, in image: UIImage) -> UInt8 {
        guard let cgImage = image.cgImage else {
            XCTFail("Unable to inspect rendered image")
            return 0
        }
        var bytes = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
        guard let context = CGContext(
            data: &bytes,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: cgImage.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Unable to normalize rendered image")
            return 0
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        let x = min(max(Int(point.x), 0), cgImage.width - 1)
        let y = min(max(Int(point.y), 0), cgImage.height - 1)
        return bytes[(y * cgImage.width + x) * 4 + 3]
    }

    private func assertEveryThemeFitsSupportedDensity(titles: [String]) throws {
        let card = CGRect(
            x: 0,
            y: 0,
            width: 393,
            height: LockThemeLiveActivityView.maximumHeight
        )
        let conservativeGoalFont = UIFont.monospacedSystemFont(ofSize: 24, weight: .black)

        for theme in LockTheme.allCases {
            let frames = try renderedLayoutFrames(theme: theme, titles: titles)
            let cardBounds = try XCTUnwrap(frames[.cardBounds], "Missing card bounds for \(theme)")
            XCTAssertEqual(cardBounds.minX, card.minX, accuracy: 0.5, "\(theme)")
            XCTAssertEqual(cardBounds.minY, card.minY, accuracy: 0.5, "\(theme)")
            XCTAssertEqual(cardBounds.width, card.width, accuracy: 0.5, "\(theme)")
            XCTAssertEqual(cardBounds.height, card.height, accuracy: 0.5, "\(theme)")

            let textElements = [.eyebrow]
                + titles.indices.map { LockThemeLayoutElement.goal($0) }
                + [.cancelledSummary, .attemptedSummary]
            let textFrames = try textElements.map { element in
                let frame = try XCTUnwrap(frames[element], "Missing \(element) for \(theme)")
                XCTAssertGreaterThan(frame.width, 0, "Collapsed \(element) for \(theme)")
                XCTAssertGreaterThan(frame.height, 0, "Collapsed \(element) for \(theme)")
                XCTAssertTrue(
                    card.insetBy(dx: -0.5, dy: -0.5).contains(frame),
                    "Text crossed card for \(theme): \(element)=\(frame)"
                )
                return frame
            }
            let typographicSpan = try XCTUnwrap(textFrames.map(\.maxY).max())
                - XCTUnwrap(textFrames.map(\.minY).min())
            let minimumTypographicSpan: CGFloat = theme == .gaming && titles.count == 1 ? 122 : 120
            XCTAssertGreaterThanOrEqual(
                typographicSpan,
                minimumTypographicSpan,
                "\(theme) uses only \(typographicSpan)pt of typographic vertical span with \(titles.count) goals"
            )

            for (index, title) in titles.enumerated() {
                let frame = try XCTUnwrap(frames[.goal(index)])
                let minimumUntruncatedWidth = singleLineWidth(title, font: conservativeGoalFont) * 0.5
                XCTAssertGreaterThanOrEqual(
                    frame.width,
                    minimumUntruncatedWidth,
                    "Goal would exceed its 0.5 minimum scale for \(theme): \(title)"
                )
            }

            let measured = UIHostingController(
                rootView: LockThemeLiveActivityView(
                    theme: theme,
                    goalTitles: titles,
                    cancelledCount: 12,
                    attemptCount: 15,
                    isMeasuring: true
                )
                .frame(width: card.width)
            ).sizeThatFits(in: CGSize(width: card.width, height: .greatestFiniteMagnitude))
            XCTAssertEqual(measured.height, card.height, accuracy: 0.5, "\(theme) measured \(measured.height)pt")
        }
    }

    private func renderedLayoutFrames(
        theme: LockTheme,
        titles: [String],
        localizationBundle: Bundle = .main,
        locale: Locale = .autoupdatingCurrent,
        imageObserver: ((UIImage) -> Void)? = nil
    ) throws -> [LockThemeLayoutElement: CGRect] {
        let size = CGSize(width: 393, height: LockThemeLiveActivityView.maximumHeight)
        let rendered = expectation(description: "Rendered layout frames for \(theme)")
        var observedFrames: [LockThemeLayoutElement: CGRect] = [:]
        var didFulfill = false
        let view = LockThemeLiveActivityView(
            theme: theme,
            goalTitles: titles,
            cancelledCount: 12,
            attemptCount: 15,
            localizationBundle: localizationBundle,
            locale: locale,
            layoutObserver: { frames in
                observedFrames = frames
                let expectedGoalCount = min(titles.count, LockThemeLiveActivityView.maximumGoals)
                let expectsMarkers = self.markerThemes.contains(theme)
                let hasMarkerFrames = !expectsMarkers || (0..<expectedGoalCount).allSatisfy {
                    frames[.goalMarker($0)] != nil && frames[.goal($0)] != nil
                }
                let hasExpectedFrames = theme == .e1
                    ? frames[.contentBounds] != nil
                        && (0..<expectedGoalCount).allSatisfy { frames[.e1Goal($0)] != nil }
                        && (0..<expectedGoalCount).allSatisfy { frames[.goal($0)] != nil }
                        && frames[.e1Divider] != nil
                        && frames[.e1Summary] != nil
                        && hasMarkerFrames
                    : frames[.contentBounds] != nil && hasMarkerFrames
                guard !didFulfill, hasExpectedFrames else { return }
                didFulfill = true
                rendered.fulfill()
            }
        )
        .frame(width: size.width)
        .ignoresSafeArea()
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()

        wait(for: [rendered], timeout: 2)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            controller.view.drawHierarchy(
                in: CGRect(origin: .zero, size: size),
                afterScreenUpdates: true
            )
        }
        XCTAssertEqual(image.size, size)
        XCTAssertGreaterThan(alpha(at: CGPoint(x: 1, y: 80), in: image), 0)
        imageObserver?(image)

        window.isHidden = true
        window.rootViewController = nil
        return observedFrames
    }

    private func localizedBundle(language: String, in bundle: Bundle) throws -> Bundle {
        let path = try XCTUnwrap(bundle.path(forResource: language, ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }

    private func singleLineWidth(_ text: String, font: UIFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private func resolvedPostScriptNames(
        in text: String,
        requestedFont: String
    ) -> Set<String> {
        let font = CTFontCreateWithName(requestedFont as CFString, 17, nil)
        let attributed = NSAttributedString(
            string: text,
            attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]
        )
        let line = CTLineCreateWithAttributedString(attributed)
        let runs = CTLineGetGlyphRuns(line) as! [CTRun]
        return Set(runs.compactMap { run in
            let attributes = CTRunGetAttributes(run) as NSDictionary
            guard let runFont = attributes[kCTFontAttributeName as String] else {
                return nil
            }
            return CTFontCopyPostScriptName(runFont as! CTFont) as String
        })
    }

    private func textInkHeight(in image: UIImage, row: CGRect) -> Int {
        guard let cgImage = image.cgImage else {
            XCTFail("Unable to inspect rendered image")
            return 0
        }
        var bytes = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
        guard let context = CGContext(
            data: &bytes,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: cgImage.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Unable to normalize rendered image")
            return 0
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

        let minX = min(max(Int(row.minX + 20), 0), cgImage.width - 1)
        let maxX = min(max(Int(row.maxX.rounded(.up)), minX + 1), cgImage.width)
        let yRanges = [row, CGRect(x: row.minX, y: CGFloat(cgImage.height) - row.maxY, width: row.width, height: row.height)]

        return yRanges.map { candidate in
            let minY = min(max(Int(candidate.minY.rounded(.down)), 0), cgImage.height - 1)
            let maxY = min(max(Int(candidate.maxY.rounded(.up)), minY + 1), cgImage.height)
            let inkRows = (minY..<maxY).filter { y in
                (minX..<maxX).contains(where: { x in
                    let offset = (y * cgImage.width + x) * 4
                    let red = bytes[offset]
                    let green = bytes[offset + 1]
                    let blue = bytes[offset + 2]
                    let alpha = bytes[offset + 3]
                    return alpha > 0
                        && red >= 180 && green >= 180 && blue >= 180
                        && abs(Int(red) - Int(green)) <= 25
                        && abs(Int(green) - Int(blue)) <= 25
                })
            }
            guard let first = inkRows.first, let last = inkRows.last else { return 0 }
            return last - first + 1
        }.max() ?? 0
    }
}

private struct LockThemeTestContainer: ContainerProviding {
    let url: URL

    func containerURL() throws -> URL { url }
}
