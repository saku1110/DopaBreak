import Foundation
import SQLite3

/// リフレクションを「スキップ済み」に更新する専用の短命 SQLite 接続。
///
/// `SQLiteLogStore` はスキップ用の公開ミューテーションを持たず、その接続・パスは
/// file-private のため別ファイルの拡張からは触れない。そこで同じ App Group DB へ
/// 2 本目の READWRITE 接続を開いて `skipped = 1` を書き込む。
/// これは安全: 本体ストアは WAL + FULLMUTEX で動作し、複数接続の同時利用を
/// 前提に設計されている（SQLiteLogStore の並行テストが実証済み）。
/// 本体アプリと Shield Extension は別プロセスから同じ DB を読むため、
/// スキップはメモリ内ではなく DB に永続する必要がある。
enum ReflectionSkipWriter {
    /// 指定リフレクションを未回答かつ未スキップのときだけ `skipped = 1` に更新する。
    /// 実際に 1 行変更したら true を返す（既に回答/スキップ済み・不明IDなら false）。
    /// 呼び出し側は true のときだけ状態遷移を確定させることで、誤った idle 化を防ぐ。
    static func markSkipped(reflectionID: UUID, databaseURL: URL) throws -> Bool {
        var handle: OpaquePointer?
        // CREATE はしない: パスが誤っていれば空DBを作らずに開けず失敗させる（安全側）。
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &handle, flags, nil) == SQLITE_OK, let db = handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unable to open database"
            if let handle {
                sqlite3_close(handle)
            }
            throw CoreError.sqliteOpen(path: databaseURL.path, message: message)
        }
        defer { sqlite3_close(db) }
        _ = sqlite3_exec(db, "PRAGMA busy_timeout = 3000", nil, nil, nil)

        // 回答済み/スキップ済みの行は対象外（誤った上書き・状態遷移を防ぐ）。
        let sql = "UPDATE reflection_logs SET skipped = 1 WHERE id = ? AND answered_at IS NULL AND skipped = 0"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let stmt = statement else {
            throw CoreError.sqliteExecution(statement: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let bindResult = reflectionID.uuidString.withCString {
            sqlite3_bind_text(stmt, 1, $0, -1, transient)
        }
        guard bindResult == SQLITE_OK else {
            throw CoreError.sqliteExecution(statement: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw CoreError.sqliteExecution(statement: sql, message: String(cString: sqlite3_errmsg(db)))
        }
        return sqlite3_changes(db) == 1
    }
}
