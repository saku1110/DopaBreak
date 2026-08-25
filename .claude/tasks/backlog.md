# バックログ

## 設計書vs実装ギャップ — 2本の監査の統合（2026-07-17）

**正本レポート: `output/audits/audit-2026-07-17-cvr-retention-gaps.md`**（同日・別セッションでCVR/継続率5レンズ+Codexアプリ実装検証込みの監査済み。905要件照合・G1-G7・B1-B14・C1-C7・R1-R7）。
Fable(このセッション)は独立に906要件で同種監査を実施し、**G4(GoalType残骸)を完全に同一の根拠で再検出**（相互検証成立）。Fable側で追加検出した項目のみ以下に残す（他はレポート本体を参照）:

- [ ] **doc11(UI文言正本)未登録の英語ラベル21箇所**: `SmallLabel`で使われる"INTERCEPTED"/"USAGE SUMMARY"/"DECISION"/"BEHAVIOR SIGNAL"等がdoc11に一切記載なし（InterventionFlowView/OnboardingFlow/StatsView/PaywallView等6ファイル）。doc11へ追記するか日本語文言に置き換えるか要判断
- [ ] **サブスク維持系ライフサイクル施策（doc15計画分）**: レポートC4/C5と同一（リバーストライアル・週1提示・Day5通知・Month1/12レポート）。レポート側に統合済みのため二重記載しない
- [ ] **Notification Content Extension未実装**: doc06が要求する「折り畳み通知ロングタップでテーマ付きカスタムUI」用拡張ターゲットが存在しない。優先度低（v1.1候補）

### 今回のセッションで実装中（codex exec委譲・優先度順）
- [x] **G1: 設定にプライバシー/全データ削除機能がない**（FR-605 Must違反・審査ブロッカー級。レポート§1・§5参照）— 2026-07-17実装完了。Codex独立レビューで実バグ3件検出→修正済み（①ログDB破損時に削除全体が無効化される ②予約済み通知が削除後も生き残り一部状態を復活させ得る ③firstLaunchDateリセットでFree枠14日拡大猶予を悪用再取得できる）。147テスト0失敗・BUILD SUCCEEDED・Fable独立検証済み
- [x] **G4: GoalType残骸の削除**（Core/GoalStore/ShieldConfigurationExtensionからhero/year型を除去しフラットリストに統一。レポート§5・Fable監査で相互検証済み）— 2026-07-17実装完了。Codex独立レビューで実バグ1件検出→修正済み（orderedForMigrationが読取時のみ正規化し永続化していなかったため、旧`[year,hero]`保存順の端末でプライマリ目標が入れ替わる回帰。一回限りの移行処理で是正）。148テスト0失敗・BUILD SUCCEEDED・Fable独立検証済み
- [x] **計測基盤の第一弾**（レポート§4優先1-3: オンボstep_completed／paywallShownへのplacement付与／app_opened）— 2026-07-17実装完了。Codex独立レビュー2周で実バグ4件検出→修正済み（①アプリ層テストターゲットのInfo.plist未生成でCodex自己申告の「3テスト成功」が実は未実行だった ②app_openedがオンボ中は一切発火せずD1/D7が測れない ③Ask to Buy等の非同期購入がpaywallDismissedと誤記録され得る ④日跨ぎキーが単調増加でなくクロック巻き戻しで二重計上され得る）。152 Coreテスト0失敗・5アプリ層テスト0失敗・BUILD SUCCEEDED・Fable独立検証済み
- [x] **コピー確定改訂（C1動的{N}化＋C3機能行の空約束是正＋オンボJP確定文言一式）**— 2026-07-18実装完了。ペイウォール見出し2行化「「あと5分だけ」が年{N}日／開く前にブレーキ」（{N}=SelfCheckSnapshot推計・固定38廃止=C1解消）、機能行「詳細な統計と継続記録」→「記録を全期間さかのぼれる」（statsDays実ゲート準拠=C3解消）。オンボはQ1を時間質問+時間バケツへ再設計（96回アンカー削除・「ざっくりでOKです」追加=doc07原設計へ回帰）、10年換算行・「この{N}つで始める」CTA・句読点/STEP表記修正・「対象の時間」ラベル等14項目。正本=doc07§5末尾/doc11§5の2026-07-18改訂表。Codex独立レビュー3件→Fable裁定（1却下=init内同期I/Oは鮮度優先で正/2採用=レガシーバケツ回帰テスト+永続化統合テスト）。158 Coreテスト0失敗・7アプリ層テスト0失敗・BUILD SUCCEEDED・Fable独立検証済み
- [x] **コピー確定改訂 第2弾（勝ち画面・サブコピー・「我慢」置換）**— 2026-07-20実装完了。勝ち画面「開かなかった／今日も自分で選べた」+サブ「今日{N}回目」（勝負フレーム廃止）、ペイウォールサブコピー差し替え（読点ゼロ・機能の嘘排除）、「開かずに我慢」→「開かずに戻れた」全UI置換（統計/週次通知/ウィジェット3箇所）。正本=doc11§14・doc13§4/§5承認済み化。158 Coreテスト0失敗・7アプリ層テスト0失敗・BUILD SUCCEEDED・Fable独立検証済み

## 最優先（死活項目）

- [x] **FamilyControls distribution entitlement — 承認済み（2026-07-03）＋ポータル設定完了（2026-07-08）**
      App Group＋5 App ID登録→4 App IDでFamily Controls (Distribution)＋App Groups有効化まで完了。**TestFlight/ストア提出のブロッカー完全解消**（docs/10 §3）
- [x] 正式名の承認: **DopaBreak**（2026-07-02・モック画面反映済み）
- [x] docs本文一括リネーム＋商品ID（dopabreak.pro.*）・App Group（group.com.dopabreak.shared）変更（2026-07-02実行済み。Web商標クイック検索=痕跡ゼロ。J-PlatPat/USPTO正式検索は提出前チェックで実施・ドメイン取得は見送り）

## Phase 1 残タスク
- [ ] 08_widget_guide.html を O-08 Notification Guide（通知許可＋Live Activity）版に改訂

## Phase 2: 実装（Codex委譲・FABLE_BRIEF §7 の分割単位）

第1スプリントで技術検証6項目を必ず消化:
1. 選択した対象アプリにカスタムシールドを出せるか
2. ShieldActionで段階的な画面遷移を実現できるか
3. 指定時間だけ一時開放して再シールドできるか
4. App GroupからExtensionが目標snapshotを安定して読めるか
5. WidgetとShieldが同じ目標データを表示できるか
6. 選択時間終了時に利用後リフレクションを表示できるか

実装順（1タスク=1 `codex exec`・workspace-writeサンドボックス・長時間はrun_in_background）:
- [x] (1) App Group＋ローカル保存（2026-07-02完了: ios/scaffold＋DopaBreakCore Models/Storage。28テスト・カバレッジ90%・BUILD SUCCEEDED・Fable独立検証済み）
- [x] (2) 目標作成（ヒーロー＋1年の2枠）（2026-07-02完了・シミュレータ動作確認済み）
- [x] (3) FamilyControls権限（2026-07-08完了: ScreenTimeCenter＋Settings許可導線。オンボ側は既存）
- [x] (4) FamilyActivityPicker（2026-07-08完了: **RuleStore新規作成**（Core・rules.json永続化・15テスト）＋Settings配線。Coreは選択データを不透明Dataで保持しFamilyControls非依存）
- [x] (5) ManagedSettingsシールド（2026-07-08完了: ShieldController・named store "dopabreak.rules"・fail-safe同期＝読取失敗時は保護維持）
- [x] (6) ShieldConfiguration表示（2026-07-08完了: 静的UI・doc11 §6b文言・読取専用・失敗時最小構成。**「理由を選んで続ける」副ボタンは(7)で追加**）
      ※(3)-(6)の実機動作確認（技術検証①④⑤）は未・オーナー作業（current.md参照）
- [ ] (7) ShieldAction（開かない/続ける）★中核ロジックは実装済み（InterventionEngine 2026-07-02 Opus）— 配線時に InterventionState へ intent フィールド追加（doc05 §5の既知制約解消）
- [ ] (8) 時間選択と一時開放 ★エンジン側（recordOpen/reshieldIfExpired）実装済み・UI/Extension配線のみ
      ⚠️ このタスクでExtensionプロセスがルールを書き始めるため、**RuleStoreのread-modify-writeに跨プロセス排他（NSFileCoordinator等）を導入すること**（2026-07-08 Codexレビュー指摘。現状は書き込みが本体アプリMainActorのみのため繰り延べ・GoalStoreと同一パターン）
- [ ] (9) 利用後リフレクション ★エンジン側（pendingReflection/recordPostUseReflection/skip）実装済み・UI配線のみ
- [ ] (10) AttemptLog/ReflectionLogと統計 ★StatsService実装済み（週次サマリー含む）・Stats画面への結線のみ
- [ ] (11) ロック画面サーフェス（朝の通知＋Live Activity(ActivityKit)＋Home Widget・テーマ6種）
- [x] (12) StoreKit 2＋ペイウォール（2026-07-08 Codex実装＋Fable検証: EntitlementGate=Core純粋ロジック100%テスト／StoreService=StoreKit2購入/復元/currentEntitlements/updatesリスナー／PaywallView=3段doc06§10文言／DopaBreak.storekit 4商品・P1Wトライアル／AppModel・Settings・Onboarding・Home年目標ゲート配線。99テスト0失敗・BUILD SUCCEEDED。**品質ゲート完了**: Codex独立レビュー6件→Fable裁定(4採用/2却下=仕様誤読)→Codex修正→Fable再検証。修正=トライアルCTA対象者限定/法的文言プラン別出し分け/deepFocusのProゲート/ShieldController適用層Free制限/復元フィードバック）
- [x] (13前半) Onboarding 14ステップ（2026-07-03完了: doc07文言転記・LossEstimator・シミュレータ通し動作確認・73テスト。**Paywall polishはStoreKit(12)とセットで残**）
- [x] InterventionState.intent 跨プロセス永続化（2026-07-03 Opus・後方互換テスト付き・doc05§5注記解消）

## Phase 3: 品質・レビュー
- [ ] セキュリティ/プライバシーレビュー（security-review・オンデバイス徹底・Privacy Manifest）
- [ ] Codex独立レビュー
- [ ] /app-store /preflight 提出前チェック（スクショ10枚/15秒プレビュー含む）

## Phase 4: マーケ成果物
- [ ] 広告クリエイティブ切り口（感情アーク5本×A/B）＋台本
- [ ] LP（日/英最小）＋「SNSを一番開く時間」診断リード
- [ ] ASO/SEO（キーワード・タイトル・サブタイトル・説明文）
- [ ] 法務（Terms/Privacy/特商法）
- [ ] Permission denied分岐のモック

## v1.1
- [ ] 「今日の1つ」（TodayFocus）実装（設計正本: docs/14_today_focus.md・2026-07-09オーナー承認）: Core `TodayFocus`/`FocusLog`＋片側集計→ホーム入力枠→一呼吸S-03/Live Activity主役表示→朝の通知導線→週次レポート「代わりにやれたこと」。UI文言はdoc14 §3の承認→doc11転記後にCodex委譲
- [ ] **傾向分析カード（Pro・条件付き着手）**（2026-07-18経営会議で保留判定・議事録=.claude/brainstorm/2026-07-18_追加機能3件の要否判定.md）: 「{アプリ}は主に{時間帯}に{理由}で開いています」を既存AttemptLog(intent×時刻×ruleId)の集計のみで表示。S-07振り返りループの「返報」として価値確定済み。**着手条件=ローンチ後D14のS-07回答率が観測できてから（50%未満なら前倒し）**。前提=FunnelEventStoreに振り返り表示/回答イベント追加（監査項目6の計測拡充と同一作業）。疑似医療訴求（ドーパミン量等）は禁止
- [ ] **執行力のあるコミットメント装置はシールドv1.1で設計**（2026-07-18経営会議で「アプリ内スイッチの24hクールダウン」案を却下）: MVPの保護実体はShortcutsオートメーション=ユーザーがShortcuts側で即削除可能なため、アプリ内クールダウンは執行力ゼロの見せかけになる。FamilyControlsシールド（deepFocus・コード温存済み）実装時に、ManagedSettingsで実際に強制できる形で再設計する
- [ ] **ストリークは実装しない（恒久判断・doc14 §原則）**: 2026-07-18経営会議で競合機能としても却下確定（ご褒美パスは「SNS=報酬」フレームで損失訴求と自己矛盾）。代わりに「連続記録であなたを縛りません」をASO説明文・Why Science画面の訴求コピー素材としてPhase 4で使う

- [ ] **ペイウォールに社会的証明を入れる（リリース後・レビューが付いてから）**（2026-08-25 paywall-optimization監査で検出）: 現在の`PaywallView`には星・レビュー・利用者数のいずれもない。スキルのパターン2は+44%、パターン19では「価格を見る直前に不安を下げる」役として見出し直下・プラン群の直上に置くのが定石。**未リリースの今は実績が存在せず、書けば捏造になる（景表法の優良誤認・App Store 2.3）。v1.0は空欄が正解**。着手条件=ストアにレビューが付き、引用できる実文が集まってから。置き場所は`header`と`featureList`の間
- [ ] **年額の解約フローにwin-backとしてLifetimeを出す**（2026-08-13オーナー決定「Lifetimeは設定画面＋年額解約フローのみ」の後半が未着手）: 設定画面側は`SettingsAccountView.swift`で実装済み。解約フロー側の導線がまだない。**初回提出には入れない**（退出オファーは審査員の判断次第でリジェクト要因になるため。paywall-optimizationスキルの明記事項）。実装するならApp Store Connectのオファー実体と表示条件を完全一致させ、既存の課金ユーザーには絶対に出さない

## 既知の制約（MVPピボット・2026-07-08）
- [ ] Free=1個ゲートはTargetAppPickerSheet(UI)のみ強制。ユーザーが手動でiOS Shortcutsのオートメーションを直接複数アプリに設定すればすり抜け可能（Shortcuts自体はアプリ外システムのため技術的に完全制御不可）。実害軽微・v1.1でPro導線を締める際に再検討

## アイデア置き場
- 自社実測データが貯まったら 06b Why Science をPNAS引用から自社数値に差替（マーケ資産化）
- ハードペイウォール vs スキップ可のA/B（オンボO-08b→P-01）
