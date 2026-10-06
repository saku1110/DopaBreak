import DopaBreakCore
import FamilyControls
import ManagedSettings
import SwiftUI
import UIKit

enum SettingsFocusRequestConsumption {
    static func consume(isSettingsVisible: Bool, pendingRequest: inout Bool) -> Bool {
        guard isSettingsVisible, pendingRequest else { return false }
        pendingRequest = false
        return true
    }
}

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
        timelineDragPreview: Bool = false,
        onResetOnboarding: @escaping () -> Void
    ) {
        self.model = model
        self.settingsStore = settingsStore
        self.onResetOnboarding = onResetOnboarding
        self.snapshotScreenTimeAuthorized = screenTimeAuthorized
        _draggingTimelineHandle = State(initialValue: timelineDragPreview ? .wake : nil)
        _wakeTimeMinutes = State(initialValue: settingsStore.wakeTimeMinutes ?? 420)
        _bedTimeMinutes = State(initialValue: settingsStore.bedTimeMinutes ?? 1_380)
    }
    #endif

    @State private var rules: [TargetRule] = []
    @State private var activitySelection = FamilyActivitySelection()
    @State private var isAuthorizationSheetPresented = false
    @State private var isFamilyActivityPickerPresented = false
    @State private var authorizationWasDenied = false
    @State private var isRequestingAuthorization = false
    @State private var shouldOpenPickerAfterAuthorization = false
    @State private var paywallPlacement: PaywallPlacement?
    @State private var isTargetPickerPresented = false
    @State private var shouldPresentTargetAppPaywallAfterDismiss = false
    /// アプリを追加した直後にショートカットの案内を開くための予約。追加したカタログIDを持つ。
    /// ピッカーを閉じてから出さないとモーダルがぶつかるので、ここで持ち越す。
    /// 同じピッカーの中で外し直したら取り消す。対象0件のまま案内を開かないため。
    @State private var pendingAutomationGuideAfterPicker: Set<String> = []
    @State private var isAutomationGuidePresented = false
    @State private var isGrayscaleGuidePresented = false
    @State private var isLockScreenCheckPresented = false
    @State private var isDeleteAllDataConfirmationPresented = false
    @State private var isDeletionFeedbackVisible = false
    @State private var breathDurationSeconds = 3
    @State private var wakeTimeMinutes = 420
    @State private var bedTimeMinutes = 1_380
    @State private var weeklyReportNotificationMinutes = 420
    @State private var verifiedAutomationCatalogIDs: [String] = []
    @State private var weeklyReportNotificationEnabled = true
    @State private var reflectionNotificationEnabled = true
    @State private var retentionSupportNotificationsEnabled = true
    @State private var planNotificationsEnabled = true
    @State private var liveActivityEnabled = true
    @State private var liveLockTheme: LockTheme = .e1
    @State private var isStrictSessionSelected = false
    @State private var isStrictExitPresented = false
    @State private var selectedSessionOption: DeepFocusSessionOption = .oneHour
    @State private var selectedScheduleIndex = 0
    @State private var scheduleCount = 1
    @State private var deepFocusSchedule: DeepFocusSchedule = .disabled
    /// 進行中の回。1秒ごとの再描画で残り時間を出し、0になった瞬間に同期へ回す。
    @State private var deepFocusSession: DeepFocusSession?
    @State private var deepFocusRemainingSeconds: TimeInterval?
    /// いま予定の時間帯に入っているか。入っているあいだは解除の導線を出さない。
    @State private var isScheduleWindowActive = false
    @State private var isWakeTimePickerPresented = false
    @State private var isBedTimePickerPresented = false
    @State private var timelineAdjustmentMessage: String?
    @State private var draggingTimelineHandle: TimelineHandle?
    @State private var timelineDragStartMinutes: Int?
    @State private var timelineDragGestureID: UUID?
    @State private var timelineDragAnchorGestureID: UUID?
    @State private var didDragTimelineHandle = false
    @State private var timelineDragCleanupTask: Task<Void, Never>?
    @State private var timelineShieldSyncTask: Task<Void, Never>?
    @State private var isTimelineShieldSyncPending = false
    @State private var isSettingsVisible = false
    @State private var isPlanEntryHighlighted = false
    @State private var isDeepFocusEntryHighlighted = false
    @State private var isBlockCategoryWarningPresented = false

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

    private enum TimelineHandle {
        case wake
        case bed
    }

    /// プラン系通知のタップで送り込む先（docs/18 §2f）。
    private static let planSectionID = "settings.section.account"
    private static let deepFocusSectionID = "settings.section.deep_focus"

    var body: some View {
        NavigationStack {
            // プラン欄は5番目のセクションで初期表示に入らないため、通知からの着地では自力で送る。
            ScrollViewReader { proxy in
                settingsScroll
                    .onAppear {
                        isSettingsVisible = true
                        scrollToPlanSectionIfRequested(proxy: proxy)
                        scrollToDeepFocusSectionIfRequested(proxy: proxy)
                    }
                    .onDisappear {
                        isSettingsVisible = false
                        flushPendingTimelineShieldSync()
                        timelineDragCleanupTask?.cancel()
                        timelineShieldSyncTask?.cancel()
                        clearTimelineDragState(resetTapGuard: true)
                    }
                    .onChange(of: model.pendingPlanSettingsFocus) { _, _ in
                        scrollToPlanSectionIfRequested(proxy: proxy)
                    }
                    .onChange(of: model.pendingDeepFocusSettingsFocus) { _, _ in
                        scrollToDeepFocusSectionIfRequested(proxy: proxy)
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

    /// ホームからの要求があれば、完全ブロックを選ぶ「止める強さ」まで送る。
    private func scrollToDeepFocusSectionIfRequested(proxy: ScrollViewProxy) {
        guard isSettingsVisible, model.pendingDeepFocusSettingsFocus else {
            return
        }
        Task { @MainActor in
            await Task.yield()
            await Task.yield()
            guard SettingsFocusRequestConsumption.consume(
                isSettingsVisible: isSettingsVisible,
                pendingRequest: &model.pendingDeepFocusSettingsFocus
            ) else { return }
            withAnimation(DopaMotion.transition) {
                proxy.scrollTo(Self.deepFocusSectionID, anchor: .center)
                isDeepFocusEntryHighlighted = true
            }
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            withAnimation(DopaMotion.control) {
                isDeepFocusEntryHighlighted = false
            }
        }
    }

    /// シート提示や状態同期はスクロール本体に付けたまま、NavigationStackで包むだけにする。
    private var settingsScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                statusSection
                modeSection
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous)
                            .stroke(
                                isDeepFocusEntryHighlighted ? DesignTokens.accent : .clear,
                                lineWidth: 1
                            )
                    }
                    .id(Self.deepFocusSectionID)

                if isDeepFocusUnlocked, model.blockConfiguration.blockEnabled {
                    deepFocusControlsSection
                } else if !isDeepFocusUnlocked {
                    deepFocusLockedSection
                }

                if isDeepFocusUnlocked, model.blockConfiguration.blockEnabled {
                    shieldModeFootnote
                }

                targetLengthAutomationSection
                entrySection
                CardContainer {
                    NavigationLink { SettingsMechanismView() } label: {
                        SettingsIconNavigationRow(systemName: "brain.head.profile",
                            label: String(localized: "settings.entry.mechanism", defaultValue: "仕組み"))
                    }
                    .buttonStyle(.plain)
                }
                aboutEntrySection

                Text(
                    String(
                        localized: "settings.device_only_note",
                        defaultValue: "開く前の一呼吸と完全ブロックはiPhoneでのみ使えます。"
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
            footerText: String(
                localized: "block_picker.footer",
                defaultValue: "DopaBreak自身は選ばないでください。指定した時間帯にDopaBreakを開けなくなります。カテゴリを選ぶと、その分類のアプリがすべてブロックされます。"),
            isPresented: $isFamilyActivityPickerPresented,
            selection: $activitySelection
        )
        .fullScreenCover(item: $paywallPlacement, onDismiss: {
            refreshSettingsState()
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
        }
        .sheet(isPresented: $isTargetPickerPresented, onDismiss: {
            if shouldPresentTargetAppPaywallAfterDismiss {
                shouldPresentTargetAppPaywallAfterDismiss = false
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
                    shouldPresentTargetAppPaywallAfterDismiss = true
                },
                onTargetAdded: { catalogID in
                    pendingAutomationGuideAfterPicker.insert(catalogID)
                },
                onTargetRemoved: { catalogID in
                    pendingAutomationGuideAfterPicker.remove(catalogID)
                }
            )
        }
        .sheet(isPresented: $isAutomationGuidePresented, onDismiss: refreshSettingsState) {
            AutomationGuideView(model: model, settingsStore: settingsStore)
        }
        .sheet(isPresented: $isGrayscaleGuidePresented) {
            GrayscaleGuideSheet()
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

            let isSelectionEmpty = activitySelection.applicationTokens.isEmpty
                && activitySelection.categoryTokens.isEmpty
                && activitySelection.webDomainTokens.isEmpty
            if shouldShowPaywallForSelectedTargets(isSelectionEmpty: isSelectionEmpty) {
                activitySelection = currentActivitySelection()
                paywallPlacement = .settingsFamilyActivityLimit
                return
            }

            let savedCategoryTokens = currentActivitySelection().categoryTokens
            let newlyAddedCategoryTokens = activitySelection.categoryTokens
                .subtracting(savedCategoryTokens)
            if newlyAddedCategoryTokens.isEmpty {
                saveActivitySelection()
            } else {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    guard !Task.isCancelled else { return }
                    isBlockCategoryWarningPresented = true
                }
            }
        }
        .onReceive(Self.deepFocusTicker) { _ in
            tickDeepFocusSession()
        }

        .alert(
            String(
                localized: "block_picker.category_warning.title",
                defaultValue: "カテゴリはまとめて止まります"
            ),
            isPresented: $isBlockCategoryWarningPresented
        ) {
            Button(
                String(
                    localized: "block_picker.category_warning.save",
                    defaultValue: "このまま保存"
                )
            ) {
                saveActivitySelection()
            }
            Button(
                String(
                    localized: "block_picker.category_warning.reselect",
                    defaultValue: "選び直す"
                ),
                role: .cancel
            ) {
                isFamilyActivityPickerPresented = true
            }
        } message: {
            Text(
                String(
                    localized: "block_picker.category_warning.message",
                    defaultValue: "選んだ分類に入っているアプリがすべて止まります。DopaBreak自身が同じ分類にあると、その時間帯は開けなくなります。"
                )
            )
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

    /// 追加直後のショートカット案内を出す。ペイウォールが控えているときはそちらを優先し、
    /// 予約を残してペイウォールの `onDismiss` で改めて出す。
    private func presentAutomationGuideAfterPickerIfNeeded() {
        guard !shouldPresentTargetAppPaywallAfterDismiss, paywallPlacement == nil else {
            return
        }
        guard !pendingAutomationGuideAfterPicker.isEmpty else {
            return
        }
        pendingAutomationGuideAfterPicker.removeAll()
        isAutomationGuidePresented = true
    }

    private var isAnyChildModalPresented: Bool {
        isAuthorizationSheetPresented
            || isFamilyActivityPickerPresented
            || paywallPlacement != nil
            || isTargetPickerPresented
            || isAutomationGuidePresented
            || isGrayscaleGuidePresented
            // 追加直後の案内も数える。ペイウォールを挟むと消化までに間が空く。
            || !pendingAutomationGuideAfterPicker.isEmpty
            || isLockScreenCheckPresented
            || isBlockCategoryWarningPresented
            || isDeleteAllDataConfirmationPresented
            || isStrictExitPresented
    }

    private var statusSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    DopaRing(
                        progress: todayCancellationRate,
                        expression: statusExpression,
                        diameter: 56
                    )
                    statusTextBlock
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .center, spacing: 12) {
                    if !statusIconSources.isEmpty {
                        AppIconStack(sources: statusIconSources, size: 30, maxVisible: 4, spacing: 6)
                    }
                    Spacer(minLength: 0)
                    todayCancellationBlock
                }
            }
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

        }
    }

    private var todayCancellationBlock: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
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
                HStack {
                    SmallLabel(text: String(localized: "block.title", defaultValue: "ブロック"))
                    Spacer()
                    Label("Pro", systemImage: isDeepFocusUnlocked ? "checkmark.shield" : "lock.fill")
                        .dopaFont(12, weight: .bold)
                        .foregroundStyle(DesignTokens.secondaryText)
                }
                Text(String(localized: "block.breath_always", defaultValue: "開く前の一呼吸はいつでも使えます"))
                    .dopaFont(13, weight: .medium)
                    .foregroundStyle(DesignTokens.secondaryText)
                VStack(spacing: 0) {
                    ForEach(BlockTrigger.allCases, id: \.self) { trigger in
                        Toggle(trigger.displayTitle, isOn: Binding(
                            get: { model.blockConfiguration.allows(trigger) },
                            set: { enabled in
                                do { try model.updateBlockTrigger(trigger, enabled: enabled) }
                                catch { model.alertMessage = error.localizedDescription }
                                refreshDeepFocusState()
                            }
                        ))
                        .tint(DesignTokens.accent)
                        .dopaFont(15, weight: .semibold)
                        .frame(minHeight: DesignTokens.minTapTarget)
                        .accessibilityIdentifier("settings.block." + trigger.rawValue)
                        .disabled(!isDeepFocusUnlocked)
                    }
                }
                SettingsDivider()
                dailyOpenLimitRow
            }
            .overlay {
                if !isDeepFocusUnlocked {
                    Button {
                        paywallPlacement = .settingsModeGate
                    } label: {
                        Color.clear.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "block.unlock", defaultValue: "Proでブロックを使う"))
                    .accessibilityIdentifier("settings.block.unlock")
                }
            }
        }
        .accessibilityIdentifier("settings.block.section")
    }

    /// 1日に開ける回数（Pro）。使い切ると、完全にブロックするアプリが翌朝の起床時刻まで止まる。
    private var dailyOpenLimitRow: some View {
        let status = model.dailyOpenLimitStatus
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(String(localized: "open_limit.settings.title", defaultValue: "1日に開ける回数"))
                    .dopaFont(15, weight: .semibold)
                    .foregroundStyle(DesignTokens.primaryText)
                Spacer(minLength: 8)
                Picker(
                    String(localized: "open_limit.settings.title", defaultValue: "1日に開ける回数"),
                    selection: Binding(
                        get: { status.pendingChange.map { $0.limit ?? 0 } ?? status.limit ?? 0 },
                        set: { model.setDailyOpenLimit($0 == 0 ? nil : $0) }
                    )
                ) {
                    Text(DailyOpenLimitDisplay.limitValue(nil)).tag(0)
                    ForEach(DailyOpenLimitConstants.limitChoices, id: \.self) { limit in
                        Text(DailyOpenLimitDisplay.limitValue(limit)).tag(limit)
                    }
                }
                .pickerStyle(.menu)
                .tint(DesignTokens.accent)
                .labelsHidden()
                .disabled(!isDeepFocusUnlocked)
                .accessibilityIdentifier("settings.open_limit.picker")
            }
            .frame(minHeight: DesignTokens.minTapTarget)

            ForEach(dailyOpenLimitNotes(status), id: \.self) { note in
                Text(note)
                    .dopaFont(13, weight: .medium, lineSpacing: 3)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityIdentifier("settings.open_limit")
    }

    private func dailyOpenLimitNotes(_ status: DailyOpenLimitStatus) -> [String] {
        guard isDeepFocusUnlocked else {
            return [String(localized: "open_limit.settings.locked", defaultValue: "決めた回数を開くと翌朝まで完全にブロックします")]
        }
        var notes: [String] = []
        if let pending = status.pendingChange {
            notes.append(DailyOpenLimitDisplay.pendingLine(pending, now: model.currentDate))
        }
        if status.isExhausted {
            // 最後の1回や緊急で開いた時間のあいだは、まだ開ける。「開けません」と言い切らない。
            let detail = model.dailyOpenLimitOpenUntil.map(DailyOpenLimitDisplay.openUntilLine)
                ?? DailyOpenLimitDisplay.untilLine(status.dayEndsAt, now: model.currentDate)
            notes.append(DailyOpenLimitDisplay.openedTitle(status.openedCount) + " " + detail)
        } else if let remaining = status.remaining {
            notes.append(String(localized: "open_limit.breath.remaining", defaultValue: "今日あと\(remaining)回"))
        }
        if status.limit == nil, let average = model.dailyOpenLimitAverageOpens {
            let recommended = DailyOpenLimitDisplay.recommendedLimit(forAverage: average)
            notes.append(String(
                localized: "open_limit.settings.average",
                defaultValue: "最近は1日平均\(average)回開いています。まずは\(recommended)回から始めるのがおすすめです。"
            ))
        }
        let wake = DailyOpenLimitDisplay.wakeTimeText(minutes: wakeTimeMinutes)
        notes.append(String(
            localized: "open_limit.settings.footnote",
            defaultValue: "使い切ると完全にブロックするアプリは翌朝 \(wake) まで開けません。急ぐときは30秒待てば開けます。"
        ))
        if status.limit != nil, primaryRule == nil {
            notes.append(String(
                localized: "open_limit.settings.no_block_apps",
                defaultValue: "完全にブロックするアプリを選ぶと、使い切ったあとはスクリーンタイムで止まります。"
            ))
        }
        return notes
    }

    private var deepFocusControlsSection: some View {
        CardContainer {
            VStack(spacing: 0) {
                if model.blockConfiguration.allows(.manual) { deepFocusSessionBlock }
                if model.blockConfiguration.allows(.manual) && model.blockConfiguration.allows(.weeklySchedule) { SettingsDivider() }
                if model.blockConfiguration.allows(.weeklySchedule) { deepFocusScheduleBlock }
            }
        }
    }

    private var shieldModeFootnote: some View {
        Text(deepFocusFootnote)
            .dopaFont(13, weight: .medium, lineSpacing: 3)
            .foregroundStyle(DesignTokens.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
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
                            defaultValue: "Proでは、選んだアプリを決めた時間だけ開けないようにできます。"
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
        VStack(spacing: 12) {
            CardContainer {
                VStack(spacing: 0) {
                    breathAppSelectionRow

                    Text(breathTargetsDescription)
                        .dopaFont(13, weight: .medium, lineSpacing: 3)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 10)

                    if let targetAppClampNotice = model.targetAppClampNotice {
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

                    SettingsDivider()
                    grayscaleGuideRow
                    SettingsDivider()
                    NavigationLink {
                        ReinterventionSettingsView(model: model)
                    } label: {
                        SettingsIconNavigationRow(systemName: "hourglass", label: String(localized: "reintervention.title", defaultValue: "利用時間の通知・制限"))
                    }
                    .buttonStyle(.plain)
                }
            }

            CardContainer {
                VStack(spacing: 0) {
                    blockedAppSelectionRow

                    Text(blockTargetsDescription)
                    .dopaFont(13, weight: .medium, lineSpacing: 3)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 10)

                    if isDeepFocusUnlocked {
                        SettingsDivider()
                        screenTimeRow
                    } else {
                        SettingsDivider()
                        blockedAppsLockedRow
                    }

                    if isDeepFocusUnlocked, model.blockConfiguration.blockTriggers.contains(.night) {
                        SettingsDivider()
                        wakeSleepTimelineSection
                    }
                }
            }
        }
    }

    private var breathTargetsDescription: String {
        if selectedCatalogItems.isEmpty {
            return String(
                localized: "settings.targets.breath.empty_description",
                defaultValue: "まだアプリを選んでいません。一呼吸をはさむアプリを選んでショートカットを設定すると使えます。"
            )
        }
        return String(
            localized: "settings.targets.breath.description",
            defaultValue: "一呼吸をはさむアプリを開く前に、呼吸の画面を表示します。ショートカットの設定が必要です。"
        )
    }

    private var breathAppSelectionRow: some View {
        Button {
            isTargetPickerPresented = true
        } label: {
            appSelectionRowLabel(
                title: String(
                    localized: "settings.targets.breath.title",
                    defaultValue: "一呼吸をはさむアプリ"
                ),
                iconSources: selectedCatalogItems.map(AppIconSource.catalog)
            )
        }
        .buttonStyle(.plain)
    }

    private var blockedAppSelectionRow: some View {
        Button {
            if isDeepFocusUnlocked {
                handleBlockedAppSelectionTap()
            } else {
                paywallPlacement = .settingsModeGate
            }
        } label: {
            appSelectionRowLabel(
                title: String(
                    localized: "settings.targets.block.title",
                    defaultValue: "完全にブロックするアプリ"
                ),
                iconSources: selectedBlockedAppTokens.map(AppIconSource.token)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDeepFocusUnlocked && isRequestingAuthorization)
    }

    private var blockTargetsDescription: String {
        // 1日に開ける回数がオンなら、きっかけのスイッチが全部オフでも対象は使われる。
        if !model.blockConfiguration.blockEnabled, model.dailyOpenLimitStatus.limit == nil {
            return String(
                localized: "settings.targets.block.description.standard",
                defaultValue: "ブロックのスイッチをオンにすると使えます"
            )
        }
        if primaryRule == nil {
            return String(
                localized: "settings.targets.block.description.empty",
                defaultValue: "対象を選ぶと、オンにしたきっかけでブロックします"
            )
        }
        return String(
            localized: "settings.targets.block.description",
            defaultValue: "オンにしたきっかけで選んだアプリをブロックします。スクリーンタイムの許可が必要です。"
        )
    }

    private func appSelectionRowLabel(
        title: String,
        iconSources: [AppIconSource]
    ) -> some View {
        HStack(spacing: 12) {
            SettingsIconTile(
                systemName: "square.grid.2x2.fill",
                background: DesignTokens.accent,
                foreground: .black
            )

            Text(title)
                .dopaFont(16, weight: .semibold)
                .foregroundStyle(DesignTokens.primaryText)

            Spacer(minLength: 8)

            if iconSources.isEmpty {
                Text(String(localized: "settings.value.not_set", defaultValue: "未設定"))
                    .dopaFont(13, weight: .semibold)
                    .foregroundStyle(DesignTokens.secondaryText)
            } else {
                AppIconStack(sources: iconSources, size: 24, maxVisible: 4)
            }

            SettingsChevron()
        }
        .frame(minHeight: DesignTokens.minTapTarget)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var blockedAppsLockedRow: some View {
        Button {
            paywallPlacement = .settingsModeGate
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.fill")
                    .dopaFont(14, weight: .bold)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .frame(width: 20)

                Text(
                    String(
                        localized: "settings.targets.block.locked_notice",
                        defaultValue: "Proで時間帯の自動ブロックを設定"
                    )
                )
                .dopaFont(13, weight: .semibold, lineSpacing: 3)
                .foregroundStyle(DesignTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)
                SettingsChevron()
            }
            .frame(minHeight: DesignTokens.minTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        let isSelected = breathDurationSeconds == seconds

        return Button {
            settingsStore.breathDurationSeconds = seconds
            breathDurationSeconds = seconds
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
                    defaultValue: "ショートカットの設定方法"
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

    /// 白黒モードの手順。iOS側のカラーフィルタの案内なので、モードや権利で出し分けず全員に出す。
    /// カラーフィルタの現在の状態はアプリから取れないため、右側の状態表示は持たせない。
    private var grayscaleGuideRow: some View {
        Button {
            isGrayscaleGuidePresented = true
        } label: {
            SettingsIconNavigationRow(
                systemName: "circle.lefthalf.filled",
                label: String(
                    localized: "settings.target.grayscale",
                    defaultValue: "画面を白黒にする"
                )
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

    private var wakeSleepTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                SmallLabel(
                    text: String(
                        localized: "settings.schedule.section",
                        defaultValue: "起床・就寝時刻"
                    )
                )

                Spacer(minLength: 8)

                Text(InterventionMode.nightOnly.detailText)
                    .dopaFont(11, weight: .semibold)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineLimit(1)
            }

            timelineBar

            HStack(alignment: .firstTextBaseline) {
                Text("0:00")
                Spacer()
                Button {
                    timelineAdjustmentMessage = nil
                    isWakeTimePickerPresented = true
                } label: {
                    Label("\(timelineTimeText(wakeTimeMinutes)) \(String(localized: "settings.timeline.wake", defaultValue: "起床"))", systemImage: "chevron.up.chevron.down")
                        .frame(minHeight: DesignTokens.minTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignTokens.accent)
                Spacer()
                Button {
                    timelineAdjustmentMessage = nil
                    isBedTimePickerPresented = true
                } label: {
                    Label("\(timelineTimeText(bedTimeMinutes)) \(String(localized: "settings.timeline.sleep", defaultValue: "就寝"))", systemImage: "chevron.up.chevron.down")
                        .frame(minHeight: DesignTokens.minTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignTokens.accent)
            }
            .dopaFont(11, weight: .medium, design: .monospaced)
            .foregroundStyle(DesignTokens.secondaryText)

            // 対象を選んである人にだけ出す。何も選んでいなければ、そもそも止まる対象がない。
            if model.showsNightBlockUnarmedNotice, primaryRule != nil {
                shieldUnarmedNotice
            }
        }
        .padding(.top, 12)
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
            let wakeOffset = WakeSleepTimelinePolicy.offset(
                forTime: wakeTimeMinutes,
                trackWidth: Double(barWidth)
            )
            let bedOffset = WakeSleepTimelinePolicy.offset(
                forTime: bedTimeMinutes,
                trackWidth: Double(barWidth)
            )
            let wake = CGFloat(wakeOffset) / barWidth
            let bed = CGFloat(bedOffset) / barWidth

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
            .position(x: proxy.size.width / 2, y: 42)

            timelineHandle(
                handle: .wake,
                systemName: "sun.max.fill",
                label: String(localized: "settings.timeline.wake", defaultValue: "起床"),
                minutes: wakeTimeMinutes,
                trackWidth: barWidth
            ) {
                timelineAdjustmentMessage = nil
                isWakeTimePickerPresented = true
            }
            .position(x: horizontalInset + wake * barWidth, y: 42)

            timelineHandle(
                handle: .bed,
                systemName: "moon.fill",
                label: String(localized: "settings.timeline.sleep", defaultValue: "就寝"),
                minutes: bedTimeMinutes,
                trackWidth: barWidth
            ) {
                timelineAdjustmentMessage = nil
                isBedTimePickerPresented = true
            }
            .position(x: horizontalInset + bed * barWidth, y: 42)
        }
        .frame(height: 76)
        .coordinateSpace(name: "wakeSleepTimeline")
        .transaction { $0.animation = nil }
    }

    private func timelineHandle(
        handle: TimelineHandle,
        systemName: String,
        label: String,
        minutes: Int,
        trackWidth: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        ZStack {
            if draggingTimelineHandle == handle {
                Text(timelineTimeText(minutes))
                    .dopaFont(11, weight: .bold, design: .monospaced)
                    .foregroundStyle(DesignTokens.primaryText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(DesignTokens.card)
                    .clipShape(Capsule())
                    .offset(y: -34)
                    .allowsHitTesting(false)
            }

            Button {
                guard !didDragTimelineHandle else { return }
                action()
            } label: {
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
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(timelineTimeText(minutes))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
        .accessibilityAction(named: Text(label), action)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                updateTimeline(handle: handle, proposedMinutes: minutes + 15, source: .accessibility)
            case .decrement:
                updateTimeline(handle: handle, proposedMinutes: minutes - 15, source: .accessibility)
            @unknown default:
                return
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 6, coordinateSpace: .named("wakeSleepTimeline"))
                .onChanged { value in
                    didDragTimelineHandle = true
                    let gestureID: UUID
                    if let activeGestureID = timelineDragGestureID {
                        gestureID = activeGestureID
                    } else {
                        gestureID = UUID()
                        timelineDragGestureID = gestureID
                        scheduleTimelineDragFailsafe(for: gestureID)
                    }
                    if timelineDragAnchorGestureID != gestureID {
                        draggingTimelineHandle = handle
                        timelineDragStartMinutes = minutes
                        timelineDragAnchorGestureID = gestureID
                    }
                    let startMinutes = timelineDragStartMinutes ?? minutes
                    let startOffset = WakeSleepTimelinePolicy.offset(
                        forTime: startMinutes,
                        trackWidth: Double(trackWidth)
                    )
                    let proposed = WakeSleepTimelinePolicy.time(
                        forOffset: startOffset + Double(value.translation.width),
                        trackWidth: Double(trackWidth)
                    )
                    updateTimeline(handle: handle, proposedMinutes: proposed, source: .drag)
                }
                .onEnded { _ in
                    flushPendingTimelineShieldSync()
                    clearTimelineDragState(resetTapGuard: false)
                    scheduleTimelineTapGuardCleanup(after: .milliseconds(120))
                }
        )
    }

    private enum TimelineUpdateSource {
        case drag
        case picker
        case accessibility

        var snapsToStep: Bool { self == .drag }
        var providesHapticFeedback: Bool { self == .drag }
    }

    private func updateTimeline(
        handle: TimelineHandle,
        proposedMinutes: Int,
        source: TimelineUpdateSource
    ) {
        let nextMinutes: Int
        switch handle {
        case .wake:
            nextMinutes = WakeSleepTimelinePolicy.clampedWake(
                proposedMinutes,
                bed: bedTimeMinutes,
                current: wakeTimeMinutes,
                snapToStep: source.snapsToStep
            )
        case .bed:
            nextMinutes = WakeSleepTimelinePolicy.clampedBed(
                proposedMinutes,
                wake: wakeTimeMinutes,
                current: bedTimeMinutes,
                snapToStep: source.snapsToStep
            )
        }
        let currentMinutes = handle == .wake ? wakeTimeMinutes : bedTimeMinutes
        if source == .picker {
            timelineAdjustmentMessage = nextMinutes == WakeSleepTimelinePolicy.normalized(proposedMinutes)
                ? nil
                : String(
                    localized: "settings.timeline.minimum_gap_notice",
                    defaultValue: "起床と就寝は1時間以上あけて設定してください。")
        }
        guard nextMinutes != currentMinutes else { return }

        if handle == .wake {
            wakeTimeMinutes = nextMinutes
            settingsStore.wakeTimeMinutes = nextMinutes
        } else {
            bedTimeMinutes = nextMinutes
            settingsStore.bedTimeMinutes = nextMinutes
        }
        if source.providesHapticFeedback {
            HapticFeedback.selection()
        }
        if source == .drag {
            // Apply the new schedule once the finger lifts, not during a paused drag.
            timelineShieldSyncTask?.cancel()
            timelineShieldSyncTask = nil
            isTimelineShieldSyncPending = true
        } else {
            scheduleTimelineShieldSync()
        }
    }

    /// ScrollViewなどに終了通知を奪われた場合だけを救う。ドラッグ中の停止を終了扱いしないよう、
    /// ジェスチャ開始時に一度だけ十分長い期限を置き、onChangedごとの再設定はしない。
    private func scheduleTimelineDragFailsafe(for gestureID: UUID) {
        timelineDragCleanupTask?.cancel()
        timelineDragCleanupTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            guard timelineDragGestureID == gestureID else { return }
            flushPendingTimelineShieldSync()
            clearTimelineDragState(resetTapGuard: true)
        }
    }

    /// 終了直後のButton再発火だけを抑え、ジェスチャ状態は保持しない。
    private func scheduleTimelineTapGuardCleanup(after delay: Duration) {
        timelineDragCleanupTask?.cancel()
        timelineDragCleanupTask = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            didDragTimelineHandle = false
            timelineDragCleanupTask = nil
        }
    }

    private func clearTimelineDragState(resetTapGuard: Bool) {
        timelineDragCleanupTask?.cancel()
        timelineDragCleanupTask = nil
        draggingTimelineHandle = nil
        timelineDragStartMinutes = nil
        timelineDragGestureID = nil
        timelineDragAnchorGestureID = nil
        if resetTapGuard {
            didDragTimelineHandle = false
        }
    }

    private func scheduleTimelineShieldSync() {
        isTimelineShieldSyncPending = true
        timelineShieldSyncTask?.cancel()
        timelineShieldSyncTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            guard isTimelineShieldSyncPending else { return }
            isTimelineShieldSyncPending = false
            timelineShieldSyncTask = nil
            model.syncShield()
        }
    }

    private func flushPendingTimelineShieldSync() {
        timelineShieldSyncTask?.cancel()
        timelineShieldSyncTask = nil
        guard isTimelineShieldSyncPending else { return }
        isTimelineShieldSyncPending = false
        model.syncShield()
    }

    private func timelineTimePicker(title: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .dopaFont(17, weight: .bold)
                .foregroundStyle(DesignTokens.primaryText)

            DatePicker(title, selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.wheel)
                .tint(DesignTokens.accent)

            if let timelineAdjustmentMessage {
                Text(timelineAdjustmentMessage)
                    .dopaFont(12, weight: .semibold, lineSpacing: 2)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(width: 300)
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
                        weeklyReportNotificationMinutes: $weeklyReportNotificationMinutes,
                        weeklyReportNotificationEnabled: $weeklyReportNotificationEnabled,
                        reflectionNotificationEnabled: $reflectionNotificationEnabled,
                        retentionSupportNotificationsEnabled: $retentionSupportNotificationsEnabled,
                        planNotificationsEnabled: $planNotificationsEnabled
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
                        liveLockTheme: $liveLockTheme,
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
                        value: liveLockTheme.localizedDisplayName
                    )
                }
                .buttonStyle(.plain)

                SettingsDivider()

                Group {
                    if model.storeService.isPro {
                        NavigationLink {
                            SettingsAccountView(
                                model: model,
                                paywallPlacement: $paywallPlacement
                            )
                        } label: {
                            proEntryLabel
                        }
                    } else {
                        Button {
                            paywallPlacement = .settingsProStatusRow
                        } label: {
                            proEntryLabel
                        }
                    }
                }
                .buttonStyle(.plain)
                .id(Self.planSectionID)

                if model.storeService.allowsFreeTesting {
                    SettingsDivider()
                    Toggle(isOn: Binding(
                        get: { model.storeService.isFreeTesting },
                        set: { model.storeService.setFreeTesting($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Freeでテスト（TestFlight限定）")
                                .dopaFont(15, weight: .semibold)
                            Text("購入履歴は消えません。オフにすると購入状態へ戻ります。")
                                .dopaFont(12, weight: .medium)
                                .foregroundStyle(DesignTokens.secondaryText)
                        }
                    }
                    .tint(DesignTokens.accent)
                    .padding(.vertical, 12)
                    .accessibilityIdentifier("settings.testflight.freeTesting")
                }
            }
        }
    }

    private var proEntryLabel: some View {
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
            if isScheduleWindowActive { scheduleWindowRow }
            if deepFocusSession != nil {
                runningSessionRow
            } else if !isScheduleWindowActive {
                sessionOptionChips
                if selectedSessionOption.durationMinutes != nil {
                    Toggle(String(localized: "settings.strict.toggle", defaultValue: "途中で解除しにくくする"), isOn: $isStrictSessionSelected)
                        .tint(DesignTokens.accent)
                    if isStrictSessionSelected {
                        Text(String(localized: "settings.strict.description", defaultValue: "終了まで通常の解除と対象・モードの変更を止めます。緊急解除には30秒の待機が必要です。iOS設定での権限取り消しは防げません。"))
                            .dopaFont(13, weight: .medium)
                            .foregroundStyle(DesignTokens.secondaryText)
                    }
                }
                startSessionButton
            }

            // 窓の内にいるのに実体が置かれていないときだけ出す。
            // 残り時間だけを見せて、実際は何も止まっていない状態を黙らせない。
            if model.showsDeepFocusUnarmedNotice,
               model.deepFocusSchedules.contains(where: DeepFocusWindowPolicy.isScheduleUsable) || deepFocusSession != nil {
                shieldUnarmedNotice
            }
        }
        .padding(.vertical, 14)
        .sheet(isPresented: $isStrictExitPresented, onDismiss: refreshDeepFocusState) {
            StrictSessionExitView(model: model)
        }
    }

    /// 画面では有効なのに、実際のブロックがまだ始まっていないことを伝える行。
    ///
    /// 解放はキャッシュ済みのProで通し、実体はStoreKitで権利を確かめられるまで置かない。
    /// その差が開いているあいだ、この行だけが「いま効いていない」と言える唯一の場所になる。
    private var shieldUnarmedNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .dopaFont(13, weight: .bold)
                .foregroundStyle(DesignTokens.danger)

            Text(
                String(
                    localized: "settings.block.check_notice",
                    defaultValue: "ブロックの準備を確認できません。権限と通信状態を確認して、再試行してください。既存のブロックは残る場合があります。"
                )
            )
            .dopaFont(13, weight: .semibold, lineSpacing: 3)
            .foregroundStyle(DesignTokens.primaryText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
            Button(String(localized: "settings.block.retry", defaultValue: "再試行")) {
                Task {
                    await model.storeService.refreshEntitlement()
                    model.syncShield()
                    refreshDeepFocusState()
                }
            }
            .tint(DesignTokens.accent)
            .frame(minHeight: DesignTokens.minTapTarget)
        }
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
                        defaultValue: "予定の終了後も、手動で始めた完全ブロックは続きます。"
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
        guard let end = model.deepFocusScheduleWindowEnd else {
            return String(localized: "settings.schedule.continuous", defaultValue: "予定が続く間")
        }
        return String(
            format: String(
                localized: "settings.deep_focus.schedule.active.until",
                defaultValue: "%@まで"
            ),
            Self.timeOfDayFormatter.string(from: end)
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
                if deepFocusSession?.isStrict == true { isStrictExitPresented = true }
                else { model.endDeepFocusSession(); refreshDeepFocusState() }
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
        let options = DeepFocusSessionOption.allCases
        // 1行に収まらない言語や文字サイズ（英語の「Until you unblock it」など）では、
        // 「解除するまで」を2行目へ送り、選択肢を画面の外へ隠さない。
        // 2行でも収まらない大きな文字サイズのときだけ横スクロールにする。
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    sessionOptionChip(option)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(options.filter { $0.durationMinutes != nil }, id: \.self) { option in
                        sessionOptionChip(option)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(options.filter { $0.durationMinutes == nil }, id: \.self) { option in
                        sessionOptionChip(option)
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        sessionOptionChip(option)
                    }
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
            if primaryRule == nil {
                handleBlockedAppSelectionTap()
            } else {
                model.startDeepFocusSession(durationMinutes: selectedSessionOption.durationMinutes, isStrict: isStrictSessionSelected && selectedSessionOption.durationMinutes != nil)
                refreshDeepFocusState()
            }
        } label: {
            Text(
                primaryRule == nil
                    ? String(
                        localized: "settings.deep_focus.choose_apps",
                        defaultValue: "完全ブロックするアプリを選ぶ"
                    )
                    : String(
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
    }

    /// 毎週の予定。既存のエディタを選択した予定に接続する。
    private var deepFocusScheduleBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(String(localized: "settings.schedule.select", defaultValue: "編集する予定"), selection: $selectedScheduleIndex) {
                Text(String(localized: "settings.schedule.first", defaultValue: "予定1")).tag(0)
                if scheduleCount > 1 {
                    Text(String(localized: "settings.schedule.second", defaultValue: "予定2")).tag(1)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedScheduleIndex) { _, _ in refreshDeepFocusState() }
            if scheduleCount < 2 {
                Button(String(localized: "settings.schedule.add", defaultValue: "予定を追加")) {
                    model.updateDeepFocusSchedule(.disabled, index: 1)
                    selectedScheduleIndex = 1
                    refreshDeepFocusState()
                }
                .frame(minHeight: DesignTokens.minTapTarget)
                .tint(DesignTokens.accent)
            } else if selectedScheduleIndex == 1 {
                Button(String(localized: "settings.schedule.remove", defaultValue: "予定2を削除"), role: .destructive) {
                    model.removeAdditionalDeepFocusSchedule()
                    selectedScheduleIndex = 0
                    refreshDeepFocusState()
                }
                .frame(minHeight: DesignTokens.minTapTarget)
            }
            Text(String(localized: "settings.schedule.scope", defaultValue: "予定は2件まで設定できます。手動セッションや就寝中のブロックと同時に使えます。"))
                .dopaFont(13, weight: .medium)
                .foregroundStyle(DesignTokens.secondaryText)
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
                defaultValue: "選んだ曜日と時間だけ、対象アプリを開けないようにします。"
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
        model.updateDeepFocusSchedule(schedule, index: selectedScheduleIndex)
        refreshDeepFocusState()
    }

    private func refreshDeepFocusState() {
        scheduleCount = model.deepFocusSchedules.count
        selectedScheduleIndex = min(selectedScheduleIndex, scheduleCount - 1)
        deepFocusSchedule = model.deepFocusSchedules[selectedScheduleIndex]
        deepFocusSession = model.deepFocusSession
        deepFocusRemainingSeconds = model.deepFocusSessionRemainingSeconds
        isScheduleWindowActive = model.blockConfiguration.allows(.weeklySchedule) && model.isDeepFocusScheduleWindowActive
    }

    /// 1秒ごとに残りを詰め、境界をまたいだ瞬間に同期まで通す。
    ///
    /// 拡張の境界コールバックを取りこぼしても、設定画面を開いたままの人はここで解除される。
    /// 「終わったのに開けない」を残さないための、3つ目の逃げ道。
    private func tickDeepFocusSession() {
        // 予定の時間帯を出入りしたら、表示も同期もやり直す。
        // 出入りで解除の導線の出し分けが変わるため、セッションが無くても見に行く。
        let scheduledNow = model.blockConfiguration.allows(.weeklySchedule) && model.isDeepFocusScheduleWindowActive
        if isScheduleWindowActive != scheduledNow {
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

    private var selectedCatalogItems: [SNSAppCatalogItem] {
        ((try? model.targetStore.selectedCatalogIDs()) ?? [])
            .compactMap { SNSAppCatalog.app(catalogID: $0) }
    }

    /// 上部の状態表示は現在の強さに効くリストを示す。
    /// 選択導線自体は下の2セクションで常に独立させる。
    private var targetIconSources: [AppIconSource] {
        let tokenSources = selectedBlockedAppTokens.map(AppIconSource.token)
        let catalogSources = selectedCatalogItems.map(AppIconSource.catalog)

        if model.blockConfiguration.blockEnabled, !tokenSources.isEmpty {
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

        if model.blockConfiguration.blockEnabled {
            return model.blockConfiguration.triggerSummary
        }

        return "\(String(localized: "settings.breath_duration.label", defaultValue: "一呼吸の長さ")) \(breathDurationText)"
    }

    private var breathDurationText: String {
        switch breathDurationSeconds {
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
        let selectedIDs = selectedCatalogItems.map(\.catalogID)
        guard !selectedIDs.isEmpty else { return false }
        return AutomationVerification.unverifiedCatalogIDs(
            selectedCatalogIDs: selectedIDs,
            verifiedCatalogIDs: verifiedAutomationCatalogIDs
        ).isEmpty
    }

    private var notificationSummary: String {
        var labels: [String] = []
        if weeklyReportNotificationEnabled {
            labels.append(
                String(
                    localized: "settings.lock_screen.weekly_report",
                    defaultValue: "毎週の記録通知"
                )
            )
        }
        if reflectionNotificationEnabled {
            labels.append(
                String(
                    localized: "settings.notifications.reflection.title",
                    defaultValue: "振り返りの通知"
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
        // 強さだけ選んで対象が空だと、何も止まらないまま止まっているつもりになる。
        // 効いていない状態を「効いています」と読める文言で覆わない。
        guard primaryRule != nil else {
            return String(
                localized: "settings.deep_focus.empty_targets_notice",
                defaultValue: "対象アプリを選ぶと、決めた時間だけ開けないようにできます。"
            )
        }
        // 夜だけ強化は止まる時間帯が違う。ディープフォーカスと同じ説明を出すと、
        // 昼も止まっていると読めてしまう。
        if model.blockConfiguration.allows(.night) && !model.blockConfiguration.allows(.manual) && !model.blockConfiguration.allows(.weeklySchedule) {
            // 1日に開ける回数がオンなら、日中も使い切れば開けない。「日中は開けます」と言い切らない。
            if model.dailyOpenLimitStatus.limit != nil {
                return String(
                    localized: "settings.night_only.description_with_limit",
                    defaultValue: "完全にブロックするアプリは、就寝時刻から起床時刻まで開けません。日中は1日の回数を使い切るまで開けます。"
                )
            }
            return String(
                localized: "settings.night_only.description",
                defaultValue: "完全にブロックするアプリは、就寝時刻から起床時刻まで開けません。日中は開けます。"
            )
        }
        // 窓を1つも持っていないディープフォーカスは、選んでいても何も止めない。
        // 効いていない状態を「効いています」と読める文言で覆わない。
        // ただし回数上限で止まっているあいだは「いま完全ブロック中のアプリはありません」が誤りになるため出さない。
        if model.dailyOpenLimitBlockSnapshot == nil, !DeepFocusWindowPolicy.hasConfiguredWindow(
            now: Date(),
            session: deepFocusSession,
            schedule: deepFocusSchedule
        ) {
            return String(
                localized: "settings.deep_focus.no_window_notice",
                defaultValue: "いま完全ブロック中のアプリはありません。時間を決めると、その間は選んだアプリを開けません。"
            )
        }
        return String(
            localized: "settings.deep_focus.description",
            defaultValue: "選んだアプリを、決めた時間だけ開けないようにします。今すぐ始めることも、毎週の予定を設定することもできます。"
        )
    }

    private var wakeTimeBinding: Binding<Date> {
        Binding(
            get: { SettingsTime.date(minutes: wakeTimeMinutes, defaultMinutes: 420) },
            set: {
                updateTimeline(
                    handle: .wake,
                    proposedMinutes: SettingsTime.minutes(from: $0),
                    source: .picker
                )
            }
        )
    }

    private var bedTimeBinding: Binding<Date> {
        Binding(
            get: { SettingsTime.date(minutes: bedTimeMinutes, defaultMinutes: 1_380) },
            set: {
                updateTimeline(
                    handle: .bed,
                    proposedMinutes: SettingsTime.minutes(from: $0),
                    source: .picker
                )
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
            return String(
                localized: "settings.authorization.denied_body",
                defaultValue: "時間帯の完全ブロックにはスクリーンタイムの許可が必要です。iPhoneの設定からいつでも許可できます。"
            )
        }
        return String(
            localized: "settings.authorization.body",
            defaultValue: "決めた時間はスクリーンタイムでアプリを完全にブロックします。利用データは端末内だけに保存されます。"
        )
    }

    private var primaryRule: TargetRule? {
        guard DeepFocusTargetGuard.hasTargets(in: rules) else { return nil }
        return rules.first { !$0.activitySelectionData.isEmpty }
    }

    /// 完全ブロック用のルール数。件数の上限判定はカタログのルールを数に入れない。
    private var blockRuleCount: Int {
        rules.filter { !$0.activitySelectionData.isEmpty }.count
    }

    private var selectedBlockedAppTokens: [ApplicationToken] {
        var tokens = Set<ApplicationToken>()
        let decoder = JSONDecoder()
        for rule in rules where rule.isEnabled && !rule.activitySelectionData.isEmpty {
            guard let selection = try? decoder.decode(
                FamilyActivitySelection.self,
                from: rule.activitySelectionData
            ) else {
                continue
            }
            tokens.formUnion(selection.applicationTokens)
        }
        let encoder = JSONEncoder()
        return tokens.sorted {
            let left = (try? encoder.encode($0).base64EncodedString()) ?? ""
            let right = (try? encoder.encode($1).base64EncodedString()) ?? ""
            return left < right
        }
    }

    private func refreshSettingsState() {
        model.ensureWakeSleepDefaults()
        breathDurationSeconds = settingsStore.breathDurationSeconds
        wakeTimeMinutes = settingsStore.wakeTimeMinutes ?? 420
        bedTimeMinutes = settingsStore.bedTimeMinutes ?? 1_380
        weeklyReportNotificationMinutes = settingsStore.weeklyReportNotificationMinutes
        verifiedAutomationCatalogIDs = settingsStore.verifiedAutomationCatalogIDs
        weeklyReportNotificationEnabled = settingsStore.weeklyReportNotificationEnabled
        reflectionNotificationEnabled = settingsStore.reflectionNotificationEnabled
        retentionSupportNotificationsEnabled = settingsStore.retentionSupportNotificationsEnabled
        planNotificationsEnabled = settingsStore.planNotificationsEnabled
        liveActivityEnabled = settingsStore.liveActivityEnabled
        liveLockTheme = model.liveLockTheme
        refreshDeepFocusState()

        model.screenTime.refresh()
        do {
            rules = try model.ruleStore.allRules()
        } catch {
            rules = []
            model.alertMessage = String(localized: "settings.error.data_load", defaultValue: "データを読み込めませんでした")
        }
    }

    private func handleBlockedAppSelectionTap() {
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

        let granted = await model.requestScreenTimeAuthorization()
        if granted {
            model.syncShield()
            isAuthorizationSheetPresented = false
        } else {
            authorizationWasDenied = true
        }
    }

    private func saveActivitySelection() {
        if model.saveBlockedAppSelection(activitySelection, mode: .deepFocus) {
            refreshSettingsState()
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

}
