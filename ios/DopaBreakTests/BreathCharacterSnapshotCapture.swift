import SwiftUI
import UIKit
import XCTest

@testable import DopaBreak

/// 呼吸同期キャラクターをテストホストの実ウィンドウで目視検証するハーネス。
/// `BREATH_STAGE_BEGIN <name>` を待ち、外部から `simctl io screenshot` で撮影する。
final class BreathCharacterSnapshotCapture: XCTestCase {
    private static let secondsPerStage: TimeInterval = 10
    private static let totalSeconds = 8

    @MainActor
    func testHoldBreathCharacterStagesOnScreen() throws {
        let timeline = BreathCharacterTimeline(totalSeconds: Self.totalSeconds)
        let inhaleEnd = timeline.cycleDuration / 2
        let stages: [(name: String, loop: Range<TimeInterval>)] = [
            ("01-inhale", 0.20..<(inhaleEnd - 0.10)),
            ("02-exhale", (inhaleEnd + 0.10)..<(timeline.reliefStart - 0.10)),
            ("03-relief", (timeline.reliefStart + 0.05)..<(timeline.totalDuration - 0.05))
        ]

        let window = try XCTUnwrap(activeKeyWindow(), "テストホストのキーウィンドウが取得できない")
        let originalRoot = window.rootViewController
        defer { window.rootViewController = originalRoot }

        for stage in stages {
            let root = ZStack {
                DesignTokens.background.ignoresSafeArea()
                BreathingCharacterView(
                    totalSeconds: Self.totalSeconds,
                    previewLoop: stage.loop
                )
                .frame(maxWidth: 380)
                .frame(height: 380)
            }
            .preferredColorScheme(.dark)

            let host = UIHostingController(rootView: root)
            host.overrideUserInterfaceStyle = .dark
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()

            // 先頭フレームを実ウィンドウへ反映してから外部キャプチャへ合図する。
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.4))
            print("BREATH_STAGE_BEGIN \(stage.name)")
            fflush(stdout)

            let deadline = Date().addingTimeInterval(Self.secondsPerStage)
            while Date() < deadline {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
            }
            print("BREATH_STAGE_END \(stage.name)")
            fflush(stdout)
        }
    }

    @MainActor
    private func activeKeyWindow() -> UIWindow? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return keyWindow
            }
            if let firstWindow = windowScene.windows.first {
                return firstWindow
            }
        }
        return nil
    }
}
