import Combine
import SwiftUI

enum BackgroundSnapshotShieldDirective: Equatable {
    case show
    case keepCurrent
    case consumePendingInterventionThenHide
}

/// アプリスイッチャー用スナップショットへホームを残さないための表示判断の正本。
/// `.inactive` 単独ではシールドを出さず、background から active へ戻る途中だけ既存表示を保持する。
enum BackgroundSnapshotShieldPolicy {
    static func directive(for scenePhase: ScenePhase) -> BackgroundSnapshotShieldDirective {
        switch scenePhase {
        case .background:
            return .show
        case .inactive:
            return .keepCurrent
        case .active:
            return .consumePendingInterventionThenHide
        @unknown default:
            return .keepCurrent
        }
    }
}

@MainActor
final class BackgroundSnapshotShieldCoordinator: ObservableObject {
    @Published private(set) var isShieldVisible = false

    func handle(
        scenePhase: ScenePhase,
        consumePendingIntervention: () -> Void
    ) {
        switch BackgroundSnapshotShieldPolicy.directive(for: scenePhase) {
        case .show:
            isShieldVisible = true
        case .keepCurrent:
            break
        case .consumePendingInterventionThenHide:
            consumePendingIntervention()
            isShieldVisible = false
        }
    }
}

/// メインウィンドウの最上段で、バックグラウンド移行時のOSスナップショットを単色化する。
/// SwiftUIのfullScreenCoverは別のpresentation windowになるため、その表示中の撮影は覆わない。
struct BackgroundSnapshotShieldHost<Content: View>: View {
    @StateObject private var coordinator = BackgroundSnapshotShieldCoordinator()
    @State private var shieldHoldWatchdog: Task<Void, Never>?
    @State private var watchdogReleasedShield = false
    @Environment(\.scenePhase) private var scenePhase

    private let onAppActive: () -> Void
    private let shouldHoldShield: () -> Bool
    private let content: Content

    init(
        onAppActive: @escaping () -> Void,
        shouldHoldShield: @escaping () -> Bool = { false },
        @ViewBuilder content: () -> Content
    ) {
        self.onAppActive = onAppActive
        self.shouldHoldShield = shouldHoldShield
        self.content = content()
    }

    var body: some View {
        let isShieldHoldRequested = shouldHoldShield()
        let isWatchdogHoldActive = isShieldHoldRequested && !coordinator.isShieldVisible

        ZStack {
            content

            if coordinator.isShieldVisible
                || (isShieldHoldRequested && !watchdogReleasedShield) {
                DesignTokens.background
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                    .zIndex(10_000)
            }
        }
        .onAppear {
            handleInitialAppearance()
        }
        .onChange(of: scenePhase) { _, newPhase in
            handle(newPhase)
        }
        .onChange(of: isWatchdogHoldActive, initial: true) { _, shouldHold in
            updateShieldHoldWatchdog(shouldHold: shouldHold)
        }
        .onDisappear {
            shieldHoldWatchdog?.cancel()
            shieldHoldWatchdog = nil
        }
    }

    private func handleInitialAppearance() {
        if scenePhase == .active {
            handle(.active)
            return
        }

        // UIWindowへ載った直後はscenePhaseがまだinactiveのことがある。
        // 旧AppLifecycleViewと同じく初回副作用を落とさず、その後に現在phaseのシールド判断を行う。
        onAppActive()
        handle(scenePhase)
    }

    private func handle(_ phase: ScenePhase) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            coordinator.handle(
                scenePhase: phase,
                consumePendingIntervention: onAppActive
            )
        }
    }

    private func updateShieldHoldWatchdog(shouldHold: Bool) {
        guard shouldHold else {
            shieldHoldWatchdog?.cancel()
            shieldHoldWatchdog = nil
            watchdogReleasedShield = false
            return
        }
        guard shieldHoldWatchdog == nil, !watchdogReleasedShield else {
            return
        }

        shieldHoldWatchdog = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else {
                return
            }
            watchdogReleasedShield = true
            shieldHoldWatchdog = nil
        }
    }
}
