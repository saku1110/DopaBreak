import DopaBreakCore
import SwiftUI

/// 目標カテゴリの見た目定義。Coreの列挙型は表示都合を持たないため、アプリ側で色と記号を与える。
/// ホーム・目標一覧・編集シートの3画面が同じ定義を参照し、カテゴリの見え方をそろえる。
extension GoalCategory {
    /// カテゴリを表すSFシンボル。
    var symbolName: String {
        switch self {
        case .study: return "book.fill"
        case .work: return "briefcase.fill"
        case .health: return "figure.run"
        case .sleep: return "moon.stars.fill"
        case .creative: return "paintbrush.fill"
        case .other: return "star.fill"
        }
    }

    /// カテゴリ色。ライムは「学び」だけに割り当て、他は塗り面積の小さいタイルにだけ使う。
    var tint: Color {
        switch self {
        case .study: return DesignTokens.accent
        case .work: return Color(red: 138.0 / 255.0, green: 180.0 / 255.0, blue: 255.0 / 255.0)
        case .health: return Color(red: 245.0 / 255.0, green: 143.0 / 255.0, blue: 180.0 / 255.0)
        case .sleep: return Color(red: 185.0 / 255.0, green: 166.0 / 255.0, blue: 255.0 / 255.0)
        case .creative: return Color(red: 255.0 / 255.0, green: 184.0 / 255.0, blue: 107.0 / 255.0)
        case .other: return DesignTokens.secondaryText
        }
    }
}

/// カテゴリのアイコンタイル。地はカテゴリ色14%、記号はカテゴリ色。
struct GoalCategoryTile: View {
    let category: GoalCategory
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: category.symbolName)
            .font(.system(size: size * 0.41, weight: .semibold))
            .foregroundStyle(category.tint)
            .frame(width: size, height: size)
            .background(category.tint.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
            .accessibilityHidden(true)
    }
}
