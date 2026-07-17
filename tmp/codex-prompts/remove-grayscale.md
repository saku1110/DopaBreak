# タスク: モノクロ化機能を完全削除

DopaBreakからモノクロ画面自動化機能（§4e時間帯版・§4f対象アプリ版）を完全に削除する。理由: Appleはサードパーティアプリがシステム全体のカラーフィルター(モノクロ)を直接自動制御する公開APIを提供しておらず、実現方法がiOS Shortcutsの手動オートメーション設定＋事前にAccessibility設定でカラーフィルタを手動有効化、という多段の手動手順になってしまい、アプリの「自動で止める」という設計思想と合わないとオーナーが判断した。

**重要: 起床/就寝時刻の連動バナー機能（`DayTimeContext`・介入フローS-02のバナー・`wakeSleepSection`）は今回の削除対象ではない。これはモノクロとは独立した別機能であり、そのまま残すこと。** `wakeTimeMinutes`/`bedTimeMinutes`・`DayTimeContext.swift`・`DayTimeContextTests.swift`・`InterventionFlowModel.dayTimeContext`・`InterventionFlowView`の`dayTimeContextBanner`・`SettingsView`の`wakeSleepSection`/`wakeTimeBinding`/`bedTimeBinding`はすべて維持する。

## 削除対象

### 1. ファイル全体を削除
- `ios/DopaBreak/GrayscaleAutomationGuideView.swift`
- `ios/DopaBreak/AppGrayscaleAutomationGuideView.swift`

### 2. `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SettingsStore.swift`
- `Key.grayscaleStartMinutes` / `Key.grayscaleEndMinutes` の定数
- `grayscaleStartMinutes` / `grayscaleEndMinutes` のプロパティ一式

### 3. `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/DopaBreakCoreTests.swift`
- 設定ラウンドトリップテスト内のgrayscale関連アサーションを削除（テストメソッド自体は残し、grayscale部分の行だけ除去）
- `testSettingsStoreNormalizesGrayscaleMinutes()` テストメソッド全体を削除

### 4. `ios/DopaBreak/SettingsView.swift`
- `isGrayscaleGuidePresented` / `isAppGrayscaleGuidePresented` の`@State`
- `grayscaleSection`の呼び出し箇所（body内）
- `GrayscaleAutomationGuideView` / `AppGrayscaleAutomationGuideView` を表示する`.sheet`修飾子2つ
- `grayscaleSection`計算プロパティ全体（「画面のモノクロ化」カード）
- `grayscaleStartBinding` / `grayscaleEndBinding`
- `refreshSettingsState()`内の`grayscaleStartMinutes`/`grayscaleEndMinutes`デフォルト値seeding処理

### 5. `docs/11_ui_copy.md`
- §4e「時間帯でモノクロにする設定」セクション全体を削除
- §4f「対象アプリの間だけモノクロにする設定」セクション全体を削除
- §4dの末尾にある「※ モノクロ関連の導線は…」という注記行を削除（もう移動先のセクションが存在しないため）
- 他のセクション（§4d起床・就寝時刻、§8起床・就寝バナー等）はそのまま維持

### 6. `docs/CHANGELOG.md`
末尾（最新エントリの上）に新しいエントリを追記:
```
## 2026-07-11 — モノクロ画面自動化機能を削除

- オーナー判断: システム全体のカラーフィルター自動制御はAppleが公開APIを提供しておらず、事前のAccessibility手動設定＋Shortcuts手動設定という多段の手間になるため、アプリの設計思想と合わないとして機能ごと削除
- 削除: `GrayscaleAutomationGuideView.swift` / `AppGrayscaleAutomationGuideView.swift`、SettingsStoreの`grayscaleStartMinutes`/`grayscaleEndMinutes`、SettingsViewの「画面のモノクロ化」セクション、docs/11 §4e・§4f
- 起床/就寝時刻連動バナー機能（DayTimeContext・S-02バナー）は別機能のため維持
```

## 禁止事項
- `DayTimeContext`関連（起床/就寝時刻・S-02バナー）には一切触れない
- 他の無関係なコードには触れない

## 完了条件
1. `cd ios/Packages/DopaBreakCore && swift test` が全件パスすること
2. `cd ios && xcodebuild build -scheme DopaBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` が`BUILD SUCCEEDED`になること
3. `grep -rn "モノクロ\|Grayscale\|grayscale" ios/ docs/11_ui_copy.md` で残存参照がゼロになっていること（起床/就寝バナー・DayTimeContext関連のヒットは無関係なので問題ない。今回の対象語自体が完全に消えているか確認）
4. 変更ファイル一覧とテスト結果を報告すること
