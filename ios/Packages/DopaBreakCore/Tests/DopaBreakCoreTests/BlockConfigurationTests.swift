import XCTest
@testable import DopaBreakCore

final class BlockConfigurationTests: XCTestCase {
    func testThreeLegacyModesMigrateOnceAndRetireNightScheduleFlag() throws {
        for mode in InterventionMode.allCases {
            for weekly in [false, true] {
                let name = "BlockMigration.\(UUID())"
                let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
                defer { defaults.removePersistentDomain(forName: name) }
                defaults.set(mode.rawValue, forKey: "pendingInterventionMode")
                defaults.set(weekly, forKey: "weeklySchedulesDuringNightEnabled")
                let settings = SettingsStore(userDefaults: defaults)
                settings.migrateBlockConfigurationIfNeeded(rules: [])
                let expected: Set<BlockTrigger>
                switch mode {
                case .standard: expected = []
                case .deepFocus: expected = [.manual, .weeklySchedule]
                case .nightOnly: expected = weekly ? [.night, .weeklySchedule] : [.night]
                }
                XCTAssertEqual(settings.blockTriggers, expected)
                XCTAssertEqual(settings.blockEnabled, mode != .standard)
                XCTAssertNil(defaults.object(forKey: "weeklySchedulesDuringNightEnabled"))
                settings.blockConfiguration = BlockConfiguration(blockEnabled: true, blockTriggers: [.manual, .night])
                let reopened = SettingsStore(userDefaults: defaults)
                reopened.migrateBlockConfigurationIfNeeded(rules: [])
                XCTAssertEqual(reopened.blockTriggers, [.manual, .night])
                reopened.resetToDefaults()
                XCTAssertEqual(reopened.blockConfiguration, BlockConfiguration())
            }
        }
    }

    func testInvalidAndMissingPendingModeMigrateTheUnionOfRules() throws {
        for pending: String? in [nil, "unknown-mode", ""] {
            for modes: [InterventionMode] in [[.standard], [.deepFocus], [.nightOnly], [.standard, .deepFocus, .nightOnly]] {
                let name = "BlockRulesMigration.\(UUID())"
                let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
                defer { defaults.removePersistentDomain(forName: name) }
                if let pending { defaults.set(pending, forKey: "pendingInterventionMode") }
                let settings = SettingsStore(userDefaults: defaults)
                let rules = modes.map { mode in
                    TargetRule(id: UUID(), name: mode.rawValue, activitySelectionData: Data([1]),
                               mode: mode, schedule: nil, delaySeconds: 0, maxOpensPerDay: nil,
                               defaultDurationMinutes: 10, isEnabled: true, createdAt: Date(), updatedAt: Date())
                }
                settings.migrateBlockConfigurationIfNeeded(rules: rules)
                var expected = Set<BlockTrigger>()
                if modes.contains(.deepFocus) { expected.formUnion([.manual, .weeklySchedule]) }
                if modes.contains(.nightOnly) { expected.insert(.night) }
                XCTAssertEqual(settings.blockTriggers, expected)
                XCTAssertEqual(settings.blockEnabled, !expected.isEmpty)
                let reopened = SettingsStore(userDefaults: defaults)
                reopened.migrateBlockConfigurationIfNeeded(rules: [])
                XCTAssertEqual(reopened.blockTriggers, expected)
            }
        }
    }

    func testFreeWithEmptyTriggersEnablesAllThreeWhenPurchaseIsConfirmed() {
        var config = BlockConfiguration()
        config.reconcileEntitlement(isPro: false, hasConfirmedEntitlement: true)
        XCTAssertFalse(config.blockEnabled)
        XCTAssertTrue(config.blockTriggers.isEmpty)
        config.reconcileEntitlement(isPro: true, hasConfirmedEntitlement: true)
        XCTAssertTrue(config.blockEnabled)
        XCTAssertEqual(config.blockTriggers, Set(BlockTrigger.allCases))
        for trigger in BlockTrigger.allCases { XCTAssertTrue(config.allows(trigger)) }
    }

    func testEntitlementLossPreservesChoicesAndRepurchaseRestoresThem() {
        var config = BlockConfiguration(blockEnabled: true, blockTriggers: Set(BlockTrigger.allCases))
        config.reconcileEntitlement(isPro: false, hasConfirmedEntitlement: false)
        XCTAssertTrue(config.blockEnabled)
        config.reconcileEntitlement(isPro: false, hasConfirmedEntitlement: true)
        XCTAssertFalse(config.blockEnabled)
        XCTAssertEqual(config.blockTriggers, Set(BlockTrigger.allCases))
        XCTAssertFalse(config.isActive(manual: true, weeklySchedule: true, night: true))
        config.reconcileEntitlement(isPro: true, hasConfirmedEntitlement: true)
        XCTAssertTrue(config.blockEnabled)
        for trigger in BlockTrigger.allCases { XCTAssertTrue(config.allows(trigger)) }
    }

    func testPersistedEntitlementLossAndRepurchaseIgnoreLegacyPreference() throws {
        let name = "BlockEntitlement.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = SettingsStore(userDefaults: defaults)
        settings.blockConfiguration = BlockConfiguration(blockEnabled: true, blockTriggers: [.manual, .night])
        settings.pendingInterventionMode = InterventionMode.standard.rawValue
        settings.reconcileBlockEntitlement(isPro: false, hasConfirmedEntitlement: true)
        let reopened = SettingsStore(userDefaults: defaults)
        reopened.migrateBlockConfigurationIfNeeded(rules: [])
        XCTAssertFalse(reopened.blockEnabled)
        XCTAssertEqual(reopened.blockTriggers, [.manual, .night])
        reopened.reconcileBlockEntitlement(isPro: true, hasConfirmedEntitlement: true)
        XCTAssertTrue(settings.blockEnabled)
        XCTAssertEqual(settings.blockTriggers, [.manual, .night])
    }

    func testArmedWindowsDescribeEveryTriggerAndExpireAtTheirOwnBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 21, hour: 23, minute: 30)))
        let sessionEnd = now.addingTimeInterval(1800)
        let deep = DeepFocusShieldSnapshot(selectionDataList: [Data([1])], sessionSelectionDataList: [Data([1])],
            schedule: .init(isEnabled: true, weekdays: [2], startMinutes: 1380, endMinutes: 60),
            session: .init(startedAt: now, endsAt: sessionEnd), updatedAt: now)
        let night = NightShieldSnapshot(selectionDataList: [Data([1])], bedTimeMinutes: 1380,
            wakeTimeMinutes: 420, updatedAt: now)
        let windows = BlockWindowStatus.active(deepFocus: deep, night: night, now: now, calendar: calendar)
        XCTAssertEqual(windows.map(\.trigger), [.manual, .weeklySchedule, .night])
        XCTAssertEqual(windows[0].endsAt, sessionEnd)
        XCTAssertEqual(windows[1].endsAt, now.addingTimeInterval(5400))
        XCTAssertEqual(windows[2].endsAt, now.addingTimeInterval(27000))
        XCTAssertEqual(BlockWindowStatus.active(deepFocus: deep, night: night, now: sessionEnd, calendar: calendar).map(\.trigger), [.weeklySchedule, .night])
        XCTAssertEqual(BlockWindowStatus.active(deepFocus: deep, night: night, now: now.addingTimeInterval(5400), calendar: calendar).map(\.trigger), [.night])
        XCTAssertTrue(BlockWindowStatus.active(deepFocus: deep, night: night, now: now.addingTimeInterval(27000), calendar: calendar).isEmpty)
    }

    func testEveryTriggerCombinationIsIndependentAndFreeNeverBlocks() {
        for mask in 0..<8 {
            let choices = Set(BlockTrigger.allCases.enumerated().compactMap { mask & (1 << $0.offset) != 0 ? $0.element : nil })
            for pro in [false, true] {
                var config = BlockConfiguration(blockTriggers: choices)
                config.reconcileEntitlement(isPro: pro, hasConfirmedEntitlement: true)
                XCTAssertEqual(config.isActive(manual: true, weeklySchedule: false, night: false), pro && (choices.isEmpty || choices.contains(.manual)))
                XCTAssertEqual(config.isActive(manual: false, weeklySchedule: true, night: false), pro && (choices.isEmpty || choices.contains(.weeklySchedule)))
                XCTAssertEqual(config.isActive(manual: false, weeklySchedule: false, night: true), pro && (choices.isEmpty || choices.contains(.night)))
                XCTAssertEqual(config.isActive(manual: true, weeklySchedule: true, night: true), pro)
                XCTAssertFalse(config.isActive(manual: false, weeklySchedule: false, night: false))
            }
        }
    }
}
