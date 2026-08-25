# モーション改修（60fps照合結果の実装）— 2026-08-25

オーナー承認: **オーバーシュート（跳ね）を許可**（2026-08-25）。照合の根拠は `.claude/specs/design-decisions.md` の
「2026-08-25 — 60fps MCP モーション改修候補の照合」を参照。

## 全ステップ共通の制約（違反は差し戻し）

- **コミットしない。** 実装と検証まで。コミット可否はオーナーが判断する
- **触ってはいけないファイル**（同じ作業ツリーで別セッションが作業中・未コミット）:
  `SettingsView.swift`、`Settings*.swift` 5ファイル、`GoalsView.swift`、`GoalCategoryStyle.swift`、
  `HomeView.swift`、`LockScreenCheckView.swift`、`BreathingCharacterView.swift`、
  `scripts/generate-appstore-screenshots.py`、`scripts/generate-appstore-screenshots-v2.py`
- **表示文言を変えない。** 本改修は動きだけを扱う。新規の文言キーは作らない
- **撮影シード値を変えない**（2.3時間/日・週6時間0分・連続7日・週36回）
- 省略・TODO・スタブ禁止
- 各ステップ完了時の検証: `xcodebuild` 成功／DopaBreakCore・DopaBreakTests 失敗0
- 報告は変更ファイル一覧と3行要約のみ。差分本文を貼らない

## Reduce Motion（全ステップ必須）

対象の各Viewに `@Environment(\.accessibilityReduceMotion) private var reduceMotion` を追加する。
オンのとき scale・morph・棒高補間・slide を止め、opacity と色の変化だけに縮退させる。
アニメーション指定は `reduceMotion ? nil : <token>` の形にする。ハプティクスは Reduce Motion では止めない。

---

## Step A: モーショントークンとハプティクスの土台

### A-1. `ios/DopaBreak/DesignTokens.swift` の `enum DopaMotion` に2つ追加する

既存4つ（control / transition / momentum / celebrate）は**値も用途も変更しない**。以下を追記する。

```
/// 選択マーカーなど、押した指へ即座に返す小さな跳ね。
static let select = Animation.spring(response: 0.25, dampingFraction: 0.72)
/// グラフ・バッジなど、同じ面が形を変える遷移。
static let morph = Animation.spring(response: 0.45, dampingFraction: 0.72)
```

`celebrate` は達成の瞬間だけに使う既存規律を維持する。`select` / `morph` を祝福用途に使わない。

### A-2. `ios/DopaBreak/HapticFeedback.swift`（新規）

アプリには呼吸用の `BreathHapticsController`（CoreHaptics）しかなく、選択・成功の共通経路がない。
UIKit のジェネレータを包む最小のヘルパーを新設する。

- `@MainActor enum HapticFeedback`
- `static func selection()` → `UISelectionFeedbackGenerator` の `selectionChanged()`
- `static func success()` → `UINotificationFeedbackGenerator` の `notificationOccurred(.success)`
- ジェネレータは都度生成でよいが、`prepare()` を呼んでから発火させる
- シミュレータや非対応端末で落ちないこと。テストターゲットからの実行も落とさない

---

## Step B: 止めるアプリの選択（`ios/DopaBreak/TargetAppGrid.swift`）

参照: 60fps `mymind-spaces-color-picker`（リング移動＋中央の丸のscale pop）と
`cred-interest-selection`（枠線は色の移り変わりのみで跳ねない）。

現状は枠線の色・太さと `selectionIndicator` の丸が即時に切り替わり、押下scaleだけが動く。

- `selectionIndicator` の丸に `DopaMotion.select` を当てる。塗り（`fill`）と `scaleEffect` を
  `isSelected` で補間する。未選択1.0 → 選択時に一度わずかに大きくなって戻る pop とする
- **チェックマークを置かない。** 承認済みの「ライム塗りの丸」を維持する
- 枠線（`strokeBorder` の色と `lineWidth`）は跳ねさせない。`DopaMotion.control` で色と太さを補間する
- 選択・解除の両方で `HapticFeedback.selection()` を返す。発火は `onToggle` を呼ぶ経路に置く
- カードの再配置・複数項目の連続stagger・押下scaleの値は変更しない
- Reduce Motion時は scale を止め、塗りと枠線の色変化だけ残す

---

## Step C: 記録の期間切替（`ios/DopaBreak/StatsView.swift`・`ios/DopaBreak/DayBars.swift`）

参照: 60fps `go-club-steps-graph-switch-animation`（週→月で棒がmorphし数値がtickerで転がる）と
`flighty-stats-by-year`（morphできない中身は crossfade）。

現状は `selectPeriod` が `period` だけを `withAnimation(DopaMotion.control)` で包み、
`dashboard` の再代入は `.onChange(of: period)` 経由の `reloadDashboard()` で走るため同じトランザクションに入らない。
`periodVisualization` は週・今日・全期間で別Viewを返すが transition 指定がない。

- **`period` と `dashboard` の更新を1つのトランザクションに束ねる。**
  `selectPeriod` の中で期間を変え、そのまま同じ `withAnimation` 内で再読込結果を反映する。
  `.onChange(of: period)` からの二重反映が起きないようにする。
  他の呼び出し元（`.task` / 復帰時 / 通知）からの `reloadDashboard()` は今の挙動を保つ
- 束ねるアニメーションは `DopaMotion.morph`
- `DayBars` の棒高を補間する。`.animation(reduceMotion ? nil : DopaMotion.morph, value: <棒の高さの元になる値>)` を
  棒側に当て、0本日の中立ドット表示の扱いは現状のまま変えない
- `periodVisualization` の3分岐には crossfade を入れる。`.transition(.opacity)` と
  `.easeOut(duration: 0.25)` 相当で、内容が入れ替わる印象にする。形の違うViewを無理にmorphさせない
- 数値の transition は既存の指定があればそれを使う。無ければ `.contentTransition(.numericText())` を当てる
- **維持する**: カード形状、実データ、Freeのぼかし、空状態（`stats.empty.*`）、週だけに出す凡例、
  Proゲート（`isStatsHistoryLocked` の分岐と `paywallPlacement`）
- Reduce Motion時は棒高補間とmorphを止め、crossfadeだけ残す

---

## Step D: ロック画面確認（`ios/DopaBreak/LockScreenCheckView.swift`）

### 前提（2026-08-25 15:48 時点・先行2作業は完了済み）

`test-project-ce`（Phase 4）と `test-project-a4`（サイドボタン位置・英語eyebrow削除）は編集を終えている。
**着手前に必ず現行コードを読み直すこと。** 8/24時点の構造から次が変わっている。

- `.waiting` が独立したcaseになり、stagger は title 0 / lead 1 / `verificationSteps` 2 / `goalPreview` 3 / `permissionNote` 4
- `goalPreview` は全phaseに出る。`.confirmed` は `goalPreview` 2 と `visibleBadge` 3
- 手順1カードと `SideButtonDeviceIllustration` は削除済み。collapse＋fadeの対象は `verificationSteps` 1枚
- 新規 `SideButtonEdgeMarker`（`LockScreenCheckView.swift:513` 定義）が `phase == .waiting` のときだけ overlay で出る。
  `LockScreenCheckSheet` と `OnboardingFlow.lockScreenCheckContent` の両方に付いている
- `phase` の状態機械・`start()` / `refreshStatus()` / `LockScreenCheckAction` ・`blocked` / `noGoal` 分岐は無変更

参照: 60fps `smallcase-wealth-office-setup-check-animation`
（説明文が fade out と down → badge が spring scale up → 成功文が fade in と up・stagger 0.09）。

### やること

- `phase` の代入（`LockScreenCheckView.swift:267` と `:278`）を `withAnimation(reduceMotion ? nil : DopaMotion.morph)` で包む
- `verificationSteps` は collapse と fade で退場、`visibleBadge` は `DopaMotion.select` の scale pop で登場
- プレビューの減光（`isDimmed: !phase.isPresenting`・`:153`、適用は `:389` の `.opacity(isDimmed ? 0.5 : 1)`）を
  同じトランザクションで 0.5 → 1.0 へ補間する
- `SideButtonEdgeMarker` は同じトランザクションに乗る。`.transition(.opacity)` を与え、
  Reduce Motion では即時に出入りさせる。**両方の設置箇所へ同じ扱いを入れる**
- `.confirmed` へ確定した瞬間だけ `HapticFeedback.success()` を1回返す。
  `refreshStatus()` は復帰のたびに走るため、**すでに `.confirmed` なら再発火させない**（遷移の瞬間だけ）
- 画面全体の祝福演出・粒子は入れない

### 維持する

`Self.phase(for:didReturnFromLockScreen:current:)` の状態機械、非同期の再判定、`.onboardingStagger` の現行index順、
`blocked` / `noGoal` の分岐、`SideButtonEdgeMarker` の表示条件（`phase == .waiting`）とジオメトリ計算。
Reduce Motion では scale・collapse・morph を止め、opacity と色だけに縮退させる。
