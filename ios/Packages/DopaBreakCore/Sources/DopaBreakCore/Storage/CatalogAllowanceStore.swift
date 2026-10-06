import Foundation

/// カタログ経由で宣言した利用時間だけを保持する許可ストア。
/// 通常介入の状態機械とは分離し、同じApp Groupを使う本体プロセス間で共有する。
public final class CatalogAllowanceStore: @unchecked Sendable {
    private enum Key {
        static let allowances = "catalogAllowances"
    }

    private let userDefaults: UserDefaults
    private let lock = NSLock()

    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    public convenience init() throws {
        guard let userDefaults = UserDefaults(suiteName: AppGroup.identifier) else {
            throw CoreError.appGroupUnavailable(AppGroup.identifier)
        }
        self.init(userDefaults: userDefaults)
    }

    public func grant(catalogID: String, until: Date) {
        guard SNSAppCatalog.contains(catalogID: catalogID) else { return }
        lock.withLock {
            var allowances = storedAllowances()
            allowances[catalogID] = until
            userDefaults.set(allowances, forKey: Key.allowances)
        }
    }

    public func activeAllowance(catalogID: String, at now: Date) -> Date? {
        lock.withLock {
            guard let until = storedAllowances()[catalogID], until > now else {
                return nil
            }
            return until
        }
    }

    public func revoke(catalogID: String) {
        lock.withLock {
            var allowances = storedAllowances()
            guard allowances.removeValue(forKey: catalogID) != nil else { return }
            persist(allowances)
        }
    }

    public func purgeExpired(at now: Date) {
        lock.withLock {
            let allowances = storedAllowances()
            let active = allowances.filter { $0.value > now }
            guard active.count != allowances.count else { return }
            persist(active)
        }
    }

    private func storedAllowances() -> [String: Date] {
        userDefaults.dictionary(forKey: Key.allowances)?.compactMapValues { $0 as? Date } ?? [:]
    }

    private func persist(_ allowances: [String: Date]) {
        if allowances.isEmpty {
            userDefaults.removeObject(forKey: Key.allowances)
        } else {
            userDefaults.set(allowances, forKey: Key.allowances)
        }
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
