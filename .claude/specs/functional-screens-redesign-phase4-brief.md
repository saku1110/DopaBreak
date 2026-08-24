# Phase 4 実装ブリーフ — 目標（GoalsView）＋ 編集シート（GoalEditorSheet）（2026-08-22・オーナー承認済み）

親仕様: `.claude/specs/functional-screens-redesign-proposal.md`。モック: `output/mockups/functional-screens-redesign-2026-08-22.html` §03。共通制約は Phase 1 ブリーフ §0 と同じ。

## 1. `GoalCategory` の見た目定義（Core または app 側の拡張）
`ios/DopaBreak/` に `GoalCategoryStyle.swift` を追加し、`GoalCategory` ごとに `symbolName` と `tint` を定義する（Core の列挙型は変えない）:
- study=`book.fill`／work=`briefcase.fill`／health=`figure.run`／sleep=`moon.stars.fill`／creative=`paintbrush.fill`／other=`star.fill`
- tint: study=accent（ライム）／work=`#8AB4FF`／health=`#F58FB4`／sleep=`#B9A6FF`／creative=`#FFB86B`／other=`secondaryText`。タイルの地は tint 14%、シンボルは tint。
- `GoalCategoryTile(category:, size: 44)` ビューを提供（角丸 size*0.27・continuous）。Phase 1 のホーム目標カードも**このタイルに差し替える**（Phase 1 で暫定実装したタイル描画があれば置換して重複を消す）。

## 2. GoalsView（`ios/DopaBreak/GoalsView.swift`）
上→下:
1. 大見出し「目標」＋右上 `EditButton`（既存）。
2. eyebrow 新規キー `goals.preview.title` = 開こうとした瞬間に見える。
3. **ロック画面プレビュー**: `LockScreenCheckView.swift` の `private struct LockScreenGoalPreview` を `internal` にして再利用（ファイル移動は不要、アクセス修飾子の変更のみ）。`titles` = 目標タイトル最大3件（ロック画面表示名 `lockScreenTitle ?? title`）、`cancelledCount` / `attemptCount` = 今日の実数。右下に `CharacterView(.relief, size 72)` を `offset(x: -8, y: 10)` で覗かせる（`overlay(alignment: .bottomTrailing)`・プレビューの角丸で `clipped`）。目標0件のときはプレビューを出さず、既存の空状態カード文言を維持。
4. **目標カード**（`List(.plain)` のまま）: 左 `GoalCategoryTile(size 44)`、中央に eyebrow（カテゴリ名＋先頭の目標だけ「 ・ ロック画面に表示中」= 新規キー `goals.badge.on_lock_screen`）＋タイトル 18pt bold 2行まで、右 chevron。並べ替え・削除・タップ編集の挙動は既存のまま。`pencil` アイコンは chevron に置き換える。
5. 「目標を追加」プライマリボタン（既存）＋ 直下に新規キー `goals.footer.unlimited` = 目標は何件でも追加できます（12pt secondary・中央）。※8/15承認「複数追加できることを書く」の継承。Free/Pro で件数上限がある場合は既存の上限文言を優先し、このフッターは上限なしのときだけ出す。

## 3. GoalEditorSheet（`ios/DopaBreak/GoalEditorSheet.swift`）
- `categoryBlock` の `Picker(.menu)` を **アイコン付きチップの横スクロール**（`GoalCategoryTile(size 24)` ＋ カテゴリ名、選択＝accent 1.5pt枠＋accent文字、未選択＝hairline）に置き換える。選択状態・保存ロジックは既存のまま。
- `inputBlock` の上に、入力中タイトルを反映した **ミニプレビュー**（`LockScreenGoalPreview(titles: [現在の入力 or プレースホルダ], ..., isDimmed: 入力が空)`）を置く。「ここで決めた一言が、開こうとした瞬間に表示されます」系の既存説明はプレビューのキャプションとして再利用。
- 文字数カウンタ・保存・削除・閉じるは変更しない。

## 4. ローカライズ
新規キー（ja/en/ko）: `goals.preview.title`、`goals.badge.on_lock_screen`（ロック画面に表示中）、`goals.footer.unlimited`（目標は何件でも追加できます）。カテゴリ名は既存キーを再利用（新規作成しない）。

## 5. スクリーンショット
`output/screenshots/redesign-phase4/goals.png`（目標3件）、`goal-editor.png`（編集シート・カテゴリ「学び」選択）。

## 6. 報告
Phase 1 と同じ形式。`LockScreenGoalPreview` のアクセス変更と、Phase 1 タイルの置換箇所を明記。

## 追記（2026-08-24）
文言は `.claude/specs/functional-screens-redesign-copy-sheet.md` の「Phase 2〜4・既存文言の書き換え」を正とする（本ブリーフ内の文言例と食い違う場合はコピーシートが勝つ。例: settings.status.title=いまの守り→「止める設定」、stats.apps.title=アプリ別→「アプリごと」、goals.preview.title=「開こうとした瞬間に見える画面」）。既存キーの rewrite 42件（英語見出しSUMMARY系の日本語化・「週次」廃止・「戻す」→「解除する」等）も該当Phaseの画面を触るタイミングで同時に適用する。gate系文言は docs/11_ui_copy.md §6c を正とし変更しない。
