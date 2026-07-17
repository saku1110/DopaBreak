# 独立レビュー依頼

このリポジトリは git 管理外（`git init`されていない）のため diff は使えない。以下のファイル群が今回のセッションで新規追加・変更されたものである。バグ・セキュリティ問題・ロジックエラーのみ報告してほしい（スタイル指摘は不要）。

## 新規/変更ファイル
- `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SettingsStore.swift`（`wakeTimeMinutes`/`bedTimeMinutes`追加）
- `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Models/DayTimeContext.swift`（新規）
- `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/DayTimeContextTests.swift`（新規）
- `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/DopaBreakCoreTests.swift`（既存テストにwake/bed分の追加）
- `ios/DopaBreak/InterventionFlowModel.swift`（`dayTimeContext`計算プロパティ追加）
- `ios/DopaBreak/InterventionFlowView.swift`（S-02にバナー表示追加）
- `ios/DopaBreak/GrayscaleAutomationGuideView.swift`（新規画面）
- `ios/DopaBreak/SettingsView.swift`（起床/就寝時刻セクション＋モノクロ導線ボタン追加）

## 機能概要
起床/就寝時刻をユーザーがSettings画面で設定すると、(1) SNS介入フロー(InterventionFlowView)のS-02画面で起床直後(起床時刻〜+30分)・就寝前(就寝時刻-60分〜就寝時刻)の時間帯だけ専用バナーを出す、(2) iOS Shortcutsのパーソナルオートメーション設定を案内する新規ガイド画面（画面全体のモノクロ化用、既存のAutomationGuideView.swiftと同パターン）を追加する機能。

## 特に見てほしい観点
- `DayTimeContext.resolve`の時刻窓判定ロジック（mod 1440演算・日付またぎ）に他の見落としがないか
- `SettingsStore`のwake/bedTimeMinutesがUserDefaultsの「未設定(nil)」と「0分(=00:00)」を正しく区別できているか
- `SettingsView`の`DatePicker`バインディング（Date⇄分数変換）にタイムゾーン起因のバグがないか
- 新規画面・新規プロパティが既存のFamilyControls/ShieldController/RuleStore/StoreKit/EntitlementGateまわりの挙動に意図せず影響していないか
- スレッド安全性（`@MainActor`/`Observable`まわり）

レビュー結果は箇条書きで、各指摘に該当ファイル・行・再現条件を明記して報告してください。問題がなければ「問題なし」とだけ報告してください。
