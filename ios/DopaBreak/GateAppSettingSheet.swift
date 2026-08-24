import DopaBreakCore
import ManagedSettings
import SwiftUI

struct GateAppSettingTarget: Identifiable {
    let token: ApplicationToken
    let tokenData: Data

    var id: Data { tokenData }
}

/// 選んだアプリ1つの回数・開く長さ・次までの間隔を決めるシート。
struct GateAppSettingSheet: View {
    let target: GateAppSettingTarget
    let model: AppModel

    @Environment(\.dismiss) private var dismiss
    @State private var dailyOpenLimit: Int?
    @State private var sessionMinutes: Int
    @State private var cooldownMinutes: Int
    @State private var errorMessage: String?

    private static let dailyLimits: [Int?] = [nil, 1, 2, 3, 5, 10]
    private static let sessionOptions = [5, 10, 15, 30]
    private static let cooldownOptions = [0, 5, 10, 30, 60]

    init(target: GateAppSettingTarget, model: AppModel) {
        self.target = target
        self.model = model
        let setting = model.gateAppSetting(for: target.tokenData)
        _dailyOpenLimit = State(initialValue: setting.dailyOpenLimit)
        _sessionMinutes = State(initialValue: setting.sessionMinutes)
        _cooldownMinutes = State(initialValue: setting.cooldownMinutes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(target.token)
                        .font(.headline)
                }

                Section {
                    Picker(
                        String(
                            localized: "settings.gate.daily_limit",
                            defaultValue: "1日に開ける回数"
                        ),
                        selection: $dailyOpenLimit
                    ) {
                        ForEach(Self.dailyLimits, id: \.self) { limit in
                            Text(dailyLimitTitle(limit)).tag(limit)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker(
                        String(
                            localized: "settings.gate.session_minutes",
                            defaultValue: "1回の長さ"
                        ),
                        selection: $sessionMinutes
                    ) {
                        ForEach(Self.sessionOptions, id: \.self) { minutes in
                            Text(minutesTitle(minutes)).tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker(
                        String(
                            localized: "settings.gate.cooldown",
                            defaultValue: "次に開けるまでの間"
                        ),
                        selection: $cooldownMinutes
                    ) {
                        ForEach(Self.cooldownOptions, id: \.self) { minutes in
                            Text(cooldownTitle(minutes)).tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(
                String(
                    localized: "settings.gate.app_list",
                    defaultValue: "アプリごとの設定"
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(
                        String(
                            localized: "settings.delete_all.confirmation.cancel",
                            defaultValue: "キャンセル"
                        )
                    ) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "goal_editor.action.save", defaultValue: "保存")) {
                        save()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        do {
            try model.saveGateAppSetting(
                tokenData: target.tokenData,
                dailyOpenLimit: dailyOpenLimit,
                sessionMinutes: sessionMinutes,
                cooldownMinutes: cooldownMinutes
            )
            dismiss()
        } catch {
            errorMessage = String(
                localized: "settings.error.data_save",
                defaultValue: "データを保存できませんでした"
            )
        }
    }

    private func dailyLimitTitle(_ limit: Int?) -> String {
        guard let limit else {
            return String(
                localized: "settings.gate.daily_limit.none",
                defaultValue: "上限なし"
            )
        }
        return String.localizedStringWithFormat(
            String(localized: "settings.gate.times_format", defaultValue: "%lld回"),
            Int64(limit)
        )
    }

    private func cooldownTitle(_ minutes: Int) -> String {
        guard minutes > 0 else {
            return String(
                localized: "settings.gate.cooldown.none",
                defaultValue: "なし"
            )
        }
        return minutesTitle(minutes)
    }

    private func minutesTitle(_ minutes: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "intervention.duration.option", defaultValue: "%lld分"),
            Int64(minutes)
        )
    }
}
