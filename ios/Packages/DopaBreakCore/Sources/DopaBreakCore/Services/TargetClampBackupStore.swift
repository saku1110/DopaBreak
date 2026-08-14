import Foundation

/// 無料枠へ縮小するときの控え。1件のレコードとして原子的に読み書きする。
///
/// 縮小は「ユーザーが選んだ対象アプリを削る」破壊的操作で、選択の書き込みと控えの更新は
/// 別々のストアへ向かう。片方だけが済んだ状態で落ちても最初の並びへ戻せるよう、
/// 「最初の並び」「書き込みが完了した結果」「書き込み中の結果」を1レコードにまとめて持つ。
public struct TargetClampBackup: Codable, Equatable, Sendable {
    /// 縮小が始まる前にユーザーが選んでいた並び。復元先。
    public let originalCatalogIDs: [String]
    /// 書き込みまで完了した縮小結果。
    public let appliedCatalogIDs: [String]?
    /// 書き込みを始めたが、完了を確認できていない縮小結果。
    public let pendingCatalogIDs: [String]?

    public init(
        originalCatalogIDs: [String],
        appliedCatalogIDs: [String]? = nil,
        pendingCatalogIDs: [String]? = nil
    ) {
        self.originalCatalogIDs = originalCatalogIDs
        self.appliedCatalogIDs = appliedCatalogIDs
        self.pendingCatalogIDs = pendingCatalogIDs
    }

    /// いまの選択が「縮小直後のまま」かどうか。
    /// 書き込みの前後どちらで落ちていても拾えるよう、完了分と書き込み中の両方を受理する。
    public func matchesClampResult(_ catalogIDs: [String]) -> Bool {
        if let appliedCatalogIDs, appliedCatalogIDs == catalogIDs {
            return true
        }
        if let pendingCatalogIDs, pendingCatalogIDs == catalogIDs {
            return true
        }
        return false
    }
}

/// 縮小前の対象アプリ選択を退避するストア。App Group の UserDefaults に1レコードで置く。
///
/// `UserDefaults` は `Sendable` ではなく、この型は `AppModel`（MainActor隔離）からのみ触る。
/// 隔離をまたいで渡す用途がないため `Sendable` には準拠しない。
public struct TargetClampBackupStore {
    private enum Key {
        static let record = "targetClampBackupRecord"

        /// 分割キー時代の残骸。未リリースのため移行はせず、掃除だけする。
        static let legacy = [
            "preClampTargetCatalogIDs",
            "preClampTargetClampedCatalogIDs"
        ]
    }

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    public init() throws {
        guard let userDefaults = UserDefaults(suiteName: AppGroup.identifier) else {
            throw CoreError.appGroupUnavailable(AppGroup.identifier)
        }
        self.init(userDefaults: userDefaults)
    }

    public var backup: TargetClampBackup? {
        guard let data = userDefaults.data(forKey: Key.record),
              let record = try? JSONDecoder().decode(TargetClampBackup.self, from: data),
              !record.originalCatalogIDs.isEmpty else {
            return nil
        }
        return record
    }

    /// 縮小の書き込みを始める前に控える。
    ///
    /// すでに控えがあり、いま縮小しようとしている並びがその控えの結果（完了分・書き込み中のどちらか）
    /// と一致するなら、段階的な縮小とみなして**最初の並びを保つ**。
    /// ここで最初の並びを捨てると、2回目の縮小の途中で落ちたとき元の選択が永久に失われる。
    public func beginClamp(originalCatalogIDs: [String], pendingCatalogIDs: [String]) {
        let record: TargetClampBackup
        if let existing = backup, existing.matchesClampResult(originalCatalogIDs) {
            record = TargetClampBackup(
                originalCatalogIDs: existing.originalCatalogIDs,
                appliedCatalogIDs: existing.appliedCatalogIDs,
                pendingCatalogIDs: pendingCatalogIDs
            )
        } else {
            record = TargetClampBackup(
                originalCatalogIDs: originalCatalogIDs,
                appliedCatalogIDs: nil,
                pendingCatalogIDs: pendingCatalogIDs
            )
        }
        write(record)
    }

    /// 縮小の書き込みが完了したら確定させる。
    public func commitClamp(appliedCatalogIDs: [String]) {
        guard let existing = backup else {
            return
        }
        write(
            TargetClampBackup(
                originalCatalogIDs: existing.originalCatalogIDs,
                appliedCatalogIDs: appliedCatalogIDs,
                pendingCatalogIDs: nil
            )
        )
    }

    public func clear() {
        userDefaults.removeObject(forKey: Key.record)
        for key in Key.legacy {
            userDefaults.removeObject(forKey: key)
        }
    }

    private func write(_ record: TargetClampBackup) {
        guard let data = try? JSONEncoder().encode(record) else {
            return
        }
        userDefaults.set(data, forKey: Key.record)
    }
}

/// 対象アプリの選択を、いまのEntitlementへ突き合わせた結果。
public enum TargetClampReconciliation: Equatable, Sendable {
    /// 権利が確定していないため何もしない。
    case skip
    /// 無料枠の上限へ縮小する。
    case clamp
    /// Proが戻ったので控えから復元する。
    case restore(catalogIDs: [String])
    /// 控えが現状と噛み合わないため捨てる。
    case discardBackup
    /// 突き合わせる必要がない。
    case noAction
}

public enum TargetClampPolicy {
    /// 縮小・復元・据え置きのどれを行うかを決める。
    ///
    /// - `hasConfirmedEntitlement` が false のときは必ず `.skip`。
    ///   取得失敗や起動直後の未解決を「無料確定」とみなして選択を削ると、
    ///   課金者から対象アプリを永久に奪うことになる（規則A・監査P0-A③）。
    /// - 復元するのは「いまの選択が縮小直後のまま」のときだけ。
    ///   ユーザーが自分で選び直した後や、全データ削除の後に古い並びを蘇らせない。
    ///   縮小の書き込み前後どちらで落ちていても復元できるよう、控えの完了分と
    ///   書き込み中の結果の両方を「縮小直後」として受理する。
    public static func reconciliation(
        hasConfirmedEntitlement: Bool,
        isPro: Bool,
        selectedCatalogIDs: [String],
        backup: TargetClampBackup?
    ) -> TargetClampReconciliation {
        guard hasConfirmedEntitlement else {
            return .skip
        }
        guard isPro else {
            return .clamp
        }
        guard let backup else {
            return .noAction
        }
        guard backup.matchesClampResult(selectedCatalogIDs) else {
            return .discardBackup
        }
        let restorableCatalogIDs = backup.originalCatalogIDs.filter {
            SNSAppCatalog.contains(catalogID: $0)
        }
        guard !restorableCatalogIDs.isEmpty,
              restorableCatalogIDs != selectedCatalogIDs else {
            return .discardBackup
        }
        return .restore(catalogIDs: restorableCatalogIDs)
    }
}
