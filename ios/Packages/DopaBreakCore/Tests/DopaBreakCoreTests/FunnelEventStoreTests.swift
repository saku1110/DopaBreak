import Foundation
import XCTest
@testable import DopaBreakCore

final class FunnelEventStoreTests: XCTestCase {
    func testRecordPersistsAndAllEventsReadsInOrder() throws {
        let store = try makeStore()
        let firstDate = Date(timeIntervalSince1970: 1_700_000_000.123)
        let secondDate = Date(timeIntervalSince1970: 1_700_000_001.456)

        try store.record(name: .onboardingCompleted, at: firstDate)
        try store.record(name: .automationVerified, detail: "instagram", at: secondDate)

        XCTAssertEqual(
            try store.allEvents(),
            [
                FunnelEvent(name: "onboardingCompleted", occurredAt: firstDate),
                FunnelEvent(name: "automationVerified", detail: "instagram", occurredAt: secondDate)
            ]
        )
    }

    func testRecordingMoreThanFiveThousandDiscardsOldestHalf() throws {
        let containerURL = try makeTemporaryDirectory()
        let snapshotStore = JSONSnapshotStore(containerProvider: FixedContainer(url: containerURL))
        let existingEvents = (0..<5_000).map { index in
            FunnelEvent(
                name: FunnelEventName.paywallShown.rawValue,
                occurredAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }
        try snapshotStore.write(existingEvents, to: .funnelEvents)
        let store = FunnelEventStore(snapshotStore: snapshotStore)

        try store.record(
            name: .trialOrPurchaseStarted,
            detail: "dopabreak.pro.annual",
            at: Date(timeIntervalSince1970: 5_000)
        )

        let events = try store.allEvents()
        XCTAssertEqual(events.count, 2_501)
        XCTAssertEqual(events.first?.occurredAt, Date(timeIntervalSince1970: 2_500))
        XCTAssertEqual(events.last?.detail, "dopabreak.pro.annual")
    }

    func testFunnelEventCodableRoundTrip() throws {
        let original = FunnelEvent(
            name: FunnelEventName.trialOrPurchaseStarted.rawValue,
            detail: "dopabreak.pro.annual",
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000.25)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FunnelEvent.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testMeasurementFoundationEventsPersistNamesAndDetails() throws {
        let store = try makeStore()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

        try store.record(name: .onboardingStepCompleted, detail: "pre_paywall_summary", at: timestamp)
        try store.record(name: .paywallDismissed, detail: "onboarding_prepaywall_summary", at: timestamp)
        try store.record(name: .prePaywallSkipped, detail: "pre_paywall_summary", at: timestamp)
        try store.record(name: .appOpened, at: timestamp)

        XCTAssertEqual(
            try store.allEvents(),
            [
                FunnelEvent(
                    name: "onboardingStepCompleted",
                    detail: "pre_paywall_summary",
                    occurredAt: timestamp
                ),
                FunnelEvent(
                    name: "paywallDismissed",
                    detail: "onboarding_prepaywall_summary",
                    occurredAt: timestamp
                ),
                FunnelEvent(
                    name: "prePaywallSkipped",
                    detail: "pre_paywall_summary",
                    occurredAt: timestamp
                ),
                FunnelEvent(name: "appOpened", occurredAt: timestamp)
            ]
        )
    }

    private func makeStore() throws -> FunnelEventStore {
        FunnelEventStore(
            snapshotStore: JSONSnapshotStore(containerProvider: FixedContainer(url: try makeTemporaryDirectory()))
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FunnelEventStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
