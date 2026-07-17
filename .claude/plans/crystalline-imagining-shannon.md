# モノクロ機能削除 ＋ 競合発の新機能4件

## Context

前タスクで実装した「画面を自動でモノクロにする」機能は、Appleの制約上ショートカット側の多段手動設定が必須になり、「自動で止める」というDopaBreakの設計思想と合わないとオーナーが判断。削除する。

代わりに、競合アプリ（One Sec/Opal/Freedom/ScreenZen/Forest/Flipd/StayFree/AppBlock/Space/Roots/Jomo）を調査し、DopaBreakの「一呼吸→目標想起→理由選択→開くか戻るか」という設計に合い、サーバー不要・一人運用で実装できる機能を4件選定した。

## モノクロ削除（実装中・別トラック）

Codexに削除を委譲済み（`GrayscaleAutomationGuideView.swift`/`AppGrayscaleAutomationGuideView.swift`の削除、SettingsStore/SettingsView/docs11 §4e・§4fの除去）。起床/就寝バナー機能（`DayTimeContext`）は別機能のため維持。完了後にFableが検証する。本プランの承認・実装とは独立して並行する。

## 新機能4件

### 1. セッション中の軽量チェックイン通知
**目的**: One Sec/ScreenZenの「長時間セッションへの再介入」に相当。ただしDopaBreakはShortcuts経由でSNSアプリに制御を渡した後は何も検知できない（強制中断は不可能）ため、**ソフトな通知ベースの呼びかけ**として実装する。誇大なコピーは書かない。

- `InterventionFlowModel.selectDuration()`（`ios/DopaBreak/InterventionFlowModel.swift`）で、選択時間が10分以上のときだけ、既存の「時間切れ通知」に加えて時間の半分の時点にもう1本ローカル通知を追加スケジュールする（タイトル「まだ見てる？」本文「戻る先を思い出す時間です」）。通知識別子に対象アプリのcatalogIDを埋め込む（例: `dopabreak.midsession.<catalogID>.<uuid>`）
- 新規: `NotificationDelegate`（`UNUserNotificationCenterDelegate`）を追加し`DopaBreakApp`起動時に`UNUserNotificationCenter.current().delegate`へ設定（現状デリゲート未設定と確認済み）。`didReceive response:`で識別子が`dopabreak.midsession.`プレフィックスならcatalogIDを取り出し`settingsStore.pendingMidSessionCheckInCatalogID`（新規App Group共有フラグ、既存の`pendingStartInterventionCatalogID`と同パターン）に書き込む。`willPresent`はバナー表示を許可
- `RootTabView`に既存の`checkPendingIntervention()`/`checkPendingReflection()`と並列で`checkPendingMidSessionCheckIn()`を追加し、新規の軽量`.sheet`（`MidSessionCheckInSheet.swift`、`PostUseReflectionSheet`と同程度の軽さ）を表示。中身は目標1件のリマインドと「閉じる」ボタンのみ（強制力がないことを前提にした誠実な設計。ボタンは1つ、既読確認以上の機能は持たせない）
- docs/11に新規セクション（通知文言・シート文言）を追加してから実装

### 2. 我慢ストリーク＋ご褒美パス
**目的**: Forest/Roots/Flipdのストリーク＋Opalの緊急パスに相当。既存の日次集計データのみを使い、新規データ収集はしない。

- **ストリーク定義**（非難しないトーンに合わせて寛容に定義）: 当日を含めず前日から遡り、「その日に試行が1回以上あり、かつ全て開いた（我慢0回）」日が現れるまでを連続日数とする。試行が0件の日（衝動自体がなかった日）はストリークを途切れさせない。`StatsService`に`resistStreak(asOf: Date) -> Int`を新規実装（`fetchAttempts`の日次走査、境界値・試行0件日・全開放日のテストを必須）
- **パス**: `SettingsStore`に`availablePasses: Int`（既定0）・`lastPassMilestoneStreak: Int`を追加。ストリークが7の倍数を新たに超えたタイミングでパス+1（上限3でキャップ）。付与判定は`AppModel.refresh()`内でストリーク再計算時に実施
- **パス消費**: `InterventionFlowModel`に`redeemPass()`を新規追加。呼吸画面（S-01）に`availablePasses > 0`のときだけ「ご褒美パスを使う（残りN回）」の副ボタンを表示。タップで`availablePasses -= 1`、`engine.resetToIdle()`で状態機械をクリーンにリセットしてから`openTargetApp()`を直接呼ぶ。**`engine.recordOpen()`は呼ばずAttemptLogを作らない**（統計・ストリークに一切影響させないのが「ノーガルティ」パスの本質。SQLiteスキーマ変更を避けられる）
- UI: `HomeView.swift`の`todayCard`（85-107行付近）の近くに新規の小さな`CardContainer`でストリーク日数とパス残数を表示
- Free/Pro: **Freeでも有効**（エンゲージメント機構であり、Pro限定にする価値訴求上の理由がないため）
- docs/11に新規セクション（ホームカード文言・S-01パスボタン文言）を追加してから実装

### 3. 傾向分析カード（Pro）
**目的**: Space/Rootsの「使用パターンの可視化」に相当。「ドーパミン量」のような疑似医療的訴求は避け、既存の理由選択・時刻データの単純集計に留める。

- `StatsService`に`topPatternInsight(from:to:) -> PatternInsight?`を新規実装。`fetchAttempts`を対象アプリ(ruleId→catalogID)×時間帯（朝5-10/昼10-17/夕方17-21/夜21-24/深夜0-5の5バケット、`Calendar.component(.hour:)`から算出）×`intent`で集計し、最頻の組み合わせを1件返す。データ不足（総試行5件未満など）は`nil`
- `PatternInsight`構造体（Core）: `appDisplayName: String, dayPart: String, intentLabel: String, occurrenceCount: Int`
- `EntitlementGate`に`patternInsightsAllowed: Bool`を新規追加（既存の`weeklyReportAllowed`と同じパターン）
- UI: `StatsView.swift`に新規`CardContainer`を追加。文言例「{app}は主に{daypart}に{reason}で開いています」。Freeはロック済みティーザー表示→タップでペイウォール（既存の1年目標Pro表示パターンを踏襲）
- docs/11に新規セクション（カード文言・時間帯ラベル・ティーザー文言）を追加してから実装

### 4.「止める機能」全体オフの24時間クールダウン
**目的**: AppBlock Strict Modeの自己コミットメント装置に相当。**個々の対象アプリの追加・削除には一切影響させない**（Free版は対象アプリ上限が1〜3個で、削除してからでないと別アプリを追加できない仕様のため、個別アプリ単位でクールダウンをかけるとFreeユーザーが対象アプリを一切入れ替えられなくなる。この衝突を避けるため、対象は「止める機能」のマスタースイッチのみに限定する）

- `SettingsStore`に`stopFeatureEnabled: Bool`（既定true）・`stopFeatureDisableRequestedAt: Date?`を追加
- Core新規: 純粋関数（`DayTimeContext`と同系統）で`disableRequestedAt`と`now`から実効状態（有効／保留中(残り時間)／無効）を判定
- ゲート適用点: `StartInterventionIntent`（またはその呼び出し元の`requestStartIntervention`/`consumeInterventionRequest`）で実効状態が「無効」なら介入フローを一切起動しない（対象アプリはそのまま開ける）
- UI: `SettingsView.swift`に新規トグル行「止める機能を使う」（docs/11 §4bに既存のこの文言をそのまま再利用。現状は休眠中のRuleStore経路に紐づいていたラベルを、実際に効いているInterventionTargetStore経路のマスタースイッチとして再配線する）。オフに倒すと即座には切れず「本当にオフにしますか／オフにすると24時間後に反映されます それまでは取り消せます」の確認シート→保留中は「あとN時間でオフになります」＋「やっぱり続ける」で取り消し可能。オンに戻す操作（保留中の取り消し、または24時間経過後の再有効化）にクールダウンはかけない
- docs/11に新規セクション（トグル・確認シート・保留表示の文言）を追加してから実装

## 実装順序・進め方

1. docs/11_ui_copy.mdに4機能分の新規セクションを先に追記（Fableが実施、既存の文言原則・改行ルールに従う）
2. Codexへ**機能ごとに逐次委譲**（同時並列は行わない。SettingsStore.swift/StatsService.swift/InterventionFlowModel.swiftが複数機能で重複して変更されるため、ファイル競合を避けるために直列実行する。プロジェクト規約「並列時は担当ファイル完全分離」に従う）
3. 各機能ごとにFable検証（テスト結果確認・ロジックレビュー）→Codex独立レビュー→指摘是正のサイクルを回す（最大3サイクル）
4. 全機能完了後にdocs/CHANGELOG.md・.claude/tasks/current.md・プロジェクトメモリを更新

## 検証方法
- 各機能ごとに`swift test --package-path ios/Packages/DopaBreakCore`と`xcodebuild build -scheme DopaBreak`で確認
- ストリーク計算・クールダウン判定は境界値テスト必須（ストリーク: 試行0件日/全開放日/連続日数の切れ目。クールダウン: 24時間ちょうど・直前・取り消し後の再オフ）
- モノクロ削除の完了確認（`grep -rn "モノクロ\|Grayscale" ios/ docs/11_ui_copy.md`でヒットゼロ）も本プランの完了条件に含める
