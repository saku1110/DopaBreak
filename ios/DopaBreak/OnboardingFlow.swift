import DopaBreakCore
import FamilyControls
import Foundation
import SwiftUI
import UIKit
import UserNotifications

enum OnboardingAutomationSetupState: Equatable {
    case initial
    case awaitingVerification
    case verified
}

enum OnboardingAutomationSetupPolicy {
    static func state(
        hasOpenedShortcuts: Bool,
        selectedCatalogIDs: [String],
        verifiedCatalogIDs: Set<String>
    ) -> OnboardingAutomationSetupState {
        if !Set(selectedCatalogIDs).isDisjoint(with: verifiedCatalogIDs) {
            return .verified
        }
        return hasOpenedShortcuts ? .awaitingVerification : .initial
    }
}

/// 完了画面で、ロック画面の許可の案内を出すか。
/// iOSは最初にライブアクティビティを出すとき「許可／許可しない」を聞く。オンボーディングには
/// ロック画面を確かめる手順がないため、終える直前に答え方を伝えておく（2026-09-26 オーナー承認）。
/// 端末ですでに許可されていない人には出さない（ホームのカードが設定へ案内する）。
enum OnboardingReadyLockScreenNotePolicy {
    static func showsPermissionNote(
        hasGoals: Bool,
        liveActivityEnabled: Bool,
        areLiveActivitiesAllowed: Bool
    ) -> Bool {
        hasGoals && liveActivityEnabled && areLiveActivitiesAllowed
    }
}

/// オンボーディングで一呼吸を体験するときに見せるアプリ。体験はSNSで見せる（2026-09-26 オーナー指示）。
/// 選んだ中にSNSがあれば最初のSNS。Safariだけを選んだ人はSafariのまま（体験の「開かなかった」は
/// 本物の記録になるため、選んでいない見本のアプリにするとルールと記録がずれる）。
/// 何も選んでいなければ従来どおり見本のInstagram。
enum OnboardingExperienceAppPolicy {
    static let nonSNSCatalogIDs: Set<String> = ["safari"]

    static func app(from selectedTargets: [SNSAppCatalogItem]) -> SNSAppCatalogItem? {
        selectedTargets.first { !nonSNSCatalogIDs.contains($0.catalogID) }
            ?? selectedTargets.first
            ?? SNSAppCatalog.app(catalogID: "instagram")
    }
}

enum OnboardingLockThemeSelectionHandler {
    static func select(
        for theme: LockTheme,
        isThemeAllowed: (LockTheme) -> Bool,
        onLocked: (LockTheme) -> Void,
        onSelect: (LockTheme) -> Void
    ) {
        if isThemeAllowed(theme) {
            onSelect(theme)
        } else {
            onLocked(theme)
        }
    }
}

enum OnboardingStep: Int, CaseIterable {
    // Keep stored v2 raw values stable; visual order comes from allCases.
    // 並びが画面順。損失を見せてから目標を聞く（オーナー決定 2026-09-21）。
    // rawValueは旧バージョンからの復帰用の識別子なので入れ替えない。
    case selfCheck = 1
    case scrollRegret = 3
    case lossRecovery = 4
    case goalSetup = 7
    case chooseApps = 6
    case chooseMode = 8
    // アプリ内だけで完結する一呼吸の体験。価値を先に見せてから課金画面へ（2026-09-24 オーナー承認）
    case experience = 19
    case notificationGuide = 12
    case prePaywallSummary = 15
    // ショートカット設定は課金画面の後ろ。外のアプリへ移って戻らない人も課金画面は見終わっている。
    // 旧版の11（課金画面より前の位置）と区別するため新しい値にした。
    case permission = 20
    case blockSetup = 18 // 16 was ready before block setup was introduced.
    case ready = 17

    var analyticsIdentifier: String { identifier }

    /// 保存された進捗から再開する画面。新規は先頭（1日のSNS時間）から始める。
    /// 目標は中心機能なので、目標が無いまま目標画面より後へは進めない。
    /// 目標画面より前の質問・人生換算は、目標が無くても保存位置から再開する（2026-09-24 修正）。
    static func restored(from settings: SettingsStore, hasGoals: Bool = true) -> Self {
        guard !settings.onboardingCompleted, let raw = settings.onboardingStepRaw else { return .selfCheck }
        let step: Self
        switch raw {
        case 0: step = .selfCheck
        case 2: step = .scrollRegret
        case 5: step = .lossRecovery
        case 9, 10, 11: step = .experience
        case 13, 14: step = .prePaywallSummary
        case 16: step = .ready
        default: step = Self(rawValue: raw) ?? .selfCheck
        }
        if !hasGoals, step.index > Self.goalSetup.index {
            return .goalSetup
        }
        return step
    }

    private var index: Int { Self.allCases.firstIndex(of: self)! }
    var position: Int { index + 1 }
    var progress: Double { Double(position) / Double(Self.allCases.count) }
    var previous: Self? { index > 0 ? Self.allCases[index - 1] : nil }
    var next: Self? { index + 1 < Self.allCases.count ? Self.allCases[index + 1] : nil }

    func shouldSkip(isPro: Bool, hasConfirmedEntitlement: Bool, mode: InterventionMode) -> Bool {
        self == .blockSetup && ((!isPro && hasConfirmedEntitlement) || !mode.usesShield)
    }

    var identifier: String {
        switch self {
        case .goalSetup: return "goal_setup"
        case .chooseApps: return "choose_apps"
        case .selfCheck: return "self_check"
        case .scrollRegret: return "scroll_regret"
        case .lossRecovery: return "loss_recovery"
        case .chooseMode: return "choose_mode"
        case .experience: return "experience"
        case .permission: return "permission"
        case .notificationGuide: return "notification_guide"
        case .prePaywallSummary: return "pre_paywall_summary"
        case .blockSetup: return "block_setup"
        case .ready: return "ready"
        }
    }
}

@MainActor
@Observable
final class OnboardingProgress {
    private let settings: SettingsStore
    var readyModeNotice: InterventionMode?
    var step: OnboardingStep {
        didSet {
            settings.onboardingStepRaw = step.rawValue
            if step != .ready { readyModeNotice = nil }
        }
    }

    init(settings: SettingsStore, initialStep: OnboardingStep? = nil,
         isPro: Bool = false, hasConfirmedEntitlement: Bool = false,
         hasGoals: Bool = true) {
        self.settings = settings
        var candidate = initialStep ?? OnboardingStep.restored(from: settings, hasGoals: hasGoals)
        let mode = Self.preferredMode(from: settings)
        while candidate.shouldSkip(isPro: isPro, hasConfirmedEntitlement: hasConfirmedEntitlement, mode: mode),
              let next = candidate.next {
            candidate = next
        }
        self.step = candidate
    }

    static func preferredMode(from settings: SettingsStore) -> InterventionMode {
        if !settings.hasBlockConfiguration { settings.migrateBlockConfigurationIfNeeded(rules: []) }
        return settings.blockTriggers.isEmpty ? .standard : .deepFocus
    }

    /// 止め方の画面で最初に選ばれている選択。まだ止め方を確定していない人には
    /// おすすめのPro（一呼吸＋完全ブロック）を選んだ状態で見せる（2026-09-26 オーナー指示）。
    /// 確定済みの人には、戻ってから再起動した場合も含めて保存済みの選択を出す。
    /// 保存値の「空＝無料」は未選択と区別できないため、確定の記録を見る。記録がない旧版からの
    /// 途中再開は、止め方の画面より後から始まるかで判断する。
    static func initialModeSelection(from settings: SettingsStore, startingAt step: OnboardingStep) -> InterventionMode {
        let steps = OnboardingStep.allCases
        let startsAfterChoice = steps.firstIndex(of: step).flatMap { current in
            steps.firstIndex(of: .chooseMode).map { current > $0 }
        } ?? false
        guard settings.onboardingBlockChoiceSaved || startsAfterChoice else {
            return .deepFocus
        }
        return preferredMode(from: settings)
    }

    func saveModePreference(_ mode: InterventionMode) {
        settings.selectBlockPreference(mode != .standard)
        settings.onboardingBlockChoiceSaved = true
    }

    /// Remember the explanation separately from the preferred mode, including across relaunches.
    func summaryPaywallDismissed(isPro: Bool, mode: InterventionMode) {
        guard step == .prePaywallSummary else { return }
        settings.onboardingPendingModeNotice = !isPro && mode.usesShield && !settings.onboardingModeNoticeShown
            ? mode.rawValue : nil
    }

    func presentReadyModeNotice(isPro: Bool) {
        guard step == .ready else { return }
        if isPro {
            readyModeNotice = nil
            settings.onboardingPendingModeNotice = nil
            return
        }
        guard !settings.onboardingModeNoticeShown,
              let raw = settings.onboardingPendingModeNotice,
              let mode = InterventionMode(rawValue: raw), mode.usesShield else { return }
        readyModeNotice = mode
        settings.onboardingModeNoticeShown = true
        settings.onboardingPendingModeNotice = nil
    }

    func deferBlockSetup() {
        guard step == .blockSetup else { return }
        step = .ready
    }

    func completeExperience() {
        guard step == .experience || step == .permission else { return }
        settings.onboardingExperienceCompleted = true
        // アプリ内の体験なら次へ。ショートカット設定中に自動化から出た体験なら、その場で確認を続ける
        if step == .experience { step = .notificationGuide }
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

struct OnboardingFlow: View {
    let model: AppModel
    let settingsStore: SettingsStore
    let onComplete: () -> Void

    private let snapshotStore = JSONSnapshotStore(containerProvider: DefaultContainerProvider())
    private let usageOptions = ["1時間未満", "1〜2時間", "2〜4時間", "4〜6時間", "6時間以上"]
    private let frequencyOptions = ["全くない", "数日", "半分以上", "ほとんど毎日"]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    @State private var experienceTarget: SNSAppCatalogItem?
    @State private var experienceCompleted = false
    @State private var progress: OnboardingProgress
    private var step: OnboardingStep {
        get { progress.step }
        nonmutating set { progress.step = newValue }
    }
    @State private var direction: SlideDirection = .forward
    @State private var usageBucket: String?
    @State private var aimlessScrollBucket: String?
    @State private var regretBucket: String?
    @State private var selfCheckSnapshot: SelfCheckSnapshot?
    @State private var selectedCatalogIDs: [String] = []
    @State private var appSelectionMessage: String?
    @State private var heroGoal = ""
    @FocusState private var isGoalFieldFocused: Bool
    @State private var goalFieldGeneration = 0
    @State private var highlightedGoalID: UUID?
    /// この画面で編集中の目標一覧。保存済みの目標も含め、ここが表示と保存の正本になる。
    @State private var draftGoals: [OnboardingGoalDraft] = []
    /// 差分の基準。入場時と保存直後の保存済み内容を持つ。
    /// これが無いと、画面を開いている間に別経路で増えた目標まで消してしまう。
    @State private var goalBaseline = OnboardingGoalBaseline()
    @State private var goalCategory: GoalCategory = .other
    @State private var selectedMode: InterventionMode = .standard
    @State private var showBlockCategoryWarning = false
    @State private var notificationMessage: String?
    @State private var isRequestingNotifications = false
    @State private var progressHeaderBottomY: CGFloat = 0
    @State private var paywallPlacement: PaywallPlacement?
    @State private var isGoalThemePickerPresented = false
    /// ピッカーを閉じ終えてからペイウォールを出すための待ち札。
    /// 閉じる途中で全画面表示を重ねると、SwiftUIが表示を捨てることがある。
    @State private var opensThemePaywallAfterPicker = false
    @State private var pendingTargetAfterPurchase: String?
    @State private var hasOpenedShortcuts = false
    @State private var showsAutomationStepsAgain = false
    @State private var confirmedAutomationCatalogIDs: Set<String> = []
    @State private var isAutomationGuidePresented = false
    @StateObject private var automationTutorialPlayback = AutomationTutorialPlaybackController()
    @State private var blockedAppSelection = FamilyActivitySelection()
    @State private var savedBlockedAppSelection = FamilyActivitySelection()
    @State private var isBlockedAppPickerPresented = false
    @State private var isRequestingScreenTimeAuthorization = false
    @State private var blockSetupSaveMessage: String?
    @State private var didSaveBlockedAppSelection = false
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

    /// - Parameter initialStep: 検証用の開始ステップ。未指定なら保存済みの進捗から再開する。
    ///   任意ステップの見た目を実機で確認するキャプチャハーネス用に開けている。
    init(
        model: AppModel,
        settingsStore: SettingsStore,
        initialStep: OnboardingStep? = nil,
        onComplete: @escaping () -> Void
    ) {
        self.model = model
        self.settingsStore = settingsStore
        self.onComplete = onComplete
        let initialProgress = OnboardingProgress(settings: settingsStore, initialStep: initialStep,
            isPro: model.storeService.isPro,
            hasConfirmedEntitlement: model.storeService.hasConfirmedEntitlement,
            hasGoals: !model.goals.isEmpty)
        _progress = State(initialValue: initialProgress)
        _selectedMode = State(initialValue: OnboardingProgress.initialModeSelection(
            from: settingsStore,
            startingAt: initialProgress.step
        ))
        _selectedCatalogIDs = State(initialValue: (try? model.targetStore.selectedCatalogIDs()) ?? [])
        let savedCheck = try? snapshotStore.read(SelfCheckSnapshot.self, from: .selfCheckSnapshot)
        _selfCheckSnapshot = State(initialValue: savedCheck)
        _usageBucket = State(initialValue: settingsStore.onboardingQuizAnswers["usage"] ?? savedCheck?.usageBucket)
        _aimlessScrollBucket = State(initialValue: settingsStore.onboardingQuizAnswers["aimless"] ?? savedCheck?.aimlessScrollBucket)
        _regretBucket = State(initialValue: settingsStore.onboardingQuizAnswers["regret"] ?? savedCheck?.regretBucket)

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
        // 入力欄以外をタップしたらキーボードを閉じる。
        // 背面に置くので、ボタンやリンクのタップは従来どおり先に処理される。
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { isGoalFieldFocused = false }
        )
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
        .sheet(isPresented: $isGoalThemePickerPresented, onDismiss: {
            guard opensThemePaywallAfterPicker else { return }
            opensThemePaywallAfterPicker = false
            paywallPlacement = .onboardingLockThemeGate
        }) {
            NavigationStack {
                ScrollView {
                    LockThemePickerView(
                        selectedTheme: model.displayedLockThemeSelection,
                        goalTitles: goalPreviewTitles,
                        cancelledCount: model.todayCancelledCount,
                        attemptCount: model.todayAttemptCount,
                        isThemeAllowed: model.entitlementGate.lockThemeAllowed,
                        onSelect: selectOnboardingLockTheme
                    )
                    .padding(20)
                }
                .background(DesignTokens.background)
                .navigationTitle(
                    String(
                        localized: "onboarding.goal.theme_picker.title",
                        defaultValue: "ロック画面のデザイン"
                    )
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "onboarding.action.close", defaultValue: "閉じる")) {
                            isGoalThemePickerPresented = false
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $paywallPlacement, onDismiss: {
            model.applyPendingProThemeSelectionIfNeeded(
                hasProEntitlement: model.storeService.isPro
            )
            if model.storeService.isPro {
                applyPendingOnboardingPurchaseIfNeeded()
            } else {
                clearPendingOnboardingPurchase()
            }
            if step == .prePaywallSummary {
                progress.summaryPaywallDismissed(isPro: model.storeService.isPro, mode: selectedMode)
                advance(from: .prePaywallSummary)
            }
        }) { placement in
            PaywallView(
                storeService: model.storeService,
                placement: placement,
                settingsStore: settingsStore,
                model: model
            )
        }
        .fullScreenCover(item: $experienceTarget, onDismiss: {
            if experienceCompleted {
                experienceCompleted = false
                model.recordFunnelEvent(.onboardingStepCompleted, detail: step.identifier)
                withAnimation(DopaMotion.transition) { progress.completeExperience() }
            }
        }) { target in
            InterventionFlowView(target: .catalog(target), model: model, settingsStore: settingsStore,
                                 isOnboardingExperience: true, onExperienceCompleted: {
                settingsStore.onboardingExperienceCompleted = true
                experienceCompleted = true
            }) {
                model.finishOnboardingExperience()
                experienceTarget = nil
            }
            .interactiveDismissDisabled()
        }
        .onChange(of: step, initial: true) { _, value in
            if !settingsStore.onboardingCompleted { settingsStore.onboardingStepRaw = value.rawValue }
            AppleAdsMeasurement.shared.recordOnboardingStep(value.analyticsIdentifier)
            presentExperienceIfNeeded()
        }
        .onChange(of: model.pendingOnboardingExperienceCatalogID) { _, _ in
            presentExperienceIfNeeded()
        }
        .onChange(of: model.storeService.isPro) { _, isPro in
            model.applyPendingProThemeSelectionIfNeeded(hasProEntitlement: isPro)
            if isPro {
                applyPendingOnboardingPurchaseIfNeeded()
            }
        }
        .onChange(of: model.storeService.entitlementRevision) { _, _ in
            model.applyPendingProThemeSelectionIfNeeded(
                hasProEntitlement: model.storeService.isPro
            )
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, step == .blockSetup {
                model.refreshScreenTimeAuthorizationStatus()
            }
            guard step == .permission else { return }
            if phase == .active {
                consumeAutomationVerificationOnActivation()
                automationTutorialPlayback.applicationDidBecomeActive()
            } else if phase == .background {
                automationTutorialPlayback.applicationDidEnterBackground()
            }
        }
        .onChange(of: isBlockedAppPickerPresented) { _, isPresented in
            guard !isPresented, step == .blockSetup, selectedMode.usesShield else { return }
            let newlyAddedCategoryTokens = blockedAppSelection.categoryTokens
                .subtracting(savedBlockedAppSelection.categoryTokens)
            if newlyAddedCategoryTokens.isEmpty {
                saveBlockedAppSelection()
            } else {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    guard !Task.isCancelled else { return }
                    showBlockCategoryWarning = true
                }
            }
        }
        .familyActivityPicker(
            footerText: String(
                localized: "block_picker.footer",
                defaultValue: "DopaBreak自身は選ばないでください。指定した時間帯にDopaBreakを開けなくなります。カテゴリを選ぶと、その分類のアプリがすべてブロックされます。"),
            isPresented: $isBlockedAppPickerPresented,
            selection: $blockedAppSelection
        )
        .sheet(isPresented: $isAutomationGuidePresented, onDismiss: {
            refreshAutomationVerificationState()
        }) {
            AutomationGuideView(model: model, settingsStore: settingsStore)
        }
        .alert(
            String(
                localized: "block_picker.category_warning.title",
                defaultValue: "カテゴリはまとめて止まります"
            ),
            isPresented: $showBlockCategoryWarning
        ) {
            Button(
                String(
                    localized: "block_picker.category_warning.save",
                    defaultValue: "このまま保存"
                )
            ) {
                saveBlockedAppSelection()
            }
            Button(
                String(
                    localized: "block_picker.category_warning.reselect",
                    defaultValue: "選び直す"
                ),
                role: .cancel
            ) {
                isBlockedAppPickerPresented = true
            }
        } message: {
            Text(
                String(
                    localized: "block_picker.category_warning.message",
                    defaultValue: "選んだ分類に入っているアプリがすべて止まります。DopaBreak自身が同じ分類にあると、その時間帯は開けなくなります。"
                )
            )
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
        case .selfCheck:
            selfCheckContent
        case .scrollRegret:
            regretQuizContent
        case .lossRecovery:
            quizResultContent
        case .chooseApps:
            chooseAppsContent
        case .goalSetup:
            goalSetupContent
        case .chooseMode:
            chooseModeContent
        case .experience:
            experienceContent
        case .permission:
            automationGuideContent
        case .notificationGuide:
            notificationGuideContent
        case .prePaywallSummary:
            prePaywallSummaryContent
        case .blockSetup:
            blockSetupContent
        case .ready:
            readyContent
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        switch step {
        case .selfCheck, .scrollRegret:
            EmptyView()
        default:
            actionArea
        }
    }

    private var actionArea: some View {
        VStack(spacing: 10) {
            if step == .ready, showsReadyLockScreenNote {
                readyLockScreenNote
            }
            primaryAction
            secondaryAction
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(DesignTokens.background)
    }

    private var showsReadyLockScreenNote: Bool {
        OnboardingReadyLockScreenNotePolicy.showsPermissionNote(
            hasGoals: !summaryGoals.titles.isEmpty,
            liveActivityEnabled: settingsStore.liveActivityEnabled,
            areLiveActivitiesAllowed: model.areLiveActivitiesAllowed
        )
    }

    /// ロック画面確認と同じ文言。スクロール位置や目標の件数に関係なく読めるよう、
    /// 画面の中ではなく完了ボタンのすぐ上に置く（6.1インチで目標2件以上だと目標カードの末尾は隠れる）。
    private var readyLockScreenNote: some View {
        Text(
            String(
                localized: "lock_check.permission_note",
                defaultValue: "初回はライブアクティビティの許可を求められます。「許可」を選ぶと、目標がロック画面に表示されます。"
            )
        )
        .dopaFont(13, weight: .medium, lineSpacing: 3)
        .foregroundStyle(DesignTokens.secondaryText)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("onboarding-ready-lock-permission-note")
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch step {
        case .lossRecovery:
            primaryButton(String(localized: "onboarding.result.action", defaultValue: "この時間を取り戻す")) { advance(from: .lossRecovery) }
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
                saveGoalAndAdvance()
            }
        case .chooseMode:
            primaryButton(String(localized: "onboarding.mode.action", defaultValue: "この設定で進む")) { confirmModeIfNeeded() }
        case .experience:
            primaryButton(String(localized: "onboarding.experience.action", defaultValue: "体験する")) {
                startInAppExperience()
            }
        case .permission:
            switch automationSetupState {
            case .initial:
                VStack(spacing: 10) {
                    primaryButton(String(localized: "onboarding.automation.action", defaultValue: "ショートカットを開く")) { openShortcuts() }
                    DopaDisplayText(text: String(localized: "onboarding.automation.action_note", defaultValue: "選んだアプリで一呼吸が始まれば設定完了"), size: 13, weight: .medium)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .multilineTextAlignment(.center)
                }
            case .awaitingVerification:
                primaryButton(
                    String(
                        localized: "onboarding.automation.test.action",
                        defaultValue: "\(firstAutomationTestTarget?.displayName ?? "対象アプリ")を開いて試す"
                    ),
                    enabled: firstAutomationTestTarget != nil
                ) {
                    if let target = firstAutomationTestTarget {
                        testFirstAutomation(target)
                    }
                }
            case .verified:
                primaryButton(String(localized: "onboarding.action.next_short", defaultValue: "次へ")) {
                    advance(from: .permission)
                }
            }
        case .notificationGuide:
            primaryButton(String(localized: "onboarding.notification.action", defaultValue: "通知をオンにする"), enabled: !isRequestingNotifications) {
                Task { await requestNotifications() }
            }
        case .prePaywallSummary:
            primaryButton(OnboardingSummaryPresentation.actionTitle) {
                if OnboardingSummaryPresentation.needsPlanReview(mode: selectedMode, isPro: model.storeService.isPro,
                    hasPendingProTheme: model.pendingProThemeSelection != nil) {
                    paywallPlacement = .onboardingPrepaywallSummary
                } else {
                    advance(from: .prePaywallSummary)
                }
            }
        case .blockSetup:
            primaryButton(
                String(localized: "onboarding.action.next_short", defaultValue: "次へ"),
                enabled: canCompleteBlockSetup
            ) {
                advance(from: .blockSetup)
            }
        case .ready:
            if automationSetupState == .verified {
                primaryButton(String(localized: "onboarding.ready.action", defaultValue: "DopaBreakをはじめる")) { advance(from: .ready) }
            } else {
                primaryButton(String(localized: "onboarding.ready.action.setup", defaultValue: "設定する")) {
                    isAutomationGuidePresented = true
                }
            }
        case .selfCheck, .scrollRegret:
            EmptyView()
        }
    }

    @ViewBuilder
    private var secondaryAction: some View {
        switch step {
        case .experience:
            secondaryButton(String(localized: "onboarding.action.later", defaultValue: "あとで")) { advance(from: .experience) }
        case .permission:
            if automationSetupState == .awaitingVerification {
                VStack(spacing: 8) {
                    secondaryButton(String(localized: "onboarding.automation.steps_again", defaultValue: "手順をもう一度見る")) {
                        showsAutomationStepsAgain = true
                    }
                    textOnlyButton(String(localized: "onboarding.action.later", defaultValue: "あとで")) {
                        advance(from: .permission)
                    }
                }
            } else if automationSetupState == .initial {
                secondaryButton(String(localized: "onboarding.action.later", defaultValue: "あとで")) { advance(from: .permission) }
            }
        case .notificationGuide:
            secondaryButton(String(localized: "onboarding.action.later", defaultValue: "あとで")) { advance(from: .notificationGuide) }
        case .blockSetup:
            VStack(spacing: 8) {
                DopaDisplayText(text: String(localized: "onboarding.block_setup.later_note", defaultValue: "設定まではブロックされません​ ホームから設定できます"), size: 13, weight: .medium)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .multilineTextAlignment(.center)
                secondaryButton(String(localized: "onboarding.block_setup.action.later", defaultValue: "あとで設定する")) {
                    leaveBlockSetupKeepingMode()
                }
            }
        case .ready:
            if automationSetupState != .verified {
                secondaryButton(String(localized: "onboarding.ready.action.home", defaultValue: "ホームへ")) {
                    advance(from: .ready)
                }
            }
        default:
            EmptyView()
        }
    }
}

private extension OnboardingFlow {


    var selfCheckContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                centeredLead(String(localized: "onboarding.welcome.tagline", defaultValue: "SNSを開く直前に ひと呼吸"))
                    .onboardingStagger(0)
                centeredTitle(String(localized: "onboarding.self_check.title", defaultValue: "1日のSNS時間は？"))
                    .onboardingStagger(1)
                centeredLead(String(localized: "onboarding.self_check.hint", defaultValue: "ざっくりでOKです"))
                    .onboardingStagger(2)
                singleSelectOptions(usageOptions, selection: usageBucket) { option in
                    usageBucket = option
                    settingsStore.onboardingQuizAnswers["usage"] = option
                    advance(from: .selfCheck)
                }
                    .onboardingStagger(3)

                centeredLead(String(localized: "onboarding.self_check.privacy_note", defaultValue: "回答の保存は端末内だけ"))
                    .onboardingStagger(4)
            }
        }
    }

    var regretQuizContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                // 見出し=判定できる行動文（行動＋結果を1文）、問い=選択肢（日数）と同じ形。
                // 3段の断片積みは廃止（オーナー指摘 2026-09-21）。
                centeredTitle(String(localized: "onboarding.regret.title", defaultValue: "目的もなく​スクロールして後悔"))
                    .onboardingStagger(0)
                centeredLead(String(localized: "onboarding.regret.lead", defaultValue: "この2週間で何日ありましたか？"))
                    .onboardingStagger(1)
                frequencyButtons(selection: regretBucket) { option in
                    aimlessScrollBucket = option
                    settingsStore.onboardingQuizAnswers["aimless"] = option
                    regretBucket = option
                    settingsStore.onboardingQuizAnswers["regret"] = option
                    if persistSelfCheckSnapshot() {
                        advance(from: .scrollRegret)
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
            defaultValue: "50年で人生の約\(LossEstimatePresentation.lifetimeYearsText(yearlyDays: estimate.yearlyDays))年"
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
                    centeredEyebrow(String(localized: "onboarding.result.eyebrow", defaultValue: "推計結果"))
                        .onboardingStagger(0)
                    centeredLead(String(localized: "onboarding.result.lead", defaultValue: "回答から計算すると"))
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

                        centeredLead(String(localized: "onboarding.result.daily_body", defaultValue: "をSNSに使っている計算です"))

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
                            defaultValue: "※1日約\(LossEstimatePresentation.dailyTimeText(minutes: estimate.dailyMinutes))の想定にもとづく推計"
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
                recoveryContent
                    .padding(.top, 32)
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
        return Group {
            VStack(alignment: .center, spacing: 24) {
                centeredEyebrow(String(localized: "onboarding.recovery.eyebrow", defaultValue: "取り戻せる時間"))
                    .onboardingStagger(0)
                centeredLead(String(localized: "onboarding.recovery.lead", defaultValue: "開く回数を半分にすると"))
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

                    centeredLead(String(localized: "onboarding.recovery.daily_body", defaultValue: "を自分のために使える計算です"))
                }
                .onboardingStagger(2)

                centeredLead(
                    String(
                        localized: "onboarding.recovery.disclaimer",
                        defaultValue: "※回答をもとに開く回数が​半分になった場合の推計"
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
                centeredTitle(String(localized: "onboarding.apps.title", defaultValue: "止めるアプリを選ぶ"))
                    .onboardingStagger(0)
                centeredLead(String(localized: "onboarding.apps.lead", defaultValue: "選んだアプリはあとから変更できます"))
                    .onboardingStagger(1)
                centeredLead(String(localized: "onboarding.apps.free_limit_note", defaultValue: "無料プランでは1つまで"))
                    .onboardingStagger(2)

                TargetAppGrid(
                    items: SNSAppCatalog.all,
                    selectedCatalogIDs: Set(selectedCatalogIDs),
                    onboardingStaggerBase: 3,
                    onToggle: toggleCatalogSelection
                )

                if let appSelectionMessage {
                    messageCard(appSelectionMessage)
                }
            }
        }
    }

    var goalSetupContent: some View {
        ScrollViewReader { screenProxy in
            screenScroll {
                VStack(alignment: .leading, spacing: 24) {
                    centeredTitle(goalSetupTitle)
                        .onboardingStagger(1)
                    centeredLead(String(localized: "onboarding.goal.lead", defaultValue: "今日から始めたいことを1つ"))
                        .onboardingStagger(2)
                    centeredLead(String(localized: "onboarding.goal.multi_note", defaultValue: "目標は5つまで あとから変えられます"))
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
                                        // 5件そろったら6件目は打てないようにする（進むボタンの空振りを防ぐ）
                                        .disabled(isGoalListFull)
                                        .focused($isGoalFieldFocused)
                                        .id(goalFieldGeneration)
                                        .task(id: goalFieldGeneration) {
                                            guard goalFieldGeneration > 0 else { return }
                                            // Let UIKit finish resigning the removed field before requesting focus.
                                            do { try await Task.sleep(for: .milliseconds(50)) }
                                            catch { return }
                                            guard !Task.isCancelled, step == .goalSetup else { return }
                                            isGoalFieldFocused = true
                                        }
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
                            Text(String(localized: "onboarding.goal.helper", defaultValue: "目標はロック画面にも表示"))
                                .dopaFont(13, weight: .medium)
                                .foregroundStyle(DesignTokens.secondaryText)
                            Spacer(minLength: 8)
                            // 入力前から「0/16」が出ていて何の数字か分からなかった。
                            // 上限が近づいたときだけ残り字数として出す。
                            if showsGoalCharacterCount {
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
                    }
                    .onboardingStagger(4)

                    if !draftGoals.isEmpty {
                        ScrollViewReader { proxy in
                            // Bound the list so adding many goals never pushes the input out of reach.
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(draftGoals) { draft in
                                        draftGoalRow(draft)
                                            .id(draft.id)
                                    }
                                }
                            }
                            .frame(height: min(CGFloat(draftGoals.count) * 64 - 8, 144))
                            .scrollBounceBehavior(.basedOnSize)
                            .task(id: highlightedGoalID) {
                                guard let id = highlightedGoalID else { return }
                                // Wait for the inserted row's layout before resolving its scroll anchor.
                                await Task.yield()
                                guard !Task.isCancelled else { return }
                                withAnimation(reduceMotion ? nil : DopaMotion.control) {
                                    proxy.scrollTo(id, anchor: .bottom)
                                    screenProxy.scrollTo("addedGoals", anchor: .bottom)
                                }
                                do {
                                    try await Task.sleep(for: .milliseconds(600))
                                } catch { return }
                                guard highlightedGoalID == id else { return }
                                highlightedGoalID = nil
                            }
                        }
                        .id("addedGoals")
                    }

                    if !draftGoals.isEmpty {
                        // 追加した目標がロック画面でどう出るかをその場で見せる。
                        // 保存前の下書きをそのまま流し込むので、足すたびに反映される。
                        VStack(alignment: .leading, spacing: 8) {
                            SmallLabel(
                                text: String(
                                    localized: "onboarding.goal.lock_preview",
                                    defaultValue: "ロック画面の見え方"
                                )
                            )

                            LockThemePreviewCard(
                                theme: model.displayedLockThemeSelection,
                                goalTitles: goalPreviewTitles,
                                cancelledCount: model.todayCancelledCount,
                                attemptCount: model.todayAttemptCount
                            )

                            Button {
                                isGoalThemePickerPresented = true
                            } label: {
                                Text(
                                    String(
                                        localized: "onboarding.goal.change_design",
                                        defaultValue: "ほかのデザインにする"
                                    )
                                )
                                .dopaFont(13, weight: .semibold)
                                .foregroundStyle(DesignTokens.accent)
                                .frame(minHeight: 44, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("onboarding-goal-theme-entry")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onboardingStagger(6)
                    }

                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                guard isGoalFieldFocused, highlightedGoalID != nil else { return }
                // Keyboard avoidance changes the viewport after the replacement field gains focus.
                withAnimation(reduceMotion ? nil : DopaMotion.control) {
                    screenProxy.scrollTo("addedGoals", anchor: .bottom)
                }
            }
        }
    }

    var chooseModeContent: some View {
        // カードが2枚しかなく、上寄せだと画面下が大きく空く。
        // 収まるときだけ縦中央へ寄せ、大きい文字で溢れるときは通常のスクロールに戻す。
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    centeredTitle(String(localized: "onboarding.mode.title", defaultValue: "止め方を選ぶ"))
                        .onboardingStagger(0)
                    centeredLead(String(localized: "onboarding.mode.lead", defaultValue: "あとから変えられます"))
                        .onboardingStagger(1)

                    VStack(spacing: 12) {
                        // おすすめのProを上に置く（2026-09-26 オーナー指示）。
                        ForEach(Array([InterventionMode.deepFocus, .standard].enumerated()), id: \.element) { index, mode in
                            modeButton(mode)
                                .onboardingStagger(2 + index)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 136)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: proxy.size.height, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

private extension OnboardingFlow {

    /// 体験に使うアプリ。選んだ最初のアプリ、未選択ならInstagram。
    var experienceApp: SNSAppCatalogItem? {
        OnboardingExperienceAppPolicy.app(from: selectedTargets)
    }

    /// ショートカットを使わず、アプリ内で本物の一呼吸を1回体験する画面。
    var experienceContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                CharacterView(.awake, size: DesignTokens.CharacterSize.header)
                    .frame(maxWidth: .infinity)
                    .onboardingStagger(0)
                centeredTitle(String(localized: "onboarding.experience.title", defaultValue: "一呼吸を体験する"))
                    .onboardingStagger(1)
                centeredLead(
                    String(
                        localized: "onboarding.experience.lead",
                        defaultValue: "\(experienceApp?.displayName ?? "SNS")を開こうとした時に出る画面です"
                    )
                )
                .onboardingStagger(2)
            }
        }
    }

    func startInAppExperience() {
        guard experienceTarget == nil, let target = experienceApp else {
            advance(from: .experience)
            return
        }
        model.beginInAppOnboardingExperience()
        experienceTarget = target
    }

    @ViewBuilder
    var automationGuideContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                switch automationSetupState {
                case .verified:
                    centeredTitle(String(localized: "onboarding.automation.confirmed.title", defaultValue: "設定を確認しました"))
                    Image(systemName: "checkmark.circle.fill")
                        .dopaFont(56, weight: .bold)
                        .foregroundStyle(DesignTokens.accent)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                case .initial, .awaitingVerification:
                    centeredTitle(String(localized: "onboarding.automation.title", defaultValue: "一呼吸を設定"))
                    centeredLead(String(localized: "onboarding.automation.lead", defaultValue: "アプリを開くと一呼吸が始まる設定​ ショートカットで約2分の初回設定"))

                    if automationSetupState == .awaitingVerification {
                        CardContainer {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(String(localized: "onboarding.automation.test.title", defaultValue: "設定できたら試す"))
                                    .dopaFont(20, weight: .black)
                                    .foregroundStyle(DesignTokens.primaryText)
                                Text(String(localized: "onboarding.automation.test.body", defaultValue: "自動化が動くとDopaBreakが自動で開きます"))
                                    .dopaFont(14, weight: .semibold, lineSpacing: 4)
                                    .foregroundStyle(DesignTokens.secondaryText)
                            }
                        }
                    }

                    if automationSetupState == .initial || showsAutomationStepsAgain {
                        AutomationGuideStepList(playbackController: automationTutorialPlayback)
                    }

                    centeredLead(
                        String(
                            localized: "onboarding.automation.privacy_note",
                            defaultValue: "検知するのは選んだアプリの起動だけ​ ほかの操作や画面の内容は送信しません"
                        )
                    )
                }
                automationTargetList
            }
        }
        .onAppear {
            consumeAutomationVerificationOnActivation()
            automationTutorialPlayback.guideDidAppear(reduceMotion: reduceMotion)
        }
        .onDisappear {
            automationTutorialPlayback.guideDidDisappear()
        }
    }

    private var automationTargetList: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                SmallLabel(text: String(localized: "onboarding.automation.apps_label", defaultValue: "設定するアプリ"))
                Text(String(localized: "automation_guide.checklist.manual", defaultValue: "ショートカットで設定したアプリをタップしてください。設定を削除した場合は、もう一度タップしてチェックを外せます。"))
                    .dopaFont(14, weight: .medium, lineSpacing: 4)
                    .foregroundStyle(DesignTokens.secondaryText)
                if selectedTargets.isEmpty {
                    Text(String(localized: "onboarding.automation.apps_empty", defaultValue: "先に一呼吸をはさむアプリを選んでください"))
                        .dopaFont(15, weight: .semibold)
                        .foregroundStyle(DesignTokens.secondaryText)
                } else {
                    ForEach(selectedTargets) { target in
                        AutomationChecklistRow(
                            target: target,
                            isConfirmed: confirmedAutomationCatalogIDs.contains(target.catalogID)
                        ) {
                            settingsStore.setAutomationConfirmed(
                                catalogID: target.catalogID,
                                confirmed: !confirmedAutomationCatalogIDs.contains(target.catalogID)
                            )
                            refreshAutomationVerificationState()
                        }
                    }
                }
            }
        }
    }

    var notificationGuideContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                centeredTitle(String(localized: "onboarding.notification.title", defaultValue: "目標をロック画面に"))
                    .onboardingStagger(0)
                centeredLead(String(localized: "onboarding.notification.lead", defaultValue: "ライブアクティビティで目標を表示​ 記録と振り返りの通知もオンにできます"))
                    .onboardingStagger(1)

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
                            Text(String(localized: "onboarding.notification.preview.cancelled", defaultValue: "開かなかった"))
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
                .onboardingStagger(2)

                if let notificationMessage {
                    messageCard(notificationMessage)
                        .onboardingStagger(3)
                }
            }
        }
    }

    var prePaywallSummaryContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                CharacterView(.awake, size: DesignTokens.CharacterSize.header)
                    .frame(maxWidth: .infinity)
                    .onboardingStagger(1)
                // ショートカット設定はこの後なので、設定状況で見出しを切り替えない
                centeredTitle(String(localized: "onboarding.summary.title", defaultValue: "プランができました"))
                    .onboardingStagger(2)
                centeredLead(String(localized: "onboarding.summary.lead", defaultValue: "SNSを開く前に一呼吸"))
                    .onboardingStagger(3)

                CardContainer {
                    VStack(spacing: 0) {
                        summaryRow(
                            label: String(localized: "onboarding.summary.apps", defaultValue: "一呼吸をはさむアプリ"),
                            value: selectedAppsSummary
                        )
                        divider
                        VStack(alignment: .leading, spacing: 10) {
                            Text(String(localized: "onboarding.summary.goal", defaultValue: "目標"))
                                .dopaFont(15, weight: .bold)
                                .foregroundStyle(DesignTokens.secondaryText)
                            summaryGoalList
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                        divider
                        summaryRow(
                            label: String(localized: "onboarding.summary.time", defaultValue: "1年でSNSに使う時間"),
                            value: String(localized: "onboarding.summary.yearly_days", defaultValue: "約\(summaryYearlyDays)日")
                        )
                        divider
                        summaryRow(
                            label: String(localized: "onboarding.summary.mode", defaultValue: "止め方"),
                            value: OnboardingSummaryPresentation.modeTitle(selectedMode, isPro: model.storeService.isPro)
                        )
                    }
                }
                .onboardingStagger(4)

                if OnboardingThemeSummaryPolicy.showsThemeCard(for: model.displayedLockThemeSelection) {
                    VStack(spacing: 10) {
                        LockThemePreviewCard(
                            theme: model.displayedLockThemeSelection,
                            goalTitles: lockThemePreviewTitles,
                            cancelledCount: model.todayCancelledCount,
                            attemptCount: model.todayAttemptCount
                        )

                        if OnboardingThemeSummaryPolicy.showsSummaryProNote(
                            for: model.displayedLockThemeSelection,
                            isThemeAllowed: model.entitlementGate.lockThemeAllowed
                        ) {
                            Text(
                                String(
                                    localized: "onboarding.summary.theme_note",
                                    defaultValue: "このデザインをロック画面に表示するにはProが必要です"
                                )
                            )
                            .dopaFont(13, weight: .semibold, lineSpacing: 3)
                            .foregroundStyle(DesignTokens.secondaryText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .onboardingStagger(5)
                }

                centeredLead(String(localized: "onboarding.summary.footer", defaultValue: "開く前に立ち止まって選べます"))
                    .onboardingStagger(6)

                if model.storeService.isPro, selectedMode.usesShield {
                    centeredLead(String(localized: "onboarding.summary.block_setup_note", defaultValue: "次はブロックするアプリを選択"))
                        .onboardingStagger(7)
                }
            }
        }
        .onAppear(perform: refreshAutomationVerificationState)
    }

    var blockSetupContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                centeredTitle(String(localized: "onboarding.block_setup.title", defaultValue: "完全にブロックする​アプリを選ぶ"))
                centeredLead(blockSetupLead)

                CardContainer {
                    VStack(alignment: .leading, spacing: 0) {
                        blockSetupAuthorizationRow
                        divider
                        blockSetupPickerRow
                        divider
                        Text(String(localized: "onboarding.block_setup.note.time", defaultValue: "時間帯は設定からいつでも変えられます"))
                            .dopaFont(14, weight: .semibold, lineSpacing: 4)
                            .foregroundStyle(DesignTokens.secondaryText)
                            .padding(.vertical, 14)
                    }
                }

                if let blockSetupSaveMessage {
                    messageCard(blockSetupSaveMessage)
                }
            }
        }
        .onAppear {
            model.ensureWakeSleepDefaults()
            loadBlockedAppSelection()
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
                    titleText(
                        automationSetupState == .verified
                            ? String(localized: "onboarding.ready.title", defaultValue: "準備完了")
                            : String(localized: "onboarding.ready.title.pending", defaultValue: "あと1つで準備完了")
                    )
                        .multilineTextAlignment(.center)
                    bodyText(
                        automationSetupState == .verified
                            ? String(localized: "onboarding.ready.body", defaultValue: "SNSを開く前に立ち止まって選べます")
                            : String(localized: "onboarding.ready.body.pending", defaultValue: "ショートカットの自動化で​ 一呼吸が動き始めます")
                    )
                        .multilineTextAlignment(.center)
                }
                .onboardingStagger(0)

                if let mode = progress.readyModeNotice, !model.storeService.isPro {
                    CardContainer {
                        VStack(spacing: 8) {
                            centeredLead(String(localized: "onboarding.ready.free_start", defaultValue: "いまは一呼吸で始めます"))
                            centeredLead(OnboardingSummaryPresentation.proNotice(mode))
                            centeredLead(String(localized: "onboarding.ready.mode_settings", defaultValue: "設定でいつでも変えられます"))
                        }
                    }
                }

                CardContainer {
                    VStack(spacing: 6) {
                        SmallLabel(
                            text: String(
                                localized: "onboarding.ready.recovered_label",
                                defaultValue: "1年で取り戻せる時間"
                            )
                        )
                        Text(
                            String(
                                localized: "onboarding.ready.recovered_value",
                                defaultValue: "約\(recoveredYearlyDays)日"
                            )
                        )
                        .dopaFont(40, weight: .black)
                        .foregroundStyle(DesignTokens.accent)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        centeredLead(
                            String(
                                localized: "onboarding.ready.recovered_note",
                                defaultValue: "いまの半分になれば戻る時間の目安です"
                            )
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
                .onboardingStagger(1)

                if !summaryGoals.titles.isEmpty {
                    CardContainer {
                        VStack(alignment: .leading, spacing: 10) {
                            SmallLabel(text: String(localized: "onboarding.ready.goal_label", defaultValue: "あなたの目標"))
                            summaryGoalList
                        }
                    }
                    .onboardingStagger(2)
                }

            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            refreshAutomationVerificationState()
            progress.presentReadyModeNotice(isPro: model.storeService.isPro)
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
        .scrollDismissesKeyboard(.interactively)
    }

    func titleText(_ text: String) -> some View {
        DopaDisplayText(text: text)
            .foregroundStyle(DesignTokens.primaryText)
    }

    func bodyText(_ text: String) -> some View {
        DopaDisplayText(text: text, size: 16, weight: .semibold)
            .foregroundStyle(DesignTokens.secondaryText)
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
                    // おすすめはProに付ける（2026-09-26 オーナー指示）。無料の方は「無料」だけにする。
                    Text(mode == .standard
                         ? String(localized: "onboarding.block.free_badge", defaultValue: "無料")
                         : String(localized: "onboarding.block.pro_badge", defaultValue: "Pro・おすすめ"))
                        .dopaFont(13, weight: .bold)
                        .foregroundStyle(mode == .standard ? DesignTokens.primaryText : DesignTokens.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(DesignTokens.backgroundRaised)
                        .clipShape(Capsule())
                    Spacer()
                    if selectedMode == mode {
                        Image(systemName: "checkmark")
                            .foregroundStyle(DesignTokens.accent)
                    }
                }
                Text(DopaDisplayText.protectingWords(mode.displayTitle, language: locale.language.languageCode?.identifier))
                    .dopaFont(20, weight: .black)
                    .foregroundStyle(DesignTokens.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if mode == .standard {
                    blockChoiceLine(String(localized: "onboarding.block.free", defaultValue: "反射で開く手が止まる"))
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        blockChoiceBullet(String(localized: "onboarding.block.manual", defaultValue: "いま30分〜2時間だけ開けなくする"))
                        blockChoiceBullet(String(localized: "onboarding.block.weekly", defaultValue: "毎週の予定で自動ブロック"))
                        blockChoiceBullet(String(localized: "onboarding.block.night", defaultValue: "就寝中は自動ブロック"))
                    }
                    // 無料トライアル（◯日間 ¥0）はペイウォールだけで伝える。この画面には出さない（2026-09-26 オーナー指示）。
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.card)
            .overlay(optionStroke(isSelected: selectedMode == mode))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(OnboardingPressStyle())
    }

    func blockChoiceLine(_ text: String) -> some View {
        Text(DopaDisplayText.protectingWords(text, language: locale.language.languageCode?.identifier))
            .dopaFont(15, weight: .semibold)
            .foregroundStyle(DesignTokens.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    func blockChoiceBullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("•").foregroundStyle(DesignTokens.secondaryText)
            blockChoiceLine(text)
        }
    }

    func selectMode(_ mode: InterventionMode) {
        // 画面に出ていない未実装のモードは選ばせない（`InterventionMode.selectable`）。
        guard mode.isSelectable else {
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
                .stroke(highlightedGoalID == draft.id ? DesignTokens.accent : DesignTokens.hairline,
                        lineWidth: highlightedGoalID == draft.id ? 2 : 1)
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
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .dopaFont(15, weight: .bold)
                .foregroundStyle(DesignTokens.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .dopaFont(17, weight: .black)
                .foregroundStyle(DesignTokens.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 16)
    }

    var selectedTargets: [SNSAppCatalogItem] {
        selectedCatalogIDs.compactMap { SNSAppCatalog.app(catalogID: $0) }
    }

    var automationSetupState: OnboardingAutomationSetupState {
        OnboardingAutomationSetupPolicy.state(
            hasOpenedShortcuts: hasOpenedShortcuts,
            selectedCatalogIDs: selectedCatalogIDs,
            verifiedCatalogIDs: confirmedAutomationCatalogIDs
        )
    }

    var firstAutomationTestTarget: SNSAppCatalogItem? {
        selectedTargets.first { $0.urlScheme != nil }
    }

    var blockedAppSelectionCount: Int {
        blockedAppSelection.applicationTokens.count
            + blockedAppSelection.categoryTokens.count
            + blockedAppSelection.webDomainTokens.count
    }

    var canCompleteBlockSetup: Bool {
        model.screenTimeAuthorizationStatus == .approved
            && blockedAppSelectionCount > 0
            && didSaveBlockedAppSelection
    }

    var blockSetupLead: String {
        return String(
            localized: "onboarding.block_setup.lead.deep_focus",
            defaultValue: "オンにしたきっかけでブロックします"
        )
    }

    @ViewBuilder
    var blockSetupAuthorizationRow: some View {
        if model.screenTimeAuthorizationStatus == .approved {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DesignTokens.accent)
                    .accessibilityHidden(true)
                Text(String(localized: "onboarding.block_setup.done.authorize", defaultValue: "許可済み"))
                    .dopaFont(16, weight: .bold)
                    .foregroundStyle(DesignTokens.primaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Button(String(localized: "onboarding.block_setup.step.authorize", defaultValue: "スクリーンタイムを許可する")) {
                    Task { await requestBlockSetupAuthorization() }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isRequestingScreenTimeAuthorization)

                if model.screenTimeAuthorizationStatus == .denied {
                    Text(String(localized: "onboarding.block_setup.denied", defaultValue: "設定アプリでスクリーンタイムを許可すると使えます"))
                        .dopaFont(13, weight: .semibold, lineSpacing: 3)
                        .foregroundStyle(DesignTokens.secondaryText)
                    Button(String(localized: "onboarding.block_setup.action.open_settings", defaultValue: "設定を開く")) {
                        openAppSettings()
                    }
                    .dopaFont(14, weight: .bold)
                    .foregroundStyle(DesignTokens.accent)
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 12)
        }
    }

    var blockSetupPickerRow: some View {
        Button {
            isBlockedAppPickerPresented = true
        } label: {
            HStack(spacing: 12) {
                Text(String(localized: "onboarding.block_setup.step.pick", defaultValue: "アプリを選ぶ"))
                    .dopaFont(16, weight: .bold)
                    .foregroundStyle(DesignTokens.primaryText)
                Spacer()
                Text(String(localized: "onboarding.block_setup.selection.count", defaultValue: "\(blockedAppSelectionCount)件"))
                    .dopaFont(14, weight: .semibold)
                    .foregroundStyle(DesignTokens.secondaryText)
                Image(systemName: "chevron.right")
                    .foregroundStyle(DesignTokens.secondaryText)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.screenTimeAuthorizationStatus != .approved)
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

    var summaryGoals: OnboardingSummaryPresentation {
        OnboardingSummaryPresentation(drafts: draftGoals, typedGoal: heroGoal)
    }

    var summaryGoalList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(summaryGoals.titles.enumerated()), id: \.offset) { _, title in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle().fill(DesignTokens.accent).frame(width: 5, height: 5)
                    Text(title).dopaFont(17, weight: .black)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if summaryGoals.additionalCount > 0 {
                Text(String(localized: "onboarding.summary.additional_goals", defaultValue: "ほか\(summaryGoals.additionalCount)件"))
                    .dopaFont(15, weight: .bold)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
            if summaryGoals.titles.isEmpty {
                Text(String(localized: "onboarding.value.not_set", defaultValue: "未設定"))
                    .dopaFont(17, weight: .black)
            }
        }
        .foregroundStyle(DesignTokens.primaryText)
    }

    var notificationGoalText: String {
        let currentGoal = model.goals.first?.lockScreenTitle ?? model.goals.first?.title
        let localGoal = summaryGoals.titles.first ?? ""
        return localGoal.isEmpty
            ? (currentGoal ?? String(localized: "onboarding.notification.preview.goal_fallback", defaultValue: "ここにあなたの目標を表示"))
            : localGoal
    }

    var lockThemePreviewTitles: [String] {
        let titles = model.lockScreenDisplayTitles.filter { !$0.isEmpty }
        return titles.isEmpty
            ? [String(localized: "lock_check.preview.goal_fallback", defaultValue: "あなたの目標")]
            : titles
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
        // モード画面では選択だけを保持し、体験とプラン確認を終えてから反映する。
        if expected == .prePaywallSummary {
            do {
                try model.applyBlockPreference(selectedMode != .standard)
            } catch {
                showModeSaveError()
                return
            }
        }
        let completedStep = expected
        model.recordFunnelEvent(.onboardingStepCompleted, detail: completedStep.identifier)

        guard let next = nextStep(after: completedStep) else {
            settingsStore.onboardingSavedGoalID = nil
            settingsStore.onboardingStepRaw = nil
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

    /// 前提を満たさないステップは飛ばす。
    func shouldSkip(_ candidate: OnboardingStep) -> Bool {
        candidate.shouldSkip(isPro: model.storeService.isPro,
                             hasConfirmedEntitlement: model.storeService.hasConfirmedEntitlement,
                             mode: selectedMode)
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
            pendingTargetAfterPurchase = item.catalogID
            paywallPlacement = .onboardingTargetAppGate
            return
        }
        selectedCatalogIDs.append(item.catalogID)
        markSelectionFeedback()
    }

    func persistSelectedAppsAndAdvance() {
        guard !selectedCatalogIDs.isEmpty else {
            appSelectionMessage = String(localized: "onboarding.apps.empty_selection_message", defaultValue: "まずは無意識に開くことが多いSNSを1つ選んでください。")
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

    /// 残り3文字を切ったときだけ字数を出す。入力前の「0/16」は意味が伝わらない。
    var showsGoalCharacterCount: Bool {
        typedGoalLength >= OnboardingGoalList.titleLimit - 3
    }

    /// 直前の損失リビールで見せた「1年で約N日」をそのまま問いに使う。
    /// 半減時の日数ではなく年単位の推計を引き継ぎ、前画面との数値差を作らない。
    var goalSetupTitle: String {
        String(
            format: String(
                localized: "onboarding.goal.title",
                defaultValue: "取り戻す%lld日で​何をする？"
            ),
            summaryYearlyDays
        )
    }

    /// ロック画面プレビューに流す目標。表示上限と同じ5件まで。
    var goalPreviewTitles: [String] {
        Array(draftGoals.prefix(Self.goalCountLimit).map(\.title))
    }

    /// 一覧でテーマを選んだとき。無料テーマは即保存し、Proテーマはペイウォールへ送る。
    func selectOnboardingLockTheme(_ theme: LockTheme) {
        guard model.entitlementGate.lockThemeAllowed(theme) else {
            model.pendingProThemeSelection = theme
            opensThemePaywallAfterPicker = true
            isGoalThemePickerPresented = false
            return
        }
        model.updateLockTheme(theme)
    }

    /// 入力欄の言葉をそのまま足せるか。上限超過は足さずに直してもらう。
    /// 表示できるのは5件まで（ロック画面・呼吸画面と同じ上限）。
    /// 6件目以降は保存しても目に入らないため、入力の段階で止める。
    static let goalCountLimit = 5

    var isGoalListFull: Bool {
        draftGoals.count >= Self.goalCountLimit
    }

    var canAddTypedGoal: Bool {
        !isGoalListFull && (1...OnboardingGoalList.titleLimit).contains(typedGoalLength)
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
            resetGoalField()
            return true
        }
        // 上限到達で足せない言葉が残っていても、次へ進むことは止めない
        guard !isGoalListFull else {
            resetGoalField()
            return true
        }
        guard addDraftGoal(title) else {
            return false
        }
        resetGoalField()
        return true
    }

    /// A binding reset alone is ignored by UIKit while an IME has marked text.
    /// Recreate only the field; its task restores focus after the new empty field mounts.
    func resetGoalField() {
        isGoalFieldFocused = false
        heroGoal = ""
        goalFieldGeneration += 1
    }

    /// リストへ1件足す。同じ言葉がすでにあれば足さずにtrueを返す。
    /// 件数の上限は撤廃済み（2026-08-17オーナー決定）のため、ここでペイウォールは出さない。
    @discardableResult
    func addDraftGoal(_ rawTitle: String) -> Bool {
        guard !OnboardingGoalList.contains(rawTitle, in: draftGoals) else {
            return true
        }
        guard !isGoalListFull else {
            return false
        }
        withAnimation(reduceMotion ? nil : DopaMotion.control) {
            draftGoals = OnboardingGoalList.appending(rawTitle, to: draftGoals)
            highlightedGoalID = draftGoals.last?.id
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

    func saveGoalAndAdvance() {
        // 入力途中の言葉は次へで拾う。書いたのに消えたと感じさせない
        guard commitDraftGoal() else {
            return
        }
        guard !draftGoals.isEmpty else {
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
        persistModeAndAdvance(selectedMode)
    }

    func persistModeAndAdvance(_ mode: InterventionMode) {
        let mode = mode.persistable
        selectedMode = mode

        progress.saveModePreference(mode)
        AppleAdsMeasurement.shared.recordBlockChoice(mode != .standard)
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

    func openShortcuts() {
        guard let url = URL(string: "shortcuts://") else { return }
        automationTutorialPlayback.prepareForExternalTransition()
        UIApplication.shared.open(url, options: [:]) { didOpen in
            Task { @MainActor in
                if didOpen {
                    hasOpenedShortcuts = true
                    showsAutomationStepsAgain = false
                } else {
                    automationTutorialPlayback.cancelExternalTransitionPreparation()
                }
            }
        }
    }

    func testFirstAutomation(_ target: SNSAppCatalogItem) {
        guard let scheme = target.urlScheme,
              let url = URL(string: scheme) else {
            return
        }
        UIApplication.shared.open(url)
    }

    func consumeAutomationVerificationOnActivation() {
        _ = model.consumeAutomationVerificationOnly(from: settingsStore)
        refreshAutomationVerificationState()
        presentExperienceIfNeeded()
    }

    func presentExperienceIfNeeded() {
        guard step == .permission, experienceTarget == nil, !experienceCompleted,
              let target = model.takeOnboardingExperience(from: settingsStore) else { return }
        experienceTarget = target
    }

    func refreshAutomationVerificationState() {
        confirmedAutomationCatalogIDs = Set(settingsStore.confirmedAutomationCatalogIDs)
    }

    func applyPendingOnboardingPurchaseIfNeeded() {
        guard model.storeService.isPro else { return }
        if let catalogID = pendingTargetAfterPurchase,
           !selectedCatalogIDs.contains(catalogID) {
            selectedCatalogIDs.append(catalogID)
            markSelectionFeedback()
        }
        clearPendingOnboardingPurchase()
    }

    func clearPendingOnboardingPurchase() {
        pendingTargetAfterPurchase = nil
    }

    @MainActor
    func requestBlockSetupAuthorization() async {
        guard !isRequestingScreenTimeAuthorization else { return }
        isRequestingScreenTimeAuthorization = true
        defer { isRequestingScreenTimeAuthorization = false }
        let granted = await model.requestScreenTimeAuthorization()
        if granted {
            blockSetupSaveMessage = nil
        }
    }

    func loadBlockedAppSelection() {
        guard let rule = try? model.ruleStore.allRules().first(where: {
            !$0.activitySelectionData.isEmpty
        }),
        let selection = try? JSONDecoder().decode(
            FamilyActivitySelection.self,
            from: rule.activitySelectionData
        ) else {
            blockedAppSelection = FamilyActivitySelection()
            savedBlockedAppSelection = FamilyActivitySelection()
            didSaveBlockedAppSelection = false
            return
        }
        blockedAppSelection = selection
        savedBlockedAppSelection = selection
        didSaveBlockedAppSelection = blockedAppSelectionCount > 0
    }

    func saveBlockedAppSelection() {
        guard selectedMode.usesShield else { return }
        if model.saveBlockedAppSelection(blockedAppSelection, mode: selectedMode) {
            blockSetupSaveMessage = nil
            savedBlockedAppSelection = blockedAppSelection
            didSaveBlockedAppSelection = blockedAppSelectionCount > 0
        } else {
            didSaveBlockedAppSelection = false
            blockSetupSaveMessage = model.alertMessage
                ?? String(localized: "onboarding.block_setup.save_error", defaultValue: "アプリを保存できませんでした")
        }
    }

    func leaveBlockSetupKeepingMode() {
        model.recordFunnelEvent(.onboardingStepCompleted, detail: OnboardingStep.blockSetup.identifier)
        direction = .forward
        withAnimation(DopaMotion.transition) { progress.deferBlockSetup() }
    }

    func formattedTime(minutes: Int) -> String {
        SettingsTime.date(minutes: minutes, defaultMinutes: minutes)
            .formatted(date: .omitted, time: .shortened)
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
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

    /// 3年換算の月数。LossEstimator側で切り捨て済みの値を1桁小数で固定表示する。
    func threeYearMonthsText(yearlyDays: Int) -> String {
        String(format: "%.1f", LossEstimator.threeYearMonths(fromYearlyDays: yearlyDays))
    }
}

/// Preserve the editor/lock-screen order and append an uncommitted, nonduplicate goal.
struct OnboardingSummaryPresentation {
    let titles: [String]
    let additionalCount: Int

    init(drafts: [OnboardingGoalDraft], typedGoal: String) {
        let all = OnboardingGoalList.appending(typedGoal, to: drafts)
        titles = Array(all.prefix(5).map(\.title))
        additionalCount = max(0, all.count - 5)
    }

    /// まとめ画面のボタン。無料トライアル（◯日間 ¥0）はペイウォールだけで伝えるため、
    /// 選んだ止め方に関係なく同じ文言にする（2026-09-27 オーナー指示）。
    static var actionTitle: String {
        String(localized: "onboarding.summary.action", defaultValue: "このプランで始める")
    }

    /// まとめ画面のボタンでペイウォールを出すか。未購入なら選んだ止め方に関係なく全員に1回出す。
    /// 閉じれば無料のまま次へ進む（2026-09-21 オーナー承認「全員が9画面目で通る」設計。
    /// 無料側で出さない実装は承認外で、ペイウォール到達がほぼゼロになっていた）。
    static func needsPlanReview(mode: InterventionMode, isPro: Bool, hasPendingProTheme: Bool = false) -> Bool {
        !isPro
    }

    static func modeTitle(_ mode: InterventionMode, isPro: Bool) -> String {
        guard mode.usesShield, !isPro else { return mode.displayTitle }
        return String(localized: "onboarding.summary.pro_mode", defaultValue: "\(mode.displayTitle)（Pro）")
    }

    static func proNotice(_ mode: InterventionMode) -> String {
        String(localized: "onboarding.ready.block_pro", defaultValue: "ブロックはProで使えます")
    }
}
