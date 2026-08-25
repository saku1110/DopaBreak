import DopaBreakCore
import Foundation

extension LockTheme {
    var localizedDisplayName: String {
        switch self {
        case .e1:
            return String(localized: "lock_surface.theme.e1", defaultValue: "黒とライム")
        case .sumi:
            return String(localized: "lock_surface.theme.sumi", defaultValue: "墨と灯")
        case .asagiri:
            return String(localized: "lock_surface.theme.asagiri", defaultValue: "朝霧")
        case .shinrin:
            return String(localized: "lock_surface.theme.shinrin", defaultValue: "森林")
        case .yozora:
            return String(localized: "lock_surface.theme.yozora", defaultValue: "夜更け")
        case .kpop:
            return String(localized: "lock_surface.theme.kpop", defaultValue: "K-POP")
        case .kawaiiPink:
            return String(localized: "lock_surface.theme.kawaiiPink", defaultValue: "かわいいピンク")
        }
    }
}
