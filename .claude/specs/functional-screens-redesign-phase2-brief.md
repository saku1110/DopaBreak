# Phase 2 実装ブリーフ — 記録（StatsView）（2026-08-22・オーナー承認済み）

親仕様: `.claude/specs/functional-screens-redesign-proposal.md`。モック: `output/mockups/functional-screens-redesign-2026-08-22.html` §02。共通制約は `functional-screens-redesign-phase1-brief.md` §0 と同じ（トークン維持・3言語・句読点なし・内部用語なし・検証コマンド全部）。Phase 1 で追加済みの共通部品 `AppIconView` / `AppIconStack` / `DayBars` を使う（`ios/DopaBreak/`）。

## 1. 画面構成（`ios/DopaBreak/StatsView.swift`）
`NavigationStack` と大見出しは維持し、タイトルは Free/Pro で変えず **「記録」**（新規キー `stats.title` = 記録）に統一する。上→下:

1. **期間チップ**（新規）: 「今週」「今日」「全期間」の3チップ（`Capsule`、選択＝accent文字＋1.5pt accent枠、未選択＝`backgroundRaised` 地＋hairline）。状態は `@State period`。Free（`entitlementGate.statsDays == 1`）は「今日」のみ有効で、「今週」「全期間」をタップすると既存の `paywallPlacement = .statsHistoryGate` を開く（チップ自体は表示し、Proバッジ小を添える）。キー: `stats.period.week` = 今週／`stats.period.today` = 今日／`stats.period.all` = 全期間。
2. **ヒーローカード**（`CardContainer`）: eyebrow「開かなかった割合」（既存文言を再利用）、左に率 56pt `.black .rounded`（`%` は22pt）、右に `DayBars(days:)`（高さ64）。その下に凡例（8pt角チップ: accent=開かなかった N／白25%=開いた N。既存 `legend` 文言を再利用）。右上に前週比: 既存 `comparisonRow` の文言（「先週より◯回少ない」等）を12pt `secondaryText` で、数値部分だけ accent。「今日」期間では DayBars の代わりに既存 `MetricBlock` 2列（開かなかった／開こうとした）を右側に置く。「全期間」では `allTimeSummary` のメトリクスを置く。
3. **アプリ別カード**（新規・Pro内容）: eyebrow 新規キー `stats.apps.title` = アプリ別。`StatsService.appRuleBreakdown(from:to:)` の ruleId を、既存経路で `SNSAppCatalogItem`（または `TargetRule.name`）に対応付けて行を作る: `AppIconView(size:30)` ＋ 名前（14pt semibold・幅74固定・1行省略）＋ 横バー（高さ6・角丸3、分母＝そのアプリの試行数・分子＝開かなかった数、塗り accent）＋ 右端「開かなかった/開こうとした」数（12pt monospaced、例 `18/23`）。開かなかった数は `attempts` と `cancelled` の両方が要るので、`StatsService` に `appRuleBreakdownDetailed(from:to:) -> [UUID: (attempts: Int, cancelled: Int)]` を**追加**してよい（Core に unit test を足す）。対応付けできない ruleId は `TargetRule.name` で表示、名前も無ければ行をスキップ。0件なら新規キー `stats.apps.empty` = 「まだアプリ別の記録がありません」。
4. **開いた後の気持ちカード**（新規・Pro内容）: eyebrow 新規キー `stats.reflection.title` = 開いた後の気持ち。`reflectionBreakdown(from:to:)` を `PostUseSatisfaction` の5値順に5列で表示: `CharacterView(satisfaction.characterExpression, size 40)`（該当件数>0 なら opacity 1、0 なら 0.45）＋ 件数 14pt `.black` ＋ ラベル 9.5pt `secondaryText`（既存の満足度ラベル文言を再利用、2行まで）。回答0件なら既存の「まだ記録がありません」系文言。
5. **開こうとした理由カード**（新規・Pro内容）: eyebrow 新規キー `stats.intent.title` = 開こうとした理由。`intentBreakdown(from:to:)` を件数降順でチップ（既存の理由ラベル文言＋割合 `%d%%`、`FlowLayout` で折返し）。
6. 既存 `behaviorSignal`（水平バー2本）は **ヒーローカードの凡例に統合して削除**。`allTimeSummary` は「全期間」チップ選択時のヒーローに統合。`lockedWeeklyDetail` / `lockedWeeklySummary` の鍵付きテキスト行は削除。

## 2. Free の見せ方（オーナー承認B）
Free では 3・4・5 のカードを **実データ（Freeでも当日分は計算できる）の上に `blur(radius: 10)`＋ `backgroundRaised` 60% のオーバーレイ**を重ね、中央に1行ボタン「毎週のふりかえりを見る」（既存キー `stats.paywall.weekly_report` の文言をそのまま使う。CTAに金額を入れない）を置く。ボタンは `paywallPlacement = .statsHistoryGate`。カードの高さはPro時と同じにして「何が見られるか」の形が見えるようにする。**データが0件でも**サンプルは生成しない（空状態文言をぼかす）。

## 3. ローカライズ
新規キー（ja/en/ko）: `stats.title`, `stats.period.week/today/all`, `stats.apps.title`, `stats.apps.empty`, `stats.reflection.title`, `stats.intent.title`, `stats.apps.ratio`（= `%lld/%lld`、書式のみ）。既存の文言は再利用を優先し、新規の詩的表現を足さない。

## 4. スクリーンショット
`output/screenshots/redesign-phase2/stats-pro.png`（Pro・今週）と `stats-free.png`（Free・今日・ぼかし表示）。撮影ハーネスは Phase 1 と同じ。

## 5. 報告
Phase 1 と同じ形式。`StatsService` に追加したAPIとテスト名を明記。

## 追記（2026-08-24）
文言は `.claude/specs/functional-screens-redesign-copy-sheet.md` の「Phase 2〜4・既存文言の書き換え」を正とする（本ブリーフ内の文言例と食い違う場合はコピーシートが勝つ。例: settings.status.title=いまの守り→「止める設定」、stats.apps.title=アプリ別→「アプリごと」、goals.preview.title=「開こうとした瞬間に見える画面」）。既存キーの rewrite 42件（英語見出しSUMMARY系の日本語化・「週次」廃止・「戻す」→「解除する」等）も該当Phaseの画面を触るタイミングで同時に適用する。gate系文言は docs/11_ui_copy.md §6c を正とし変更しない。

## オーナー訂正（2026-08-24・後勝ち）

- 行動コピーはコピーシートの「開くのをやめた / 開こうとした」を使う。
- FreeのProカード3枚は個別に同一CTAを置かず、3枚をまとめたロック領域に `stats.paywall.weekly_report` CTAを1個だけ置く。
- Home用の `DayBars` はライム1系列になったため、Statsで「開いた」比較も必要ならStats専用の凡例付きチャートとして実装し、Homeへグレー系列を戻さない。
