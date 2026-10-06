import DopaBreakCore
import SwiftUI

struct SettingsNotificationsView: View {
    let model: AppModel
    let settingsStore: SettingsStore

    @Binding var weeklyReportNotificationMinutes: Int
    @Binding var weeklyReportNotificationEnabled: Bool
    @Binding var reflectionNotificationEnabled: Bool
    @Binding var retentionSupportNotificationsEnabled: Bool
    @Binding var planNotificationsEnabled: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                SmallLabel(
                    text: String(localized: "settings.entry.notifications", defaultValue: "通知")
                )

                CardContainer {
                    VStack(spacing: 0) {
                        SettingsIconToggleRow(
                            systemName: "calendar",
                            label: String(
                                localized: "settings.lock_screen.weekly_report",
                                defaultValue: "毎週の記録通知"
                            ),
                            isOn: weeklyReportNotificationBinding
                        )

                        SettingsDivider()

                        SettingsIconTimePickerRow(
                            systemName: "clock.fill",
                            label: String(
                                localized: "settings.lock_screen.notification_time",
                                defaultValue: "記録通知の時刻"
                            ),
                            selection: weeklyReportNotificationTimeBinding
                        )
                        .disabled(!weeklyReportNotificationEnabled)
                        .opacity(weeklyReportNotificationEnabled ? 1 : 0.45)

                        SettingsDivider()

                        SettingsIconToggleRow(
                            systemName: "text.bubble.fill",
                            label: String(
                                localized: "settings.notifications.reflection.title",
                                defaultValue: "振り返りの通知"
                            ),
                            isOn: reflectionNotificationBinding
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
            .padding(.horizontal, DesignTokens.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .dopaScreenBackground()
        .navigationTitle(String(localized: "settings.entry.notifications", defaultValue: "通知"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var weeklyReportNotificationTimeBinding: Binding<Date> {
        Binding(
            get: {
                SettingsTime.date(
                    minutes: weeklyReportNotificationMinutes,
                    defaultMinutes: 420
                )
            },
            set: { date in
                let minutes = SettingsTime.minutes(from: date)
                weeklyReportNotificationMinutes = minutes
                settingsStore.weeklyReportNotificationMinutes = minutes
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

    private var reflectionNotificationBinding: Binding<Bool> {
        Binding(
            get: { reflectionNotificationEnabled },
            set: { value in
                reflectionNotificationEnabled = value
                settingsStore.reflectionNotificationEnabled = value
                model.syncReinterventionNotificationPreference()
                if !value {
                    for app in SNSAppCatalog.all { model.reflectionNotificationScheduler.cancelWorkCheckIn(catalogID: app.catalogID) }
                    model.cancelReflectionNotification()
                }
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
}
