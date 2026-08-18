import UIKit

/// ホーム画面クイックアクションを受け取るためのアプリデリゲート。
///
/// SwiftUIのAppライフサイクルには押下を受け取る口が無いため、`@UIApplicationDelegateAdaptor` で挟む。
/// 受け口はコールドスタートと復帰で別々にあるため、次の3経路すべてを実装する。
///   1. `application(_:didFinishLaunchingWithOptions:)` … シーン非対応時のコールドスタート
///   2. `scene(_:willConnectTo:options:)` … シーン対応時のコールドスタート
///   3. `windowScene(_:performActionFor:completionHandler:)` … 起動済みの状態で押されたとき
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            QuickActionCenter.shared.enqueue(shortcutItem)
        }
        return true
    }

    /// 起動済みの状態での押下（シーン非対応時の経路）。
    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(QuickActionCenter.shared.enqueue(shortcutItem))
    }

    /// シーンデリゲートを差し込む。ウインドウの生成はSwiftUIのWindowGroupが行う。
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: connectingSceneSession.configuration.name,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = QuickActionSceneDelegate.self
        return configuration
    }
}

/// クイックアクションだけを担当するシーンデリゲート。
///
/// ウインドウの生成はSwiftUI側が行うため、ここでは `window` を触らない。
@MainActor
final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let shortcutItem = connectionOptions.shortcutItem else {
            return
        }
        QuickActionCenter.shared.enqueue(shortcutItem)
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(QuickActionCenter.shared.enqueue(shortcutItem))
    }
}
