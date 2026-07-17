import DopaBreakCore

extension InterventionMode {
    var displayTitle: String {
        switch self {
        case .deepFocus:
            return "ディープフォーカス"
        case .standard:
            return "標準"
        case .nightOnly:
            return "夜だけ強化"
        }
    }

    var detailText: String {
        switch self {
        case .deepFocus:
            return "作業中はSNSを開く前に強く止める"
        case .standard:
            return "SNSを開く前にひと呼吸と理由確認"
        case .nightOnly:
            return "夜は確認を強くして開きすぎを防ぐ"
        }
    }
}
