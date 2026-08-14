import ActivityKit
import DopaBreakCore
import Foundation
import UserNotifications
import WidgetKit

@MainActor
final class LockSurfaceCoordinator {
    /// Live Activityへ載せる目標の上限（ロック画面で読める件数＝ContentStateの4KB対策）。
    static let liveActivityGoalLimit = 3

    // 識別子はCoreのNotificationIdentifierを正本にする（取り消しと通知タップのルーティングで
    // 同じ文字列を参照するため、アプリ側に二重定義を持たない）。
    static let morningNotificationIdentifier = NotificationIdentifier.morning
    static let weeklyNotificationIdentifier = NotificationIdentifier.weekly
    static let d1ActivationNotificationIdentifier = NotificationIdentifier.d1Activation
    static let d3ActivationNotificationIdentifier = NotificationIdentifier.d3Activation
    static let d7InactiveNotificationIdentifier = NotificationIdentifier.d7Inactive
    static let trialDay5NotificationIdentifier = NotificationIdentifier.trialDay5
    static let month1ReportNotificationIdentifier = NotificationIdentifier.month1Report
    static let freeMonthlyReportNotificationIdentifiers = NotificationIdentifier.freeMonthlyReports
    static let month12RenewalNotificationIdentifier = NotificationIdentifier.month12Renewal
    static let annualUpgradeOfferNotificationIdentifier = NotificationIdentifier.annualUpgradeOffer
    static let cancelSaveNotificationIdentifier = NotificationIdentifier.cancelSave
    private static let legacyNotificationIdentifiers = NotificationIdentifier.legacyIdentifiers

    /// 予約が実際に成立した一回きりの通知。呼び出し側が送信済みマーカーを永続化するために使う。
    /// 追加が失敗したときは呼ばれないため、権限がない端末でマーカーだけ立つことがない。
    enum ScheduledOneShotNotification: Equatable {
        case annualUpgradeOffer(fireDate: Date)
        case cancelSave(fireDate: Date, expirationDate: Date)
    }

    private let notificationCenter: UNUserNotificationCenter
    private var notificationTask: Task<Void, Never>?
    private var notificationGeneration = 0
    private var invalidatedNotificationIdentifiers: Set<String> = []
    private var liveActivityTask: Task<Void, Never>?
    private var liveActivityGeneration = 0

    /// 一回きりの通知を予約できたときに呼ぶ。
    var onOneShotNotificationScheduled: ((ScheduledOneShotNotification) -> Void)?

    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    @discardableResult
    func rescheduleNotifications(
        goals: [Goal],
        state: LockSurfaceState,
        weeklySummary: WeeklySummary?,
        retentionNotifications: RetentionNotificationSchedules,
        hasConfirmedEntitlement: Bool,
        firstLaunchDate: Date?,
        verifiedAutomationCatalogIDs: [String],
        totalInterventionAttempts: Int,
        now: Date
    ) -> Task<Void, Never> {
        invalidatedNotificationIdentifiers.removeAll()
        let precedingTask = notificationTask
        notificationGeneration += 1
        let generation = notificationGeneration
        let task = Task { @MainActor [weak self] in
            await precedingTask?.value
            guard let self else {
                return
            }
            if !Task.isCancelled,
               self.notificationGeneration == generation {
                await self.performNotificationReschedule(
                    goals: goals,
                    state: state,
                    weeklySummary: weeklySummary,
                    retentionNotifications: retentionNotifications,
                    hasConfirmedEntitlement: hasConfirmedEntitlement,
                    firstLaunchDate: firstLaunchDate,
                    verifiedAutomationCatalogIDs: verifiedAutomationCatalogIDs,
                    totalInterventionAttempts: totalInterventionAttempts,
                    now: now,
                    generation: generation
                )
            }
            if self.notificationGeneration == generation {
                self.notificationTask = nil
            }
        }
        notificationTask = task
        return task
    }

    func cancelAllNotifications() {
        notificationGeneration += 1
        invalidatedNotificationIdentifiers = Set(allNotificationIdentifiers)
        notificationTask?.cancel()
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }

    /// オートメーションの検収が済んだ瞬間に、D1・D3の「まだ設定できていませんか」を取り消す。
    /// 進行中の再スケジュールが後から積み直さないよう、無効化集合にも入れる。
    func cancelActivationNotifications() {
        let identifiers = [
            Self.d1ActivationNotificationIdentifier,
            Self.d3ActivationNotificationIdentifier
        ]
        invalidatedNotificationIdentifiers.formUnion(identifiers)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func waitForNotificationReschedule() async {
        await notificationTask?.value
    }

    private func performNotificationReschedule(
        goals: [Goal],
        state: LockSurfaceState,
        weeklySummary: WeeklySummary?,
        retentionNotifications: RetentionNotificationSchedules,
        hasConfirmedEntitlement: Bool,
        firstLaunchDate: Date?,
        verifiedAutomationCatalogIDs: [String],
        totalInterventionAttempts: Int,
        now: Date,
        generation: Int
    ) async {
        let identifiers = Self.removableNotificationIdentifiers(
            hasConfirmedEntitlement: hasConfirmedEntitlement,
            planNotificationsEnabled: state.planNotificationsEnabled,
            retentionSupportNotificationsEnabled: state.retentionSupportNotificationsEnabled
        )
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: Self.legacyNotificationIdentifiers
        )
        notificationCenter.removeDeliveredNotifications(
            withIdentifiers: Self.legacyNotificationIdentifiers
        )

        let settings = await notificationCenter.notificationSettings()
        guard isNotificationRescheduleCurrent(generation: generation) else {
            return
        }
        guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else {
            return
        }

        let calendar = Calendar.current
        let hour = state.morningNotificationTime.hour ?? 7
        let minute = state.morningNotificationTime.minute ?? 0
        let titles = goals.map(\.title)

        if state.morningNotificationEnabled, !titles.isEmpty {
            let content = UNMutableNotificationContent()
            content.title = String(
                localized: "lock_surface.notification.morning.title",
                defaultValue: "目標"
            )
            content.body = titles.joined(
                separator: String(
                    localized: "lock_surface.notification.morning.goal_separator",
                    defaultValue: "・"
                )
            )
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: hour, minute: minute),
                repeats: true
            )
            try? await notificationCenter.add(
                UNNotificationRequest(
                    identifier: Self.morningNotificationIdentifier,
                    content: content,
                    trigger: trigger
                )
            )
            guard isNotificationRescheduleCurrent(generation: generation) else {
                return
            }
        }

        if state.weeklyReportEnabled,
           let weeklySummary,
           weeklySummary.attempts > 0 {
            let content = UNMutableNotificationContent()
            content.title = String(
                localized: "lock_surface.notification.weekly.title",
                defaultValue: "今週のふりかえり"
            )
            content.body = String(
                localized: "lock_surface.notification.weekly.body",
                defaultValue: "開かなかった \(weeklySummary.cancelled)回 / 開こうとした \(weeklySummary.attempts)回"
            )
            content.sound = .default
            let weeklyTotalMinutes = hour * 60 + minute + 30
            let weeklyMinutes = weeklyTotalMinutes % (24 * 60)
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(
                    hour: weeklyMinutes / 60,
                    minute: weeklyMinutes % 60,
                    weekday: weeklyTotalMinutes >= 24 * 60 ? 3 : 2
                ),
                repeats: false
            )
            try? await notificationCenter.add(
                UNNotificationRequest(
                    identifier: Self.weeklyNotificationIdentifier,
                    content: content,
                    trigger: trigger
                )
            )
            guard isNotificationRescheduleCurrent(generation: generation) else { return }
        }

        if hasConfirmedEntitlement,
           state.planNotificationsEnabled,
           let trialDay5 = retentionNotifications.trialDay5,
           let fireDate = futureQuietHoursFireDate(
               for: trialDay5.fireDate,
               now: now,
               calendar: calendar
           ) {
            let content = UNMutableNotificationContent()
            content.title = String(
                localized: "lock_surface.notification.trial_day5.title",
                defaultValue: "無料期間はあと2日です"
            )
            if trialDay5.cancelledCount > 0 {
                content.body = String(
                    localized: "lock_surface.notification.trial_day5.body_with_count",
                    defaultValue: "ここまでに開かなかった \(trialDay5.cancelledCount)回。7日目に年額プランへ切り替わります。解約はいつでもできます。"
                )
            } else {
                content.body = String(
                    localized: "lock_surface.notification.trial_day5.body",
                    defaultValue: "7日目に年額プランへ切り替わります。解約はいつでもできます。"
                )
            }
            content.sound = .default
            try? await notificationCenter.add(
                UNNotificationRequest(
                    identifier: Self.trialDay5NotificationIdentifier,
                    content: content,
                    trigger: oneShotTrigger(for: fireDate)
                )
            )
            guard isNotificationRescheduleCurrent(generation: generation) else { return }
        }

        if hasConfirmedEntitlement,
           state.planNotificationsEnabled,
           let month1 = retentionNotifications.month1,
           let fireDate = futureQuietHoursFireDate(
               for: month1.fireDate,
               now: now,
               calendar: calendar
           ) {
            let content = UNMutableNotificationContent()
            if month1.isFirstMonthlyReport {
                content.title = String(
                    localized: "lock_surface.notification.month1.title",
                    defaultValue: "この1ヶ月のふりかえり"
                )
            } else {
                content.title = String(
                    localized: "lock_surface.notification.monthly.title",
                    defaultValue: "今月のふりかえり"
                )
            }
            content.body = String(
                localized: "lock_surface.notification.month1.body",
                defaultValue: "開かなかった \(month1.cancelledCount)回 / 開こうとした \(month1.attemptCount)回"
            )
            content.sound = .default
            try? await notificationCenter.add(
                UNNotificationRequest(
                    identifier: Self.month1ReportNotificationIdentifier,
                    content: content,
                    trigger: oneShotTrigger(for: fireDate)
                )
            )
            guard isNotificationRescheduleCurrent(generation: generation) else { return }
        }

        if hasConfirmedEntitlement,
           state.retentionSupportNotificationsEnabled {
            for (identifier, freeMonthly) in zip(
                Self.freeMonthlyReportNotificationIdentifiers,
                retentionNotifications.freeMonthlyReports
            ) {
                guard let fireDate = futureQuietHoursFireDate(
                    for: freeMonthly.fireDate,
                    now: now,
                    calendar: calendar
                ) else {
                    continue
                }
                let content = UNMutableNotificationContent()
                content.title = String(
                    localized: "lock_surface.notification.monthly.title",
                    defaultValue: "今月のふりかえり"
                )
                switch freeMonthly.body {
                case .counts(let cancelled, let attempts):
                    content.body = String(
                        localized: "lock_surface.notification.month1.body",
                        defaultValue: "開かなかった \(cancelled)回 / 開こうとした \(attempts)回"
                    )
                case .fixed:
                    content.body = String(
                        localized: "lock_surface.notification.free_monthly.fixed_body",
                        defaultValue: "この1ヶ月の記録がまとまりました"
                    )
                }
                content.sound = .default
                try? await notificationCenter.add(
                    UNNotificationRequest(
                        identifier: identifier,
                        content: content,
                        trigger: oneShotTrigger(for: fireDate)
                    )
                )
                guard isNotificationRescheduleCurrent(generation: generation) else { return }
            }
        }

        if hasConfirmedEntitlement,
           state.planNotificationsEnabled,
           let month12 = retentionNotifications.month12,
           let fireDate = futureQuietHoursFireDate(
               for: month12.fireDate,
               now: now,
               calendar: calendar
           ) {
            let content = UNMutableNotificationContent()
            content.title = String(
                localized: "lock_surface.notification.month12.title",
                defaultValue: "まもなく1年の更新です"
            )
            content.body = String(
                localized: "lock_surface.notification.month12.body",
                defaultValue: "この1年で開かなかった \(month12.cancelledCount)回。更新の確認はApp Storeの設定からできます。"
            )
            content.sound = .default
            try? await notificationCenter.add(
                UNNotificationRequest(
                    identifier: Self.month12RenewalNotificationIdentifier,
                    content: content,
                    trigger: oneShotTrigger(for: fireDate)
                )
            )
            guard isNotificationRescheduleCurrent(generation: generation) else { return }
        }

        if hasConfirmedEntitlement,
           state.planNotificationsEnabled,
           let annualOffer = retentionNotifications.annualUpgradeOffer,
           let fireDate = futureQuietHoursFireDate(
               for: annualOffer.fireDate,
               now: now,
               calendar: calendar
           ) {
            let content = UNMutableNotificationContent()
            content.title = String(
                localized: "lock_surface.notification.annual_offer.title",
                defaultValue: "3ヶ月続きました"
            )
            content.body = String(
                localized: "lock_surface.notification.annual_offer.body",
                defaultValue: "ここまで開かなかった\(annualOffer.cancelledCount)回。年額プランなら月あたりの負担が下がります"
            )
            content.sound = .default
            let trigger = oneShotTrigger(for: fireDate)
            let didSchedule = await addNotificationRequest(
                UNNotificationRequest(
                    identifier: Self.annualUpgradeOfferNotificationIdentifier,
                    content: content,
                    trigger: trigger
                )
            )
            guard isNotificationRescheduleCurrent(generation: generation) else { return }
            // ここへ来るまでのawaitで発火時刻を跨ぐと、過去日時のトリガーになり二度と発火しない。
            // それでマーカーを立てると一生に1回の機会を使い切るため、発火予定が残る時だけ記録する。
            if didSchedule, trigger.nextTriggerDate() != nil {
                onOneShotNotificationScheduled?(.annualUpgradeOffer(fireDate: fireDate))
            }
        }

        if hasConfirmedEntitlement,
           state.planNotificationsEnabled,
           let cancelSave = retentionNotifications.cancelSave,
           let fireDate = futureQuietHoursFireDate(
               for: cancelSave.fireDate,
               now: now,
               calendar: calendar
           ) {
            let content = UNMutableNotificationContent()
            content.title = String(
                localized: "lock_surface.notification.cancel_save.title",
                defaultValue: "あと3日で終了します"
            )
            content.body = String(
                localized: "lock_surface.notification.cancel_save.body",
                defaultValue: "ここまで開かなかった\(cancelSave.cancelledCount)回。このまま続けるかは期限までに選べます"
            )
            content.sound = .default
            let didSchedule = await addNotificationRequest(
                UNNotificationRequest(
                    identifier: Self.cancelSaveNotificationIdentifier,
                    content: content,
                    trigger: oneShotTrigger(for: fireDate)
                )
            )
            guard isNotificationRescheduleCurrent(generation: generation) else { return }
            if didSchedule {
                onOneShotNotificationScheduled?(
                    .cancelSave(
                        fireDate: fireDate,
                        expirationDate: cancelSave.expirationDate
                    )
                )
            }
        }

        if !invalidatedNotificationIdentifiers.contains(Self.d1ActivationNotificationIdentifier),
           let fireDate = ActivationNotificationPolicy.d1FireDate(
               firstLaunchDate: firstLaunchDate,
               isEnabled: state.retentionSupportNotificationsEnabled,
               verifiedAutomationCatalogIDs: verifiedAutomationCatalogIDs,
               now: now,
               calendar: calendar
           ) {
            let content = UNMutableNotificationContent()
            content.title = String(
                localized: "lock_surface.notification.activation.title",
                defaultValue: "一呼吸の設定は終わっていますか"
            )
            content.body = String(
                localized: "lock_surface.notification.activation.body",
                defaultValue: "対象アプリを開いたときに一呼吸が出れば設定完了です。設定はアプリからいつでも確認できます。"
            )
            content.sound = .default
            try? await notificationCenter.add(
                UNNotificationRequest(
                    identifier: Self.d1ActivationNotificationIdentifier,
                    content: content,
                    trigger: oneShotTrigger(for: fireDate)
                )
            )
            // 待っている間に検収された場合、いま積んだ予約を取り除く。
            // この後のD3/D7の判定は続行する（D3は無効化集合で自然に落ちる）。
            if invalidatedNotificationIdentifiers.contains(Self.d1ActivationNotificationIdentifier) {
                removeInvalidatedNotificationRequests()
            } else {
                guard isNotificationRescheduleCurrent(generation: generation) else { return }
            }
        }

        // D3再挑戦（docs/18 §2c）。D1と同じ未検収条件で、検収されたら次の再スケジュールで消える。
        if !invalidatedNotificationIdentifiers.contains(Self.d3ActivationNotificationIdentifier),
           let fireDate = ActivationNotificationPolicy.d3FireDate(
               firstLaunchDate: firstLaunchDate,
               isEnabled: state.retentionSupportNotificationsEnabled,
               verifiedAutomationCatalogIDs: verifiedAutomationCatalogIDs,
               now: now,
               calendar: calendar
           ) {
            let content = UNMutableNotificationContent()
            content.title = String(
                localized: "lock_surface.notification.d3.title",
                defaultValue: "設定は動画を見ながら3分で終わります"
            )
            content.body = String(
                localized: "lock_surface.notification.d3.body",
                defaultValue: "対象アプリを開いたとき一呼吸が出れば完了です"
            )
            content.sound = .default
            try? await notificationCenter.add(
                UNNotificationRequest(
                    identifier: Self.d3ActivationNotificationIdentifier,
                    content: content,
                    trigger: oneShotTrigger(for: fireDate)
                )
            )
            if invalidatedNotificationIdentifiers.contains(Self.d3ActivationNotificationIdentifier) {
                removeInvalidatedNotificationRequests()
            } else {
                guard isNotificationRescheduleCurrent(generation: generation) else { return }
            }
        }

        // D7未活性フォールバック（docs/18 §2d）。
        // ローカル通知は予約時点の内容で確定し、発火時に条件を再評価する仕組みがiOSにない。
        // そのため「予約時に試行0件か」で判定し、試行が1件でも入った後の再スケジュールで
        // pendingを積み直さないことが唯一の取り消し経路になる。
        // 週次ふりかえり（直近7日のattempts>0が条件）とは条件が背反のため同時には出ない。
        if let fireDate = ActivationNotificationPolicy.d7FireDate(
            firstLaunchDate: firstLaunchDate,
            isEnabled: state.retentionSupportNotificationsEnabled,
            totalInterventionAttempts: totalInterventionAttempts,
            now: now,
            calendar: calendar
        ) {
            let content = UNMutableNotificationContent()
            content.title = String(
                localized: "lock_surface.notification.d7.title",
                defaultValue: "この1週間 一呼吸は出ていません"
            )
            content.body = String(
                localized: "lock_surface.notification.d7.body",
                defaultValue: "対象アプリの選び直しはいつでもできます。1つのアプリから試せます"
            )
            content.sound = .default
            try? await notificationCenter.add(
                UNNotificationRequest(
                    identifier: Self.d7InactiveNotificationIdentifier,
                    content: content,
                    trigger: oneShotTrigger(for: fireDate)
                )
            )
            guard isNotificationRescheduleCurrent(generation: generation) else { return }
        }
    }

    /// 追加に成功したかを返す。成功したときだけ送信済みマーカーを立てるために使う。
    private func addNotificationRequest(_ request: UNNotificationRequest) async -> Bool {
        do {
            try await notificationCenter.add(request)
            return true
        } catch {
            return false
        }
    }

    private static let nonEntitlementNotificationIdentifiers = [
        LockSurfaceCoordinator.morningNotificationIdentifier,
        LockSurfaceCoordinator.weeklyNotificationIdentifier,
        LockSurfaceCoordinator.d1ActivationNotificationIdentifier,
        LockSurfaceCoordinator.d3ActivationNotificationIdentifier,
        LockSurfaceCoordinator.d7InactiveNotificationIdentifier
    ]

    /// 「プラン通知」トグルで出し分ける通知。
    private static let planNotificationIdentifiers = [
        LockSurfaceCoordinator.trialDay5NotificationIdentifier,
        LockSurfaceCoordinator.month1ReportNotificationIdentifier,
        LockSurfaceCoordinator.month12RenewalNotificationIdentifier,
        LockSurfaceCoordinator.annualUpgradeOfferNotificationIdentifier,
        LockSurfaceCoordinator.cancelSaveNotificationIdentifier
    ]

    /// 「継続サポート」トグルで出し分ける通知。
    private static let retentionSupportNotificationIdentifiers =
        LockSurfaceCoordinator.freeMonthlyReportNotificationIdentifiers

    private static let entitlementNotificationIdentifiers =
        LockSurfaceCoordinator.planNotificationIdentifiers
            + LockSurfaceCoordinator.retentionSupportNotificationIdentifiers

    /// この再スケジュールで取り消す識別子。
    ///
    /// 権利が確定するまでは、権利に紐づく通知を消して無料向けに積み直すことはしない
    /// （取得に失敗しただけの課金者の予約を消してしまうため）。
    /// ただし**ユーザーが自分でオフにした通知の取り消しは確定を待たない**。
    /// 待つと、オフラインのProがトグルをオフにしても既存の予約が届き続ける。
    private static func removableNotificationIdentifiers(
        hasConfirmedEntitlement: Bool,
        planNotificationsEnabled: Bool,
        retentionSupportNotificationsEnabled: Bool
    ) -> [String] {
        guard !hasConfirmedEntitlement else {
            return nonEntitlementNotificationIdentifiers + entitlementNotificationIdentifiers
        }

        var identifiers = nonEntitlementNotificationIdentifiers
        if !planNotificationsEnabled {
            identifiers += planNotificationIdentifiers
        }
        if !retentionSupportNotificationsEnabled {
            identifiers += retentionSupportNotificationIdentifiers
        }
        return identifiers
    }

    private var allNotificationIdentifiers: [String] {
        Self.nonEntitlementNotificationIdentifiers + Self.entitlementNotificationIdentifiers
    }

    private func isNotificationRescheduleCurrent(generation: Int) -> Bool {
        guard !Task.isCancelled,
              notificationGeneration == generation else {
            removeInvalidatedNotificationRequests()
            return false
        }
        return true
    }

    private func removeInvalidatedNotificationRequests() {
        guard !invalidatedNotificationIdentifiers.isEmpty else {
            return
        }
        let identifiers = Array(invalidatedNotificationIdentifiers)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    /// 端末側でLive Activityが許可されているか（設定 > アプリ > ライブアクティビティ）。
    /// ユーザーがロック画面の確認プロンプトで「許可しない」を選ぶとfalseになる。
    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// いまロック画面に掲出中のActivityがあるか。
    var isLiveActivityRunning: Bool {
        !Activity<DopaBreakActivityAttributes>.activities.isEmpty
    }

    func refreshLiveActivity(
        goals: [Goal],
        state: LockSurfaceState,
        todayCancelledCount: Int,
        todayAttemptCount: Int,
        restart: Bool
    ) async {
        let precedingTask = liveActivityTask
        liveActivityGeneration += 1
        let generation = liveActivityGeneration
        let task = Task { @MainActor [weak self] in
            await precedingTask?.value
            guard let self else { return }
            await self.performLiveActivityRefresh(
                goals: goals,
                state: state,
                todayCancelledCount: todayCancelledCount,
                todayAttemptCount: todayAttemptCount,
                restart: restart
            )
        }
        liveActivityTask = task
        await task.value
        if liveActivityGeneration == generation {
            liveActivityTask = nil
        }
    }

    private func performLiveActivityRefresh(
        goals: [Goal],
        state: LockSurfaceState,
        todayCancelledCount: Int,
        todayAttemptCount: Int,
        restart: Bool
    ) async {
        guard state.liveActivityEnabled else {
            await endAllActivities()
            return
        }

        // ActivityKitのContentStateは4KB制限がある。Proは目標数が無制限のため、
        // ロック画面で実際に読める件数へ丸めてから渡す（超過するとrequest/updateが黙って失敗する）。
        let goalTitles = goals.prefix(Self.liveActivityGoalLimit).map { goal in
            let short = goal.lockScreenTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            return short.flatMap { $0.isEmpty ? nil : $0 } ?? goal.title
        }
        guard !goalTitles.isEmpty, ActivityAuthorizationInfo().areActivitiesEnabled else {
            await endAllActivities()
            return
        }

        let contentState = DopaBreakActivityAttributes.ContentState(
            goalTitles: goalTitles,
            todayCancelledCount: todayCancelledCount,
            todayAttemptCount: todayAttemptCount,
            themeRawValue: state.theme.rawValue
        )
        let content = ActivityContent(state: contentState, staleDate: nil)

        if restart {
            // A Live Activity cannot run beyond eight hours. Recreating only when the app
            // returns to foreground resets that window without churn on every intervention.
            await endAllActivities()
            _ = try? Activity<DopaBreakActivityAttributes>.request(
                attributes: DopaBreakActivityAttributes(),
                content: content,
                pushType: nil
            )
            await endDuplicateActivities()
        } else if let current = Activity<DopaBreakActivityAttributes>.activities.first {
            await current.update(content)
            await endDuplicateActivities()
        } else {
            _ = try? Activity<DopaBreakActivityAttributes>.request(
                attributes: DopaBreakActivityAttributes(),
                content: content,
                pushType: nil
            )
            await endDuplicateActivities()
        }
    }

    func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: "DopaBreakHome")
    }

    private func endAllActivities() async {
        for activity in Activity<DopaBreakActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func endDuplicateActivities() async {
        for duplicate in Activity<DopaBreakActivityAttributes>.activities.dropFirst() {
            await duplicate.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func futureQuietHoursFireDate(
        for candidate: Date,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        NotificationQuietHours.futureFireDate(
            for: candidate,
            now: now,
            calendar: calendar
        )
    }

    private func oneShotTrigger(for date: Date) -> UNCalendarNotificationTrigger {
        var components = Calendar(identifier: .gregorian).dateComponents(
            [.era, .year, .month, .day, .hour, .minute, .second],
            from: date
        )
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .current
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
}

struct RetentionNotificationSchedules {
    let trialDay5: RetentionNotificationSchedule?
    let month1: RetentionNotificationSchedule?
    let month12: RetentionNotificationSchedule?
    let freeMonthlyReports: [FreeMonthlyReportNotificationSchedule]
    let annualUpgradeOffer: RetentionNotificationSchedule?
    let cancelSave: CancelSaveNotificationSchedule?

    init(
        trialDay5: RetentionNotificationSchedule?,
        month1: RetentionNotificationSchedule?,
        month12: RetentionNotificationSchedule?,
        freeMonthlyReports: [FreeMonthlyReportNotificationSchedule] = [],
        annualUpgradeOffer: RetentionNotificationSchedule? = nil,
        cancelSave: CancelSaveNotificationSchedule? = nil
    ) {
        self.trialDay5 = trialDay5
        self.month1 = month1
        self.month12 = month12
        self.freeMonthlyReports = freeMonthlyReports
        self.annualUpgradeOffer = annualUpgradeOffer
        self.cancelSave = cancelSave
    }

    static let empty = RetentionNotificationSchedules(
        trialDay5: nil,
        month1: nil,
        month12: nil
    )
}

/// 解約セーブ通知は、送信済みマーカーを請求期間の期限日で持つため期限日も一緒に運ぶ。
struct CancelSaveNotificationSchedule {
    let fireDate: Date
    let cancelledCount: Int
    let expirationDate: Date
}

struct RetentionNotificationSchedule {
    let fireDate: Date
    let cancelledCount: Int
    let attemptCount: Int
    let isFirstMonthlyReport: Bool

    init(
        fireDate: Date,
        cancelledCount: Int,
        attemptCount: Int,
        isFirstMonthlyReport: Bool = false
    ) {
        self.fireDate = fireDate
        self.cancelledCount = cancelledCount
        self.attemptCount = attemptCount
        self.isFirstMonthlyReport = isFirstMonthlyReport
    }
}
