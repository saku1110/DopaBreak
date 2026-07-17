import DopaBreakCore
import Foundation
import Observation
import UIKit
import UserNotifications

/// 一呼吸フロー（S-01〜S-05・doc12 §2）の画面状態。
enum InterventionFlowStage: Equatable {
    case breathing
    case usageSummary
    case goalReminder
    case reasonSelection
    case decision
    case durationSelection
    case opening(fallbackMessage: String?)
    case win
    case failed(String)
}

/// 一呼吸フローで選べる「なんのために開く？」の理由（doc11 §7 S-04選択肢）。
enum InterventionReason: String, CaseIterable, Identifiable {
    case work
    case research
    case communication
    case posting
    case boredom
    case unconscious

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .work: return "仕事で使う"
        case .research: return "調べもの"
        case .communication: return "連絡を確認"
        case .posting: return "投稿する"
        case .boredom: return "暇つぶし"
        case .unconscious: return "なんとなく"
        }
    }

    var intentCategory: IntentCategory {
        switch self {
        case .work: return .workRequired
        case .research: return .research
        case .communication: return .communication
        case .posting: return .posting
        case .boredom: return .boredom
        case .unconscious: return .unconscious
        }
    }

    var interventionStyle: IntentInterventionStyle {
        intentCategory.interventionStyle
    }
}

/// 開く時間の選択肢（doc11 §7 S-05時間選択肢）。
enum InterventionDuration: Int, CaseIterable, Identifiable {
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    case thirtyMinutes = 30

    var id: Int { rawValue }

    var displayTitle: String { "\(rawValue)分" }

    var seconds: Int { rawValue * 60 }
}

@MainActor
@Observable
final class InterventionFlowModel {
    let target: SNSAppCatalogItem
    private let model: AppModel
    private let settingsStore: SettingsStore

    private(set) var stage: InterventionFlowStage = .reasonSelection
    private(set) var breathRemainingSeconds: Int = 3
    private(set) var breathTotalSeconds: Int = 3
    private(set) var todayAttemptDisplayCount = 0
    private(set) var selectedReason: InterventionReason?
    private(set) var selectedDuration: InterventionDuration = .tenMinutes

    private var breathTask: Task<Void, Never>?
    private var ruleId: UUID?
    private var lastAttemptId: UUID?

    var goals: [Goal] { model.goals }
    var todayCancelledCountForDisplay: Int { model.todayCancelledCount }
    var todayAttemptCountForDisplay: Int { model.todayAttemptCount }
    var dayTimeContext: DayTimeContext {
        DayTimeContext.resolve(
            now: Date(),
            wakeMinutes: settingsStore.wakeTimeMinutes,
            bedMinutes: settingsStore.bedTimeMinutes
        )
    }

    init(target: SNSAppCatalogItem, model: AppModel, settingsStore: SettingsStore) {
        self.target = target
        self.model = model
        self.settingsStore = settingsStore
    }

    func start() {
        guard let engine = model.interventionEngine else {
            stage = .failed("記録データを準備できませんでした")
            return
        }
        do {
            let rule = try model.ruleStore.catalogTargetRule(for: target)
            ruleId = rule.id

            let current = try engine.currentStep()
            let resumable: Set<InterventionStep> = [.idle, .cancelled, .postUseReflection]
            if !resumable.contains(current) {
                try engine.resetToIdle()
            }
            try engine.beginIntervention(ruleId: rule.id)
            try engine.beginIntentSelection() // shieldPresented -> intentSelection
            todayAttemptDisplayCount = model.todayAttemptCountForCurrentRule(catalogID: target.catalogID) + 1
            stage = .reasonSelection
        } catch {
            stage = .failed("準備できませんでした")
        }
    }

    func stop() {
        breathTask?.cancel()
        breathTask = nil
    }

    private func beginBreathing() {
        breathTask?.cancel()
        let total = settingsStore.breathDurationSeconds
        breathTotalSeconds = total
        breathRemainingSeconds = total
        stage = .breathing

        breathTask = Task { [weak self] in
            var remaining = total
            while remaining > 0 {
                if Task.isCancelled { return }
                self?.breathRemainingSeconds = remaining
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                remaining -= 1
            }
            if Task.isCancelled { return }
            self?.stage = .usageSummary
        }
    }

    func advanceToGoalReminder() {
        stage = .goalReminder
    }

    func advanceToDecision() {
        stage = .decision
    }

    func selectReason(_ reason: InterventionReason) {
        guard let engine = model.interventionEngine else { return }
        do {
            selectedReason = reason
            try engine.recordIntent(reason.intentCategory)
            try engine.advanceStep() // intentSelection -> decision
            switch reason.interventionStyle {
            case .direct:
                stage = .durationSelection
            case .reflective:
                beginBreathing()
            }
        } catch {
            stage = .failed("進められませんでした")
        }
    }

    func chooseCancel() {
        guard let engine = model.interventionEngine else { return }
        do {
            try engine.recordCancel()
            model.refresh()
            stage = .win
        } catch {
            stage = .failed("記録できませんでした")
        }
    }

    func chooseOpenWithTime() {
        stage = .durationSelection
    }

    func chooseDuration(_ duration: InterventionDuration) {
        selectedDuration = duration
    }

    func confirmSelectedDuration() {
        open(for: selectedDuration)
    }

    private func open(for duration: InterventionDuration) {
        guard let engine = model.interventionEngine else { return }
        do {
            try engine.recordOpen(durationSeconds: duration.seconds)
            model.refresh()
            scheduleTimeUpNotification(after: duration)
            if duration.seconds >= 600 {
                scheduleMidSessionCheckIn(after: duration)
            }
            openTargetApp()
        } catch {
            stage = .failed("記録できませんでした")
        }
    }

    private func scheduleTimeUpNotification(after duration: InterventionDuration) {
        let content = UNMutableNotificationContent()
        content.title = "そろそろひと休み"
        content.body = "そろそろ\(duration.rawValue)分。見てどうだった？"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(duration.seconds),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "dopabreak.timeup.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleMidSessionCheckIn(after duration: InterventionDuration) {
        let content = UNMutableNotificationContent()
        content.title = "まだ見てる？"
        content.body = "戻る先を思い出す時間です"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(duration.seconds / 2),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "dopabreak.midsession.\(target.catalogID).\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func openTargetApp() {
        guard let urlScheme = target.urlScheme, let url = URL(string: urlScheme) else {
            stage = .opening(fallbackMessage: "ホームに戻って開き直してください")
            return
        }

        stage = .opening(fallbackMessage: nil)
        UIApplication.shared.open(url, options: [:]) { [weak self] success in
            guard let self else { return }
            if !success {
                self.stage = .opening(fallbackMessage: "ホームに戻って開き直してください")
            }
        }
    }
}
