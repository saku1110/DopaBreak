import DopaBreakCore
import FamilyControls
import ManagedSettings
import StoreKit
import SwiftUI

/// 一呼吸フロー全体（S-01〜S-05・doc12 §2 / doc11 §7）。
/// AppIntent / URLスキーム経由で起動され、RootTabView最前面の不透明オーバーレイとして表示される。
struct InterventionFlowView: View {
    let onFinished: () -> Void

    @State private var flow: InterventionFlowModel
    @State private var goalEditorRoute: GoalEditorRoute?
    private let model: AppModel
    private let settingsStore: SettingsStore
    private let startsFlowOnAppear: Bool
    private let breathPreviewLoop: Range<TimeInterval>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview

    init(
        target: InterventionTarget,
        model: AppModel,
        settingsStore: SettingsStore,
        onFinished: @escaping () -> Void
    ) {
        self.onFinished = onFinished
        self.startsFlowOnAppear = true
        self.breathPreviewLoop = nil
        self.model = model
        self.settingsStore = settingsStore
        _goalEditorRoute = State(initialValue: nil)
        _flow = State(
            initialValue: InterventionFlowModel(
                target: target,
                model: model,
                settingsStore: settingsStore
            )
        )
    }

    init(target: SNSAppCatalogItem, model: AppModel, settingsStore: SettingsStore, onFinished: @escaping () -> Void) {
        self.init(
            target: .catalog(target),
            model: model,
            settingsStore: settingsStore,
            onFinished: onFinished
        )
    }

    #if DEBUG
    /// App Store素材撮影用。通常画面と同じ状態機械を実際に開始し、指定した理由があれば
    /// 選択まで進めた状態を実ウィンドウへ載せる。本番の表示経路では使用しない。
    init(
        snapshotTarget target: SNSAppCatalogItem,
        model: AppModel,
        settingsStore: SettingsStore,
        selectedReason: InterventionReason?,
        completesBreathing: Bool = false,
        breathPreviewLoop: Range<TimeInterval>? = nil,
        onFinished: @escaping () -> Void
    ) {
        let snapshotFlow = InterventionFlowModel(
            target: target,
            model: model,
            settingsStore: settingsStore
        )
        snapshotFlow.start()
        if completesBreathing {
            snapshotFlow.completeBreathingForTesting()
        }
        if let selectedReason {
            snapshotFlow.selectReason(selectedReason)
        }

        self.init(
            snapshotFlow: snapshotFlow,
            model: model,
            settingsStore: settingsStore,
            breathPreviewLoop: breathPreviewLoop,
            onFinished: onFinished
        )
    }

    /// 撮影側がフローの寿命を明示管理する場合に使う。
    init(
        snapshotFlow: InterventionFlowModel,
        model: AppModel,
        settingsStore: SettingsStore,
        breathPreviewLoop: Range<TimeInterval>? = nil,
        onFinished: @escaping () -> Void
    ) {
        self.onFinished = onFinished
        self.startsFlowOnAppear = false
        self.breathPreviewLoop = breathPreviewLoop
        self.model = model
        self.settingsStore = settingsStore
        _goalEditorRoute = State(initialValue: nil)
        _flow = State(initialValue: snapshotFlow)
    }
    #endif

    var body: some View {
        ZStack {
            DesignTokens.background.ignoresSafeArea()
            flowContent
                .transition(stageTransition)
        }
        // 段階の切り替えを瞬間差し替えからばねへ。中断・巻き戻しができる。
        .animation(DopaMotion.transition, value: flow.stage)
        // 触覚は「結果が確定した瞬間」だけに絞る。段階送りのたびに鳴らすと意味が薄れる。
        .sensoryFeedback(trigger: flow.stage) { _, stage in
            switch stage {
            case .win:
                return flow.winMilestone == nil
                    ? .success
                    : .impact(weight: .heavy, intensity: 1)
            case .failed, .limit: return .error
            default: return nil
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if startsFlowOnAppear {
                flow.start()
            }
        }
        .onDisappear {
            flow.stop()
        }
        .task(id: openingTaskID) {
            guard case .opening(let message) = flow.stage,
                  message == nil,
                  !flow.isAwaitingTargetOpen else {
                return
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            if case .opening(let latest) = flow.stage, latest == nil {
                onFinished()
            }
        }
        .task(id: reviewPromptTaskID) {
            await requestReviewFromWinScreenIfEligible()
        }
        .sheet(item: $goalEditorRoute) { route in
            GoalEditorSheet(model: model, goal: route.goal)
        }
    }

    /// 段階の入れ替え方。動きを減らす設定のときは移動も拡縮もせず、明度の変化だけにする。
    private var stageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.98)),
            removal: .opacity
        )
    }

    private var openingTaskID: String {
        if case .opening(let message) = flow.stage, message == nil {
            return flow.isAwaitingTargetOpen ? "opening-pending" : "opening-ready"
        }
        if case .opening = flow.stage {
            return "opening-fallback"
        }
        return "idle"
    }

    private var reviewPromptTaskID: String {
        flow.stage == .win ? "win" : "not-win"
    }

    @MainActor
    private func requestReviewFromWinScreenIfEligible() async {
        guard flow.stage == .win else { return }
        do {
            try await Task.sleep(for: .milliseconds(1_500))
        } catch {
            return
        }
        guard flow.stage == .win,
              let requestDate = flow.reviewPromptRequestDateIfEligible() else {
            return
        }

        requestReview()
        flow.recordReviewPromptShown(at: requestDate)
    }

    @ViewBuilder
    private var flowContent: some View {
        switch flow.stage {
        case .reflection(let reflection):
            PostUseReflectionContent(
                reflection: reflection,
                onSelect: flow.recordReflection,
                onSkip: flow.skipReflection
            )
        case .breathing:
            breathingScreen
        case .usageSummary:
            usageSummaryScreen
        case .reasonSelection:
            reasonSelectionScreen
        case .durationSelection:
            durationSelectionScreen
        case .opening(let message):
            openingScreen(fallbackMessage: message)
        case .limit(let denial):
            limitScreen(denial: denial)
        case .win:
            winScreen
        case .failed(let message):
            failedScreen(message: message)
        }
    }

    // MARK: - 全経路共通の一呼吸

    private var breathingScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SmallLabel(text: String(localized: "intervention.breath.eyebrow", defaultValue: "PAUSE"))
                Spacer()
                targetLabel
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            Spacer(minLength: 4)

            VStack(spacing: 20) {
                Text(String(localized: "intervention.breath.title", defaultValue: "まずはひと呼吸"))
                    .dopaFont(24, weight: .black)
                    .foregroundStyle(DesignTokens.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)

                breathingCharacter
                    .frame(maxWidth: 520, maxHeight: 520)
                    .padding(.horizontal, 6)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 4)
        }
        .onAppear {
            flow.resumeBreathingIfNeeded()
        }
    }

    @ViewBuilder
    private var breathingCharacter: some View {
        if let breathPreviewLoop {
            BreathingCharacterView(
                totalSeconds: flow.breathTotalSeconds,
                previewLoop: breathPreviewLoop
            )
        } else {
            BreathingCharacterView(totalSeconds: flow.breathTotalSeconds)
        }
    }

    // MARK: - 反射的な目的の利用状況 + 目標 + 判断

    private var usageSummaryScreen: some View {
        stepScaffold {
            VStack(alignment: .leading, spacing: 24) {
                if flow.dayTimeContext != .normal {
                    dayTimeContextBanner(for: flow.dayTimeContext)
                }
                VStack(alignment: .leading, spacing: 14) {
                    SmallLabel(
                        text: String(
                            localized: "intervention.usage_summary.eyebrow_ja",
                            defaultValue: "今日のSNS"
                        )
                    )

                    CardContainer {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(usageAttemptCountValue)
                                    .dopaFont(60, weight: .black, design: .rounded, tracking: -1.5)
                                    .monospacedDigit()
                                    .foregroundStyle(DesignTokens.primaryText)
                                    .contentTransition(.numericText())
                                    .dopaDisplayClamp()

                                Text(usageAttemptLabel)
                                    .dopaFont(15, weight: .semibold)
                                    .foregroundStyle(DesignTokens.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(usageAttemptLine)

                            Rectangle()
                                .fill(DesignTokens.hairline)
                                .frame(height: 1)

                            usageCancelledMetric
                        }
                    }
                }

                Divider()
                    .overlay(DesignTokens.hairline)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        SmallLabel(
                            text: String(
                                localized: "intervention.goal.eyebrow_ja",
                                defaultValue: "あなたの目標"
                            )
                        )
                        Spacer(minLength: 0)
                        Button {
                            goalEditorRoute = GoalEditorRoute(goal: flow.goals.first)
                        } label: {
                            Label(goalActionTitle, systemImage: goalActionSymbol)
                                .labelStyle(.titleAndIcon)
                                .frame(minWidth: 44, minHeight: DesignTokens.minTapTarget)
                                .contentShape(Rectangle())
                        }
                        .dopaFont(15, weight: .bold)
                        .foregroundStyle(DesignTokens.accent)
                        .buttonStyle(.plain)
                    }

                    CardContainer {
                        if flow.goals.isEmpty {
                            Text(
                                String(
                                    localized: "intervention.goal.empty_prompt",
                                    defaultValue: "開く目的を決める"
                                )
                            )
                                .dopaFont(18, weight: .bold)
                                .foregroundStyle(DesignTokens.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(flow.goals, id: \.id) { goal in
                                    HStack(alignment: .top, spacing: 10) {
                                        Circle()
                                            .fill(DesignTokens.accent)
                                            .frame(width: 6, height: 6)
                                            .padding(.top, 8)
                                            .accessibilityHidden(true)
                                        Text(goal.title)
                                            .dopaFont(18, weight: .bold)
                                            .foregroundStyle(DesignTokens.primaryText)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } action: {
            VStack(spacing: 10) {
                primaryButton(
                    String(localized: "intervention.usage_summary.action.cancel", defaultValue: "開かない")
                ) {
                    flow.chooseCancel()
                }
                secondaryButton(
                    usageSummaryOpenActionTitle
                ) {
                    flow.chooseOpen()
                }
            }
        }
    }

    private var usageCancelledMetric: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                usageCancelledMetricLabel
                Spacer(minLength: 12)
                usageCancelledCountText
            }

            VStack(alignment: .leading, spacing: 10) {
                usageCancelledMetricLabel
                usageCancelledCountText
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(usageCancelledLine)
    }

    private var usageCancelledMetricLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .dopaFont(19, weight: .semibold)
                .foregroundStyle(DesignTokens.accent)
                .accessibilityHidden(true)
            Text(usageCancelledLabel)
                .dopaFont(17, weight: .bold)
                .foregroundStyle(DesignTokens.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var usageCancelledCountText: some View {
        Text(usageCancelledCountValue)
            .dopaFont(28, weight: .black, design: .rounded)
            .monospacedDigit()
            .foregroundStyle(DesignTokens.accent)
            .contentTransition(.numericText())
            .dopaDisplayClamp()
    }

    private var usageAttemptLabel: String {
        String(
            localized: "intervention.usage_summary.attempt_label",
            defaultValue: "開こうとした回数"
        )
    }

    private var usageCancelledLabel: String {
        String(
            localized: "intervention.usage_summary.cancelled_label",
            defaultValue: "開かなかった"
        )
    }

    private var usageAttemptCountValue: String {
        usageCountValue(flow.todayAttemptCountForDisplay)
    }

    private var usageCancelledCountValue: String {
        usageCountValue(flow.todayCancelledCountForDisplay)
    }

    private func usageCountValue(_ count: Int) -> String {
        String(
            format: String(
                localized: "intervention.usage_summary.count_value",
                defaultValue: "%lld回"
            ),
            locale: .current,
            Int64(count)
        )
    }

    private var usageAttemptLine: String {
        String(
            format: String(
                localized: "intervention.usage_summary.attempt_line",
                defaultValue: "今日開こうとした回数　%lld回"
            ),
            locale: .current,
            Int64(flow.todayAttemptCountForDisplay)
        )
    }

    private var usageCancelledLine: String {
        String(
            format: String(
                localized: "intervention.usage_summary.cancelled_line",
                defaultValue: "今日開かなかった回数　%lld回"
            ),
            locale: .current,
            Int64(flow.todayCancelledCountForDisplay)
        )
    }

    private var goalActionTitle: String {
        if flow.goals.isEmpty {
            return String(localized: "intervention.goal.action.set", defaultValue: "決める")
        }
        return String(localized: "intervention.goal.action.edit", defaultValue: "変える")
    }

    private var goalActionSymbol: String {
        flow.goals.isEmpty ? "plus" : "pencil"
    }

    // MARK: - S-04 理由

    private var reasonSelectionScreen: some View {
        // 6択カード自体が選択手段なので、下部CTAは持たない。
        stepScaffold(hasAction: false) {
            VStack(alignment: .leading, spacing: 20) {
                SmallLabel(text: String(localized: "intervention.intent.eyebrow", defaultValue: "INTENT"))
                titleText(String(localized: "intervention.intent.title", defaultValue: "何のために\n開きますか？"))
                Text(String(localized: "intervention.intent.description", defaultValue: "開く理由を選んでください"))
                    .dopaFont(14, weight: .medium)
                    .foregroundStyle(DesignTokens.secondaryText)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(InterventionReason.allCases) { reason in
                        Button {
                            flow.selectReason(reason)
                        } label: {
                            VStack(alignment: .leading, spacing: 18) {
                                Image(systemName: reasonSymbol(reason))
                                    .dopaFont(22, weight: .semibold)
                                    .foregroundStyle(DesignTokens.primaryText)
                                Text(reason.displayTitle)
                                    .dopaFont(16, weight: .bold)
                                    .foregroundStyle(DesignTokens.primaryText)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
                            .background(DesignTokens.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(DesignTokens.hairline, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } action: {
            EmptyView()
        }
    }

    private var durationSelectionScreen: some View {
        stepScaffold {
            VStack(alignment: .leading, spacing: 20) {
                SmallLabel(text: String(localized: "intervention.duration.eyebrow", defaultValue: "TIME"))
                titleText(String(localized: "intervention.duration.title", defaultValue: "何分だけ\n開きますか？"))
                if let reason = flow.selectedReason {
                    CardContainer {
                        HStack(spacing: 10) {
                            Image(systemName: reasonSymbol(reason))
                                .foregroundStyle(DesignTokens.accent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(reason.displayTitle)
                                    .dopaFont(16, weight: .bold)
                                    .foregroundStyle(DesignTokens.primaryText)
                            }
                        }
                    }
                }
                Text(
                    String(
                        localized: "intervention.duration.guidance",
                        defaultValue: "必要なぶんだけ時間を選んでください"
                    )
                )
                    .dopaFont(14, weight: .medium)
                    .foregroundStyle(DesignTokens.secondaryText)
                if case .catalog = flow.target {
                    Text(
                        String(
                            localized: "intervention.duration.catalog_notice",
                            defaultValue: "この時間が過ぎてもアプリは自動では閉じません"
                        )
                    )
                        .dopaFont(14, weight: .semibold)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(InterventionDuration.allCases) { duration in
                        let isSelected = flow.selectedDuration == duration
                        Button {
                            flow.chooseDuration(duration)
                        } label: {
                            Text(duration.displayTitle)
                                .dopaFont(22, weight: .black, design: .rounded)
                                .foregroundStyle(isSelected ? DesignTokens.accent : DesignTokens.primaryText)
                                .frame(maxWidth: .infinity, minHeight: 84)
                                .background(DesignTokens.card)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(
                                            isSelected ? DesignTokens.accent : DesignTokens.hairline,
                                            lineWidth: isSelected ? 2 : 1
                                        )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        // 選択状態はVoiceOverにも伝える。見た目の枠線だけでは伝わらない。
                        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    }
                }
                .animation(DopaMotion.control, value: flow.selectedDuration)
                // 選択の切り替えは触覚で確定を返す。ピッカーと同じ役割。
                .sensoryFeedback(.selection, trigger: flow.selectedDuration)

            }
        } action: {
            VStack(spacing: 4) {
                primaryButton(
                    String(
                        localized: "intervention.duration.action.open",
                        defaultValue: "\(flow.selectedDuration.rawValue)分だけ開く"
                    )
                ) {
                    flow.confirmSelectedDuration()
                }

                if flow.selectedReason?.interventionStyle == .direct {
                    Button(String(localized: "intervention.duration.action.cancel", defaultValue: "やっぱり開かない")) {
                        flow.chooseCancel()
                    }
                    .dopaFont(15, weight: .semibold)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityHint(
                        String(
                            localized: "intervention.duration.action.cancel_hint",
                            defaultValue: "SNSは開かず、今日の記録を見ます"
                        )
                    )
                }
            }
        }
    }

    private func openingScreen(fallbackMessage: String?) -> some View {
        // 起動待ちの通常時はCTAなし。失敗メッセージが出たときだけ「閉じる」を置く。
        stepScaffold(hasAction: fallbackMessage != nil) {
            VStack(alignment: .center, spacing: 24) {
                SmallLabel(text: String(localized: "intervention.opening.eyebrow", defaultValue: "OPENING"))
                if let fallbackMessage {
                    titleText(fallbackMessage)
                } else {
                    titleText(
                        String(
                            localized: "intervention.opening.title",
                            defaultValue: "\(targetDisplayName)を開いています"
                        )
                    )
                    if let reason = flow.selectedReason {
                        Text(
                            openingSummary(for: reason)
                        )
                            .dopaFont(15, weight: .bold)
                            .foregroundStyle(DesignTokens.secondaryText)
                    }
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(DesignTokens.accent)
                        .frame(maxWidth: 220)
                }
            }
            .frame(maxWidth: .infinity)
        } action: {
            if fallbackMessage != nil {
                primaryButton(String(localized: "intervention.action.close", defaultValue: "閉じる")) {
                    onFinished()
                }
            } else {
                EmptyView()
            }
        }
    }

    private var usageSummaryOpenActionTitle: String {
        String(
            localized: "intervention.usage_summary.action.choose_duration",
            defaultValue: "開く時間を選ぶ"
        )
    }

    private func openingSummary(for reason: InterventionReason) -> String {
        String(
            localized: "intervention.opening.summary",
            defaultValue: "\(reason.displayTitle) ・ \(flow.selectedDuration.rawValue)分"
        )
    }

    // MARK: - 勝ち画面

    private var winScreen: some View {
        stepScaffold(topPadding: 28) {
            WinScreenContent(
                reclaimedSeconds: flow.winReclaimedSeconds,
                lifetimeReclaimedSeconds: flow.winLifetimeReclaimedSeconds,
                todayCancelledCount: flow.todayCancelledCountForDisplay,
                estimatedMinutesPerCancellation: flow.winEstimatedMinutesPerCancellation,
                goals: flow.goals,
                milestone: flow.winMilestone
            )
        } action: {
            primaryButton(String(localized: "intervention.action.close", defaultValue: "閉じる")) {
                onFinished()
            }
        }
    }

    private func failedScreen(message: String) -> some View {
        stepScaffold {
            VStack(alignment: .leading, spacing: 20) {
                titleText(message)
            }
        } action: {
            primaryButton(String(localized: "intervention.action.close", defaultValue: "閉じる")) {
                onFinished()
            }
        }
    }

    private func limitScreen(denial: GateDenial) -> some View {
        stepScaffold {
            VStack(alignment: .leading, spacing: 20) {
                titleText(
                    String(
                        localized: "intervention.gate.limit.title",
                        defaultValue: "今日はここまで"
                    )
                )
                Text(limitMessage(for: denial))
                    .dopaFont(16, weight: .medium, lineSpacing: 5)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } action: {
            primaryButton(String(localized: "intervention.action.close", defaultValue: "閉じる")) {
                onFinished()
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var targetLabel: some View {
        switch flow.target {
        case .catalog(let target):
            SmallLabel(text: target.displayName.uppercased())
        case .gateToken(let tokenData, _):
            if let token = try? GateTokenCoding.decode(ApplicationToken.self, from: tokenData) {
                Label(token)
                    .dopaFont(12, weight: .bold)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineLimit(1)
            } else {
                SmallLabel(text: targetDisplayName)
            }
        }
    }

    private var targetDisplayName: String {
        switch flow.target {
        case .catalog(let target):
            return target.displayName
        case .gateToken:
            return String(
                localized: "intervention.gate.target_name",
                defaultValue: "このアプリ"
            )
        }
    }

    private func limitMessage(for denial: GateDenial) -> String {
        switch denial {
        case .limitReached:
            return String(
                localized: "intervention.gate.limit.body",
                defaultValue: "このアプリは今日の上限に達しました。上限は設定で変えられます。"
            )
        case .cooldown(let until):
            let time = until.formatted(date: .omitted, time: .shortened)
            return String(
                localized: "intervention.gate.cooldown.body",
                defaultValue: "\(time)から開けます。待ち時間は設定で変えられます。"
            )
        case .alreadyOpen:
            return String(
                localized: "intervention.gate.already_open.body",
                defaultValue: "このアプリは、すでに開ける状態です。"
            )
        }
    }

    /// - Parameter hasAction: CTAを持たない段階では `false`。
    ///   `EmptyView` を渡しても余白と背景は残るため、固定バー自体を作らないことで
    ///   本文の安全領域が30pt無駄に縮むのを防ぐ。
    private func stepScaffold<Content: View, Action: View>(
        hasAction: Bool = true,
        topPadding: CGFloat = 60,
        @ViewBuilder content: () -> Content,
        @ViewBuilder action: () -> Action
    ) -> some View {
        ScrollView {
            content()
                .padding(.horizontal, 20)
                .padding(.top, topPadding)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        // 中身が短いときに空振りで弾ませない。
        .scrollBounceBehavior(.basedOnSize)
        // CTAは固定バーとして安全領域に載せる。本文はその下へスクロールして潜り込む。
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if hasAction {
                action()
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
                    .background(DesignTokens.background)
            }
        }
    }

    private func titleText(_ text: String) -> some View {
        Text(text)
            .dopaFont(32, weight: .black, lineSpacing: 5)
            .foregroundStyle(DesignTokens.primaryText)
            .minimumScaleFactor(0.8)
    }

    @ViewBuilder
    private func dayTimeContextBanner(for context: DayTimeContext) -> some View {
        switch context {
        case .wake:
            dayTimeContextBanner(
                title: String(localized: "intervention.day_context.morning.title", defaultValue: "起きてすぐの数分"),
                body: String(localized: "intervention.day_context.morning.body", defaultValue: "起きてすぐSNSを開く前に、今日の過ごし方を選ぶ時間です。")
            )
        case .sleep:
            dayTimeContextBanner(
                title: String(localized: "intervention.day_context.night.title", defaultValue: "眠る前の数分"),
                body: String(localized: "intervention.day_context.night.body", defaultValue: "眠る前にSNSから離れるきっかけをつくる時間です。")
            )
        case .normal:
            EmptyView()
        }
    }

    private func dayTimeContextBanner(title: String, body: String) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 4) {
                SmallLabel(text: title)
                Text(body)
                    .dopaFont(15, weight: .semibold)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(PrimaryButtonStyle())
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(SecondaryButtonStyle())
    }

    private func reasonSymbol(_ reason: InterventionReason) -> String {
        switch reason {
        case .work: return "briefcase"
        case .research: return "magnifyingglass"
        case .communication: return "message"
        case .posting: return "square.and.arrow.up"
        case .boredom: return "leaf"
        case .unconscious: return "ellipsis"
        }
    }
}
