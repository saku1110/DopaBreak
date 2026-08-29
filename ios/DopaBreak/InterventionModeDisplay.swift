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
                defaultValue: "決めた時間だけアプリを開けなくする"
            )
        case .standard:
            return String(
                localized: "intervention_mode.standard.detail",
                defaultValue: "開く前に一呼吸して理由を確かめる"
            )
        case .nightOnly:
            return String(
                localized: "intervention_mode.night_only.detail",
                defaultValue: "就寝時刻から起床時刻までアプリを開けなくする"
            )
        }
    }
}
