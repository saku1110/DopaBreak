import DopaBreakCore
import SwiftUI

enum GoalsAddRequestPolicy {
    static func shouldPresent(request: UUID?, consumed: UUID?) -> Bool {
        guard let request else { return false }
        return request != consumed
    }
}

struct GoalsView: View {
    let model: AppModel
    @Binding private var addRequest: UUID?
    @State private var editorRoute: GoalEditorRoute?
    @State private var consumedAddRequest: UUID?

    init(model: AppModel, addRequest: Binding<UUID?> = .constant(nil)) {
        self.model = model
        _addRequest = addRequest
    }

    var body: some View {
        NavigationStack {
            List {
                if !model.goals.isEmpty {
                    Section {
                        lockScreenPreviewBlock
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(
                        EdgeInsets(
                            top: 4,
                            leading: DesignTokens.horizontalPadding,
                            bottom: 10,
                            trailing: DesignTokens.horizontalPadding
                        )
                    )
                }

                Section {
                    if model.goals.isEmpty {
                        emptyRow
                    } else {
                        ForEach(Array(model.goals.enumerated()), id: \.element.id) { index, goal in
                            goalRow(goal, index: index)
                        }
                        .onDelete(perform: deleteGoals)
                        .onMove(perform: model.moveGoal)
                    }
                } footer: {
                    if !model.goals.isEmpty {
                        Text(
                            String(
                                localized: "goals.footer.lock_screen_limit",
                                defaultValue: "ロック画面に表示されるのは上位5件までです。並べ替えで変更できます。")
                        )
                            .dopaFont(12, weight: .medium, lineSpacing: 3)
                            .foregroundStyle(DesignTokens.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .textCase(nil)
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
            consumeAddRequestIfNeeded()
        }
        .onChange(of: isAnyChildModalPresented) { _, isPresented in
            model.isChildModalActive = isPresented
        }
        .onChange(of: addRequest) { _, _ in
            consumeAddRequestIfNeeded()
        }
        .sheet(item: $editorRoute) { route in
            GoalEditorSheet(model: model, goal: route.goal)
        }
    }

    private var isAnyChildModalPresented: Bool {
        editorRoute != nil
    }

    /// 目標がどこに出るものなのかを、画面の先頭で実物の体裁のまま見せる。
    ///
    /// キャラクターはカードの外（見出し行の右）に置く。理由は2つある。
    /// 実物のロック画面にキャラクターは乗らないため、カードは再現に徹したほうが正確なこと。
    /// もう1つは、カウンター行「今日は%lld回、開くのをやめました 開こうとした %lld回」が
    /// カード内寸のほぼ全部を使うため、カードに重ねると375〜402ptの端末で回数が隠れること。
    private var lockScreenPreviewBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                SmallLabel(
                    text: String(
                        localized: "goals.preview.title",
                        defaultValue: "対象アプリを開く前に表示される画面"
                    )
                )
                Spacer(minLength: 8)
                CharacterView(.relief, size: 56)
            }

            LockScreenGoalPreview(
                titles: previewTitles,
                cancelledCount: model.todayCancelledCount,
                attemptCount: model.todayAttemptCount,
                theme: model.lockSurfaceState.theme
            )
        }
    }

    private var previewTitles: [String] {
        // 上限はプレビュー側が実機のLive Activityと同じ値で丸めるため、ここでは絞らない。
        model.lockScreenDisplayTitles.filter { !$0.isEmpty }
    }

    private var emptyRow: some View {
        Button {
            editorRoute = GoalEditorRoute(goal: nil)
        } label: {
            CardContainer {
                VStack(alignment: .leading, spacing: 18) {
                    SmallLabel(text: String(localized: "goals.empty.label", defaultValue: "目標"))
                    Text(String(localized: "goals.empty.title", defaultValue: "目標を決める"))
                        .dopaFont(24, weight: .bold)
                        .foregroundStyle(DesignTokens.primaryText)

                    Text(
                        String(
                            localized: "goals.empty.description",
                            defaultValue: "目標を設定すると、対象アプリを開く前に表示されます。例：英語で話せるようになる"
                        )
                    )
                        .dopaFont(14, weight: .medium, lineSpacing: 3)
                        .foregroundStyle(DesignTokens.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(
            EdgeInsets(
                top: 6,
                leading: DesignTokens.horizontalPadding,
                bottom: 6,
                trailing: DesignTokens.horizontalPadding
            )
        )
    }

    private func goalRow(_ goal: Goal, index: Int) -> some View {
        Button {
            editorRoute = GoalEditorRoute(goal: goal)
        } label: {
            CardContainer {
                HStack(spacing: 14) {
                    GoalCategoryTile(category: goal.category, size: 44)

                    VStack(alignment: .leading, spacing: 7) {
                        SmallLabel(text: rowLabel(for: goal, index: index))
                        Text(goal.title)
                            .dopaFont(18, weight: .bold)
                            .foregroundStyle(DesignTokens.primaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.84)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .dopaFont(13, weight: .bold)
                        .foregroundStyle(DesignTokens.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(
            EdgeInsets(
                top: 6,
                leading: DesignTokens.horizontalPadding,
                bottom: 6,
                trailing: DesignTokens.horizontalPadding
            )
        )
    }

    /// カテゴリ名。ロック画面に出ない目標だけ注記を添える。
    private func rowLabel(for goal: Goal, index: Int) -> String {
        let category = goal.category.japaneseLabel
        guard index >= LockSurfaceCoordinator.liveActivityGoalLimit else {
            return category
        }
        let badge = String(
            localized: "goals.badge.off_lock_screen",
            defaultValue: "ロック画面には出ません"
        )
        return "\(category) ・ \(badge)"
    }

    private var addButton: some View {
        VStack(spacing: 8) {
            Button {
                editorRoute = GoalEditorRoute(goal: nil)
            } label: {
                Text(String(localized: "goals.action.add", defaultValue: "目標を追加"))
            }
            .buttonStyle(PrimaryButtonStyle())

            // 件数上限があるプランでは既存の上限文言が優先されるため、無制限のときだけ出す。
            if model.entitlementGate.goalsLimit == nil {
                Text(
                    String(
                        localized: "goals.footer.unlimited",
                        defaultValue: "目標は何個でも追加できます"
                    )
                )
                    .dopaFont(12, weight: .medium)
                    .foregroundStyle(DesignTokens.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.bottom, 20)
    }

    private func deleteGoals(at offsets: IndexSet) {
        for index in offsets {
            let goal = model.goals[index]
            model.deleteGoal(id: goal.id)
        }
    }

    private func consumeAddRequestIfNeeded() {
        let request = addRequest
        guard GoalsAddRequestPolicy.shouldPresent(
            request: request,
            consumed: consumedAddRequest
        ) else { return }

        consumedAddRequest = request
        DispatchQueue.main.async {
            guard editorRoute == nil else { return }
            editorRoute = GoalEditorRoute(goal: nil)
            addRequest = nil
        }
    }
}
