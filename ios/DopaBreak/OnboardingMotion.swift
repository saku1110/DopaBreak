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

extension View {
    /// 画面内の登場順を指定する。0が最初。
    func onboardingStagger(_ index: Int) -> some View {
        modifier(OnboardingStaggerReveal(index: index))
    }
}
