import Darwin
import Foundation

/// 回数上限の控えを、アプリと拡張のあいだで1つの手順として読み書きする。
///
/// 拡張が控えを読んでからシールドへ流すまでのあいだに、アプリが控えを消して解除すると、
/// 拡張が古い内容で張り直してしまう。読み取り・書き換え・シールドへの反映を
/// 同じファイルロックの中で済ませ、後から来た側が必ず最新の控えで決めるようにする
/// （`ReinterventionStore` と同じ考え方）。
public struct DailyOpenLimitStore: Sendable {
    private let snapshots: JSONSnapshotStore

    public init(snapshotStore: JSONSnapshotStore = JSONSnapshotStore()) {
        snapshots = snapshotStore
    }

    public func read() throws -> DailyOpenLimitShieldSnapshot? {
        try transaction { $0 }
    }

    /// - Parameters:
    ///   - body: 控えを書き換える。`nil` にすると控えを消す。
    ///   - afterCommit: 書き終えた控えを受け取る。ロックの中で呼ぶので、シールドへの反映はここで行う。
    @discardableResult
    public func transaction<T>(
        _ body: (inout DailyOpenLimitShieldSnapshot?) throws -> T,
        afterCommit: (DailyOpenLimitShieldSnapshot?) -> Void = { _ in }
    ) throws -> T {
        let file = try snapshots.url(for: .dailyOpenLimitShieldSnapshot)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let fd = open(file.path + ".lock", O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else {
            throw CoreError.validation(message: "Cannot open open-limit lock")
        }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else {
            throw CoreError.validation(message: "Cannot lock open-limit state")
        }
        defer { flock(fd, LOCK_UN) }

        // 壊れた控えは「掛け続ける根拠がない」状態として扱い、消す側へ倒す。
        let original = (try? snapshots.read(
            DailyOpenLimitShieldSnapshot.self,
            from: .dailyOpenLimitShieldSnapshot
        )) ?? nil
        var state = original
        let result = try body(&state)
        if state != original || (state == nil && snapshots.exists(.dailyOpenLimitShieldSnapshot)) {
            if let state {
                try snapshots.write(state, to: .dailyOpenLimitShieldSnapshot)
            } else {
                try snapshots.remove(.dailyOpenLimitShieldSnapshot)
            }
        }
        afterCommit(state)
        return result
    }
}
