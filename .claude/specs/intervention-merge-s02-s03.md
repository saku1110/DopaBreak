# 介入フロー S-02+S-03 統合＋「目標を変える」ボタン（2026-08-28・オーナー指示）

## 背景（コードで確認済み）
- S-02 `usageSummaryScreen`（InterventionFlowView.swift:313-352）: 72ptの「N回」＋英語eyebrow「USAGE SUMMARY」＋「すでに開いています」＋目標カード（先頭1件）＋CTA「目標を思い出す」
- S-03 `goalReminderScreen`（:353-394）: 目標を全件列挙するだけ＋CTA「どうするか選ぶ」→ S-04理由へ
- 問題: S-02に既に目標が出ているのに、S-03でほぼ同じ目標を再掲するだけの中継ぎ。無駄な1タップ。「N回」が今日か累積か画面から不明（実体は今日）。英語eyebrowはオーナー恒久ルール違反
- 数値は `flow.todayAttemptCountForDisplay`（=`todayAttemptDisplayCount`・今回分+1込み）と `flow.todayCancelledCountForDisplay`（今日やめた回数）が InterventionFlowModel に既存。`flow.goals` も既存
- **理由選択S-04は残す**（`interventionStyle` で direct=時間選択へ直行／reflective=呼吸へ、と動線を分岐している。消さない）

## 変更（InterventionFlowView.swift のみ・InterventionFlowModel は最小追加のみ）
### 1. S-02 と S-03 を1画面に統合（`usageSummaryScreen` を作り替え、`goalReminderScreen` と `.goalReminder` stageを削除）
新1画面の構成（E1 Dark Mono・上から）:
- 日本語eyebrow（新キー `intervention.usage_summary.eyebrow_ja` 相当。既存 `intervention.usage_summary.eyebrow`="USAGE SUMMARY" は使わない）。文言: ja「今日のSNS」/ en「Today」/ ko「오늘」——短い名詞
- 見出し数字＋対比の2行:
  - `intervention.usage_summary.attempt_line`（新・位置指定子 `%lld`）ja「今日 %lld回 開こうとしています」/ en「%lld opens attempted today」/ ko「오늘 %lld번 열려고 했습니다」——`todayAttemptCountForDisplay`
  - `intervention.usage_summary.cancelled_line`（新・`%lld`）ja「開かずにやめた %lld回」/ en「%lld times you stopped」/ ko「%lld번 참았습니다」——`todayCancelledCountForDisplay`。数字は大きく、やめた回数はaccent色で肯定的に
- 区切り
- 目標セクション: 見出し ja「あなたの目標」（新キー日本語eyebrow・既存英語 `intervention.goal.eyebrow`="YOUR GOAL" は使わない）＋右に**「変える」ボタン**（新キー `intervention.goal.action.edit` ja「変える」/ en「Edit」/ ko「변경」・44pt・contentShape）。`flow.goals` を全件 `・`付き列挙（S-03の列挙様式を流用）。目標0件なら「開く目的を決める」1行＋「変える」を「決める」に
- 「変える」タップ: 既存 `GoalEditorSheet` を `.sheet` で提示（介入フローを閉じない）。保存後 `flow.goals` が最新化されること（`model.goals` は @Observable なので再描画される）。編集シートの提示状態は InterventionFlowView 内の `@State`
- CTA: `intervention.usage_summary.action.continue` の defaultValue を「目標を思い出す」→ **「次へ」**（ja）/ en「Next」/ ko「다음」に変更。押下で `flow.advanceToReasonSelection()`（現行の advanceToGoalReminder を廃し、S-04理由選択へ直接進む）

### 2. InterventionFlowModel.swift
- `enum InterventionStep`（or Stage）から `.goalReminder` を削除。`advanceToGoalReminder()` を削除し `advanceToReasonSelection()`（or 既存の理由選択へ進む遷移名）へ置換。エンジンのステップ列（breathing→usageSummary→goalReminder→reasonSelection→decision）から goalReminder を除く。**engine側の状態機械に goalReminder に相当する内部ステップがあれば併せて除去**（無ければView段の分岐のみ）
- 目標編集を介入中に行えるよう、必要なら `model.updateGoal`/`addGoal`/`replaceGoals`（既存）をそのまま使う。新APIは増やさない

### 3. 不変
- S-01呼吸／S-04理由（分岐込み）／S-05決定／win画面／gate（回数上限・alreadyOpen）／スナップショット用DEBUG init。理由のfast-path注記（decision画面）も不変

## テスト
- 既存 `.goalReminder` を参照するテストがあれば新遷移に更新（テストファイルの当該箇所のみ）。スナップショット系（CoreScreensSnapshotCapture等）に goalReminder ステップの撮影があれば統合画面へ変更
- 新規 `ios/DopaBreakTests/InterventionMergeCopyTests.swift`: 新キー（attempt_line/cancelled_line/goal.action.edit/eyebrow_ja/goal_ja・action.continue）が ja/en/ko translated、eyebrowに英語ベタ書きが無い（"USAGE SUMMARY"/"YOUR GOAL" を defaultValue に使っていない）ことを固定
- 純ロジックがあれば Core でテスト。UIのみなら App テストで可

## 検証
- `cd ios/Packages/DopaBreakCore && swift test`／`cd ios && xcodebuild test ... iPhone 16 Pro` TEST SUCCEEDED
- `python3 scripts/lint-display-copy.py`（読点・句点・英語eyebrow検出）/ `audit-default-values.py` exit 0
- シミュレータで統合画面を撮影 `output/verify/intervention-merged.png`（目標3件・今日の回数入り）
- 報告: 変更ファイル一覧＋3行要約＋検証結果。差分本文は貼らない
- 注意: InterventionFlowView.swift / InterventionFlowModel.swift に他作業の未コミット差分がある場合、S-02/S-03/理由遷移の該当箇所のみ触り無関係ハンクを整形しない

## 追加（ショートカットレビューの残指摘・統合と同時に適用）
- `InterventionFlowModel.swift` の `catalogChoice` ファクトリの `precondition(!targets.isEmpty)` を、`compactMap` で不正IDを除いた上で空なら `nil`/スキップに変更（破損スナップショット時のハードクラッシュ回避）。`.choose` ブランチ側で `SNSAppCatalog.contains` フィルタを掛けてから返すのでも可。実運用では到達不能だが防御目的
