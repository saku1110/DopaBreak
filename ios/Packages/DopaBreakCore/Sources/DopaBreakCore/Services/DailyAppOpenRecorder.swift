import Foundation

public struct DailyAppOpenRecorder {
    private let settingsStore: SettingsStore
    private let funnelEventStore: FunnelEventStore
    private let calendar: Calendar

    public init(
        settingsStore: SettingsStore,
        funnelEventStore: FunnelEventStore,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.settingsStore = settingsStore
        self.funnelEventStore = funnelEventStore
        self.calendar = calendar
    }

    @discardableResult
    public func recordIfNeeded(at date: Date) throws -> Bool {
        let dateKey = localDateKey(for: date)
        guard settingsStore.lastAppOpenedDateKey.map({ dateKey > $0 }) ?? true else {
            return false
        }

        try funnelEventStore.record(name: .appOpened, at: date)
        settingsStore.lastAppOpenedDateKey = dateKey
        return true
    }

    private func localDateKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
