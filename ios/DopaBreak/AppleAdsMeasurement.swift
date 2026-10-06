import Foundation
import RevenueCat

/// RevenueCat observes purchases; StoreService remains the owner of StoreKit transactions
/// and Pro access. No IDFA, contact details, goals, or selected SNS names are collected here.
@MainActor
final class AppleAdsMeasurement {
    static let shared = AppleAdsMeasurement(client: RevenueCatMeasurementClient())

    private let client: AppleAdsMeasurementClient
    private(set) var isStarted = false
    private var stepTask: Task<Void, Never>?
    private var recordedMilestones = Set<Milestone>()

    /// Display only after SDK startup, so opening privacy settings never starts collection.
    var supportIdentifier: String? { isStarted ? client.appUserID : nil }

    enum Milestone: String {
        case onboardingCompleted = "onboarding_completed"
        case automationVerified = "automation_verified"
        case breathingCompleted = "breathing_completed"
        /// ペイウォールを1回でも見たか。試用しなかった人が「見ていない」のか「見て断った」のかを分ける
        case paywallViewed = "paywall_viewed"
    }

    init(client: AppleAdsMeasurementClient) {
        self.client = client
    }

    func start(apiKey: String?, enabled: Bool) {
        guard enabled, !isStarted,
              let apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              apiKey.hasPrefix("appl_"), apiKey.count > 10 else { return }
        client.configure(apiKey: apiKey)
        client.enableAppleAdsAttribution()
        isStarted = true
    }

    /// Coarse completion flags only. They are customer attributes, not an event history.
    func record(_ milestone: Milestone) {
        guard isStarted, recordedMilestones.insert(milestone).inserted else { return }
        client.setMilestone(milestone.rawValue)
    }

    /// オンボーディングの止め方の選択（free=一呼吸だけ／block=一呼吸＋ブロック）。最後の選択で上書きする。
    func recordBlockChoice(_ choosesBlock: Bool) {
        guard isStarted else { return }
        client.setAttribute("onboarding_block_choice", value: choosesBlock ? "block" : "free")
    }

    /// 最後に見たペイウォールの出し場所。どの導線から課金画面に来たかを残す。
    func recordPaywallShown(placement: String) {
        guard isStarted else { return }
        record(.paywallViewed)
        client.setAttribute("paywall_last_placement", value: placement)
    }

    func recordOnboardingStep(_ identifier: String) {
        guard isStarted else { return }
        stepTask?.cancel()
        stepTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            guard !Task.isCancelled else { return }
            self?.client.setAttribute("onboarding_last_step", value: identifier)
        }
    }

    /// Explicitly synchronize after purchase/restore. Failure must never change Pro access.
    /// The SDK also observes transaction updates and refreshes on foreground.
    func synchronizePurchases() async {
        guard isStarted else { return }
        await client.synchronizePurchases()
    }
}

@MainActor
protocol AppleAdsMeasurementClient {
    var appUserID: String { get }
    func configure(apiKey: String)
    func enableAppleAdsAttribution()
    func setMilestone(_ name: String)
    func setAttribute(_ name: String, value: String)
    func synchronizePurchases() async
}

@MainActor
private final class RevenueCatMeasurementClient: AppleAdsMeasurementClient {
    var appUserID: String { Purchases.shared.appUserID }
    func configure(apiKey: String) {
        Purchases.logLevel = .error
        Purchases.configure(
            with: Configuration.Builder(withAPIKey: apiKey)
                .with(purchasesAreCompletedBy: .myApp, storeKitVersion: .storeKit2)
                .with(automaticDeviceIdentifierCollectionEnabled: false)
                .build()
        )
    }

    func enableAppleAdsAttribution() {
        Purchases.shared.attribution.enableAdServicesAttributionTokenCollection()
    }

    func setAttribute(_ name: String, value: String) {
        Purchases.shared.attribution.setAttributes([name: value])
    }

    func setMilestone(_ name: String) {
        Purchases.shared.attribution.setAttributes([name: "true"])
    }

    func synchronizePurchases() async {
        // Server-verified transactions, not paywall taps, determine trial/revenue in RevenueCat.
        // SDK/server reconciliation retries on future activity; this is not a purchase gate.
        _ = try? await Purchases.shared.syncPurchases()
    }
}
