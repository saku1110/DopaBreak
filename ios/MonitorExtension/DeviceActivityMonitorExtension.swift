import DeviceActivity
import DopaBreakCore
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

/// 控えから取り出した、1つのストアへ流し込むぶんのトークン。
private struct SnapshotTokens {
    var applications = Set<ApplicationToken>()
    var categories = Set<ActivityCategoryToken>()
    var webDomains = Set<WebDomainToken>()

    var isEmpty: Bool {
        applications.isEmpty && categories.isEmpty && webDomains.isEmpty
    }
}

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    /// 日常ゲート専用ストア。夜・Deep Focusをここから解除しないよう完全に分ける。
    private let gateShieldStore = ManagedSettingsStore(
        named: .init(GateConstants.shieldStoreName)
    )
    /// 夜だけ強化の分だけを置くストア。常時ブロック（"dopabreak.rules"）とは別にしてあるため、
    /// ここから朝の解除を出してもディープフォーカスには当たらない。
    private let nightShieldStore = ManagedSettingsStore(
        named: .init(NightShieldConstants.shieldStoreName)
    )
    /// 完全ブロックの窓の分だけを置くストア。夜だけ強化とも旧ストアとも分けてあるため、
    /// ここから窓の終わりの解除を出しても、他の強さには当たらない。
    private let deepFocusShieldStore = ManagedSettingsStore(
        named: .init(DeepFocusConstants.shieldStoreName)
    )
    private let decoder = JSONDecoder()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        if activity.rawValue.hasPrefix(GateConstants.reshieldActivityPrefix) {
            reshieldGateIfExpired(for: activity)
            return
        }

        if DeepFocusConstants.isWindowActivity(activity.rawValue) {
            applyDeepFocusShield()
            return
        }

        switch activity.rawValue {
        case UsageWatchConstants.activityName:
            guard let store = try? UsageWatchStore() else {
                return
            }
            store.resetDailyState()
        case NightShieldConstants.activityName:
            applyNightShield()
        default:
            return
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        if activity.rawValue.hasPrefix(GateConstants.reshieldActivityPrefix) {
            reshieldGateIfExpired(for: activity)
            return
        }

        if DeepFocusConstants.isWindowActivity(activity.rawValue) {
            clearDeepFocusShieldIfOutsideWindow()
            return
        }

        guard activity.rawValue == NightShieldConstants.activityName else {
            return
        }
        clearNightShieldIfOutsideWindow()
    }

    /// 一時開放の終端で、該当トークンを日常ゲートへ戻す。
    ///
    /// DeviceActivityの境界は数十秒ずれることがあるため終了30秒前から同じ終端として扱う。
    /// 名前が衝突した・早すぎるコールバックは台帳を変えず、ここから監視を張り直さない。
    private func reshieldGateIfExpired(for activity: DeviceActivityName) {
        let now = Date()
        let snapshotStore = JSONSnapshotStore()
        let ledgerStore = GateLedgerStore(snapshotStore: snapshotStore)
        let ledger = try? ledgerStore.ledger()
        let grant = ledger?.activeGrants.first(where: {
            $0.activityName == activity.rawValue
        })
        let decision = GateReshieldPolicy.decision(
            grant: grant,
            now: now,
            tolerance: 30
        )

        guard decision.shouldReshield, let grant else {
            if decision.shouldStopMonitoring {
                DeviceActivityCenter().stopMonitoring([activity])
            }
            return
        }
        // 期限回収へ進んだ後は、成功・破損・降格・競合のどの出口でも片付ける。
        // 早すぎるcallbackだけは停止せず、intervalDidEndの保険を残す。
        defer {
            if decision.shouldStopMonitoring {
                DeviceActivityCenter().stopMonitoring([activity])
            }
        }
        guard let shieldSnapshot = try? GateShieldSnapshotStore(
                snapshotStore: snapshotStore
              ).snapshot() else {
            return
        }

        let selectedTokens = decodedGateApplicationTokens(
            from: shieldSnapshot.selectionDataList
        )

        // 30秒許容で早く届いた場合も、このgrantだけは終了したものとして台帳から落とす。
        // 同時に、これより前に終わっているgrantもまとめて回収する。
        var reconciledLedger: GateLedger?
        do {
            try ledgerStore.update { currentLedger in
                guard let currentGrant = currentLedger.activeGrants.first(where: {
                    $0.activityName == activity.rawValue
                }),
                now >= currentGrant.endsAt.addingTimeInterval(-30) else {
                    return
                }
                let expiration = GatePolicy.expiringGrants(
                    ledger: currentLedger,
                    now: now,
                    additionallyExpiring: [currentGrant.id],
                    calendar: .autoupdatingCurrent
                )
                guard expiration.expired.contains(where: { $0.id == currentGrant.id }) else {
                    return
                }
                currentLedger = expiration.ledger
                reconciledLedger = expiration.ledger
            }
        } catch {
            return
        }
        guard let reconciledLedger else {
            return
        }

        // 30秒の許容値は「このgrantを期限切れにするか」だけへ使う。他grantの
        // シールド集合は実時刻で判定し、未来へ進めた参照時刻で早く閉じない。
        let tokensToShield = GatePolicy.tokensToShield(
            selectionTokens: selectedTokens,
            ledger: reconciledLedger,
            now: now
        )

        // 読み取り中に降格・全削除で控えが消えたなら、ゲートを復活させない。
        guard snapshotStore.exists(.gateShieldSnapshot) else {
            return
        }

        gateShieldStore.shield.applications = tokensToShield.isEmpty ? nil : tokensToShield
        // v1.1のゲートはアプリ単位だけ。旧値が混ざらないよう他の種類は常に空にする。
        gateShieldStore.shield.applicationCategories = nil
        gateShieldStore.shield.webDomains = nil
    }

    /// 窓の終わりに完全ブロックを剥がす。ただし、いま別の窓の内にいるなら剥がさない。
    ///
    /// セッションと予定は重なることがある。片方が終わっただけで両方の解除を出すと、
    /// まだ続いているはずのブロックが落ちる。
    ///
    /// 控えが読めないときは剥がす側へ倒す。降格や全データ削除の後始末が走った後か、
    /// 控えが壊れているかのどちらかで、どちらも「掛け続ける根拠がない」状態だからだ。
    /// ここで維持を選ぶと、終わったのに開けないブロックを誰も外せなくなる。
    private func clearDeepFocusShieldIfOutsideWindow() {
        let snapshotStore = JSONSnapshotStore()
        let now = Date()
        if let snapshot = try? snapshotStore.read(
            DeepFocusShieldSnapshot.self,
            from: .deepFocusShieldSnapshot
        ),
        DeepFocusWindowPolicy.isWindowActive(
            now: now,
            snapshot: snapshot,
            calendar: .autoupdatingCurrent
        ) {
            // セッションと予定が重なって片方だけ終わった場合は、残った窓の対象へ
            // 正確に戻す。手動セッションの全モード対象を予定終了まで残さない。
            applyDeepFocusShield(snapshot: snapshot, snapshotStore: snapshotStore, now: now)
            return
        }
        clearDeepFocusShield()
    }

    /// 窓のはじまりに、アプリが書いた控えのぶんだけブロックする。
    ///
    /// 権利の判定もルールの読み取りもここではしない。控えが無い・読めないときは何もしない。
    /// 拡張が独自に判断すると、Freeへ戻った端末でブロックが復活する。
    ///
    /// 控えに書かれた窓で「いま窓の内か」も確かめる。設定を変えた直後は、
    /// 古い予定ぶんの開始が遅れて届くことがあり、時刻を見ずに従うと窓の外でブロックが出る。
    private func applyDeepFocusShield() {
        let snapshotStore = JSONSnapshotStore()
        guard let snapshot = try? snapshotStore.read(
            DeepFocusShieldSnapshot.self,
            from: .deepFocusShieldSnapshot
        ) else {
            return
        }

        applyDeepFocusShield(snapshot: snapshot, snapshotStore: snapshotStore, now: Date())
    }

    private func applyDeepFocusShield(
        snapshot: DeepFocusShieldSnapshot,
        snapshotStore: JSONSnapshotStore,
        now: Date
    ) {
        guard DeepFocusWindowPolicy.isWindowActive(
            now: now,
            snapshot: snapshot,
            calendar: .autoupdatingCurrent
        ) else {
            return
        }

        let selectionDataList = DeepFocusWindowPolicy.selectionDataListToShield(
            now: now,
            snapshot: snapshot,
            calendar: .autoupdatingCurrent
        )
        guard !selectionDataList.isEmpty else {
            clearDeepFocusShield()
            return
        }

        let tokens = decodedTokens(from: selectionDataList)
        guard !tokens.isEmpty else {
            return
        }

        // 読んでからここへ来るまでに、アプリが降格の後始末で控えを消していることがある。
        // 消えていれば「もう適用してはいけない」の合図なので、張らずに引き返す。
        // それでも残る極小の競合窓は、次にアプリが前面へ来たときの `syncShield` が必ず剥がす。
        guard snapshotStore.exists(.deepFocusShieldSnapshot) else {
            return
        }

        apply(tokens, to: deepFocusShieldStore)
    }

    private func clearDeepFocusShield() {
        clear(deepFocusShieldStore)
    }

    /// 起床時刻に夜間ぶんを剥がす。ただし、いま新しい窓の内にいるなら剥がさない。
    ///
    /// 就寝・起床を変えると、古いスケジュールぶんの終了が新しい窓の最中に届くことがある。
    /// 控えが無いときは降格や全データ削除の後始末が走った後なので、そのまま解除でよい。
    private func clearNightShieldIfOutsideWindow() {
        if let snapshot = try? JSONSnapshotStore().read(
            NightShieldSnapshot.self,
            from: .nightShieldSnapshot
        ),
        NightWindowPolicy.isNight(
            now: Date(),
            snapshot: snapshot,
            calendar: .autoupdatingCurrent
        ) {
            return
        }
        clearNightShield()
    }

    /// 就寝時刻に、アプリが書いた控えのぶんだけブロックする。
    ///
    /// 権利の判定もルールの読み取りもここではしない。控えが無い・読めないときは何もしない。
    /// 拡張が独自に判断すると、Freeへ戻った端末で夜だけブロックが復活する。
    ///
    /// 控えに書かれた就寝・起床で「いま窓の内か」も確かめる。就寝時刻を変えた直後は、
    /// 古いスケジュールぶんの開始が遅れて届くことがあり、時刻を見ずに従うと昼にブロックが出る。
    private func applyNightShield() {
        let snapshotStore = JSONSnapshotStore()
        guard let snapshot = try? snapshotStore.read(
            NightShieldSnapshot.self,
            from: .nightShieldSnapshot
        ) else {
            return
        }

        guard NightWindowPolicy.isNight(
            now: Date(),
            snapshot: snapshot,
            calendar: .autoupdatingCurrent
        ) else {
            return
        }

        let tokens = decodedTokens(from: snapshot.selectionDataList)
        guard !tokens.isEmpty else {
            return
        }

        // 読んでからここへ来るまでに、アプリが降格の後始末で控えを消していることがある。
        // 消えていれば「もう適用してはいけない」の合図なので、張らずに引き返す。
        // それでも残る極小の競合窓は、次にアプリが前面へ来たときの `syncShield` が必ず剥がす。
        guard snapshotStore.exists(.nightShieldSnapshot) else {
            return
        }

        apply(tokens, to: nightShieldStore)
    }

    private func clearNightShield() {
        clear(nightShieldStore)
    }

    /// 控えに入っている選択データを、実際に止められるトークンへほどく。
    /// 1件でも読めなければその1件だけを飛ばす。壊れた1件で全部を落とさない。
    private func decodedTokens(from selectionDataList: [Data]) -> SnapshotTokens {
        var tokens = SnapshotTokens()
        for selectionData in selectionDataList {
            guard let selection = try? decoder.decode(
                FamilyActivitySelection.self,
                from: selectionData
            ) else {
                continue
            }
            tokens.applications.formUnion(selection.applicationTokens)
            tokens.categories.formUnion(selection.categoryTokens)
            tokens.webDomains.formUnion(selection.webDomainTokens)
        }
        return tokens
    }

    /// ゲートはアプリトークンだけを必要分だけ復号する。
    /// blobごとに独立して扱い、壊れた1件は黙って飛ばして復号できた集合を正とする。
    private func decodedGateApplicationTokens(
        from selectionDataList: [Data]
    ) -> Set<ApplicationToken> {
        var applications = Set<ApplicationToken>()
        for selectionData in selectionDataList {
            guard let selection = try? decoder.decode(
                FamilyActivitySelection.self,
                from: selectionData
            ) else {
                continue
            }
            applications.formUnion(selection.applicationTokens)
        }
        return applications
    }

    private func apply(_ tokens: SnapshotTokens, to store: ManagedSettingsStore) {
        store.shield.applications = tokens.applications.isEmpty ? nil : tokens.applications
        store.shield.applicationCategories = tokens.categories.isEmpty
            ? nil
            : .specific(tokens.categories)
        store.shield.webDomains = tokens.webDomains.isEmpty ? nil : tokens.webDomains
    }

    private func clear(_ store: ManagedSettingsStore) {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        guard activity.rawValue == UsageWatchConstants.activityName,
              let stepIndex = UsageWatchConstants.stepIndex(eventName: event.rawValue),
              let store = try? UsageWatchStore() else {
            return
        }

        let eventDate = Date()
        let result = UsageWatchPolicy.evaluate(
            newEventAt: eventDate,
            stepIndex: stepIndex,
            state: store.loadState(),
            config: store.loadConfiguration(),
            calendar: .autoupdatingCurrent
        )
        store.saveState(result.state)

        guard result.decision != .none else {
            return
        }
        postNotification(for: result.decision)
    }

    private func postNotification(for decision: UsageWatchDecision) {
        let content = UNMutableNotificationContent()
        switch decision {
        case .none:
            return
        case .freeWarning:
            content.title = String(
                localized: "usage_watch.notification.free_warning.title",
                defaultValue: "連続で2時間になりました⏰"
            )
            content.body = String(
                localized: "usage_watch.notification.free_warning.body",
                defaultValue: "見ようとしていたものは見つかりましたか？"
            )
        case .question(let question):
            let copy = notificationCopy(for: question)
            content.title = copy.title
            content.body = copy.body
        }

        content.sound = .default
        content.categoryIdentifier = UsageWatchConstants.notificationCategoryIdentifier
        let request = UNNotificationRequest(
            identifier: UsageWatchConstants.notificationIdentifierPrefix + UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    private func notificationCopy(for question: UsageWatchQuestion) -> (title: String, body: String) {
        switch question {
        case .q15:
            return (
                String(
                    localized: "usage_watch.notification.q15.title",
                    defaultValue: "15分たちました"
                ),
                String(
                    localized: "usage_watch.notification.q15.body",
                    defaultValue: "SNSをまだ見ますか？"
                )
            )
        case .q30:
            return (
                String(
                    localized: "usage_watch.notification.q30.title",
                    defaultValue: "30分たちました"
                ),
                String(
                    localized: "usage_watch.notification.q30.body",
                    defaultValue: "SNSで満足感を得られましたか？👀"
                )
            )
        case .q45:
            return (
                String(
                    localized: "usage_watch.notification.q45.title",
                    defaultValue: "45分たちました"
                ),
                String(
                    localized: "usage_watch.notification.q45.body",
                    defaultValue: "あと何分で終わりにしますか？⏳"
                )
            )
        case .hourly:
            return (
                String(
                    localized: "usage_watch.notification.hourly.title",
                    defaultValue: "また1時間たちました"
                ),
                String(
                    localized: "usage_watch.notification.hourly.body",
                    defaultValue: "この1時間で何が残りましたか？💭"
                )
            )
        }
    }
}
