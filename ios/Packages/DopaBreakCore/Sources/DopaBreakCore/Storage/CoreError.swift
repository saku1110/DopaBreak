import Foundation

public enum CoreError: Error, Equatable, Sendable {
    case appGroupUnavailable(String)
    case corruptedSnapshot(file: String, message: String)
    case fileSystem(operation: String, path: String, message: String)
    case sqliteOpen(path: String, message: String)
    case sqliteExecution(statement: String, message: String)
    case sqliteDecoding(column: String, value: String)
    case validation(message: String)
}

extension CoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .appGroupUnavailable(identifier):
            return "App Group container is unavailable: \(identifier)"
        case let .corruptedSnapshot(file, message):
            return "Snapshot file is corrupted: \(file) (\(message))"
        case let .fileSystem(operation, path, message):
            return "File system \(operation) failed at \(path): \(message)"
        case let .sqliteOpen(path, message):
            return "SQLite open failed at \(path): \(message)"
        case let .sqliteExecution(statement, message):
            return "SQLite statement failed: \(statement) (\(message))"
        case let .sqliteDecoding(column, value):
            return "SQLite value could not be decoded for \(column): \(value)"
        case let .validation(message):
            return message
        }
    }
}
