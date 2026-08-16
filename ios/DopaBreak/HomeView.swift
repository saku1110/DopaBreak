import DopaBreakCore
import SwiftUI

struct HomeView: View {
    let model: AppModel
    let settingsStore: SettingsStore
    @State private var editorRoute: GoalEditorRoute?
    @State private var isAutomationGuidePresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroBand
                if !unverifiedAutomationTargets.isEmpty {
                    automationStatusBanner
                        .padding(.top, 20)
                        .padding(.horizontal, DesignTokens.horizontalPadding)
                }
                goalSection
                    .padding(.top, 20)
                if isFirstDayEmpty {
                    firstDayEmptySection
                        .padding(.top, 44)
                } else {
                    achievementSection
                        .padding(.top, 28)
                    weekSignal
                        .padding(.top, 24)
                }
            }
            .padding(.bottom, 28)
        }
        .dopaScreenBackground()
        .onAppear {
            model.refresh()
            model.isChildModalActive = isAnyChildModalPresented
        }
        .onChange(of: isAnyChildModalPresented) { _, isPresented in
            model.isChildModalActive = isPresented
        }
        .sheet(item: $editorRoute) { route in
            GoalEditorSheet(model: model, goal: route.goal)
        }
        .sheet(isPresented: $isAutomationGuidePresented) {
            AutomationGuideView(model: model, settingsStore: settingsStore)
        }
    }

    private var isAnyChildModalPresented: Bool {
        editorRoute != nil || isAutomationGuidePresented
    }

    private var automationStatusBanner: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                Text(automationStatusTitle)
                    .dopaFont(20, weight: .black)
                    .foregroundStyle(DesignTokens.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(localized: "home.automation_status.body", defaultValue: "対象アプリを開いたときに一呼吸が出れば設定完了です。"))
                    .dopaFont(14, weight: .semibold, lineSpacing: 4)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Button(String(localized: "home.automation_status.action", defaultValue: "設定を確認")) {
                    isAutomationGuidePresented = true
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var heroBand: some View {
        VStack(spacing: 12) {
            HStack {
                SmallLabel(text: String(localized: "home.hero.today", defaultValue: "TODAY ・ \(todayText)"))
                Spacer()
                if !isFirstDayEmpty {
                    Text(String(localized: "home.hero.week_count", defaultValue: "\(model.weekCancelledCount)回 / 今週"))
                        .dopaFont(12, weight: .bold, design: .monospaced)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(DesignTokens.background.opacity(0.72))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, DesignTokens.horizontalPadding)
            .padding(.top, 18)

            CharacterView(
                model.todayAttemptCount > 0 && model.todayCancelledCount == 0 ? .doom : .awake,
                size: DesignTokens.CharacterSize.header
            )
            .frame(maxWidth: .infinity)
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
                        SmallLabel(text: String(localized: "home.goal.label", defaultValue: "あなたの目標"))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .dopaFont(12, weight: .bold)
                            .foregroundStyle(DesignTokens.secondaryText)
                    }

                    Text(primaryGoalTitle)
                        .dopaFont(
                            hasPrimaryGoal ? 22 : 20,
                            weight: hasPrimaryGoal ? .black : .bold,
                            tracking: hasPrimaryGoal ? -0.4 : 0
                        )
                        .foregroundStyle(hasPrimaryGoal ? DesignTokens.primaryText : DesignTokens.accent)
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
                    SmallLabel(text: String(localized: "home.goal.label", defaultValue: "あなたの目標"))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .dopaFont(12, weight: .bold)
                        .foregroundStyle(DesignTokens.secondaryText)
                }

                Text(primaryGoalTitle)
                    .dopaFont(
                        hasPrimaryGoal ? 29 : 20,
                        weight: hasPrimaryGoal ? .black : .bold,
                        tracking: hasPrimaryGoal ? -0.7 : 0
                    )
                    .foregroundStyle(hasPrimaryGoal ? DesignTokens.primaryText : DesignTokens.accent)
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
            Text(String(localized: "home.first_day.title", defaultValue: "開こうとした瞬間に一呼吸が入ります"))
                .dopaFont(38, weight: .black, tracking: -0.8, lineSpacing: 5)
                .foregroundStyle(DesignTokens.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(String(localized: "home.first_day.body", defaultValue: "開かなかった回数がここに残ります"))
                .dopaFont(15, weight: .semibold, lineSpacing: 4)
                .foregroundStyle(DesignTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignTokens.horizontalPadding)
    }

    private var achievementSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(model.todayCancelledCount)")
                    .dopaFont(82, weight: .black, design: .rounded, tracking: -3)
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.accent)
                    // 記録が増えた瞬間に桁が回る。達成が「起きたこと」として見える。
                    .contentTransition(.numericText())
                    // 数字ヒーローは最大文字サイズでも1行に収める。
                    .dopaDisplayClamp()
                Text(String(localized: "home.achievement.count_unit", defaultValue: "回"))
                    .dopaFont(30, weight: .black)
                    .foregroundStyle(DesignTokens.accent)
            }
            .animation(DopaMotion.control, value: model.todayCancelledCount)
            // 「12」「回」を別々に読ませない。
            .accessibilityElement(children: .combine)

            Text(String(localized: "home.achievement.title", defaultValue: "今日 開かなかった"))
                .dopaFont(24, weight: .black)
                .foregroundStyle(DesignTokens.primaryText)

            if model.todayAttemptCount == 0 {
                Text(String(localized: "home.achievement.empty_body", defaultValue: "今日はまだ開こうとしていません"))
                    .dopaFont(14, weight: .semibold)
                    .foregroundStyle(DesignTokens.secondaryText)
            } else {
                Text(String(localized: "home.achievement.summary", defaultValue: "開こうとしたのは\(model.todayAttemptCount)回"))
                    .dopaFont(14, weight: .semibold)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignTokens.horizontalPadding)
    }

    private var weekSignal: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                SmallLabel(text: String(localized: "home.week.eyebrow", defaultValue: "THIS WEEK"))
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DesignTokens.hairline)
                        Capsule()
                            .fill(DesignTokens.accent)
                            .frame(width: proxy.size.width * weekSuccessRate)
                    }
                }
                .frame(height: 5)
                .animation(DopaMotion.transition, value: weekSuccessRate)
                .accessibilityHidden(true)
                Text(String(localized: "home.week.summary", defaultValue: "今週 開かなかったのは\(model.weekCancelledCount)回"))
                    .dopaFont(14, weight: .bold)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
        }
        .padding(.horizontal, DesignTokens.horizontalPadding)
    }

    private var primaryGoalTitle: String {
        model.goals.first?.title ?? String(localized: "home.goal.fallback", defaultValue: "タップして目標を追加")
    }

    private var hasPrimaryGoal: Bool {
        model.goals.first != nil
    }

    private var unverifiedAutomationCatalogIDs: [String] {
        AutomationVerification.unverifiedCatalogIDs(
            selectedCatalogIDs: (try? model.targetStore.selectedCatalogIDs()) ?? [],
            verifiedCatalogIDs: settingsStore.verifiedAutomationCatalogIDs
        )
    }

    private var unverifiedAutomationTargets: [SNSAppCatalogItem] {
        unverifiedAutomationCatalogIDs.compactMap { SNSAppCatalog.app(catalogID: $0) }
    }

    private var automationStatusTitle: String {
        if unverifiedAutomationTargets.count == 1,
           let target = unverifiedAutomationTargets.first {
            return String(localized: "home.automation_status.title_single", defaultValue: "\(target.displayName)の一呼吸はまだ動いていません")
        }
        return String(localized: "home.automation_status.title_multiple", defaultValue: "\(unverifiedAutomationCatalogIDs.count)個のアプリで一呼吸がまだ動いていません")
    }

    private var isFirstDayEmpty: Bool {
        model.todayAttemptCount == 0 && model.weekAttemptCount == 0
    }

    private var weekSuccessRate: CGFloat {
        guard model.weekAttemptCount > 0 else { return 0 }
        return min(1, CGFloat(model.weekCancelledCount) / CGFloat(model.weekAttemptCount))
    }

    private var todayText: String {
        Date.now.formatted(.dateTime.month().day())
    }
}
