import DopaBreakCore
import SwiftUI

struct TargetAppGrid: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let items: [SNSAppCatalogItem]
    let selectedCatalogIDs: Set<String>
    var onboardingStaggerBase: Int? = nil
    let onToggle: (SNSAppCatalogItem) -> Void

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 8),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
        )
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                staggeredAppCard(item, index: index)
            }
        }
    }

    @ViewBuilder
    private func staggeredAppCard(_ item: SNSAppCatalogItem, index: Int) -> some View {
        if let onboardingStaggerBase {
            appCard(item)
                .onboardingStagger(onboardingStaggerBase + index)
        } else {
            appCard(item)
        }
    }

    private func appCard(_ item: SNSAppCatalogItem) -> some View {
        let isSelected = selectedCatalogIDs.contains(item.catalogID)
        return Button {
            onToggle(item)
        } label: {
            HStack(spacing: 10) {
                AppIconView(source: .catalog(item), size: 50)

                Text(item.displayName)
                    .dopaFont(15, weight: .semibold)
                    .foregroundStyle(DesignTokens.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 0)

                selectionIndicator(isSelected: isSelected)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(DesignTokens.card)
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? DesignTokens.accent : DesignTokens.hairline,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous))
        }
        .buttonStyle(TargetAppCardButtonStyle())
        .accessibilityLabel(item.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        Circle()
            .fill(isSelected ? DesignTokens.accent : Color.clear)
            .overlay {
                Circle()
                    .stroke(
                        isSelected ? DesignTokens.accent : DesignTokens.secondaryText,
                        lineWidth: 1.5
                    )
            }
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)
    }
}

private struct TargetAppCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(DopaMotion.control, value: configuration.isPressed)
    }
}
