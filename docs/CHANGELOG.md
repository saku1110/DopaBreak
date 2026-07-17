# 設計ドキュメント改訂履歴

## 2026-07-12 — 最新モックのSwiftUI実装・設計書同期

- 朝焼け海を感情的アンカー（Welcome/Home/Ready/Paywall/通知プレビュー）に限定して導入。介入・設定・入力画面は無写真E1 Dark Monoを維持
- 介入を目的確認6択から開始し、明確目的は呼吸省略、反射的目的だけ呼吸/回数/目標/判断へ分岐
- 時間選択を5/10/15/30分＋確定CTAへ変更。「自動で閉じる」を廃止し通知表現へ統一
- Homeの推測節約時間を廃止し、実ログから正確に出せる「自分で選べた回数」を達成ヒーローに採用
- 2段階振り返り、途中チェックイン、Notification+Live Activity案内を最新モックへ整合
- 同期: `docs/04_functional_requirements.md` / `docs/06_screen_design.md` / `docs/07_onboarding_design_lifefocus.md` / `docs/11_ui_copy.md` / `docs/12_hybrid_intervention.md` / `docs/FABLE_BRIEF.md` / `design/BUILD_SPEC_E1.md`
- 検証: iPhone 16 Pro simulator build成功、Core 144テスト成功、`design-qa.md` passed

## 2026-07-11 — モノクロ画面自動化機能を削除

- オーナー判断: システム全体のカラーフィルター自動制御はAppleが公開APIを提供しておらず、事前のAccessibility手動設定＋Shortcuts手動設定という多段の手間になるため、アプリの設計思想と合わないとして機能ごと削除
- 削除: `GrayscaleAutomationGuideView.swift` / `AppGrayscaleAutomationGuideView.swift`、SettingsStoreの`grayscaleStartMinutes`/`grayscaleEndMinutes`、SettingsViewの「画面のモノクロ化」セクション、docs/11 §4e・§4f
- 起床/就寝時刻連動バナー機能（DayTimeContext・S-02バナー）は別機能のため維持

## 2026-07-10 — ロック画面サーフェス文言の正本化

- **11_ui_copy.md** §9「ロック画面の表示」を新設し、朝の目標通知・週次レポート通知・Live Activity・Home Widget・テーマ名の文言を正本化
- 週次通知と実績表示の統計ラベルは、現行のホーム/統計文言に合わせて「開かずに我慢」「開こうとした」に統一

## 2026-07-10 — オートメーション検収＋Free価値実感ウィンドウ

- オートメーション設定済み判定を、対象アプリ用の介入IntentまたはURLルーティングが実際に発火した事実に基づく方式へ変更
- **11_ui_copy.md** §4cに設定状態バッジ、アプリごとのテスト、Safari注記、自動確認説明、Free上限説明の正本文言を追加
- Freeの対象アプリ上限を初回14日間は3つ、14日経過後は1つに変更（Proは無制限のまま）

## 2026-07-09 — 「今日の1つ」（TodayFocus）設計確定（v1.1スコープ）

- **14_today_focus.md 新設（正本）**: オーナー議論で方向性確定。階層化（大目標→月→日）とTodo統合は却下し、フラット目標（複数・現行維持）＋「今日の1つ」（常に1枠・任意入力・毎日自動失効・繰り越しなし・完了後差し替え可）を採用
- 完了チェックは**片側集計**（できた日だけ記録・未完了は数えない/表示しない）。ストリーク不採用（依存させにくい設計のガードレールを明文化）
- 表示優先: 一呼吸S-03・Live Activityで「今日の1つ」を主役表示、未入力時はフラット目標フォールバック（既存仕様）
- UI文言ドラフトは同doc §3（オーナー承認待ち→doc11転記で正本化）
- スコープ: **v1.1**。MVP（実装(11)まで）は2026-07-08確定のまま変更なし

## 2026-07-09 — 起床/就寝の時間帯検知 ＋ 画面を自動でモノクロにする設定ガイド追加

計画: `.claude/plans/crystalline-imagining-shannon.md`

- **11_ui_copy.md**: §4d（起床・就寝時刻設定）／§4e（画面を自動でモノクロにする設定ガイド）／§8（S-02起床・就寝バナー）を新設
- 実装（Codex委譲・Fable検証・Codex独立レビュー1件是正済み）:
  - `SettingsStore`に`wakeTimeMinutes`/`bedTimeMinutes`（当日0時からの分数・未設定はnilを厳密に区別）を追加
  - Core新規`DayTimeContext`: 現在時刻が起床窓（起床時刻〜+30分）／就寝窓（就寝時刻-60分〜就寝時刻）のどちらに該当するかを純粋関数で判定。mod 1440演算で日付またぎを吸収（9テスト→レビュー後11テスト、境界値・日付またぎ・優先順位を網羅）
  - 介入フローS-02に起床窓/就寝窓限定のバナー表示（「起きてすぐの数分／その日の集中を決める時間」「眠る前の数分／その日の睡眠の質を決める時間」）
  - 新規`GrayscaleAutomationGuideView`（既存`AutomationGuideView`と同パターン）: iOS Shortcutsのパーソナルオートメーション（時刻トリガー→カラーフィルタ設定）を案内。**Appleはサードパーティアプリによるシステム全体モノクロの直接自動制御APIを提供していないため、ショートカット連携が唯一の実現方法**（初回のみユーザーが手動設定、以降は完全自動）
  - Settings画面に「起床・就寝時刻」セクション追加（DatePicker、Settings画面を開いた時点でデフォルト値07:00/23:00を実際にコミットし表示と実データの不整合を防止）
- 品質ゲート: Codex実装→Fable検証（起床窓ロジックのバグ1件を発見・Fable自身のテスト仕様誤りが原因と特定→Codex修正）→Codex独立レビュー（デフォルト値がSettingsStoreに未コミットのままになる不整合を1件検出→Codex修正）→再検証。124テスト0失敗・BUILD SUCCEEDED

## 2026-07-08 — MVP pivot コピー追加

- **11_ui_copy.md**: 目標をフラット複数リストにするMVP文言を追加（「目標」「目標を追加」「一番上の目標が一呼吸のときに表示されます」）
- **11_ui_copy.md**: ペイウォール機能文言を「目標を何個でも追加できる」に差し替え
- **11_ui_copy.md**: one sec方式の一呼吸フロー追加文言（時間選択、Safari案内、勝ち画面、時間切れ通知、幸福感選択肢）とAppIntent/ショートカット自動設定ガイド文言を追加

## 2026-07-08 — 実装(3)-(6) FamilyControls配線に伴う改訂

- **11_ui_copy.md**: §4b（対象アプリ設定・スクリーンタイム許可の文言）と §6b（止める画面=静的シールドの文言・配色）を新設。対象行の値は「選択中の種別のみ・区切り表示（アプリN個・カテゴリM個・WebサイトK個、0は省略）」に確定
- **11_ui_copy.md**: §5にペイウォール法務表示の分岐文言（年額トライアル対象/対象外・月額・Lifetime）を追加。年額トライアル対象の自動更新文言はdoc06 §10の正本を維持
- **10_familycontrols_entitlement.md**: 承認済み反映（2026-07-03・Team単位・即日）。Bundle IDごと4件申請は旧プロセスと判明し取り消し線化。申請英文はApp Review Notes転用のため存置
- 実装メモ: RuleStore（doc05 §9）をDopaBreakCoreに新規実装（FamilyControls非依存・選択は不透明Data）。シールド同期はfail-safe（rules.json読取失敗時は既存保護を維持）。RuleStore跨プロセス排他は実装(8)で導入（backlog記載）

## 2026-07-02 — 設計・戦略ブラッシュアップ（Phase 0+1 / 収益最大化）

計画: `.claude/plans/dapper-inventing-lightning.md`

### 確定事項（オーナー回答）
1. **ICP**: SNS依存・ドーパミン中毒層全般×損失回避訴求（特定層に絞らない。差別化必須）
2. **正式名**: 候補調査完了（2次）。Modoru/AfterScrollはオーナー却下（ASO・海外展開観点）→ 最終推奨 **DopaBreak**／第2候補 DopaDetox（Reset案は製品一致が弱く撤回。Break懸念は再検証で低リスク→09 §5第4次）。最終承認・商標確認待ち
3. **トーン**: 既存E1 Dark Mono vs Fable新提案のモック比較で確定する
4. **スコープ**: Phase 0+1（整合＋設計）。実装は次セッションでCodex委譲

### 新規作成
- `09_market_verification.md` — 競合価格/App Review・Screen Time API制約/PNAS研究の表現規範/名称調査/ASO所見（確認日付き）
- `CHANGELOG.md` — 本ファイル
- `.claude/tasks/{current,backlog,completed}.md` — タスク管理

### 主要な設計変更
| 項目 | 旧 | 新 |
| --- | --- | --- |
| 価格（年額） | ブリーフ¥5,400 vs モック¥2,400で矛盾 | **¥4,980（7日無料・デフォルト）**。A/B: ¥3,980 vs ¥4,980 |
| 価格（月/買切） | ¥780・¥12,800 vs ¥700・¥15,000 | **月¥780 / 買切¥14,800**（米: $5.99/$34.99/$99.99） |
| 目標仕様 | doc06=無制限複数目標 / doc07=目標全削除 | **ヒーロー目標1＋1年目標1の2枠固定**（Free=ヒーローのみ、Pro=＋1年目標） |
| ロック画面複数表示 | 複数目標を無制限配置 | ヒーロー/1年/状態チップの組み合わせのみ |
| オンボ | doc06=7画面(目標入力あり) / doc07=7画面(目標なし) / ブリーフ=9画面 | **14ステップ損失顕在化フロー**（クイズ3問＋損失リビール＋Why Science＋Pre-Paywall Summary。v2モックと1:1） |
| トライアル | Should（3日or7日） | **Must（7日・年額のみ）** |

### ファイル別差分
- **01_business_design.md**: GoalGate表記除去。ICP確定反映。§7競合表を2026年実勢価格に更新。§8価格確定＋ユニットエコノミクス根拠＋A/B計画。§11にentitlement申請を追加。北極星をConscious Savesに一本化
- **03_product_spec.md**: 冒頭に読み替え注記のみ追加（本文は初期版のまま）
- **04_functional_requirements.md**: Goal FRを2枠モデルに改訂（FR-001/005）。オンボクイズFR追加（FR-011〜013）。FR-306を状態チップモデルに変更。FR-502〜506を確定価格・7日無料Must・価格A/Bに更新。イベント追加
- **06_screen_design.md**: **全面改訂**。旧GoalGate版を廃止し29画面カタログ（v2モック1:1・S-07新規モック含む）。オンボ詳細はdoc07へ委譲。Goals画面を2枠固定に。Paywall確定価格。S-07リフレクションのモック欠落を明記。E1 Dark Monoを現行トークンとして記載
- **07_onboarding_design_lifefocus.md**: 「入れないもの」から目標入力を軽量2枠として復活。14ステップ構成表＋離脱対策。新画面詳細（O-02b/02c/03r/04/06b/08/08b）追加。計測イベント拡充。モック対応状況更新
- **README.md**: 名称注記。スコープ判断を二層構造に更新。ドキュメント一覧を現行状態に更新
- **FABLE_BRIEF.md**: §6を29画面/14ステップに更新。§9確定価格。§10未決定5件中4件解消。§15トークン二重基準の注記

### 本セッション内で追加完了
- S-07（23_post_reflection.html/.png）をE1トーンで新規作成（差別化中核の欠落解消）
- 22_paywall.html を確定価格に更新・再レンダリング（Lifetime高位アンカーを最上段に）
- doc02の新旧価格・doc05のGoal 2枠/SelfCheckSnapshot/商品ID/Entitlementを更新
- トーン最終比較セット `output/mockups/tone_comparison_v2/`（E1 vs F1墨と灯・3画面×2）作成

### Codex独立レビュー（実施済み・指摘対応済み）
Codexレビューで検出→修正した項目:
- 画面数28/29の残存不整合（README/doc07/FABLE_BRIEF索引・§14）
- READMEスコープ判断の旧「複数目標」記述 → 2枠＋状態チップに統一
- 審査リスクコピー: O-03r「この時間は、取り戻せます」→「使い方はここから選び直せます」/ O-06b見出し「なぜ一呼吸で減るのか」→「背景にある行動科学」
- 価格A/Bの実装方式を「年額製品2本＋リモート構成で表示切替」に是正（StoreKitは表示価格を動的変更できない）
- Free「1対象アプリ」をトークン数検証で実効化（target_app_tokens_limit）。ウィジェット制限は設置数でなく表示内容でゲート（widget_content）
- 1年目標のFree時挙動を定義（保存可・表示ロック・「Proで表示」バッジ＝保有効果）
- ペイウォールの誇大コピー「すべてのアプリをブロック」→「選んだアプリを何個でも守れる」（E1/F1両方・再レンダリング済み）

Codex指摘のうち**対応見送り**: doc02/02b内の強い効果表現（「意志力ゼロで減る」等）→ マーケ土台docのためPhase 4（LP/広告制作時）にlegal-compliance-jpレビューとセットで書き直す。

### 追加作業（同日・オーナー指示）
- **名称確定: DopaBreak**（Reset案は「アプリは目標に引き戻す設計でリセット要素がない」とのオーナー指摘で撤回→Break復帰で承認）。モック全29枚のブランド表記をDopaBreakに置換・可視7画面を再レンダリング。ドメイン取得は今回見送り
- **Proウィジェットテーマ画像を新規作成**: 墨と灯/朝霧/森林/夜更けの4テーマ × 2モデル比較（`gemini-3.1-flash-image` vs `gemini-3.1-flash-lite-image`）→ `output/mockups/widget_themes/`。結論: 資料用は標準版、Liteは案出し用（詳細は同ディレクトリREADME）
- **女性向けテーマ2種を追加**: K-POPパステル（Y2K・目標例「韓国語で話す」）/ かわいいピンク（サンリオ的トーンの**オリジナル再構成・IPセーフ**、サンリオキャラ使用禁止を明記）。全10枚プレビュー済み・所見はwidget_themes/README

### 追加作業2（同日・オーナー指示: 常設ウィジェット廃止）
- **ロック画面の常設ウィジェットを廃止**し、戻る先表示を「朝の目標通知＋デイリーLive Activity」に一本化（設置摩擦ゼロ化。旧KPI設置率40%→通知許可率60%+/Live Activity有効率40%+）
- 反映: doc01（提供価値/KPI/課金ロジック）/ doc04（FR-301〜308全面改訂）/ doc05（LockSurfaceState追加・旧LockScreenGoalSnapshot等廃止・LockSurfaceStore・ActivityKit）/ doc06 §9（9a通知/9b Live Activity）/ doc07（O-08をNotification Guideに置換）/ FABLE_BRIEF / README
- **通知/Live Activityテーマ6種のモック生成**（E1/墨と灯/朝霧/夜更け/K-POP/かわいいピンク）→ `output/mockups/notification_themes/`（全6枚プレビュー済み・◎）。widget_themes/はアーカイブ化
- 技術制約を明記: 折りたたみ標準通知はテーマ不可→テーマの主戦場はLive Activity。8時間制限は更新で延長。審査対策=「今日の実績ライブ更新」で進行中要件を満たす
- モック要改訂として残: 08_widget_guide（→通知案内）。20_lock_widgetは廃止残置

## 2026-07-02（Phase 2 着手）

### docs一括リネーム（LifeFocus→DopaBreak・実行済み）
- 全docs/design/モックREADMEの本文を **DopaBreak** に統一（履歴行「旧仮称LifeFocus」・docs/09の名称調査経緯は原文維持。競合「LifeFocus360」表記も保護）
- 識別子確定: 商品ID `dopabreak.pro.{monthly,annual,annual.launch,lifetime}` / App Group `group.com.dopabreak.shared` / bundle prefix `com.dopabreak`（変更は ios/Configs/Shared.xcconfig の1行）
- 商標: Webクイック検索で既存アプリ・商標の痕跡ゼロ（2026-07-02）。J-PlatPat/USPTOの正式DB検索は提出前チェックで実施。ドメイン取得は見送り（オーナー決定）

### FamilyControls entitlement申請パッケージ（docs/10・新規）
- フォームURL・オーナー実行手順15分・**4 Bundle ID分の貼り付け英文**（本体＋Shield2種＋Monitor。拡張も個別承認が必要＝2026年Forums報告）・未応答2週で再送信の運用・ステータス表
- 承認リードタイム1日〜4.5週。承認待ち中もDevelopment entitlementで開発継続可（実機必須）

### ios/ Xcodeプロジェクト scaffold（codex exec委譲・検証済み）
- xcodegen 2.45.4導入 → `ios/project.yml`（iOS 17.0・5ターゲット: 本体＋ShieldConfig/ShieldAction/Monitor/Widgets拡張）＋ローカルSPM `DopaBreakCore`（全ターゲットにリンク）
- entitlements: App Group全5ターゲット / family-controls 4ターゲット（Widgets除く）— Fable独立検証で仕様一致確認
- 検証: `xcodegen generate` ✓ / `swift test` ✓ / `xcodebuild`（simulator・署名なし）**BUILD SUCCEEDED** ✓

### 実装(1) App Group＋ローカル保存（codex exec委譲・完了）
- DopaBreakCoreにModels（doc05 §4完全準拠・LockTheme 7ケース・InterventionStep 12ステップ・FamilyControls非依存のopaque Data方式）＋Storage（AppGroupContainer厳格版/JSONSnapshotStoreアトミック書込＋completeUntilFirstUserAuthentication保護/SQLiteLogStore WAL+busy_timeout 3000/SettingsStore）
- doc05修正: InterventionModeの3値（deepFocus|standard|nightOnly）を明記（未定義だったためCodexが6ケースを推測→doc明記後にCodexが自主是正）
- 検証: **28テスト0失敗・カバレッジ90.04%（source-only）・xcodebuild BUILD SUCCEEDED**（Codex報告＋Fable独立再実行の両方で確認）

### 実装(2) 目標作成＋4タブUI（codex exec委譲・完了）＋Opus並列投入
- アプリが操作可能に: 4タブ（ホーム/目標/統計/設定・E1トークン）＋目標2枠のCRUD（GoalStore・永続化）＋今日/今週の実績表示（実データ結線）。38テスト→シミュレータ起動確認済み
- scaffoldの誤り修正: ShieldActionの拡張ポイントIDは `com.apple.ManagedSettings.shield-action-service`（UIなし。ManagedSettingsUIはShieldConfigurationのみ）
- オーナー指示によりOpusを並列投入（担当分離: Codex=UI / Opus=InterventionEngine＋StatsService新規ファイルのみ）

### UI文言の全面是正（2026-07-02 オーナー指摘2件）
- 指摘: ①「介入」は内部用語でユーザー目線でない ②代替の「アプリを守る」も対象不明で意味が通らない。根因=設計書に画面文言の正本がなくdoc06 §11に内部用語が残存
- **対策: [docs/11_ui_copy.md](./11_ui_copy.md) 新設（UI文言の正本）**。実装は転記のみ・新画面は文言先行のプロセスに変更
- 語彙確定: 止める（止めるアプリ/止める強さ）・開こうとした・開かずに我慢・戻る先。「守る」系表現は全廃（app/doc01/doc06/モック08b・13・22を修正、PNG再レンダリング済み）
- 適用: アプリ4ファイル＋FABLE_BRIEF §5＋doc06 §10/§11＋doc01 §8＋メモリ

### 中核ロジック実装（Opus並列・完了 2026-07-02）
- **InterventionEngine**（介入状態遷移: begin→advance→cancel/open→一時開放→再シールド→振り返り。intervention_state.json永続化・クラッシュ復帰考慮）＋ **StatsService**（今日/期間別/意図別/満足感別集計・wastedTimeRealizationRate・週次サマリー）＋ SQLiteLogStore+Aggregates
- 新規6ファイルのみ（既存ファイル無改変=Codex並列作業と無衝突）。**65テスト0失敗・新規コード96%カバレッジ**・iOS実機向けビルド成功。Opus内でCodexレビュー2周（実バグ2件修正: pendingReflectionの取りこぼし・skip二重適用ガード）
- 既知制約を文書化: InterventionState.intentは実装(7)配線時に追加（doc05 §5に明記）

## 2026-07-03

### FamilyControls entitlement 承認（即日）
- 申請プロセスは2026年に**Team単位付与**へ変更されており（Bundle IDごとの申請は不要だった）、送信同日に承認。TestFlight/ストア提出ブロッカー解消。残＝App ID登録＋Capability有効化（docs/10 §3・提出前でOK）

### 実装(13前半) オンボーディング14ステップ（Codex）＋ intent永続化（Opus・並列）
- OnboardingFlow: O-01〜O-09の14ステップ（doc07文言を転記・損失顕在化クイズ3問→LossEstimator推計「年N日」リビール→汎用アイコンのアプリ選択→目標→止める強さ→科学的背景→許可2種はシミュレータ安全分岐→まとめ→完了）。ペイウォールはStoreKit(12)とセットで後続
- LossEstimator（Core・純関数・テスト5件）: 時間バケット→分/日→年間日数（150分→38日）
- InterventionState.intent 跨プロセス永続化（Opus・後方互換decode・テスト3件追加）→ doc05 §5の既知制約解消
- docs/11 §5b: 実装時に新規発生した文言4件を正本に登録（許可拒否フォールバック等）
- 検証: **73テスト0失敗・BUILD SUCCEEDED・禁止語ゼロ・シミュレータ新規インストールで初回オンボ表示確認**。設定にDEBUG限定「オンボーディングをもう一度見る」

### Phase 4着手: マーケ実行計画（インパクト順）新設
- **`02c_marketing_impact_plan.md` 新規作成**: 02b（訴求の正本）を実行順序・予算・撤退基準に落とす実行レイヤー。Tier S（転換基盤＝ストアCVR/レビューエンジン/課金ファネル/CRM・ASO）→ A（SEO×比較メディア／クリエイティブ工場／ASA／**ゲート制**有料スケール）→ B（第三者インフルエンサー／ローンチ演出／共有カード）→ C（米国・韓国・マスコットIP）。意図補正した許容CPI/CPT（ASA exact ¥210-280、ペイド社会面 ¥98-140）・90日カレンダー（製品Phase 2と同期）・テスト6件・週次30分運用・予算3シナリオ（¥50-80k/¥120-180k/〜¥300k）を確定
- 実装バックログへの追加依頼を明記: レビュー依頼トリガー（S-05累計3回目/週次レポート後）・共有カードPNG書き出し・CRMライフサイクル通知（いずれもdocs/11に文言追加→実装(13後半)へ統合）
- **オーナー判断2件**: ①ドメイン取得（SEO/LP/診断の前提・年数千円） ②初期予算水準（推奨=準備期¥50-80k/月）
- FABLE_BRIEF §12/§16・tasks/current.md に参照を追加

### 未解決（次アクション）
1. 実装(12) StoreKit 2＋ペイウォール（.storekit構成でシミュレータ購入テスト可）
2. 実装(3)-(6) FamilyControls配線（実機必須・エンジン完成済み）＋(11)ロック画面サーフェス
3. doc02/02b の効果表現はPhase 4で一括更新（legal-compliance-jp準拠）※使用時の置換ルールは02c §11に既定
4. モック改訂残: 08_widget_guide → Notification Guide版
5. 02c実行の先頭タスク: ドメイン判断（オーナー）→ ASOメタデータ最終化（/seo-aso）→ スクショ10枚制作 → SEOクラスタA 6本
