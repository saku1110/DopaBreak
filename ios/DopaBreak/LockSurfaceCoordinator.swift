import ActivityKit
import DopaBreakCore
import Foundation
import UserNotifications
import WidgetKit

@MainActor
final class LockSurfaceCoordinator {
    static let morningNotificationIdentifier = "dopabreak.lock.morning"
    static let weeklyNotificationIdentifier = "dopabreak.lock.weekly"
    static let day14WarningNotificationIdentifier = "dopabreak.day14warning"
    static let d1ActivationNotificationIdentifier = "dopabreak.d1activation"
    static let trialDay5NotificationIdentifier = "dopabreak.trialday5"
    static let month1ReportNotificationIdentifier = "dopabreak.month1report"
    static let month12RenewalNotificationIdentifier = "dopabreak.month12renewal"

    private let notificationCenter: UNUserNotificationCenter
    private var notificationTask: Task<Void, Never>?
    private var notificationGeneration = 0
    private var invalidatedNotificationIdentifiers: Set<String> = []
    private var liveActivityTask: Task<Void, Never>?
    private var liveActivityGeneration = 0

    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    @discardableResult
    func rescheduleNotifications(
        goals: [Goal],
        state: LockSurfaceState,
        weeklySummary: WeeklySummary?,
        day14Warning: Day14WarningSchedule?,
        retentionNotifications: RetentionNotificationSchedules,
        firstLaunchDate: Date?,
        verifiedAutomationCatalogIDs: [String],
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
                    day14Warning: day14Warning,
                    retentionNotifications: retentionNotifications,
                    firstLaunchDate: firstLaunchDate,
                    verifiedAutomationCatalogIDs: verifiedAutomationCatalogIDs,
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

    func cancelD1ActivationNotification() {
        invalidatedNotificationIdentifiers.insert(Self.d1ActivationNotificationIdentifier)
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [Self.d1ActivationNotificationIdentifier]
        )
        notificationCenter.removeDeliveredNotifications(
            withIdentifiers: [Self.d1ActivationNotificationIdentifier]
        )
    }

    func waitForNotificationReschedule() async {
        await notificationTask?.value
    }

    private func performNotificationReschedule(
        goals: [Goal],
        state: LockSurfaceState,
        weeklySummary: WeeklySummary?,
        day14Warning: Day14WarningSchedule?,
        retentionNotifications: RetentionNotificationSchedules,
        firstLaunchDate: Date?,
        verifiedAutomationCatalogIDs: [String],
        now: Date,
        generation: Int
    ) async {
        let identifiers = allNotificationIdentifiers
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)

        let settings = await notificationCenter.notificationSettings()
        guard isNotificationRescheduleCurrent(generation: generation) else {
            return
        }
        guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else {
            return
        }

        let hour = state.morningNotificationTime.hour ?? 7
        let minute = state.morningNotificationTime.minute ?? 0
        let titles = goals.map(\.title)

        if state.morningNotificationEnabled, !titles.isEmpty {
            let content = UNMutableNotificationContent()
            content.title = String(
                localized: "lock_surface.notification.morning.title",
                defaultValue: "今日の戻る先"
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
                defaultValue: "開かずに戻れた \(weeklySummary.cancelled)回 / 開こうとした \(weeklySummary.attempts)回"
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

        if let day14Warning {
            let content = UNMutableNotificationContent()
            content.title = String(
                localized: "lock_surface.notification.day14_warning.title",
                defaultValue: "止めるアプリが あと2日で1つになります"
            )
            if day14Warning.cancelledCount > 0 {
                content.body = String(
                    localized: "lock_surface.notification.day14_warning.body_with_count",
                    defaultValue: "この2週間で開かずに戻れた \(day14Warning.cancelledCount)回。14日が終わると、止めるアプリは1つになります。残す1つを選ぶか、Proでそのまま続けるかを選べます。"
                )
            } else {
                content.body = String(
                    localized: "lock_surface.notification.day14_warning.body",
                    defaultValue: "14日が終わると、止めるアプリは1つになります。残す1つを選ぶか、Proでそのまま続けるかを選べます。"
                )
            }
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: day14Warning.fireDate
                ),
                repeats: false
            )
            try? await notificationCenter.add(
                UNNotificationRequest(
                    identifier: Self.day14WarningNotificationIdentifier,
                    content: content,
                    trigger: trigger
                )
            )
            guard isNotificationRescheduleCurrent(generation: generation) else { return }
        }

        if let trialDay5 = retentionNotifications.trialDay5 {
            let content = UNMutableNotificationContent()
            content.title = String(
                localized: "lock_surface.notification.trial_day5.title",
                defaultValue: "無料期間はあと2日です"
            )
            if trialDay5.cancelledCount > 0 {
                content.body = String(
                    localized: "lock_surface.notification.trial_day5.body_with_count",
                    defaultValue: "ここまでに開かずに戻れた \(trialDay5.cancelledCount)回。7日目に年額プランへ切り替わります。解約はいつでもできます。"
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
                    trigger: oneShotTrigger(for: trialDay5.fireDate)
                )
            )
            guard isNotificationRescheduleCurrent(generation: generation) else { return }
        }

        if let month1 = retentionNotifications.month1 {
            let content = UNMutableNotificationContent()
            content.title = String(
                localized: "lock_surface.notification.month1.title",
                defaultValue: "この1ヶ月のふりかえり"
            )
            content.body = String(
                localized: "lock_surface.notification.month1.body",
                defaultValue: "開かずに戻れた \(month1.cancelledCount)回 / 開こうとした \(month1.attemptCount)回"
            )
            content.sound = .default
            try? await notificationCenter.add(
                UNNotificationRequest(
                    identifier: Self.month1ReportNotificationIdentifier,
                    content: content,
                    trigger: oneShotTrigger(for: month1.fireDate)
                )
            )
            guard isNotificationRescheduleCurrent(generation: generation) else { return }
        }

        if let month12 = retentionNotifications.month12 {
            let content = UNMutableNotificationContent()
            content.title = String(
                localized: "lock_surface.notification.month12.title",
                defaultValue: "まもなく1年の更新です"
            )
            content.body = String(
                localized: "lock_surface.notification.month12.body",
                defaultValue: "この1年で開かずに戻れた \(month12.cancelledCount)回。更新の確認はApp Storeの設定からできます。"
            )
            content.sound = .default
            try? await notificationCenter.add(
                UNNotificationRequest(
                    identifier: Self.month12RenewalNotificationIdentifier,
                    content: content,
                    trigger: oneShotTrigger(for: month12.fireDate)
                )
            )
            guard isNotificationRescheduleCurrent(generation: generation) else { return }
        }

        if !invalidatedNotificationIdentifiers.contains(Self.d1ActivationNotificationIdentifier),
           verifiedAutomationCatalogIDs.isEmpty,
           let firstLaunchDate {
            let fireDate = firstLaunchDate.addingTimeInterval(24 * 60 * 60)
            guard fireDate > now else {
                return
            }
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
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: fireDate
                ),
                repeats: false
            )
            try? await notificationCenter.add(
                UNNotificationRequest(
                    identifier: Self.d1ActivationNotificationIdentifier,
                    content: content,
                    trigger: trigger
                )
            )
            guard !invalidatedNotificationIdentifiers.contains(
                Self.d1ActivationNotificationIdentifier
            ) else {
                removeInvalidatedNotificationRequests()
                return
            }
            guard isNotificationRescheduleCurrent(generation: generation) else { return }
        }
    }

    private var allNotificationIdentifiers: [String] {
        [
            Self.morningNotificationIdentifier,
            Self.weeklyNotificationIdentifier,
            Self.day14WarningNotificationIdentifier,
            Self.d1ActivationNotificationIdentifier,
            Self.trialDay5NotificationIdentifier,
            Self.month1ReportNotificationIdentifier,
            Self.month12RenewalNotificationIdentifier
        ]
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

        let goalTitles = goals.map { goal in
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

    private func oneShotTrigger(for date: Date) -> UNCalendarNotificationTrigger {
        UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: date
            ),
            repeats: false
        )
    }
}

struct RetentionNotificationSchedules {
    let trialDay5: RetentionNotificationSchedule?
    let month1: RetentionNotificationSchedule?
    let month12: RetentionNotificationSchedule?

    static let empty = RetentionNotificationSchedules(
        trialDay5: nil,
        month1: nil,
        month12: nil
    )
}

struct RetentionNotificationSchedule {
    let fireDate: Date
    let cancelledCount: Int
    let attemptCount: Int
}

struct Day14WarningSchedule {
    let fireDate: Date
    let cancelledCount: Int

    static func nextFireDate(
        nominalFireDate: Date,
        now: Date,
        day14Boundary: Date
    ) -> Date? {
        guard now < day14Boundary else {
            return nil
        }
        guard nominalFireDate <= now else {
            return nominalFireDate
        }

        return [
            now.addingTimeInterval(60 * 60),
            day14Boundary.addingTimeInterval(-12 * 60 * 60)
        ]
        .filter { $0 > now && $0 < day14Boundary }
        .min()
    }
}
