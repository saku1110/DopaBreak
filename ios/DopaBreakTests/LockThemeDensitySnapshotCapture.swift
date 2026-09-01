import DopaBreakCore
import SwiftUI
import UIKit
import XCTest

@testable import DopaBreak

/// Live Activityカードの件数別レイアウトを目視検証するためのハーネス。
/// 10テーマ×目標1〜5件を PNG へ書き出し、`output/verify/live-activity-density/` へ保存する。
/// 行間・行高・下余白・文字の潰れは数値テストだけでは判定できないため、実描画で確認する。
final class LockThemeDensitySnapshotCapture: XCTestCase {
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
