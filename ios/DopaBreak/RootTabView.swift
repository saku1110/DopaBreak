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

struct InterventionOverlayPresentationState: Equatable {
    private(set) var target: InterventionTarget?

    init(initialTarget: InterventionTarget? = nil) {
        target = initialTarget
    }

    var flowID: String? {
        target?.presentationID
    }

    mutating func present(_ target: InterventionTarget) {
        self.target = target
    }

    mutating func dismiss() {
        target = nil
    }
}

enum InterventionTargetPresentationPolicy {
    static func validatedTarget(
        _ target: InterventionTarget?,
        now: Date
    ) -> InterventionTarget? {
        guard let target else { return nil }
        if case .catalogPassThrough(_, let until) = target, until <= now {
            return nil
        }
        return target
    }
}

enum ReflectionInterventionPriority {
    static func shouldSuppressPassThrough(
        for pendingDestination: PendingNotificationDestination?,
        now: Date
    ) -> Bool {
        guard let pendingDestination,
              pendingDestination.isValid(at: now),
              case .reflection = pendingDestination.destination else {
            return false
        }
        return true
    }
}

enum ReflectionDeferralPolicy {
    static func shouldRestore(
        pendingReflection: ReflectionLog?,
        deferredReflection: ReflectionLog?
    ) -> Bool {
        guard pendingReflection == nil,
              let deferredReflection else {
            return false
        }
        return deferredReflection.answeredAt == nil && !deferredReflection.skipped
    }
}

enum InterventionModalBlocker: Equatable {
    case lockScreenCheck
    case paywall
    case reflection
    case nonTargetAutomation
}

enum InterventionPresentationDirective: Equatable {
    case present
    case waitForModalDismissal
    case dismissLockScreenCheck
    case dismissPaywall
    case dismissReflection
    case dismissNonTargetAutomation
}

enum InterventionPresentationPolicy {
    static func directive(
        awaitingModalDismissal: InterventionModalBlocker?,
        isLockScreenCheckPresented: Bool,
        isPaywallPresented: Bool,
        isReflectionPresented: Bool,
        isNonTargetAutomationPresented: Bool = false
    ) -> InterventionPresentationDirective {
        if awaitingModalDismissal != nil {
            return .waitForModalDismissal
        }
        if isLockScreenCheckPresented {
            return .dismissLockScreenCheck
        }
        if isPaywallPresented {
            return .dismissPaywall
        }
        if isReflectionPresented {
            return .dismissReflection
        }
        if isNonTargetAutomationPresented {
            return .dismissNonTargetAutomation
        }
        return .present
    }

    static func awaitingModalDismissal(
        for modal: InterventionModalBlocker,
        presentedInterventionModal: InterventionModalBlocker?
    ) -> InterventionModalBlocker? {
        presentedInterventionModal == modal ? modal : nil
    }
}

struct RootTabView: View {
    let model: AppModel
    let settingsStore: SettingsStore
    let onResetOnboarding: () -> Void
    @State private var selectedTab: AppTab = .home
    @State private var goalsAddRequest: UUID?
    @State private var pendingPaywallPlacement: PaywallPlacement?
    @State private var paywallAfterNonTargetAutomation: PaywallPlacement?
    @State private var pendingReflectionLog: ReflectionLog?
    @State private var deferredReflectionLog: ReflectionLog?
    @State private var presentedNonTargetAutomation: NonTargetAutomation?
    @State private var interventionOverlay: InterventionOverlayPresentationState
    @State private var isLockScreenCheckPresented = false
    @State private var interventionAwaitingModalDismiss: InterventionModalBlocker?
    @State private var presentedInterventionModal: InterventionModalBlocker?
    @State private var interventionDismissTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    init(
        model: AppModel,
        settingsStore: SettingsStore,
        onResetOnboarding: @escaping () -> Void
    ) {
        self.model = model
        self.settingsStore = settingsStore
        self.onResetOnboarding = onResetOnboarding
        let pendingTarget = model.isInterventionSuppressedByHardBlock ? nil : model.pendingInterventionTarget
        let initialTarget = InterventionTargetPresentationPolicy.validatedTarget(
            pendingTarget,
            now: model.currentDate
        )
        _interventionOverlay = State(
            initialValue: InterventionOverlayPresentationState(
                initialTarget: initialTarget
            )
        )
        _pendingReflectionLog = State(initialValue: nil)
        _deferredReflectionLog = State(initialValue: nil)
        _interventionAwaitingModalDismiss = State(initialValue: nil)
        _presentedInterventionModal = State(initialValue: nil)
        _interventionDismissTask = State(initialValue: nil)
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView(
                    model: model,
                    settingsStore: settingsStore,
                    onOpenStats: { selectedTab = .stats },
                    onOpenGoals: { addRequested in
                        selectedTab = .goals
                        if addRequested {
                            goalsAddRequest = UUID()
                        }
                    },
                    onOpenBlockSettings: {
                        selectedTab = .settings
                        model.pendingDeepFocusSettingsFocus = true
                    }
                )
                    .tag(AppTab.home)
                    .tabItem {
                        Label(String(localized: "root_tab.home", defaultValue: "ホーム"), systemImage: "house")
                    }

                GoalsView(model: model, addRequest: $goalsAddRequest)
                    .tag(AppTab.goals)
                    .tabItem {
                        Label(String(localized: "root_tab.goals", defaultValue: "目標"), systemImage: "flag")
                    }

                StatsView(model: model, onOpenBlockSettings: {
                    selectedTab = .settings
                    model.pendingDeepFocusSettingsFocus = true
                })
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
            .allowsHitTesting(!isInterventionOverlayVisible)
            .accessibilityHidden(isInterventionOverlayVisible)

            if let target = interventionOverlay.target,
               let flowID = interventionOverlay.flowID {
                InterventionFlowView(
                    target: target,
                    model: model,
                    settingsStore: settingsStore,
                    onFinished: dismissInterventionOverlay
                )
                .id(flowID)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignTokens.background.ignoresSafeArea())
                .transition(.opacity)
                .zIndex(1)
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
        .onDisappear {
            model.isInterventionOverlayPresented = false
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                handleAppActive()
            case .background:
                break
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .onChange(of: model.storeService.isPro) { _, isPro in
            model.applyPendingProThemeSelectionIfNeeded(hasProEntitlement: isPro)
            model.applyPurchaseContinuationIfNeeded()
            model.refresh()
            presentPendingInterventionIfValid(model.pendingInterventionTarget)
            checkPendingPaywalls()
        }
        .onChange(of: model.storeService.hasResolvedEntitlement) { _, _ in
            model.refresh()
            presentPendingInterventionIfValid(model.pendingInterventionTarget)
            checkPendingPaywalls()
        }
        .onChange(of: model.storeService.entitlementRevision) { _, _ in
            model.applyPendingProThemeSelectionIfNeeded(
                hasProEntitlement: model.storeService.isPro
            )
            model.applyPurchaseContinuationIfNeeded()
            model.refresh()
            presentPendingInterventionIfValid(model.pendingInterventionTarget)
            checkPendingPaywalls()
        }
        .onChange(of: model.isChildModalActive) { _, isActive in
            guard !isActive else { return }
            checkPendingLockScreenCheck()
            checkPendingPaywalls()
            checkPendingReflection()
            checkPendingNonTargetAutomation()
        }
        .onChange(of: model.pendingLockScreenCheck) { _, _ in
            checkPendingLockScreenCheck()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            model.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .notificationDestinationDidChange)) { _ in
            consumePendingNotificationDestination()
        }
        .onChange(of: model.pendingInterventionTarget) { _, target in
            guard target != nil || interventionOverlay.target == nil else {
                return
            }
            presentPendingInterventionIfValid(target)
        }
        .onChange(of: model.reinterventionRevision) { _, _ in checkPendingReflection() }
        .onChange(of: model.pendingNonTargetAutomation) { _, _ in
            checkPendingNonTargetAutomation()
        }
        .fullScreenCover(isPresented: $isLockScreenCheckPresented, onDismiss: {
            presentedInterventionModal = nil
            if interventionAwaitingModalDismiss == .lockScreenCheck {
                interventionAwaitingModalDismiss = nil
            }
            consumePendingNotificationDestination()
            presentPendingInterventionIfValid(model.pendingInterventionTarget)
            checkPendingPaywalls()
            checkPendingReflection()
            checkPendingNonTargetAutomation()
        }) {
            LockScreenCheckSheet(model: model) {
                isLockScreenCheckPresented = false
            }
            .onAppear {
                presentedInterventionModal = .lockScreenCheck
            }
        }
        .fullScreenCover(item: $pendingPaywallPlacement, onDismiss: {
            presentedInterventionModal = nil
            if interventionAwaitingModalDismiss == .paywall {
                interventionAwaitingModalDismiss = nil
            }
            consumePendingNotificationDestination()
            presentPendingInterventionIfValid(model.pendingInterventionTarget)
            checkPendingPaywalls()
            checkPendingReflection()
            checkPendingNonTargetAutomation()
        }) { placement in
            PaywallView(
                storeService: model.storeService,
                placement: placement,
                settingsStore: settingsStore,
                model: model
            )
            .onAppear {
                presentedInterventionModal = .paywall
            }
        }
        .sheet(item: $pendingReflectionLog, onDismiss: {
            presentedInterventionModal = nil
            model.cancelReflectionNotification()
            if interventionAwaitingModalDismiss == .reflection {
                interventionAwaitingModalDismiss = nil
            }
            consumePendingNotificationDestination()
            presentPendingInterventionIfValid(model.pendingInterventionTarget)
            checkPendingLockScreenCheck()
            checkPendingPaywalls()
            checkPendingNonTargetAutomation()
        }) { reflection in
            if let engine = model.interventionEngine {
                PostUseReflectionSheet(
                    model: model,
                    engine: engine,
                    reflection: reflection
                ) {
                    pendingReflectionLog = nil
                    model.refresh()
                }
                .onAppear {
                    presentedInterventionModal = .reflection
                }
            }
        }
        .sheet(item: $presentedNonTargetAutomation, onDismiss: {
            presentedInterventionModal = nil
            if interventionAwaitingModalDismiss == .nonTargetAutomation {
                interventionAwaitingModalDismiss = nil
            }
            if let placement = paywallAfterNonTargetAutomation {
                paywallAfterNonTargetAutomation = nil
                pendingPaywallPlacement = placement
                return
            }
            presentPendingInterventionIfValid(model.pendingInterventionTarget)
            checkPendingLockScreenCheck()
            checkPendingPaywalls()
            checkPendingReflection()
            checkPendingNonTargetAutomation()
        }) { automation in
            NonTargetAutomationSheet(
                automation: automation,
                restoreDecision: restoreDecision(for: automation),
                onRestore: { restoreNonTargetAutomation(automation) },
                onShowPro: { showProForNonTargetAutomation(automation) },
                onOpenApp: { openNonTargetAutomationApp(automation) },
                onClose: { presentedNonTargetAutomation = nil }
            )
            .onAppear {
                presentedInterventionModal = .nonTargetAutomation
            }
        }
    }

    private var isInterventionOverlayVisible: Bool {
        interventionOverlay.target != nil || interventionDismissTask != nil
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

    private func checkPendingIntervention(suppressPassThrough: Bool = false) {
        model.consumePendingInterventionRequest(
            from: settingsStore,
            suppressPassThrough: suppressPassThrough
        )
    }

    private func handleAppActive() {
        interventionAwaitingModalDismiss = nil
        model.refresh(restartLiveActivity: true)
        // 自動更新オフはiOS設定側で起きるためTransactionが流れない。
        // 復帰のたびに取り直さないと、プロセスが生きている限り解約を検知できない（docs/18 §4）。
        model.refreshEntitlementOnForeground()
        let suppressPassThrough = hasValidPendingReflectionDestination
        if suppressPassThrough {
            discardPendingPassThroughForReflection()
        }
        consumePendingNotificationDestination()
        checkPendingIntervention(suppressPassThrough: suppressPassThrough)
        presentPendingInterventionIfValid(model.pendingInterventionTarget)
        checkPendingLockScreenCheck()
        checkPendingPaywalls()
        checkPendingReflection()
        checkPendingNonTargetAutomation()
    }

    private var hasValidPendingReflectionDestination: Bool {
        ReflectionInterventionPriority.shouldSuppressPassThrough(
            for: settingsStore.pendingNotificationDestination,
            now: model.currentDate
        )
    }

    private func discardPendingPassThroughForReflection() {
        guard let target = model.pendingInterventionTarget,
              case .catalogPassThrough = target,
              model.discardPendingInterventionTarget(ifMatching: target) else {
            return
        }
        guard interventionOverlay.target == target else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            interventionOverlay.dismiss()
        }
        model.isInterventionOverlayPresented = false
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
        guard model.pendingInterventionTarget == nil,
              interventionOverlay.target == nil,
              pendingPaywallPlacement == nil,
              presentedNonTargetAutomation == nil,
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
        case .reflection:
            presentReflectionFromNotification()
        }
    }

    private func presentReflectionFromNotification() {
        model.recordFunnelEvent(.reflectionNotificationTapped)
        guard settingsStore.onboardingCompleted,
              pendingReflectionLog == nil,
              model.pendingInterventionTarget == nil,
              interventionOverlay.target == nil,
              pendingPaywallPlacement == nil,
              presentedNonTargetAutomation == nil,
              !isLockScreenCheckPresented,
              !model.isChildModalActive,
              let engine = model.interventionEngine else {
            return
        }
        pendingReflectionLog = model.pendingReinterventionReflection() ?? (try? engine.pendingReflection(
            within: InterventionEngine.reflectionNotificationTapWindow
        ))
    }

    /// オンボーディング後に最初の目標を追加したら、ロック画面での確認導線を出す。
    /// Live Activityを有効にしている場合だけ、他のモーダルと競合しないタイミングで提示する。
    private func checkPendingLockScreenCheck() {
        guard settingsStore.onboardingCompleted,
              settingsStore.liveActivityEnabled,
              model.pendingLockScreenCheck,
              !isLockScreenCheckPresented,
              model.pendingInterventionTarget == nil,
              interventionOverlay.target == nil,
              pendingPaywallPlacement == nil,
              presentedNonTargetAutomation == nil,
              !model.isChildModalActive else {
            return
        }

        isLockScreenCheckPresented = true
    }

    private func checkPendingPaywalls() {
        checkPendingWeeklyPaywall()
    }

    private func checkPendingReflection() {
        guard settingsStore.onboardingCompleted,
              pendingReflectionLog == nil,
              model.pendingInterventionTarget == nil,
              interventionOverlay.target == nil,
              pendingPaywallPlacement == nil,
              presentedNonTargetAutomation == nil,
              !isLockScreenCheckPresented,
              !model.isChildModalActive,
              let engine = model.interventionEngine else {
            return
        }
        let expiredCount = (try? engine.expireStaleReflections(
            olderThan: InterventionEngine.reflectionNotificationTapWindow
        )) ?? 0
        if expiredCount > 0 {
            model.removeDeliveredReflectionNotification()
        }
        pendingReflectionLog = model.pendingReinterventionReflection() ?? (try? engine.pendingReflection())
    }

    private func checkPendingWeeklyPaywall() {
        guard settingsStore.onboardingCompleted,
              model.pendingInterventionTarget == nil,
              interventionOverlay.target == nil,
              pendingPaywallPlacement == nil,
              presentedNonTargetAutomation == nil,
              !isLockScreenCheckPresented,
              !model.isChildModalActive,
              WeeklyPaywallPolicy.shouldPresent(
                  isPro: model.storeService.isPro,
                  // 権利の取得に失敗しただけの課金者へ週次ペイウォールを出さない。
                  // 判断は「解決を試した」ではなく「確定して解決できた」で行う。
                  hasResolvedEntitlement: model.storeService.hasConfirmedEntitlement,
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

    private func presentPendingInterventionIfValid(_ target: InterventionTarget?) {
        if model.isInterventionSuppressedByHardBlock {
            model.pendingInterventionTarget = nil
            if interventionOverlay.target != nil {
                dismissInvalidInterventionOverlayWithoutAnimation()
            }
            return
        }
        guard let target else {
            guard interventionDismissTask == nil else {
                return
            }
            let wasPresented = interventionOverlay.target != nil
            interventionAwaitingModalDismiss = nil
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                interventionOverlay.dismiss()
            }
            model.isInterventionOverlayPresented = false
            if wasPresented {
                runPostInterventionDismissalChecks()
            }
            return
        }
        guard let target = InterventionTargetPresentationPolicy.validatedTarget(
            target,
            now: model.currentDate
        ) else {
            model.discardPendingInterventionTarget(ifMatching: target)
            dismissInvalidInterventionOverlayWithoutAnimation()
            return
        }
        switch target {
        case .catalog(let catalogTarget), .catalogPassThrough(let catalogTarget, _):
            guard model.isCurrentInterventionTarget(catalogID: catalogTarget.catalogID) else {
                guard model.discardPendingInterventionTarget(ifMatching: target) else {
                    return
                }
                dismissInvalidInterventionOverlayWithoutAnimation()
                return
            }
        }
        // 対象アプリを開こうとした瞬間の一呼吸が最優先。先行中の全画面表示は畳んでから出す。
        var shouldAwaitModalDismissal = false
        switch InterventionPresentationPolicy.directive(
            awaitingModalDismissal: interventionAwaitingModalDismiss,
            isLockScreenCheckPresented: isLockScreenCheckPresented,
            isPaywallPresented: pendingPaywallPlacement != nil,
            isReflectionPresented: pendingReflectionLog != nil,
            isNonTargetAutomationPresented: presentedNonTargetAutomation != nil
        ) {
        case .waitForModalDismissal:
            return
        case .dismissLockScreenCheck:
            if let awaitingModalDismissal = InterventionPresentationPolicy.awaitingModalDismissal(
                for: .lockScreenCheck,
                presentedInterventionModal: presentedInterventionModal
            ) {
                interventionAwaitingModalDismiss = awaitingModalDismissal
                shouldAwaitModalDismissal = true
            }
            isLockScreenCheckPresented = false
        case .dismissPaywall:
            if let awaitingModalDismissal = InterventionPresentationPolicy.awaitingModalDismissal(
                for: .paywall,
                presentedInterventionModal: presentedInterventionModal
            ) {
                interventionAwaitingModalDismiss = awaitingModalDismissal
                shouldAwaitModalDismissal = true
            }
            pendingPaywallPlacement = nil
        case .dismissReflection:
            if let awaitingModalDismissal = InterventionPresentationPolicy.awaitingModalDismissal(
                for: .reflection,
                presentedInterventionModal: presentedInterventionModal
            ) {
                interventionAwaitingModalDismiss = awaitingModalDismissal
                shouldAwaitModalDismissal = true
            }
            deferredReflectionLog = pendingReflectionLog
            pendingReflectionLog = nil
        case .dismissNonTargetAutomation:
            if let awaitingModalDismissal = InterventionPresentationPolicy.awaitingModalDismissal(
                for: .nonTargetAutomation,
                presentedInterventionModal: presentedInterventionModal
            ) {
                interventionAwaitingModalDismiss = awaitingModalDismissal
                shouldAwaitModalDismissal = true
            }
            presentedNonTargetAutomation = nil
        case .present:
            break
        }
        guard !shouldAwaitModalDismissal else {
            return
        }

        interventionDismissTask?.cancel()
        interventionDismissTask = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            interventionOverlay.present(target)
        }
        model.isInterventionOverlayPresented = true
    }

    private func dismissInterventionOverlay() {
        guard interventionOverlay.target != nil else {
            return
        }
        interventionDismissTask?.cancel()
        interventionDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else {
                return
            }
            interventionDismissTask = nil
            runPostInterventionDismissalChecks()
        }
        model.pendingInterventionTarget = nil
        model.refresh()
        withAnimation(.easeOut(duration: 0.2)) {
            interventionOverlay.dismiss()
        }
        model.isInterventionOverlayPresented = false
    }

    private func dismissInvalidInterventionOverlayWithoutAnimation() {
        interventionAwaitingModalDismiss = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            interventionOverlay.dismiss()
        }
        model.isInterventionOverlayPresented = false
        runPostInterventionDismissalChecks()
    }

    private func runPostInterventionDismissalChecks() {
        restoreDeferredReflectionIfNeeded()
        consumePendingNotificationDestination()
        checkPendingLockScreenCheck()
        checkPendingPaywalls()
        checkPendingReflection()
        checkPendingNonTargetAutomation()
    }

    private func restoreDeferredReflectionIfNeeded() {
        guard ReflectionDeferralPolicy.shouldRestore(
            pendingReflection: pendingReflectionLog,
            deferredReflection: deferredReflectionLog
        ), let deferredReflectionLog else {
            return
        }
        pendingReflectionLog = deferredReflectionLog
        self.deferredReflectionLog = nil
    }

    private func checkPendingNonTargetAutomation() {
        guard presentedNonTargetAutomation == nil,
              model.pendingInterventionTarget == nil,
              interventionOverlay.target == nil,
              pendingPaywallPlacement == nil,
              !isLockScreenCheckPresented,
              pendingReflectionLog == nil,
              !model.isChildModalActive,
              let pending = model.pendingNonTargetAutomation else {
            return
        }
        model.pendingNonTargetAutomation = nil
        presentedNonTargetAutomation = pending
    }

    /// 枠が埋まっているだけの状態を「2個目の追加」と数えると、入れ替えのつもりの操作が
    /// ペイウォールに落ちる。追加・入れ替え・課金導線の判定はCoreの純関数に寄せる。
    private func restoreDecision(
        for automation: NonTargetAutomation
    ) -> NonTargetAutomationRestorePolicy.Decision {
        let selected = (try? model.targetStore.selectedCatalogIDs()) ?? []
        return NonTargetAutomationRestorePolicy.decision(
            reason: restorePolicyReason(automation.reason),
            restoredCatalogID: automation.catalogID,
            selectedCatalogIDs: selected,
            limit: model.entitlementGate.targetAppTokensLimit
        )
    }

    /// 画面層の理由をCoreの判定用へ写す。網羅スイッチにして、理由が増えたらここで気づけるようにする。
    private func restorePolicyReason(
        _ reason: NonTargetAutomationReason
    ) -> NonTargetAutomationRestorePolicy.Reason {
        switch reason {
        case .removed:
            return .removed
        case .clampedByEntitlement:
            return .clampedByEntitlement
        }
    }

    /// 対象へ戻す。失敗したら文言を返し、シートは開いたままにする。
    /// 呼び出し元のアラートはこのシートに隠れて出ないため、表示はシート側に任せる。
    private func restoreNonTargetAutomation(_ automation: NonTargetAutomation) -> String? {
        let selected: [String]
        do {
            // 読み取りに失敗した0件を「空き枠あり」と読むと、生きている対象を消して保存してしまう。
            // 保存する側では握りつぶさず、何も書かずに理由を返す。
            selected = try model.targetStore.selectedCatalogIDs()
        } catch {
            return String(localized: "settings.error.data_load", defaultValue: "データを読み込めませんでした")
        }
        // 押し出す分の失効処理とクランプ控えの破棄は setTargetCatalogIDs が持っている。
        let resulting = NonTargetAutomationRestorePolicy.resultingCatalogIDs(
            restoredCatalogID: automation.catalogID,
            selectedCatalogIDs: selected,
            limit: model.entitlementGate.targetAppTokensLimit
        )
        do {
            try model.setTargetCatalogIDs(resulting)
            model.requestStartIntervention(catalogID: automation.catalogID)
            presentedNonTargetAutomation = nil
            return nil
        } catch {
            return String(localized: "settings.error.data_save", defaultValue: "データを保存できませんでした")
        }
    }

    private func showProForNonTargetAutomation(_ automation: NonTargetAutomation) {
        model.purchaseContinuation = .addTarget(catalogID: automation.catalogID)
        paywallAfterNonTargetAutomation = .settingsTargetAppLimit
        presentedNonTargetAutomation = nil
    }

    private func openNonTargetAutomationApp(_ automation: NonTargetAutomation) {
        guard let scheme = SNSAppCatalog.app(catalogID: automation.catalogID)?.urlScheme,
              let url = URL(string: scheme) else {
            return
        }
        // 自動化は残ったままなので、戻った先でもう一度発火する。
        // 自己起動として記録しておかないと、同じシートがそのまま返ってくる。
        model.markSelfOpened(catalogID: automation.catalogID)
        UIApplication.shared.open(url)
        presentedNonTargetAutomation = nil
    }
}

// 旧 DopaTabBar（自前のタブバー）は削除した。
// システムのタブバーはDynamic Type・VoiceOver・選択トレイト・Liquid Glass・
// ホームインジケータとの間隔を標準どおりに扱うため、自前実装より一貫して正しく振る舞う。
