# ロック済みテーマの選択を購入後に反映する（ND-5・オーナー承認済み）

- 承認日: 2026-08-26（オーナー指示「ロック済みテーマをタップしてペイウォールで購入にしたら選択されるようにして」）
- 元設計正本: `.claude/specs/lock-theme-picker-onboarding.md`（**§0の絶対制約は引き続き厳守**）

## 背景

現状、無料ユーザーが設定やホームでロック済み（Pro）テーマをタップすると、ペイウォールは開くが**タップしたテーマは捨てられる**。購入を完了しても黒とライムのままで、ユーザーはもう一度選び直す必要がある。欲しくて押したものを覚えていないのは購入直後の体験として損失。

## 方針: 新しい永続状態を作らない

**オンボーディングと同じ仕組みをそのまま使う。** 保留用のフィールドやフラグを新設しないこと。

設計正本 §2.2 のとおり、オンボではProテーマも `settingsStore.lockTheme` へ普通に保存している。`AppContainer.lockSurfaceState` の権利ガードが描画直前に `.e1` へ落とすため、無料のうちは実機に出ない。課金した瞬間、ガードが落とさなくなり保存済みテーマがそのまま反映される。この経路は既に `testSavedProThemeStaysGuardedForFreeAndReturnsForPro` で守られている。

つまり **`onLocked` でも保存すればよい**。それだけで購入後の反映は自動的に成立する。

## 変更内容

対象は2箇所の選択ハンドラ。

- `ios/DopaBreak/SettingsLockSurfaceView.swift` の `selectTheme(_:)` → `SettingsLockThemeSelectionHandler`
- `ios/DopaBreak/HomeView.swift` の `selectHomeLockTheme(_:)` → `HomeLockThemeSelectionHandler`

現在は「許可されていれば保存」「ロック済みならペイウォールだけ」という排他分岐になっている。これを次へ変える。

1. **テーマは常に保存する**（`settingsStore.lockTheme = theme`、表示用Stateの更新、`model.refreshLockSurfaces(scheduleNotifications: false)`）。許可の有無で分岐しない
2. **そのうえで**、許可されていないテーマだったときだけペイウォールを提示する（設定は `.settingsThemeGate`、ホームは `.homeThemeGate`。**現在の出し分けを変えない**）
3. ホームは現状どおり、ペイウォール提示前にピッカーのシートを閉じる

保存を先、ペイウォール提示を後にすること。順序が逆だと、シート遷移の途中で保存が飛ぶ経路が生まれる。

## 期待される挙動

| 状況 | 結果 |
|---|---|
| 無料ユーザーがProテーマをタップ | そのテーマが選択状態になり「Proにすると このデザインになります」が出て、ペイウォールが開く。実機ロック画面は黒とライムのまま |
| そのままペイウォールを閉じた | 選択は保持されたまま。実機は黒とライム。設定を開き直しても選択は残る |
| ペイウォールで購入した | **選び直し不要でそのテーマが実機ロック画面に反映される**。注記も消える |
| 解約して期限が切れた | 自動で黒とライムに戻る。保存値は残るので再課金で復活する |

## 絶対に触らないこと

- `AppContainer.lockSurfaceState` の権利ガード（描画直前の `.e1` 降格）
- `EntitlementGate.lockThemeAllowed`（free は `.e1` のみ）
- ペイウォールの出し分け（設定＝`settingsThemeGate` / ホーム＝`homeThemeGate`）
- `LockThemePreviewCard` の修飾子順序（`.aspectRatio(393/160, .fit)` → `.frame(maxWidth: 393)`）

**この変更で「無料ユーザーがProテーマを実機で使える」状態を作ってはならない。** 保存はするが描画はガードが止める、という既存の二層構造を維持すること。

## テスト（必須）

1. **無料ユーザーが設定でProテーマをタップすると、`settingsStore.lockTheme` がそのテーマになり、かつ `.settingsThemeGate` が立つこと**（保存とペイウォールの両方が起きる。片方だけではない）
2. ホームでも同様に保存され、かつ `.homeThemeGate` が立つこと
3. **その状態で `AppModel.lockSurfaceState.theme` が `.e1` のままであること**（漏れの回帰防止。最重要）
4. **同じ状態でProに切り替えると、選び直しなしに `lockSurfaceState.theme` が保存済みテーマになること**（この施策の本体）
5. ペイウォールを閉じても保存が消えないこと

恒等関数へのアサーションで済ませないこと。ハンドラの実挙動を通して検証する。

## 完了条件

- generic iOS の全ターゲットで `BUILD SUCCEEDED`
- DopaBreakCore と DopaBreakTests が失敗0
- `scripts/lint-display-copy.py` と `scripts/audit-default-values.py` が exit 0
