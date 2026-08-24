import DopaBreakCore
import Foundation
import Observation
import UIKit
import UserNotifications

/// 一呼吸を始める対象。カタログ起動とシールドからの一時開放を同じ流れへ載せる。
enum InterventionTarget: Equatable {
    case catalog(SNSAppCatalogItem)
    case gateToken(tokenData: Data, ruleId: UUID)
}

/// 一呼吸フロー（S-01〜S-05・doc12 §2）の画面状態。
enum InterventionFlowStage: Equatable {
    case breathing
    case usageSummary
    case goalReminder
    case reasonSelection
    case decision
    case durationSelection
    case opening(fallbackMessage: String?)
    case limit(GateDenial)
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
        case .work:
            return String(localized: "intervention.reason.work", defaultValue: "仕事で使う")
        case .research:
            return String(localized: "intervention.reason.research", defaultValue: "調べもの")
        case .communication:
            return String(localized: "intervention.reason.communication", defaultValue: "連絡を確認")
        case .posting:
            return String(localized: "intervention.reason.posting", defaultValue: "投稿する")
        case .boredom:
            return String(localized: "intervention.reason.boredom", defaultValue: "暇つぶし")
        case .unconscious:
            return String(localized: "intervention.reason.unconscious", defaultValue: "なんとなく")
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

    var displayTitle: String {
        String(localized: "intervention.duration.option", defaultValue: "\(rawValue)分")
    }

    var seconds: Int { rawValue * 60 }
}

@MainActor
@Observable
final class InterventionFlowModel {
    let target: InterventionTarget
    private let model: AppModel
    private let settingsStore: SettingsStore

    private(set) var stage: InterventionFlowStage = .reasonSelection
    private(set) var breathRemainingSeconds: Int = 3
    private(set) var breathTotalSeconds: Int = 3
    private(set) var todayAttemptDisplayCount = 0
    private(set) var selectedReason: InterventionReason?
    private(set) var selectedDuration: InterventionDuration = .tenMinutes
    private(set) var isAwaitingTargetOpen = false
    private(set) var notificationsAuthorized = false

    private var breathTask: Task<Void, Never>?
    private var startGeneration = 0
    private var ruleId: UUID?
    private var lastAttemptId: UUID?

    private static let breathTimerTickNanoseconds: UInt64 = 250_000_000

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

    func reviewPromptRequestDateIfEligible() -> Date? {
        model.reviewPromptRequestDateIfEligible(
            sessionBlocked: model.purchaseOrRestoreFailedThisSession
        )
    }

    func recordReviewPromptShown(at date: Date) {
        model.recordReviewPromptShown(at: date)
    }

    init(target: InterventionTarget, model: AppModel, settingsStore: SettingsStore) {
        self.target = target
        self.model = model
        self.settingsStore = settingsStore
        if case .gateToken(let tokenData, _) = target {
            let minutes = model.gateAppSetting(for: tokenData).sessionMinutes
            selectedDuration = InterventionDuration(rawValue: minutes) ?? .tenMinutes
        }
    }

    convenience init(
        target: SNSAppCatalogItem,
        model: AppModel,
        settingsStore: SettingsStore
    ) {
        self.init(target: .catalog(target), model: model, settingsStore: settingsStore)
    }

    func start() {
        model.usageWatch.recordIntervention(at: Date())
        breathTask?.cancel()
        breathTask = nil
        startGeneration += 1
        let generation = startGeneration

        Task { [weak self] in
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard let self, generation == self.startGeneration else {
                return
            }
            self.notificationsAuthorized = switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                true
            case .notDetermined, .denied:
                false
            @unknown default:
                false
            }
        }

        guard let engine = model.interventionEngine else {
            stage = .failed(
                String(
                    localized: "intervention.error.record_store_unavailable",
                    defaultValue: "記録データを準備できませんでした"
                )
            )
            return
        }
        do {
            let resolvedRuleID: UUID
            switch target {
            case .catalog(let catalogTarget):
                resolvedRuleID = try model.ruleStore.catalogTargetRule(for: catalogTarget).id
            case .gateToken(_, let gateRuleID):
                resolvedRuleID = gateRuleID
            }
            ruleId = resolvedRuleID

            let current = try engine.currentStep()
            let resumable: Set<InterventionStep> = [.idle, .cancelled, .postUseReflection]
            if !resumable.contains(current) {
                try engine.resetToIdle()
            }
            try engine.beginIntervention(ruleId: resolvedRuleID)
            try engine.beginIntentSelection() // shieldPresented -> intentSelection
            todayAttemptDisplayCount = model.todayAttemptCount(for: resolvedRuleID) + 1
            stage = .reasonSelection
        } catch {
            stage = .failed(String(localized: "intervention.error.preparation", defaultValue: "準備できませんでした"))
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
        let generation = startGeneration

        breathTask = Task { [weak self] in
            let totalDuration = TimeInterval(total)
            let startTime = ProcessInfo.processInfo.systemUptime

            while true {
                guard let self,
                      !Task.isCancelled,
                      generation == self.startGeneration,
                      self.stage == .breathing else {
                    return
                }

                let elapsed = min(
                    ProcessInfo.processInfo.systemUptime - startTime,
                    totalDuration
                )
                self.breathRemainingSeconds = max(0, Int(ceil(totalDuration - elapsed)))

                if elapsed >= totalDuration {
                    break
                }
                try? await Task.sleep(nanoseconds: Self.breathTimerTickNanoseconds)
            }

            guard let self,
                  !Task.isCancelled,
                  generation == self.startGeneration,
                  self.stage == .breathing else {
                return
            }
            self.breathRemainingSeconds = 0
            self.stage = .usageSummary
        }
    }

    func advanceToGoalReminder() {
        guard stage == .usageSummary else { return }
        stage = .goalReminder
    }

    func advanceToDecision() {
        guard stage == .goalReminder else { return }
        stage = .decision
    }

    func selectReason(_ reason: InterventionReason) {
        guard stage == .reasonSelection else { return }
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
            stage = .failed(String(localized: "intervention.error.progression", defaultValue: "進められませんでした"))
        }
    }

    func chooseCancel() {
        guard stage == .decision || stage == .durationSelection else { return }
        guard let engine = model.interventionEngine else { return }
        do {
            try engine.recordCancel()
            model.refresh()
            stage = .win
        } catch {
            stage = .failed(String(localized: "intervention.error.record", defaultValue: "記録できませんでした"))
        }
    }

    func chooseOpenWithTime() {
        guard stage == .decision else { return }
        stage = .durationSelection
    }

    func chooseDuration(_ duration: InterventionDuration) {
        guard stage == .durationSelection else { return }
        selectedDuration = duration
    }

    func confirmSelectedDuration() {
        guard stage == .durationSelection else { return }
        open(for: selectedDuration)
    }

    private func open(for duration: InterventionDuration) {
        switch target {
        case .catalog(let catalogTarget):
            openCatalogTarget(catalogTarget, for: duration)
        case .gateToken(let tokenData, let ruleId):
            openGateTarget(tokenData: tokenData, ruleId: ruleId, for: duration)
        }
    }

    private func recordOpenAndScheduleNotifications(for duration: InterventionDuration) {
        guard let engine = model.interventionEngine else { return }
        do {
            try engine.recordOpen(durationSeconds: duration.seconds)
            model.refresh()
            scheduleTimeUpNotification(after: duration)
            if duration.seconds >= 600 {
                scheduleMidSessionCheckIn(after: duration)
            }
        } catch {
            stage = .failed(String(localized: "intervention.error.record", defaultValue: "記録できませんでした"))
        }
    }

    private func scheduleTimeUpNotification(after duration: InterventionDuration) {
        let content = UNMutableNotificationContent()
        content.title = String(
            localized: "intervention.notification.time_up.title",
            defaultValue: "そろそろひと休み"
        )
        content.body = String(
            localized: "intervention.notification.time_up.body",
            defaultValue: "そろそろ\(duration.rawValue)分。見てどうだった？"
        )
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
        UNUserNotificationCenter.current().add(request) { _ in
        }
    }

    private func scheduleMidSessionCheckIn(after duration: InterventionDuration) {
        let content = UNMutableNotificationContent()
        content.title = String(
            localized: "intervention.notification.check_in.title",
            defaultValue: "まだ見てる？"
        )
        content.body = String(
            localized: "intervention.notification.check_in.body",
            defaultValue: "目標を思い出す時間です"
        )
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(duration.seconds / 2),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "dopabreak.midsession.\(notificationTargetIdentifier).\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { _ in
        }
    }

    private func openCatalogTarget(
        _ catalogTarget: SNSAppCatalogItem,
        for duration: InterventionDuration
    ) {
        let fallbackMessage = String(
            localized: "intervention.opening.manual_fallback",
            defaultValue: "ホーム画面から\(catalogTarget.displayName)を開いてください"
        )
        guard let urlScheme = catalogTarget.urlScheme, let url = URL(string: urlScheme) else {
            stage = .opening(fallbackMessage: fallbackMessage)
            // URLスキームがないアプリは、この案内から手動で開く前提で記録と通知を維持する。
            recordOpenAndScheduleNotifications(for: duration)
            return
        }

        isAwaitingTargetOpen = true
        stage = .opening(fallbackMessage: nil)
        UIApplication.shared.open(url, options: [:]) { [weak self] success in
            guard let self else { return }
            if success {
                self.recordOpenAndScheduleNotifications(for: duration)
            } else {
                self.stage = .opening(fallbackMessage: fallbackMessage)
                // URL起動失敗時も、この案内から手動で開く前提で記録と通知を維持する。
                self.recordOpenAndScheduleNotifications(for: duration)
            }
            self.isAwaitingTargetOpen = false
        }
    }

    private func openGateTarget(
        tokenData: Data,
        ruleId: UUID,
        for duration: InterventionDuration
    ) {
        guard let engine = model.interventionEngine else {
            stage = .failed(
                String(
                    localized: "intervention.error.record_store_unavailable",
                    defaultValue: "記録データを準備できませんでした"
                )
            )
            return
        }

        let validation: Result<Void, GateDenial>
        do {
            validation = try model.canGrantGate(tokenData: tokenData)
        } catch {
            stage = .failed(
                String(localized: "intervention.error.record", defaultValue: "記録できませんでした")
            )
            return
        }

        switch validation {
        case .success:
            break
        case .failure(.alreadyOpen):
            showGateOpening(for: duration)
            return
        case .failure(let denial):
            do {
                try engine.recordCancel()
                model.refresh()
                stage = .limit(denial)
            } catch {
                stage = .failed(
                    String(localized: "intervention.error.record", defaultValue: "記録できませんでした")
                )
            }
            return
        }

        // ここから先はopenedとして記録済みになるため、grant内部の再検証は拒否に使わない。
        // alreadyOpen競合は既存grantを再利用し、limit/cooldown競合も開放を完了させる。
        do {
            try engine.recordOpen(durationSeconds: duration.seconds)
            try model.grantGate(
                tokenData: tokenData,
                ruleId: ruleId,
                minutes: duration.rawValue
            )
            model.refresh()
            scheduleTimeUpNotification(after: duration)
            // gateTokenは通知タップからcatalogIDへ戻せないため、中間確認は予約しない。
            showGateOpening(for: duration)
        } catch {
            stage = .failed(
                String(localized: "intervention.error.record", defaultValue: "記録できませんでした")
            )
        }
    }

    private func showGateOpening(for duration: InterventionDuration) {
        stage = .opening(
            fallbackMessage: String(
                localized: "intervention.gate.opening.back",
                defaultValue: "左上の ◀ から戻ると開けます（\(duration.rawValue)分）"
            )
        )
    }

    private var notificationTargetIdentifier: String {
        switch target {
        case .catalog(let target):
            return target.catalogID
        case .gateToken(_, let ruleId):
            return "gate-\(ruleId.uuidString)"
        }
    }
}
