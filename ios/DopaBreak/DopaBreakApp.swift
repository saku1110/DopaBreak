import DopaBreakCore
import Observation
import SwiftUI
import UserNotifications

@main
struct DopaBreakApp: App {
    @State private var model = AppModel()
    @State private var onboarding = OnboardingCoordinator()
    private let notificationDelegate: NotificationDelegate

    init() {
        let settingsStore = (try? SettingsStore()) ?? SettingsStore(userDefaults: .standard)
        let notificationDelegate = NotificationDelegate(settingsStore: settingsStore)
        self.notificationDelegate = notificationDelegate
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboarding.isCompleted {
                    RootTabView(
                        model: model,
                        settingsStore: onboarding.settingsStore,
                        onResetOnboarding: {
                            onboarding.reset()
                        }
                    )
                } else {
                    OnboardingFlow(
                        model: model,
                        settingsStore: onboarding.settingsStore,
                        onComplete: {
                            onboarding.complete()
                            model.recordFunnelEvent(.onboardingCompleted)
                            model.refresh()
                        }
                    )
                }
            }
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    handleOpenURL(url)
                }
                .onAppear {
                    consumePendingInterventionRequest()
                }
        }
    }

    /// `dopabreak://intervene?app=<catalogID>` を受け付ける（doc12 §2 URLルーティング・フォールバック経路）。
    private func handleOpenURL(_ url: URL) {
        guard url.scheme == "dopabreak", url.host == "intervene" else {
            return
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let catalogID = components.queryItems?.first(where: { $0.name == "app" })?.value else {
            return
        }
        guard SNSAppCatalog.contains(catalogID: catalogID) else {
            return
        }
        model.consumeInterventionRequest(
            catalogID: catalogID,
            settingsStore: onboarding.settingsStore
        )
    }

    /// AppIntent（別プロセス実行）が SettingsStore 経由で残した起動要求を取り込む。
    private func consumePendingInterventionRequest() {
        model.consumePendingInterventionRequest(from: onboarding.settingsStore)
    }
}

@MainActor
@Observable
final class OnboardingCoordinator {
    let settingsStore: SettingsStore
    private(set) var isCompleted: Bool

    init(settingsStore: SettingsStore? = nil) {
        let resolvedStore = settingsStore ?? Self.makeSettingsStore()
        self.settingsStore = resolvedStore
        self.isCompleted = resolvedStore.onboardingCompleted
    }

    func complete() {
        settingsStore.onboardingCompleted = true
        isCompleted = true
    }

    func reset() {
        settingsStore.onboardingCompleted = false
        isCompleted = false
    }

    nonisolated private static func makeSettingsStore() -> SettingsStore {
        (try? SettingsStore()) ?? SettingsStore(userDefaults: .standard)
    }
}
