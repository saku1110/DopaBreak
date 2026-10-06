import DopaBreakCore
import SwiftUI

struct StrictSessionChangeError: LocalizedError {
    var errorDescription: String? {
        String(localized: "settings.strict.change_blocked", defaultValue: "強いブロック中は変更できません。必要な場合は、セッションの解除から緊急解除してください。")
    }
}

/// One exit flow for Home and Settings. The persisted session owns the deadline,
/// so dismissing or restarting the app cannot skip the waiting period.
struct StrictSessionExitView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var didRequest = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let session = model.deepFocusSession
                let remaining = session?.emergencyExitRemainingSeconds(now: model.currentDate) ?? 0
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(String(localized: "settings.strict.exit.description", defaultValue: "終了時刻まで続ける設定です。緊急で必要なときは、30秒待って手動セッションを解除できます。毎週の予定と就寝中のブロックは別に続きます。"))
                            .foregroundStyle(DesignTokens.secondaryText)
                        if session == nil {
                            Button(String(localized: "settings.strict.exit.done", defaultValue: "セッションは終了しました")) { dismiss() }
                        } else if didRequest || session?.emergencyExitRequestedAt != nil {
                            Text(String(localized: "settings.strict.exit.countdown", defaultValue: "解除まであと\(Int(remaining.rounded(.up)))秒"))
                                .monospacedDigit()
                            Button(String(localized: "settings.strict.exit.confirm", defaultValue: "手動セッションを緊急解除"), role: .destructive) {
                                model.endDeepFocusSession(emergency: true)
                                if model.deepFocusSession == nil { dismiss() }
                            }
                            .disabled(remaining > 0)
                        } else {
                            Button(String(localized: "settings.strict.exit.request", defaultValue: "緊急解除の待機を始める")) {
                                model.requestEmergencyDeepFocusExit()
                                didRequest = true
                            }
                        }
                        Button(String(localized: "settings.strict.exit.continue", defaultValue: "ブロックを続ける")) { dismiss() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle(String(localized: "settings.strict.exit.title", defaultValue: "緊急解除"))
            .navigationBarTitleDisplayMode(.inline)
            .dopaScreenBackground()
        }
        .tint(DesignTokens.accent)
    }
}
