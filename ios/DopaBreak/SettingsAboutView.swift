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
                if let identifier = AppleAdsMeasurement.shared.supportIdentifier {
                    analyticsPrivacySection(identifier: identifier)
                }
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

    private func analyticsPrivacySection(identifier: String) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "settings.analytics.deletion_info", defaultValue: "端末内のデータを削除しても、購入・広告の分析データは削除されません。削除をご希望の場合は、下のIDをコピーしてサポートへお知らせください。"))
                    .dopaFont(14)
                    .foregroundStyle(DesignTokens.secondaryText)
                Text(identifier)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                Button {
                    UIPasteboard.general.string = identifier
                } label: {
                    SettingsRow(label: String(localized: "settings.analytics.copy_id", defaultValue: "分析データのIDをコピー"))
                }
                .buttonStyle(.plain)
                Link(destination: AppURLs.support) {
                    SettingsRow(label: String(localized: "settings.analytics.support", defaultValue: "データ削除について問い合わせる"), disclosure: .external)
                }
                .buttonStyle(.plain)
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

struct SettingsMechanismView: View {
    @Environment(\.locale) private var locale
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                centeredEyebrow(String(localized: "onboarding.science.eyebrow", defaultValue: "WHY IT WORKS / 科学的背景"))
                centeredTitle(String(localized: "onboarding.science.title", defaultValue: "意志だけでは 止めにくい理由"))
                centeredLead(String(localized: "onboarding.science.lead", defaultValue: "つい開いてしまうのは、あなたが弱いからではありません。SNSは、考える前に開きたくなる仕組みでできています。"))

                centeredLead(
                    String(localized: "onboarding.science.dopamine", defaultValue: "SNSでは次に何が出るかわからない仕組みが、つい続きを見たくなる気持ちを生みます。スロットマシンと同じ「変動報酬」です。意志だけで開かないようにするのは簡単ではありません。")
                )

                CardContainer {
                    VStack(alignment: .leading, spacing: 14) {
                        principleLine(
                            String(localized: "onboarding.science.principle1.title", defaultValue: "1. 一呼吸"),
                            String(localized: "onboarding.science.principle1.detail", defaultValue: "開く前に数秒立ち止まる")
                        )
                        principleLine(
                            String(localized: "onboarding.science.principle2.title", defaultValue: "2. 目的を確認"),
                            String(localized: "onboarding.science.principle2.detail", defaultValue: "開く理由を選ぶ")
                        )
                        principleLine(
                            String(localized: "onboarding.science.principle3.title", defaultValue: "3. 回数を確認"),
                            String(localized: "onboarding.science.principle3.detail", defaultValue: "今日何回目かを見る")
                        )
                        principleLine(
                            String(localized: "onboarding.science.principle4.title", defaultValue: "4. 振り返り"),
                            String(localized: "onboarding.science.principle4.detail", defaultValue: "見たあとの気持ちを記録する")
                        )
                    }
                }

                centeredLead(
                    String(localized: "onboarding.science.mechanism", defaultValue: "DopaBreakはSNSが開く直前に一呼吸をはさみ、無意識の行動を自分で選び直すきっかけをつくります。")
                )

                centeredLead(
                    String(localized: "onboarding.science.research", defaultValue: "one secを使った査読付き研究（PNAS, 2023）では、6週間継続した参加者が対象アプリを実際に開いた回数が平均57%減少しました。")
                )

                VStack(alignment: .leading, spacing: 8) {
                    bodyText(String(localized: "onboarding.science.disclaimer.study", defaultValue: "※他社アプリ(one sec)を対象とした研究です。"))
                    bodyText(String(localized: "onboarding.science.disclaimer.effect", defaultValue: "※本アプリの効果を保証するものではありません。"))
                    bodyText(String(localized: "onboarding.science.disclaimer.medical", defaultValue: "※医療・治療を目的としたアプリではありません。"))
                }
            }
            .padding(20)
        }
        .dopaScreenBackground()
        .navigationTitle(String(localized: "settings.entry.mechanism", defaultValue: "仕組み"))
        .navigationBarTitleDisplayMode(.inline)
    }

    func titleText(_ text: String) -> some View {
        Text(text)
            .typesettingLanguage(locale.language)
            .dopaFont(34, weight: .black, lineSpacing: 5)
            .foregroundStyle(DesignTokens.primaryText)
            .minimumScaleFactor(0.74)
    }

    func bodyText(_ text: String) -> some View {
        Text(text)
            .typesettingLanguage(locale.language)
            .dopaFont(16, weight: .semibold, lineSpacing: 5)
            .foregroundStyle(DesignTokens.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    // 訴求文言（アイブロウ・見出し・リード）は中央寄せ。フォーム・選択肢・カード内は左寄せのまま
    func centeredEyebrow(_ text: String) -> some View {
        SmallLabel(text: text)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    func centeredTitle(_ text: String) -> some View {
        titleText(text)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    func centeredLead(_ text: String) -> some View {
        bodyText(text)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    func principleLine(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .dopaFont(17, weight: .black)
                .foregroundStyle(DesignTokens.primaryText)
            Text(detail)
                .dopaFont(15, weight: .semibold)
                .foregroundStyle(DesignTokens.secondaryText)
        }
    }
}
