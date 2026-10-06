# ショートカット介入の実機報告（2026-09-07）

## 報告
- IMG_9864.PNG: 設定済みでも対象アプリ指定エラー。画面にはInstagramとX。
- IMG_9866.PNG: Instagramを繰り返し開いても呼吸に進まず「選んだ利用時間の計測を続けます」。

## コードから確認した条件
- StartInterventionIntent.appは任意。未指定の場合は自動解決要求を保存する。
- AppContainer.consumePendingInterventionRequestは、未指定かつ複数対象の場合に1枚目のエラーを出す。InterventionTargetResolutionPolicyは誤ったアプリへの帰属を防ぐため推測しない。
- AppContainer.consumeInterventionRequestは、到達済み再介入セッションを優先する。それ以外でCatalogAllowanceStoreの許可が有効ならパススルーを開始する。
- InterventionFlowModel.recordCatalogOpenは、監視セッションがある場合、選んだ分数ではなくprepared.expiresAtまで許可を保存する。ReinterventionSession.expiresAtは開始から最大12時間の監視期限。
- このため到達イベントが未記録なら、繰り返し起動しても2枚目の表示に入る経路がある。実利用時間を累積する設計なので、短時間の再起動だけでは到達しないこと自体は説明できる。

## 未確認・次の判断
- 実機ショートカットのアクション内「アプリ」の値、選んだ分数、累積利用時間、MonitorExtensionの到達記録は未取得。
- 2枚目で停止するのか、表示後Instagramに遷移するのかは静止画像では判定できない。
- 毎回の起動時に呼吸を入れる要件か、利用時間中は省略する要件かを区別して修正する必要がある。監視期限を選択分数へ単純に変更すると実利用時間と経過時間を混同する。
- 今回はコードの読み取りによる原因経路の確認のみ。アプリコードの変更、実機検証、ビルド、配信は実施していない。

## 同日の追加確認による更新

ユーザー確認: 2枚目の後にInstagramは開く。ショートカット設定は継続しており、手動チェックもON。詳細は `2026-09-07-shortcut-reintervention-spec-audit.md` を参照。9月5日の仕様では再オープン時の予算継続が正しく、毎回の呼吸への変更は不要。12時間は放置終了期限で、それだけを不具合としない。ホームの未設定表示は手動チェックを参照していない不整合。エラーだけからショートカット編集画面の未設定を断定しない。
