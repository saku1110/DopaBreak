# タスク: 起床/就寝の時間帯検知 → 介入コピー出し分け ＋ 画面を自動でモノクロにする設定ガイド

DopaBreak（iOS/SwiftUI/iOS 17+、xcodegenプロジェクト `ios/`）への機能追加。設計は `.claude/plans/crystalline-imagining-shannon.md` に承認済み。文言の正本は `docs/11_ui_copy.md`（§4d, §4e, §8 に今回分を追記済み）。**このタスクでは docs/11_ui_copy.md 自体は変更しない**（既に更新済み）— そこに書かれた文言をそのまま転記すること。省略・TODO残しは禁止。完全なコードを出力すること。

## 背景・制約
- Appleはサードパーティアプリがシステム全体のカラーフィルター(モノクロ)を直接自動でON/OFFする公開APIを提供していない。実現方法は「ショートカットのパーソナルオートメーション（時刻トリガー→カラーフィルタ設定）」のみ。ユーザーが初回に手動で設定すれば以降は完全自動。
- 既存の `ios/DopaBreak/AutomationGuideView.swift` が全く同じ制約（設定完了をアプリ側から検知できない）を「`shortcuts://`ディープリンク＋番号付き手順ガイド」で解決済み。新規画面はこのファイルと同じ構成・コーディングスタイルを踏襲すること。

## 実装項目

### 1. `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SettingsStore.swift`
既存の `Key` enum + computed property パターンに倣い、以下を追加:
- `Key.wakeTimeMinutes = "wakeTimeMinutes"` / `Key.bedTimeMinutes = "bedTimeMinutes"`
- `public var wakeTimeMinutes: Int?` / `public var bedTimeMinutes: Int?`
  - 「起床/就寝時刻」を**当日0時からの分数**（0〜1439の整数）として保存する
  - **重要**: `UserDefaults.integer(forKey:)` は未設定時に0を返すため「未設定」と「0分＝深夜0:00」を区別できない。必ず `object(forKey:) as? Int` で読み取り、未設定はnilを返すこと。setterは既存の `setOptional` ヘルパーを再利用

### 2. 新規: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Models/DayTimeContext.swift`
```swift
public enum DayTimeContext: Equatable, Sendable {
    case wake
    case sleep
    case normal
}
```
純粋関数として実装（`public static func resolve(now: Date, wakeMinutes: Int?, bedMinutes: Int?, calendar: Calendar = .current) -> DayTimeContext` のような形、命名はCore既存の命名規則に合わせて調整可）。

**アルゴリズム（分数の mod 1440 演算で日付またぎを吸収する。Calendar.dateで日付比較しないこと）**:
1. `wakeMinutes`と`bedMinutes`が両方nilなら`.normal`を返す
2. `now`を `calendar.dateComponents([.hour, .minute], from: now)` で分解し `nowMinutes = hour*60 + minute` を算出
3. 窓判定ヘルパー: `isInWindow(nowMinutes, start: Int, lengthMinutes: Int) -> Bool` を、`((nowMinutes - start) mod 1440 + 1440) mod 1440 < lengthMinutes` で実装（start自体も事前に `((start mod 1440) + 1440) mod 1440` で正規化）。startちょうどは含む（>=0）、start+length ちょうどは含まない（exclusive end）
4. `wakeMinutes`があれば起床窓 = `isInWindow(nowMinutes, start: wakeMinutes, lengthMinutes: 30)` → true なら `.wake`
5. 次に`bedMinutes`があれば就寝窓 = `isInWindow(nowMinutes, start: bedMinutes - 60, lengthMinutes: 60)` → true なら `.sleep`（`bedMinutes - 60`が負になっても上記正規化で吸収される）
6. どちらでもなければ`.normal`
7. 両方の窓に理論上該当し得る場合は起床窓を優先（4→5の順で判定すればよい）

### 3. 新規テスト: `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/DayTimeContextTests.swift`
（既存の `RuleStoreTests.swift` 等と同じターゲット・スタイルに合わせる）。以下を必ずカバー:
- wake/bed両方nil → 常に`.normal`
- 起床窓の開始ちょうど（例: wake=420 [07:00] → now=420 は `.wake`）
- 起床窓の1分前（now=419）は`.normal`
- 起床窓の終了ちょうど（now=450 [07:30、開始+30分]）は`.normal`（exclusive end）
- 就寝窓の開始ちょうど（例: bed=1380 [23:00] → 窓開始=1320 [22:00]、now=1320は`.sleep`）
- 就寝窓の終了ちょうど（now=1380）は`.normal`
- **日付またぎケース**: wake=10（00:10）で窓が前日23:50〜00:40相当になる場合、now=1430（23:50）が`.wake`になること
- **日付またぎケース**: bed=20（00:20）で就寝窓が23:20(前日)〜00:20になる場合、now=1400（23:20）が`.sleep`になること、now=10（00:10）も`.sleep`になること
- wakeとbedが同時に該当しうる境界を作った場合は`.wake`が優先されること

### 4. `ios/DopaBreak/InterventionFlowModel.swift`
`InterventionFlowModel`に計算プロパティを追加:
```swift
var dayTimeContext: DayTimeContext {
    DayTimeContext.resolve(now: Date(), wakeMinutes: settingsStore.wakeTimeMinutes, bedMinutes: settingsStore.bedTimeMinutes)
    // ↑ 実際の関数名はCore側の実装に合わせる
}
```

### 5. `ios/DopaBreak/InterventionFlowView.swift` の `usageSummaryScreen`（S-02、現在97-110行付近）
既存の `titleText("今日はもう\(flow.todayAttemptDisplayCount)回目")` は変更しない。その**上**に、`flow.dayTimeContext`が`.wake`または`.sleep`のときだけ小さなバナーを追加表示する（`.normal`のときは何も表示せず現状のまま）。

バナーの文言は `docs/11_ui_copy.md` §8 から転記:
- `.wake`: 見出し「起きてすぐの数分」／本文「その日の集中を決める時間」
- `.sleep`: 見出し「眠る前の数分」／本文「その日の睡眠の質を決める時間」

見た目は既存の`SmallLabel`（見出し用、DesignTokens.accent系）と`DesignTokens.secondaryText`の本文テキストを使い、既存の`CardContainer`または単純な`VStack(alignment: .leading, spacing: 4)`で囲む。既存のS-02 VStack（`VStack(alignment: .leading, spacing: 22)`）の先頭要素として条件付きで挿入すること（`if flow.dayTimeContext != .normal { ... }`）。

### 6. 新規: `ios/DopaBreak/GrayscaleAutomationGuideView.swift`
`ios/DopaBreak/AutomationGuideView.swift`を参考に**同一パターン**で新規作成:
- ファイル冒頭のドキュメントコメントは「画面を自動でモノクロにする設定ガイド（doc11 §4e）。設定完了はiOSの仕様上検知できないため手順ガイドのみで案内する。」のような一文
- `struct GrayscaleAutomationGuideView: View { let model: AppModel; let settingsStore: SettingsStore; ... }`
- タイトル・サブ・「ショートカットを開く」ボタン（`AutomationGuideView.openShortcutsApp()`と同じ`shortcuts://`実装。コード重複でよい、共通化は不要）
- 理由カード（見出し「なぜモノクロ?」／本文「色のない画面はSNSへの反応を弱めると言われています」）
- `settingsStore.wakeTimeMinutes`と`bedTimeMinutes`が両方設定済みの場合のみ、2枚の手順カードを表示:
  - カード1見出し「就寝時刻にモノクロにする」、手順1〜5（docs/11 §4e の手順カード1-1〜1-5をそのまま使用。手順1-3の「{就寝時刻}」は実際の値をHH:mm形式で埋め込む）
  - カード2見出し「起床時刻にモノクロを解除する」、同様に手順1-4は共通、手順5は「モノクロをオフにする」、時刻は起床時刻を埋め込む
  - いずれか未設定の場合は「先に起床・就寝時刻を設定してください」のみ表示（`AutomationGuideView`の`selectedTargets.isEmpty`時の表示パターンを参考に）
- フッター注記「設定完了はiOSの仕様上確認できません。設定後は実際に時刻を待って確認してください。」
- `numberedStep`ヘルパーは`AutomationGuideView`と同じ実装を複製してよい
- `.preferredColorScheme(.dark)` / `.tint(DesignTokens.accent)` / `dopaScreenBackground()` など既存の画面と同じ修飾子を使う
- 閉じるボタンは既存と同じ「閉じる」ラベル

### 7. `ios/DopaBreak/SettingsView.swift`
- 新規 `@State private var isGrayscaleGuidePresented = false`
- `targetSection`（対象アプリ・一呼吸の長さ・自動設定ガイドが入っているCardContainer）とは別に、新セクション`wakeSleepSection`を追加し、`targetSection`の直後・`accountSection`の直前に配置:
  - `SmallLabel(text: "起床・就寝時刻")`
  - `CardContainer`内に2行:
    - 「起床時刻」ラベル＋`DatePicker(selection:, displayedComponents: .hourAndMinute)`（`.labelsHidden()`、compactスタイル）。バインディングは`settingsStore.wakeTimeMinutes`（Int?・分数）と`Date`を相互変換する`Binding<Date>`を新規computed propertyとして実装。getはnilなら07:00相当のデフォルト`Date`を表示用に返す（保存はしない）、setは選択された`Date`から`Calendar.current.dateComponents([.hour,.minute], from:)`で分数を計算し`settingsStore.wakeTimeMinutes`に書き込む
    - 「就寝時刻」も同様（デフォルト表示23:00、`settingsStore.bedTimeMinutes`）
    - 区切り線（既存`divider`を再利用）
    - ボタン「画面を自動でモノクロにする設定」→ `isGrayscaleGuidePresented = true`（既存の「自動で一呼吸を出す設定」ボタンと同じ`settingsRow`スタイル）
- `.sheet(isPresented: $isGrayscaleGuidePresented) { GrayscaleAutomationGuideView(model: model, settingsStore: settingsStore) }` を既存の`.sheet`群に追加

## 禁止事項・注意
- `docs/11_ui_copy.md`にない文言を新規に作らない（見出し・短文は句読点なし・改行/体言止めの既存ルールに既に従って書かれているのでそのまま使う）
- 既存のS-01〜S-05フロー・既存のInterventionMode/RuleStore/ShieldController関連コードには一切触れない（MVPでシールド同期は意図的にno-opのまま、今回の変更対象外）
- 新しい依存パッケージを追加しない
- コード省略・`// TODO`・プレースホルダ実装を残さない。完全に動くコードを書くこと

## 完了条件
1. `cd ios && xcodebuild test -scheme DopaBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`（またはプロジェクトの既存テスト実行コマンド。`project.yml`や既存CIスクリプトがあれば従う）でビルド・全テストがグリーン
2. 新規`DayTimeContextTests.swift`のテストが上記シナリオを全てカバーしパス
3. 変更ファイル一覧と、実行したテストコマンド・結果を最後に要約すること
