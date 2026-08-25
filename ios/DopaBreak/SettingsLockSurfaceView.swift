import DopaBreakCore
import SwiftUI

struct SettingsLockSurfaceView: View {
    let model: AppModel
    let settingsStore: SettingsStore

    @Binding var selectedLockTheme: LockTheme
    @Binding var liveActivityEnabled: Bool
    @Binding var isLockScreenCheckPresented: Bool
    @Binding var paywallPlacement: PaywallPlacement?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                SmallLabel(
                    text: String(
                        localized: "settings.entry.lock_surface",
                        defaultValue: "ロック画面の表示"
                    )
                )

                CardContainer {
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                SettingsIconTile(systemName: "paintpalette.fill")
                                Text(
                                    String(
                                        localized: "settings.lock_screen.theme",
                                        defaultValue: "表示デザイン"
                                    )
                                )
                                .dopaFont(16, weight: .semibold)
                                .foregroundStyle(DesignTokens.primaryText)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(LockTheme.allCases, id: \.self) { theme in
                                        themeChip(theme)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)

                        SettingsDivider()

                        Button {
                            isLockScreenCheckPresented = true
                        } label: {
                            SettingsIconNavigationRow(
                                systemName: "checkmark.rectangle.fill",
                                label: String(
                                    localized: "settings.lock_screen.check",
                                    defaultValue: "ロック画面で確かめる"
                                )
                            )
                        }
                        .buttonStyle(.plain)

                        SettingsDivider()

                        SettingsIconToggleRow(
                            systemName: "dot.radiowaves.left.and.right",
                            label: String(
                                localized: "settings.lock_screen.live_activity",
                                defaultValue: "ロック画面に目標と記録を表示"
                            ),
                            isOn: liveActivityBinding
                        )
                    }
                }
            }
            .padding(.horizontal, DesignTokens.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .dopaScreenBackground()
        .navigationTitle(
            String(
                localized: "settings.entry.lock_surface",
                defaultValue: "ロック画面の表示"
            )
        )
        .navigationBarTitleDisplayMode(.inline)
    }

    private func themeChip(_ theme: LockTheme) -> some View {
        let isSelected = selectedLockTheme == theme
        let isAllowed = model.entitlementGate.lockThemeAllowed(theme)
        let palette = theme.palette

        return Button {
            guard isAllowed else {
                paywallPlacement = .settingsThemeGate
                return
            }
            selectedLockTheme = theme
            settingsStore.lockTheme = theme
            model.refreshLockSurfaces()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(lockThemeColor: palette.accent))
                    .frame(width: 8, height: 8)
                Text(theme.displayName)
                    .dopaFont(13, weight: .bold)
                if theme != .e1 {
                    Text(String(localized: "settings.status.pro", defaultValue: "Pro"))
                        .dopaFont(9, weight: .black)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(lockThemeColor: palette.accent).opacity(0.18))
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isSelected ? DesignTokens.background : DesignTokens.primaryText)
            .padding(.horizontal, 12)
            .frame(minHeight: 38)
            .background(isSelected ? DesignTokens.accent : DesignTokens.backgroundRaised)
            .overlay(
                Capsule()
                    .stroke(isSelected ? DesignTokens.accent : DesignTokens.hairline, lineWidth: 1)
            )
            .clipShape(Capsule())
            .frame(minHeight: DesignTokens.minTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var liveActivityBinding: Binding<Bool> {
        Binding(
            get: { liveActivityEnabled },
            set: { value in
                liveActivityEnabled = value
                settingsStore.liveActivityEnabled = value
                model.refreshLockSurfaces(restartLiveActivity: value)
            }
        )
    }
}
