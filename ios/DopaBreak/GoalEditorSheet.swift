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
    @Environment(\.dismiss) private var dismiss

    let model: AppModel
    let goal: Goal?
    @State private var title: String
    @State private var category: GoalCategory
    @State private var lockScreenTitle: String

    private var isExisting: Bool { goal != nil }

    init(model: AppModel, goal: Goal?) {
        self.model = model
        self.goal = goal
        _title = State(initialValue: goal?.title ?? "")
        _category = State(initialValue: goal?.category ?? .other)
        _lockScreenTitle = State(initialValue: goal?.lockScreenTitle ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    inputBlock
                    categoryBlock
                    lockScreenBlock
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

    private var inputBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SmallLabel(text: String(localized: "goal_editor.goal.label", defaultValue: "目標"))
                Spacer()
                counterText(count: title.count, limit: 40)
            }
            fieldContainer {
                TextField(
                    String(localized: "goal_editor.goal.placeholder", defaultValue: "例 英語で商談できる自分になる"),
                    text: $title,
                    axis: .vertical
                )
                    .lineLimit(2...4)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DesignTokens.primaryText)
            }
            .onChange(of: title) { _, newValue in
                if newValue.count > 40 {
                    title = String(newValue.prefix(40))
                }
            }
        }
    }

    private var categoryBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SmallLabel(text: String(localized: "goal_editor.category.label", defaultValue: "カテゴリ"))
            fieldContainer {
                Picker(String(localized: "goal_editor.category.label", defaultValue: "カテゴリ"), selection: $category) {
                    ForEach(GoalCategory.allCases, id: \.self) { category in
                        Text(category.japaneseLabel).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var lockScreenBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SmallLabel(text: String(localized: "goal_editor.lock_title.label", defaultValue: "ロック画面用の短い表示名"))
                Spacer()
                counterText(count: lockScreenTitle.count, limit: 16)
            }
            fieldContainer {
                TextField(
                    String(localized: "goal_editor.lock_title.placeholder", defaultValue: "ロック画面用の短い表示名"),
                    text: $lockScreenTitle
                )
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DesignTokens.primaryText)
            }
            .onChange(of: lockScreenTitle) { _, newValue in
                if newValue.count > 16 {
                    lockScreenTitle = String(newValue.prefix(16))
                }
            }
        }
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
                        lockScreenTitle: lockScreenTitle
                    )
                } else {
                    saved = model.addGoal(
                        title: title,
                        category: category,
                        lockScreenTitle: lockScreenTitle
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
                        .font(.system(size: 16, weight: .semibold))
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

    private var isValid: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLockTitle = lockScreenTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...40).contains(trimmedTitle.count) else {
            return false
        }
        return trimmedLockTitle.isEmpty || trimmedLockTitle.count <= 16
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
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(count > limit ? DesignTokens.danger : DesignTokens.secondaryText)
    }

}
