import SwiftUI

struct DopaRing: View {
    let progress: Double
    let expression: CharacterExpression
    var diameter: CGFloat = 188

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(DesignTokens.accent.opacity(0.18), lineWidth: 6)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    DesignTokens.accent,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            CharacterView(expression, size: diameter * 0.72)
        }
        .frame(width: diameter, height: diameter)
        .animation(DopaMotion.transition, value: clampedProgress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(localized: "stats.rate.title", defaultValue: "開かなかった割合")
        )
        .accessibilityValue(
            String(
                localized: "stats.rate.percentage",
                defaultValue: "\(Int((clampedProgress * 100).rounded()))%%"
            )
        )
    }
}
