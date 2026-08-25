import Foundation

/// キャンセル時に確定する「開かなかった推定時間」を一箇所で算出する。
public enum ReclaimedTimeEstimator {
    public static let defaultSeconds = 300
    public static let historyWindow: TimeInterval = 30 * 86_400

    public static func estimatedSeconds(
        at reference: Date,
        logStore: SQLiteLogStore
    ) throws -> Int {
        let durations = try logStore.fetchAttempts(
            from: reference.addingTimeInterval(-historyWindow),
            to: reference
        )
        .filter { $0.decision == .opened }
        .compactMap(\.selectedDurationSeconds)
        .filter { $0 > 0 }

        return median(of: durations) ?? defaultSeconds
    }

    static func median(of values: [Int]) -> Int? {
        let sortedValues = values.sorted()
        guard !sortedValues.isEmpty else { return nil }
        let middle = sortedValues.count / 2
        if sortedValues.count.isMultiple(of: 2) {
            let lower = sortedValues[middle - 1]
            let upper = sortedValues[middle]
            return lower + (upper - lower) / 2
        }
        return sortedValues[middle]
    }
}
