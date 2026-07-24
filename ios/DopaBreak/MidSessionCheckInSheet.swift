import SwiftUI

struct MidSessionCheckInSheet: View {
    let model: AppModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "mid_session_check_in.title", defaultValue: "まだ見てる？"))
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(DesignTokens.primaryText)
                    .tracking(-0.8)

                Text(reminderText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignTokens.primaryText)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignTokens.card)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(DesignTokens.hairline, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Spacer(minLength: 0)

            Button(String(localized: "mid_session_check_in.action.close", defaultValue: "閉じる")) {
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.background)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }

    private var reminderText: String {
        guard let goal = model.goals.first else {
            return String(
                localized: "mid_session_check_in.reminder.no_goal",
                defaultValue: "何のために開いたか思い出せますか"
            )
        }
        return String(
            localized: "mid_session_check_in.reminder.goal",
            defaultValue: "戻る先　\(goal.title)"
        )
    }
}
