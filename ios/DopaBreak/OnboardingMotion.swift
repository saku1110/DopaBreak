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

/// 着火演出の時間曲線。進捗（0→1）から各時点の値を出す純粋計算。
///
/// 尺を進捗ひとつに畳んであるのは、`FlameBreathView`が内側に`.animation(_:value:)`を持ち、
/// 外から当てたアニメーションを上書きするため。親が進捗を補間し、値として渡す形にする。
struct GoalIgnitionPhase: Equatable {
    /// 立ち上がりの上限。介入画面の「ひと呼吸」のピーク1.0を侵さないよう0.72に留める。
    static let peakBreath: Double = 0.72
    /// 演出の全長。ここを過ぎたら次の画面へ送る。
    static let duration: TimeInterval = 0.8
    /// 火が立ち上がりきるまで。
    static let breathRise: TimeInterval = 0.30
    /// 吹き上がりの立ち上がり。
    static let flareRise: TimeInterval = 0.18
    /// 吹き上がりの減衰。尾を引かせて落とす。
    static let flareFall: TimeInterval = 0.34
    /// 姿を現すまで。強度0でも炎は描かれるため、頭だけ透過から入る。
    static let fadeIn: TimeInterval = 0.12

    /// 0→1で線形に進む演出の進捗。
    var progress: Double

    /// 着火からの経過秒。
    var elapsed: TimeInterval {
        Self.duration * min(max(progress, 0), 1)
    }

    var opacity: Double {
        Self.eased(elapsed / Self.fadeIn)
    }

    var breathPhase: Double {
        Self.peakBreath * Self.eased(elapsed / Self.breathRise)
    }

    var flare: Double {
        guard elapsed > Self.flareRise else {
            return Self.eased(elapsed / Self.flareRise)
        }
        return 1 - Self.eased((elapsed - Self.flareRise) / Self.flareFall)
    }

    /// 3次のease-out。減速して着地させる。
    static func eased(_ ratio: Double) -> Double {
        let clamped = min(max(ratio, 0), 1)
        return 1 - pow(1 - clamped, 3)
    }
}

/// 目標を決めた瞬間に一度だけ着火させる演出。
///
/// 常時描いていた種火（〜2026-08-08）の置き換え。火の意味を「打鍵数への反応」から
/// 「決意への報酬」へ変えるため、入力中は何も描かず、次へタップの一度だけ吹き上げる。
///
/// フレームは画面最下端へ置いたうえで、さらに`rootOffset`だけ下（画面外）へ逃がす。
/// シェーダは下端側に根元のフェード帯（`rootFade`。高さの約10%を透明化する）を持つため、
/// 素直に下端へ合わせると火の根元が透けて「根元が映らない」状態になる。
struct GoalIgnitionFlame: View {
    /// 炎フレームの高さ。
    static let height: CGFloat = 280
    /// 画面外へ逃がす量。根元のフェード帯（280ptの約10%＝28pt）をここで画面外へ出す。
    static let rootOffset: CGFloat = 30
    /// 着火から次画面へ進むまでの尺。
    static let duration: TimeInterval = GoalIgnitionPhase.duration

    @State private var progress: Double = 0

    var body: some View {
        GoalIgnitionVisual(phase: GoalIgnitionPhase(progress: progress))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                // 進捗だけを線形で送り、緩急は`GoalIgnitionPhase`側の曲線で作る。
                // `KeyframeAnimator`の自動再生は実機のオーバーレイ内で走らなかったため使わない
                withAnimation(.linear(duration: Self.duration)) {
                    progress = 1
                }
            }
    }
}

/// 着火の描画本体。`Animatable`にして、進捗をフレーム単位で補間させる。
///
/// `FlameBreathView`は内側に`.animation(.linear, value: breathPhase)`を持つため、
/// 外から尺を当てても上書きされる。ここで補間してから値として渡す。
struct GoalIgnitionVisual: View, Animatable {
    var phase: GoalIgnitionPhase

    var animatableData: Double {
        get { phase.progress }
        set { phase.progress = newValue }
    }

    var body: some View {
        FlameBreathView(
            breathPhase: phase.breathPhase,
            flare: phase.flare,
            framesPerSecond: 60,
            animatesFlare: false
        )
        .frame(maxWidth: .infinity)
        .frame(height: GoalIgnitionFlame.height)
        .offset(y: GoalIgnitionFlame.rootOffset)
        .opacity(phase.opacity)
    }
}

extension View {
    /// 画面内の登場順を指定する。0が最初。
    func onboardingStagger(_ index: Int) -> some View {
        modifier(OnboardingStaggerReveal(index: index))
    }
}
