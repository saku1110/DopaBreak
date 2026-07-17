# 修正指示: 起床/就寝時刻の「表示はデフォルト値・保存はnilのまま」不整合

Codexによる独立レビューで以下の指摘を受け、コード確認の結果、事実であることを確認した。修正してほしい。

## バグ
`ios/DopaBreak/SettingsView.swift`の`wakeTimeBinding`/`bedTimeBinding`（195-207行目）は、`settingsStore.wakeTimeMinutes`/`bedTimeMinutes`が`nil`（未設定）のとき、`get`が表示用のデフォルト値（07:00/23:00）を返す。しかし`set`はユーザーがDatePickerの値を実際に変更したときにしか呼ばれない。

結果として、ユーザーがSettings画面を開いただけ（時刻を一度も変更しない）だと、画面上は「起床時刻 07:00 / 就寝時刻 23:00」が設定済みに見えるが、`settingsStore`には`nil`のまま残る。そのため:
- `GrayscaleAutomationGuideView.swift:41`の`if let wakeTimeText, let bedTimeText`が`nil`判定になり、「先に起床・就寝時刻を設定してください」のままオートメーション手順が表示されない
- `InterventionFlowModel`の`dayTimeContext`も常に`.normal`のままで、S-02の起床/就寝バナーが一切出ない

つまりユーザーから見ると「設定したはずなのに機能が動かない」状態になる。

## 修正方針
`SettingsView.swift`の`refreshSettingsState()`（既存の`.onAppear { refreshSettingsState() }`から呼ばれている関数、350行目付近）に、次の処理を追加する:
- `settingsStore.wakeTimeMinutes == nil`なら`settingsStore.wakeTimeMinutes = 420`（07:00）を書き込む
- `settingsStore.bedTimeMinutes == nil`なら`settingsStore.bedTimeMinutes = 1_380`（23:00）を書き込む

これにより「Settings画面を開いた時点で、画面に表示されている時刻が実際に保存されている状態」を保証する（以後はユーザーが自由に変更できる。強制的な入力ステップを追加するわけではなく、単に表示と実データを一致させるだけ）。

`wakeTimeBinding`/`bedTimeBinding`の`get`側のデフォルト値ロジック自体は保険としてそのまま残してよい（削除不要）。`dateForTime`/`minutes(from:)`ヘルパーも変更不要。

## 完了条件
- `cd ios/Packages/DopaBreakCore && swift test` が全件パスすること（既存の`DopaBreakCoreTests.swift`の`wakeTimeMinutes`/`bedTimeMinutes`関連テストに影響がないことを確認）
- `cd ios && xcodebuild build -scheme DopaBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` が`BUILD SUCCEEDED`になること
- 変更内容を簡潔に報告（diff要約でよい）
