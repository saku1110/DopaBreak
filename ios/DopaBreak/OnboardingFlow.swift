import DopaBreakCore
import Foundation
import SwiftUI
import UIKit
import UserNotifications

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case selfCheck
    case quizAimless
    case quizRegret
    case quizResult
    case recovery
    case chooseApps
    case goalSetup
    case chooseMode
    case preview
    case whyScience
    case permission
    case notificationGuide
    case lockScreenCheck
    case prePaywallSummary
    case ready

    var progress: Double {
        Double(rawValue + 1) / Double(Self.allCases.count)
    }

    var previous: OnboardingStep? {
        Self(rawValue: rawValue - 1)
    }

    var next: OnboardingStep? {
        Self(rawValue: rawValue + 1)
    }

    var identifier: String {
        switch self {
        case .welcome: return "welcome"
        case .selfCheck: return "self_check"
        case .quizAimless: return "quiz_aimless"
        case .quizRegret: return "quiz_regret"
        case .quizResult: return "quiz_result"
        case .recovery: return "recovery_estimate"
        case .chooseApps: return "choose_apps"
        case .goalSetup: return "goal_setup"
        case .chooseMode: return "choose_mode"
        case .preview: return "preview"
        case .whyScience: return "why_science"
        case .permission: return "permission"
        case .notificationGuide: return "notification_guide"
        case .lockScreenCheck: return "lock_screen_check"
        case .prePaywallSummary: return "pre_paywall_summary"
        case .ready: return "ready"
        }
    }
}

private enum SlideDirection {
    case forward
    case backward

    var insertionEdge: Edge {
        self == .forward ? .trailing : .leading
    }

    var removalEdge: Edge {
        self == .forward ? .leading : .trailing
    }
}

private struct PagerHitTestingModifier: ViewModifier {
    let allowsHitTesting: Bool

    func body(content: Content) -> some View {
        content.allowsHitTesting(allowsHitTesting)
    }
}

private struct OnboardingProgressHeaderBottomPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct RotatingGoalPlaceholder: View {
    let placeholders: [String]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @State private var index = 0

    var body: some View {
        ZStack(alignment: .leading) {
            Text(placeholders.indices.contains(index) ? placeholders[index] : (placeholders.first ?? ""))
                .typesettingLanguage(locale.language)
                .id(index)
                .transition(.opacity)
                .minimumScaleFactor(0.85)
        }
        .dopaFont(18, weight: .bold)
        .foregroundStyle(DesignTokens.secondaryText)
        .lineLimit(1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: index)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        // Viewに紐づくtaskなので、入力開始または画面離脱で自動キャンセルされる。
        .task(id: reduceMotion) {
            index = 0
            guard !reduceMotion, placeholders.count > 1 else {
                return
            }

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(3.5))
                } catch {
                    return
                }
                guard !Task.isCancelled else {
                    return
                }
                index = (index + 1) % placeholders.count
            }
        }
    }
}

private struct OnboardingAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct TimeLedgerMotif: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            ledger(at: context.date)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "onboarding.welcome.ledger.accessibility_label", defaultValue: "今日の24時間のうち、現在時刻までの経過を示しています"))
    }

    private func ledger(at date: Date) -> some View {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let currentHour = components.hour ?? 0
        let currentMinute = components.minute ?? 0

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SmallLabel(text: String(localized: "onboarding.welcome.ledger.eyebrow", defaultValue: "TODAY / 1,440 MINUTES"))
                Spacer()
                Text(String(format: "%02d:%02d", currentHour, currentMinute))
                    .dopaFont(12, weight: .bold, design: .monospaced)
                    .foregroundStyle(DesignTokens.primaryText)
                    .monospacedDigit()
            }

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<24, id: \.self) { hour in
                    Capsule()
                        .fill(color(for: hour, currentHour: currentHour))
                        .frame(maxWidth: .infinity)
                        .frame(height: hour == currentHour ? 58 : 38)
                }
            }
            .frame(height: 58, alignment: .bottom)

            HStack {
                Text("00")
                Spacer()
                Text(String(localized: "onboarding.welcome.ledger.elapsed_time", defaultValue: "過ぎた時間"))
                Spacer()
                Text("24")
            }
            .dopaFont(10, weight: .bold, design: .monospaced)
            .foregroundStyle(DesignTokens.tertiaryText)

            HStack(spacing: 9) {
                Circle()
                    .fill(DesignTokens.accent)
                    .frame(width: 6, height: 6)
                Text(String(localized: "onboarding.welcome.ledger.body", defaultValue: "今日という時間は、いまも減り続けている。"))
                    .dopaFont(13, weight: .bold)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
        }
        .padding(16)
        .background(DesignTokens.card.opacity(0.72))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous)
                .stroke(DesignTokens.hairline, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous))
    }

    private func color(for hour: Int, currentHour: Int) -> Color {
        if hour == currentHour {
            return DesignTokens.accent
        }
        if hour < currentHour {
            return DesignTokens.secondaryText.opacity(0.42)
        }
        return DesignTokens.hairline
    }
}

struct OnboardingFlow: View {
    let model: AppModel
    let settingsStore: SettingsStore
    let onComplete: () -> Void

    private let snapshotStore = JSONSnapshotStore(containerProvider: DefaultContainerProvider())
    private let usageOptions = ["1時間未満", "1〜2時間", "2〜4時間", "4〜6時間", "6時間以上"]
    private let frequencyOptions = ["全くない", "数日", "半分以上", "ほとんど毎日"]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    @State private var step: OnboardingStep = .welcome
    @State private var direction: SlideDirection = .forward
    @State private var usageBucket: String?
    @State private var aimlessScrollBucket: String?
    @State private var regretBucket: String?
    @State private var selfCheckSnapshot: SelfCheckSnapshot?
    @State private var selectedCatalogIDs: [String] = []
    @State private var appSelectionMessage: String?
    @State private var heroGoal = ""
    /// この画面で編集中の目標一覧。保存済みの目標も含め、ここが表示と保存の正本になる。
    @State private var draftGoals: [OnboardingGoalDraft] = []
    /// 差分の基準。入場時と保存直後の保存済み内容を持つ。
    /// これが無いと、画面を開いている間に別経路で増えた目標まで消してしまう。
    @State private var goalBaseline = OnboardingGoalBaseline()
    @State private var goalCategory: GoalCategory = .other
    @State private var selectedMode: InterventionMode = .standard
    @State private var showDeepFocusConfirmation = false
    @State private var notificationMessage: String?
    @State private var isRequestingNotifications = false
    @State private var lockScreenCheckPhase: LockScreenCheckPhase = .starting
    @State private var lockScreenMarkerBlockBottomY: CGFloat = 0
    @State private var lockScreenSideButtonGeometry = DeviceSideButtonGeometry.current()
    @State private var progressHeaderBottomY: CGFloat = 0
    @State private var paywallPlacement: PaywallPlacement?
    @State private var flowAlert: OnboardingAlert?
    /// 選択の触感トークン。画面と一緒に消えない位置で監視する
    @State private var selectionFeedbackToken = 0
    /// 完了画面の祝福演出を一度だけ走らせるフラグ
    @State private var isReadyCelebrated = false

    private var goalPlaceholders: [String] {
        [
            String(localized: "onboarding.goal.placeholder.aspiration", defaultValue: "例: 英語で話せるようになる"),
            String(localized: "onboarding.goal.placeholder.habit", defaultValue: "例: 寝る前に本を読む"),
            String(localized: "onboarding.goal.placeholder.action", defaultValue: "例: 資格の勉強を進める"),
        ]
    }

    /// - Parameter initialStep: 開始ステップ。既定は`.welcome`で本番の挙動は変わらない。
    ///   任意ステップの見た目を実機で確認するキャプチャハーネス用に開けている。
    init(
        model: AppModel,
        settingsStore: SettingsStore,
        initialStep: OnboardingStep = .welcome,
        onComplete: @escaping () -> Void
    ) {
        self.model = model
        self.settingsStore = settingsStore
        self.onComplete = onComplete
        _step = State(initialValue: initialStep)

        // 保存済みの目標をそのままリストへ戻す。IDを持ったまま扱うため、
        // 中断して入り直しても、次へで同じ目標がもう1件増えることはない。
        _draftGoals = State(initialValue: OnboardingGoalList.restore(from: model.goals))
        _goalBaseline = State(initialValue: OnboardingGoalBaseline(goals: model.goals))
    }

    var body: some View {
        ZStack {
            onboardingBackdrop
            VStack(spacing: 0) {
                progressHeader
                pager
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .alert(item: $flowAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(String(localized: "onboarding.action.close", defaultValue: "閉じる")))
            )
        }
        .fullScreenCover(item: $paywallPlacement, onDismiss: {
            if step == .prePaywallSummary {
                advance(from: .prePaywallSummary)
            }
        }) { placement in
            PaywallView(
                storeService: model.storeService,
                placement: placement,
                settingsStore: settingsStore
            )
        }
        .alert(String(localized: "onboarding.mode.deep_focus.confirmation.title", defaultValue: "Deep Focusは強めの設定です"), isPresented: $showDeepFocusConfirmation) {
            Button(String(localized: "onboarding.mode.deep_focus.confirmation.start", defaultValue: "Deep Focusで始める")) {
                persistModeAndAdvance(.deepFocus)
            }
            Button(String(localized: "onboarding.mode.deep_focus.confirmation.standard", defaultValue: "通常モードにする")) {
                selectedMode = .standard
                persistModeAndAdvance(.standard)
            }
        } message: {
            Text(String(localized: "onboarding.mode.deep_focus.confirmation.message", defaultValue: "Deep Focus中は選んだアプリを開けません。時間はいつでも変えられます。"))
        }
        // 選択の触感は画面（`.id(step)`）と一緒に消えない位置へ置く。
        // 回答と同時に次へ進むクイズでも、触感が失われないようにするため
        .sensoryFeedback(.selection, trigger: selectionFeedbackToken)
        .sensoryFeedback(.success, trigger: isReadyCelebrated)
        .preferredColorScheme(.dark)
    }

    private var onboardingBackdrop: some View {
        DesignTokens.background.ignoresSafeArea()
    }

    private var progressHeader: some View {
        VStack(spacing: 10) {
            HStack {
                if previousStep(before: step) != nil {
                    Button {
                        goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .dopaFont(17, weight: .bold)
                            .foregroundStyle(DesignTokens.primaryText)
                            .frame(width: 44, height: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }

                Spacer()

                SmallLabel(text: String(format: "%02d / %02d", step.rawValue + 1, OnboardingStep.allCases.count))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle().fill(DesignTokens.hairline)
                    Rectangle()
                        .fill(DesignTokens.accent)
                        .frame(width: max(0, proxy.size.width * step.progress))
                        // 幅がアニメーションせず飛んでいたため、遷移と同じ長さで伸ばす
                        .animation(reduceMotion ? nil : DopaMotion.transition, value: step)
                }
            }
            .frame(height: 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: OnboardingProgressHeaderBottomPreferenceKey.self,
                    value: proxy.frame(in: .global).maxY
                )
            }
        }
        .onPreferenceChange(OnboardingProgressHeaderBottomPreferenceKey.self) {
            progressHeaderBottomY = $0
        }
    }

    private var pager: some View {
        ZStack {
            currentContent
                .id(step)
                .transition(slideTransition)
        }
        .animation(DopaMotion.transition, value: step)
    }

    private var slideTransition: AnyTransition {
        let departingHitTesting = AnyTransition.modifier(
            active: PagerHitTestingModifier(allowsHitTesting: false),
            identity: PagerHitTestingModifier(allowsHitTesting: true)
        )

        // Reduce Motion時は画面全体の水平移動をやめ、フェードだけで入れ替える
        guard !reduceMotion else {
            return .asymmetric(
                insertion: .opacity,
                removal: .opacity.combined(with: departingHitTesting)
            )
        }
        return .asymmetric(
            insertion: .move(edge: direction.insertionEdge).combined(with: .opacity),
            removal: .move(edge: direction.removalEdge)
                .combined(with: .opacity)
                .combined(with: departingHitTesting)
        )
    }

    @ViewBuilder
    private var currentContent: some View {
        switch step {
        case .welcome:
            welcomeContent
        case .selfCheck:
            selfCheckContent
        case .quizAimless:
            aimlessQuizContent
        case .quizRegret:
            regretQuizContent
        case .quizResult:
            quizResultContent
        case .recovery:
            recoveryContent
        case .chooseApps:
            chooseAppsContent
        case .goalSetup:
            goalSetupContent
        case .chooseMode:
            chooseModeContent
        case .preview:
            previewContent
        case .whyScience:
            whyScienceContent
        case .permission:
            automationGuideContent
        case .notificationGuide:
            notificationGuideContent
        case .lockScreenCheck:
            lockScreenCheckContent
        case .prePaywallSummary:
            prePaywallSummaryContent
        case .ready:
            readyContent
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        switch step {
        case .selfCheck, .quizAimless, .quizRegret:
            EmptyView()
        default:
            actionArea
        }
    }

    private var actionArea: some View {
        VStack(spacing: 10) {
            primaryAction
            secondaryAction
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(DesignTokens.background)
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch step {
        case .welcome:
            VStack(spacing: 10) {
                primaryButton(String(localized: "onboarding.welcome.action", defaultValue: "どれだけ溶けているか見る")) { advance(from: .welcome) }
                Text(String(localized: "onboarding.welcome.action_note", defaultValue: "質問3つ・30秒"))
                    .dopaFont(13, weight: .medium, lineSpacing: 3)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .multilineTextAlignment(.center)
            }
        case .quizResult:
            primaryButton(String(localized: "onboarding.result.action", defaultValue: "この時間を取り戻す")) { advance(from: .quizResult) }
        case .recovery:
            primaryButton(String(localized: "onboarding.recovery.action", defaultValue: "取り戻す設定を始める")) { advance(from: .recovery) }
        case .chooseApps:
            primaryButton(
                selectedCatalogIDs.isEmpty
                    ? String(localized: "onboarding.apps.action.empty", defaultValue: "アプリを選ぶ")
                    : String(localized: "onboarding.apps.action.selected", defaultValue: "この\(selectedCatalogIDs.count)つで始める")
            ) {
                persistSelectedAppsAndAdvance()
            }
        case .goalSetup:
            primaryButton(
                String(localized: "onboarding.goal.action", defaultValue: "この目標で進む"),
                enabled: canLeaveGoalSetup
            ) {
                saveGoalAndAdvance(skipped: false)
            }
        case .chooseMode:
            primaryButton(String(localized: "onboarding.mode.action", defaultValue: "この設定で進む")) { confirmModeIfNeeded() }
        case .preview:
            primaryButton(String(localized: "onboarding.preview.action", defaultValue: "この仕組みを使う")) { advance(from: .preview) }
        case .whyScience:
            primaryButton(String(localized: "onboarding.science.action", defaultValue: "仕組みに任せる")) { advance(from: .whyScience) }
        case .permission:
            VStack(spacing: 10) {
                primaryButton(String(localized: "onboarding.automation.action", defaultValue: "ショートカットを開く")) { openShortcutsAndAdvance() }
                Text(String(localized: "onboarding.automation.action_note", defaultValue: "設定できたかどうかは 対象アプリを開いたときに自動で確認されます"))
                    .dopaFont(13, weight: .medium, lineSpacing: 3)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .multilineTextAlignment(.center)
            }
        case .notificationGuide:
            primaryButton(String(localized: "onboarding.notification.action", defaultValue: "通知をオンにする"), enabled: !isRequestingNotifications) {
                Task { await requestNotifications() }
            }
        case .lockScreenCheck:
            switch lockScreenCheckPhase {
            case .blocked(.systemDisabled):
                primaryButton(String(localized: "lock_check.action.settings", defaultValue: "設定を開く")) {
                    LockScreenSettingsLink.open()
                }
            case .blocked(.failed):
                primaryButton(String(localized: "lock_check.action.retry", defaultValue: "もう一度出す")) {
                    Task {
                        await LockScreenCheckAction.retry(
                            model: model,
                            phase: $lockScreenCheckPhase
                        )
                    }
                }
            case .starting, .waiting, .confirmed, .noGoal:
                primaryButton(String(localized: "onboarding.action.next", defaultValue: "次に進む")) {
                    completeLockScreenCheckAndAdvance()
                }
            }
        case .prePaywallSummary:
            primaryButton(String(localized: "onboarding.summary.action", defaultValue: "この時間を守る")) { paywallPlacement = .onboardingPrepaywallSummary }
        case .ready:
            primaryButton(String(localized: "onboarding.ready.action", defaultValue: "DopaBreakをはじめる")) { advance(from: .ready) }
        case .selfCheck, .quizAimless, .quizRegret:
            EmptyView()
        }
    }

    @ViewBuilder
    private var secondaryAction: some View {
        switch step {
        case .goalSetup:
            textOnlyButton(String(localized: "onboarding.goal.action.later", defaultValue: "あとで設定する")) { saveGoalAndAdvance(skipped: true) }
        case .permission:
            secondaryButton(String(localized: "onboarding.action.later", defaultValue: "あとで")) { advance(from: .permission) }
        case .notificationGuide:
            secondaryButton(String(localized: "onboarding.action.later", defaultValue: "あとで")) { advance(from: .notificationGuide) }
        case .lockScreenCheck:
            if lockScreenCheckPhase.isBlocked {
                secondaryButton(String(localized: "onboarding.action.later", defaultValue: "あとで")) { advance(from: .lockScreenCheck) }
            }
        case .prePaywallSummary:
            secondaryButton(String(localized: "onboarding.action.later", defaultValue: "あとで")) {
                model.recordFunnelEvent(.prePaywallSkipped, detail: step.identifier)
                advance(from: .prePaywallSummary)
            }
        default:
            EmptyView()
        }
    }
}

private extension OnboardingFlow {
    var welcomeContent: some View {
        screenScroll {
            centeredEyebrow(String(localized: "onboarding.welcome.eyebrow", defaultValue: "DOPABREAK"))
                .onboardingStagger(0)

            // Spacerは幅を持たないため、overlayを重ねると中央基準が定まらず左へ寄る。
            // キャラは自前で横幅いっぱいの中央へ置き、前後20ptで見出しと分離する。
            CharacterView(.doom, size: DesignTokens.CharacterSize.lead)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .onboardingStagger(1)

            VStack(alignment: .center, spacing: 22) {
                Text(String(localized: "onboarding.welcome.title", defaultValue: "人生の時間は\n二度と戻らない"))
                    .typesettingLanguage(locale.language)
                    .dopaFont(44, weight: .black, tracking: -1, lineSpacing: 2)
                    .foregroundStyle(DesignTokens.primaryText)
                    .minimumScaleFactor(0.74)
                    .multilineTextAlignment(.center)

                centeredLead(String(localized: "onboarding.welcome.lead", defaultValue: "なんとなく開くだけで1日が終わる"))

                Text(String(localized: "onboarding.welcome.tagline", defaultValue: "ブロックしない 開く直前のひと呼吸"))
                    .dopaFont(17, weight: .bold)
                    .foregroundStyle(DesignTokens.accent)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .onboardingStagger(2)
        }
    }

    var selfCheckContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                centeredEyebrow(String(localized: "onboarding.self_check.eyebrow", defaultValue: "質問 1 / 3"))
                    .onboardingStagger(0)
                centeredTitle(String(localized: "onboarding.self_check.title", defaultValue: "SNSを見ている時間は 1日どれくらいですか？"))
                    .onboardingStagger(1)
                centeredLead(String(localized: "onboarding.self_check.hint", defaultValue: "ざっくりでOKです"))
                    .onboardingStagger(2)
                singleSelectOptions(usageOptions, selection: usageBucket) { option in
                    usageBucket = option
                    advance(from: .selfCheck)
                }
                    .onboardingStagger(3)

                centeredLead(String(localized: "onboarding.self_check.privacy_note", defaultValue: "回答は端末内にのみ保存されます。"))
                    .onboardingStagger(4)
            }
        }
    }

    var aimlessQuizContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                centeredEyebrow(String(localized: "onboarding.aimless.eyebrow", defaultValue: "質問 2 / 3"))
                    .onboardingStagger(0)
                centeredTitle(String(localized: "onboarding.aimless.title", defaultValue: "気づけば目的もなく スクロールしている"))
                    .onboardingStagger(1)
                centeredLead(String(localized: "onboarding.aimless.lead", defaultValue: "この2週間でどれくらい当てはまりましたか？"))
                    .onboardingStagger(2)
                frequencyButtons(selection: aimlessScrollBucket) { option in
                    aimlessScrollBucket = option
                    advance(from: .quizAimless)
                }
                .onboardingStagger(3)
            }
        }
    }

    var regretQuizContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                centeredEyebrow(String(localized: "onboarding.regret.eyebrow", defaultValue: "質問 3 / 3"))
                    .onboardingStagger(0)
                centeredTitle(String(localized: "onboarding.regret.title", defaultValue: "「時間を溶かした」と 感じることがある"))
                    .onboardingStagger(1)
                centeredLead(String(localized: "onboarding.regret.lead", defaultValue: "SNSを閉じたあと どれくらい当てはまりますか？"))
                    .onboardingStagger(2)
                frequencyButtons(selection: regretBucket) { option in
                    regretBucket = option
                    if persistSelfCheckSnapshot() {
                        advance(from: .quizRegret)
                    }
                }
                .onboardingStagger(3)
            }
        }
    }

    var quizResultContent: some View {
        let estimate = currentEstimate
        let heroPrefix = String(localized: "onboarding.result.hero_yearly.prefix", defaultValue: "1年で 約")
        let heroDays = "\(estimate.yearlyDays)"
        let heroSuffix = String(localized: "onboarding.result.hero_yearly.suffix", defaultValue: "日")
        let heroAccessibilityText = "\(heroPrefix) \(heroDays) \(heroSuffix)"
        let threeYearPrefix = String(localized: "onboarding.result.three_year.prefix", defaultValue: "3年なら 約")
        let threeYearMonths = threeYearMonthsText(yearlyDays: estimate.yearlyDays)
        let threeYearSuffix = String(localized: "onboarding.result.three_year.suffix", defaultValue: "か月")
        let threeYearAccessibilityText = "\(threeYearPrefix) \(threeYearMonths) \(threeYearSuffix)"
        let lifetimeYears = LossEstimator.lifetimeYears(fromYearlyDays: estimate.yearlyDays)
        let lifetimeText = String(
            localized: "onboarding.result.lifetime",
            defaultValue: "このままなら50年で 人生の約\(lifetimeYearsText(yearlyDays: estimate.yearlyDays))年"
        )
        let lifeGridFill = LossEstimator.lifeGridFill(lifetimeYears: lifetimeYears)
        return GeometryReader { viewport in
            let usesCompactResultSpacing = viewport.size.height < 700
            let resultSpacing: CGFloat = usesCompactResultSpacing ? 8 : 12
            let heroSpacing: CGFloat = usesCompactResultSpacing ? 4 : 8
            let resultCharacterSize: CGFloat = usesCompactResultSpacing
                ? 120
                : DesignTokens.CharacterSize.header

            screenScroll {
                VStack(alignment: .center, spacing: resultSpacing) {
                    centeredEyebrow(String(localized: "onboarding.result.eyebrow", defaultValue: "推計結果 / YOUR RESULT"))
                        .onboardingStagger(0)
                    centeredLead(String(localized: "onboarding.result.lead", defaultValue: "あなたの回答にもとづく推計では"))
                        .onboardingStagger(1)

                    // 結果画面だけheader寸法へ下げ、6.1インチでも人生グリッドまで初期表示する。
                    CharacterSwapSequence(
                        from: .doom,
                        to: .worse,
                        size: resultCharacterSize,
                        delayNanoseconds: 1_350_000_000
                    )
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .center, spacing: heroSpacing) {
                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            Text(heroPrefix)
                                .dopaFont(20, weight: .bold)
                                .foregroundStyle(DesignTokens.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .allowsTightening(true)
                            ZStack {
                                // 最終値と同じ桁幅を先に確保し、0→38の途中で行全体を動かさない。
                                Text(heroDays)
                                    .dopaFont(70, weight: .black, design: .rounded)
                                    .monospacedDigit()
                                    .foregroundStyle(DesignTokens.accent)
                                    .dopaDisplayClamp()
                                    .hidden()
                                    .accessibilityHidden(true)

                                OnboardingCountUp(
                                    target: estimate.yearlyDays,
                                    accessibilityText: heroAccessibilityText
                                ) { days in
                                    Text("\(days)")
                                        .dopaFont(70, weight: .black, design: .rounded)
                                        .monospacedDigit()
                                        .foregroundStyle(DesignTokens.accent)
                                        .dopaDisplayClamp()
                                }
                            }
                            .layoutPriority(1)
                            Text(heroSuffix)
                                .dopaFont(28, weight: .black)
                                .foregroundStyle(DesignTokens.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .allowsTightening(true)
                        }
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: heroAccessibilityText))

                        centeredLead(String(localized: "onboarding.result.daily_body", defaultValue: "がSNSに溶けています"))

                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            Text(threeYearPrefix)
                                .dopaFont(18, weight: .bold)
                                .foregroundStyle(DesignTokens.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .allowsTightening(true)
                            Text(threeYearMonths)
                                .dopaFont(58, weight: .black, design: .rounded)
                                .monospacedDigit()
                                .foregroundStyle(DesignTokens.accent)
                                .dopaDisplayClamp()
                                .layoutPriority(1)
                            Text(threeYearSuffix)
                                .dopaFont(28, weight: .black)
                                .foregroundStyle(DesignTokens.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .allowsTightening(true)
                        }
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: threeYearAccessibilityText))
                    }
                    .onboardingStagger(2)

                    centeredLead(
                        String(
                            localized: "onboarding.result.disclaimer",
                            defaultValue: "※1日約\(dailyTimeText(minutes: estimate.dailyMinutes))の想定にもとづく推計値です。"
                        )
                    )
                        .onboardingStagger(3)

                    centeredLead(lifetimeText)
                        .onboardingStagger(4)

                    VStack(spacing: 8) {
                        OnboardingLifeGrid(
                            fullCells: lifeGridFill.fullCells,
                            partialFraction: lifeGridFill.partialFraction,
                            cellCount: LossEstimator.lifetimeHorizonYears,
                            reduceMotion: reduceMotion,
                            viewportHeight: viewport.size.height
                        )
                        .onboardingStagger(5)

                        SmallLabel(
                            text: String(
                                localized: "onboarding.result.life_grid.legend",
                                defaultValue: "1マス ＝ 1年　塗り ＝ SNSに消える時間"
                            )
                        )
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 320, alignment: .center)
                        .onboardingStagger(6)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                // 共有screenScrollの28ptは変えず、この結果画面だけ上部の空きを詰める。
                .padding(.top, usesCompactResultSpacing ? -20 : -16)
            }
        }
    }

    /// 損失の提示（`quizResultContent`）の直後に置く回復の一手。
    /// 同じ推計から「半分にできたら戻る時間」だけを取り出して見せ、
    /// 落ち込みで終わらせずに設定へ進む動機に変える。
    var recoveryContent: some View {
        let recoveredDays = recoveredYearlyDays
        let heroPrefix = String(localized: "onboarding.recovery.hero_yearly.prefix", defaultValue: "1年で 約")
        let heroDays = "\(recoveredDays)"
        let heroSuffix = String(localized: "onboarding.recovery.hero_yearly.suffix", defaultValue: "日")
        let heroAccessibilityText = "\(heroPrefix) \(heroDays) \(heroSuffix)"
        return screenScroll {
            VStack(alignment: .center, spacing: 24) {
                centeredEyebrow(String(localized: "onboarding.recovery.eyebrow", defaultValue: "取り戻せる時間 / GOOD NEWS"))
                    .onboardingStagger(0)
                centeredLead(String(localized: "onboarding.recovery.lead", defaultValue: "開く回数を半分にできた場合の試算では"))
                    .onboardingStagger(1)

                // 損失側の doom→worse と対にする。数字が出そろった直後に目を覚ました表情へ替える。
                CharacterSwapSequence(
                    from: .doom,
                    to: .awake,
                    size: DesignTokens.CharacterSize.lead,
                    delayNanoseconds: 1_350_000_000
                )
                .frame(maxWidth: .infinity)

                VStack(alignment: .center, spacing: 16) {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(heroPrefix)
                            .dopaFont(20, weight: .bold)
                            .foregroundStyle(DesignTokens.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .allowsTightening(true)
                        ZStack {
                            // 最終値と同じ桁幅を先に確保し、カウントアップ中に行全体を動かさない。
                            Text(heroDays)
                                .dopaFont(70, weight: .black, design: .rounded)
                                .monospacedDigit()
                                .foregroundStyle(DesignTokens.accent)
                                .dopaDisplayClamp()
                                .hidden()
                                .accessibilityHidden(true)

                            OnboardingCountUp(
                                target: recoveredDays,
                                accessibilityText: heroAccessibilityText
                            ) { days in
                                Text("\(days)")
                                    .dopaFont(70, weight: .black, design: .rounded)
                                    .monospacedDigit()
                                    .foregroundStyle(DesignTokens.accent)
                                    .dopaDisplayClamp()
                            }
                        }
                        .layoutPriority(1)
                        Text(heroSuffix)
                            .dopaFont(28, weight: .black)
                            .foregroundStyle(DesignTokens.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .allowsTightening(true)
                    }
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: heroAccessibilityText))

                    centeredLead(String(localized: "onboarding.recovery.daily_body", defaultValue: "が自分の時間に戻ります"))
                }
                .onboardingStagger(2)

                centeredLead(
                    String(
                        localized: "onboarding.recovery.disclaimer",
                        defaultValue: "※質問1の回答をもとに 開く回数が半分になった場合を計算した試算値です。"
                    )
                )
                    .padding(.top, 8)
                    .onboardingStagger(3)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    var chooseAppsContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                centeredEyebrow(String(localized: "onboarding.apps.eyebrow", defaultValue: "TARGET APPS"))
                    .onboardingStagger(0)
                centeredTitle(String(localized: "onboarding.apps.title", defaultValue: "止めたいアプリを選ぶ"))
                    .onboardingStagger(1)
                centeredLead(String(localized: "onboarding.apps.lead", defaultValue: "いつでも変更できます。"))
                    .onboardingStagger(2)
                centeredLead(String(localized: "onboarding.apps.free_limit_note", defaultValue: "無料プランでは1つまで"))
                    .onboardingStagger(3)

                TargetAppGrid(
                    items: SNSAppCatalog.all,
                    selectedCatalogIDs: Set(selectedCatalogIDs),
                    onboardingStaggerBase: 4,
                    onToggle: toggleCatalogSelection
                )

                if let appSelectionMessage {
                    messageCard(appSelectionMessage)
                }
            }
        }
    }

    var goalSetupContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                centeredEyebrow(String(localized: "onboarding.goal.eyebrow", defaultValue: "あなたの目標 / GOAL"))
                    .onboardingStagger(0)
                centeredTitle(String(localized: "onboarding.goal.title", defaultValue: "空いたこの時間で 何をしますか？"))
                    .onboardingStagger(1)
                centeredLead(String(localized: "onboarding.goal.lead", defaultValue: "なりたい姿でも やることでもいい"))
                    .onboardingStagger(2)
                centeredLead(String(localized: "onboarding.goal.multi_note", defaultValue: "目標は複数追加できます。無料プランでは1つまで"))
                    .onboardingStagger(3)

                VStack(alignment: .leading, spacing: 8) {
                    fieldContainer {
                        HStack(spacing: 8) {
                            ZStack(alignment: Alignment(horizontal: .leading, vertical: .firstTextBaseline)) {
                                if heroGoal.isEmpty {
                                    RotatingGoalPlaceholder(placeholders: goalPlaceholders)
                                }

                                // 変換中の未確定文字列をbindingへ書き戻すと日本語入力が壊れるため、
                                // ここでは切り詰めない。上限は文字数表示と追加ボタンの有効・無効で示し、
                                // 確定はcommit時の正規化で行う
                                TextField("", text: $heroGoal)
                                    .dopaFont(18, weight: .bold)
                                    .foregroundStyle(DesignTokens.primaryText)
                                    .submitLabel(.done)
                                    .accessibilityLabel(
                                        String(localized: "onboarding.goal.field.accessibility", defaultValue: "目標を入力")
                                    )
                                    .accessibilityHint(
                                        String(localized: "onboarding.goal.placeholder.aspiration", defaultValue: "例: 英語で話せるようになる")
                                    )
                                    .onSubmit {
                                        commitDraftGoal()
                                    }
                            }
                            .frame(maxWidth: .infinity)

                            addGoalButton
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(String(localized: "onboarding.goal.helper", defaultValue: "そのままロック画面に表示されます"))
                            .dopaFont(13, weight: .medium)
                            .foregroundStyle(DesignTokens.secondaryText)
                        Spacer(minLength: 8)
                        Text(
                            String(
                                localized: "onboarding.goal.character_count",
                                defaultValue: "\(typedGoalLength)/\(OnboardingGoalList.titleLimit)"
                            )
                        )
                        .dopaFont(12, weight: .medium, design: .monospaced)
                        .foregroundStyle(isTypedGoalOverLimit ? DesignTokens.danger : DesignTokens.secondaryText)
                    }
                }
                .onboardingStagger(4)

                if !draftGoals.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(draftGoals) { draft in
                            draftGoalRow(draft)
                        }
                    }
                    .onboardingStagger(5)
                }
            }
        }
    }

    var chooseModeContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                centeredEyebrow(String(localized: "onboarding.mode.eyebrow", defaultValue: "STRENGTH"))
                    .onboardingStagger(0)
                centeredTitle(String(localized: "onboarding.mode.title", defaultValue: "どのくらい強く 止めますか？"))
                    .onboardingStagger(1)
                centeredLead(String(localized: "onboarding.mode.lead", defaultValue: "生活に合う強さを選べます。"))
                    .onboardingStagger(2)

                VStack(spacing: 12) {
                    ForEach(Array(InterventionMode.selectable.enumerated()), id: \.element) { index, mode in
                        modeButton(mode)
                            .onboardingStagger(3 + index)
                    }
                }
            }
        }
    }
}

private extension OnboardingFlow {
    var previewContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                centeredEyebrow(String(localized: "onboarding.preview.eyebrow", defaultValue: "PREVIEW"))
                    .onboardingStagger(0)
                centeredTitle(String(localized: "onboarding.preview.title", defaultValue: "SNSを開こうとすると こうなります"))
                    .onboardingStagger(1)
                centeredLead(String(localized: "onboarding.preview.lead", defaultValue: "目的を確かめて、必要なときだけ意図して開けるようにします。"))
                    .onboardingStagger(2)

                CharacterSwapSequence(
                    from: .doom,
                    to: .awake,
                    size: DesignTokens.CharacterSize.header,
                    delayNanoseconds: 700_000_000
                )
                .frame(maxWidth: .infinity)
                .onboardingStagger(3)

                CardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        numberedLine(String(localized: "onboarding.preview.step1", defaultValue: "1. 何のために開くか確認する"))
                        numberedLine(String(localized: "onboarding.preview.step2", defaultValue: "2. 仕事や連絡なら、すぐ時間を選ぶ"))
                        numberedLine(String(localized: "onboarding.preview.step3", defaultValue: "3. 暇つぶしなら、一呼吸して選び直す"))
                        numberedLine(String(localized: "onboarding.preview.step4", defaultValue: "4. 使った後の満足感を振り返る"))
                    }
                }
                .onboardingStagger(4)

                CardContainer {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(String(localized: "onboarding.preview.card.title", defaultValue: "何のために開く？"))
                            .dopaFont(24, weight: .bold)
                            .foregroundStyle(DesignTokens.primaryText)
                        previewChoice(String(localized: "onboarding.preview.card.cancel", defaultValue: "開かない"), highlighted: true)
                        previewChoice(String(localized: "onboarding.preview.card.continue", defaultValue: "理由を選んで続ける"), highlighted: false)
                    }
                }
                .onboardingStagger(5)
            }
        }
    }

    var whyScienceContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                centeredEyebrow(String(localized: "onboarding.science.eyebrow", defaultValue: "WHY IT WORKS / 科学的背景"))
                    .onboardingStagger(0)
                centeredTitle(String(localized: "onboarding.science.title", defaultValue: "意志の力では 勝てない"))
                    .onboardingStagger(1)
                centeredLead(String(localized: "onboarding.science.lead", defaultValue: "つい開いてしまうのは、あなたが弱いからではありません。SNSは無意識の起動を狙って設計されています。"))
                    .onboardingStagger(2)

                centeredLead(
                    String(localized: "onboarding.science.dopamine", defaultValue: "SNSは次に何が出るかわからない報酬でドーパミンの回路を刺激し続けます。スロットマシンと同じ変動報酬という設計です。この反射は意志の力では止められません。")
                )
                .onboardingStagger(3)

                CardContainer {
                    VStack(alignment: .leading, spacing: 14) {
                        principleLine(
                            String(localized: "onboarding.science.principle1.title", defaultValue: "1. 摩擦"),
                            String(localized: "onboarding.science.principle1.detail", defaultValue: "反射的な起動に一拍置く")
                        )
                        principleLine(
                            String(localized: "onboarding.science.principle2.title", defaultValue: "2. 実行意図"),
                            String(localized: "onboarding.science.principle2.detail", defaultValue: "開く前に理由を言語化する")
                        )
                        principleLine(
                            String(localized: "onboarding.science.principle3.title", defaultValue: "3. 自己モニタリング"),
                            String(localized: "onboarding.science.principle3.detail", defaultValue: "今日何回目かを見る")
                        )
                        principleLine(
                            String(localized: "onboarding.science.principle4.title", defaultValue: "4. 自己観察"),
                            String(localized: "onboarding.science.principle4.detail", defaultValue: "見た後の満足感を記録する")
                        )
                    }
                }
                .onboardingStagger(4)

                centeredLead(
                    String(localized: "onboarding.science.mechanism", defaultValue: "DopaBreakはこの回路が自動で回り出す入口に割り込み、ひと呼吸ぶんの間を差し込みます。")
                )
                .onboardingStagger(5)

                centeredLead(
                    String(localized: "onboarding.science.research", defaultValue: "開く前にワンクッション置く手法は、査読付き研究（PNAS, 2023）でSNS利用を平均57%減らすことが示されています。")
                )
                .onboardingStagger(6)

                VStack(alignment: .leading, spacing: 8) {
                    bodyText(String(localized: "onboarding.science.disclaimer.study", defaultValue: "※他社アプリ(one sec)を対象とした研究です。"))
                    bodyText(String(localized: "onboarding.science.disclaimer.effect", defaultValue: "※本アプリの効果を保証するものではありません。"))
                    bodyText(String(localized: "onboarding.science.disclaimer.medical", defaultValue: "※医療・治療を目的としたアプリではありません。"))
                }
                .onboardingStagger(7)
            }
        }
    }

    var automationGuideContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                centeredEyebrow(String(localized: "onboarding.automation.eyebrow", defaultValue: "SETUP"))
                    .onboardingStagger(0)
                centeredTitle(String(localized: "onboarding.automation.title", defaultValue: "自動で一呼吸を出す設定"))
                    .onboardingStagger(1)
                centeredLead(String(localized: "onboarding.automation.lead", defaultValue: "ショートカットのオートメーションで、選んだアプリを開いたときにDopaBreakを起動します。設定は一度だけ・約2分です。"))
                    .onboardingStagger(2)

                CardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        numberedLine(String(localized: "onboarding.automation.step1", defaultValue: "1. オートメーションを開く"))
                        numberedLine(String(localized: "onboarding.automation.step2", defaultValue: "2. ＋を押してAppを選ぶ"))
                        numberedLine(String(localized: "onboarding.automation.step3", defaultValue: "3. 対象アプリを選び「開かれたとき」を選ぶ"))
                        numberedLine(String(localized: "onboarding.automation.step4", defaultValue: "4. すぐに実行を選ぶ"))
                        numberedLine(String(localized: "onboarding.automation.step5", defaultValue: "5. アクションで「DopaBreakで一呼吸」を選ぶ"))
                    }
                }
                .onboardingStagger(3)

                // つまずくのは3・4の選択肢だけなので、その2画面ぶんだけ模式図で見せる。
                // 正解に色と「ここを選ぶ」を付け、選ばない側は減光して迷いを消す。
                CardContainer {
                    VStack(alignment: .leading, spacing: 14) {
                        SmallLabel(text: String(localized: "onboarding.automation.mock.label", defaultValue: "選択画面のイメージ"))
                        automationMockGroup(
                            correct: String(localized: "onboarding.automation.mock.opened", defaultValue: "開かれたとき"),
                            incorrect: String(localized: "onboarding.automation.mock.closed", defaultValue: "閉じられたとき")
                        )
                        automationMockGroup(
                            correct: String(localized: "onboarding.automation.mock.run_immediately", defaultValue: "すぐに実行"),
                            incorrect: String(localized: "onboarding.automation.mock.ask_before", defaultValue: "実行の前に尋ねる")
                        )
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    Text(
                        String(
                            localized: "onboarding.automation.mock.accessibility_label",
                            defaultValue: "「開かれたとき」と「すぐに実行」を選びます"
                        )
                    )
                )
                .onboardingStagger(4)

                CardContainer {
                    VStack(alignment: .leading, spacing: 10) {
                        SmallLabel(text: String(localized: "onboarding.automation.apps_label", defaultValue: "設定するアプリ"))
                        if selectedTargets.isEmpty {
                            Text(String(localized: "onboarding.automation.apps_empty", defaultValue: "先に止めるアプリを選んでください。"))
                                .dopaFont(15, weight: .semibold)
                                .foregroundStyle(DesignTokens.secondaryText)
                        } else {
                            ForEach(selectedTargets) { target in
                                Text(target.displayName)
                                    .dopaFont(16, weight: .bold)
                                    .foregroundStyle(DesignTokens.primaryText)
                            }
                        }
                    }
                }
                .onboardingStagger(5)

                centeredLead(
                    String(
                        localized: "onboarding.automation.privacy_note",
                        defaultValue: "検知するのは選んだアプリを開いたことだけです。ほかの操作や画面の内容がDopaBreakに送られることはありません。"
                    )
                )
                .onboardingStagger(6)
            }
        }
    }

    var notificationGuideContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                centeredEyebrow(String(localized: "onboarding.notification.eyebrow", defaultValue: "NOTIFICATION"))
                    .onboardingStagger(0)
                centeredTitle(String(localized: "onboarding.notification.title", defaultValue: "ロック画面に 目標を"))
                    .onboardingStagger(1)
                centeredLead(String(localized: "onboarding.notification.lead", defaultValue: "朝の通知とLive Activityで、目標を毎日思い出します。"))
                    .onboardingStagger(2)

                VStack(spacing: 0) {
                    CharacterView(.relief, size: DesignTokens.CharacterSize.header)
                        .padding(.top, 16)
                    Spacer(minLength: 12)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            SmallLabel(text: String(localized: "onboarding.notification.preview.app_name", defaultValue: "DOPABREAK"))
                            Spacer()
                            SmallLabel(text: String(localized: "onboarding.notification.preview.now", defaultValue: "今"))
                        }
                        Text(notificationGoalText)
                            .dopaFont(20, weight: .black)
                            .foregroundStyle(DesignTokens.primaryText)
                            .lineLimit(2)
                        HStack(spacing: 6) {
                            Text(String(localized: "onboarding.notification.preview.today", defaultValue: "今日"))
                                .foregroundStyle(DesignTokens.secondaryText)
                            Text(String(localized: "onboarding.notification.preview.count", defaultValue: "\(model.todayCancelledCount)回"))
                                .foregroundStyle(DesignTokens.accent)
                            Text(String(localized: "onboarding.notification.preview.cancelled", defaultValue: "開くのをやめた"))
                                .foregroundStyle(DesignTokens.secondaryText)
                        }
                        .dopaFont(14, weight: .bold)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignTokens.card.opacity(0.96))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(DesignTokens.hairline, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(16)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 300)
                .background(DesignTokens.backgroundRaised)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(DesignTokens.hairline, lineWidth: 1)
                }
                .onboardingStagger(3)

                if let notificationMessage {
                    messageCard(notificationMessage)
                        .onboardingStagger(4)
                }
            }
        }
    }

    var lockScreenCheckContent: some View {
        GeometryReader { proxy in
            screenScroll {
                LockScreenCheckContent(
                    model: model,
                    phase: $lockScreenCheckPhase,
                    markerBlockBottomY: lockScreenMarkerBlockBottomY,
                    scrollContainerTopY: proxy.frame(in: .global).minY,
                    contentTopPadding: 28
                )
            }
            .overlay(alignment: .topTrailing) {
                if lockScreenCheckPhase == .waiting {
                    SideButtonEdgeMarker(
                        geometry: lockScreenSideButtonGeometry,
                        headerBottomY: progressHeaderBottomY
                    )
                    .ignoresSafeArea()
                }
            }
            .onPreferenceChange(SideButtonMarkerBottomPreferenceKey.self) {
                lockScreenMarkerBlockBottomY = $0
            }
        }
    }

    var prePaywallSummaryContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                centeredEyebrow(String(localized: "onboarding.summary.eyebrow", defaultValue: "あなた専用プラン / READY"))
                    .onboardingStagger(0)
                CharacterView(.awake, size: DesignTokens.CharacterSize.header)
                    .frame(maxWidth: .infinity)
                    .onboardingStagger(1)
                centeredTitle(String(localized: "onboarding.summary.title", defaultValue: "準備が整いました"))
                    .onboardingStagger(2)
                centeredLead(String(localized: "onboarding.summary.lead", defaultValue: "この設定で、開く前の一呼吸が増えます。"))
                    .onboardingStagger(3)

                CardContainer {
                    VStack(spacing: 0) {
                        summaryRow(
                            label: String(localized: "onboarding.summary.apps", defaultValue: "止めるアプリ"),
                            value: selectedAppsSummary
                        )
                        divider
                        summaryRow(
                            label: String(localized: "onboarding.summary.goal", defaultValue: "目標"),
                            value: goalSummaryText.isEmpty
                                ? String(localized: "onboarding.value.not_set", defaultValue: "未設定")
                                : goalSummaryText
                        )
                        divider
                        summaryRow(
                            label: String(localized: "onboarding.summary.time", defaultValue: "対象の時間"),
                            value: String(localized: "onboarding.summary.yearly_days", defaultValue: "年 約\(summaryYearlyDays)日分")
                        )
                    }
                }
                .onboardingStagger(4)

                centeredLead(String(localized: "onboarding.summary.footer", defaultValue: "今日から、開く前に選べるようになります。"))
                    .onboardingStagger(5)
            }
        }
    }

    var readyContent: some View {
        screenScroll {
            VStack(alignment: .center, spacing: 24) {
                CharacterView(.relief, size: DesignTokens.CharacterSize.header)
                    // 到達を祝うポップイン。Reduce Motion時は拡大せず出すだけにする
                    .scaleEffect(readyCheckmarkScale)
                    .opacity(isReadyCelebrated ? 1 : 0)

                VStack(spacing: 12) {
                    titleText(String(localized: "onboarding.ready.title", defaultValue: "準備完了"))
                        .multilineTextAlignment(.center)
                    bodyText(String(localized: "onboarding.ready.body", defaultValue: "今日から 開く前に選び直す"))
                        .multilineTextAlignment(.center)
                }
                .onboardingStagger(0)

                if !goalSummaryText.isEmpty {
                    CardContainer {
                        VStack(alignment: .leading, spacing: 10) {
                            SmallLabel(text: String(localized: "onboarding.ready.goal_label", defaultValue: "あなたの目標"))
                            Text(goalSummaryText)
                                .dopaFont(20, weight: .black)
                                .foregroundStyle(DesignTokens.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .onboardingStagger(1)
                }

                if let firstTarget = selectedTargets.first,
                   firstTarget.urlScheme != nil {
                    CardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Button(String(localized: "onboarding.ready.test_action", defaultValue: "最初のテストをする")) {
                                testFirstAutomation(firstTarget)
                            }
                            .buttonStyle(SecondaryButtonStyle())

                            Text(String(localized: "onboarding.ready.test_body", defaultValue: "\(firstTarget.displayName)を開いて一呼吸が出れば成功です。"))
                                .dopaFont(14, weight: .semibold, lineSpacing: 4)
                                .foregroundStyle(DesignTokens.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .onboardingStagger(2)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            celebrateReadyIfNeeded()
        }
    }

    /// 祝福前は少し縮めておき、到達時にバネで戻す
    var readyCheckmarkScale: CGFloat {
        if isReadyCelebrated {
            return 1
        }
        return reduceMotion ? 1 : 0.62
    }
}

private extension OnboardingFlow {
    func screenScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
                .padding(.horizontal, 20)
                .containerRelativeFrame(.horizontal)
                .padding(.top, 28)
                .padding(.bottom, 136)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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

    func singleSelectOptions(
        _ options: [String],
        selection: String?,
        action: @escaping (String) -> Void
    ) -> some View {
        VStack(spacing: 10) {
            ForEach(options, id: \.self) { option in
                optionButton(
                    title: usageOptionTitle(option),
                    isSelected: selection == option
                ) {
                    markSelectionFeedback()
                    action(option)
                }
            }
        }
    }

    func frequencyButtons(
        selection: String?,
        action: @escaping (String) -> Void
    ) -> some View {
        VStack(spacing: 10) {
            ForEach(frequencyOptions, id: \.self) { option in
                optionButton(title: frequencyOptionTitle(option), isSelected: selection == option) {
                    markSelectionFeedback()
                    action(option)
                }
            }
        }
    }

    func optionButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .dopaFont(18, weight: .bold)
                    .foregroundStyle(DesignTokens.primaryText)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(DesignTokens.accent)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(DesignTokens.card)
            .overlay(optionStroke(isSelected: isSelected))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(OnboardingPressStyle())
    }

    func optionStroke(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(isSelected ? DesignTokens.accent : DesignTokens.hairline, lineWidth: 1)
    }

    func usageOptionTitle(_ option: String) -> String {
        switch option {
        case "1時間未満":
            return String(localized: "onboarding.self_check.option.less_than_hour", defaultValue: "1時間未満")
        case "1〜2時間":
            return String(localized: "onboarding.self_check.option.one_to_two_hours", defaultValue: "1〜2時間")
        case "2〜4時間":
            return String(localized: "onboarding.self_check.option.two_to_four_hours", defaultValue: "2〜4時間")
        case "4〜6時間":
            return String(localized: "onboarding.self_check.option.four_to_six_hours", defaultValue: "4〜6時間")
        case "6時間以上":
            return String(localized: "onboarding.self_check.option.six_plus_hours", defaultValue: "6時間以上")
        default:
            return option
        }
    }

    func frequencyOptionTitle(_ option: String) -> String {
        switch option {
        case "全くない":
            return String(localized: "onboarding.frequency.option.never", defaultValue: "全くない")
        case "数日":
            return String(localized: "onboarding.frequency.option.some_days", defaultValue: "数日")
        case "半分以上":
            return String(localized: "onboarding.frequency.option.more_than_half", defaultValue: "半分以上")
        case "ほとんど毎日":
            return String(localized: "onboarding.frequency.option.almost_daily", defaultValue: "ほとんど毎日")
        default:
            return option
        }
    }
}

private extension OnboardingFlow {
    func modeButton(_ mode: InterventionMode) -> some View {
        Button {
            selectMode(mode)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(mode.displayTitle)
                        .dopaFont(20, weight: .black)
                        .foregroundStyle(DesignTokens.primaryText)
                    Spacer()
                    if selectedMode == mode {
                        Image(systemName: "checkmark")
                            .foregroundStyle(DesignTokens.accent)
                    }
                }
                Text(mode.detailText)
                    .dopaFont(15, weight: .semibold)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.card)
            .overlay(optionStroke(isSelected: selectedMode == mode))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(OnboardingPressStyle())
    }

    func selectMode(_ mode: InterventionMode) {
        // 画面に出ていない未実装のモードは選ばせない（`InterventionMode.selectable`）。
        guard mode.isSelectable else {
            return
        }
        guard modeAllowedForCurrentEntitlement(mode) == mode else {
            paywallPlacement = .onboardingModeGate
            return
        }
        guard selectedMode != mode else {
            return
        }
        selectedMode = mode
        markSelectionFeedback()
    }

    /// 入力中の言葉をリストへ足すボタン。キーボードの確定（`onSubmit`）と同じ動作。
    var addGoalButton: some View {
        Button {
            commitDraftGoal()
        } label: {
            Text(String(localized: "onboarding.goal.add", defaultValue: "追加"))
                .dopaFont(15, weight: .bold)
                .foregroundStyle(canAddTypedGoal ? DesignTokens.accent : DesignTokens.tertiaryText)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canAddTypedGoal)
    }

    func draftGoalRow(_ draft: OnboardingGoalDraft) -> some View {
        HStack(spacing: 8) {
            Text(draft.title)
                .dopaFont(17, weight: .bold)
                .foregroundStyle(DesignTokens.primaryText)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                removeDraftGoal(draft)
            } label: {
                Image(systemName: "xmark")
                    .dopaFont(13, weight: .black)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "onboarding.goal.remove", defaultValue: "\(draft.title)を削除"))
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(DesignTokens.card)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DesignTokens.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

}

private extension OnboardingFlow {
    func fieldContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .tint(DesignTokens.accent)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(DesignTokens.card)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DesignTokens.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    func primaryButton(
        _ title: String,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .buttonStyle(PrimaryButtonStyle(isEnabled: enabled))
            .disabled(!enabled)
    }

    func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(SecondaryButtonStyle())
    }

    func textOnlyButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .dopaFont(15, weight: .semibold)
            .foregroundStyle(DesignTokens.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
    }

    func messageCard(_ text: String) -> some View {
        CardContainer {
            Text(text)
                .dopaFont(15, weight: .semibold, lineSpacing: 5)
                .foregroundStyle(DesignTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func numberedLine(_ text: String) -> some View {
        Text(text)
            .dopaFont(17, weight: .bold)
            .foregroundStyle(DesignTokens.primaryText)
    }

    /// ショートカットの選択画面を模した2択の組。正解に枠と印を付け、もう一方を減光する。
    /// OSのUIを寸法まで写すのではなく、どちらを押すかだけが伝わればよい模式図に留める。
    func automationMockGroup(correct: String, incorrect: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text(correct)
                    .dopaFont(16, weight: .bold)
                    .foregroundStyle(DesignTokens.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text(String(localized: "onboarding.automation.mock.badge", defaultValue: "ここを選ぶ"))
                    .dopaFont(11, weight: .black)
                    .foregroundStyle(DesignTokens.background)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignTokens.accent)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.accent.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DesignTokens.accent, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(incorrect)
                .dopaFont(16, weight: .semibold)
                .foregroundStyle(DesignTokens.secondaryText.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignTokens.backgroundRaised.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DesignTokens.hairline, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    func previewChoice(_ text: String, highlighted: Bool) -> some View {
        Text(text)
            .dopaFont(16, weight: .bold)
            .foregroundStyle(highlighted ? DesignTokens.background : DesignTokens.primaryText)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(highlighted ? DesignTokens.accent : DesignTokens.backgroundRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

private extension OnboardingFlow {
    var divider: some View {
        Rectangle()
            .fill(DesignTokens.hairline)
            .frame(height: 1)
    }

    func summaryRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(label)
                .dopaFont(15, weight: .bold)
                .foregroundStyle(DesignTokens.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .dopaFont(17, weight: .black)
                .foregroundStyle(DesignTokens.primaryText)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 16)
    }

    var selectedTargets: [SNSAppCatalogItem] {
        selectedCatalogIDs.compactMap { SNSAppCatalog.app(catalogID: $0) }
    }

    var selectedAppsSummary: String {
        let targets = selectedTargets
        guard let first = targets.first else {
            return String(localized: "onboarding.value.not_set", defaultValue: "未設定")
        }
        if targets.count == 1 {
            return first.displayName
        }
        return String(localized: "onboarding.summary.additional_apps", defaultValue: "\(first.displayName) ほか\(targets.count - 1)件")
    }

    var goalSummaryText: String {
        if let first = draftGoals.first {
            return first.title
        }
        // まだ足していない入力途中の言葉も、まとめ画面では拾う
        return OnboardingGoalList.normalize(heroGoal)
    }

    var notificationGoalText: String {
        let currentGoal = model.goals.first?.lockScreenTitle ?? model.goals.first?.title
        let localGoal = goalSummaryText
        return localGoal.isEmpty
            ? (currentGoal ?? String(localized: "onboarding.notification.preview.goal_fallback", defaultValue: "目標を設定すると、ここに表示されます"))
            : localGoal
    }

    var summaryYearlyDays: Int {
        selfCheckSnapshot?.estimatedYearlyDays ?? currentEstimate.yearlyDays
    }

    var currentEstimate: LossEstimator.Estimate {
        let bucket = usageBucket ?? "2-4時間"
        return (try? LossEstimator.estimate(usageBucket: bucket)) ??
            LossEstimator.Estimate(dailyMinutes: 150, yearlyDays: 38)
    }

    /// 開く回数が半分になった場合に戻る日数。損失側と同じ推計から切り出す。
    /// 最小の推計でも0日と出さないよう1日で下げ止める。
    var recoveredYearlyDays: Int {
        max(1, currentEstimate.yearlyDays / 2)
    }
}

private extension OnboardingFlow {
    /// 選択操作の触感を1本のトークンへ集約する。
    func markSelectionFeedback() {
        selectionFeedbackToken += 1
    }

    /// 完了画面の祝福。1画面につき一度だけ走らせる。
    func celebrateReadyIfNeeded() {
        guard !isReadyCelebrated else {
            return
        }
        withAnimation(reduceMotion ? DopaMotion.control : DopaMotion.celebrate) {
            isReadyCelebrated = true
        }
    }

    func advance(from expected: OnboardingStep) {
        guard step == expected else {
            return
        }
        let completedStep = expected
        model.recordFunnelEvent(.onboardingStepCompleted, detail: completedStep.identifier)

        guard let next = nextStep(after: completedStep) else {
            settingsStore.onboardingSavedGoalID = nil
            onComplete()
            return
        }
        direction = .forward
        withAnimation(DopaMotion.transition) {
            step = next
        }
    }

    func goBack() {
        guard let previous = previousStep(before: step) else {
            return
        }
        direction = .backward
        withAnimation(DopaMotion.transition) {
            step = previous
        }
    }

    /// 前提を満たさないステップは飛ばす。いまはロック画面確認のみ（目標がなければ出せない）。
    func shouldSkip(_ candidate: OnboardingStep) -> Bool {
        candidate == .lockScreenCheck && model.goals.isEmpty
    }

    func nextStep(after current: OnboardingStep) -> OnboardingStep? {
        var candidate = current.next
        while let step = candidate, shouldSkip(step) {
            candidate = step.next
        }
        return candidate
    }

    func previousStep(before current: OnboardingStep) -> OnboardingStep? {
        var candidate = current.previous
        while let step = candidate, shouldSkip(step) {
            candidate = step.previous
        }
        return candidate
    }

    func completeLockScreenCheckAndAdvance() {
        // 実際にロック画面から戻ってきて掲出が続いていた場合だけ完了扱いにする。
        // 見ないまま進んだ人には、あとで目標を追加したときにもう一度出す。
        if lockScreenCheckPhase == .confirmed {
            model.markLockScreenCheckCompleted()
        }
        advance(from: .lockScreenCheck)
    }

    func persistSelfCheckSnapshot() -> Bool {
        guard let usageBucket, let aimlessScrollBucket, let regretBucket else {
            showSaveError()
            return false
        }

        do {
            let estimate = try LossEstimator.estimate(usageBucket: usageBucket)
            let snapshot = SelfCheckSnapshot(
                id: UUID(),
                usageBucket: usageBucket,
                aimlessScrollBucket: aimlessScrollBucket,
                regretBucket: regretBucket,
                estimatedDailyMinutes: estimate.dailyMinutes,
                estimatedYearlyDays: estimate.yearlyDays,
                createdAt: Date()
            )
            try snapshotStore.write(snapshot, to: .selfCheckSnapshot)
            selfCheckSnapshot = snapshot
            return true
        } catch {
            showSaveError()
            return false
        }
    }

    func toggleCatalogSelection(_ item: SNSAppCatalogItem) {
        appSelectionMessage = nil
        if selectedCatalogIDs.contains(item.catalogID) {
            selectedCatalogIDs.removeAll { $0 == item.catalogID }
            markSelectionFeedback()
            return
        }
        guard model.entitlementGate.canAddTargetTokens(currentCount: selectedCatalogIDs.count) else {
            paywallPlacement = .onboardingTargetAppGate
            return
        }
        selectedCatalogIDs.append(item.catalogID)
        markSelectionFeedback()
    }

    func persistSelectedAppsAndAdvance() {
        guard !selectedCatalogIDs.isEmpty else {
            appSelectionMessage = String(localized: "onboarding.apps.empty_selection_message", defaultValue: "まずは1つだけ選びましょう。\n\n一番無意識に開いてしまうSNSから始めるのがおすすめです。")
            return
        }
        do {
            try model.setTargetCatalogIDs(selectedCatalogIDs)
            appSelectionMessage = nil
            advance(from: .chooseApps)
        } catch CoreError.validation(let message) {
            appSelectionMessage = message
        } catch {
            showSaveError()
        }
    }

    /// 入力欄の文字数。上限の表示と判定で同じ値を使う。
    var typedGoalLength: Int {
        heroGoal.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    var isTypedGoalOverLimit: Bool {
        typedGoalLength > OnboardingGoalList.titleLimit
    }

    /// 入力欄の言葉をそのまま足せるか。上限超過は足さずに直してもらう。
    var canAddTypedGoal: Bool {
        (1...OnboardingGoalList.titleLimit).contains(typedGoalLength)
    }

    /// 目標画面から先へ進める状態か。リストが空でも、入力途中の言葉があれば進める。
    var canLeaveGoalSetup: Bool {
        !isTypedGoalOverLimit && (!draftGoals.isEmpty || typedGoalLength > 0)
    }

    /// 入力欄の言葉をリストへ移す。移せない状態（上限）ならfalseを返し、呼び出し側を止める。
    @discardableResult
    func commitDraftGoal() -> Bool {
        let title = OnboardingGoalList.normalize(heroGoal)
        guard !title.isEmpty else {
            return true
        }
        guard !isTypedGoalOverLimit else {
            return false
        }
        // すでに同じ言葉が入っている場合は足さず、入力欄だけ空ける
        guard !OnboardingGoalList.contains(title, in: draftGoals) else {
            heroGoal = ""
            return true
        }
        guard addDraftGoal(title) else {
            return false
        }
        heroGoal = ""
        return true
    }

    /// リストへ1件足す。同じ言葉がすでにあれば足さずにtrueを返す。
    /// 件数の上限は撤廃済み（2026-08-17オーナー決定）のため、ここでペイウォールは出さない。
    @discardableResult
    func addDraftGoal(_ rawTitle: String) -> Bool {
        guard !OnboardingGoalList.contains(rawTitle, in: draftGoals) else {
            return true
        }
        withAnimation(DopaMotion.control) {
            draftGoals = OnboardingGoalList.appending(rawTitle, to: draftGoals)
        }
        markSelectionFeedback()
        return true
    }

    func removeDraftGoal(_ draft: OnboardingGoalDraft) {
        withAnimation(DopaMotion.control) {
            draftGoals.removeAll { $0.id == draft.id }
        }
        markSelectionFeedback()
    }

    func saveGoalAndAdvance(skipped: Bool) {
        if skipped {
            advance(from: .goalSetup)
            return
        }
        // 入力途中の言葉は次へで拾う。書いたのに消えたと感じさせない
        guard commitDraftGoal() else {
            return
        }
        guard !draftGoals.isEmpty else {
            advance(from: .goalSetup)
            return
        }
        guard persistDraftGoals() else {
            return
        }
        advance(from: .goalSetup)
    }

    /// リストの内容を保存済みデータへ反映する。
    ///
    /// 削除・更新・追加を積み上げず、最終形を作って1回で書き込む。
    /// 途中で失敗して既存の目標だけが消えた状態を残さないため。
    func persistDraftGoals() -> Bool {
        let plan = OnboardingGoalList.syncPlan(
            drafts: draftGoals,
            persisted: model.goals,
            baseline: goalBaseline
        )
        guard !plan.isEmpty else {
            // 触っていないなら書き込まない
            return true
        }

        // カテゴリは新規ぶんにだけ使う。既存の目標のカテゴリは`merged`が保つ
        let merged = OnboardingGoalList.merged(
            plan: plan,
            into: model.goals,
            category: goalCategory,
            now: Date()
        )
        guard model.replaceGoals(merged) else {
            showGoalSaveError()
            return false
        }

        // 保存済みを正としてリストと基準を組み直す。戻って入り直しても二重に足さない
        draftGoals = OnboardingGoalList.restore(from: model.goals)
        goalBaseline = OnboardingGoalBaseline(goals: model.goals)
        return true
    }

    func showGoalSaveError() {
        flowAlert = OnboardingAlert(
            title: String(localized: "onboarding.error.save.title", defaultValue: "保存できませんでした"),
            message: model.alertMessage ?? String(localized: "onboarding.error.save.message", defaultValue: "データを保存できませんでした")
        )
    }

}

private extension OnboardingFlow {
    func confirmModeIfNeeded() {
        let mode = modeAllowedForCurrentEntitlement(selectedMode)
        if mode != selectedMode {
            selectedMode = mode
            persistModeAndAdvance(mode)
        } else if mode == .deepFocus {
            showDeepFocusConfirmation = true
        } else {
            persistModeAndAdvance(mode)
        }
    }

    func persistModeAndAdvance(_ mode: InterventionMode) {
        let mode = modeAllowedForCurrentEntitlement(mode).persistable
        selectedMode = mode

        // 保存するだけではルールへ届かない。対象アプリはこの前の画面で確定しているため、
        // ここでルールを作って選んだ強さを実際に反映する（ディープフォーカスなら完全ブロックも同期される）。
        // ルールへ届かなかったときは選択も進めず、その場に留めてもう一度試させる。
        // 「選んだのに効いていない」まま先へ進ませない。
        do {
            try model.applyInterventionMode(mode)
        } catch {
            showModeSaveError()
            return
        }

        settingsStore.pendingInterventionMode = mode.rawValue
        advance(from: .chooseMode)
    }

    func showModeSaveError() {
        flowAlert = OnboardingAlert(
            title: String(localized: "onboarding.error.save.title", defaultValue: "保存できませんでした"),
            message: String(
                localized: "onboarding.mode.save_error.message",
                defaultValue: "止める強さを保存できませんでした。もう一度お試しください。"
            )
        )
    }

    /// 夜だけ強化もディープフォーカスと同じ完全ブロックを使うため、Pro専用の扱いは共通にする。
    /// ここを `deepFocus` の直接比較のままにすると、夜だけ強化がFreeへ素通りする。
    func modeAllowedForCurrentEntitlement(_ mode: InterventionMode) -> InterventionMode {
        if mode.usesShield, !model.entitlementGate.strictModeAllowed {
            return .standard
        }
        return mode
    }

    func openShortcutsAndAdvance() {
        if let url = URL(string: "shortcuts://") {
            UIApplication.shared.open(url)
        }
        advance(from: .permission)
    }

    func testFirstAutomation(_ target: SNSAppCatalogItem) {
        guard let scheme = target.urlScheme,
              let url = URL(string: scheme) else {
            return
        }
        UIApplication.shared.open(url)
    }

    @MainActor
    func requestNotifications() async {
        guard !isRequestingNotifications else {
            return
        }
        isRequestingNotifications = true
        defer { isRequestingNotifications = false }

        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await model.rescheduleNotificationsAfterAuthorization()
                advance(from: .notificationGuide)
            } else {
                showNotificationFallback()
            }
        } catch {
            showNotificationFallback()
        }
    }
}

private extension OnboardingFlow {
    func showNotificationFallback() {
        notificationMessage = String(localized: "onboarding.notification.fallback", defaultValue: "通知はあとで設定できます。")
    }

    func showSaveError() {
        flowAlert = OnboardingAlert(
            title: String(localized: "onboarding.error.save.title", defaultValue: "保存できませんでした"),
            message: String(localized: "onboarding.error.save.message", defaultValue: "データを保存できませんでした")
        )
    }

    func dailyTimeText(minutes: Int) -> String {
        if minutes < 60 {
            return String(localized: "onboarding.result.duration.minutes", defaultValue: "\(minutes)分")
        }
        let hours = Double(minutes) / 60.0
        return hours.rounded() == hours
            ? String(localized: "onboarding.result.duration.hours", defaultValue: "\(Int(hours))時間")
            : String(localized: "onboarding.result.duration.decimal_hours", defaultValue: "\(hours)時間")
    }

    /// 3年換算の月数。LossEstimator側で切り捨て済みの値を1桁小数で固定表示する。
    func threeYearMonthsText(yearlyDays: Int) -> String {
        String(format: "%.1f", LossEstimator.threeYearMonths(fromYearlyDays: yearlyDays))
    }

    /// 人生換算の年数。LossEstimator側で切り捨て済みの値を文字列にしてから差し込み、
    /// ローカライズ側の書式で丸め直されないようにする（%@で受ける）。
    func lifetimeYearsText(yearlyDays: Int) -> String {
        String(format: "%.1f", LossEstimator.lifetimeYears(fromYearlyDays: yearlyDays))
    }
}
