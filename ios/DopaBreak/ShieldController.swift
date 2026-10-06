import DeviceActivity
import DopaBreakCore
import FamilyControls
import Foundation
import ManagedSettings

/// 廃止した常時ゲートが残したDeviceActivityの監視を止めるためだけの入口。
/// テストから差し替えられるように切っておく。
protocol RetiredActivityMonitoring {
    /// いまこのアプリが登録している監視の名前。
    var monitoredActivityNames: [DeviceActivityName] { get }
    func stopMonitoring(_ activities: [DeviceActivityName])
}

extension DeviceActivityCenter: RetiredActivityMonitoring {
    var monitoredActivityNames: [DeviceActivityName] {
        activities
    }
}

/// Named ManagedSettings output. Tests record writes because Simulator cannot authorize Screen Time.
protocol ShieldSettingsWriting: AnyObject {
    func setShield(applications: Set<ApplicationToken>, categories: Set<ActivityCategoryToken>, webDomains: Set<WebDomainToken>)
}

extension ManagedSettingsStore: ShieldSettingsWriting {
    func setShield(applications: Set<ApplicationToken>, categories: Set<ActivityCategoryToken>, webDomains: Set<WebDomainToken>) {
        shield.applications = applications.isEmpty ? nil : applications
        shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        shield.webDomains = webDomains.isEmpty ? nil : webDomains
    }
}

@MainActor
final class ShieldController {
    private let ruleStore: RuleStore
    /// 完全ブロック（ディープフォーカス）の分を置くストア。窓の境界で拡張が
    /// ここだけを触れるように、夜だけ強化とも旧ストアとも分ける。
    private let deepFocusManagedSettingsStore: any ShieldSettingsWriting
    /// 夜間は独立したストアに置き、手動終了では解除しない。
    private let nightManagedSettingsStore: any ShieldSettingsWriting
    /// 常時ブロックだった頃の置き場。もう誰も書かないが、更新前に掛かったままの端末が残る。
    /// 空にし続けないと、窓が終わっても剥がれないブロックが更新直後の全員に残る。
    private let legacyManagedSettingsStore: any ShieldSettingsWriting
    /// 更新前の常時ゲートが使っていたストア。
    /// 新しい書き込み元は持たず、更新後の最初の同期から空にし続ける。
    private let retiredAlwaysOnManagedSettingsStore: any ShieldSettingsWriting
    /// 更新前の常時ゲートが張ったDeviceActivityの名前の頭（`dopabreak.gate.reshield.<uuid>`）。
    /// 張り直しの持ち主だったコントローラごと廃止したため、止める経路が誰にも残っていない。
    private static let retiredGateActivityPrefix = "dopabreak.gate"
    private let activityCenter: any RetiredActivityMonitoring
    /// 廃止済みゲートの掃除を済ませたか。
    private var didStopRetiredGateMonitoring = false
    private let decoder = JSONDecoder()

    init(
        ruleStore: RuleStore,
        activityCenter: any RetiredActivityMonitoring = DeviceActivityCenter(),
        storeFactory: (String) -> any ShieldSettingsWriting = { ManagedSettingsStore(named: .init($0)) }
    ) {
        self.ruleStore = ruleStore
        self.activityCenter = activityCenter
        self.deepFocusManagedSettingsStore = storeFactory(DeepFocusConstants.shieldStoreName)
        self.nightManagedSettingsStore = storeFactory(NightShieldConstants.shieldStoreName)
        self.legacyManagedSettingsStore = storeFactory(DeepFocusConstants.legacyShieldStoreName)
        self.retiredAlwaysOnManagedSettingsStore = storeFactory("dopabreak.gate")
    }

    /// 完全ブロックを現在の権利とルールへ合わせる。
    ///
    /// 適用対象は選択データを持つ有効なルールのうち、窓のなかの `deepFocus` と、
    /// 夜の窓のなかの `nightOnly`（docs/12 §5）。
    /// カタログ由来の通常介入ルールは選択データが空のため触れない。
    ///
    /// `isNightWindow` と `isDeepFocusWindowActive` は呼び出し側が現在時刻から決めて渡す。
    /// 拡張の境界コールバックは取りこぼしがあるため、アプリが前面に来るたびのこの同期が
    /// 復旧経路になる。とくに完全ブロックは、窓が終わったのに解除が届かない状態を作らないため、
    /// ここを通るたびに窓の外なら必ず剥がす。
    ///
    /// `hasConfirmedEntitlement` が偽のあいだは何もしない。取得に失敗しただけの課金者から
    /// 完全ブロックを剥がさないため（`ShieldSyncPolicy` の `preserve`）。
    ///
    /// 解除だけはルールの読み取りより先に済ませる。読み取りが失敗する端末で
    /// `return` すると、Freeへ戻った人の完全ブロックが二度と外れなくなるため。
    func syncShield(
        entitlementGate: EntitlementGate,
        hasConfirmedEntitlement: Bool,
        isNightWindow: Bool,
        isDeepFocusWindowActive: Bool,
        isManualDeepFocusSessionActive: Bool = false,
        allowsNightSchedule: Bool = false,
        blockConfiguration: BlockConfiguration = BlockConfiguration()
    ) {
        // 権利確認やルール読み取りより先に、廃止済みの常時ゲートだけを必ず剥がす。
        // これが更新後の初回同期で、既存ユーザーの灰色アイコンを確実に戻す移行経路になる。
        clear(retiredAlwaysOnManagedSettingsStore)
        stopRetiredGateMonitoring()

        // ルールの取得も含めて `ShieldSyncPolicy` に判断させる。
        // 取得してから判断する形にすると、読み取りが失敗する端末で
        // Freeへ戻った人の解除が落ちる（判断の順序をここで持たない）。
        switch ShieldSyncPolicy.action(
            rulesProvider: { try ruleStore.allRules() },
            isPro: entitlementGate.tier == .pro,
            strictModeAllowed: entitlementGate.strictModeAllowed,
            hasConfirmedEntitlement: hasConfirmedEntitlement,
            isNightWindow: isNightWindow,
            isDeepFocusWindowActive: isDeepFocusWindowActive,
            isManualDeepFocusSessionActive: isManualDeepFocusSessionActive,
                allowsNightSchedule: allowsNightSchedule,
                blockConfiguration: blockConfiguration
        ) {
        case .preserve:
            return
        case .clear:
            clearShield()
        case .apply(let rules):
            applyShield(
                rules: rules,
                entitlementGate: entitlementGate,
                isNightWindow: isNightWindow,
                isDeepFocusWindowActive: isDeepFocusWindowActive,
                isManualDeepFocusSessionActive: isManualDeepFocusSessionActive,
                allowsNightSchedule: allowsNightSchedule,
                blockConfiguration: blockConfiguration
            )
        }
    }

    private func applyShield(
        rules: [TargetRule],
        entitlementGate: EntitlementGate,
        isNightWindow: Bool,
        isDeepFocusWindowActive: Bool,
        isManualDeepFocusSessionActive: Bool,
        allowsNightSchedule: Bool,
        blockConfiguration: BlockConfiguration
    ) {
        var deepFocusTokens = ShieldTokens()
        var nightTokens = ShieldTokens()
        // 上限は2つのストアで分け合う。ルールの並び順のまま先頭から数えるところは変えない。
        var remainingTargetTokenLimit = entitlementGate.targetAppTokensLimit

        for rule in applicableRules(from: rules, entitlementGate: entitlementGate) {
            let appliesToDeepFocus = blockConfiguration.isActive(manual: isManualDeepFocusSessionActive, weeklySchedule: isDeepFocusWindowActive, night: false)
            let appliesToNight = blockConfiguration.allows(.night) && isNightWindow

            do {
                let selection = try decoder.decode(
                    FamilyActivitySelection.self,
                    from: rule.activitySelectionData
                )
                // 同じ夜ルールが手動セッションと夜窓の両方へ入る場合も、権利上限は
                // 1回だけ消費し、同じ限定済みトークン集合を2ストアへ流す。
                var ruleTokens = ShieldTokens()
                ruleTokens.append(selection, remainingLimit: &remainingTargetTokenLimit)
                if appliesToDeepFocus {
                    deepFocusTokens.merge(ruleTokens)
                }
                if appliesToNight {
                    nightTokens.merge(ruleTokens)
                }
            } catch {
                if appliesToDeepFocus {
                    deepFocusTokens.didFailDecodingSelection = true
                }
                if appliesToNight {
                    nightTokens.didFailDecodingSelection = true
                }
                continue
            }
        }

        apply(deepFocusTokens, to: deepFocusManagedSettingsStore)
        apply(nightTokens, to: nightManagedSettingsStore)
        clear(legacyManagedSettingsStore)
    }

    func clearShield() {
        clear(deepFocusManagedSettingsStore)
        clear(nightManagedSettingsStore)
        clear(legacyManagedSettingsStore)
        clear(retiredAlwaysOnManagedSettingsStore)
    }

    /// 完全ブロックぶんだけを剥がす。窓の予定を張れなかったときに、
    /// 終わりの解除を出す担い手がいないままブロックを残さないための出口（`DeepFocusScheduler`）。
    func clearDeepFocusShield() {
        clear(deepFocusManagedSettingsStore)
    }

    /// 夜間ぶんだけを剥がす。夜の監視を張れなかったときに、朝の解除を出す担い手が
    /// いないままブロックを残さないための出口（`NightShieldScheduler`）。
    func clearNightShield() {
        clear(nightManagedSettingsStore)
    }

    /// 廃止した常時ゲートが残した監視を止める。
    ///
    /// `ManagedSettingsStore` 側の掃除だけでは、旧ビルドから上げた端末に
    /// `dopabreak.gate.reshield.<uuid>` の予定が残り続ける。枠を食いながら
    /// `MonitorExtension` を無駄に起こすため、シールドの解除と同じ最初の同期で落とす。
    ///
    /// 何度呼んでも壊れない。走り切るのはプロセスに1回だけで、そのあとは問い合わせもしない。
    /// この版に `dopabreak.gate.*` を張る書き手はもういないため、あとから増えることがない。
    ///
    /// 済んだ印は、一覧を実際に読めてから立てる。スクリーンタイムの認可が未解決の端末では
    /// `monitoredActivityNames` が空で返るため、そこで印を立てるとそのプロセスでは二度と見に行かない。
    /// 空のときは印を立てず次の同期へ回す。前面復帰のたびの問い合わせは掃除が済むまでの間だけになる。
    ///
    /// `AppContainer.syncShield()` が予定を張り直すより前にも通す。DeviceActivityの枠には
    /// 上限があり、旧アクティビティが居座ったまま新しい予定を登録させないため。
    func stopRetiredGateMonitoring() {
        guard !didStopRetiredGateMonitoring else {
            return
        }

        let monitored = activityCenter.monitoredActivityNames
        guard !monitored.isEmpty else {
            return
        }
        didStopRetiredGateMonitoring = true

        let retired = monitored.filter {
            $0.rawValue.hasPrefix(Self.retiredGateActivityPrefix)
        }
        guard !retired.isEmpty else {
            return
        }
        activityCenter.stopMonitoring(retired)
    }

    /// 読み取れたぶんだけを反映する。1件でもデコードに失敗したときは解除しない。
    /// 壊れたルールを理由に、いま効いているブロックを剥がさないため。
    private func apply(_ tokens: ShieldTokens, to store: any ShieldSettingsWriting) {
        guard !tokens.isEmpty else {
            if tokens.didFailDecodingSelection {
                return
            }
            clear(store)
            return
        }

        store.setShield(applications: tokens.applications, categories: tokens.categories, webDomains: tokens.webDomains)
    }

    private func clear(_ store: any ShieldSettingsWriting) {
        store.setShield(applications: [], categories: [], webDomains: [])
    }

    private func applicableRules(
        from rules: [TargetRule],
        entitlementGate: EntitlementGate
    ) -> [TargetRule] {
        guard let limit = entitlementGate.targetRulesLimit else {
            return rules
        }
        return Array(rules.prefix(limit))
    }
}

/// 1つのストアへ流し込むぶんのトークン。権利上限は呼び出し側で全ストア共通に数える。
private struct ShieldTokens {
    var applications = Set<ApplicationToken>()
    var categories = Set<ActivityCategoryToken>()
    var webDomains = Set<WebDomainToken>()
    var didFailDecodingSelection = false

    var isEmpty: Bool {
        applications.isEmpty && categories.isEmpty && webDomains.isEmpty
    }

    mutating func append(_ selection: FamilyActivitySelection, remainingLimit: inout Int?) {
        Self.appendTokens(
            selection.applicationTokens,
            to: &applications,
            remainingLimit: &remainingLimit
        )
        Self.appendTokens(
            selection.categoryTokens,
            to: &categories,
            remainingLimit: &remainingLimit
        )
        Self.appendTokens(
            selection.webDomainTokens,
            to: &webDomains,
            remainingLimit: &remainingLimit
        )
    }

    mutating func merge(_ other: ShieldTokens) {
        applications.formUnion(other.applications)
        categories.formUnion(other.categories)
        webDomains.formUnion(other.webDomains)
        didFailDecodingSelection = didFailDecodingSelection || other.didFailDecodingSelection
    }

    private static func appendTokens<Token: Hashable>(
        _ source: Set<Token>,
        to target: inout Set<Token>,
        remainingLimit: inout Int?
    ) {
        guard let limit = remainingLimit else {
            target.formUnion(source)
            return
        }

        guard limit > 0 else {
            return
        }

        let selected = source.prefix(limit)
        target.formUnion(selected)
        remainingLimit = limit - selected.count
    }
}
