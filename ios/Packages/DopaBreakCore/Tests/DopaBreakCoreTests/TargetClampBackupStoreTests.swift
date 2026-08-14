import Foundation
import XCTest
@testable import DopaBreakCore

final class TargetClampBackupStoreTests: XCTestCase {
    // MARK: - 未確定のあいだは縮小しない

    /// 取得失敗や起動直後の未解決を「無料確定」とみなして縮小すると、
    /// 課金者の対象アプリを復元経路なしに削ることになる（監査P0-A③）。
    func testDoesNotClampWhileEntitlementIsUnconfirmed() {
        let reconciliation = TargetClampPolicy.reconciliation(
            hasConfirmedEntitlement: false,
            isPro: false,
            selectedCatalogIDs: ["instagram", "youtube", "x"],
            backup: nil
        )

        XCTAssertEqual(reconciliation, .skip)
    }

    /// 未確定なら、控えがあっても復元も破棄もしない。確定するまで一切触らない。
    func testDoesNotTouchBackupWhileEntitlementIsUnconfirmed() {
        let reconciliation = TargetClampPolicy.reconciliation(
            hasConfirmedEntitlement: false,
            isPro: true,
            selectedCatalogIDs: ["instagram"],
            backup: TargetClampBackup(
                originalCatalogIDs: ["instagram", "youtube"],
                appliedCatalogIDs: ["instagram"]
            )
        )

        XCTAssertEqual(reconciliation, .skip)
    }

    func testClampsWhenFreeIsConfirmed() {
        let reconciliation = TargetClampPolicy.reconciliation(
            hasConfirmedEntitlement: true,
            isPro: false,
            selectedCatalogIDs: ["instagram", "youtube", "x"],
            backup: nil
        )

        XCTAssertEqual(reconciliation, .clamp)
    }

    // MARK: - 縮小 → Pro復帰の往復

    func testClampThenProRecoveryRestoresTheOriginalSelection() throws {
        let store = try makeStore()
        let original = ["instagram", "youtube", "x"]
        let clamped = ["youtube"]

        store.beginClamp(originalCatalogIDs: original, pendingCatalogIDs: clamped)
        store.commitClamp(appliedCatalogIDs: clamped)

        XCTAssertEqual(
            store.backup,
            TargetClampBackup(
                originalCatalogIDs: original,
                appliedCatalogIDs: clamped,
                pendingCatalogIDs: nil
            )
        )
        XCTAssertEqual(
            TargetClampPolicy.reconciliation(
                hasConfirmedEntitlement: true,
                isPro: true,
                selectedCatalogIDs: clamped,
                backup: store.backup
            ),
            .restore(catalogIDs: original)
        )

        store.clear()

        XCTAssertNil(store.backup)
        XCTAssertEqual(
            TargetClampPolicy.reconciliation(
                hasConfirmedEntitlement: true,
                isPro: true,
                selectedCatalogIDs: original,
                backup: store.backup
            ),
            .noAction
        )
    }

    /// 段階的に縮小しても、最初に選ばれていた並びへ戻せる。
    func testRepeatedClampKeepsTheOriginalSelection() throws {
        let store = try makeStore()

        store.beginClamp(
            originalCatalogIDs: ["instagram", "youtube", "x"],
            pendingCatalogIDs: ["instagram", "youtube"]
        )
        store.commitClamp(appliedCatalogIDs: ["instagram", "youtube"])
        store.beginClamp(
            originalCatalogIDs: ["instagram", "youtube"],
            pendingCatalogIDs: ["instagram"]
        )
        store.commitClamp(appliedCatalogIDs: ["instagram"])

        XCTAssertEqual(
            store.backup,
            TargetClampBackup(
                originalCatalogIDs: ["instagram", "youtube", "x"],
                appliedCatalogIDs: ["instagram"],
                pendingCatalogIDs: nil
            )
        )
    }

    /// 縮小と無関係な並びから縮小したときは、控えを取り直す。
    func testUnrelatedClampReplacesTheBackup() throws {
        let store = try makeStore()

        store.beginClamp(
            originalCatalogIDs: ["instagram", "youtube"],
            pendingCatalogIDs: ["instagram"]
        )
        store.commitClamp(appliedCatalogIDs: ["instagram"])
        store.beginClamp(originalCatalogIDs: ["x", "tiktok"], pendingCatalogIDs: ["x"])
        store.commitClamp(appliedCatalogIDs: ["x"])

        XCTAssertEqual(
            store.backup,
            TargetClampBackup(
                originalCatalogIDs: ["x", "tiktok"],
                appliedCatalogIDs: ["x"],
                pendingCatalogIDs: nil
            )
        )
    }

    // MARK: - 縮小の途中で落ちた場合の復旧

    /// 2回目の縮小で「控えを書いた直後・選択を書き込む前」に落ちた場合。
    /// 再起動後の選択は1回目の結果のままなので、そこから最初の並びへ戻せなければならない。
    func testProRestartAfterCrashBeforeWritingSelectionRestoresTheOriginalSelection() throws {
        let store = try makeStore()
        store.beginClamp(
            originalCatalogIDs: ["instagram", "youtube", "x"],
            pendingCatalogIDs: ["instagram", "youtube"]
        )
        store.commitClamp(appliedCatalogIDs: ["instagram", "youtube"])

        // 2回目の縮小を開始した直後に落ちる（選択はまだ ["instagram", "youtube"]）。
        store.beginClamp(
            originalCatalogIDs: ["instagram", "youtube"],
            pendingCatalogIDs: ["instagram"]
        )

        XCTAssertEqual(store.backup?.originalCatalogIDs, ["instagram", "youtube", "x"])
        XCTAssertEqual(
            TargetClampPolicy.reconciliation(
                hasConfirmedEntitlement: true,
                isPro: true,
                selectedCatalogIDs: ["instagram", "youtube"],
                backup: store.backup
            ),
            .restore(catalogIDs: ["instagram", "youtube", "x"])
        )
    }

    /// 「選択を書き込んだ直後・確定させる前」に落ちた場合。
    /// 選択は書き込み中の結果になっているので、そちらからも復元できなければならない。
    func testProRestartAfterCrashBeforeCommitRestoresTheOriginalSelection() throws {
        let store = try makeStore()
        store.beginClamp(
            originalCatalogIDs: ["instagram", "youtube", "x"],
            pendingCatalogIDs: ["instagram"]
        )

        XCTAssertEqual(
            TargetClampPolicy.reconciliation(
                hasConfirmedEntitlement: true,
                isPro: true,
                selectedCatalogIDs: ["instagram"],
                backup: store.backup
            ),
            .restore(catalogIDs: ["instagram", "youtube", "x"])
        )
    }

    /// 無料のまま再起動した場合。もう一度縮小をやり直しても最初の並びは失われない。
    func testFreeRestartAfterCrashKeepsTheOriginalSelectionThroughTheRetry() throws {
        let store = try makeStore()
        store.beginClamp(
            originalCatalogIDs: ["instagram", "youtube", "x"],
            pendingCatalogIDs: ["instagram", "youtube"]
        )
        store.commitClamp(appliedCatalogIDs: ["instagram", "youtube"])
        store.beginClamp(
            originalCatalogIDs: ["instagram", "youtube"],
            pendingCatalogIDs: ["instagram"]
        )

        // 再起動。無料のままなので縮小をやり直す。
        XCTAssertEqual(
            TargetClampPolicy.reconciliation(
                hasConfirmedEntitlement: true,
                isPro: false,
                selectedCatalogIDs: ["instagram", "youtube"],
                backup: store.backup
            ),
            .clamp
        )
        store.beginClamp(
            originalCatalogIDs: ["instagram", "youtube"],
            pendingCatalogIDs: ["instagram"]
        )
        store.commitClamp(appliedCatalogIDs: ["instagram"])

        XCTAssertEqual(store.backup?.originalCatalogIDs, ["instagram", "youtube", "x"])
        XCTAssertEqual(
            TargetClampPolicy.reconciliation(
                hasConfirmedEntitlement: true,
                isPro: true,
                selectedCatalogIDs: ["instagram"],
                backup: store.backup
            ),
            .restore(catalogIDs: ["instagram", "youtube", "x"])
        )
    }

    /// 書き込み中の結果を確定させたら、書き込み前の状態はもう復元条件にしない。
    func testCommitClearsThePendingClampResult() throws {
        let store = try makeStore()
        store.beginClamp(
            originalCatalogIDs: ["instagram", "youtube", "x"],
            pendingCatalogIDs: ["instagram", "youtube"]
        )
        store.commitClamp(appliedCatalogIDs: ["instagram", "youtube"])
        store.beginClamp(
            originalCatalogIDs: ["instagram", "youtube"],
            pendingCatalogIDs: ["instagram"]
        )
        store.commitClamp(appliedCatalogIDs: ["instagram"])

        XCTAssertNil(store.backup?.pendingCatalogIDs)
        XCTAssertEqual(
            TargetClampPolicy.reconciliation(
                hasConfirmedEntitlement: true,
                isPro: true,
                selectedCatalogIDs: ["instagram", "youtube"],
                backup: store.backup
            ),
            .discardBackup
        )
    }

    /// 控えが無いのに確定だけ来ても、レコードを作らない。
    func testCommitWithoutBeginDoesNotCreateARecord() throws {
        let store = try makeStore()

        store.commitClamp(appliedCatalogIDs: ["instagram"])

        XCTAssertNil(store.backup)
    }

    // MARK: - 復元してはいけない場合

    /// ユーザーが自分で選び直したあとに古い並びを蘇らせない。
    func testDiscardsBackupWhenSelectionChangedAfterClamp() {
        let reconciliation = TargetClampPolicy.reconciliation(
            hasConfirmedEntitlement: true,
            isPro: true,
            selectedCatalogIDs: ["tiktok"],
            backup: TargetClampBackup(
                originalCatalogIDs: ["instagram", "youtube"],
                appliedCatalogIDs: ["instagram"]
            )
        )

        XCTAssertEqual(reconciliation, .discardBackup)
    }

    /// カタログから消えたアプリは復元対象から外す。
    func testRestoreDropsUnknownCatalogIDs() {
        let reconciliation = TargetClampPolicy.reconciliation(
            hasConfirmedEntitlement: true,
            isPro: true,
            selectedCatalogIDs: ["instagram"],
            backup: TargetClampBackup(
                originalCatalogIDs: ["instagram", "retired_app", "youtube"],
                appliedCatalogIDs: ["instagram"]
            )
        )

        XCTAssertEqual(reconciliation, .restore(catalogIDs: ["instagram", "youtube"]))
    }

    /// 復元しても中身が変わらないなら控えを捨てるだけにする。
    func testDiscardsBackupWhenRestoreWouldChangeNothing() {
        let reconciliation = TargetClampPolicy.reconciliation(
            hasConfirmedEntitlement: true,
            isPro: true,
            selectedCatalogIDs: ["instagram"],
            backup: TargetClampBackup(
                originalCatalogIDs: ["instagram", "retired_app"],
                appliedCatalogIDs: ["instagram"]
            )
        )

        XCTAssertEqual(reconciliation, .discardBackup)
    }

    func testProWithoutBackupDoesNothing() {
        let reconciliation = TargetClampPolicy.reconciliation(
            hasConfirmedEntitlement: true,
            isPro: true,
            selectedCatalogIDs: ["instagram", "youtube"],
            backup: nil
        )

        XCTAssertEqual(reconciliation, .noAction)
    }

    // MARK: - 永続化

    func testBackupSurvivesANewStoreOverTheSameDefaults() throws {
        let defaults = try makeDefaults()
        let writer = TargetClampBackupStore(userDefaults: defaults)
        writer.beginClamp(
            originalCatalogIDs: ["instagram", "youtube"],
            pendingCatalogIDs: ["instagram"]
        )
        writer.commitClamp(appliedCatalogIDs: ["instagram"])

        XCTAssertEqual(
            TargetClampBackupStore(userDefaults: defaults).backup,
            TargetClampBackup(
                originalCatalogIDs: ["instagram", "youtube"],
                appliedCatalogIDs: ["instagram"],
                pendingCatalogIDs: nil
            )
        )
    }

    func testClearRemovesStoredKeysIncludingLegacyOnes() throws {
        let defaults = try makeDefaults()
        defaults.set(["instagram", "youtube"], forKey: "preClampTargetCatalogIDs")
        defaults.set(["instagram"], forKey: "preClampTargetClampedCatalogIDs")
        let store = TargetClampBackupStore(userDefaults: defaults)
        store.beginClamp(
            originalCatalogIDs: ["instagram", "youtube"],
            pendingCatalogIDs: ["instagram"]
        )

        store.clear()

        XCTAssertNil(store.backup)
        XCTAssertNil(defaults.object(forKey: "targetClampBackupRecord"))
        XCTAssertNil(defaults.object(forKey: "preClampTargetCatalogIDs"))
        XCTAssertNil(defaults.object(forKey: "preClampTargetClampedCatalogIDs"))
    }

    // MARK: - Helpers

    private func makeStore() throws -> TargetClampBackupStore {
        TargetClampBackupStore(userDefaults: try makeDefaults())
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "TargetClampBackupStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
