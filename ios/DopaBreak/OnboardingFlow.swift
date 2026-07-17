import DopaBreakCore
import Foundation
import SwiftUI
import UIKit
import UserNotifications

private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case selfCheck
    case quizAimless
    case quizRegret
    case quizResult
    case chooseApps
    case goalSetup
    case chooseMode
    case preview
    case whyScience
    case permission
    case notificationGuide
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
        .accessibilityLabel("今日の24時間のうち、現在時刻までの経過を示しています")
    }

    private func ledger(at date: Date) -> some View {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let currentHour = components.hour ?? 0
        let currentMinute = components.minute ?? 0

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SmallLabel(text: "TODAY / 1,440 MINUTES")
                Spacer()
                Text(String(format: "%02d:%02d", currentHour, currentMinute))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
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
                Text("過ぎた時間")
                Spacer()
                Text("24")
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(DesignTokens.tertiaryText)

            HStack(spacing: 9) {
                Circle()
                    .fill(DesignTokens.accent)
                    .frame(width: 6, height: 6)
                Text("今日という時間は、いまも減り続けている。")
                    .font(.system(size: 13, weight: .bold))
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
    private let usageOptions = ["5回未満", "5〜15回", "15〜30回", "30回以上"]
    private let frequencyOptions = ["全くない", "数日", "半分以上", "ほとんど毎日"]
    private let goalPresets = ["読書を30分", "筋トレを続ける", "資格の勉強"]

    @State private var step: OnboardingStep = .welcome
    @State private var direction: SlideDirection = .forward
    @State private var usageBucket: String?
    @State private var aimlessScrollBucket: String?
    @State private var regretBucket: String?
    @State private var selfCheckSnapshot: SelfCheckSnapshot?
    @State private var selectedCatalogIDs: [String] = []
    @State private var appSelectionMessage: String?
    @State private var heroGoal = ""
    @State private var lockScreenTitle = ""
    @State private var goalCategory: GoalCategory = .other
    @State private var isLockScreenTitleExpanded = false
    @State private var selectedMode: InterventionMode = .standard
    @State private var showDeepFocusConfirmation = false
    @State private var notificationMessage: String?
    @State private var isRequestingNotifications = false
    @State private var isPaywallPresented = false
    @State private var flowAlert: OnboardingAlert?

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
                dismissButton: .default(Text("閉じる"))
            )
        }
        .fullScreenCover(isPresented: $isPaywallPresented, onDismiss: {
            if step == .prePaywallSummary {
                advance()
            }
        }) {
            PaywallView(storeService: model.storeService)
        }
        .alert("Deep Focusは強めの設定です", isPresented: $showDeepFocusConfirmation) {
            Button("Deep Focusで始める") {
                persistModeAndAdvance(.deepFocus)
            }
            Button("通常モードにする") {
                selectedMode = .standard
                persistModeAndAdvance(.standard)
            }
        } message: {
            Text("集中時間中は、簡単にはSNSを開けません。")
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var onboardingBackdrop: some View {
        DesignTokens.background.ignoresSafeArea()
        if step == .welcome || step == .ready {
            MorningHorizon(height: 470, alignment: .top, bottomFade: 0.98)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea(edges: .top)
                .transition(.opacity)
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 10) {
            HStack {
                if step.previous != nil {
                    Button {
                        goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .bold))
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
                }
            }
            .frame(height: 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var pager: some View {
        ZStack {
            currentContent
                .id(step)
                .transition(slideTransition)
        }
        .animation(.easeInOut(duration: 0.24), value: step)
    }

    private var slideTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: direction.insertionEdge).combined(with: .opacity),
            removal: .move(edge: direction.removalEdge).combined(with: .opacity)
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
        case .prePaywallSummary:
            prePaywallSummaryContent
        case .ready:
            readyContent
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        switch step {
        case .quizAimless, .quizRegret:
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
            primaryButton("はじめる") { advance() }
        case .selfCheck:
            primaryButton("次へ", enabled: usageBucket != nil) { advance() }
        case .quizResult:
            primaryButton("この時間を、変える") { advance() }
        case .chooseApps:
            primaryButton(selectedCatalogIDs.isEmpty ? "アプリを選ぶ" : "\(selectedCatalogIDs.count)つのアプリをブロック") {
                persistSelectedAppsAndAdvance()
            }
        case .goalSetup:
            primaryButton("次へ") { saveGoalAndAdvance(skipped: false) }
        case .chooseMode:
            primaryButton("この設定で進む") { confirmModeIfNeeded() }
        case .preview:
            primaryButton("なるほど、続ける") { advance() }
        case .whyScience:
            primaryButton("続ける") { advance() }
        case .permission:
            VStack(spacing: 10) {
                primaryButton("ショートカットを開く") { openShortcutsAndAdvance() }
                Text("設定できたかどうかは 対象アプリを開いたときに自動で確認されます")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        case .notificationGuide:
            primaryButton("通知をオンにする", enabled: !isRequestingNotifications) {
                Task { await requestNotifications() }
            }
        case .prePaywallSummary:
            primaryButton("続ける") { isPaywallPresented = true }
        case .ready:
            primaryButton("DopaBreakをはじめる") { onComplete() }
        case .quizAimless, .quizRegret:
            EmptyView()
        }
    }

    @ViewBuilder
    private var secondaryAction: some View {
        switch step {
        case .goalSetup:
            textOnlyButton("あとで設定する") { saveGoalAndAdvance(skipped: true) }
        case .permission:
            secondaryButton("あとで") { advance() }
        case .notificationGuide:
            secondaryButton("あとで") { advance() }
        case .prePaywallSummary:
            secondaryButton("あとで") { advance() }
        default:
            EmptyView()
        }
    }
}

private extension OnboardingFlow {
    var welcomeContent: some View {
        screenScroll {
            centeredEyebrow("DOPABREAK")

            Spacer(minLength: 292)

            VStack(alignment: .center, spacing: 22) {
                Text("人生の時間は\n二度と戻らない")
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(DesignTokens.primaryText)
                    .lineSpacing(2)
                    .tracking(-1)
                    .minimumScaleFactor(0.74)
                    .multilineTextAlignment(.center)

                centeredLead("そのスクロールが、いちばん高くついている。")

                Text("開く前に、選び直す")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DesignTokens.accent)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    var selfCheckContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                centeredEyebrow("質問 1 / 3")
                centeredLead("回答は端末内にのみ保存されます。")

                optionSection(title: "1日に何回、無意識にSNSを開いていますか？") {
                    singleSelectOptions(usageOptions, selection: $usageBucket)
                }

                centeredLead("平均的な人は1日96回スマホを手に取ります。")
            }
        }
    }

    var aimlessQuizContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 26) {
                centeredEyebrow("質問 2 / 3")
                centeredLead("この2週間、次のことはどれくらい当てはまりますか？")
                centeredTitle("気づけば、目的もなく\nスクロールしている")
                frequencyButtons(selection: aimlessScrollBucket) { option in
                    aimlessScrollBucket = option
                    advance()
                }
            }
        }
    }

    var regretQuizContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 26) {
                centeredEyebrow("質問 3 / 3")
                centeredLead("SNSを閉じたあとの気持ちは")
                centeredTitle("「時間を溶かした」と\n感じることがある")
                frequencyButtons(selection: regretBucket) { option in
                    regretBucket = option
                    if persistSelfCheckSnapshot() {
                        advance()
                    }
                }
            }
        }
    }

    var quizResultContent: some View {
        let estimate = currentEstimate
        return screenScroll {
            VStack(alignment: .center, spacing: 24) {
                centeredEyebrow("推計結果 / YOUR RESULT")
                centeredLead("あなたの回答にもとづく推計では")

                VStack(alignment: .center, spacing: 16) {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(dailyTimeText(minutes: estimate.dailyMinutes))
                            .font(.system(size: 70, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(DesignTokens.accent)
                        Text("/ 日")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(DesignTokens.primaryText)
                    }

                    centeredLead("が毎日、SNSに溶けています")

                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("1年に換算すると 約")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(DesignTokens.primaryText)
                        Text("\(estimate.yearlyDays)")
                            .font(.system(size: 58, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(DesignTokens.accent)
                        Text("日")
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(DesignTokens.primaryText)
                    }
                }

                centeredLead("※ご回答からの推計値です。医療診断ではありません。")
                    .padding(.top, 8)

                centeredLead("眠る時間を除けば、起きている人生の約1年分以上に相当します。")
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    var chooseAppsContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                centeredEyebrow("STEP 02 / 04")
                centeredTitle("止めたいアプリを選ぶ")
                centeredLead("いつでも変更できます。")

                VStack(spacing: 10) {
                    ForEach(SNSAppCatalog.all) { item in
                        catalogAppButton(item)
                    }
                }

                if let appSelectionMessage {
                    messageCard(appSelectionMessage)
                }
            }
        }
    }

    var goalSetupContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 22) {
                centeredEyebrow("あなたの目標 / GOAL")
                centeredTitle("空いたこの時間で\n何をしますか？")

                fieldContainer {
                    TextField("例: 英語で話せるようになる", text: $heroGoal, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DesignTokens.primaryText)
                        .onChange(of: heroGoal) { _, value in
                            trim($heroGoal, to: 40, value: value)
                        }
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 96), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(goalPresets, id: \.self) { preset in
                        goalPresetChip(preset)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isLockScreenTitleExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text("ロック画面に出す短い言葉(任意)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(DesignTokens.secondaryText)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(DesignTokens.secondaryText)
                                .rotationEffect(.degrees(isLockScreenTitleExpanded ? 90 : 0))
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        .background(DesignTokens.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(DesignTokens.hairline, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(isLockScreenTitleExpanded ? "展開中" : "折りたたみ中")

                    if isLockScreenTitleExpanded {
                        fieldContainer {
                            TextField("例: 英語で話す", text: $lockScreenTitle)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(DesignTokens.primaryText)
                                .onChange(of: lockScreenTitle) { _, value in
                                    trim($lockScreenTitle, to: 16, value: value)
                                }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    var chooseModeContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                centeredEyebrow("STEP 04 / 04")
                centeredTitle("どのくらい強く\n止めますか？")
                centeredLead("生活に合う強さを選べます。")

                VStack(spacing: 12) {
                    ForEach(InterventionMode.allCases, id: \.self) { mode in
                        modeButton(mode)
                    }
                }
            }
        }
    }
}

private extension OnboardingFlow {
    var previewContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 22) {
                centeredEyebrow("PREVIEW")
                centeredTitle("SNSを開こうとすると、\nこうなります")
                centeredLead("目的を確かめて、必要なときだけ意図して開けるようにします。")

                CardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        numberedLine("1. 何のために開くか確認する")
                        numberedLine("2. 仕事や連絡なら、すぐ時間を選ぶ")
                        numberedLine("3. 暇つぶしなら、一呼吸して選び直す")
                        numberedLine("4. 使った後の満足感を振り返る")
                    }
                }

                CardContainer {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("何のために開く？")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(DesignTokens.primaryText)
                        previewChoice("開かない", highlighted: true)
                        previewChoice("理由を選んで続ける", highlighted: false)
                    }
                }
            }
        }
    }

    var whyScienceContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 22) {
                centeredEyebrow("WHY IT WORKS / 科学的背景")
                centeredTitle("意志の力では、\n勝てない。")
                centeredLead("つい開いてしまうのは、あなたが弱いからではありません。SNSは無意識の起動を狙って設計されています。")

                CardContainer {
                    VStack(alignment: .leading, spacing: 14) {
                        principleLine("1. 摩擦", "反射的な起動に一拍置く")
                        principleLine("2. 実行意図", "開く前に理由を言語化する")
                        principleLine("3. 自己モニタリング", "今日何回目かを見る")
                        principleLine("4. 自己観察", "見た後の満足感を記録する")
                    }
                }

                centeredLead(
                    "開く前にワンクッション置く手法は、\n査読付き研究（PNAS, 2023）で\nSNS利用を平均57%減らすことが\n示されています。"
                )

                VStack(alignment: .leading, spacing: 8) {
                    bodyText("※他社アプリ(one sec)を対象とした研究です。")
                    bodyText("※本アプリの効果を保証するものではありません。")
                    bodyText("※医療・治療を目的としたアプリではありません。")
                }
            }
        }
    }

    var automationGuideContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 22) {
                centeredTitle("自動で一呼吸を出す設定")
                centeredLead("ショートカットのオートメーションで、選んだアプリを開いたときにDopaBreakを起動します。")

                CardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        numberedLine("1. オートメーションを開く")
                        numberedLine("2. ＋を押してAppを選ぶ")
                        numberedLine("3. 対象アプリを選び開かれたときを選ぶ")
                        numberedLine("4. すぐに実行を選ぶ")
                        numberedLine("5. アクションでDopaBreakで一呼吸を選ぶ")
                    }
                }

                CardContainer {
                    VStack(alignment: .leading, spacing: 10) {
                        SmallLabel(text: "設定するアプリ")
                        if selectedTargets.isEmpty {
                            Text("先に止めるアプリを選んでください。")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(DesignTokens.secondaryText)
                        } else {
                            ForEach(selectedTargets) { target in
                                Text(target.displayName)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(DesignTokens.primaryText)
                            }
                        }
                    }
                }

            }
        }
    }

    var notificationGuideContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                centeredEyebrow("NOTIFICATION")
                centeredTitle("ロック画面に、\n戻る先を")
                centeredLead("朝の通知とLive Activityで、目標を毎日思い出します。")

                ZStack(alignment: .bottom) {
                    MorningHorizon(height: 300, alignment: .center, bottomFade: 0.78)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            SmallLabel(text: "DOPABREAK")
                            Spacer()
                            SmallLabel(text: "今")
                        }
                        Text(notificationGoalText)
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(DesignTokens.primaryText)
                            .lineLimit(2)
                        HStack(spacing: 6) {
                            Text("今日")
                                .foregroundStyle(DesignTokens.secondaryText)
                            Text("\(model.todayCancelledCount)回")
                                .foregroundStyle(DesignTokens.accent)
                            Text("開かずに戻れた")
                                .foregroundStyle(DesignTokens.secondaryText)
                        }
                        .font(.system(size: 14, weight: .bold))
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
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(DesignTokens.hairline, lineWidth: 1)
                }

                if let notificationMessage {
                    messageCard(notificationMessage)
                }
            }
        }
    }

    var prePaywallSummaryContent: some View {
        screenScroll {
            VStack(alignment: .leading, spacing: 24) {
                centeredEyebrow("あなた専用プラン / READY")
                centeredTitle("準備が、整いました")
                centeredLead("この設定で、無意識にSNSを開く瞬間をDopaBreakが止めます。")

                CardContainer {
                    VStack(spacing: 0) {
                        summaryRow(label: "止めるアプリ", value: selectedAppsSummary)
                        divider
                        summaryRow(label: "戻る先", value: goalSummaryText.isEmpty ? "未設定" : goalSummaryText)
                        divider
                        summaryRow(label: "取り戻せる時間", value: "年 約\(summaryYearlyDays)日分")
                    }
                }

                centeredLead("開く前に選べる状態を、今日から始めます。")
            }
        }
    }

    var readyContent: some View {
        screenScroll {
            VStack(alignment: .center, spacing: 26) {
                Image(systemName: "checkmark")
                    .font(.system(size: 58, weight: .heavy))
                    .foregroundStyle(DesignTokens.accent)
                    .frame(width: 136, height: 96)
                    .background(DesignTokens.accent.opacity(0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(DesignTokens.accent.opacity(0.42), lineWidth: 2)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(spacing: 12) {
                    titleText("準備完了。")
                        .multilineTextAlignment(.center)
                    bodyText("今日から、開く前に選び直す。")
                        .multilineTextAlignment(.center)
                }

                if !goalSummaryText.isEmpty {
                    CardContainer {
                        VStack(alignment: .leading, spacing: 10) {
                            SmallLabel(text: "あなたの目標")
                            Text(goalSummaryText)
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(DesignTokens.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
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
            .font(.system(size: 34, weight: .black))
            .foregroundStyle(DesignTokens.primaryText)
            .lineSpacing(5)
            .minimumScaleFactor(0.74)
    }

    func bodyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(DesignTokens.secondaryText)
            .lineSpacing(5)
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

    func optionSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(DesignTokens.primaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            content()
        }
    }

    func singleSelectOptions(
        _ options: [String],
        selection: Binding<String?>
    ) -> some View {
        VStack(spacing: 10) {
            ForEach(options, id: \.self) { option in
                optionButton(
                    title: option,
                    isSelected: selection.wrappedValue == option
                ) {
                    selection.wrappedValue = option
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
                optionButton(title: option, isSelected: selection == option) {
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
                    .font(.system(size: 18, weight: .bold))
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
        .buttonStyle(.plain)
    }

    func optionStroke(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(isSelected ? DesignTokens.accent : DesignTokens.hairline, lineWidth: 1)
    }
}

private extension OnboardingFlow {
    func catalogAppButton(_ item: SNSAppCatalogItem) -> some View {
        let isSelected = selectedCatalogIDs.contains(item.catalogID)
        return Button {
            toggleCatalogSelection(item)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: item.symbolName)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(DesignTokens.primaryText)
                    .frame(width: 42, height: 42)
                    .background(DesignTokens.backgroundRaised)
                    .clipShape(Circle())

                Text(item.displayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DesignTokens.primaryText)
                Spacer()
                Image(systemName: isSelected ? "checkmark" : "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isSelected ? DesignTokens.accent : DesignTokens.secondaryText)
            }
            .padding(16)
            .background(DesignTokens.card)
            .overlay(optionStroke(isSelected: isSelected))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    func modeButton(_ mode: InterventionMode) -> some View {
        Button {
            selectMode(mode)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(mode.displayTitle)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(DesignTokens.primaryText)
                    Spacer()
                    if selectedMode == mode {
                        Image(systemName: "checkmark")
                            .foregroundStyle(DesignTokens.accent)
                    }
                }
                Text(mode.detailText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignTokens.secondaryText)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.card)
            .overlay(optionStroke(isSelected: selectedMode == mode))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    func selectMode(_ mode: InterventionMode) {
        guard modeAllowedForCurrentEntitlement(mode) == mode else {
            isPaywallPresented = true
            return
        }
        selectedMode = mode
    }

    func goalPresetChip(_ preset: String) -> some View {
        Button {
            heroGoal = preset
        } label: {
            Text(preset)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(heroGoal == preset ? DesignTokens.background : DesignTokens.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 10)
                .background(heroGoal == preset ? DesignTokens.accent : DesignTokens.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(heroGoal == preset ? DesignTokens.accent : DesignTokens.hairline, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(heroGoal == preset ? .isSelected : [])
    }

    func goalInputBlock(
        label: String,
        placeholder: String,
        text: Binding<String>,
        limit: Int,
        help: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SmallLabel(text: label)
                Spacer()
                Text("\(text.wrappedValue.count)/\(limit)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            fieldContainer {
                TextField(placeholder, text: text, axis: .vertical)
                    .lineLimit(1...3)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DesignTokens.primaryText)
                    .onChange(of: text.wrappedValue) { _, value in
                        trim(text, to: limit, value: value)
                    }
            }

            if let help {
                bodyText(help)
            }
        }
    }

    var categoryBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SmallLabel(text: "カテゴリ")
            fieldContainer {
                Picker("カテゴリ", selection: $goalCategory) {
                    ForEach(GoalCategory.allCases, id: \.self) { category in
                        Text(category.japaneseLabel).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(DesignTokens.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
    }

    func messageCard(_ text: String) -> some View {
        CardContainer {
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignTokens.secondaryText)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func numberedLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(DesignTokens.primaryText)
    }

    func previewChoice(_ text: String, highlighted: Bool) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(highlighted ? DesignTokens.background : DesignTokens.primaryText)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(highlighted ? DesignTokens.accent : DesignTokens.backgroundRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func principleLine(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(DesignTokens.primaryText)
            Text(detail)
                .font(.system(size: 15, weight: .semibold))
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
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DesignTokens.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(.system(size: 17, weight: .black))
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
            return "未設定"
        }
        if targets.count == 1 {
            return first.displayName
        }
        return "\(first.displayName) ほか\(targets.count - 1)件"
    }

    var goalSummaryText: String {
        let lockTitle = trimmed(lockScreenTitle)
        let heroTitle = trimmed(heroGoal)
        return lockTitle.isEmpty ? heroTitle : lockTitle
    }

    var notificationGoalText: String {
        let currentGoal = model.goals.first?.lockScreenTitle ?? model.goals.first?.title
        let localGoal = goalSummaryText
        return localGoal.isEmpty ? (currentGoal ?? "目標を設定すると、ここに表示されます") : localGoal
    }

    var summaryYearlyDays: Int {
        selfCheckSnapshot?.estimatedYearlyDays ?? currentEstimate.yearlyDays
    }

    var currentEstimate: LossEstimator.Estimate {
        let bucket = usageBucket ?? "2-4時間"
        return (try? LossEstimator.estimate(usageBucket: bucket)) ??
            LossEstimator.Estimate(dailyMinutes: 150, yearlyDays: 38)
    }
}

private extension OnboardingFlow {
    func advance() {
        guard let next = step.next else {
            return
        }
        direction = .forward
        withAnimation {
            step = next
        }
    }

    func goBack() {
        guard let previous = step.previous else {
            return
        }
        direction = .backward
        withAnimation {
            step = previous
        }
    }

    func persistSelfCheckSnapshot() -> Bool {
        guard let usageBucket, let aimlessScrollBucket, let regretBucket else {
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
            return
        }
        guard model.entitlementGate.canAddTargetTokens(currentCount: selectedCatalogIDs.count) else {
            isPaywallPresented = true
            return
        }
        selectedCatalogIDs.append(item.catalogID)
    }

    func persistSelectedAppsAndAdvance() {
        guard !selectedCatalogIDs.isEmpty else {
            appSelectionMessage = "まずは1つだけ選びましょう。\n\n一番無意識に開いてしまうSNSから始めるのがおすすめです。"
            return
        }
        do {
            try model.targetStore.setTargets(selectedCatalogIDs)
            appSelectionMessage = nil
            advance()
        } catch CoreError.validation(let message) {
            appSelectionMessage = message
        } catch {
            showSaveError()
        }
    }

    func saveGoalAndAdvance(skipped: Bool) {
        if skipped {
            advance()
            return
        }

        let normalizedTitle = trimmed(heroGoal)
        guard !normalizedTitle.isEmpty else {
            advance()
            return
        }

        let saved = model.addGoal(
            title: normalizedTitle,
            category: goalCategory,
            lockScreenTitle: lockScreenTitle
        )
        if !saved {
            flowAlert = OnboardingAlert(
                title: "保存できませんでした",
                message: model.alertMessage ?? "データを保存できませんでした"
            )
            return
        }
        advance()
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
        let mode = modeAllowedForCurrentEntitlement(mode)
        selectedMode = mode
        settingsStore.pendingInterventionMode = mode.rawValue
        advance()
    }

    func modeAllowedForCurrentEntitlement(_ mode: InterventionMode) -> InterventionMode {
        if mode == .deepFocus, !model.entitlementGate.strictModeAllowed {
            return .standard
        }
        return mode
    }

    func openShortcutsAndAdvance() {
        if let url = URL(string: "shortcuts://") {
            UIApplication.shared.open(url)
        }
        advance()
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
            granted ? advance() : showNotificationFallback()
        } catch {
            showNotificationFallback()
        }
    }
}

private extension OnboardingFlow {
    func showNotificationFallback() {
        notificationMessage = "通知はあとで設定できます。"
    }

    func showSaveError() {
        flowAlert = OnboardingAlert(
            title: "保存できませんでした",
            message: "データを保存できませんでした"
        )
    }

    func dailyTimeText(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)分"
        }
        let hours = Double(minutes) / 60.0
        return hours.rounded() == hours ? "\(Int(hours))時間" : "\(hours)時間"
    }

    func trim(_ binding: Binding<String>, to limit: Int, value: String) {
        guard value.count > limit else {
            return
        }
        binding.wrappedValue = String(value.prefix(limit))
    }

    func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
