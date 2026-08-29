# 実機指摘の是正バッチ（2026-08-28・オーナー実機テスト由来）

調査正本: Opus5調査（本セッション）。対象は `23033b5` 時点のコード。**別セッションの未コミット差分があるファイル（HomeView / OnboardingFlow / PaywallView / SettingsLockSurfaceView / LockThemePickerView）は、指定したcomputed property以外を編集・整形しない。**

## F1. 一呼吸の長さチップが再描画されない（バグ）
- 原因: `SettingsStore` は Observable ではなく、`SettingsView` は `let settingsStore` で保持（SettingsView.swift:9）。チップ（:728-746）の `isSelected`（:729）が store を直読みするため、書き込み（:732）後に再描画されない
- 修正: `@State private var breathDurationSeconds: Int` を追加し、`refreshSettingsState()` と `onAppear` で store から同期、チップは `@State` を読み、タップで store と `@State` の両方へ書く（ロック画面テーマの ND-1 是正 `@State savedLockTheme` と同じ流儀）
- 一括点検: `SettingsView` / `SettingsNotificationsView` / `SettingsAccountView` / `SettingsAboutView` の body 内で `settingsStore.` を直接読んで選択状態・トグル状態を決めている箇所を全て列挙し、同じ症状のものは同じ方式で直す。列挙結果（file:line）を報告に含める

## F2. ディープフォーカス「開始」が無反応（UX欠落）
- 現状: `startSessionButton`（SettingsView.swift:1336-1358）は `primaryRule == nil` で `.disabled` ＋ 45%透明。説明は枠外脚注（:1782-1787）のみ
- 修正: `primaryRule == nil` のときはボタンを**無効にせず**、ラベルを新キー `settings.deep_focus.choose_apps`（ja「完全ブロックするアプリを選ぶ」／en「Choose apps to block」／ko「완전 차단할 앱 선택」）に切り替える。タップ: `model.screenTime.isAuthorized` が false なら既存の許可シート → 許可後に既存 `handleAppSelectionTap()`（FamilyActivityPicker）へ。選択済みになったら従来の「開始」に戻る
- 脚注は残す。透明化は撤去

## F3. ホーム「30分だけ開けなくする」（→ 本バッチから除外・別仕様へ）
- 2026-08-28 オーナー判断: ホームのこのボタンは「N分開けなくする」ではなく、**止めているアプリごとの個別設定画面へ行く導線**に置き換える。設計は `.claude/specs/per-app-settings.md`（作成予定）で扱う。本バッチでは `HomeView.swift` を**触らない**
- ただし空セッション問題（対象未選択でも `startDeepFocusSession` が走る）の判定は本バッチで基盤だけ用意する: `AppModel.hasDeepFocusTargets`（`rules.first { !$0.activitySelectionData.isEmpty } != nil` を1箇所に集約）を追加し、`SettingsView.primaryRule` の判定もそれを使う。ホーム側の差し替えは別仕様で行う

## F4. 起床・就寝タイムラインをドラッグ可能に（仕様変更・オーナー指摘）
- 現状: `timelineBar`（SettingsView.swift:942-991）のハンドルは `Button` → ポップオーバーの `DatePicker`。DragGesture なし（phase3-brief:16「ドラッグ実装はしない」→ 2026-08-28 オーナー指摘で撤回）
- 修正: ハンドルに `DragGesture` を追加。トラック幅→時刻の変換は **15分刻みにスナップ**、スナップ時に `.selection` 触覚。ドラッグ中は時刻ラベルをハンドル上にライブ表示。起床と就寝が交差しないよう最小間隔を1時間で制約。タップ→ポップオーバーは維持（微調整用）。`accessibilityAdjustableAction` で VoiceOver も15分刻みで動かせるように
- 純関数 `WakeSleepTimelinePolicy`（Core）: `time(forOffset:trackWidth:)`／`offset(forTime:trackWidth:)`／`snapped(_:)`／`clamped(wake:bed:)` を切り出しテスト（境界: 0:00/24:00 跨ぎ・最小間隔・スナップ）

## テスト
- Core: `WakeSleepTimelinePolicyTests`（新規）
- App: `DeepFocusTargetGuardTests`（新規）: `hasDeepFocusTargets` の真偽（対象あり／なし／空データ）
- 既存テストファイルは編集しない。新規ファイル追加後 `cd ios && xcodegen generate`

## 検証（全て実行して報告）
- `swift test`（Core）／`xcodebuild test`（アプリ全体）TEST SUCCEEDED
- `python3 scripts/lint-display-copy.py` / `python3 scripts/audit-default-values.py` exit 0
- シミュレータで設定画面（止める強さ＝ディープフォーカス・対象未選択の「完全ブロックするアプリを選ぶ」表示）とタイムライン（ドラッグ中のライブ時刻表示）のスクショを `output/verify/` に保存
- 報告: 変更ファイル一覧＋3行要約＋F1一括点検の列挙＋検証結果。差分本文は貼らない
