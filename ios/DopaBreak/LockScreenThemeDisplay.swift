import DopaBreakCore
import Foundation

extension LockTheme {
    var localizedDisplayName: String {
        switch self {
        case .e1:
            return String(localized: "lock_surface.theme.e1", defaultValue: "黒とライム")
        case .gaming:
            return String(localized: "lock_surface.theme.gaming", defaultValue: "ゲーミング")
        case .asagiri:
            return String(localized: "lock_surface.theme.asagiri", defaultValue: "朝霧")
        case .monochrome:
            return String(localized: "lock_surface.theme.monochrome", defaultValue: "モノクロ")
        case .liquidGlass:
            return String(localized: "lock_surface.theme.liquidGlass", defaultValue: "リキッドグラス")
        case .kpop:
            return String(localized: "lock_surface.theme.kpop", defaultValue: "K-POP")
        case .kawaiiPink:
            return String(localized: "lock_surface.theme.kawaiiPink", defaultValue: "かわいいピンク")
        case .note:
            return String(localized: "lock_surface.theme.note", defaultValue: "手書きノート")
        case .spiderWeb:
            return String(localized: "lock_surface.theme.spiderWeb", defaultValue: "スパイダーウェブ")
        case .blueprint:
            return String(localized: "lock_surface.theme.blueprint", defaultValue: "設計図")
        }
    }
}
