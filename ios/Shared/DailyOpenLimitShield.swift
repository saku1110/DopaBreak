import DopaBreakCore
import FamilyControls
import Foundation
import ManagedSettings

/// 回数上限で止めるシールドを、アプリと拡張で同じ手順で掛け外しする。
///
/// どの経路から呼ばれても「最新の控えを読み、いま窓の内なら掛け、外なら外す」だけを行う。
/// 開始と終了のコールバックの区別には頼らない。監視の停止でも終了が届くことがあり、
/// 古い予定ぶんの通知が遅れて届くこともあるため。
enum DailyOpenLimitShield {
    struct Tokens: Equatable {
        var applications = Set<ApplicationToken>()
        var categories = Set<ActivityCategoryToken>()
        var webDomains = Set<WebDomainToken>()

        var isEmpty: Bool {
            applications.isEmpty && categories.isEmpty && webDomains.isEmpty
        }
    }

    static func tokens(from selectionDataList: [Data]) -> Tokens {
        let decoder = JSONDecoder()
        var tokens = Tokens()
        for data in selectionDataList {
            guard let selection = try? decoder.decode(FamilyActivitySelection.self, from: data) else {
                continue
            }
            tokens.applications.formUnion(selection.applicationTokens)
            tokens.categories.formUnion(selection.categoryTokens)
            tokens.webDomains.formUnion(selection.webDomainTokens)
        }
        return tokens
    }

    /// いま掛けるべきトークン。窓の外・控えなしは空。
    static func tokensToShield(_ snapshot: DailyOpenLimitShieldSnapshot?, now: Date) -> Tokens {
        guard let snapshot, DailyOpenLimitPolicy.isBlockActive(now: now, snapshot: snapshot) else {
            return Tokens()
        }
        return tokens(from: snapshot.selectionDataList)
    }

    /// 拡張から使う。控えの期限切れを掃除し、ロックの中で掛け外しする。
    /// 控えが読めないときはシールドを外す（終わったのに開けない状態を残さない）。
    static func sync(store: DailyOpenLimitStore = .init(), now: Date = Date()) {
        do {
            try store.transaction({ snapshot in
                if let current = snapshot, !DailyOpenLimitPolicy.isSnapshotCurrent(now: now, snapshot: current) {
                    snapshot = nil
                }
            }, afterCommit: { apply(tokensToShield($0, now: now)) })
        } catch {
            apply(Tokens())
        }
    }

    static func apply(_ tokens: Tokens) {
        let store = ManagedSettingsStore(named: .init(DailyOpenLimitConstants.shieldStoreName))
        store.shield.applications = tokens.applications.isEmpty ? nil : tokens.applications
        store.shield.applicationCategories = tokens.categories.isEmpty ? nil : .specific(tokens.categories)
        store.shield.webDomains = tokens.webDomains.isEmpty ? nil : tokens.webDomains
    }

    /// シールドの表示とボタンの判定用。いま回数上限で止めている控えを返す。
    static func activeSnapshot(now: Date = Date(), store: DailyOpenLimitStore = .init()) -> DailyOpenLimitShieldSnapshot? {
        guard let snapshot = try? store.read(),
              DailyOpenLimitPolicy.isBlockActive(now: now, snapshot: snapshot) else {
            return nil
        }
        return snapshot
    }

    /// このアプリを回数上限で止めているか。カテゴリでの指定も含めて、対象の種類ごとに照合する。
    static func isBlocking(application token: ApplicationToken, now: Date = Date()) -> Bool {
        guard let snapshot = activeSnapshot(now: now) else { return false }
        return tokens(from: snapshot.selectionDataList).applications.contains(token)
    }
}
