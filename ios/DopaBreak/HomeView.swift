import Combine
import DopaBreakCore
import Foundation
import SwiftUI

private enum HomeStatsProvider {
    static let shared: StatsService? = {
        guard let logStore = try? SQLiteLogStore(containerProvider: DefaultContainerProvider()) else {
            return nil
        }
        return StatsService(logStore: logStore, calendar: .autoupdatingCurrent)
    }()
}

enum HomeLockThemeSelectionHandler {
    static func select(
        for theme: LockTheme,
        isThemeAllowed: (LockTheme) -> Bool,
        onLocked: (LockTheme, PaywallPlacement) -> Void,
        onSelect: (LockTheme) -> Void
    ) {
        if isThemeAllowed(theme) {
            onSelect(theme)
        } else {
            onLocked(theme, .homeThemeGate)
        }
    }
}

/// ホームのロック画面カードに何を出すか。
/// iOSの確認で「許可しない」を選んだ人にプレビューを出し続けると、
/// 目標がロック画面に出ていないことに本人が気づけない（2026-09-26 オーナー承認）。
enum HomeLockScreenCardPolicy {
    enum Content: Equatable {
        /// アプリ内の設定でロック画面の表示を切っている。カードごと出さない。
        case hidden
        case preview
        /// 端末の設定でライブアクティビティが許可されていない。設定への導線を出す。
        case systemDisabled
    }

    static func content(liveActivityEnabled: Bool, areLiveActivitiesAllowed: Bool) -> Content {
        guard liveActivityEnabled else {
            return .hidden
        }
        return areLiveActivitiesAllowed ? .preview : .systemDisabled
    }
}

private struct HomeDashboardData {
    var weeklySummary: WeeklySummary?
    var consecutiveDays = 0
    var hasCompletedWin = false
    var lifetimeReclaimedSeconds = 0
    var todayReclaimedSeconds = 0
    var todayReclaimedCancellationCount = 0
    var estimatedSecondsPerCancellation = ReclaimedTimeEstimator.defaultSeconds

    static let empty = HomeDashboardData()
}

struct HomeView: View {
    let model: AppModel
    let settingsStore: SettingsStore
    let onOpenStats: () -> Void
    let onOpenGoals: (_ addRequested: Bool) -> Void
    let onOpenBlockSettings: () -> Void
    private let injectedStatsService: StatsService?
    private let onThemePickerEntryActionReady: ((@escaping () -> Void) -> Void)?
    private let onThemePickerActionReady: ((@escaping (LockTheme) -> Void) -> Void)?
    private let onThemePickerSelectionChanged: ((LockTheme) -> Void)?
    private let onLockScreenPreviewRendered: ((LockTheme) -> Void)?
    private let onPaywallPresented: ((PaywallPlacement) -> Void)?
    private let onBlockSettingsActionReady: ((@escaping () -> Void) -> Void)?

    @State private var isStrictExitPresented = false
    @State private var isOpenLimitEmergencyPresented = false
    @State private var editorRoute: GoalEditorRoute?
    @State private var isAutomationGuidePresented = false
    @State private var isTargetPickerPresented = false
    @State private var isLockThemePickerPresented = false
    @State private var isLockScreenCheckPresented = false
    @State private var paywallPlacement: PaywallPlacement?
    @State private var showPaywallAfterTargetPicker = false
    /// アプリを追加した直後にショートカットの案内を開くための予約。追加したカタログIDを持つ。
    /// ピッカーを閉じてから出さないとモーダルがぶつかるので、ここで持ち越す。
    /// 同じピッカーの中で外し直したら取り消す。対象0件のまま案内を開かないため。
    @State private var pendingAutomationGuideAfterPicker: Set<String> = []
    @State private var pendingThemePaywallPlacement: PaywallPlacement?
    @State private var dashboard = HomeDashboardData.empty
    @State private var clock = Date()
    @State private var liveActivityEnabled: Bool
    @State private var breathDurationSeconds: Int
    @State private var confirmedAutomationCatalogIDs: [String]
    @State private var wakeTimeMinutes: Int
    @State private var bedTimeMinutes: Int
    @State private var isBlockConfigured: Bool
    @State private var blockTargetRuleCount: Int

    private static let dashboardTicker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    init(
        model: AppModel,
        settingsStore: SettingsStore,
        onOpenStats: @escaping () -> Void = {},
        onOpenGoals: @escaping (_ addRequested: Bool) -> Void = { _ in },
        onOpenBlockSettings: @escaping () -> Void = {},
        statsService: StatsService? = nil,
        onThemePickerEntryActionReady: ((@escaping () -> Void) -> Void)? = nil,
        onThemePickerActionReady: ((@escaping (LockTheme) -> Void) -> Void)? = nil,
        onThemePickerSelectionChanged: ((LockTheme) -> Void)? = nil,
        onLockScreenPreviewRendered: ((LockTheme) -> Void)? = nil,
        onPaywallPresented: ((PaywallPlacement) -> Void)? = nil,
        onBlockSettingsActionReady: ((@escaping () -> Void) -> Void)? = nil
    ) {
        self.model = model
        self.settingsStore = settingsStore
        self.onOpenStats = onOpenStats
        self.onOpenGoals = onOpenGoals
        self.onOpenBlockSettings = onOpenBlockSettings
        injectedStatsService = statsService
        self.onThemePickerEntryActionReady = onThemePickerEntryActionReady
        self.onThemePickerActionReady = onThemePickerActionReady
        self.onThemePickerSelectionChanged = onThemePickerSelectionChanged
        self.onLockScreenPreviewRendered = onLockScreenPreviewRendered
        self.onPaywallPresented = onPaywallPresented
        self.onBlockSettingsActionReady = onBlockSettingsActionReady
        _liveActivityEnabled = State(initialValue: settingsStore.liveActivityEnabled)
        _breathDurationSeconds = State(initialValue: settingsStore.breathDurationSeconds)
        _confirmedAutomationCatalogIDs = State(
            initialValue: settingsStore.confirmedAutomationCatalogIDs
        )
        _wakeTimeMinutes = State(
            initialValue: settingsStore.wakeTimeMinutes
                ?? NightShieldConstants.defaultWakeTimeMinutes
        )
        _bedTimeMinutes = State(
            initialValue: settingsStore.bedTimeMinutes
                ?? NightShieldConstants.defaultBedTimeMinutes
        )
        _isBlockConfigured = State(initialValue: model.isBlockConfigured)
        _blockTargetRuleCount = State(initialValue: model.blockTargetRuleCount)
    }

    private var statsService: StatsService? {
        injectedStatsService ?? HomeStatsProvider.shared
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                topLine

                if !unconfirmedAutomationTargets.isEmpty {
                    automationStatusBanner
                }

                if model.blockConfiguration.blockEnabled && !isBlockConfigured {
                    blockSetupBanner
                }

                heroSection

                targetAppsCard

                if isFirstDayEmpty {
                    firstDayEmptySection
                        .padding(.vertical, 12)
                }

                weekCard

                if !isFirstDayEmpty {
                    statsLinkCard
                }

                goalCard

                if settingsStore.onboardingExperienceCompleted || dashboard.hasCompletedWin {
                    Button {
                        isLockScreenCheckPresented = true
                    } label: {
                        SettingsRow(label: String(localized: "settings.lock_screen.check", defaultValue: "ロック画面で確かめる"), disclosure: .navigate)
                    }
                    .buttonStyle(.plain)
                }

                switch HomeLockScreenCardPolicy.content(
                    liveActivityEnabled: liveActivityEnabled,
                    areLiveActivitiesAllowed: model.areLiveActivitiesAllowed
                ) {
                case .preview:
                    lockScreenCard
                case .systemDisabled:
                    lockScreenDisabledCard
                case .hidden:
                    EmptyView()
                }
            }
            .padding(.horizontal, DesignTokens.horizontalPadding)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .dopaScreenBackground()
        .onAppear {
            model.refresh()
            refreshSettingsMirrors()
            reloadDashboard()
            model.isChildModalActive = isAnyChildModalPresented
        }
        .onChange(of: model.todayAttemptCount) { _, _ in
            reloadDashboard()
        }
        .onChange(of: model.weekAttemptCount) { _, _ in
            reloadDashboard()
        }
        .onChange(of: isAnyChildModalPresented) { _, isPresented in
            model.isChildModalActive = isPresented
        }
        .onReceive(Self.dashboardTicker) { date in
            let didRollOver = !Calendar.autoupdatingCurrent.isDate(clock, inSameDayAs: date)
            clock = date
            if didRollOver {
                reloadDashboard(referenceDate: date)
            }
        }
        .fullScreenCover(isPresented: $isLockScreenCheckPresented) {
            LockScreenCheckSheet(model: model) { isLockScreenCheckPresented = false }
        }
        .sheet(isPresented: $isStrictExitPresented) { StrictSessionExitView(model: model) }
        .sheet(isPresented: $isOpenLimitEmergencyPresented) { DailyOpenLimitEmergencySheet(model: model) }
        .sheet(item: $editorRoute) { route in
            GoalEditorSheet(model: model, goal: route.goal)
        }
        .sheet(isPresented: $isAutomationGuidePresented, onDismiss: refreshSettingsMirrors) {
            AutomationGuideView(model: model, settingsStore: settingsStore)
        }
        .sheet(isPresented: $isTargetPickerPresented, onDismiss: {
            reloadDashboard()
            if showPaywallAfterTargetPicker {
                showPaywallAfterTargetPicker = false
                // 閉じ切る前に載せ替えるとfullScreenCoverが落ち、placementだけが残る。
                // 残ると画面に何も出ないまま `isAnyChildModalPresented` が真で固まり、
                // 以後のロック画面確認・ペイウォール・振り返り・対象外シートが全部止まる。
                Task {
                    try? await Task.sleep(for: .milliseconds(100))
                    guard !Task.isCancelled else { return }
                    paywallPlacement = .settingsTargetAppLimit
                }
                // ペイウォールが先。案内の予約は残し、ペイウォールを閉じたあとに出す。
                return
            }
            presentAutomationGuideAfterPickerIfNeeded()
        }) {
            TargetAppPickerSheet(
                model: model,
                onPaywallNeeded: {
                    showPaywallAfterTargetPicker = true
                },
                onTargetAdded: { catalogID in
                    pendingAutomationGuideAfterPicker.insert(catalogID)
                },
                onTargetRemoved: { catalogID in
                    pendingAutomationGuideAfterPicker.remove(catalogID)
                }
            )
        }
        .sheet(isPresented: $isLockThemePickerPresented, onDismiss: {
            guard let placement = pendingThemePaywallPlacement else { return }
            pendingThemePaywallPlacement = nil
            paywallPlacement = placement
        }) {
            homeThemePickerSheet
        }
        .fullScreenCover(item: $paywallPlacement, onDismiss: {
            if model.pendingAutomationGuideAfterPurchase {
                model.pendingAutomationGuideAfterPurchase = false
                pendingAutomationGuideAfterPicker.insert("purchase")
            }
            // ペイウォールを先に出したぶん、持ち越した案内はここで消化する。
            presentAutomationGuideAfterPickerIfNeeded()
        }) { placement in
            PaywallView(
                storeService: model.storeService,
                placement: placement,
                settingsStore: settingsStore,
                model: model
            )
            .onAppear { onPaywallPresented?(placement) }
        }
    }

    /// 追加直後のショートカット案内を出す。ペイウォールが控えているときはそちらを優先し、
    /// 予約を残してペイウォールの `onDismiss` で改めて出す。
    private func presentAutomationGuideAfterPickerIfNeeded() {
        guard !showPaywallAfterTargetPicker, paywallPlacement == nil else {
            return
        }
        guard !pendingAutomationGuideAfterPicker.isEmpty else {
            return
        }
        pendingAutomationGuideAfterPicker.removeAll()
        isAutomationGuidePresented = true
    }

    private var isAnyChildModalPresented: Bool {
        editorRoute != nil
            || isAutomationGuidePresented
            || isTargetPickerPresented
            || isLockThemePickerPresented
            || isLockScreenCheckPresented
            // ピッカーを閉じてからペイウォールが出るまでの受け渡し中も「モーダル中」に数える。
            // ここが抜けると、シートが閉じるあいだだけ `isChildModalActive` が false になり、
            // RootTabView の週次ペイウォールが割り込んで保留中のProテーマを捨ててしまう。
            // `onDismiss` が nil 化と `paywallPlacement` の設定を同じ一回で行うため、隙間はできない。
            || pendingThemePaywallPlacement != nil
            // 追加直後の案内も同じ理由で数える。ペイウォールを挟むと消化までに間が空く。
            || !pendingAutomationGuideAfterPicker.isEmpty
            || paywallPlacement != nil
            || isStrictExitPresented
            || isOpenLimitEmergencyPresented
    }

    private var topLine: some View {
        HStack(spacing: 12) {
            SmallLabel(
                text: String(
                    localized: "home.hero.today",
                    defaultValue: "今日 ・ \(todayText)"
                )
            )
            Spacer(minLength: 8)
            if !isFirstDayEmpty {
                Text(
                    String(
                        localized: "home.hero.week_count",
                        defaultValue: "\(model.weekCancelledCount)回 / 今週"
                    )
                )
                .dopaFont(12, weight: .bold, design: .monospaced)
                .foregroundStyle(DesignTokens.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(DesignTokens.background.opacity(0.72))
                .clipShape(Capsule())
            }
        }
    }

    private var heroSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 22) {
                CharacterView(heroExpression, size: 112)
                achievementBlock
            }

            VStack(alignment: .center, spacing: 14) {
                CharacterView(heroExpression, size: 112)
                    .frame(maxWidth: .infinity)
                achievementBlock
            }
        }
        .padding(.vertical, 6)
    }

    private var achievementBlock: some View {
        // 取り戻した時間とその前後の説明は中央そろえ（オーナー指示 2026-09-21）
        VStack(alignment: .center, spacing: 5) {
            SmallLabel(
                text: String(
                    localized: "home.hero.lifetime.title",
                    defaultValue: "SNSを開かずに取り戻した時間"
                )
            )

            HStack(alignment: .lastTextBaseline, spacing: 12) {
                Spacer(minLength: 0)
                Text(lifetimeReclaimedTimeText)
                    .dopaFont(56, weight: .black, design: .rounded, tracking: -2)
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.accent)
                    .contentTransition(.numericText())
                    .dopaDisplayClamp()

                if let lifetimeReclaimedEquivalentText {
                    Text(lifetimeReclaimedEquivalentText)
                        .dopaFont(20, weight: .semibold)
                        .monospacedDigit()
                        .foregroundStyle(DesignTokens.secondaryText)
                        .contentTransition(.numericText())
                        .dopaDisplayClamp()
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .animation(DopaMotion.control, value: dashboard.lifetimeReclaimedSeconds)

            if dashboard.todayReclaimedCancellationCount == 0 {
                Text(
                    String(
                        localized: "home.achievement.empty_body",
                        defaultValue: "今日はまだ対象アプリを開こうとしていません"
                    )
                )
                .dopaFont(14, weight: .semibold)
                .foregroundStyle(DesignTokens.secondaryText)
            } else {
                Text(
                    String(
                        localized: "home.hero.today_delta",
                        defaultValue: "今日 +\(todayReclaimedTimeText)"
                    )
                )
                .dopaFont(20, weight: .black)
                .foregroundStyle(DesignTokens.primaryText)

                Text(
                    String(
                        localized: "home.hero.basis",
                        defaultValue: "開かなかった\(dashboard.todayReclaimedCancellationCount)回 × 1回約\(estimatedMinutesPerCancellation)分"
                    )
                )
                .dopaFont(14, weight: .semibold)
                .foregroundStyle(DesignTokens.secondaryText)
            }

            if dashboard.consecutiveDays > 0 {
                HStack(spacing: 7) {
                    Circle()
                        .fill(DesignTokens.accent)
                        .frame(width: 7, height: 7)
                    Text(
                        String(
                            localized: "home.streak.days",
                            defaultValue: "連続 \(dashboard.consecutiveDays)日"
                        )
                    )
                    .dopaFont(12, weight: .semibold)
                    .foregroundStyle(DesignTokens.primaryText)
                }
                .padding(.horizontal, 10)
                .frame(minHeight: 30)
                .overlay {
                    Capsule().stroke(DesignTokens.hairline, lineWidth: 1)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var targetAppsCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    isTargetPickerPresented = true
                } label: {
                    VStack(alignment: .leading, spacing: 14) {
                        SmallLabel(
                            text: String(
                                localized: "home.targets.title",
                                defaultValue: "一呼吸をはさむアプリ"
                            )
                        )

                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .center, spacing: 14) {
                                targetIcons
                                Spacer(minLength: 4)
                                targetStatus
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                targetIcons
                                targetStatus
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if !selectedCatalogItems.isEmpty {
                    automationSettingsLink
                }

                // 回数上限だけがオンのときに「ブロック: オフ」と並べると矛盾して見えるため、そのときは出さない。
                if model.blockConfiguration.blockEnabled || model.dailyOpenLimitStatus.limit == nil {
                    Text(model.blockConfiguration.triggerSummary)
                        .dopaFont(14, weight: .semibold)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .accessibilityIdentifier("home.block.state")
                }
                if model.blockConfiguration.blockEnabled { blockConfigurationLine }
                dailyOpenLimitLine

                if showsEndDeepFocusButton {
                    Button(
                        String(localized: "home.targets.focus_end", defaultValue: "完全ブロックを解除")
                    ) {
                        if model.deepFocusSession?.isStrict == true { isStrictExitPresented = true }
                        else { model.endDeepFocusSession(); clock = Date() }
                    }
                    .buttonStyle(HomeFocusButtonStyle(kind: .secondary))
                } else if model.blockConfiguration.blockEnabled, !isBlockConfigured {
                    Button(
                        String(
                            localized: "home.targets.block_setup_action",
                            defaultValue: "ブロックするアプリを選ぶ"
                        )
                    ) {
                        onOpenBlockSettings()
                    }
                    .buttonStyle(HomeFocusButtonStyle(kind: .primary))
                    .onAppear {
                        onBlockSettingsActionReady?(onOpenBlockSettings)
                    }
                } else if showsStartDeepFocusButton {
                    Button(
                        String(localized: "home.targets.block_settings", defaultValue: "ブロックを設定する")
                    ) {
                        onOpenBlockSettings()
                    }
                    .buttonStyle(HomeFocusButtonStyle(kind: .primary))
                    .onAppear {
                        onBlockSettingsActionReady?(onOpenBlockSettings)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var targetIcons: some View {
        if selectedCatalogItems.isEmpty {
            HStack(spacing: 10) {
                plusTile
                Text(
                    String(localized: "home.targets.empty", defaultValue: "アプリを選ぶ")
                )
                .dopaFont(15, weight: .semibold)
                .foregroundStyle(DesignTokens.accent)
            }
        } else {
            AppIconStack(
                sources: selectedCatalogItems.map { .catalog($0) },
                size: 44,
                maxVisible: 3,
                showsStatusDots: true
            )
        }
    }

    private var plusTile: some View {
        Image(systemName: "plus")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(DesignTokens.accent)
            .frame(width: 44, height: 44)
            .background(DesignTokens.backgroundRaised)
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(DesignTokens.secondaryText, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .accessibilityHidden(true)
    }

    private var targetStatus: some View {
        Text(targetPrimaryStatus)
            .dopaFont(13, weight: .semibold)
            .foregroundStyle(DesignTokens.primaryText)
            .multilineTextAlignment(.trailing)
            .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var targetPrimaryStatus: String {
        String(
            localized: "home.targets.breath_line",
            defaultValue: "開く前に\(breathDurationSeconds)秒の一呼吸をはさみます"
        )
    }

    /// 1日に開ける回数。使い切ったら理由と終わる時刻、緊急で開く導線を出す。
    @ViewBuilder
    private var dailyOpenLimitLine: some View {
        let status = model.dailyOpenLimitStatus
        if status.isExhausted {
            // 最後の1回や緊急で開いた時間のあいだは、まだ開ける。そのあいだは緊急の導線も要らない。
            let openUntil = model.dailyOpenLimitOpenUntil
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(DailyOpenLimitDisplay.openedTitle(status.openedCount))
                        .dopaFont(13, weight: .semibold)
                        .foregroundStyle(DesignTokens.accent)
                    Text(openUntil.map(DailyOpenLimitDisplay.openUntilLine)
                         ?? DailyOpenLimitDisplay.untilLine(status.dayEndsAt, now: clock))
                        .dopaFont(12, weight: .semibold)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                if openUntil == nil, !model.isOtherHardBlockActive {
                    Button(String(localized: "open_limit.emergency.start", defaultValue: "30秒待って開く")) {
                        isOpenLimitEmergencyPresented = true
                    }
                    .buttonStyle(HomeFocusButtonStyle(kind: .secondary))
                    .accessibilityIdentifier("home.open_limit.emergency")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("home.open_limit")
        } else if let remaining = status.remaining {
            Text(String(localized: "open_limit.home.remaining", defaultValue: "今日あと\(remaining)回開けます"))
                .dopaFont(13, weight: .semibold)
                .foregroundStyle(DesignTokens.secondaryText)
                .monospacedDigit()
                .accessibilityIdentifier("home.open_limit")
        }
    }

    private var blockConfigurationLine: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(blockConfigurationStatus)
                .dopaFont(13, weight: .semibold)
                .foregroundStyle(
                    isBlockConfigured && isAnyHardBlockActive && !model.blockMonitoringNeedsAttention
                        ? DesignTokens.accent
                        : DesignTokens.secondaryText
                )
                .fixedSize(horizontal: false, vertical: true)

            if isBlockConfigured, let activeStatus = activeBlockStatus {
                Text(activeStatus)
                    .dopaFont(12, weight: .semibold)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var blockConfigurationStatus: String {
        guard isBlockConfigured else {
            return String(
                localized: "home.targets.block_unset",
                defaultValue: "完全ブロックは未設定"
            )
        }
        if model.blockMonitoringNeedsAttention {
            return String(localized: "home.block.check", defaultValue: "ブロックの準備を確認してください")
        }
        return isAnyHardBlockActive
            ? String(localized: "block.state.active", defaultValue: "ブロック中")
            : String(localized: "block.state.ready", defaultValue: "開始まで待機")
    }

    private var activeBlockStatus: String? {
        guard isBlockConfigured, !model.blockMonitoringNeedsAttention,
              isNightBlockActive || isDeepFocusActive else { return nil }
        var schedules: [DeepFocusSchedule] = []
        if model.blockConfiguration.allows(.weeklySchedule) {
            schedules = model.deepFocusSchedules
        }
        if model.blockConfiguration.allows(.night) {
            schedules.append(.init(isEnabled: true, weekdays: DeepFocusConstants.allWeekdays,
                                   startMinutes: bedTimeMinutes, endMinutes: wakeTimeMinutes))
        }
        if let end = DeepFocusWindowPolicy.scheduleWindowEnd(now: clock, schedules: schedules,
                calendar: .autoupdatingCurrent, session: model.deepFocusSession),
           let remaining = Self.remainingFormatter.string(from: max(60, end.timeIntervalSince(clock))) {
            return String(localized: "home.targets.focus_running", defaultValue: "あと\(remaining)は開けません")
        }
        return String(localized: "home.block.continues", defaultValue: "設定したブロックが続いています")
    }

    private var weekCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                SmallLabel(text: String(localized: "home.week.eyebrow", defaultValue: "今週"))

                DayBars(
                    days: dashboard.weeklySummary?.days
                        ?? WeeklySummaryPlaceholder.emptyWeekDays(referenceDate: clock)
                )

                Text(weekSummaryText)
                    .dopaFont(14, weight: .bold)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var weekSummaryText: String {
        String(
            localized: "home.week.summary",
            defaultValue: "今週は\(model.weekCancelledCount)回 開かずにすみました"
        )
    }

    private var statsLinkCard: some View {
        Button {
            onOpenStats()
        } label: {
            CardContainer {
                HStack(spacing: 12) {
                    Text(
                        String(
                            localized: "home.stats_link.title",
                            defaultValue: "アプリ別の記録と振り返りを見る"
                        )
                    )
                        .dopaFont(15, weight: .bold)
                        .foregroundStyle(DesignTokens.primaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .dopaFont(13, weight: .bold)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private var goalCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    SmallLabel(
                        text: String(localized: "home.goal.label", defaultValue: "あなたの目標")
                    )

                    Spacer(minLength: 8)

                    goalHeaderButton(
                        title: String(localized: "home.goal.add", defaultValue: "追加"),
                        addRequested: true
                    )
                    goalHeaderButton(
                        title: String(localized: "home.goal.edit", defaultValue: "編集"),
                        addRequested: false
                    )
                }

                if model.goals.isEmpty {
                    Button {
                        onOpenGoals(true)
                    } label: {
                        Text(
                            String(
                                localized: "home.goal.fallback",
                                defaultValue: "目標を追加する"
                            )
                        )
                        .dopaFont(17, weight: .semibold)
                        .foregroundStyle(DesignTokens.accent)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    ForEach(model.goals, id: \.id) { goal in
                        Button {
                            editorRoute = GoalEditorRoute(goal: goal)
                        } label: {
                            HStack(spacing: 12) {
                                GoalCategoryTile(category: goal.category, size: 32)

                                Text(goal.title)
                                    .dopaFont(17, weight: .semibold)
                                    .foregroundStyle(DesignTokens.primaryText)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                Spacer(minLength: 8)

                                Image(systemName: "chevron.right")
                                    .dopaFont(13, weight: .bold)
                                    .foregroundStyle(DesignTokens.secondaryText)
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func goalHeaderButton(title: String, addRequested: Bool) -> some View {
        Button {
            onOpenGoals(addRequested)
        } label: {
            Text(title)
                .dopaFont(15, weight: .semibold)
                .foregroundStyle(DesignTokens.accent)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var lockScreenCard: some View {
        Button {
            isLockThemePickerPresented = true
        } label: {
            CardContainer {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        SettingsIconTile(systemName: "rectangle.inset.filled.and.person.filled")
                        Text(
                            String(
                                localized: "settings.entry.lock_surface",
                                defaultValue: "ロック画面の表示"
                            )
                        )
                        .dopaFont(16, weight: .semibold)
                        .foregroundStyle(DesignTokens.primaryText)

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .dopaFont(13, weight: .bold)
                            .foregroundStyle(DesignTokens.secondaryText)
                            .accessibilityHidden(true)
                    }

                    LockThemePreviewCard(
                        theme: model.liveLockTheme,
                        goalTitles: homeLockThemePreviewTitles,
                        cancelledCount: model.todayCancelledCount,
                        attemptCount: model.todayAttemptCount
                    )
                    .onAppear { onLockScreenPreviewRendered?(model.liveLockTheme) }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home-lock-theme-picker-entry")
        .onAppear {
            onThemePickerEntryActionReady? { isLockThemePickerPresented = true }
        }
    }

    /// 端末でライブアクティビティがオフのときの代わりのカード。文言はロック画面確認と共通。
    /// 設定から戻ると前面復帰の `refresh()` が許可を取り直し、プレビューへ戻る。
    private var lockScreenDisabledCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                Text(String(localized: "lock_check.title.blocked", defaultValue: "ロック画面の表示がオフ"))
                    .dopaFont(20, weight: .black)
                    .foregroundStyle(DesignTokens.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    String(
                        localized: "lock_check.lead.blocked",
                        defaultValue: "端末の設定でライブアクティビティをオンにすると表示できます。"
                    )
                )
                .dopaFont(14, weight: .semibold, lineSpacing: 4)
                .foregroundStyle(DesignTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                Button(String(localized: "lock_check.action.settings", defaultValue: "設定を開く")) {
                    LockScreenSettingsLink.open()
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("home.lockScreenOpenSettings")
            }
        }
        .accessibilityIdentifier("home.lockScreenDisabledCard")
    }

    private var homeThemePickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !model.entitlementGate.lockThemeAllowed(model.displayedLockThemeSelection) {
                        Text(
                            String(
                                localized: "settings.lock_screen.pro_note",
                                defaultValue: "このデザインをロック画面に表示するにはProが必要です"
                            )
                        )
                        .dopaFont(13, weight: .semibold, lineSpacing: 3)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    LockThemePickerView(
                        selectedTheme: model.displayedLockThemeSelection,
                        goalTitles: homeLockThemePreviewTitles,
                        cancelledCount: model.todayCancelledCount,
                        attemptCount: model.todayAttemptCount,
                        isThemeAllowed: model.entitlementGate.lockThemeAllowed,
                        onSelect: selectHomeLockTheme
                    )
                    .onAppear { onThemePickerActionReady?(selectHomeLockTheme) }
                }
                .padding(.horizontal, DesignTokens.horizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .dopaScreenBackground()
            .navigationTitle(
                String(
                    localized: "settings.entry.lock_surface",
                    defaultValue: "ロック画面の表示"
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "onboarding.action.close", defaultValue: "閉じる")) {
                        isLockThemePickerPresented = false
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var homeLockThemePreviewTitles: [String] {
        let titles = model.lockScreenDisplayTitles.filter { !$0.isEmpty }
        return titles.isEmpty
            ? [String(localized: "lock_check.preview.goal_fallback", defaultValue: "あなたの目標")]
            : titles
    }

    private func selectHomeLockTheme(_ theme: LockTheme) {
        HomeLockThemeSelectionHandler.select(
            for: theme,
            isThemeAllowed: model.entitlementGate.lockThemeAllowed,
            onLocked: { selectedTheme, placement in
                model.pendingProThemeSelection = selectedTheme
                onThemePickerSelectionChanged?(selectedTheme)
                pendingThemePaywallPlacement = placement
                isLockThemePickerPresented = false
            },
            onSelect: { selectedTheme in
                model.updateLockTheme(selectedTheme)
                onThemePickerSelectionChanged?(selectedTheme)
            }
        )
    }

    private var firstDayEmptySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                String(
                    localized: "home.first_day.title",
                    defaultValue: "対象アプリを開くと まず一呼吸"
                )
            )
            .dopaFont(30, weight: .black, tracking: -0.7, lineSpacing: 4)
            .foregroundStyle(DesignTokens.primaryText)
            .fixedSize(horizontal: false, vertical: true)

            Text(
                String(
                    localized: "home.first_day.body",
                    defaultValue: "開かなかった回数が、ここに記録されます。"
                )
            )
            .dopaFont(15, weight: .semibold, lineSpacing: 4)
            .foregroundStyle(DesignTokens.secondaryText)
        }
    }

    private var blockSetupBanner: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                Text(String(localized: "home.block_setup.title", defaultValue: "ブロック未設定"))
                    .dopaFont(20, weight: .black)
                    .foregroundStyle(DesignTokens.primaryText)
                Button(String(localized: "home.block_setup.action", defaultValue: "ブロックを設定する"), action: onOpenBlockSettings)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .accessibilityIdentifier("home.blockSetupBanner")
    }

    private var automationStatusBanner: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                Text(automationStatusTitle)
                    .dopaFont(20, weight: .black)
                    .foregroundStyle(DesignTokens.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    String(
                        localized: "home.automation_status.body",
                        defaultValue: "ショートカットで設定したアプリにチェックを付けてください。"
                    )
                )
                .dopaFont(14, weight: .semibold, lineSpacing: 4)
                .foregroundStyle(DesignTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                Button(
                    String(localized: "home.automation_status.action", defaultValue: "設定済みのアプリをチェック")
                ) {
                    isAutomationGuidePresented = true
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("home.confirmAutomation")
            }
        }
        .accessibilityIdentifier("home.automationStatusBanner")
    }

    private var automationSettingsLink: some View {
        Button {
            isAutomationGuidePresented = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checklist")
                    .foregroundStyle(DesignTokens.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "home.automation_settings.title", defaultValue: "ショートカットの設定状況"))
                        .dopaFont(14, weight: .semibold)
                        .foregroundStyle(DesignTokens.primaryText)
                    Text(String(localized: "automation_guide.progress", defaultValue: "\(selectedCatalogItems.count - unconfirmedAutomationCatalogIDs.count)/\(selectedCatalogItems.count) 設定済み"))
                        .dopaFont(12, weight: .medium)
                        .foregroundStyle(DesignTokens.secondaryText)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .dopaFont(12, weight: .semibold)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: DesignTokens.minTapTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.automationSettings")
    }

    private var selectedCatalogItems: [SNSAppCatalogItem] {
        ((try? model.targetStore.selectedCatalogIDs()) ?? [])
            .compactMap { SNSAppCatalog.app(catalogID: $0) }
    }

    private var isNightBlockActive: Bool {
        model.blockConfiguration.allows(.night) && NightWindowPolicy.isNight(
            now: clock,
            bedTimeMinutes: bedTimeMinutes,
            wakeTimeMinutes: wakeTimeMinutes,
            calendar: .autoupdatingCurrent
        )
    }

    private var isManualDeepFocusActive: Bool {
        model.blockConfiguration.allows(.manual) && model.deepFocusSession != nil
    }

    private var isScheduledDeepFocusActive: Bool {
        model.blockConfiguration.allows(.weeklySchedule) && model.isDeepFocusScheduleWindowActive
    }

    private var isDeepFocusActive: Bool {
        isManualDeepFocusActive || isScheduledDeepFocusActive
    }

    private var isAnyHardBlockActive: Bool {
        // 回数上限で止まっているあいだも「ブロック中」。夜・予定の窓だけを見ると「開始まで待機」と矛盾して出る。
        isBlockConfigured && (isNightBlockActive || isDeepFocusActive || model.dailyOpenLimitBlockSnapshot != nil)
    }

    private var showsEndDeepFocusButton: Bool {
        isManualDeepFocusActive && (!isScheduledDeepFocusActive || model.deepFocusSession?.isStrict == true)
    }

    private var showsStartDeepFocusButton: Bool {
        // 1日に開ける回数を使い切っているあいだは、緊急で開く導線だけを出す。設定へのボタンを並べると、そちらが主に見える。
        !isNightBlockActive && !isDeepFocusActive && !model.dailyOpenLimitStatus.isExhausted
    }

    private static let remainingFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter
    }()

    private static let timeOfDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return formatter
    }()

    private var bedTimeText: String {
        let calendar = Calendar.autoupdatingCurrent
        let minutes = bedTimeMinutes
        let date = calendar.date(
            bySettingHour: minutes / 60,
            minute: minutes % 60,
            second: 0,
            of: clock
        ) ?? clock
        return Self.timeOfDayFormatter.string(from: date)
    }

    private var wakeTimeText: String {
        let calendar = Calendar.autoupdatingCurrent
        let date = calendar.date(
            bySettingHour: wakeTimeMinutes / 60,
            minute: wakeTimeMinutes % 60,
            second: 0,
            of: clock
        ) ?? clock
        return Self.timeOfDayFormatter.string(from: date)
    }

    private var lifetimeReclaimedTimeText: String {
        ReclaimedTimeFormatter.string(seconds: dashboard.lifetimeReclaimedSeconds)
    }

    private var lifetimeReclaimedEquivalentText: String? {
        ReclaimedTimeFormatter.equivalentString(seconds: dashboard.lifetimeReclaimedSeconds)
    }

    private var todayReclaimedTimeText: String {
        ReclaimedTimeFormatter.detailedString(seconds: dashboard.todayReclaimedSeconds)
    }

    private var estimatedMinutesPerCancellation: Int {
        ReclaimedTimeFormatter.estimatedMinutesPerCancellation(
            todayReclaimedSeconds: dashboard.todayReclaimedSeconds,
            todayCancellationCount: dashboard.todayReclaimedCancellationCount,
            fallbackSeconds: dashboard.estimatedSecondsPerCancellation
        )
    }

    private var heroExpression: CharacterExpression {
        model.todayAttemptCount > 0 && model.todayCancelledCount == 0 ? .doom : .awake
    }

    private var unconfirmedAutomationCatalogIDs: [String] {
        AutomationVerification.unverifiedCatalogIDs(
            selectedCatalogIDs: (try? model.targetStore.selectedCatalogIDs()) ?? [],
            verifiedCatalogIDs: confirmedAutomationCatalogIDs
        )
    }

    private var unconfirmedAutomationTargets: [SNSAppCatalogItem] {
        unconfirmedAutomationCatalogIDs.compactMap { SNSAppCatalog.app(catalogID: $0) }
    }

    private var automationStatusTitle: String {
        if unconfirmedAutomationTargets.count == 1,
           let target = unconfirmedAutomationTargets.first {
            return String(
                localized: "home.automation_status.title_single",
                defaultValue: "\(target.displayName)のショートカット設定を確認"
            )
        }
        return String(
            localized: "home.automation_status.title_multiple",
            defaultValue: "\(unconfirmedAutomationCatalogIDs.count)個のアプリの設定状況を確認"
        )
    }

    private var isFirstDayEmpty: Bool {
        model.todayAttemptCount == 0 && model.weekAttemptCount == 0
    }

    private func refreshSettingsMirrors() {
        liveActivityEnabled = settingsStore.liveActivityEnabled
        breathDurationSeconds = settingsStore.breathDurationSeconds
        confirmedAutomationCatalogIDs = settingsStore.confirmedAutomationCatalogIDs
        wakeTimeMinutes = settingsStore.wakeTimeMinutes
            ?? NightShieldConstants.defaultWakeTimeMinutes
        bedTimeMinutes = settingsStore.bedTimeMinutes
            ?? NightShieldConstants.defaultBedTimeMinutes
        isBlockConfigured = model.isBlockConfigured
        blockTargetRuleCount = model.blockTargetRuleCount
    }

    private var todayText: String {
        clock.formatted(.dateTime.month().day())
    }

    private func reloadDashboard(referenceDate: Date = Date()) {
        guard let statsService else {
            dashboard = .empty
            return
        }

        let calendar = Calendar.autoupdatingCurrent
        let now = referenceDate
        let todayStart = calendar.startOfDay(for: now)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)
            ?? todayStart.addingTimeInterval(86_400)
        dashboard = HomeDashboardData(
            weeklySummary: try? statsService.weeklySummary(),
            consecutiveDays: (try? statsService.consecutiveDaysWithCancellations(endingOn: now)) ?? 0,
            hasCompletedWin: ((try? statsService.cancelledAttemptsAllTime()) ?? 0) > 0,
            lifetimeReclaimedSeconds: (try? statsService.reclaimedSecondsAllTime()) ?? 0,
            todayReclaimedSeconds: (try? statsService.reclaimedSeconds(from: todayStart, to: todayEnd)) ?? 0,
            todayReclaimedCancellationCount: (
                try? statsService.reclaimedCancellationCount(from: todayStart, to: todayEnd)
            ) ?? 0,
            estimatedSecondsPerCancellation: (
                try? statsService.estimatedReclaimedSecondsPerCancellation(at: now)
            ) ?? ReclaimedTimeEstimator.defaultSeconds
        )
    }
}

private struct HomeFocusButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dopaFont(15, weight: .bold)
            .foregroundStyle(kind == .primary ? DesignTokens.background : DesignTokens.primaryText)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                kind == .primary
                    ? DesignTokens.accent
                    : (configuration.isPressed ? DesignTokens.cardPressed : DesignTokens.backgroundRaised)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(kind == .primary ? Color.clear : DesignTokens.strongHairline, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(DopaMotion.control, value: configuration.isPressed)
    }
}
