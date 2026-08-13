import SwiftUI

struct FlameBreathView: View {
    var breathPhase: Double
    var flare: Double
    /// 描画レート上限。介入画面は60fpsのまま、負荷を抑えたい従属的な用途だけ下げる。
    var framesPerSecond: Double = 60
    /// `flare`の暗黙アニメーション。外部から連続値を与える場合は二重補間になるため切る。
    var animatesFlare: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animationStartDate: Date?

    private var frameInterval: Double {
        let cap = reduceMotion ? min(framesPerSecond, 30) : framesPerSecond
        return 1.0 / max(cap, 1)
    }

    var body: some View {
        TimelineView(
            .animation(minimumInterval: frameInterval)
        ) { context in
            GeometryReader { proxy in
                let time = elapsedTime(at: context.date)
                let size = proxy.size

                ZStack(alignment: .bottom) {
                    flameLayer(size: size, time: time)
                        .blendMode(.plusLighter)
                }
                .drawingGroup(opaque: false, colorMode: .extendedLinear)
                .animation(.linear(duration: 1.0 / 30.0), value: breathPhase)
                .animation(animatesFlare ? .easeOut(duration: 0.08) : nil, value: flare)
            }
        }
        .onAppear {
            animationStartDate = .now
        }
        .onDisappear {
            animationStartDate = nil
        }
        .accessibilityHidden(true)
    }

    private func flameLayer(size: CGSize, time: TimeInterval) -> some View {
        Rectangle()
            .fill(.white)
            .colorEffect(
                ShaderLibrary.flame(
                    .float2(size),
                    .float(time),
                    .float(min(max(breathPhase, 0), 1)),
                    .float(min(max(flare, 0), 1)),
                    .float(reduceMotion ? 1 : 0)
                )
            )
    }

    private func elapsedTime(at date: Date) -> TimeInterval {
        guard let animationStartDate else {
            return 0
        }
        return max(0, date.timeIntervalSince(animationStartDate))
    }
}
