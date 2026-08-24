# 機能画面リデザイン提案（2026-08-22・承認待ち）

Artifact（Before/Afterモック・根拠・判断事項）: https://claude.ai/code/artifact/57d14808-8a03-483e-97b3-013e3b81f8af
ソース: scratchpad `dopabreak-screens-redesign.html`（template.html + build.py で生成）

## 4つの打ち手
1. SNSは常にアイコンで見せる — 新部品 `AppIconView`: カタログ8アプリ＝ブランド色タイル＋SFグリフ（自前描画・44〜60pt可）／Screen Timeトークン＝`Label(token).labelStyle(.iconOnly)` を30pt前後に限定（低解像度・色スキーム不可・重い）。ロゴ画像は同梱しない。
2. Dopaが毎画面で状態を語る — `DopaRing`（BreathingCharacterViewのリングを一般化）。ホーム=ヒーロー、記録=満足度5表情、目標=LockScreenGoalPreview右下、設定=ステータスカードの小リング。
3. 数字に形 — `DayBars`（7本）、アプリ別バー（appRuleBreakdown）、理由チップ（intentBreakdown）、満足度（reflectionBreakdown）、前週比（comparisonRow）。新しい計測は不要。
4. 設定は「いまの守り」から — ステータスカード → `ModeCard` 3枚（標準/Deep Focus/夜だけ強化）→ 止めるアプリ（アイコンスタック）・一呼吸の長さ（チップ）・自動化 → 起床就寝24hタイムライン → 通知/ロック画面/Pro は入口行（子画面）。ロジック・保存先は不変。

## 画面別
- ホーム: リング(今日の率)＋Dopa → 12回/今日 開かなかった → 守っているアプリ行（アイコン＋ライム点＋「一呼吸 3秒」）→ 週7本バー → 目標カード（カテゴリタイル）。文言は8/15承認の事実コピーのまま。
- 記録: 期間チップ（今週/今日/全期間、Freeは今日のみ）→ 率＋日別バー＋前週比 → アプリ別 → 開いた後の気持ち（5表情）→ 理由チップ。FreeのProカードは「ぼかし＋解放ボタン」（判断B）。
- 目標: 先頭にLockScreenGoalPreview（Dopa覗き）→ カテゴリタイル付きカード → 追加CTA＋「目標は何件でも追加できます」。GoalCategoryに色・SFシンボル（book/briefcase/figure.run/moon.stars/paintbrush/star）を追加。編集シートのカテゴリはアイコン付きチップ。
- 設定: 上記4。
- 止めるアプリ: 2列カード（アイコン50〜60pt＋名前＋今週◯回＋選択リング）＋「ほかのアプリを選ぶ（スクリーンタイム）」。

## オーナー判断待ち
A トークンなしアプリのアイコン（推奨: ブランド色タイル） B Freeの記録でProカードをぼかし表示（推奨: する） C 設定トップの範囲（推奨: 子画面分割）

## 実装順（承認後）
Phase1 AppIconView＋止めるアプリ＋ホーム → Phase2 記録 → Phase3 設定 → Phase4 目標＋編集シート。各Phase末にシミュレータ実機スクショをBefore/Afterで提示し承認を得る。実装=Opus5サブエージェント（Codex上限中）、レビュー=別Opus5。
