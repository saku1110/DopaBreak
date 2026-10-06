import DopaBreakCore
import Foundation
import Observation
import UIKit

/// ショートカット経由で一呼吸を始める対象。
enum InterventionTarget: Equatable {
    case catalog(SNSAppCatalogItem)
    case catalogPassThrough(SNSAppCatalogItem, until: Date)

    /// SwiftUIの介入ルートを対象単位で作り直すための安定した識別子。
    var presentationID: String {
        switch self {
        case .catalog(let target):
            return "catalog:\(target.catalogID)"
        case .catalogPassThrough(let target, let until):
            return "catalog-pass-through:\(target.catalogID):\(until.timeIntervalSince1970)"
        }
    }
}

/// 一呼吸フロー（S-01〜S-05・doc12 §2）の画面状態。
enum InterventionFlowStage: Equatable {
    case breathing
    case usageSummary
    case reasonSelection
    case durationSelection
    case opening(fallbackMessage: String?)
    case passingThrough(remainingMinutes: Int)
    case win
    case failed(String)
    /// 1日に開ける回数を使い切ったあとに呼ばれた。
    case limitReached
    /// 使い切ったあと、緊急で開くための30秒を待っている。
    case emergencyWaiting
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
    typealias OpenURL = @MainActor (
        URL,
        @escaping @MainActor @Sendable (Bool) -> Void
    ) -> Void

    let isOnboardingExperience: Bool
    let target: InterventionTarget
    private let model: AppModel
    private let settingsStore: SettingsStore
    private let openURL: OpenURL

    private(set) var stage: InterventionFlowStage = .breathing
    private(set) var breathRemainingSeconds: Int
    private(set) var breathTotalSeconds: Int
    private(set) var todayAttemptDisplayCount = 0
    private(set) var selectedReason: InterventionReason?
    var blocksNecessaryUse = false
    var usesTimeLimit = true
    var isGentleCheckIn: Bool { canChooseUntimed && usesTimeLimit && !blocksNecessaryUse }
    var canBlockNecessaryUse: Bool {
        if case .catalog(let app) = target { return model.isReinterventionConnected(catalogID: app.catalogID) }
        return false
    }
    /// 最後の1回は時間なしを選べない。決めた時間の終わりから止まり始めるため。
    var canChooseUntimed: Bool { selectedReason?.interventionStyle == .direct && !isLastOpenForDailyLimit }

    /// 1日に開ける回数の状態。段階の切り替わりで取り直し、描画のたびに記録を読まない。
    private(set) var dailyOpenLimitStatus: DailyOpenLimitStatus?
    /// 使い切ったあと、30秒待って緊急で開こうとしている。
    private(set) var isEmergencyOpen = false

    /// 呼吸中に出す残りの回数。オフ・使い切ったあとは `nil`。
    var remainingOpensForDisplay: Int? {
        guard let remaining = dailyOpenLimitStatus?.remaining, remaining > 0 else { return nil }
        return remaining
    }

    /// これを開くと今日の回数を使い切る。
    var isLastOpenForDailyLimit: Bool {
        !isEmergencyOpen && dailyOpenLimitStatus?.isLastOpen == true
    }

    var dailyOpenLimitOpenedCount: Int { dailyOpenLimitStatus?.openedCount ?? 0 }
    var dailyOpenLimitDayEndsAt: Date? { dailyOpenLimitStatus?.dayEndsAt }
    var dailyOpenLimitEmergencyState: DailyOpenLimitPolicy.EmergencyState { model.dailyOpenLimitEmergencyState }
    /// 夜・予定・手動のブロックが重なっているか。緊急で外せるのは回数上限ぶんだけなので、緊急の導線を出さない。
    var isOtherHardBlockActive: Bool { model.isOtherHardBlockActive }
    var isUntimedPassThrough: Bool {
        if case .catalogPassThrough(let app, _) = target {
            return model.catalogAllowanceStore.activeAllowance(catalogID: app.catalogID, at: model.currentDate) == nil
        }
        return false
    }
    private(set) var selectedDuration: InterventionDuration = .tenMinutes
    private(set) var isAwaitingTargetOpen = false
    private(set) var winReclaimedSeconds = 0
    private(set) var winLifetimeReclaimedSeconds = 0
    private(set) var winEstimatedMinutesPerCancellation = 1
    private(set) var winConsecutiveDays = 0
    private(set) var winMilestone: ReclaimedTimeMilestone?

    private var breathTask: Task<Void, Never>?
    private var passThroughTask: Task<Void, Never>?
    private var startGeneration = 0

    private static let breathTimerTickNanoseconds: UInt64 = 250_000_000

    var hasMonitoredUsageBudget: Bool {
        switch target {
        case .catalog(let app), .catalogPassThrough(let app, _):
            return model.reinterventionSession(catalogID: app.catalogID) != nil
        }
    }
    var goals: [Goal] { model.goals }
    var todayCancelledCountForDisplay: Int { model.todayCancelledCount }
    var todayAttemptCountForDisplay: Int { todayAttemptDisplayCount }
    var dayTimeContext: DayTimeContext {
        DayTimeContext.resolve(
            now: Date(),
            wakeMinutes: settingsStore.wakeTimeMinutes,
            bedMinutes: settingsStore.bedTimeMinutes
        )
    }

    func reviewPromptRequestDateIfEligible() -> Date? {
        guard !isOnboardingExperience else { return nil }
        return model.reviewPromptRequestDateIfEligible(
            sessionBlocked: model.purchaseOrRestoreFailedThisSession
        )
    }

    func recordReviewPromptShown(at date: Date) {
        model.recordReviewPromptShown(at: date)
    }

    init(
        target: InterventionTarget,
        model: AppModel,
        settingsStore: SettingsStore,
        isOnboardingExperience: Bool = false,
        openURL: @escaping OpenURL = { url, completion in
            UIApplication.shared.open(url, options: [:], completionHandler: completion)
        }
    ) {
        self.isOnboardingExperience = isOnboardingExperience
        self.target = target
        self.model = model
        self.settingsStore = settingsStore
        self.openURL = openURL
        let breathDurationSeconds = settingsStore.breathDurationSeconds
        self.breathRemainingSeconds = breathDurationSeconds
        self.breathTotalSeconds = breathDurationSeconds
    }

    convenience init(
        target: SNSAppCatalogItem,
        model: AppModel,
        settingsStore: SettingsStore
    ) {
        self.init(target: .catalog(target), model: model, settingsStore: settingsStore)
    }

    func start() {
        breathTask?.cancel()
        breathTask = nil
        passThroughTask?.cancel()
        passThroughTask = nil
        startGeneration += 1

        if case .catalogPassThrough(let catalogTarget, let until) = target {
            beginPassThrough(to: catalogTarget, until: until)
            return
        }

        isEmergencyOpen = false
        refreshDailyOpenLimitStatus()
        if dailyOpenLimitStatus?.isExhausted == true {
            // 使い切ったあとは一呼吸を始めない。記録も作らず、上限画面だけを出す。
            stage = .limitReached
            return
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
            try beginInterventionAndBreathing(using: engine)
        } catch {
            stage = .failed(String(localized: "intervention.error.preparation", defaultValue: "準備できませんでした"))
        }
    }

    func stop() {
        breathTask?.cancel()
        breathTask = nil
        passThroughTask?.cancel()
        passThroughTask = nil
    }

    /// 画面離脱で停止した呼吸だけを再開する。進行中Taskや他ステージには触れない。
    func resumeBreathingIfNeeded() {
        guard stage == .breathing, breathTask == nil else { return }
        beginBreathing()
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
            self.completeBreathing(generation: generation)
        }
    }

    private func completeBreathing(generation: Int) {
        guard generation == startGeneration, stage == .breathing else { return }
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
            // 呼吸中は開始状態を維持し、理由画面を表示する直前に intentSelection へ揃える。
            try engine.beginIntentSelection()
            AppleAdsMeasurement.shared.record(.breathingCompleted)
            breathRemainingSeconds = 0
            if !isOnboardingExperience, case .catalog(let target) = target, model.reinterventionSession(catalogID: target.catalogID)?.resumeRequested == true {
                try engine.advanceStep()
                stage = .durationSelection
            } else {
                stage = .reasonSelection
            }
        } catch {
            stage = .failed(String(localized: "intervention.error.progression", defaultValue: "進められませんでした"))
        }
    }

    #if DEBUG
    /// スナップショットと状態遷移テストで、実時間待機せず本番と同じ完了処理を通す。
    func completeBreathingForTesting() {
        guard stage == .breathing else { return }
        breathTask?.cancel()
        breathTask = nil
        completeBreathing(generation: startGeneration)
    }
    #endif

    func selectReason(_ reason: InterventionReason) {
        guard stage == .reasonSelection else { return }
        guard let engine = model.interventionEngine else { return }
        do {
            selectedReason = reason
            usesTimeLimit = true
            blocksNecessaryUse = false
            try engine.recordIntent(reason.intentCategory)
            try engine.advanceStep() // intentSelection -> decision
            switch reason.interventionStyle {
            case .direct:
                proceedToOpenOrDurationSelection()
            case .reflective:
                stage = .usageSummary
            }
        } catch {
            stage = .failed(String(localized: "intervention.error.progression", defaultValue: "進められませんでした"))
        }
    }

    func chooseCancel() {
        guard stage == .reasonSelection || stage == .usageSummary || stage == .durationSelection else { return }
        guard let engine = model.interventionEngine else { return }
        do {
            if !isOnboardingExperience, case .catalog(let catalogTarget) = target, model.reinterventionSession(catalogID: catalogTarget.catalogID) != nil {
                try model.finishReintervention(catalogID: catalogTarget.catalogID)
            }
            let reclaimedSeconds = try engine.recordCancel()
            model.refresh()
            let lifetimeReclaimedSeconds = try model.reclaimedSecondsAllTime()
            let todayReclaimedSeconds = try model.reclaimedSecondsToday()
            winReclaimedSeconds = reclaimedSeconds
            winLifetimeReclaimedSeconds = lifetimeReclaimedSeconds
            winEstimatedMinutesPerCancellation = ReclaimedTimeFormatter.estimatedMinutesPerCancellation(
                todayReclaimedSeconds: todayReclaimedSeconds,
                todayCancellationCount: model.todayCancelledCount,
                fallbackSeconds: reclaimedSeconds
            )
            winConsecutiveDays = try model.consecutiveDaysWithCancellations()
            winMilestone = ReclaimedTimeMilestoneTracker.claimNewMilestone(
                previousTotalSeconds: lifetimeReclaimedSeconds - reclaimedSeconds,
                totalSeconds: lifetimeReclaimedSeconds,
                settingsStore: settingsStore
            )
            stage = .win
        } catch {
            stage = .failed(String(localized: "intervention.error.record", defaultValue: "記録できませんでした"))
        }
    }

    func chooseOpen() {
        guard stage == .usageSummary else { return }
        proceedToOpenOrDurationSelection()
    }

    func chooseDuration(_ duration: InterventionDuration) {
        guard stage == .durationSelection else { return }
        selectedDuration = duration
    }

    func confirmSelectedDuration() {
        guard stage == .durationSelection else { return }
        guard case .catalog(let catalogTarget) = target else { return }
        if isOnboardingExperience {
            chooseCancel()
            return
        }
        if isEmergencyOpen {
            // 時間を選んでいるあいだに朝を迎えた・Freeへ戻ったなら、緊急ではなく通常の一呼吸からやり直す。
            guard restartIfLimitNoLongerApplies() == false else { return }
            openForEmergency(catalogTarget, for: selectedDuration)
            return
        }
        // 画面を出してから確定までのあいだに使い切っていないか、確定の直前にも確かめる。
        refreshDailyOpenLimitStatus()
        if dailyOpenLimitStatus?.isExhausted == true {
            try? model.interventionEngine?.resetToIdle()
            stage = .limitReached
            return
        }
        openCatalogTarget(catalogTarget, for: selectedDuration)
    }

    private func proceedToOpenOrDurationSelection() {
        stage = .durationSelection
        prepareDurationSelectionForDailyOpenLimit()
    }

    /// 時間選択の画面へ入るときに、最新の残り回数で最後の1回かを決め直す。最後の1回は時間ありに固定する。
    private func prepareDurationSelectionForDailyOpenLimit() {
        refreshDailyOpenLimitStatus()
        if isLastOpenForDailyLimit {
            usesTimeLimit = true
        }
    }

    // MARK: - 1日に開ける回数

    private func refreshDailyOpenLimitStatus() {
        dailyOpenLimitStatus = isOnboardingExperience ? nil : model.dailyOpenLimitStatus
    }

    /// 上限画面から、緊急で開くための30秒の待ちを始める。待ち時間が切れたあとの出し直しにも使う。
    func requestEmergencyOpen() {
        guard stage == .limitReached || stage == .emergencyWaiting, !isOtherHardBlockActive else { return }
        guard restartIfLimitNoLongerApplies() == false else { return }
        model.requestDailyOpenLimitEmergency()
        stage = .emergencyWaiting
    }

    /// 上限画面・緊急の待ちを出しているあいだに呼ぶ（前面へ戻ったとき・1分ごと）。
    /// 上限がもう効いていなければ、通常の一呼吸からやり直す。
    func refreshLimitStateIfNeeded() {
        guard stage == .limitReached || stage == .emergencyWaiting else { return }
        _ = restartIfLimitNoLongerApplies()
    }

    /// 上限画面を開いたまま起床時刻を過ぎた・Freeへ戻ったときは、上限はもう効いていない。
    /// 古い上限画面のまま待たせず、通常の一呼吸からやり直す。
    /// - Returns: やり直したか。
    private func restartIfLimitNoLongerApplies() -> Bool {
        refreshDailyOpenLimitStatus()
        guard dailyOpenLimitStatus?.isExhausted != true else { return false }
        start()
        return true
    }

    /// 待ち終わったら時間選択へ進む。待ちの途中・猶予切れでは進まない。
    func proceedAfterEmergencyWait() {
        guard stage == .emergencyWaiting else { return }
        guard restartIfLimitNoLongerApplies() == false else { return }
        guard model.dailyOpenLimitEmergencyState == .ready else {
            if model.dailyOpenLimitEmergencyState == .notRequested {
                stage = .limitReached
            }
            return
        }
        isEmergencyOpen = true
        selectedReason = nil
        usesTimeLimit = true
        blocksNecessaryUse = false
        stage = .durationSelection
    }

    private func openForEmergency(_ catalogTarget: SNSAppCatalogItem, for duration: InterventionDuration) {
        guard model.openForDailyOpenLimitEmergency(durationSeconds: duration.seconds, catalogTarget: catalogTarget) else {
            isEmergencyOpen = false
            refreshDailyOpenLimitStatus()
            stage = model.dailyOpenLimitEmergencyState == .notRequested ? .limitReached : .emergencyWaiting
            return
        }
        launchCatalogTarget(catalogTarget)
    }

    @discardableResult
    private func recordCatalogOpen(for duration: InterventionDuration) -> Bool {
        guard let engine = model.interventionEngine, case .catalog(let catalogTarget) = target else { return false }
        var prepared: ReinterventionSession?
        var createdReflection: ReflectionLog?
        do {
            model.reflectionNotificationScheduler.cancelWorkCheckIn(catalogID: catalogTarget.catalogID)
            if canChooseUntimed && !usesTimeLimit {
                try engine.recordUntimedOpen()
                try model.finishReintervention(catalogID: catalogTarget.catalogID)
                model.cancelReflectionNotification()
                model.refresh()
                return true
            }
            prepared = try model.reinterventionScheduler.prepare(catalogID: catalogTarget.catalogID,
                minutes: duration.rawValue, authorized: model.screenTimeAuthorizationStatus == .approved, notificationsEnabled: model.reinterventionNotificationsEnabled, blocksAtLimit: !isGentleCheckIn)
            if isGentleCheckIn {
                try engine.recordUntimedOpen(selectedDurationSeconds: duration.seconds)
                model.cancelReflectionNotification()
                if let prepared {
                    model.catalogAllowanceStore.grant(catalogID: catalogTarget.catalogID, until: prepared.expiresAt)
                } else {
                    model.catalogAllowanceStore.grant(catalogID: catalogTarget.catalogID, until: model.currentDate.addingTimeInterval(Double(duration.seconds)))
                    model.reflectionNotificationScheduler.scheduleWorkCheckIn(catalogID: catalogTarget.catalogID, minutes: duration.rawValue,
                        isEnabled: model.reinterventionNotificationsEnabled, now: model.currentDate)
                }
                model.refresh()
                return true
            }
            let reflection = try engine.recordCatalogOpen(durationSeconds: duration.seconds, deferReflection: prepared != nil)
            createdReflection = reflection
            if let prepared {
                try model.reinterventionScheduler.attach(reflectionID: reflection.id, to: prepared)
                model.catalogAllowanceStore.grant(catalogID: catalogTarget.catalogID, until: prepared.expiresAt)
                model.cancelReflectionNotification()
            } else {
                model.catalogAllowanceStore.grant(catalogID: catalogTarget.catalogID, until: reflection.promptedAt)
                model.scheduleReflectionNotification(for: reflection, appDisplayName: catalogTarget.displayName, declaredMinutes: duration.rawValue)
            }
            model.refresh()
            return true
        } catch {
            if let createdReflection { try? engine.skipReflection(id: createdReflection.id) }
            if prepared != nil { try? model.finishReintervention(catalogID: catalogTarget.catalogID) }
            stage = .failed(error.localizedDescription)
            return false
        }
    }

    private func openCatalogTarget(
        _ catalogTarget: SNSAppCatalogItem,
        for duration: InterventionDuration
    ) {
        let isUntimed = canChooseUntimed && !usesTimeLimit
        guard recordCatalogOpen(for: duration) else { return }
        // 使い切ったら、決めた時間の終わりから完全ブロックを始める。
        model.didRecordOpenForDailyOpenLimit(durationSeconds: isUntimed ? nil : duration.seconds)
        launchCatalogTarget(catalogTarget)
    }

    /// 記録を済ませたあとに、対象アプリを開く。開けなければホーム画面から開くよう案内する。
    private func launchCatalogTarget(_ catalogTarget: SNSAppCatalogItem) {
        let fallbackMessage = String(
            localized: "intervention.opening.manual_fallback",
            defaultValue: "ホーム画面から\(catalogTarget.displayName)を開いてください"
        )
        guard let urlScheme = catalogTarget.urlScheme, let url = URL(string: urlScheme) else {
            stage = .opening(fallbackMessage: fallbackMessage)
            // Monitoring is armed before the user opens the app manually.
            return
        }

        isAwaitingTargetOpen = true
        stage = .opening(fallbackMessage: nil)
        model.markSelfOpened(catalogID: catalogTarget.catalogID)
        openURL(url) { [weak self] success in
            guard let self else { return }
            self.model.discardPendingInterventionTarget(ifMatching: self.target)
            if !success {
                self.stage = .opening(fallbackMessage: fallbackMessage)
                // The same budget remains armed for a manual launch.
            }
            self.isAwaitingTargetOpen = false
        }
    }

    private func beginInterventionAndBreathing(using engine: InterventionEngine) throws {
        guard case .catalog(let catalogTarget) = target else { return }
        let resolvedRuleID = try model.ruleStore.catalogTargetRule(for: catalogTarget).id
        let current = try engine.currentStep()
        let resumable: Set<InterventionStep> = [.idle, .cancelled, .postUseReflection]
        if !resumable.contains(current) {
            try engine.resetToIdle()
        }
        try engine.beginIntervention(ruleId: resolvedRuleID)
        todayAttemptDisplayCount = model.todayAttemptCount(for: resolvedRuleID) + 1
        selectedReason = nil
        usesTimeLimit = true
        blocksNecessaryUse = false
        beginBreathing()
    }

    private func beginPassThrough(to catalogTarget: SNSAppCatalogItem, until: Date) {
        let remainingMinutes = max(
            1,
            Int(ceil(until.timeIntervalSince(model.currentDate) / 60))
        )
        stage = .passingThrough(remainingMinutes: remainingMinutes)
        isAwaitingTargetOpen = true
        let fallbackMessage = String(
            localized: "intervention.opening.manual_fallback",
            defaultValue: "ホーム画面から\(catalogTarget.displayName)を開いてください"
        )

        passThroughTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard let self, !Task.isCancelled else { return }
            guard let urlScheme = catalogTarget.urlScheme, let url = URL(string: urlScheme) else {
                self.isAwaitingTargetOpen = false
                self.stage = .opening(fallbackMessage: fallbackMessage)
                return
            }
            self.model.markSelfOpened(catalogID: catalogTarget.catalogID)
            self.openURL(url) { [weak self] success in
                guard let self else { return }
                self.model.discardPendingInterventionTarget(ifMatching: self.target)
                if !success {
                    self.stage = .opening(fallbackMessage: fallbackMessage)
                }
                self.isAwaitingTargetOpen = false
            }
        }
    }

}
