import DopaBreakCore
import Foundation

extension InterventionMode {
    var displayTitle: String {
        switch self {
        case .deepFocus:
            return String(localized: "intervention_mode.deep_focus.title", defaultValue: "ディープフォーカス")
        case .standard:
            return String(localized: "intervention_mode.standard.title", defaultValue: "標準")
        case .nightOnly:
            return String(localized: "intervention_mode.night_only.title", defaultValue: "夜だけ強化")
        }
    }

    var detailText: String {
        switch self {
        case .deepFocus:
            return String(
                localized: "intervention_mode.deep_focus.detail",
                defaultValue: "決めた時間は選んだアプリを完全ブロック"
            )
        case .standard:
            return String(
                localized: "intervention_mode.standard.detail",
                defaultValue: "SNSを開く前にひと呼吸と理由確認"
            )
        case .nightOnly:
            return String(
                localized: "intervention_mode.night_only.detail",
                defaultValue: "就寝から起床まで完全ブロックする"
            )
        }
    }
}
