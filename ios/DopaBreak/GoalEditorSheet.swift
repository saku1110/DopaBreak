import DopaBreakCore
import SwiftUI

struct GoalEditorRoute: Identifiable {
    let goal: Goal?

    var id: String {
        goal?.id.uuidString ?? "new"
    }
}

extension GoalCategory {
    var japaneseLabel: String {
        switch self {
        case .study:
            return String(localized: "goal_editor.category.study", defaultValue: "学び")
        case .work:
            return String(localized: "goal_editor.category.work", defaultValue: "仕事")
        case .health:
            return String(localized: "goal_editor.category.health", defaultValue: "健康")
        case .sleep:
            return String(localized: "goal_editor.category.sleep", defaultValue: "睡眠")
        case .creative:
            return String(localized: "goal_editor.category.creative", defaultValue: "創作")
        case .other:
            return String(localized: "goal_editor.category.other", defaultValue: "その他")
        }
    }
}

struct GoalEditorSheet: View {
    /// 題名の文字数上限。入力した言葉がそのままロック画面へ出るため、
    /// ロック面に収まる長さを入力側の上限に揃える（2026-08-08の入力一本化）。
    private let titleLimit = OnboardingGoalList.titleLimit

    @Environment(\.dismiss) private var dismiss

    let model: AppModel
    let goal: Goal?
    @State private var title: String
    @State private var category: GoalCategory

    private var isExisting: Bool { goal != nil }

    init(model: AppModel, goal: Goal?) {
        self.model = model
        self.goal = goal
        // 上限を超える既存データ（旧40字）は開いた時点で16字へ寄せる。
        // 開いてすぐ保存できない行き止まりを作らないため。
        _title = State(initialValue: goal.map { OnboardingGoalList.normalize($0.title) } ?? "")
        _category = State(initialValue: goal?.category ?? .other)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    previewBlock
                    inputBlock
                    categoryBlock
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, isExisting ? 150 : 96)
            }
            .dopaScreenBackground()
            .navigationTitle(
                isExisting
                    ? String(localized: "goal_editor.title.edit", defaultValue: "目標を編集")
                    : String(localized: "goal_editor.title.add", defaultValue: "目標を追加")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "goal_editor.action.close", defaultValue: "閉じる")) {
                        dismiss()
                    }
                    .foregroundStyle(DesignTokens.secondaryText)
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionArea
            }
        }
        .tint(DesignTokens.accent)
        .preferredColorScheme(.dark)
    }

    /// 入力した言葉がどこに出るのかを、実物と同じ体裁で入力欄の上に見せる。
    private var previewBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SmallLabel(
                text: String(
                    localized: "goals.preview.title",
                    defaultValue: "開こうとした瞬間に見える画面"
                )
            )

            LockScreenGoalPreview(
                titles: [previewTitle],
                cancelledCount: model.todayCancelledCount,
                attemptCount: model.todayAttemptCount,
                theme: model.lockSurfaceState.theme,
                isDimmed: trimmedTitle.isEmpty
            )
        }
    }

    /// 未入力のうちは入力欄と同じ例文を薄く出し、入れた瞬間に本文へ差し替える。
    private var previewTitle: String {
        guard trimmedTitle.isEmpty else {
            return trimmedTitle
        }
        return String(
            localized: "goal_editor.goal.placeholder",
            defaultValue: "例 英語で商談できる自分になる"
        )
    }

    /// 目標の題名。入力した言葉はそのままロック画面へ出るため、上限はロック面に収まる16字。
    private var inputBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SmallLabel(text: String(localized: "goal_editor.goal.label", defaultValue: "目標"))
                Spacer()
                // 保存可否の判定と同じ数え方（前後の空白を除く）にそろえる
                counterText(count: trimmedTitle.count, limit: titleLimit)
            }
            // 変換中の未確定文字列をbindingへ書き戻すと日本語入力が壊れるため、
            // ここでは切り詰めない。上限超過は赤いカウンタと保存の無効化で示す
            fieldContainer {
                TextField(
                    String(localized: "goal_editor.goal.placeholder", defaultValue: "例 英語で商談できる自分になる"),
                    text: $title,
                    axis: .vertical
                )
                    .lineLimit(2...4)
                    .dopaFont(20, weight: .bold)
                    .foregroundStyle(DesignTokens.primaryText)
            }
        }
    }

    /// カテゴリはメニューではなくアイコン付きのチップで選ぶ。
    /// 目標一覧のタイルと同じ記号・同じ色なので、選んだ結果が一覧でどう出るかがそのまま分かる。
    private var categoryBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SmallLabel(text: String(localized: "goal_editor.category.label", defaultValue: "カテゴリ"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GoalCategory.allCases, id: \.self) { item in
                        Button {
                            category = item
                        } label: {
                            categoryChip(item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.japaneseLabel)
                        .accessibilityAddTraits(item == category ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func categoryChip(_ item: GoalCategory) -> some View {
        let isSelected = item == category
        return HStack(spacing: 8) {
            GoalCategoryTile(category: item, size: 24)
            Text(item.japaneseLabel)
                .dopaFont(14, weight: .semibold)
                .foregroundStyle(isSelected ? DesignTokens.accent : DesignTokens.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: DesignTokens.minTapTarget)
        .background(DesignTokens.card)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isSelected ? DesignTokens.accent : DesignTokens.hairline,
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(DopaMotion.control, value: isSelected)
    }

    private var actionArea: some View {
        VStack(spacing: 10) {
            Button(String(localized: "goal_editor.action.save", defaultValue: "保存")) {
                let saved: Bool
                if let goal {
                    saved = model.updateGoal(
                        goal,
                        title: title,
                        category: category,
                        lockScreenTitle: nil
                    )
                } else {
                    saved = model.addGoal(
                        title: title,
                        category: category,
                        lockScreenTitle: nil
                    )
                }
                if saved {
                    dismiss()
                }
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: isValid))
            .disabled(!isValid)

            if let goal {
                Button(role: .destructive) {
                    if model.deleteGoal(id: goal.id) {
                        dismiss()
                    }
                } label: {
                    Text(String(localized: "goal_editor.action.delete", defaultValue: "削除"))
                        .dopaFont(16, weight: .semibold)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .foregroundStyle(DesignTokens.danger)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(DesignTokens.background)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        (1...titleLimit).contains(trimmedTitle.count)
    }

    private func fieldContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .tint(DesignTokens.accent)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(DesignTokens.card)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DesignTokens.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func counterText(count: Int, limit: Int) -> some View {
        Text(String(localized: "goal_editor.character_count", defaultValue: "\(count)/\(limit)"))
            .dopaFont(12, weight: .medium, design: .monospaced)
            .foregroundStyle(count > limit ? DesignTokens.danger : DesignTokens.secondaryText)
    }

}
