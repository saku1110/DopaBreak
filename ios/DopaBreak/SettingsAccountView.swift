import SwiftUI

struct SettingsAccountView: View {
    let model: AppModel
    @Binding var paywallPlacement: PaywallPlacement?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                SmallLabel(
                    text: String(
                        localized: "settings.account.section",
                        defaultValue: "プランと購入"
                    )
                )

                CardContainer {
                    VStack(spacing: 0) {
                        if model.storeService.isPro {
                            SettingsRow(
                                label: String(
                                    localized: "settings.account.pro_status",
                                    defaultValue: "現在のプラン"
                                ),
                                value: String(
                                    localized: "settings.status.pro",
                                    defaultValue: "Pro"
                                )
                            )
                        } else {
                            Button {
                                paywallPlacement = .settingsProStatusRow
                            } label: {
                                SettingsRow(
                                    label: String(
                                        localized: "settings.account.pro_status",
                                        defaultValue: "現在のプラン"
                                    ),
                                    value: String(
                                        localized: "settings.status.free",
                                        defaultValue: "Free"
                                    ),
                                    disclosure: .navigate
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        SettingsDivider()

                        Button {
                            Task {
                                await model.restorePurchases()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text(
                                    String(
                                        localized: "settings.account.restore",
                                        defaultValue: "購入を復元"
                                    )
                                )
                                .dopaFont(16, weight: .semibold)
                                .foregroundStyle(DesignTokens.primaryText)

                                Spacer()

                                if model.storeService.isRestoring {
                                    ProgressView()
                                        .tint(DesignTokens.secondaryText)
                                }
                            }
                            .frame(minHeight: DesignTokens.minTapTarget)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isBillingBusy)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .dopaScreenBackground()
        .navigationTitle(
            String(localized: "settings.entry.pro", defaultValue: "DopaBreak Pro")
        )
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isBillingBusy: Bool {
        model.storeService.isLoadingProducts
            || model.storeService.isPurchasing
            || model.storeService.isRestoring
    }

}
