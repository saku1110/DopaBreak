import DeviceActivity
import DopaBreakCore
import Foundation

protocol NightShieldMonitoring {
    func startMonitoring(
        _ activity: DeviceActivityName,
        during schedule: DeviceActivitySchedule,
        events: [DeviceActivityEvent.Name: DeviceActivityEvent]
    ) throws
    func stopMonitoring(_ activities: [DeviceActivityName])
}

extension DeviceActivityCenter: NightShieldMonitoring {}

/// 夜だけ強化を、アプリが起きていないあいだも切り替えるための下ごしらえ。
///
/// 拡張の中では権利もルールも見ない。Proだと確定しているあいだにアプリが控え
/// （`NightShieldSnapshot`）を書き、権利を落としたら控えごと消す。
/// 判断をアプリ側に寄せることで、拡張には「書いてあるものを適用する」だけが残る。
@MainActor
final class NightShieldScheduler {
    static let activityName = DeviceActivityName(NightShieldConstants.activityName)

    private let ruleStore: RuleStore
    private let settingsStore: SettingsStore
    private let snapshotStore: JSONSnapshotStore
    private let monitoringCenter: any NightShieldMonitoring
    private let clearNightShield: @MainActor () -> Void
    private let now: () -> Date

    private(set) var didLastRebuildFail = false

    init(
        ruleStore: RuleStore,
        settingsStore: SettingsStore,
        snapshotStore: JSONSnapshotStore,
        monitoringCenter: any NightShieldMonitoring = DeviceActivityCenter(),
        clearNightShield: @MainActor @escaping () -> Void,
        now: @escaping () -> Date = { Date() }
    ) {
        self.ruleStore = ruleStore
        self.settingsStore = settingsStore
        self.snapshotStore = snapshotStore
        self.monitoringCenter = monitoringCenter
        self.clearNightShield = clearNightShield
        self.now = now
    }

    /// 控えと監視を、現在の権利・ルール・就寝起床時刻へ合わせ直す。
    ///
    /// 権利が未確定のあいだは何も触らない（`ShieldSyncPolicy` の `preserve` と同じ考え方）。
    /// 取得に失敗しただけの課金者の夜間ブロックを、ここで先に剥がしてしまわないため。
    ///
    /// - Returns: 監視を張れたかどうか。張らないことが正しい場面でも `false` を返す。
    @discardableResult
    func rebuild(entitlementGate: EntitlementGate, hasConfirmedEntitlement: Bool) -> Bool {
        guard hasConfirmedEntitlement else {
            return false
        }

        // Freeだと確定した時点で、ルールを読む前に止める。
        // ルールの読み取りに失敗する端末でも、降格の後始末だけは必ず通す。
        guard entitlementGate.tier == .pro, entitlementGate.strictModeAllowed else {
            stopAndClear()
            return false
        }

        let bedTimeMinutes = NightWindowPolicy.normalizedMinutes(
            settingsStore.bedTimeMinutes ?? NightShieldConstants.defaultBedTimeMinutes
        )
        let wakeTimeMinutes = NightWindowPolicy.normalizedMinutes(
            settingsStore.wakeTimeMinutes ?? NightShieldConstants.defaultWakeTimeMinutes
        )
        // 15分未満の窓はDeviceActivityが受け付けない。張れない予定を控えごと残さない。
        guard NightWindowPolicy.hasWindow(
            bedTimeMinutes: bedTimeMinutes,
            wakeTimeMinutes: wakeTimeMinutes
        ) else {
            stopAndClear()
            return false
        }

        // Proのまま読めなかったときは触らない。読めないことを理由に、
        // 効いている夜間ブロックの予定を消さない。
        guard let rules = try? ruleStore.allRules() else {
            return false
        }

        let selectionDataList = rules
            .filter { $0.isEnabled && $0.mode == .nightOnly && !$0.activitySelectionData.isEmpty }
            .map(\.activitySelectionData)

        guard !selectionDataList.isEmpty else {
            stopAndClear()
            return false
        }

        // 控えを先に置く。書けなかったときは既存の監視に触らない。
        // 先に監視を止める形にすると、書き込みに失敗した端末で朝の解除まで失う。
        do {
            try snapshotStore.write(
                NightShieldSnapshot(
                    selectionDataList: selectionDataList,
                    bedTimeMinutes: bedTimeMinutes,
                    wakeTimeMinutes: wakeTimeMinutes,
                    updatedAt: now()
                ),
                to: .nightShieldSnapshot
            )
        } catch {
            didLastRebuildFail = true
            return false
        }

        monitoringCenter.stopMonitoring([Self.activityName])

        do {
            try monitoringCenter.startMonitoring(
                Self.activityName,
                during: Self.schedule(
                    bedTimeMinutes: bedTimeMinutes,
                    wakeTimeMinutes: wakeTimeMinutes
                ),
                events: [:]
            )
            didLastRebuildFail = false
            return true
        } catch {
            // 張れなかったときは、朝に解除を出す担い手が拡張側にいなくなる。
            // 掛けっぱなしで放置するより、いったん夜間ぶんを剥がす側へ倒す
            // （Proの利用者を一晩締め出す被害の方が大きい・2026-08-14 Fable裁定）。
            // このあと呼び出し側の `syncShield` が続くため、いま窓の内なら同じ経路で張り直り、
            // 朝の解除は「次にアプリが前面へ来たときの再計算」が受け持つ。
            monitoringCenter.stopMonitoring([Self.activityName])
            clearNightShield()
            try? snapshotStore.remove(.nightShieldSnapshot)
            didLastRebuildFail = true
            return false
        }
    }

    /// 監視を止めて控えを消す。降格と全データ削除の後始末はここに一本化する。
    ///
    /// 順序は「監視停止 → 控え削除」。逆にすると、控えを消してから監視が止まるまでの
    /// あいだに境界が来たとき、拡張が消したはずの対象を張り直す余地が広がる。
    /// 呼び出し側は、このあとにシールドの解除を置くこと。
    ///
    /// ルールに保存された `nightOnly` は書き換えない（2026-08-14の非破壊降格の裁定）。
    /// 再びProになったときに、前の設定がそのまま戻るようにするため。
    ///
    /// - Returns: 控えを消しきれたか。消せなかったことを握りつぶさず、
    ///   次の `syncShield` で消し直せるように失敗として残す。
    @discardableResult
    func stopAndClear() -> Bool {
        monitoringCenter.stopMonitoring([Self.activityName])

        do {
            try snapshotStore.remove(.nightShieldSnapshot)
            didLastRebuildFail = false
            return true
        } catch {
            // 監視は止まっているため、新たな境界で拡張が起きることはない。
            // 残った控えは次の同期で消し直す。
            didLastRebuildFail = true
            return false
        }
    }

    static func schedule(bedTimeMinutes: Int, wakeTimeMinutes: Int) -> DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(
                hour: bedTimeMinutes / 60,
                minute: bedTimeMinutes % 60
            ),
            intervalEnd: DateComponents(
                hour: wakeTimeMinutes / 60,
                minute: wakeTimeMinutes % 60
            ),
            repeats: true
        )
    }
}
