import DopaBreakCore
import SwiftUI

/// `.sheet(item:)` で使うための Identifiable 準拠（Core側の型定義は変更しない）。
extension ReflectionLog: @retroactive Identifiable {}

/// 見たあとの振り返り（doc11 §7 振り返り）のシート用ラッパー。
struct PostUseReflectionSheet: View {
    let model: AppModel
    let engine: InterventionEngine
    let reflection: ReflectionLog
    let onFinished: () -> Void

    init(
        model: AppModel,
        engine: InterventionEngine,
        reflection: ReflectionLog,
        onFinished: @escaping () -> Void
    ) {
        self.model = model
        self.engine = engine
        self.reflection = reflection
        self.onFinished = onFinished
    }

    var body: some View {
        PostUseReflectionContent(
            reflection: reflection,
            onSelect: { satisfaction in
                finish(
                    satisfaction: satisfaction,
                    happinessDelta: satisfaction.impliedHappinessDelta
                )
            },
            onSkip: skip
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
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

/// シートと一呼吸フロー冒頭で共用する振り返り本体。
struct PostUseReflectionContent: View {
    let reflection: ReflectionLog
    let onSelect: (PostUseSatisfaction) -> Void
    let onSkip: () -> Void

    @State private var satisfaction: PostUseSatisfaction?
    private let referenceDate: Date

    init(
        reflection: ReflectionLog,
        referenceDate: Date = Date(),
        onSelect: @escaping (PostUseSatisfaction) -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.reflection = reflection
        self.referenceDate = referenceDate
        self.onSelect = onSelect
        self.onSkip = onSkip
        _satisfaction = State(initialValue: nil)
    }

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

                satisfactionStep
                    .disabled(satisfaction != nil)

                Button(String(localized: "reflection.action.skip", defaultValue: "今回はスキップ")) {
                    onSkip()
                }
                .dopaFont(15, weight: .bold)
                .foregroundStyle(DesignTokens.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .opacity(satisfaction != nil ? 0.4 : 1)
                .disabled(satisfaction != nil)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DesignTokens.background)
        .animation(.easeInOut(duration: 0.2), value: satisfaction)
        .task(id: satisfaction) {
            guard let satisfaction else { return }
            do {
                try await Task.sleep(for: .milliseconds(550))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            onSelect(satisfaction)
        }
    }

    private var satisfactionStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(String(localized: "reflection.satisfaction.title", defaultValue: "SNSを見たあとの気持ちは？"))
                .dopaFont(34, weight: .black, tracking: -0.8)
                .foregroundStyle(DesignTokens.primaryText)

            Text(ReflectionTimingSummary.text(for: reflection, now: referenceDate))
                .dopaFont(16, weight: .bold)
                .foregroundStyle(DesignTokens.accent)

            Text(String(localized: "reflection.satisfaction.description", defaultValue: "今の気持ちを記録すると次に開くか選ぶときの参考になります"))
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

    private func satisfactionChoiceButton(_ value: PostUseSatisfaction) -> some View {
        choiceButton(value.displayTitle, isSelected: satisfaction == value) {
            satisfaction = value
            AccessibilityNotification.Announcement(value.displayTitle).post()
        }
        .opacity(satisfaction != nil && satisfaction != value ? 0.4 : 1)
    }

    private func choiceButton(
        _ title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
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
                    .stroke(
                        isSelected ? DesignTokens.accent : DesignTokens.hairline,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

}

enum ReflectionTimingSummary {
    static func durationMinutes(for reflection: ReflectionLog) -> Int {
        max(1, Int((reflection.promptedAt.timeIntervalSince(reflection.createdAt) / 60).rounded()))
    }

    static func elapsedMinutes(for reflection: ReflectionLog, now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(reflection.promptedAt) / 60))
    }

    static func text(for reflection: ReflectionLog, now: Date) -> String {
        let elapsedMinutes = elapsedMinutes(for: reflection, now: now)
        let elapsed: String
        if elapsedMinutes < 60 {
            elapsed = String(
                localized: "reflection.context.elapsed_minutes",
                defaultValue: "\(elapsedMinutes)分"
            )
        } else {
            elapsed = String(
                localized: "reflection.context.elapsed_hours",
                defaultValue: "\(elapsedMinutes / 60)時間"
            )
        }
        return String(
            localized: "reflection.context.summary",
            defaultValue: "\(elapsed)前の\(durationMinutes(for: reflection))分について"
        )
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
