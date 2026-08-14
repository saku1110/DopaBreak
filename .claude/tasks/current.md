# 現在のタスク状況

## 2026-08-14 — 介入呼吸ステージ「ドーパと一緒に呼吸」演出（🔄 実装中）

- [x] /brainstorm（タイプB）: 炎の代替演出を検討 → A(キャラ呼吸同期)+C(ハプティクス)採用・B(呼吸円=one sec型)/D(リング)/E(粒子系=炎と同じ品質リスク)却下。議事録=`.claude/brainstorm/2026-08-14_介入呼吸演出_炎の代替.md`
- [x] オーナー承認「OKそれでいこう」→ BUILD_SPEC作成=`design/BUILD_SPEC_BREATH_CHARACTER.md`（拡縮1.00〜1.06・blink→doom→relief・relief完了0.8秒前・cycleCount=round(total/3)・ドットはcycleCount>=2のみ・CoreHaptics呼吸同期・reduceMotion対応）
- [x] Codex実装（BreathingCharacterView/BreathHapticsController/スナップショットハーネス/単体テスト5本新規）→ BUILD SUCCEEDED・MeasurementFoundationTests 14件0失敗
- [x] Opus5独立レビュー: 仕様準拠は全項目合致・軽微4件（initのエンジン生成/再表示ハプティクスのデッドパス/最終ドット未点灯/タイムライン定数二重定義）→ 全採用でCodex差し戻し → 修正完了・テスト7件0失敗（境界テスト2本追加）
- [x] シミュレータ実描画確認: 吸気(blink+glow)/呼気/relief(全ドット点灯)の3ステージをスクリーンショットで確認（テストランナーのハングが頻発 → シミュレータ再起動・別機種で回避。`-parallel-testing-enabled NO` 推奨）
- [ ] 実機確認（ハプティクスの体感同期・relief transientの強さ・20回介入しても鬱陶しくないか）→ 不足なら中間表情の追加検討

## 2026-08-14 — 炎表現の全削除（オーナー決定・✅ 実装完了・未コミット）

- 経緯: 炎の根元が水平に切れる指摘 → 円弧＋グロー強化で丸い根元を実装・実機3ステージ確認 → オーナー「火の表現の質が悪いから火は全て削除しよう」で撤去に転換
- [x] オーナー確認3点: 呼吸画面=キャラ（ドーパ）常時表示／着火演出=演出ごと削除／`flame.fill`アイコン=`wind`へ置換
- [x] Codex削除実装: `Flame.metal`（Shaders/ごと）・`FlameBreathView.swift`・`FlameSnapshotCapture.swift`削除、介入フロー・オンボーディング・自動化ガイド・テスト4ファイル修正。呼吸タイマーは維持
- [x] 検証: xcodegen成功・BUILD SUCCEEDED・Core 285テスト0失敗・`flame/ignition/着火/炎`残存grep 0件（Swift/Metalのみ対象）・Opus5独立レビュー（コード5観点問題なし）
- [x] レビュー付随指摘の是正: ストアスクショ生成スクリプトの炎合成＋炎コピー3言語を差し替え（審査2.3リスク）・呼吸テストの保証回復・呼吸ティック30fps→250msへ・旧BUILD_SPEC 2本に廃止注記
- 残: スクショ画像の再生成はASC提出前に実施（`/preflight`で確認）。呼吸画面のキャラ余白は実機で要目視（380pt枠に200ptキャラ）
- 注: 炎ステージ機能構想（2026-08-07発案）は前提喪失により実装不可 → 再開はオーナー再判断。design-decisions.mdに記録済み

## 2026-08-14 — 規則A監査「課金したのに有料機能が使えない」コード経路の徹底確認（✅ 監査完了・❌ リリース不可判定・修正はオーナー判断待ち）

- [x] Opus5サブエージェント4体並列監査（インベントリ/購入伝播/フェイルセーフ/復元・ライフサイクル）→ Fableが全Critical指摘をコードで裏取り済み。Core 285テスト0失敗は確認済みだが、失敗経路の回帰テストは存在しない
- 🔴 P0（課金者からProを剥奪する経路・4件連鎖）:
  1. `StoreService.swift:206-249` 取得失敗/空＝無料確定。`catch { continue }`でunverified黙殺・キャッシュなし・失敗でも`hasResolvedEntitlement=true`
  2. `StoreService.swift:220-222` 手動`expirationDate <= now`フィルタがBilling Grace Period中の課金者を即ロック
  3. `AppContainer.swift:714-761` クランプが誤Free判定で発火し対象アプリを1個へ永続削除（復元経路なし）。ガード`hasResolvedEntitlement`は「試行完了」しか意味せず機能不全
  4. `refreshEntitlement()`再入ガードなし。購入直後のscenePhase復帰との並行実行で`isPro`がfalseへ巻き戻る→クランプ発火
- 🔴 P0（ペイウォール訴求と実体の不一致・審査2.3リスク）:
  5. 「Deep Focus」行: `syncShield()`がno-op（`AppContainer.swift:399-401`）・モード切替UI非表示・介入のたび`.standard`上書き（`InterventionFlowModel.swift:168`→`RuleStore.swift:40`）。挙動差は自動化ガイド追記のみ
  6. 「週次レポート詳細」行: `weeklyReportAllowed`参照0件・解放ロジック不在。週次通知は無料にも配信
- 🟡 P1: 購入成功でもペイウォールが閉じない無言経路（`PaywallView.swift:404-416`）／unverified取引がfinishされず毎起動アラート／起動直後の一瞬Free表示（EntitlementTierにunknownなし・`StatsView.swift:53`等）／`.storekit`のgroupNumber逆転（月→年がダウングレード扱いの疑い・ASC実体要確認）／`dopabreak.pro.annual.launch`がペイウォールから到達不能
- ✅ OK確認済み: Restore実装＋配置（スクロール不要位置）・トライアル判定・返金ロック・解約後期限まで利用可・リアクティブ伝播・`.pending`処理・購入の同期即時反映
- [x] オーナー決定: ①全部修正（Codex sol＋Opus5並列。「sol fast」はモデル未対応エラーのため恒久ルールのsol/effort maxで実行） ②訴求2行は**C=両方本実装**（「ディープフォーカルはPro機能だろ」→経緯説明後にC選択）

## 2026-08-14 — 監査指摘の全修正＋ペイウォール2行の実体化（✅ 実装・クロスレビュー・修正まで完了・未コミット・実機検証待ち）

- 設計契約: `.claude/specs/entitlement-failsafe-fix.md`（フェイルセーフ）／`.claude/specs/deepfocus-weekly-implementation.md`（Deep Focus＋週次詳細）
- **WS-A（Codex実装→Opus5レビュー11件→Codex修正）**: StoreService中核。`hasConfirmedEntitlement`新設（到達性の傍証=Product.products非空チェック付き）・App Groupキャッシュ永続化＋起動シード・Grace Period手動フィルタ削除・refresh単一フライト＋追走1回保証＋defer解放・キャッシュPro降格時のsubscriptionStatus/Transaction.latest裏取り・unverified抑制は受動経路のみ・restore失敗時refresh＋Pro優先返却・storekit groupNumber是正（annual=1）
- **WS-B（Opus5実装→Codexレビュー5件→Opus5修正）**: クランプをTargetClampPolicy化（confirmed必須）・単一トランザクショナルバックアップ（original/applied/pending・クラッシュ復旧テスト付き）＋Pro復帰自動復元・通知IDの「confirmedゲートは追加のみ/オプトアウト削除は常時」分割・ペイウォール自動dismiss（initial:true）・RuleStoreモード上書きバグ修正（modeForNewRule化）
- **WS-C（Opus5実装→Codexレビュー→Opus5修正）Deep Focus本実装**: ShieldSyncPolicy純関数（未confirmed=preserve/確定Free=無条件clear=ルール読取前・throw時も到達/確定Pro+deepFocus=apply）・AppContainer.syncShield再配線（refresh()のdefer=先行throwでも必ず同期）・SettingsView完全ブロックUI復活（Free=ロック行→settingsModeGate）・オンボchooseModeのルール到達（throws化・失敗時は遷移しない）・nightOnly封鎖（selectable=[standard,deepFocus]・persistableで.standardへ移行）・シールド文言3言語改訂・**降格は非破壊**（Free中は解除のみ・設定保持・再Proで復帰=2026-08-14 Fable裁定）
- **WS-D（Opus5実装→Codexレビュー→Opus5修正）週次詳細レポート**: `weeklyReportAllowed`初消費。StatsViewにPro専用週次詳細カード（日別積みバー・前週比・a11y対応）・Free=ロックカード→statsHistoryGate流用・StatsService.weeklyDetailReport()（単一アンカーで深夜跨ぎ窓ズレ防止）・日付/タイムゾーン変更/scenePhase復帰で再読込・autoupdatingCurrent化
- 検証（統合後・Fable実施）: **Core 356テスト0失敗・アプリ66テスト0失敗 TEST SUCCEEDED・BUILD SUCCEEDED・lint-display-copy exit 0**
- [ ] 🔴 残（リリース前必須・規則A）: **実機検証**（サンドボックス購入→即時解放・復元・オフライン起動でPro維持・解約/返金・シールド実適用/解除=ManagedSettingsはシミュレータ不可・Deep Focus/週次詳細の実機確認）
- [ ] オーナー確認事項: ASC側のサブスクグループランク（annual>monthly。ローカル.storekitは是正済み）・annual→annual.launchは同期間別レベルのため次回更新扱いになる点

## 2026-08-13 — 法務ページGitHub Pages公開＋ブロッカー①解消（✅ 完了）

- [x] オーナー決定「ドメインじゃなくGithubPagesでいい」→ dopabreak.appドメイン取得は撤回
- [x] `saku1110/dopabreak-legal`（public）作成・Pages有効化: terms/privacy/support×ja/en/ko＋tokushoho-ja＋index=11ページ、全200確認。shapegap-legal/bestswipe-legalと同一パターン。価格は3言語とも記載（KR=₩9,900/₩49,000/₩149,000は同日の価格凍結決定=docs/15 §3.4に基づき追記。「未サインオフ」は旧情報だった）
- [x] `AppURLs.swift` 言語別URL化（preferredLocalizationsでja/ko/en出し分け）＋`AppURLs.support`新設（ASC Support URL用）→ BUILD SUCCEEDED
- [x] design-decisions.md記録済み。Codex独立レビュー実施
- 残: ASCメタデータ入力時にPrivacy Policy URL / Support URLへこのPagesを設定する

## 2026-08-11 — リバーストライアル全廃（✅ 完了・未コミット）

- [x] オーナー問い「Pro機能3日体験の意味」→ Fable×Codex sol 2ラウンド議論＋SOSA/one sec実物ペイウォール検証 → **オーナー決定: 決済不要のPro開放は廃止・Proの入口はStoreKit購入シート（7日intro offer/即購入）のみ**
- [x] 経緯調査（オーナー指摘「なぜ実装したか調べろ・勝手に判断するな」）: docs/15未承認メモ→7/17監査で「確定済み」昇格→7/20バッチ実装、の未承認実装経路を特定。**指摘レジストリに恒久記録**（承認なき新機能・課金導線の実装禁止）
- [x] Codex削除実装（14ファイル・ReverseTrialPolicy+テスト削除・Pro判定StoreKit単独化・7日トライアル無変更）→ Opus5独立レビュー **ACCEPT WITH FIXES** → 指摘裁定（docs残存記載2件是正・UserDefaults残骸は未リリースのため不採用）→ **213 Coreテスト0失敗・BUILD SUCCEEDED**（Fable独立検証）
- [x] 正本反映: docs/15 §1・docs/11 §18廃止注記・i18n-launch-inventoryキー行削除・design-decisions.md・メモリ
- [x] 追加オーナー決定2件実装（同日）: ①**初回14日3アプリの時限開放廃止**（無料=常に1個・Day12/14警告通知削除・クランプはPro失効用に維持・旧通知識別子の一掃つき）②**ペイウォール機能リスト4→6行**（Deep Focus行・週次詳細レポート行を3言語追加）。Codex実装→Opus5レビューACCEPT WITH FIXES→P2差し戻し修正→**234テスト0失敗・BUILD SUCCEEDED**。docs/11・12・18・i18nインベントリ整合済み
- [ ] オーナー判断保留: one sec年額¥1,990（DopaBreakの2.5分の1）を踏まえた¥4,980維持/A/B前倒し（Fable進言=当面維持）
- [ ] オーナー報告済み・判断待ち（軽微）: ペイウォール「Deep Focus」とアプリ内モード名「ディープフォーカス」の表記揺れ統一
- [ ] 🔴 リリース前必須（規則A連動）: Deep Focus行を課金訴求に載せたため、実機でのDeep Focus解放確認（MVPでは観測差分が白黒案内中心）をBlock A表に追加

## 2026-08-11 — 継続率通知＋レビュー誘導タイミング設計（✅ 設計完了・実装待ち）

- [x] 現状実査: 通知9本実装済み（朝/週次/Day14/トライアル5日目/1ヶ月/12ヶ月更新/D1/時間切れ/中間チェックイン）・pre-permission✅。**レビュー誘導は完全未実装**（preflightブロッカー③と一致）
- [x] 設計書作成 → **`docs/18_retention_notification_review_design.md`**（正本）: レビュー誘導=勝ち画面`.win`+1.5s・累計5回/3日経過/90日間隔/年3回ゲート・満足度ゲート禁止／深夜帯制御9:00-21:00（one-shot繰り延べ）／オプトアウト2トグル新設（継続サポート/プラン通知）／D3再挑戦・D7未活性フォールバック・休眠30日win-back／通知タップ着地先ルーティング／フィードバックmailto導線
- [x] 追加設計（オーナー依頼 2026-08-11 第2弾）: ①**解約率低減マップ**（利用時間ウォッチ/月次レポート恒常化=1回きり→毎月/炎ステージ昇格通知/年額移行オファー/willAutoRenew解約検知→期限3日前セーブ通知1回/Billing Grace Period・計測ゲート=月次解約8%未満/1年更新40%/トグルOFF率監視） ②**利用時間ウォッチ**=DeviceActivity閾値イベントで「介入なしでも合計N時間で警告通知」。**技術確定: entitlement承認済み・MonitorExtensionスケルトン・許可導線・Picker永続化すべて資産済み**。残実装=startMonitoring+Extension内通知のみ。実機検証必須
- [x] 利用時間ウォッチ設計確定（オーナー決定 2026-08-11）: **Free=連続2時間で1日1回警告／Pro=15分ごと問いかけ（カスタム10/15/30分・エスカレーション・1日8回上限・夜間モード=就寝前間隔半分）**。主軸=利用量・時間帯は修飾子。実現方式=15分刻み閾値イベント梯子1本を両プラン共用（連続判定は発火間隔≦20分の連なり・±15分近似）。コピーは「事実か問いのみ」（「今日は勝ち」等の曖昧表現禁止→メモリ・design-decisions記録済み）
### 実装進捗（2026-08-11・オーナー指示で一旦停止・後日再開）

- [x] **Batch 1 完了・受け入れ済み**（Codex実装→Opus5独立レビュー→Codex修正→Fable受け入れ）: レビュー誘導（勝ち画面`.win`+1.5秒・`ReviewPromptPolicy`＝累計5回/3日/90日/年3回/失敗直後5分ブロック）・`NotificationQuietHours`（9-21時・繰り延べのみ）・オプトアウト2トグル（継続サポート/プラン）・月次レポート恒常化（1回きり→毎月）・フィードバックmailto導線
  - Opus5指摘 P1×1・P2×3・P3×6 → 8件修正。**P1=深夜帯購入ユーザーの月次レポートが毎月消える**（anniversary選択が深夜帯繰り延べを考慮せず、繰り延べ窓中にアプリを開くと翌月へスキップ）→ `nextMonthlyReportDate`をQuietHours考慮へ是正＋回帰テスト。他: `oneShotTrigger`のGregorian固定（和暦端末で発火不能だった）・復元/購入の「失敗」誤判定でレビュー恒久ブロック→5分タイムボックス化・`reviewPromptEventDates`をreset対象外へ
  - Fable独立検証: BUILD SUCCEEDED・Core 213テスト0失敗を自ら再実行・修正箇所スポットチェック済み
- [x] **Batch 2 完了・受け入れ済み**（Codex実装が中断→Opus5が仕上げ検証と是正）: `UsageWatchPolicy`(284行)・`UsageWatchStore`・MonitorExtension実装・`UsageWatchController`・設定UI・3言語19キー・project.yml配線
  - Opus5が重大欠陥5件を検出・修正。**D1=起動/entitlement更新/設定表示のたびに`startMonitoring`再登録され当日の梯子進捗がゼロリセット**（Freeユーザーは事実上一生2時間に到達しなかった）→ `isMonitoringActive`ガード導入。**D3=Pro質問が15分ごとに永久発火し「また1時間たちました」が75/90/105分でも出て事実と矛盾＋1日上限8回を2時間で使い切り**→ 60分以降は`max(interval,60)`へ位相変更。他: ピッカー無変更クローズでもリセット/`startMonitoring`失敗が不可視/言語変更時の通知カテゴリ重複
  - 検証: BUILD SUCCEEDED・Core 234テスト0失敗（UsageWatch 24件）・アプリ61テスト0失敗・lint exit 0・禁止2ファイルSHA一致
- [x] **Batch 3 完了・受け入れ済み**（ワークフロー8エージェント: 実装→4観点並列レビュー→敵対的検証→修正→最終ゲート）: D3再挑戦・D7未活性フォールバック・年額移行オファー（月額90日・一生1回）・解約セーブ（`willAutoRenew`false→期限3日前・請求期間ごと1回）・通知タップ着地ルーティング（Core `NotificationRouting`に一元化）
  - 新規Core: `ActivationNotificationPolicy`（D1/D3/D7）・`SubscriptionNotificationPolicy`（年額オファー/解約セーブ）・`NotificationRouting`（識別子→着地先の単一正）
  - 敵対的検証で17件確定・全件対応。**P1×2**: ①解約セーブがウォーム復帰ユーザーに永久に届かない（`willAutoRenew`は`refreshEntitlement()`でしか更新されず、プロセスが生きたままだと解約検知不能）→ `refreshEntitlementOnForeground()`新設 ②オンボ通知見出しに廃止語彙が残存 → 是正＋**linterを全キー・全言語・全4カタログの禁止語スキャンへ拡張**（今後の再発を機械検出）
  - 実装者が1件を**反証して不採用**（年額オファーの「未配信なら再送」案＝バナー無視ユーザーへ何度も再送するバグに化ける。ロジックを読んだ上での判断として受理）
  - Fable独立検証: **Core 273テスト0失敗を自ら再実行**・禁止2ファイルSHA一致・P1修正の実在確認（AppContainer:413/RootTabView:205）・新8キー×3言語完備
  - 副産物: `app.day14_clamp.notice`は**死にコピーではない**と判明（Pro失効クランプの説明として現役・キー名だけがレガシー）。Day14通知は復活していない（レガシー識別子は掃除専用）
- [ ] **🔴 オーナー判断（docs/18 §4末）**: 月次レポートは「次の1回」しか予約されず、**アプリを開かなくなった購読者には以降届かない**。案A=反復トリガー追加（ただし本文は件数なしの固定文になる）／案B=現状維持＋利用時間ウォッチが代替になるか計測。判断が出るまでコード不変
- [ ] 未着手（P3）: 休眠30日win-back・Statsへの実測利用時間グラフ（DeviceActivityReport・表示専用）
  - 炎ステージ昇格通知は**バックログから削除**（オーナー「いらない」2026-08-13・並行セッション経由で共有）
  - [x] 新規要件「無料ユーザー向け月次レポート通知」**実装完了・受け入れ済み（2026-08-13・課金導線バッチ担当セッション）**: FreeMonthlyReportNotificationPolicy（無料のみ・month1と排他・月周年ladder3本=直近1本実数/以降固定文/0件時は全て固定文・休眠者へ最大3通・QuietHours・継続サポートトグル・着地=Stats）。Codex実装→Opus5レビューACCEPT WITH FIXES→P2(0回/0回通知)修正→**Core 285テスト0失敗・BUILD SUCCEEDED**・新ポリシーカバレッジ100%。残=実機発火確認（規則B・他通知と同枠）・未コミット
- [ ] **🔴 全Batch共通の残**: 実機発火確認（規則B: 設計＋実装＋実機の3点揃って初めて✅）・確定文言のdocs/11転記・利用時間ウォッチはシミュレータ検証不可のため実機必須

## 2026-08-10 — 実機レビューセッション是正（ガイド刷新＋キャラ統一＋ロック確認2ステップ）（✅ 実装完了・未コミット・実機再インストール待ち）

- [x] one sec実録画（`video/onesec/`）を根拠にAutomationGuideViewをone sec水準へ刷新（Codex実装）: 進捗n/m・ヒーローCTA・7ステップSwiftUI図解・アプリ別✅・scenePhase復帰再読込・Phase 2動画カード枠（flag off）
- [x] キャラ5段トークン化（hero200/lead152/header120/support88/inline44・10画面写像）＋ホームheroBand縦積み化（TODAY行→12pt→キャラ→20pt）＋ロック確認のサイドボタン物理位置合わせ廃止→番号2ステップ＋簡略端末図（Codex実装）
- [x] Opus5一括独立レビュー: P1×1（ガイドが実在しないアクション名「一呼吸を開始」を探させる→実名「DopaBreakで一呼吸」へ是正）・P2×2（「新規の空のオートメーション」段欠落→7ステップ化・未設定パラメータは「アプリ」表記）・P3×6（装飾枠比率/読込エラー区別/ショートカットApp欠落アラート/バッジコントラスト/許可注記コントラスト/行内キャラのTimelineView静止化）全採用＋既知ブロッカー（count_unit enの日本語メモ→"times"）同時是正 → Codex修正完了
- [x] 検証: BUILD SUCCEEDED・アプリ50＋Core204=254テスト0失敗・xcstrings 493キー3言語完備・禁止2ファイルSHA一致・Fableスポットチェック（ガイド手順とIntent実名の一致確認）
- [ ] **実機再インストール**: iPhone接続切れで保留（接続され次第ビルド→インストール）
- [ ] オーナー保留: 視差効果を減らすのオン/オフ確認（推計カウントアップの切り分け。シミュレータ実写では回っている＝コード健在）

## 2026-08-10 — Phase 2完遂: チュートリアル動画3言語内製＋PiP＋白黒モード案内（🔄 最終レビュー中・未コミット）

- [x] **動画内製パイプライン確立**（オーナー指示「録画あなたがやって」「シミュレータでできるでしょ」→内製へ切替）: iOS 26.5シミュレータ＋AXe＋simctl recordVideoで実操作を録画。ロケール切替で3言語量産（ja 34s/0.93MB・en 39s/0.74MB・ko 34s/0.70MB）。mpdecimateで静止区間自動圧縮。詳細は design-decisions.md「チュートリアル動画の内製パイプライン確立」
- [x] **録画過程でiOS 26実表記を全段実証**: アプリ／開いている・閉じている／すぐに実行／**新規ショートカットを作成**（前回修正の「新規の空のオートメーション」は誤りと判明）／アプリ一覧からDopaBreak選択が確実（日本語IMEで検索破壊を実測）／右上チェックで完了
- [x] Codex実装3連: ①ja動画同梱＋PiP（canStartPictureInPictureAutomaticallyFromInline・AudioSession mixWithOthers・UIBackgroundModes=audio・RM時は再生ボタン）＋文言12キー実表記統一 ②白黒モード任意セクション（Deep Focus選択者のみ・カラーフィルタ2オートメーション＋サイドボタン3回押し代替・Apple公式ko/en表記照合済み） ③en/ko動画同梱＋ロケール出し分け純関数＋テスト
- [x] 各実装でBUILD SUCCEEDED・全テスト0失敗・禁止2ファイルSHA一致を確認
- [x] Opus5最終独立レビュー: H1（復帰時PiP未停止→黒箱）・M1（自動PiP常時武装＋prepareForExternalTransitionデッドコード）・M2（LazyVStackスクロールで再生破棄・巻き戻り）・M3（audio宣言は**削除不可**とApple公式4箇所で確定→Review Notes整備へ）・L×4。健全確認: 音楽非中断・3動画バンドル解決SHA実測・xcstrings 512キー機械検証・Deep Focus判定・Locale.currentのAPI選択が正
- [x] 採用8件Codex修正完了: PiP武装はCTA直前のみ・完全解放はルート閉鎖時のみ・審査官向けReview Notes文面をdocs/10へ追加・プレイヤー失敗時は図解フォールバック等。**アプリ56＋Core204=260テスト0失敗**
- [x] Fable受け入れ: BUILD SUCCEEDED・Core204を自ら再実行0失敗・PiP武装/停止経路のコード確認・禁止2ファイルSHA一致 → **Phase 2完了（未コミット）**
- [ ] 実機インストール（iPhone接続待ち）・実機でのPiP実挙動確認（シミュレータでは自動PiP非対応のため実機のみ検証可）

## 2026-08-10 — オンボーディングCTA全面動詞化（✅ 完了・未コミット）

- [x] オーナー指示「なるほど等のフィラー排除・動詞化・CVR最大化」。sales-copywritingスキル適用でFableがコピー確定・直接実装（文言のみの変更）
- [x] 変更7キー（ja/en/ko）: welcome→30秒でチェックする／次へ→次に進む／quizResult→この時間を取り戻す／goalSetup→この目標で進む(新キー)／preview→この仕組みを使う／whyScience→仕組みに任せる(新キー)／prePaywall→この時間を守る(新キー)。ペイウォール・chooseApps等は既に動詞型のため不変
- [x] humanizer-en/ko audit両ゲートexit 0・xcstrings JSON妥当・「なるほど」全消去・共有キー参照整合確認。Opus5独立レビュー実施。詳細は design-decisions.md 2026-08-10 CTAエントリ

## 2026-08-10 — コミット前レビュー是正バッチ（✅ 完了・未コミット）

- [x] /code-review（未コミットdiff 44ファイル＋新規Swift 5本）: 指摘5件 → Fable裁定で採用4・却下1（GoalEditorSheetの16字切り詰め=文書化済みの意図的設計・未リリースでレガシーデータ実害なし）
- [x] Codex実装（gpt-5.6-sol max）: ①自動ロック画面確認を`liveActivityEnabled`でゲート（無断で設定を覆しLive Activityを出す0タップ経路を閉塞） ②ロック確認dismiss＋介入presentのトランザクション分離 ③`animatesFlare: false`を連続値2箇所へ ④CharacterView 30fpsキャップ
- [x] Opus5独立レビュー: 4指摘 → 採用2（②の再入穴=遅延フラグ`interventionAwaitingLockDismiss`導入／ロック確認onDismissにmid-session・reflection再評価追加）・却下2（pending永続化=2026-07-25却下事項と矛盾／breathPhase二重補間=意図的フレームブレンド・非可視）→ Codex差し戻し修正完了
- [x] Fable受け入れ: BUILD SUCCEEDED・Core 201テスト0失敗を自ら再実行。禁止2ファイル（FlameBreathView/Flame.metal）SHA一致。詳細は design-decisions.md 2026-08-10 の2エントリ
- 変更ファイル: RootTabView / AppContainer経路はRootTabView側ゲートで対応 / OnboardingMotion / InterventionFlowView / CharacterView

## 2026-08-08 — O-02利用時間バケット上位分割（✅ 完了・未コミット）

- [x] オーナー指摘: 推計上限4.5h/日は現代のヘビーユーザーに過小 → 選択肢を5択化（4〜6時間→300分/76日/10.4年・6時間以上→390分/99日/13.5年）。旧「4時間以上」→270分は保存済みデータ互換のため受理のみ継続
- [x] Codex実装（gpt-5.6-sol max）: LossEstimator＋OnboardingFlow＋xcstrings(ja/en/ko)＋テスト＋docs/07＋design-decisions＋i18nインベントリの8ファイル
- [x] Opus5独立レビュー: バグ0。参考指摘3件（docs/07の中央値記述の不正確・xcstrings死にキーfour_plus_hours・docs/05コメント旧記述）→ Fableが直接修正（軽微なドキュメント/キー整合のみ）
- [x] Fable受け入れ: Core 201テスト0失敗を再実行・xcstrings JSON検証・option系キー5件確認
- 補足（依頼外・報告のみ）: オンボQ2/Q3の回答はSnapshotに保存されるだけで未活用。ペイウォール/通知の出し分けに使う余地あり

## 2026-08-08 — 目標入力一本化＋着火演出（✅ 完了・未コミット）

- [x] 設計確定（オーナー決定4件）: 単一フィールド16字・複数追加・常時種火→着火演出・編集シートも同構造。詳細は design-decisions.md 2026-08-08「目標入力の一本化」
- [x] Opus5サブエージェント実装（Codex使用量上限のためフォールバック適用）: BUILD SUCCEEDED・禁止2ファイルSHA一致・着火の根元描画をキャプチャ確認
- [x] Codex独立レビュー: P1×2＋P2×4検出（.goalsLimitペイウォール永久ループ／三者差分化／IME trim破壊／着火中の操作窓／非トランザクション保存）。P2「編集導線なし」は却下→バックログ
- [x] 採用5件修正（Opus5）→ Codex焦点再レビュー（残1件P2・独立でビルド＋全テスト再実行0失敗）→ 最終サイクルで三者差分の外部削除分岐＋旧設計死コード削除（goalInputBlock/categoryBlock/旧trim）
- [x] Fable最終受け入れ: BUILD SUCCEEDED・Core201テスト0失敗を自ら実行・GoalEmber残参照0・onChange書き戻し残骸0・xcstrings 460キー往復一致・SHA-256一致
- [x] i18nインベントリ更新（460キー・新規4キーはja/en/ko同梱）・lessons.md追記（JSONSnapshotStoreミリ秒精度flaky）
- 最終テスト数: アプリ50＋Core201=**251件0失敗**。バックログ: オンボ保存済み行の編集導線（削除→再追加で代替可・Goal.id永続参照が生まれたら再検討）

## プロジェクト情報
- **プロジェクト名**: **DopaBreak**（2026-07-02承認・旧仮称LifeFocus・docs本文リネーム済み）— SNS依存改善iOSアプリ
- **最終更新**: 2026-07-20（**監査バグB1-B14全件＋CVR施策C1-C5＋R1完遂**。後半=R1可視化・C5トライアル防衛線・週1提示・C4リバーストライアル3日→一括レビュー7件全採用是正（ペイウォール・オーケストレーション一元化・通知世代競合・willAutoRenew分岐等）。**192 Coreテスト0失敗・BUILD SUCCEEDED**（Fable独立検証）。監査残=C6日本向け長文ペイウォール・C7小粒群・R2-R7・計測基盤優先4-7・オーナー判断待ち構造提案）

## 2026-07-29 — O-03r損失回避の人生年数換算（完了）

- [x] オーナー指示「人生で何年失う」文言を推計結果画面へ実装。「10年で約N日」を「このままなら50年で 人生の約{N}年」（1.5/3.1/5.2/9.3年・切り捨て）へ置換。3言語確定（EN/KO humanizer exit 0）・Core 196テスト0失敗・BUILD SUCCEEDED・Codexレビュー通過。詳細は design-decisions.md 同日エントリ
- [x] オーナー指摘によりリズム読点5件を全廃（「この時間を、変える」等→読点なし）・恒久ルール化（CLAUDE.md/レジストリ/メモリ記録済み）。構造的読点3件は意図的維持。BUILD SUCCEEDED。詳細は design-decisions.md 同日エントリ
- ⚠️ 依頼外発見（未対応）: `home.achievement.count_unit` en値に日本語作業メモが「translated」で混入（別セッションi18n作業の残骸・英語UIに表示される）

## ⚠️ 2026-07-17 監査による訂正（本ファイルのstale項目）
- ペイウォール2段化は**7/15にCodexアプリで実装済み**（残=Lifetime設定画面導線のみ）。7/12 Codex指摘は8件中2件修正済み・6件未修正（監査レポート§1）
- 「モノクロShortcuts設定」オーナー作業は機能削除済み（7/11）のため実行不能。「実装(11) Live Activity未実装」記述はWP2完了（7/10）と矛盾＝実装済みが正。backlog(9)(10)(11)も実装済み未チェック
- 新規の重要検出: 設定にプライバシー/データ削除がない（FR-605 Must違反・審査ブロッカー級）・ペイウォール「38日」固定・Day14クランプ無告知・ペイウォール機能行の空約束（統計/継続記録）。詳細と優先順位はレポート参照

## 進捗サマリー
| フェーズ | 状態 | 進捗 |
|---------|------|------|
| Phase 0: 整合・事実確認 | ✅ 完了 | 100% |
| Phase 1: 設計成果物 | ✅ 完了 | 100%（08_widget_guideモック改訂のみ残） |
| Phase 2: 実装（Codex委譲） | 🔄 進行中 | 65%（(1)-(6)(7)-(10)中核(13前半)完了・**88テスト0失敗**） |
| Phase 3: 品質・レビュー | 🔄 進行中 | 40%（2026-07-12 Fable検証＋Codex独立レビュー完了・指摘対応残） |
| Phase 4: マーケ成果物 | 🔄 進行中 | 10%（02c実行計画=インパクト順の正本を作成） |

## 2026-07-27 — ネイティブUI化（完了・オーナー決定2件）

オーナー決定: ①**ブランド維持＋中身をネイティブ化**（完全ストック外観は却下） ②**Xcode 26.6 / iOS 26.5 SDK へ切替**（deployment targetは17.0据え置き）。詳細は `.claude/specs/design-decisions.md` の同日エントリ。

- [x] **ツールチェーン切替の互換検証**: Xcode 26.6 で全7ターゲット BUILD SUCCEEDED。Metal Toolchain を別途取得（`xcodebuild -downloadComponent MetalToolchain`・`Flame.metal` に必須）
- [x] **潜在バグ1件修正**: `DopaBreakActivityAttributes.swift` のガードが `#if canImport(ActivityKit)` のみで、macOSでは`ActivityAttributes`が使えないのに素通りしていた → `&& !os(macOS)` を追加。Swift 6.2（Xcode 26.6）でコンパイルエラー化して発覚。**切替による退行ではなく元からの誤り**
- [x] **Dynamic Type 全面対応**（design-decisions 2026-07-12「最重要a11y」として未処理だった項目）: 固定pt 168箇所を `.dopaFont()`（`@ScaledMetric`）へ移行。字間11・行間24箇所も引数へ畳み込み拡縮に追従。**既定文字サイズでの見た目は不変**
- [x] **自前タブバー廃止 → システムTabView**: iOS 26のLiquid Glass素材・選択インジケータ・ホームインジケータ間隔が標準で入る
- [x] **自前ScreenHeader → `.navigationTitle`**（Goals/Stats/Settings）: 書体だけ `UINavigationBar.appearance()` でE1に上書きし、背景は既定のままスクロール端素材効果を維持。Homeは朝焼け帯がヘッダーのため大見出しなし
- [x] **ネイティブ挙動**: `DopaMotion`（臨界減衰既定・跳ねは達成時のみ）・`.sensoryFeedback`（勝ち/失敗/時間選択のみ）・`.contentTransition(.numericText())`・`.symbolEffect`・`.safeAreaInset` 固定CTA・`.scrollBounceBehavior`・reduce motion対応
- [x] **a11y**: 設定行のディスクロージャ記号（design-decisions 2026-07-12の未処理項目）・テーマチップの当たり判定38→44pt・`.isSelected`トレイト・メトリクスの読み上げ結合
- [x] **Codex独立レビュー**（gpt-5.6-sol / xhigh）: 7観点中6観点「問題なし」、1件の実バグ（CTAなし画面での30pt空インセット）を検出 → `stepScaffold(hasAction:)` で是正
- [x] **検証**: アプリ21テスト・Core 193テスト 0失敗（Xcode 16.2 / 26.6 両方）。iPhone 17 Pro（iOS 26）でHome実機確認＋`NativeChromeSnapshotCapture` で Goals/Stats/Settings を既定サイズとAX3で撮影 → `output/screenshots/native-pass/`

**残（今回スコープ外・要判断）**:
- [ ] 拡張ターゲット（Widgets 18箇所・ShieldConfig）は `DesignTokens.swift` を共有していないため固定ptのまま。対応するなら共有ファイル化が先
- [ ] Stats初日の巨大「—」（design-decisions 2026-07-12で既出の未処理項目・今回のAX3スクショでも確認）
- [ ] PaywallView の CTA固定ボトムバー化（design-decisions 2026-07-12でモック承認待ちのため未着手）

## タスク一覧（Phase 2・2026-07-02開始）
- [x] docs本文一括リネーム LifeFocus→DopaBreak（商品ID `dopabreak.pro.*`・App Group `group.com.dopabreak.shared`・履歴行は維持）
- [x] **FamilyControls entitlement申請パッケージ作成 → docs/10**（フォームURL・4件分の貼り付け英文・手順15分）
- [x] entitlement申請の送信 → **承認済み（2026-07-03・Team単位・即日）**
- [x] **オーナー作業完了（2026-07-08）**: App Group＋5 App ID登録→4 App IDでFamily Controls (Distribution)＋App Groups有効化（docs/10 §3）→ **FamilyControlsのポータル作業は全完了・提出ブロッカー解消**
- [x] ios/ scaffold（xcodegen・5ターゲット＋DopaBreakCore・ビルド/テスト/entitlements検証済み）
- [x] 実装(1) App Group＋ローカル保存（28テスト・カバレッジ90%）
- [x] 実装(2) 目標作成＋4タブUI（シミュレータ動作確認済み・UI文言はdocs/11正本から転記）
- [x] 実装(7)-(10)中核ロジック: InterventionEngine＋StatsService（Opus並列・96%カバレッジ・intent跨プロセス永続化済み）
- [x] 実装(13前半) オンボーディング14ステップ（doc07転記・損失顕在化クイズ→年N日リビール・シミュレータ通し確認・**73テスト0失敗**）
- [x] **FamilyControls entitlement 承認済み**（2026-07-03・Team単位・即日）
- [x] **実装(3)-(6) FamilyControls配線**（2026-07-08・Codex実装＋Codexレビュー3件是正済み・88テスト0失敗・BUILD SUCCEEDED）
  - RuleStore新規（Core・FamilyControls非依存・15テスト）／ScreenTimeCenter＋ShieldController（アプリ層）／Settings画面に許可導線・FamilyActivityPicker・トグル・モード選択／ShieldConfigurationExtension静的UI（doc11 §6b転記）
  - シールド同期はfail-safe設計（rules.json読取失敗時は既存の保護を維持）
- [ ] **🔴 オーナー実機検証（次回・iPhone接続15分）**: 技術検証①カスタムシールド表示 ④Extensionのsnapshot読取 ⑤Widget/Shield同一目標表示 — Settings→スクリーンタイム許可→止めるアプリ選択→対象アプリを開いてシールド確認
- [x] **実装(12) StoreKit 2＋ペイウォール**（2026-07-08 Codex実装＋Fable検証・99テスト0失敗・BUILD SUCCEEDED）
  - EntitlementGate（Core純粋ロジック・StoreKit非依存・100%テスト）／StoreService（StoreKit2: 購入/復元/currentEntitlements/updatesリスナー）／PaywallView（3段doc06§10文言・禁止語是正済み）／DopaBreak.storekit（4商品・P1Wトライアル・scheme参照）
  - 配線: AppModel/Settings(Pro状態+復元)/Onboarding(あとで可)/Home年目標ゲート
  - 品質ゲート完了: Codex実装→Fable検証→Codex独立レビュー(6件指摘)→Fable裁定(4件採用/2件は仕様誤読で却下)→Codex修正→Fable再検証。99テスト0失敗・BUILD SUCCEEDED
  - 採用修正: ①トライアルCTAを対象者のみ(3.1.2) ②法的文言を年/月/買切で出し分け(doc11§5追記) ③deepFocus厳格モードをProゲート ④ShieldController適用層でFree制限強制 ⑤復元対象なし時フィードバック＋P1W→7日間換算
  - 却下(仕様通り): GoalsViewの1年目標「Proで表示」バッジ表示・Freeの1年目標保存（doc05§445 保有効果）
  - 既知の軽微残: サブスク失効の適用層再クランプは次回syncShield時(次回起動/再認可)。ローンチ非ブロッカー
- [x] **実機ビルド・インストール成功（2026-07-08）**: Team ID是正 `C76D9UB7AV`（Toshiki Sakuraya個人。34FRXY33CGは古い別チーム=Fable誤設定だった）→ BUILD SUCCEEDED → iPhone 16 Proへインストール・起動確認
- [x] **🔴 方針転換（2026-07-08 オーナー実機フィードバック→docs/12新設）**: シールド静的画面はオーナー想定と乖離 → **方式C: ハイブリッド承認**。さらにMVPスコープ確定=①目標はフラット複数リスト（人生/1年廃止・Free1件/Pro無制限）②介入=one sec方式一気通貫（オートメーション→自動起動→呼吸アニメ→N回目→目標→理由→復帰/勝ち→時間切れ通知→振り返り）③完全ブロック(シールド)はv1.1保留・コード温存
- [x] **MVPピボット実装完了（2026-07-08）**: Core層=Codex実装（113テスト）／アプリ層=Opusサブエージェント実装（6新規ファイル1034行: StartInterventionIntent/InterventionFlowModel/InterventionFlowView/PostUseReflectionSheet/TargetAppPickerSheet/AutomationGuideView＋AppContainer/GoalsView/HomeView/SettingsView/OnboardingFlow/DopaBreakApp/RootTabView/PaywallView/project.yml改修）
- [x] **モノクロ設定のユーザー設定拡張（2026-07-10・オーナー承認スコープA+B）**: A=モノクロ時間帯の自由設定（SettingsStore新キー grayscaleStart/EndMinutes・設定画面に新セクション「画面のモノクロ化」・ガイド文言を時間帯ベースへ改訂）／B=対象アプリの間だけモノクロ（AppGrayscaleAutomationGuideView新規・開かれたとき→ON/閉じられたとき→OFFの2オートメーション案内）。docs/11 §4e改訂＋§4f新設。**125テスト0失敗・BUILD SUCCEEDED**。実装=Fable直接（Codex使用量上限のため・オーナー承認済み例外）。Codex独立レビュー完了（3件指摘→全採用: グレイスケール前提手順カード「はじめに一度だけ」・色覚補助/併用の注意・同一時刻警告。修正済み）
- [x] **WP1: オートメーション検収＋初回14日3アプリ（2026-07-10 Codex実装→Fable検証）**: `verifiedAutomationCatalogIDs`（Intent実発火=検収の真実ベース判定）・ガイドにアプリ別「設定済み/未確認」バッジ＋アプリ別テストボタン・`firstLaunchDate`・EntitlementGate=Free 14日未満3/以降1（now/firstLaunchDate注入・境界テスト済み）
- [x] **WP2: 実装(11)ロック画面（2026-07-10 Codex実装→Fable検証）**: LockTheme7テーマ＋Proゲート・朝の目標通知（全目標列挙・目標0件は登録なし）・週次通知・Live Activity（全目標＋今日の実績・Dynamic Island・8時間対策）・Home Widget Small/Medium・設定「ロック画面の表示」セクション・NSSupportsLiveActivities・docs/11新§追記
- [x] **WP3: ローカル計測イベント（2026-07-10）**: FunnelEventStore（App Group JSON・4イベント・5000件キャップ・外部送信なし）・フック=オンボ完了/検収/ペイウォール表示/購入・DEBUG限定エクスポート
- [x] **WP4: Codex総合レビュー7件→6件採用・修正（2026-07-10）**: ①14日経過時の保存済み選択をゲート上限へクランプ ②週次通知=無料と確定（doc05修正・Pro=詳細分析） ③週次通知を単発・毎回再登録方式へ（本文の陳腐化解消） ④⑤Intent書き込みをpendingキー1本に限定し検収マーク/イベント記録を本体消費点へ移動=単一ライター化（プロセス間競合根治） ⑥Live Activity更新の単一フライト化＋全経路で最大1件保証 ⑦doc05 §11をローカル4イベントに整合。指摘1前半（Shortcuts直接設定でのFreeゲートすり抜け）は2026-07-08オーナー受容済み既知制約のため対象外。**最終: 139テスト0失敗・BUILD SUCCEEDED（7ターゲット）**
- [x] **2026-07-12 Fable検証セッション（モック→SwiftUI実装の確認）**: 144テスト0失敗・BUILD SUCCEEDED（xcodegen＋simulator）・シミュレータ実起動OK（Welcome/Home/URLスキーム`dopabreak://intervene`→介入フロー・direct目的の呼吸スキップ→時間選択の動作をスクショ確認=output/screenshots/verify-0712-*.png）。design-qa.md「passed」の主張と実装は概ね整合。DesignTokensのbg/cardがE1スペック値と1〜2階調ずれ（#0B0D0F vs #0A0B0D等・目視不可のP3）
- [x] **Codex独立レビュー指摘対応（2026-07-12→2026-07-24解消）**: 2026-07-24のコミット前レビューで再照合し、High3件のうち①②は既に閉塞済み・③(再入ガード)が`start()`ライフサイクル再入で未閉塞と判明→**#1-6を修正しコミット**（①`start()`冪等化=世代トークン＋breathTask再startキャンセル＋呼吸完了stageガード ②Day14通知タップ保留フラグをentitlement未解決時に保持 ③通常再予約でdelivered通知を消さない ④Day14フォールバックをday14Boundary前に限定 ⑤通知権限の非同期取得を確定拒否として誤用しない ⑥D1取消を全体notificationGenerationから分離）。回帰テスト2件追加（start()再入・Day14境界）。**残**: 旧Medium=スキップ時の未保存目標露出（M2）/Low=Home日付日跨ぎ は未再検証（軽微・別途）
- [ ] **オーナー判断待ち（未実装・意図的）**: ①介入フロー1画面短縮（ディベート推奨だがdoc12承認フローと矛盾するため保留） ②doc13コピー刷新の承認（メインコピー選定・「開かずに我慢」→「開かずに戻れた」等の置換）**※注: 7/11実装のHomeView・介入フロー勝ち画面は未承認のdoc13案文言（開かずに戻れた/開かなかった等）を先行使用中。doc11正本（開かずに我慢/開かずに戻る）と乖離 → doc13承認してdoc11改訂 or 実装を正本に戻すの二択**
- [ ] **🔴 オーナー実機作業**: 実機一気通貫テスト（オートメーション設定→介入→検収バッジ確認）・朝/週次通知・Live Activity/Widget/テーマの実機確認・モノクロShortcuts設定
  - Fable独立検証: 113テスト0失敗・実機ビルドBUILD SUCCEEDED・目標「全件箇条書き」表示確認・エンジン状態遷移がdoc05と一致・データ移行テストあり・Codexの代わりにFableが7項目セルフレビュー（競合状態/状態機械誤用/データ整合性/ゲート/通知/URL/並行処理）でブロッカーなし確認
  - 既知の制約1件をbacklogへ記録（Free=1個ゲートはiOS Shortcuts側で技術的にすり抜け可能・実害軽微）
  - Codex独立レビューは利用制限中(回復18:39)のためスキップしFable単独検証で完了
- [ ] 実装(11)ロック画面（Live Activity未実装=オーナー指摘済み）・(7)(8)旧シールド配線はv1.1へ → backlog.md 参照
- [x] **起床/就寝の時間帯検知＋画面を自動でモノクロにする設定ガイド（2026-07-09・オーナー依頼）**: 計画=`.claude/plans/crystalline-imagining-shannon.md`／文言=docs/11 §4d・§4e・§8。Core新規`DayTimeContext`（起床窓+30分・就寝窓-60分をmod 1440演算で判定）／SettingsStoreにwake/bedTimeMinutes／S-02バナー／新規`GrayscaleAutomationGuideView`（AutomationGuideViewと同パターン・shortcuts://連携。**Appleはシステム全体モノクロの自動制御APIを提供しないため初回手動設定＋以降自動のショートカット方式が唯一の実現手段**）／Settings画面に起床・就寝時刻セクション。品質ゲート=Codex実装→Fable検証（起床窓バグ1件発見・是正）→Codex独立レビュー（デフォルト値未コミット1件検出・是正）→再検証。**124テスト0失敗・BUILD SUCCEEDED**。オーナー実機での動作確認・Shortcuts自動化の手動設定は未実施（次回オーナー作業）

## タスク一覧（Phase 4・2026-07-03着手）
- [x] **02c_marketing_impact_plan.md 作成**（インパクト順・Tier S/A/B/C・許容CPI/CPT・90日カレンダー・テスト6件・予算3シナリオ）
- [x] **docs/15_pricing_design.md 作成（2026-07-11）**: SOSA 2026ベンチマークで価格設計を検証・確定。フリーミアム/7日トライアル/年額¥4,980は支持。KPI3段目標（P50/Q3/P90）設定
- [x] **価格改定オーナー承認・反映（2026-07-11）**: ①月額¥980確定（.storekit反映済み） ②ペイウォール2段確定 ③LTV基準40%でdoc01 §8-2/8-3改訂（CPI許容¥140→¥100） ④米国価格=月額$9.99（1.5倍・NA中央値）/年額$39.99+$49.99A/B/Lifetime $119.99
- [x] **実装（Codex委譲・2026-07-21）: ペイウォール2段化＋月換算ヒーロー表示＋Settings買い切り行**: PaywallViewからLifetime除去・年額/月額とも「◯円/月」ヒーロー表示（24pt・StoreKit実価格÷12動的算出）・「年間◯円を一括請求」可読表示・法務文言に請求額明記（§5c準拠）・Settings「買い切りプラン」行（Free時のみ）。doc06 §10-11/doc11 §5c/docs/15 §3.3改訂済み。品質ゲート完遂: Codex実装→Fable検証→Codex独立レビュー3件指摘（P1フォールバック価格・P1 entitlement未解決時の買い切り行・P2購入/復元競合）→全件採用→Codex修正→Fable再検証（価格リテラルゼロ・hasResolvedEntitlementゲート・isBillingBusy相互排他・192テスト0失敗・BUILD SUCCEEDED）。doc11 §5cに「—」プレースホルダ規則追記済み
- [x] **価格・ペイウォール知見のスキル汎用化（2026-07-21 オーナー指示）**: subscription-benchmarks SKILL.mdに「実戦決定ルール」5項目（LTV=Q3基準・地域差は月額1.5倍/年額A/B・月額アンカー中央値以上・2プラン+月換算ヒーロー・計測はDL→トライアル開始率）／paywall-optimization SKILL.mdにパターン15（月換算ヒーロー＋ガードレール）・16（2プラン+Lifetime移設）＋チェックリスト3項目追加
- [x] **ASC登録の事前調査・自動化準備完了（2026-07-23）**: asc CLI 3.1.0公開APIキー認証OK・DopaBreakレコード未作成を確認・**有料App契約は締結済みと確認**（BestSwipeにサブスク2本存在=契約Activeの証拠）・`scripts/asc-setup-dopabreak.sh` 作成（サブスク3本+7日トライアル+買い切りIAP+JP価格+検証を一括・構文チェック済み）。**RevenueCatは不要と判断**（実装はStoreKit2ネイティブ・A/Bはリモート構成で実装済み・RC導入はコード変更を伴うため見送り）
- [ ] **🔴 オーナー作業（ASC・5分）: `asc web auth login --apple-id <Apple ID>` を実行**（アプリレコード作成はAppleの制約で公開API不可・webセッション必須。2FAは本人デバイスのみ）→ 完了後Fableが `asc web apps create`（名称=DopaBreak − SNS依存対策・スクリーンタイム / bundle=com.dopabreak.app / SKU=dopabreak-ios / ja-JP）→ スクリプト実行→検証まで自動実行
- [ ] ASC登録後: 各商品の審査用スクリーンショット添付・サンドボックス実機テスト（購入/復元/動的価格）

## 🔴 方針転換（2026-07-24 オーナー決定）: 日本＋韓国＋米国 3市場同時ローンチ
旧「JP先行→US10-12か月目→KR Tier C」を撤回。3言語同時提出。docs/01 §11改訂済み。ワークストリーム:
- [x] **A. アプリi18n土台完了（2026-07-24・Codex実装+Fable検証）**: `ios/DopaBreak/Localizable.xcstrings`（237キー: Paywall29/Onboarding134/Home21/Settings53・ja=source/ko・en=空）。project.yml+Info.plistをja/ko/en対応。補間は%@/%lld/%%で正常保全・独立BUILD SUCCEEDED・192テスト0失敗。キー対応表＋残222ハードコード棚卸し=`.claude/specs/i18n-launch-inventory.md`。**⚠️注意: paywall.header.line1が prefix「「あと5分だけ」が年」+suffix「日」に分割抽出（数字にアクセント色のため）→ ko/enはフラグメント直訳不可・翻訳時に文全体で再構成が必要**
- [ ] **A2. 残222ハードコード＋拡張機能i18n**: 🔄Codex背景実行中（batch2・b428f5og2）。inventory基準で移行＋widget/shield拡張の.xcstrings新設
- [x] **A3. 全457キーのko/en翻訳完了（2026-07-24）**: Paywall29はFable直訳→適用。残411はWorkflow並列（18画面グループ×translate→verify・36エージェント0エラー・2Mトークン）→journalから検証済み再構成→書式検証ゲート適用。拡張17（Widgets13/ShieldConfig4）はFable翻訳→適用。**全822+34件が%@/%lld/%%一致検証パス**。主440＋拡張17。**全ターゲットBUILD SUCCEEDED・192テスト0失敗**。適用スクリプト=scratchpad/apply_translations.py（書式不一致fail-closed）
  - [x] **Codex全翻訳独立レビュー→補正JSON生成済み**（韓国語トーン/誤訳/用語統一・グロッサリー統一）※機械的UI向けは有効。訴求キーは下記トランスクリエーションで上書きされる
- [ ] **🔴 訴求トランスクリエーション（2026-07-25開始・オーナー指摘で発覚した最重要是正）**: アプリ内US/KR訴求コピーが日本語版の直訳だった。**国別訴求の正本＝`output/audits/onboarding-copy-strategy-by-country-2026-07-17.md`（v2.1・WebSearch検証済み・146エージェント確定）**が既存だが未適用だった。88の訴求キー（Welcome/クイズ/リビール/科学/プラン確認/勝ち画面/ペイウォール見出し・本文・機能行/介入判断）をv2.1のframingでトランスクリエーション中（Workflow・US=not a blocker/agency、KR=차단 아니라 브레이크・**디톡스禁止**・셀프 체크）→適用（直訳上書き）→Codexレビュー→韓国語ネイティブ確認。**機械的UI（ボタン/設定/エラー/手順）は直訳のまま**。docs/16 ASOもv2.1整合へ是正済み。教訓=lessons.md記録
  - v2.1の時期前提（US=10-12か月目/KR=Tier C）は3市場同時へ更新済み（戦略角度は有効）
  - [x] **88訴求キーのトランスクリエーション適用完了（2026-07-25）**: Workflow（US/KR×transcreate→verify・디톡스0件）→journal再構成→書式検証ゲート176件適用（直訳上書き）→**BUILD SUCCEEDED**。US=Welcome"Your feed is engineered to never let go"/科学"slot machine in your pocket"/勝ち"Loop broken"、KR=Welcome"시간 순삭의 정체는 도파민 루프"/科学"의지력 문제가 아니라 설계 문제"/勝ち"브레이크 성공"。3市場で全く別のフック確認
  - [x] **オーナー最終チェック是正（2026-07-25）**: ①目標系空状態コピー却下→是正（空状態=詩でなくアフォーダンス原則・doc11 §19）②**「戻る」系語彙3言語全廃**（目標ラベル「戻る先」→「目標/Your goal/목표」・指標「開かずに戻れた」→「開かなかった/Didn't open/열지 않음」・28キー84値・doc11 §19b）③AI典型読点4件除去＋**句読点リンター新設**（scripts/lint-display-copy.py・doc11変更手順に組込）
  - [x] **457キー×3言語 全数監査完了（Workflow 14エージェント・94指摘）**: 適用71件（INTERCEPTED→PAUSE・韓国語助詞露出(을)를是正・EN plural variation 5キー・ブロックframing除去・EN"SNS"除去・ショートカット手順の引用符付け等）／stale16（本日の是正で解消済）／廃止語彙再導入2件は語彙統一形で手動適用／レポート=scratchpad/audit_apply_report.md。**最終: 廃止語彙残存ゼロ・linterグリーン・BUILD SUCCEEDED・192テスト0失敗**
  - [x] 🔶 韓国語ネイティブ最終確認【ASO分のみ完了 2026-08-14】: オーナー指示「ネイティブかはあなたが確認して」によりクロスモデル代替（humanizer-ko全ゲート exit 0＋Opus5独立レビュー＋Fable採否）で実施。成果=docs/16改訂（サブタイトルv2.1『숏폼·SNS 앱 열기 전 잠깐 멈추는 습관』23字・KW欄88/100拡張・ko説明文v2・3言語に規約実URL追記=3.1.2対応）。**残: アプリ内コピー分（kr_native_review_sheet.md 114行）は未実施**
  - [ ] 🔶 ASA検索ポピュラリティ実査: API資格情報未設定を実測確認（2026-08-14）。広告未配信ではAPI取得不可の公算→**最短=オーナーがASA管理画面キーワード候補ツールでJP/KR/US目視**（詳細docs/16次アクション2）。未実証でもローンチ非ブロック
  - [x] **3市場ASO説明文＋サブタイトルv2完成（2026-07-25・sales-copywriting/global-marketing-psychology/seo-aso/humanizer-en・ko適用）**: 説明文ja/en/ko=docs/16に保存（折りたたみ前3行にフック＋差別化・サブスク条件明示・**EN/KOはhumanizer監査全ゲート通過 exit 0**）。サブタイトルv2=JP『禁止しないアプリ制限・開く前にひと呼吸』(19)／US『Doomscroll less. Not a blocker』(30)／KR『숏폼·SNS 열기 전 잠깐 멈추는 습관』(21)＋KW欄玉突き調整（重複排除・全字数検証済み）。アプリ内EN em dash 3件も是正。**オーナー承認事項=JPサブタイトル差し替え（doc02c確定値の変更）**・US/KRはASA実証前のためv1をPPO A/B候補として保持
- [x] **韓国語ネイティブレビュー用パッケージ作成（docs/17）**: ASO＋Paywall韓国語＋直訳＋確認ポイント＋入手先。オーナーがネイティブに渡せる形
- [ ] **B. 3ストアASO**: JP(02c確定)／US(`DopaBreak: Screen Time & Dopamine Detox`・02c)／KR新規(タイトル・サブ・KW=KO+EN(UK)索引・スクショ)
- [ ] **C. 3通貨価格**: JP¥980/¥4,980/¥14,800確定・US$9.99/$39.99+$49.99A/B/$119.99確定(docs/15)・**KR ₩は docs/15 §3.4で算出済み（月₩9,900/年₩49,000/年A/B₩39,000/買切₩149,000・FX実査2026-07-23）→残=オーナー正式サインオフ＋AppleのKRW price point載否検証（アプリレコード作成後）**。ASCスクリプト(scripts/asc-setup-dopabreak.sh)は3テリトリー対応済み・買い切りのKR/US厳密上書きのみ残
- [ ] **D. 3法域法務**: JP／US英語／KR韓国語(전자상거래법のサブスク解約/返金表示)・年齢レーティング
- [ ] **E. サブスク/IAP 3言語ローカライズ**: ja/ko/en display name・description
- [ ] **F. 多言語CS自動化**: 定型返信＋自動翻訳（オーナー絶対条件「CS軽い」を守る・solo-automation）
- [ ] **翻訳QA**: Fable作成→Codex独立レビュー→人間ネイティブ最終確認(launch-criticalのみ)。韓国語コピーはまだ未作成（現状アプリは日本語のみ）
- [ ] **🔴 オーナー判断2件**: ①ドメイン取得（SEO/LP/診断の前提・年数千円） ②初期予算水準（推奨=準備期¥50-80k/月）
- [ ] W1-2: ASOメタデータ最終化（/seo-aso）→ スクショ10枚＋15秒プレビュー制作
- [ ] W1-2: レビュー依頼トリガー・共有カード・CRM通知の文言をdocs/11へ追加→実装(13後半)バックログに統合
- [ ] W1-2: SEO記事クラスタA（競合比較）6本 ※ドメイン取得後
- [ ] grok生声検証（XAI_API_KEY接続後）: 「SNS 時間 溶けた」「夜 スマホ やめられない」「one sec 高い」等→フック文言に反映

## 環境メモ（Phase 2）
- Xcode 16.2 / xcodegen 2.45.4（brew）/ codex CLI 0.139（OPENAI_API_KEY設定済み）
- ビルド: `cd ios && xcodegen generate && xcodebuild -project DopaBreak.xcodeproj -scheme DopaBreak -destination 'generic/platform=iOS Simulator' -derivedDataPath .deriveddata CODE_SIGNING_ALLOWED=NO build`
- テスト: `swift test --package-path ios/Packages/DopaBreakCore`
- codex exec は workspace-write サンドボックス・**10分超タスクは run_in_background 必須**（タイムアウト143で中断された実績）
- FamilyControls実機必須（シミュレータ不可）。Development entitlementは申請不要
- シミュレータ検証は専用デバイスを使うこと（「Temp iPhone 16 Pro」は別プロジェクト=BestSwipeのCodexセッションと共用でフォアグラウンド競合の実績あり・2026-07-12）。`simctl`直接起動では.storekitスキーム構成が効かず商品ロード失敗→ハードコードのフォールバック価格が表示される（Xcodeスキーム起動または実機で課金表示を確認する）

## 引き継ぎメモ
- 正: FABLE_BRIEF / README / 01 / 04 / 05 / 06 / 07 / 09 / 10（全て2026-07-02改訂済み）。02/02bの効果表現はPhase 4で書き直し
- **マーケの実行順序・予算・撤退基準の正本 = docs/02c**（2026-07-03新設）。訴求=02b・経済=01 §8・表現規範=09 §2 と役割分担
- InterventionMode は3値のみ（deepFocus | standard | nightOnly）— doc05に明記済み。Codexが推測した6ケース版は是正対象
- 価格A/BはStoreKit製品2本（annual ¥4,980 / annual.launch ¥3,980）＋リモート構成で表示切替
- Free制限は「トークン数」「表示内容」でゲート（ルール数・設置数ではない）

## 2026-07-25 一呼吸「リアルな炎」アニメーション（オーナー依頼・完了）
- [x] **一呼吸画面を手続き的Metalシェーダの炎へ差し替え**（`design/BUILD_SPEC_FLAME_BREATH.md` が仕様正本。追補A=火の粉）
  - 新規: `ios/DopaBreak/Shaders/Flame.metal`（純Metal手続き生成・外部依存/画像アセットなし）・`ios/DopaBreak/FlameBreathView.swift`
  - 改修: `InterventionFlowView.breathingScreen`（数字カウントダウン＋バーを撤去し炎主体へ）・`InterventionFlowModel`（`breathPhase`/`flarePhase`＋末尾0.8秒の最終フレア区間）
  - 呼吸で炎が拡縮し、最後のフレアで明確に大きく明るくなる。火の粉が左右に舞い、フレアで大量に吹き上がる
  - **7/24の`startGeneration`世代ガードは維持**（カウントダウンもフレアも同一世代ガード下）。reflective限定・総尺{3,5,8}秒も不変
  - 回帰テスト2件追加（フレア到達→`.usageSummary`／別介入start()割り込みで旧世代が進めない）
- [x] **見た目の反復（R0→R4）**: ビルドとテストが通っても見た目は別問題だったため、実描画を撮って毎回目視判定
  - R0=内部が白いベタ塗りのアイコン風／火の粉なし → R1=暗くぼやけた煙 → R2=「ウサギの耳」シルエット → **R3=本物の炎**（`density = ノイズ×形 − 高さ` の創発方式＋異方性ノイズで解決）→ R4=フレア増強＋上端クリッピング解消
  - 実描画: `output/screenshots/flame-r4/comparison-r4-final.png`（intensity=1.0 と flare=1.0 の左右比較）
- [x] **Codex独立レビュー**: 1件(Low: シェーダuniformのNaNガード欠如)→採用し`isfinite`サニタイズを追加
- [x] **Fable独立検証**: Core 192テスト0失敗・アプリ層14テスト0失敗・BUILD SUCCEEDED・`default.metallib`に`flame`シンボル確認
- **検証手段の確立（再利用可）**: `ios/DopaBreakTests/FlameSnapshotCapture.swift`＝テストホストの実ウィンドウへ炎を載せ各状態を保持し、外部から`simctl io screenshot`で同期キャプチャする。`.colorEffect`のMetal描画はシーン未接続のオフスクリーンでは撮れないため、この方式が必要（`ImageRenderer`/未接続`UIWindow`+`drawHierarchy`は真っ白になる）
- [ ] **オーナー判断待ち**: 炎の太さ（現在は細身＝松明/ガス炎系。参考画像の焚き火はもっとボリュームあり。細身の方が鎮静目的の一呼吸には合うと判断して現状維持を推奨）
- [ ] **未決**: `FlameSnapshotCapture.swift` を恒久ハーネスとして残すか削除するか（現状は残置。CIでは実行しない前提）

## 2026-07-25 ロック画面の掲出確認導線（オーナー依頼・完了）
- [x] **目標保存 → ロック画面で確認 → 許可、の導線を新設**（文言正本=`docs/11_ui_copy.md` §20・設計記録=`.claude/specs/design-decisions.md` 2026-07-25）
  - 現状の問題: Live Activityは実装済み（WP2）で保存時に`Activity.request`まで走るが、**出ているか確認させる導線がなく**、端末側がオフだと黙って`endAllActivities()`していた。iOSは**ロック画面で最初に見た瞬間に許可を聞く**ため、導線がないと「許可しない」を押されたまま気づけない
  - 新規: `ios/DopaBreak/LockScreenCheckView.swift`（掲出プレビュー＋サイドボタンへ向かう矢印＋許可注記。starting/waiting/confirmed/blocked/noGoalの5状態）
  - 改修: `OnboardingFlow`（`.lockScreenCheck`を`notification_guide`の次に追加＝全15ステップ・目標0件は前後どちらの方向でもスキップ）／`AppContainer`（`presentGoalOnLockScreen()`・`lockScreenGoalStatus`・`pendingLockScreenCheck`）／`LockSurfaceCoordinator`（許可状態と掲出状態を公開）／`RootTabView`（オンボ後の初回目標追加で自動提示・他モーダルと排他）／`SettingsView`（「ロック画面で確かめる」で再確認）／`SettingsStore`（`lockScreenCheckCompleted`）
  - 掲出経路はWP4 ⑥の単一フライトのまま（重複Activityを作らない）。確認済みへは**実際にバックグラウンドへ落ちて戻り、かつ掲出が続いている場合のみ**進む（自己申告ボタンなし）
  - i18n: ja/ko/en 20キー追加（台帳=`.claude/specs/i18n-launch-inventory.md`・主アプリ460キー）・`scripts/lint-display-copy.py` exit 0
  - **検証: Core 193テスト0失敗・アプリ層19テスト0失敗・BUILD SUCCEEDED / TEST SUCCEEDED**。3状態の実描画=`output/screenshots/lock-check/`（`LockScreenCheckSnapshotCapture`で書き出し）
- [ ] **🔴 オーナー実機作業**: 実機で「サイドボタン→ロック画面に目標＋許可プロンプト→許可→アプリへ戻ると『ロック画面に表示中』」の一連を確認（シミュレータでは許可プロンプトの実挙動を再現できない）
  - **Codexレビュー（ultra）9件→7件採用**: ①完了記録を`.confirmed`限定へ ②設定復帰時の再掲出 ③ルートモーダルの排他を双方向化（介入優先・dismissで再評価） ④復帰観測の保持で状態競合を解消 ⑤既存掲出があれば更新のみ（不要な作り直しを廃止） ⑥`blocked`を「端末オフ」と「出せなかった」に分離し案内を出し分け ⑦Live Activityの目標数を3件へ丸め（ContentState 4KB制限の沈黙failを回避）。不採用2件（ロック検知APIは存在しない／pending永続化は無関係なタイミングでの全画面提示を招く）は理由を`design-decisions.md`に記録

## 2026-07-28 オンボーディングのモーション実装（オーナー依頼・完了）
- [x] **目標設定画面に種火**（既存Metal炎`FlameBreathView`を再利用。新規シェーダなし）
  - 新規: `ios/DopaBreak/OnboardingMotion.swift`（Stagger修飾子・押下ButtonStyle・カウントアップ・`GoalEmberField`）
  - 未入力=種火(intensity 0.12) → 入力12文字で上限(0.55) → プリセット選択で0.8秒フレア
  - 上限0.55は介入画面のピーク1.0と明確に差をつけるための固定値。「火を灯す」→「その火を守る」の物語をつなぐ
- [x] **オンボーディング全6施策**: Stagger登場 / 遷移バネ化 / **進捗バーのアニメ欠落を修正** / 推計結果のカウントアップ / 押下フィードバック＋ハプティクス / 完了画面の祝福
- [x] **既存バグ修正**: `onboarding.result.duration.decimal_hours` が `%lf` のため推計結果に `2.500000時間` と70ptで表示されていた（利用時間の選択肢4つ中3つが該当）。`%.1lf` へ修正（ja/en/ko）
- [x] Codexレビュー（gpt-5.6-sol / ultra）→ 指摘8件すべて是正（詳細は`.claude/specs/design-decisions.md` 2026-07-28の2項目）
- **検証**: `BUILD SUCCEEDED` / ユニットテスト18件 0 failures / 種火4状態を実Simulatorで同期キャプチャ（`output/screenshots/goal-ember/`）
- **検証手段（再利用可）**: `ios/DopaBreakTests/GoalEmberSnapshotCapture.swift`。`EMBER_STAGE_BEGIN`マーカーをxcodebuildログで待ってから`simctl io screenshot`する方式。時間ベースの待ちはドリフトして別画面を撮るため使わない
- [x] **オーナー確認済み（2026-08-06）**: ①の答えは「逆」。主張が強すぎるのではなく**弱すぎて意味を成していない**。実測キャプチャ`01-ember-empty`(0.12)と`03-ember-max`(0.55)を並べても炎の大きさ差がほぼ知覚できない → 下の種火v2へ

## 2026-08-06 種火v2「知覚できる成長」（オーナー依頼・進行中）
- **正本**: `design/BUILD_SPEC_GOAL_EMBER_V2.md`
- **オーナー判断**: まず「見えるようにする」改修を行い、それでも微妙なら種火を削除する
- **v1が機能しなかった3つの原因**: ①intensityの可変幅0.43ではシェーダ上で高さ・幅とも12%程度しか動かない ②描画枠320×172固定で物理的な大きさが変わらない ③変化にアニメーションが乗っておらず動きとして知覚されない
- [x] **Codex実装**: 枠サイズを成長（200×104→340×224）／intensity 0.10〜0.72へ拡張（介入ピーク1.0の聖域は維持）／立ち上がりを`pow(growth, 0.65)`でイージング／足元の楕円グロー追加で浮遊感を解消／フレア時に枠+12%
- [x] **Opus5独立レビュー → 重大2件を検出**: ①`viewport - 400`予約が過大で、キーボード表示中のSE/15 Proで`maximumHeight = 0`→**入力中に種火が完全消滅**（機能が働くべき唯一の瞬間に壊れていた） ②クリップ時`emberWidth = targetWidth * fitScale`のため**入力を増やすほど幅が細くなり成長が視覚的に反転**。他にintensityのイージング未適用・グローblurの毎フレーム再ラスタライズ・ハーネスが破損経路を再現不能
- [x] **是正実装（Opus5・Codexが使用上限のためフォールバック）**: 予約200pt＋下限化／クリップ時は高さのみクランプし幅は`targetWidth`維持／`GoalEmberVisual`を`Animatable`化しintensityと枠を同カーブに／グローは固定ラスタ＋`scaleEffect`・`opacity`／ハーネスを9段階に拡張しクリップ経路を撮影可能に
- [x] **狭小時のフェード**: 下限130pt。利用可能高さ130〜170ptで不透明度0→1に補間し、130pt未満は非描画。SEのキーボード表示中は炎が入力欄カードの背面に挟まり破片だけ覗く状態だったため、中途半端に描かず消す判断。キーボードを閉じれば育った状態で現れる
- **検証**: `BUILD SUCCEEDED` / ユニットテスト24件0失敗 / DopaBreakCore 196件0失敗 / 9状態を実Simulatorで再キャプチャ。赤色画素数が 01→04 で 11778→20927 と単調増加、SE相当3枚は11282で一致（＝非描画）
- **✅ 受け入れ基準クリア**: `01-ember-empty` と `03-ember-max` で炎の大きさの差が一目でわかる（高さ2.9倍・面積7倍）
- [x] **最終レビュー完了（2026-08-08・Opus＋Fable体制／オーナー承認による変更）**: Codex使用上限のため、レビューをOpusサブエージェント＋Fable本体の2系統＋ワークフロー3方向（SwiftUI意味論・完全性クリティック・製品意図）で実施。**全10指摘のうち9件を反証で棄却**
  - **反証した重大指摘**: Opusの「種火テストは未コンパイル・仕様の検証手順が未達」は誤り。参照先の`ios/.dd-sim*`が2026-07-25で停止した古い成果物だった。既定DerivedDataには`GoalEmberSnapshotCapture.o`が存在し、Fableが独立に実行して19件0失敗を確認
  - **実測で決着させた2点**（推測を排し実ウィンドウで観測）: ①SwiftUIのTextField binding は**未確定(marked)文字列を反映する**（`setMarkedText`直後に@Stateが同値・binding履歴 `["しかく","しかくのべんきょう","資格の勉強"]`）→ IME対策が必要と確定 ②ネストした`.animation(_:value:)`は`maximumHeight`単独変化でも**正常に補間される**（set 20回・中間値19回・0.312秒）→ 変更不要と確定
- [x] **是正5件（Opus実装）**: ①**日本語IME対策**＝growthを実文字数でなく編集セッション内の高水位から算出（かな→漢字変換で文字数が減り「決めた瞬間に火が縮む」意味の反転が起きていた。9文字→5文字で面積-33%） ②`glowScale`の死んだ上限クランプを是正（ぼかしの滲みを含む実効高さ226.4ptを基準に。滲みは実測で半径の1.2倍へ較正。発光上端 222pt→173pt で上限177pt内に収まった） ③空フレーム3枚を非表示確認1段＋フェード帯350pt＋最も詰まった377ptへ差し替え ④幾何ロジックを`GoalEmberGeometry`/`GoalEmberInput`へ切り出し、成長の単調非減少・上限遵守・境界170ptの回帰テストを追加 ⑤仕様書とdesign-decisions.mdの古い数値（104pt/107pt）を実装へ更新
- **最終検証（Fable独立実行）**: `BUILD SUCCEEDED` / `DopaBreakTests` 30件0失敗 / 聖域2ファイルはmtime 7/28・7/25で無変更 / キャプチャ9段再生成
- [ ] **コミット可否のオーナー判断**: 種火関連は未追跡4ファイル＋`OnboardingFlow.swift`の14行のみ。リポジトリ全体では未追跡46件・他の未コミット作業が混在するため、切り出すか一括確定かの判断が要る
- [x] **オーナー最終判断（2026-08-07）**: 種火は残す。さらに炎を仕組みへ昇格させる（下記）

## 2026-08-13 /preflight + /verify 再実行結果（総合: ❌ リリース不可・前回比3件解消）
- 検証: BUILD SUCCEEDED・Core 273テスト0失敗・アプリ63テスト0失敗（TEST SUCCEEDED）・表示コピーlinter exit 0・xcstrings 4カタログ（主530/Monitor11/ShieldConfig4/Widgets12）3言語完備・TODO/print/シークレット残存なし
- ✅ 前回比で解消: ③レビュー誘導（ReviewPromptPolicy＋`@Environment(\.requestReview)` InterventionFlowView:89-101。前回⑤の「未実装」記載は今回訂正）・⑦count_unit en="times"・通知オプトアウト2トグル（timeup/midsessionはdocs/18 §で意図的対象外）・深夜帯制御（全対象通知に適用漏れなし）・Monitor l10n
- 🔶 部分解消: ⑤ASCレコード作成済み（com.dopabreak.app / ID 6794221254）だが**サブスクグループ・IAPとも0件**→ scripts/asc-setup-dopabreak.sh 実行が次アクション（KR価格のオーナーサインオフ待ちに注意）。課金実機検証（規則A）は全項目未実施
- 🔴 未解消ブロッカー: ①dopabreak.appドメインDNS未解決＝Terms/Privacyデッドリンク（3.1.2） ②PrivacyInfo.xcprivacy 0件（参照もゼロ） ④ITSAppUsesNonExemptEncryption未設定 ⑥クイックアクション3枠ゼロ（構造準備もなし）
- ⚠️ 未解消: EntitlementGate未配線4件（weeklyReport/themes/yearGoal+canDisplayYearGoal/heroGoal＝デッドコード・themesAllowedはlockThemeAllowedと重複）・App Preview 15-30秒候補ゼロ（onboarding-motion.mp4 67.8sから切り出し可）・Privacyラベル/年齢レーティング記入案なし・win-back/Offer Codeコード実装ゼロ（設計記録のみ・presentCodeRedemptionSheetヒット0）
- 補足: ShieldActionExtensionのみl10nなしだがユーザー可視文字列ゼロで実害なし。**Batch 1-3含む141ファイルが未コミット**（git log最新 c25bea6）

## 2026-08-07 /preflight 実行結果（総合: ❌ リリース不可）
- 検証: BUILD SUCCEEDED（Xcode 26.6）・Core 196テスト0失敗・表示コピーlinterグリーン。※シェルのxcode-selectは16.2のまま（要 `sudo xcode-select -s /Applications/Xcode.app`）
- 🔴 ブロッカー: ①Terms/Privacy文書が不存在＋`AppURLs.swift`の`dopabreak.app`が未取得ドメイン=デッドリンク（3.1.2直撃） ②PrivacyInfo.xcprivacy全5ターゲット欠如 ③レビュー誘導API未実装 ④ITSAppUsesNonExemptEncryption未設定 ⑤ASCレコード未作成→課金実機検証（規則Aブロック）全項目未実施 ⑥クイックアクション3枠未実装 ⑦`home.achievement.count_unit` en値に日本語メモ混入（7/29検出・未対応）
- ⚠️ 要対応: Day14/時間切れ通知にオプトアウトなし・D1/サブスク系通知に深夜帯制御なし・EntitlementGate未配線プロパティ4件（weeklyReport/themes/yearGoal/heroGoal）・App Preview動画なし（launch-portrait.mp4は3秒でストア規格15-30秒に不適合）・Privacyラベル/年齢レーティング記入案なし・win-back/Offer Code未設定・Monitor/ShieldActionExtensionのl10nなし
- ✅ 合格: AppIcon 1024(alpha無)・ストアスクショ63枚asc検証済(未アップロード)・ペイウォール復元ボタン固定表示/CTA金額なし/法務リンク実装/自動更新文言3言語・購入→即時解放の伝播設計・hasResolvedEntitlementガード・トライアル5日目リマインダー・全データ削除導線・通知pre-permission・外部送信コードゼロ（Data Not Collected根拠）

## 2026-08-07 炎ステージ「守るほど育ち、青へ至る火」（オーナー発案・MVP採用・実装待ち）
- **正本**: `design/BUILD_SPEC_FLAME_STATE.md`（設計済み。決定履歴はdesign-decisions.md 2026-08-07）
- 守れた日の連続で5段階: 種火→1日→3日→7日→**21日=青い炎**。介入の一呼吸をその人の現在ステージで描く（損失回避を選択の瞬間に働かせる）
- 降格設計が本体: 火は消えない・静かな日は下げない・翌日1守りで即復帰・降格演出は静か・課金ロックなし
- `Flame.metal` に `bluePalette` uniform追加（聖域の意図的解除。`bluePalette: 0` は現行とピクセル一致が条件）
- [ ] **着手条件: 種火v2のCodexレビュー完了＋コミット後**（同一ファイル群へ未レビュー変更を重ねない）
- [ ] 実装順: FlameStageEngine+テスト → シェーダ青パレット+回帰キャプチャ → ホーム炉+進行表 → 介入への適用 → 昇格演出・コピー・l10n → 全体検証

## 2026-08-14 未コミット変更のクロスモデルレビュー＋是正（完了）
- 対象: 無料月次レポート通知バッチ一式＋AppURLs法的ページ言語振り分け
- 体制: 実装=Codex(gpt-5.6-sol max)／レビュー=Opus5サブエージェント／統合判断=Fable
- 是正1（Codex指摘・修正済み）: AppURLsが`Bundle.main.preferredLocalizations`使用で未対応言語端末がja法的ページへ誘導されるバグ → `Locale.preferredLanguages`+言語サブタグ完全一致に修正（kok≠ko対策込み）。AppURLsTests 6本新規（TDD: RED→GREEN確認済み）
- 是正2（Opus5指摘・修正済み）: 起動直後のエンタイトルメント未解決窓で全通知が削除→未復元のまま残るリスク → 削除リストを非エンタイトルメント系5IDに限定し、エンタイトルメント系8ID（trialDay5/month1/freeMonthly1-3/month12/annualOffer/cancelSave）は未解決時温存+スケジュールスキップ。初回修正の「全体早期リターン」はOpus5再指摘（設定トグル無効化の副作用）で棄却→スコープ限定版に差し替え
- 是正3（Opus5指摘・修正済み）: freeMonthlySummaryのSQLite集計を`解決済み&&非Pro&&通知トグルON&&初回起動日あり`の分岐内へ（不要実行の排除）
- 受容（オーナー判断 2026-08-14）: 他端末購入等でアプリ未起動のままPro化したユーザーへ予約済み無料向け通知が最長約3ヶ月届く件は受容（ローカル通知の構造的制約・着地先Statsで実害小）
- 検証: Core 285テスト0失敗・アプリ67テスト0失敗（AppURLsTests 6本含む）・Opus5最終確認「Confirmed clean. No remaining findings.」（IDリスト分割の完全性・解決済みケースの挙動同一性・静的イニシャライザ非循環まで検証済み）
- 未コミット（コミット承認待ち）

## 2026-08-14 推計結果画面の再構成＋オンボ12/15キャラサイズ是正（完了・未コミット）
- オーナー決定1: 質問回答（1日あたり時間）の見せ返しをやめ、換算値を主役に。ヒーロー=1年損失日数（カウントアップ維持）→3年換算（月表記・静的）→人生換算（既存50年表記維持）の3段エスカレート。1日想定値は免責行へ格下げ統合。正本: `.claude/specs/onboarding-result-restructure.md`
- オーナー決定2: オンボ12（通知ガイド）・15（準備完了）のキャラを88→120ptへ。15は旧チェックマークバッジ由来の額縁装飾を削除し素置き統一（祝福ポップインは維持）。正本: `.claude/specs/onboarding-character-size-fix.md`
- 体制: 実装=Codex(gpt-5.6-sol max)／レビュー=Opus5サブエージェント2巡／統合判断=Fable
- [x] Codex実装（OnboardingFlow.swift / LossEstimator.swift+テスト / Localizable.xcstrings ja/en/ko 新規4キー・変更2キー）
- [x] Opus5レビュー1巡目: 幅あふれ・桁数ジッター・VoiceOver分断の3件 → Codex修正済み
- [x] Opus5レビュー2巡目: ①EN行のAX2+省略切れ→行全体をAX1上限化 ②12枚目キャラ120pt化でxxxL+時に通知カード衝突→ZStack固定300pt構造をVStack+minHeight:300へ変更（既存AX5パネルはみ出しも同時解消）→ Codex修正済み・Fable受け入れ確定
- [x] design-decisions.md へ決定記録（Codexが追記済み）
- 検証: swift test 356件0失敗 / xcodebuild BUILD SUCCEEDED / xcstrings 3言語充足 / 3年換算は全バケットで実値以下（切り捨て）をOpus5が数値検証
- 備考: `onboarding.result.per_day`・`onboarding.result.yearly.prefix/suffix` は未参照キーとしてxcstringsに残置（実害なし）。免責の1日想定は既存フォーマッタ準拠で「2.5時間」表記（Fable判断で受容）
