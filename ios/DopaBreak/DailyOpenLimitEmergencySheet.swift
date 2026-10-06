import DopaBreakCore
import SwiftUI

/// ホームから使う、回数を使い切ったあとの「30秒待って開く」。
///
/// 待ち始めた時刻は保存してあり、シートを閉じて開き直しても待ちは短くならない。
/// 待ち終わったら時間を選び、その時間だけ完全ブロックを外して一呼吸を素通しにする。
struct DailyOpenLimitEmergencySheet: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDuration: InterventionDuration = .tenMinutes
    @State private var openedUntil: Date?
    @State private var didFail = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let openedUntil {
                            openedContent(until: openedUntil)
                        } else {
                            waitingContent(model.dailyOpenLimitEmergencyState)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle(String(localized: "open_limit.emergency.start", defaultValue: "30秒待って開く"))
            .navigationBarTitleDisplayMode(.inline)
            .dopaScreenBackground()
        }
        .tint(DesignTokens.accent)
        .onAppear {
            // ホームのボタンを押したこと自体を「待ちを始める」として扱う。待ち中・待ち終わりなら延ばさない。
            model.requestDailyOpenLimitEmergency()
        }
    }

    @ViewBuilder
    private func waitingContent(_ state: DailyOpenLimitPolicy.EmergencyState) -> some View {
        switch state {
        case .waiting(let seconds):
            Text(String(localized: "open_limit.emergency.waiting", defaultValue: "あと\(seconds)秒で開けます"))
                .dopaFont(28, weight: .black)
                .foregroundStyle(DesignTokens.primaryText)
                .monospacedDigit()
        case .ready:
            Text(String(localized: "open_limit.emergency.ready", defaultValue: "開けます"))
                .dopaFont(28, weight: .black)
                .foregroundStyle(DesignTokens.primaryText)
            Text(String(localized: "open_limit.emergency.duration_notice", defaultValue: "この時間が過ぎるとまた開けなくなります"))
                .dopaFont(14, weight: .semibold)
                .foregroundStyle(DesignTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(InterventionDuration.allCases) { duration in
                    let isSelected = selectedDuration == duration
                    Button {
                        selectedDuration = duration
                    } label: {
                        Text(duration.displayTitle)
                            .dopaFont(20, weight: .black, design: .rounded)
                            .foregroundStyle(isSelected ? DesignTokens.accent : DesignTokens.primaryText)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(DesignTokens.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(isSelected ? DesignTokens.accent : DesignTokens.hairline,
                                            lineWidth: isSelected ? 2 : 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            if didFail {
                Text(String(localized: "open_limit.emergency.failed", defaultValue: "開けるようにできませんでした。もう一度試してください。"))
                    .dopaFont(14, weight: .semibold)
                    .foregroundStyle(DesignTokens.danger)
            }
            Button(String(localized: "intervention.duration.action.open", defaultValue: "\(selectedDuration.rawValue)分だけ開く")) {
                if model.openForDailyOpenLimitEmergency(durationSeconds: selectedDuration.seconds, catalogTarget: nil) {
                    openedUntil = model.currentDate.addingTimeInterval(TimeInterval(selectedDuration.seconds))
                } else {
                    didFail = true
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("open_limit.emergency.open")
        case .notRequested:
            Text(String(localized: "open_limit.emergency.expired", defaultValue: "待ち時間が切れました"))
                .dopaFont(28, weight: .black)
                .foregroundStyle(DesignTokens.primaryText)
            Button(String(localized: "open_limit.emergency.start", defaultValue: "30秒待って開く")) {
                model.requestDailyOpenLimitEmergency()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        Button(String(localized: "settings.strict.exit.continue", defaultValue: "ブロックを続ける")) {
            dismiss()
        }
        .dopaFont(15, weight: .semibold)
        .foregroundStyle(DesignTokens.secondaryText)
        .frame(maxWidth: .infinity, minHeight: 44)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func openedContent(until: Date) -> some View {
        Text(String(
            localized: "open_limit.emergency.opened_title",
            defaultValue: "\(until.formatted(date: .omitted, time: .shortened))まで開けます"
        ))
        .dopaFont(28, weight: .black)
        .foregroundStyle(DesignTokens.primaryText)
        .monospacedDigit()
        Text(String(
            localized: "open_limit.emergency.opened_body",
            defaultValue: "ホーム画面からアプリを開いてください。この時間が過ぎるとまた開けなくなります。"
        ))
        .dopaFont(15, weight: .semibold)
        .foregroundStyle(DesignTokens.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
        Button(String(localized: "intervention.action.close", defaultValue: "閉じる")) {
            dismiss()
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}
