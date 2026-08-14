# ペイウォール実体化C: Deep Focus本実装＋週次詳細レポート 設計契約（2026-08-14・Fable設計・オーナー決定「C・Opus並列実装」）

背景: 2026-08-14監査でペイウォール6行中2行（Deep Focus・週次詳細）の実体不在が判明。オーナー決定=両方とも本実装。
正本: docs/12_hybrid_intervention.md（方式C・§5既存実装への影響・H3シールド再配置）。UI着手前に .claude/specs/design-decisions.md を必ず読むこと。

## 前提（Fableの設計判断）

- **Deep Focus v1のスコープ**: Pro専用の「完全ブロック」。FamilyActivityPickerで選んだ対象（トークン）をManagedSettingsシールドで常時ブロックする。docs/12の「指定時間帯」スケジュール機能は今回スコープ外（v1.2）。「止めるアプリ」（カタログ・介入フロー）と「完全ブロックの対象」（Picker・Pro）は別物として画面上も分離する（docs/12 §5）。
- **nightOnly**: UIには出さない（時間帯制御が未実装のため）。シールド同期のモードフィルタは deepFocus のみ通す（nightOnlyの分岐構造は温存してよいが露出禁止）。
- **entitlement結合**: シールド適用は `storeService.hasConfirmedEntitlement && isPro && strictModeAllowed` の時のみ。**Free確定**（confirmed && !isPro）で clearShield。未confirmed（オフライン等）では**現状維持**（シールドを剥がさない・追加もしない）。
- **UI文言**: 内部用語「介入」「シールド」をユーザー向けに出さない（恒久指示）。「完全ブロック」「守り」等の語彙。見出しは句読点なし・体言止め。3言語（ja/en/ko）完備・既存linterの禁止語スキャンを通す。

## ワークストリーム分担（Opus5×2並列・worktree隔離）

| WS | 内容 | 所有ファイル |
|---|---|---|
| C | Deep Focus本実装 | `ios/DopaBreak/ShieldController.swift` / `ios/DopaBreak/AppContainer.swift`（syncShield再配線＋関連のみ） / `ios/DopaBreak/SettingsView.swift` / `ios/DopaBreak/OnboardingFlow.swift`（chooseMode永続化のみ） / ShieldConfigurationExtension関連 / `ios/DopaBreak/Localizable.xcstrings`（自キーのみ） / Core新規純関数＋テスト |
| D | 週次詳細レポート | `ios/DopaBreak/StatsView.swift` / Core `StatsService.swift` / `ios/DopaBreak/Localizable.xcstrings`（自キーのみ） / Coreテスト |

衝突点はLocalizable.xcstringsのみ。**両WSとも追加キーの一覧（キー名＋3言語の値）を最終報告に必ず含める**（マージ失敗時にFableが手で再適用するため）。

## WS-C: Deep Focus本実装

1. **ShieldController.syncShield のモードフィルタ**: 現状は enabledRules 全部を対象にしている。`mode == .deepFocus` のルールのみシールド対象に変更。判定は純関数としてCoreへ切り出しテスト（例: `ShieldSyncPolicy.rulesToShield(rules:isPro:strictModeAllowed:hasConfirmedEntitlement:) -> [TargetRule]` ＋ clear/維持/適用のアクション判定）。
2. **AppContainer.syncShield() 再配線**: 現在no-op（397-401）。実装: 上記条件でshieldController.syncShield / clearShield / 何もしない を分岐。呼び出し箇所を確認し、最低限 refresh()・entitlement確定変化・ルール/選択変更・FamilyActivitySelection保存後に同期されること。
3. **SettingsView UI復活**: MVP非表示の screenTimeRow（スクリーンタイム許可導線）・modePickerRow（止める強さ）・完全ブロック対象のFamilyActivityPicker行を表示に戻す。Free: ロック行＋ペイウォール導線（既存 `.settingsUsageWatchGate` 等のパターン踏襲・placementは適切な既存/新設値）。Pro: モード切替＋Picker操作可能。既存の温存コード（familyActivityPicker配線・ruleEnabledBinding等）を活用。
4. **オンボーディング chooseMode の永続化**: `settingsStore.pendingInterventionMode` が初回ルールに反映されない既知ギャップを修正。deepFocus選択（Pro時）が最初のルールの mode に到達すること。RuleStoreの新API（modeForNewRule）と整合させる。Free が deepFocus を選ぶ経路はペイウォール誘導（既存挙動を確認して踏襲）。
5. **ShieldConfigurationExtension 文言改訂**: 「完全ブロック中」向けのDeep Focus価値訴求文言へ（docs/12 §5）。ボタンは[閉じる]系。3言語。
6. **Pro失効時**: confirmed Freeでシールド解除＋モードstandard化は既存のentitlement降格処理と整合（SettingsViewの降格ガードはhasConfirmedEntitlement前提で実装済み＝並行バッチ）。
7. **テスト**: Core純関数テスト（Free確定→clear / 未confirmed→維持 / Pro+deepFocus→適用 / standardのみ→clear）。アプリビルドBUILD SUCCEEDED。

## WS-D: 週次詳細レポート（Pro専用）

1. **データ層**: `StatsService.weeklySummary()` の `WeeklySummary.days`（既存・未消費）を活用。前週比較のため `weeklySummary(weeksBack: Int = 0)` 相当の拡張を追加（今週/前週のrange計算・Coreテスト必須）。
2. **StatsView**: 週セクションに「週次詳細」を新設。内容: ①7日分の日別バー（開こうとした回数／開かずに済んだ回数。既存E1 Dark Monoの意匠・既存コンポーネントのスタイル踏襲） ②週間合計と前週比 ③既存の週間集計との重複表示を避ける整理。
3. **ゲート**: `entitlementGate.weeklyReportAllowed`（既存・未使用プロパティ）で解放判定。Free: 既存Statsロックカード（`StatsView.swift:133-155`パターン）と同様のロックカード＋ペイウォールCTA。未confirmed時にPro利用者へロックを見せない配慮は既存パターン（キャッシュシードで実質解決済み）と同じ扱いでよい。
4. **通知着地**: 週次レポート通知タップの着地先がStatsになっていることを確認（NotificationRoutingは読むだけ・変更禁止=WS-B所有だった）。着地後に週次詳細セクションへ自然に到達できる配置にする。
5. **テスト**: StatsService拡張のCoreテスト（週range・前週比・空データ・タイムゾーン境界）。アプリビルドBUILD SUCCEEDED。

## 共通規律

- worktreeはHEAD基点のため未コミット変更が無い。**作業開始前に本体 `/Users/solotech/Desktop/test-project/ios/` を worktree の `ios/` へ rsync -a --delete で取り込み、`git add -A` でベースラインとしてステージしてから着手**（未ステージdiff=自分の成果、の形にする）。
- 所有外ファイル変更禁止・git commit禁止・TODO/省略禁止。
- 検証: Core `swift test` 0失敗＋`xcodegen generate`→`xcodebuild build` SUCCEEDED（シミュレータ）。
- 最終報告: 変更ファイル一覧・要約・テスト結果・追加xcstringsキー一覧（3言語の値込み）・worktreeパス。
