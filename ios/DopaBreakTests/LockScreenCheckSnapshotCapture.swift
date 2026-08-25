import DopaBreakCore
import SwiftUI
import UIKit
import XCTest

@testable import DopaBreak

/// ロック画面確認画面を目視検証するためのハーネス。
/// 各状態を iPhone 相当のサイズで PNG に書き出し、`output/screenshots/lock-check/` へ保存する。
/// レイアウト崩れ（サイドボタンマーカー・手順2カード・プレビュー）の確認に使う。
final class LockScreenCheckSnapshotCapture: XCTestCase {
    @MainActor
    func testCaptureLockScreenCheckPhases() throws {
        let model = AppModel()
        let goalID = UUID()
        let didAddGoal = model.addGoal(
            title: "英語で商談できる自分になる",
            category: .other,
            lockScreenTitle: "英語で話す",
            id: goalID
        )
        defer {
            if didAddGoal {
                model.deleteGoal(id: goalID)
            }
        }

        let directory = Self.outputDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let phases: [(name: String, phase: LockScreenCheckPhase)] = [
            ("01-waiting", .waiting),
            ("02-confirmed", .confirmed),
            ("03-blocked", .blocked(.systemDisabled)),
            ("04-failed", .blocked(.failed))
        ]

        for entry in phases {
            // ImageRenderer は ScrollView の中身を描かないため、実画面と同じ余白を持つ
            // VStack へ直接置いて描画する。
            let content = LockScreenCheckSnapshotHost(model: model, phase: entry.phase)
                .frame(width: 393, height: 852, alignment: .top)
                .environment(\.colorScheme, .dark)

            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage, "\(entry.name) を描画できなかった")
            let data = try XCTUnwrap(image.pngData(), "\(entry.name) をPNG化できなかった")
            try data.write(to: directory.appendingPathComponent("lock-check-\(entry.name).png"))
        }
    }

    private static var outputDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("output/screenshots/lock-check", isDirectory: true)
    }
}

private struct LockScreenCheckSnapshotHost: View {
    let model: AppModel
    let phase: LockScreenCheckPhase

    @State private var markerBlockBottomY: CGFloat = (0.2924 + 0.1255) * 852

    private let iPhone15Geometry = DeviceSideButtonGeometry(
        top: 0.2924 * 852,
        length: 0.1255 * 852,
        hasCameraControl: false
    )

    var body: some View {
        ZStack(alignment: .top) {
            DesignTokens.background
            LockScreenCheckContent(
                model: model,
                phase: .constant(phase),
                markerBlockBottomY: markerBlockBottomY,
                scrollContainerTopY: 0,
                contentTopPadding: 36
            )
                .padding(.horizontal, 20)
                .padding(.top, 36)
                .transaction { $0.disablesAnimations = true }

            if phase == .waiting {
                SideButtonEdgeMarker(geometry: iPhone15Geometry, headerBottomY: 0)
                    .transaction { $0.disablesAnimations = true }
            }
        }
        .onPreferenceChange(SideButtonMarkerBottomPreferenceKey.self) {
            if $0 > 0 {
                markerBlockBottomY = $0
            }
        }
    }
}
