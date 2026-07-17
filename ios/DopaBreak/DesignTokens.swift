import SwiftUI
import DopaBreakCore
import UIKit

extension Color {
    init(lockThemeColor color: LockThemeColor) {
        self.init(
            red: Double(color.red) / 255,
            green: Double(color.green) / 255,
            blue: Double(color.blue) / 255
        )
    }
}

enum DesignTokens {
    static let background = Color(red: 11.0 / 255.0, green: 13.0 / 255.0, blue: 15.0 / 255.0)
    static let backgroundRaised = Color(red: 15.0 / 255.0, green: 18.0 / 255.0, blue: 21.0 / 255.0)
    static let card = Color(red: 20.0 / 255.0, green: 23.0 / 255.0, blue: 27.0 / 255.0)
    static let cardPressed = Color(red: 25.0 / 255.0, green: 29.0 / 255.0, blue: 33.0 / 255.0)
    static let primaryText = Color(red: 244.0 / 255.0, green: 245.0 / 255.0, blue: 242.0 / 255.0)
    static let secondaryText = Color(red: 126.0 / 255.0, green: 134.0 / 255.0, blue: 148.0 / 255.0)
    static let tertiaryText = Color(red: 91.0 / 255.0, green: 98.0 / 255.0, blue: 108.0 / 255.0)
    static let accent = Color(red: 199.0 / 255.0, green: 249.0 / 255.0, blue: 77.0 / 255.0)
    static let danger = Color(red: 255.0 / 255.0, green: 107.0 / 255.0, blue: 90.0 / 255.0)
    static let hairline = Color.white.opacity(0.11)
    static let strongHairline = Color.white.opacity(0.18)
    static let cardRadius: CGFloat = 16
    static let horizontalPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 16
}

struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(DesignTokens.background)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(isEnabled ? DesignTokens.accent : DesignTokens.secondaryText.opacity(0.3))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(isEnabled ? 0.18 : 0))
                    .frame(height: 1)
                    .padding(.horizontal, 12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(DesignTokens.primaryText)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(configuration.isPressed ? DesignTokens.cardPressed : DesignTokens.backgroundRaised)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(DesignTokens.strongHairline, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct CardContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous)
                    .stroke(DesignTokens.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cardRadius, style: .continuous))
    }
}

struct SmallLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(DesignTokens.secondaryText)
            .tracking(1.5)
            .textCase(.none)
    }
}

struct ScreenHeader: View {
    let eyebrow: String
    let title: String
    var trailingText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                SmallLabel(text: eyebrow)
                Spacer()
                if let trailingText {
                    Text(trailingText)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(DesignTokens.secondaryText)
                }
            }
            Text(title)
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(DesignTokens.primaryText)
                .tracking(-0.7)
        }
    }
}

struct SignalLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 9) {
            Capsule()
                .fill(DesignTokens.accent)
                .frame(width: 3, height: 18)
            Text(text)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DesignTokens.accent)
        }
    }
}

struct MetricBlock: View {
    let label: String
    let value: String
    var accent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(value)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accent ? DesignTokens.accent : DesignTokens.primaryText)
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DesignTokens.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MorningHorizon: View {
    var height: CGFloat
    var alignment: Alignment = .center
    var bottomFade: CGFloat = 0.92

    var body: some View {
        horizonImage
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: height, alignment: alignment)
            .clipped()
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: DesignTokens.background.opacity(0.18), location: 0),
                        .init(color: DesignTokens.background.opacity(0.26), location: 0.48),
                        .init(color: DesignTokens.background.opacity(bottomFade), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .accessibilityHidden(true)
    }

    private var horizonImage: Image {
        guard
            let url = Bundle.main.url(forResource: "morning-horizon", withExtension: "png"),
            let image = UIImage(contentsOfFile: url.path)
        else {
            return Image(systemName: "photo")
        }
        return Image(uiImage: image)
    }
}

extension View {
    func dopaScreenBackground() -> some View {
        background(
            LinearGradient(
                colors: [DesignTokens.backgroundRaised.opacity(0.72), DesignTokens.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}
