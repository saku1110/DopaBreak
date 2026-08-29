# 介入フロー順序反転: 呼吸を無条件の先頭へ（2026-08-29 オーナー承認）

正本: `docs/12_hybrid_intervention.md` §2（2026-08-29決定ブロック）。本ファイルはその実装仕様。

## 決定内容

旧: 起動 → 理由選択（S-01）→ direct系（仕事/調べ物/連絡/投稿）は呼吸なしで即開く／reflective系（暇つぶし/なんとなく）は呼吸→回数＋目標＋判断。
新: **起動 → 呼吸（全員必須・3/5/8秒設定値）→ 理由選択 → direct系は即開く（gateTokenなら時間選択へ）／reflective系は回数＋目標＋判断へ**。

理由: 「仕事」タップが呼吸の免除券になっており、正直に答えるほど画面が増える逆インセンティブだった。呼吸を無条件化し、回答は「呼吸後の扱い」だけを変える。

## 新ステート遷移（InterventionFlowModel.stage）

両経路（catalog / gateToken）共通:

1. `start()` → エンジン準備・todayAttemptDisplayCount確定（現行どおり）→ **`stage = .breathing`**（beginBreathing()を無条件で開始）
2. 呼吸完了 → **`stage = .reasonSelection`**（現行の「呼吸完了→usageSummary」を変更）
3. `selectReason(_:)`:
   - `.direct`（work/research/communication/posting）→ `proceedToOpenOrDurationSelection()`（現行どおり: catalogは開く、gateTokenはdurationSelection）
   - `.reflective`（boredom/unconscious）→ **`stage = .usageSummary`**（呼吸は開始しない。もう済んでいる）
4. `.usageSummary` 以降（chooseOpen / chooseCancel / win / opening / limit）は現行どおり変更なし

## 実装要件

1. **InterventionFlowModel.swift**
   - `start()` の到達ステージを `.reasonSelection` から呼吸開始に変更。呼吸中断→再`start()`時のresetToIdle・generation制御など既存の再入ガードの意図を新順序で維持する
   - `selectReason` の分岐から `beginBreathing()` 呼び出しを除去し、reflectiveは直接 `.usageSummary` へ
   - エンジンステップ整合: 理由画面が表示されている間に `currentStep() == .intentSelection` が成り立つこと。`beginIntentSelection()` は呼吸完了時（reasonSelection遷移時）に呼ぶのが望ましいが、エンジン側の制約（タイムアウト・ステップ検証等）で不都合があれば現行どおりstart時に呼んでよい。どちらにしたかと理由を報告すること
   - `recordIntent` → `advanceStep`（intentSelection→decision）の記録順序は現行を維持
2. **InterventionFlowView.swift**
   - 呼吸画面が最初に表示される。呼吸画面内に `selectedReason` 前提の表示があれば依存を外す（新順序では呼吸中はnil）
   - 理由選択・usageSummary・勝ち画面・durationSelection・opening の意匠は変更しない
   - 呼吸にスキップ導線を追加しない（既存にもないはず。あれば除去）
3. **テスト（ios/DopaBreakTests/MeasurementFoundationTests.swift 860-915付近ほか）**
   - 現行順序（start→reasonSelection、selectReason→breathing→usageSummary）を検証しているテストを新順序に書き換える
   - 追加テスト: ①`start()`直後が`.breathing`である ②呼吸完了後に`.reasonSelection`へ遷移する ③directな理由（.work等）を選んでも呼吸を経ている（＝呼吸完了前にreasonSelectionへ到達できない） ④reflectiveな理由選択で`.usageSummary`へ直行する
4. **スナップショット（CoreScreensSnapshotCapture.swift）**
   - `selectedReason` を渡して画面を組み立てている箇所があれば、新順序でも各画面（呼吸・理由・summary）を撮れるように調整
5. **文言**: 新規文言なし想定。呼吸画面に理由前提の文言が既存であれば中立文言へ（xcstrings既存キーの流用可否を報告）
6. **触らないもの**: InterventionEngine（DopaBreakCore）のpublic API互換を優先。統計・記録スキーマ・シールド関連・PostUseReflectionは変更しない
7. 省略・TODO禁止。`xcodebuild`でビルドと関連テストを通すこと

## 検収

- 全テストパス
- 実機/シミュレータ: カタログ経路とgateToken経路の両方で「呼吸→理由」の順になり、work選択でも呼吸が出る
