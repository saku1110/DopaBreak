import DopaBreakCore
import SwiftUI

struct TargetAppGrid: View {
    enum Style {
        case regular
        case large
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let items: [SNSAppCatalogItem]
    let selectedCatalogIDs: Set<String>
    var style: Style = .regular
    var onboardingStaggerBase: Int? = nil
    let onToggle: (SNSAppCatalogItem) -> Void

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: layout.gridSpacing),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
        )
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: layout.gridSpacing) {
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
            VStack(spacing: layout.labelSpacing) {
                AppIconView(source: .catalog(item), size: layout.iconSize)

                Text(item.displayName)
                    .dopaFont(layout.fontSize, weight: .semibold)
                    .foregroundStyle(DesignTokens.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.vertical, layout.verticalPadding)
            .frame(maxWidth: .infinity, minHeight: layout.minHeight)
            .background(DesignTokens.card)
            .overlay(alignment: .topTrailing) {
                selectionIndicator(isSelected: isSelected)
                    .padding(.top, 10)
                    .padding(.trailing, 10)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? DesignTokens.accent : DesignTokens.hairline,
                        lineWidth: isSelected ? 2 : 1
                    )
                    .animation(reduceMotion ? nil : DopaMotion.control, value: isSelected)
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
            .animation(reduceMotion ? nil : DopaMotion.select, value: isSelected)
            .frame(width: layout.indicatorSize, height: layout.indicatorSize)
            .phaseAnimator([1.0, 1.08, 1.0], trigger: isSelected) { content, scale in
                content.scaleEffect(reduceMotion ? 1 : scale)
            } animation: { _ in
                reduceMotion ? nil : DopaMotion.select
            }
            .accessibilityHidden(true)
    }

    private var layout: Layout {
        switch style {
        case .regular:
            Layout(
                iconSize: 50,
                fontSize: 15,
                horizontalPadding: 12,
                verticalPadding: 11,
                minHeight: 108,
                gridSpacing: 8,
                labelSpacing: 8,
                indicatorSize: 22
            )
        case .large:
            Layout(
                iconSize: 60,
                fontSize: 17,
                horizontalPadding: 14,
                verticalPadding: 16,
                minHeight: 124,
                gridSpacing: 12,
                labelSpacing: 10,
                indicatorSize: 24
            )
        }
    }

    private struct Layout {
        let iconSize: CGFloat
        let fontSize: CGFloat
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let minHeight: CGFloat
        let gridSpacing: CGFloat
        let labelSpacing: CGFloat
        let indicatorSize: CGFloat
    }
}

private struct TargetAppCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.985 : 1))
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : DopaMotion.control, value: configuration.isPressed)
    }
}
