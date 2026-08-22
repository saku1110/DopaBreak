# O-03r 人生グリッド（オーナー指示 2026-08-22「人生グリッド（O-03r）だけ入れて」）

## 目的
クイズ結果画面（`quizResultContent` in `ios/DopaBreak/OnboardingFlow.swift`）の最終行「このままなら50年で 人生の約X年」を、数字だけでなく**面積**で見せる。50年を50マスで並べ、SNSに消える年数分を塗る。危機感を「数字を読む」から「面積を見る」に変える。

## 表示（ja 例・バケット2〜4時間＝5.2年）
```
※1日約2.5時間の想定にもとづく推計値です。      ← 既存 disclaimer（据え置き）
このままなら50年で 人生の約5.2年               ← 既存 lifetime 行（据え置き・文言変更なし）
[■■■■■▪□□□□]
[□□□□□□□□□□]
[□□□□□□□□□□]                               ← 新規 LifeGrid（10列×5行＝50マス）
[□□□□□□□□□□]
[□□□□□□□□□□]
1マス ＝ 1年　塗り ＝ SNSに消える時間            ← 新規 凡例（小）
```
- 並び順: disclaimer → lifetime行 → グリッド → 凡例。`.onboardingStagger` は lifetime行=4（既存）、グリッド=5、凡例=6
- 画面内キャラは既存1体のまま（グリッドにキャラを入れない）

## グリッド仕様
- 50マス固定（`LossEstimator.lifetimeHorizonYears`）。10列×5行。左上から行優先で1マス=1年
- 塗る量 = `LossEstimator.lifetimeYears(fromYearlyDays:)`（切り捨て済み・例5.2）。満マス=整数部（5）、端数マス=小数部を**そのマスの横幅比率**で左から塗る（0.2→20%）。切り上げは絶対にしない
- Coreに純関数を追加: `LossEstimator.lifeGridFill(lifetimeYears: Double) -> (fullCells: Int, partialFraction: Double)`（`fullCells` は 0...50 にクランプ、`partialFraction` は 0..<1。`lifetimeYears` が50以上なら (50, 0)）。DopaBreakCoreTests に 0 / 1.5 / 3.1 / 5.2 / 10.4 / 13.5 / 50 / 60 のケースを追加
- 見た目: マスは角丸（`RoundedRectangle(cornerRadius: 4, style: .continuous)`）、間隔6pt、横幅は画面幅から算出（`GeometryReader` か固定の最大幅320ptで10等分。Dynamic Typeの影響を受けない）。塗りマス＝`DesignTokens.accent`、未塗り＝`DesignTokens.hairline` 相当の薄い面（既存トークンのみ使用。新色を作らない）
- アニメーション: lifetime行が出た後、左上から1マスずつ順に点灯（1マス約25ms、5.2年なら約150ms＋端数）。`accessibilityReduceMotion` なら即時表示（`OnboardingMotion.swift` の既存パターンに倣う）。`OnboardingCountUp` のカウントアップ完了を待たなくてよいが、stagger 5 の出現後に開始する
- アクセシビリティ: グリッド全体を1要素にし、ラベルは lifetime 行と同じ文言（VoiceOverで二重読みにならないよう、個々のマスは `accessibilityHidden`）。凡例は通常テキスト
- 凡例テキスト（新キー `onboarding.result.life_grid.legend`・読点句点なし・中央揃え・`SmallLabel` または `centeredLead` の小サイズ）:
  - ja: `1マス ＝ 1年　塗り ＝ SNSに消える時間`
  - en: `1 square = 1 year   Filled = time lost to social media`
  - ko: `한 칸 = 1년   채워진 칸 = SNS에 사라지는 시간`
  （xcstrings に3言語を追加。`extractionState: manual`、`comment: Screen: Onboarding quiz result`）

## 変更しないもの
- 既存の文言・キー（hero/3年/disclaimer/lifetime）、CharacterSwapSequence、`LossEstimator` の既存API、他のオンボ画面
- 診断的表現・効果の断定は追加しない（docs/09 §3）

## ドキュメント
- `docs/07_onboarding_design_lifefocus.md` の O-03r 節に「人生グリッド（2026-08-22 オーナー指示）」を追記（表示・算出・切り捨て・凡例3言語）
- `.claude/specs/design-decisions.md` 末尾に決定と理由（数字より面積／既存の科学画面は増やさない判断）を追記

## 検証（報告に必ず含める）
- `cd ios/Packages/DopaBreakCore && swift test` 全通過（新規テスト含む件数）
- `cd ios && xcodegen generate` → 署名なしgeneric iOS Simulator向け `xcodebuild build` が `BUILD SUCCEEDED`
- `ios/DopaBreakTests/OnboardingMotionCapture.swift` の `03-quiz-result` ステージを既存手順で実行し、出力PNGのパスを報告（実行不可なら理由）。可能なら ja で1枚、グリッドが5.2年塗りで見えること
- xcstrings JSON整合・新キー3言語充足、`python3 scripts/lint-display-copy.py` exit 0、`git diff --check`

## 2026-08-22 是正パス（Fable受け入れ前レビュー反映・Codex実装）
レビュー（Opus5）と実画面目視の結果、以下を修正する。
1. **ファーストビュー内に収める（最優先）**: 現状グリッド＋凡例はPro Maxでも約170ptスクロールしないと見えない。`quizResultContent` 内だけで、ブロック間spacing（24→16等）・キャラ高さ（152→120pt程度まで可）・ヒーロー塊の上下余白を詰め、**iPhone 16（6.1"・393×852pt）とiPhone 16 Pro Max の両方で、スクロール位置0のままグリッド50マス＋凡例がCTAに隠れず全部見える**こと。他画面のspacing・共有コンポーネントは触らない。どうしても6.1"に入らない場合のみ、キャラを更に縮める（グリッドのマスは縮めない）
2. **点灯アニメの発火条件**: view生成＋固定620msではなく、グリッドの矩形が可視領域（`.scrollView` 座標空間・iOS17）に50%以上入った時点で開始（初回のみ）。1の修正後は通常ファーストビューで即発火するが、小型端末のフォールバックとして残す
3. **Reduce Motion**: 初期stateを目標値で初期化し、空グリッドが1フレームも出ないようにする
4. `.task(id:)` に fill値を渡し、値変化時に追従
5. **アクセシビリティ**: lifetime行の `accessibilityHidden` を外す（元に戻す）。グリッドはlifetime行の視覚表現なので**グリッド全体を `accessibilityHidden(true)`**、凡例は通常テキスト（二重読み回避はこの方法で）
6. **撮影ハーネス**: `03-quiz-result` は `ONB_STAGE_BEGIN` を先に出してから静止画を撮る。静止画はスクロール位置0で撮る（1の修正でスクロール不要になる）。Pro Max と 6.1"（iPhone 16 Simulatorが無ければ利用可能な6.1"機）で1枚ずつ出力し、パスを報告
検証は元仕様と同じ＋2端末のPNG。
