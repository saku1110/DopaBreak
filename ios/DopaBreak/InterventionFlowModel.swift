import DopaBreakCore
import Foundation
import Observation
import UIKit

/// 一呼吸を始める対象。カタログ起動とシールドからの一時開放を同じ流れへ載せる。
enum InterventionTarget: Equatable {
    case catalog(SNSAppCatalogItem)
    case gateToken(tokenData: Data, ruleId: UUID)

    /// SwiftUIの介入ルートを対象単位で作り直すための安定した識別子。
    var presentationID: String {
        switch self {
        case .catalog(let target):
            return "catalog:\(target.catalogID)"
        case .gateToken(let tokenData, let ruleId):
            return "gate:\(ruleId.uuidString):\(tokenData.base64EncodedString())"
        }
    }
}

/// 一呼吸フロー（S-01〜S-05・doc12 §2）の画面状態。
enum InterventionFlowStage: Equatable {
    case reflection(ReflectionLog)
    case breathing
    case usageSummary
    case reasonSelection
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

    private(set) var stage: InterventionFlowStage = .breathing
    private(set) var breathRemainingSeconds: Int
    private(set) var breathTotalSeconds: Int
    private(set) var todayAttemptDisplayCount = 0
    private(set) var selectedReason: InterventionReason?
    private(set) var selectedDuration: InterventionDuration = .tenMinutes
    private(set) var isAwaitingTargetOpen = false
    private(set) var winReclaimedSeconds = 0
    private(set) var winLifetimeReclaimedSeconds = 0
    private(set) var winEstimatedMinutesPerCancellation = 1
    private(set) var winMilestone: ReclaimedTimeMilestone?

    private var breathTask: Task<Void, Never>?
    private var startGeneration = 0

    private static let breathTimerTickNanoseconds: UInt64 = 250_000_000

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
        let breathDurationSeconds = settingsStore.breathDurationSeconds
        self.breathRemainingSeconds = breathDurationSeconds
        self.breathTotalSeconds = breathDurationSeconds
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
        breathTask?.cancel()
        breathTask = nil
        startGeneration += 1

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
            if let reflection = try engine.pendingReflection() {
                stage = .reflection(reflection)
                return
            }
            try beginInterventionAndBreathing(using: engine)
        } catch {
            stage = .failed(String(localized: "intervention.error.preparation", defaultValue: "準備できませんでした"))
        }
    }

    func recordReflection(_ satisfaction: PostUseSatisfaction) {
        guard case .reflection(let reflection) = stage,
              let engine = model.interventionEngine else { return }
        do {
            try engine.recordPostUseReflection(
                id: reflection.id,
                satisfaction: satisfaction,
                happinessDelta: satisfaction.impliedHappinessDelta
            )
            try beginInterventionAndBreathing(using: engine)
        } catch {
            stage = .failed(String(localized: "reflection.error.data_save", defaultValue: "データを保存できませんでした"))
        }
    }

    func skipReflection() {
        guard case .reflection(let reflection) = stage,
              let engine = model.interventionEngine else { return }
        do {
            try engine.skipReflection(id: reflection.id)
            try beginInterventionAndBreathing(using: engine)
        } catch {
            stage = .failed(String(localized: "reflection.error.data_save", defaultValue: "データを保存できませんでした"))
        }
    }

    func stop() {
        breathTask?.cancel()
        breathTask = nil
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
            breathRemainingSeconds = 0
            stage = .reasonSelection
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
        guard stage == .usageSummary || stage == .durationSelection else { return }
        guard let engine = model.interventionEngine else { return }
        do {
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
        switch target {
        case .catalog(let catalogTarget):
            openCatalogTarget(catalogTarget, for: selectedDuration)
        case .gateToken(let tokenData, let ruleId):
            openGateTarget(
                tokenData: tokenData,
                ruleId: ruleId,
                for: selectedDuration
            )
        }
    }

    private func proceedToOpenOrDurationSelection() {
        stage = .durationSelection
    }

    private func recordCatalogOpen(for duration: InterventionDuration) {
        guard let engine = model.interventionEngine else { return }
        do {
            try engine.recordCatalogOpen(durationSeconds: duration.seconds)
            model.refresh()
        } catch {
            stage = .failed(String(localized: "intervention.error.record", defaultValue: "記録できませんでした"))
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
            // URLスキームがないアプリは、この案内から手動で開く前提で宣言時間を記録する。
            recordCatalogOpen(for: duration)
            return
        }

        isAwaitingTargetOpen = true
        stage = .opening(fallbackMessage: nil)
        UIApplication.shared.open(url, options: [:]) { [weak self] success in
            guard let self else { return }
            if success {
                self.recordCatalogOpen(for: duration)
            } else {
                self.stage = .opening(fallbackMessage: fallbackMessage)
                // URL起動失敗時も、この案内から手動で開く前提で宣言時間を記録する。
                self.recordCatalogOpen(for: duration)
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
                defaultValue: "左上の◀をタップすると、\(duration.rawValue)分間開けます"
            )
        )
    }

    private func beginInterventionAndBreathing(using engine: InterventionEngine) throws {
        let resolvedRuleID: UUID
        switch target {
        case .catalog(let catalogTarget):
            resolvedRuleID = try model.ruleStore.catalogTargetRule(for: catalogTarget).id
        case .gateToken(_, let gateRuleID):
            resolvedRuleID = gateRuleID
        }
        let current = try engine.currentStep()
        let resumable: Set<InterventionStep> = [.idle, .cancelled, .postUseReflection]
        if !resumable.contains(current) {
            try engine.resetToIdle()
        }
        try engine.beginIntervention(ruleId: resolvedRuleID)
        todayAttemptDisplayCount = model.todayAttemptCount(for: resolvedRuleID) + 1
        selectedReason = nil
        beginBreathing()
    }

}
