# ロック画面テーマピッカー 第2独立レビュー指摘の是正（差し戻し・第3ラウンド）

- 元設計正本: `.claude/specs/lock-theme-picker-onboarding.md`（**§0の絶対制約は引き続き厳守**）
- 第1ラウンド指示書: `.claude/specs/lock-theme-picker-review-fixes.md`
- 第2レビュー判定: **SEND BACK**

## 第2レビューで「直っている」と確認された項目（再度触らないこと）

F2 / F3 / F4 / F5 / F6 / F7 / F8 はすべて FIXED。§0の7制約も全て無傷。ビルド成功、Core 526件・iOS 233件（14 skip）失敗0、両監査 exit 0 も再現済み。

**特にF3の修飾子順序は現状が正しい。** 実測で、現在の `.aspectRatio(...)` → `.frame(maxWidth: 393)` の順だけが700pt/1024ptで 393×160 を返す。第1ラウンド指示書が書いた逆順（frame→aspectRatio）は高さ285ptのレターボックスが残る。**指示書の記述より実装が正しかったので、現状を維持すること。**

---

## ND-1 — 🔴 ブロッカー: 設定のピッカーが無料ユーザーの選択に反応しない

F1の修正で `SettingsLockSurfaceView` が `settingsStore.lockTheme` を **`body` の中で直接読む**ようになった（`:66-69` と `:81-84`）。しかし `SettingsStore` は非Observable（`SettingsStore.swift:3` はただの `final class`。`AppModel` 内で `private let` 保持のため `@Observable` マクロの計装対象外）。

`@Binding var selectedLockTheme`（`:36`）は `:149` で**書かれるだけで `body` から読まれていない**。つまり再描画のきっかけは、親の `@State` が値として変化することだけ。

`selectedLockTheme` は**ガード後**の値、ピッカーが出すのは**保存**値。したがって、保存値がProテーマの無料ユーザーが唯一選べる「黒とライム」(`.e1`) をタップすると、書き込みは `.e1 → .e1` の同値書き込みになる。SwiftUIは同値の `@State` 書き込みを重複排除するため再描画が起きない。

レビューの実測:

```
初期:                        parentBody=1 childBody=1 childRead=kpop
同値書き込み(.e1をタップ):    parentBody 1->1  childBody 1->1  childRead=kpop  store=e1  ← 表示が古い
異値書き込み(gamingをタップ): parentBody 1->2  childBody 1->2  childRead=gaming        ← 正常
```

**実害**: 設定は黙って `.e1` に変わっているのに、チェックはProテーマに付いたまま、「Proにすると このデザインになります」も出たまま。画面に入り直すまで直らない。オンボでProテーマを選べるようにしたことで、この状態が常態になる。解約直後のユーザーでも起きる。

**`HomeView` にはこのバグが無い。** `@State` が**保存値**を写している（`HomeView.swift:209/253/793`）。こちらが正しいパターン。

さらに、`.claude/specs/design-decisions.md:1137` に自分たちで書いた制約「設定の選択枠…は非Observableな`SettingsStore`だけへ依存せずSwiftUI Stateにも同期する」に、今回のF1修正が違反している。

**修正**: `SettingsLockSurfaceView` の内部に、`settingsStore.lockTheme` を初期値とする `@State`（保存テーマ用）を持ち、`selectTheme` で更新する。`HomeView` と同じ形にそろえる。`body` から非Observableなストアを直接読まないこと。

---

## ND-1b — 🔴 ブロッカー: F1の回帰テストが恒真で、何も守っていない

`testSettingsPickerUsesSavedLockedThemeAndShowsProNote`（`MeasurementFoundationTests.swift:108-123`）:

- 第1のアサーションは `SettingsLockThemePresentation.selectedTheme(savedTheme:)`（`SettingsLockSurfaceView.swift:20-22`）を検証しているが、これは**恒等関数**。`identity(x) == x` は何をしても落ちない
- 第2のアサーション（free+`.kpop` で `showsProNote` が true）は、`!isThemeAllowed(theme)` と `theme != .e1` を**区別できない**

レビューが実際に確認: **`SettingsLockSurfaceView.swift:66-84` をF1修正前の `selectedLockTheme` に戻しても、このテストは緑のまま。**

**修正**: 恒等ヘルパーへのアサーションを廃止し、**実際のビューを描画して**検証するテストへ置き換える。`testLockThemePreviewCardAtWideWidthHasNoLetterboxedRowHeight`（`:141-172`）が `UIHostingController` を実ウィンドウで回す良い前例なので、同じ手法を使う。要求する性質:

1. free かつ保存値が `.kpop` のとき、ピッカーの選択表示が `.kpop` に付くこと。**F1修正を戻すと落ちること**
2. **ND-1の再現を封じる**: 保存値が `.kpop`・ガード後が `.e1` の状態から `.e1` を選択したとき、表示上の選択が `.e1` に追随すること（同値書き込みで固まらないこと）

---

## ND-2 — 🟠 Live Activityのマスタースイッチが約1,600pt下に埋もれた

第1ラウンドで私が「固定332ptビューポートを廃止せよ」と指示した副作用。設定カードに10枚が実寸で並ぶため、440pt機で1枚約150pt × 10 = **約1,600pt** スクロールしないと「ロック画面で確かめる」（`:96`）とLive Activityトグル（`:111`）に到達しない。画面2つ分。

機能そのもののオン/オフがピッカーより下にあるのは順序として誤り。トグルがオフならピッカーは無意味なので、論理的にも先に来るべき。

**修正**: `SettingsLockSurfaceView` で「ロック画面で確かめる」行とLive Activityトグル行を**ピッカーより上**へ移動する。ピッカーはカード内の最後に置く。行の実装・文言・トグルの挙動は変更しない。

---

## ND-4 — 🟡 タップ領域の修飾子が効いていない

`LockThemePickerView.swift:51-52` の `.frame(minHeight: 44)` と `.contentShape(Rectangle())` が `Button` の**外側**に付いているため、ボタンのヒット領域を広げていない。iPhoneではカードが130pt以上あるので無害だが、iPadではカード（393pt）の外側の行内をタップしても何も起きない。

**修正**: 両修飾子を `Button` の `label` の内側（＝カード側）へ移すか、`Button` 自身に `.contentShape` を当てて行全体を押せるようにする。

---

## 対応しないもの（記録のみ・コードを変えない）

- **ND-3**（iPadでカードが中央、見出しが左寄せ）: `scale = min(1, w/393)` に由来する設計正本 §1.2 どおりの挙動
- **ND-5**（ロック済みテーマをタップしてペイウォールへ行くと、選択が記憶されず購入後に選び直しになる）: 設計正本の「現在の挙動を維持」どおりで既存仕様。**オーナー判断待ちのため今回は変更しない**
- `testLockThemePickerRendersEveryThemeInCaseOrder` と `testPrePaywallSummaryOnlyShowsCardForProThemeSelection` の弱さ: 今回の要求範囲外

## 完了条件

- generic iOS の全ターゲットで `BUILD SUCCEEDED`
- DopaBreakCore と DopaBreakTests が失敗0
- `scripts/lint-display-copy.py` と `scripts/audit-default-values.py` が exit 0
- 元設計正本 §0 の7項目に一切触れていないこと（**特に `AppContainer.lockSurfaceState` の権利ガード**）
- F3の修飾子順序（`.aspectRatio` → `.frame(maxWidth: 393)`）を変えていないこと
