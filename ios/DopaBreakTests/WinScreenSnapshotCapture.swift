import DopaBreakCore
import SwiftUI
import UIKit
import XCTest

@testable import DopaBreak

/// 開かなかった画面の目視検証ハーネス。目標1〜5件と節目到達時を PNG へ書き出し、
/// `output/verify/win-screen/` へ保存する。行間・文字の潰れ・溢れは数値だけでは判定できない。
final class WinScreenSnapshotCapture: XCTestCase {
    private static let goalTitles = [
        "ベンチプレス80kg",
        "日常会話を英語で出来るようになる",
        "11月末までに月売上100万",
        "毎朝6時に起きる",
        "週3回ジムに行く"
    ]

    @MainActor
    func testCaptureWinScreenAcrossGoalCountsAndMilestone() throws {
        let directory = Self.outputDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var cases: [(name: String, goals: Int, lifetime: Int, milestone: ReclaimedTimeMilestone?)] = []
        for count in 1...5 {
            cases.append((name: "goals-\(count)", goals: count, lifetime: 8_040, milestone: nil))
        }
        cases.append((name: "milestone-1day", goals: 3, lifetime: 86_400, milestone: .init(thresholdSeconds: 86_400)))
        cases.append((name: "milestone-1hour", goals: 3, lifetime: 3_600, milestone: .init(thresholdSeconds: 3_600)))

        for entry in cases {
            let goals = Self.goalTitles.prefix(entry.goals).map { title in
                Goal(
                    id: UUID(),
                    title: title,
                    lockScreenTitle: nil,
                    category: .other,
                    displayImagePath: nil,
                    createdAt: Date(timeIntervalSince1970: 0),
                    updatedAt: Date(timeIntervalSince1970: 0)
                )
            }
            let content = WinScreenContent(
                reclaimedSeconds: 480,
                lifetimeReclaimedSeconds: entry.lifetime,
                todayCancelledCount: 3,
                estimatedMinutesPerCancellation: 8,
                goals: Array(goals),
                milestone: entry.milestone
            )
            .frame(width: 393, height: 720, alignment: .top)
            .background(DesignTokens.background)
            .environment(\.colorScheme, .dark)

            let renderer = ImageRenderer(content: content)
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage, "\(entry.name) を描画できなかった")
            let data = try XCTUnwrap(image.pngData(), "\(entry.name) をPNG化できなかった")
            try data.write(to: directory.appendingPathComponent("win-\(entry.name).png"))
        }
    }

    private static var outputDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("output/verify/win-screen", isDirectory: true)
    }
}
