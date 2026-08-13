import DopaBreakCore
import Foundation

/// オンボーディングで編集中の目標1件。
///
/// オンボは「戻る→再入場→編集→次へ」で同じ画面を何度も通る。
/// 画面の状態と保存済みデータの差分をビューへ埋めると重複追加や取りこぼしが起きるため、
/// 差分の材料になる値だけをここへ切り出す。
struct OnboardingGoalDraft: Identifiable, Equatable {
    /// リスト内の識別子。新規追加を保存するときの`Goal.id`にもこの値を使う。
    let id: UUID
    /// すでに保存されている目標のID。この画面で足しただけの行はnil。
    let persistedID: UUID?
    /// 表示・保存に使う文字列。`OnboardingGoalList.normalize`済み。
    let title: String
}

/// 保存済み目標のタイトルだけを差し替える指示。
struct OnboardingGoalTitleUpdate: Equatable {
    let id: UUID
    let title: String
}

/// 差分の基準になる、画面へ入った時点（と直近の保存時点）の保存済み目標。
///
/// 「いま保存されているのにリストに無いものを消す」だけでは、画面を開いている間に
/// 別経路で増えた目標まで巻き込んで消してしまう。基準を持ち、
/// 「基準にあった目標をユーザーが明示的に外したときだけ消す」ようにする。
struct OnboardingGoalBaseline: Equatable {
    private let titlesByID: [UUID: String]

    init(goals: [Goal] = []) {
        titlesByID = Dictionary(
            goals.map { ($0.id, $0.title) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func contains(_ id: UUID) -> Bool {
        titlesByID[id] != nil
    }

    /// 基準時点のタイトル。基準に無いIDはnil。
    func title(for id: UUID) -> String? {
        titlesByID[id]
    }
}

/// 編集中リストを保存済みデータへ反映するための差分。
struct OnboardingGoalSyncPlan: Equatable {
    /// リストから消えた保存済み目標のID。
    var deletedIDs: [UUID] = []
    /// タイトルが変わった保存済み目標。
    var updates: [OnboardingGoalTitleUpdate] = []
    /// まだ保存されていない目標。
    var insertions: [OnboardingGoalDraft] = []

    var isEmpty: Bool {
        deletedIDs.isEmpty && updates.isEmpty && insertions.isEmpty
    }
}

/// 目標リストの正規化・追加・復元・差分計算。副作用を持たない値の変換だけを置く。
enum OnboardingGoalList {
    /// 目標の文字数上限。
    ///
    /// 入力した言葉はそのままロック画面へ出るため、ロック面に収まる長さを入力側の上限にする
    /// （2026-08-08の入力一本化。旧仕様は目標40字＋ロック用の短縮名16字の2段入力だった）。
    static let titleLimit = 16

    /// 入力値を保存・比較に使う形へ整える。前後の空白を落とし、上限で切る。
    static func normalize(_ rawTitle: String) -> String {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > titleLimit else {
            return trimmed
        }
        // 切った位置が空白に当たると末尾へ空白が残るため、切ってからもう一度落とす
        return String(trimmed.prefix(titleLimit)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 正規化後に同じ文字列がリストへ入っているか。プリセットチップの選択状態にも使う。
    static func contains(_ rawTitle: String, in drafts: [OnboardingGoalDraft]) -> Bool {
        let title = normalize(rawTitle)
        guard !title.isEmpty else {
            return false
        }
        return drafts.contains { $0.title == title }
    }

    /// リストへ1件足す。空文字と重複（正規化後の完全一致）は足さず、元のリストをそのまま返す。
    static func appending(
        _ rawTitle: String,
        to drafts: [OnboardingGoalDraft],
        idProvider: () -> UUID = UUID.init
    ) -> [OnboardingGoalDraft] {
        let title = normalize(rawTitle)
        guard !title.isEmpty, !contains(title, in: drafts) else {
            return drafts
        }
        return drafts + [OnboardingGoalDraft(id: idProvider(), persistedID: nil, title: title)]
    }

    /// 保存済み目標からリストを作る。オンボ入場時と保存直後の組み直しに使う。
    ///
    /// ここでは重複を落とさない。上限を超える既存データ（旧40字）は正規化すると先頭16字が
    /// 一致することがあり、落とすと差分計算が「リストから消えた」と見なして削除してしまう。
    static func restore(from goals: [Goal]) -> [OnboardingGoalDraft] {
        goals.map { goal in
            OnboardingGoalDraft(
                id: goal.id,
                persistedID: goal.id,
                title: normalize(goal.title)
            )
        }
    }

    /// 編集中リストと保存済み目標の差分を、基準時点との三者比較で出す。
    ///
    /// - 削除: 基準にあった目標をユーザーがリストから外したときだけ。
    ///   画面を開いている間に別経路で増えた目標は基準に無いため、触らない。
    /// - 更新: 基準時点のタイトルから変わったときだけ。
    ///   ユーザーが触っていない行は、外で書き換えられていても巻き戻さない。
    /// - 追加: まだ保存されていない行。
    static func syncPlan(
        drafts: [OnboardingGoalDraft],
        persisted: [Goal],
        baseline: OnboardingGoalBaseline
    ) -> OnboardingGoalSyncPlan {
        let persistedIDs = Set(persisted.map(\.id))
        var plan = OnboardingGoalSyncPlan()
        var keptIDs: Set<UUID> = []

        for draft in drafts {
            guard !draft.title.isEmpty else {
                continue
            }
            guard let persistedID = draft.persistedID,
                  persistedIDs.contains(persistedID) else {
                // 保存済みの実体が無い行。外で消されただけで、この画面では触っていないなら、
                // その削除を受け入れて復活させない。触っているときだけ作り直す
                guard isEditedInThisScreen(draft, baseline: baseline) else {
                    continue
                }
                plan.insertions.append(draft)
                continue
            }
            keptIDs.insert(persistedID)
            guard let baselineTitle = baseline.title(for: persistedID) else {
                // 基準に無い＝この画面を開いたあとに外から増えた目標。書き換えない
                continue
            }
            if baselineTitle != draft.title {
                plan.updates.append(OnboardingGoalTitleUpdate(id: persistedID, title: draft.title))
            }
        }

        // 並び順は保存済みの順に従える。Setの列挙順に依存させない
        plan.deletedIDs = persisted.map(\.id).filter { id in
            baseline.contains(id) && !keptIDs.contains(id)
        }
        return plan
    }

    /// この画面でユーザーが文字を変えたか。
    ///
    /// 上限に合わせた切り詰め（旧40字データの16字化）は「触った」に数えない。
    /// 判断がつかない行（基準に無い）は、内容を失わない側＝触った扱いにする。
    ///
    /// 保存の要否を見る比較とは別物なので分けてある。保存の要否は基準の生の文字列と比べる
    /// （切り詰めも書き込みが要る）。ここは「ユーザーの意思があったか」だけを見る。
    private static func isEditedInThisScreen(
        _ draft: OnboardingGoalDraft,
        baseline: OnboardingGoalBaseline
    ) -> Bool {
        guard let persistedID = draft.persistedID,
              let baselineTitle = baseline.title(for: persistedID) else {
            return true
        }
        return normalize(baselineTitle) != draft.title
    }

    /// 差分を保存済みデータへ当てて、書き込むべき全件を組み立てる。
    ///
    /// 1件ずつ保存すると途中で失敗したときに既存の目標を落とすため、
    /// ここで最終形を作ってから1回で書き込む。
    static func merged(
        plan: OnboardingGoalSyncPlan,
        into goals: [Goal],
        category: GoalCategory,
        now: Date
    ) -> [Goal] {
        var merged = goals.filter { !plan.deletedIDs.contains($0.id) }

        for update in plan.updates {
            guard let index = merged.firstIndex(where: { $0.id == update.id }) else {
                continue
            }
            merged[index].title = update.title
            merged[index].lockScreenTitle = nil
            merged[index].updatedAt = now
        }

        for draft in plan.insertions {
            merged.append(
                Goal(
                    id: draft.id,
                    title: draft.title,
                    lockScreenTitle: nil,
                    category: category,
                    displayImagePath: nil,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }

        return merged
    }
}
