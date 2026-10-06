import Foundation
import Darwin

public enum ReinterventionConstants {
    public static let shieldStoreName = "dopabreak.reintervention"
    public static let activityPrefix = "dopabreak.reintervention."
    public static let maximumSessionAge: TimeInterval = 12 * 60 * 60
    public static func activityName(_ catalogID: String) -> String { activityPrefix + catalogID }
    public static var allActivityNames: [String] { SNSAppCatalog.all.map { activityName($0.catalogID) } }
}

public struct ReinterventionSession: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let catalogID: String
    public let selectionData: Data
    public let minutes: Int
    public let startedAt: Date
    public let expiresAt: Date
    public var reflectionID: UUID?
    public var reachedAt: Date?
    public var resumeRequested: Bool
    public var endedEarly: Bool
    public var notificationsEnabled: Bool
    public var blocksAtLimit: Bool?
    public var isBlocking: Bool { blocksAtLimit ?? true }

    public init(catalogID: String, selectionData: Data, minutes: Int, now: Date, notificationsEnabled: Bool = true, blocksAtLimit: Bool = true) {
        id = UUID()
        self.catalogID = catalogID
        self.selectionData = selectionData
        self.minutes = minutes
        startedAt = now
        // DeviceActivity boundaries may be delivered at minute precision. Use the same
        // boundary in persisted state so intervalDidEnd cannot leave a shield behind.
        expiresAt = Date(timeIntervalSince1970: floor((now.timeIntervalSince1970 + ReinterventionConstants.maximumSessionAge) / 60) * 60)
        reflectionID = nil
        reachedAt = nil
        resumeRequested = false
        endedEarly = false
        self.notificationsEnabled = notificationsEnabled
        self.blocksAtLimit = blocksAtLimit
    }

    public func shouldShield(at now: Date) -> Bool {
        isBlocking && reachedAt != nil && !endedEarly && now < expiresAt
    }

    public func acceptsThreshold(eventID: String, now: Date) -> Bool {
        id.uuidString == eventID && reachedAt == nil && now < expiresAt
            && now.timeIntervalSince(startedAt) >= TimeInterval(minutes * 60)
    }
}

public struct ReinterventionState: Codable, Equatable, Sendable {
    public var selections: [String: Data] = [:]
    public var sessions: [String: ReinterventionSession] = [:]
    public init() {}
}

/// One cross-process transaction covers both state changes and shield reconciliation.
/// A stale extension callback must not restore a shield after the app removed it.
public struct ReinterventionStore: Sendable {
    private let snapshots: JSONSnapshotStore
    public init(snapshotStore: JSONSnapshotStore = JSONSnapshotStore()) { snapshots = snapshotStore }

    public func read() throws -> ReinterventionState { try transaction { $0 } }

    @discardableResult
    public func transaction<T>(_ body: (inout ReinterventionState) throws -> T, afterCommit: (ReinterventionState) -> Void = { _ in }) throws -> T {
        let file = try snapshots.url(for: .reintervention)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let fd = open(file.path + ".lock", O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw CoreError.validation(message: "Cannot open re-intervention lock") }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw CoreError.validation(message: "Cannot lock re-intervention state") }
        defer { flock(fd, LOCK_UN) }
        var state = try snapshots.read(ReinterventionState.self, from: .reintervention) ?? .init()
        let original = state
        let result = try body(&state)
        if state != original { try snapshots.write(state, to: .reintervention) }
        afterCommit(state)
        return result
    }
}
