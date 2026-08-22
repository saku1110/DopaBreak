import SwiftUI

// オンボーディング専用のモーション部品。
// 可視テキスト・レイアウト・配色は変更せず、登場と操作反応だけを足す。
// Reduce Motion時は移動量とバネを落とし、フェードのみへ縮退させる。

/// 画面内の要素を順に立ち上げる登場演出（Stagger）。
/// 反復要素のstaggerは50ms未満に収める規約に合わせ、1段あたり40msとする。
struct OnboardingStaggerReveal: ViewModifier {
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false

    func body(content: Content) -> some View {
        content
            .opacity(isRevealed ? 1 : 0)
            .offset(y: offsetY)
            // 出現前は透明なだけで当たり判定が残るため、遷移中の誤タップを防ぐ
            .allowsHitTesting(isRevealed)
            .onAppear {
                guard !isRevealed else {
                    return
                }
                withAnimation(revealAnimation) {
                    isRevealed = true
                }
            }
    }

    private var offsetY: CGFloat {
        if reduceMotion || isRevealed {
            return 0
        }
        return 14
    }

    /// 段数が増えても待ち時間が伸び続けないよう、遅延は6段でも頭打ちにする。
    private var revealAnimation: Animation {
        let delay = min(Double(max(index, 0)), 6) * 0.04
        if reduceMotion {
            return .easeOut(duration: 0.18).delay(delay * 0.5)
        }
        return .smooth(duration: 0.42, extraBounce: 0.08).delay(delay)
    }
}

/// 押した瞬間に沈む触感フィードバック。選択肢・チップ・カードボタンへ使う。
struct OnboardingPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(scale(isPressed: configuration.isPressed))
            .opacity(opacity(isPressed: configuration.isPressed))
            .animation(DopaMotion.momentum, value: configuration.isPressed)
    }

    private func scale(isPressed: Bool) -> CGFloat {
        guard isPressed, !reduceMotion else {
            return 1
        }
        return 0.97
    }

    /// Reduce Motion時は縮小せず、押下の手応えを明度で残す。無反応にはしない。
    private func opacity(isPressed: Bool) -> Double {
        guard isPressed, reduceMotion else {
            return 1
        }
        return 0.72
    }
}

/// 数値をカウントアップ表示する（Number ticker）。
/// `Animatable` により、値の変化がフレーム単位で補間される。
/// 表示整形は呼び出し側へ委ね、ローカライズ済みの書式をそのまま使えるようにする。
struct OnboardingAnimatedCount<Content: View>: View, Animatable {
    var value: Double
    @ViewBuilder var content: (Int) -> Content

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        content(Int(value.rounded()))
    }
}

/// 0から目標値まで数字を回す。進捗の状態を自分で持つため、
/// 親のstepに紐づく状態が画面の生成・破棄と競合しない。
///
/// 読み上げには最終値だけを出す。途中の暫定値をVoiceOverへ流さない。
struct OnboardingCountUp<Content: View>: View {
    let target: Int
    let accessibilityText: String
    @ViewBuilder var content: (Int) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: Double = 0

    var body: some View {
        OnboardingAnimatedCount(value: progress * Double(target)) { current in
            content(current)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .onAppear {
            guard !reduceMotion else {
                progress = 1
                return
            }
            withAnimation(.easeOut(duration: 1.1).delay(0.22)) {
                progress = 1
            }
        }
    }
}

/// 50年を面積で示す人生グリッド。
/// 満マスを左上から順に点灯し、端数は次のマスを左から横幅比率で塗る。
struct OnboardingLifeGrid: View {
    let fullCells: Int
    let partialFraction: Double
    let cellCount: Int
    let reduceMotion: Bool
    let viewportHeight: CGFloat

    @State private var animatedFill: Double
    @State private var hasEnteredVisibleArea = false

    private let columnCount = 10
    private let cellSpacing: CGFloat = 6
    private let cornerRadius: CGFloat = 4
    private let staggerRevealLeadIn = Duration.milliseconds(250)
    private let cellRevealInterval = Duration.milliseconds(45)

    init(
        fullCells: Int,
        partialFraction: Double,
        cellCount: Int,
        reduceMotion: Bool,
        viewportHeight: CGFloat
    ) {
        self.fullCells = fullCells
        self.partialFraction = partialFraction
        self.cellCount = cellCount
        self.reduceMotion = reduceMotion
        self.viewportHeight = viewportHeight

        let initialFill = Self.targetFill(
            fullCells: fullCells,
            partialFraction: partialFraction,
            cellCount: cellCount
        )
        _animatedFill = State(initialValue: reduceMotion ? initialFill : 0)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: cellSpacing) {
            ForEach(0..<cellCount, id: \.self) { index in
                lifeGridCell(fillFraction: fillFraction(for: index))
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: 320)
        .accessibilityHidden(true)
        .onGeometryChange(for: Double.self) { geometry in
            Self.visibleFraction(
                of: geometry.frame(in: .scrollView(axis: .vertical)),
                viewportHeight: viewportHeight
            )
        } action: { visibleFraction in
            guard visibleFraction >= 0.5, !hasEnteredVisibleArea else {
                return
            }
            // 一度50%以上見えたらラッチし、スクロールで外れても点灯を中断しない。
            hasEnteredVisibleArea = true
        }
        .task(id: fillTaskID) {
            await revealFill(for: fillTaskID)
        }
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: cellSpacing),
            count: columnCount
        )
    }

    private var targetFill: Double {
        Self.targetFill(
            fullCells: fullCells,
            partialFraction: partialFraction,
            cellCount: cellCount
        )
    }

    /// fill値をtask IDへ含め、同じView identityのまま推計値が変わっても追従する。
    private var fillTaskID: FillTaskID {
        FillTaskID(
            fill: targetFill,
            canReveal: hasEnteredVisibleArea,
            reduceMotion: reduceMotion
        )
    }

    private func fillFraction(for index: Int) -> Double {
        min(max(animatedFill - Double(index), 0), 1)
    }

    private func lifeGridCell(fillFraction: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DesignTokens.hairline)

                Rectangle()
                    .fill(DesignTokens.accent)
                    .frame(width: geometry.size.width * fillFraction)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private static func targetFill(
        fullCells: Int,
        partialFraction: Double,
        cellCount: Int
    ) -> Double {
        let safeCellCount = max(cellCount, 0)
        let safeFullCells = min(max(fullCells, 0), safeCellCount)
        guard safeFullCells < safeCellCount else {
            return Double(safeFullCells)
        }
        let safePartialFraction = partialFraction.isFinite
            ? min(max(partialFraction, 0), Double(1).nextDown)
            : 0
        return Double(safeFullCells) + safePartialFraction
    }

    private static func visibleFraction(of frame: CGRect, viewportHeight: CGFloat) -> Double {
        guard frame.height > 0, viewportHeight > 0 else {
            return 0
        }
        let visibleHeight = max(
            0,
            min(frame.maxY, viewportHeight) - max(frame.minY, 0)
        )
        return Double(min(visibleHeight / frame.height, 1))
    }

    @MainActor
    private func revealFill(for taskID: FillTaskID) async {
        guard !taskID.reduceMotion else {
            animatedFill = taskID.fill
            return
        }

        animatedFill = 0
        guard taskID.canReveal, taskID.fill > 0 else {
            return
        }

        // stagger 5のフェード開始を待ち、見えない間に点灯が終わらないようにする。
        do {
            try await Task.sleep(for: staggerRevealLeadIn)
        } catch {
            return
        }

        let fullCellCount = min(Int(taskID.fill.rounded(.down)), cellCount)
        for index in 0..<fullCellCount {
            guard !Task.isCancelled else {
                return
            }
            withAnimation(.easeOut(duration: 0.02)) {
                animatedFill = Double(index + 1)
            }
            do {
                try await Task.sleep(for: cellRevealInterval)
            } catch {
                return
            }
        }

        let partialFraction = taskID.fill - Double(fullCellCount)
        guard partialFraction > 0, !Task.isCancelled else {
            return
        }
        withAnimation(.linear(duration: 0.025)) {
            animatedFill = taskID.fill
        }
    }

    private struct FillTaskID: Hashable {
        let fill: Double
        let canReveal: Bool
        let reduceMotion: Bool
    }
}

extension View {
    /// 画面内の登場順を指定する。0が最初。
    func onboardingStagger(_ index: Int) -> some View {
        modifier(OnboardingStaggerReveal(index: index))
    }
}
