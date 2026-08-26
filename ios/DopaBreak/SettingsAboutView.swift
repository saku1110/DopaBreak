import SwiftUI
import UIKit

struct SettingsAboutView: View {
    let model: AppModel
    let onResetOnboarding: () -> Void
    let onDataDeleted: () -> Void

    @Binding var isDeleteAllDataConfirmationPresented: Bool
    @Binding var isDeletionFeedbackVisible: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                privacySection
                appSection
            }
            .padding(.horizontal, DesignTokens.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .dopaScreenBackground()
        .navigationTitle(
            String(
                localized: "settings.entry.about",
                defaultValue: "プライバシーとアプリ情報"
            )
        )
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            String(
                localized: "settings.delete_all.confirmation.title",
                defaultValue: "全データを削除しますか？"
            ),
            isPresented: $isDeleteAllDataConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(
                String(
                    localized: "settings.delete_all.confirmation.delete",
                    defaultValue: "削除する"
                ),
                role: .destructive
            ) {
                deleteAllData()
            }
            Button(
                String(
                    localized: "settings.delete_all.confirmation.cancel",
                    defaultValue: "キャンセル"
                ),
                role: .cancel
            ) {}
        } message: {
            Text(
                String(
                    localized: "settings.delete_all.confirmation.message",
                    defaultValue: "目標・記録・設定がすべて削除されます。この操作は取り消せません。"
                )
            )
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SmallLabel(
                text: String(
                    localized: "settings.privacy.section",
                    defaultValue: "プライバシー"
                )
            )

            CardContainer {
                VStack(spacing: 0) {
                    Link(destination: AppURLs.privacy) {
                        SettingsRow(
                            label: String(
                                localized: "settings.privacy.policy",
                                defaultValue: "プライバシーポリシー"
                            ),
                            disclosure: .external
                        )
                    }
                    .buttonStyle(.plain)

                    SettingsDivider()

                    Link(destination: AppURLs.terms) {
                        SettingsRow(
                            label: String(
                                localized: "settings.privacy.terms",
                                defaultValue: "利用規約"
                            ),
                            disclosure: .external
                        )
                    }
                    .buttonStyle(.plain)

                    SettingsDivider()

                    Button {
                        isDeleteAllDataConfirmationPresented = true
                    } label: {
                        SettingsRow(
                            label: String(
                                localized: "settings.privacy.delete_all",
                                defaultValue: "全データを削除"
                            ),
                            value: isDeletionFeedbackVisible
                                ? String(
                                    localized: "settings.privacy.deleted",
                                    defaultValue: "削除しました"
                                )
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

    private var appSection: some View {
        CardContainer {
            VStack(spacing: 0) {
                SettingsRow(
                    label: String(
                        localized: "settings.app.version",
                        defaultValue: "バージョン"
                    ),
                    value: versionText
                )

                SettingsDivider()

                SettingsRow(
                    label: "DotGothic16 / Galmuri11",
                    value: "SIL OFL 1.1"
                )

                SettingsDivider()

                SettingsRow(
                    label: "Zen Kurenaido / Nanum Pen Script",
                    value: "SIL OFL 1.1"
                )

                SettingsDivider()

                Button {
                    openFeedbackEmail()
                } label: {
                    SettingsRow(
                        label: String(
                            localized: "settings.feedback.title",
                            defaultValue: "フィードバックを送る"
                        ),
                        disclosure: .external
                    )
                }
                .buttonStyle(.plain)

                #if DEBUG
                SettingsDivider()

                Button {
                    onResetOnboarding()
                } label: {
                    SettingsRow(
                        label: String(
                            localized: "settings.debug.replay_onboarding",
                            defaultValue: "最初の説明をもう一度見る"
                        ),
                        disclosure: .navigate
                    )
                }
                .buttonStyle(.plain)

                SettingsDivider()

                Button {
                    copyFunnelEvents()
                } label: {
                    SettingsRow(
                        label: String(
                            localized: "settings.debug.copy_event_log",
                            defaultValue: "操作記録をコピー"
                        )
                    )
                }
                .buttonStyle(.plain)
                #endif
            }
        }
    }

    private func deleteAllData() {
        guard model.deleteAllLocalData() else { return }

        onDataDeleted()
        isDeletionFeedbackVisible = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            isDeletionFeedbackVisible = false
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
