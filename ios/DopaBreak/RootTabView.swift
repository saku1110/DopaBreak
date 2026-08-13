import Combine
import DopaBreakCore
import Foundation
import SwiftUI

enum AppTab: Hashable {
    case home
    case goals
    case stats
    case settings
}

struct RootTabView: View {
    let model: AppModel
    let settingsStore: SettingsStore
    let onResetOnboarding: () -> Void
    @State private var selectedTab: AppTab = .home
    @State private var pendingReflection: ReflectionLog?
    @State private var pendingMidSessionCheckInTarget: SNSAppCatalogItem?
    @State private var pendingPaywallPlacement: PaywallPlacement?
    @State private var presentedInterventionCatalogID: String?
    @State private var isLockScreenCheckPresented = false
    @State private var interventionAwaitingLockDismiss = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(model: model, settingsStore: settingsStore)
                .tag(AppTab.home)
                .tabItem {
                    Label(String(localized: "root_tab.home", defaultValue: "ホーム"), systemImage: "house")
                }

            GoalsView(model: model)
                .tag(AppTab.goals)
                .tabItem {
                    Label(String(localized: "root_tab.goals", defaultValue: "目標"), systemImage: "flag")
                }

            StatsView(model: model)
                .tag(AppTab.stats)
                .tabItem {
                    Label(String(localized: "root_tab.stats", defaultValue: "統計"), systemImage: "chart.bar")
                }

            SettingsView(
                model: model,
                settingsStore: settingsStore,
                onResetOnboarding: onResetOnboarding
            )
                .tag(AppTab.settings)
                .tabItem {
                    Label(String(localized: "root_tab.settings", defaultValue: "設定"), systemImage: "gearshape")
                }
        }
        // 自前のタブバーをやめ、システムのタブバーへ戻した。
        // iOS 26 SDKでビルドするとLiquid Glassの素材・スクロール追従・選択インジケータが自動で載る。
        // 選択色はアクセントで引き続きブランドを担保する。
        .tint(DesignTokens.accent)
        .alert(String(localized: "root_alert.error.title", defaultValue: "エラー"), isPresented: alertPresented) {
            Button(String(localized: "root_alert.action.close", defaultValue: "閉じる")) {
                model.alertMessage = nil
            }
        } message: {
            Text(model.alertMessage ?? "")
        }
        .onAppear {
            handleAppActive()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            handleAppActive()
        }
        .onChange(of: model.storeService.isPro) { _, _ in
            model.refresh()
            presentPendingInterventionIfValid(model.pendingInterventionCatalogID)
            checkPendingPaywalls()
        }
        .onChange(of: model.storeService.hasResolvedEntitlement) { _, _ in
            model.refresh()
            presentPendingInterventionIfValid(model.pendingInterventionCatalogID)
            checkPendingPaywalls()
        }
        .onChange(of: model.storeService.entitlementRevision) { _, _ in
            model.syncUsageWatchEntitlement()
            model.refresh()
            presentPendingInterventionIfValid(model.pendingInterventionCatalogID)
            checkPendingPaywalls()
        }
        .onChange(of: model.isChildModalActive) { _, isActive in
            guard !isActive else { return }
            checkPendingLockScreenCheck()
            checkPendingPaywalls()
        }
        .onChange(of: model.pendingLockScreenCheck) { _, _ in
            checkPendingLockScreenCheck()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            model.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pendingMidSessionCheckInDidChange)) { _ in
            checkPendingMidSessionCheckIn()
        }
        .onReceive(NotificationCenter.default.publisher(for: .notificationDestinationDidChange)) { _ in
            consumePendingNotificationDestination()
        }
        .onChange(of: model.pendingInterventionCatalogID) { _, catalogID in
            presentPendingInterventionIfValid(catalogID)
        }
        .fullScreenCover(isPresented: interventionPresented, onDismiss: {
            consumePendingNotificationDestination()
            checkPendingMidSessionCheckIn()
            checkPendingReflection()
            checkPendingLockScreenCheck()
            checkPendingPaywalls()
        }) {
            if let catalogID = presentedInterventionCatalogID,
               let target = SNSAppCatalog.app(catalogID: catalogID) {
                InterventionFlowView(
                    target: target,
                    model: model,
                    settingsStore: settingsStore,
                    onFinished: {
                        model.pendingInterventionCatalogID = nil
                        presentedInterventionCatalogID = nil
                        model.refresh()
                    }
                )
            }
        }
        .sheet(item: $pendingReflection, onDismiss: {
            checkPendingMidSessionCheckIn()
            checkPendingLockScreenCheck()
            checkPendingPaywalls()
        }) { reflection in
            if let engine = model.interventionEngine {
                PostUseReflectionSheet(model: model, engine: engine, reflection: reflection) {
                    pendingReflection = nil
                    model.refresh()
                }
            }
        }
        .sheet(item: $pendingMidSessionCheckInTarget, onDismiss: {
            checkPendingReflection()
            checkPendingLockScreenCheck()
            checkPendingPaywalls()
        }) { _ in
            MidSessionCheckInSheet(model: model)
        }
        .fullScreenCover(isPresented: $isLockScreenCheckPresented, onDismiss: {
            interventionAwaitingLockDismiss = false
            consumePendingNotificationDestination()
            presentPendingInterventionIfValid(model.pendingInterventionCatalogID)
            checkPendingMidSessionCheckIn()
            checkPendingReflection()
            checkPendingPaywalls()
        }) {
            LockScreenCheckSheet(model: model) {
                isLockScreenCheckPresented = false
            }
        }
        .fullScreenCover(item: $pendingPaywallPlacement, onDismiss: {
            consumePendingNotificationDestination()
            checkPendingPaywalls()
        }) { placement in
            PaywallView(
                storeService: model.storeService,
                placement: placement,
                settingsStore: settingsStore
            )
        }
    }

    private var alertPresented: Binding<Bool> {
        Binding(
            get: { model.alertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    model.alertMessage = nil
                }
            }
        )
    }

    private var interventionPresented: Binding<Bool> {
        Binding(
            get: { presentedInterventionCatalogID != nil },
            set: { isPresented in
                if !isPresented {
                    model.pendingInterventionCatalogID = nil
                    presentedInterventionCatalogID = nil
                }
            }
        )
    }

    private func checkPendingIntervention() {
        model.consumePendingInterventionRequest(from: settingsStore)
    }

    private func handleAppActive() {
        model.refresh(restartLiveActivity: true)
        // 自動更新オフはiOS設定側で起きるためTransactionが流れない。
        // 復帰のたびに取り直さないと、プロセスが生きている限り解約を検知できない（docs/18 §4）。
        model.refreshEntitlementOnForeground()
        consumePendingNotificationDestination()
        checkPendingIntervention()
        presentPendingInterventionIfValid(model.pendingInterventionCatalogID)
        checkPendingMidSessionCheckIn()
        checkPendingReflection()
        checkPendingLockScreenCheck()
        checkPendingPaywalls()
    }

    /// 通知タップの着地先を消費する（docs/18 §2f）。
    /// 介入フローが最優先のため、出ている間は保存したまま据え置き、閉じたときに改めて消費する。
    /// コールドスタート（通知タップでの起動）では delegate の書き込みが onAppear より後に届くため、
    /// `.notificationDestinationDidChange` からも呼ぶ。
    private func consumePendingNotificationDestination() {
        guard let pending = settingsStore.pendingNotificationDestination else {
            return
        }
        // オンボーディング途中で通知をタップすると誰も消費できないまま残る。
        // 古くなったものはここで捨て、後日オンボーディングを終えた瞬間に飛ばされないようにする。
        guard pending.isValid(at: Date()) else {
            settingsStore.pendingNotificationDestination = nil
            return
        }
        // 他の全画面提示が出ている間は据え置き、閉じたときのonDismissから改めて消費する。
        // 先に消してしまうと、生きているcoverの下でシートを立てようとして着地先を落とす。
        guard model.pendingInterventionCatalogID == nil,
              presentedInterventionCatalogID == nil,
              pendingPaywallPlacement == nil,
              !isLockScreenCheckPresented else {
            return
        }

        settingsStore.pendingNotificationDestination = nil
        switch pending.destination {
        case .stats:
            selectedTab = .stats
        case .planSettings:
            // ペイウォールは自動提示しない。設定のプラン周りまで連れて行くところまで。
            selectedTab = .settings
            model.pendingPlanSettingsFocus = true
        case .automationGuide:
            selectedTab = .settings
            model.pendingAutomationGuideRequest = true
        }
    }

    /// オンボーディング後に最初の目標を追加したら、ロック画面での確認導線を出す。
    /// Live Activityを有効にしている場合だけ、他のモーダルと競合しないタイミングで提示する。
    private func checkPendingLockScreenCheck() {
        guard settingsStore.onboardingCompleted,
              settingsStore.liveActivityEnabled,
              model.pendingLockScreenCheck,
              !isLockScreenCheckPresented,
              model.pendingInterventionCatalogID == nil,
              presentedInterventionCatalogID == nil,
              pendingMidSessionCheckInTarget == nil,
              pendingReflection == nil,
              pendingPaywallPlacement == nil,
              !model.isChildModalActive else {
            return
        }

        isLockScreenCheckPresented = true
    }

    private func checkPendingReflection() {
        guard model.pendingInterventionCatalogID == nil,
              pendingMidSessionCheckInTarget == nil,
              pendingReflection == nil,
              !isLockScreenCheckPresented else {
            return
        }
        guard let engine = model.interventionEngine else {
            return
        }
        pendingReflection = try? engine.pendingReflection()
    }

    private func checkPendingMidSessionCheckIn() {
        guard model.pendingInterventionCatalogID == nil,
              pendingReflection == nil,
              pendingMidSessionCheckInTarget == nil,
              !isLockScreenCheckPresented else {
            return
        }
        guard let pending = settingsStore.pendingMidSessionCheckIn else {
            return
        }

        guard pending.isValid(at: Date()) else {
            settingsStore.pendingMidSessionCheckIn = nil
            return
        }

        settingsStore.pendingMidSessionCheckIn = nil
        pendingMidSessionCheckInTarget = SNSAppCatalog.app(catalogID: pending.catalogID)
    }

    private func checkPendingPaywalls() {
        checkPendingWeeklyPaywall()
    }

    private func checkPendingWeeklyPaywall() {
        guard settingsStore.onboardingCompleted,
              model.pendingInterventionCatalogID == nil,
              presentedInterventionCatalogID == nil,
              pendingMidSessionCheckInTarget == nil,
              pendingReflection == nil,
              pendingPaywallPlacement == nil,
              !isLockScreenCheckPresented,
              !model.isChildModalActive,
              WeeklyPaywallPolicy.shouldPresent(
                  isPro: model.storeService.isPro,
                  hasResolvedEntitlement: model.storeService.hasResolvedEntitlement,
                  onboardingCompleted: settingsStore.onboardingCompleted,
                  onboardingCompletedAt: settingsStore.onboardingCompletedAt,
                  lastShownAt: settingsStore.lastWeeklyPaywallShownAt,
                  lastAnyPaywallShownAt: settingsStore.lastAnyPaywallShownAt,
                  now: Date()
              ) else {
            return
        }

        pendingPaywallPlacement = .weekly
    }

    private func presentPendingInterventionIfValid(_ catalogID: String?) {
        guard !interventionAwaitingLockDismiss else {
            return
        }
        guard let catalogID else {
            presentedInterventionCatalogID = nil
            return
        }
        guard model.storeService.hasResolvedEntitlement else {
            return
        }
        guard model.isCurrentInterventionTarget(catalogID: catalogID) else {
            model.pendingInterventionCatalogID = nil
            presentedInterventionCatalogID = nil
            return
        }
        // 対象アプリを開こうとした瞬間の一呼吸が最優先。掲出確認は畳んで譲る。
        if isLockScreenCheckPresented {
            interventionAwaitingLockDismiss = true
            isLockScreenCheckPresented = false
            return
        }
        presentedInterventionCatalogID = catalogID
    }
}

// 旧 DopaTabBar（自前のタブバー）は削除した。
// システムのタブバーはDynamic Type・VoiceOver・選択トレイト・Liquid Glass・
// ホームインジケータとの間隔を標準どおりに扱うため、自前実装より一貫して正しく振る舞う。
