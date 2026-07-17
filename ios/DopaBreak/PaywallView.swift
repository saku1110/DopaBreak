import DopaBreakCore
import Foundation
import StoreKit
import SwiftUI

enum PaywallPlacement: String, CaseIterable, Identifiable {
    case goalsLimit = "goals_limit"
    case settingsTargetAppLimit = "settings_target_app_limit"
    case settingsFamilyActivityLimit = "settings_family_activity_limit"
    case settingsProStatusRow = "settings_pro_status_row"
    case settingsThemeGate = "settings_theme_gate"
    case settingsModeGate = "settings_mode_gate"
    case onboardingPrepaywallSummary = "onboarding_prepaywall_summary"
    case onboardingModeGate = "onboarding_mode_gate"
    case onboardingTargetAppGate = "onboarding_target_app_gate"

    var id: String { rawValue }
}

private enum PaywallPlan: CaseIterable, Identifiable {
    case annual
    case monthly

    var id: String {
        switch self {
        case .annual:
            return ProProductID.annual.rawValue
        case .monthly:
            return ProProductID.monthly.rawValue
        }
    }
}

struct PaywallView: View {
    let storeService: StoreService
    let placement: PaywallPlacement

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: PaywallPlan = .annual
    @State private var alertMessage: String?
    @State private var didRecordAppearance = false
    @State private var didRecordDismissal = false

    private var isBusy: Bool {
        storeService.isPurchasing || storeService.isRestoring
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                featureList
                planList
                legalArea
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 18)
        }
        .dopaScreenBackground()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            fixedActionBar
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard !didRecordAppearance else { return }
            didRecordAppearance = true
            storeService.recordPaywallShown(placement: placement.rawValue)
        }
        .task {
            await storeService.loadProducts()
        }
        .alert("エラー", isPresented: alertPresented) {
            Button("閉じる") {
                alertMessage = nil
            }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            MorningHorizon(height: 112, alignment: .center, bottomFade: 0.72)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DesignTokens.hairline, lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    SmallLabel(text: "DOPABREAK PRO")
                        .padding(14)
                }

            (Text("その ").foregroundStyle(DesignTokens.primaryText)
                + Text("38").foregroundStyle(DesignTokens.accent)
                + Text(" 日を、人生に使う").foregroundStyle(DesignTokens.primaryText))
                .font(.system(size: 30, weight: .black))
                .tracking(-1)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text("無意識に消える時間を、あなたが選んだ目標へ戻します。")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)
                .lineSpacing(4)
        }
    }

    private var featureList: some View {
        VStack(spacing: 0) {
            PaywallFeatureRow(text: "止めるアプリを何個でも追加できる")
            divider
            PaywallFeatureRow(text: "ロック画面テーマを着せ替え")
            divider
            PaywallFeatureRow(text: "詳細な統計と継続記録")
            divider
            PaywallFeatureRow(text: "複数の目標とモード")
        }
        .padding(.horizontal, 4)
    }

    private var planList: some View {
        VStack(spacing: 10) {
            planCard(.annual)
            planCard(.monthly)
        }
        .disabled(isBusy)
    }

    private var fixedActionBar: some View {
        VStack(spacing: 4) {
            Button {
                Task {
                    await purchaseSelectedPlan()
                }
            } label: {
                if storeService.isPurchasing {
                    ProgressView()
                        .tint(DesignTokens.background)
                } else {
                    Text(primaryButtonTitle)
                }
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: !isBusy))
            .disabled(isBusy)

            HStack(spacing: 8) {
                Button {
                    Task {
                        await restorePurchases()
                    }
                } label: {
                    HStack(spacing: 7) {
                        if storeService.isRestoring {
                            ProgressView()
                                .tint(DesignTokens.secondaryText)
                        }
                        Text("購入を復元")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .disabled(isBusy)

                Button("あとで") {
                    dismissWithoutPurchase()
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(isBusy)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(DesignTokens.secondaryText)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background {
            LinearGradient(
                colors: [DesignTokens.background.opacity(0.92), DesignTokens.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(DesignTokens.hairline)
                    .frame(height: 1)
            }
        }
    }

    private var legalArea: some View {
        VStack(spacing: 8) {
            Text(legalText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: .infinity)

            HStack(spacing: 18) {
                Link("利用規約", destination: AppURLs.terms)
                Link("プライバシー", destination: AppURLs.privacy)
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(DesignTokens.secondaryText)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(DesignTokens.hairline)
            .frame(height: 1)
    }

    private func planCard(_ plan: PaywallPlan) -> some View {
        Button {
            selectedPlan = plan
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(planTitle(plan))
                                .font(.system(size: 17, weight: .black))
                                .foregroundStyle(DesignTokens.primaryText)
                            if plan == .annual {
                                Text("一番人気・\(annualDiscountPercent)%お得")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundStyle(DesignTokens.background)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(DesignTokens.accent)
                                    .clipShape(Capsule())
                            }
                        }

                        if let detail = planDetail(plan) {
                            Text(detail)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DesignTokens.secondaryText)
                        }
                    }

                    Spacer()

                    Text(planPrice(plan))
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(DesignTokens.primaryText)
                        .multilineTextAlignment(.trailing)
                }

            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(planBackground(plan))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selectedPlan == plan ? DesignTokens.accent : DesignTokens.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedPlan == plan ? .isSelected : [])
    }

    private func planBackground(_ plan: PaywallPlan) -> some ShapeStyle {
        selectedPlan == plan ? AnyShapeStyle(DesignTokens.accent.opacity(0.08)) : AnyShapeStyle(DesignTokens.card)
    }

    private func planTitle(_ plan: PaywallPlan) -> String {
        switch plan {
        case .annual:
            return "年額"
        case .monthly:
            return "月額"
        }
    }

    private func planDetail(_ plan: PaywallPlan) -> String? {
        switch plan {
        case .annual:
            let introText = storeService.isEligibleForAnnualIntroOffer
                ? (storeService.annualIntroOfferText ?? "7日間無料")
                : nil
            return [annualMonthlyEquivalentText, introText]
                .compactMap { $0 }
                .joined(separator: "・")
        case .monthly:
            return nil
        }
    }

    private func planPrice(_ plan: PaywallPlan) -> String {
        switch plan {
        case .annual:
            return "\(product(for: plan)?.displayPrice ?? "4,980円")/年"
        case .monthly:
            return "\(product(for: plan)?.displayPrice ?? "980円")/月"
        }
    }

    private var primaryButtonTitle: String {
        if selectedPlan == .annual, storeService.isEligibleForAnnualIntroOffer {
            return "7日間無料で始める"
        }
        return "\(planTitle(selectedPlan))プランを始める"
    }

    private var legalText: String {
        switch selectedPlan {
        case .annual:
            if storeService.isEligibleForAnnualIntroOffer {
                return "7日間の無料期間終了後、年額\(annualDisplayPrice)で自動更新。いつでも解約できます。"
            }
            return "年額\(annualDisplayPrice)で自動更新。いつでも解約できます。"
        case .monthly:
            return "月額\(monthlyDisplayPrice)で自動更新。いつでも解約できます。"
        }
    }

    private func product(for plan: PaywallPlan) -> Product? {
        switch plan {
        case .annual:
            return storeService.activeAnnualProduct
        case .monthly:
            return storeService.monthlyProduct
        }
    }

    private var annualDisplayPrice: String {
        storeService.activeAnnualProduct?.displayPrice ?? "4,980円"
    }

    private var monthlyDisplayPrice: String {
        storeService.monthlyProduct?.displayPrice ?? "980円"
    }

    private var annualMonthlyEquivalentText: String {
        let annualPrice = storeService.activeAnnualProduct.map {
            NSDecimalNumber(decimal: $0.price).doubleValue
        } ?? 4_980
        let monthlyEquivalent = Int((annualPrice / 12).rounded())
        return "月あたり\(monthlyEquivalent.formatted(.number))円"
    }

    private var annualDiscountPercent: Int {
        guard let annual = storeService.activeAnnualProduct,
              let monthly = storeService.monthlyProduct else {
            return 58
        }
        let annualPrice = NSDecimalNumber(decimal: annual.price).doubleValue
        let monthlyPrice = NSDecimalNumber(decimal: monthly.price).doubleValue
        guard monthlyPrice > 0 else { return 58 }
        return max(0, Int(((1 - annualPrice / (monthlyPrice * 12)) * 100).rounded()))
    }

    private func purchaseSelectedPlan() async {
        guard let product = product(for: selectedPlan) else {
            alertMessage = "商品情報を読み込めませんでした"
            return
        }

        let didBecomePro = await storeService.purchase(product)
        if didBecomePro {
            dismiss()
        } else if let message = storeService.alertMessage {
            alertMessage = message
        }
    }

    private func restorePurchases() async {
        let didBecomePro = await storeService.restore()
        if didBecomePro {
            dismiss()
        } else if let message = storeService.alertMessage {
            alertMessage = message
        }
    }

    private func dismissWithoutPurchase() {
        guard !didRecordDismissal else { return }
        didRecordDismissal = true
        storeService.recordPaywallDismissedIfNeeded(placement: placement.rawValue)
        dismiss()
    }

    private var alertPresented: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    alertMessage = nil
                }
            }
        )
    }
}

private struct PaywallFeatureRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(DesignTokens.accent)
                .frame(width: 20, height: 20)

            Text(text)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DesignTokens.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
    }
}
