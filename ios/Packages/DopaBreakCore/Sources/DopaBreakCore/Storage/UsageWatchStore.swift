import Foundation

public final class UsageWatchStore: @unchecked Sendable {
    private enum Key {
        static let configuration = "usageWatch.configuration"
        static let state = "usageWatch.state"
    }

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    public convenience init() throws {
        guard let userDefaults = UserDefaults(suiteName: AppGroup.identifier) else {
            throw CoreError.appGroupUnavailable(AppGroup.identifier)
        }
        self.init(userDefaults: userDefaults)
    }

    public func loadConfiguration() -> UsageWatchConfiguration {
        guard let data = userDefaults.data(forKey: Key.configuration),
              let configuration = try? decoder.decode(UsageWatchConfiguration.self, from: data) else {
            return UsageWatchConfiguration()
        }
        return configuration
    }

    public func saveConfiguration(_ configuration: UsageWatchConfiguration) {
        guard let data = try? encoder.encode(configuration) else {
            return
        }
        userDefaults.set(data, forKey: Key.configuration)
    }

    public func updateConfiguration(
        _ update: (inout UsageWatchConfiguration) -> Void
    ) {
        var configuration = loadConfiguration()
        update(&configuration)
        saveConfiguration(configuration)
    }

    public func loadState() -> UsageWatchState {
        guard let data = userDefaults.data(forKey: Key.state),
              let state = try? decoder.decode(UsageWatchState.self, from: data) else {
            return UsageWatchState()
        }
        return state
    }

    public func saveState(_ state: UsageWatchState) {
        guard let data = try? encoder.encode(state) else {
            return
        }
        userDefaults.set(data, forKey: Key.state)
    }

    public func updateState(_ update: (inout UsageWatchState) -> Void) {
        var state = loadState()
        update(&state)
        saveState(state)
    }

    public func recordIntervention(at date: Date) {
        updateState { state in
            state.lastInterventionAt = date
        }
    }

    public func muteForToday(at date: Date, calendar: Calendar = .current) {
        guard let dayInterval = calendar.dateInterval(of: .day, for: date) else {
            return
        }
        updateState { state in
            state.mutedUntil = dayInterval.end
        }
    }

    public func resetDailyState(at date: Date = .now, calendar: Calendar = .current) {
        let state = loadState()
        if let dayStart = state.dayStart,
           calendar.isDate(dayStart, inSameDayAs: date) {
            return
        }
        saveState(state.resettingDailyFields(at: date, calendar: calendar))
    }

    public func clear() {
        userDefaults.removeObject(forKey: Key.configuration)
        userDefaults.removeObject(forKey: Key.state)
    }
}
