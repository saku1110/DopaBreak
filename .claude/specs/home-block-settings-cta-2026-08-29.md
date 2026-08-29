# ホーム完全ブロックCTAの置き換え（2026-08-29・オーナー承認）

決定: ホームの「30分間 開けないようにする」ボタン（`home.targets.focus_30`・固定30分の `startDeepFocusSession(30)`）を廃止し、完全ブロック設定への導線に置き換える。オーナーが3案から「完全ブロック設定への導線」を選択（2026-08-29）。背景は 2026-08-28/29 の指摘（固定30分に根拠の記録なし・対象未選択でも押せて空セッションが始まり「あと30分 開けません」と表示しながら何も止めない）。

前提: 是正バッチ `settings-home-device-fixes-2026-08-28.md` は実装済み。`AppModel.hasDeepFocusTargets` と SettingsView 側の「完全ブロックするアプリを選ぶ」CTA（F2）は存在する。

## 仕様

### H1. ボタンの置き換え（HomeView.swift）
- `showsStartDeepFocusButton` の分岐で出しているボタンを置き換える:
  - 新ラベルキー `home.targets.block_settings`。ja「完全ブロックを設定する」。en/ko は設定画面の完全ブロック既存語彙（xcstringsカタログ値が正）に一致させる
  - タップ: ホーム経路の `startDeepFocus()`（`startDeepFocusSession(30)` 直呼びと `paywallPlacement = .settingsModeGate`）を削除し、親から渡す閉包 `onOpenBlockSettings` を呼ぶだけにする
  - ペイウォールはホームでは出さない。Proゲートは設定側の既存ゲートに委ねる
- 進行中表示（`showsEndDeepFocusButton` の「完全ブロックを解除」と残り時間表示）は現状維持
- ボタンスタイルは既存の `HomeFocusButtonStyle(kind: .primary)` を継続使用

### H2. 遷移（RootTabView.swift / AppContainer.swift / SettingsView.swift）
- 既存パターンに完全一致させる: `pendingPlanSettingsFocus` / `pendingAutomationGuideRequest` と同型の `pendingDeepFocusSettingsFocus` を `AppModel` に追加
- RootTabView が HomeView へ渡す閉包（`onOpenStats` と同じ並び）で `selectedTab = .settings` ＋ `model.pendingDeepFocusSettingsFocus = true`
- SettingsView は `pendingPlanSettingsFocus` の消費実装と同じ流儀で、止める強さ（完全ブロック）セクションへスクロール・着地させて消費する
- 新しいグローバル状態機構を発明しない。既存フラグ消費の流儀からの逸脱は不可

### H3. 文言（Localizable.xcstrings）
- `home.targets.block_settings` を ja/en/ko の3言語でカタログへ収録（defaultValueだけにしない）
- `home.targets.focus_30` はコード参照を消した上で3言語ともカタログから削除。grep で参照残りゼロを確認
- 表示コピー規則: 句読点なし・ユーザー語彙のみ（介入/シールド等の内部用語禁止・金額なし）

### 触らないもの
- SettingsView の是正バッチ実装（F1/F2/F4）・DeepFocusScheduler・ShieldController・AppContainer の Deep Focus 契約（`startDeepFocusSession` 本体は設定側が使うので削除しない）
- 並行作業中のファイル（LockTheme系・Live Activity系・OnboardingFlow）
- 対象ファイルでも無関係な箇所の整形・リネームはしない

## テスト・検証（全て実行して報告）
- `home.targets.focus_30` の参照残りゼロ（コード・カタログ・テスト）。参照していた既存テスト/スナップショットは新導線に合わせて更新
- `xcodebuild test`（アプリ）: 今回対象のテストが TEST SUCCEEDED（並行作業由来の LockThemeLiveActivityViewTests の既存失敗は対象外と明記して報告）
- `python3 scripts/lint-display-copy.py` / `python3 scripts/audit-default-values.py` exit 0
- シミュレータで ホーム→タップ→設定の完全ブロックセクション着地 のスクショを `output/verify/` に保存
- 報告: 変更ファイル一覧＋3行要約＋検証結果。差分本文は貼らない
