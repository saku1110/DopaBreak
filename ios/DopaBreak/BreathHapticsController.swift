import CoreHaptics
import Foundation

/// 呼吸の連続振動とreliefの単発振動を管理する。未対応端末では全APIがno-opになる。
@MainActor
final class BreathHapticsController {
    private struct Session {
        let id = UUID()
        let timeline: BreathCharacterTimeline
        let startedAtUptime: TimeInterval
    }

    private static let schedulingLeadTime: TimeInterval = 0.02
    private static let minimumPlayableDuration: TimeInterval = 0.01
    private static let maximumRecoveryAttempts = 3

    private let supportsHaptics: Bool
    private var engine: CHHapticEngine?
    private var players: [CHHapticPatternPlayer] = []
    private var session: Session?
    private var isAppActive = true
    private var isEngineStarted = false
    private var stopGeneration = 0
    private var isStopInFlight = false
    private var recoveryAttempts = 0
    private var recoveryTask: Task<Void, Never>?

    init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    func start(totalSeconds: Int, startedAtUptime: TimeInterval) {
        guard supportsHaptics else {
            return
        }

        let newSession = Session(
            timeline: BreathCharacterTimeline(totalSeconds: totalSeconds),
            startedAtUptime: startedAtUptime
        )
        let mustStopCurrentPlayback = isEngineStarted || !players.isEmpty || isStopInFlight

        session = newSession
        isAppActive = true
        recoveryAttempts = 0
        recoveryTask?.cancel()
        recoveryTask = nil

        if mustStopCurrentPlayback {
            stopEngine(preservingSession: true)
        } else {
            startPlaybackIfPossible(for: newSession.id)
        }
    }

    /// バックグラウンドではセッション時刻を保持したままエンジンを止める。
    func pause() {
        guard supportsHaptics, session != nil else {
            return
        }
        isAppActive = false
        recoveryTask?.cancel()
        recoveryTask = nil
        stopEngine(preservingSession: true)
    }

    /// 復帰時は現在の経過時刻から残りのパターンだけを再構成する。
    func resume() {
        guard supportsHaptics, let session else {
            return
        }
        isAppActive = true
        guard remainingDuration(for: session) > Self.minimumPlayableDuration else {
            stop()
            return
        }
        guard !isStopInFlight else {
            return
        }
        startPlaybackIfPossible(for: session.id)
    }

    func stop() {
        guard supportsHaptics else {
            return
        }
        session = nil
        isAppActive = false
        recoveryTask?.cancel()
        recoveryTask = nil
        stopEngine(preservingSession: false)
    }

    private func prepareEngineIfNeeded() {
        guard supportsHaptics, engine == nil else {
            return
        }

        do {
            let newEngine = try CHHapticEngine()
            newEngine.playsHapticsOnly = true
            newEngine.isAutoShutdownEnabled = false
            newEngine.stoppedHandler = { [weak self] reason in
                Task { @MainActor in
                    self?.handleEngineStopped(reason: reason)
                }
            }
            newEngine.resetHandler = { [weak self] in
                Task { @MainActor in
                    self?.handleEngineReset()
                }
            }
            engine = newEngine
        } catch {
            engine = nil
        }
    }

    private func startPlaybackIfPossible(for sessionID: UUID) {
        guard supportsHaptics,
              isAppActive,
              !isStopInFlight,
              players.isEmpty,
              let session,
              session.id == sessionID else {
            return
        }

        let remaining = remainingDuration(for: session)
        guard remaining > Self.minimumPlayableDuration else {
            return
        }

        prepareEngineIfNeeded()
        guard let engine else {
            scheduleRecovery(for: sessionID)
            return
        }

        do {
            try engine.start()
            isEngineStarted = true

            let elapsedAtStart = min(
                session.timeline.totalDuration,
                elapsed(for: session) + Self.schedulingLeadTime
            )
            let patterns = try makePatterns(session: session, elapsed: elapsedAtStart)
            let startTime = engine.currentTime + Self.schedulingLeadTime
            var startedPlayers: [CHHapticPatternPlayer] = []

            do {
                for pattern in patterns {
                    let player = try engine.makePlayer(with: pattern)
                    try player.start(atTime: startTime)
                    startedPlayers.append(player)
                }
            } catch {
                for player in startedPlayers {
                    try? player.stop(atTime: CHHapticTimeImmediate)
                }
                throw error
            }

            players = startedPlayers
        } catch {
            stopPlayers()
            isEngineStarted = false
            engine.stop(completionHandler: nil)
            self.engine = nil
            scheduleRecovery(for: sessionID)
        }
    }

    private func makePatterns(session: Session, elapsed: TimeInterval) throws -> [CHHapticPattern] {
        var patterns: [CHHapticPattern] = []

        if let breathingPattern = try makeBreathingPattern(session: session, elapsed: elapsed) {
            patterns.append(breathingPattern)
        }
        if let reliefPattern = try makeReliefPattern(session: session, elapsed: elapsed) {
            patterns.append(reliefPattern)
        }
        return patterns
    }

    private func makeBreathingPattern(
        session: Session,
        elapsed: TimeInterval
    ) throws -> CHHapticPattern? {
        let cycleDuration = session.timeline.cycleDuration
        let cycleEnd = cycleDuration
        let segmentStart = elapsed
        let duration = cycleEnd - segmentStart
        guard duration > Self.minimumPlayableDuration else {
            return nil
        }

        let midpoint = cycleDuration / 2
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ],
            relativeTime: 0,
            duration: duration
        )

        var controlPoints = [
            CHHapticParameterCurve.ControlPoint(
                relativeTime: 0,
                value: intensity(
                    at: segmentStart,
                    midpoint: midpoint,
                    cycleEnd: cycleEnd
                )
            )
        ]
        if midpoint > segmentStart {
            controlPoints.append(
                CHHapticParameterCurve.ControlPoint(
                    relativeTime: midpoint - segmentStart,
                    value: 0.6
                )
            )
        }
        controlPoints.append(
            CHHapticParameterCurve.ControlPoint(relativeTime: duration, value: 0.15)
        )
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: controlPoints,
            relativeTime: 0
        )

        return try CHHapticPattern(events: [event], parameterCurves: [curve])
    }

    private func makeReliefPattern(
        session: Session,
        elapsed: TimeInterval
    ) throws -> CHHapticPattern? {
        let reliefTime = session.timeline.reliefStart
        guard reliefTime >= elapsed else {
            return nil
        }

        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ],
            relativeTime: reliefTime - elapsed
        )
        return try CHHapticPattern(events: [event], parameters: [])
    }

    private func intensity(
        at time: TimeInterval,
        midpoint: TimeInterval,
        cycleEnd: TimeInterval
    ) -> Float {
        if time <= midpoint {
            let progress = time / max(midpoint, .leastNonzeroMagnitude)
            return Float(0.2 + (0.4 * min(max(progress, 0), 1)))
        }

        let progress = (time - midpoint) / max(cycleEnd - midpoint, .leastNonzeroMagnitude)
        return Float(0.6 - (0.45 * min(max(progress, 0), 1)))
    }

    private func handleEngineStopped(reason: CHHapticEngine.StoppedReason) {
        stopPlayers()
        isEngineStarted = false

        switch reason {
        case .applicationSuspended:
            isAppActive = false
            return
        default:
            break
        }

        guard let session, isAppActive, !isStopInFlight else {
            return
        }
        scheduleRecovery(for: session.id)
    }

    private func handleEngineReset() {
        stopPlayers()
        isEngineStarted = false
        guard let session, isAppActive, !isStopInFlight else {
            return
        }
        scheduleRecovery(for: session.id)
    }

    private func scheduleRecovery(for sessionID: UUID) {
        guard supportsHaptics,
              recoveryTask == nil,
              recoveryAttempts < Self.maximumRecoveryAttempts,
              let session,
              session.id == sessionID,
              isAppActive,
              remainingDuration(for: session) > Self.minimumPlayableDuration else {
            return
        }

        recoveryAttempts += 1
        recoveryTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 150_000_000)
            } catch {
                return
            }
            guard let self else {
                return
            }
            self.recoveryTask = nil
            self.startPlaybackIfPossible(for: sessionID)
        }
    }

    private func stopEngine(preservingSession: Bool) {
        stopPlayers()
        recoveryTask?.cancel()
        recoveryTask = nil

        guard let engine else {
            isEngineStarted = false
            if !preservingSession {
                session = nil
            }
            return
        }

        stopGeneration += 1
        let generation = stopGeneration
        isStopInFlight = true
        engine.stop { [weak self] _ in
            Task { @MainActor in
                guard let self, generation == self.stopGeneration else {
                    return
                }
                self.isStopInFlight = false
                self.isEngineStarted = false
                if !preservingSession {
                    self.session = nil
                }
                guard let session = self.session, self.isAppActive else {
                    return
                }
                self.startPlaybackIfPossible(for: session.id)
            }
        }
    }

    private func stopPlayers() {
        for player in players {
            try? player.stop(atTime: CHHapticTimeImmediate)
        }
        players.removeAll()
    }

    private func elapsed(for session: Session) -> TimeInterval {
        min(
            session.timeline.totalDuration,
            max(0, ProcessInfo.processInfo.systemUptime - session.startedAtUptime)
        )
    }

    private func remainingDuration(for session: Session) -> TimeInterval {
        max(0, session.timeline.totalDuration - elapsed(for: session))
    }
}
