# 介入統合画面の数字階層の是正（2026-08-28・レイアウトのみ）

対象: `ios/DopaBreak/InterventionFlowView.swift` の統合画面（旧S-02）。ロジック・遷移・キーは変えない。数字が折り返す見た目を直す。

## 問題
「今日開こうとした回数 16回」を1つの大きなboldテキストにしたため、数字が行末で「16」と「回」に割れて折り返す。数字が主役にならず読みにくい。

## 是正（表示のみ・数値バインドと文言キーは既存のまま）
- 数字を主役にした階層へ:
  - 大数字（72pt black rounded・monospacedDigit・`.dopaDisplayClamp()`）で `todayAttemptCountForDisplay`＋単位「回」を1行（折り返さない・`.lineLimit(1)`・`.minimumScaleFactor(0.6)`）
  - その直下に小さめ（15pt secondary）のラベル「今日開こうとした」——数字とラベルを別行に分ける
  - 対比行「開かずにやめた %lld回」はaccentで中サイズ（20pt bold）。「今日」の語はeyebrowで1度出ているので各行頭の重複「今日」を削り、上ラベル=「今日開こうとした」/下=「開かずにやめた」に整理（冗長な「今日…回数」の二重を解消）
- 文言キーは既存を流用しつつ、重複「今日…回数」を避けるため必要なら defaultValue のみ調整（`intervention.usage_summary.attempt_line`→ラベル用に「今日開こうとした」、`cancelled_line`→「開かずにやめた %lld回」）。**位置指定子 %lld は保持**。ja/en/ko 3言語とも整合
- eyebrow「今日のSNS」・目標セクション・「変える」・「次へ」は不変

## 検証
- `xcodebuild test`（アプリ全体）TEST SUCCEEDED／lint・audit exit 0
- 統合画面を再撮影 `output/verify/intervention-merged-v2.png`（数字が折り返さず主役・目標3件）
- 報告: 変更ファイルと3行要約と検証結果のみ。差分は貼らない
