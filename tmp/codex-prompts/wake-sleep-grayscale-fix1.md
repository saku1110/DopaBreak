# 修正指示: DayTimeContext の起床窓ロジックのバグ

前タスクの実装をFableが検証したところ、`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Models/DayTimeContext.swift` の `isInWakeWindow` にバグを発見した。原因はFableが前タスクのプロンプトで渡したテスト仕様例が数学的に誤っていたこと（起床窓は仕様上「起床時刻〜+30分」の前方一方向のみのはずが、誤って「起床時刻の前後」を含む例を指示してしまった）。

## バグの内容
`isInWakeWindow`内の「carry」分岐（46〜51行目付近、`carryLength` / `carryStart` を使う部分）が、起床時刻が `00:00〜00:29`（`wakeMinutes < 30`）の場合にのみ発火し、本来30分のはずの起床窓を最大60分まで不正に拡張し、かつ本来の起床時刻より前の時間帯まで「起床窓」と誤判定してしまう。例: `wakeMinutes = 0`（00:00）の場合、正しくは窓 `[00:00, 00:30)` のみだが、現状の実装だと `[23:30, 00:30)` の60分間が起床窓になってしまう。

これに対応する形で書かれたテスト `testWakeWindowWrapsAcrossMidnight`（`wakeMinutes: 10, nowMinutes: 1_430` → `.wake`を期待）も、同じ誤った前提に基づいており不正確。

## 修正方針
1. `isInWakeWindow`の特殊な「carry」分岐を削除し、単純に `isInWindow(nowMinutes, start: wakeMinutes, lengthMinutes: wakeWindowLengthMinutes)` の結果をそのまま返すだけにする（`isInWindow`内の`normalizedMinutes`によるmod 1440演算だけで、起床時刻が23:xx台で窓が翌日0時をまたぐ正当なケースは既に正しく処理できる。問題は00:00〜00:29台の起床時刻を不必要に「前日夜まで」拡張していたことだけ）
2. `DayTimeContextTests.swift`の`testWakeWindowWrapsAcrossMidnight`を、正当な深夜またぎ例に差し替える: `wakeMinutes: 1_430`（23:50）、`nowMinutes: 10`（00:10）→ `.wake`を期待（窓は23:50〜00:20なので00:10は含まれる）
3. 追加で以下の境界ケースをテストに加える:
   - `wakeMinutes: 0`（00:00）の場合、`nowMinutes: 1_430`（前日23:50）は`.normal`であること（起床時刻より前は起床窓に含まれないことの回帰防止）
   - `wakeMinutes: 0`の場合、`nowMinutes: 29`は`.wake`、`nowMinutes: 30`は`.normal`であること（境界値がちょうど30分幅であることの確認）
4. `sleep`側の実装・テストは正しいので変更不要

## 完了条件
- `cd ios/Packages/DopaBreakCore && swift test` が全件パスすること
- 修正後のコードと修正理由を簡潔に報告すること（コード全文の貼り付けは不要、diffの要約でよい）
