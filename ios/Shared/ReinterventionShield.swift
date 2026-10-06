import DeviceActivity
import DopaBreakCore
import FamilyControls
import Foundation
import ManagedSettings

enum ReinterventionShield {
    /// カタログIDとScreen Timeの匿名トークンは本体で照合できないため、
    /// アプリを止めるハードブロックの窓では通常介入を休止する。
    /// 保存済みの予定だけでは止めず、拡張と同じ控え・現在時刻から判断する。
    static func suppressesIntervention(
        snapshotStore: JSONSnapshotStore = .init(),
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        func blocksApplications(_ data: Data) -> Bool {
            guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
                return false
            }
            return !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
        }
        if let deep = try? snapshotStore.read(DeepFocusShieldSnapshot.self, from: .deepFocusShieldSnapshot),
           DeepFocusWindowPolicy.selectionDataListToShield(now: now, snapshot: deep, calendar: calendar)
            .contains(where: blocksApplications) { return true }
        if let night = try? snapshotStore.read(NightShieldSnapshot.self, from: .nightShieldSnapshot),
           NightWindowPolicy.isNight(now: now, snapshot: night, calendar: calendar),
           night.selectionDataList.contains(where: blocksApplications) { return true }
        return false
    }

    static func tokens(in data: Data) -> Set<ApplicationToken> {
        (try? JSONDecoder().decode(FamilyActivitySelection.self, from: data).applicationTokens) ?? []
    }

    static func apply(_ state: ReinterventionState, now: Date) {
        let store = ManagedSettingsStore(named: .init(ReinterventionConstants.shieldStoreName))
        let applicationTokens = state.sessions.values.filter { $0.shouldShield(at: now) }
            .reduce(into: Set<ApplicationToken>()) { $0.formUnion(tokens(in: $1.selectionData)) }
        store.shield.applications = applicationTokens.isEmpty ? nil : applicationTokens
    }

    static func sync(store: ReinterventionStore = .init(), now: Date = Date()) {
        do { try store.transaction({ _ in }, afterCommit: { apply($0, now: now) }) }
        catch { ManagedSettingsStore(named: .init(ReinterventionConstants.shieldStoreName)).clearAllSettings() }
    }

    private static func hardSelection(_ data: Data, contains token: ApplicationToken) -> Bool {
        guard let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return false }
        return selection.applicationTokens.contains(token) || !selection.categoryTokens.isEmpty
    }

    /// 夜・予定・手動・回数上限のどれかで、このアプリを完全ブロックしているか。
    /// 完全ブロック中は、利用時間の区切り（再介入）の表示と導線を出さない。
    static func hasHardBlock(for token: ApplicationToken, now: Date = Date()) -> Bool {
        hasWindowBlock(for: token, now: now) || DailyOpenLimitShield.isBlocking(application: token, now: now)
    }

    /// 夜・予定・手動の時間の窓で、このアプリを完全ブロックしているか（回数上限を除く）。
    static func hasWindowBlock(for token: ApplicationToken, now: Date = Date()) -> Bool {
        let snapshots = JSONSnapshotStore()
        if let deep = try? snapshots.read(DeepFocusShieldSnapshot.self, from: .deepFocusShieldSnapshot),
           DeepFocusWindowPolicy.selectionDataListToShield(now: now, snapshot: deep, calendar: .autoupdatingCurrent)
            .contains(where: { hardSelection($0, contains: token) }) { return true }
        if let night = try? snapshots.read(NightShieldSnapshot.self, from: .nightShieldSnapshot),
           NightWindowPolicy.isNight(now: now, snapshot: night, calendar: .autoupdatingCurrent),
           night.selectionDataList.contains(where: { hardSelection($0, contains: token) }) { return true }
        return false
    }

    static func session(for token: ApplicationToken, store: ReinterventionStore = .init(), now: Date = Date()) -> ReinterventionSession? {
        try? store.read().sessions.values.first { $0.shouldShield(at: now) && tokens(in: $0.selectionData).contains(token) }
    }
}
