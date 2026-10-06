# ショートカット・利用時間・再介入の仕様照合監査

実施: 2026-09-07。対象は現在の作業ツリー。依頼は監査のため、アプリ実装・設定・配布は変更していない。

## 結論と前回説明の訂正

- 利用中の再介入は「選んだ累積実利用時間への到達」が基準。起動回数や、ホーム画面を含む経過時間ではない。利用枠内で2枚目を経由してInstagramが開くことは仕様に合う。
- 12時間は放置セッションの終了期限であり、5/10/15/30分の利用予算とは別。12時間の保存だけを不具合とは判断しない。ただし到達を取りこぼした際の回復不足は別の問題。
- 1枚目の背景の「設定が完了していません」と、前面のアプリ指定エラーは別判定。手動チェックを背景の判定へ反映し忘れている不整合は確認できた。前面のエラーは受信した要求が未指定の場合に出るが、それだけではユーザーのショートカット編集画面が未設定だったとは証明できない。
- 9月6日の調査記録にもユーザーはXを明示選択したと記録されている。以前の回答で設定ミスを前提にしたのは不適切だった。
- 今回の実機で到達イベントが来ない原因までは確定できていない。保存セッション・OS監視登録・イベント受信記録とインストール済みビルドの照合が必要。

## 採用する仕様

1. `.claude/specs/reintervention-implementation-2026-09-05.md`、末尾の「目的別の通知・ブロック」を含む。仕事/調べもの/連絡/投稿は時間選択初期ON、基本は通知のみ。接続済みなら任意でブロックON。暇つぶし/なんとなくはブロック型。
2. `.claude/specs/design-decisions.md` の2026-09-06手動チェック化。確認メモと自動実行履歴は別保存。設定済み表示・進捗はユーザー申告を使う。
3. `.claude/specs/hard-block-intervention-suppression-2026-09-06.md`。完全ブロック時間中は通常介入全体を休止。ブロック対象外のSNSにも及ぶことは承認済み制約。
4. 古い `docs/12_hybrid_intervention.md` にある通常介入の時間選択廃止は後日の変更により更新が必要。現在の動作を古い仕様へ戻す根拠にしない。

## コードで確認した不整合

### F1 / P2: 手動チェックしてもホームが「設定未完了」と断定する

- `ios/DopaBreak/AutomationGuideView.swift:329` は `confirmedAutomationCatalogIDs` でチェックと設定済みを表示する。
- `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SettingsStore.swift:194` にユーザー申告を独立保存する。
- `ios/DopaBreak/HomeView.swift:1006` は `verifiedAutomationCatalogIDs` だけで未設定バナーを判定し、1021行付近で「設定が完了していません」と表示する。手動チェックを読んでいない。
- 再現条件: Xを手動チェックON、Xの自動実行履歴なし。ガイドは設定済み、ホームは設定未完了になる。今回の画像背景と整合する。
- 修正方針: 設定の申告状態と動作確認状態を区別する。ホームの設定済み判定を手動チェックへ合わせ、必要なら実行未確認を別の文言で案内する。チェックをONにしても曖昧な起動元を推測してはいけない。

### F2 / P1: URL方式に自己起動ループ抑止がない

- `ios/DopaBreak/DopaBreakApp.swift:233` の `dopabreak://intervene?app=instagram` は `consumeInterventionRequest` を直接呼ぶ。
- AppIntent方式だけは `ios/DopaBreak/AppContainer.swift:1318` の鮮度・自己起動判定を通る。URL方式はこの判定を通らない。
- `ios/DopaBreak/InterventionFlowModel.swift:448` と497行付近でSNSへ戻る際は自己起動記録を残しているが、URL受信側がその記録を参照しない。
- 発生条件: 「Instagramを開く→DopaBreakのURLを開く」方式のオートメーション。通過許可中にDopaBreakがInstagramを開くと、再度URLが呼ばれ、再び通過・Instagram起動になる経路がある。許可なしでは再度呼吸へ入る可能性がある。
- 修正方針: URLとAppIntentで自己起動の消費判定を共通化する。URLの受信時刻を明示し、通知優先・オンボーディングの扱いも合わせる。
- 今回のユーザーがURL方式を使っていることは確認していない。1枚目の文言はAppIntent側の曖昧要求であり、これを今回の原因とは断定しない。静的な経路確認であり実機ループ再現は未実施。

### F3 / P2: 古い要求を捨てる前に検証済み履歴を書いている

- `ios/DopaBreak/AppContainer.swift:1226` と1269行付近で `markAutomationVerifiedIfNeeded` が鮮度判定より先。
- 日付なし/20秒超過で捨てる要求でも、対象IDが解決すれば履歴へ入る。`automationVerified` 計測と通知の取り消しにも進む。
- 修正方針: 古い要求は検証履歴へ入れない。自己起動の反響はオートメーションが発火した事実として扱うか明示して分岐する。手動チェックを実行履歴で上書きしない原則は維持。
- 今回の「未設定」表示を単独で説明する不具合ではなく、逆に誤って検証済みにする経路。

### F4 / P2: 正本を名乗る仕様書が現行の承認仕様と矛盾している

- `docs/12_hybrid_intervention.md` は通常介入の時間選択/通知廃止・毎回呼吸を記載。
- `docs/04_functional_requirements.md:53`、`docs/06_screen_design.md:95`、`docs/11_ui_copy.md:361` にも旧仕様が残る。
- 9月5日の追加仕様は累積利用時間の再介入、目的別の通知/ブロック、未接続時の経過時間へのフォールバックを定義する。コードは概ねこちらに対応している。
- 修正方針: 現行正本と優先順位を統合する。旧仕様は履歴と明記し、未接続・通知型・ブロック型の違いも正本へ反映する。

## 2枚目が続く原因になり得る回復・診断の不足

### R1 / 優先度高: 到達イベントを早すぎると判断して捨てた後の回復がない

- `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/ReinterventionStore.swift:48` はイベントUUIDの一致だけでなく、壁時計でも選択分数が経過したことを要求する。
- `ios/MonitorExtension/DeviceActivityMonitorExtension.swift:38` はその条件を満たさないイベントを無記録で捨てる。保留、再確認、棄却理由の保存がない。
- 例: 5分セッションに対し開始299秒時点で同じUUIDのイベントが来ると拒否する。その後イベントが再配信されなければ、300秒を過ぎても `reachedAt` はnilのまま。単に時間が経ってもブロックへ変わらない。
- これは条件付きの障害経路として確実だが、今回実機で早期イベントが来たという証拠はない。既存テストも「299秒は拒否、300秒は受理」しか検証しておらず、再配信なしの回復は検証していない。
- Appleの文書は閾値到達時のコールバックを定義するが、アプリが無視したイベントを再配信すると保証していない。単純に早期イベントをすべて受理する修正も、誤ブロックを招くので避ける。まず受信時刻・UUID・棄却理由を保存し、回復方針を決める。

### R2 / 優先度高: 保存データがあれば実際の監視がなくても「計測中」と扱える

- `ios/DopaBreak/AppContainer.swift:812` 付近の同期はセッション期限・権限・対象・到達を確認するが、OSの登録済み活動・イベントを照合しない。
- `ios/DopaBreak/InterventionFlowModel.swift:142` の計測中判定は保存セッションの有無だけ。`AppContainer.swift:1308` の通過は保存した許可期限で判断する。
- OS登録が失われた場合や、プロセス終了等で登録と保存状態がずれた場合、計測が継続している保証なしに2枚目を表示できる。最大12時間まで続き得るが、今回OS登録が失われたという証拠はない。
- 保存とOS操作が分離される具体例: `ReinterventionScheduler.prepare` はセッション保存→既存監視停止→登録の順。`finish/finishEarly` は監視停止→保存の順なので、停止後の保存失敗で未到達セッションだけが残る。
- 修正方針: 復帰時にOSのactivity/event UUIDとセッションを照合する。欠落は異常として示し、利用済み時間を黙ってゼロへ戻す再登録はしない。保存失敗時の復旧も含める。

### R3 / 要追加確認: アクション入力とアプリ受信要求を結ぶ診断情報がない

- `StartInterventionIntent.swift` は日付・ID・自動解決フラグを別々のUserDefaultsキーで保存。要求IDや入力の受信記録がなく、アプリ側は消費時に3キーを消去する。
- 未指定の複数対象では現在の選択集合を見てエラーを出す。手動チェックの有無はこの分岐へ影響しない。これは誤ったSNSを開かないためのガードとして正しい。
- ただし「アクションで選択済みなのにnilが届く」「別の古い/重複オートメーションが未指定で発火」「保存・消費のタイミングによる欠落」を現状のログでは区別できない。共有キーの競合は未再現の仮説であり断定しない。
- 修正方針: 要求ID・入口種別・受信catalogID・受信/消費時刻・判定結果をローカルへ保存。単一要求の保存と消費を整合させ、エラーはユーザーの設定状態ではなく『対象アプリ名を受け取れなかった』という確認可能な事実を伝える。

## 観点別の照合結果

| 観点 | 確認した結果 | 制約 |
|---|---|---|
| 手動チェック/表示/再起動 | 保存とチェックUIは独立実装済み。ホームだけ旧判定 | F1 |
| 起動対象 | 明示ID優先、1対象だけ省略可、複数を推測しない | 入力欠落の原因は未確定 |
| コールド/ウォーム復帰 | 初期化・active・RootTabの消費経路あり | 実機のAppIntent完了順序は未確認 |
| 自己起動/二重介入 | AppIntentに8秒の自己起動抑止、要求20秒の鮮度制限 | URL方式はF2。別キー共有はR3 |
| 利用時間登録 | 5/10/15/30分、includesPastActivity=false、セッションごとのイベントUUID | 実測ではなく登録引数をテスト |
| 閉じる/再オープン | 未到達予算の再登録を拒否、通過画面で継続 | R1/R2では継続表示が実態を保証しない |
| 目的別挙動 | 仕事系は通知、任意ブロック。暇つぶし系は接続済みならブロック | 理由・トグルが不明なら未ブロックを断定不可 |
| Screen Time接続 | 1アプリ、カテゴリ/Web拒否、重複接続拒否 | 匿名トークンとInstagramの同一性を本体で自動確定できない旨は表示済み |
| 未接続 | 経過時間の許可/振り返り/仕事通知へフォールバック | ショートカット設定とScreen Time接続は別 |
| 到達/通知OFF | 到達保存と遮蔽が通知有無より先、通知OFFでもブロック可 | OSイベントと実遮蔽の配送は未検証 |
| 振り返り/延長 | 到達を優先、回答済みを再質問せず、延長は呼吸→時間。旧イベントをUUIDで拒否 | モーダル/実機通知タップは全組合せ実測なし |
| 複数SNS | セッションをIDごとに保持、flockで共有更新、遮蔽は到達した集合 | 不正トークン対応づけは検出不能 |
| 削除/解除/期限/権限 | 対象削除、権限取消、12時間満了の後始末あり | 保存失敗後・監視欠落はR2 |
| 完全ブロック併用 | 別ストア。ブロック時間中の通常介入全体休止は最新仕様どおり | 対象外SNSも休止する承認済み制約 |
| 拡張/共有設定 | 本体/MonitorのApp Group一致、Family Controls entitlement、拡張ビルド成功 | インストール済み署名/実機権限は今回未照合 |
| データ/診断 | セッションはローカル共有、UUIDで古いイベント拒否 | 棄却・実登録状態・入力の診断が不足 |
| 仕様/テスト | 正常系の登録・状態遷移は成功 | 旧正本と不一致。実機の配送成功を証明しない |

## 今回の検証

- Core: 関連64件、失敗0。ReinterventionStore / AutomationRequestPolicy / InterventionTargetResolutionPolicy / SettingsStore / CatalogAllowanceStore / ReflectionNotificationPolicy。
- iOS 26.5専用QA Simulator: 56件、失敗0。InterventionRouting 37、ReinterventionScheduler 8、ReflectionNotificationScheduler 7、NotificationDelegateRouting 4。本体と拡張ビルド成功。
- テストの保存領域は一時ディレクトリ/独自UserDefaults、監視にはBudgetMonitor等の代替を使う。実機へインストール・設定変更はしていない。
- 最初の通常サンドボックス実行はキャッシュ/Simulatorアクセス制限で実行不可。承認された権限拡張で再実行し成功。既存のSwift 6移行等の警告あり。
- 過去テストの成功を転載したものではなく今回再実行。正常系テスト成功と、上記の未試験の障害回復不足は両立する。
- ログ: `docs/reviews/2026-09-07-shortcut-audit-evidence/core-tests.log`、`ios-tests.log`。

## 実機で原因を確定するために必要な最小証拠

1. インストール済みビルド、InstagramセッションのID/開始時刻/分数/blocksAtLimit/reachedAt/期限。
2. 同じIDのOS監視活動・イベントが登録されているか。接続対象がInstagramかはユーザーに見える選択表示で確認する。
3. AppIntentの受信入力と、Monitorの到達受信/棄却記録。現状記録が不足しているため、診断を追加してから次の発火を確認する。

ユーザーへショートカットの作り直しやチェックの付け直しを先に求める根拠はない。

## Appleの一次資料

- [DeviceActivityEvent.threshold](https://developer.apple.com/documentation/deviceactivity/deviceactivityevent/threshold): 利用が閾値に達した場合の通知契約。
- [includesPastActivity](https://developer.apple.com/documentation/deviceactivity/deviceactivityevent/includespastactivity): 登録以前の利用を含めるかの指定。
- [DeviceActivityCenter](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter): 登録済みactivities、events、scheduleの照合手段。
- [eventDidReachThreshold](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor/eventdidreachthreshold(_:activity:)): 閾値到達コールバック。
