import XCTest
@testable import DopaBreak

@MainActor
final class AppleAdsMeasurementTests: XCTestCase {
    func testOnboardingLastStepDebouncesAndUsesAnalyticsIdentifier() async throws {
        let client = MeasurementClientSpy()
        let measurement = AppleAdsMeasurement(client: client)
        measurement.recordOnboardingStep("ignored")
        measurement.start(apiKey: "appl_fixture_public_key", enabled: true)
        measurement.recordOnboardingStep(OnboardingStep.chooseApps.analyticsIdentifier)
        measurement.recordOnboardingStep(OnboardingStep.permission.analyticsIdentifier)
        XCTAssertEqual(client.calls, ["configure", "attribution"])
        try await Task.sleep(for: .milliseconds(1200))
        XCTAssertEqual(client.calls, ["configure", "attribution", "onboarding_last_step=permission"])
    }

    func testDisabledStartupDoesNotConfigureOrSendAnything() async {
        let client = MeasurementClientSpy()
        let measurement = AppleAdsMeasurement(client: client)
        measurement.start(apiKey: "appl_fixture_public_key", enabled: false)
        await measurement.synchronizePurchases()
        XCTAssertEqual(client.calls, [])
        XCTAssertFalse(measurement.isStarted)
        XCTAssertNil(measurement.supportIdentifier)
    }

    func testMissingSecretAndTestStoreKeysAreRejected() {
        for key in [nil, "", "$(REVENUECAT_PUBLIC_SDK_KEY)", "sk_secret", "test_fixture"] as [String?] {
            let client = MeasurementClientSpy()
            let measurement = AppleAdsMeasurement(client: client)
            measurement.start(apiKey: key, enabled: true)
            XCTAssertEqual(client.calls, [])
        }
    }

    func testConfigurationPrecedesAttributionAndRunsOnlyOnce() async {
        let client = MeasurementClientSpy()
        let measurement = AppleAdsMeasurement(client: client)
        measurement.start(apiKey: "appl_fixture_public_key", enabled: true)
        measurement.start(apiKey: "appl_other_public_key", enabled: true)
        await measurement.synchronizePurchases()
        XCTAssertEqual(client.calls, ["configure", "attribution", "sync"])
        XCTAssertTrue(measurement.isStarted)
        XCTAssertEqual(measurement.supportIdentifier, "$RCAnonymousID:fixture")
    }

    func testStartupCanBeEnabledAfterDisabledAttempt() {
        let client = MeasurementClientSpy()
        let measurement = AppleAdsMeasurement(client: client)
        measurement.start(apiKey: nil, enabled: false)
        measurement.start(apiKey: "appl_fixture_public_key", enabled: true)
        XCTAssertEqual(client.calls, ["configure", "attribution"])
    }

    func testMilestonesAreSuppressedWhileDisabledAndDeduplicatedPerSession() {
        let client = MeasurementClientSpy()
        let measurement = AppleAdsMeasurement(client: client)
        measurement.record(.breathingCompleted)
        XCTAssertEqual(client.calls, [])
        measurement.start(apiKey: "appl_fixture_public_key", enabled: true)
        measurement.record(.breathingCompleted)
        measurement.record(.breathingCompleted)
        measurement.record(.automationVerified)
        XCTAssertEqual(client.calls, ["configure", "attribution", "breathing_completed", "automation_verified"])
    }

    /// 止め方の選択とペイウォール表示は、試用しなかった理由を切り分けるために外へ送る（2026-09-24）。
    func testBlockChoiceAndPaywallViewAreSentOnlyAfterStart() {
        let client = MeasurementClientSpy()
        let measurement = AppleAdsMeasurement(client: client)
        measurement.recordBlockChoice(true)
        measurement.recordPaywallShown(placement: "onboarding_prepaywall_summary")
        XCTAssertEqual(client.calls, [])
        measurement.start(apiKey: "appl_fixture_public_key", enabled: true)
        measurement.recordBlockChoice(false)
        measurement.recordPaywallShown(placement: "onboarding_prepaywall_summary")
        measurement.recordPaywallShown(placement: "settings_mode_gate")
        XCTAssertEqual(client.calls, [
            "configure", "attribution",
            "onboarding_block_choice=free",
            "paywall_viewed", "paywall_last_placement=onboarding_prepaywall_summary",
            "paywall_last_placement=settings_mode_gate"
        ])
    }
}

@MainActor
private final class MeasurementClientSpy: AppleAdsMeasurementClient {
    var appUserID: String { "$RCAnonymousID:fixture" }
    var calls: [String] = []
    func configure(apiKey: String) { calls.append("configure") }
    func enableAppleAdsAttribution() { calls.append("attribution") }
    func setMilestone(_ name: String) { calls.append(name) }
    func setAttribute(_ name: String, value: String) { calls.append("\(name)=\(value)") }
    func synchronizePurchases() async { calls.append("sync") }
}
