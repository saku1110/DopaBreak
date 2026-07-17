import SwiftUI

struct StatsView: View {
    let model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.sectionSpacing) {
                ScreenHeader(eyebrow: "STATS · 今週", title: "今週の傾向")
                    .padding(.top, 18)

                VStack(alignment: .leading, spacing: 6) {
                    Text(weeklySuccessRateText)
                        .font(.system(size: 68, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(DesignTokens.primaryText)
                        .tracking(-2)
                    Text("開かずに我慢できた割合")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DesignTokens.secondaryText)
                }

                CardContainer {
                    VStack(alignment: .leading, spacing: 18) {
                        SmallLabel(text: "WEEKLY SUMMARY")

                        if model.weekAttemptCount == 0 {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("まだ記録がありません")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(DesignTokens.primaryText)

                                Text("開く前に選び直すたび、取り戻した記録がここに貯まります。")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(DesignTokens.secondaryText)
                                    .lineSpacing(4)
                            }
                        } else {
                            HStack(spacing: 14) {
                                MetricBlock(label: "開かなかった", value: "\(model.weekCancelledCount)回", accent: true)
                                MetricBlock(label: "試行", value: "\(model.weekAttemptCount)回")
                            }
                        }
                    }
                }

                if model.weekAttemptCount > 0 {
                    CardContainer {
                        VStack(alignment: .leading, spacing: 15) {
                            SmallLabel(text: "BEHAVIOR SIGNAL")
                            signalRow(label: "戻れた", value: weeklySuccessRate, color: DesignTokens.accent)
                            signalRow(label: "開いた", value: 1 - weeklySuccessRate, color: DesignTokens.secondaryText)
                        }
                    }
                }
            }
            .padding(.horizontal, DesignTokens.horizontalPadding)
            .padding(.bottom, 24)
        }
        .dopaScreenBackground()
        .onAppear {
            model.refresh()
        }
    }

    private func signalRow(label: String, value: CGFloat, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DesignTokens.secondaryText)
                .frame(width: 52, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DesignTokens.hairline)
                    Capsule().fill(color).frame(width: proxy.size.width * value)
                }
            }
            .frame(height: 6)
            Text("\(Int((value * 100).rounded()))%")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(DesignTokens.secondaryText)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private var weeklySuccessRate: CGFloat {
        guard model.weekAttemptCount > 0 else { return 0 }
        return min(1, CGFloat(model.weekCancelledCount) / CGFloat(model.weekAttemptCount))
    }

    private var weeklySuccessRateText: String {
        guard model.weekAttemptCount > 0 else { return "—" }
        return "\(Int((weeklySuccessRate * 100).rounded()))%"
    }
}
