import DopaBreakCore
import FamilyControls
import ManagedSettings
import SwiftUI

enum AppIconSource {
    case catalog(SNSAppCatalogItem)
    case token(ApplicationToken)

    var accessibilityName: String {
        switch self {
        case .catalog(let item):
            return item.displayName
        case .token:
            return String(localized: "shortcuts.intervention.parameter.app", defaultValue: "アプリ")
        }
    }
}

/// カタログのブランド色タイルと、Screen Timeが提供する実アプリアイコンを同じ寸法で扱う。
struct AppIconView: View {
    let source: AppIconSource
    var size: CGFloat = 44

    var body: some View {
        Group {
            switch source {
            case .catalog(let item):
                catalogTile(item)
            case .token(let token):
                Label(token)
                    .labelStyle(.iconOnly)
                    .frame(width: min(size, 30), height: min(size, 30))
                    .clipped()
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(source.accessibilityName)
    }

    private func catalogTile(_ item: SNSAppCatalogItem) -> some View {
        ZStack {
            tileBackground(for: item.catalogID)
            if item.catalogID == "tiktok" {
                tiktokGlyph(item.symbolName)
            } else {
                Image(systemName: item.symbolName)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(symbolColor(for: item.catalogID))
            }
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .strokeBorder(innerRingColor(for: item.catalogID), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
    }

    @ViewBuilder
    private func tileBackground(for catalogID: String) -> some View {
        switch catalogID {
        case "instagram":
            LinearGradient(
                colors: [Self.color(0xF9CE34), Self.color(0xEE2A7B), Self.color(0x6228D7)],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
        case "x", "tiktok", "threads":
            Color.black
        case "youtube":
            Self.color(0xFF0033)
        case "facebook":
            Self.color(0x1877F2)
        case "line":
            Self.color(0x06C755)
        case "safari":
            LinearGradient(
                colors: [Self.color(0x2FB4FF), Self.color(0x0A84FF)],
                startPoint: .top,
                endPoint: .bottom
            )
        default:
            DesignTokens.card
        }
    }

    private func tiktokGlyph(_ symbolName: String) -> some View {
        ZStack {
            Image(systemName: symbolName)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(Self.color(0x25F4EE))
                .offset(x: -1.5, y: -1.5)
            Image(systemName: symbolName)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(Self.color(0xFE2C55))
                .offset(x: 1.5, y: 1.5)
            Image(systemName: symbolName)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(Color.white)
        }
    }

    private func innerRingColor(for catalogID: String) -> Color {
        if ["x", "tiktok", "threads"].contains(catalogID) {
            return Self.color(0x2A2A2A)
        }
        return Color.white.opacity(0.08)
    }

    private func symbolColor(for catalogID: String) -> Color {
        let knownCatalogIDs = [
            "instagram", "x", "youtube", "facebook", "threads", "line", "safari"
        ]
        return knownCatalogIDs.contains(catalogID) ? Color.white : DesignTokens.primaryText
    }

    private static func color(_ rgb: UInt32) -> Color {
        Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

struct AppIconStack: View {
    let sources: [AppIconSource]
    var size: CGFloat = 44
    var maxVisible: Int = 4
    var showsStatusDots = false

    private var visibleSources: [AppIconSource] {
        Array(sources.prefix(max(0, maxVisible)))
    }

    private var overflowCount: Int {
        max(0, sources.count - visibleSources.count)
    }

    private var displayedCount: Int {
        visibleSources.count + (overflowCount > 0 ? 1 : 0)
    }

    private var stride: CGFloat {
        size * 0.7
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(visibleSources.indices), id: \.self) { index in
                framedIcon(visibleSources[index])
                    .offset(x: CGFloat(index) * stride)
                    .zIndex(Double(index))
            }

            if overflowCount > 0 {
                Text(verbatim: "+\(overflowCount)")
                    .dopaFont(size * 0.28, weight: .black, design: .rounded)
                    .foregroundStyle(DesignTokens.primaryText)
                    .frame(width: size, height: size)
                    .background(DesignTokens.backgroundRaised)
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                            .stroke(DesignTokens.background, lineWidth: 2)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
                    .offset(x: CGFloat(visibleSources.count) * stride)
                    .zIndex(Double(visibleSources.count))
            }

            if showsStatusDots {
                ForEach(Array(visibleSources.indices), id: \.self) { index in
                    statusDot
                        .offset(
                            x: CGFloat(index) * stride + size - 8,
                            y: 1
                        )
                        .zIndex(100 + Double(index))
                }
            }
        }
        .frame(
            width: displayedCount == 0 ? 0 : size + CGFloat(displayedCount - 1) * stride,
            height: size,
            alignment: .leading
        )
    }

    private func framedIcon(_ source: AppIconSource) -> some View {
        AppIconView(source: source, size: size)
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                    .stroke(DesignTokens.background, lineWidth: 2)
            }
    }

    private var statusDot: some View {
        Circle()
            .fill(DesignTokens.accent)
            .frame(width: 8, height: 8)
            .overlay {
                Circle().stroke(DesignTokens.background, lineWidth: 2)
            }
    }
}
