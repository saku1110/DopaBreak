import DopaBreakCore
import FamilyControls
import SwiftUI
import UIKit

struct SettingsView: View {
    let model: AppModel
    let settingsStore: SettingsStore
    let onResetOnboarding: () -> Void

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
    @State private var isLockScreenCheckPresented = false
    @State private var isDeleteAllDataConfirmationPresented = false
    @State private var isDeletionFeedbackVisible = false
    @State private var morningNotificationEnabled = true
    @State private var weeklyReportNotificationEnabled = true
    @State private var retentionSupportNotificationsEnabled = true
    @State private var planNotificationsEnabled = true
    @State private var liveActivityEnabled = true
    @State private var selectedLockTheme: LockTheme = .e1
    @Environment(\.openURL) private var openURL

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
            withAnimation {
                proxy.scrollTo(Self.planSectionID, anchor: .top)
            }
        }
    }

    /// シート提示や状態同期はスクロール本体に付けたまま、NavigationStackで包むだけにする。
    private var settingsScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                targetSection

                deepFocusSection

                wakeSleepSection

                usageWatchSection

                lockSurfaceSection

                accountSection
                    .id(Self.planSectionID)

                privacySection

                appSection

                Text(String(localized: "settings.device_only_note", defaultValue: "SNSなどのアプリを止める機能は、iPhone実機でのみ動作します。"))
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
        .familyActivityPicker(
            isPresented: $isUsageWatchPickerPresented,
            selection: $usageWatchSelection
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
        .fullScreenCover(isPresented: $isLockScreenCheckPresented, onDismiss: {
            // 確認画面はアプリ内トグルを必要に応じてオンへ戻すため、表示値を取り直す。
            refreshSettingsState()
        }) {
            LockScreenCheckSheet(model: model) {
                isLockScreenCheckPresented = false
            }
        }
        .confirmationDialog(
            String(localized: "settings.delete_all.confirmation.title", defaultValue: "全データを削除しますか"),
            isPresented: $isDeleteAllDataConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.delete_all.confirmation.delete", defaultValue: "削除する"), role: .destructive) {
                deleteAllData()
            }
            Button(String(localized: "settings.delete_all.confirmation.cancel", defaultValue: "キャンセル"), role: .cancel) {}
        } message: {
            Text(String(localized: "settings.delete_all.confirmation.message", defaultValue: "目標・記録・設定がすべて削除されます。この操作は取り消せません。"))
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
        .onChange(of: isUsageWatchPickerPresented) { oldValue, newValue in
            guard oldValue, !newValue else {
                return
            }
            saveUsageWatchSelection()
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
            || isLockScreenCheckPresented
            || isDeleteAllDataConfirmationPresented
    }

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SmallLabel(text: String(localized: "settings.target.section", defaultValue: "対象"))

            CardContainer {
                VStack(spacing: 0) {
                    Button {
                        isTargetPickerPresented = true
                    } label: {
                        settingsRow(
                            label: String(localized: "settings.target.apps", defaultValue: "止めるアプリ"),
                            value: targetAppsSummary,
                            disclosure: .navigate
                        )
                    }
                    .buttonStyle(.plain)

                    if let targetAppClampNotice = model.targetAppClampNotice {
                        Text(targetAppClampNotice)
                            .dopaFont(13, weight: .semibold)
                            .foregroundStyle(DesignTokens.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 14)
                    }

                    divider
                    breathDurationRow

                    divider
                    Button {
                        isAutomationGuidePresented = true
                    } label: {
                        settingsRow(
                            label: String(localized: "settings.target.automation", defaultValue: "自動で一呼吸を出す設定"),
                            value: "",
                            disclosure: .navigate
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var wakeSleepSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SmallLabel(text: String(localized: "settings.schedule.section", defaultValue: "起床・就寝時刻"))

            CardContainer {
                VStack(spacing: 0) {
                    timePickerRow(
                        label: String(localized: "settings.schedule.wake_time", defaultValue: "起床時刻"),
                        selection: wakeTimeBinding
                    )

                    divider
                    timePickerRow(
                        label: String(localized: "settings.schedule.bed_time", defaultValue: "就寝時刻"),
                        selection: bedTimeBinding
                    )
                }
            }
        }
    }

    private var usageWatchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SmallLabel(
                text: String(
                    localized: "settings.usage_watch.section.title",
                    defaultValue: "利用時間の通知"
                )
            )

            CardContainer {
                VStack(spacing: 0) {
                    toggleRow(
                        label: String(
                            localized: "settings.usage_watch.enable.title",
                            defaultValue: "利用時間の通知を使う"
                        ),
                        isOn: usageWatchEnabledBinding
                    )
                    .disabled(isRequestingUsageWatchAuthorization)

                    divider

                    Button {
                        beginUsageWatchSelection(enableAfterSelection: false)
                    } label: {
                        settingsRow(
                            label: String(
                                localized: "settings.usage_watch.apps.title",
                                defaultValue: "時間をはかるアプリ"
                            ),
                            value: usageWatchSelectionSummary,
                            disclosure: .navigate
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isRequestingUsageWatchAuthorization)

                    if model.storeService.isPro {
                        divider
                        usageWatchIntervalRow

                        divider
                        toggleRow(
                            label: String(
                                localized: "settings.usage_watch.night_mode.title",
                                defaultValue: "就寝前は間隔を短く"
                            ),
                            isOn: usageWatchNightModeBinding
                        )
                    } else {
                        divider
                        Text(
                            String(
                                localized: "settings.usage_watch.free_rule.description",
                                defaultValue: "連続で2時間になったら1日1回だけお知らせします"
                            )
                        )
                        .dopaFont(14, weight: .medium, lineSpacing: 4)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)

                        divider
                        usageWatchLockedRow(
                            label: String(
                                localized: "settings.usage_watch.interval.title",
                                defaultValue: "問いかけの間隔"
                            )
                        )

                        divider
                        usageWatchLockedRow(
                            label: String(
                                localized: "settings.usage_watch.night_mode.title",
                                defaultValue: "就寝前は間隔を短く"
                            )
                        )
                    }
                }
            }

            Text(usageWatchFootnote)
            .dopaFont(13, weight: .medium, lineSpacing: 3)
            .foregroundStyle(
                usageWatchAuthorizationWasDenied || model.usageWatch.didLastMonitoringStartFail
                    ? DesignTokens.danger
                    : DesignTokens.secondaryText
            )
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
        }
    }

    /// 登録に失敗するとトグルが黙って戻るだけになるため、理由をその場に出す。
    private var usageWatchFootnote: String {
        guard model.usageWatch.didLastMonitoringStartFail else {
            return String(
                localized: "settings.usage_watch.permission.description",
                defaultValue: "スクリーンタイムの許可が必要です。利用データはこの端末の外に出ません"
            )
        }
        return String(
            localized: "settings.usage_watch.start_failed.description",
            defaultValue: "利用時間の通知を開始できませんでした。時間をはかるアプリを選び直してからもう一度お試しください"
        )
    }

    private var usageWatchIntervalRow: some View {
        HStack(spacing: 12) {
            Text(
                String(
                    localized: "settings.usage_watch.interval.title",
                    defaultValue: "問いかけの間隔"
                )
            )
            .dopaFont(16, weight: .semibold)
            .foregroundStyle(DesignTokens.primaryText)

            Spacer()

            Picker(
                String(
                    localized: "settings.usage_watch.interval.title",
                    defaultValue: "問いかけの間隔"
                ),
                selection: usageWatchIntervalBinding
            ) {
                ForEach(UsageWatchConfiguration.allowedQuestionIntervals, id: \.self) { minutes in
                    Text(usageWatchIntervalLabel(minutes)).tag(minutes)
                }
            }
            .pickerStyle(.menu)
            .tint(DesignTokens.secondaryText)
        }
        .padding(.vertical, 14)
    }

    private func usageWatchLockedRow(label: String) -> some View {
        Button {
            paywallPlacement = .settingsUsageWatchGate
        } label: {
            HStack(spacing: 12) {
                Text(label)
                    .dopaFont(16, weight: .semibold)
                    .foregroundStyle(DesignTokens.primaryText)

                Spacer()

                Label(
                    String(localized: "settings.status.pro", defaultValue: "Pro"),
                    systemImage: "lock.fill"
                )
                .dopaFont(13, weight: .bold)
                .foregroundStyle(DesignTokens.secondaryText)

                Image(systemName: "chevron.right")
                    .dopaFont(13, weight: .semibold)
                    .foregroundStyle(DesignTokens.tertiaryText)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private var lockSurfaceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SmallLabel(text: String(localized: "settings.lock_screen.section", defaultValue: "ロック画面の表示"))

            CardContainer {
                VStack(spacing: 0) {
                    toggleRow(
                        label: String(localized: "settings.lock_screen.morning_notification", defaultValue: "朝の目標通知"),
                        isOn: morningNotificationBinding
                    )

                    divider
                    timePickerRow(
                        label: String(localized: "settings.lock_screen.notification_time", defaultValue: "通知時刻"),
                        selection: morningNotificationTimeBinding
                    )
                        .disabled(!morningNotificationEnabled)
                        .opacity(morningNotificationEnabled ? 1 : 0.45)

                    divider
                    toggleRow(
                        label: String(localized: "settings.lock_screen.weekly_report", defaultValue: "週次レポート通知"),
                        isOn: weeklyReportNotificationBinding
                    )

                    divider
                    toggleRow(
                        label: String(
                            localized: "settings.notifications.retention_support.title",
                            defaultValue: "継続サポートの通知"
                        ),
                        isOn: retentionSupportNotificationsBinding
                    )

                    divider
                    toggleRow(
                        label: String(
                            localized: "settings.notifications.plan.title",
                            defaultValue: "プランに関する通知"
                        ),
                        isOn: planNotificationsBinding
                    )

                    divider
                    toggleRow(
                        label: String(localized: "settings.lock_screen.live_activity", defaultValue: "Live Activity"),
                        isOn: liveActivityBinding
                    )

                    divider
                    Button {
                        isLockScreenCheckPresented = true
                    } label: {
                        settingsRow(
                            label: String(localized: "settings.lock_screen.check", defaultValue: "ロック画面で確かめる"),
                            value: "",
                            disclosure: .navigate
                        )
                    }
                    .buttonStyle(.plain)

                    divider
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "settings.lock_screen.theme", defaultValue: "テーマ"))
                            .dopaFont(16, weight: .semibold)
                            .foregroundStyle(DesignTokens.primaryText)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(LockTheme.allCases, id: \.self) { theme in
                                    themeChip(theme)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 14)
                }
            }
        }
    }

    private func themeChip(_ theme: LockTheme) -> some View {
        let isSelected = selectedLockTheme == theme
        let isAllowed = model.entitlementGate.lockThemeAllowed(theme)
        let palette = theme.palette

        return Button {
            guard isAllowed else {
                paywallPlacement = .settingsThemeGate
                return
            }
            selectedLockTheme = theme
            settingsStore.lockTheme = theme
            model.refreshLockSurfaces()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(lockThemeColor: palette.accent))
                    .frame(width: 8, height: 8)
                Text(theme.displayName)
                    .dopaFont(13, weight: .bold)
                if theme != .e1 {
                    Text(String(localized: "settings.status.pro", defaultValue: "Pro"))
                        .dopaFont(9, weight: .black)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(lockThemeColor: palette.accent).opacity(0.18))
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isSelected ? DesignTokens.background : DesignTokens.primaryText)
            .padding(.horizontal, 12)
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

    private func toggleRow(label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .dopaFont(16, weight: .semibold)
                .foregroundStyle(DesignTokens.primaryText)
        }
        .tint(DesignTokens.accent)
        .padding(.vertical, 14)
    }

    /// 完全ブロック（Pro）。「止めるアプリ」＝通常の一呼吸の対象とは別物なので、区画も分ける（docs/12 §5）。
    private var deepFocusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SmallLabel(
                text: String(
                    localized: "settings.deep_focus.section",
                    defaultValue: "完全ブロック"
                )
            )

            CardContainer {
                VStack(spacing: 0) {
                    if isDeepFocusUnlocked {
                        modePickerRow

                        divider
                        screenTimeRow

                        divider
                        deepFocusTargetsRow
                    } else {
                        deepFocusLockedRow(
                            label: String(localized: "settings.mode.label", defaultValue: "止める強さ")
                        )

                        divider
                        deepFocusLockedRow(
                            label: String(
                                localized: "settings.deep_focus.targets.label",
                                defaultValue: "完全ブロックの対象"
                            )
                        )
                    }
                }
            }

            Text(deepFocusFootnote)
                .dopaFont(13, weight: .medium, lineSpacing: 3)
                .foregroundStyle(DesignTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
    }

    /// Proかどうかだけで決める。権利が未確定でも上位機能を勝手に開けない。
    /// （`isPro` は端末に控えたキャッシュから起動直後にも立つため、通信が切れた課金者は締め出さない）
    private var isDeepFocusUnlocked: Bool {
        model.entitlementGate.strictModeAllowed
    }

    /// 選んだ強さによって、いま何が起きるのかをその場に書く。
    /// ディープフォーカス以外では対象を選んでもブロックされないため、黙って無効にしない。
    private var deepFocusFootnote: String {
        guard isDeepFocusUnlocked else {
            return String(
                localized: "settings.deep_focus.locked_notice",
                defaultValue: "ディープフォーカスにすると、選んだアプリを完全に止められます。"
            )
        }
        guard selectedMode.usesShield else {
            return String(
                localized: "settings.deep_focus.standard_notice",
                defaultValue: "いまは一呼吸の確認だけが出ます。ディープフォーカスに変えると、選んだアプリが開けなくなります。"
            )
        }
        // 強さだけ選んで対象が空だと、何も止まらないまま止まっているつもりになる。
        // 効いていない状態を「効いています」と読める文言で覆わない。
        guard primaryRule != nil else {
            return String(
                localized: "settings.deep_focus.empty_targets_notice",
                defaultValue: "完全ブロックの対象を選ぶと、そのアプリは開けなくなります。"
            )
        }
        // 夜だけ強化は止まる時間帯が違う。ディープフォーカスと同じ説明を出すと、
        // 昼も止まっていると読めてしまう。
        if selectedMode == .nightOnly {
            return String(
                localized: "settings.night_only.description",
                defaultValue: "選んだアプリは就寝から起床まで開けなくなります。昼は一呼吸の確認だけが出ます。"
            )
        }
        return String(
            localized: "settings.deep_focus.description",
            defaultValue: "選んだアプリは開けなくなります。強さを標準へ戻すまで続きます。"
        )
    }

    private var deepFocusTargetsRow: some View {
        Button {
            handleAppSelectionTap()
        } label: {
            settingsRow(
                label: String(
                    localized: "settings.deep_focus.targets.label",
                    defaultValue: "完全ブロックの対象"
                ),
                value: appSelectionSummary,
                disclosure: .navigate
            )
        }
        .buttonStyle(.plain)
        .disabled(isRequestingAuthorization)
    }

    private func deepFocusLockedRow(label: String) -> some View {
        Button {
            paywallPlacement = .settingsModeGate
        } label: {
            HStack(spacing: 12) {
                Text(label)
                    .dopaFont(16, weight: .semibold)
                    .foregroundStyle(DesignTokens.primaryText)

                Spacer()

                Label(
                    String(localized: "settings.status.pro", defaultValue: "Pro"),
                    systemImage: "lock.fill"
                )
                .dopaFont(13, weight: .bold)
                .foregroundStyle(DesignTokens.secondaryText)

                Image(systemName: "chevron.right")
                    .dopaFont(13, weight: .semibold)
                    .foregroundStyle(DesignTokens.tertiaryText)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private var targetAppsSummary: String {
        let ids = (try? model.targetStore.selectedCatalogIDs()) ?? []
        guard !ids.isEmpty else {
            return String(localized: "settings.value.not_set", defaultValue: "未設定")
        }
        let names = ids.compactMap { SNSAppCatalog.app(catalogID: $0)?.displayName }
        return names.joined(separator: "・")
    }

    private var breathDurationRow: some View {
        HStack(spacing: 12) {
            Text(String(localized: "settings.breath_duration.label", defaultValue: "一呼吸の長さ"))
                .dopaFont(16, weight: .semibold)
                .foregroundStyle(DesignTokens.primaryText)

            Spacer()

            Picker(String(localized: "settings.breath_duration.label", defaultValue: "一呼吸の長さ"), selection: breathDurationBinding) {
                Text(String(localized: "settings.breath_duration.three_seconds", defaultValue: "3秒")).tag(3)
                Text(String(localized: "settings.breath_duration.five_seconds", defaultValue: "5秒")).tag(5)
                Text(String(localized: "settings.breath_duration.eight_seconds", defaultValue: "8秒")).tag(8)
            }
            .pickerStyle(.menu)
            .tint(DesignTokens.secondaryText)
        }
        .padding(.vertical, 14)
    }

    private var breathDurationBinding: Binding<Int> {
        Binding(
            get: { settingsStore.breathDurationSeconds },
            set: { settingsStore.breathDurationSeconds = $0 }
        )
    }

    private func timePickerRow(label: String, selection: Binding<Date>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .dopaFont(16, weight: .semibold)
                .foregroundStyle(DesignTokens.primaryText)

            Spacer()

            DatePicker(label, selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(DesignTokens.secondaryText)
        }
        .padding(.vertical, 14)
    }

    private var wakeTimeBinding: Binding<Date> {
        Binding(
            get: { dateForTime(minutes: settingsStore.wakeTimeMinutes, defaultMinutes: 420) },
            set: {
                settingsStore.wakeTimeMinutes = minutes(from: $0)
                model.usageWatch.configurationDidChange(isPro: model.storeService.isPro)
                // 夜だけ強化の窓もここで決まる。いまブロックすべきかの再計算と
                // 監視の張り直しを同時にやる `syncShield` を通す。
                model.syncShield()
            }
        )
    }

    private var bedTimeBinding: Binding<Date> {
        Binding(
            get: { dateForTime(minutes: settingsStore.bedTimeMinutes, defaultMinutes: 1_380) },
            set: {
                settingsStore.bedTimeMinutes = minutes(from: $0)
                model.usageWatch.configurationDidChange(isPro: model.storeService.isPro)
                model.syncShield()
            }
        )
    }

    private var usageWatchEnabledBinding: Binding<Bool> {
        Binding(
            get: { model.usageWatch.isEnabled },
            set: { isEnabled in
                if isEnabled {
                    beginUsageWatchSelection(enableAfterSelection: true)
                } else {
                    model.usageWatch.disable()
                }
            }
        )
    }

    private var usageWatchIntervalBinding: Binding<Int> {
        Binding(
            get: { model.usageWatch.questionIntervalMinutes },
            set: { minutes in
                model.usageWatch.setQuestionIntervalMinutes(
                    minutes,
                    isPro: model.storeService.isPro
                )
            }
        )
    }

    private var usageWatchNightModeBinding: Binding<Bool> {
        Binding(
            get: { model.usageWatch.nightModeEnabled },
            set: { isEnabled in
                model.usageWatch.setNightModeEnabled(
                    isEnabled,
                    isPro: model.storeService.isPro
                )
            }
        )
    }

    private var morningNotificationBinding: Binding<Bool> {
        Binding(
            get: { morningNotificationEnabled },
            set: { value in
                morningNotificationEnabled = value
                settingsStore.morningNotificationEnabled = value
                model.refreshLockSurfaces()
            }
        )
    }

    private var morningNotificationTimeBinding: Binding<Date> {
        Binding(
            get: { dateForTime(minutes: settingsStore.morningNotificationMinutes, defaultMinutes: 420) },
            set: { date in
                settingsStore.morningNotificationMinutes = minutes(from: date)
                model.refreshLockSurfaces()
            }
        )
    }

    private var weeklyReportNotificationBinding: Binding<Bool> {
        Binding(
            get: { weeklyReportNotificationEnabled },
            set: { value in
                weeklyReportNotificationEnabled = value
                settingsStore.weeklyReportNotificationEnabled = value
                model.refreshLockSurfaces()
            }
        )
    }

    private var retentionSupportNotificationsBinding: Binding<Bool> {
        Binding(
            get: { retentionSupportNotificationsEnabled },
            set: { value in
                retentionSupportNotificationsEnabled = value
                settingsStore.retentionSupportNotificationsEnabled = value
                model.refreshLockSurfaces()
            }
        )
    }

    private var planNotificationsBinding: Binding<Bool> {
        Binding(
            get: { planNotificationsEnabled },
            set: { value in
                planNotificationsEnabled = value
                settingsStore.planNotificationsEnabled = value
                model.refreshLockSurfaces()
            }
        )
    }

    private var liveActivityBinding: Binding<Bool> {
        Binding(
            get: { liveActivityEnabled },
            set: { value in
                liveActivityEnabled = value
                settingsStore.liveActivityEnabled = value
                model.refreshLockSurfaces(restartLiveActivity: value)
            }
        )
    }

    /// 保存してある「壁時計の分数」を、その時分そのものを指すDateへ戻す。
    ///
    /// 0時から分を足す形にすると、夏時間の切り替わる日（23時間・25時間の日）に
    /// 表示が1時間ずれる。時分を直接指定して組み立てれば、日の長さに左右されない。
    private func dateForTime(minutes: Int?, defaultMinutes: Int) -> Date {
        let calendar = Calendar.current
        let normalized = normalizedMinutes(minutes ?? defaultMinutes)
        let now = Date()
        return calendar.date(
            bySettingHour: normalized / 60,
            minute: normalized % 60,
            second: 0,
            of: now
        ) ?? now
    }

    /// 表示側と対になる戻し。こちらも時分の成分だけを見る。
    private func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ((components.hour ?? 0) * 60) + (components.minute ?? 0)
    }

    private func normalizedMinutes(_ value: Int) -> Int {
        ((value % 1_440) + 1_440) % 1_440
    }

    private var appSection: some View {
        CardContainer {
            VStack(spacing: 0) {
                settingsRow(
                    label: String(localized: "settings.app.version", defaultValue: "バージョン"),
                    value: versionText
                )
                divider
                Button {
                    openFeedbackEmail()
                } label: {
                    settingsRow(
                        label: String(
                            localized: "settings.feedback.title",
                            defaultValue: "フィードバックを送る"
                        ),
                        value: "",
                        disclosure: .external
                    )
                }
                .buttonStyle(.plain)
                #if DEBUG
                divider
                Button {
                    onResetOnboarding()
                } label: {
                    settingsRow(
                        label: String(localized: "settings.debug.replay_onboarding", defaultValue: "オンボーディングをもう一度見る"),
                        value: "",
                        disclosure: .navigate
                    )
                }
                .buttonStyle(.plain)
                divider
                Button {
                    copyFunnelEvents()
                } label: {
                    settingsRow(
                        label: String(localized: "settings.debug.copy_event_log", defaultValue: "イベントログをコピー"),
                        value: ""
                    )
                }
                .buttonStyle(.plain)
                #endif
            }
        }
    }

    #if DEBUG
    private func copyFunnelEvents() {
        guard let events = try? model.funnelEventStore.allEvents(),
              let data = try? JSONEncoder().encode(events),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        UIPasteboard.general.string = json
    }
    #endif

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SmallLabel(text: String(localized: "settings.account.section", defaultValue: "アカウント/課金"))

            CardContainer {
                VStack(spacing: 0) {
                    if model.storeService.isPro {
                        settingsRow(
                            label: String(localized: "settings.account.pro_status", defaultValue: "Pro状態"),
                            value: String(localized: "settings.status.pro", defaultValue: "Pro")
                        )
                    } else {
                        Button {
                            paywallPlacement = .settingsProStatusRow
                        } label: {
                            settingsRow(
                                label: String(localized: "settings.account.pro_status", defaultValue: "Pro状態"),
                                value: String(localized: "settings.status.free", defaultValue: "Free"),
                                disclosure: .navigate
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // 「Freeだから買い切りを勧める」はユーザーに見える判断のため、
                    // 解決を試みただけの `hasResolvedEntitlement` ではなく確定済みで出し分ける。
                    // 取得に失敗しただけの課金者に購入行を見せない。
                    if model.storeService.hasConfirmedEntitlement && !model.storeService.isPro {
                        divider

                        Button {
                            Task {
                                await purchaseLifetimePlan()
                            }
                        } label: {
                            ZStack(alignment: .trailing) {
                                settingsRow(
                                    label: String(localized: "settings.account.lifetime_plan", defaultValue: "買い切りプラン"),
                                    value: model.storeService.lifetimeProduct?.displayPrice
                                        ?? String(localized: "settings.value.unavailable", defaultValue: "—")
                                )

                                if model.storeService.isPurchasing {
                                    ProgressView()
                                        .tint(DesignTokens.secondaryText)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isBillingBusy)
                    }

                    divider

                    Button {
                        Task {
                            await model.restorePurchases()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(String(localized: "settings.account.restore", defaultValue: "購入を復元"))
                                .dopaFont(16, weight: .semibold)
                                .foregroundStyle(DesignTokens.primaryText)

                            Spacer()

                            if model.storeService.isRestoring {
                                ProgressView()
                                    .tint(DesignTokens.secondaryText)
                            }
                        }
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .disabled(isBillingBusy)
                }
            }
        }
    }

    private var isBillingBusy: Bool {
        model.storeService.isLoadingProducts
            || model.storeService.isPurchasing
            || model.storeService.isRestoring
    }

    @MainActor
    private func purchaseLifetimePlan() async {
        if model.storeService.lifetimeProduct == nil {
            await model.storeService.loadProducts()
        }

        guard let lifetimeProduct = model.storeService.lifetimeProduct else {
            model.alertMessage = String(localized: "settings.error.product_load", defaultValue: "商品情報を読み込めませんでした")
            return
        }

        guard !model.storeService.isPro else { return }
        let didBecomePro = await model.storeService.purchase(lifetimeProduct)
        if !didBecomePro, let message = model.storeService.alertMessage {
            model.alertMessage = message
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SmallLabel(text: String(localized: "settings.privacy.section", defaultValue: "プライバシー"))

            CardContainer {
                VStack(spacing: 0) {
                    Link(destination: AppURLs.privacy) {
                        settingsRow(
                            label: String(localized: "settings.privacy.policy", defaultValue: "プライバシーポリシー"),
                            value: "",
                            disclosure: .external
                        )
                    }
                    .buttonStyle(.plain)

                    divider

                    Link(destination: AppURLs.terms) {
                        settingsRow(
                            label: String(localized: "settings.privacy.terms", defaultValue: "利用規約"),
                            value: "",
                            disclosure: .external
                        )
                    }
                    .buttonStyle(.plain)

                    divider

                    Button {
                        isDeleteAllDataConfirmationPresented = true
                    } label: {
                        settingsRow(
                            label: String(localized: "settings.privacy.delete_all", defaultValue: "全データを削除"),
                            value: isDeletionFeedbackVisible
                                ? String(localized: "settings.privacy.deleted", defaultValue: "削除しました")
                                : "",
                            labelColor: DesignTokens.danger,
                            valueColor: DesignTokens.accent
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func deleteAllData() {
        guard model.deleteAllLocalData() else {
            return
        }

        refreshSettingsState()
        isDeletionFeedbackVisible = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            isDeletionFeedbackVisible = false
        }
    }

    @ViewBuilder
    private var screenTimeRow: some View {
        if model.screenTime.isAuthorized {
            settingsRow(
                label: String(localized: "settings.screen_time.label", defaultValue: "スクリーンタイム"),
                value: String(localized: "settings.screen_time.authorized", defaultValue: "許可済み")
            )
        } else {
            Button {
                shouldOpenPickerAfterAuthorization = false
                authorizationWasDenied = false
                isAuthorizationSheetPresented = true
            } label: {
                settingsRow(
                    label: String(localized: "settings.screen_time.label", defaultValue: "スクリーンタイム"),
                    value: String(localized: "settings.screen_time.not_authorized", defaultValue: "未許可"),
                    disclosure: .navigate
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var modePickerRow: some View {
        HStack(spacing: 12) {
            Text(String(localized: "settings.mode.label", defaultValue: "止める強さ"))
                .dopaFont(16, weight: .semibold)
                .foregroundStyle(DesignTokens.primaryText)

            Spacer()

            Picker(String(localized: "settings.mode.label", defaultValue: "止める強さ"), selection: modeBinding) {
                ForEach(InterventionMode.selectable, id: \.self) { mode in
                    Text(mode.displayTitle).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .tint(DesignTokens.secondaryText)
        }
        .padding(.vertical, 14)
    }

    private var authorizationSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(String(localized: "settings.authorization.title", defaultValue: "SNSの前で止める許可"))
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
            return String(localized: "settings.authorization.denied_body", defaultValue: "許可がないため、SNSを開く前の確認はまだ使えません。設定からいつでも有効にできます。")
        }
        return String(localized: "settings.authorization.body", defaultValue: "選んだSNSを開こうとした瞬間に確認画面を出すために、iOSのスクリーンタイムを使います。使用データは端末内に保存されます。")
    }

    private func settingsRow(
        label: String,
        value: String,
        labelColor: Color = DesignTokens.primaryText,
        valueColor: Color = DesignTokens.secondaryText,
        disclosure: SettingsRowDisclosure = .none
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .dopaFont(16, weight: .semibold)
                .foregroundStyle(labelColor)

            Spacer()

            Text(value)
                .dopaFont(14, weight: .semibold)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)

            if let symbol = disclosure.symbolName {
                Image(systemName: symbol)
                    .dopaFont(13, weight: .semibold)
                    .foregroundStyle(DesignTokens.tertiaryText)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 14)
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignTokens.hairline)
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    /// 完全ブロックの対象を持つルール。
    ///
    /// 通常の一呼吸で使うカタログ由来のルールは選択データが空で、この画面の
    /// 「完全ブロックの対象」とは別物。`rules.first` で拾うとカタログのルールを
    /// 完全ブロックの選択で上書きしてしまうため、選択データの有無で見分ける。
    private var primaryRule: TargetRule? {
        rules.first { !$0.activitySelectionData.isEmpty }
    }

    /// 完全ブロック用のルール数。件数の上限判定はカタログのルールを数に入れない。
    private var blockRuleCount: Int {
        rules.filter { !$0.activitySelectionData.isEmpty }.count
    }

    private var appSelectionSummary: String {
        guard let primaryRule else {
            return String(localized: "settings.value.not_set", defaultValue: "未設定")
        }

        let counts = selectionCounts(for: primaryRule)
        var summaries: [String] = []
        if counts.applications > 0 {
            summaries.append(String(localized: "settings.selection.app_count", defaultValue: "アプリ\(counts.applications)個"))
        }
        if counts.categories > 0 {
            summaries.append(String(localized: "settings.selection.category_count", defaultValue: "カテゴリ\(counts.categories)個"))
        }
        if counts.webDomains > 0 {
            summaries.append(String(localized: "settings.selection.website_count", defaultValue: "Webサイト\(counts.webDomains)個"))
        }
        return summaries.isEmpty
            ? String(localized: "settings.value.not_set", defaultValue: "未設定")
            : summaries.joined(separator: "・")
    }

    private var ruleEnabledBinding: Binding<Bool> {
        Binding(
            get: {
                primaryRule?.isEnabled ?? false
            },
            set: { isEnabled in
                setRuleEnabled(isEnabled)
            }
        )
    }

    private var modeBinding: Binding<InterventionMode> {
        Binding(
            get: {
                selectedMode
            },
            set: { mode in
                setSelectedMode(mode)
            }
        )
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

    private var usageWatchSelectionSummary: String {
        guard model.usageWatch.selectedTokenCount > 0 else {
            return String(localized: "settings.value.not_set", defaultValue: "未設定")
        }
        return model.usageWatch.selectedTokenCount.formatted()
    }

    private func usageWatchIntervalLabel(_ minutes: Int) -> String {
        String.localizedStringWithFormat(
            String(
                localized: "settings.usage_watch.interval.minutes_format",
                defaultValue: "%lld分ごと"
            ),
            Int64(minutes)
        )
    }

    private func beginUsageWatchSelection(enableAfterSelection: Bool) {
        guard !isRequestingUsageWatchAuthorization else {
            return
        }

        isRequestingUsageWatchAuthorization = true
        Task { @MainActor in
            defer { isRequestingUsageWatchAuthorization = false }
            let authorized = await model.usageWatch.requestAuthorization(using: model.screenTime)
            guard authorized else {
                usageWatchAuthorizationWasDenied = true
                shouldEnableUsageWatchAfterPicker = false
                return
            }

            usageWatchAuthorizationWasDenied = false
            shouldEnableUsageWatchAfterPicker = enableAfterSelection
            usageWatchSelection = model.usageWatch.selection
            isUsageWatchPickerPresented = true
        }
    }

    private func saveUsageWatchSelection() {
        let shouldEnable = shouldEnableUsageWatchAfterPicker
        shouldEnableUsageWatchAfterPicker = false

        if shouldEnable {
            model.usageWatch.enable(
                with: usageWatchSelection,
                isPro: model.storeService.isPro
            )
        } else {
            model.usageWatch.updateSelection(
                usageWatchSelection,
                isPro: model.storeService.isPro
            )
        }
        usageWatchAuthorizationWasDenied = false
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

    private func setRuleEnabled(_ isEnabled: Bool) {
        guard let rule = primaryRule else {
            return
        }

        do {
            if isEnabled {
                if rule.mode == .deepFocus,
                   model.storeService.hasConfirmedEntitlement,
                   !model.entitlementGate.strictModeAllowed {
                    try model.ruleStore.updateMode(id: rule.id, mode: .standard)
                    selectedMode = .standard
                }
                try model.ruleStore.enableRule(id: rule.id)
            } else {
                try model.ruleStore.disableRule(id: rule.id)
            }
            refreshSettingsState()
            model.syncShield()
        } catch CoreError.validation(let message) {
            model.alertMessage = message
        } catch {
            model.alertMessage = String(localized: "settings.error.data_save", defaultValue: "データを保存できませんでした")
        }
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

    private func selectionCounts(for rule: TargetRule) -> (applications: Int, categories: Int, webDomains: Int) {
        guard let selection = try? JSONDecoder().decode(
            FamilyActivitySelection.self,
            from: rule.activitySelectionData
        ) else {
            return (0, 0, 0)
        }
        return (
            selection.applicationTokens.count,
            selection.categoryTokens.count,
            selection.webDomainTokens.count
        )
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

    private var versionText: String {
        let shortVersion = appShortVersion
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch build {
        case let build?:
            return "\(shortVersion) (\(build))"
        case nil:
            return shortVersion
        }
    }

    private var appShortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func openFeedbackEmail() {
        guard let url = AppURLs.feedbackEmail(appVersion: appShortVersion) else { return }
        openURL(url)
    }
}

/// 設定行の右端に出す記号。
/// タップして「何が起きるか」を記号で見分けられるようにする（アプリ内で開く／アプリの外へ出る）。
/// 押すだけで完結する操作（削除・コピー・購入）には付けない。付けると遷移だと誤解されるため。
enum SettingsRowDisclosure {
    case none
    /// アプリ内で画面やシートが開く。
    case navigate
    /// Safari等、アプリの外へ出る。
    case external

    var symbolName: String? {
        switch self {
        case .none: return nil
        case .navigate: return "chevron.right"
        case .external: return "arrow.up.right"
        }
    }
}
