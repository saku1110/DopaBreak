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

enum HomeStatsLinkDestination: Equatable {
    case statsTab
    case statsHistoryGate

    init(weeklyReportAllowed: Bool) {
        self = weeklyReportAllowed ? .statsTab : .statsHistoryGate
    }
}

private struct HomeDashboardData {
    var weeklySummary: WeeklySummary?
    var consecutiveDays = 0
    var reclaimedSeconds = 0

    static let empty = HomeDashboardData()
}

struct HomeView: View {
    let model: AppModel
    let settingsStore: SettingsStore
    let onOpenStats: () -> Void
    private let injectedStatsService: StatsService?

    @State private var editorRoute: GoalEditorRoute?
    @State private var isAutomationGuidePresented = false
    @State private var isTargetPickerPresented = false
    @State private var paywallPlacement: PaywallPlacement?
    @State private var showPaywallAfterTargetPicker = false
    @State private var dashboard = HomeDashboardData.empty
    @State private var clock = Date()

    private static let dashboardTicker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    init(
        model: AppModel,
        settingsStore: SettingsStore,
        onOpenStats: @escaping () -> Void = {},
        statsService: StatsService? = nil
    ) {
        self.model = model
        self.settingsStore = settingsStore
        self.onOpenStats = onOpenStats
        injectedStatsService = statsService
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

                if !isFirstDayEmpty {
                    reclaimedTimeCard
                }

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
            }
            .padding(.horizontal, DesignTokens.horizontalPadding)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .dopaScreenBackground()
        .onAppear {
            model.refresh()
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
        .sheet(isPresented: $isAutomationGuidePresented) {
            AutomationGuideView(model: model, settingsStore: settingsStore)
        }
        .sheet(isPresented: $isTargetPickerPresented, onDismiss: { reloadDashboard() }) {
            TargetAppPickerSheet(model: model) {
                showPaywallAfterTargetPicker = true
            }
        }
        .fullScreenCover(item: $paywallPlacement) { placement in
            PaywallView(
                storeService: model.storeService,
                placement: placement,
                settingsStore: settingsStore
            )
        }
    }

    private var isAnyChildModalPresented: Bool {
        editorRoute != nil
            || isAutomationGuidePresented
            || isTargetPickerPresented
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
            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text("\(model.todayCancelledCount)")
                    .dopaFont(56, weight: .black, design: .rounded, tracking: -2)
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.accent)
                    .contentTransition(.numericText())
                    .dopaDisplayClamp()
                Text(String(localized: "home.achievement.count_unit", defaultValue: "回"))
                    .dopaFont(20, weight: .black)
                    .foregroundStyle(DesignTokens.accent)
            }
            .accessibilityElement(children: .combine)
            .animation(DopaMotion.control, value: model.todayCancelledCount)

            Text(String(localized: "home.achievement.title", defaultValue: "開くのをやめた"))
                .dopaFont(20, weight: .black)
                .foregroundStyle(DesignTokens.primaryText)

            Text(achievementSummary)
                .dopaFont(14, weight: .semibold)
                .foregroundStyle(DesignTokens.secondaryText)

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

    private var achievementSummary: String {
        if model.todayAttemptCount == 0 {
            return String(
                localized: "home.achievement.empty_body",
                defaultValue: "今日はまだ開こうとしていません"
            )
        }
        return String(
            localized: "home.achievement.summary",
            defaultValue: "開こうとしたのは\(model.todayAttemptCount)回"
        )
    }

    private var reclaimedTimeCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                SmallLabel(
                    text: String(localized: "home.reclaimed.title", defaultValue: "取り戻した時間")
                )

                HStack(alignment: .lastTextBaseline, spacing: 9) {
                    Text(reclaimedTimeText)
                        .dopaFont(32, weight: .black, design: .rounded, tracking: -0.7)
                        .foregroundStyle(DesignTokens.accent)
                        .contentTransition(.numericText())
                    Text(String(localized: "home.reclaimed.week_label", defaultValue: "今週"))
                        .dopaFont(13, weight: .semibold)
                        .foregroundStyle(DesignTokens.secondaryText)
                }

                if dashboard.reclaimedSeconds > 0 {
                    Text(
                        String(
                            localized: "home.reclaimed.yearly",
                            defaultValue: "この調子なら1年で約 \(yearlyReclaimedDaysText)日分"
                        )
                    )
                    .dopaFont(13, weight: .semibold)
                    .foregroundStyle(DesignTokens.secondaryText)
                }
            }
        }
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
                                defaultValue: "止めているアプリ"
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
                        String(localized: "home.targets.focus_end", defaultValue: "いま解除する")
                    ) {
                        model.endDeepFocusSession()
                        clock = Date()
                    }
                    .buttonStyle(HomeFocusButtonStyle(kind: .secondary))
                } else if showsStartDeepFocusButton {
                    Button(
                        String(localized: "home.targets.focus_30", defaultValue: "30分だけ開けなくする")
                    ) {
                        startDeepFocus()
                    }
                    .buttonStyle(HomeFocusButtonStyle(kind: .primary))
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
                    String(localized: "home.targets.empty", defaultValue: "止めるアプリを選ぶ")
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
                        defaultValue: "\(bedTimeText)から朝まで開けません"
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
                    defaultValue: "あと\(remaining) 開けません"
                )
            }
            return String(
                localized: "home.targets.night_line",
                defaultValue: "\(bedTimeText)から朝まで開けません"
            )
        }
        if isDeepFocusActive {
            if let remaining = deepFocusRemainingText {
                return String(
                    localized: "home.targets.focus_running",
                    defaultValue: "あと\(remaining) 開けません"
                )
            }
            return String(
                localized: "settings.deep_focus.session.open_ended.label",
                defaultValue: "自分で解除するまで"
            )
        }
        return String(
            localized: "home.targets.breath_line",
            defaultValue: "開く前に\(settingsStore.breathDurationSeconds)秒の間が入ります"
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
            defaultValue: "今週は\(model.weekCancelledCount)回 開くのをやめました"
        )
    }

    private var statsLinkCard: some View {
        let destination = HomeStatsLinkDestination(
            weeklyReportAllowed: model.entitlementGate.weeklyReportAllowed
        )

        return Button {
            switch destination {
            case .statsTab:
                onOpenStats()
            case .statsHistoryGate:
                paywallPlacement = .statsHistoryGate
            }
        } label: {
            CardContainer {
                HStack(spacing: 12) {
                    if destination == .statsHistoryGate {
                        Image(systemName: "lock.fill")
                            .dopaFont(13, weight: .bold)
                            .foregroundStyle(DesignTokens.secondaryText)
                            .accessibilityHidden(true)
                    }

                    Text(statsLinkTitle(for: destination))
                        .dopaFont(15, weight: .bold)
                        .foregroundStyle(DesignTokens.primaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    if destination == .statsTab {
                        Image(systemName: "chevron.right")
                            .dopaFont(13, weight: .bold)
                            .foregroundStyle(DesignTokens.secondaryText)
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private func statsLinkTitle(for destination: HomeStatsLinkDestination) -> String {
        switch destination {
        case .statsTab:
            return String(
                localized: "home.stats_link.title",
                defaultValue: "アプリごとの内訳と振り返りを見る"
            )
        case .statsHistoryGate:
            return String(
                localized: "stats.paywall.weekly_report",
                defaultValue: "記録を全部見る"
            )
        }
    }

    private var goalCard: some View {
        Button {
            editorRoute = GoalEditorRoute(goal: model.goals.first)
        } label: {
            CardContainer {
                HStack(spacing: 14) {
                    GoalCategoryTile(category: primaryGoalCategory, size: 44)

                    VStack(alignment: .leading, spacing: 7) {
                        SmallLabel(text: goalLabel)
                        Text(primaryGoalTitle)
                            .dopaFont(20, weight: .bold)
                            .foregroundStyle(hasPrimaryGoal ? DesignTokens.primaryText : DesignTokens.accent)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .dopaFont(13, weight: .bold)
                        .foregroundStyle(DesignTokens.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var goalLabel: String {
        let base = String(localized: "home.goal.label", defaultValue: "あなたの目標")
        guard hasPrimaryGoal else { return base }
        return "\(base) ・ \(primaryGoalCategory.japaneseLabel)"
    }

    private var firstDayEmptySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                String(
                    localized: "home.first_day.title",
                    defaultValue: "開こうとした瞬間に一呼吸が入ります"
                )
            )
            .dopaFont(30, weight: .black, tracking: -0.7, lineSpacing: 4)
            .foregroundStyle(DesignTokens.primaryText)
            .fixedSize(horizontal: false, vertical: true)

            Text(
                String(
                    localized: "home.first_day.body",
                    defaultValue: "開くのをやめた回数がここに残ります"
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
                        defaultValue: "対象アプリを開いたときに一呼吸が出れば設定完了です。"
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
        let persistedMode: InterventionMode
        if let rawValue = settingsStore.pendingInterventionMode,
           let mode = InterventionMode(rawValue: rawValue) {
            persistedMode = mode
        } else {
            persistedMode = (try? model.ruleStore.allRules().first?.mode) ?? .standard
        }
        return InterventionModeResolver.resolve(
            persistedMode,
            hasConfirmedEntitlement: model.storeService.hasConfirmedEntitlement,
            strictModeAllowed: model.entitlementGate.strictModeAllowed
        )
    }

    private var isNightBlockActive: Bool {
        currentMode == .nightOnly && NightWindowPolicy.isNight(
            now: clock,
            bedTimeMinutes: settingsStore.bedTimeMinutes ?? NightShieldConstants.defaultBedTimeMinutes,
            wakeTimeMinutes: settingsStore.wakeTimeMinutes ?? NightShieldConstants.defaultWakeTimeMinutes,
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

    private func startDeepFocus() {
        guard model.entitlementGate.strictModeAllowed else {
            paywallPlacement = .settingsModeGate
            return
        }
        model.startDeepFocusSession(durationMinutes: 30)
        clock = Date()
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
        let wakeMinutes = settingsStore.wakeTimeMinutes
            ?? NightShieldConstants.defaultWakeTimeMinutes
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
        let minutes = settingsStore.bedTimeMinutes ?? NightShieldConstants.defaultBedTimeMinutes
        let date = calendar.date(
            bySettingHour: minutes / 60,
            minute: minutes % 60,
            second: 0,
            of: clock
        ) ?? clock
        return Self.timeOfDayFormatter.string(from: date)
    }

    private var reclaimedTimeText: String {
        let totalMinutes = dashboard.reclaimedSeconds / 60
        if totalMinutes < 60 {
            return String(
                localized: "home.reclaimed.minutes",
                defaultValue: "\(totalMinutes)分"
            )
        }
        return String(
            localized: "home.reclaimed.hours_minutes",
            defaultValue: "\(totalMinutes / 60)時間\(totalMinutes % 60)分"
        )
    }

    private var yearlyReclaimedDaysText: String {
        let days = Double(dashboard.reclaimedSeconds) * 52 / 86_400
        let floored = floor(days * 10) / 10
        let format = floored.rounded(.towardZero) == floored ? "%.0f" : "%.1f"
        return String(format: format, locale: Locale.autoupdatingCurrent, floored)
    }

    private var primaryGoalTitle: String {
        model.goals.first?.title
            ?? String(localized: "home.goal.fallback", defaultValue: "タップして目標を追加")
    }

    private var primaryGoalCategory: GoalCategory {
        model.goals.first?.category ?? .other
    }

    private var hasPrimaryGoal: Bool {
        model.goals.first != nil
    }

    private var heroExpression: CharacterExpression {
        model.todayAttemptCount > 0 && model.todayCancelledCount == 0 ? .doom : .awake
    }

    private var unverifiedAutomationCatalogIDs: [String] {
        AutomationVerification.unverifiedCatalogIDs(
            selectedCatalogIDs: (try? model.targetStore.selectedCatalogIDs()) ?? [],
            verifiedCatalogIDs: settingsStore.verifiedAutomationCatalogIDs
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
                defaultValue: "\(target.displayName)の一呼吸はまだ動いていません"
            )
        }
        return String(
            localized: "home.automation_status.title_multiple",
            defaultValue: "\(unverifiedAutomationCatalogIDs.count)個のアプリで一呼吸がまだ動いていません"
        )
    }

    private var isFirstDayEmpty: Bool {
        model.todayAttemptCount == 0 && model.weekAttemptCount == 0
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
        let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart)
            ?? todayStart.addingTimeInterval(-6 * 86_400)
        dashboard = HomeDashboardData(
            weeklySummary: try? statsService.weeklySummary(),
            consecutiveDays: (try? statsService.consecutiveDaysWithCancellations(endingOn: now)) ?? 0,
            reclaimedSeconds: (try? statsService.reclaimedSeconds(from: weekStart, to: todayEnd)) ?? 0
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
