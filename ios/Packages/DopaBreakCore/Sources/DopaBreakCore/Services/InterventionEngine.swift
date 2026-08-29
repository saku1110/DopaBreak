import Foundation

/// 介入フローの状態機械エンジン（doc05 §5 介入状態遷移 / §6 介入ロジック）。
///
/// - `InterventionState` を毎回のミューテーション後に `SnapshotFile.interventionState` に永続化する。
/// - 状態は遅延読み込みし、ファイルが無ければ idle として扱う。
/// - `AttemptLog` / `ReflectionLog` は共有 `SQLiteLogStore` に書き込む（本体アプリと
///   Shield Extension が別プロセスから同じ App Group を読むため、状態も永続する必要がある）。
public final class InterventionEngine {
    private let snapshotStore: JSONSnapshotStore
    private let logStore: SQLiteLogStore
    private let now: () -> Date

    /// インスタンス内キャッシュ。別インスタンスはスナップショットから再読込する。
    private var cachedState: InterventionState?

    private static let beginAllowedSteps: Set<InterventionStep> = [.idle, .cancelled, .postUseReflection]

    /// リフレクションを解決（回答/スキップ）したとき idle へ戻してよいステップ集合。
    /// これ以外（例: 新しい介入が breathing 中）に非同期の回答/スキップが届いても、
    /// 進行中の介入を idle で潰さないよう状態はそのままにする。
    private static let reflectionFlowSteps: Set<InterventionStep> = [
        .temporarilyAllowed, .reShieldScheduled, .postUseReflection
    ]

    /// 線形進行（doc05 §5）: shieldPresented → breathing → usageSummary → intentSelection → decision。
    private static let linearNext: [InterventionStep: InterventionStep] = [
        .shieldPresented: .breathing,
        .breathing: .usageSummary,
        .usageSummary: .intentSelection,
        .intentSelection: .decision
    ]

    public init(
        snapshotStore: JSONSnapshotStore,
        logStore: SQLiteLogStore,
        now: @escaping () -> Date = Date.init
    ) {
        self.snapshotStore = snapshotStore
        self.logStore = logStore
        self.now = now
    }

    // MARK: - 状態参照

    /// 現在の状態。未保存なら idle を返す（遅延読み込み・doc05 §5）。
    public func currentState() throws -> InterventionState {
        if let cachedState {
            return cachedState
        }
        let loaded = try snapshotStore.read(InterventionState.self, from: .interventionState) ?? idleState(at: now())
        cachedState = loaded
        return loaded
    }

    public func currentStep() throws -> InterventionStep {
        try currentState().currentStep
    }

    // MARK: - 遷移

    /// 介入を開始する。idle / cancelled / postUseReflection からのみ許可（後二者はクラッシュ復帰用）。
    public func beginIntervention(ruleId: UUID) throws {
        let state = try currentState()
        guard Self.beginAllowedSteps.contains(state.currentStep) else {
            throw InterventionEngineError.invalidTransition(from: state.currentStep, action: "beginIntervention")
        }
        let timestamp = now()
        // 新しい介入では intent を持たない状態から開始する（前フローの意図を引き継がない）。
        try persist(
            InterventionState(
                currentStep: .shieldPresented,
                ruleId: ruleId,
                startedAt: timestamp,
                updatedAt: timestamp,
                allowedUntil: nil,
                intent: nil
            )
        )
    }

    /// 目的確認を最初に行う新フロー向けに、開始直後の状態から intentSelection へ進める。
    /// 既存の線形フローは後方互換のため残し、呼び出し側がどちらを使うか選択する。
    public func beginIntentSelection() throws {
        let state = try currentState()
        guard state.currentStep == .shieldPresented else {
            throw InterventionEngineError.invalidTransition(
                from: state.currentStep,
                action: "beginIntentSelection"
            )
        }
        try persist(state.with(step: .intentSelection, updatedAt: now()))
    }

    /// 線形に 1 ステップ進める。progression 外では invalidTransition を投げる。
    @discardableResult
    public func advanceStep() throws -> InterventionStep {
        let state = try currentState()
        guard let next = Self.linearNext[state.currentStep] else {
            throw InterventionEngineError.invalidTransition(from: state.currentStep, action: "advanceStep")
        }
        try persist(state.with(step: next, updatedAt: now()))
        return next
    }

    /// 意図カテゴリを記録する（intentSelection / decision のみ）。AttemptLog へ持ち越すため
    /// 永続スナップショットに書き込む。これにより別プロセス（ShieldAction 拡張）の新しい
    /// エンジンインスタンスでも recordCancel / recordOpen 時に意図を復元できる。
    public func recordIntent(_ intent: IntentCategory) throws {
        let state = try currentState()
        guard state.currentStep == .intentSelection || state.currentStep == .decision else {
            throw InterventionEngineError.invalidTransition(from: state.currentStep, action: "recordIntent")
        }
        try persist(state.with(intent: intent, updatedAt: now()))
    }

    /// 「開かない」。decision または intentSelection から許可。AttemptLog(cancelled) を書き、cancelled → idle へ。
    public func recordCancel() throws {
        let state = try currentState()
        guard state.currentStep == .decision || state.currentStep == .intentSelection else {
            throw InterventionEngineError.invalidTransition(from: state.currentStep, action: "recordCancel")
        }
        let ruleId = try requireRule(state, action: "recordCancel")
        let timestamp = now()
        let log = AttemptLog(
            id: UUID(),
            ruleId: ruleId,
            startedAt: state.startedAt ?? timestamp,
            completedAt: timestamp,
            decision: .cancelled,
            intent: state.intent,
            selectedDurationSeconds: nil,
            attemptCount24h: try attemptCount24h(ruleId: ruleId, before: timestamp),
            opened: false
        )
        let reclaimedSeconds = try ReclaimedTimeEstimator.estimatedSeconds(
            at: timestamp,
            logStore: logStore
        )
        try logStore.insertCancelledAttempt(log, reclaimedSeconds: reclaimedSeconds)
        // idle へ戻す際に intent はクリアされる（idleContext / idleState は intent = nil）。
        try resolveToIdle(via: .cancelled, at: timestamp)
    }

    /// 時間を計測せずに対象アプリを開く。通常のSNS起動では他社アプリの実利用時間を
    /// 取得できないため、選択時間・終了予定・利用後リフレクションを作らず opened の事実だけを記録する。
    public func recordUntimedOpen() throws {
        let state = try currentState()
        guard state.currentStep == .decision else {
            throw InterventionEngineError.invalidTransition(from: state.currentStep, action: "recordUntimedOpen")
        }
        let ruleId = try requireRule(state, action: "recordUntimedOpen")
        let timestamp = now()
        try logStore.insert(
            AttemptLog(
                id: UUID(),
                ruleId: ruleId,
                startedAt: state.startedAt ?? timestamp,
                completedAt: timestamp,
                decision: .opened,
                intent: state.intent,
                selectedDurationSeconds: nil,
                attemptCount24h: try attemptCount24h(ruleId: ruleId, before: timestamp),
                opened: true
            )
        )
        try persist(idleState(at: timestamp))
    }

    /// 時間を決めてシールドを一時解除する。decision からのみ。AttemptLog(opened) と
    /// 未回答 ReflectionLog を作成し、timeSelection → temporarilyAllowed へ進める。
    /// 通常のSNS起動には使わず、実際に解除期限を制御できるgateToken専用とする。
    public func recordOpen(durationSeconds: Int) throws {
        let state = try currentState()
        guard state.currentStep == .decision else {
            throw InterventionEngineError.invalidTransition(from: state.currentStep, action: "recordOpen")
        }
        guard durationSeconds > 0 else {
            throw CoreError.validation(message: "durationSeconds must be positive")
        }
        let ruleId = try requireRule(state, action: "recordOpen")
        let timestamp = now()
        let allowedUntil = timestamp.addingTimeInterval(TimeInterval(durationSeconds))
        let attemptId = UUID()
        try logStore.insert(
            AttemptLog(
                id: attemptId,
                ruleId: ruleId,
                startedAt: state.startedAt ?? timestamp,
                completedAt: timestamp,
                decision: .opened,
                intent: state.intent,
                selectedDurationSeconds: durationSeconds,
                attemptCount24h: try attemptCount24h(ruleId: ruleId, before: timestamp),
                opened: true
            )
        )
        // doc05 §6: ReflectionLog を未回答状態で作成。促し時刻は選択時間の終了時刻。
        try logStore.insert(
            ReflectionLog(
                id: UUID(),
                attemptLogId: attemptId,
                ruleId: ruleId,
                promptedAt: allowedUntil,
                answeredAt: nil,
                trigger: .timedSessionEnded,
                satisfaction: nil,
                happinessDelta: nil,
                skipped: false,
                createdAt: timestamp
            )
        )
        // timeSelection / temporarilyAllowed へ遷移する際に intent はクリアされる（intent = nil）。
        try persist(InterventionState(currentStep: .timeSelection, ruleId: ruleId, startedAt: state.startedAt, updatedAt: timestamp, allowedUntil: nil))
        try persist(InterventionState(currentStep: .temporarilyAllowed, ruleId: ruleId, startedAt: state.startedAt, updatedAt: timestamp, allowedUntil: allowedUntil))
    }

    /// 一時開放が満了していれば再シールド予定へ遷移し true を返す。
    @discardableResult
    public func reshieldIfExpired() throws -> Bool {
        let state = try currentState()
        guard state.currentStep == .temporarilyAllowed, let allowedUntil = state.allowedUntil else {
            return false
        }
        guard now() >= allowedUntil else {
            return false
        }
        try persist(
            InterventionState(
                currentStep: .reShieldScheduled,
                ruleId: state.ruleId,
                startedAt: state.startedAt,
                updatedAt: now(),
                allowedUntil: allowedUntil
            )
        )
        return true
    }

    /// 直近セッションから `window` 秒以内（既定 1800）の未回答リフレクションのうち最新のものを返す（doc05 §6）。
    /// リフレクションはセッション終了以降に促されるため、promptedAt が現在以前で経過が window 以内のものだけを対象にする。
    ///
    /// 取得は `fetchReflections(from:)` で時間窓に絞る。`fetchUnansweredReflections` は
    /// prompted_at ASC + 件数 LIMIT のため、古い未回答が大量に溜まると新しい対象を取りこぼす
    /// 恐れがあった（レビュー指摘 2026-07-02）。時間窓で絞ればその取りこぼしは起きない。
    public func pendingReflection(within window: TimeInterval = 1800) throws -> ReflectionLog? {
        let reference = now()
        let candidates = try logStore.fetchReflections(from: reference.addingTimeInterval(-window))
        let eligible = candidates.filter { reflection in
            guard reflection.answeredAt == nil, !reflection.skipped else { return false }
            let age = reference.timeIntervalSince(reflection.promptedAt)
            return age >= 0 && age <= window
        }
        return eligible.max { $0.promptedAt < $1.promptedAt }
    }

    /// 利用後リフレクションを回答として保存し、リフレクションフロー中なら idle へ戻す。
    /// `id` は pendingReflection() が返した対象を渡す契約。状態解決は reflectionFlowSteps に
    /// いる場合のみ行うため、進行中の新しい介入（shieldPresented..decision）を潰すことはない。
    public func recordPostUseReflection(
        id: UUID,
        satisfaction: PostUseSatisfaction,
        happinessDelta: HappinessDelta
    ) throws {
        let timestamp = now()
        try logStore.updateAnswers(
            reflectionID: id,
            satisfaction: satisfaction,
            happinessDelta: happinessDelta,
            answeredAt: timestamp
        )
        try resolveReflectionFlow(intermediate: .postUseReflection, at: timestamp)
    }

    /// リフレクションをスキップ扱いにし（共有DBへ永続化）、実際にスキップできたときだけ
    /// リフレクションフロー中なら idle へ戻す。既に回答/スキップ済みや不明IDは冪等な no-op。
    public func skipReflection(id: UUID) throws {
        let didSkip = try ReflectionSkipWriter.markSkipped(reflectionID: id, databaseURL: try reflectionDatabaseURL())
        guard didSkip else {
            return
        }
        try resolveReflectionFlow(intermediate: nil, at: now())
    }

    /// 状態を idle に戻す（コンテキストをクリア。idleState は intent = nil）。
    public func resetToIdle() throws {
        try persist(idleState(at: now()))
    }

    // MARK: - 内部処理

    /// trailing 24h の同一ルール試行数 + 1（書き込み時点で算出・doc05 §4）。
    private func attemptCount24h(ruleId: UUID, before reference: Date) throws -> Int {
        let windowStart = reference.addingTimeInterval(-24 * 60 * 60)
        let prior = try logStore.fetchAttempts(from: windowStart, to: reference)
            .filter { $0.ruleId == ruleId }
        return prior.count + 1
    }

    private func requireRule(_ state: InterventionState, action: String) throws -> UUID {
        guard let ruleId = state.ruleId else {
            throw InterventionEngineError.missingRule(action: action)
        }
        return ruleId
    }

    /// リフレクション解決の状態遷移。フロー中のみ (intermediate →) idle へ。フロー外なら状態は不変。
    private func resolveReflectionFlow(intermediate: InterventionStep?, at timestamp: Date) throws {
        let state = try currentState()
        guard Self.reflectionFlowSteps.contains(state.currentStep) else {
            return
        }
        if let intermediate {
            try persist(idleContext(step: intermediate, at: timestamp))
        }
        try persist(idleState(at: timestamp))
    }

    /// intermediate ステップを経由して idle に戻す（cancelled → idle など）。
    /// 中間状態も永続することでクラッシュ復帰時に beginIntervention が受理できる。
    private func resolveToIdle(via intermediate: InterventionStep, at timestamp: Date) throws {
        try persist(idleContext(step: intermediate, at: timestamp))
        try persist(idleState(at: timestamp))
    }

    private func persist(_ state: InterventionState) throws {
        try snapshotStore.write(state, to: .interventionState)
        cachedState = state
    }

    private func idleState(at timestamp: Date) -> InterventionState {
        InterventionState(currentStep: .idle, ruleId: nil, startedAt: nil, updatedAt: timestamp, allowedUntil: nil)
    }

    private func idleContext(step: InterventionStep, at timestamp: Date) -> InterventionState {
        InterventionState(currentStep: step, ruleId: nil, startedAt: nil, updatedAt: timestamp, allowedUntil: nil)
    }

    /// reflection_logs.sqlite の URL。
    /// 前提条件: snapshotStore と logStore は同一 App Group コンテナを共有する（doc05 §8 のアーキテクチャ。
    /// 本番は両者とも AppGroupContainer、テストは同一 FixedContainer）。init は独立した 2 ストアを受け取るが、
    /// logStore はパスを公開しないため URL は snapshotStore 側から導出する。誤設定時は READWRITE-only の
    /// オープンが失敗して throw する（空DBを作らない）ので、静かな別DB書き込みは起きない。
    private func reflectionDatabaseURL() throws -> URL {
        let stateURL = try snapshotStore.url(for: .interventionState)
        return stateURL.deletingLastPathComponent().appendingPathComponent("reflection_logs.sqlite")
    }
}

private extension InterventionState {
    /// ステップと更新時刻だけを差し替えた新しい状態を返す（intent 等の他フィールドは保持）。
    /// intentSelection で意図を記録した後に advanceStep で decision へ進んでも意図が失われないよう、
    /// intent を必ず引き継ぐ。
    func with(step: InterventionStep, updatedAt: Date) -> InterventionState {
        InterventionState(
            currentStep: step,
            ruleId: ruleId,
            startedAt: startedAt,
            updatedAt: updatedAt,
            allowedUntil: allowedUntil,
            intent: intent
        )
    }

    /// 意図と更新時刻だけを差し替えた新しい状態を返す（ステップ等の他フィールドは保持）。
    func with(intent: IntentCategory, updatedAt: Date) -> InterventionState {
        InterventionState(
            currentStep: currentStep,
            ruleId: ruleId,
            startedAt: startedAt,
            updatedAt: updatedAt,
            allowedUntil: allowedUntil,
            intent: intent
        )
    }
}
