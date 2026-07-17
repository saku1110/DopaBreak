# 現在のタスク状況

## プロジェクト情報
- **プロジェクト名**: **DopaBreak**（2026-07-02承認・旧仮称LifeFocus・docs本文リネーム済み）— SNS依存改善iOSアプリ
- **最終更新**: 2026-07-17（総合監査＋オンボ訴求文言の中央寄せ実装。**正本レポート: output/audits/audit-2026-07-17-cvr-retention-gaps.md**）

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
- [ ] **🔴 Codex独立レビュー指摘対応（2026-07-12・9件）**: High3件=①`temporarilyAllowed`（N分だけ開く承認中）に再オートメーション/URL起動で許可時間が破棄されフル介入が再表示（StartInterventionIntent.performが無条件書込み＋InterventionFlowModel.start()のresumableに temporarilyAllowed が無い） ②recordOpenがURL起動失敗でも開いた扱いで記録・通知予約 ③理由カード/CTA連打の再入ガードなし（engine遷移エラー→.failed、呼吸タスクが.failedを上書きの可能性）。Medium4件=オンボ戻る→進むで目標重複保存（Freeは上限詰みリスク）/スキップ時に未保存目標「英語で話す」を要約・通知プレビュー表示/振り返り保存失敗をtry?で握り潰し/ペイウォール商品ロード中に購入可。Low1件=Home日付の日跨ぎ未更新。→ ペイウォール2段化のCodex委譲と同時に修正が効率的
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
- [ ] **実装（Codex委譲・価格改定分）**: PaywallView 3段→2段化・Lifetime導線を設定画面へ移動・月額¥980表示確認（doc06 P-01改訂とセット。docs/15 §8参照）
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
