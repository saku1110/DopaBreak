import DopaBreakCore
import Foundation
import XCTest

@testable import DopaBreak

/// オンボーディングの目標リストと保存済みデータの同期を固定する。
///
/// この画面は「戻る→再入場→編集→次へ」で何度も通る。差分の出し方を間違えると
/// 同じ目標が増える・消したはずの目標が残る・外の変更を巻き戻すといった形でデータへ残るため、
/// 追加・更新・削除の判定をビューから切り離して回帰させる。
final class OnboardingGoalDraftsTests: XCTestCase {
    private let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeGoal(
        id: UUID = UUID(),
        title: String,
        lockScreenTitle: String? = nil,
        category: GoalCategory = .other
    ) -> Goal {
        Goal(
            id: id,
            title: title,
            lockScreenTitle: lockScreenTitle,
            category: category,
            displayImagePath: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    private func draft(_ title: String, id: UUID = UUID(), persistedID: UUID? = nil) -> OnboardingGoalDraft {
        OnboardingGoalDraft(id: id, persistedID: persistedID, title: title)
    }

    // MARK: - 正規化

    func testNormalizeTrimsSurroundingWhitespaceAndClipsAtTheLimit() {
        XCTAssertEqual(OnboardingGoalList.normalize("  英語で話す  "), "英語で話す")
        XCTAssertEqual(OnboardingGoalList.normalize("\n\n"), "")
        XCTAssertEqual(OnboardingGoalList.titleLimit, 16)

        // 上限ちょうどは切らない
        let exact = String(repeating: "あ", count: 16)
        XCTAssertEqual(OnboardingGoalList.normalize(exact), exact)

        // 超過分は落とす
        let long = String(repeating: "あ", count: 40)
        XCTAssertEqual(OnboardingGoalList.normalize(long).count, 16)

        // 切った位置が空白に当たっても末尾へ空白を残さない
        let spaced = String(repeating: "あ", count: 16) + " いろは"
        XCTAssertEqual(OnboardingGoalList.normalize(spaced), String(repeating: "あ", count: 16))
    }

    // MARK: - 追加

    func testAppendingIgnoresEmptyAndDuplicateTitles() {
        var drafts: [OnboardingGoalDraft] = []
        drafts = OnboardingGoalList.appending("  ", to: drafts)
        XCTAssertTrue(drafts.isEmpty, "空文字が足された")

        drafts = OnboardingGoalList.appending(" 読書を30分 ", to: drafts)
        XCTAssertEqual(drafts.map(\.title), ["読書を30分"])
        XCTAssertNil(drafts[0].persistedID, "この画面で足した行は未保存として扱う")

        // 前後の空白違いは同じ言葉として扱う
        drafts = OnboardingGoalList.appending("読書を30分", to: drafts)
        drafts = OnboardingGoalList.appending("  読書を30分", to: drafts)
        XCTAssertEqual(drafts.count, 1, "重複が足された")

        // 上限超過の入力は切ってから比較する
        let long = String(repeating: "あ", count: 20)
        drafts = OnboardingGoalList.appending(long, to: drafts)
        drafts = OnboardingGoalList.appending(String(repeating: "あ", count: 16), to: drafts)
        XCTAssertEqual(drafts.count, 2, "切り詰め後に同じになる入力が重複して足された")
        XCTAssertEqual(drafts[1].title.count, 16)
    }

    func testAppendingKeepsOrderAndUsesTheProvidedIdentifier() {
        let first = UUID()
        let second = UUID()
        var drafts = OnboardingGoalList.appending("読書を30分", to: [], idProvider: { first })
        drafts = OnboardingGoalList.appending("筋トレを続ける", to: drafts, idProvider: { second })

        XCTAssertEqual(drafts.map(\.id), [first, second])
        XCTAssertEqual(drafts.map(\.title), ["読書を30分", "筋トレを続ける"])
    }

    func testContainsComparesNormalizedTitles() {
        let drafts = OnboardingGoalList.appending("資格の勉強", to: [])
        XCTAssertTrue(OnboardingGoalList.contains(" 資格の勉強 ", in: drafts))
        XCTAssertFalse(OnboardingGoalList.contains("読書を30分", in: drafts))
        XCTAssertFalse(OnboardingGoalList.contains("   ", in: drafts))
    }

    // MARK: - 復元

    func testRestoreKeepsIdentifiersAndClipsLegacyTitles() {
        let shortID = UUID()
        let longID = UUID()
        let goals = [
            makeGoal(id: shortID, title: "英語で話す"),
            makeGoal(id: longID, title: String(repeating: "あ", count: 40))
        ]

        let drafts = OnboardingGoalList.restore(from: goals)

        XCTAssertEqual(drafts.map(\.id), [shortID, longID])
        XCTAssertEqual(drafts.map(\.persistedID), [shortID, longID])
        XCTAssertEqual(drafts[0].title, "英語で話す")
        XCTAssertEqual(drafts[1].title, String(repeating: "あ", count: 16))
    }

    /// 先頭16字が一致する既存データを落とすと、差分計算が「消えた」と誤読して削除してしまう。
    func testRestoreKeepsGoalsThatShareTheSameClippedTitle() {
        let goals = [
            makeGoal(title: String(repeating: "あ", count: 16) + "1"),
            makeGoal(title: String(repeating: "あ", count: 16) + "2")
        ]

        let drafts = OnboardingGoalList.restore(from: goals)

        XCTAssertEqual(drafts.count, 2)
        let plan = OnboardingGoalList.syncPlan(
            drafts: drafts,
            persisted: goals,
            baseline: OnboardingGoalBaseline(goals: goals)
        )
        XCTAssertTrue(plan.deletedIDs.isEmpty)
    }

    // MARK: - 差分

    func testSyncPlanIsEmptyWhenNothingChanged() {
        let goals = [makeGoal(title: "英語で話す"), makeGoal(title: "読書を30分")]
        let plan = OnboardingGoalList.syncPlan(
            drafts: OnboardingGoalList.restore(from: goals),
            persisted: goals,
            baseline: OnboardingGoalBaseline(goals: goals)
        )

        XCTAssertTrue(plan.isEmpty, "変更していないのに保存が走る")
    }

    func testSyncPlanUpdatesOnlyTheChangedTitle() {
        let keptID = UUID()
        let editedID = UUID()
        let goals = [
            makeGoal(id: keptID, title: "英語で話す"),
            makeGoal(id: editedID, title: "読書を30分")
        ]
        var drafts = OnboardingGoalList.restore(from: goals)
        drafts[1] = OnboardingGoalDraft(id: editedID, persistedID: editedID, title: "読書を60分")

        let plan = OnboardingGoalList.syncPlan(
            drafts: drafts,
            persisted: goals,
            baseline: OnboardingGoalBaseline(goals: goals)
        )

        XCTAssertEqual(plan.updates, [OnboardingGoalTitleUpdate(id: editedID, title: "読書を60分")])
        XCTAssertTrue(plan.deletedIDs.isEmpty)
        XCTAssertTrue(plan.insertions.isEmpty)
    }

    func testSyncPlanDeletesRowsRemovedFromTheList() {
        let keptID = UUID()
        let removedID = UUID()
        let goals = [
            makeGoal(id: keptID, title: "英語で話す"),
            makeGoal(id: removedID, title: "読書を30分")
        ]
        let drafts = OnboardingGoalList.restore(from: goals).filter { $0.id == keptID }

        let plan = OnboardingGoalList.syncPlan(
            drafts: drafts,
            persisted: goals,
            baseline: OnboardingGoalBaseline(goals: goals)
        )

        XCTAssertEqual(plan.deletedIDs, [removedID])
        XCTAssertTrue(plan.updates.isEmpty)
        XCTAssertTrue(plan.insertions.isEmpty)
    }

    func testSyncPlanInsertsNewRowsWithTheirDraftIdentifier() {
        let existingID = UUID()
        let newID = UUID()
        let goals = [makeGoal(id: existingID, title: "英語で話す")]
        let drafts = OnboardingGoalList.restore(from: goals)
            + [draft("筋トレを続ける", id: newID)]

        let plan = OnboardingGoalList.syncPlan(
            drafts: drafts,
            persisted: goals,
            baseline: OnboardingGoalBaseline(goals: goals)
        )

        XCTAssertEqual(plan.insertions.map(\.id), [newID])
        XCTAssertEqual(plan.insertions.map(\.title), ["筋トレを続ける"])
        XCTAssertTrue(plan.deletedIDs.isEmpty)
        XCTAssertTrue(plan.updates.isEmpty)
    }

    /// 別経路（設定画面など）で消された目標を、この画面では触っていないなら復活させない。
    /// 復活させると、消したはずの目標がIDごと戻ってくる。
    func testSyncPlanAcceptsOutsideDeletionForUntouchedDrafts() {
        let missingID = UUID()
        let entryGoals = [makeGoal(id: missingID, title: "英語で話す")]
        let baseline = OnboardingGoalBaseline(goals: entryGoals)
        let drafts = OnboardingGoalList.restore(from: entryGoals)

        let plan = OnboardingGoalList.syncPlan(drafts: drafts, persisted: [], baseline: baseline)

        XCTAssertTrue(plan.insertions.isEmpty, "外で消された目標を復活させている")
        XCTAssertTrue(plan.deletedIDs.isEmpty, "すでに無いIDへ削除をかけている")
        XCTAssertTrue(plan.isEmpty)
    }

    /// 16字への切り詰めだけで内容が同じ行も「触っていない」と見なす。
    func testSyncPlanAcceptsOutsideDeletionForClippedLegacyDrafts() {
        let missingID = UUID()
        let entryGoals = [makeGoal(id: missingID, title: String(repeating: "あ", count: 40))]
        let baseline = OnboardingGoalBaseline(goals: entryGoals)
        let drafts = OnboardingGoalList.restore(from: entryGoals)

        let plan = OnboardingGoalList.syncPlan(drafts: drafts, persisted: [], baseline: baseline)

        XCTAssertTrue(plan.insertions.isEmpty, "切り詰めただけの行を編集扱いで復活させている")
        XCTAssertTrue(plan.isEmpty)
    }

    /// 外で消された目標をこの画面で書き換えていたなら、入力を失わせず作り直す。
    func testSyncPlanRecreatesEditedDraftsWhoseGoalDisappeared() {
        let missingID = UUID()
        let entryGoals = [makeGoal(id: missingID, title: "英語で話す")]
        let baseline = OnboardingGoalBaseline(goals: entryGoals)
        let drafts = [draft("英語で話し切る", id: missingID, persistedID: missingID)]

        let plan = OnboardingGoalList.syncPlan(drafts: drafts, persisted: [], baseline: baseline)

        XCTAssertEqual(plan.insertions.map(\.id), [missingID])
        XCTAssertEqual(plan.insertions.map(\.title), ["英語で話し切る"])
        XCTAssertTrue(plan.deletedIDs.isEmpty)
    }

    /// 基準に無い行（判断がつかない）は、内容を失わない側へ倒して作り直す。
    func testSyncPlanRecreatesDraftsWithNoBaselineEntry() {
        let unknownID = UUID()
        let drafts = [draft("英語で話す", id: unknownID, persistedID: unknownID)]

        let plan = OnboardingGoalList.syncPlan(
            drafts: drafts,
            persisted: [],
            baseline: OnboardingGoalBaseline()
        )

        XCTAssertEqual(plan.insertions.map(\.id), [unknownID])
    }

    func testSyncPlanSkipsEmptyTitles() {
        let goals = [makeGoal(title: "英語で話す")]
        let drafts = OnboardingGoalList.restore(from: goals) + [draft("")]

        let plan = OnboardingGoalList.syncPlan(
            drafts: drafts,
            persisted: goals,
            baseline: OnboardingGoalBaseline(goals: goals)
        )

        XCTAssertTrue(plan.isEmpty)
    }

    /// 上限を超える既存データは、この画面を通した時点で16字へ寄せる。
    func testSyncPlanClipsLegacyTitlesOnSave() {
        let legacyID = UUID()
        let goals = [makeGoal(id: legacyID, title: String(repeating: "あ", count: 40))]

        let plan = OnboardingGoalList.syncPlan(
            drafts: OnboardingGoalList.restore(from: goals),
            persisted: goals,
            baseline: OnboardingGoalBaseline(goals: goals)
        )

        XCTAssertEqual(
            plan.updates,
            [OnboardingGoalTitleUpdate(id: legacyID, title: String(repeating: "あ", count: 16))]
        )
    }

    // MARK: - 画面を開いている間の外からの変更

    /// 画面を開いたあとに別経路で増えた目標は、基準に無いので消さない。
    func testSyncPlanKeepsGoalsAddedOutsideWhileTheScreenIsOpen() {
        let ownID = UUID()
        let outsideID = UUID()
        let entryGoals = [makeGoal(id: ownID, title: "英語で話す")]
        let baseline = OnboardingGoalBaseline(goals: entryGoals)
        let drafts = OnboardingGoalList.restore(from: entryGoals)

        // 入場後に外から1件増えた
        let persisted = entryGoals + [makeGoal(id: outsideID, title: "外で足した目標")]

        let plan = OnboardingGoalList.syncPlan(drafts: drafts, persisted: persisted, baseline: baseline)

        XCTAssertTrue(plan.deletedIDs.isEmpty, "外で足された目標を消している")
        XCTAssertTrue(plan.isEmpty)

        let merged = OnboardingGoalList.merged(plan: plan, into: persisted, category: .other, now: timestamp)
        XCTAssertEqual(merged.map(\.id), [ownID, outsideID])
    }

    /// ユーザーが触っていない行は、外で書き換えられていても巻き戻さない。
    func testSyncPlanDoesNotRevertEditsMadeOutsideTheScreen() {
        let untouchedID = UUID()
        let editedID = UUID()
        let entryGoals = [
            makeGoal(id: untouchedID, title: "英語で話す"),
            makeGoal(id: editedID, title: "読書を30分")
        ]
        let baseline = OnboardingGoalBaseline(goals: entryGoals)
        var drafts = OnboardingGoalList.restore(from: entryGoals)
        // 2件目だけこの画面で書き換える
        drafts[1] = OnboardingGoalDraft(id: editedID, persistedID: editedID, title: "読書を60分")

        // 1件目は外で書き換えられた
        let persisted = [
            makeGoal(id: untouchedID, title: "外で書き換えた目標"),
            entryGoals[1]
        ]

        let plan = OnboardingGoalList.syncPlan(drafts: drafts, persisted: persisted, baseline: baseline)

        XCTAssertEqual(
            plan.updates,
            [OnboardingGoalTitleUpdate(id: editedID, title: "読書を60分")],
            "触っていない行まで書き戻している"
        )

        let merged = OnboardingGoalList.merged(plan: plan, into: persisted, category: .other, now: timestamp)
        XCTAssertEqual(merged.map(\.title), ["外で書き換えた目標", "読書を60分"])
    }

    /// 基準にあった目標を外で先に消されていた場合、削除は投げ直さない。
    func testSyncPlanSkipsDeletionsAlreadyAppliedOutside() {
        let removedID = UUID()
        let entryGoals = [makeGoal(id: removedID, title: "英語で話す")]
        let baseline = OnboardingGoalBaseline(goals: entryGoals)

        let plan = OnboardingGoalList.syncPlan(drafts: [], persisted: [], baseline: baseline)

        XCTAssertTrue(plan.isEmpty)
    }

    // MARK: - 書き込む全件の組み立て

    func testMergedAppliesDeletionsUpdatesAndInsertionsInOneList() {
        let keptID = UUID()
        let editedID = UUID()
        let removedID = UUID()
        let newID = UUID()
        let goals = [
            makeGoal(id: keptID, title: "英語で話す", lockScreenTitle: "英語", category: .study),
            makeGoal(id: editedID, title: "読書を30分", lockScreenTitle: "読書", category: .creative),
            makeGoal(id: removedID, title: "筋トレを続ける")
        ]
        let plan = OnboardingGoalSyncPlan(
            deletedIDs: [removedID],
            updates: [OnboardingGoalTitleUpdate(id: editedID, title: "読書を60分")],
            insertions: [draft("資格の勉強", id: newID)]
        )
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let merged = OnboardingGoalList.merged(plan: plan, into: goals, category: .work, now: now)

        XCTAssertEqual(merged.map(\.id), [keptID, editedID, newID])
        XCTAssertEqual(merged.map(\.title), ["英語で話す", "読書を60分", "資格の勉強"])

        // 触っていない目標は何も変えない
        XCTAssertEqual(merged[0], goals[0])
        // 書き換えた目標はカテゴリと作成日を保ち、旧ロック表示名だけ落とす
        XCTAssertEqual(merged[1].category, .creative)
        XCTAssertEqual(merged[1].createdAt, timestamp)
        XCTAssertNil(merged[1].lockScreenTitle)
        XCTAssertEqual(merged[1].updatedAt, now)
        // 新規はこの画面のカテゴリで作る
        XCTAssertEqual(merged[2].category, .work)
        XCTAssertNil(merged[2].lockScreenTitle)
        XCTAssertEqual(merged[2].createdAt, now)
    }

    // MARK: - 画面の往復

    /// 保存 → 戻る → 再入場 → 次へ で同じ目標が増えないこと。
    /// 保存後にリストと基準を組み直す実装（`persistDraftGoals`）と同じ順序で回す。
    func testSavingTwiceDoesNotDuplicateGoals() {
        var persisted: [Goal] = []
        var baseline = OnboardingGoalBaseline(goals: persisted)
        var drafts: [OnboardingGoalDraft] = []

        // 1回目: 入力途中のテキストを次へで拾って保存する
        drafts = OnboardingGoalList.appending("英語で話す", to: drafts)
        (persisted, drafts, baseline) = save(drafts: drafts, persisted: persisted, baseline: baseline)
        XCTAssertEqual(persisted.count, 1)

        // 2回目: 何も触らずもう一度次へ
        let secondPlan = OnboardingGoalList.syncPlan(
            drafts: drafts,
            persisted: persisted,
            baseline: baseline
        )
        XCTAssertTrue(secondPlan.isEmpty, "同じ内容の再保存で差分が出た")
        (persisted, drafts, baseline) = save(drafts: drafts, persisted: persisted, baseline: baseline)
        XCTAssertEqual(persisted.count, 1, "戻って進み直すと目標が増えた")

        // 3回目: 1件足して1件消す入れ替え
        drafts = OnboardingGoalList.appending("筋トレを続ける", to: drafts)
        drafts.removeAll { $0.title == "英語で話す" }
        let thirdPlan = OnboardingGoalList.syncPlan(
            drafts: drafts,
            persisted: persisted,
            baseline: baseline
        )
        XCTAssertEqual(thirdPlan.deletedIDs.count, 1)
        XCTAssertEqual(thirdPlan.insertions.count, 1)
        (persisted, drafts, _) = save(drafts: drafts, persisted: persisted, baseline: baseline)
        XCTAssertEqual(persisted.map(\.title), ["筋トレを続ける"])
    }

    /// 1回の保存を実装と同じ順序で通す（差分 → 全件の組み立て → リストと基準の組み直し）。
    private func save(
        drafts: [OnboardingGoalDraft],
        persisted: [Goal],
        baseline: OnboardingGoalBaseline
    ) -> ([Goal], [OnboardingGoalDraft], OnboardingGoalBaseline) {
        let plan = OnboardingGoalList.syncPlan(drafts: drafts, persisted: persisted, baseline: baseline)
        guard !plan.isEmpty else {
            return (persisted, drafts, baseline)
        }
        let merged = OnboardingGoalList.merged(
            plan: plan,
            into: persisted,
            category: .other,
            now: timestamp
        )
        return (merged, OnboardingGoalList.restore(from: merged), OnboardingGoalBaseline(goals: merged))
    }
}
