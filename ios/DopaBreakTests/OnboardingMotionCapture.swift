import DopaBreakCore
import SwiftUI
import UIKit
import XCTest

@testable import DopaBreak

/// オンボーディングのモーションを実画面のまま目視確認するためのハーネス。
///
/// `axe`/`idb` が無い環境ではタップで画面を進められないため、`OnboardingFlow` を
/// 任意の `initialStep` でテストホストの実ウィンドウへマウントし、一定時間保持する。
/// Metalシェーダ（`.colorEffect`）はオフスクリーンで描画されないため、この方式が必要。
///
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

        // 着火演出は「次へ」タップでしか発火しないため、ループ再生ホストで単体保持する
        let ignitionHost = UIHostingController(rootView: IgnitionLoopHost())
        window.rootViewController = ignitionHost
        window.makeKeyAndVisible()
        ignitionHost.view.setNeedsLayout()
        ignitionHost.view.layoutIfNeeded()
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.5))
        print("ONB_STAGE_BEGIN 06-ignition")
        fflush(stdout)
        let ignitionDeadline = Date().addingTimeInterval(Self.secondsPerStage)
        while Date() < ignitionDeadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        print("ONB_STAGE_END 06-ignition")
        fflush(stdout)
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

/// 着火演出を繰り返し再生するキャプチャ専用ホスト。
/// `GoalIgnitionFlame`は出現時に一度だけ走るため、1.6秒ごとに再マウントしてループさせる。
private struct IgnitionLoopHost: View {
    @State private var tick = 0
    private let timer = Timer.publish(every: 1.6, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            DesignTokens.background.ignoresSafeArea()
            GoalIgnitionFlame()
                .ignoresSafeArea()
                .id(tick)
        }
        .onReceive(timer) { _ in
            tick += 1
        }
    }
}
