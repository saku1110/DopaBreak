# 設定エントリ行の表示テーマが実機とずれる（ND-5の副作用・是正）

- 元設計正本: `.claude/specs/lock-theme-picker-onboarding.md`（**§0の絶対制約は厳守**）
- 直前の変更: `.claude/specs/lock-theme-pending-selection.md`（ND-5）

## 不具合

`SettingsLockSurfaceView.swift` の `selectTheme(_:)` の `onSelect` が

```swift
savedLockTheme = selectedTheme      // 正しい（保存値の表示用State）
selectedLockTheme = selectedTheme   // ← ここが誤り
```

としている。`selectedLockTheme` は **`SettingsView` の `@State`（`SettingsView.swift:71`）** で、次の意味を持つ。

- `SettingsView.swift:1923` の `refreshSettingsState()` が **`model.lockSurfaceState.theme`（＝権利ガード適用後＝いま実機に出ているもの）** を代入する
- `SettingsView.swift:1083` で設定エントリ行の `value:` ラベルとして表示される

つまりこの値の意味は「**いま実機のロック画面に出ているテーマ**」。ND-5でロック済みテーマも保存するようになった結果、無料ユーザーがProテーマをタップすると生の選択値がここへ入る。

**実害**: 無料ユーザーが「ゲーミング」を押すと、設定エントリ行が「ゲーミング」と表示される。しかし実機ロック画面は権利ガードにより黒とライムのまま。さらに画面へ入り直すと `refreshSettingsState()` が走って行が黙って「黒とライム」へ戻る。表示が実機と食い違い、かつ勝手に変わったように見える。

F1・ND-1と同じ「実機と違うものを表示する」系統の問題であり、ND-5で新たに入り込んだもの。

## ホーム側は正しいので触らない

`HomeView` の `selectedLockTheme` は `settingsStore.lockTheme`（保存値）で初期化（`:208`）・更新（`:252`）されており、**一貫して保存値の意味**。ピッカーの選択表示（`:744`）とProノート判定（`:731`）に使われ、実機表示のカードは別途 `model.lockSurfaceState.theme` を描いている。**この構成は正しいので変更しないこと。**

## 修正

`SettingsLockSurfaceView.swift` の `onSelect` で、`selectedLockTheme` へ**生の選択値を入れない**。権利ガード適用後の値を入れる。

- `savedLockTheme`（ピッカーの選択枠とProノート用）は**保存値**のまま維持する
- `selectedLockTheme`（親の行ラベル用）は `model.lockSurfaceState.theme` を読み直して代入する。`refreshLockSurfaces` の後に読むこと

結果として、無料ユーザーがProテーマを押したときの表示は次になる。

| 場所 | 表示 |
|---|---|
| 設定エントリ行 | 黒とライム（実機と一致） |
| ピッカーの選択枠 | 押したProテーマ（ユーザーの意思を保持） |
| Proノート | 表示される |
| 実機ロック画面 | 黒とライム |

購入後は `refreshSettingsState()` と entitlement の伝播により、行もピッカーも保存済みテーマになる。

## テスト（必須）

1. **無料ユーザーが設定でProテーマをタップした直後、親の行に渡る `selectedLockTheme` が `.e1` のままであること**（ガード後の値）
2. 同じ操作で `savedLockTheme` 相当のピッカー選択表示は押したProテーマになること
3. 同じ操作で `settingsStore.lockTheme` が押したProテーマになり、`.settingsThemeGate` が立つこと（ND-5の挙動を壊していないこと）
4. Proユーザーが同じテーマを押すと、行・ピッカー・保存値の3つとも押したテーマになること

恒等関数へのアサーションで済ませず、ハンドラの実挙動を通して検証すること。

## 絶対に触らないこと

- `AppContainer.lockSurfaceState` の権利ガード
- `EntitlementGate.lockThemeAllowed`
- `HomeView` の `selectedLockTheme` の扱い（保存値の意味で正しい）
- ND-5の「保存が先・ペイウォール提示が後」の順序
- `LockThemePreviewCard` の修飾子順序（`.aspectRatio` → `.frame(maxWidth: 393)`）

## 完了条件

- generic iOS の全ターゲットで `BUILD SUCCEEDED`
- DopaBreakCore と DopaBreakTests が失敗0
- `scripts/lint-display-copy.py` と `scripts/audit-default-values.py` が exit 0
