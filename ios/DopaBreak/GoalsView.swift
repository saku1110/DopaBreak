import DopaBreakCore
import SwiftUI

struct GoalsView: View {
    let model: AppModel
    @State private var editorRoute: GoalEditorRoute?

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
                }

                Section {
                    addButton
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            // 自前のScreenHeaderをやめ、システムの大見出しへ寄せた。
            .navigationTitle(String(localized: "goals.header.title", defaultValue: "目標"))
            .navigationBarTitleDisplayMode(.large)
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
    }

    private var isAnyChildModalPresented: Bool {
        editorRoute != nil
    }

    private var emptyRow: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 18) {
                SmallLabel(text: String(localized: "goals.empty.label", defaultValue: "目標"))
                Text(String(localized: "goals.empty.title", defaultValue: "目標を決める"))
                    .dopaFont(24, weight: .bold)
                    .foregroundStyle(DesignTokens.primaryText)

                Text(String(localized: "goals.empty.description", defaultValue: "ここで決めた一言が、開こうとした瞬間に表示されます。例：英語で話せるようになる"))
                    .dopaFont(14, weight: .medium, lineSpacing: 3)
                    .foregroundStyle(DesignTokens.secondaryText)
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
                            .dopaFont(14, weight: .semibold)
                            .foregroundStyle(DesignTokens.secondaryText)
                    }

                    Text(goal.title)
                        .dopaFont(22, weight: .bold)
                        .foregroundStyle(DesignTokens.primaryText)
                        .lineLimit(3)
                        .minimumScaleFactor(0.84)
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
            editorRoute = GoalEditorRoute(goal: nil)
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
