# 保留中のProテーマは「デザインを選ぶ導線」からの購入でだけ反映する（2026-09-04・オーナー指示）

- 依頼（逐語）: 「オンボーディングや有料デザイン選択以外の画面からペイウォールでProにした場合はデフォルトのLiveActivityデザインになるようにして。」
- 前提の正本: `.claude/specs/live-activity-font-and-theme-apply-2026-09-01.md`（`pendingProThemeSelection` の非永続設計）。`.claude/specs/lock-theme-pending-selection.md` は永続保存版で、**現行実装は非永続版が正**

## 現状（コードで確認済み）

- ロック済み（Pro）テーマをタップすると `model.pendingProThemeSelection` にメモリ保持され、永続値 `settingsStore.lockTheme` は `.e1` のまま（`SettingsLockSurfaceView.swift:166` / `HomeView.swift:782` / `OnboardingFlow.swift:1537`）
- 保留はプロセスが生きている間ずっと残り、`RootTabView.swift:259,271` と `OnboardingFlow.swift:352,372,378` の**Pro成立監視すべて**が `applyPendingProThemeSelectionIfNeeded` を呼ぶ
- したがって「ピッカーでProテーマをタップ → ペイウォールを閉じる → 後で**別の画面**のペイウォールで購入」でも、その保留テーマが実機ロック画面とLive Activityに出る。オーナーの指摘はここ

## 決定ルール

保留中のProテーマを購入へ持ち込めるのは、**そのテーマを選ぶ導線から開いたペイウォールだけ**とする。

| ペイウォールの placement | 保留を持ち込む |
|---|---|
| `settingsThemeGate` / `homeThemeGate` | ○（有料デザイン選択の導線） |
| `onboardingPrepaywallSummary` / `onboardingModeGate` / `onboardingTargetAppGate` | ○（オンボーディング） |
| `settingsProStatusRow` / `settingsTargetAppLimit` / `settingsFamilyActivityLimit` / `settingsModeGate` / `weekly` | ×（購入してもデフォルト `.e1` のまま） |

破棄は**購入時ではなくペイウォール提示時**に行う。提示中のピッカー表示（「Proにするとこのデザインになります」）と購入後の結果を食い違わせないため。

## 変更内容

対象は `ios/DopaBreak/PaywallView.swift` の1ファイル＋テスト。

1. `PaywallPlacement` の直後に判定を追加する。**`default` を書かず全ケースを列挙**し、placementを追加したときにコンパイルエラーで判断を強制する。

```swift
/// 保留中のProテーマ選択を購入へ持ち込んでよいペイウォールか。
/// デザインを選ぶ導線（オンボーディング／テーマピッカー）から開いた時だけ持ち込む。
enum PendingProThemePaywallPolicy {
    static func keepsPendingSelection(for placement: PaywallPlacement) -> Bool
}
```

2. `PaywallView` の `.onAppear`（`didRecordAppearance` のガード内、計測記録と同じ場所）で、`keepsPendingSelection(for: placement) == false` のときだけ `model?.pendingProThemeSelection = nil` を実行する。

提示元4箇所（`SettingsView.swift:321` / `HomeView.swift:209` / `OnboardingFlow.swift:364` / `RootTabView.swift:333`）はすべて `model:` を渡しているため、この1箇所で全経路を覆える。呼び出し側は変更しない。

## 絶対に触らないこと

- `AppContainer.lockSurfaceState` の権利ガード（描画直前の `.e1` 降格）と `EntitlementGate.lockThemeAllowed`
- `updateLockTheme(_:)` / `applyPendingProThemeSelectionIfNeeded(hasProEntitlement:)` の実装と呼び出し箇所
- 3つの選択ハンドラ（`Settings*` / `Home*` / `Onboarding*LockThemeSelectionHandler`）とペイウォールの出し分け
- `settingsStore.lockTheme` を購入時に書き換える処理を新設しないこと（**永続値には手を触れない**。解約→再課金でユーザーが以前使っていたテーマが戻る挙動を壊さない）
- 計測（`recordPaywallShown` / `recordPaywallDismissedIfNeeded`）の呼び出し順と回数

## テスト（必須・`ios/DopaBreakTests/MeasurementFoundationTests.swift` の既存テーマ系テストの隣に追加）

1. `PendingProThemePaywallPolicy` の真理値表を `PaywallPlacement.allCases` で全件検証する（上表と一致すること）
2. 保留を立てた状態で `placement: .settingsProStatusRow` の `PaywallView` を表示すると `pendingProThemeSelection` が nil になり、その後 `applyPendingProThemeSelectionIfNeeded(hasProEntitlement: true)` が `false` を返し、`settingsStore.lockTheme` と `model.lockSurfaceState.theme` が `.e1` のままであること（この施策の本体）
3. `placement: .settingsThemeGate` では保留が残り、`applyPendingProThemeSelectionIfNeeded(hasProEntitlement: true)` で保留テーマが反映されること（既存の導線を壊していない証明）
4. `placement: .onboardingPrepaywallSummary` でも保留が残ること
5. 既存の保留系テスト（`testFreeSettingsProThemeSelectionStaysPendingAndPresentsSettingsPaywall` ほか）が無傷であること

表示は既存の `UIHostingController` パターンで行う（`MeasurementFoundationTests.swift:1205` に `PaywallView` を組み立てる先例あり）。恒等関数へのアサーションで済ませないこと。

## 完了条件

- `xcodebuild ... -destination 'generic/platform=iOS Simulator'` で全ターゲット `BUILD SUCCEEDED`
- DopaBreakCore（`swift test`）失敗0 / DopaBreakTests 失敗0（**専用シミュレータで実行**・`TEST SUCCEEDED` をログ本文で確認）
- `scripts/lint-display-copy.py` と `scripts/audit-default-values.py` が exit 0

## 今回の対象外（オーナーへ報告のみ）

設定＞アカウントの「購入を復元」（`SettingsAccountView.swift:85`）はペイウォールを経ないため、この変更後も保留テーマが反映されうる。依頼はペイウォール購入に限定されているため触っていない。
