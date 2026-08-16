import DopaBreakCore
import SwiftUI

/// `.sheet(item:)` で使うための Identifiable 準拠（Core側の型定義は変更しない）。
extension ReflectionLog: @retroactive Identifiable {}

/// 見たあとの振り返り（doc11 §7 振り返り）。アプリがアクティブになった際、
/// engine.pendingReflection() が対象を返したら表示する。
struct PostUseReflectionSheet: View {
    let model: AppModel
    let engine: InterventionEngine
    let reflection: ReflectionLog
    let onFinished: () -> Void

    @State private var satisfaction: PostUseSatisfaction?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SmallLabel(text: String(localized: "reflection.eyebrow", defaultValue: "REFLECTION"))

                CharacterView(
                    satisfaction?.characterExpression ?? .doom,
                    size: DesignTokens.CharacterSize.lead
                )
                    .frame(maxWidth: .infinity)
                    .characterPop(trigger: satisfaction)

                if let satisfaction {
                    happinessStep(satisfaction: satisfaction)
                } else {
                    satisfactionStep
                }

                Button(String(localized: "reflection.action.skip", defaultValue: "今回はスキップ")) {
                    skip()
                }
                .dopaFont(15, weight: .bold)
                .foregroundStyle(DesignTokens.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DesignTokens.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.2), value: satisfaction)
    }

    private var satisfactionStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(String(localized: "reflection.satisfaction.title", defaultValue: "SNSを見て\nどうだった？"))
                .dopaFont(34, weight: .black, tracking: -0.8)
                .foregroundStyle(DesignTokens.primaryText)

            Text(String(localized: "reflection.satisfaction.description", defaultValue: "必要な時間を使い終えました。次の選択のために記録します。"))
                .dopaFont(14, weight: .medium)
                .foregroundStyle(DesignTokens.secondaryText)

            VStack(spacing: 10) {
                satisfactionChoiceButton(.satisfied)
                satisfactionChoiceButton(.fun)
                satisfactionChoiceButton(.nothingGained)
                satisfactionChoiceButton(.lostTime)
                satisfactionChoiceButton(.feltWorse)
            }
        }
    }

    private func happinessStep(satisfaction: PostUseSatisfaction) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            CardContainer {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                        .dopaFont(13, weight: .black)
                        .foregroundStyle(DesignTokens.accent)
                    Text(satisfaction.displayTitle)
                        .dopaFont(15, weight: .bold)
                        .foregroundStyle(DesignTokens.primaryText)
                }
            }

            Text(String(localized: "reflection.happiness.title", defaultValue: "幸福感や集中力は\n上がった？"))
                .dopaFont(32, weight: .black)
                .foregroundStyle(DesignTokens.primaryText)

            VStack(spacing: 10) {
                choiceButton(HappinessDelta.increased.displayTitle) {
                    finish(satisfaction: satisfaction, happinessDelta: .increased)
                }
                choiceButton(HappinessDelta.unchanged.displayTitle) {
                    finish(satisfaction: satisfaction, happinessDelta: .unchanged)
                }
                choiceButton(HappinessDelta.decreased.displayTitle) {
                    finish(satisfaction: satisfaction, happinessDelta: .decreased)
                }
            }
        }
    }

    private func satisfactionChoiceButton(_ value: PostUseSatisfaction) -> some View {
        choiceButton(value.displayTitle, expression: value.characterExpression) {
            satisfaction = value
        }
    }

    private func choiceButton(
        _ title: String,
        expression: CharacterExpression? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                if let expression {
                    CharacterView(
                        expression,
                        size: DesignTokens.CharacterSize.inline,
                        animated: false
                    )
                }
                Text(title)
                    .dopaFont(17, weight: .bold)
                    .foregroundStyle(DesignTokens.primaryText)
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(DesignTokens.card)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DesignTokens.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func finish(satisfaction: PostUseSatisfaction, happinessDelta: HappinessDelta) {
        do {
            try engine.recordPostUseReflection(
                id: reflection.id,
                satisfaction: satisfaction,
                happinessDelta: happinessDelta
            )
            onFinished()
        } catch {
            model.alertMessage = String(localized: "reflection.error.data_save", defaultValue: "データを保存できませんでした")
        }
    }

    private func skip() {
        do {
            try engine.skipReflection(id: reflection.id)
            onFinished()
        } catch {
            model.alertMessage = String(localized: "reflection.error.data_save", defaultValue: "データを保存できませんでした")
        }
    }
}

extension PostUseSatisfaction {
    var characterExpression: CharacterExpression {
        switch self {
        case .satisfied, .fun: return .awake
        case .nothingGained: return .blank
        case .lostTime: return .doom
        case .feltWorse: return .worse
        }
    }

    var displayTitle: String {
        switch self {
        case .satisfied:
            return String(localized: "reflection.satisfaction.satisfied", defaultValue: "満足感があった")
        case .fun:
            return String(localized: "reflection.satisfaction.fun", defaultValue: "楽しかった")
        case .nothingGained:
            return String(localized: "reflection.satisfaction.nothing_gained", defaultValue: "何も得られなかった")
        case .lostTime:
            return String(localized: "reflection.satisfaction.lost_time", defaultValue: "時間を失った")
        case .feltWorse:
            return String(localized: "reflection.satisfaction.felt_worse", defaultValue: "気分が下がった")
        }
    }
}

extension HappinessDelta {
    var displayTitle: String {
        switch self {
        case .increased:
            return String(localized: "reflection.happiness.increased", defaultValue: "上がった")
        case .unchanged:
            return String(localized: "reflection.happiness.unchanged", defaultValue: "変わらない")
        case .decreased:
            return String(localized: "reflection.happiness.decreased", defaultValue: "下がった")
        }
    }
}
