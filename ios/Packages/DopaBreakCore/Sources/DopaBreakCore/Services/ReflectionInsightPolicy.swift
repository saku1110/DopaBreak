import Foundation

/// A suggestion from answered reflections, not an estimate of time or a diagnosis.
public struct ReflectionInsight: Equatable, Sendable {
    public let answerCount: Int
    public let regretCount: Int
}

public enum ReflectionInsightPolicy {
    public static func insight(counts: [PostUseSatisfaction: Int]) -> ReflectionInsight? {
        let answers = counts.values.reduce(0) { $0 + max(0, $1) }
        let regrets = max(0, counts[.lostTime] ?? 0) + max(0, counts[.feltWorse] ?? 0)
        guard answers >= 5, Double(regrets) / Double(answers) >= 0.6 else { return nil }
        return ReflectionInsight(answerCount: answers, regretCount: regrets)
    }
}
