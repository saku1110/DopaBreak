import DeviceActivity
import DopaBreakCore
import Foundation

protocol GateGrantMonitoring {
    func startMonitoring(
        _ activity: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws
    func stopMonitoring(_ activities: [DeviceActivityName])
}

extension DeviceActivityCenter: GateGrantMonitoring {}

/// 一時開放の台帳と、終了時に掛け直すDeviceActivity監視を一緒に管理する。
@MainActor
final class GateGrantController {
    private static let monitoringTailMinutes = 16

    private let settingsStore: GateAppSettingsStore
    private let ledgerStore: GateLedgerStore
    private let requestStore: GateUnlockRequestStore
    private let monitoringCenter: any GateGrantMonitoring
    private let reapplyGate: (Date) throws -> Void
    private let now: () -> Date
    private let calendar: Calendar
    private let makeUUID: () -> UUID

    init(
        settingsStore: GateAppSettingsStore,
        ledgerStore: GateLedgerStore,
        requestStore: GateUnlockRequestStore,
        monitoringCenter: any GateGrantMonitoring = DeviceActivityCenter(),
        reapplyGate: @escaping (Date) throws -> Void,
        now: @escaping () -> Date = { Date() },
        calendar: Calendar = .autoupdatingCurrent,
        makeUUID: @escaping () -> UUID = { UUID() }
    ) {
        self.settingsStore = settingsStore
        self.ledgerStore = ledgerStore
        self.requestStore = requestStore
        self.monitoringCenter = monitoringCenter
        self.reapplyGate = reapplyGate
        self.now = now
        self.calendar = calendar
        self.makeUUID = makeUUID
    }

    /// 記録をopenedへ進める直前の拒否判定。ストレージ障害は呼び出し側へthrowし、
    /// 上限・待ち時間・既存開放だけを画面分岐用のResultで返す。
    func validate(tokenData: Data) throws -> Result<Void, GateDenial> {
        let referenceDate = now()
        let expiration = GatePolicy.expiringGrants(
            ledger: try ledgerStore.ledger(),
            now: referenceDate,
            calendar: calendar
        )
        return GatePolicy.canGrant(
            tokenData: tokenData,
            now: referenceDate,
            settings: try settingsStore.snapshot(),
            ledger: expiration.ledger,
            calendar: calendar
        )
    }

    /// 一呼吸を終えたアプリを指定分だけ開放する。
    ///
    /// DeviceActivityの登録だけが失敗しても開放は取り消さない。前面復帰時の回収と
    /// 拡張側の再適用が残るため、台帳には監視名を空で保存して復旧経路を保つ。
    @discardableResult
    func grant(tokenData: Data, ruleId: UUID, minutes: Int) throws -> GateGrant {
        let startedAt = now()
        let settings = try settingsStore.snapshot()
        let grantID = makeUUID()
        let pendingGrant = GateGrant(
            id: grantID,
            tokenData: tokenData,
            ruleId: ruleId,
            startedAt: startedAt,
            endsAt: startedAt.addingTimeInterval(TimeInterval(minutes * 60)),
            activityName: ""
        )
        var stoppedGrants: [GateGrant] = []
        var reusedGrant: GateGrant?
        try ledgerStore.update { ledger in
            let expiration = GatePolicy.expiringGrants(
                ledger: ledger,
                now: startedAt,
                calendar: self.calendar
            )
            let advisoryValidation = GatePolicy.canGrant(
                tokenData: tokenData,
                now: startedAt,
                settings: settings,
                ledger: expiration.ledger,
                calendar: self.calendar
            )
            if case .failure(.alreadyOpen) = advisoryValidation,
               let activeGrant = expiration.ledger.activeGrants
                .filter({ $0.tokenData == tokenData && startedAt < $0.endsAt })
                .max(by: { $0.endsAt < $1.endsAt }) {
                // validate後に別プロセスが同じトークンを開けた競合は成功として再利用する。
                stoppedGrants = expiration.expired
                reusedGrant = activeGrant
                ledger = expiration.ledger
                return
            }
            // limit/cooldownがvalidate後に競合しても、recordOpen済みなのでここでは拒否しない。

            let application = GatePolicy.applyingGrant(
                ledger: expiration.ledger,
                grant: pendingGrant,
                calendar: self.calendar
            )
            stoppedGrants = expiration.expired + application.expired
            ledger = application.ledger
        }
        // 消費点が先に落ちても、grant確定後に同じトークンの要求を残さない。
        // 削除失敗時もGatePolicyがgrantより古い要求を無視するため、開放自体は維持する。
        _ = try? requestStore.clear(for: tokenData)
        do {
            try reapplyGate(startedAt)
        } catch {
            // 台帳上の開放は確定済み。前面復帰reconcileと拡張の再適用で回復できる。
        }
        stopMonitoring(for: stoppedGrants)

        if let reusedGrant {
            return reusedGrant
        }

        let activityName = GateConstants.reshieldActivityName(for: grantID)
        let activity = DeviceActivityName(activityName)
        do {
            try monitoringCenter.startMonitoring(
                activity,
                during: schedule(for: pendingGrant),
                events: [:]
            )
        } catch {
            return pendingGrant
        }

        var monitoredGrant = pendingGrant
        monitoredGrant.activityName = activityName

        do {
            var didUpdateGrant = false
            try ledgerStore.update { ledger in
                guard let index = ledger.activeGrants.firstIndex(where: { $0.id == grantID }) else {
                    return
                }
                ledger.activeGrants[index] = monitoredGrant
                didUpdateGrant = true
            }
            guard didUpdateGrant else {
                monitoringCenter.stopMonitoring([activity])
                return pendingGrant
            }
            return monitoredGrant
        } catch {
            // 監視自体は生きている。台帳はactivityNameなしのgrantを保持し、
            // MonitorExtensionはgrant IDを含む活動名から期限回収できる。
            return pendingGrant
        }
    }

    /// 終了済みの一時開放を回収し、現在の選択全体を掛け直す。
    @discardableResult
    func reconcile(now referenceDate: Date) throws -> [GateGrant] {
        var expiredGrants: [GateGrant] = []
        try ledgerStore.update { ledger in
            let expiration = GatePolicy.expiringGrants(
                ledger: ledger,
                now: referenceDate,
                calendar: self.calendar
            )
            expiredGrants = expiration.expired
            ledger = expiration.ledger
        }
        try reapplyGate(referenceDate)
        stopMonitoring(for: expiredGrants)
        return expiredGrants
    }

    func hasActiveGrant(at referenceDate: Date) -> Bool {
        guard let ledger = try? ledgerStore.ledger() else {
            return false
        }
        return ledger.activeGrants.contains {
            referenceDate < $0.endsAt
        }
    }

    /// 全削除の前に、台帳に残る監視名を止める。
    func stopAllMonitoring() {
        guard let grants = try? ledgerStore.ledger().activeGrants else {
            return
        }
        stopMonitoring(for: grants)
    }

    private func schedule(for grant: GateGrant) -> DeviceActivitySchedule {
        let fields: Set<Calendar.Component> = [.era, .year, .month, .day, .hour, .minute]
        let minuteInterval = calendar.dateInterval(of: .minute, for: grant.endsAt)
        let intervalStartDate: Date
        if let minuteInterval {
            intervalStartDate = grant.endsAt > minuteInterval.start
                ? minuteInterval.end
                : minuteInterval.start
        } else {
            let seconds = grant.endsAt.timeIntervalSinceReferenceDate
            intervalStartDate = Date(
                timeIntervalSinceReferenceDate: ceil(seconds / 60) * 60
            )
        }
        let intervalEndDate = calendar.date(
            byAdding: .minute,
            value: Self.monitoringTailMinutes,
            to: intervalStartDate
        ) ?? intervalStartDate.addingTimeInterval(
            TimeInterval(Self.monitoringTailMinutes * 60)
        )
        return DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(fields, from: intervalStartDate),
            intervalEnd: calendar.dateComponents(fields, from: intervalEndDate),
            repeats: false
        )
    }

    private func stopMonitoring(for grants: [GateGrant]) {
        let activities = grants.compactMap { grant -> DeviceActivityName? in
            guard !grant.activityName.isEmpty else {
                return nil
            }
            return DeviceActivityName(grant.activityName)
        }
        guard !activities.isEmpty else {
            return
        }
        monitoringCenter.stopMonitoring(activities)
    }
}
