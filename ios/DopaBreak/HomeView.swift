import DopaBreakCore
import SwiftUI

struct HomeView: View {
    let model: AppModel
    @State private var editorRoute: GoalEditorRoute?
    @State private var isPaywallPresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroBand
                goalSection
                    .padding(.top, 20)
                if isFirstDayEmpty {
                    firstDayEmptySection
                        .padding(.top, 44)
                } else {
                    achievementSection
                        .padding(.top, 28)
                    metricsCard
                        .padding(.top, 26)
                    weekSignal
                        .padding(.top, 16)
                }
            }
            .padding(.bottom, 28)
        }
        .dopaScreenBackground()
        .onAppear { model.refresh() }
        .sheet(item: $editorRoute) { route in
            GoalEditorSheet(model: model, goal: route.goal)
        }
        .fullScreenCover(isPresented: $isPaywallPresented) {
            PaywallView(storeService: model.storeService)
        }
    }

    private var heroBand: some View {
        ZStack(alignment: .topLeading) {
            MorningHorizon(height: 132, alignment: .center, bottomFade: 0.97)

            HStack {
                SmallLabel(text: "TODAY ・ \(todayText)")
                Spacer()
                if !isFirstDayEmpty {
                    Text("\(model.weekCancelledCount)回 / 今週")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(DesignTokens.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(DesignTokens.background.opacity(0.72))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, DesignTokens.horizontalPadding)
            .padding(.top, 18)
        }
    }

    @ViewBuilder
    private var goalSection: some View {
        if isFirstDayEmpty {
            firstDayGoalCard
        } else {
            standardGoalSection
        }
    }

    private var firstDayGoalCard: some View {
        Button {
            editorRoute = GoalEditorRoute(goal: model.goals.first)
        } label: {
            CardContainer {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        SmallLabel(text: "あなたの目標")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DesignTokens.secondaryText)
                    }

                    Text(primaryGoalTitle)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(DesignTokens.primaryText)
                        .tracking(-0.4)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.horizontal, DesignTokens.horizontalPadding)
        }
        .buttonStyle(.plain)
    }

    private var standardGoalSection: some View {
        Button {
            editorRoute = GoalEditorRoute(goal: model.goals.first)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SmallLabel(text: "あなたの目標")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignTokens.secondaryText)
                }

                Text(primaryGoalTitle)
                    .font(.system(size: 29, weight: .black))
                    .foregroundStyle(DesignTokens.primaryText)
                    .tracking(-0.7)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignTokens.horizontalPadding)
        }
        .buttonStyle(.plain)
    }

    private var firstDayEmptySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("最初のひと呼吸から\n今日が始まる")
                .font(.system(size: 38, weight: .black))
                .foregroundStyle(DesignTokens.primaryText)
                .tracking(-0.8)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            Text("対象アプリを開こうとすると、ここに記録がつきます")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignTokens.secondaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignTokens.horizontalPadding)
    }

    private var achievementSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(model.todayCancelledCount)")
                    .font(.system(size: 82, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.accent)
                    .tracking(-3)
                Text("回")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(DesignTokens.accent)
            }

            Text("今日、自分で選べた")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(DesignTokens.primaryText)

            if model.todayAttemptCount == 0 {
                Text("最初の選択から、今日の記録が始まります")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignTokens.secondaryText)
            } else {
                Text("開こうとした\(model.todayAttemptCount)回のうち、\(successRateText)で立ち止まれました")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignTokens.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignTokens.horizontalPadding)
    }

    private var metricsCard: some View {
        CardContainer {
            HStack(spacing: 18) {
                homeMetric(value: "\(model.todayCancelledCount)回", label: "開かずに戻れた", accent: true)
                Rectangle()
                    .fill(DesignTokens.hairline)
                    .frame(width: 1, height: 58)
                homeMetric(value: "\(model.todayAttemptCount)回", label: "開こうとした")
            }
        }
        .padding(.horizontal, DesignTokens.horizontalPadding)
    }

    private var weekSignal: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                SmallLabel(text: "THIS WEEK")
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DesignTokens.hairline)
                        Capsule()
                            .fill(DesignTokens.accent)
                            .frame(width: proxy.size.width * weekSuccessRate)
                    }
                }
                .frame(height: 5)
                Text("今週 \(model.weekCancelledCount)回、自分で選び直しました")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DesignTokens.secondaryText)
            }
        }
        .padding(.horizontal, DesignTokens.horizontalPadding)
    }

    private func homeMetric(value: String, label: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(value)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accent ? DesignTokens.accent : DesignTokens.primaryText)
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DesignTokens.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var primaryGoalTitle: String {
        model.goals.first?.title ?? "SNSの先ではなく、戻りたい先を決める"
    }

    private var isFirstDayEmpty: Bool {
        model.todayAttemptCount == 0 && model.weekAttemptCount == 0
    }

    private var successRate: CGFloat {
        guard model.todayAttemptCount > 0 else { return 0 }
        return min(1, CGFloat(model.todayCancelledCount) / CGFloat(model.todayAttemptCount))
    }

    private var weekSuccessRate: CGFloat {
        guard model.weekAttemptCount > 0 else { return 0 }
        return min(1, CGFloat(model.weekCancelledCount) / CGFloat(model.weekAttemptCount))
    }

    private var successRateText: String {
        "\(Int((successRate * 100).rounded()))%"
    }

    private var todayText: String {
        Date.now.formatted(.dateTime.month().day())
    }
}
