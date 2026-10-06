import DopaBreakCore
import SwiftUI
import UIKit
import XCTest

@testable import DopaBreak

/// Live Activityカードの件数別レイアウトを目視検証するためのハーネス。
/// 10テーマ×目標1〜5件を PNG へ書き出し、`output/verify/live-activity-density/` へ保存する。
/// 行間・行高・下余白・文字の潰れは数値テストだけでは判定できないため、実描画で確認する。
final class LockThemeDensitySnapshotCapture: XCTestCase {
    /// Opt-in store artwork capture. A real window preserves iOS 26 glass materials.
    @MainActor
    func testCaptureAppStoreThemeGallery() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["DOPABREAK_CAPTURE_THEME_GALLERY"] == "1",
            "Only run when generating the App Store theme gallery"
        )
        let environment = ProcessInfo.processInfo.environment
        let outputLocale = environment["DOPABREAK_THEME_GALLERY_LOCALE"] ?? "ja"
        let language: String
        let localeIdentifier: String
        switch outputLocale {
        case "ja": (language, localeIdentifier) = ("ja", "ja_JP")
        case "en-US": (language, localeIdentifier) = ("en", "en_US")
        case "ko": (language, localeIdentifier) = ("ko", "ko_KR")
        default: throw NSError(domain: "ThemeGalleryUnsupportedLocale", code: 1)
        }
        let bundlePath = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
        let localizedBundle = try XCTUnwrap(Bundle(path: bundlePath))
        let directory = Self.outputDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("app-store-screenshots/theme-gallery/raw/\(outputLocale)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let goalsJSON = try XCTUnwrap(environment["DOPABREAK_THEME_GALLERY_GOALS"])
        let goals = try JSONDecoder().decode([String].self, from: Data(goalsJSON.utf8))
        XCTAssertEqual(goals.count, 4)
        let size = CGSize(width: 393, height: LockThemeLiveActivityView.maximumHeight)
        let registeredFonts = DopaBreakFontRegistrar.registerBundledFonts()
        let fonts: [DopaBreakBundledFont] = language == "ko"
            ? [.galmuri11, .nanumPenScript] : [.dotGothic16, .zenKurenaido]
        for font in fonts {
            XCTAssertTrue(registeredFonts.contains(font.rawValue))
        }

        for theme in LockTheme.allCases {
            let root = LockThemeLiveActivityView(
                theme: theme,
                goalTitles: goals,
                cancelledCount: 12,
                attemptCount: 15,
                localizationBundle: localizedBundle,
                locale: Locale(identifier: localeIdentifier)
            )
            .frame(width: size.width, height: size.height)
            .environment(\.locale, Locale(identifier: localeIdentifier))
            .environment(\.colorScheme, .dark)
            .ignoresSafeArea()
            let controller = UIHostingController(rootView: root)
            controller.view.backgroundColor = .clear
            let scene = try XCTUnwrap(
                UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            )
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
            let background = UIColor(red: 11 / 255, green: 13 / 255, blue: 15 / 255, alpha: 1)
            window.backgroundColor = background
            controller.view.backgroundColor = background
            window.overrideUserInterfaceStyle = .dark
            window.rootViewController = controller
            window.makeKeyAndVisible()
            controller.view.frame = window.bounds
            window.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            let format = UIGraphicsImageRendererFormat()
            format.opaque = true
            format.scale = 3
            let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                controller.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
            }
            let cgImage = try XCTUnwrap(image.cgImage)
            guard CoreScreensSnapshotCapturePolicy.hasVisibleContent(in: cgImage) else {
                XCTFail("Blank capture for \(theme)")
                throw NSError(domain: "ThemeGalleryCapture", code: 1)
            }
            let data = try XCTUnwrap(image.pngData())
            try data.write(to: directory.appendingPathComponent("\(theme.rawValue).png"))
            XCTAssertEqual(image.cgImage?.width, 1179)
            XCTAssertEqual(image.cgImage?.height, 480)
            window.isHidden = true
            window.rootViewController = nil
        }
        let metadata: [String: Any] = [
            "locale": outputLocale,
            "themes": LockTheme.allCases.map(\.rawValue),
            "goals": goals,
            "fonts": fonts.map(\.rawValue),
            "eyebrow": localizedBundle.localizedString(forKey: "live_activity.goal.eyebrow", value: nil, table: nil),
            "summaryCancelled": localizedBundle.localizedString(forKey: "live_activity.summary.cancelled", value: nil, table: nil),
            "summaryAttempted": localizedBundle.localizedString(forKey: "live_activity.summary.attempted", value: nil, table: nil)
        ]
        try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("capture.json"))
    }

    private static let goals = [
        "ベンチプレス80kg",
        "日常会話を英語で出来るようになる",
        "11月末までに月売上100万",
        "毎朝6時に起きる",
        "週3回ジムに行く"
    ]

    @MainActor
    func testCaptureEveryThemeAtEverySupportedGoalCount() throws {
        let directory = Self.outputDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for theme in LockTheme.allCases {
            for count in 1...LockThemeLiveActivityView.maximumGoals {
                let card = LockThemeLiveActivityView(
                    theme: theme,
                    goalTitles: Array(Self.goals.prefix(count)),
                    cancelledCount: 0,
                    attemptCount: 4
                )
                .frame(width: 393, height: LockThemeLiveActivityView.maximumHeight)

                let renderer = ImageRenderer(content: card)
                renderer.scale = 3
                let image = try XCTUnwrap(renderer.uiImage, "\(theme) count \(count) を描画できなかった")
                let data = try XCTUnwrap(image.pngData(), "\(theme) count \(count) をPNG化できなかった")
                try data.write(
                    to: directory.appendingPathComponent("\(theme.rawValue)-\(count).png")
                )
            }
        }
    }

    private static var outputDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("output/verify/live-activity-density", isDirectory: true)
    }
}
