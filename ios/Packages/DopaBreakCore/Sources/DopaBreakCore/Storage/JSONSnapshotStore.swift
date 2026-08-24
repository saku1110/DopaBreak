import Foundation

public enum SnapshotFile: String, Codable, Equatable, Sendable, CaseIterable {
    case goals = "goals.json"
    case rules = "rules.json"
    case widgetSnapshot = "widget_snapshot.json"
    case lockSurfaceState = "lock_surface_state.json"
    case interventionState = "intervention_state.json"
    case selfCheckSnapshot = "self_check_snapshot.json"
    case interventionTargets = "intervention_targets.json"
    case funnelEvents = "funnel_events.json"
    case nightShieldSnapshot = "night_shield_snapshot.json"
    case deepFocusShieldSnapshot = "deepfocus_shield_snapshot.json"
    case gateAppSettings = "gate_app_settings.json"
    case gateLedger = "gate_ledger.json"
    case gateShieldSnapshot = "gate_shield_snapshot.json"
    case gateUnlockRequest = "gate_unlock_request.json"
}

public struct JSONSnapshotStore: Sendable {
    private let containerProvider: any ContainerProviding

    public init(containerProvider: any ContainerProviding = AppGroupContainer()) {
        self.containerProvider = containerProvider
    }

    public func url(for file: SnapshotFile) throws -> URL {
        try containerProvider.containerURL().appendingPathComponent(file.rawValue)
    }

    /// ファイルが今この瞬間あるか。
    ///
    /// 読んでから適用するまでの間に消える場合があるため、適用の直前にもう一度これで確かめる。
    /// 権利を落とした側は「監視停止→控え削除」の順で後始末をしていて、
    /// 控えが消えていることは「もう適用してはいけない」の合図になる。
    public func exists(_ file: SnapshotFile) -> Bool {
        guard let fileURL = try? url(for: file) else {
            return false
        }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    public func read<Value: Decodable>(
        _ type: Value.Type,
        from file: SnapshotFile
    ) throws -> Value? {
        let fileURL = try url(for: file)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try Self.decoder.decode(Value.self, from: data)
        } catch let error as DecodingError {
            throw CoreError.corruptedSnapshot(file: file.rawValue, message: "\(error)")
        } catch {
            throw CoreError.fileSystem(
                operation: "read",
                path: fileURL.path,
                message: "\(error)"
            )
        }
    }

    public func write<Value: Encodable>(_ value: Value, to file: SnapshotFile) throws {
        let fileURL = try url(for: file)
        let directoryURL = fileURL.deletingLastPathComponent()
        let tempURL = directoryURL.appendingPathComponent(".\(file.rawValue).\(UUID()).tmp")

        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            let data = try Self.encoder.encode(value)
            try data.write(to: tempURL, options: [])
            try applyFileProtectionIfNeeded(to: tempURL)
            try replaceOrMoveItem(from: tempURL, to: fileURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw CoreError.fileSystem(
                operation: "atomicWrite",
                path: fileURL.path,
                message: "\(error)"
            )
        }
    }

    public func remove(_ file: SnapshotFile) throws {
        let fileURL = try url(for: file)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            throw CoreError.fileSystem(
                operation: "remove",
                path: fileURL.path,
                message: "\(error)"
            )
        }
    }

    private func replaceOrMoveItem(from tempURL: URL, to fileURL: URL) throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(
                fileURL,
                withItemAt: tempURL,
                backupItemName: nil,
                options: []
            )
        } else {
            try FileManager.default.moveItem(at: tempURL, to: fileURL)
        }
    }

    private func applyFileProtectionIfNeeded(to url: URL) throws {
        #if os(iOS)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        #else
        _ = url
        #endif
    }

    // 日付はミリ秒精度のISO8601で保存する。標準の .iso8601 は小数秒を落とし
    // Date() の往復が不正確になるため（レビュー指摘 2026-07-02）。
    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plainFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(fractionalFormatter.string(from: date))
        }
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = fractionalFormatter.date(from: string) ?? plainFormatter.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(string)"
            )
        }
        return decoder
    }()
}
