import Foundation

/// 起床・就寝タイムラインの座標変換と制約を一箇所で決める純関数。
public enum WakeSleepTimelinePolicy {
    public static let minutesPerDay = 1_440
    public static let stepMinutes = 15
    public static let minimumGapMinutes = 60
    public static let latestMinute = minutesPerDay - stepMinutes

    public static func time(forOffset offset: Double, trackWidth: Double) -> Int {
        guard trackWidth > 0 else { return 0 }
        let progress = min(max(offset / trackWidth, 0), 1)
        return min(Int((progress * Double(minutesPerDay)).rounded()), minutesPerDay - 1)
    }

    public static func offset(forTime time: Int, trackWidth: Double) -> Double {
        guard trackWidth > 0 else { return 0 }
        let clampedTime = min(max(time, 0), minutesPerDay)
        return Double(clampedTime) / Double(minutesPerDay) * trackWidth
    }

    public static func snapped(_ time: Int) -> Int {
        let step = Double(time) / Double(stepMinutes)
        let roundedTime = Int(step.rounded()) * stepMinutes
        return min(max(roundedTime, 0), latestMinute)
    }

    /// 24時間の円環上で、動かす起床ハンドルだけを有効範囲へ止める。
    public static func clampedWake(
        _ proposedWake: Int,
        bed: Int,
        current: Int,
        snapToStep: Bool = true
    ) -> Int {
        clampedMovingTime(
            proposedWake,
            fixedTime: bed,
            currentTime: current,
            snapToStep: snapToStep
        )
    }

    /// 24時間の円環上で、動かす就寝ハンドルだけを有効範囲へ止める。
    public static func clampedBed(
        _ proposedBed: Int,
        wake: Int,
        current: Int,
        snapToStep: Bool = true
    ) -> Int {
        clampedMovingTime(
            proposedBed,
            fixedTime: wake,
            currentTime: current,
            snapToStep: snapToStep
        )
    }

    /// 両方向の弧がそれぞれ最小60分あるかを返す。
    public static func hasValidArcs(wake: Int, bed: Int) -> Bool {
        let nightArc = clockwiseDistance(from: bed, to: wake)
        let dayArc = clockwiseDistance(from: wake, to: bed)
        return nightArc >= minimumGapMinutes && dayArc >= minimumGapMinutes
    }

    public static func normalized(_ time: Int) -> Int {
        let remainder = time % minutesPerDay
        return remainder >= 0 ? remainder : remainder + minutesPerDay
    }

    private static func clampedMovingTime(
        _ proposedTime: Int,
        fixedTime: Int,
        currentTime: Int,
        snapToStep: Bool
    ) -> Int {
        let candidate = snapToStep ? snapped(proposedTime) : normalized(proposedTime)
        let fixed = normalized(fixedTime)
        let forward = clockwiseDistance(from: fixed, to: candidate)
        let current = normalized(currentTime)
        let currentForward = clockwiseDistance(from: fixed, to: current)
        let currentIsAtBoundary = currentForward == minimumGapMinutes
            || currentForward == minutesPerDay - minimumGapMinutes
        let currentIsClockwise = currentForward <= minutesPerDay / 2
        let candidateIsClockwise = forward <= minutesPerDay / 2
        if snapToStep && currentIsAtBoundary && currentIsClockwise != candidateIsClockwise {
            return current
        }
        guard forward < minimumGapMinutes || forward > minutesPerDay - minimumGapMinutes else {
            return candidate
        }

        return normalized(fixed + (currentIsClockwise ? minimumGapMinutes : -minimumGapMinutes))
    }

    private static func clockwiseDistance(from start: Int, to end: Int) -> Int {
        normalized(end - start)
    }
}
