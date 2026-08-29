import DopaBreakCore
import SwiftUI

enum OnboardingThemeSummaryPolicy {
    static func showsThemeCard(for theme: LockTheme) -> Bool {
        theme != .e1
    }

    static func showsPickerProNote(
        for theme: LockTheme,
        isThemeAllowed: (LockTheme) -> Bool
    ) -> Bool {
        !isThemeAllowed(theme)
    }

    static func showsSummaryProNote(
        for theme: LockTheme,
        isThemeAllowed: (LockTheme) -> Bool
    ) -> Bool {
        !isThemeAllowed(theme)
    }
}

struct LockThemePickerView: View {
    static let renderedThemes = LockTheme.allCases

    let selectedTheme: LockTheme
    let goalTitles: [String]
    let cancelledCount: Int
    let attemptCount: Int
    let isThemeAllowed: (LockTheme) -> Bool
    let onSelect: (LockTheme) -> Void
    var onSelectedThemeRendered: ((LockTheme) -> Void)? = nil

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(Self.renderedThemes, id: \.self) { theme in
                let showsProBadge = !isThemeAllowed(theme)
                Button {
                    onSelect(theme)
                } label: {
                    LockThemePreviewCard(
                        theme: theme,
                        goalTitles: resolvedGoalTitles,
                        cancelledCount: cancelledCount,
                        attemptCount: attemptCount,
                        isSelected: selectedTheme == theme,
                        showsProBadge: showsProBadge
                    )
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .onAppear {
                        if selectedTheme == theme {
                            onSelectedThemeRendered?(theme)
                        }
                    }
                    .onChange(of: selectedTheme) { _, selection in
                        if selection == theme {
                            onSelectedThemeRendered?(theme)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(for: theme, showsProBadge: showsProBadge))
                .accessibilityAddTraits(selectedTheme == theme ? [.isSelected] : [])
                .accessibilityIdentifier("lock-theme-picker-\(theme.rawValue)")
            }
        }
        .accessibilityIdentifier("lock-theme-picker")
    }

    private func accessibilityLabel(for theme: LockTheme, showsProBadge: Bool) -> String {
        guard showsProBadge else { return theme.localizedDisplayName }
        let proLabel = String(localized: "settings.status.pro", defaultValue: "Pro")
        return "\(theme.localizedDisplayName) \(proLabel)"
    }

    private var resolvedGoalTitles: [String] {
        let titles = goalTitles.filter { !$0.isEmpty }
        return titles.isEmpty
            ? [String(localized: "lock_check.preview.goal_fallback", defaultValue: "あなたの目標")]
            : titles
    }
}

struct LockThemePreviewCard: View {
    let theme: LockTheme
    let goalTitles: [String]
    let cancelledCount: Int
    let attemptCount: Int
    var isSelected = false
    var showsProBadge = false
    var onLayout: ((CGSize) -> Void)? = nil

    var body: some View {
        GeometryReader { proxy in
            let scale = min(1, proxy.size.width / 393)

            ZStack(alignment: .topTrailing) {
                LockThemeLiveActivityView(
                    theme: theme,
                    goalTitles: goalTitles,
                    cancelledCount: cancelledCount,
                    attemptCount: attemptCount
                )
                .frame(width: 393, height: 160)
                .scaleEffect(scale, anchor: .center)
                .frame(width: 393 * scale, height: 160 * scale)
                .clipShape(
                    RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                )
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                            .stroke(DesignTokens.accent, lineWidth: 2)
                    }
                }

                HStack(spacing: 6) {
                    if showsProBadge {
                        Text(String(localized: "settings.status.pro", defaultValue: "Pro"))
                            .dopaFont(11, weight: .black)
                            .foregroundStyle(DesignTokens.background)
                            .padding(.horizontal, 8)
                            .frame(minHeight: 24)
                            .background(DesignTokens.accent)
                            .clipShape(Capsule())
                    }

                    if isSelected {
                        Image(systemName: "checkmark")
                            .dopaFont(12, weight: .black)
                            .foregroundStyle(DesignTokens.background)
                            .frame(width: 24, height: 24)
                            .background(DesignTokens.accent)
                            .clipShape(Circle())
                            .accessibilityHidden(true)
                    }
                }
                .padding(10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { onLayout?(proxy.size) }
            .onChange(of: proxy.size) { _, size in onLayout?(size) }
        }
        .aspectRatio(393 / 160, contentMode: .fit)
        .frame(maxWidth: 393)
    }
}
