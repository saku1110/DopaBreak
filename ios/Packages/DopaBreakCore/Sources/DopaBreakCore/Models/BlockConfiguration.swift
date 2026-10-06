import Foundation

public enum BlockTrigger: String, Codable, CaseIterable, Sendable {
    case manual
    case weeklySchedule
    case night
}

/// One Pro capability. Trigger choices survive entitlement loss.
public struct BlockConfiguration: Codable, Equatable, Sendable {
    public var blockEnabled: Bool
    public var blockTriggers: Set<BlockTrigger>

    public init(blockEnabled: Bool = false, blockTriggers: Set<BlockTrigger> = []) {
        self.blockEnabled = blockEnabled
        self.blockTriggers = blockTriggers
    }

    public static func migrating(_ mode: InterventionMode, weeklySchedulesDuringNightEnabled: Bool = false) -> Self {
        switch mode {
        case .standard: return Self()
        case .deepFocus: return Self(blockEnabled: true, blockTriggers: [.manual, .weeklySchedule])
        case .nightOnly:
            return Self(blockEnabled: true, blockTriggers: weeklySchedulesDuringNightEnabled ? [.night, .weeklySchedule] : [.night])
        }
    }

    public func allows(_ trigger: BlockTrigger) -> Bool {
        blockEnabled && blockTriggers.contains(trigger)
    }

    public mutating func reconcileEntitlement(isPro: Bool, hasConfirmedEntitlement: Bool) {
        guard hasConfirmedEntitlement else { return }
        if isPro && blockTriggers.isEmpty {
            blockTriggers = Set(BlockTrigger.allCases)
        }
        blockEnabled = isPro && !blockTriggers.isEmpty
    }

    public func isActive(manual: Bool, weeklySchedule: Bool, night: Bool) -> Bool {
        (allows(.manual) && manual) || (allows(.weeklySchedule) && weeklySchedule) || (allows(.night) && night)
    }
}

/// A successfully armed trigger currently blocking apps. Optional end means user-ended or continuous.
public struct BlockWindowStatus: Codable, Hashable, Sendable {
    public var trigger: BlockTrigger
    public var endsAt: Date?

    public init(trigger: BlockTrigger, endsAt: Date?) {
        self.trigger = trigger
        self.endsAt = endsAt
    }

    public static func active(deepFocus: DeepFocusShieldSnapshot?, night: NightShieldSnapshot?,
                              now: Date, calendar: Calendar) -> [Self] {
        var result: [Self] = []
        if let deepFocus {
            if !(deepFocus.sessionSelectionDataList ?? deepFocus.selectionDataList).isEmpty,
               let session = DeepFocusWindowPolicy.activeSession(deepFocus.session, now: now) {
                result.append(Self(trigger: .manual, endsAt: session.endsAt))
            }
            if !deepFocus.selectionDataList.isEmpty,
               DeepFocusWindowPolicy.isScheduleActive(now: now, schedules: deepFocus.schedules, calendar: calendar) {
                result.append(Self(trigger: .weeklySchedule, endsAt: DeepFocusWindowPolicy.scheduleWindowEnd(
                    now: now, schedules: deepFocus.schedules, calendar: calendar)))
            }
        }
        if let night, !night.selectionDataList.isEmpty,
           NightWindowPolicy.isNight(now: now, snapshot: night, calendar: calendar) {
            let end = calendar.nextDate(after: now,
                matching: DateComponents(hour: night.wakeTimeMinutes / 60, minute: night.wakeTimeMinutes % 60),
                matchingPolicy: .nextTime)
            result.append(Self(trigger: .night, endsAt: end))
        }
        return result
    }
}
