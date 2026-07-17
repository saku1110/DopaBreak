# LifeFocus 設計・戦略ブラッシュアップ計画（Phase 0+1 / 収益最大化）

## Context

LifeFocus（SNS依存改善iOSアプリ・仮称）の既存設計・戦略を収益最大化とユーザー価値の観点でブラッシュアップする。実装はCodex委譲（次セッション）、本セッションはFableが設計とレビューに専念。入口は `docs/FABLE_BRIEF.md`（マスターブリーフ）。

**調査で確定した現状**（Explore調査 2026-07-02）:
- `output/mockups/lifefocus_v2/` に28枚のHTMLモック完成済み。オンボはブリーフの9画面を超えた拡張版（02b/02c 感情・損失クイズ、03_quiz_result 損失リビール「1日2.5h→年38日」、06b 科学的根拠、08b ペイウォール前損失サマリー）＝実質14ステップ
- トーン3案比較画像（A黒/Bミニマル/C明るい朝）は `output/mockups/tone_comparison/` に作成済み。`design/BUILD_SPEC_E1.md`（Dark Mono）が現行トークン
- **価格矛盾**: FABLE_BRIEF §9 = ¥780月/¥5,400年/¥12,800買切 vs モック22_paywall = ¥700月/¥2,400年/¥15,000買切
- doc06（旧GoalGate・目標入力あり7画面）とdoc07（目標入力なし7画面）が確定方針「目標ヒーロー軽量版・9画面」と未整合。doc01にもGoalGate残骸
- `.claude/tasks/` が未作成（CLAUDE.md必須要件）
- doc05のデータモデルは軽量版と整合済み（改訂ほぼ不要）

**オーナー決定事項**（AskUserQuestion回答 2026-07-02）:
1. **ICP**: 特定層でなく「SNS依存・ドーパミン中毒ユーザー全般」。依存が人生を無駄にしているという**損失回避の心理喚起**が軸。競合多数ゆえ訴求の差別化必須 → v2モックのクイズ型損失リビール路線と合致。既存メモリ: オーナー個人SNS資産は使わない
2. **正式名**: 候補出し→WebSearchで空き確認→推奨1つ提示（最終決定はオーナー）
3. **トーン**: 既存モック（E1 Dark Mono）vs Fableが最適と考える新提案モックの画像比較で決定
4. **スコープ**: Phase 0+1（整合＋設計成果物）まで。実装着手しない

---

## 作業計画

### Phase 0: 事実確認・整合（順に実行）

**T1. WebSearch事実確認**（設計判断の前提。並列サブエージェント可）
- App Review最新基準: 依存/メンタルヘルス表現・Screen Time API（FamilyControls配布許可要否含む）の現行制約
- 競合の現在地と価格: one sec / Opal / ScreenZen / Jomo 等の機能・価格・トライアル設計（¥2,400年 vs ¥5,400年の判断材料）
- ASO: 「スマホ依存」「スクリーンタイム」等の日本語キーワード競合状況
- 成果物: `docs/09_market_verification.md`（新規・確認日付き）

**T2. 正式アプリ名候補**
- 損失回避×依存改善の世界観に合う候補5つ生成 → App Store検索・ドメイン・商標DBの空きをWebSearchで確認 → 推奨1つ＋理由
- 成果物: `docs/09_market_verification.md` 内に名称セクション。**確定はオーナー承認後**（docs全体のリネームは確定後に一括）

**T3. 価格・マネタイズ再設計（収益最大化の中核）**
- `unit-economics` スキルで感度分析: ¥2,400年（モック・one sec対比+20%）vs ¥5,400年（ブリーフ）vs 中間。Trial→Paid率・LTV・広告CAC回収の観点で月/年/買切の推奨価格を決定
- 課金タイミング・Free/Pro境界・7日無料→損失レポート先出し導線の再検証（`paywall-optimization` 準拠）
- 成果物: `docs/01_business_design.md` §8改訂＋FABLE_BRIEF §9更新。価格変更時は `22_paywall.html` も更新

**T4. doc整合（確定版=「目標ヒーロー軽量版・v2オンボフロー」に統一）**
- v2モックの拡張オンボ（クイズ型損失リビール）を正式仕様に昇格（ICP回答=損失回避軸と合致するため）。ステップ数・Goal Setup位置（O-04）を全docで統一
- 改訂対象: `docs/06_screen_design.md`（全面改訂・28画面）/ `docs/01_business_design.md`（GoalGate残骸除去）/ `docs/07_onboarding_design_lifefocus.md`（目標入力O-04追加・拡張フロー反映）/ `docs/04_functional_requirements.md`（FR整合）/ `docs/03_product_spec.md`（注記整理）/ `docs/FABLE_BRIEF.md`（§6/§9/§10更新）/ `docs/README.md`
- 成果物: 改訂済みdocs＋差分メモ（`docs/CHANGELOG.md` 新規）

**T5. タスク管理ファイル整備**
- `.claude/tasks/current.md` / `backlog.md` / `completed.md` 新規作成（CLAUDE.mdフォーマット準拠、Phase 2実装のCodex分割単位(1)〜(13)をbacklogに登録）

### Phase 1: 設計成果物

**T6. トーン比較 → 確定**
- 代表3画面（介入Shield / Home / Paywall）で「既存E1 Dark Mono」vs「Fable最適新提案」のHTMLモックを作成・`render.sh` でPNG化 → 比較画像をオーナーに提示（AskUserQuestionで最終選択）
- 新提案は `taste-skill`/`frontend-design` 準拠・円形リング/神秘図形不使用の制約内で差別化
- 出力先: `output/mockups/tone_comparison_v2/`

**T7. オンボ・ペイウォール設計最終化**
- 確定オンボフローのActivation条件・分岐（権限拒否/アプリ未選択/Deep Focus確認）を doc07 に明文化（`onboarding-optimization` 準拠）
- T3の確定価格でペイウォール仕様を doc06/07 とモックに反映
- 日本語ディスプレイコピーはタイポグラフィ規則（句読点→改行・体言止め）でレビュー

**T8. データモデル・技術検証項目の最終確認**
- doc05 を確定スコープと突合（クイズ回答データの保存要否、StoreKit商品ID、Free/Pro entitlement境界）。差分のみ改訂
- 第1スプリント技術検証6項目（ブリーフ§7）をbacklog先頭に固定

### レビュー（各Phase末）
- Fableセルフレビュー: doc間クロス整合（画面数・価格・用語・禁止表現の全doc grep）
- Codexレビュー: `codex exec --skip-git-repo-check "Review docs/ and output/mockups/ changes in this session for internal contradictions, pricing inconsistencies, and App Review risk wording. Skip style."`（OPENAI_API_KEY未設定なら通知のみ）

---

## 変更対象ファイル（要点）

| ファイル | 変更 |
| --- | --- |
| docs/01_business_design.md | GoalGate除去・価格§8改訂 |
| docs/06_screen_design.md | 全面改訂（28画面・軽量目標版） |
| docs/07_onboarding_design_lifefocus.md | 拡張オンボ正式化・分岐明文化 |
| docs/04_functional_requirements.md | FR整合（目標FR・オンボFR） |
| docs/FABLE_BRIEF.md | §6/§9/§10更新 |
| docs/09_market_verification.md（新規） | 市場・審査・名称の事実確認 |
| docs/CHANGELOG.md（新規） | 差分メモ |
| .claude/tasks/*.md（新規） | タスク管理 |
| output/mockups/lifefocus_v2/22_paywall.html | 確定価格反映 |
| output/mockups/tone_comparison_v2/（新規） | トーン比較モック |

## 検証方法

1. **doc整合チェック**: 画面数・価格（¥表記）・「LifeFocus/GoalGate」「アファメーション/タスク/期限」等の禁止語を全docで grep し矛盾ゼロを確認
2. **モック検証**: `render.sh` でPNG再生成し、価格・コピーが確定値と一致することを目視確認
3. **チェックリスト**: FABLE_BRIEF §13 の★項目のうち設計段階で満たせるもの（E審査法務・C課金設計）を消し込み
4. **Codex独立レビュー**で矛盾・審査リスク表現の残存を検出

## スコープ外（次セッション）
- Phase 2実装（Xcodeプロジェクト作成〜Codex委譲）、LP/広告クリエイティブ制作、法務文書生成
