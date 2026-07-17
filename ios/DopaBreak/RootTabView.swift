import SwiftUI
import DopaBreakCore

enum AppTab: Hashable {
    case home
    case goals
    case stats
    case settings
}

struct RootTabView: View {
    let model: AppModel
    let settingsStore: SettingsStore
    let onResetOnboarding: () -> Void
    @State private var selectedTab: AppTab = .home
    @State private var pendingReflection: ReflectionLog?
    @State private var pendingMidSessionCheckInTarget: SNSAppCatalogItem?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(model: model)
                .tag(AppTab.home)
                .tabItem {
                    Label("ホーム", systemImage: "house")
                }

            GoalsView(model: model)
                .tag(AppTab.goals)
                .tabItem {
                    Label("目標", systemImage: "flag")
                }

            StatsView(model: model)
                .tag(AppTab.stats)
                .tabItem {
                    Label("統計", systemImage: "chart.bar")
                }

            SettingsView(
                model: model,
                settingsStore: settingsStore,
                onResetOnboarding: onResetOnboarding
            )
                .tag(AppTab.settings)
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DopaTabBar(selection: $selectedTab)
        }
        .tint(DesignTokens.accent)
        .alert("エラー", isPresented: alertPresented) {
            Button("閉じる") {
                model.alertMessage = nil
            }
        } message: {
            Text(model.alertMessage ?? "")
        }
        .onAppear {
            handleAppActive()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            handleAppActive()
        }
        .fullScreenCover(isPresented: interventionPresented) {
            if let catalogID = model.pendingInterventionCatalogID,
               let target = SNSAppCatalog.app(catalogID: catalogID) {
                InterventionFlowView(
                    target: target,
                    model: model,
                    settingsStore: settingsStore,
                    onFinished: {
                        model.pendingInterventionCatalogID = nil
                        model.refresh()
                    }
                )
            }
        }
        .sheet(item: $pendingReflection) { reflection in
            if let engine = model.interventionEngine {
                PostUseReflectionSheet(engine: engine, reflection: reflection) {
                    pendingReflection = nil
                    model.refresh()
                }
            }
        }
        .sheet(item: $pendingMidSessionCheckInTarget) { _ in
            MidSessionCheckInSheet(model: model)
        }
    }

    private var alertPresented: Binding<Bool> {
        Binding(
            get: { model.alertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    model.alertMessage = nil
                }
            }
        )
    }

    private var interventionPresented: Binding<Bool> {
        Binding(
            get: { model.pendingInterventionCatalogID != nil },
            set: { isPresented in
                if !isPresented {
                    model.pendingInterventionCatalogID = nil
                }
            }
        )
    }

    private func checkPendingIntervention() {
        model.consumePendingInterventionRequest(from: settingsStore)
    }

    private func handleAppActive() {
        model.refresh(restartLiveActivity: true)
        checkPendingIntervention()
        checkPendingMidSessionCheckIn()
        checkPendingReflection()
    }

    private func checkPendingReflection() {
        guard model.pendingInterventionCatalogID == nil,
              pendingMidSessionCheckInTarget == nil,
              pendingReflection == nil else {
            return
        }
        guard let engine = model.interventionEngine else {
            return
        }
        pendingReflection = try? engine.pendingReflection()
    }

    private func checkPendingMidSessionCheckIn() {
        guard model.pendingInterventionCatalogID == nil,
              pendingReflection == nil,
              pendingMidSessionCheckInTarget == nil else {
            return
        }
        guard let catalogID = settingsStore.pendingMidSessionCheckInCatalogID else {
            return
        }

        settingsStore.pendingMidSessionCheckInCatalogID = nil
        pendingMidSessionCheckInTarget = SNSAppCatalog.app(catalogID: catalogID)
    }
}

private struct DopaTabBar: View {
    @Binding var selection: AppTab

    private let items: [(AppTab, String, String)] = [
        (.home, "ホーム", "house.fill"),
        (.goals, "目標", "flag.fill"),
        (.stats, "統計", "chart.bar.fill"),
        (.settings, "設定", "slider.horizontal.3")
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.0) { tab, label, symbol in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: symbol)
                            .font(.system(size: 16, weight: .bold))
                        Text(label)
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(selection == tab ? DesignTokens.accent : DesignTokens.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(selection == tab ? DesignTokens.accent.opacity(0.09) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(6)
        .background(DesignTokens.backgroundRaised)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignTokens.hairline)
                .frame(height: 1)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .background(DesignTokens.background)
    }
}
