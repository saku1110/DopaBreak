import Combine
import DopaBreakCore
import Foundation
import SwiftUI

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
    @State private var pendingPaywallPlacement: PaywallPlacement?
    @State private var presentedInterventionCatalogID: String?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(model: model, settingsStore: settingsStore)
                .tag(AppTab.home)
                .tabItem {
                    Label(String(localized: "root_tab.home", defaultValue: "ホーム"), systemImage: "house")
                }

            GoalsView(model: model)
                .tag(AppTab.goals)
                .tabItem {
                    Label(String(localized: "root_tab.goals", defaultValue: "目標"), systemImage: "flag")
                }

            StatsView(model: model)
                .tag(AppTab.stats)
                .tabItem {
                    Label(String(localized: "root_tab.stats", defaultValue: "統計"), systemImage: "chart.bar")
                }

            SettingsView(
                model: model,
                settingsStore: settingsStore,
                onResetOnboarding: onResetOnboarding
            )
                .tag(AppTab.settings)
                .tabItem {
                    Label(String(localized: "root_tab.settings", defaultValue: "設定"), systemImage: "gearshape")
                }
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DopaTabBar(selection: $selectedTab)
        }
        .tint(DesignTokens.accent)
        .alert(String(localized: "root_alert.error.title", defaultValue: "エラー"), isPresented: alertPresented) {
            Button(String(localized: "root_alert.action.close", defaultValue: "閉じる")) {
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
        .onChange(of: model.storeService.isPro) { _, _ in
            model.refresh()
            presentPendingInterventionIfValid(model.pendingInterventionCatalogID)
            checkPendingPaywalls()
        }
        .onChange(of: model.storeService.hasResolvedEntitlement) { _, _ in
            model.refresh()
            presentPendingInterventionIfValid(model.pendingInterventionCatalogID)
            checkPendingPaywalls()
        }
        .onChange(of: model.storeService.entitlementRevision) { _, _ in
            model.refresh()
            presentPendingInterventionIfValid(model.pendingInterventionCatalogID)
            checkPendingPaywalls()
        }
        .onChange(of: model.isChildModalActive) { _, isActive in
            guard !isActive else { return }
            checkPendingPaywalls()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            model.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pendingMidSessionCheckInDidChange)) { _ in
            checkPendingMidSessionCheckIn()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pendingDay14WarningDidChange)) { _ in
            checkPendingDay14Warning()
        }
        .onChange(of: model.pendingInterventionCatalogID) { _, catalogID in
            presentPendingInterventionIfValid(catalogID)
        }
        .fullScreenCover(isPresented: interventionPresented, onDismiss: {
            checkPendingMidSessionCheckIn()
            checkPendingReflection()
            checkPendingPaywalls()
        }) {
            if let catalogID = presentedInterventionCatalogID,
               let target = SNSAppCatalog.app(catalogID: catalogID) {
                InterventionFlowView(
                    target: target,
                    model: model,
                    settingsStore: settingsStore,
                    onFinished: {
                        model.pendingInterventionCatalogID = nil
                        presentedInterventionCatalogID = nil
                        model.refresh()
                    }
                )
            }
        }
        .sheet(item: $pendingReflection, onDismiss: {
            checkPendingMidSessionCheckIn()
            checkPendingPaywalls()
        }) { reflection in
            if let engine = model.interventionEngine {
                PostUseReflectionSheet(model: model, engine: engine, reflection: reflection) {
                    pendingReflection = nil
                    model.refresh()
                }
            }
        }
        .sheet(item: $pendingMidSessionCheckInTarget, onDismiss: {
            checkPendingReflection()
            checkPendingPaywalls()
        }) { _ in
            MidSessionCheckInSheet(model: model)
        }
        .fullScreenCover(item: $pendingPaywallPlacement, onDismiss: {
            checkPendingPaywalls()
        }) { placement in
            PaywallView(
                storeService: model.storeService,
                placement: placement,
                settingsStore: settingsStore
            )
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
            get: { presentedInterventionCatalogID != nil },
            set: { isPresented in
                if !isPresented {
                    model.pendingInterventionCatalogID = nil
                    presentedInterventionCatalogID = nil
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
        presentPendingInterventionIfValid(model.pendingInterventionCatalogID)
        checkPendingMidSessionCheckIn()
        checkPendingReflection()
        checkPendingPaywalls()
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
        guard let pending = settingsStore.pendingMidSessionCheckIn else {
            return
        }

        guard pending.isValid(at: Date()) else {
            settingsStore.pendingMidSessionCheckIn = nil
            return
        }

        settingsStore.pendingMidSessionCheckIn = nil
        pendingMidSessionCheckInTarget = SNSAppCatalog.app(catalogID: pending.catalogID)
    }

    private func checkPendingDay14Warning() {
        guard model.pendingInterventionCatalogID == nil,
              pendingMidSessionCheckInTarget == nil,
              pendingReflection == nil,
              pendingPaywallPlacement == nil,
              !model.isChildModalActive else {
            return
        }
        guard let pending = settingsStore.pendingDay14Warning else {
            return
        }

        guard pending.isValid(at: Date()) else {
            settingsStore.pendingDay14Warning = nil
            return
        }

        guard model.storeService.hasResolvedEntitlement else {
            return
        }
        guard model.shouldPresentDay14Warning else {
            settingsStore.pendingDay14Warning = nil
            return
        }

        settingsStore.pendingDay14Warning = nil
        pendingPaywallPlacement = .day14Warning
    }

    private func checkPendingReverseTrialEndPaywall() {
        guard settingsStore.onboardingCompleted,
              model.storeService.hasResolvedEntitlement,
              !model.storeService.isPro,
              model.pendingInterventionCatalogID == nil,
              presentedInterventionCatalogID == nil,
              pendingMidSessionCheckInTarget == nil,
              pendingReflection == nil,
              pendingPaywallPlacement == nil,
              !model.isChildModalActive,
              model.shouldPresentReverseTrialEndPaywall else {
            return
        }

        pendingPaywallPlacement = .reverseTrialEnd
    }

    private func checkPendingPaywalls() {
        // Day14 keeps the existing warning priority. Reverse-trial expiry is
        // evaluated after it, and both remain deferred while another modal is up.
        checkPendingDay14Warning()
        checkPendingReverseTrialEndPaywall()
        checkPendingWeeklyPaywall()
    }

    private func checkPendingWeeklyPaywall() {
        guard settingsStore.onboardingCompleted,
              model.pendingInterventionCatalogID == nil,
              presentedInterventionCatalogID == nil,
              pendingMidSessionCheckInTarget == nil,
              pendingReflection == nil,
              pendingPaywallPlacement == nil,
              !model.isChildModalActive,
              WeeklyPaywallPolicy.shouldPresent(
                  isPro: model.storeService.isPro,
                  hasResolvedEntitlement: model.storeService.hasResolvedEntitlement,
                  onboardingCompleted: settingsStore.onboardingCompleted,
                  onboardingCompletedAt: settingsStore.onboardingCompletedAt,
                  lastShownAt: settingsStore.lastWeeklyPaywallShownAt,
                  lastAnyPaywallShownAt: settingsStore.lastAnyPaywallShownAt,
                  now: Date()
              ) else {
            return
        }

        pendingPaywallPlacement = .weekly
    }

    private func presentPendingInterventionIfValid(_ catalogID: String?) {
        guard let catalogID else {
            presentedInterventionCatalogID = nil
            return
        }
        guard model.storeService.hasResolvedEntitlement else {
            return
        }
        guard model.isCurrentInterventionTarget(catalogID: catalogID) else {
            model.pendingInterventionCatalogID = nil
            presentedInterventionCatalogID = nil
            return
        }
        presentedInterventionCatalogID = catalogID
    }
}

private struct DopaTabBar: View {
    @Binding var selection: AppTab

    private let items: [(AppTab, String, String)] = [
        (.home, String(localized: "root_tab.home", defaultValue: "ホーム"), "house.fill"),
        (.goals, String(localized: "root_tab.goals", defaultValue: "目標"), "flag.fill"),
        (.stats, String(localized: "root_tab.stats", defaultValue: "統計"), "chart.bar.fill"),
        (.settings, String(localized: "root_tab.settings", defaultValue: "設定"), "slider.horizontal.3")
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
