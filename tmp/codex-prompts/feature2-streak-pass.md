# タスク: 我慢ストリーク＋ご褒美パス

DopaBreak（iOS/SwiftUI/iOS 17+）への機能追加。設計は`.claude/plans/crystalline-imagining-shannon.md`の「2. 我慢ストリーク＋ご褒美パス」に承認済み。文言正本は`docs/11_ui_copy.md` §11（既に追記済み・変更不要、そこから転記のみ）。省略・TODO禁止、完全なコードを出力すること。

## 背景
既存の日次記録（`AttemptLog`）のみから連続我慢日数（ストリーク）を算出し、節目でご褒美パス（介入をスキップして即座に開ける権利）を付与する。新規データ収集はしない。Free/Pro共通で有効（課金誘導ではなくエンゲージメント機構）。

## 既存コードの参照点
- `AttemptLog`構造体（`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Models/AppModels.swift`）: `decision: Decision`（`.cancelled`/`.opened`）、`startedAt: Date`
- `SQLiteLogStore.fetchAttempts(from:to:)`（`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SQLiteLogStore.swift`）で日付範囲のattemptsを取得できる
- `StatsService.swift`（`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/StatsService.swift`）が既存の集計ロジックの置き場所
- `SettingsStore.swift`の`Key`enum + computed propertyパターン
- `InterventionFlowModel.swift`の`start()`（`engine.resetToIdle()`を呼ぶ既存の状態リセットロジックあり）・`openTargetApp()`
- `InterventionFlowView.swift`のS-01呼吸画面（`breathingScreen`）
- `HomeView.swift`の`todayCard`（既存の「今日の記録」`CardContainer`。この近くに新規カードを追加する）
- `AppContainer.swift`の`AppModel.refresh()`（ログ集計を再計算する箇所。ここでストリーク再計算とパス付与判定を行う）

## 実装項目

### 1. Core: `StatsService`に`resistStreak(asOf: Date, calendar: Calendar = .current) -> Int`を新規実装
**ストリーク定義（非難しないトーンに合わせて寛容に定義。必ずこの定義通りに実装すること）**:
- `asOf`の前日から日を遡って数える（当日は未確定なので含めない）
- ある日が「ストリークを途切れさせる日」となるのは、その日に試行（attempt）が1件以上あり、かつ全ての試行が`.opened`（我慢=`.cancelled`が0件）だったときのみ
- 試行が0件の日（衝動自体がなかった日）はストリークを途切れさせない。スキップしてそのまま前日方向へ継続してカウントする
- 「途切れさせる日」に到達するまで遡り続け、そこまでの経過日数（途切れさせる日は含まない）がストリーク値
- データが全く無い場合は0
- 実装は`fetchAttempts`を使った日次ループでよい（無限ループ防止のため遡る日数に妥当な上限、例えば365日を設ける）

**必須ユニットテスト（`StatsServiceTests.swift`、既存のテストファイル・パターンに追加）**:
- 直近3日間、毎日1件以上試行がありすべて`.cancelled` → ストリーク3
- 4日前が「全て`.opened`」の日 → ストリークはそこで止まる（3日前からのみカウント）
- 昨日が試行0件（当日と直近はcancelledのみ）→ ストリークが途切れない
- 全期間データなし → 0
- 昨日が「試行1件・全て`.opened`」→ ストリーク0

### 2. Core: `SettingsStore`に追加
既存の`Key`enum + computed propertyパターンに倣う:
- `availablePasses: Int`（既定0、UserDefaults未設定時は0を返す通常のInt扱いでよい。負値のセットは0にクランプする）
- `lastPassMilestoneStreak: Int`（既定0）

### 3. `AppContainer.swift`の`AppModel`
- `refresh()`内（既存のログ集計呼び出し箇所と同じタイミング）で`statsService.resistStreak(asOf: Date())`を計算し`private(set) var currentStreak: Int`として公開する
- ストリークが7の倍数を新たに超えた（`currentStreak / 7 > settingsStore.lastPassMilestoneStreak / 7`のような判定、かつ`currentStreak >= 7`）ときにパス+1・上限3でキャップ・`settingsStore.lastPassMilestoneStreak = currentStreak`を更新。この判定はストリークが減った場合に誤って何度も付与しないよう、必ず「前回記録した達成ストリーク値」との比較で行うこと
- `availablePasses: Int`をAppModelからも参照できるようにする（`settingsStore.availablePasses`をそのまま公開するcomputed propertyでよい）

### 4. `InterventionFlowModel.swift`に`redeemPass()`を新規追加
```
func redeemPass() {
    guard settingsStore.availablePasses > 0 else { return }
    settingsStore.availablePasses -= 1
    breathTask?.cancel()
    breathTask = nil
    try? model.interventionEngine?.resetToIdle()
    openTargetApp()
}
```
上記は方針。**`engine.recordOpen()`は呼ばない**（AttemptLogを作らない＝統計・ストリークに一切影響させないのが「ノーガルティ」パスの本質）。既存の`openTargetApp()`をそのまま再利用する。

### 5. `InterventionFlowView.swift`のS-01呼吸画面（`breathingScreen`）
`settingsStore.availablePasses > 0`のときだけ、カウントダウンの下に副次的なテキストボタン「ご褒美パスを使う（残り{N}回）」を表示する。タップ時、docs/11 §11の確認シート（見出し「このまま開きますか」／本文「我慢の記録はつきません 好きなときに使えます」／ボタン「開く」「やめておく」）を挟んでから`flow.redeemPass()`を呼ぶ（`.confirmationDialog`または軽量`.alert`でよい、既存の`DesignTokens`スタイルに合わせる）

### 6. `HomeView.swift`
`todayCard`の近くに新規`CardContainer`を追加:
- 見出し「ストリーク」（`SmallLabel`）
- `model.currentStreak > 0`なら「{N}日連続」、0なら「まだ記録がありません」
- `model.availablePasses > 0`なら「ご褒美パス 残り{N}回」を併記

## 禁止事項
- パス消費でAttemptLog/ReflectionLogを作らない（SQLiteスキーマ変更は不要・行わないこと）
- 既存のS-01〜S-05フロー本体・`InterventionEngine`の状態遷移ロジックには`resetToIdle()`呼び出し以外触れない
- docs/11_ui_copy.mdは変更しない（既に§11として追記済み）
- コード省略・TODO・プレースホルダ禁止

## 完了条件
1. `swift test --package-path ios/Packages/DopaBreakCore` 全件パス（`resistStreak`の全テストケース含む）
2. `cd ios && xcodebuild build -scheme DopaBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` が `BUILD SUCCEEDED`
3. 変更/新規ファイル一覧とテスト結果を最後に要約すること
