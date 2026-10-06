# 2026-09-13 広告流入の到達確認

RevenueCat DopaBreak (b342aaa8) Customersの本日First Seen 4プロフィールを読取確認。全期間一覧は顧客10、試用0、有料0、売上USD0。全期間顧客数は広告インストール数ではない。

| Apple Adsキーワード | 初回設定完了 | オートメーション実行確認 | 呼吸完了 |
|---|---|---|---|
| アプリ制限（JP CP2） | true | 未記録 | 未記録 |
| スマホ制限アプリ（JP CP2） | true | true | true |
| 스크린 타임（KR CP2） | 未記録 | 未記録 | 未記録 |

以上3プロフィールでMedia Source = Apple Search AdsとCampaign/Keywordを確認。残る本日の日本1プロフィールは呼吸完了trueだが広告帰属欄が空のため、広告経由と数えない。個別IDは本書へ転載しない。

実装照合：AppleAdsMeasurementは上記3種の到達状態をRevenueCat顧客属性として送る。onboarding_completedはDopaBreakAppのOnboardingFlow完了コールバック。automation_verifiedはAppContainerでオートメーションの実行確認時。breathing_completedは呼吸終了後の意図選択への遷移時。詳細な閲覧イベントや最後の画面ではなく、永続的なtrue属性。

StoreService.recordPaywallShownはローカルFunnelEventStoreにのみ記録。オンボーディング各画面の到達・課金画面の閲覧/離脱はRevenueCatからは確認できない。未記録は未到達とは限らず、属性の同期遅延や古い版の利用もある。今回の値から離脱画面・離脱理由・広告全体のCVRは断定しない。

App Store Connectでは1.0.1がREADY_FOR_DISTRIBUTION。コード変更・広告設定変更なし。画面単位の離脱分析が必要なら、step viewed/completed、paywall viewed/dismissedなどの外部イベント計測を追加した更新版が必要。過去の未収集イベントは復元できない。
