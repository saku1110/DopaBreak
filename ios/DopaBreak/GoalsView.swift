import DopaBreakCore
import SwiftUI

struct GoalsView: View {
    let model: AppModel
    @State private var editorRoute: GoalEditorRoute?
    @State private var paywallPlacement: PaywallPlacement?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if model.goals.isEmpty {
                        emptyRow
                    } else {
                        ForEach(model.goals, id: \.id) { goal in
                            goalRow(goal)
                        }
                        .onDelete(perform: deleteGoals)
                        .onMove(perform: model.moveGoal)
                    }
                } header: {
                    ScreenHeader(
                        eyebrow: String(localized: "goals.header.eyebrow", defaultValue: "YOUR GOAL"),
                        title: String(localized: "goals.header.title", defaultValue: "目標")
                    )
                        .textCase(.none)
                        .padding(.top, 12)
                }

                Section {
                    addButton
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .dopaScreenBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !model.goals.isEmpty {
                        EditButton()
                            .foregroundStyle(DesignTokens.accent)
                    }
                }
            }
        }
        .tint(DesignTokens.accent)
        .onAppear {
            model.refresh()
            model.isChildModalActive = isAnyChildModalPresented
        }
        .onChange(of: isAnyChildModalPresented) { _, isPresented in
            model.isChildModalActive = isPresented
        }
        .sheet(item: $editorRoute) { route in
            GoalEditorSheet(model: model, goal: route.goal)
        }
        .fullScreenCover(item: $paywallPlacement) { placement in
            PaywallView(storeService: model.storeService, placement: placement)
        }
    }

    private var isAnyChildModalPresented: Bool {
        editorRoute != nil || paywallPlacement != nil
    }

    private var emptyRow: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 18) {
                SmallLabel(text: String(localized: "goals.empty.label", defaultValue: "目標"))
                Text(String(localized: "goals.empty.title", defaultValue: "戻りたい自分を決める"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(DesignTokens.primaryText)

                Text(String(localized: "goals.empty.description", defaultValue: "目標は、あなたを連れ戻す錨です。開く前に思い出せる言葉を置きましょう。"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignTokens.secondaryText)
                    .lineSpacing(3)
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
    }

    private func goalRow(_ goal: Goal) -> some View {
        Button {
            editorRoute = GoalEditorRoute(goal: goal)
        } label: {
            CardContainer {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SmallLabel(text: goal.category.japaneseLabel)
                        Spacer()
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DesignTokens.secondaryText)
                    }

                    Text(goal.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(DesignTokens.primaryText)
                        .lineLimit(3)
                        .minimumScaleFactor(0.84)

                    if let lockTitle = goal.lockScreenTitle {
                        Text(lockTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DesignTokens.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
    }

    private var addButton: some View {
        Button {
            if model.canAddGoal {
                editorRoute = GoalEditorRoute(goal: nil)
            } else {
                paywallPlacement = .goalsLimit
            }
        } label: {
            Text(String(localized: "goals.action.add", defaultValue: "目標を追加"))
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.bottom, 20)
    }

    private func deleteGoals(at offsets: IndexSet) {
        for index in offsets {
            let goal = model.goals[index]
            model.deleteGoal(id: goal.id)
        }
    }
}
