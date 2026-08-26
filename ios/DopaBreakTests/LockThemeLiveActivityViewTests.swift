import DopaBreakCore
import CoreText
import SwiftUI
import UIKit
import XCTest
@testable import DopaBreak

@MainActor
final class LockThemeLiveActivityViewTests: XCTestCase {
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
            try XCTUnwrap(frames[.e1Goal(index)], "Missing rendered frame for e1 goal \(index)")
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
            summaryFrame.minY - dividerFrame.maxY,
            1,
            "Rendered e1 summary touches or intersects the divider: \(dividerFrame), \(summaryFrame)"
        )
    }

    func testE1SupportedGoalCountsKeepRowsDividerAndSummarySeparated() throws {
        let shortTitle = "朝のランニングを続ける"
        let longTitle = "通知に反応する前に深呼吸して本当に必要な行動か考える"

        for title in [shortTitle, longTitle] {
            for count in 1...3 {
                let frames = try renderedLayoutFrames(
                    theme: .e1,
                    titles: Array(repeating: title, count: count)
                )
                let goals = try (0..<count).map { index in
                    try XCTUnwrap(frames[.e1Goal(index)], "Missing e1 goal \(index) for count \(count)")
                }
                let divider = try XCTUnwrap(frames[.e1Divider])
                let summary = try XCTUnwrap(frames[.e1Summary])

                for (current, next) in zip(goals, goals.dropFirst()) {
                    XCTAssertGreaterThanOrEqual(next.minY - current.maxY, 1)
                }
                XCTAssertGreaterThanOrEqual(divider.minY - goals[count - 1].maxY, 1)
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
            let row = try XCTUnwrap(frames[.e1Goal(index)])
            let inkHeight = textInkHeight(in: image, row: row)
            XCTAssertGreaterThanOrEqual(
                inkHeight,
                10,
                "e1 goal \(index) rendered only \(inkHeight)pt of visible text ink"
            )
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
                let hasExpectedFrames = theme == .e1
                    ? frames[.contentBounds] != nil
                        && (0..<expectedGoalCount).allSatisfy { frames[.e1Goal($0)] != nil }
                        && frames[.e1Divider] != nil
                        && frames[.e1Summary] != nil
                    : frames[.contentBounds] != nil
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
