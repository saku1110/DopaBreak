import Foundation

public struct GateAppSettingsStore: Sendable {
    private let snapshotStore: JSONSnapshotStore

    public init(snapshotStore: JSONSnapshotStore = JSONSnapshotStore()) {
        self.snapshotStore = snapshotStore
    }

    public func snapshot() throws -> GateAppSettingsSnapshot {
        try snapshotStore.read(
            GateAppSettingsSnapshot.self,
            from: .gateAppSettings
        ) ?? .empty
    }

    public func setting(for tokenData: Data) throws -> GateAppSetting {
        try snapshot().setting(for: tokenData)
    }

    public func save(_ snapshot: GateAppSettingsSnapshot) throws {
        try snapshotStore.write(snapshot, to: .gateAppSettings)
    }

    public func remove() throws {
        try snapshotStore.remove(.gateAppSettings)
    }
}

public struct GateLedgerStore: Sendable {
    private let snapshotStore: JSONSnapshotStore

    public init(snapshotStore: JSONSnapshotStore = JSONSnapshotStore()) {
        self.snapshotStore = snapshotStore
    }

    public func ledger() throws -> GateLedger {
        try snapshotStore.read(GateLedger.self, from: .gateLedger) ?? .empty
    }

    public func save(_ ledger: GateLedger) throws {
        try coordinateWriting {
            try snapshotStore.write(ledger, to: .gateLedger)
        }
    }

    /// 3プロセスからのread-modify-writeを、ファイル調停の単一書き込み区間にまとめる。
    /// JSONSnapshotStoreの一時ファイル＋置換は、この調停ブロックの内側で維持する。
    @discardableResult
    public func update(
        _ mutate: @escaping (inout GateLedger) throws -> Void
    ) throws -> GateLedger {
        try coordinateWriting {
            var ledger = try snapshotStore.read(GateLedger.self, from: .gateLedger) ?? .empty
            try mutate(&ledger)
            try snapshotStore.write(ledger, to: .gateLedger)
            return ledger
        }
    }

    public func remove() throws {
        try coordinateWriting {
            try snapshotStore.remove(.gateLedger)
        }
    }

    private func coordinateWriting<Value>(
        _ operation: @escaping () throws -> Value
    ) throws -> Value {
        try coordinateSnapshotWrite(
            snapshotStore: snapshotStore,
            file: .gateLedger,
            operation
        )
    }
}

/// シールド拡張から本体へ渡す一時要求。台帳とは別ファイルなので、要求投稿が
/// grant/expiry/reconcileの台帳更新を上書きしない。
public struct GateUnlockRequestStore: Sendable {
    private let snapshotStore: JSONSnapshotStore

    public init(snapshotStore: JSONSnapshotStore = JSONSnapshotStore()) {
        self.snapshotStore = snapshotStore
    }

    public func request() throws -> GateUnlockRequest? {
        try snapshotStore.read(GateUnlockRequest.self, from: .gateUnlockRequest)
    }

    public func save(_ request: GateUnlockRequest) throws {
        try coordinateWriting {
            try snapshotStore.write(request, to: .gateUnlockRequest)
        }
    }

    @discardableResult
    public func clear(matching requestID: UUID) throws -> Bool {
        try coordinateWriting {
            guard try request()?.id == requestID else {
                return false
            }
            try snapshotStore.remove(.gateUnlockRequest)
            return true
        }
    }

    @discardableResult
    public func clear(for tokenData: Data) throws -> Bool {
        try coordinateWriting {
            guard try request()?.tokenData == tokenData else {
                return false
            }
            try snapshotStore.remove(.gateUnlockRequest)
            return true
        }
    }

    public func remove() throws {
        try coordinateWriting {
            try snapshotStore.remove(.gateUnlockRequest)
        }
    }

    private func coordinateWriting<Value>(
        _ operation: @escaping () throws -> Value
    ) throws -> Value {
        try coordinateSnapshotWrite(
            snapshotStore: snapshotStore,
            file: .gateUnlockRequest,
            operation
        )
    }
}

private func coordinateSnapshotWrite<Value>(
    snapshotStore: JSONSnapshotStore,
    file: SnapshotFile,
    _ operation: @escaping () throws -> Value
) throws -> Value {
    let fileURL = try snapshotStore.url(for: file)
    let coordinator = NSFileCoordinator(filePresenter: nil)
    var coordinationError: NSError?
    var operationResult: Result<Value, Error>?

    coordinator.coordinate(
        writingItemAt: fileURL,
        options: .forReplacing,
        error: &coordinationError
    ) { _ in
        operationResult = Result { try operation() }
    }

    if let coordinationError {
        throw CoreError.fileSystem(
            operation: "coordinateWrite",
            path: fileURL.path,
            message: coordinationError.localizedDescription
        )
    }
    guard let operationResult else {
        throw CoreError.fileSystem(
            operation: "coordinateWrite",
            path: fileURL.path,
            message: "file coordinator did not invoke the accessor"
        )
    }
    return try operationResult.get()
}

public struct GateShieldSnapshotStore: Sendable {
    private let snapshotStore: JSONSnapshotStore

    public init(snapshotStore: JSONSnapshotStore = JSONSnapshotStore()) {
        self.snapshotStore = snapshotStore
    }

    /// 控えが無いこと自体が「適用してはいけない」の合図なので、既定値ではなくnilを返す。
    public func snapshot() throws -> GateShieldSnapshot? {
        try snapshotStore.read(GateShieldSnapshot.self, from: .gateShieldSnapshot)
    }

    public func save(_ snapshot: GateShieldSnapshot) throws {
        try snapshotStore.write(snapshot, to: .gateShieldSnapshot)
    }

    public func remove() throws {
        try snapshotStore.remove(.gateShieldSnapshot)
    }
}
