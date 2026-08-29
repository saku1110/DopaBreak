# ロック画面テーマの2つの意味を名前で分ける（根本原因の是正）

- 元設計正本: `.claude/specs/lock-theme-picker-onboarding.md`（**§0の絶対制約は厳守**）
- 第3独立レビュー判定: SEND BACK（**正しさではなく根本原因が未着手のため**）

## なぜやるか

同じ不具合が3回出た。すべて原因は同じで、すべてテスト全通しの状態で潜んでいた。

| 回 | 症状 |
|---|---|
| F1 | 設定がガード後の値を表示し、追加したja/en/ko文言が3言語とも到達不能な死にコードになった |
| ND-1 | 非Observableなストアを`body`で直読みし、同値`@State`書き込みの重複排除で表示が固まった |
| 直近 | `onSelect` が生の選択テーマを親の`selectedLockTheme`へ書き、行が実機と違うテーマを表示した |

レビューの結論: **`selectedLockTheme` という同じ名前が、画面によって逆の意味を持っていることが唯一の原因。**

- `SettingsView` / `SettingsLockSurfaceView` では **ガード後（実機に出ているもの）**
- `HomeView` / `OnboardingFlow` では **保存値（ユーザーの選択）**

さらに `SettingsLockSurfaceView` の内部では両方が並んでおり、`selectedLockTheme` がガード後・`savedLockTheme` が選択という、直感と逆の対応になっている。3回目の不具合はまさにその行で起きた。

**現在の挙動は正しい。** レビューは横断監査で全描画経路がガード後の値、全意図経路が保存値であることを確認し、7つの回帰チェックもすべて通っている。これは再発防止のための改名であって、バグ修正ではない。

## R1 — 改名（挙動を1ミリも変えない）

### 1. ガード後の値を持つスロットを `liveLockTheme` へ改名

- `ios/DopaBreak/SettingsView.swift` の `@State`（宣言・`refreshSettingsState()`の代入・エントリ行の`value:`・`SettingsLockSurfaceView`へ渡す箇所）
- `ios/DopaBreak/SettingsLockSurfaceView.swift` の `@Binding`（宣言・`init`・`selectTheme` 内の代入）

### 2. 保存値を持つスロットを `savedLockTheme` へ改名

- `ios/DopaBreak/HomeView.swift` の `@State`（宣言・初期化・`onAppear`等の再同期・Proノート判定・ピッカーの`selectedTheme:`・選択ハンドラ内の代入）
- `ios/DopaBreak/OnboardingFlow.swift` の `@State`（宣言・初期化・各参照）

`SettingsLockSurfaceView` の既存 `savedLockTheme` はそのままでよい。改名後、同名は同義になる。

### 3. `AppModel` に名前付きアクセサを2つ追加

`ios/DopaBreak/AppContainer.swift` に置く。**`lockSurfaceState` の権利ガード本体には触らない。**

```swift
/// 実機のロック画面とウィジェットに出ているテーマ（権利ガード適用後）
var liveLockTheme: LockTheme { lockSurfaceState.theme }

/// ユーザーが選んで保存しているテーマ（無料でもProテーマになりうる）
var savedLockTheme: LockTheme { settingsStore.lockTheme }
```

以後、`live*` のスロットへは `model.liveLockTheme` からのみ、`saved*` のスロットへは `model.savedLockTheme` かタップされたテーマからのみ代入する。この規約により `liveLockTheme = selectedTheme` はその行だけを見て誤りと分かる。

### やらないこと

**専用の型（ラッパー構造体）は作らない。** `LockThemePreviewCard.theme` と `LockThemeLiveActivityView.theme` は両方の意味を正当に受け取るため、ラッパーは約15箇所で `.value` を強いるうえ `LiveLockTheme(selectedTheme)` を防げない。改名とアクセサで十分。

**親から`@Binding`を削って `model.lockSurfaceState.theme` を直読みする案も採らない。** `SettingsStore` が非Observableなため、選択直後に行が更新されなくなり、命名バグを鮮度バグに置き換えるだけになる。

## R2 — F1の修正を守るテストがゼロ（必須）

`SettingsLockThemePresentation.showsProNote`（`SettingsLockSurfaceView.swift:19`）は**どのテストからも参照されていない**。`savedTheme:` に渡す値をガード後の値へ戻すとF1がそのまま再発し、ja/en/ko文言が再び死ぬのに、スイートは緑のまま。

**追加するテスト**: 無料ユーザーで `SettingsLockSurfaceView` を実際にホストし、Proテーマをタップした後に**Proノートが描画されること**を検証する。`testFreeSettingsPickerSelectionKeepsRowGuardedWhileSavingAndRenderingProTheme` が実ビューをホストする良い前例なので同じ手法を使う。F1修正を戻すと落ちること。

## R3 — Home画面をホストするテストがゼロ（必須）

`HomeView` はテストで一度もホストされていない。Homeは `selectedLockTheme` が保存値を意味する側なので、ここを設定側に「揃える」誤修正をしても何も落ちない。ユーザーのPro選択が黙って外れ、Proノートも消える。

**追加するテスト**: 無料ユーザーで `HomeView` をホストし、ピッカーでProテーマを選んだあと次の4点を同時に検証する。

1. ピッカーの選択表示 = 選んだProテーマ
2. `lockScreenCard` のプレビュー = `.e1`（実機に出ているもの）
3. `settingsStore.lockTheme` = 選んだProテーマ
4. 立つペイウォールが `.homeThemeGate`

## R4 / R5 — 中身のないテストの是正（同じパスで対応）

- `MeasurementFoundationTests.swift` の `testDismissingThemePaywallDoesNotClearHandlerSavedTheme`: ローカル変数に `nil` を代入して `nil` を検証しているだけで、**どんな実装変更でも落ちない**。実際のペイウォール解除経路を通すよう書き直すか、価値がある最後の1アサーションだけを他テストへ統合して削除する
- `testLockThemePickerRendersEveryThemeInCaseOrder`: `renderedThemes` は `static let renderedThemes = LockTheme.allCases` なので第1アサーションは恒真。削除し、`count == 10` の行だけ残す

## 絶対に触らないこと

- `AppContainer.lockSurfaceState` の権利ガード本体
- `EntitlementGate.lockThemeAllowed`
- ペイウォールの出し分け（設定＝`settingsThemeGate` / ホーム＝`homeThemeGate` / オンボは非ゲート）
- 「保存が先・ペイウォール提示が後」の順序
- `LockThemePreviewCard` の修飾子順序（`.aspectRatio(393/160, .fit)` → `.frame(maxWidth: 393)`）
- 既存の表示文言

## 完了条件

- **改名によって挙動が1つも変わっていないこと**（差分は識別子とアクセサ追加とテスト追加のみ）
- generic iOS の全ターゲットで `BUILD SUCCEEDED`
- DopaBreakCore と DopaBreakTests が失敗0
- `scripts/lint-display-copy.py` と `scripts/audit-default-values.py` が exit 0
- R2・R3のテストが、それぞれ対応する修正を戻すと**落ちること**を変異検証で確認し、結果を報告に含めること
