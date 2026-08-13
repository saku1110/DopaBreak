import DopaBreakCore
import SwiftUI
import UIKit
import XCTest

@testable import DopaBreak

/// ネイティブ化したナビゲーション周り（システム大見出し・スクロール端の素材・Dynamic Type）を
/// 目視検証するためのハーネス。
///
/// `ImageRenderer` はナビゲーションバーやScrollViewの中身を描かないため、
/// テストホストの実ウィンドウへ載せてから `drawHierarchy` で実描画を取り込む。
/// 出力は `output/screenshots/native-pass/` に置く。
final class NativeChromeSnapshotCapture: XCTestCase {
    /// 既定サイズと、レイアウトが最も壊れやすいアクセシビリティサイズの2点で撮る。
    private static let typeSizes: [(name: String, size: DynamicTypeSize)] = [
        ("default", .large),
        ("ax3", .accessibility3)
    ]

    @MainActor
    func testCaptureNativeChrome() throws {
        let model = AppModel()
        let settingsStore = (try? SettingsStore()) ?? SettingsStore(userDefaults: .standard)

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

        let window = try XCTUnwrap(activeKeyWindow(), "テストホストのキーウィンドウが取得できない")
        let originalRoot = window.rootViewController
        defer { window.rootViewController = originalRoot }

        for typeSize in Self.typeSizes {
            let screens: [(name: String, view: AnyView)] = [
                ("goals", AnyView(GoalsView(model: model))),
                ("stats", AnyView(StatsView(model: model))),
                (
                    "settings",
                    AnyView(
                        SettingsView(
                            model: model,
                            settingsStore: settingsStore,
                            onResetOnboarding: {}
                        )
                    )
                )
            ]

            for screen in screens {
                let root = screen.view
                    .environment(\.dynamicTypeSize, typeSize.size)
                    .preferredColorScheme(.dark)

                let host = UIHostingController(rootView: root)
                host.overrideUserInterfaceStyle = .dark
                window.rootViewController = host
                window.makeKeyAndVisible()
                host.view.setNeedsLayout()
                host.view.layoutIfNeeded()

                // ナビゲーションバーの素材とレイアウトが確定するまで数フレーム回す。
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.6))

                let image = Self.render(window: window)
                let data = try XCTUnwrap(image.pngData(), "\(screen.name) をPNG化できなかった")
                let filename = "chrome-\(screen.name)-\(typeSize.name).png"
                try data.write(to: directory.appendingPathComponent(filename))
            }
        }
    }

    /// 実ウィンドウの描画結果をそのまま取り込む。ナビゲーションバーの素材も含まれる。
    @MainActor
    private static func render(window: UIWindow) -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
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

    private static var outputDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("output/screenshots/native-pass", isDirectory: true)
    }
}
