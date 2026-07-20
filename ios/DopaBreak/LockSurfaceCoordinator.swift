import ActivityKit
import DopaBreakCore
import Foundation
import UserNotifications
import WidgetKit

@MainActor
final class LockSurfaceCoordinator {
    static let morningNotificationIdentifier = "dopabreak.lock.morning"
    static let weeklyNotificationIdentifier = "dopabreak.lock.weekly"

    private let notificationCenter: UNUserNotificationCenter
    private var notificationTask: Task<Void, Never>?
    private var notificationGeneration = 0
    private var liveActivityTask: Task<Void, Never>?
    private var liveActivityGeneration = 0

    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    func rescheduleNotifications(
        goals: [Goal],
        state: LockSurfaceState,
        weeklySummary: WeeklySummary?
    ) {
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
                    generation: generation
                )
            }
            if self.notificationGeneration == generation {
                self.notificationTask = nil
            }
        }
        notificationTask = task
    }

    func cancelAllNotifications() {
        notificationGeneration += 1
        notificationTask?.cancel()
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }

    private func performNotificationReschedule(
        goals: [Goal],
        state: LockSurfaceState,
        weeklySummary: WeeklySummary?,
        generation: Int
    ) async {
        let identifiers = [
            Self.morningNotificationIdentifier,
            Self.weeklyNotificationIdentifier
        ]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)

        let settings = await notificationCenter.notificationSettings()
        guard !Task.isCancelled,
              notificationGeneration == generation else {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
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
            content.title = "今日の戻る先"
            content.body = titles.joined(separator: "・")
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
            guard !Task.isCancelled,
                  notificationGeneration == generation else {
                notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
                return
            }
        }

        if state.weeklyReportEnabled,
           let weeklySummary,
           weeklySummary.attempts > 0 {
            let content = UNMutableNotificationContent()
            content.title = "今週のふりかえり"
            content.body = "開かずに戻れた \(weeklySummary.cancelled)回 / 開こうとした \(weeklySummary.attempts)回"
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: hour, minute: minute, weekday: 2),
                repeats: false
            )
            try? await notificationCenter.add(
                UNNotificationRequest(
                    identifier: Self.weeklyNotificationIdentifier,
                    content: content,
                    trigger: trigger
                )
            )
            if Task.isCancelled || notificationGeneration != generation {
                notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
            }
        }
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
}
