import Foundation
import XCTest
@testable import DopaBreakCore

final class CatalogAllowanceStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: CatalogAllowanceStore!

    override func setUpWithError() throws {
        suiteName = "CatalogAllowanceStoreTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        store = CatalogAllowanceStore(userDefaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
        suiteName = nil
    }

    func testGrantReturnsActiveAllowance() {
        let now = Date(timeIntervalSince1970: 1_000)
        let until = now.addingTimeInterval(600)

        store.grant(catalogID: "instagram", until: until)

        XCTAssertEqual(store.activeAllowance(catalogID: "instagram", at: now), until)
    }

    func testExpiredAllowanceIsInactive() {
        let until = Date(timeIntervalSince1970: 1_000)
        store.grant(catalogID: "instagram", until: until)

        XCTAssertNil(store.activeAllowance(catalogID: "instagram", at: until))
        XCTAssertNil(store.activeAllowance(catalogID: "instagram", at: until.addingTimeInterval(1)))
    }

    func testRevokeRemovesAllowance() {
        let now = Date(timeIntervalSince1970: 1_000)
        store.grant(catalogID: "instagram", until: now.addingTimeInterval(600))

        store.revoke(catalogID: "instagram")

        XCTAssertNil(store.activeAllowance(catalogID: "instagram", at: now))
    }

    func testPurgeRemovesOnlyExpiredAllowances() {
        let now = Date(timeIntervalSince1970: 1_000)
        let activeUntil = now.addingTimeInterval(600)
        store.grant(catalogID: "instagram", until: now)
        store.grant(catalogID: "youtube", until: activeUntil)

        store.purgeExpired(at: now)

        XCTAssertNil(store.activeAllowance(catalogID: "instagram", at: now))
        XCTAssertEqual(store.activeAllowance(catalogID: "youtube", at: now), activeUntil)
    }
}
