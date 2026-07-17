import Foundation

public struct LocalDataResetter {
    private let goalStore: GoalStore
    private let ruleStore: RuleStore
    private let targetStore: InterventionTargetStore
    private let logStore: SQLiteLogStore?
    private let funnelEventStore: FunnelEventStore
    private let settingsStore: SettingsStore
    private let snapshotStore: JSONSnapshotStore
    private let interventionEngine: InterventionEngine?
    private let containerProvider: any ContainerProviding

    public init(
        goalStore: GoalStore,
        ruleStore: RuleStore,
        targetStore: InterventionTargetStore,
        logStore: SQLiteLogStore?,
        funnelEventStore: FunnelEventStore,
        settingsStore: SettingsStore,
        snapshotStore: JSONSnapshotStore,
        interventionEngine: InterventionEngine?,
        containerProvider: any ContainerProviding = AppGroupContainer()
    ) {
        self.goalStore = goalStore
        self.ruleStore = ruleStore
        self.targetStore = targetStore
        self.logStore = logStore
        self.funnelEventStore = funnelEventStore
        self.settingsStore = settingsStore
        self.snapshotStore = snapshotStore
        self.interventionEngine = interventionEngine
        self.containerProvider = containerProvider
    }

    public func deleteAllLocalData() throws {
        var successfulOperationCount = 0
        var firstError: Error?

        func attempt(_ operation: () throws -> Void) {
            do {
                try operation()
                successfulOperationCount += 1
            } catch {
                if firstError == nil {
                    firstError = error
                }
            }
        }

        if let interventionEngine {
            attempt { try interventionEngine.resetToIdle() }
        }
        attempt { try goalStore.deleteAll() }
        attempt { try ruleStore.deleteAll() }
        attempt { try targetStore.deleteAll() }

        var clearedLogsThroughStore = false
        if let logStore {
            do {
                try logStore.deleteAllLogs()
                successfulOperationCount += 1
                clearedLogsThroughStore = true
            } catch {
                firstError = firstError ?? error
            }
        }
        if !clearedLogsThroughStore {
            removeSQLiteDatabaseFiles(attempt: attempt)
        }

        attempt { try funnelEventStore.deleteAll() }
        attempt { try snapshotStore.remove(.interventionState) }
        attempt { try snapshotStore.remove(.selfCheckSnapshot) }
        attempt { try snapshotStore.remove(.widgetSnapshot) }
        attempt { try snapshotStore.remove(.lockSurfaceState) }

        settingsStore.resetToDefaults()
        successfulOperationCount += 1

        guard successfulOperationCount > 0 else {
            throw firstError ?? CoreError.fileSystem(
                operation: "deleteAllLocalData",
                path: "local stores",
                message: "no local data store could be cleared"
            )
        }
    }

    private func removeSQLiteDatabaseFiles(attempt: (() throws -> Void) -> Void) {
        let containerURL: URL
        do {
            containerURL = try containerProvider.containerURL()
        } catch {
            attempt { throw error }
            return
        }

        let sidecarSuffixes = ["", "-wal", "-shm", "-journal"]
        for fileName in SQLiteLogStore.databaseFileNames {
            for suffix in sidecarSuffixes {
                let fileURL = containerURL.appendingPathComponent(fileName + suffix)
                attempt {
                    guard FileManager.default.fileExists(atPath: fileURL.path) else {
                        return
                    }
                    try FileManager.default.removeItem(at: fileURL)
                }
            }
        }
    }
}
