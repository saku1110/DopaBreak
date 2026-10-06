import DopaBreakCore
import SwiftUI

enum SettingsLockThemeSelectionHandler {
    static func select(
        for theme: LockTheme,
        isThemeAllowed: (LockTheme) -> Bool,
        onLocked: (LockTheme, PaywallPlacement) -> Void,
        onSelect: (LockTheme) -> Void
    ) {
        if isThemeAllowed(theme) {
            onSelect(theme)
        } else {
            onLocked(theme, .settingsThemeGate)
        }
    }
}

enum SettingsLockThemePresentation {
    static func showsProNote(
        savedTheme: LockTheme,
        isThemeAllowed: (LockTheme) -> Bool
    ) -> Bool {
        !isThemeAllowed(savedTheme)
    }
}

struct SettingsLockSurfaceView: View {
    let model: AppModel
    let settingsStore: SettingsStore

    @Binding var liveLockTheme: LockTheme
    @Binding var liveActivityEnabled: Bool
    @Binding var isLockScreenCheckPresented: Bool
    @Binding var paywallPlacement: PaywallPlacement?
    private let onPickerActionReady: ((@escaping (LockTheme) -> Void) -> Void)?
    private let onPickerSelectionRendered: ((LockTheme) -> Void)?
    private let onProNoteRendered: (() -> Void)?

    init(
        model: AppModel,
        settingsStore: SettingsStore,
        liveLockTheme: Binding<LockTheme>,
        liveActivityEnabled: Binding<Bool>,
        isLockScreenCheckPresented: Binding<Bool>,
        paywallPlacement: Binding<PaywallPlacement?>,
        onPickerActionReady: ((@escaping (LockTheme) -> Void) -> Void)? = nil,
        onPickerSelectionRendered: ((LockTheme) -> Void)? = nil,
        onProNoteRendered: (() -> Void)? = nil
    ) {
        self.model = model
        self.settingsStore = settingsStore
        _liveLockTheme = liveLockTheme
        _liveActivityEnabled = liveActivityEnabled
        _isLockScreenCheckPresented = isLockScreenCheckPresented
        _paywallPlacement = paywallPlacement
        self.onPickerActionReady = onPickerActionReady
        self.onPickerSelectionRendered = onPickerSelectionRendered
        self.onProNoteRendered = onProNoteRendered
    }

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

                        SettingsDivider()

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

                            if SettingsLockThemePresentation.showsProNote(
                                savedTheme: model.displayedLockThemeSelection,
                                isThemeAllowed: model.entitlementGate.lockThemeAllowed
                            ) {
                                Text(
                                    String(
                                        localized: "settings.lock_screen.pro_note",
                                        defaultValue: "このデザインをロック画面に表示するにはProが必要です"
                                    )
                                )
                                .dopaFont(13, weight: .semibold, lineSpacing: 3)
                                .foregroundStyle(DesignTokens.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .onAppear { onProNoteRendered?() }
                            }

                            LockThemePickerView(
                                selectedTheme: model.displayedLockThemeSelection,
                                goalTitles: previewTitles,
                                cancelledCount: model.todayCancelledCount,
                                attemptCount: model.todayAttemptCount,
                                isThemeAllowed: model.entitlementGate.lockThemeAllowed,
                                onSelect: selectTheme,
                                onSelectedThemeRendered: onPickerSelectionRendered
                            )
                            .onAppear { onPickerActionReady?(selectTheme) }
                        }
                        .padding(.vertical, 8)
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

    private var previewTitles: [String] {
        let titles = model.lockScreenDisplayTitles.filter { !$0.isEmpty }
        return titles.isEmpty
            ? [String(localized: "lock_check.preview.goal_fallback", defaultValue: "あなたの目標")]
            : titles
    }

    private func selectTheme(_ theme: LockTheme) {
        SettingsLockThemeSelectionHandler.select(
            for: theme,
            isThemeAllowed: model.entitlementGate.lockThemeAllowed,
            onLocked: { selectedTheme, placement in
                model.pendingProThemeSelection = selectedTheme
                paywallPlacement = placement
            },
            onSelect: { selectedTheme in
                model.updateLockTheme(selectedTheme)
                liveLockTheme = model.liveLockTheme
            }
        )
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
