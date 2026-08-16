import SwiftUI

/// 呼吸ステージの描画だけを担うタイムライン。フロー遷移の正はInterventionFlowModelに置く。
struct BreathCharacterTimeline {
    static let reliefDuration: TimeInterval = 0.8

    let totalDuration: TimeInterval
    let cycleDuration: TimeInterval

    init(totalSeconds: Int) {
        let safeTotal = max(1, totalSeconds)
        totalDuration = TimeInterval(safeTotal)
        cycleDuration = totalDuration
    }

    var reliefStart: TimeInterval {
        max(0, totalDuration - Self.reliefDuration)
    }

    func expression(at elapsed: TimeInterval) -> CharacterExpression {
        let elapsed = clampedElapsed(elapsed)
        if elapsed >= reliefStart {
            return .relief
        }

        // 3秒設定では短い呼気中にdoomを挟まず、blinkからreliefへ直接つなぐ。
        if totalDuration == 3 {
            return .blink
        }

        return cycleProgress(at: elapsed) < 0.5 ? .blink : .doom
    }

    func scale(at elapsed: TimeInterval) -> CGFloat {
        let elapsed = clampedElapsed(elapsed)
        guard elapsed < totalDuration else {
            return 1
        }

        if elapsed < reliefStart {
            return cycleScale(at: elapsed)
        }

        let reliefProgress = Self.unitInterval(
            (elapsed - reliefStart) / Self.reliefDuration
        )
        let easedProgress = Self.easeInOut(reliefProgress)
        let startingScale = cycleScale(at: reliefStart)
        return startingScale + ((1 - startingScale) * CGFloat(easedProgress))
    }

    func opacity(at elapsed: TimeInterval, reduceMotion: Bool) -> Double {
        guard reduceMotion else {
            return 1
        }

        let elapsed = clampedElapsed(elapsed)
        guard elapsed < reliefStart else {
            return 1
        }

        return 0.85 + (0.15 * cycleBreathLevel(at: elapsed))
    }

    private func cycleScale(at elapsed: TimeInterval) -> CGFloat {
        1 + (0.06 * CGFloat(cycleBreathLevel(at: elapsed)))
    }

    private func cycleBreathLevel(at elapsed: TimeInterval) -> Double {
        let progress = cycleProgress(at: elapsed)
        if progress < 0.5 {
            return Self.easeInOut(progress / 0.5)
        }

        let exhaleProgress = Self.easeInOut((progress - 0.5) / 0.5)
        return 1 - exhaleProgress
    }

    private func cycleProgress(at elapsed: TimeInterval) -> Double {
        guard elapsed < totalDuration else {
            return 1
        }
        return elapsed / cycleDuration
    }

    private func clampedElapsed(_ elapsed: TimeInterval) -> TimeInterval {
        min(max(0, elapsed), totalDuration)
    }

    private static func easeInOut(_ value: Double) -> Double {
        let value = unitInterval(value)
        return 0.5 - (0.5 * cos(.pi * value))
    }

    private static func unitInterval(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

/// ドーパの表情・拡縮と呼吸同期ハプティクスをまとめた呼吸ステージ専用ビュー。
struct BreathingCharacterView: View {
    private static let frameInterval: TimeInterval = 1.0 / 30.0

    let totalSeconds: Int
    private let previewLoop: Range<TimeInterval>?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAtUptime = ProcessInfo.processInfo.systemUptime
    @State private var hasStarted = false
    @State private var haptics = BreathHapticsController()

    init(totalSeconds: Int) {
        self.totalSeconds = totalSeconds
        previewLoop = nil
    }

    /// 実ウィンドウ検証用。指定位相内を往復し、表情の段階を変えずに動きを保持する。
    init(totalSeconds: Int, previewLoop: Range<TimeInterval>) {
        self.totalSeconds = totalSeconds
        self.previewLoop = previewLoop
    }

    var body: some View {
        let timeline = BreathCharacterTimeline(totalSeconds: totalSeconds)

        TimelineView(.animation(minimumInterval: Self.frameInterval)) { _ in
            let elapsed = elapsed(
                atUptime: ProcessInfo.processInfo.systemUptime,
                timeline: timeline
            )
            let expression = timeline.expression(at: elapsed)
            let scale = reduceMotion ? CGFloat(1) : timeline.scale(at: elapsed)
            let opacity = timeline.opacity(at: elapsed, reduceMotion: reduceMotion)

            CharacterView(expression, size: DesignTokens.CharacterSize.hero)
                .scaleEffect(scale)
                .opacity(opacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            beginPlaybackIfNeeded()
        }
        .onDisappear {
            haptics.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard previewLoop == nil, hasStarted else {
                return
            }
            switch newPhase {
            case .active:
                haptics.resume()
            case .background:
                haptics.pause()
            case .inactive:
                break
            @unknown default:
                haptics.pause()
            }
        }
    }

    private func elapsed(
        atUptime uptime: TimeInterval,
        timeline: BreathCharacterTimeline
    ) -> TimeInterval {
        let elapsed = max(0, uptime - startedAtUptime)
        guard let previewLoop else {
            return min(elapsed, timeline.totalDuration)
        }

        let lowerBound = min(max(0, previewLoop.lowerBound), timeline.totalDuration)
        let upperBound = min(max(lowerBound, previewLoop.upperBound), timeline.totalDuration)
        let span = upperBound - lowerBound
        guard span > 0 else {
            return lowerBound
        }

        // 端点で折り返すため、ループ境界でもスケールが不連続に跳ねない。
        let roundTrip = span * 2
        let position = elapsed.truncatingRemainder(dividingBy: roundTrip)
        let offset = position <= span ? position : roundTrip - position
        return lowerBound + offset
    }

    @MainActor
    private func beginPlaybackIfNeeded() {
        guard !hasStarted else {
            if previewLoop == nil {
                startHapticsAlignedToTimeline()
            }
            return
        }

        hasStarted = true
        startedAtUptime = ProcessInfo.processInfo.systemUptime
        guard previewLoop == nil else {
            return
        }
        startHapticsAlignedToTimeline()
    }

    @MainActor
    private func startHapticsAlignedToTimeline() {
        haptics.start(
            totalSeconds: totalSeconds,
            startedAtUptime: startedAtUptime
        )
    }
}
