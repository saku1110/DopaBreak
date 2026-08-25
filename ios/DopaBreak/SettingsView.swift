import DopaBreakCore
import FamilyControls
import ManagedSettings
import SwiftUI
import UIKit

struct SettingsView: View {
    let model: AppModel
    let settingsStore: SettingsStore
    let onResetOnboarding: () -> Void

    #if DEBUG
    private let snapshotScreenTimeAuthorized: Bool?
    #endif

    init(
        model: AppModel,
        settingsStore: SettingsStore,
        onResetOnboarding: @escaping () -> Void
    ) {
        self.model = model
        self.settingsStore = settingsStore
        self.onResetOnboarding = onResetOnboarding
        #if DEBUG
        self.snapshotScreenTimeAuthorized = nil
        #endif
    }

    #if DEBUG
    /// App Store素材撮影用。AuthorizationCenterの実状態は変更せず、認可行の表示だけを
    /// 決定的に差し替える。本番のinitializerからは指定できない。
    init(
        snapshotModel model: AppModel,
        settingsStore: SettingsStore,
        screenTimeAuthorized: Bool,
        onResetOnboarding: @escaping () -> Void
    ) {
        self.model = model
        self.settingsStore = settingsStore
        self.onResetOnboarding = onResetOnboarding
        self.snapshotScreenTimeAuthorized = screenTimeAuthorized
    }
    #endif

    @State private var rules: [TargetRule] = []
    @State private var selectedMode: InterventionMode = .standard
    @State private var activitySelection = FamilyActivitySelection()
    @State private var isAuthorizationSheetPresented = false
    @State private var isFamilyActivityPickerPresented = false
    @State private var authorizationWasDenied = false
    @State private var isRequestingAuthorization = false
    @State private var shouldOpenPickerAfterAuthorization = false
    @State private var usageWatchSelection = FamilyActivitySelection()
    @State private var isUsageWatchPickerPresented = false
    @State private var shouldEnableUsageWatchAfterPicker = false
    @State private var usageWatchAuthorizationWasDenied = false
    @State private var isRequestingUsageWatchAuthorization = false
    @State private var paywallPlacement: PaywallPlacement?
    @State private var isTargetPickerPresented = false
    @State private var shouldPresentTargetAppPaywallAfterDismiss = false
    @State private var isAutomationGuidePresented = false
    @State private var gateAppSettingTarget: GateAppSettingTarget?
    @State private var isLockScreenCheckPresented = false
    @State private var isDeleteAllDataConfirmationPresented = false
    @State private var isDeletionFeedbackVisible = false
    @State private var morningNotificationEnabled = true
    @State private var weeklyReportNotificationEnabled = true
    @State private var retentionSupportNotificationsEnabled = true
    @State private var planNotificationsEnabled = true
    @State private var liveActivityEnabled = true
    @State private var selectedLockTheme: LockTheme = .e1
    @State private var selectedSessionOption: DeepFocusSessionOption = .oneHour
    @State private var deepFocusSchedule: DeepFocusSchedule = .disabled
    /// 進行中の回。1秒ごとの再描画で残り時間を出し、0になった瞬間に同期へ回す。
    @State private var deepFocusSession: DeepFocusSession?
    @State private var deepFocusRemainingSeconds: TimeInterval?
    /// いま予定の時間帯に入っているか。入っているあいだは解除の導線を出さない。
    @State private var isScheduleWindowActive = false
    @State private var isWakeTimePickerPresented = false
    @State private var isBedTimePickerPresented = false
    @State private var isPlanEntryHighlighted = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 曜日チップの並び。月曜から日曜（`Calendar` の番号では2から始まり1で終わる）。
    private static let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]

    private static let deepFocusTicker = Timer.publish(every: 1, on: .main, in: .common)
        .autoconnect()

    /// 「いますぐ」の4択。`durationMinutes` が `nil` なら「自分で解除するまで」。
    enum DeepFocusSessionOption: Hashable, CaseIterable {
        case thirtyMinutes
        case oneHour
        case twoHours
        case untilStopped

        var durationMinutes: Int? {
            switch self {
            case .thirtyMinutes:
                return 30
            case .oneHour:
                return 60
            case .twoHours:
                return 120
            case .untilStopped:
                return nil
            }
        }

        var title: String {
            switch self {
            case .thirtyMinutes:
                return String(
                    localized: "settings.deep_focus.session.option.thirty_minutes",
                    defaultValue: "30分"
                )
            case .oneHour:
                return String(
                    localized: "settings.deep_focus.session.option.one_hour",
                    defaultValue: "1時間"
                )
            case .twoHours:
                return String(
                    localized: "settings.deep_focus.session.option.two_hours",
                    defaultValue: "2時間"
                )
            case .untilStopped:
                return String(
                    localized: "settings.deep_focus.session.option.until_stopped",
                    defaultValue: "解除するまで"
                )
            }
        }
    }

    /// プラン系通知のタップで送り込む先（docs/18 §2f）。
    private static let planSectionID = "settings.section.account"

    var body: some View {
        NavigationStack {
            // プラン欄は5番目のセクションで初期表示に入らないため、通知からの着地では自力で送る。
            ScrollViewReader { proxy in
                settingsScroll
                    .onAppear {
                        scrollToPlanSectionIfRequested(proxy: proxy)
                    }
                    .onChange(of: model.pendingPlanSettingsFocus) { _, _ in
                        scrollToPlanSectionIfRequested(proxy: proxy)
                    }
            }
            // 自前のScreenHeaderをやめ、システムの大見出しへ寄せた。
            .navigationTitle(String(localized: "settings.header.title", defaultValue: "設定"))
            .navigationBarTitleDisplayMode(.large)
        }
        .tint(DesignTokens.accent)
    }

    /// 通知タップの要求があればプラン欄まで送る。
    /// onAppearから呼ぶ経路があるため、レイアウト確定後に走るよう1フレーム置く。
    private func scrollToPlanSectionIfRequested(proxy: ScrollViewProxy) {
        guard model.pendingPlanSettingsFocus else {
            return
        }
        model.pendingPlanSettingsFocus = false
        Task { @MainActor in
            await Task.yield()
            withAnimation(DopaMotion.transition) {
                proxy.scrollTo(Self.planSectionID, anchor: .center)
                isPlanEntryHighlighted = true
            }
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            withAnimation(DopaMotion.control) {
                isPlanEntryHighlighted = false
            }
        }
    }

    /// シート提示や状態同期はスクロール本体に付けたまま、NavigationStackで包むだけにする。
    private var settingsScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                statusSection
                modeSection

                if isDeepFocusUnlocked, selectedMode == .deepFocus {
                    deepFocusControlsSection
                } else if !isDeepFocusUnlocked {
                    deepFocusLockedSection
                }

                targetLengthAutomationSection
                wakeSleepTimelineSection
                entrySection
                aboutEntrySection

                Text(
                    String(
                        localized: "settings.device_only_note",
                        defaultValue: "SNSなどのアプリを止める機能はiPhoneでのみ使えます"
                    )
                )
                    .dopaFont(13, weight: .medium)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, DesignTokens.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .dopaScreenBackground()
        .onAppear {
            refreshSettingsState()
            model.isChildModalActive = isAnyChildModalPresented
            presentAutomationGuideIfRequested()
        }
        .onChange(of: isAnyChildModalPresented) { _, isPresented in
            model.isChildModalActive = isPresented
            if !isPresented {
                presentAutomationGuideIfRequested()
            }
        }
        .onChange(of: model.pendingAutomationGuideRequest) { _, _ in
            presentAutomationGuideIfRequested()
        }
        .sheet(isPresented: $isAuthorizationSheetPresented) {
            authorizationSheet
        }
        .familyActivityPicker(
            isPresented: $isFamilyActivityPickerPresented,
            selection: $activitySelection
        )
        .fullScreenCover(item: $paywallPlacement, onDismiss: {
            refreshSettingsState()
        }) { placement in
            PaywallView(
                storeService: model.storeService,
                placement: placement,
                settingsStore: settingsStore
            )
        }
        .sheet(isPresented: $isTargetPickerPresented, onDismiss: {
            guard shouldPresentTargetAppPaywallAfterDismiss else {
                return
            }
            shouldPresentTargetAppPaywallAfterDismiss = false
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                paywallPlacement = .settingsTargetAppLimit
            }
        }) {
            TargetAppPickerSheet(model: model) {
                shouldPresentTargetAppPaywallAfterDismiss = true
            }
        }
        .sheet(isPresented: $isAutomationGuidePresented) {
            AutomationGuideView(model: model, settingsStore: settingsStore)
        }
        .sheet(item: $gateAppSettingTarget) { target in
            GateAppSettingSheet(target: target, model: model)
        }
        .fullScreenCover(isPresented: $isLockScreenCheckPresented, onDismiss: {
            // 確認画面はアプリ内トグルを必要に応じてオンへ戻すため、表示値を取り直す。
            refreshSettingsState()
        }) {
            LockScreenCheckSheet(model: model) {
                isLockScreenCheckPresented = false
            }
        }
        .onChange(of: isAuthorizationSheetPresented) { oldValue, newValue in
            guard oldValue, !newValue else {
                return
            }
            defer { shouldOpenPickerAfterAuthorization = false }
            if shouldOpenPickerAfterAuthorization, model.screenTime.isAuthorized {
                presentFamilyActivityPicker()
            }
        }
        .onChange(of: isFamilyActivityPickerPresented) { oldValue, newValue in
            guard oldValue, !newValue else {
                return
            }
            saveActivitySelection()
        }
        .onReceive(Self.deepFocusTicker) { _ in
            tickDeepFocusSession()
        }
    }

    /// D1/D3/D7通知のタップで設定ガイドを開く（docs/18 §2f）。
    /// 他のシートが出ている間は開かず、閉じた時点で改めて開く。
    private func presentAutomationGuideIfRequested() {
        guard model.pendingAutomationGuideRequest,
              !isAnyChildModalPresented else {
            return
        }
        model.pendingAutomationGuideRequest = false
        isAutomationGuidePresented = true
    }

    private var isAnyChildModalPresented: Bool {
        isAuthorizationSheetPresented
            || isFamilyActivityPickerPresented
            || isUsageWatchPickerPresented
            || paywallPlacement != nil
            || isTargetPickerPresented
            || isAutomationGuidePresented
            || gateAppSettingTarget != nil
            || isLockScreenCheckPresented
            || isDeleteAllDataConfirmationPresented
    }

    private var statusSection: some View {
        CardContainer {
            ViewThatFits(in: .horizontal) {
                statusHorizontalLayout
                statusCompactLayout
            }
        }
    }

    private var statusHorizontalLayout: some View {
        HStack(spacing: 12) {
            DopaRing(
                progress: todayCancellationRate,
                expression: statusExpression,
                diameter: 64
            )

            statusTextBlock
                .frame(maxWidth: .infinity, alignment: .leading)

            todayCancellationBlock
        }
    }

    private var statusCompactLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                DopaRing(
                    progress: todayCancellationRate,
                    expression: statusExpression,
                    diameter: 64
                )
                statusTextBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            todayCancellationBlock
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var statusTextBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            SmallLabel(
                text: String(localized: "settings.status.title", defaultValue: "止める設定")
            )

            if canEndDeepFocusFromStatus {
                Button {
                    model.endDeepFocusSession()
                    refreshDeepFocusState()
                } label: {
                    Text(statusSummary)
                        .dopaFont(16, weight: .bold)
                        .foregroundStyle(DesignTokens.primaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.plain)
                .frame(minHeight: DesignTokens.minTapTarget, alignment: .leading)
            } else {
                Text(statusSummary)
                    .dopaFont(16, weight: .bold)
                    .foregroundStyle(DesignTokens.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !statusIconSources.isEmpty {
                AppIconStack(sources: statusIconSources, size: 30, maxVisible: 4)
            }
        }
    }

    private var todayCancellationBlock: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(model.todayCancelledCount.formatted())
                .dopaFont(22, weight: .black, design: .rounded)
                .foregroundStyle(DesignTokens.accent)
                .monospacedDigit()
                .contentTransition(.numericText())

            Text(
                "\(String(localized: "stats.period.today", defaultValue: "今日")) \(String(localized: "home.achievement.title", defaultValue: "開くのをやめた"))"
            )
            .dopaFont(11, weight: .semibold)
            .foregroundStyle(DesignTokens.secondaryText)
            .multilineTextAlignment(.trailing)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var modeSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                SmallLabel(
                    text: String(localized: "settings.mode.label", defaultValue: "止める強さ")
                )

                LazyVGrid(columns: modeColumns, alignment: .leading, spacing: 8) {
                    ForEach(InterventionMode.selectable, id: \.self) { mode in
                        modeCard(mode)
                    }
                }
            }
        }
    }

    private var modeColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    }

    private func modeCard(_ mode: InterventionMode) -> some View {
        let isSelected = selectedMode == mode
        let isLocked = mode.usesShield && !isDeepFocusUnlocked

        return Button {
            setSelectedMode(mode)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    SettingsIconTile(
                        systemName: modeSymbolName(mode),
                        background: isSelected
                            ? DesignTokens.accent.opacity(0.14)
                            : Color(red: 44 / 255, green: 49 / 255, blue: 57 / 255),
                        foreground: isSelected ? DesignTokens.accent : .white
                    )

                    Spacer(minLength: 4)

                    if isLocked {
                        Text(String(localized: "settings.status.pro", defaultValue: "Pro"))
                            .dopaFont(9, weight: .black)
                            .foregroundStyle(DesignTokens.primaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(DesignTokens.backgroundRaised)
                            .clipShape(Capsule())
                    }
                }

                // 3列だと「ディープフォーカス」が1行に収まらない。強さの名前が読めないと
                // どれを選んでいるか分からなくなるため、名前だけは折り返して全部出す。
                Text(mode.displayTitle)
                    .dopaFont(13, weight: .bold)
                    .foregroundStyle(DesignTokens.primaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(mode.detailText)
                    .dopaFont(11, weight: .medium, lineSpacing: 2)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .topLeading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .background(isSelected ? DesignTokens.accent.opacity(0.06) : DesignTokens.backgroundRaised)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? DesignTokens.accent : DesignTokens.hairline, lineWidth: isSelected ? 2 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(4)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? DesignTokens.accent.opacity(0.12) : .clear, lineWidth: 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func modeSymbolName(_ mode: InterventionMode) -> String {
        switch mode {
        case .standard: return "wind"
        case .deepFocus: return "lock.shield.fill"
        case .nightOnly: return "moon.stars.fill"
        }
    }

    private var deepFocusControlsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardContainer {
                VStack(spacing: 0) {
                    deepFocusSessionBlock
                    SettingsDivider()
                    deepFocusScheduleBlock
                }
            }

            Text(deepFocusFootnote)
                .dopaFont(13, weight: .medium, lineSpacing: 3)
                .foregroundStyle(DesignTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
    }

    private var deepFocusLockedSection: some View {
        CardContainer {
            Button {
                paywallPlacement = .settingsModeGate
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    SettingsIconTile(systemName: "lock.fill")

                    Text(
                        String(
                            localized: "settings.deep_focus.locked_notice",
                            defaultValue: "完全ブロックでは決めた時間だけ選んだアプリを止められます"
                        )
                    )
                    .dopaFont(13, weight: .semibold, lineSpacing: 3)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    Label(
                        String(localized: "settings.status.pro", defaultValue: "Pro"),
                        systemImage: "lock.fill"
                    )
                    .dopaFont(12, weight: .bold)
                    .foregroundStyle(DesignTokens.primaryText)

                    SettingsChevron()
                }
                .frame(minHeight: DesignTokens.minTapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var targetLengthAutomationSection: some View {
        CardContainer {
            VStack(spacing: 0) {
                appSelectionRow

                if isGateUnlocked, !selectedGateApps.isEmpty {
                    SettingsDivider()
                    gateAppSettingsRows
                }

                if isGateUnlocked {
                    Text(
                        String(
                            localized: "settings.gate.description",
                            defaultValue: "開く前に必ず一呼吸。回数や長さはアプリごとに決められます"
                        )
                    )
                    .dopaFont(13, weight: .medium, lineSpacing: 3)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                }

                if !isGateUnlocked, let targetAppClampNotice = model.targetAppClampNotice {
                    Text(targetAppClampNotice)
                        .dopaFont(13, weight: .semibold)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 10)
                }

                SettingsDivider()
                breathDurationRow

                SettingsDivider()
                automationRow

                // 許可がないと一呼吸そのものが出ない。許可の状態と取り直しの入口は
                // 対象・長さと同じカードに残す（再構成前は完全ブロックの枠にあった）。
                if isDeepFocusUnlocked {
                    SettingsDivider()
                    screenTimeRow
                }

                if isGateUnlocked {
                    gateAutomationNotes
                } else {
                    SettingsDivider()
                    gateLockedRow
                }
            }
        }
    }

    private var appSelectionRow: some View {
        Button {
            if isGateUnlocked {
                handleAppSelectionTap()
            } else {
                isTargetPickerPresented = true
            }
        } label: {
            HStack(spacing: 12) {
                SettingsIconTile(
                    systemName: "square.grid.2x2.fill",
                    background: DesignTokens.accent,
                    foreground: .black
                )

                Text(String(localized: "settings.gate.section", defaultValue: "止めるアプリ"))
                    .dopaFont(16, weight: .semibold)
                    .foregroundStyle(DesignTokens.primaryText)

                Spacer(minLength: 8)

                if targetRowIconSources.isEmpty {
                    Text(String(localized: "settings.value.not_set", defaultValue: "未設定"))
                        .dopaFont(13, weight: .semibold)
                        .foregroundStyle(DesignTokens.secondaryText)
                } else {
                    AppIconStack(sources: targetRowIconSources, size: 24, maxVisible: 4)
                }

                SettingsChevron()
            }
            .frame(minHeight: DesignTokens.minTapTarget)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isGateUnlocked && isRequestingAuthorization)
    }

    private var gateAppSettingsRows: some View {
        VStack(spacing: 0) {
            Text(
                String(
                    localized: "settings.gate.app_list",
                    defaultValue: "アプリごとの設定"
                )
            )
            .dopaFont(13, weight: .bold)
            .foregroundStyle(DesignTokens.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
            .padding(.bottom, 6)

            ForEach(Array(selectedGateApps.enumerated()), id: \.element.id) { index, target in
                if index > 0 {
                    SettingsDivider()
                        .padding(.leading, 36)
                }

                Button {
                    gateAppSettingTarget = target
                } label: {
                    HStack(spacing: 12) {
                        AppIconView(source: .token(target.token), size: 24)

                        Label(target.token)
                            .labelStyle(.titleOnly)
                            .dopaFont(16, weight: .semibold)
                            .foregroundStyle(DesignTokens.primaryText)
                            .lineLimit(1)

                        Spacer(minLength: 8)
                        SettingsChevron()
                    }
                    .frame(minHeight: DesignTokens.minTapTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var breathDurationRow: some View {
        HStack(spacing: 10) {
            SettingsIconTile(systemName: "clock")

            Text(String(localized: "settings.breath_duration.label", defaultValue: "一呼吸の長さ"))
                .dopaFont(16, weight: .semibold)
                .foregroundStyle(DesignTokens.primaryText)
                .layoutPriority(1)

            Spacer(minLength: 2)

            HStack(spacing: 5) {
                breathDurationChip(
                    3,
                    title: String(
                        localized: "settings.breath_duration.three_seconds",
                        defaultValue: "3秒"
                    )
                )
                breathDurationChip(
                    5,
                    title: String(
                        localized: "settings.breath_duration.five_seconds",
                        defaultValue: "5秒"
                    )
                )
                breathDurationChip(
                    8,
                    title: String(
                        localized: "settings.breath_duration.eight_seconds",
                        defaultValue: "8秒"
                    )
                )
            }
        }
        .padding(.vertical, 8)
    }

    private func breathDurationChip(_ seconds: Int, title: String) -> some View {
        let isSelected = settingsStore.breathDurationSeconds == seconds

        return Button {
            settingsStore.breathDurationSeconds = seconds
        } label: {
            Text(title)
                .dopaFont(12, weight: .bold)
                .foregroundStyle(isSelected ? DesignTokens.accent : DesignTokens.secondaryText)
                .padding(.horizontal, 8)
                .frame(minHeight: 32)
                .overlay {
                    Capsule()
                        .stroke(isSelected ? DesignTokens.accent : DesignTokens.hairline, lineWidth: 1)
                }
                .frame(minHeight: DesignTokens.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var automationRow: some View {
        Button {
            isAutomationGuidePresented = true
        } label: {
            SettingsIconNavigationRow(
                systemName: "bolt.fill",
                label: String(
                    localized: "settings.target.automation",
                    defaultValue: "自動で一呼吸を出す設定"
                ),
                value: isAutomationConfigured
                    ? String(
                        localized: "settings.automation.configured",
                        defaultValue: "設定済み"
                    )
                    : String(
                        localized: "settings.automation.not_configured",
                        defaultValue: "未設定"
                    ),
                valueColor: isAutomationConfigured
                    ? DesignTokens.accent
                    : DesignTokens.secondaryText
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var screenTimeRow: some View {
        if screenTimeAuthorizedForDisplay {
            HStack(spacing: 12) {
                SettingsIconTile(systemName: "checkmark.shield.fill")

                Text(
                    String(
                        localized: "settings.screen_time.label",
                        defaultValue: "スクリーンタイム"
                    )
                )
                .dopaFont(16, weight: .semibold)
                .foregroundStyle(DesignTokens.primaryText)

                Spacer(minLength: 8)

                Text(
                    String(
                        localized: "settings.screen_time.authorized",
                        defaultValue: "許可済み"
                    )
                )
                .dopaFont(13, weight: .semibold)
                .foregroundStyle(DesignTokens.secondaryText)
            }
            .frame(minHeight: DesignTokens.minTapTarget)
            .padding(.vertical, 8)
        } else {
            Button {
                shouldOpenPickerAfterAuthorization = false
                authorizationWasDenied = false
                isAuthorizationSheetPresented = true
            } label: {
                SettingsIconNavigationRow(
                    systemName: "checkmark.shield.fill",
                    label: String(
                        localized: "settings.screen_time.label",
                        defaultValue: "スクリーンタイム"
                    ),
                    value: String(
                        localized: "settings.screen_time.not_authorized",
                        defaultValue: "未許可"
                    )
                )
            }
            .buttonStyle(.plain)
        }
    }

    /// App Store素材の撮影では許可済みの見た目を固定する。本番経路は実状態のまま。
    private var screenTimeAuthorizedForDisplay: Bool {
        #if DEBUG
        if let snapshotScreenTimeAuthorized {
            return snapshotScreenTimeAuthorized
        }
        #endif
        return model.screenTime.isAuthorized
    }

    private var gateAutomationNotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                String(
                    localized: "settings.gate.automation_note",
                    defaultValue: "Proの止めるアプリではショートカットの自動化は不要です"
                )
            )
            Text(
                String(
                    localized: "settings.gate.category_note",
                    defaultValue: "カテゴリ選択は完全ブロックでだけ使われます。開く前の一呼吸はアプリ単位です"
                )
            )
        }
        .dopaFont(13, weight: .medium, lineSpacing: 3)
        .foregroundStyle(DesignTokens.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }

    private var gateLockedRow: some View {
        Button {
            paywallPlacement = .settingsGateGate
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.fill")
                    .dopaFont(14, weight: .bold)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .frame(width: 20)

                Text(
                    String(
                        localized: "settings.gate.locked_notice",
                        defaultValue: "Proにするとショートカット設定なしで開く前に必ず止まり回数や待ち時間も決められます"
                    )
                )
                .dopaFont(13, weight: .semibold, lineSpacing: 3)
                .foregroundStyle(DesignTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
                SettingsChevron()
            }
            .frame(minHeight: DesignTokens.minTapTarget)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var wakeSleepTimelineSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    SmallLabel(
                        text: String(
                            localized: "settings.schedule.section",
                            defaultValue: "起床・就寝時刻"
                        )
                    )

                    Spacer(minLength: 8)

                    if selectedMode == .nightOnly {
                        Text(InterventionMode.nightOnly.detailText)
                            .dopaFont(11, weight: .semibold)
                            .foregroundStyle(DesignTokens.secondaryText)
                            .lineLimit(1)
                    }
                }

                timelineBar

                HStack(alignment: .firstTextBaseline) {
                    Text("0:00")
                    Spacer()
                    Text(
                        "\(timelineTimeText(settingsStore.wakeTimeMinutes ?? 420)) \(String(localized: "settings.timeline.wake", defaultValue: "起床"))"
                    )
                    Spacer()
                    Text(
                        "\(timelineTimeText(settingsStore.bedTimeMinutes ?? 1_380)) \(String(localized: "settings.timeline.sleep", defaultValue: "就寝"))"
                    )
                }
                .dopaFont(11, weight: .medium, design: .monospaced)
                .foregroundStyle(DesignTokens.secondaryText)
            }
        }
        .popover(isPresented: $isWakeTimePickerPresented, arrowEdge: .top) {
            timelineTimePicker(
                title: String(localized: "settings.timeline.wake", defaultValue: "起床"),
                selection: wakeTimeBinding
            )
        }
        .popover(isPresented: $isBedTimePickerPresented, arrowEdge: .top) {
            timelineTimePicker(
                title: String(localized: "settings.timeline.sleep", defaultValue: "就寝"),
                selection: bedTimeBinding
            )
        }
    }

    private var timelineBar: some View {
        GeometryReader { proxy in
            let horizontalInset: CGFloat = 17
            let barWidth = max(1, proxy.size.width - horizontalInset * 2)
            let wake = CGFloat(SettingsTime.normalizedMinutes(settingsStore.wakeTimeMinutes ?? 420))
                / 1_440
            let bed = CGFloat(SettingsTime.normalizedMinutes(settingsStore.bedTimeMinutes ?? 1_380))
                / 1_440

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color(red: 44 / 255, green: 49 / 255, blue: 57 / 255))

                if bed < wake {
                    Rectangle()
                        .fill(Color(red: 27 / 255, green: 42 / 255, blue: 74 / 255))
                        .frame(width: max(1, (wake - bed) * barWidth))
                        .offset(x: bed * barWidth)
                } else {
                    Rectangle()
                        .fill(Color(red: 27 / 255, green: 42 / 255, blue: 74 / 255))
                        .frame(width: max(1, (1 - bed) * barWidth))
                        .offset(x: bed * barWidth)
                    Rectangle()
                        .fill(Color(red: 27 / 255, green: 42 / 255, blue: 74 / 255))
                        .frame(width: max(1, wake * barWidth))
                }
            }
            .frame(width: barWidth, height: 26)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .position(x: proxy.size.width / 2, y: 22)

            timelineHandle(
                systemName: "sun.max.fill",
                label: String(localized: "settings.timeline.wake", defaultValue: "起床")
            ) {
                isWakeTimePickerPresented = true
            }
            .position(x: horizontalInset + wake * barWidth, y: 22)

            timelineHandle(
                systemName: "moon.fill",
                label: String(localized: "settings.timeline.sleep", defaultValue: "就寝")
            ) {
                isBedTimePickerPresented = true
            }
            .position(x: horizontalInset + bed * barWidth, y: 22)
        }
        .frame(height: 44)
    }

    private func timelineHandle(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .dopaFont(15, weight: .bold)
                .foregroundStyle(.black)
                .frame(width: 34, height: 34)
                .background(.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
                .frame(width: DesignTokens.minTapTarget, height: DesignTokens.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func timelineTimePicker(title: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .dopaFont(17, weight: .bold)
                .foregroundStyle(DesignTokens.primaryText)

            DatePicker(title, selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(DesignTokens.accent)
        }
        .padding(20)
        .frame(minWidth: 220)
        .background(DesignTokens.card)
        .presentationCompactAdaptation(.popover)
    }

    private func timelineTimeText(_ minutes: Int) -> String {
        let value = SettingsTime.normalizedMinutes(minutes)
        return String(format: "%d:%02d", value / 60, value % 60)
    }

    private var entrySection: some View {
        CardContainer {
            VStack(spacing: 0) {
                NavigationLink {
                    SettingsNotificationsView(
                        model: model,
                        settingsStore: settingsStore,
                        morningNotificationEnabled: $morningNotificationEnabled,
                        weeklyReportNotificationEnabled: $weeklyReportNotificationEnabled,
                        retentionSupportNotificationsEnabled: $retentionSupportNotificationsEnabled,
                        planNotificationsEnabled: $planNotificationsEnabled,
                        usageWatchSelection: $usageWatchSelection,
                        isUsageWatchPickerPresented: $isUsageWatchPickerPresented,
                        shouldEnableUsageWatchAfterPicker: $shouldEnableUsageWatchAfterPicker,
                        usageWatchAuthorizationWasDenied: $usageWatchAuthorizationWasDenied,
                        isRequestingUsageWatchAuthorization: $isRequestingUsageWatchAuthorization,
                        paywallPlacement: $paywallPlacement
                    )
                } label: {
                    SettingsIconNavigationRow(
                        systemName: "bell.fill",
                        label: String(
                            localized: "settings.entry.notifications",
                            defaultValue: "通知"
                        ),
                        value: notificationSummary
                    )
                }
                .buttonStyle(.plain)

                SettingsDivider()

                NavigationLink {
                    SettingsLockSurfaceView(
                        model: model,
                        settingsStore: settingsStore,
                        selectedLockTheme: $selectedLockTheme,
                        liveActivityEnabled: $liveActivityEnabled,
                        isLockScreenCheckPresented: $isLockScreenCheckPresented,
                        paywallPlacement: $paywallPlacement
                    )
                } label: {
                    SettingsIconNavigationRow(
                        systemName: "lock.iphone",
                        label: String(
                            localized: "settings.entry.lock_surface",
                            defaultValue: "ロック画面の表示"
                        ),
                        value: selectedLockTheme.displayName
                    )
                }
                .buttonStyle(.plain)

                SettingsDivider()

                NavigationLink {
                    SettingsAccountView(
                        model: model,
                        paywallPlacement: $paywallPlacement
                    )
                } label: {
                    SettingsIconNavigationRow(
                        systemName: "star.fill",
                        label: String(localized: "settings.entry.pro", defaultValue: "DopaBreak Pro"),
                        value: model.storeService.isPro
                            ? String(localized: "settings.status.pro", defaultValue: "Pro")
                            : String(localized: "settings.status.free", defaultValue: "Free"),
                        tileBackground: Color(red: 245 / 255, green: 143 / 255, blue: 180 / 255),
                        tileForeground: .black
                    )
                    .padding(.horizontal, 6)
                    .background(
                        isPlanEntryHighlighted
                            ? DesignTokens.accent.opacity(0.12)
                            : Color.clear
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isPlanEntryHighlighted ? DesignTokens.accent : .clear,
                                lineWidth: 1
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .id(Self.planSectionID)
            }
        }
    }

    private var aboutEntrySection: some View {
        CardContainer {
            NavigationLink {
                SettingsAboutView(
                    model: model,
                    onResetOnboarding: onResetOnboarding,
                    onDataDeleted: refreshSettingsState,
                    isDeleteAllDataConfirmationPresented: $isDeleteAllDataConfirmationPresented,
                    isDeletionFeedbackVisible: $isDeletionFeedbackVisible
                )
            } label: {
                SettingsIconNavigationRow(
                    systemName: "info.circle",
                    label: String(
                        localized: "settings.entry.about",
                        defaultValue: "プライバシーとアプリ情報"
                    )
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 完全ブロックの窓

    /// 「いますぐ」で始める枠。実行中は残り時間と解除だけを出す。
    private var deepFocusSessionBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 予定の時間帯に入っているあいだは、行そのものが「予定の時間帯」と名乗る。
            // 見出しを重ねると、始める操作ができない枠に「いますぐ始める」が残って読みづらい。
            if !isScheduleWindowActive {
                Text(
                    String(
                        localized: "settings.deep_focus.session.label",
                        defaultValue: "いますぐ始める"
                    )
                )
                .dopaFont(16, weight: .semibold)
                .foregroundStyle(DesignTokens.primaryText)
            }

            // 予定の時間帯に入っているあいだは「いま解除」を出さない。
            // 押しても予定のぶんが残って開かないため、効かないボタンを見せることになる。
            if isScheduleWindowActive {
                scheduleWindowRow
            } else if deepFocusSession != nil {
                runningSessionRow
            } else {
                sessionOptionChips
                startSessionButton
            }
        }
        .padding(.vertical, 14)
    }

    /// 予定の時間帯に入っているあいだの表示。いつまで続くかを時刻で示す。
    private var scheduleWindowRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(
                    String(
                        localized: "settings.deep_focus.schedule.active.label",
                        defaultValue: "予定の時間帯"
                    )
                )
                .dopaFont(16, weight: .bold)
                .foregroundStyle(DesignTokens.accent)

                Spacer()

                Text(scheduleWindowUntilText)
                    .dopaFont(16, weight: .bold)
                    .foregroundStyle(DesignTokens.accent)
                    .monospacedDigit()
            }

            // 予定が終わったあとも続くぶんがあるなら、そのことを先に書いておく。
            // 黙っていると、22時を過ぎても開かない理由が誰にも分からない。
            if deepFocusSession != nil {
                Text(
                    String(
                        localized: "settings.deep_focus.schedule.active.session_notice",
                        defaultValue: "予定が終わっても手動で始めた分は続きます"
                    )
                )
                .dopaFont(13, weight: .medium, lineSpacing: 3)
                .foregroundStyle(DesignTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// 予定の終わりの時刻。表記はOSの言語・24時間設定に任せる。
    private var scheduleWindowUntilText: String {
        String(
            format: String(
                localized: "settings.deep_focus.schedule.active.until",
                defaultValue: "%@まで"
            ),
            Self.timeOfDayFormatter.string(
                from: SettingsTime.date(
                    minutes: deepFocusSchedule.endMinutes,
                    defaultMinutes: DeepFocusConstants.defaultScheduleEndMinutes
                )
            )
        )
    }

    private static let timeOfDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return formatter
    }()

    private var runningSessionRow: some View {
        HStack(spacing: 12) {
            Text(remainingSessionText)
                .dopaFont(16, weight: .bold)
                .foregroundStyle(DesignTokens.accent)
                .monospacedDigit()

            Spacer()

            Button {
                model.endDeepFocusSession()
                refreshDeepFocusState()
            } label: {
                Text(
                    String(
                        localized: "settings.deep_focus.session.stop.action",
                        defaultValue: "いま解除する"
                    )
                )
                .dopaFont(15, weight: .bold)
                .foregroundStyle(DesignTokens.primaryText)
                .padding(.horizontal, 16)
                .frame(minHeight: DesignTokens.minTapTarget)
                .background(DesignTokens.backgroundRaised)
                .overlay(
                    Capsule().stroke(DesignTokens.strongHairline, lineWidth: 1)
                )
                .clipShape(Capsule())
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// 残りの表示。「自分で戻すまで」は時間で終わらないので、そのまま状態を書く。
    private var remainingSessionText: String {
        guard let seconds = deepFocusRemainingSeconds else {
            return String(
                localized: "settings.deep_focus.session.open_ended.label",
                defaultValue: "自分で解除するまで"
            )
        }
        return String(
            format: String(
                localized: "settings.deep_focus.session.remaining",
                defaultValue: "残り%@"
            ),
            Self.remainingFormatter.string(from: max(60, seconds.rounded(.up))) ?? ""
        )
    }

    /// 単位はOSの言語設定に任せる。分より下は出さず、最後の1分は「1分」のまま見せる。
    private static let remainingFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter
    }()

    private var sessionOptionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DeepFocusSessionOption.allCases, id: \.self) { option in
                    sessionOptionChip(option)
                }
            }
        }
    }

    private func sessionOptionChip(_ option: DeepFocusSessionOption) -> some View {
        let isSelected = selectedSessionOption == option

        return Button {
            selectedSessionOption = option
        } label: {
            Text(option.title)
                .dopaFont(14, weight: .bold)
                .foregroundStyle(isSelected ? DesignTokens.background : DesignTokens.primaryText)
                .padding(.horizontal, 14)
                .frame(minHeight: 38)
                .background(isSelected ? DesignTokens.accent : DesignTokens.backgroundRaised)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? DesignTokens.accent : DesignTokens.hairline, lineWidth: 1)
                )
                .clipShape(Capsule())
                // チップの見た目は38ptのまま、当たり判定だけHIG下限の44ptへ広げる。
                .frame(minHeight: DesignTokens.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var startSessionButton: some View {
        Button {
            model.startDeepFocusSession(durationMinutes: selectedSessionOption.durationMinutes)
            refreshDeepFocusState()
        } label: {
            Text(
                String(
                    localized: "settings.deep_focus.session.start.action",
                    defaultValue: "開始"
                )
            )
            .dopaFont(16, weight: .bold)
            .foregroundStyle(DesignTokens.background)
            .frame(maxWidth: .infinity)
            .frame(minHeight: DesignTokens.minTapTarget)
            .background(DesignTokens.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(primaryRule == nil)
        .opacity(primaryRule == nil ? 0.45 : 1)
    }

    /// 毎週の予定。曜日と時間帯を1本だけ持つ。
    private var deepFocusScheduleBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: scheduleEnabledBinding) {
                Text(
                    String(
                        localized: "settings.deep_focus.schedule.label",
                        defaultValue: "毎週の予定"
                    )
                )
                .dopaFont(16, weight: .semibold)
                .foregroundStyle(DesignTokens.primaryText)
            }
            .tint(DesignTokens.accent)

            if deepFocusSchedule.isEnabled {
                weekdayChips

                HStack(spacing: 12) {
                    scheduleTimeField(
                        label: String(
                            localized: "settings.deep_focus.schedule.start.label",
                            defaultValue: "開始"
                        ),
                        selection: scheduleStartBinding
                    )

                    scheduleTimeField(
                        label: String(
                            localized: "settings.deep_focus.schedule.end.label",
                            defaultValue: "終了"
                        ),
                        selection: scheduleEndBinding
                    )
                }

                if let scheduleNotice {
                    Text(scheduleNotice)
                        .dopaFont(13, weight: .medium, lineSpacing: 3)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 14)
    }

    private var weekdayChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.weekdayOrder, id: \.self) { weekday in
                    weekdayChip(weekday)
                }
            }
        }
    }

    private func weekdayChip(_ weekday: Int) -> some View {
        let isSelected = deepFocusSchedule.weekdays.contains(weekday)

        return Button {
            toggleWeekday(weekday)
        } label: {
            Text(Self.weekdaySymbol(weekday))
                .dopaFont(14, weight: .bold)
                .foregroundStyle(isSelected ? DesignTokens.background : DesignTokens.primaryText)
                .frame(minWidth: 38, minHeight: 38)
                .background(isSelected ? DesignTokens.accent : DesignTokens.backgroundRaised)
                .overlay(
                    Circle()
                        .stroke(isSelected ? DesignTokens.accent : DesignTokens.hairline, lineWidth: 1)
                )
                .clipShape(Circle())
                .frame(minWidth: DesignTokens.minTapTarget, minHeight: DesignTokens.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.weekdayAccessibilityLabel(weekday))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// 曜日名はOSの言語設定から取る。3言語ぶんを自前で持たない。
    private static func weekdaySymbol(_ weekday: Int) -> String {
        let symbols = Calendar.autoupdatingCurrent.veryShortWeekdaySymbols
        guard symbols.indices.contains(weekday - 1) else {
            return String(weekday)
        }
        return symbols[weekday - 1]
    }

    private static func weekdayAccessibilityLabel(_ weekday: Int) -> String {
        let symbols = Calendar.autoupdatingCurrent.weekdaySymbols
        guard symbols.indices.contains(weekday - 1) else {
            return String(weekday)
        }
        return symbols[weekday - 1]
    }

    private func scheduleTimeField(label: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .dopaFont(13, weight: .semibold)
                .foregroundStyle(DesignTokens.secondaryText)

            DatePicker(label, selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(DesignTokens.secondaryText)
        }
    }

    /// 設定はしたのに効かない状態を黙って見せない。
    private var scheduleNotice: String? {
        if deepFocusSchedule.weekdays.isEmpty {
            return String(
                localized: "settings.deep_focus.schedule.no_weekday_notice",
                defaultValue: "選んだ曜日と時間だけアプリを止めます"
            )
        }
        guard DeepFocusWindowPolicy.hasWindow(
            startMinutes: deepFocusSchedule.startMinutes,
            endMinutes: deepFocusSchedule.endMinutes
        ) else {
            return String(
                localized: "settings.deep_focus.schedule.too_short_notice",
                defaultValue: "開始から終了まで15分以上にしてください"
            )
        }
        return nil
    }

    private var scheduleEnabledBinding: Binding<Bool> {
        Binding(
            get: { deepFocusSchedule.isEnabled },
            set: { isEnabled in
                // 曜日は自動で埋めない。オンにした瞬間に既定の時間帯（20:00-22:00）が
                // そのまま効くと、20時台にオンにした人が時刻を直す前にブロックされる。
                // 曜日を選ぶまでは何も起こらず、その1タップが「この設定でいい」の確認になる。
                // 曜日が空のあいだは `scheduleNotice` が次にやることを出す。
                applySchedule(
                    DeepFocusSchedule(
                        isEnabled: isEnabled,
                        weekdays: deepFocusSchedule.weekdays,
                        startMinutes: deepFocusSchedule.startMinutes,
                        endMinutes: deepFocusSchedule.endMinutes
                    )
                )
            }
        )
    }

    private var scheduleStartBinding: Binding<Date> {
        Binding(
            get: {
                SettingsTime.date(
                    minutes: deepFocusSchedule.startMinutes,
                    defaultMinutes: DeepFocusConstants.defaultScheduleStartMinutes
                )
            },
            set: { date in
                applySchedule(
                    DeepFocusSchedule(
                        isEnabled: deepFocusSchedule.isEnabled,
                        weekdays: deepFocusSchedule.weekdays,
                        startMinutes: SettingsTime.minutes(from: date),
                        endMinutes: deepFocusSchedule.endMinutes
                    )
                )
            }
        )
    }

    private var scheduleEndBinding: Binding<Date> {
        Binding(
            get: {
                SettingsTime.date(
                    minutes: deepFocusSchedule.endMinutes,
                    defaultMinutes: DeepFocusConstants.defaultScheduleEndMinutes
                )
            },
            set: { date in
                applySchedule(
                    DeepFocusSchedule(
                        isEnabled: deepFocusSchedule.isEnabled,
                        weekdays: deepFocusSchedule.weekdays,
                        startMinutes: deepFocusSchedule.startMinutes,
                        endMinutes: SettingsTime.minutes(from: date)
                    )
                )
            }
        )
    }

    private func toggleWeekday(_ weekday: Int) {
        var weekdays = Set(deepFocusSchedule.weekdays)
        if weekdays.contains(weekday) {
            weekdays.remove(weekday)
        } else {
            weekdays.insert(weekday)
        }
        applySchedule(
            DeepFocusSchedule(
                isEnabled: deepFocusSchedule.isEnabled,
                weekdays: Array(weekdays),
                startMinutes: deepFocusSchedule.startMinutes,
                endMinutes: deepFocusSchedule.endMinutes
            )
        )
    }

    /// 保存してすぐ同期する。いま窓に入ったかどうかを、その場の表示にも反映する。
    private func applySchedule(_ schedule: DeepFocusSchedule) {
        model.updateDeepFocusSchedule(schedule)
        refreshDeepFocusState()
    }

    private func refreshDeepFocusState() {
        deepFocusSchedule = model.deepFocusSchedule
        deepFocusSession = model.deepFocusSession
        deepFocusRemainingSeconds = model.deepFocusSessionRemainingSeconds
        isScheduleWindowActive = model.isDeepFocusScheduleWindowActive
    }

    /// 1秒ごとに残りを詰め、境界をまたいだ瞬間に同期まで通す。
    ///
    /// 拡張の境界コールバックを取りこぼしても、設定画面を開いたままの人はここで解除される。
    /// 「終わったのに開けない」を残さないための、3つ目の逃げ道。
    private func tickDeepFocusSession() {
        // 予定の時間帯を出入りしたら、表示も同期もやり直す。
        // 出入りで解除の導線の出し分けが変わるため、セッションが無くても見に行く。
        if isScheduleWindowActive != model.isDeepFocusScheduleWindowActive {
            model.syncShield()
            refreshDeepFocusState()
            return
        }

        guard deepFocusSession != nil else {
            return
        }
        guard model.deepFocusSession != nil else {
            model.syncShield()
            refreshDeepFocusState()
            return
        }
        deepFocusRemainingSeconds = model.deepFocusSessionRemainingSeconds
    }

    /// Proかどうかだけで決める。権利が未確定でも上位機能を勝手に開けない。
    /// （`isPro` は端末に控えたキャッシュから起動直後にも立つため、通信が切れた課金者は締め出さない）
    private var isDeepFocusUnlocked: Bool {
        model.entitlementGate.strictModeAllowed
    }

    private var isGateUnlocked: Bool {
        GateEntitlementAccess.isAllowed(
            hasConfirmedEntitlement: model.storeService.hasConfirmedEntitlement,
            gateAllowed: model.entitlementGate.gateAllowed
        )
    }

    private var selectedCatalogItems: [SNSAppCatalogItem] {
        ((try? model.targetStore.selectedCatalogIDs()) ?? [])
            .compactMap { SNSAppCatalog.app(catalogID: $0) }
    }

    /// 「止める設定」カードと「止めるアプリ」行は同じ選択を指す。別々に組むと
    /// 片方だけ「未設定」になる食い違いが出るため、1つの並びを両方で使う。
    private var targetIconSources: [AppIconSource] {
        let tokenSources = selectedGateApps.map { AppIconSource.token($0.token) }
        let catalogSources = selectedCatalogItems.map(AppIconSource.catalog)

        if isGateUnlocked, !tokenSources.isEmpty {
            return tokenSources
        }
        if !catalogSources.isEmpty {
            return catalogSources
        }
        return tokenSources
    }

    private var statusIconSources: [AppIconSource] {
        targetIconSources
    }

    private var targetRowIconSources: [AppIconSource] {
        targetIconSources
    }

    private var todayCancellationRate: Double {
        guard model.todayAttemptCount > 0 else { return 0 }
        return Double(model.todayCancelledCount) / Double(model.todayAttemptCount)
    }

    private var statusExpression: CharacterExpression {
        model.todayAttemptCount > 0 && model.todayCancelledCount == 0 ? .doom : .awake
    }

    private var canEndDeepFocusFromStatus: Bool {
        deepFocusSession != nil && !isScheduleWindowActive
    }

    private var statusSummary: String {
        if isScheduleWindowActive {
            return "\(scheduleWindowUntilText) ・ \(String(localized: "settings.deep_focus.schedule.active.label", defaultValue: "予定の時間帯"))"
        }

        if deepFocusSession != nil {
            return "\(remainingSessionText) ・ \(String(localized: "settings.deep_focus.session.stop.action", defaultValue: "いま解除する"))"
        }

        if selectedMode.usesShield {
            return selectedMode.detailText
        }

        return "\(String(localized: "settings.breath_duration.label", defaultValue: "一呼吸の長さ")) \(breathDurationText)"
    }

    private var breathDurationText: String {
        switch settingsStore.breathDurationSeconds {
        case 3:
            return String(
                localized: "settings.breath_duration.three_seconds",
                defaultValue: "3秒"
            )
        case 5:
            return String(
                localized: "settings.breath_duration.five_seconds",
                defaultValue: "5秒"
            )
        default:
            return String(
                localized: "settings.breath_duration.eight_seconds",
                defaultValue: "8秒"
            )
        }
    }

    private var isAutomationConfigured: Bool {
        if isGateUnlocked {
            return !selectedGateApps.isEmpty
        }

        let selectedIDs = selectedCatalogItems.map(\.catalogID)
        guard !selectedIDs.isEmpty else { return false }
        return AutomationVerification.unverifiedCatalogIDs(
            selectedCatalogIDs: selectedIDs,
            verifiedCatalogIDs: settingsStore.verifiedAutomationCatalogIDs
        ).isEmpty
    }

    private var notificationSummary: String {
        var labels: [String] = []
        if morningNotificationEnabled {
            labels.append(
                String(
                    localized: "settings.lock_screen.morning_notification",
                    defaultValue: "朝の目標通知"
                )
            )
        }
        if weeklyReportNotificationEnabled {
            labels.append(
                String(
                    localized: "settings.lock_screen.weekly_report",
                    defaultValue: "毎週の記録通知"
                )
            )
        }
        if retentionSupportNotificationsEnabled {
            labels.append(
                String(
                    localized: "settings.notifications.retention_support.title",
                    defaultValue: "設定確認と記録の通知"
                )
            )
        }
        if planNotificationsEnabled {
            labels.append(
                String(
                    localized: "settings.notifications.plan.title",
                    defaultValue: "プランに関する通知"
                )
            )
        }

        guard !labels.isEmpty else {
            return String(localized: "settings.value.not_set", defaultValue: "未設定")
        }

        var summary = Array(labels.prefix(2))
        let remaining = labels.count - summary.count
        if remaining > 0 {
            summary.append(
                String.localizedStringWithFormat(
                    String(
                        localized: "settings.summary.more",
                        defaultValue: "ほか%lld件"
                    ),
                    Int64(remaining)
                )
            )
        }
        return summary.joined(separator: " ・ ")
    }

    /// 選んだ強さによって、いま何が起きるのかをその場に書く。
    /// ディープフォーカス以外では対象を選んでもブロックされないため、黙って無効にしない。
    private var deepFocusFootnote: String {
        guard isDeepFocusUnlocked else {
            return String(
                localized: "settings.deep_focus.locked_notice",
                defaultValue: "完全ブロックでは決めた時間だけ選んだアプリを止められます"
            )
        }
        guard selectedMode.usesShield else {
            return String(
                localized: "settings.deep_focus.standard_notice",
                defaultValue: "一呼吸では開く前に待ち時間が入ります 完全ブロックでは決めた時間だけ開けなくなります"
            )
        }
        // 強さだけ選んで対象が空だと、何も止まらないまま止まっているつもりになる。
        // 効いていない状態を「効いています」と読める文言で覆わない。
        guard primaryRule != nil else {
            return String(
                localized: "settings.deep_focus.empty_targets_notice",
                defaultValue: "完全ブロックするアプリを選ぶと決めた時間だけ開けなくなります"
            )
        }
        // 夜だけ強化は止まる時間帯が違う。ディープフォーカスと同じ説明を出すと、
        // 昼も止まっていると読めてしまう。
        if selectedMode == .nightOnly {
            return String(
                localized: "settings.night_only.description",
                defaultValue: "選んだアプリは就寝から起床まで開けません 昼は開く前に一呼吸が入ります"
            )
        }
        // 窓を1つも持っていないディープフォーカスは、選んでいても何も止めない。
        // 効いていない状態を「効いています」と読める文言で覆わない。
        if !DeepFocusWindowPolicy.hasConfiguredWindow(
            now: Date(),
            session: deepFocusSession,
            schedule: deepFocusSchedule
        ) {
            return String(
                localized: "settings.deep_focus.no_window_notice",
                defaultValue: "いま止めているアプリはありません 時間を決めると選んだアプリが開けなくなります"
            )
        }
        return String(
            localized: "settings.deep_focus.description",
            defaultValue: "選んだアプリは決めた時間だけ開けなくなります いますぐ始めるか毎週の予定を設定できます"
        )
    }

    private var wakeTimeBinding: Binding<Date> {
        Binding(
            get: { SettingsTime.date(minutes: settingsStore.wakeTimeMinutes, defaultMinutes: 420) },
            set: {
                settingsStore.wakeTimeMinutes = SettingsTime.minutes(from: $0)
                model.usageWatch.configurationDidChange(isPro: model.storeService.isPro)
                // 夜だけ強化の窓もここで決まる。いまブロックすべきかの再計算と
                // 監視の張り直しを同時にやる `syncShield` を通す。
                model.syncShield()
            }
        )
    }

    private var bedTimeBinding: Binding<Date> {
        Binding(
            get: { SettingsTime.date(minutes: settingsStore.bedTimeMinutes, defaultMinutes: 1_380) },
            set: {
                settingsStore.bedTimeMinutes = SettingsTime.minutes(from: $0)
                model.usageWatch.configurationDidChange(isPro: model.storeService.isPro)
                model.syncShield()
            }
        )
    }

    private var authorizationSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(String(localized: "settings.authorization.title", defaultValue: "スクリーンタイムの許可"))
                .dopaFont(28, weight: .black)
                .foregroundStyle(DesignTokens.primaryText)

            Text(authorizationSheetBody)
                .dopaFont(16, weight: .semibold, lineSpacing: 5)
                .foregroundStyle(DesignTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button(String(localized: "settings.authorization.allow", defaultValue: "許可する")) {
                Task {
                    await requestScreenTimeAuthorization()
                }
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: !isRequestingAuthorization))
            .disabled(isRequestingAuthorization)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.background)
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    private var authorizationSheetBody: String {
        if authorizationWasDenied {
            return String(localized: "settings.authorization.denied_body", defaultValue: "スクリーンタイムを許可していないため開く前の一呼吸を使えません 設定からいつでも許可できます")
        }
        return String(localized: "settings.authorization.body", defaultValue: "選んだアプリを開く前に一呼吸を出すためスクリーンタイムを使います 利用データは端末内に保存されます")
    }

    private var primaryRule: TargetRule? {
        rules.first { !$0.activitySelectionData.isEmpty }
    }

    /// 完全ブロック用のルール数。件数の上限判定はカタログのルールを数に入れない。
    private var blockRuleCount: Int {
        rules.filter { !$0.activitySelectionData.isEmpty }.count
    }

    private var selectedGateApps: [GateAppSettingTarget] {
        Self.gateAppSettingTargets(from: rules)
    }

    static func gateAppSettingTargets(from rules: [TargetRule]) -> [GateAppSettingTarget] {
        var targetsByTokenData: [Data: GateAppSettingTarget] = [:]
        let decoder = JSONDecoder()
        for rule in rules where rule.isEnabled && !rule.activitySelectionData.isEmpty {
            guard let selection = try? decoder.decode(
                FamilyActivitySelection.self,
                from: rule.activitySelectionData
            ) else {
                continue
            }
            for token in selection.applicationTokens {
                guard let tokenData = try? GateTokenCoding.encode(token) else {
                    continue
                }
                targetsByTokenData[tokenData] = GateAppSettingTarget(
                    token: token,
                    tokenData: tokenData
                )
            }
        }
        return targetsByTokenData.values.sorted {
            $0.tokenData.base64EncodedString() < $1.tokenData.base64EncodedString()
        }
    }

    private func refreshSettingsState() {
        if settingsStore.wakeTimeMinutes == nil {
            settingsStore.wakeTimeMinutes = 420
        }
        if settingsStore.bedTimeMinutes == nil {
            settingsStore.bedTimeMinutes = 1_380
        }
        morningNotificationEnabled = settingsStore.morningNotificationEnabled
        weeklyReportNotificationEnabled = settingsStore.weeklyReportNotificationEnabled
        retentionSupportNotificationsEnabled = settingsStore.retentionSupportNotificationsEnabled
        planNotificationsEnabled = settingsStore.planNotificationsEnabled
        liveActivityEnabled = settingsStore.liveActivityEnabled
        selectedLockTheme = model.lockSurfaceState.theme
        refreshDeepFocusState()
        model.usageWatch.configurationDidChange(isPro: model.storeService.isPro)

        model.screenTime.refresh()
        do {
            rules = try model.ruleStore.allRules()
            selectedMode = storedMode
        } catch {
            rules = []
            selectedMode = storedMode
            model.alertMessage = String(localized: "settings.error.data_load", defaultValue: "データを読み込めませんでした")
        }
    }

    private func handleAppSelectionTap() {
        if model.screenTime.isAuthorized {
            presentFamilyActivityPicker()
        } else {
            shouldOpenPickerAfterAuthorization = true
            authorizationWasDenied = false
            isAuthorizationSheetPresented = true
        }
    }

    private func presentFamilyActivityPicker() {
        activitySelection = currentActivitySelection()
        isFamilyActivityPickerPresented = true
    }

    @MainActor
    private func requestScreenTimeAuthorization() async {
        guard !isRequestingAuthorization else {
            return
        }

        isRequestingAuthorization = true
        defer { isRequestingAuthorization = false }

        let granted = await model.screenTime.requestAuthorization()
        if granted {
            model.syncShield()
            isAuthorizationSheetPresented = false
        } else {
            authorizationWasDenied = true
        }
    }

    private func saveActivitySelection() {
        let isSelectionEmpty = activitySelection.applicationTokens.isEmpty
            && activitySelection.categoryTokens.isEmpty
            && activitySelection.webDomainTokens.isEmpty

        if shouldShowPaywallForSelectedTargets(isSelectionEmpty: isSelectionEmpty) {
            activitySelection = currentActivitySelection()
            paywallPlacement = .settingsFamilyActivityLimit
            return
        }

        do {
            // 強さは「止める強さ」で決めた値をそのまま使う。ここで書き換えると、
            // 対象を選び直しただけで強さが勝手に変わる。
            let mode = modeAllowedForCurrentEntitlement(selectedMode)
            if let rule = primaryRule {
                if isSelectionEmpty {
                    try model.ruleStore.deleteRule(id: rule.id)
                } else {
                    let data = try JSONEncoder().encode(activitySelection)
                    try model.ruleStore.saveFamilyActivitySelection(
                        data,
                        name: rule.name,
                        mode: mode,
                        defaultDurationMinutes: rule.defaultDurationMinutes,
                        ruleId: rule.id
                    )
                }
            } else if !isSelectionEmpty {
                let data = try JSONEncoder().encode(activitySelection)
                try model.ruleStore.saveFamilyActivitySelection(
                    data,
                    name: "SNS",
                    mode: mode
                )
            }

            refreshSettingsState()
            model.syncShield()
        } catch CoreError.validation(let message) {
            model.alertMessage = message
        } catch {
            model.alertMessage = String(localized: "settings.error.data_save", defaultValue: "データを保存できませんでした")
        }
    }

    private func shouldShowPaywallForSelectedTargets(isSelectionEmpty: Bool) -> Bool {
        let gate = model.entitlementGate

        if !isSelectionEmpty,
           primaryRule == nil,
           !gate.canAddRule(currentCount: blockRuleCount) {
            return true
        }

        if let limit = gate.targetAppTokensLimit,
           selectedTargetTokenCount(activitySelection) > limit {
            return true
        }

        return false
    }

    private func setSelectedMode(_ mode: InterventionMode) {
        // 解放判定は権利の確定を待たない。未確定でも上位の強さを勝手には開けない。
        // 夜だけ強化も同じ完全ブロックを使うため、ディープフォーカスと同じ扱いにする。
        guard !mode.usesShield || isDeepFocusUnlocked else {
            paywallPlacement = .settingsModeGate
            selectedMode = storedMode
            return
        }

        // 通常介入のルールと完全ブロックのルールの両方へ届ける。届けたうえで同期する。
        // 書き込めなかったときは選択も表示も進めない。保存だけ進めると、ルールは標準のままなのに
        // 画面はディープフォーカスと表示され、止まらない理由が誰にも分からなくなる。
        do {
            try model.applyInterventionMode(mode)
        } catch {
            model.alertMessage = String(localized: "settings.error.data_save", defaultValue: "データを保存できませんでした")
            selectedMode = storedMode
            return
        }

        selectedMode = mode
        settingsStore.pendingInterventionMode = mode.rawValue
        refreshSettingsState()
    }

    /// 保存・表示に使う強さへ丸める。降格するのは**Freeだと確定したとき**だけ。
    ///
    /// 権利を取り直せていない状態（通信断・StoreKit障害）で降格を書き込むと、
    /// 課金者のディープフォーカスを標準へ永久に書き換えてしまう。
    /// 未確定のあいだは現状の値をそのまま通す（`.claude/specs/entitlement-failsafe-fix.md`）。
    private func modeAllowedForCurrentEntitlement(_ mode: InterventionMode) -> InterventionMode {
        guard mode.usesShield,
              model.storeService.hasConfirmedEntitlement,
              !model.entitlementGate.strictModeAllowed else {
            return mode
        }
        return .standard
    }

    private func currentActivitySelection() -> FamilyActivitySelection {
        guard let rule = primaryRule,
              let selection = try? JSONDecoder().decode(
                FamilyActivitySelection.self,
                from: rule.activitySelectionData
              ) else {
            return FamilyActivitySelection()
        }
        return selection
    }

    private func selectedTargetTokenCount(_ selection: FamilyActivitySelection) -> Int {
        selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }

    /// いま保存されている「止める強さ」。画面上ひとつの設定として見せるため、
    /// ルールごとの値ではなく保存済みの選択を正とし、無ければルールから拾う。
    private var storedMode: InterventionMode {
        if let rawValue = settingsStore.pendingInterventionMode,
           let mode = InterventionMode(rawValue: rawValue) {
            return modeAllowedForCurrentEntitlement(mode)
        }
        return modeAllowedForCurrentEntitlement(primaryRule?.mode ?? .standard)
    }

}
