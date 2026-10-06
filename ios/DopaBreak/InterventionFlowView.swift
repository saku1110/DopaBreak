import DopaBreakCore
import StoreKit
import SwiftUI

private struct StepContentHeightModifier: ViewModifier {
    let fillsAvailableHeight: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if fillsAvailableHeight {
            content.containerRelativeFrame(.vertical, alignment: .top)
        } else {
            content
        }
    }
}

/// 一呼吸フロー全体（S-01〜S-05・doc12 §2 / doc11 §7）。
/// AppIntent / URLスキーム経由で起動され、RootTabView最前面の不透明オーバーレイとして表示される。
struct InterventionFlowView: View {
    let onFinished: () -> Void
    private var onExperienceCompleted: () -> Void = {}

    @State private var flow: InterventionFlowModel
    @State private var goalEditorRoute: GoalEditorRoute?
    private let model: AppModel
    private let settingsStore: SettingsStore
    private let startsFlowOnAppear: Bool
    private let breathPreviewLoop: Range<TimeInterval>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase

    init(
        target: InterventionTarget,
        model: AppModel,
        settingsStore: SettingsStore,
        isOnboardingExperience: Bool = false,
        onExperienceCompleted: @escaping () -> Void = {},
        onFinished: @escaping () -> Void
    ) {
        self.onExperienceCompleted = onExperienceCompleted
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
                settingsStore: settingsStore,
                isOnboardingExperience: isOnboardingExperience
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
        onExperienceCompleted: @escaping () -> Void = {},
        onFinished: @escaping () -> Void
    ) {
        self.onExperienceCompleted = onExperienceCompleted
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
            case .failed: return .error
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
            guard isReadyToDismissAfterOpening else {
                return
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            if isReadyToDismissAfterOpening {
                onFinished()
            }
        }
        .task(id: reviewPromptTaskID) {
            await requestReviewFromWinScreenIfEligible()
        }
        // 上限画面を開いたまま朝を迎えた・Freeへ戻ったときに、古い画面のまま待たせない。
        .task(id: isShowingDailyOpenLimitScreen) {
            while isShowingDailyOpenLimitScreen, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                flow.refreshLimitStateIfNeeded()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                flow.refreshLimitStateIfNeeded()
            }
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
        if case .passingThrough = flow.stage {
            return flow.isAwaitingTargetOpen ? "pass-through-pending" : "pass-through-ready"
        }
        if case .opening(let message) = flow.stage, message == nil {
            return flow.isAwaitingTargetOpen ? "opening-pending" : "opening-ready"
        }
        if case .opening = flow.stage {
            return "opening-fallback"
        }
        return "idle"
    }

    private var isReadyToDismissAfterOpening: Bool {
        switch flow.stage {
        case .opening(let message):
            return message == nil && !flow.isAwaitingTargetOpen
        case .passingThrough:
            return !flow.isAwaitingTargetOpen
        default:
            return false
        }
    }

    private var isShowingDailyOpenLimitScreen: Bool {
        flow.stage == .limitReached || flow.stage == .emergencyWaiting
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
        case .passingThrough(let remainingMinutes):
            passThroughScreen(remainingMinutes: remainingMinutes)
        case .win:
            winScreen
        case .failed(let message):
            failedScreen(message: message)
        case .limitReached:
            limitReachedScreen
        case .emergencyWaiting:
            emergencyWaitingScreen
        }
    }

    // MARK: - 全経路共通の一呼吸

    private var breathingScreen: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 4)

                    VStack(spacing: 20) {
                        if !flow.goals.isEmpty {
                            VStack(spacing: 14) {
                                Text(String(
                                    localized: "intervention.breath.goals_title",
                                    defaultValue: "目標を思い出しましょう"
                                ))
                                .dopaFont(18, weight: .bold)
                                .foregroundStyle(DesignTokens.primaryText)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .frame(maxWidth: .infinity)

                                CardContainer {
                                    goalRows(Array(flow.goals.prefix(5)))
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        if let remaining = flow.remainingOpensForDisplay {
                            Text(String(localized: "open_limit.breath.remaining", defaultValue: "今日あと\(remaining)回"))
                                .dopaFont(16, weight: .bold)
                                .foregroundStyle(DesignTokens.secondaryText)
                                .monospacedDigit()
                                .frame(maxWidth: .infinity)
                                .accessibilityIdentifier("intervention.open_limit.remaining")
                        }

                        breathingCharacter
                            .frame(maxWidth: 520, maxHeight: 520)
                            .padding(.horizontal, 6)

                    }
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 4)
                }
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onAppear {
            flow.resumeBreathingIfNeeded()
        }
    }

    private func goalRows(_ goals: [Goal]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(goals, id: \.id) { goal in
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
                            goalRows(flow.goals)
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
        // 開かない決断には理由の入力を要求しない。
        stepScaffold {
            VStack(alignment: .leading, spacing: 20) {
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
            primaryButton(String(localized: "intervention.usage_summary.action.cancel", defaultValue: "開かない")) {
                flow.chooseCancel()
            }
        }
    }

    private var durationSelectionScreen: some View {
        stepScaffold {
            VStack(alignment: .leading, spacing: 20) {
                titleText(flow.canChooseUntimed && !flow.usesTimeLimit
                    ? String(localized: "reintervention.work.title", defaultValue: "用事に集中しましょう")
                    : String(localized: "intervention.duration.title", defaultValue: "何分だけ\n開きますか？"))
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
                if flow.isEmergencyOpen {
                    Text(String(localized: "open_limit.emergency.duration_notice", defaultValue: "この時間が過ぎるとまた開けなくなります"))
                        .dopaFont(14, weight: .semibold)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else if flow.isLastOpenForDailyLimit, let end = flow.dailyOpenLimitDayEndsAt {
                    CardContainer {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "open_limit.last.title", defaultValue: "今日はこれが最後の1回です"))
                                .dopaFont(16, weight: .bold)
                                .foregroundStyle(DesignTokens.primaryText)
                            Text(DailyOpenLimitDisplay.lastOpenNotice(end, now: model.currentDate))
                                .dopaFont(14, weight: .semibold)
                                .foregroundStyle(DesignTokens.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityIdentifier("intervention.open_limit.last")
                }
                if flow.canChooseUntimed {
                    Toggle(String(localized: "reintervention.work.toggle", defaultValue: "今回は利用時間を決める"), isOn: $flow.usesTimeLimit)
                        .tint(DesignTokens.accent)
                    if !flow.usesTimeLimit {
                        Text(String(localized: "reintervention.work.notice", defaultValue: "今回は利用時間の通知・制限や満足度の質問はありません。毎週の予定や就寝中のブロックは続きます。"))
                            .dopaFont(14, weight: .medium).foregroundStyle(DesignTokens.secondaryText)
                    }
                }
                if !flow.canChooseUntimed || flow.usesTimeLimit {
                Text(
                    String(
                        localized: "intervention.duration.guidance",
                        defaultValue: "必要なぶんだけ時間を選んでください"
                    )
                )
                    .dopaFont(14, weight: .medium)
                    .foregroundStyle(DesignTokens.secondaryText)
                if flow.canChooseUntimed {
                    if flow.canBlockNecessaryUse {
                        Toggle(String(localized: "reintervention.soft.block", defaultValue: "時間になったらブロックする"), isOn: $flow.blocksNecessaryUse)
                            .tint(DesignTokens.accent)
                    }
                    if flow.isGentleCheckIn {
                        Text(flow.canBlockNecessaryUse
                            ? String(localized: "reintervention.soft.usage_notice", defaultValue: "選んだ利用時間になったら確認通知を送ります。ブロックや満足度の質問はありません。")
                            : String(localized: "reintervention.soft.clock_notice", defaultValue: "開いてから選んだ時間がたつと確認通知を送ります。ブロックや満足度の質問はありません。"))
                            .dopaFont(14, weight: .medium).foregroundStyle(DesignTokens.secondaryText)
                        Text(String(localized: "reintervention.soft.permission", defaultValue: "確認通知にはiOSの通知許可と設定の「振り返りの通知」が必要です。"))
                            .font(.footnote).foregroundStyle(DesignTokens.secondaryText)
                    }
                }
                if flow.isEmergencyOpen || flow.isLastOpenForDailyLimit {
                    // 回数上限の一文を上に出している。自動では閉じない旨や再介入の案内は、この回には当てはまらない。
                    EmptyView()
                } else if !flow.isGentleCheckIn, case .catalog(let target) = flow.target, model.isReinterventionConnected(catalogID: target.catalogID) {
                    Text(String(localized: "reintervention.duration.notice", defaultValue: "選んだ利用時間に達すると通知またはブロックでお知らせします。戻ったあとに満足度を記録し、終了か延長を選べます。"))
                        .dopaFont(14, weight: .semibold)
                        .foregroundStyle(DesignTokens.secondaryText)
                } else if !flow.isGentleCheckIn, case .catalog = flow.target {
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

            }
        } action: {
            VStack(spacing: 4) {
                primaryButton(
                    flow.isOnboardingExperience
                    ? String(localized: "onboarding.experience.finish", defaultValue: "一呼吸の体験を終える")
                    : flow.canChooseUntimed && !flow.usesTimeLimit
                    ? String(localized: "reintervention.work.open", defaultValue: "時間を決めずに開く")
                    : String(
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

    private func passThroughScreen(remainingMinutes: Int) -> some View {
        stepScaffold(hasAction: false) {
            VStack(alignment: .center, spacing: 16) {
                titleText(
                    String(
                        localized: "intervention.pass_through.title",
                        defaultValue: "\(targetDisplayName)を開きます"
                    )
                )
                Text(flow.isUntimedPassThrough
                    ? String(localized: "reintervention.work.passing", defaultValue: "今回は通知・制限をスキップして開きます")
                    : flow.hasMonitoredUsageBudget
                    ? String(localized: "reintervention.continuing", defaultValue: "選んだ利用時間の計測を続けます")
                    : String(
                        localized: "intervention.pass_through.remaining",
                        defaultValue: "決めた時間はあと\(remainingMinutes)分"
                    )
                )
                    .dopaFont(15, weight: .bold)
                    .foregroundStyle(DesignTokens.secondaryText)
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(DesignTokens.accent)
                    .frame(maxWidth: 220)
            }
            .frame(maxWidth: .infinity)
        } action: {
            EmptyView()
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
        stepScaffold(fillsAvailableHeight: true, topPadding: 28) {
            WinScreenContent(
                reclaimedSeconds: flow.winReclaimedSeconds,
                lifetimeReclaimedSeconds: flow.winLifetimeReclaimedSeconds,
                todayCancelledCount: flow.todayCancelledCountForDisplay,
                consecutiveDays: flow.winConsecutiveDays,
                estimatedMinutesPerCancellation: flow.winEstimatedMinutesPerCancellation,
                goals: flow.goals,
                milestone: flow.winMilestone
            )
            if flow.isOnboardingExperience {
                Text(String(localized: "onboarding.experience.win", defaultValue: "これが一呼吸です"))
                    .dopaFont(17, weight: .semibold)
                    .foregroundStyle(DesignTokens.primaryText)
            }
        } action: {
            primaryButton(String(localized: "intervention.action.close", defaultValue: "閉じる")) {
                if flow.isOnboardingExperience { onExperienceCompleted() }
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

    // MARK: - 1日に開ける回数

    /// 使い切ったあとに呼ばれたときの画面。理由と終わる時刻だけを書く。
    private var limitReachedScreen: some View {
        stepScaffold {
            VStack(alignment: .leading, spacing: 14) {
                titleText(DailyOpenLimitDisplay.openedTitle(flow.dailyOpenLimitOpenedCount))
                if let end = flow.dailyOpenLimitDayEndsAt {
                    Text(DailyOpenLimitDisplay.untilLine(end, now: model.currentDate))
                        .dopaFont(17, weight: .bold)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .monospacedDigit()
                }
            }
            .accessibilityIdentifier("intervention.open_limit.reached")
        } action: {
            VStack(spacing: 4) {
                primaryButton(String(localized: "intervention.action.close", defaultValue: "閉じる")) {
                    onFinished()
                }
                if !flow.isOtherHardBlockActive {
                    textButton(String(localized: "open_limit.emergency.start", defaultValue: "30秒待って開く")) {
                        flow.requestEmergencyOpen()
                    }
                    .accessibilityIdentifier("intervention.open_limit.emergency")
                }
            }
        }
    }

    /// 緊急で開く前の30秒。待ち始めた時刻は保存してあり、閉じて開き直しても短くならない。
    private var emergencyWaitingScreen: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let state = flow.dailyOpenLimitEmergencyState
            stepScaffold {
                VStack(alignment: .leading, spacing: 14) {
                    switch state {
                    case .waiting(let seconds):
                        titleText(String(localized: "open_limit.emergency.waiting", defaultValue: "あと\(seconds)秒で開けます"))
                            .monospacedDigit()
                    case .ready:
                        titleText(String(localized: "open_limit.emergency.ready", defaultValue: "開けます"))
                    case .notRequested:
                        titleText(String(localized: "open_limit.emergency.expired", defaultValue: "待ち時間が切れました"))
                    }
                }
                .accessibilityIdentifier("intervention.open_limit.waiting")
            } action: {
                VStack(spacing: 4) {
                    if state == .notRequested {
                        primaryButton(String(localized: "open_limit.emergency.start", defaultValue: "30秒待って開く")) {
                            flow.requestEmergencyOpen()
                        }
                    } else {
                        // 待っているあいだは押しても進まないため、押せない見た目にする。
                        Button(String(localized: "open_limit.emergency.choose_time", defaultValue: "時間を選ぶ")) {
                            flow.proceedAfterEmergencyWait()
                        }
                        .buttonStyle(PrimaryButtonStyle(isEnabled: state == .ready))
                        .disabled(state != .ready)
                    }
                    textButton(String(localized: "open_limit.emergency.cancel", defaultValue: "開かない")) {
                        onFinished()
                    }
                }
            }
        }
    }

    private func textButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .dopaFont(15, weight: .semibold)
            .foregroundStyle(DesignTokens.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var targetDisplayName: String {
        switch flow.target {
        case .catalog(let target), .catalogPassThrough(let target, _):
            return target.displayName
        }
    }

    /// - Parameter hasAction: CTAを持たない段階では `false`。
    ///   `EmptyView` を渡しても余白と背景は残るため、固定バー自体を作らないことで
    ///   本文の安全領域が30pt無駄に縮むのを防ぐ。
    private func stepScaffold<Content: View, Action: View>(
        hasAction: Bool = true,
        fillsAvailableHeight: Bool = false,
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
                .modifier(
                    StepContentHeightModifier(
                        fillsAvailableHeight: fillsAvailableHeight
                    )
                )
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
