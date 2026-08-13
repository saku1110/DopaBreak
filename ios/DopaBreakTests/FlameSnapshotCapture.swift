import SwiftUI
import UIKit
import XCTest

@testable import DopaBreak

/// 一呼吸の炎レンダリングを目視検証するためのハーネス。
/// Metalシェーダ（`.colorEffect`）はシーン未接続のオフスクリーンウィンドウでは描画されないため、
/// テストホストアプリの実ウィンドウへ炎を載せ、各段階を一定時間表示し続ける。
/// 表示中に外部から `xcrun simctl io <UDID> screenshot` を撮ることで実描画を確認する。
final class FlameSnapshotCapture: XCTestCase {
    private static let secondsPerStage: TimeInterval = 10

    @MainActor
    func testHoldFlameStagesOnScreen() throws {
        let stages: [(name: String, breath: Double, flare: Double)] = [
            ("01-exhale-min", 0.05, 0.0),
            ("02-inhale-max", 1.00, 0.0),
            ("03-flare-peak", 1.00, 1.0)
        ]

        let window = try XCTUnwrap(activeKeyWindow(), "テストホストのキーウィンドウが取得できない")
        let originalRoot = window.rootViewController

        for stage in stages {
            // 実装と同じ 380×380 の炎を、根本（下端）が画面内に収まる位置へ寄せて表示する。
            let root = ZStack(alignment: .bottom) {
                Color(red: 10.0 / 255.0, green: 11.0 / 255.0, blue: 13.0 / 255.0)
                    .ignoresSafeArea()
                FlameBreathView(breathPhase: stage.breath, flare: stage.flare)
                    .frame(width: 380, height: 380)
                    .padding(.bottom, 60)
            }

            let host = UIHostingController(rootView: root)
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()

            let deadline = Date().addingTimeInterval(Self.secondsPerStage)
            // 先頭フレームが描画されてからマーカーを出し、外部キャプチャと同期させる。
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.4))
            print("FLAME_STAGE_BEGIN \(stage.name)")
            fflush(stdout)

            while Date() < deadline {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
            }
            print("FLAME_STAGE_END \(stage.name)")
            fflush(stdout)
        }

        window.rootViewController = originalRoot
    }

    @MainActor
    private func activeKeyWindow() -> UIWindow? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            if let key = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return key
            }
            if let first = windowScene.windows.first {
                return first
            }
        }
        return nil
    }
}
