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
    @State private var paywallPlacement: PaywallPlacement?
    @State private var isTargetPickerPresented = false
    @State private var shouldPresentTargetAppPaywallAfterDismiss = false
    @State private var isAutomationGuidePresented = false
    @State private var isDeleteAllDataConfirmationPresented = false
    @State private var isDeletionFeedbackVisible = false
    @State private var morningNotificationEnabled = true
    @State private var weeklyReportNotificationEnabled = true
    @State private var liveActivityEnabled = true
    @State private var selectedLockTheme: LockTheme = .e1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                ScreenHeader(
                    eyebrow: String(localized: "settings.header.eyebrow", defaultValue: "SETTINGS"),
                    title: String(localized: "settings.header.title", defaultValue: "設定")
                )
                    .padding(.top, 18)

                targetSection

                wakeSleepSection

                lockSurfaceSection

                accountSection

                privacySection

                appSection

                Text(String(localized: "settings.device_only_note", defaultValue: "SNSなどのアプリを止める機能は、iPhone実機でのみ動作します。"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, DesignTokens.horizontalPadding)
            .padding(.bottom, 24)
        }
        .dopaScreenBackground()
        .onAppear {
            refreshSettingsState()
            model.isChildModalActive = isAnyChildModalPresented
        }
        .onChange(of: isAnyChildModalPresented) { _, isPresented in
            model.isChildModalActive = isPresented
        }
        .sheet(isPresented: $isAuthorizationSheetPresented) {
            authorizationSheet
        }
        .familyActivityPicker(
            isPresented: $isFamilyActivityPickerPresented,
            selection: $activitySelection
        )
        .fullScreenCover(item: $paywallPlacement) { placement in
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
    }

    private var isAnyChildModalPresented: Bool {
        isAuthorizationSheetPresented
            || isFamilyActivityPickerPresented
            || paywallPlacement != nil
            || isTargetPickerPresented
            || isAutomationGuidePresented
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
                            value: targetAppsSummary
                        )
                    }
                    .buttonStyle(.plain)

                    if let day14ClampNotice = model.day14ClampNotice {
                        Text(day14ClampNotice)
                            .font(.system(size: 13, weight: .semibold))
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
                            value: ""
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
                        label: String(localized: "settings.lock_screen.live_activity", defaultValue: "Live Activity"),
                        isOn: liveActivityBinding
                    )

                    divider
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "settings.lock_screen.theme", defaultValue: "テーマ"))
                            .font(.system(size: 16, weight: .semibold))
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
                    .font(.system(size: 13, weight: .bold))
                if theme != .e1 {
                    Text(String(localized: "settings.status.pro", defaultValue: "Pro"))
                        .font(.system(size: 9, weight: .black))
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
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignTokens.primaryText)
        }
        .tint(DesignTokens.accent)
        .padding(.vertical, 14)
    }

    // MVP: スクリーンタイム許可・完全ブロック（FamilyActivityPicker）・止める強さの行はUI非表示。
    // 実装コードは温存（screenTimeRow / modePickerRow / ruleEnabledBinding / familyActivityPicker配線 等）。
    // v1.1のdeepFocus/nightOnly再配線時に再利用する（docs/12 §5）。

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
                .font(.system(size: 16, weight: .semibold))
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
                .font(.system(size: 16, weight: .semibold))
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
            set: { settingsStore.wakeTimeMinutes = minutes(from: $0) }
        )
    }

    private var bedTimeBinding: Binding<Date> {
        Binding(
            get: { dateForTime(minutes: settingsStore.bedTimeMinutes, defaultMinutes: 1_380) },
            set: { settingsStore.bedTimeMinutes = minutes(from: $0) }
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

    private func dateForTime(minutes: Int?, defaultMinutes: Int) -> Date {
        let calendar = Calendar.current
        let normalized = normalizedMinutes(minutes ?? defaultMinutes)
        let startOfDay = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .minute, value: normalized, to: startOfDay) ?? Date()
    }

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
                #if DEBUG
                divider
                Button {
                    onResetOnboarding()
                } label: {
                    settingsRow(
                        label: String(localized: "settings.debug.replay_onboarding", defaultValue: "オンボーディングをもう一度見る"),
                        value: ""
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
                                value: String(localized: "settings.status.free", defaultValue: "Free")
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if model.storeService.hasResolvedEntitlement && !model.storeService.isPro {
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
                                .font(.system(size: 16, weight: .semibold))
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
                            value: ""
                        )
                    }
                    .buttonStyle(.plain)

                    divider

                    Link(destination: AppURLs.terms) {
                        settingsRow(
                            label: String(localized: "settings.privacy.terms", defaultValue: "利用規約"),
                            value: ""
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
                    value: String(localized: "settings.screen_time.not_authorized", defaultValue: "未許可")
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var modePickerRow: some View {
        HStack(spacing: 12) {
            Text(String(localized: "settings.mode.label", defaultValue: "止める強さ"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignTokens.primaryText)

            Spacer()

            Picker(String(localized: "settings.mode.label", defaultValue: "止める強さ"), selection: modeBinding) {
                ForEach(InterventionMode.allCases, id: \.self) { mode in
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
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(DesignTokens.primaryText)

            Text(authorizationSheetBody)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignTokens.secondaryText)
                .lineSpacing(5)
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
        valueColor: Color = DesignTokens.secondaryText
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(labelColor)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 14)
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignTokens.hairline)
            .frame(height: 1)
    }

    private var primaryRule: TargetRule? {
        rules.first
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
        liveActivityEnabled = settingsStore.liveActivityEnabled
        selectedLockTheme = model.lockSurfaceState.theme

        model.screenTime.refresh()
        do {
            rules = try model.ruleStore.allRules()
            selectedMode = modeAllowedForCurrentEntitlement(primaryRule?.mode ?? pendingMode)
        } catch {
            rules = []
            selectedMode = modeAllowedForCurrentEntitlement(pendingMode)
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
            if let rule = primaryRule {
                if isSelectionEmpty {
                    settingsStore.pendingInterventionMode = modeAllowedForCurrentEntitlement(selectedMode).rawValue
                    try model.ruleStore.deleteRule(id: rule.id)
                } else {
                    let mode = modeAllowedForCurrentEntitlement(selectedMode)
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
                let mode = modeAllowedForCurrentEntitlement(pendingMode)
                settingsStore.pendingInterventionMode = mode.rawValue
                let data = try JSONEncoder().encode(activitySelection)
                try model.ruleStore.saveFamilyActivitySelection(
                    data,
                    name: "SNS",
                    mode: mode
                )
                selectedMode = mode
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
           !gate.canAddRule(currentCount: rules.count) {
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
                if rule.mode == .deepFocus, !model.entitlementGate.strictModeAllowed {
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
        guard modeAllowedForCurrentEntitlement(mode) == mode else {
            paywallPlacement = .settingsModeGate
            selectedMode = modeAllowedForCurrentEntitlement(primaryRule?.mode ?? pendingMode)
            return
        }

        selectedMode = mode

        guard let rule = primaryRule else {
            settingsStore.pendingInterventionMode = mode.rawValue
            return
        }

        do {
            try model.ruleStore.updateMode(id: rule.id, mode: mode)
            refreshSettingsState()
        } catch CoreError.validation(let message) {
            model.alertMessage = message
        } catch {
            model.alertMessage = String(localized: "settings.error.data_save", defaultValue: "データを保存できませんでした")
        }
    }

    private func modeAllowedForCurrentEntitlement(_ mode: InterventionMode) -> InterventionMode {
        if mode == .deepFocus, !model.entitlementGate.strictModeAllowed {
            return .standard
        }
        return mode
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

    private var pendingMode: InterventionMode {
        guard let rawValue = settingsStore.pendingInterventionMode,
              let mode = InterventionMode(rawValue: rawValue) else {
            return .standard
        }
        return mode
    }

    private var versionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, build) {
        case let (shortVersion?, build?):
            return "\(shortVersion) (\(build))"
        case let (shortVersion?, nil):
            return shortVersion
        default:
            return "1.0"
        }
    }
}
