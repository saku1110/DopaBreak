import DopaBreakCore
import StoreKit
import SwiftUI

private enum BreathingVisualPhase: Equatable {
    case character
    case fadingCharacter
    case flame
}

/// 一呼吸フロー全体（S-01〜S-05・doc12 §2 / doc11 §7）。
/// AppIntent / URLスキーム経由で起動され、fullScreenCoverとして表示される。
struct InterventionFlowView: View {
    let onFinished: () -> Void

    @State private var flow: InterventionFlowModel
    @State private var breathingVisualPhase: BreathingVisualPhase = .character
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview

    init(target: SNSAppCatalogItem, model: AppModel, settingsStore: SettingsStore, onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
        _flow = State(initialValue: InterventionFlowModel(target: target, model: model, settingsStore: settingsStore))
    }

    var body: some View {
        ZStack {
            DesignTokens.background.ignoresSafeArea()
            content
                .transition(stageTransition)
        }
        // 段階の切り替えを瞬間差し替えからばねへ。中断・巻き戻しができる。
        .animation(DopaMotion.transition, value: flow.stage)
        // 触覚は「結果が確定した瞬間」だけに絞る。段階送りのたびに鳴らすと意味が薄れる。
        .sensoryFeedback(trigger: flow.stage) { _, stage in
            switch stage {
            case .win: return .success
            case .failed: return .error
            default: return nil
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            flow.start()
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
    private var content: some View {
        switch flow.stage {
        case .breathing:
            breathingScreen
        case .usageSummary:
            usageSummaryScreen
        case .goalReminder:
            goalReminderScreen
        case .reasonSelection:
            reasonSelectionScreen
        case .decision:
            decisionScreen
        case .durationSelection:
            durationSelectionScreen
        case .opening(let message):
            openingScreen(fallbackMessage: message)
        case .win:
            winScreen
        case .failed(let message):
            failedScreen(message: message)
        }
    }

    // MARK: - 反射的な目的だけに入る一呼吸

    private var breathingScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SmallLabel(text: String(localized: "intervention.breath.eyebrow", defaultValue: "INTERCEPTED"))
                Spacer()
                SmallLabel(text: target.displayName.uppercased())
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            Spacer(minLength: 12)

            VStack(spacing: 12) {
                breathingVisual
                .frame(maxWidth: 380)
                .frame(height: 380)
                .task {
                    await revealFlameAfterCharacter()
                }

                VStack(spacing: 8) {
                    Text(String(localized: "intervention.breath.title", defaultValue: "ひと呼吸おきましょう"))
                        .dopaFont(24, weight: .black)
                        .foregroundStyle(DesignTokens.primaryText)
                    SmallLabel(
                        text: String(
                            localized: "intervention.breath.timer_label",
                            defaultValue: "BREATHE · \(flow.breathTotalSeconds) SEC"
                        )
                    )
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 16)
        }
    }

    @ViewBuilder
    private var breathingVisual: some View {
        switch breathingVisualPhase {
        case .character, .fadingCharacter:
            CharacterView(.doom, size: DesignTokens.CharacterSize.hero)
                .opacity(breathingVisualPhase == .character ? 1 : 0)
        case .flame:
            FlameBreathView(
                breathPhase: flow.breathPhase,
                flare: flow.flarePhase,
                animatesFlare: false
            )
        }
    }

    /// キャラが消え切るまで炎を生成せず、両者が同時に描かれないようにする。
    @MainActor
    private func revealFlameAfterCharacter() async {
        breathingVisualPhase = .character
        do {
            try await Task.sleep(nanoseconds: 600_000_000)
        } catch {
            return
        }
        guard flow.stage == .breathing else { return }
        withAnimation(DopaMotion.control) {
            breathingVisualPhase = .fadingCharacter
        }
        do {
            try await Task.sleep(nanoseconds: 300_000_000)
        } catch {
            return
        }
        guard flow.stage == .breathing else { return }
        breathingVisualPhase = .flame
    }

    // MARK: - S-02 今日はもう N回目

    private var usageSummaryScreen: some View {
        stepScaffold {
            VStack(alignment: .leading, spacing: 22) {
                if flow.dayTimeContext != .normal {
                    dayTimeContextBanner(for: flow.dayTimeContext)
                }
                SmallLabel(text: String(localized: "intervention.usage_summary.eyebrow", defaultValue: "USAGE SUMMARY"))
                Text(
                    String(
                        localized: "intervention.usage_summary.attempt_count",
                        defaultValue: "\(flow.todayAttemptDisplayCount)回"
                    )
                )
                    .dopaFont(72, weight: .black, design: .rounded, tracking: -2)
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.primaryText)
                    .contentTransition(.numericText())
                    .dopaDisplayClamp()
                titleText(String(localized: "intervention.usage_summary.title", defaultValue: "すでに開いています"))
                CardContainer {
                    VStack(alignment: .leading, spacing: 7) {
                        SmallLabel(text: String(localized: "intervention.goal.eyebrow", defaultValue: "YOUR GOAL"))
                        Text(
                            flow.goals.first?.title
                                ?? String(localized: "intervention.goal.fallback", defaultValue: "開く目的を確かめる")
                        )
                            .dopaFont(18, weight: .bold)
                            .foregroundStyle(DesignTokens.primaryText)
                    }
                }
            }
        } action: {
            primaryButton(String(localized: "intervention.usage_summary.action.continue", defaultValue: "目標を思い出す")) {
                flow.advanceToGoalReminder()
            }
        }
    }

    // MARK: - S-03 あなたの目標

    private var goalReminderScreen: some View {
        stepScaffold {
            VStack(alignment: .leading, spacing: 20) {
                if flow.goals.isEmpty {
                    titleText(
                        String(
                            localized: "intervention.goal_reminder.empty_title",
                            defaultValue: "何のために開きますか？"
                        )
                    )
                } else {
                    SmallLabel(text: String(localized: "intervention.goal.eyebrow", defaultValue: "YOUR GOAL"))
                    titleText(String(localized: "intervention.goal_reminder.title", defaultValue: "戻りたい自分"))
                    CardContainer {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(flow.goals, id: \.id) { goal in
                                HStack(alignment: .top, spacing: 10) {
                                    Text(
                                        String(
                                            localized: "intervention.goal_reminder.list_separator",
                                            defaultValue: "・"
                                        )
                                    )
                                        .foregroundStyle(DesignTokens.accent)
                                    Text(goal.title)
                                        .dopaFont(18, weight: .bold)
                                        .foregroundStyle(DesignTokens.primaryText)
                                }
                            }
                        }
                    }
                }
            }
        } action: {
            primaryButton(String(localized: "intervention.goal_reminder.action.continue", defaultValue: "どうするか選ぶ")) {
                flow.advanceToDecision()
            }
        }
    }

    // MARK: - S-04 理由

    private var reasonSelectionScreen: some View {
        // 6択カード自体が選択手段なので、下部CTAは持たない。
        stepScaffold(hasAction: false) {
            VStack(alignment: .leading, spacing: 20) {
                SmallLabel(text: String(localized: "intervention.intent.eyebrow", defaultValue: "INTENT"))
                titleText(String(localized: "intervention.intent.title", defaultValue: "何のために\n開きますか？"))
                Text(String(localized: "intervention.intent.description", defaultValue: "目的が明確なら、一呼吸を省いてすぐ進めます"))
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

    // MARK: - S-05 決定

    private var decisionScreen: some View {
        stepScaffold {
            VStack(alignment: .leading, spacing: 20) {
                SmallLabel(text: String(localized: "intervention.decision.eyebrow", defaultValue: "DECISION"))
                CharacterSwapSequence(
                    from: .doom,
                    to: .awake,
                    size: DesignTokens.CharacterSize.lead,
                    delayNanoseconds: 650_000_000
                )
                .frame(maxWidth: .infinity)
                titleText(String(localized: "intervention.decision.title", defaultValue: "本当に今、\n必要ですか？"))
                if let reason = flow.selectedReason {
                    CardContainer {
                        HStack {
                            Image(systemName: reasonSymbol(reason))
                                .foregroundStyle(DesignTokens.accent)
                            Text(reason.displayTitle)
                                .dopaFont(16, weight: .bold)
                                .foregroundStyle(DesignTokens.primaryText)
                        }
                    }
                }
            }
        } action: {
            VStack(spacing: 10) {
                primaryButton(String(localized: "intervention.decision.action.cancel", defaultValue: "開かない")) {
                    flow.chooseCancel()
                }
                secondaryButton(String(localized: "intervention.decision.action.open", defaultValue: "必要な時間だけ開く")) {
                    flow.chooseOpenWithTime()
                }
            }
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
                                if reason.interventionStyle == .direct {
                                    Text(
                                        String(
                                            localized: "intervention.duration.fast_path_note",
                                            defaultValue: "目的が明確なため、一呼吸を省きました"
                                        )
                                    )
                                        .dopaFont(12, weight: .medium)
                                        .foregroundStyle(DesignTokens.secondaryText)
                                }
                            }
                        }
                    }
                }
                Text(
                    String(
                        localized: "intervention.duration.guidance",
                        defaultValue: "必要な用事が終わる時間だけ選びましょう"
                    )
                )
                    .dopaFont(14, weight: .medium)
                    .foregroundStyle(DesignTokens.secondaryText)
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

                Text(notificationMessage)
                    .dopaFont(13, weight: .medium)
                    .foregroundStyle(DesignTokens.secondaryText)
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
                    Button(String(localized: "intervention.duration.action.cancel", defaultValue: "開かずに戻る")) {
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
                            defaultValue: "SNSを開かずに達成画面へ進みます"
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
                            defaultValue: "\(target.displayName)を開いています"
                        )
                    )
                    if let reason = flow.selectedReason {
                        Text(
                            String(
                                localized: "intervention.opening.summary",
                                defaultValue: "\(reason.displayTitle) ・ \(flow.selectedDuration.rawValue)分"
                            )
                        )
                            .dopaFont(15, weight: .bold)
                            .foregroundStyle(DesignTokens.secondaryText)
                    }
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(DesignTokens.accent)
                        .frame(maxWidth: 220)
                    Text(notificationMessage)
                        .dopaFont(13, weight: .medium)
                        .foregroundStyle(DesignTokens.secondaryText)
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

    private var notificationMessage: String {
        flow.notificationsAuthorized
            ? String(
                localized: "intervention.notification.enabled",
                defaultValue: "時間になったら通知でお知らせします"
            )
            : String(
                localized: "intervention.notification.disabled",
                defaultValue: "通知がオフのため時間のお知らせは届きません"
            )
    }

    // MARK: - 勝ち画面

    private var winScreen: some View {
        stepScaffold {
            VStack(alignment: .center, spacing: 18) {
                CharacterView(.relief, size: DesignTokens.CharacterSize.support)
                    .frame(
                        width: DesignTokens.CharacterSize.support * (96.0 / 86.0),
                        height: DesignTokens.CharacterSize.support
                    )
                    .background(DesignTokens.card)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(DesignTokens.hairline, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .characterPop(.celebrate)

                Text(String(localized: "intervention.success.title", defaultValue: "開かなかった\n自分の時間に戻る"))
                    .dopaFont(32, weight: .black, lineSpacing: 4)
                    .foregroundStyle(DesignTokens.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(
                    String(
                        localized: "intervention.success.daily_attempt",
                        defaultValue: "今日\(flow.todayAttemptDisplayCount)回目"
                    )
                )
                    .dopaFont(15, weight: .semibold)
                    .foregroundStyle(DesignTokens.secondaryText)

                if let goal = flow.goals.first {
                    CardContainer {
                        VStack(alignment: .leading, spacing: 8) {
                            SmallLabel(text: String(localized: "intervention.goal.eyebrow", defaultValue: "YOUR GOAL"))
                            Text(goal.title)
                                .dopaFont(17, weight: .bold)
                                .foregroundStyle(DesignTokens.primaryText)
                        }
                    }
                }

                CardContainer {
                    HStack(spacing: 18) {
                        metricColumn(
                            label: String(
                                localized: "intervention.success.metric.cancelled",
                                defaultValue: "開かずに戻れた"
                            ),
                            value: todayCancelledCountText
                        )
                        Rectangle()
                            .fill(DesignTokens.hairline)
                            .frame(width: 1, height: 54)
                        metricColumn(
                            label: String(
                                localized: "intervention.success.metric.attempted",
                                defaultValue: "開こうとした"
                            ),
                            value: todayAttemptCountText
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity)
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

    // MARK: - Helpers

    private var target: SNSAppCatalogItem { flow.target }

    private var todayCancelledCountText: String {
        String(
            localized: "intervention.success.cancelled_count",
            defaultValue: "\(flow.todayCancelledCountForDisplay)"
        )
    }

    private var todayAttemptCountText: String {
        String(
            localized: "intervention.success.attempt_count",
            defaultValue: "\(flow.todayAttemptCountForDisplay)"
        )
    }

    private func metricColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .dopaFont(13, weight: .semibold)
                .foregroundStyle(DesignTokens.secondaryText)
            Text(value)
                .dopaFont(30, weight: .bold, design: .rounded)
                .monospacedDigit()
                .foregroundStyle(DesignTokens.accent)
                // 数字が増えるところは桁を回して見せる。
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 「開かずに戻れた / 3」を1つの読み上げにまとめる。
        .accessibilityElement(children: .combine)
    }

    /// - Parameter hasAction: CTAを持たない段階では `false`。
    ///   `EmptyView` を渡しても余白と背景は残るため、固定バー自体を作らないことで
    ///   本文の安全領域が30pt無駄に縮むのを防ぐ。
    private func stepScaffold<Content: View, Action: View>(
        hasAction: Bool = true,
        @ViewBuilder content: () -> Content,
        @ViewBuilder action: () -> Action
    ) -> some View {
        ScrollView {
            content()
                .padding(.horizontal, 20)
                .padding(.top, 60)
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
                body: String(localized: "intervention.day_context.morning.body", defaultValue: "その日の集中を決める時間")
            )
        case .sleep:
            dayTimeContextBanner(
                title: String(localized: "intervention.day_context.night.title", defaultValue: "眠る前の数分"),
                body: String(localized: "intervention.day_context.night.body", defaultValue: "その日の睡眠の質を決める時間")
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
