import DopaBreakCore
import Foundation
import StoreKit
import SwiftUI

// 目標の件数制限は撤廃済み（2026-08-17オーナー決定）のため、goals_limit の掲出箇所はない。
enum PaywallPlacement: String, CaseIterable, Identifiable {
    case settingsTargetAppLimit = "settings_target_app_limit"
    case settingsFamilyActivityLimit = "settings_family_activity_limit"
    case settingsProStatusRow = "settings_pro_status_row"
    case settingsThemeGate = "settings_theme_gate"
    case settingsModeGate = "settings_mode_gate"
    case settingsGateGate = "settings_gate_gate"
    case settingsUsageWatchGate = "settings_usage_watch_gate"
    case onboardingPrepaywallSummary = "onboarding_prepaywall_summary"
    case onboardingModeGate = "onboarding_mode_gate"
    case onboardingTargetAppGate = "onboarding_target_app_gate"
    case statsHistoryGate = "stats_history_gate"
    case weekly = "weekly"

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
    let yearlyDays: Int
    let settingsStore: SettingsStore

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: PaywallPlan = .annual
    /// 終了前通知の何日前かを画面側で保持する。`SettingsStore` は監視対象ではないため、
    /// 表示はここを正本にし、変更のたびに保存へ書き戻す。
    @State private var trialReminderLeadDays: Int
    @State private var alertMessage: String?
    @State private var didRecordAppearance = false
    @State private var didRecordDismissal = false

    init(
        storeService: StoreService,
        placement: PaywallPlacement,
        snapshotStore: JSONSnapshotStore = JSONSnapshotStore(
            containerProvider: DefaultContainerProvider()
        ),
        settingsStore: SettingsStore? = nil
    ) {
        self.storeService = storeService
        self.placement = placement
        let resolvedSettingsStore = settingsStore ?? ((try? SettingsStore()) ?? SettingsStore(userDefaults: .standard))
        self.settingsStore = resolvedSettingsStore
        _trialReminderLeadDays = State(initialValue: resolvedSettingsStore.trialReminderLeadDays)
        let snapshot = try? snapshotStore.read(
            SelfCheckSnapshot.self,
            from: .selfCheckSnapshot
        )
        yearlyDays = Self.resolvedYearlyDays(snapshot: snapshot)
    }

    static func resolvedYearlyDays(snapshot: SelfCheckSnapshot?) -> Int {
        snapshot?.estimatedYearlyDays ??
            (try? LossEstimator.estimate(usageBucket: "2-4時間").yearlyDays) ??
            38
    }

    private var isBusy: Bool {
        storeService.isLoadingProducts || storeService.isPurchasing || storeService.isRestoring
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                featureList
                planList
                trialReminderCard
                legalArea
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
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
            let shownAt = Date()
            settingsStore.lastAnyPaywallShownAt = shownAt
            if placement == .weekly {
                settingsStore.lastWeeklyPaywallShownAt = shownAt
            }
            storeService.recordPaywallShown(placement: placement.rawValue)
        }
        .onDisappear {
            recordDismissalWithoutPurchaseIfNeeded()
        }
        // Proである事実だけを見て閉じる。purchase() の戻り値に頼ると、
        // 保留購入の承認・Transaction.updates 経由の解放・別端末での購入など
        // 「戻り値を受け取れない解放」でペイウォールが開いたまま残る。
        // initial: true は、開いた時点ですでにProだった場合（購入の解放が
        // 表示より先に届いた・キャッシュからPro復元された等）を拾うため。
        // ペイウォールを開く導線はいずれも非Proのときだけなので、誤爆しない。
        .onChange(of: storeService.isPro, initial: true) { _, isPro in
            guard isPro else { return }
            dismiss()
        }
        .task {
            await storeService.loadProducts()
        }
        .alert(String(localized: "paywall.alert.error.title", defaultValue: "エラー"), isPresented: alertPresented) {
            Button(String(localized: "paywall.action.close", defaultValue: "閉じる")) {
                alertMessage = nil
            }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            CharacterView(.awake, size: DesignTokens.CharacterSize.header)
                .frame(maxWidth: .infinity)
                .frame(height: DesignTokens.CharacterSize.header)
                .background(DesignTokens.backgroundRaised)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DesignTokens.hairline, lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    SmallLabel(text: String(localized: "paywall.brand.pro", defaultValue: "DOPABREAK PRO"))
                        .padding(14)
                }
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 2) {
                (Text(String(localized: "paywall.header.line1.prefix", defaultValue: "「あと5分だけ」が年")).foregroundStyle(DesignTokens.primaryText)
                    + Text("\(yearlyDays)").foregroundStyle(DesignTokens.accent)
                    + Text(String(localized: "paywall.header.line1.suffix", defaultValue: "日")).foregroundStyle(DesignTokens.primaryText))
                    .dopaFont(30, weight: .black, tracking: -1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(String(localized: "paywall.header.line2", defaultValue: "開く前にブレーキ"))
                    .dopaFont(30, weight: .black, tracking: -1)
                    .foregroundStyle(DesignTokens.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Text(String(localized: "paywall.header.body", defaultValue: "がんばって我慢するアプリではありません。開く前に毎回ひと呼吸が入るだけ。開くのをやめた回数が毎日ホームに積み上がります。"))
                .dopaFont(14, weight: .medium, lineSpacing: 4)
                .foregroundStyle(DesignTokens.secondaryText)
        }
    }

    private var featureList: some View {
        VStack(spacing: 0) {
            PaywallFeatureRow(text: String(localized: "paywall.feature.unlimited_apps", defaultValue: "止めるアプリを何個でも追加"))
            divider
            PaywallFeatureRow(text: String(localized: "paywall.feature.deep_focus", defaultValue: "選んだアプリを完全にブロック"))
            divider
            PaywallFeatureRow(text: String(localized: "paywall.feature.night_block", defaultValue: "就寝中は自動で完全ブロック"))
            divider
            PaywallFeatureRow(text: String(localized: "paywall.feature.usage_watch", defaultValue: "使いすぎたら15分ごとに声かけ"))
            divider
            PaywallFeatureRow(text: String(localized: "paywall.feature.full_history", defaultValue: "記録と週次レポートを全期間"))
            divider
            PaywallFeatureRow(text: String(localized: "paywall.feature.lock_theme", defaultValue: "ロック画面テーマを着せ替え"))
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

    /// 無料期間つきの年額を選んでいるときだけ出す、終了前の知らせの事前選択。
    /// 請求されるタイミングを自分で握れる実感が、無料期間への警戒をほどく。
    /// CTAより手前に置くが、支配的にならないよう寸法と彩度は抑える。
    @ViewBuilder
    private var trialReminderCard: some View {
        if selectedPlan == .annual, storeService.isEligibleForAnnualIntroOffer {
            CardContainer {
                VStack(alignment: .leading, spacing: 10) {
                    SmallLabel(text: String(localized: "paywall.trial_reminder.label", defaultValue: "更新前のお知らせ"))

                    Text(String(localized: "paywall.trial_reminder.body", defaultValue: "無料期間が終わる前に通知でお知らせします"))
                        .dopaFont(14, weight: .bold)
                        .foregroundStyle(DesignTokens.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Picker(
                        String(localized: "paywall.trial_reminder.label", defaultValue: "更新前のお知らせ"),
                        selection: $trialReminderLeadDays
                    ) {
                        Text(String(localized: "paywall.trial_reminder.option.two_days", defaultValue: "2日前"))
                            .tag(2)
                        Text(String(localized: "paywall.trial_reminder.option.three_days", defaultValue: "3日前"))
                            .tag(3)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .disabled(isBusy)

                    Text(String(localized: "paywall.trial_reminder.note", defaultValue: "無料期間中に解約すれば請求はありません"))
                        .dopaFont(12, weight: .medium, lineSpacing: 2)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .onChange(of: trialReminderLeadDays) { _, newValue in
                settingsStore.trialReminderLeadDays = newValue
            }
        }
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
                        Text(String(localized: "paywall.action.restore", defaultValue: "購入を復元"))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .disabled(isBusy)

                Button(String(localized: "paywall.action.later", defaultValue: "あとで")) {
                    dismissWithoutPurchase()
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(isBusy)
            }
            .dopaFont(14, weight: .semibold)
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
                .dopaFont(10, weight: .medium, lineSpacing: 2)
                .foregroundStyle(DesignTokens.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            HStack(spacing: 18) {
                Link(String(localized: "paywall.legal.terms", defaultValue: "利用規約"), destination: AppURLs.terms)
                Link(String(localized: "paywall.legal.privacy", defaultValue: "プライバシー"), destination: AppURLs.privacy)
            }
            .dopaFont(11, weight: .bold)
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
                HStack(spacing: 8) {
                    Text(planTitle(plan))
                        .dopaFont(17, weight: .black)
                        .foregroundStyle(DesignTokens.primaryText)
                    if plan == .annual {
                        Text(String(localized: "paywall.plan.annual.savings_badge", defaultValue: "一番人気・\(annualDiscountPercent)%お得"))
                            .dopaFont(11, weight: .black)
                            .foregroundStyle(DesignTokens.background)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DesignTokens.accent)
                            .clipShape(Capsule())
                    }
                }

                Text(planPrice(plan))
                    .dopaFont(24, weight: .black, design: .rounded)
                    .foregroundStyle(DesignTokens.primaryText)

                if let detail = planDetail(plan) {
                    Text(detail)
                        .dopaFont(12, weight: .semibold)
                        .foregroundStyle(DesignTokens.secondaryText)
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
            return String(localized: "paywall.plan.annual.title", defaultValue: "年額")
        case .monthly:
            return String(localized: "paywall.plan.monthly.title", defaultValue: "月額")
        }
    }

    private func planDetail(_ plan: PaywallPlan) -> String? {
        switch plan {
        case .annual:
            let annualChargeText = storeService.activeAnnualProduct.map {
                String(localized: "paywall.plan.annual.charge", defaultValue: "年間\($0.displayPrice)を一括請求")
            }
            let introText = storeService.isEligibleForAnnualIntroOffer
                ? (storeService.annualIntroOfferText ?? String(localized: "paywall.plan.annual.intro_fallback", defaultValue: "7日間無料"))
                : nil
            let details = [annualChargeText, introText].compactMap { $0 }
            return details.isEmpty ? nil : details.joined(separator: "・")
        case .monthly:
            return nil
        }
    }

    private func planPrice(_ plan: PaywallPlan) -> String {
        switch plan {
        case .annual:
            return annualMonthlyEquivalentText
        case .monthly:
            guard let product = storeService.monthlyProduct else {
                return String(localized: "paywall.value.unavailable", defaultValue: "—")
            }
            return String(localized: "paywall.plan.monthly.price", defaultValue: "\(product.displayPrice)/月")
        }
    }

    private var primaryButtonTitle: String {
        if selectedPlan == .annual, storeService.isEligibleForAnnualIntroOffer {
            return String(localized: "paywall.action.start_free", defaultValue: "\(annualIntroOfferDurationText)無料で始める")
        }
        return String(localized: "paywall.action.start_plan", defaultValue: "\(planTitle(selectedPlan))プランを始める")
    }

    private var legalText: String {
        switch selectedPlan {
        case .annual:
            guard let product = storeService.activeAnnualProduct else {
                return String(localized: "paywall.legal.auto_renew", defaultValue: "解約しない場合、期間終了時に自動更新されます\n購入はApple IDに請求されます")
            }
            if storeService.isEligibleForAnnualIntroOffer {
                return String(localized: "paywall.legal.annual_intro", defaultValue: "\(annualIntroOfferDurationText)の無料期間終了後、年額\(product.displayPrice)で自動更新。いつでも解約できます。購入はApple IDに請求されます")
            }
            return String(localized: "paywall.legal.auto_renew", defaultValue: "解約しない場合、期間終了時に自動更新されます\n購入はApple IDに請求されます")
        case .monthly:
            return String(localized: "paywall.legal.auto_renew", defaultValue: "解約しない場合、期間終了時に自動更新されます\n購入はApple IDに請求されます")
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

    private var annualIntroOfferDurationText: String {
        storeService.annualIntroOfferDurationText ?? String(localized: "paywall.plan.annual.intro_duration_fallback", defaultValue: "7日間")
    }

    private var annualMonthlyEquivalentText: String {
        guard let product = storeService.activeAnnualProduct else {
            return String(localized: "paywall.value.unavailable", defaultValue: "—")
        }
        return String(localized: "paywall.plan.annual.monthly_equivalent", defaultValue: "\(product.priceFormatStyle.format(product.price / Decimal(12)))/月")
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
            alertMessage = String(localized: "paywall.error.product_load", defaultValue: "商品情報を読み込めませんでした")
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
        recordDismissalWithoutPurchaseIfNeeded()
        dismiss()
    }

    private func recordDismissalWithoutPurchaseIfNeeded() {
        guard !didRecordDismissal,
              storeService.recordPaywallDismissedIfNeeded(placement: placement.rawValue) else {
            return
        }
        didRecordDismissal = true
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
                .dopaFont(14, weight: .black)
                .foregroundStyle(DesignTokens.accent)
                .frame(width: 20, height: 20)

            Text(text)
                .dopaFont(15, weight: .bold)
                .foregroundStyle(DesignTokens.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
    }
}
