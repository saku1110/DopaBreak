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
        onLocked: (PaywallPlacement) -> Void,
        onSelect: (LockTheme) -> Void
    ) {
        onSelect(theme)
        if !isThemeAllowed(theme) {
            onLocked(.homeThemeGate)
        }
    }
}

private struct HomeDashboardData {
    var weeklySummary: WeeklySummary?
    var consecutiveDays = 0
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

    @State private var editorRoute: GoalEditorRoute?
    @State private var isAutomationGuidePresented = false
    @State private var isTargetPickerPresented = false
    @State private var isLockThemePickerPresented = false
    @State private var savedLockTheme: LockTheme
    @State private var paywallPlacement: PaywallPlacement?
    @State private var showPaywallAfterTargetPicker = false
    @State private var pendingThemePaywallPlacement: PaywallPlacement?
    @State private var dashboard = HomeDashboardData.empty
    @State private var clock = Date()
    @State private var liveActivityEnabled: Bool
    @State private var breathDurationSeconds: Int
    @State private var verifiedAutomationCatalogIDs: [String]
    @State private var persistedInterventionMode: InterventionMode
    @State private var wakeTimeMinutes: Int
    @State private var bedTimeMinutes: Int

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
        _savedLockTheme = State(initialValue: model.savedLockTheme)
        _liveActivityEnabled = State(initialValue: settingsStore.liveActivityEnabled)
        _breathDurationSeconds = State(initialValue: settingsStore.breathDurationSeconds)
        _verifiedAutomationCatalogIDs = State(
            initialValue: settingsStore.verifiedAutomationCatalogIDs
        )
        let storedMode = settingsStore.pendingInterventionMode
            .flatMap(InterventionMode.init(rawValue:))
            ?? (try? model.ruleStore.allRules().first?.mode)
            ?? .standard
        _persistedInterventionMode = State(initialValue: storedMode)
        _wakeTimeMinutes = State(
            initialValue: settingsStore.wakeTimeMinutes
                ?? NightShieldConstants.defaultWakeTimeMinutes
        )
        _bedTimeMinutes = State(
            initialValue: settingsStore.bedTimeMinutes
                ?? NightShieldConstants.defaultBedTimeMinutes
        )
    }

    private var statsService: StatsService? {
        injectedStatsService ?? HomeStatsProvider.shared
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                topLine

                if !unverifiedAutomationTargets.isEmpty {
                    automationStatusBanner
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

                if liveActivityEnabled {
                    lockScreenCard
                }
            }
            .padding(.horizontal, DesignTokens.horizontalPadding)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .dopaScreenBackground()
        .onAppear {
            model.refresh()
            savedLockTheme = model.savedLockTheme
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
        .onChange(of: isTargetPickerPresented) { _, isPresented in
            guard !isPresented, showPaywallAfterTargetPicker else { return }
            showPaywallAfterTargetPicker = false
            reloadDashboard()
            paywallPlacement = .settingsTargetAppLimit
        }
        .onReceive(Self.dashboardTicker) { date in
            let didRollOver = !Calendar.autoupdatingCurrent.isDate(clock, inSameDayAs: date)
            clock = date
            if didRollOver {
                reloadDashboard(referenceDate: date)
            }
        }
        .sheet(item: $editorRoute) { route in
            GoalEditorSheet(model: model, goal: route.goal)
        }
        .sheet(isPresented: $isAutomationGuidePresented, onDismiss: refreshSettingsMirrors) {
            AutomationGuideView(model: model, settingsStore: settingsStore)
        }
        .sheet(isPresented: $isTargetPickerPresented, onDismiss: { reloadDashboard() }) {
            TargetAppPickerSheet(model: model) {
                showPaywallAfterTargetPicker = true
            }
        }
        .sheet(isPresented: $isLockThemePickerPresented, onDismiss: {
            guard let placement = pendingThemePaywallPlacement else { return }
            pendingThemePaywallPlacement = nil
            paywallPlacement = placement
        }) {
            homeThemePickerSheet
        }
        .fullScreenCover(item: $paywallPlacement) { placement in
            PaywallView(
                storeService: model.storeService,
                placement: placement,
                settingsStore: settingsStore
            )
            .onAppear { onPaywallPresented?(placement) }
        }
    }

    private var isAnyChildModalPresented: Bool {
        editorRoute != nil
            || isAutomationGuidePresented
            || isTargetPickerPresented
            || isLockThemePickerPresented
            || paywallPlacement != nil
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

            VStack(alignment: .leading, spacing: 14) {
                CharacterView(heroExpression, size: 112)
                    .frame(maxWidth: .infinity)
                achievementBlock
            }
        }
        .padding(.vertical, 6)
    }

    private var achievementBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            SmallLabel(
                text: String(
                    localized: "home.hero.lifetime.title",
                    defaultValue: "SNSを開かずに取り戻した時間"
                )
            )

            HStack(alignment: .lastTextBaseline, spacing: 12) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
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

                if showsEndDeepFocusButton {
                    Button(
                        String(localized: "home.targets.focus_end", defaultValue: "完全ブロックを解除")
                    ) {
                        model.endDeepFocusSession()
                        clock = Date()
                    }
                    .buttonStyle(HomeFocusButtonStyle(kind: .secondary))
                } else if showsStartDeepFocusButton {
                    Button(
                        String(localized: "home.targets.block_settings", defaultValue: "止める強さを設定する")
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
        VStack(alignment: .trailing, spacing: 5) {
            Text(targetPrimaryStatus)
                .dopaFont(13, weight: .semibold)
                .foregroundStyle(isAnyHardBlockActive ? DesignTokens.accent : DesignTokens.primaryText)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)

            if currentMode == .nightOnly, !isNightBlockActive {
                Text(
                    String(
                        localized: "home.targets.night_line",
                        defaultValue: "\(bedTimeText)から起床時刻まで開けません"
                    )
                )
                .dopaFont(12, weight: .semibold)
                .foregroundStyle(DesignTokens.secondaryText)
                .multilineTextAlignment(.trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var targetPrimaryStatus: String {
        if isNightBlockActive {
            if let remaining = nightRemainingText {
                return String(
                    localized: "home.targets.focus_running",
                    defaultValue: "あと\(remaining)は開けません"
                )
            }
            return String(
                localized: "home.targets.night_line",
                defaultValue: "\(bedTimeText)から起床時刻まで開けません"
            )
        }
        if isDeepFocusActive {
            if let remaining = deepFocusRemainingText {
                return String(
                    localized: "home.targets.focus_running",
                    defaultValue: "あと\(remaining)は開けません"
                )
            }
            return String(
                localized: "settings.deep_focus.session.open_ended.label",
                defaultValue: "自分で解除するまで"
            )
        }
        return String(
            localized: "home.targets.breath_line",
            defaultValue: "開く前に\(breathDurationSeconds)秒の一呼吸をはさみます"
        )
    }

    private var weekCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                SmallLabel(text: String(localized: "home.week.eyebrow", defaultValue: "今週"))

                DayBars(days: dashboard.weeklySummary?.days ?? emptyWeekDays)

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

    private var homeThemePickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !model.entitlementGate.lockThemeAllowed(savedLockTheme) {
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
                        selectedTheme: savedLockTheme,
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
            onLocked: { placement in
                pendingThemePaywallPlacement = placement
                isLockThemePickerPresented = false
            },
            onSelect: { selectedTheme in
                settingsStore.lockTheme = selectedTheme
                savedLockTheme = selectedTheme
                onThemePickerSelectionChanged?(selectedTheme)
                model.refreshLockSurfaces(scheduleNotifications: false)
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
                        defaultValue: "対象アプリを開き、一呼吸の画面が表示されれば設定完了です。"
                    )
                )
                .dopaFont(14, weight: .semibold, lineSpacing: 4)
                .foregroundStyle(DesignTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                Button(
                    String(localized: "home.automation_status.action", defaultValue: "設定を確認")
                ) {
                    isAutomationGuidePresented = true
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var selectedCatalogItems: [SNSAppCatalogItem] {
        ((try? model.targetStore.selectedCatalogIDs()) ?? [])
            .compactMap { SNSAppCatalog.app(catalogID: $0) }
    }

    private var currentMode: InterventionMode {
        return InterventionModeResolver.resolve(
            persistedInterventionMode,
            hasConfirmedEntitlement: model.storeService.hasConfirmedEntitlement,
            strictModeAllowed: model.entitlementGate.strictModeAllowed
        )
    }

    private var isNightBlockActive: Bool {
        currentMode == .nightOnly && NightWindowPolicy.isNight(
            now: clock,
            bedTimeMinutes: bedTimeMinutes,
            wakeTimeMinutes: wakeTimeMinutes,
            calendar: .autoupdatingCurrent
        )
    }

    private var isManualDeepFocusActive: Bool {
        model.deepFocusSession != nil
    }

    private var isScheduledDeepFocusActive: Bool {
        currentMode == .deepFocus && model.isDeepFocusScheduleWindowActive
    }

    private var isDeepFocusActive: Bool {
        isManualDeepFocusActive || isScheduledDeepFocusActive
    }

    private var isAnyHardBlockActive: Bool {
        isNightBlockActive || isDeepFocusActive
    }

    private var showsEndDeepFocusButton: Bool {
        isManualDeepFocusActive && !isScheduledDeepFocusActive
    }

    private var showsStartDeepFocusButton: Bool {
        !isNightBlockActive && !isDeepFocusActive
    }

    private var deepFocusRemainingText: String? {
        if isManualDeepFocusActive {
            guard let seconds = model.deepFocusSessionRemainingSeconds else { return nil }
            return Self.remainingFormatter.string(from: max(60, seconds.rounded(.up)))
        }
        guard isScheduledDeepFocusActive, let seconds = scheduleRemainingSeconds else { return nil }
        return Self.remainingFormatter.string(from: max(60, seconds.rounded(.up)))
    }

    private var scheduleRemainingSeconds: TimeInterval? {
        guard model.isDeepFocusScheduleWindowActive else { return nil }
        let calendar = Calendar.autoupdatingCurrent
        let endMinutes = DeepFocusWindowPolicy.normalizedMinutes(model.deepFocusSchedule.endMinutes)
        let startOfDay = calendar.startOfDay(for: clock)
        guard var end = calendar.date(byAdding: .minute, value: endMinutes, to: startOfDay) else {
            return nil
        }
        if end <= clock {
            end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        }
        return max(0, end.timeIntervalSince(clock))
    }

    private var nightRemainingText: String? {
        let calendar = Calendar.autoupdatingCurrent
        let wakeMinutes = wakeTimeMinutes
        let startOfDay = calendar.startOfDay(for: clock)
        guard var wake = calendar.date(byAdding: .minute, value: wakeMinutes, to: startOfDay) else {
            return nil
        }
        if wake <= clock {
            wake = calendar.date(byAdding: .day, value: 1, to: wake) ?? wake
        }
        return Self.remainingFormatter.string(from: max(60, wake.timeIntervalSince(clock)))
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

    private var unverifiedAutomationCatalogIDs: [String] {
        AutomationVerification.unverifiedCatalogIDs(
            selectedCatalogIDs: (try? model.targetStore.selectedCatalogIDs()) ?? [],
            verifiedCatalogIDs: verifiedAutomationCatalogIDs
        )
    }

    private var unverifiedAutomationTargets: [SNSAppCatalogItem] {
        unverifiedAutomationCatalogIDs.compactMap { SNSAppCatalog.app(catalogID: $0) }
    }

    private var automationStatusTitle: String {
        if unverifiedAutomationTargets.count == 1,
           let target = unverifiedAutomationTargets.first {
            return String(
                localized: "home.automation_status.title_single",
                defaultValue: "\(target.displayName)で一呼吸の設定が完了していません"
            )
        }
        return String(
            localized: "home.automation_status.title_multiple",
            defaultValue: "\(unverifiedAutomationCatalogIDs.count)個のアプリで一呼吸の設定が完了していません"
        )
    }

    private var isFirstDayEmpty: Bool {
        model.todayAttemptCount == 0 && model.weekAttemptCount == 0
    }

    private func refreshSettingsMirrors() {
        liveActivityEnabled = settingsStore.liveActivityEnabled
        breathDurationSeconds = settingsStore.breathDurationSeconds
        verifiedAutomationCatalogIDs = settingsStore.verifiedAutomationCatalogIDs
        persistedInterventionMode = settingsStore.pendingInterventionMode
            .flatMap(InterventionMode.init(rawValue:))
            ?? (try? model.ruleStore.allRules().first?.mode)
            ?? .standard
        wakeTimeMinutes = settingsStore.wakeTimeMinutes
            ?? NightShieldConstants.defaultWakeTimeMinutes
        bedTimeMinutes = settingsStore.bedTimeMinutes
            ?? NightShieldConstants.defaultBedTimeMinutes
    }

    private var todayText: String {
        clock.formatted(.dateTime.month().day())
    }

    private var emptyWeekDays: [WeeklySummary.Day] {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: clock)
        return (0..<7).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index - 6, to: today) else {
                return nil
            }
            return WeeklySummary.Day(date: date, attempts: 0, cancelled: 0)
        }
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
