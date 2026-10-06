import DeviceActivity
import DopaBreakCore
import FamilyControls
import Foundation

@MainActor
final class ReinterventionScheduler {
    let store: ReinterventionStore
    private let monitoring: any DeepFocusMonitoring
    private let now: () -> Date

    init(store: ReinterventionStore, monitoring: any DeepFocusMonitoring = DeviceActivityCenter(), now: @escaping () -> Date = Date.init) {
        self.store = store
        self.monitoring = monitoring
        self.now = now
    }

    func prepare(catalogID: String, minutes: Int, authorized: Bool, notificationsEnabled: Bool = true, blocksAtLimit: Bool = true) throws -> ReinterventionSession? {
        let state = try store.read()
        guard let selection = state.selections[catalogID] else { return nil }
        guard #available(iOS 17.4, *), authorized,
              [5, 10, 15, 30].contains(minutes), ReinterventionShield.tokens(in: selection).count == 1 else {
            throw ReinterventionError.setup
        }
        // An unfinished budget must not be restarted by another open request.
        if let previous = state.sessions[catalogID], previous.reachedAt == nil, previous.expiresAt > now() {
            throw ReinterventionError.monitoring
        }
        let session = ReinterventionSession(catalogID: catalogID, selectionData: selection, minutes: minutes, now: now(), notificationsEnabled: notificationsEnabled, blocksAtLimit: blocksAtLimit)
        let activity = DeviceActivityName(ReinterventionConstants.activityName(catalogID))
        try store.transaction { $0.sessions[catalogID] = session }
        monitoring.stopMonitoring([activity])
        do {
            let calendar = Calendar.autoupdatingCurrent
            let fields: Set<Calendar.Component> = [.era, .year, .month, .day, .hour, .minute, .second]
            try monitoring.startMonitoring(activity, during: DeviceActivitySchedule(
                intervalStart: calendar.dateComponents(fields, from: session.startedAt),
                intervalEnd: calendar.dateComponents(fields, from: session.expiresAt), repeats: false),
                events: [.init(session.id.uuidString): DeviceActivityEvent(
                    applications: ReinterventionShield.tokens(in: selection), threshold: .init(minute: minutes), includesPastActivity: false)])
        } catch {
            monitoring.stopMonitoring([activity])
            try? store.transaction { $0.sessions[catalogID] = state.sessions[catalogID] }
            ReinterventionShield.sync(store: store, now: now())
            throw ReinterventionError.monitoring
        }
        // Clear only the old re-intervention shield. Sleep/strict block stores are independent.
        ReinterventionShield.sync(store: store, now: now())
        return session
    }

    func attach(reflectionID: UUID, to session: ReinterventionSession) throws {
        try store.transaction {
            guard $0.sessions[session.catalogID]?.id == session.id else { throw ReinterventionError.monitoring }
            $0.sessions[session.catalogID]?.reflectionID = reflectionID
        }
    }

    func finish(catalogID: String, disconnect: Bool = false) throws {
        monitoring.stopMonitoring([.init(ReinterventionConstants.activityName(catalogID))])
        try store.transaction({
            $0.sessions.removeValue(forKey: catalogID)
            if disconnect { $0.selections.removeValue(forKey: catalogID) }
        }, afterCommit: { ReinterventionShield.apply($0, now: now()) })
    }

    func finishEarly(catalogID: String) throws {
        monitoring.stopMonitoring([.init(ReinterventionConstants.activityName(catalogID))])
        try store.transaction({ state in
            guard state.sessions[catalogID] != nil else { return }
            state.sessions[catalogID]?.reachedAt = now()
            state.sessions[catalogID]?.endedEarly = true
        }, afterCommit: { ReinterventionShield.apply($0, now: now()) })
    }

    func reset() throws {
        monitoring.stopMonitoring(ReinterventionConstants.allActivityNames.map { DeviceActivityName($0) })
        try store.transaction({ $0 = .init() }, afterCommit: { ReinterventionShield.apply($0, now: now()) })
    }
}

enum ReinterventionError: LocalizedError {
    case setup, selection, duplicate, monitoring
    var errorDescription: String? {
        switch self {
        case .setup: return String(localized: "reintervention.error.setup", defaultValue: "利用時間の通知・制限にはiOS 17.4以降とスクリーンタイムの許可が必要です。設定を確認してください。")
        case .selection: return String(localized: "reintervention.error.selection", defaultValue: "カテゴリやWebサイトではなく、指定したアプリを1つだけ選んでください。")
        case .duplicate: return String(localized: "reintervention.error.duplicate", defaultValue: "このアプリはすでに別の対象へ接続されています。接続先を確認してください。")
        case .monitoring: return String(localized: "reintervention.error.monitoring", defaultValue: "利用時間の通知・制限を開始できませんでした。もう一度試すか、設定で連携を解除してください。")
        }
    }
}
