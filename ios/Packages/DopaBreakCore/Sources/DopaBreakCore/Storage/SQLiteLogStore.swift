import Foundation
import SQLite3

public final class SQLiteLogStore: @unchecked Sendable {
    private let attemptDatabase: SQLiteDatabase
    private let reflectionDatabase: SQLiteDatabase

    public init(containerProvider: any ContainerProviding = AppGroupContainer()) throws {
        let containerURL = try containerProvider.containerURL()
        try FileManager.default.createDirectory(
            at: containerURL,
            withIntermediateDirectories: true
        )
        self.attemptDatabase = try SQLiteDatabase(
            url: containerURL.appendingPathComponent("attempt_logs.sqlite"),
            schema: .attemptLogs
        )
        self.reflectionDatabase = try SQLiteDatabase(
            url: containerURL.appendingPathComponent("reflection_logs.sqlite"),
            schema: .reflectionLogs
        )
    }

    public func insert(_ log: AttemptLog) throws {
        try attemptDatabase.perform { db in
            let sql = """
            INSERT INTO attempt_logs
            (id, rule_id, started_at, completed_at, decision, intent,
             selected_duration_seconds, attempt_count24h, opened)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            let statement = try prepare(db, sql)
            defer { sqlite3_finalize(statement) }
            try bindAttempt(log, to: statement, db: db)
            try stepDone(statement, db: db, sql: sql)
        }
    }

    public func fetchAttempts(from start: Date? = nil, to end: Date? = nil) throws -> [AttemptLog] {
        try attemptDatabase.perform { db in
            let query = rangeQuery(
                table: "attempt_logs",
                columns: attemptColumns,
                dateColumn: "started_at",
                start: start,
                end: end
            )
            let statement = try prepare(db, query.sql)
            defer { sqlite3_finalize(statement) }
            try bindRange(query.values, to: statement, db: db)
            return try fetchRows(statement, db: db, sql: query.sql, decode: decodeAttempt)
        }
    }

    public func attemptCount(onDay day: Date, calendar: Calendar) throws -> Int {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return 0
        }
        return try countAttempts(from: start, to: end)
    }

    public func insert(_ log: ReflectionLog) throws {
        try reflectionDatabase.perform { db in
            let sql = """
            INSERT INTO reflection_logs
            (id, attempt_log_id, rule_id, prompted_at, answered_at, trigger,
             satisfaction, happiness_delta, skipped, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            let statement = try prepare(db, sql)
            defer { sqlite3_finalize(statement) }
            try bindReflection(log, to: statement, db: db)
            try stepDone(statement, db: db, sql: sql)
        }
    }

    public func updateAnswers(
        reflectionID: UUID,
        satisfaction: PostUseSatisfaction,
        happinessDelta: HappinessDelta,
        answeredAt: Date
    ) throws {
        try reflectionDatabase.perform { db in
            let sql = """
            UPDATE reflection_logs
            SET satisfaction = ?, happiness_delta = ?, answered_at = ?, skipped = 0
            WHERE id = ?
            """
            let statement = try prepare(db, sql)
            defer { sqlite3_finalize(statement) }
            try bindText(satisfaction.rawValue, to: statement, at: 1, db: db, sql: sql)
            try bindText(happinessDelta.rawValue, to: statement, at: 2, db: db, sql: sql)
            try bindDate(answeredAt, to: statement, at: 3, db: db, sql: sql)
            try bindText(reflectionID.uuidString, to: statement, at: 4, db: db, sql: sql)
            try stepDone(statement, db: db, sql: sql)
        }
    }

    public func fetchUnansweredReflections(limit: Int) throws -> [ReflectionLog] {
        try reflectionDatabase.perform { db in
            let sql = """
            SELECT \(reflectionColumns)
            FROM reflection_logs
            WHERE answered_at IS NULL AND skipped = 0
            ORDER BY prompted_at ASC
            LIMIT ?
            """
            let statement = try prepare(db, sql)
            defer { sqlite3_finalize(statement) }
            try bindInt(max(limit, 0), to: statement, at: 1, db: db, sql: sql)
            return try fetchRows(statement, db: db, sql: sql, decode: decodeReflection)
        }
    }

    public func fetchReflections(from start: Date? = nil, to end: Date? = nil) throws -> [ReflectionLog] {
        try reflectionDatabase.perform { db in
            let query = rangeQuery(
                table: "reflection_logs",
                columns: reflectionColumns,
                dateColumn: "prompted_at",
                start: start,
                end: end
            )
            let statement = try prepare(db, query.sql)
            defer { sqlite3_finalize(statement) }
            try bindRange(query.values, to: statement, db: db)
            return try fetchRows(statement, db: db, sql: query.sql, decode: decodeReflection)
        }
    }

    public func deleteAllLogs() throws {
        try attemptDatabase.perform { db in
            try execute(db, "DELETE FROM attempt_logs")
        }
        try reflectionDatabase.perform { db in
            try execute(db, "DELETE FROM reflection_logs")
        }
    }

    private func countAttempts(from start: Date, to end: Date) throws -> Int {
        try attemptDatabase.perform { db in
            let sql = """
            SELECT COUNT(*)
            FROM attempt_logs
            WHERE started_at >= ? AND started_at < ?
            """
            let statement = try prepare(db, sql)
            defer { sqlite3_finalize(statement) }
            try bindDate(start, to: statement, at: 1, db: db, sql: sql)
            try bindDate(end, to: statement, at: 2, db: db, sql: sql)
            return try fetchCount(statement, db: db, sql: sql)
        }
    }
}

private let attemptColumns = """
id, rule_id, started_at, completed_at, decision, intent,
selected_duration_seconds, attempt_count24h, opened
"""

private let reflectionColumns = """
id, attempt_log_id, rule_id, prompted_at, answered_at, trigger,
satisfaction, happiness_delta, skipped, created_at
"""

private enum SQLiteSchema {
    case attemptLogs
    case reflectionLogs

    var version: Int { 1 }

    var createSQL: String {
        switch self {
        case .attemptLogs:
            return """
            CREATE TABLE IF NOT EXISTS attempt_logs (
                id TEXT PRIMARY KEY NOT NULL,
                rule_id TEXT NOT NULL,
                started_at REAL NOT NULL,
                completed_at REAL,
                decision TEXT NOT NULL,
                intent TEXT,
                selected_duration_seconds INTEGER,
                attempt_count24h INTEGER NOT NULL,
                opened INTEGER NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_attempt_logs_started_at
            ON attempt_logs(started_at);
            """
        case .reflectionLogs:
            return """
            CREATE TABLE IF NOT EXISTS reflection_logs (
                id TEXT PRIMARY KEY NOT NULL,
                attempt_log_id TEXT,
                rule_id TEXT NOT NULL,
                prompted_at REAL NOT NULL,
                answered_at REAL,
                trigger TEXT NOT NULL,
                satisfaction TEXT,
                happiness_delta TEXT,
                skipped INTEGER NOT NULL,
                created_at REAL NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_reflection_logs_prompted_at
            ON reflection_logs(prompted_at);
            CREATE INDEX IF NOT EXISTS idx_reflection_logs_answered_at
            ON reflection_logs(answered_at);
            """
        }
    }
}

private final class SQLiteDatabase: @unchecked Sendable {
    private let lock = NSLock()
    private let url: URL
    private var db: OpaquePointer?

    init(url: URL, schema: SQLiteSchema) throws {
        self.url = url
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(url.path, &handle, flags, nil)
        guard result == SQLITE_OK, let opened = handle else {
            let message = sqliteMessage(handle)
            if let handle {
                sqlite3_close(handle)
            }
            throw CoreError.sqliteOpen(path: url.path, message: message)
        }

        self.db = opened
        try execute(opened, "PRAGMA busy_timeout = 3000")
        try execute(opened, "PRAGMA journal_mode = WAL")
        try migrate(schema: schema)
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func perform<Value>(_ body: (OpaquePointer) throws -> Value) throws -> Value {
        lock.lock()
        defer { lock.unlock() }
        guard let db else {
            throw CoreError.sqliteOpen(path: url.path, message: "database is closed")
        }
        return try body(db)
    }

    private func migrate(schema: SQLiteSchema) throws {
        guard let db else {
            throw CoreError.sqliteOpen(path: url.path, message: "database is closed")
        }
        let currentVersion = try userVersion(db)
        guard currentVersion < schema.version else {
            return
        }
        try execute(db, "BEGIN IMMEDIATE")
        do {
            try execute(db, schema.createSQL)
            try execute(db, "PRAGMA user_version = \(schema.version)")
            try execute(db, "COMMIT")
        } catch {
            try? execute(db, "ROLLBACK")
            throw error
        }
    }
}

private func bindAttempt(_ log: AttemptLog, to statement: OpaquePointer, db: OpaquePointer) throws {
    let sql = "INSERT attempt log"
    try bindText(log.id.uuidString, to: statement, at: 1, db: db, sql: sql)
    try bindText(log.ruleId.uuidString, to: statement, at: 2, db: db, sql: sql)
    try bindDate(log.startedAt, to: statement, at: 3, db: db, sql: sql)
    try bindOptionalDate(log.completedAt, to: statement, at: 4, db: db, sql: sql)
    try bindText(log.decision.rawValue, to: statement, at: 5, db: db, sql: sql)
    try bindOptionalText(log.intent?.rawValue, to: statement, at: 6, db: db, sql: sql)
    try bindOptionalInt(log.selectedDurationSeconds, to: statement, at: 7, db: db, sql: sql)
    try bindInt(log.attemptCount24h, to: statement, at: 8, db: db, sql: sql)
    try bindBool(log.opened, to: statement, at: 9, db: db, sql: sql)
}

private func bindReflection(_ log: ReflectionLog, to statement: OpaquePointer, db: OpaquePointer) throws {
    let sql = "INSERT reflection log"
    try bindText(log.id.uuidString, to: statement, at: 1, db: db, sql: sql)
    try bindOptionalText(log.attemptLogId?.uuidString, to: statement, at: 2, db: db, sql: sql)
    try bindText(log.ruleId.uuidString, to: statement, at: 3, db: db, sql: sql)
    try bindDate(log.promptedAt, to: statement, at: 4, db: db, sql: sql)
    try bindOptionalDate(log.answeredAt, to: statement, at: 5, db: db, sql: sql)
    try bindText(log.trigger.rawValue, to: statement, at: 6, db: db, sql: sql)
    try bindOptionalText(log.satisfaction?.rawValue, to: statement, at: 7, db: db, sql: sql)
    try bindOptionalText(log.happinessDelta?.rawValue, to: statement, at: 8, db: db, sql: sql)
    try bindBool(log.skipped, to: statement, at: 9, db: db, sql: sql)
    try bindDate(log.createdAt, to: statement, at: 10, db: db, sql: sql)
}

private func decodeAttempt(_ statement: OpaquePointer) throws -> AttemptLog {
    let decisionText = try requiredText(statement, 4, column: "decision")
    guard let decision = Decision(rawValue: decisionText) else {
        throw CoreError.sqliteDecoding(column: "decision", value: decisionText)
    }
    let intent = try optionalEnum(IntentCategory.self, statement, 5, column: "intent")
    return AttemptLog(
        id: try uuid(statement, 0, column: "id"),
        ruleId: try uuid(statement, 1, column: "rule_id"),
        startedAt: date(statement, 2),
        completedAt: optionalDate(statement, 3),
        decision: decision,
        intent: intent,
        selectedDurationSeconds: optionalInt(statement, 6),
        attemptCount24h: int(statement, 7),
        opened: bool(statement, 8)
    )
}

private func decodeReflection(_ statement: OpaquePointer) throws -> ReflectionLog {
    let triggerText = try requiredText(statement, 5, column: "trigger")
    guard let trigger = ReflectionTrigger(rawValue: triggerText) else {
        throw CoreError.sqliteDecoding(column: "trigger", value: triggerText)
    }
    return ReflectionLog(
        id: try uuid(statement, 0, column: "id"),
        attemptLogId: try optionalUUID(statement, 1, column: "attempt_log_id"),
        ruleId: try uuid(statement, 2, column: "rule_id"),
        promptedAt: date(statement, 3),
        answeredAt: optionalDate(statement, 4),
        trigger: trigger,
        satisfaction: try optionalEnum(PostUseSatisfaction.self, statement, 6, column: "satisfaction"),
        happinessDelta: try optionalEnum(HappinessDelta.self, statement, 7, column: "happiness_delta"),
        skipped: bool(statement, 8),
        createdAt: date(statement, 9)
    )
}

private func rangeQuery(
    table: String,
    columns: String,
    dateColumn: String,
    start: Date?,
    end: Date?
) -> (sql: String, values: [Date]) {
    var clauses: [String] = []
    var values: [Date] = []
    if let start {
        clauses.append("\(dateColumn) >= ?")
        values.append(start)
    }
    if let end {
        clauses.append("\(dateColumn) < ?")
        values.append(end)
    }
    let whereClause = clauses.isEmpty ? "" : " WHERE \(clauses.joined(separator: " AND "))"
    let sql = "SELECT \(columns) FROM \(table)\(whereClause) ORDER BY \(dateColumn) ASC"
    return (sql, values)
}

private func bindRange(_ values: [Date], to statement: OpaquePointer, db: OpaquePointer) throws {
    for (index, value) in values.enumerated() {
        try bindDate(value, to: statement, at: Int32(index + 1), db: db, sql: "range query")
    }
}

private func fetchRows<Value>(
    _ statement: OpaquePointer,
    db: OpaquePointer,
    sql: String,
    decode: (OpaquePointer) throws -> Value
) throws -> [Value] {
    var values: [Value] = []
    while true {
        let result = sqlite3_step(statement)
        if result == SQLITE_ROW {
            values.append(try decode(statement))
        } else if result == SQLITE_DONE {
            return values
        } else {
            throw CoreError.sqliteExecution(statement: sql, message: sqliteMessage(db))
        }
    }
}

private func fetchCount(_ statement: OpaquePointer, db: OpaquePointer, sql: String) throws -> Int {
    let result = sqlite3_step(statement)
    guard result == SQLITE_ROW else {
        throw CoreError.sqliteExecution(statement: sql, message: sqliteMessage(db))
    }
    return Int(sqlite3_column_int64(statement, 0))
}

private func userVersion(_ db: OpaquePointer) throws -> Int {
    let sql = "PRAGMA user_version"
    let statement = try prepare(db, sql)
    defer { sqlite3_finalize(statement) }
    return try fetchCount(statement, db: db, sql: sql)
}

private func prepare(_ db: OpaquePointer, _ sql: String) throws -> OpaquePointer {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
        throw CoreError.sqliteExecution(statement: sql, message: sqliteMessage(db))
    }
    return statement
}

private func execute(_ db: OpaquePointer, _ sql: String) throws {
    var errorMessage: UnsafeMutablePointer<CChar>?
    let result = sqlite3_exec(db, sql, nil, nil, &errorMessage)
    guard result == SQLITE_OK else {
        let message = errorMessage.map { String(cString: $0) } ?? sqliteMessage(db)
        sqlite3_free(errorMessage)
        throw CoreError.sqliteExecution(statement: sql, message: message)
    }
}

private func stepDone(_ statement: OpaquePointer, db: OpaquePointer, sql: String) throws {
    guard sqlite3_step(statement) == SQLITE_DONE else {
        throw CoreError.sqliteExecution(statement: sql, message: sqliteMessage(db))
    }
}

private func bindText(
    _ value: String,
    to statement: OpaquePointer,
    at index: Int32,
    db: OpaquePointer,
    sql: String
) throws {
    let result = value.withCString {
        sqlite3_bind_text(statement, index, $0, -1, sqliteTransient)
    }
    try checkBind(result, db: db, sql: sql)
}

private func bindOptionalText(
    _ value: String?,
    to statement: OpaquePointer,
    at index: Int32,
    db: OpaquePointer,
    sql: String
) throws {
    guard let value else {
        try checkBind(sqlite3_bind_null(statement, index), db: db, sql: sql)
        return
    }
    try bindText(value, to: statement, at: index, db: db, sql: sql)
}

private func bindDate(
    _ value: Date,
    to statement: OpaquePointer,
    at index: Int32,
    db: OpaquePointer,
    sql: String
) throws {
    try checkBind(
        sqlite3_bind_double(statement, index, value.timeIntervalSince1970),
        db: db,
        sql: sql
    )
}

private func bindOptionalDate(
    _ value: Date?,
    to statement: OpaquePointer,
    at index: Int32,
    db: OpaquePointer,
    sql: String
) throws {
    guard let value else {
        try checkBind(sqlite3_bind_null(statement, index), db: db, sql: sql)
        return
    }
    try bindDate(value, to: statement, at: index, db: db, sql: sql)
}

private func bindInt(
    _ value: Int,
    to statement: OpaquePointer,
    at index: Int32,
    db: OpaquePointer,
    sql: String
) throws {
    try checkBind(sqlite3_bind_int64(statement, index, sqlite3_int64(value)), db: db, sql: sql)
}

private func bindOptionalInt(
    _ value: Int?,
    to statement: OpaquePointer,
    at index: Int32,
    db: OpaquePointer,
    sql: String
) throws {
    guard let value else {
        try checkBind(sqlite3_bind_null(statement, index), db: db, sql: sql)
        return
    }
    try bindInt(value, to: statement, at: index, db: db, sql: sql)
}

private func bindBool(
    _ value: Bool,
    to statement: OpaquePointer,
    at index: Int32,
    db: OpaquePointer,
    sql: String
) throws {
    try bindInt(value ? 1 : 0, to: statement, at: index, db: db, sql: sql)
}

private func checkBind(_ result: Int32, db: OpaquePointer, sql: String) throws {
    guard result == SQLITE_OK else {
        throw CoreError.sqliteExecution(statement: sql, message: sqliteMessage(db))
    }
}

private func requiredText(_ statement: OpaquePointer, _ index: Int32, column: String) throws -> String {
    guard let value = optionalText(statement, index) else {
        throw CoreError.sqliteDecoding(column: column, value: "NULL")
    }
    return value
}

private func optionalText(_ statement: OpaquePointer, _ index: Int32) -> String? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL,
          let pointer = sqlite3_column_text(statement, index) else {
        return nil
    }
    let cString = UnsafeRawPointer(pointer).assumingMemoryBound(to: CChar.self)
    return String(cString: cString)
}

private func uuid(_ statement: OpaquePointer, _ index: Int32, column: String) throws -> UUID {
    let value = try requiredText(statement, index, column: column)
    guard let uuid = UUID(uuidString: value) else {
        throw CoreError.sqliteDecoding(column: column, value: value)
    }
    return uuid
}

private func optionalUUID(_ statement: OpaquePointer, _ index: Int32, column: String) throws -> UUID? {
    guard let value = optionalText(statement, index) else {
        return nil
    }
    guard let uuid = UUID(uuidString: value) else {
        throw CoreError.sqliteDecoding(column: column, value: value)
    }
    return uuid
}

private func optionalEnum<Value: RawRepresentable>(
    _ type: Value.Type,
    _ statement: OpaquePointer,
    _ index: Int32,
    column: String
) throws -> Value? where Value.RawValue == String {
    guard let value = optionalText(statement, index) else {
        return nil
    }
    guard let decoded = Value(rawValue: value) else {
        throw CoreError.sqliteDecoding(column: column, value: value)
    }
    return decoded
}

private func date(_ statement: OpaquePointer, _ index: Int32) -> Date {
    Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
}

private func optionalDate(_ statement: OpaquePointer, _ index: Int32) -> Date? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
        return nil
    }
    return date(statement, index)
}

private func int(_ statement: OpaquePointer, _ index: Int32) -> Int {
    Int(sqlite3_column_int64(statement, index))
}

private func optionalInt(_ statement: OpaquePointer, _ index: Int32) -> Int? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
        return nil
    }
    return int(statement, index)
}

private func bool(_ statement: OpaquePointer, _ index: Int32) -> Bool {
    int(statement, index) != 0
}

private func sqliteMessage(_ db: OpaquePointer?) -> String {
    guard let db else {
        return "unknown sqlite error"
    }
    return String(cString: sqlite3_errmsg(db))
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
