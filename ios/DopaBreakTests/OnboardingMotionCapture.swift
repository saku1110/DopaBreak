import DopaBreakCore
import SwiftUI
import UIKit
import XCTest

@testable import DopaBreak

/// オンボーディングのモーションを実画面のまま目視確認するためのハーネス。
///
/// `axe`/`idb` が無い環境ではタップで画面を進められないため、`OnboardingFlow` を
/// 任意の `initialStep` でテストホストの実ウィンドウへマウントし、一定時間保持する。
/// 保持中に外部から `xcrun simctl io <UDID> screenshot` / `recordVideo` で撮る。
/// マーカー `ONB_STAGE_BEGIN <name>` を待ってから撮ること。時間ベースの待ちはドリフトする。
final class OnboardingMotionCapture: XCTestCase {
    private static let secondsPerStage: TimeInterval = 12

    @MainActor
    func testHoldOnboardingStagesOnScreen() throws {
        let model = AppModel()
        let settingsStore = (try? SettingsStore()) ?? SettingsStore(userDefaults: .standard)

        // 目標入力済みの状態は、保存済み目標からの復元経路で作る（privateなStateへ触らない）。
        // `OnboardingFlow`は入場時に`model.goals`をそのままリストへ戻すため、
        // ステージごとに保存済み目標の有無を作り分ける。
        let goalID = UUID()
        defer { model.deleteGoal(id: goalID) }

        let stages: [(name: String, step: OnboardingStep, withGoal: Bool)] = [
            ("01-goal-empty", .goalSetup, false),
            ("02-goal-filled", .goalSetup, true),
            ("03-quiz-result", .quizResult, false),
            ("04-choose-mode", .chooseMode, false),
            ("05-ready", .ready, true)
        ]

        let window = try XCTUnwrap(activeKeyWindow(), "テストホストのキーウィンドウが取得できない")
        let originalRoot = window.rootViewController
        defer { window.rootViewController = originalRoot }

        for stage in stages {
            if stage.withGoal {
                if !model.goals.contains(where: { $0.id == goalID }) {
                    model.addGoal(
                        title: "英語で話す",
                        category: .other,
                        lockScreenTitle: nil,
                        id: goalID
                    )
                }
            } else {
                model.deleteGoal(id: goalID)
            }

            let root = OnboardingFlow(
                model: model,
                settingsStore: settingsStore,
                initialStep: stage.step,
                onComplete: {}
            )

            let host = UIHostingController(rootView: root)
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()

            // 先頭フレームが描画されてからマーカーを出し、外部キャプチャと同期させる
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.5))
            print("ONB_STAGE_BEGIN \(stage.name)")
            fflush(stdout)

            let deadline = Date().addingTimeInterval(Self.secondsPerStage)
            while Date() < deadline {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
            }
            print("ONB_STAGE_END \(stage.name)")
            fflush(stdout)
        }

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
