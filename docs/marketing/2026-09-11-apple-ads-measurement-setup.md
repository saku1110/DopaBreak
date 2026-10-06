# Apple Ads計測の実装・接続状態

2026-09-11。DopaBreak / com.dopabreak.app / App Store ID 6794221254。

## 最新状態：1.0.1 (9) 審査提出済み

2026-09-11 19:01 JST、計測ONのビルド9を提出し、WAITING_FOR_REVIEWを確認。提出IDは8464c75a-c0f9-439b-8630-bcbd1db4b622。以下の準備中・無効・公開待ちの記録は作業履歴であり、この最新状態で置き換わる。

公開プライバシーポリシー3言語とApp Store Connectの申告を反映済み。購入履歴＝分析・アプリ機能、製品の操作・広告データ＝分析。全て身元への紐付けなし・トラッキングなし。計測・起動25テスト成功、全5バンドル署名とIPAの計測ONを確認。証跡 `.claude/verification-logs/2026-09-11-appstore-b9/result.md`。

承認後は手動公開。公開中の1.0にはSDKがなく、実際の広告帰属・購入成果は更新版の公開後に確認する。本番広告経由の購入照合は未実施。

## 現在地

- RevenueCat既存プロジェクト b342aaa8、App Store設定 appec2bcd06d1 を確認。
- 課金検証キーは画面上でValid credentials。サーバー通知は2026-09-10 08:13 UTCに受信実績あり。新規購入のサーバー通知取り込みは既に有効。秘密鍵や通知URLは本書に転載しない。
- Apple Search Ads連携を追加。Basic integration・Advanced integrationともにDone（DopaBreakプロジェクト画面で確認）。
- AdvancedのApple OAuthへのアクセス許可はユーザーが明示承認済み。ユーザーのApple認証後、DopaBreakへの接続確認を実行し、認可完了を確認済み。
- RevenueCat 5.89.0を固定してアプリ本体に追加。公開SDKキーは上記アプリのもの。別アプリのキーは流用しない。
- **送信は無効（APPLE_ADS_MEASUREMENT_ENABLED=NO）。設定完了・計測稼働中とは扱わない。** SDKを有効化した更新版の配布は未実施。

## 実装

`AppleAdsMeasurement`を追加。起動時に構成し、AdServices標準帰属トークンの自動取得を有効にする構成。匿名RevenueCat IDを使用し、IDFA等の自動収集を明示的に無効化。ATTを新設しない。SNS名・目標・振り返り・連絡先は送らない。

購入は従来どおりStoreKit 2で実行し、RevenueCatは `.myApp` / `.storeKit2` として併用。Pro判定・transaction.finishはStoreServiceが担当。購入成功・復元時に非同期で同期し、失敗してもPro判定や購入結果を変更しない。更新等はSDKの監視と既存のサーバー通知を使う。実課金・試用の判定はRevenueCatの検証済み取引を使用し、従来のローカル `trialOrPurchaseStarted` を売上として扱わない。

オンボ完了・オートメーション検収・呼吸完了を粗いtrue属性として送る実装を追加。これらはイベント履歴ではなく到達状態。`breathing_completed`は呼吸画面の完了であり、SNS利用減少や介入全体の成功を意味しない。時系列ファネルの集計が必要な場合は別途イベント基盤が必要。既存利用者が更新版を起動した場合もRevenueCatの新規顧客になることがあるため、新規顧客数を新規DL数と同一視しない。

## 確認済み

実SDKをリンクしてiOS Simulator（iPhone 17 Pro Max / iOS 26.5）で `AppleAdsMeasurementTests` を実行、TEST SUCCEEDED。5ケース：無効時送信なし、不正キー拒否、初期化順序と重複防止、無効状態からの開始、完了フラグの抑制と重複防止。テストは注入したスタブを使い、起動時のSDK初期化もXCTestでは無効。ライブの購入・課金・広告配信テストは行っていない。

ログ：`/private/tmp/dopabreak-ads-tests.log`。xcresult：`/private/tmp/dopabreak-ads-derived/Logs/Test/`。

## 有効化前に必要

1. ユーザーのApple認証後、承認済みのアクセス範囲で認可し、Advanced接続の完了を確認する。RevenueCat Basic/Advancedは接続設定の区別であり、標準/詳細AdServicesペイロードの区別とは異なる。
2. 収集を有効にする版に合わせ、公開プライバシーポリシー（日英韓）、App Store ConnectのApp Privacy、アプリmanifestを更新。購入履歴（分析・アプリ機能）、広告データ（分析）、完了フラグ（製品操作・分析）の実際の分類と、SDK同梱manifestを照合する。氏名等に結び付かない匿名IDのみ。ユーザーの削除依頼はRevenueCat側の削除も必要で、現在の「ローカルデータ削除」だけではサーバーデータを削除できない。
3. `APPLE_ADS_MEASUREMENT_ENABLED=YES` のテスト配布版で、SDK顧客生成・sandbox試用・初回実課金・更新・復元を検証。実購入は別途承認が必要。sandboxの帰属値を本番広告成果と混同しない。
4. 更新版公開後の新規獲得で、Apple Adsの新規DLとRevenueCatの帰属・試用・初回実課金を照合。クリックと表示経由の帰属、再DL、既存顧客、未終了試用を区別する。

広告費・クレジット消費・キャンペーン作成は今回行っていない。Apple手数料15%は既知の事業前提。RevenueCatのSmall Business Program適用日設定は今回未確認。控除済み売上から手数料を二重に引かない。

## 一次資料

- https://www.revenuecat.com/docs/integrations/attribution/apple-search-ads
- https://www.revenuecat.com/docs/migrating-to-revenuecat/sdk-or-not/finishing-transactions
- https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-app-privacy
- https://developer.apple.com/documentation/adservices/

公開ポリシーURLは `ios/DopaBreak/AppURLs.swift` の dopabreak-legal。公開先の編集・公開は本作業ではまだ行っていない。

## 公開表示の確認と改定案（未公開）

2026-09-11にChromeで日本語ポリシーを確認。現行版（9月7日）はAppleのサーバ通知によるRevenueCat購入分析と削除窓口を記載済み。ただしSDKからの帰属情報・完了状態送信は未記載。「外部収集なし」はアプリからの送信のみの説明であり、既存サーバ通知による収集がないという意味ではない。

次の内容を日英韓の基本方針・課金分析・外部サービス・削除の節へ反映する。現時点の稼働内容として公開しない。

### 日本語案

広告の効果と購入後の利用状況を分析するため、RevenueCat SDKを利用します。アプリは匿名の顧客ID、購入情報、Apple Ads経由のインストールを判定するAdServicesトークン、および初回設定・オートメーション設定の確認・呼吸画面の完了状態をRevenueCatへ送信します。RevenueCatはAppleの帰属情報と購入情報を照合します。氏名、メールアドレス、IDFA、選択したSNS、目標や振り返りの内容、スクリーンタイム情報は送信しません。他社アプリやウェブサイトを横断する広告目的のトラッキングには使用しません。端末内データの削除では、この分析データは削除されません。分析データの削除はお問い合わせ窓口で受け付けます。

### English draft

We use the RevenueCat SDK to measure advertising effectiveness and use after purchase. The app sends an anonymous customer ID, purchase information, an AdServices token used to determine Apple Ads attribution, and completion flags for onboarding, automation setup verification, and the breathing screen to RevenueCat. RevenueCat associates Apple's attribution information with purchase information. We do not send your name, email address, IDFA, selected social apps, goals, reflection content, or Screen Time information. We do not use this information for advertising tracking across other companies' apps or websites. Deleting local app data does not delete this analytics data. Please contact support to request deletion of analytics data.

### 한국어 초안

광고 효과와 구매 후 이용 현황을 분석하기 위해 RevenueCat SDK를 사용합니다. 앱은 익명의 고객 ID, 구매 정보, Apple Ads 유입을 확인하기 위한 AdServices 토큰, 초기 설정·자동화 설정 확인·호흡 화면의 완료 여부를 RevenueCat에 전송합니다. RevenueCat은 Apple의 광고 기여 정보와 구매 정보를 연결합니다. 이름, 이메일 주소, IDFA, 선택한 SNS, 목표 및 회고 내용, 스크린 타임 정보는 전송하지 않습니다. 다른 회사의 앱이나 웹사이트에 걸친 광고 목적의 추적에는 사용하지 않습니다. 기기 내 데이터를 삭제해도 이 분석 데이터는 삭제되지 않습니다. 분석 데이터 삭제는 문의 창구를 통해 요청할 수 있습니다.

設定のプライバシー画面へ分析IDの表示・コピーとサポートリンクを追加（日英韓）。SDK無効時は表示しない。未購入の匿名顧客もこのIDで削除対象を指定できる。メール送信・外部削除は自動実行しない。

## 追加実装・公開待ち

- 2026-09-11、匿名IDの無効時非表示・初期化後取得も含む5件のスタブテストが成功。本体と設定画面のコンパイル成功。ログ `/private/tmp/dopabreak-ads-tests-final.log`。本番送信・sandbox取引・新しい設定表示の目視は未検証。
- manifestにPurchase History（Analytics / App Functionality）、Advertising Data（Analytics）、Product Interaction（Analytics）を追加。有効版に合わせた宣言。追跡なし、身元への紐付けなし。SDK同梱manifestとも照合し、plutil検証成功。
- 公式公開ソース `saku1110/dopabreak-legal` を取得して日英韓HTMLを改定。成果物 `docs/marketing/apple-ads-privacy-ready/`。公開用作業コピー `/private/tmp/dopabreak-legal-ads-20260911`。本文とスタイルを保ち、更新版からの適用と従来版のサーバ通知を区別。未公開。
- App Store Connectへの反映内容：購入履歴＝分析・アプリ機能、広告データ＝分析、製品の操作＝分析。いずれも身元への紐付けなし・トラッキングなし。カスタムUser ID・IDFA・IDFVは収集しない。任意の削除依頼で届く分析IDは対象特定にのみ使用し、広告分析に身元を追加しない。
- 公開ポリシーとApp Privacyの反映後に送信フラグをYESへ変更し、テスト配布・新ビルド提出する。現在の送信フラグはNOで、アプリ計測は稼働していない。
