# シールド解除フロー＋回数上限＋クールダウン＋アプリ別設定（v1.1・設計正本）

作成: 2026-08-22 / 設計: Fable / 実装: Codex（gpt-5.6-sol Fast・effort max） / レビュー: Opus5
オーナー決定: 2026-08-22「B. 今シールド解除フローまで作る」（Clarymind比較で制御系の機能差を強制型で埋める）

関連: `docs/12_hybrid_intervention.md`（ハイブリッド方式・正本）/ `.claude/specs/deepfocus-windows-and-paywall-batch.md` / `.claude/specs/nightonly-implementation.md` / `.claude/tasks/backlog.md` v1.1「執行力のあるコミットメント装置はシールドv1.1で設計」

---

## 0. 結論（1画面で分かる版）

| 項目 | 決定 |
|---|---|
| 何を作るか | Pro向けに **Screen Timeシールドで常時止める「ゲート」** を追加。対象アプリを開くとシールド→ボタンでDopaBreakが開く→**既存の一呼吸→理由→時間選択フローをそのまま実行**→選んだ分数だけシールドを外す→時間が来たらDeviceActivityで再シールド。1日の開く回数上限・クールダウン（解除と解除の間の待ち時間）・1回の長さをアプリごとに設定できる |
| 誰に | **Proのみ**。Freeは現行どおりショートカット自動化の一呼吸（変更なし） |
| 既存のDeep Focus / 夜だけ | **変更なし（完全ブロックのまま・解除ボタンなし）**。ゲートはその外側の「日常の層」。強さの順: 標準（ゲート） < 夜だけ（ゲート＋夜は完全） < Deep Focus（ゲート＋窓は完全） |
| シールド→アプリの遷移 | iOS 26.5+: `ShieldActionResponse.openParentalControlsApp`（SDK確認済み・一次API）。iOS 17〜26.4: ローカル通知タップ（Clarymind/one secと同じ）。26.5+でも保険として遅延通知を併用し、アプリが開いたら取り消す |
| 再シールド | 3層: ①DeviceActivity（開始=解除終了時刻・長さ≥15分・`intervalDidStart`で再適用・活動名は解除ごとに一意） ②アプリ前面復帰時の同期 ③台帳のタイムスタンプ再検証（Bool禁止）。どれか1層が落ちても次で回復する |
| 既定値 | 1日の上限=なし / クールダウン=なし / 1回の長さ=10分。「禁止でなく気づき」の方針を守り、制限はユーザーが自分で入れる。設定画面では目立つ位置に置く |
| 上限・クールダウン中 | シールドに「今日はここまで」「◯時◯分から開けます」を表示し**解除ボタンを出さない**。設定で上限を変えれば即反映（閉じ込めを作らない） |
| 実装しないもの | アプリ内でのシールド常時表示・カウントダウン（APIに無い）/ 代替アプリ70種誘導 / Chrome拡張 / QR解除 / Freeへの適用 / ペイウォール行の追加（オーナー未承認） |

---

## 1. 背景と根拠（要約）

- Clarymind実測: 解除フローはシールド→「Continue」→`.defer`で2段目＋ローカル通知→通知タップで自アプリ→呼吸/AIは自アプリ内→解除→ユーザーが自分で対象アプリを開き直す。1日の上限（`0/3 opens today` をシールド上に表示）・Back-to-Back Unlocks（クールダウン）・アプリ別設定あり
- Apple DTS/一次情報: iOS≤26.4で拡張から親アプリを開く公開APIは無い（私的API使用は2.5.1リジェクト実例あり）。**iOS 26.5 SDKに `ShieldActionResponse.openParentalControlsApp` が追加**（実機挙動は未報告→実機スパイクで確認）。`DeviceActivitySchedule` は最短15分（`intervalTooShort`）。`intervalDidEnd` は端末使用時にしか来ない。`ApplicationToken` の同一性は不安定な報告あり（FB14082790）
- 本リポジトリ: ShieldActionExtensionは全`.close`の17行・ShieldConfigurationは静的・`TargetRule.maxOpensPerDay`/`delaySeconds`は未使用フィールド・`InterventionEngine.recordOpen/reshieldIfExpired`は再利用可・MonitorExtensionはDeep Focus/夜/使用量監視の閾値イベントを既に処理・`ShieldSyncPolicy`は純関数＋全数テスト
- 2026-07-18却下「アプリ内スイッチの24hクールダウン」は**ショートカット経路で執行力ゼロ**が理由。本設計はManagedSettingsで強制するため前提が異なる（backlog v1.1の条件を満たす）
- 2026-07-08「シールドは静的・アニメ不可」問題は、シールドを**入口だけ**にして体験本体をアプリ内で行う構成で解消

---

## 2. 用語（UI文言ではなく設計用語。UIには出さない）

| 用語 | 意味 |
|---|---|
| ゲート | Pro向けの常時シールド層。ストア名 `dopabreak.gate`（Deep Focus `dopabreak.deepfocus`・夜 `dopabreak.night` とは別ストア） |
| 解除（grant） | 1回の一時開放。対象トークン1個・分数・終了時刻・一意ID |
| 台帳（ledger） | トークンごとの当日回数・直近解除終了時刻・進行中解除。App Group JSON |
| アプリ別設定 | トークンごとの 1日上限 / 1回の長さ / クールダウン分 |

---

## 3. 対象・モードの意味（再定義）

| モード | Free | Pro |
|---|---|---|
| 標準 | ショートカット一呼吸（現行） | **ゲート**（常時シールド＋解除フロー） |
| 夜だけ | — | ゲート ＋ 就寝〜起床は完全ブロック（現行の夜ストア） |
| Deep Focus | — | ゲート ＋ 窓/セッション中は完全ブロック（現行のDFストア） |

- ゲートの対象 = 既存の「完全ブロックの対象」（`TargetRule` で `activitySelectionData` 非空のルール）と**同じ選択**。Proは1つの選択で3つの強さを使う。設定画面の見出しは「止めるアプリ」に統一し、「完全ブロックの対象」という別枠表現をやめる（§9）
- 完全ブロックの窓の中はゲートと窓ストアが重なって掛かる。**シールド表示は窓を優先**（解除ボタンなし）
- ショートカット自動化を併用しているProユーザーの二重発火: ゲート解除中（台帳に進行中解除がある間）は `AppModel.consumeInterventionRequest` で自動化由来の介入を**抑止**する。設定画面の自動化ガイドに「Proのゲートを使うアプリでは自動化は不要」と明記

---

## 4. データモデル（DopaBreakCore・すべてCodable・App Group）

### 4.1 `GateAppSettings`（新規・`gate_app_settings.json`）

```swift
public struct GateAppSetting: Codable, Equatable, Sendable {
    public var tokenData: Data            // ApplicationToken を JSONEncoder で符号化したもの（キー）
    public var dailyOpenLimit: Int?       // nil=上限なし。許容 1,2,3,5,10
    public var sessionMinutes: Int        // 既定10。許容 5,10,15,30
    public var cooldownMinutes: Int       // 既定0。許容 0,5,10,30,60
    public var updatedAt: Date
}
public struct GateAppSettingsSnapshot: Codable, Equatable, Sendable {
    public var settings: [GateAppSetting]
    public var updatedAt: Date
}
```
- 取得 `setting(for token:)` は tokenData の完全一致 → 見つからなければ**既定値**を返す（トークン不一致時の安全側＝制限なし。閉じ込めを作らない）
- 既定値は `GateDefaults` enum に集約（`dailyOpenLimit: nil, sessionMinutes: 10, cooldownMinutes: 0`）

### 4.2 `GateLedger`（新規・`gate_ledger.json`）

```swift
public struct GateGrant: Codable, Equatable, Sendable {
    public var id: UUID
    public var tokenData: Data
    public var ruleId: UUID
    public var startedAt: Date
    public var endsAt: Date
    public var activityName: String       // "dopabreak.gate.reshield.<id>"
}
public struct GateLedgerEntry: Codable, Equatable, Sendable {
    public var tokenData: Data
    public var dayKey: String             // "yyyy-MM-dd"（Calendar.autoupdatingCurrent）
    public var opensToday: Int
    public var lastGrantEndedAt: Date?    // クールダウン起点
}
public struct GateLedger: Codable, Equatable, Sendable {
    public var entries: [GateLedgerEntry]
    public var activeGrants: [GateGrant]
    public var pendingUnlockRequest: GateUnlockRequest?   // §6.2
    public var updatedAt: Date
}
public struct GateUnlockRequest: Codable, Equatable, Sendable {
    public var id: UUID
    public var tokenData: Data
    public var requestedAt: Date          // 10分で失効
}
```
- 日付が変わったエントリは読み取り時に `opensToday=0` として扱う（純関数 `GatePolicy.normalized(entry, now:)`）
- `activeGrants` は `endsAt` を過ぎたものを「期限切れ」として扱う。**Boolフラグは置かない**

### 4.3 `GateShieldSnapshot`（新規・`gate_shield_snapshot.json`）
`DeepFocusShieldSnapshot` と同形（`selectionDataList: [Data]`, `updatedAt`）。アプリが権利確認後に書く。拡張はこれを正として読む（拡張が権利判定をしない＝既存方針）。Freeへ降格・全データ削除で消す。

### 4.4 `GatePolicy`（新規・純関数・全数テスト）

```swift
public enum GateShieldState: Equatable {
    case hardWindow(kind: HardKind)                  // deepFocus / night（窓優先・解除なし）
    case canUnlock(opensToday: Int, limit: Int?)     // 通常
    case waitingForApp(requestedAt: Date)            // 通知ホップ待ち（iOS<26.5）
    case limitReached(limit: Int)
    case cooldown(until: Date)
}
public enum GatePolicy {
    static func shieldState(tokenData:, now:, settings:, ledger:, isDeepFocusWindowActive:, isNightWindow:, calendar:) -> GateShieldState
    static func canGrant(tokenData:, now:, settings:, ledger:, calendar:) -> Result<Void, GateDenial>   // .limitReached / .cooldown(until)
    static func applyingGrant(ledger:, grant:, calendar:) -> GateLedger      // opensToday+1・activeGrants追加
    static func expiringGrants(ledger:, now:) -> (expired: [GateGrant], ledger: GateLedger)   // lastGrantEndedAt更新
    static func tokensToShield(selectionTokens: Set<ApplicationToken>, ledger:, now:) -> Set<ApplicationToken>  // 選択 − 進行中解除
}
```
- クールダウン判定: `lastGrantEndedAt + cooldownMinutes > now` → `.cooldown(until:)`。`cooldownMinutes == 0` なら常に許可
- 上限判定: `limit != nil && opensToday >= limit` → `.limitReached`
- 優先順: hardWindow > waitingForApp（10分以内の未消費要求あり）> limitReached > cooldown > canUnlock

---

## 5. ストア・同期（アプリ側）

### 5.1 `GateShieldController`（新規・`ios/DopaBreak/`）
- `ManagedSettingsStore(named: "dopabreak.gate")`
- `sync(entitlementGate:hasConfirmedEntitlement:)`: `ShieldSyncPolicy` と同じ契約（`preserve / clear / apply`）。適用集合 = `GatePolicy.tokensToShield(選択トークン全体, ledger, now)`。**カテゴリ・Webドメインは v1.1のゲート対象外**（`.specific(categories, except:)` の個別解除が複雑なため。選択にカテゴリがあればアプリトークン分のみゲートし、カテゴリはDeep Focus/夜でのみ使う）。設定画面で「ゲートはアプリ単位」と注記
- `AppModel.syncShield()` の末尾でゲートも同期（夜→DF→ゲートの順）。既存の `requiresUnconditionalClear` と同じ条件でゲートも無条件クリア
- Free/未確認時は**設定・台帳を消さない**（非破壊降格の不変条件を継承）

### 5.2 `GateGrantController`（新規）
`grant(tokenData:ruleId:minutes:)`:
1. `GatePolicy.canGrant` で再検証（シールド表示時点とズレていれば拒否してフローに`.failed`を返す）
2. 台帳更新（`applyingGrant`）→ 書き込み
3. ゲートストアからそのトークンを除外（`tokensToShield` で再計算して丸ごと適用）
4. `DeviceActivityCenter.startMonitoring("dopabreak.gate.reshield.<id>", during: schedule(intervalStart: endsAt, intervalEnd: endsAt+16分, repeats: false))`。失敗時は台帳に `activityName=""` を残し、**②③の層で回復**（失敗で解除を取り消さない。ユーザーは一呼吸を済ませている）
5. 既存の時間切れ通知（`InterventionFlowModel` の `dopabreak.timeup.*`）はそのまま
6. 同時進行の解除は最大5件（超えたら最古を期限切れ扱いで再シールド）。監視活動は20件上限のため解除終了時に `stopMonitoring` する

`reconcile(now:)`（前面復帰・`syncShield` のたび・設定変更時）: 期限切れ解除を台帳から落とし `lastGrantEndedAt` を更新 → ゲート再適用 → 使い終わった監視活動を停止。

---

## 6. 拡張の振る舞い

### 6.1 ShieldConfigurationExtension（改修）
表示分岐を `GatePolicy.shieldState` に委ねる。読むもの: `gate_app_settings.json` / `gate_ledger.json` / `deepfocus_shield_snapshot.json` / `night_shield_snapshot.json` / 目標（既存）。すべて同期読み・失敗時は最小表示（既存方針）。
**重要**: 夜の窓のときのタイトルが現状「ディープフォーカス中」固定になっている既知の不整合をこの改修で直す（§8の文言）。

| 状態 | タイトル | サブ | 主ボタン | 副ボタン |
|---|---|---|---|---|
| hardWindow(deepFocus) | ディープフォーカス中 | 守っている目標 {目標} / いまは開かない時間 | 閉じる | なし |
| hardWindow(night) | いまは就寝の時間 | 守っている目標 {目標} / 起きたら開けます | 閉じる | なし |
| canUnlock | 開く前にひと呼吸 | 今日 {n}回目（上限ありなら `今日 {n}/{limit}回`）＋改行なしで「戻る先 {目標}」は入らないため目標は省略 | 一呼吸して開く | 開かない |
| waitingForApp | 通知をタップ | 上に出た通知からDopaBreakで一呼吸 | 通知をもう一度送る | 開かない |
| limitReached | 今日はここまで | 今日の上限 {limit}回に達しました 0時にリセット | 閉じる | なし |
| cooldown | 少し間をあける | {HH:mm}から開けます | 閉じる | なし |

- サブは1行〜2行・SE幅で切れない長さ（§8で文言確定）。フォント・配置は制御不可（API制約）
- アイコン: 既存どおり（未設定ならシステム既定）。色は `ShieldColors` 既存値
- シールド設定は表示のたびに再計算される（＝クールダウンの残り時刻は表示時点の値）。**カウントダウンは不可**（API制約）

### 6.2 ShieldActionExtension（新規実装）
`handle(action:for application:)`:
- `primaryButtonPressed`:
  - 状態が `canUnlock` のとき: 台帳に `pendingUnlockRequest{id, tokenData(application の符号化), requestedAt}` を書く →
    - `if #available(iOS 26.5, *)`: ローカル通知（下記）を**8秒遅延**でスケジュールしてから `completionHandler(.openParentalControlsApp)`
    - それ以外: ローカル通知を**即時**スケジュールして `completionHandler(.defer)`（シールドが `waitingForApp` に再描画される）
  - 状態が `waitingForApp`: 通知を再送して `.defer`
  - 状態が `limitReached` / `cooldown` / `hardWindow`: `.close`
- `secondaryButtonPressed`（開かない）: AttemptLog(cancelled) を**直接**書く（`SQLiteLogStore` はクロスプロセス安全設計・`ruleId` はトークンを含む `TargetRule` を `rules.json` から逆引き。見つからなければ記録せず閉じる）→ `.close`
- カテゴリ/Webドメインの `handle` は `.close`（ゲート対象外）
- **完了ハンドラより前に全書き込みを終える**（拡張はすぐ終了しうる）

ローカル通知: id `dopabreak.gate.unlock.<requestId>`、タイトル「タップして一呼吸」本文「DopaBreakで一呼吸してから {アプリ名は不明のため} 開きます」→ 実文言は §8。`userInfo: {gateUnlockRequestId}`。通知カテゴリは既存の通知権限で送る（権限なしの場合は `.defer` 後の再描画サブに「通知をオンにすると開けます」を出す＝`waitingForApp` の派生状態 `notificationDenied`。設定アプリへの誘導はできないため文言のみ）。
通知タップ→ `AppDelegate`/`UNUserNotificationCenterDelegate` で `gateUnlockRequestId` を受け、`AppModel.consumePendingGateUnlock()` を呼ぶ。

### 6.3 DeviceActivityMonitorExtension（追記）
- `intervalDidStart(for:)` で `activity.rawValue.hasPrefix("dopabreak.gate.reshield.")`: 台帳を読み、該当grantが**期限切れ（now >= endsAt − 30秒）なら**再シールド（`GateShieldSnapshot` の選択 − 進行中解除 を `dopabreak.gate` に適用）・台帳を期限切れ処理・自活動を `stopMonitoring`。期限前なら何もしない（二重起動・名前衝突の防御）
- `intervalDidEnd` 同処理（保険）
- ここで `startMonitoring` は呼ばない（同名再登録のデッドロック回避）
- メモリ6MB上限: トークン復号は必要分のみ。既存 `applyDeepFocusShield` の書き方に倣う

---

## 7. アプリ内フロー（既存 `InterventionFlowView/Model` の拡張）

### 7.1 起動
- `AppModel.consumePendingGateUnlock()`（前面復帰・通知タップ・`scenePhase == .active` で呼ぶ）: 台帳の `pendingUnlockRequest` が10分以内なら消費→ 対応する `TargetRule`（`activitySelectionData` を復号してトークン一致で検索。なければ最初のゲート対象ルール）→ `requestStartIntervention(gateToken:)` → `InterventionFlowView` を既存 `.fullScreenCover` で提示。保険通知（8秒遅延）が未発火なら取り消す
- `InterventionTarget` を列挙に一般化: `.catalog(SNSAppCatalogItem)` / `.gateToken(tokenData: Data, ruleId: UUID)`。表示名とアイコンは `Label(token)`（FamilyControls）で描画。**アプリ名の文字列は取得できない**ため、文言は「このアプリ」で組む（§8）

### 7.2 フロー本体
既存と同一: 理由選択 →（反射的なら）呼吸→今日N回目→目標→決定 → 時間選択。
差分:
- 時間選択プリセットは `GateAppSetting.sessionMinutes` を既定選択にし、選択肢は 5/10/15/30 のまま（アプリ別の「1回の長さ」は既定選択のみ変える。フロー中の自由は残す）
- 決定前に `GatePolicy.canGrant` を再評価（上限/クールダウンに達していれば `.failed` ではなく専用の `limit` ステージ「今日はここまで」で終了・AttemptLog(cancelled)）
- `[N分だけ開く]` → `engine.recordOpen(durationSeconds:)`（既存・AttemptLog/ReflectionLog）→ `GateGrantController.grant`
- 復帰ステージ `.opening(fallbackMessage:)` を再利用: URLスキームが無いため**「左上の ◀ から戻ると開けます」**を表示（§8）。Clarymindと同じ制約（トークンからアプリを起動できない）。自動化由来の介入抑止は §3
- 振り返り（`PostUseReflectionSheet`）: 既存どおり `pendingReflection` で出る

### 7.3 「開かない」 
アプリ内で押した場合は既存 `recordCancel`。シールド上で押した場合は §6.2（拡張が直接記録）。

---

## 8. 文言（docs/11 に §6c として追記してから実装・ja/en/ko）

禁止語彙（内部用語）: 介入/シールド/セッション/ゲート。読点なし・体言止め優先・金額なし。

### 8.1 シールド（`ios/ShieldConfigExtension/Localizable.xcstrings` に追加）

| キー | ja | en | ko |
|---|---|---|---|
| shield.title（既存・変更なし） | ディープフォーカス中 | Deep Focus on | 딥 포커스 중 |
| shield.night.title（新） | いまは就寝の時間 | Bedtime now | 지금은 취침 시간 |
| shield.night.subtitle（新） | 起きたら開けます | Opens after you wake | 일어나면 열 수 있어요 |
| shield.gate.title（新） | 開く前にひと呼吸 | One breath before you open | 열기 전에 한 호흡 |
| shield.gate.subtitle.count（新・%lld） | 今日 %lld回目 | Open #%lld today | 오늘 %lld번째 |
| shield.gate.subtitle.count_limit（新・%lld/%lld） | 今日 %lld/%lld回 | %lld of %lld opens today | 오늘 %lld/%lld회 |
| shield.gate.action.breathe（新） | 一呼吸して開く | Take a breath to open | 한 호흡 후 열기 |
| shield.gate.action.cancel（新） | 開かない | Don't open | 열지 않기 |
| shield.gate.waiting.title（新） | 通知をタップ | Tap the notification | 알림을 탭하세요 |
| shield.gate.waiting.subtitle（新） | 上に出た通知からDopaBreakで一呼吸 | Use the banner above to breathe in DopaBreak | 위 알림에서 DopaBreak로 한 호흡 |
| shield.gate.waiting.denied（新） | 通知をオンにすると開けます | Turn on notifications to continue | 알림을 켜면 열 수 있어요 |
| shield.gate.waiting.retry（新） | 通知をもう一度送る | Send it again | 알림 다시 보내기 |
| shield.gate.limit.title（新） | 今日はここまで | That's it for today | 오늘은 여기까지 |
| shield.gate.limit.subtitle（新・%lld） | 今日の上限 %lld回に達しました 0時にリセット | Daily limit of %lld reached · resets at midnight | 오늘 상한 %lld회 도달 · 자정에 초기화 |
| shield.gate.cooldown.title（新） | 少し間をあける | Take a short break | 잠시 쉬어가기 |
| shield.gate.cooldown.subtitle（新・%@=HH:mm） | %@から開けます | Opens at %@ | %@부터 열 수 있어요 |

en/ko は実装後に `humanizer-en` / `humanizer-ko` の audit.py を通す（UIラベルなので語彙監査のみ・exit 0）。

### 8.2 通知（アプリ本体カタログ）
| キー | ja | en | ko |
|---|---|---|---|
| gate.notification.unlock.title | タップして一呼吸 | Tap to take a breath | 탭해서 한 호흡 |
| gate.notification.unlock.body | DopaBreakで一呼吸してから開きます | Breathe in DopaBreak, then open the app | DopaBreak에서 한 호흡 후 열어요 |

### 8.3 アプリ内（復帰・上限）
| キー | ja |
|---|---|
| intervention.gate.opening.back | 左上の ◀ から戻ると開けます（{N}分） |
| intervention.gate.limit.title | 今日はここまで |
| intervention.gate.limit.body | このアプリは今日の上限に達しました。上限は設定で変えられます。 |
| intervention.gate.cooldown.body | {HH:mm}から開けます。待ち時間は設定で変えられます。 |
| intervention.gate.target_name | このアプリ |

### 8.4 設定
| キー | ja |
|---|---|
| settings.gate.section | 止めるアプリ |
| settings.gate.description | 開く前に必ず一呼吸。回数や長さはアプリごとに決められます |
| settings.gate.app_list | アプリごとの設定 |
| settings.gate.daily_limit | 1日に開ける回数 |
| settings.gate.daily_limit.none | 上限なし |
| settings.gate.session_minutes | 1回の長さ |
| settings.gate.cooldown | 次に開けるまでの間 |
| settings.gate.cooldown.none | なし |
| settings.gate.automation_note | Proの止めるアプリでは、ショートカットの自動化は不要です |
| settings.gate.category_note | カテゴリ選択は完全ブロックでだけ使われます。開く前の一呼吸はアプリ単位です |
| settings.gate.locked_notice（Free） | Proにすると、ショートカット設定なしで開く前に必ず止まり、回数や待ち時間も決められます |

---

## 9. 設定画面（SettingsView）

- `targetSection` を再構成:
  - Pro: 「止めるアプリ」= FamilyActivityPicker（既存の完全ブロック対象を流用）。選択済みアプリを `Label(token)` で一覧 → 行タップで `GateAppSettingSheet`（1日の回数 / 1回の長さ / 次に開けるまでの間。各Pickerはセグメント or メニュー）。一覧下に `automation_note`
  - Free: 既存のカタログ＋自動化ガイドそのまま。`locked_notice` 行 → ペイウォール（`placement: .settingsGateGate` 新設・既存 `.settingsModeGate` と同型）
- 「止める強さ」（モードPicker）は既存のまま。説明文に「標準＝開く前に一呼吸」を追記
- 自動化ガイドは Pro でも開ける（併用者向け）が既定で折り畳む
- 設定変更（上限を上げた等）は保存時に `GateGrantController.reconcile` → `syncShield` を呼ぶ＝シールドの次回表示に反映

---

## 10. 権利・フェイルセーフ・不変条件（既存ルール継承）

- Proゲート: `EntitlementGate` に `gateAllowed`（= `tier == .pro`）を追加（`strictModeAllowed` と同値だが意味を分ける）
- `hasConfirmedEntitlement == false` の間は `preserve`（課金者から剥がさない）。Free確定なら無条件クリア。**設定・台帳は消さない**
- 「終わったのに開けない」禁止: 上限/クールダウンは**設定変更で即解除可能**。拡張は権利判定をしない（`GateShieldSnapshot` の有無に従う）。全データ削除で snapshot/ledger/settings を消し、ゲートストアをクリア
- 再シールド3層（§5.2, §6.3）。解除終了後に再シールドが遅れても、次のシールド表示・前面復帰で整合する
- Shield設定キャッシュ（アプリ使用中は古い表示が出る既知バグ）は受容。文言で「表示は次に開き直したとき更新」とは書かない（ユーザーには見えない細部）
- 監視活動の上限: ゲートの再シールド活動は最大5件・終了時に停止

---

## 11. 変更ファイル一覧（Codex向け）

**Core（`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/`）**
- `Models/GateModels.swift`（新: §4.1〜4.3）
- `Services/GatePolicy.swift`（新: §4.4）
- `Services/GateStores.swift`（新: `GateAppSettingsStore` / `GateLedgerStore` / `GateShieldSnapshotStore`。`JSONSnapshotStore` に `SnapshotFile` 3件追加）
- `Services/EntitlementGate.swift`（`gateAllowed` 追加）
- `Storage/JSONSnapshotStore.swift`（ファイル追加）/ `Storage/SettingsStore.swift`（新キーがあれば `resettable` に追加）
- `DopaBreakCore.swift`（`GateConstants`: ストア名・活動名プレフィックス・通知ID・要求失効10分）

**アプリ（`ios/DopaBreak/`）**
- `GateShieldController.swift`（新）/ `GateGrantController.swift`（新）
- `ShieldController.swift`（ゲート同期の呼び出し統合 or `AppModel.syncShield` から別呼び出し）
- `AppContainer.swift`（`consumePendingGateUnlock` / 自動化抑止 / `syncShield` への統合 / 全データ削除 / 降格処理）
- `DopaBreakApp.swift` or 通知デリゲート（通知タップ→要求消費・保険通知取消）
- `InterventionFlowModel.swift` / `InterventionFlowView.swift`（`InterventionTarget` 一般化・`Label(token)` 表示・上限ステージ・復帰文言・既定分数）
- `SettingsView.swift` ＋ `GateAppSettingSheet.swift`（新）
- `PaywallView`（`placement` 追加のみ。文言変更なし）
- `Localizable.xcstrings`（§8.2〜8.4・ja/en/ko）

**拡張**
- `ShieldConfigExtension/ShieldConfigurationExtension.swift`（§6.1）＋ `Localizable.xcstrings`（§8.1）
- `ShieldActionExtension/ShieldActionExtension.swift`（§6.2）＋ `Info.plist` に通知利用の説明不要（ローカル通知）
- `MonitorExtension/DeviceActivityMonitorExtension.swift`（§6.3）

**ドキュメント**
- `docs/11_ui_copy.md` §6c 追記（§8）/ `docs/12_hybrid_intervention.md` §1 表にPro列追記 / `.claude/specs/design-decisions.md` エントリ / `.claude/tasks/current.md`
- `xcodegen generate` を実行し `project.pbxproj` を更新（新ファイルはglobで拾われるが生成は必要）

---

## 12. テスト（必須・Core純関数は全数）

- `GatePolicyTests`: 状態優先順（hard > waiting > limit > cooldown > canUnlock）/ 日付境界（23:59→0:00でopensToday=0）/ cooldown=0 / limit=nil / 期限切れgrantの `lastGrantEndedAt` 更新 / `tokensToShield` が進行中解除を除外 / 要求の10分失効
- `GateStoresTests`: 往復・旧ファイル無しでの既定値・tokenData不一致時は既定値
- `EntitlementGateTests`: `gateAllowed`
- `GateShieldController` の同期判断は `ShieldSyncPolicy` と同じ形の純関数 `GateSyncPolicy.action(...)` に切り出して全数テスト（preserve/clear/apply）
- アプリ層: `InterventionFlowModel` のゲートターゲット起動・上限ステージ・既定分数（既存テストの流儀）
- `swift test`（Core）＋ `xcodebuild test`（DopaBreakTests）0失敗・`BUILD SUCCEEDED`

---

## 13. 実機検証（オーナー or Fable・Sandboxで）

1. Pro＋Screen Time許可＋通知許可 → 止めるアプリにInstagram → ホームでInstagramタップ → **「開く前にひと呼吸」シールド**が出る
2. 「一呼吸して開く」→ iOS 26.5+ で DopaBreak が直接開く（開かなければ8秒後の通知で開く）→ 理由→呼吸→「10分だけ開く」→ 「左上の◀から戻る」→ Instagramが開く
3. 10分後（＋最大数分の遅延）に再びシールドが掛かる。掛からない場合、DopaBreakを前面にすると掛かる（層②）
4. 上限=2 に設定 → 3回目でシールドが「今日はここまで」になり解除ボタンが無い → 設定で上限を上げると次のタップで解除可能に戻る
5. クールダウン=10分 → 2回目のタップで「少し間をあける 12:34から開けます」
6. Deep Focusセッション開始 → シールドが「ディープフォーカス中」（解除ボタンなし）に切り替わる。終了→ゲート表示に戻る
7. 夜だけ：就寝時刻後のシールドが「いまは就寝の時間」
8. 解約（Sandbox）→ ゲートが外れる・設定は残る・Pro復帰でそのまま使える
9. 全データ削除 → ゲートが外れる
10. **TestFlightビルドでも2を再確認**（解除直後にシールドが残る報告あり）

---

## 14. 未確定・オーナー確認事項

1. **既定値**（上限なし・クールダウンなし・10分）で良いか。Clarymind流に「初回設定で回数と長さを聞く」にするならオンボ変更が要る（本バッチ外）
2. **ペイウォール機能行**（現行6行）に「開く回数と待ち時間をアプリごとに」を入れるか。入れるなら承認済みコピーの改訂になるため別途
3. ストア説明文・スクショ（08/09）への反映は v1.1 リリース時に別タスク
4. `openParentalControlsApp` の実機挙動は未報告。スパイクで動かなければ通知ホップが全員の経路になる（機能は成立する・UXが1タップ増える）

---

## 15. 工数見積（Codex委譲・目安）

Core（モデル・純関数・ストア・テスト）1日 / 拡張3本 1日 / アプリ側（コントローラ・フロー・設定UI・通知）2日 / 文言3言語＋監査 0.5日 / 実機検証・TestFlight 1〜2日 ＝ **約1週間〜1.5週間**（当初見積2〜4週間より短いのは既存フローを全面再利用できるため）
