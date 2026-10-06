# 詳細設計

作成日: 2026-06-27 / 改訂: 2026-07-17（Goalを種類なしのフラットリストへ同期）

## 1. 技術方針

MVPは iOS Native / SwiftUI を推奨する。

理由:

- Screen Time APIはSwift/SwiftUIとの親和性が高い。
- Device Activity Monitor Extension、Shield Configuration Extension、Shield Action Extensionが必要。
- WidgetKit、StoreKit 2、App Groupsとの統合が明確。
- Expo/React Nativeで作る場合も、Screen Time周りは結局ネイティブ実装が必要になる。

将来React Native/Expoを採用する場合は、設定画面やコンテンツ画面だけRNにし、Screen Time、Shield、Widget、StoreKitはiOSネイティブモジュールとして分離する。

## 2. 全体アーキテクチャ

```text
iOS App (SwiftUI)
├── Onboarding
├── Goal Management
├── Target App Setup
├── Stats
├── Paywall
├── Settings
│
├── Core
│   ├── GoalStore
│   ├── RuleStore
│   ├── AttemptLogStore
│   ├── EntitlementStore
│   └── AnalyticsClient
│
├── ScreenTime
│   ├── FamilyControls authorization
│   ├── FamilyActivityPicker
│   ├── DeviceActivityCenter schedules
│   └── ManagedSettingsStore shields
│
├── Extensions
│   ├── DeviceActivityMonitorExtension
│   ├── ShieldConfigurationExtension
│   ├── ShieldActionExtension
│   ├── WidgetExtension（Home Widgetのみ・2026-07-02ロック常設廃止）
│   └── LiveActivity (ActivityKit)
│
└── Shared Storage
    ├── App Group UserDefaults
    ├── SwiftData / SQLite
    └── Keychain
```

## 3. Apple API利用

| API | 用途 |
| --- | --- |
| FamilyControls | Screen Time権限、対象アプリ/カテゴリ/Web選択 |
| DeviceActivity | スケジュール、利用閾値、バックグラウンド監視 |
| ManagedSettings | アプリ/Webのシールド、制限適用 |
| ManagedSettingsUI | カスタムシールド表示 |
| WidgetKit | ホーム画面ウィジェット（ロック常設は2026-07-02廃止） |
| ActivityKit | デイリーLive Activity（ロック画面カード・テーマ適用面） |
| StoreKit 2 | サブスクリプション/買い切り |
| UserNotifications | 日次/週次リマインド |
| SwiftData or SQLite | ローカルデータ保存 |
| App Groups | 本体アプリとExtension間の共有 |

制約:

- DeviceActivityはスケジュール開始/終了、利用閾値到達、警告などを扱えるが、他社SNSアプリを閉じた瞬間のイベントは提供しない。
- standardでは他社SNSのリアルタイム使用時間を取得できないため、時間選択・時間経過通知・自動リフレクションを行わない。
- シールド一時解除は、OS側で管理する解除期限・再シールド・DopaBreak復帰時だけをリフレクションの根拠にする。

## 4. データモデル

### Goal（2026-07-17 改訂: 種類なしのフラットリスト）

```text
Goal
- id: UUID
- title: String
- lockScreenTitle: String?
- category: GoalCategory
- displayImagePath: String?
- createdAt: Date
- updatedAt: Date
```

目標は種類を持たない軽量なフラットリストとする。Freeは1件、Proは複数件を保存できる。配列の保存順が表示順で、先頭を主目標としてHome・Shield・介入画面などに表示する。追加は末尾、並べ替えは`moveGoal`で行う。`category`は目標エディタの分類に使うため維持する。タスク/期限/チェックリストは持たない。

### SelfCheckSnapshot（2026-07-02 追加: オンボ損失クイズの回答）

```text
SelfCheckSnapshot
- id: UUID
- usageBucket: String        // 1時間未満 / 1-2 / 2-4 / 4-6 / 6時間以上（旧データは 4時間以上 も保持）
- aimlessScrollBucket: String
- regretBucket: String
- estimatedDailyMinutes: Int // 推計表から算出
- estimatedYearlyDays: Int   // 例: 38
- createdAt: Date
```

用途: O-03r損失リビール、O-08bサマリー、週次レポートの「取り戻した時間」物差し。端末外送信はbucket値のみ（本文なし）。

### TargetRule

```text
TargetRule
- id: UUID
- name: String
- activitySelectionData: Data
- mode: InterventionMode   // deepFocus | standard | nightOnly の3値のみ（O-05の3モード。doc06 §5）
- schedule: ScheduleRule?
- delaySeconds: Int
- maxOpensPerDay: Int?
- defaultDurationMinutes: Int
- isEnabled: Bool
- createdAt: Date
- updatedAt: Date
```

`activitySelectionData` はFamilyActivitySelectionをApp Group領域に保存する想定。

### AttemptLog

```text
AttemptLog
- id: UUID
- ruleId: UUID
- startedAt: Date
- completedAt: Date?
- decision: Decision
- intent: IntentCategory?
- selectedDurationSeconds: Int?
- attemptCount24h: Int
- opened: Bool
```

### ReflectionLog

```text
ReflectionLog
- id: UUID
- attemptLogId: UUID?
- ruleId: UUID
- promptedAt: Date
- answeredAt: Date?
- trigger: ReflectionTrigger
- satisfaction: PostUseSatisfaction?
- happinessDelta: HappinessDelta?
- skipped: Bool
- createdAt: Date
```

```text
ReflectionTrigger
- timedSessionEnded
- reshielded
- appReturned
- notification
```

```text
PostUseSatisfaction
- satisfied
- fun
- nothingGained
- lostTime
- feltWorse
```

```text
HappinessDelta
- increased
- unchanged
- decreased
```

### WidgetSnapshot（Home Widget用・2026-07-02改訂: ロック常設系モデルを廃止）

```text
WidgetSnapshot
- primaryGoalTitle: String        // フル文言
- displayTitle: String            // 短縮表示名 12-16文字（Home Small/Dynamic Island用）
- todayCancelledCount: Int
- todayAttemptCount: Int
- theme: LockTheme
- updatedAt: Date
```

### LockSurfaceState（2026-07-02 追加: 通知/Live Activity、2026-09-03 朝通知廃止）

```text
LockSurfaceState
- weeklyReportNotificationTime: DateComponents   // 例 7:00
- weeklyReportEnabled: Bool
- liveActivityEnabled: Bool
- liveActivityStartedAt: Date?              // 8時間制限 → 起動/介入時に更新して延長
- theme: LockTheme                          // e1 | sumi | asagiri | shinrin | yozora | kpop | kawaiiPink（Free=e1のみ）
```

設計:

- 週次通知: 月曜（weekday: 2）の`weeklyReportNotificationTime`ちょうどに`UNCalendarNotificationTrigger`で発火する。
- Live Activity: ActivityKitで「今日のゲート実績」を表示。`todayCancelledCount`/取り戻した時間をShieldAction後にpush更新（ライブ更新が審査要件を満たす根拠）。8時間で失効するため、アプリ起動時・介入時に再開始する。
- `displayTitle`（12-16文字）はHome Widget/Dynamic Islandで使用。旧 LockScreenGoalSnapshot / LockScreenWidgetLayout は廃止。

## 5. 介入状態遷移

```text
Idle
  -> ShieldPresented
  -> Breathing
  -> UsageSummary
  -> GoalReminder
  -> IntentSelection
  -> Decision
       -> Cancelled
       -> TimeSelection
            -> TemporarilyAllowed
            -> ReShieldScheduled
            -> PostUseReflection
                 -> ReflectionAnswered
                 -> Closed
```

注意: `TimeSelection` 以降はシールド一時解除の経路だけで使う。`PostUseReflection` は対象SNSを閉じた瞬間ではなく、実際の解除期限後の再シールドまたはDopaBreak復帰時に開始する。通常起動では時間選択・時間通知・自動リフレクションを行わない。

### InterventionState（実装済み 2026-07-02・InterventionEngineが intervention_state.json に永続化）

```text
InterventionState
- currentStep: InterventionStep   // 上記ステートマシンの12値
- ruleId: UUID?
- startedAt: Date?
- updatedAt: Date
- allowedUntil: Date?             // 一時開放の期限
- intent: IntentCategory?         // ✅実装済み（2026-07-03）。snapshotに永続化され跨プロセスで保持。
                                  //   旧intervention_state.json（intentキーなし）は後方互換でnilとして読める
```

## 6. 介入ロジック

### シールド表示時

1. ShieldConfigurationExtensionが呼ばれる。
2. App Groupから現在の主目標、当日の試行回数、対象ルールを読む。
3. 現在のステップに応じて画面文言を返す。
4. Primary/Secondary buttonを表示する。

### ボタンアクション時

1. ShieldActionExtensionが押下内容を受け取る。
2. `開かない` の場合:
   - AttemptLogを `cancelled` で保存
   - ManagedSettingsのシールドを維持
   - shield action responseで閉じる
3. `続ける` の場合:
   - 次ステップへ進める
   - 必要に応じてdeferしてシールド再描画
4. `時間を選択して開く` の場合:
   - 指定時間だけ対象tokenのシールドを解除
   - DeviceActivityまたはローカルタイマーで再シールド予定を保存
   - AttemptLogを `opened` で保存
   - `ReflectionLog` を未回答状態で作成

### 利用後リフレクション時

1. `timedSessionEnded` または `reshielded` のタイミングで未回答の `ReflectionLog` を探す。
2. 未回答ログがあり、直近セッションから一定時間内ならリフレクション画面を表示する。
3. ユーザーが満足感を1つ選択する。
4. `ReflectionLog` に `satisfaction` と、満足感から導出した `happinessDelta` を保存する。
5. 集計snapshotを更新する。
6. 「何も得られなかった」「時間を失った感じがする」「気分が下がった」が一定割合を超えた場合、Deep Focus強化の提案を表示する。

## 7. 画面ごとのデータ読み書き

| 画面/Extension | Read | Write |
| --- | --- | --- |
| Onboarding | Entitlement状態 | Goal, TargetRule, WidgetSnapshot |
| Target App Setup | FamilyActivitySelection | TargetRule |
| ShieldConfiguration | Goal, Rule, AttemptLog集計 | なし |
| ShieldAction | Rule, InterventionState | AttemptLog, ReflectionLog, Rule一時解除 |
| Home | Goal, Stats | Goal並び替え |
| Home Widget | WidgetSnapshot | なし |
| Live Activity | WidgetSnapshot, LockSurfaceState | なし |
| Stats | AttemptLog, ReflectionLog | なし |
| Paywall | Entitlement | Purchase state |

## 8. Extension間共有

App Groupを使う。

```text
group.com.dopabreak.shared   // 確定（2026-07-02・旧: goalgate→lifefocus）
├── goals.json / sqlite
├── rules.json / sqlite
├── attempt_logs.sqlite
├── reflection_logs.sqlite
├── widget_snapshot.json
├── lock_surface_state.json
├── self_check_snapshot.json   // オンボ損失クイズ回答（週次レポートの比較基準に使用）
└── intervention_state.json
```

注意:

- Extensionから重いDB処理をしない。
- Shield表示に必要な情報は `widget_snapshot` と同様に軽量snapshot化する。
- 目標画像はExtensionで読みやすいサイズにリサイズして保存する。

## 9. 主要サービス

### GoalStore

- goals / allGoals
- primaryGoal   // 保存順の先頭を取得
- save
- delete(id:) / deleteAll
- moveGoal(from:to:)

### LockSurfaceStore（旧WidgetStoreを置換・2026-07-02）

- scheduleMorningNotification / cancelMorningNotification
- scheduleWeeklyReportNotification
- startDailyLiveActivity / refreshLiveActivity / endLiveActivity
- setLockTheme（Entitlement検証: Free=e1のみ）
- makeWidgetSnapshot（Home Widget用）

### RuleStore

- saveFamilyActivitySelection
- enableRule
- disableRule
- updateSchedule
- updateMode

### InterventionEngine

- getCurrentStep
- advanceStep
- recordIntent
- recordCancel
- recordOpen
- temporaryAllow
- rescheduleShield
- createPendingReflection
- shouldShowPostUseReflection
- recordPostUseReflection

### StatsService

- attemptsToday
- cancelledToday
- intentBreakdown
- reflectionBreakdown
- happinessDeltaBreakdown
- wastedTimeRealizationRate
- appRuleBreakdown
- weeklySummary

### EntitlementService

- loadProducts
- purchase
- restore
- isPro
- canAddGoal(currentCount:)   // Freeは1件、Proは上限なし
- canAddRule

## 10. ローカル保存方針

| データ | 保存先 | 理由 |
| --- | --- | --- |
| 目標/ルール | SwiftData or SQLite in App Group | 本体とExtension共有 |
| AttemptLog | SQLite in App Group | 集計しやすい |
| ReflectionLog | SQLite in App Group | 日次/週次の満足感集計に使う |
| 購入状態 | StoreKit + Keychain/Cache | 復元可能にする |
| 画像 | App Group file storage | Widget/Shieldで参照 |
| 設定 | App Group UserDefaults | 軽量アクセス |

## 11. Analytics方針

MVPはオンデバイスのローカル4イベント（`onboardingCompleted` / `automationVerified` / `paywallShown` / `trialOrPurchaseStarted`）のみで、外部送信は行わない（2026-07-10 WP3）。介入・振り返り系は`AttemptLog` / `ReflectionLog`から導出する。外部Analytics導入はローンチ後に判断する。

ローンチ後に外部Analyticsを導入する場合のイベント候補:

- オンボーディング完了
- 目標作成
- 対象アプリ数
- ウィジェット設置導線開始
- 介入開始
- 意図カテゴリ選択
- 開かない
- 開く
- 利用後リフレクション表示
- 利用後リフレクション回答
- 利用後リフレクションスキップ
- Paywall表示
- 購入

## 12. 課金設計

StoreKit 2を使う。

商品（2026-07-02 確定。価格根拠は doc01 §8。2026-07-02確定）:

```text
dopabreak.pro.monthly        ¥780/月    ($5.99)
dopabreak.pro.annual         ¥4,980/年  ($34.99) 7日無料トライアル付き・デフォルト
dopabreak.pro.annual.launch  ¥3,980/年  ($27.99) 7日無料・価格A/B用（テスト終了後に販売停止）
dopabreak.pro.lifetime       ¥14,800    ($99.99) 非消耗型
```

- 年額はIntroductory Offer（7日無料）を設定。価格A/Bは年額製品2本を用意し、ペイウォールに表示する製品IDをリモート構成で切り替える（StoreKitの表示価格は製品定義に従うため）。
- 復元必須・Entitlement同期・サンドボックス/TestFlight検証（審査3.1.1/3.1.2）。

Entitlement:

```text
Free:
- goals_limit = 1
- target_rules_limit = 1
- target_app_tokens_limit = 1   // FamilyActivitySelection内のapp/categoryトークン合計を保存時に検証。超過分は無効化しPro導線
- lock_theme = e1_only          // Live Activityテーマ（2026-09-03: 朝の目標通知廃止。テーマがロック面の課金価値）
- stats_days = 1

Pro:
- goals_limit = unlimited
- target_rules_limit = unlimited
- target_app_tokens_limit = unlimited
- lock_theme = all_6_themes     // 墨と灯/朝霧/森林/夜更け/K-POP/かわいいピンク
- stats_days = unlimited
- themes = true
- weekly_report = true          // 週次通知（基本件数）=無料／週次レポート詳細分析=Pro（2026-07-10確定・通知はリテンション面として無料開放）
- strict_mode = true
```

**目標の扱い**: オンボーディングでは最初の1件を作成する。Freeは1件まで、Proは複数件を追加できる。保存順の先頭を主目標として表示し、Goals画面の並べ替えで変更できる。削除はいつでも可能。

**対象アプリの扱い（オンボ）**: O-03では複数選択を許可し、O-08bサマリーにも全選択を表示する。Freeで開始した場合は最初の1個のみルール有効化し、残りは「Proで守る」導線として保持する。

## 13. エラー/例外

| ケース | 挙動 |
| --- | --- |
| Screen Time権限なし | セットアップ画面へ戻し、権限説明 |
| 対象アプリ未設定 | 介入機能は無効。ウィジェットだけ利用可能 |
| 主目標なし | デフォルト文言「いま本当に必要？」を表示 |
| App Group読み込み失敗 | 最小シールドを表示し、開かない/続けるだけ表示 |
| 未回答リフレクションが古い | 表示せず、skippedとして扱う |
| 通知許可なし | 利用後通知は出さず、次回アプリ復帰時に表示候補にする |
| 購入復元失敗 | エラー表示、再試行導線 |
| Widget更新遅延 | 最終更新時刻を内部保持。リアルタイム前提にしない |

## 14. セキュリティ/プライバシー

- 目標文、理由ログ、対象アプリ情報はデフォルトで端末外へ送らない。
- 利用後リフレクション回答はセンシティブな自己評価データとして扱い、デフォルトで端末外へ送らない。
- Analyticsには本文を入れない。
- Crash logにはPIIを含めない。
- Privacy Policyに、Screen Time API利用、保存データ、送信データを明記する。
- ユーザーが全ローカルデータを削除できるようにする。

## 15. 実装順

1. App Groupとローカル保存
2. 目標作成
3. FamilyControls権限
4. FamilyActivityPicker
5. ManagedSettingsでシールド
6. ShieldConfiguration表示
7. ShieldActionで開かない/続ける
8. シールド一時解除の時間選択と一時開放（standardは時間選択なし）
9. 利用後リフレクション
10. AttemptLog/ReflectionLogと統計
11. WidgetKit
12. StoreKit 2
13. Onboarding/Paywall polish

## 16. 技術検証タスク

最初のスプリントで必ず確認する。

1. 選択した対象アプリにカスタムシールドを出せるか。
2. ShieldActionで段階的な画面遷移を実現できるか。
3. 指定時間だけ一時開放して再シールドできるか。
4. App GroupからExtensionが目標snapshotを安定して読めるか。
5. WidgetとShieldが同じ目標データを表示できるか。
6. シールド一時解除の期限終了後に利用後リフレクションを表示できるか。
7. standardで利用時間を推測せず、通知や時間選択なしでも介入からSNS復帰まで自然か。
