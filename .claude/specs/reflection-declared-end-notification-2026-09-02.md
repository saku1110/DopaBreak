# 振り返りの通知: 宣言した時間の終了に1回だけ知らせる（案A）— 設計（2026-09-02）

オーナー決定（2026-09-02）: 振り返り（リフレクション）は**案A**。
> 宣言した利用時間の終了時刻に通知を1回。タップで振り返りを開く。設定で個別にオフ。文面は事実と問いのみ。

背景は `product-design-cvr-audit-2026-09-02.md` §2b。9/1の案A（窓30分・DopaBreakに戻ったときだけ聞く）は、その30分にDopaBreakを開く理由が無いため実質発火しない。本通知はその「戻る理由」を1本だけ足す。

**8/28に廃止した「利用時間の通知」との違い**: あれはiOSが判定できない「今使っているか」を根拠にしていた。本通知の根拠は**本人が宣言した終了時刻**だけで、使っているかどうかは一切主張しない。文面もそれに合わせる。

---

## 0. 到達したい挙動

1. 一呼吸の後に「10分」を選んでInstagramを開く
2. 10分後、ロック画面に **「Instagramを開いて10分がたちました」／「SNSを見たあとの気持ちは？」** が1本届く（静音時間の対象外＝23時でも届く）
3. タップするとDopaBreakが開き、既存の `PostUseReflectionSheet` がそのまま出る（他のモーダルが出ていなければ）
4. 通知が来る前にDopaBreakへ戻って答えた／スキップした場合は、通知を取り消す
5. 通知が届いた後、答えないまま時間が過ぎたら、次にDopaBreakを開いたときに9/1どおり黙って畳み、通知センターに残っている通知も消す
6. 設定 → 通知 に「振り返りの通知」のトグル。既定ON。OFFにしたら予約済み・配信済みを消す
7. 通知許可が無ければ何もしない（催促しない）

---

## 1. Core: 記録した振り返りを呼び出し元へ返す

`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/InterventionEngine.swift`

- `recordTimedOpen(state:ruleId:timestamp:durationSeconds:)`（:319-356）の戻り値を `Date` から**挿入した `ReflectionLog`** に変える（`promptedAt == allowedUntil`、:346）。`recordOpen`（:200-219）側は `allowedUntil` を `reflection.promptedAt` から取る。**`recordOpen` の挙動は変えない**
- `recordCatalogOpen(durationSeconds:)`（:178-195）を `@discardableResult ... throws -> ReflectionLog` にし、`recordTimedOpen` の戻り値をそのまま返す。`persist(idleState(at:))` はそのまま
- 既存テスト `testCatalogOpenRecordsDeclaredDurationAndReflectionWithoutTemporaryAllowance`（InterventionEngineTests.swift:137）を、戻り値の `promptedAt == date(700)` と `id` がストアの行と一致することを確認する形に更新する

## 2. Core: 通知ポリシー（純粋関数）

新規 `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/ReflectionNotificationPolicy.swift`
`ActivationNotificationPolicy` と同じ作法。

```swift
public enum ReflectionNotificationPolicy {
    /// 通知を出す時刻。出さないときは nil。
    /// - 静音時間（NotificationQuietHours）は適用しない。本人が決めたタイマーなので23時でも鳴らす
    ///   （DeepFocusScheduler.syncSessionEndNotification と同じ判断）
    public static func fireDate(
        promptedAt: Date,
        now: Date,
        isEnabled: Bool
    ) -> Date?   // isEnabled == false → nil / promptedAt <= now → nil / それ以外 promptedAt
}
```

`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/NotificationRouting.swift`
- `NotificationIdentifier` に `public static let reflectionPrompt = "dopabreak.reflection.prompt"` を追加（**固定ID・常に1本**。同じIDで再登録すれば置き換わるので、宣言時間内に開き直して再宣言した場合は新しい終了時刻に置き換わる）
- `NotificationDestination` に `case reflection` を追加。`destination(forIdentifier:)` に `reflectionPrompt → .reflection` の腕を足す
- `allNotificationIdentifiers` 相当のリストに含める（アプリ側 §4 参照）

`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/InterventionEngine.swift`
- `public static let reflectionNotificationTapWindow: TimeInterval = 3 * 60 * 60` を追加。**通知をタップして来た人にだけ**この窓で `pendingReflection(within:)` を引く。自発的に開いたときの表示窓（30分）は変えない。理由: 通知をタップした＝本人が答えに来たので、30分を過ぎていても出す。経過は既存の `ReflectionTimingSummary` が「◯分前の10分について」と示す

## 3. Core: 設定キーと FunnelEvent

`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SettingsStore.swift`
- Key `reflectionNotificationEnabled`、既定 `true`。他の通知トグル（:22-26 / :219-247）と同じ形
- `lockSurfaceState`（:429-437）に載せる。`LockSurfaceState`（AppModels.swift:450-479）に `reflectionNotificationEnabled: Bool` を追加し、init の既定値 `true` で既存呼び出しを壊さない

`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/FunnelEventStore.swift`
- `FunnelEventName` に追加（rawValue は snake_case を明示）:
  `reflectionNotificationScheduled = "reflection_notification_scheduled"`
  `reflectionNotificationTapped = "reflection_notification_tapped"`
  `reflectionAnswered = "reflection_answered"`
  `reflectionSkipped = "reflection_skipped"`
- 計測SDK導入（オーナー決定③）の前に、ここへ積んでおく

## 4. アプリ: 予約と取り消し

新規 `ios/DopaBreak/ReflectionNotificationScheduler.swift`（`@MainActor`）
`DeepFocusScheduler.syncSessionEndNotification`（DeepFocusScheduler.swift:391-431）と同じ構造。通知センターは `DeepFocusSessionNotifying` と同型のプロトコルで注入し、テスト可能にする。

```swift
func schedule(reflection: ReflectionLog, appDisplayName: String, declaredMinutes: Int, isEnabled: Bool, now: Date) async -> Bool
    // 1. ReflectionNotificationPolicy.fireDate(...) が nil → 既存の予約を消して false
    // 2. notificationSettings().authorizationStatus が authorized/provisional/ephemeral 以外 → false（催促しない）
    // 3. UNCalendarNotificationTrigger（LockSurfaceCoordinator.oneShotTrigger と同じ秒精度・repeats: false）
    // 4. identifier = NotificationIdentifier.reflectionPrompt（置き換え）
    // 5. 成功で true。呼び出し元が FunnelEvent .reflectionNotificationScheduled を記録
func cancel() async            // pending + delivered の両方を reflectionPrompt で削除
func removeDelivered() async   // delivered だけ削除（期限切れで畳んだとき用）
```

`ios/DopaBreak/AppContainer.swift`（`AppModel`）
- `scheduleReflectionNotification(for reflection: ReflectionLog, appDisplayName: String, declaredMinutes: Int)`: `settingsStore.reflectionNotificationEnabled` を渡して上を呼ぶ
- `cancelReflectionNotification()`
- `cancelAllNotifications`（:721）の経路で本通知も消えること

`ios/DopaBreak/InterventionFlowModel.swift`
- `recordCatalogOpen(for:)`（:322-330）: `engine.recordCatalogOpen` の戻り値 `ReflectionLog` を受け、`model.scheduleReflectionNotification(for:appDisplayName: target の displayName, declaredMinutes: duration.rawValue)` を呼ぶ。`model.refresh()` はそのまま。3つの呼び出し元（:343 / :352 / :356）はいずれも同じ関数を通るので変更不要

`ios/DopaBreak/LockSurfaceCoordinator.swift`
- **`performNotificationReschedule` は本通知を消してはいけない**。前面復帰のたびに走るため、`removableNotificationIdentifiers`（:569-586）／`removeInvalidatedNotificationRequests`（:601-608）の対象から `reflectionPrompt` を**除外**する。ただし `state.reflectionNotificationEnabled == false` のときは pending・delivered とも削除する
- `cancelAllNotifications()`（:93-99）では削除対象に含める

## 5. アプリ: タップで振り返りを開く

`ios/DopaBreak/NotificationDelegate.swift` は変更不要（識別子→destination の写像は Core 側で足す）。

`ios/DopaBreak/RootTabView.swift`
- `consumePendingNotificationDestination()`（:339-370）の switch に `case .reflection:` を追加。処理は `presentReflectionFromNotification()`:
  - `checkPendingReflection()`（:393-406）と同じガード（オンボ完了・介入なし・ペイウォールなし・ロック画面チェックなし・子モーダルなし）を通す
  - **`expireStaleReflections()` は呼ばない**（タップで来た人の分を畳まないため）
  - `engine.pendingReflection(within: InterventionEngine.reflectionNotificationTapWindow)` を引き、あれば `pendingReflectionLog` に入れる
  - `model.recordFunnelEvent(.reflectionNotificationTapped)`
  - ガードで出せないときは何もしない。`checkPendingReflection` が後で拾う（30分窓）か、期限切れで畳まれる
- `handleAppActive()` の順序（:321-333）は変えない。`consumePendingNotificationDestination` が `checkPendingReflection` より先に走るので、タップ経路が先に `pendingReflectionLog` を埋めれば `checkPendingReflection` は先頭のガードで抜ける
- `checkPendingReflection()`: `expireStaleReflections()` の戻り値が 1 以上なら `model.removeDeliveredReflectionNotification()` を呼ぶ（通知センターの残骸を消す）
- `.sheet(item: $pendingReflectionLog, onDismiss:)`（:276-299）の `onDismiss` で `model.cancelReflectionNotification()` を呼ぶ（答えた／スキップした後に通知が来ないように）。`PostUseReflectionSheet` 内の `recordPostUseReflection` / `skipReflection` 呼び出し直後に FunnelEvent `.reflectionAnswered` / `.reflectionSkipped` を記録（detail に satisfaction の rawValue）

## 6. 設定画面

`ios/DopaBreak/SettingsNotificationsView.swift`
- 「毎週の記録通知」（:47-54）の**直後**に `SettingsIconToggleRow(systemName: "text.bubble.fill", label: settings.notifications.reflection.title, isOn: reflectionNotificationBinding)` と `SettingsDivider()` を追加
- binding は他と同じ形（:117-126）: `settingsStore.reflectionNotificationEnabled` を書き、**OFF にしたら `model.cancelReflectionNotification()`**、ON にしたら何もしない（次の宣言から予約される）
- `@Binding` の追加に伴い `SettingsView.swift:73-78` の `@State` と `:1297-1316` の配線、`notificationSummary`（:1956+）の件数計算を更新

## 7. 文言（xcstrings・ja/en/ko すべて）

事実と問いのみ。自己評価語・時制ラベル・リズム読点なし。

| key | ja | en | ko |
|---|---|---|---|
| `notification.reflection.title` | `%1$@を開いて%2$lld分がたちました` | `%2$lld minutes since you opened %1$@` | `%1$@을(를) 연 지 %2$lld분이 지났어요` |
| `notification.reflection.body` | `SNSを見たあとの気持ちは？` | `How do you feel after using social media?` | `SNS를 보고 난 지금 기분은 어떤가요?` |
| `settings.notifications.reflection.title` | `振り返りの通知` | `Reflection reminder` | `되돌아보기 알림` |

- body はシートの設問 `reflection.satisfaction.title` と同じ値にする（タップ先と一致させる）
- 韓国語の助詞 `을(를)` は既存カタログの同型表記に揃える。既存に別の流儀があればそれに従う
- 書式引数は `String(localized:defaultValue:)` の既存作法（`%1$@` / `%2$lld`）

## 8. テスト

Core（`ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/`）
- 新規 `ReflectionNotificationPolicyTests`: 23:10 でも `promptedAt` をそのまま返す／`isEnabled == false` で nil／`promptedAt <= now` で nil
- `NotificationRoutingTests`: `reflectionPrompt → .reflection`
- `InterventionEngineTests`: §1 の戻り値。`pendingReflection(within: reflectionNotificationTapWindow)` が 30分超〜3時間以内の未回答を返し、3時間超は返さない
- `FunnelEventStore` の rawValue 4件

アプリ（`ios/DopaBreakTests/`）
- 新規 `ReflectionNotificationSchedulerTests`（`DeepFocusSchedulerTests` の `RecordingDeepFocusNotifying` 方式を踏襲）: 予約される／同じIDで置き換わる／未許可で予約しない／トグルOFFで予約せず既存を消す／`cancel()` が pending と delivered を消す
- 既存スイートが全件通ること（Core・アプリとも）

## 9. 触らないもの

- 30分の表示窓、`expireStaleReflections` の畳み方、`PostUseReflectionSheet` の設問と選択肢
- `recordOpen`（Screen Time経路）の挙動。死にコードの整理は別タスク
- 静音時間 `NotificationQuietHours` の 09:00–21:00。本通知だけが対象外
- 他の通知の予約・削除の挙動
- 🔴4（宣言時間内の再オープンで一呼吸が再発する）は別タスク。本設計は固定IDの置き換えで通知の重複だけ防ぐ

## 10. 判断の記録

- 静音時間の対象外にした: 本人が「10分」と決めた直後の通知なので、23時でも届かなければ意味がない。DeepFocusのセッション終了通知と同じ扱い
- タップ窓を3時間にした: 自発表示の30分窓は「覚えていない状態で聞かれる」対策。通知をタップした人はその状態ではない。3時間を超えたら出さない
- 固定IDにした: 常に最新の宣言1本だけ。IDにUUIDを入れる案は、ログをIDで引くAPIが無く（`SQLiteLogStore` に fetch-by-id 無し）通知側の複雑さに見合わない
- 通知許可が無いときは催促しない: 権限要求はオンボの1回だけという既存方針に従う

---

## 11. レビュー後の修正（2026-09-02・Opus5独立レビュー → Fable裁定）

レビュー評決「accept with fixes」。以下を実装担当（Codex）へ差し戻す。§1〜§10 と矛盾する箇所は本節が優先。

### 11-1. 🟡 コールドスタートで3時間のタップ窓が死ぬ（必須）
症状: 通知タップでコールドスタートすると、`handleAppActive` → `checkPendingReflection` → `expireStaleReflections()`（30分）が **delegateの宛先書き込みより先に** 走り、30分超の未回答を畳んでしまう。その後 `.notificationDestinationDidChange` → `presentReflectionFromNotification` → `pendingReflection(within: 3h)` が nil。`.onChange(of: model.isChildModalActive)` 経路も同型。
裁定: 宛先を見て畳むかを判断する案は、コールドスタート時点で宛先がまだ無いので採らない。**畳む閾値を3時間に揃える**。
- `RootTabView.checkPendingReflection()` の呼び出しを `engine.expireStaleReflections(olderThan: InterventionEngine.reflectionNotificationTapWindow)` にする（**呼び出し側で明示**。`InterventionEngine.expireStaleReflections` の既定引数 30分と `reflectionPromptWindow` は変えない）
- 自発表示の `pendingReflection()`（30分）はそのまま。30分〜3時間の未回答は「自発では出さない・タップでは出す・3時間で畳む」になる
- 配信済み通知の削除（§5「expire が1以上なら removeDelivered」）はこの3時間畳みに連動する＝通知センターの通知は答えられる間だけ残る
- テスト: `InterventionEngineTests` に「2時間前の未回答は `expireStaleReflections(olderThan: 3h)` で畳まれず、`pendingReflection(within: 3h)` で取れる」「3時間超は畳まれる」を追加

### 11-2. 🟡 背面移行の瞬間に非同期予約して取りこぼす（必須）
症状: 主経路は `UIApplication.shared.open` の completion＝アプリが背面へ落ちる瞬間。そこから `Task` で `await notificationSettings()` → `await add()` と2回サスペンドするため、途中で suspend されると予約されない。手本の `DeepFocusScheduler.syncSessionEndNotification` は同期で `add(_:withCompletionHandler:)` を呼んでいる。
裁定:
- `ReflectionNotificationScheduler.schedule` を **同期** にする。`notificationSettings()` の事前 await を廃止し、`removeDeliveredNotifications([id])` → `add(request) { error in ... }` を即時に発行する。未許可なら `add` がエラーを返すだけで、催促はしない（§0-7 は維持）
- 呼び出し側（`AppModel.scheduleReflectionNotification`）は `UIApplication.shared.beginBackgroundTask(expirationHandler:)` で挟み、`add` の completion で `endBackgroundTask`。expiration でも end する
- `.reflectionNotificationScheduled` は `add` の completion で `error == nil` のときだけ記録
- `cancel()` / `removeDelivered()` も同期発行に揃える（competion 不要）
- テスト: 注入プロトコルを同期版に合わせて更新。既存5観点は維持。置き換えテストは識別子だけでなく **trigger の日時成分が新しい時刻に更新されている** ことまで比較する

### 11-3. 🟢 `.reflectionNotificationTapped` の記録位置
宛先 `.reflection` を消費した時点で **ガードより前に1回** 記録する（タップという事実を測る。シートが出せたかは別）。

### 11-4. 🟢 再宣言時に配信済みの旧通知が残る
11-2 に含めた: `add` の直前に `removeDeliveredNotifications(withIdentifiers: [id])`。

### 11-5. 🟢 `design-decisions.md` のCodex記録が実装と不一致
末尾ブロック「2026-09-02 — 宣言終了時刻に振り返り通知を届ける（案A）」を実装に合わせて訂正する: IDは `dopabreak.reflection.prompt`（`NotificationRouting.swift`）。存在しない関数名 `refreshNotifications` / `reconcileDelivered` は `performNotificationReschedule` / `removeInvalidatedNotificationRequests` に直す。11-1・11-2 の変更点を追記する。

### 11-6. 🟢 設定トグルが `refreshLockSurfaces()` を呼ばない
他の通知トグルと同じく、書き込み後に `model.refreshLockSurfaces()` を呼ぶ（OFF時の `cancelReflectionNotification()` は維持）。

### 受け入れ条件
Core・アプリの全テストが失敗0。上記 11-1〜11-6 が実装済み。差分本文は貼らず、変更ファイル一覧・3行要約・テスト件数のみ報告。
