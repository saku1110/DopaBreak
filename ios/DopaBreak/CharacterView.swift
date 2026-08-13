import SwiftUI

enum CharacterExpression: String, CaseIterable {
    case doom
    case blink
    case awake
    case relief
    case blank
    case worse
}

/// 表情差し替え・浮遊・まばたきを一か所へ閉じ込めたキャラクタービュー。
struct CharacterView: View {
    private static let floatAmplitude: CGFloat = 4
    private static let floatPeriod: TimeInterval = 1.6
    private static let blinkDuration: TimeInterval = 0.13
    private static let blinkPatternCount = 64
    private static let frameInterval: TimeInterval = 1.0 / 30.0

    let expression: CharacterExpression
    let size: CGFloat
    let animated: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sourceExpression: CharacterExpression
    @State private var targetExpression: CharacterExpression
    @State private var swapStartedAt: TimeInterval?

    init(_ expression: CharacterExpression, size: CGFloat, animated: Bool = true) {
        self.expression = expression
        self.size = size
        self.animated = animated
        _sourceExpression = State(initialValue: expression)
        _targetExpression = State(initialValue: expression)
    }

    var body: some View {
        Group {
            if animated {
                TimelineView(.animation(minimumInterval: Self.frameInterval)) { context in
                    let elapsed = context.date.timeIntervalSinceReferenceDate
                    characterImage(at: elapsed)
                        .onChange(of: expression) { _, newExpression in
                            beginSwap(to: newExpression, at: elapsed)
                        }
                }
            } else {
                staticCharacterImage
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var staticCharacterImage: some View {
        Image(expression.rawValue)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .transaction { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
    }

    private func characterImage(at elapsed: TimeInterval) -> some View {
        let frameExpression = renderedExpression(at: elapsed)
        return Image(frameExpression.rawValue)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .offset(y: Self.idleFloatOffset(elapsed: elapsed, reduceMotion: reduceMotion))
            // 親の暗黙アニメーションが画像差し替えをクロスフェードしないよう遮断する。
            .transaction { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
    }

    private func renderedExpression(at elapsed: TimeInterval) -> CharacterExpression {
        if isSwapBlinking(at: elapsed) || Self.isAutoBlinking(at: elapsed) {
            return .blink
        }
        return underlyingExpression(at: elapsed)
    }

    private func underlyingExpression(at elapsed: TimeInterval) -> CharacterExpression {
        guard let swapStartedAt else {
            return targetExpression
        }
        let swapElapsed = elapsed - swapStartedAt
        return swapElapsed < Self.blinkDuration / 2 ? sourceExpression : targetExpression
    }

    private func isSwapBlinking(at elapsed: TimeInterval) -> Bool {
        guard let swapStartedAt else {
            return false
        }
        let swapElapsed = elapsed - swapStartedAt
        return swapElapsed >= 0 && swapElapsed < Self.blinkDuration
    }

    private func beginSwap(to newExpression: CharacterExpression, at elapsed: TimeInterval) {
        guard newExpression != targetExpression else {
            return
        }
        sourceExpression = underlyingExpression(at: elapsed)
        targetExpression = newExpression
        swapStartedAt = elapsed
    }

    /// Reduce Motion時は0を返し、表情を伝えるまばたきだけを残す。
    static func idleFloatOffset(elapsed: TimeInterval, reduceMotion: Bool) -> CGFloat {
        guard !reduceMotion else {
            return 0
        }
        let cycle = positiveRemainder(elapsed, divisor: floatPeriod) / floatPeriod
        return floatAmplitude * CGFloat(sin(cycle * 2 * .pi))
    }

    private static func isAutoBlinking(at elapsed: TimeInterval) -> Bool {
        var cursor = positiveRemainder(elapsed, divisor: blinkCycleDuration)
        for index in 0..<blinkPatternCount {
            let interval = blinkInterval(for: index)
            if cursor < interval {
                return cursor < blinkDuration
            }
            cursor -= interval
        }
        return false
    }

    private static var blinkCycleDuration: TimeInterval {
        (0..<blinkPatternCount).reduce(0) { total, index in
            total + blinkInterval(for: index)
        }
    }

    /// blink番号をハッシュし、開始間隔を必ず3.5〜6.0秒へ収める。
    private static func blinkInterval(for index: Int) -> TimeInterval {
        3.5 + (2.5 * hashedUnitInterval(index))
    }

    private static func hashedUnitInterval(_ index: Int) -> Double {
        var value = UInt64(truncatingIfNeeded: index) &+ 0x9E3779B97F4A7C15
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31
        let mask = (UInt64(1) << 53) - 1
        return Double(value & mask) / Double(mask)
    }

    private static func positiveRemainder(_ value: TimeInterval, divisor: TimeInterval) -> TimeInterval {
        let remainder = value.truncatingRemainder(dividingBy: divisor)
        return remainder >= 0 ? remainder : remainder + divisor
    }
}

/// 指定時間だけ最初の表情を見せたあと、CharacterViewの閉眼差し替えを起動する。
struct CharacterSwapSequence: View {
    let initialExpression: CharacterExpression
    let finalExpression: CharacterExpression
    let size: CGFloat
    let delayNanoseconds: UInt64

    @State private var expression: CharacterExpression

    init(
        from initialExpression: CharacterExpression,
        to finalExpression: CharacterExpression,
        size: CGFloat,
        delayNanoseconds: UInt64
    ) {
        self.initialExpression = initialExpression
        self.finalExpression = finalExpression
        self.size = size
        self.delayNanoseconds = delayNanoseconds
        _expression = State(initialValue: initialExpression)
    }

    var body: some View {
        CharacterView(expression, size: size)
            .task {
                do {
                    try await Task.sleep(nanoseconds: delayNanoseconds)
                } catch {
                    return
                }
                guard !Task.isCancelled else {
                    return
                }
                expression = finalExpression
            }
    }
}

enum CharacterPopVariant {
    case control
    case celebrate

    var animation: Animation {
        switch self {
        case .control: return DopaMotion.control
        case .celebrate: return DopaMotion.celebrate
        }
    }
}

private enum CharacterPopPhase: Equatable {
    case resting
    case expanded

    static let sequence: [Self] = [.resting, .expanded, .resting]

    var scale: CGFloat {
        self == .expanded ? 1.06 : 1
    }
}

private struct TriggeredCharacterPopModifier<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    let variant: CharacterPopVariant

    func body(content: Content) -> some View {
        content.phaseAnimator(CharacterPopPhase.sequence, trigger: trigger) { view, phase in
            view.scaleEffect(phase.scale)
        } animation: { _ in
            variant.animation
        }
    }
}

private struct CharacterPopOnAppearModifier: ViewModifier {
    let variant: CharacterPopVariant
    @State private var trigger = 0
    @State private var didRun = false

    func body(content: Content) -> some View {
        content
            .modifier(TriggeredCharacterPopModifier(trigger: trigger, variant: variant))
            .onAppear {
                guard !didRun else {
                    return
                }
                didRun = true
                trigger += 1
            }
    }
}

extension View {
    /// 表示時に1.0→1.06→1.0を一度だけ走らせる。
    func characterPop(_ variant: CharacterPopVariant = .control) -> some View {
        modifier(CharacterPopOnAppearModifier(variant: variant))
    }

    /// 選択値が変わるたびに同じポップを再生する。
    func characterPop<Trigger: Equatable>(
        trigger: Trigger,
        variant: CharacterPopVariant = .control
    ) -> some View {
        modifier(TriggeredCharacterPopModifier(trigger: trigger, variant: variant))
    }
}
