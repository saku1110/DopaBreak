import Foundation
import XCTest
@testable import DopaBreakCore

final class DeepFocusShieldSnapshotTests: XCTestCase {
    /// 拡張はこの控えだけを見て完全ブロックを出す。書いたものがそのまま戻ることを固定する。
    func testRoundTripsWithATimedSession() throws {
        let store = try makeSnapshotStore()
        let snapshot = DeepFocusShieldSnapshot(
            selectionDataList: [Data([0x01, 0x02]), Data([0xFF])],
            schedule: DeepFocusSchedule(
                isEnabled: true,
                weekdays: [2, 4, 6],
                startMinutes: 1_320,
                endMinutes: 360
            ),
            session: DeepFocusSession(
                startedAt: Date(timeIntervalSince1970: 1_755_100_000.123),
                endsAt: Date(timeIntervalSince1970: 1_755_103_600.456)
            ),
            updatedAt: Date(timeIntervalSince1970: 1_755_100_000.123)
        )

        try store.write(snapshot, to: .deepFocusShieldSnapshot)

        XCTAssertEqual(
            try store.read(DeepFocusShieldSnapshot.self, from: .deepFocusShieldSnapshot),
            snapshot
        )
    }

    /// 「自分で戻すまで」は終わる時刻を持たない。`nil` のまま戻ることを固定する。
    func testRoundTripsWithAnOpenEndedSession() throws {
        let store = try makeSnapshotStore()
        let snapshot = DeepFocusShieldSnapshot(
            selectionDataList: [Data([0x01])],
            schedule: .disabled,
            session: DeepFocusSession(
                startedAt: Date(timeIntervalSince1970: 1_755_100_000),
                endsAt: nil
            ),
            updatedAt: Date(timeIntervalSince1970: 1_755_100_000)
        )

        try store.write(snapshot, to: .deepFocusShieldSnapshot)

        let restored = try store.read(
            DeepFocusShieldSnapshot.self,
            from: .deepFocusShieldSnapshot
        )
        XCTAssertEqual(restored, snapshot)
        XCTAssertNil(restored?.session?.endsAt)
    }

    func testRoundTripsWithoutASession() throws {
        let store = try makeSnapshotStore()
        let snapshot = DeepFocusShieldSnapshot(
            selectionDataList: [],
            schedule: DeepFocusSchedule(
                isEnabled: true,
                weekdays: DeepFocusConstants.allWeekdays,
                startMinutes: 0,
                endMinutes: 1_439
            ),
            session: nil,
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        try store.write(snapshot, to: .deepFocusShieldSnapshot)

        XCTAssertEqual(
            try store.read(DeepFocusShieldSnapshot.self, from: .deepFocusShieldSnapshot),
            snapshot
        )
    }

    /// 保存の往復でも曜日は正規化されたまま。拡張側で並びが揺れないことを固定する。
    func testDecodingNormalizesWeekdaysAndMinutes() throws {
        let store = try makeSnapshotStore()
        let snapshot = DeepFocusShieldSnapshot(
            selectionDataList: [],
            schedule: DeepFocusSchedule(
                isEnabled: true,
                weekdays: [7, 2, 2, 9, 0],
                startMinutes: 1_500,
                endMinutes: -60
            ),
            session: nil,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(snapshot.schedule.weekdays, [2, 7])
        XCTAssertEqual(snapshot.schedule.startMinutes, 60)
        XCTAssertEqual(snapshot.schedule.endMinutes, 1_380)

        try store.write(snapshot, to: .deepFocusShieldSnapshot)
        let restored = try store.read(
            DeepFocusShieldSnapshot.self,
            from: .deepFocusShieldSnapshot
        )

        XCTAssertEqual(restored?.schedule.weekdays, [2, 7])
        XCTAssertEqual(restored?.schedule.startMinutes, 60)
        XCTAssertEqual(restored?.schedule.endMinutes, 1_380)
    }

    /// 降格と全データ削除で消す先。消したあとは「無い」として読めることまで確かめる。
    func testReadsNilAfterRemoval() throws {
        let store = try makeSnapshotStore()
        try store.write(makeSnapshot(), to: .deepFocusShieldSnapshot)

        try store.remove(.deepFocusShieldSnapshot)

        XCTAssertNil(try store.read(DeepFocusShieldSnapshot.self, from: .deepFocusShieldSnapshot))
    }

    /// 拡張が適用の直前に見る存在確認。消えたら張らない、が成り立つことを固定する。
    func testExistsFollowsWriteAndRemove() throws {
        let store = try makeSnapshotStore()
        XCTAssertFalse(store.exists(.deepFocusShieldSnapshot))

        try store.write(makeSnapshot(), to: .deepFocusShieldSnapshot)
        XCTAssertTrue(store.exists(.deepFocusShieldSnapshot))

        try store.remove(.deepFocusShieldSnapshot)
        XCTAssertFalse(store.exists(.deepFocusShieldSnapshot))
    }

    /// ファイル名は拡張と共有する。変えるとアプリが書いた控えを拡張が見つけられなくなる。
    func testSnapshotFileName() {
        XCTAssertEqual(
            SnapshotFile.deepFocusShieldSnapshot.rawValue,
            "deepfocus_shield_snapshot.json"
        )
    }

    /// 夜だけ強化の控えと同じファイルに書くと、片方の削除でもう片方が消える。
    func testSnapshotFileIsSeparateFromTheNightOne() {
        XCTAssertNotEqual(
            SnapshotFile.deepFocusShieldSnapshot.rawValue,
            SnapshotFile.nightShieldSnapshot.rawValue
        )
    }

    private func makeSnapshot() -> DeepFocusShieldSnapshot {
        DeepFocusShieldSnapshot(
            selectionDataList: [Data([0x01])],
            schedule: .disabled,
            session: DeepFocusSession(
                startedAt: Date(timeIntervalSince1970: 0),
                endsAt: Date(timeIntervalSince1970: 3_600)
            ),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func makeSnapshotStore() throws -> JSONSnapshotStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "DeepFocusShieldSnapshotTests-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return JSONSnapshotStore(containerProvider: FixedContainer(url: url))
    }
}
