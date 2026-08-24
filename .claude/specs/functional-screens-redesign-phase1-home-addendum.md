# Phase 1 追記 — ホーム構成の差し替え（2026-08-24 オーナー承認モック準拠）

親: `functional-screens-redesign-phase1-brief.md`。本追記は §3「ホーム」を**丸ごと置き換える**。§0 共通制約・§1 共通部品・§2 止めるアプリ・§4 撮影・§5 報告は親ブリーフのまま。
承認モック: https://claude.ai/code/artifact/9b380cad-0f42-4cc1-b289-59134e1076b1（scratchpad `dopabreak-home-mock.html`）。

## 0. 文言の原則（オーナー指示 2026-08-24・全Phase共通）
- **見出し・ラベルは中身そのものを平易な名詞で書く**。造語・概念名（守り／見守り／チェックイン等）、英語だけのeyebrow（TODAY・THIS WEEK・RECLAIMED 等の装飾ラベル）、内部用語（介入／シールド／ゲート／モード名だけの表示）は禁止。
- 設定画面など既存画面の語彙に揃える（「止めるアプリ」「一呼吸の長さ」「開けなくなります」）。
- 短い表示コピーに読点・句点を入れない。CTAに金額を入れない。
- 最終文言は `.claude/specs/functional-screens-redesign-copy-sheet.md`（humanizer通過済み・ja/en/ko）を正とし、ここに書いた文言と食い違えばコピーシートが勝つ。

## 1. ホーム（`HomeView.swift`）上→下

### 1-1 先頭行
- 左: 日付ラベル。既存 `home.hero.today`（`TODAY ・ %@`）は英語eyebrowなので文言を **「今日 ・ 8月24日」** に変更（キーは維持、3言語更新）。右: 既存 `home.hero.week_count`（「%lld回 / 今週」）。

### 1-2 ヒーロー（横組み）
- 左に `CharacterView`（表情は現行ロジック維持）112pt。右に縦積み: ライム数字「12<small>回</small>」（56pt `.black .rounded`）→「今日 開かなかった」（既存 `home.achievement.title` 相当）→ 既存 `home.achievement.summary`（「開こうとしたのは%lld回」）→ **連続日数チップ**（新規キー `home.streak.days` = 「連続 %lld日」、ライム点＋12pt semibold・hairline枠カプセル）。
- 連続日数の定義: 「開かなかった回数 ≥ 1 の日」が今日から遡って連続している日数（今日が0回でも昨日までの連続を表示。今日を含め連続0なら チップ非表示）。Core に純関数 `StatsService.consecutiveDaysWithCancellations(endingOn:)` を追加しテスト（0日／今日のみ／今日0で昨日から3日／途切れ）。
- 親ブリーフの `DopaRing` ヒーローは**ホームでは使わない**（設定のステータスカード用に部品は作る）。

### 1-3 取り戻した時間カード（新規）
- eyebrow 新規キー `home.reclaimed.title` = 「取り戻した時間」。本文: ライム 32pt `.black` 「2時間48分」＋ 13pt secondary「今週」。下行 新規キー `home.reclaimed.yearly` = 「この調子なら1年で約 %@日分」。
- 算出（Core 純関数 `StatsService.reclaimedSeconds(from:to:)`）: 期間内の `decision == .cancelled`（開かなかった）試行1件につき、**直近30日の開いた試行の `selectedDurationSeconds` の中央値**を加算。開いた実績が無い間は既定 300秒。1年換算 = 週の取り戻し秒 × 52 ÷ 86400、小数1桁切り捨て。0のときは「0分」を表示し年換算行は非表示。テスト: 中央値・既定値・0件。
- 表示書式: 60分未満「%lld分」、以上「%lld時間%lld分」（新規キー `home.reclaimed.minutes` / `home.reclaimed.hours_minutes`）。

### 1-4 止めているアプリカード（新規）
- eyebrow 新規キー `home.targets.title` = 「止めているアプリ」（親ブリーフの「守っているアプリ」を置換）。
- 本文左: 選択中カタログアプリを `AppIconView(size:44)` 横並び（最大3、超過は `AppIconStack` の `+N`）。各アイコン右上にライム点。0件なら `＋` タイルと新規キー `home.targets.empty` = 「止めるアプリを選ぶ」。
- 本文右（縦2行）:
  - 1行目 新規キー `home.targets.breath_line` = 「開く前に%lld秒の間が入ります」（一呼吸の長さから）。強さが Deep Focus 実行中なら 新規キー `home.targets.focus_running` = 「あと%@ 開けません」（残り時間・既存書式再利用）。
  - 2行目 夜だけ強化がONのときだけ 新規キー `home.targets.night_line` = 「%@から朝まで開けません」（就寝時刻）。OFFなら行を出さない。
- ボタン（`PrimaryButtonStyle`・高さ48）新規キー `home.targets.focus_30` = 「30分だけ開けなくする」。タップ: Pro なら `container.startDeepFocusSession(durationMinutes: 30)`、Free なら既存 `settingsModeGate` ペイウォール。Deep Focus 実行中はボタンを 新規キー `home.targets.focus_end` = 「いま解除する」（`.ghost` 相当の枠線スタイル）に差し替え `endDeepFocusSession()`。強さが「夜だけ強化」で夜間ブロック中も「あと%@ 開けません」を1行目に出しボタンは非表示。
- カード本文（ボタン以外）タップで `TargetAppPickerSheet`。

### 1-5 今週カード
- eyebrow 既存 `THIS WEEK` を **「今週」** に変更（キー維持・3言語）。`DayBars(days:)`（親ブリーフ §1-4 のまま。今日を強調）。下行: 既存 `home.week.summary`（「今週 開かなかったのは%lld回」）＋「 ・ 」＋ 前週比（`WeeklyDetailReport.cancelledDelta` を使い既存 `stats.weekly_detail.comparison.less/more` を再利用。比較不能なら省略）。

### 1-6 アプリごとカード（新規）
- eyebrow 新規キー `home.apps.title` = 「アプリごと」。行: `AppIconView(size:22)` ＋ 横バー（分母=今日の試行、分子=開かなかった）＋ 右端 `%lld / %lld`（monospaced）。下行 新規キー `home.apps.legend` = 「今日 開かなかった / 開こうとした」。
- データ: **`StatsService.appRuleBreakdownDetailed(from:to:) -> [UUID: (attempts: Int, cancelled: Int)]` をこのPhaseで追加**（Phase 2 ブリーフの先取り・Core テスト付き）。ruleId → catalog の対応付けは既存経路のみ。対応できない rule は `TargetRule.name`、名前もなければ行をスキップ。0件ならカード非表示。
- Free: 実データの上に `blur(10)`＋`backgroundRaised` 60% オーバーレイ＋ 中央ボタン（既存 `stats.paywall.weekly_report` 文言・`paywallPlacement = .statsHistoryGate`）。高さはPro時と同じ。

### 1-7 SNSを見てどうだった？カード（新規）
- eyebrow = 振り返りの質問文そのもの（既存 `reflection.satisfaction.title` を再利用）。
- 本文: 今週の `reflectionBreakdown` で最多の満足度を 18pt bold で「『%@』が多め」（新規キー `home.reflection.top` = 「「%@」が多め」、%@は既存の満足度ラベル）。同数首位や回答0件の扱い: 0件ならカード非表示、同数なら5値順で先。下: 直近6回の回答を10ptドットで（satisfied/fun=accent、nothingGained=tertiary、lostTime/feltWorse=danger）＋ 新規キー `home.reflection.count` = 「今週の%lld回中 %lld回」。
- Free: 1-6 と同じぼかし＋ボタン。

### 1-8 目標カード
- 親ブリーフ §3-6 のまま（カテゴリタイル＋eyebrow「あなたの目標」＋タイトル＋chevron）。最下部。

### 1-9 その他
- `firstDayEmptySection` / `automationStatusBanner` の位置は親ブリーフどおり。初日（試行0）は 1-3・1-6・1-7 を非表示、1-4 は表示。
- 新しい計測は追加しない。Core 追加はすべて既存ログからの純関数＋テスト。

## 2. 触ってはいけない他セッションの未コミット変更（上書き・整形禁止）
- シールド解除フロー v1.1（test-project-f1）: `AppContainer.swift`, `DopaBreakApp.swift`, `NotificationDelegate.swift`, `RootTabView.swift`, `SettingsView.swift`, `PaywallView.swift`, `InterventionFlowModel.swift`, `InterventionFlowView.swift`, `ShieldController.swift`, `Gate*.swift`, `ios/MonitorExtension/*`, `ios/Shield*Extension/*`, `ios/project.yml`, Core の `DopaBreakCore.swift` / `EntitlementGate.swift` / `LocalDataResetter.swift` / `JSONSnapshotStore.swift` / `Gate*.swift`。`AppContainer.startDeepFocusSession` を**呼ぶだけ**は可。
- スクショ担当（test-project-23）: `BreathingCharacterView.swift`（リング ratio 0.82／線幅6／`BreathCharacterTimeline.progress(at:)`）— DopaRing はこれを参照して**別ファイルに**一般化し、元は触らない。
- `Localizable.xcstrings` は**キー追加・指定キーの値更新のみ**。既存の他キーを並べ替え・整形しない。

## 3. 撮影（親 §4 に追加）
`output/screenshots/redesign-phase1/home.png`（Pro・シード）、`home-free.png`（Free・ぼかし）、`target-picker.png`。

## オーナー訂正（2026-08-24・後勝ち）

- Freeの「アプリごと」と「SNSを見てどうだった？」は、それぞれの実データとカード高を維持してぼかすが、`stats.paywall.weekly_report` CTAは2カードをまとめた領域の中央に1個だけ置く。両CTAは同じ遷移だったため個別表示を廃止する。
- Homeの行動コピーは「開くのをやめた / 開こうとした」へ統一し、週サマリーは自然な文章にする。
