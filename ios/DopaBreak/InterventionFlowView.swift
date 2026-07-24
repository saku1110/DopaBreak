import DopaBreakCore
import SwiftUI

/// 一呼吸フロー全体（S-01〜S-05・doc12 §2 / doc11 §7）。
/// AppIntent / URLスキーム経由で起動され、fullScreenCoverとして表示される。
struct InterventionFlowView: View {
    let onFinished: () -> Void

    @State private var flow: InterventionFlowModel

    init(target: SNSAppCatalogItem, model: AppModel, settingsStore: SettingsStore, onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
        _flow = State(initialValue: InterventionFlowModel(target: target, model: model, settingsStore: settingsStore))
    }

    var body: some View {
        ZStack {
            DesignTokens.background.ignoresSafeArea()
            content
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

            Spacer()

            VStack(spacing: 28) {
                VStack(spacing: 14) {
                    Text(
                        String(
                            localized: "intervention.breath.countdown",
                            defaultValue: "\(flow.breathRemainingSeconds)"
                        )
                    )
                        .font(.system(size: 92, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(DesignTokens.primaryText)
                        .contentTransition(.numericText())

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(DesignTokens.hairline)
                            Capsule()
                                .fill(DesignTokens.accent)
                                .frame(
                                    width: proxy.size.width
                                        * CGFloat(flow.breathRemainingSeconds)
                                        / CGFloat(max(flow.breathTotalSeconds, 1))
                                )
                        }
                    }
                    .frame(width: 150, height: 5)
                }
                .padding(30)
                .background(DesignTokens.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(DesignTokens.hairline, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(spacing: 8) {
                    Text(String(localized: "intervention.breath.title", defaultValue: "ひと呼吸おきましょう"))
                        .font(.system(size: 24, weight: .black))
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

            Spacer()
        }
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
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.primaryText)
                    .tracking(-2)
                titleText(String(localized: "intervention.usage_summary.title", defaultValue: "すでに開いています"))
                CardContainer {
                    VStack(alignment: .leading, spacing: 7) {
                        SmallLabel(text: String(localized: "intervention.goal.eyebrow", defaultValue: "YOUR GOAL"))
                        Text(
                            flow.goals.first?.title
                                ?? String(localized: "intervention.goal.fallback", defaultValue: "開く目的を確かめる")
                        )
                            .font(.system(size: 18, weight: .bold))
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
                                        .font(.system(size: 18, weight: .bold))
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
        stepScaffold {
            VStack(alignment: .leading, spacing: 20) {
                SmallLabel(text: String(localized: "intervention.intent.eyebrow", defaultValue: "INTENT"))
                titleText(String(localized: "intervention.intent.title", defaultValue: "何のために\n開きますか？"))
                Text(String(localized: "intervention.intent.description", defaultValue: "目的が明確なら、一呼吸を省いてすぐ進めます"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(InterventionReason.allCases) { reason in
                        Button {
                            flow.selectReason(reason)
                        } label: {
                            VStack(alignment: .leading, spacing: 18) {
                                Image(systemName: reasonSymbol(reason))
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(DesignTokens.primaryText)
                                Text(reason.displayTitle)
                                    .font(.system(size: 16, weight: .bold))
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
                titleText(String(localized: "intervention.decision.title", defaultValue: "本当に今、\n必要ですか？"))
                if let reason = flow.selectedReason {
                    CardContainer {
                        HStack {
                            Image(systemName: reasonSymbol(reason))
                                .foregroundStyle(DesignTokens.accent)
                            Text(reason.displayTitle)
                                .font(.system(size: 16, weight: .bold))
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
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(DesignTokens.primaryText)
                                if reason.interventionStyle == .direct {
                                    Text(
                                        String(
                                            localized: "intervention.duration.fast_path_note",
                                            defaultValue: "目的が明確なため、一呼吸を省きました"
                                        )
                                    )
                                        .font(.system(size: 12, weight: .medium))
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
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(InterventionDuration.allCases) { duration in
                        Button {
                            flow.chooseDuration(duration)
                        } label: {
                            Text(duration.displayTitle)
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    flow.selectedDuration == duration
                                        ? DesignTokens.accent
                                        : DesignTokens.primaryText
                                )
                                .frame(maxWidth: .infinity, minHeight: 84)
                                .background(DesignTokens.card)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(
                                            flow.selectedDuration == duration
                                                ? DesignTokens.accent
                                                : DesignTokens.hairline,
                                            lineWidth: 1
                                        )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(notificationMessage)
                    .font(.system(size: 13, weight: .medium))
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
                    .font(.system(size: 15, weight: .semibold))
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
        stepScaffold {
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
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(DesignTokens.secondaryText)
                    }
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(DesignTokens.accent)
                        .frame(maxWidth: 220)
                    Text(notificationMessage)
                        .font(.system(size: 13, weight: .medium))
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
                Image(systemName: "checkmark")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(DesignTokens.accent)
                    .frame(width: 96, height: 86)
                    .background(DesignTokens.card)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(DesignTokens.hairline, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                Text(String(localized: "intervention.success.title", defaultValue: "開かなかった\n自分の時間に戻る"))
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(DesignTokens.primaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(
                    String(
                        localized: "intervention.success.daily_attempt",
                        defaultValue: "今日\(flow.todayAttemptDisplayCount)回目"
                    )
                )
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignTokens.secondaryText)

                if let goal = flow.goals.first {
                    CardContainer {
                        VStack(alignment: .leading, spacing: 8) {
                            SmallLabel(text: String(localized: "intervention.goal.eyebrow", defaultValue: "YOUR GOAL"))
                            Text(goal.title)
                                .font(.system(size: 17, weight: .bold))
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignTokens.secondaryText)
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepScaffold<Content: View, Action: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                content()
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom, 40)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            action()
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 18)
                .background(DesignTokens.background)
        }
    }

    private func titleText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 32, weight: .black))
            .foregroundStyle(DesignTokens.primaryText)
            .lineSpacing(5)
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
                    .font(.system(size: 15, weight: .semibold))
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
