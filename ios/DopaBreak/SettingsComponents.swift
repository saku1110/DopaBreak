import SwiftUI

enum SettingsTime {
    /// 壁時計の時分を直接設定してDateへ戻す。startOfDayへ分を足すとDST日にずれる。
    static func date(minutes: Int?, defaultMinutes: Int, now: Date = Date()) -> Date {
        let calendar = Calendar.current
        let normalized = normalizedMinutes(minutes ?? defaultMinutes)
        return calendar.date(
            bySettingHour: normalized / 60,
            minute: normalized % 60,
            second: 0,
            of: now
        ) ?? now
    }

    static func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ((components.hour ?? 0) * 60) + (components.minute ?? 0)
    }

    static func normalizedMinutes(_ value: Int) -> Int {
        ((value % 1_440) + 1_440) % 1_440
    }
}

/// 設定行の右端に出す記号。
/// タップして「何が起きるか」を記号で見分ける（アプリ内で開く／アプリの外へ出る）。
enum SettingsRowDisclosure {
    case none
    case navigate
    case external

    var symbolName: String? {
        switch self {
        case .none: return nil
        case .navigate: return "chevron.right"
        case .external: return "arrow.up.right"
        }
    }
}

struct SettingsRow: View {
    let label: String
    var value = ""
    var labelColor: Color = DesignTokens.primaryText
    var valueColor: Color = DesignTokens.secondaryText
    var disclosure: SettingsRowDisclosure = .none

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .dopaFont(16, weight: .semibold)
                .foregroundStyle(labelColor)

            Spacer(minLength: 8)

            if !value.isEmpty {
                Text(value)
                    .dopaFont(14, weight: .semibold)
                    .foregroundStyle(valueColor)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }

            if let symbol = disclosure.symbolName {
                Image(systemName: symbol)
                    .dopaFont(13, weight: .semibold)
                    .foregroundStyle(DesignTokens.tertiaryText)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(DesignTokens.hairline)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

struct SettingsIconTile: View {
    let systemName: String
    var background: Color = Color(red: 44.0 / 255.0, green: 49.0 / 255.0, blue: 57.0 / 255.0)
    var foreground: Color = .white

    var body: some View {
        Image(systemName: systemName)
            .dopaFont(14, weight: .bold)
            .foregroundStyle(foreground)
            .frame(width: 30, height: 30)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct SettingsChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .dopaFont(13, weight: .semibold)
            .foregroundStyle(DesignTokens.tertiaryText)
            .accessibilityHidden(true)
    }
}

struct SettingsIconNavigationRow: View {
    let systemName: String
    let label: String
    var value = ""
    var tileBackground: Color = Color(red: 44.0 / 255.0, green: 49.0 / 255.0, blue: 57.0 / 255.0)
    var tileForeground: Color = .white
    var valueColor: Color = DesignTokens.secondaryText

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconTile(
                systemName: systemName,
                background: tileBackground,
                foreground: tileForeground
            )

            Text(label)
                .dopaFont(16, weight: .semibold)
                .foregroundStyle(DesignTokens.primaryText)

            Spacer(minLength: 8)

            if !value.isEmpty {
                Text(value)
                    .dopaFont(13, weight: .semibold)
                    .foregroundStyle(valueColor)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }

            SettingsChevron()
        }
        .frame(minHeight: DesignTokens.minTapTarget)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

struct SettingsIconToggleRow: View {
    let systemName: String
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconTile(systemName: systemName)

            Toggle(isOn: $isOn) {
                Text(label)
                    .dopaFont(16, weight: .semibold)
                    .foregroundStyle(DesignTokens.primaryText)
            }
            .tint(DesignTokens.accent)
        }
        .frame(minHeight: DesignTokens.minTapTarget)
        .padding(.vertical, 8)
    }
}

struct SettingsIconTimePickerRow: View {
    let systemName: String
    let label: String
    @Binding var selection: Date

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconTile(systemName: systemName)

            Text(label)
                .dopaFont(16, weight: .semibold)
                .foregroundStyle(DesignTokens.primaryText)

            Spacer(minLength: 8)

            DatePicker(label, selection: $selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(DesignTokens.secondaryText)
        }
        .frame(minHeight: DesignTokens.minTapTarget)
        .padding(.vertical, 8)
    }
}
