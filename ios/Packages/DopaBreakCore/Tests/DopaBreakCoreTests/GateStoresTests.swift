import Foundation
import XCTest
@testable import DopaBreakCore

final class GateStoresTests: XCTestCase {
    func testAllGateStoresRoundTrip() throws {
        let snapshotStore = try makeSnapshotStore()
        let settingsStore = GateAppSettingsStore(snapshotStore: snapshotStore)
        let ledgerStore = GateLedgerStore(snapshotStore: snapshotStore)
        let shieldStore = GateShieldSnapshotStore(snapshotStore: snapshotStore)
        let requestStore = GateUnlockRequestStore(snapshotStore: snapshotStore)
        let timestamp = Date(timeIntervalSince1970: 1_777_777_777.123)
        let tokenData = Data([0x01, 0x02])
        let settings = GateAppSettingsSnapshot(
            settings: [
                GateAppSetting(
                    tokenData: tokenData,
                    dailyOpenLimit: 3,
                    sessionMinutes: 15,
                    cooldownMinutes: 30,
                    updatedAt: timestamp
                )
            ],
            updatedAt: timestamp
        )
        let grantID = UUID()
        let ledger = GateLedger(
            entries: [
                GateLedgerEntry(
                    tokenData: tokenData,
                    dayKey: "2026-08-22",
                    opensToday: 2,
                    lastGrantEndedAt: timestamp.addingTimeInterval(-600)
                )
            ],
            activeGrants: [
                GateGrant(
                    id: grantID,
                    tokenData: tokenData,
                    ruleId: UUID(),
                    startedAt: timestamp,
                    endsAt: timestamp.addingTimeInterval(900),
                    activityName: GateConstants.reshieldActivityName(for: grantID)
                )
            ],
            updatedAt: timestamp
        )
        let shield = GateShieldSnapshot(
            selectionDataList: [Data([0xAA]), Data([0xBB])],
            updatedAt: timestamp
        )
        let request = GateUnlockRequest(
            id: UUID(),
            tokenData: tokenData,
            requestedAt: timestamp
        )

        try settingsStore.save(settings)
        try ledgerStore.save(ledger)
        try shieldStore.save(shield)
        try requestStore.save(request)

        XCTAssertEqual(try settingsStore.snapshot(), settings)
        XCTAssertEqual(try settingsStore.setting(for: tokenData), settings.settings[0])
        XCTAssertEqual(try ledgerStore.ledger(), ledger)
        XCTAssertEqual(try shieldStore.snapshot(), shield)
        XCTAssertEqual(try requestStore.request(), request)
    }

    /// 旧バージョンにファイルが無いのは正常。制限なし・空台帳・控えなしで始める。
    func testMissingFilesReturnSafeDefaults() throws {
        let snapshotStore = try makeSnapshotStore()
        let tokenData = Data([0x01])

        let setting = try GateAppSettingsStore(snapshotStore: snapshotStore)
            .setting(for: tokenData)

        XCTAssertEqual(setting.tokenData, tokenData)
        XCTAssertNil(setting.dailyOpenLimit)
        XCTAssertEqual(setting.sessionMinutes, 10)
        XCTAssertEqual(setting.cooldownMinutes, 0)
        XCTAssertEqual(
            try GateAppSettingsStore(snapshotStore: snapshotStore).snapshot(),
            .empty
        )
        XCTAssertEqual(try GateLedgerStore(snapshotStore: snapshotStore).ledger(), .empty)
        XCTAssertNil(try GateShieldSnapshotStore(snapshotStore: snapshotStore).snapshot())
        XCTAssertNil(try GateUnlockRequestStore(snapshotStore: snapshotStore).request())
    }

    /// トークンが更新で変わっても古い設定を別アプリへ誤適用せず、制限なしへ倒す。
    func testMismatchedTokenDataReturnsDefaults() throws {
        let snapshotStore = try makeSnapshotStore()
        let storedToken = Data([0x01])
        let requestedToken = Data([0x02])
        try GateAppSettingsStore(snapshotStore: snapshotStore).save(
            GateAppSettingsSnapshot(
                settings: [
                    GateAppSetting(
                        tokenData: storedToken,
                        dailyOpenLimit: 1,
                        sessionMinutes: 30,
                        cooldownMinutes: 60,
                        updatedAt: Date(timeIntervalSince1970: 100)
                    )
                ],
                updatedAt: Date(timeIntervalSince1970: 100)
            )
        )

        let setting = try GateAppSettingsStore(snapshotStore: snapshotStore)
            .setting(for: requestedToken)

        XCTAssertEqual(setting.tokenData, requestedToken)
        XCTAssertNil(setting.dailyOpenLimit)
        XCTAssertEqual(setting.sessionMinutes, GateDefaults.sessionMinutes)
        XCTAssertEqual(setting.cooldownMinutes, GateDefaults.cooldownMinutes)
    }

    func testGateStoreRemovalRestoresDefaults() throws {
        let snapshotStore = try makeSnapshotStore()
        let settingsStore = GateAppSettingsStore(snapshotStore: snapshotStore)
        let ledgerStore = GateLedgerStore(snapshotStore: snapshotStore)
        let shieldStore = GateShieldSnapshotStore(snapshotStore: snapshotStore)
        let requestStore = GateUnlockRequestStore(snapshotStore: snapshotStore)
        let now = Date(timeIntervalSince1970: 100)

        try settingsStore.save(.init(settings: [], updatedAt: now))
        try ledgerStore.save(.init(entries: [], activeGrants: [], updatedAt: now))
        try shieldStore.save(.init(selectionDataList: [], updatedAt: now))
        try requestStore.save(.init(id: UUID(), tokenData: Data([0x01]), requestedAt: now))
        try settingsStore.remove()
        try ledgerStore.remove()
        try shieldStore.remove()
        try requestStore.remove()

        XCTAssertEqual(try settingsStore.snapshot(), .empty)
        XCTAssertEqual(try ledgerStore.ledger(), .empty)
        XCTAssertNil(try shieldStore.snapshot())
        XCTAssertNil(try requestStore.request())
    }

    func testGateSnapshotFileNamesAndConstantsAreStable() {
        XCTAssertEqual(SnapshotFile.gateAppSettings.rawValue, "gate_app_settings.json")
        XCTAssertEqual(SnapshotFile.gateLedger.rawValue, "gate_ledger.json")
        XCTAssertEqual(SnapshotFile.gateShieldSnapshot.rawValue, "gate_shield_snapshot.json")
        XCTAssertEqual(SnapshotFile.gateUnlockRequest.rawValue, "gate_unlock_request.json")
        XCTAssertEqual(GateConstants.shieldStoreName, "dopabreak.gate")
        XCTAssertEqual(GateConstants.reshieldActivityPrefix, "dopabreak.gate.reshield.")
        XCTAssertEqual(
            GateConstants.unlockNotificationIdentifierPrefix,
            "dopabreak.gate.unlock."
        )
        XCTAssertEqual(GateConstants.pendingRequestTTL, 600)
        XCTAssertEqual(GateConstants.maximumConcurrentGrants, 5)
    }

    func testLedgerCoordinatedUpdatesPreserveBackToBackMutations() throws {
        let snapshotStore = try makeSnapshotStore()
        let firstStore = GateLedgerStore(snapshotStore: snapshotStore)
        let secondStore = GateLedgerStore(snapshotStore: snapshotStore)
        let now = Date(timeIntervalSince1970: 1_777_777_700)
        let entry = GateLedgerEntry(
            tokenData: Data("entry-token".utf8),
            dayKey: "2026-08-22",
            opensToday: 1,
            lastGrantEndedAt: nil
        )
        let grant = GateGrant(
            id: UUID(),
            tokenData: Data("grant-token".utf8),
            ruleId: UUID(),
            startedAt: now,
            endsAt: now.addingTimeInterval(600),
            activityName: "activity"
        )

        try firstStore.update { ledger in
            ledger.entries.append(entry)
            ledger.updatedAt = now
        }
        try secondStore.update { ledger in
            ledger.activeGrants.append(grant)
            ledger.updatedAt = now.addingTimeInterval(1)
        }

        let ledger = try firstStore.ledger()
        XCTAssertEqual(ledger.entries, [entry])
        XCTAssertEqual(ledger.activeGrants, [grant])
        XCTAssertEqual(ledger.updatedAt, now.addingTimeInterval(1))
    }

    private func makeSnapshotStore() throws -> JSONSnapshotStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GateStoresTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return JSONSnapshotStore(containerProvider: FixedContainer(url: url))
    }
}
