import DopaBreakCore
import Foundation
import StoreKit
import SwiftUI
import UIKit

// 目標の件数制限は撤廃済み（2026-08-17オーナー決定）のため、goals_limit の掲出箇所はない。
enum PaywallPlacement: String, CaseIterable, Identifiable {
    case settingsTargetAppLimit = "settings_target_app_limit"
    case settingsFamilyActivityLimit = "settings_family_activity_limit"
    case settingsProStatusRow = "settings_pro_status_row"
    case settingsThemeGate = "settings_theme_gate"
    case homeThemeGate = "home_theme_gate"
    case settingsModeGate = "settings_mode_gate"
    case onboardingPrepaywallSummary = "onboarding_prepaywall_summary"
    case onboardingModeGate = "onboarding_mode_gate"
    case onboardingTargetAppGate = "onboarding_target_app_gate"
    case onboardingLockThemeGate = "onboarding_lock_theme_gate"
    case weekly = "weekly"

    var id: String { rawValue }
}

/// 保留中のProテーマ選択を購入へ持ち込んでよいペイウォールか。
/// デザインを選ぶ導線（オンボーディング／テーマピッカー）から開いた時だけ持ち込む。
/// それ以外のペイウォールでProになっても、ロック画面とLive Activityは既定の `.e1` のままにする。
/// `default` を書かないのは、placementを追加したときにここでコンパイルエラーを出して判断を強制するため。
enum PendingProThemePaywallPolicy {
    static func keepsPendingSelection(for placement: PaywallPlacement) -> Bool {
        switch placement {
        case .settingsThemeGate, .homeThemeGate:
            return true
        case .onboardingPrepaywallSummary, .onboardingModeGate, .onboardingTargetAppGate, .onboardingLockThemeGate:
            return true
        case .settingsTargetAppLimit,
             .settingsFamilyActivityLimit,
             .settingsProStatusRow,
             .settingsModeGate,
             .weekly:
            return false
        }
    }
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

enum AnnualDiscountPolicy {
    static func percent(annualPrice: Decimal?, monthlyPrice: Decimal?) -> Int? {
        guard let annualPrice, let monthlyPrice else { return nil }

        let annualPriceValue = NSDecimalNumber(decimal: annualPrice).doubleValue
        let monthlyPriceValue = NSDecimalNumber(decimal: monthlyPrice).doubleValue
        guard monthlyPriceValue > 0 else { return nil }

        let discountPercent = Int(
            ((1 - annualPriceValue / (monthlyPriceValue * 12)) * 100).rounded()
        )
        return discountPercent > 0 ? discountPercent : nil
    }
}

struct PaywallView: View {
    let storeService: StoreService
    let placement: PaywallPlacement
    let yearlyDays: Int
    let dailyMinutes: Int
    let settingsStore: SettingsStore
    let model: AppModel?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: PaywallPlan = .annual
    @State private var alertMessage: String?
    @State private var didRecordAppearance = false
    @State private var didRecordDismissal = false

    init(
        storeService: StoreService,
        placement: PaywallPlacement,
        snapshotStore: JSONSnapshotStore = JSONSnapshotStore(
            containerProvider: DefaultContainerProvider()
        ),
        settingsStore: SettingsStore? = nil,
        model: AppModel? = nil
    ) {
        self.storeService = storeService
        self.placement = placement
        let resolvedSettingsStore = settingsStore ?? ((try? SettingsStore()) ?? SettingsStore(userDefaults: .standard))
        self.settingsStore = resolvedSettingsStore
        self.model = model
        let snapshot = try? snapshotStore.read(
            SelfCheckSnapshot.self,
            from: .selfCheckSnapshot
        )
        yearlyDays = Self.resolvedYearlyDays(snapshot: snapshot)
        dailyMinutes = Self.resolvedDailyMinutes(snapshot: snapshot)
    }

    static func resolvedYearlyDays(snapshot: SelfCheckSnapshot?) -> Int {
        snapshot?.estimatedYearlyDays ??
            (try? LossEstimator.estimate(usageBucket: "2-4時間").yearlyDays) ??
            38
    }

    /// 推計注記に出す「1日の利用時間」。年間日数と同じ回答・同じ既定バケットから解決し、
    /// 見出しの年数と注記の前提が食い違わないようにする。
    static func resolvedDailyMinutes(snapshot: SelfCheckSnapshot?) -> Int {
        snapshot?.estimatedDailyMinutes ??
            (try? LossEstimator.estimate(usageBucket: "2-4時間").dailyMinutes) ??
            150
    }

    private var canPurchase: Bool { storeService.canPurchase(product(for: selectedPlan)) }

    private var isBusy: Bool {
        storeService.isLoadingProducts || storeService.isPurchasing || storeService.isRestoring
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
            .padding(.top, 24)
            .padding(.bottom, 18)
        }
        .dopaScreenBackground()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            fixedActionBar
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // 破棄は購入時ではなく提示時に行う。提示中のピッカー表示と購入後の結果を食い違わせないため。
            // 計測のガードの外に置くのは、`fullScreenCover(item:)` が nil を挟まず placement だけ
            // 差し替わったときにビューの同一性と `didRecordAppearance` が保たれ、破棄が飛ぶため。
            // 代入は冪等で、ファネル計測の一部でもない。
            if !PendingProThemePaywallPolicy.keepsPendingSelection(for: placement) {
                model?.pendingProThemeSelection = nil
            }
            guard !didRecordAppearance else { return }
            didRecordAppearance = true
            let shownAt = Date()
            settingsStore.lastAnyPaywallShownAt = shownAt
            if placement == .weekly {
                settingsStore.lastWeeklyPaywallShownAt = shownAt
            }
            storeService.recordPaywallShown(placement: placement.rawValue)
            AppleAdsMeasurement.shared.recordPaywallShown(placement: placement.rawValue)
        }
        .onDisappear {
            if storeService.isPro {
                model?.applyPurchaseContinuationIfNeeded()
            } else {
                model?.purchaseContinuation = nil
            }
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
            model?.applyPurchaseContinuationIfNeeded()
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
        // 見出しブロックだけ中央揃えにする（CLAUDE.md「訴求画面の見出しは中央揃えが既定」）。
        // 外側の VStack(alignment: .leading) と、チェックリスト・プラン・法務は左揃えのまま。
        VStack(alignment: .center, spacing: 12) {
            CharacterView(.awake, size: DesignTokens.CharacterSize.header)
                .frame(maxWidth: .infinity)
                .frame(height: DesignTokens.CharacterSize.header)
                .background(DesignTokens.backgroundRaised)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DesignTokens.hairline, lineWidth: 1)
                }
                // ラベルは左上のまま。中央上へ寄せるとキャラクターの頭に重なる（2026-09-04 実画面で確認）。
                .overlay(alignment: .topLeading) {
                    SmallLabel(text: String(localized: "paywall.brand.pro", defaultValue: "DOPABREAK PRO"))
                        .padding(14)
                }
                .padding(.bottom, 4)

            VStack(alignment: .center, spacing: 2) {
                // 数字だけaccent色。前後の語は本文色のままにして、視線を年数へ落とす。
                (Text(String(localized: "paywall.header.line1.prefix", defaultValue: "「あと5分」が人生の")).foregroundStyle(DesignTokens.primaryText)
                    + Text(LossEstimatePresentation.lifetimeYearsText(yearlyDays: yearlyDays)).foregroundStyle(DesignTokens.accent)
                    + Text(String(localized: "paywall.header.line1.suffix", defaultValue: "年")).foregroundStyle(DesignTokens.primaryText))
                    .dopaFont(30, weight: .black, tracking: -1)
                    .multilineTextAlignment(.center)
                    // 2行目と同じ1行固定。折返しを許すと英語が3行になり見出しが崩れる（2026-09-04 実画面で確認）。
                    // 他の大見出しと同じ `dopaDisplayClamp()` で1行固定＋縮小下限0.5＋AX2打ち止めにする。
                    // 0.78止めだと文字を最大にした英語で末尾が「years g…」と切れた（同日 XXXL 実測）。
                    .dopaDisplayClamp()
                    .frame(maxWidth: .infinity)

                Text(String(localized: "paywall.header.line2", defaultValue: "開く前にブレーキ"))
                    .dopaFont(30, weight: .black, tracking: -1)
                    .foregroundStyle(DesignTokens.primaryText)
                    .multilineTextAlignment(.center)
                    .dopaDisplayClamp()
                    .frame(maxWidth: .infinity)

                // 50年という前提と、個人の回答からの推計であることを数字の直下に置く（docs/07 O-03r と同方針）。
                // 本文より見出し側に寄せたいので、外側の12ではなく6ptで見出しに付ける。
                Text(
                    String(
                        localized: "paywall.header.estimate_note",
                        defaultValue: "1日約\(LossEstimatePresentation.dailyTimeText(minutes: dailyMinutes))が50年続いた場合の推計"
                    )
                )
                .dopaFont(12, weight: .medium)
                .foregroundStyle(DesignTokens.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
            }

            // 無料機能の説明は置かない。本人が入れた目標を出し、何のために止めるかを買う直前に思い出させる
            // （2026-09-24 オーナー承認）。目標が無い導線では何も出さない。
            if !paywallGoalTitles.isEmpty {
                VStack(alignment: .center, spacing: 6) {
                    SmallLabel(text: String(localized: "paywall.goals.label", defaultValue: "あなたの目標"))
                    ForEach(Array(paywallGoalTitles.enumerated()), id: \.offset) { _, title in
                        Text(title)
                            .dopaFont(16, weight: .bold)
                            .foregroundStyle(DesignTokens.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
        }
    }

    /// 課金画面に出す目標。場所を取りすぎないよう3件まで。
    private var paywallGoalTitles: [String] {
        Array((model?.lockScreenDisplayTitles ?? []).filter { !$0.isEmpty }.prefix(3))
    }

    private var featureList: some View {
        VStack(spacing: 0) {
            // ブロックの3つのきっかけ（手動・毎週の予定・就寝中）を先頭に。Proで同時に使える（2026-09-24）
            PaywallFeatureRow(text: String(localized: "paywall.feature.deep_focus", defaultValue: "選んだアプリを完全にブロック"))
            divider
            PaywallFeatureRow(text: String(localized: "paywall.feature.weekly_schedule", defaultValue: "毎週のブロック予定を2つ設定"))
            divider
            PaywallFeatureRow(text: String(localized: "paywall.feature.night_block", defaultValue: "就寝中は自動で完全ブロック"))
            divider
            // 1日に開ける回数。2026-10-05 オーナー指示で「解除に30秒待つ強いブロック」の行から差し替えた。
            PaywallFeatureRow(text: String(localized: "paywall.feature.daily_open_limit", defaultValue: "1日の開く回数を制限してブロック"))
            divider
            PaywallFeatureRow(text: String(localized: "paywall.feature.unlimited_apps", defaultValue: "対応アプリの登録数制限を解除"))
            divider
            PaywallFeatureRow(text: String(localized: "paywall.feature.lock_theme", defaultValue: "ロック画面のデザインを選べる"))
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
            .buttonStyle(PrimaryButtonStyle(isEnabled: canPurchase))
            .disabled(!canPurchase)

            legalLinks

            if storeService.productLoadingState == .failed {
                Button(String(localized: "paywall.action.reload", defaultValue: "再読み込み")) {
                    Task { await storeService.loadProducts() }
                }
                .buttonStyle(SecondaryButtonStyle())
            }

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
                .disabled(storeService.isPurchasing || storeService.isRestoring)

                Button(String(localized: "paywall.action.later", defaultValue: "あとで")) {
                    dismissWithoutPurchase()
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(storeService.isPurchasing)
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
        Text(legalText)
            .dopaFont(10, weight: .medium, lineSpacing: 2)
            .foregroundStyle(DesignTokens.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // Keep both legal links below the purchase button, outside the scrolling content.
    private var legalLinks: some View {
        HStack(spacing: 8) {
            Link(destination: AppURLs.terms) {
                Text(String(localized: "paywall.legal.terms", defaultValue: "利用規約"))
                    .underline()
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            Link(destination: AppURLs.privacy) {
                Text(String(localized: "paywall.legal.privacy", defaultValue: "プライバシー"))
                    .underline()
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
        }
        .dopaFont(14, weight: .semibold)
        .foregroundStyle(DesignTokens.primaryText)
        .multilineTextAlignment(.center)
        .buttonStyle(.plain)
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
                        Text(
                            annualDiscountPercent.map {
                                String(
                                    localized: "paywall.plan.annual.savings_badge",
                                    defaultValue: "一番人気・\($0)%%お得"
                                )
                            } ?? String(
                                localized: "paywall.plan.annual.popular_badge",
                                defaultValue: "一番人気"
                            )
                        )
                            .dopaFont(11, weight: .black)
                            .foregroundStyle(DesignTokens.background)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DesignTokens.accent)
                            .clipShape(Capsule())
                    }
                }

                Text(storeService.productLoadingState == .loading ? "0000 / 00" : planPrice(plan))
                    .redacted(reason: storeService.productLoadingState == .loading ? .placeholder : [])
                    .dopaFont(storeService.productLoadingState == .failed ? 15 : 24, weight: .black, design: .rounded)
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
        guard storeService.productLoadingState == .loaded else { return nil }
        switch plan {
        case .annual:
            // 請求額（年額）はカードの大きい数字で出し、月あたりはここで小さく添える。
            // 審査3.1.2で「月あたりの方が目立つ」と却下されたため（2026-09-26 オーナー承認）。
            let monthlyEquivalentText = storeService.activeAnnualProduct.map { _ in annualMonthlyEquivalentText }
            let introText = storeService.isEligibleForAnnualIntroOffer
                ? (storeService.annualIntroOfferText ?? String(localized: "paywall.plan.annual.intro_fallback", defaultValue: "無料トライアルあり"))
                : nil
            let details = [monthlyEquivalentText, introText].compactMap { $0 }
            return details.isEmpty ? nil : details.joined(separator: "・")
        case .monthly:
            return nil
        }
    }

    private func planPrice(_ plan: PaywallPlan) -> String {
        if storeService.productLoadingState == .failed {
            return String(localized: "paywall.price.failed", defaultValue: "読み込めませんでした")
        }
        switch plan {
        case .annual:
            guard let product = storeService.activeAnnualProduct else {
                return String(localized: "paywall.value.unavailable", defaultValue: "—")
            }
            return String(localized: "paywall.plan.annual.price", defaultValue: "\(product.displayPrice)/年")
        case .monthly:
            guard let product = storeService.monthlyProduct else {
                return String(localized: "paywall.value.unavailable", defaultValue: "—")
            }
            return String(localized: "paywall.plan.monthly.price", defaultValue: "\(product.displayPrice)/月")
        }
    }

    private var primaryButtonTitle: String {
        if selectedPlan == .annual, storeService.isEligibleForAnnualIntroOffer {
            return storeService.annualIntroOfferCTAText
                ?? String(localized: "paywall.action.start_free_generic", defaultValue: "無料で始める")
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
                guard storeService.annualIntroOfferDurationText != nil else {
                    return String(localized: "paywall.legal.annual_intro_unspecified", defaultValue: "無料期間終了後、年額\(product.displayPrice)で自動更新。いつでも解約できます。購入はApple IDに請求されます")
                }
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
        storeService.annualIntroOfferDurationText ?? String(localized: "paywall.plan.annual.intro_duration_fallback", defaultValue: "無料期間あり")
    }

    private var annualMonthlyEquivalentText: String {
        guard let product = storeService.activeAnnualProduct else {
            return String(localized: "paywall.value.unavailable", defaultValue: "—")
        }
        return String(localized: "paywall.plan.annual.monthly_equivalent", defaultValue: "月あたり\(product.priceFormatStyle.format(product.price / Decimal(12)))")
    }

    private var annualDiscountPercent: Int? {
        AnnualDiscountPolicy.percent(
            annualPrice: storeService.activeAnnualProduct?.price,
            monthlyPrice: storeService.monthlyProduct?.price
        )
    }

    private func purchaseSelectedPlan() async {
        guard canPurchase, let product = product(for: selectedPlan) else {
            alertMessage = String(localized: "paywall.error.product_load", defaultValue: "商品情報を読み込めませんでした")
            return
        }

        let didBecomePro = await storeService.purchase(product)
        if didBecomePro {
            model?.applyPurchaseContinuationIfNeeded()
            dismiss()
        } else if let message = storeService.alertMessage {
            alertMessage = message
        }
    }

    private func restorePurchases() async {
        let didBecomePro = await storeService.restore()
        if didBecomePro {
            model?.applyPurchaseContinuationIfNeeded()
            dismiss()
        } else if let message = storeService.alertMessage {
            alertMessage = message
        }
    }

    private func dismissWithoutPurchase() {
        model?.purchaseContinuation = nil
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
