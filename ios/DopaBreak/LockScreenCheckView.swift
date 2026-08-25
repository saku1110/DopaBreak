import DopaBreakCore
import SwiftUI
import UIKit

/// ロック画面での掲出確認の進行状態。
enum LockScreenCheckPhase: Equatable {
    /// 掲出処理中。
    case starting
    /// 出せた。サイドボタンで確かめてもらう段階。
    case waiting
    /// 一度アプリを離れて戻ってきて、まだ出ている。
    case confirmed
    /// 出せていない。原因で案内を変える。
    case blocked(BlockedReason)
    /// 出す目標がまだない。
    case noGoal

    enum BlockedReason: Equatable {
        /// 端末側でライブアクティビティがオフ（許可プロンプトで「許可しない」を含む）。
        case systemDisabled
        /// 許可はあるのに掲出できなかった。再試行で復帰することがある。
        case failed
    }

    /// 掲出できている状態か。
    var isPresenting: Bool {
        self == .waiting || self == .confirmed
    }

    var isBlocked: Bool {
        if case .blocked = self {
            return true
        }
        return false
    }
}

/// 目標をロック画面のLive Activityで確かめてもらう画面の中身。
///
/// 表示直後にLive Activityを出し、消灯してから再点灯する2ステップで掲出を確認してもらう。
struct LockScreenCheckContent: View {
    let model: AppModel
    @Binding var phase: LockScreenCheckPhase
    var markerBlockBottomY: CGFloat? = nil
    var scrollContainerTopY: CGFloat = 0
    var contentTopPadding: CGFloat = 0

    @Environment(\.scenePhase) private var scenePhase
    @State private var titleHeight: CGFloat = 0
    @State private var didEnterBackground = false
    /// 一度でもアプリを離れて戻ったか。掲出処理の完了と復帰の順序が入れ替わっても
    /// 確認済みを取りこぼさないよう、状態として持つ。
    @State private var didObserveReturn = false

    var body: some View {
        VStack(alignment: .center, spacing: 24) {
            Text(title)
                .dopaFont(32, weight: .black, lineSpacing: 4)
                .foregroundStyle(DesignTokens.primaryText)
                .minimumScaleFactor(0.74)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: LockScreenTitleHeightPreferenceKey.self,
                            value: proxy.size.height
                        )
                    }
                }
                .onboardingStagger(0)

            // 掲出できている間は2ステップカードが案内するため、リードは出さない。
            if let lead {
                Text(lead)
                    .dopaFont(16, weight: .semibold, lineSpacing: 5)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .onboardingStagger(1)
            }

            switch phase {
            case .waiting:
                Color.clear
                    .frame(height: waitingSpacerHeight)

                verificationSteps
                    .onboardingStagger(2)
                goalPreview
                    .onboardingStagger(3)
                permissionNote
                    .onboardingStagger(4)
            case .starting:
                goalPreview
                    .onboardingStagger(2)
                verificationSteps
                    .onboardingStagger(3)
                permissionNote
                    .onboardingStagger(4)
            case .confirmed:
                goalPreview
                    .onboardingStagger(2)
                visibleBadge
                    .onboardingStagger(3)
            case .blocked(.systemDisabled):
                goalPreview
                    .onboardingStagger(2)
                settingsPathCard
                    .onboardingStagger(3)
            case .blocked(.failed), .noGoal:
                goalPreview
                    .onboardingStagger(2)
            }
        }
        .frame(maxWidth: .infinity)
        .onPreferenceChange(LockScreenTitleHeightPreferenceKey.self) { titleHeight = $0 }
        .task {
            await start()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                didEnterBackground = true
            case .active:
                if didEnterBackground {
                    didObserveReturn = true
                }
                didEnterBackground = false
                Task {
                    await refreshStatus()
                }
            default:
                break
            }
        }
    }

    private var waitingSpacerHeight: CGFloat {
        guard phase == .waiting, let markerBlockBottomY else {
            return 0
        }
        let stableTitleBottomY = scrollContainerTopY + contentTopPadding + titleHeight
        return max(0, markerBlockBottomY - stableTitleBottomY + 16 - 48)
    }

    private var goalPreview: some View {
        LockScreenGoalPreview(
            titles: previewTitles,
            cancelledCount: model.todayCancelledCount,
            attemptCount: model.todayAttemptCount,
            isDimmed: !phase.isPresenting
        )
    }

    private var title: String {
        switch phase {
        case .starting, .waiting, .confirmed:
            return String(localized: "lock_check.title.ready", defaultValue: "ロック画面に出しました")
        case .blocked(.systemDisabled):
            return String(localized: "lock_check.title.blocked", defaultValue: "ロック画面の表示がオフ")
        case .blocked(.failed):
            return String(localized: "lock_check.title.failed", defaultValue: "いま出せませんでした")
        case .noGoal:
            return String(localized: "lock_check.title.no_goal", defaultValue: "まず目標をひとつ")
        }
    }

    private var lead: String? {
        switch phase {
        case .starting, .waiting:
            return nil
        case .confirmed:
            return String(
                localized: "lock_check.lead.confirmed",
                defaultValue: "開こうとするたび この言葉が先に目に入ります。"
            )
        case .blocked(.systemDisabled):
            return String(
                localized: "lock_check.lead.blocked",
                defaultValue: "端末の設定でライブアクティビティをオンにすると出せます。"
            )
        case .blocked(.failed):
            return String(
                localized: "lock_check.lead.failed",
                defaultValue: "もう一度出すと表示できることがあります。"
            )
        case .noGoal:
            return String(
                localized: "lock_check.lead.no_goal",
                defaultValue: "目標を決めると ロック画面に出せます。"
            )
        }
    }

    private var previewTitles: [String] {
        let titles = model.lockScreenDisplayTitles.filter { !$0.isEmpty }
        guard titles.isEmpty else {
            return titles
        }
        return [String(localized: "lock_check.preview.goal_fallback", defaultValue: "あなたの目標")]
    }

    private var verificationSteps: some View {
        CardContainer {
            LockScreenStepRow(
                number: 2,
                title: String(
                    localized: "lock_check.step2.title",
                    defaultValue: "画面をタップして点けるとロック画面に目標が出ています"
                )
            )
        }
    }

    private var permissionNote: some View {
        Text(
            String(
                localized: "lock_check.permission_note",
                defaultValue: "はじめて出るときは「許可しますか」と聞かれます。「許可」を選ぶとロック画面に残ります。"
            )
        )
            .dopaFont(14, weight: .semibold, lineSpacing: 4)
            .foregroundStyle(DesignTokens.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var visibleBadge: some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark")
                .dopaFont(13, weight: .heavy)
            Text(String(localized: "lock_check.status.visible", defaultValue: "ロック画面に表示中"))
                .dopaFont(15, weight: .bold)
        }
        .foregroundStyle(DesignTokens.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(DesignTokens.accent.opacity(0.09))
        .overlay {
            Capsule().stroke(DesignTokens.accent.opacity(0.42), lineWidth: 1)
        }
        .clipShape(Capsule())
    }

    private var settingsPathCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                SmallLabel(text: String(localized: "lock_check.settings_path.label", defaultValue: "設定の場所"))
                Text(
                    String(
                        localized: "lock_check.settings_path.value",
                        defaultValue: "設定 > DopaBreak > ライブアクティビティ"
                    )
                )
                    .dopaFont(16, weight: .bold)
                    .foregroundStyle(DesignTokens.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func start() async {
        let status = await model.presentGoalOnLockScreen()
        phase = Self.phase(for: status, didReturnFromLockScreen: didObserveReturn, current: phase)
    }

    private func refreshStatus() async {
        var status = model.lockScreenGoalStatus
        if status == .failed {
            // 復帰時は8時間対策の張り直しが同時に走る。設定からライブアクティビティを
            // オンにして戻ってきた直後も掲出は空になる。どちらも「出せない」と誤判定
            // しないよう、出し直してから判定する。
            status = await model.presentGoalOnLockScreen()
        }
        phase = Self.phase(
            for: status,
            didReturnFromLockScreen: didObserveReturn,
            current: phase
        )
    }

    /// 掲出状況と「ロック画面から戻ってきたか」から表示状態を決める。
    /// 一度も端末を伏せていないのに確認済みへ進めないよう、復帰を条件にする。
    static func phase(
        for status: LockScreenGoalStatus,
        didReturnFromLockScreen: Bool,
        current: LockScreenCheckPhase
    ) -> LockScreenCheckPhase {
        switch status {
        case .noGoal:
            return .noGoal
        case .systemDisabled:
            return .blocked(.systemDisabled)
        case .failed:
            return .blocked(.failed)
        case .visible:
            if current == .confirmed || didReturnFromLockScreen {
                return .confirmed
            }
            return .waiting
        }
    }
}

/// 各コンテナ（オンボーディング / 単独表示）から共通で呼ぶ操作。
enum LockScreenCheckAction {
    /// 掲出をやり直して結果を反映する。許可はあるのに出せなかったときの復旧用。
    @MainActor
    static func retry(model: AppModel, phase: Binding<LockScreenCheckPhase>) async {
        let status = await model.presentGoalOnLockScreen()
        phase.wrappedValue = LockScreenCheckContent.phase(
            for: status,
            didReturnFromLockScreen: false,
            current: phase.wrappedValue
        )
    }
}

/// 実際のLive Activityと同じ体裁のプレビュー。
/// ロック画面確認だけでなく、目標一覧と編集シートからも参照するため internal にしてある。
/// 表示件数は実機のLive Activityと同じ上限（`LockSurfaceCoordinator.liveActivityGoalLimit`）に合わせる。
/// ここを固定値で持つと実機と食い違うため、必ず同じ定数を参照する。
struct LockScreenGoalPreview: View {
    let titles: [String]
    let cancelledCount: Int
    let attemptCount: Int
    var isDimmed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SmallLabel(text: String(localized: "lock_check.preview.eyebrow", defaultValue: "あなたの目標"))

            VStack(alignment: .leading, spacing: 6) {
                ForEach(
                    Array(titles.prefix(LockSurfaceCoordinator.liveActivityGoalLimit).enumerated()),
                    id: \.offset
                ) { _, title in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Rectangle()
                            .fill(DesignTokens.accent)
                            .frame(width: 10, height: 2)
                        Text(title)
                            .dopaFont(17, weight: .bold)
                            .foregroundStyle(DesignTokens.primaryText)
                            .lineLimit(2)
                    }
                }
            }

            Rectangle()
                .fill(DesignTokens.hairline)
                .frame(height: 1)

            HStack(spacing: 14) {
                Text(
                    String(
                        localized: "lock_check.preview.cancelled",
                        defaultValue: "今日は\(cancelledCount)回 開くのをやめた"
                    )
                )
                    .foregroundStyle(DesignTokens.accent)
                Text(
                    String(
                        localized: "lock_check.preview.attempted",
                        defaultValue: "開こうとした \(attemptCount)回"
                    )
                )
                    .foregroundStyle(DesignTokens.secondaryText)
            }
            .dopaFont(12, weight: .semibold)
            .monospacedDigit()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.card)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(DesignTokens.accent)
                .frame(width: 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DesignTokens.hairline, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .opacity(isDimmed ? 0.5 : 1)
    }
}

/// 番号と説明をひとまとまりで読ませる確認手順。
private struct LockScreenStepRow: View {
    let number: Int
    let title: String
    var note: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .dopaFont(13, weight: .black, design: .rounded)
                .foregroundStyle(DesignTokens.background)
                .frame(width: 28, height: 28)
                .background(DesignTokens.accent)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .dopaFont(16, weight: .bold, lineSpacing: 3)
                    .foregroundStyle(DesignTokens.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let note {
                    Text(note)
                        .dopaFont(13, weight: .semibold, lineSpacing: 3)
                        .foregroundStyle(DesignTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LockScreenTitleHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct SideButtonMarkerFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct SideButtonMarkerBottomPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct SideButtonMarkerLayout: Layout {
    let geometry: DeviceSideButtonGeometry
    let headerBottomY: CGFloat
    let originY: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 4 else {
            assertionFailure("SideButtonMarkerLayout expects exactly four subviews")
            return
        }

        let barHeight = max(56, geometry.length)
        let barTopY = geometry.top - originY
        subviews[0].place(
            at: CGPoint(x: bounds.maxX, y: bounds.minY + barTopY),
            anchor: .topTrailing,
            proposal: ProposedViewSize(width: 5, height: barHeight)
        )

        let maximumBlockWidth: CGFloat = 240
        let textProposal = ProposedViewSize(width: maximumBlockWidth, height: nil)
        let textSize = subviews[1].sizeThatFits(textProposal)
        let arrowSize = subviews[2].sizeThatFits(.unspecified)
        let blockHeight = textSize.height + 8 + arrowSize.height
        let blockWidth = max(textSize.width, arrowSize.width + 14)
        let barCenterY = geometry.top + barHeight / 2
        let centeredBlockTopY = barCenterY - blockHeight / 2
        let blockTopY = max(headerBottomY + 8, centeredBlockTopY) - originY
        subviews[1].place(
            at: CGPoint(x: bounds.maxX - 5, y: bounds.minY + blockTopY),
            anchor: .topTrailing,
            proposal: ProposedViewSize(width: textSize.width, height: textSize.height)
        )
        subviews[2].place(
            at: CGPoint(
                x: bounds.maxX - 5 - 14,
                y: bounds.minY + blockTopY + textSize.height + 8
            ),
            anchor: .topTrailing,
            proposal: ProposedViewSize(width: arrowSize.width, height: arrowSize.height)
        )
        subviews[3].place(
            at: CGPoint(x: bounds.maxX - 5, y: bounds.minY + blockTopY),
            anchor: .topTrailing,
            proposal: ProposedViewSize(width: blockWidth, height: blockHeight)
        )
    }
}

/// 実際の物理サイドボタンと同じ画面Y座標を指すエッジマーカー。
struct SideButtonEdgeMarker: View {
    let geometry: DeviceSideButtonGeometry
    let headerBottomY: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var markerFrame: CGRect = .zero
    @State private var isVisible = false

    var body: some View {
        GeometryReader { proxy in
            let originY = proxy.frame(in: .global).minY
            let barHeight = max(56, geometry.length)
            let barCenterY = geometry.top + barHeight / 2
            let arrowName = arrowName(barCenterY: barCenterY)

            SideButtonMarkerLayout(
                geometry: geometry,
                headerBottomY: headerBottomY,
                originY: originY
            ) {
                Capsule()
                    .fill(DesignTokens.accent)
                    .frame(width: 5, height: barHeight)
                    .accessibilityHidden(true)

                markerText
                    .padding(.trailing, 14)

                Image(systemName: arrowName)
                    .font(.system(size: 28))
                    .foregroundStyle(DesignTokens.primaryText)

                Color.clear
                    .background {
                        GeometryReader { labelProxy in
                            let frame = labelProxy.frame(in: .global)
                            Color.clear
                                .preference(
                                    key: SideButtonMarkerFramePreferenceKey.self,
                                    value: frame
                                )
                                .preference(
                                    key: SideButtonMarkerBottomPreferenceKey.self,
                                    value: frame.maxY
                                )
                        }
                    }
            }
            .opacity(isVisible ? 1 : 0)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                geometry.hasCameraControl
                    ? "\(localizedLabel) \(localizedNote)"
                    : localizedLabel
            )
        }
        .ignoresSafeArea(.all, edges: .trailing)
        .onPreferenceChange(SideButtonMarkerFramePreferenceKey.self) { markerFrame = $0 }
        .onAppear {
            if reduceMotion {
                isVisible = true
            } else {
                withAnimation(DopaMotion.transition) {
                    isVisible = true
                }
            }
        }
    }

    private func arrowName(barCenterY: CGFloat) -> String {
        guard markerFrame.height > 0 else {
            return "arrow.right"
        }
        if barCenterY < markerFrame.minY {
            return "arrow.turn.right.up"
        }
        if barCenterY > markerFrame.maxY {
            return "arrow.turn.right.down"
        }
        return "arrow.right"
    }

    private var localizedLabel: String {
        String(
            localized: "lock_check.side_button.label",
            defaultValue: "サイドボタンを1回押して画面を消す"
        )
    }

    private var localizedNote: String {
        String(
            localized: "lock_check.side_button.camera_control_note",
            defaultValue: "下のカメラボタンではなく上のボタン"
        )
    }

    private var markerText: some View {
        VStack(alignment: .trailing) {
            Text(localizedLabel)
                .dopaFont(20, weight: .black, lineSpacing: 4)
                .foregroundStyle(DesignTokens.primaryText)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)

            if geometry.hasCameraControl {
                Text(localizedNote)
                    .dopaFont(13, weight: .semibold)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }

        }
    }
}

/// オンボーディング外（目標追加後・設定から）で使う単独表示。
struct LockScreenCheckSheet: View {
    let model: AppModel
    let onFinish: () -> Void

    @State private var phase: LockScreenCheckPhase = .starting
    @State private var markerBlockBottomY: CGFloat = 0
    @State private var sideButtonGeometry = DeviceSideButtonGeometry.current()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                DesignTokens.background.ignoresSafeArea()

                ScrollView {
                    LockScreenCheckContent(
                        model: model,
                        phase: $phase,
                        markerBlockBottomY: markerBlockBottomY,
                        scrollContainerTopY: proxy.frame(in: .global).minY + proxy.safeAreaInsets.top,
                        contentTopPadding: 36
                    )
                        .padding(.horizontal, 20)
                        .padding(.top, 36)
                        .padding(.bottom, 132)
                }
                .overlay(alignment: .topTrailing) {
                    if phase == .waiting {
                        SideButtonEdgeMarker(
                            geometry: sideButtonGeometry,
                            headerBottomY: proxy.safeAreaInsets.top
                        )
                        .ignoresSafeArea()
                    }
                }
                .onPreferenceChange(SideButtonMarkerBottomPreferenceKey.self) {
                    markerBlockBottomY = $0
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                switch phase {
                case .blocked(.systemDisabled):
                    Button(String(localized: "lock_check.action.settings", defaultValue: "設定を開く")) {
                        LockScreenSettingsLink.open()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    laterButton
                case .blocked(.failed):
                    Button(String(localized: "lock_check.action.retry", defaultValue: "もう一度出す")) {
                        Task { await LockScreenCheckAction.retry(model: model, phase: $phase) }
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    laterButton
                case .starting, .waiting, .confirmed, .noGoal:
                    Button(String(localized: "lock_check.action.done", defaultValue: "完了")) {
                        // 確認できた場合だけ完了扱いにする。見ていない状態で以後の
                        // 自動提示を止めない。
                        finish(markCompleted: phase == .confirmed)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(DesignTokens.background)
        }
        .preferredColorScheme(.dark)
    }

    private var laterButton: some View {
        Button(String(localized: "lock_check.action.later", defaultValue: "あとで")) {
            finish(markCompleted: false)
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    private func finish(markCompleted: Bool) {
        if markCompleted {
            model.markLockScreenCheckCompleted()
        } else {
            model.dismissPendingLockScreenCheck()
        }
        onFinish()
    }
}

/// 端末の「設定 > アプリ」へ送る導線。ライブアクティビティのトグルはこの階層にある。
enum LockScreenSettingsLink {
    static func open() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }
}
