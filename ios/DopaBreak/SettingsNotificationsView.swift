import DopaBreakCore
import FamilyControls
import SwiftUI

struct SettingsNotificationsView: View {
    let model: AppModel
    let settingsStore: SettingsStore

    @Binding var morningNotificationEnabled: Bool
    @Binding var weeklyReportNotificationEnabled: Bool
    @Binding var retentionSupportNotificationsEnabled: Bool
    @Binding var planNotificationsEnabled: Bool
    @Binding var usageWatchSelection: FamilyActivitySelection
    @Binding var isUsageWatchPickerPresented: Bool
    @Binding var shouldEnableUsageWatchAfterPicker: Bool
    @Binding var usageWatchAuthorizationWasDenied: Bool
    @Binding var isRequestingUsageWatchAuthorization: Bool
    @Binding var paywallPlacement: PaywallPlacement?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                notificationSection
                usageWatchSection
            }
            .padding(.horizontal, DesignTokens.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .dopaScreenBackground()
        .navigationTitle(String(localized: "settings.entry.notifications", defaultValue: "通知"))
        .navigationBarTitleDisplayMode(.inline)
        .familyActivityPicker(
            isPresented: $isUsageWatchPickerPresented,
            selection: $usageWatchSelection
        )
        .onChange(of: isUsageWatchPickerPresented) { oldValue, newValue in
            guard oldValue, !newValue else { return }
            saveUsageWatchSelection()
        }
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SmallLabel(
                text: String(localized: "settings.entry.notifications", defaultValue: "通知")
            )

            CardContainer {
                VStack(spacing: 0) {
                    SettingsIconToggleRow(
                        systemName: "sun.max.fill",
                        label: String(
                            localized: "settings.lock_screen.morning_notification",
                            defaultValue: "朝の目標通知"
                        ),
                        isOn: morningNotificationBinding
                    )

                    SettingsDivider()

                    SettingsIconTimePickerRow(
                        systemName: "clock.fill",
                        label: String(
                            localized: "settings.lock_screen.notification_time",
                            defaultValue: "通知時刻"
                        ),
                        selection: morningNotificationTimeBinding
                    )
                    .disabled(!morningNotificationEnabled)
                    .opacity(morningNotificationEnabled ? 1 : 0.45)

                    SettingsDivider()

                    SettingsIconToggleRow(
                        systemName: "calendar",
                        label: String(
                            localized: "settings.lock_screen.weekly_report",
                            defaultValue: "毎週の記録通知"
                        ),
                        isOn: weeklyReportNotificationBinding
                    )

                    SettingsDivider()

                    SettingsIconToggleRow(
                        systemName: "checkmark.seal.fill",
                        label: String(
                            localized: "settings.notifications.retention_support.title",
                            defaultValue: "設定確認と記録の通知"
                        ),
                        isOn: retentionSupportNotificationsBinding
                    )

                    SettingsDivider()

                    SettingsIconToggleRow(
                        systemName: "star.fill",
                        label: String(
                            localized: "settings.notifications.plan.title",
                            defaultValue: "プランに関する通知"
                        ),
                        isOn: planNotificationsBinding
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
                    SettingsIconToggleRow(
                        systemName: "timer",
                        label: String(
                            localized: "settings.usage_watch.enable.title",
                            defaultValue: "利用時間の通知を使う"
                        ),
                        isOn: usageWatchEnabledBinding
                    )
                    .disabled(isRequestingUsageWatchAuthorization)

                    SettingsDivider()

                    Button {
                        beginUsageWatchSelection(enableAfterSelection: false)
                    } label: {
                        SettingsIconNavigationRow(
                            systemName: "square.grid.2x2.fill",
                            label: String(
                                localized: "settings.usage_watch.apps.title",
                                defaultValue: "時間をはかるアプリ"
                            ),
                            value: usageWatchSelectionSummary
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isRequestingUsageWatchAuthorization)

                    if model.storeService.isPro {
                        SettingsDivider()
                        usageWatchIntervalRow

                        SettingsDivider()
                        SettingsIconToggleRow(
                            systemName: "moon.fill",
                            label: String(
                                localized: "settings.usage_watch.night_mode.title",
                                defaultValue: "就寝前は問いかけの間隔を短く"
                            ),
                            isOn: usageWatchNightModeBinding
                        )
                    } else {
                        SettingsDivider()

                        HStack(alignment: .top, spacing: 12) {
                            SettingsIconTile(systemName: "info.circle.fill")
                            Text(
                                String(
                                    localized: "settings.usage_watch.free_rule.description",
                                    defaultValue: "選んだアプリを2時間続けて使うと1日1回通知します"
                                )
                            )
                            .dopaFont(14, weight: .medium, lineSpacing: 4)
                            .foregroundStyle(DesignTokens.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 10)

                        SettingsDivider()
                        usageWatchLockedRow(
                            systemName: "clock.arrow.circlepath",
                            label: String(
                                localized: "settings.usage_watch.interval.title",
                                defaultValue: "問いかけの間隔"
                            )
                        )

                        SettingsDivider()
                        usageWatchLockedRow(
                            systemName: "moon.fill",
                            label: String(
                                localized: "settings.usage_watch.night_mode.title",
                                defaultValue: "就寝前は問いかけの間隔を短く"
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

    private var usageWatchIntervalRow: some View {
        HStack(spacing: 12) {
            SettingsIconTile(systemName: "clock.arrow.circlepath")

            Text(
                String(
                    localized: "settings.usage_watch.interval.title",
                    defaultValue: "問いかけの間隔"
                )
            )
            .dopaFont(16, weight: .semibold)
            .foregroundStyle(DesignTokens.primaryText)

            Spacer(minLength: 8)

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
        .frame(minHeight: DesignTokens.minTapTarget)
        .padding(.vertical, 8)
    }

    private func usageWatchLockedRow(systemName: String, label: String) -> some View {
        Button {
            paywallPlacement = .settingsUsageWatchGate
        } label: {
            HStack(spacing: 12) {
                SettingsIconTile(systemName: systemName)

                Text(label)
                    .dopaFont(16, weight: .semibold)
                    .foregroundStyle(DesignTokens.primaryText)

                Spacer(minLength: 8)

                Label(
                    String(localized: "settings.status.pro", defaultValue: "Pro"),
                    systemImage: "lock.fill"
                )
                .dopaFont(13, weight: .bold)
                .foregroundStyle(DesignTokens.secondaryText)

                SettingsChevron()
            }
            .frame(minHeight: DesignTokens.minTapTarget)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            get: {
                SettingsTime.date(
                    minutes: settingsStore.morningNotificationMinutes,
                    defaultMinutes: 420
                )
            },
            set: { date in
                settingsStore.morningNotificationMinutes = SettingsTime.minutes(from: date)
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
        guard !isRequestingUsageWatchAuthorization else { return }

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
}
