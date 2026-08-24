import DopaBreakCore
import Dispatch
import FamilyControls
import Foundation
import ManagedSettings
import ManagedSettingsUI
import UserNotifications

final class ShieldActionExtension: ShieldActionDelegate {
    private let decoder = JSONDecoder()

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            handlePrimaryButton(for: application, completionHandler: completionHandler)
        case .secondaryButtonPressed:
            // 拡張は完了ハンドラ後すぐ終了しうるため、ログの同期書き込みを先に終える。
            recordCancelledAttempt(for: application)
            completionHandler(.close)
        default:
            completionHandler(.close)
        }
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        // Webドメインはv1.1のゲート対象外。
        completionHandler(.close)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        // カテゴリは完全ブロックだけで使い、アプリ単位の解除は出さない。
        completionHandler(.close)
    }

    private func handlePrimaryButton(
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let completion = SingleShotShieldActionCompletion(completionHandler)
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2) {
            completion.finish(.close)
        }

        do {
            let now = Date()
            let calendar = Calendar.autoupdatingCurrent
            let snapshotStore = JSONSnapshotStore()
            guard let gateSnapshot = try GateShieldSnapshotStore(
                snapshotStore: snapshotStore
            ).snapshot(),
            containsGateApplication(
                application,
                in: gateSnapshot.selectionDataList
            ) else {
                completion.finish(.close)
                return
            }

            let tokenData = try GateTokenCoding.encode(application)
            let settings = try GateAppSettingsStore(snapshotStore: snapshotStore)
                .setting(for: tokenData)
            let ledgerStore = GateLedgerStore(snapshotStore: snapshotStore)
            let ledger = try ledgerStore.ledger()
            let requestStore = GateUnlockRequestStore(snapshotStore: snapshotStore)
            let pendingRequest = try? requestStore.request()
            let deepFocusSnapshot = try snapshotStore.read(
                DeepFocusShieldSnapshot.self,
                from: .deepFocusShieldSnapshot
            )
            let nightSnapshot = try snapshotStore.read(
                NightShieldSnapshot.self,
                from: .nightShieldSnapshot
            )
            let state = GatePolicy.shieldState(
                tokenData: tokenData,
                now: now,
                settings: settings,
                ledger: ledger,
                pendingUnlockRequest: pendingRequest,
                isDeepFocusWindowActive: try isDeepFocusActive(
                    application: application,
                    snapshot: deepFocusSnapshot,
                    now: now,
                    calendar: calendar
                ),
                isNightWindow: try isNightActive(
                    application: application,
                    snapshot: nightSnapshot,
                    now: now,
                    calendar: calendar
                ),
                calendar: calendar
            )

            switch state {
            case .canUnlock:
                let request = GateUnlockRequest(
                    id: UUID(),
                    tokenData: tokenData,
                    requestedAt: now
                )
                try requestStore.save(request)

                if #available(iOS 26.5, *) {
                    scheduleUnlockNotification(
                        requestID: request.id,
                        delay: 8,
                        response: .openParentalControlsApp,
                        completion: completion
                    )
                } else {
                    scheduleUnlockNotification(
                        requestID: request.id,
                        delay: nil,
                        response: .defer,
                        completion: completion
                    )
                }
            case .waitingForApp:
                guard let request = pendingRequest,
                      request.tokenData == tokenData else {
                    completion.finish(.close)
                    return
                }
                scheduleUnlockNotification(
                    requestID: request.id,
                    delay: nil,
                    response: .defer,
                    completion: completion
                )
            case .limitReached, .cooldown, .hardWindow, .alreadyOpen:
                completion.finish(.close)
            }
        } catch {
            completion.finish(.close)
        }
    }

    /// 通知権限の状態と通知登録が完了してからShieldの応答を返す。
    /// 応答を先に返すと拡張が終了し、通知が登録されない端末があるため。
    private func scheduleUnlockNotification(
        requestID: UUID,
        delay: TimeInterval?,
        response: ShieldActionResponse,
        completion: SingleShotShieldActionCompletion
    ) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = String(
            localized: "gate.notification.unlock.title",
            defaultValue: "タップして一呼吸",
            bundle: .main
        )
        content.body = String(
            localized: "gate.notification.unlock.body",
            defaultValue: "DopaBreakで一呼吸してから開きます",
            bundle: .main
        )
        content.sound = .default
        content.userInfo = [GateConstants.unlockRequestUserInfoKey: requestID.uuidString]
        let trigger = delay.map {
            UNTimeIntervalNotificationTrigger(timeInterval: $0, repeats: false)
        }
        let request = UNNotificationRequest(
            identifier: GateConstants.unlockNotificationIdentifier(for: requestID),
            content: content,
            trigger: trigger
        )

        center.getNotificationSettings { settings in
            let unavailable: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                unavailable = false
            case .notDetermined, .denied:
                unavailable = true
            @unknown default:
                unavailable = true
            }
            UserDefaults(suiteName: AppGroup.identifier)?.set(
                unavailable,
                forKey: GateConstants.notificationUnavailableDefaultsKey
            )

            center.add(request) { _ in
                completion.finish(response)
            }
        }
    }

    /// ゲート控えの各blobを独立に復号し、壊れた1件は飛ばして有効な選択を照合する。
    private func containsGateApplication(
        _ application: ApplicationToken,
        in selectionDataList: [Data]
    ) -> Bool {
        for selectionData in selectionDataList {
            guard let selection = try? decoder.decode(
                FamilyActivitySelection.self,
                from: selectionData
            ) else {
                continue
            }
            if selection.applicationTokens.contains(application) {
                return true
            }
        }
        return false
    }

    /// 「開かない」はアプリ本体を経由しないため、同じSQLiteへ直接記録する。
    /// トークンを持つルールが見つからない・読み書きに失敗した場合は記録せず閉じる。
    private func recordCancelledAttempt(for application: ApplicationToken) {
        do {
            let snapshotStore = JSONSnapshotStore()
            guard let ruleID = try matchingRuleID(
                for: application,
                snapshotStore: snapshotStore
            ) else {
                return
            }

            let now = Date()
            let logStore = try SQLiteLogStore()
            let priorCount = try logStore
                .fetchAttempts(from: now.addingTimeInterval(-86_400), to: now)
                .filter { $0.ruleId == ruleID }
                .count
            try logStore.insert(
                AttemptLog(
                    id: UUID(),
                    ruleId: ruleID,
                    startedAt: now,
                    completedAt: now,
                    decision: .cancelled,
                    intent: nil,
                    selectedDurationSeconds: nil,
                    attemptCount24h: priorCount + 1,
                    opened: false
                )
            )
        } catch {
            return
        }
    }

    private func matchingRuleID(
        for application: ApplicationToken,
        snapshotStore: JSONSnapshotStore
    ) throws -> UUID? {
        for rule in try RuleStore(snapshotStore: snapshotStore).allRules() {
            guard !rule.activitySelectionData.isEmpty else {
                continue
            }
            guard let selection = try? decoder.decode(
                FamilyActivitySelection.self,
                from: rule.activitySelectionData
            ) else {
                continue
            }
            if selection.applicationTokens.contains(application) {
                return rule.id
            }
        }
        return nil
    }

    private func isDeepFocusActive(
        application: ApplicationToken,
        snapshot: DeepFocusShieldSnapshot?,
        now: Date,
        calendar: Calendar
    ) throws -> Bool {
        guard let snapshot,
              DeepFocusWindowPolicy.isWindowActive(
                now: now,
                snapshot: snapshot,
                calendar: calendar
              ) else {
            return false
        }
        return try contains(application, in: snapshot.selectionDataList)
    }

    private func isNightActive(
        application: ApplicationToken,
        snapshot: NightShieldSnapshot?,
        now: Date,
        calendar: Calendar
    ) throws -> Bool {
        guard let snapshot,
              NightWindowPolicy.isNight(
                now: now,
                snapshot: snapshot,
                calendar: calendar
              ) else {
            return false
        }
        return try contains(application, in: snapshot.selectionDataList)
    }

    private func contains(
        _ application: ApplicationToken,
        in selectionDataList: [Data]
    ) throws -> Bool {
        for selectionData in selectionDataList {
            let selection = try decoder.decode(
                FamilyActivitySelection.self,
                from: selectionData
            )
            if selection.applicationTokens.contains(application) {
                return true
            }
        }
        return false
    }
}

/// UserNotificationsのどのcallbackが返らなくても2秒で応答し、遅着callbackとの二重完了を防ぐ。
private final class SingleShotShieldActionCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var didFinish = false
    private let completionHandler: (ShieldActionResponse) -> Void

    init(_ completionHandler: @escaping (ShieldActionResponse) -> Void) {
        self.completionHandler = completionHandler
    }

    func finish(_ response: ShieldActionResponse) {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        didFinish = true
        lock.unlock()
        completionHandler(response)
    }
}
