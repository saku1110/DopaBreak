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

                        // 権利取得に失敗しただけの課金者へ購入行を見せない。
                        if model.storeService.hasConfirmedEntitlement && !model.storeService.isPro {
                            SettingsDivider()

                            Button {
                                Task {
                                    await purchaseLifetimePlan()
                                }
                            } label: {
                                ZStack(alignment: .trailing) {
                                    SettingsRow(
                                        label: String(
                                            localized: "settings.account.lifetime_plan",
                                            defaultValue: "買い切りプラン"
                                        ),
                                        value: model.storeService.lifetimeProduct?.displayPrice
                                            ?? String(
                                                localized: "settings.value.unavailable",
                                                defaultValue: "—"
                                            )
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

    @MainActor
    private func purchaseLifetimePlan() async {
        if model.storeService.lifetimeProduct == nil {
            await model.storeService.loadProducts()
        }

        guard let lifetimeProduct = model.storeService.lifetimeProduct else {
            model.alertMessage = String(
                localized: "settings.error.product_load",
                defaultValue: "商品情報を読み込めませんでした"
            )
            return
        }

        guard !model.storeService.isPro else { return }
        let didBecomePro = await model.storeService.purchase(lifetimeProduct)
        if !didBecomePro, let message = model.storeService.alertMessage {
            model.alertMessage = message
        }
    }
}
