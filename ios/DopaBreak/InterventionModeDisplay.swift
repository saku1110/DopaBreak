import DopaBreakCore
import Foundation

extension InterventionMode {
    var displayTitle: String {
        switch self {
        case .standard:
            return String(localized: "onboarding.block.breath_title", defaultValue: "開く前に一呼吸")
        case .deepFocus, .nightOnly:
            return String(localized: "onboarding.block.pro_title", defaultValue: "一呼吸＋完全ブロック")
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
                defaultValue: "就寝から起床までアプリをブロック"
            )
        }
    }
}


extension BlockTrigger {
    var displayTitle: String {
        switch self {
        case .manual: return String(localized: "block.trigger.manual", defaultValue: "手動セッション")
        case .weeklySchedule: return String(localized: "block.trigger.weekly", defaultValue: "毎週の予定")
        case .night: return String(localized: "block.trigger.night", defaultValue: "就寝中は自動")
        }
    }
    var shortTitle: String {
        switch self {
        case .manual: return String(localized: "block.state.manual", defaultValue: "手動")
        case .weeklySchedule: return String(localized: "block.state.weekly", defaultValue: "予定")
        case .night: return String(localized: "block.state.night", defaultValue: "就寝中")
        }
    }
}

extension BlockConfiguration {
    var triggerSummary: String {
        let names = BlockTrigger.allCases.filter { blockTriggers.contains($0) }.map(\.shortTitle)
        let value = blockEnabled && !names.isEmpty ? names.joined(separator: "／") : String(localized: "block.state.off", defaultValue: "オフ")
        return String(localized: "block.state.summary", defaultValue: "ブロック: \(value)")
    }
}
