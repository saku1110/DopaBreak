import Foundation
import XCTest
@testable import DopaBreakCore

final class NightShieldSnapshotTests: XCTestCase {
    /// 拡張はこの控えだけを見て夜間ブロックを出す。書いた選択データがそのまま戻ることを固定する。
    func testRoundTripsThroughTheSnapshotStore() throws {
        let store = try makeSnapshotStore()
        let snapshot = NightShieldSnapshot(
            selectionDataList: [Data([0x01, 0x02]), Data([0xFF])],
            bedTimeMinutes: 1_380,
            wakeTimeMinutes: 420,
            updatedAt: Date(timeIntervalSince1970: 1_755_100_000.123)
        )

        try store.write(snapshot, to: .nightShieldSnapshot)

        XCTAssertEqual(
            try store.read(NightShieldSnapshot.self, from: .nightShieldSnapshot),
            snapshot
        )
    }

    func testRoundTripsWithoutSelections() throws {
        let store = try makeSnapshotStore()
        let snapshot = NightShieldSnapshot(
            selectionDataList: [],
            bedTimeMinutes: 0,
            wakeTimeMinutes: 1_439,
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        try store.write(snapshot, to: .nightShieldSnapshot)

        XCTAssertEqual(
            try store.read(NightShieldSnapshot.self, from: .nightShieldSnapshot),
            snapshot
        )
    }

    /// 降格と全データ削除で消す先。消したあとは「無い」として読めることまで確かめる。
    func testReadsNilAfterRemoval() throws {
        let store = try makeSnapshotStore()
        try store.write(
            NightShieldSnapshot(
                selectionDataList: [Data([0x01])],
                bedTimeMinutes: 1_380,
                wakeTimeMinutes: 420,
                updatedAt: Date(timeIntervalSince1970: 0)
            ),
            to: .nightShieldSnapshot
        )

        try store.remove(.nightShieldSnapshot)

        XCTAssertNil(try store.read(NightShieldSnapshot.self, from: .nightShieldSnapshot))
    }

    /// 拡張が適用の直前に見る存在確認。消えたら張らない、が成り立つことを固定する。
    func testExistsFollowsWriteAndRemove() throws {
        let store = try makeSnapshotStore()
        XCTAssertFalse(store.exists(.nightShieldSnapshot))

        try store.write(
            NightShieldSnapshot(
                selectionDataList: [Data([0x01])],
                bedTimeMinutes: 1_380,
                wakeTimeMinutes: 420,
                updatedAt: Date(timeIntervalSince1970: 0)
            ),
            to: .nightShieldSnapshot
        )
        XCTAssertTrue(store.exists(.nightShieldSnapshot))

        try store.remove(.nightShieldSnapshot)
        XCTAssertFalse(store.exists(.nightShieldSnapshot))
    }

    /// ファイル名は拡張と共有する。変えるとアプリが書いた控えを拡張が見つけられなくなる。
    func testSnapshotFileName() {
        XCTAssertEqual(SnapshotFile.nightShieldSnapshot.rawValue, "night_shield_snapshot.json")
    }

    private func makeSnapshotStore() throws -> JSONSnapshotStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("NightShieldSnapshotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return JSONSnapshotStore(containerProvider: FixedContainer(url: url))
    }
}
