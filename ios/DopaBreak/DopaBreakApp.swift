import DopaBreakCore
import Observation
import StoreKit
import SwiftUI
import UIKit
import UserNotifications

enum DopaBreakOpenURLHandler {
    static func handle(
        _ url: URL,
        consumeInterventionRequest: (String) -> Void
    ) -> Bool {
        guard url.scheme == "dopabreak", url.host == "intervene" else {
            return false
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let catalogID = components.queryItems?.first(where: { $0.name == "app" })?.value else {
            return false
        }
        guard SNSAppCatalog.contains(catalogID: catalogID) else {
            return false
        }

        consumeInterventionRequest(catalogID)
        return true
    }
}

enum AppLaunchPolicy {
    static func enablesStartupSideEffects(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["XCTestConfigurationFilePath"] == nil
    }
}

@main
struct DopaBreakApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: AppModel
    @State private var onboarding = OnboardingCoordinator()
    @StateObject private var launchSplash = LaunchSplashCoordinator()
    @StateObject private var quickActions = QuickActionCenter.shared
    private let notificationDelegate: NotificationDelegate

    init() {
        DopaBreakFontRegistrar.registerBundledFonts(
            resourceBundleURL: Bundle.main.bundleURL
        )
        let enablesStartupSideEffects = AppLaunchPolicy.enablesStartupSideEffects()
        let model = AppModel(
            automaticallyRefreshEntitlement: enablesStartupSideEffects,
            scheduleNotificationsOnInit: enablesStartupSideEffects
        )
        _model = State(
            initialValue: model
        )
        let settingsStore = (try? SettingsStore()) ?? SettingsStore(userDefaults: .standard)
        let notificationDelegate = NotificationDelegate(
            settingsStore: settingsStore,
            onGateUnlockRequest: { [weak model] in
                model?.consumePendingGateUnlock()
            }
        )
        self.notificationDelegate = notificationDelegate
        UNUserNotificationCenter.current().delegate = notificationDelegate
        DopaNavigationBar.apply()
    }

    var body: some Scene {
        WindowGroup {
            LaunchSplashHost(coordinator: launchSplash) {
                AppLifecycleView(onAppActive: handleAppActive) {
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
                }
            }
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                guard handleOpenURL(url) else {
                    return
                }
                withAnimation(LaunchSplashConfiguration.crossfadeAnimation) {
                    launchSplash.complete(.deepLink)
                }
            }
            // コールドスタートでは押下がViewの生成より先に届くため、ここでも拾う。
            .task {
                updateQuickActions()
                consumePendingQuickAction()
            }
            .onChange(of: quickActions.pendingAction) { _, _ in
                consumePendingQuickAction()
            }
            .onChange(of: onboarding.isCompleted) { _, _ in
                updateQuickActions()
            }
            // 設定で対象アプリを全部外した直後に、着地先の無い介入枠を残さない。
            .onChange(of: model.hasInterventionTargets) { _, _ in
                updateQuickActions()
            }
            .onChange(of: model.storeService.isPro) { _, _ in
                updateQuickActions()
            }
            .onChange(of: model.storeService.hasConfirmedEntitlement) { _, _ in
                updateQuickActions()
            }
            .onChange(of: model.storeService.entitlementRevision) { _, _ in
                updateQuickActions()
            }
        }
    }

    /// 権利・オンボーディング状態・対象アプリの有無に合わせてクイックアクションを登録し直す。
    /// 課金状態と対象アプリが変わるたびに通す唯一の入口。
    private func updateQuickActions() {
        quickActions.updateShortcutItems(
            isOnboardingCompleted: onboarding.isCompleted,
            hasInterventionTargets: model.hasInterventionTargets,
            isPro: model.storeService.isPro,
            hasConfirmedEntitlement: model.storeService.hasConfirmedEntitlement
        )
    }

    /// ホーム画面クイックアクション（アイコン長押し）の押下を着地先へ送る。
    ///
    /// オンボーディング中でもサポート枠は押せるため、消費はRootTabViewではなくここに置く。
    /// RootTabViewに置くと、オンボーディング中の押下を誰も拾えず無反応になる。
    private func consumePendingQuickAction() {
        guard let action = quickActions.consumePendingAction() else {
            return
        }
        // 着地先へ即座に送るため起動演出は畳む。
        withAnimation(LaunchSplashConfiguration.crossfadeAnimation) {
            launchSplash.complete(.quickAction)
        }

        switch action {
        case .intervene:
            startInterventionFromQuickAction()
        case .offer:
            presentOfferCodeRedeemSheet()
        case .support:
            openFeedbackEmail()
        }
    }

    /// コア機能の枠。選んである対象アプリの1つ目で介入フローを開く。
    ///
    /// 渡す先はオートメーション検収を進める `consumeInterventionRequest` ではない。
    /// 長押しからの起動は対象アプリを開いた事実ではないため、検収済みマークを付けてはいけない。
    /// 実際の提示はRootTabViewが `pendingInterventionCatalogID` の変化を見て行う。
    /// 対象アプリが0件のときはそもそも枠を登録しない（`QuickActionPolicy.types`）。
    /// ここのguardは、登録直後に対象が消えた場合の受け皿として残す。
    private func startInterventionFromQuickAction() {
        guard onboarding.isCompleted,
              let catalogID = (try? model.targetStore.selectedCatalogIDs())?.first else {
            return
        }
        model.requestStartIntervention(catalogID: catalogID)
    }

    /// 引き止めオファーの枠。Apple の Offer Code 引き換えシートだけを開く。
    /// 外部リンク・別決済への誘導は審査3.1.1違反になるため実装しない。
    private func presentOfferCodeRedeemSheet() {
        guard QuickActionsConfiguration.offerSlotEnabled else {
            return
        }
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let windowScene = windowScenes.first(where: { $0.activationState == .foregroundActive })
            ?? windowScenes.first else {
            return
        }
        Task {
            do {
                try await AppStore.presentOfferCodeRedeemSheet(in: windowScene)
            } catch {
                model.alertMessage = String(
                    localized: "quick_action.offer.error.unavailable",
                    defaultValue: "オファーの画面を開けませんでした"
                )
            }
        }
    }

    /// サポートの枠。設定と同じ問い合わせ導線（mailto）へ送る。
    private func openFeedbackEmail() {
        let appShortVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.0"
        guard let url = AppURLs.feedbackEmail(appVersion: appShortVersion) else {
            return
        }
        UIApplication.shared.open(url)
    }

    /// `dopabreak://intervene?app=<catalogID>` を受け付ける（doc12 §2 URLルーティング・フォールバック経路）。
    private func handleOpenURL(_ url: URL) -> Bool {
        DopaBreakOpenURLHandler.handle(url) { catalogID in
            model.consumeInterventionRequest(
                catalogID: catalogID,
                settingsStore: onboarding.settingsStore
            )
        }
    }

    /// AppIntent（別プロセス実行）が SettingsStore 経由で残した起動要求を取り込む。
    private func consumePendingInterventionRequest() {
        model.consumePendingInterventionRequest(from: onboarding.settingsStore)
    }

    private func handleAppActive() {
        model.recordAppOpenedIfNeeded()
        model.reconcileGateGrantsOnForeground()
        // openParentalControlsAppは通知タップを伴わないため、activeのたびにも要求を拾う。
        model.consumePendingGateUnlock()
        consumePendingInterventionRequest()
        updateQuickActions()
        consumePendingQuickAction()
    }
}

struct AppLifecycleView<Content: View>: View {
    private let onAppActive: () -> Void
    private let content: Content
    @Environment(\.scenePhase) private var scenePhase

    init(
        onAppActive: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.onAppActive = onAppActive
        self.content = content()
    }

    var body: some View {
        content
            .onAppear(perform: onAppActive)
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                onAppActive()
            }
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
        if resolvedStore.onboardingCompleted,
           resolvedStore.onboardingCompletedAt == nil {
            resolvedStore.onboardingCompletedAt = Date()
        }
        self.isCompleted = resolvedStore.onboardingCompleted
    }

    func complete() {
        settingsStore.onboardingCompleted = true
        settingsStore.onboardingCompletedAt = Date()
        settingsStore.onboardingSavedGoalID = nil
        isCompleted = true
    }

    func reset() {
        settingsStore.onboardingCompleted = false
        settingsStore.onboardingCompletedAt = nil
        isCompleted = false
    }

    nonisolated private static func makeSettingsStore() -> SettingsStore {
        (try? SettingsStore()) ?? SettingsStore(userDefaults: .standard)
    }
}
