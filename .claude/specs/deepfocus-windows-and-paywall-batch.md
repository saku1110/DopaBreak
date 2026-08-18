# Deep Focus窓機能＋ペイウォール6行＋目標無料化 設計契約（2026-08-17・Fable設計・オーナーGO取得済み）

オーナー決定（本日の会話・引用可能）: ①ペイウォール6行差し替え ②目標の無料無制限化 ③モード説明2キーの実動作合わせ ④Deep Focus窓機能（いますぐ30分/1h/2h/戻すまで・デフォルト1時間＋週次スケジュール1本=曜日+時間帯・時間切れ自動解除）。スケジュールは1本まで（複雑なルールビルダー化の回避=competitor-profiles/_summary.md「Explicitly avoid」準拠）。

## ワークストリーム分担

| WS | 担当 | 内容 | 所有ファイル |
|---|---|---|---|
| E | Codex (gpt-5.6-sol/max) | ④Deep Focus窓機能 | ShieldSyncPolicy.swift / SettingsView.swift / AppContainer.swift / NightShieldScheduler.swift(参照・共通化する場合は新DeepFocusScheduler.swift) / MonitorExtension / SettingsStore.swift(窓設定キー) / 新Core: DeepFocusWindowPolicy.swift＋Snapshot / Localizable.xcstrings(窓UI新キーのみ) / Coreテスト |
| F | Opus5 (worktree) | ①②③ | PaywallView.swift(機能リスト行構成) / EntitlementGate.swift(goalsLimit) / GoalsView.swift / OnboardingFlow.swift(目標ゲート箇所のみ) / Localizable.xcstrings(ペイウォール行＋モード説明2キーのみ) / docs/15・design-decisions.md追記 / EntitlementGateTests ほか関連テスト |

xcstringsのみ両WSが触る。**追加・変更キー一覧を両WSとも最終報告に含める**（マージ衝突時のFable手動再適用用）。SettingsView/AppContainerはWS-E専有。OnboardingFlowはWS-F（目標ゲート）とWS-E（なし）で分離済み。

## WS-E: Deep Focus窓機能

### 意味論の変更
- 現行: mode==.deepFocus 選択中は常時シールド
- 新: mode==.deepFocus 選択中、**窓がアクティブな間だけ**シールド。窓は2種:
  1. **セッション**（いますぐ）: 30分/1時間/2時間/自分で戻すまで。デフォルト選択=1時間。「戻すまで」=終了時刻なしセッション（現行の常時ブロックの後継）
  2. **週次スケジュール1本**: 曜日集合（毎日=全曜日）＋開始/終了時刻。跨日窓可（例 22:00→翌6:00。NightWindowPolicyの跨日判定パターンを踏襲）
- 夜だけ強化(nightOnly)は現状のまま独立（睡眠時刻連動）。統合しない

### Core（純関数・テスト必須）
- 新規 `DeepFocusWindowPolicy`: `isWindowActive(now:session:schedule:calendar:) -> Bool`。セッション（endDate nil=無期限含む）とスケジュール（weekdays+start/end分・跨日対応・15分未満の窓は無効=NightWindowPolicyと同じ縮退）を判定
- `ShieldSyncPolicy`: `isNightWindow` と並ぶ入力として `isDeepFocusWindowActive: Bool` を追加し、deepFocusルールの通過条件を「常時」→「窓アクティブ時」へ。**既存の不変条件（未confirmed=preserve/確定Free=ルール読取前に無条件clear/throw時preserve/非破壊降格）は一切変えない**
- スナップショット: nightOnlyの`NightShieldSnapshot`パターンで `deepfocus_shield_snapshot.json`（selectionDataList＋schedule＋sessionEnd＋updatedAt）。拡張はこれだけを読む（権利判定・RuleStore読取を拡張内でしない）

### スケジューラ（NightShieldSchedulerの設計原則を踏襲）
- DeviceActivityScheduleで窓境界を駆動（曜日はDateComponents(weekday:)・repeats。セッション終了はone-shot）＋**アプリ前面時のsyncShieldで再計算フォールバック**（二重化）
- シールドストアは専用 `ManagedSettingsStore(named: "dopabreak.deepfocus")`（夜間"dopabreak.night"・常時"dopabreak.rules"と分離し相互に触らない）
- 順序の規律（nightOnlyレビュー指摘の踏襲）: 降格時=監視停止→控え削除→解除の順。rebuild=控え書込→成功時のみstop→start。startMonitoring失敗時は掛けっぱなしにしない。境界コールバックは控えの時刻で「いま窓内か」を検算してから動く
- **時間切れ解除の保証が最重要**（「終わったのに開けない」は新種の閉じ込め事故）: 拡張のintervalDidEnd＋前面復帰再計算＋確定Free無条件clearの三重。実機検証項目に「時間切れ解除」「指定曜日のみ発火」「翌週再発火」を追加すること

### UI（SettingsView・完全ブロックセクション内）
- いますぐ開始: 30分/1時間/2時間/自分で戻すまで の4択（デフォルト1時間・ワンタップ開始）。実行中は残り時間と「いま解除」を表示
- スケジュール: 曜日チップ（月〜日）＋開始/終了時刻ピッカー（DatePickerの成分変換=夏時間対応はnightOnlyの実装パターンを流用）＋ON/OFF
- 文言: 内部用語（介入/シールド）禁止・見出しは句読点なし。既存 `settings.deep_focus.*` の説明文も窓の意味論に合わせて改訂（「強さを標準へ戻すまで続きます」→窓の説明へ）。3言語・linter通過
- セッション終了通知1本（事実のみの文言・QuietHours対象外でよいか→対象外とする: ユーザーが自分で設定した窓の終了通知のため）

## WS-F: ペイウォール6行＋目標無料化＋モード説明

### ① ペイウォール6行（確定コピー・変更禁止）

| キー | ja | en | ko |
|---|---|---|---|
| paywall.feature.unlimited_apps（既存値維持） | 止めるアプリを何個でも追加 | Add unlimited apps to pause | 브레이크 걸 앱 무제한 추가 |
| paywall.feature.deep_focus（値変更） | 選んだアプリを完全にブロック | Fully block the apps you choose | 고른 앱 완전 차단 |
| paywall.feature.night_block（新規） | 就寝中は自動で完全ブロック | Auto-block while you sleep | 자는 동안 자동 완전 차단 |
| paywall.feature.usage_watch（新規） | 使いすぎたら15分ごとに声かけ | Check-ins as often as every 15 minutes | 15분마다 확인 알림 받기 |
| paywall.feature.full_history（値変更） | 記録と週次レポートを全期間 | Full history and weekly reports | 전체 기록과 주간 리포트 |
| paywall.feature.lock_theme（既存値維持） | ロック画面テーマを着せ替え | Customize lock screen themes | 잠금화면 테마 바꾸기 |

- ja現行の「止めるアプリを何個でも追加**できる**」→「〜追加」へ短縮（言い切り統一）
- PaywallViewの行構成をこの6行・この順に。`paywall.feature.unlimited_goals`・`paywall.feature.weekly_report` は行から除去（キーは削除してよい。ただしxcstrings削除はWS-Eの追加キーと衝突しないhunkで）
- en/koはhumanizer監査ゲート通過済みの確定値。改変しない

### ② 目標の無料無制限化（オーナー承認済みの課金設計変更）
- `EntitlementGate.goalsLimit`: Free=1 → 無制限(nil)。Pro差なし
- 目標追加のゲート・ペイウォール導線を除去: AppContainer(canAddGoal/replaceGoals系)・GoalsView・OnboardingFlowの目標件数ゲート。**目標データ・UIそのものは不変**（ゲートだけ外す）
- EntitlementGateTests更新。docs/15の機能表・design-decisions.mdに決定を追記（2026-08-17オーナー決定・理由=目標は介入体験の中核でFree制限が継続を毀損・課金推進力が弱い）

### ③ モード説明2キー（実動作合わせ・窓の意味論で書く）
- `intervention_mode.deep_focus.detail`: ja「決めた時間は選んだアプリを完全ブロック」/ en「Fully blocks your chosen apps during the times you set」/ ko「정한 시간에는 고른 앱을 완전 차단」
- `onboarding.mode.deep_focus.confirmation.message`: ja「Deep Focus中は選んだアプリを開けません。時間はいつでも変えられます。」/ en/koは同義でtranscreation（本文なので句読点可）

## 共通規律
- コミット禁止・TODO省略禁止・既存スタイル踏襲・3言語完備・`scripts/lint-display-copy.py` exit 0
- 検証: Core swift test 0失敗＋アプリビルドSUCCEEDED（可能ならアプリテストも）
- クロスレビュー: WS-E(Codex実装)→Opus5レビュー / WS-F(Opus5実装)→Codexレビュー。指摘はFable裁定→実装者差し戻し
