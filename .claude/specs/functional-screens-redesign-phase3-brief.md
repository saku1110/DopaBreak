# Phase 3 実装ブリーフ — 設定（SettingsView）（2026-08-22・オーナー承認済み・判断C=子画面分割）

親仕様: `.claude/specs/functional-screens-redesign-proposal.md`。モック: `output/mockups/functional-screens-redesign-2026-08-22.html` §04。共通制約は Phase 1 ブリーフ §0 と同じ。Phase 1 の `AppIconView` / `AppIconStack` / `DopaRing` を使う。

## 0. 原則
- **ロジック・保存先・ゲート（Pro判定・PaywallPlacement）・ScrollViewReader の通知着地（`settings.section.account`）は変えない。** 並び・見た目・階層だけを再構成する。
- 現行 `SettingsView.swift`（2230行）は大きいので、子画面を別ファイル（`SettingsNotificationsView.swift` / `SettingsLockSurfaceView.swift` / `SettingsAccountView.swift` / `SettingsAboutView.swift`）へ**既存コードを移動**する形で分割する（コピーして残さない）。`@State`・ストア参照は親から渡す。

## 1. トップ画面の構成（上→下）
1. **ステータスカード「いまの守り」**（新規）: 左 `DopaRing(progress: 今日の率, expression: ホームと同じ判定, diameter: 64)`、中央 eyebrow 新規キー `settings.status.title` = いまの守り／1行目 16pt bold「{強さ名} ・ 一呼吸 {秒}秒」（強さ名は既存 `InterventionModeDisplay` の文言、秒は `home.targets.breath_seconds` と同じ書式を再利用）／2行目 `AppIconStack`（選択中カタログアプリ、size 30、maxVisible 4）。右端に今日の開かなかった回数 22pt `.black` accent ＋ 11pt「今日 開かなかった」（既存文言再利用）。Deep Focus 実行中は2行目を「残り◯分 ・ いま解除」の既存表示に差し替える（既存ロジック流用）。
2. **止める強さカード**（新規・`ModeCard` 3枚）: eyebrow 既存「止める強さ」。`LazyVGrid` 3列、各カード: アイコンタイル30pt（標準=`wind`／Deep Focus=`lock.shield.fill`／夜だけ強化=`moon.stars.fill`）＋名前13pt bold＋説明11pt 2行（既存 `InterventionModeDisplay` の名称・説明を再利用）。選択＝`inset 0 0 0 2px accent`＋外側 `accent 12%` 4pt リング、アイコン地 accent 14%。Free は Deep Focus／夜だけ強化に `Pro` 小バッジを付け、タップで既存 `settingsModeGate` ペイウォール。選択ロジックは既存 Picker の `onChange` と同じ経路を呼ぶ（Picker は削除）。
3. **対象・長さ・自動化カード**: 3行。各行左にアイコンタイル（30pt・角丸8）: `square.grid.2x2.fill`（accent地・黒シンボル）／`clock`（`#2C3139` 地・白）／`bolt.fill`（同）。
   - 止めるアプリ: 値は文字列連結をやめ `AppIconStack(size 24)`＋chevron。タップで既存ピッカー。
   - 一呼吸の長さ: 右側に **3チップ（3秒／5秒／8秒）** 横並び（Picker.menu を置換、選択＝accent文字＋枠）。
   - 自動で一呼吸を出す設定: 値「設定済み」（accent）／「未設定」（secondary）を既存の検証状態から表示、chevron。
4. **起床・就寝カード**（DatePicker 2行を置換）: eyebrow 既存「起床・就寝時刻」。**24hタイムライン**: 高さ26の角丸バー（0:00〜24:00、就寝→起床の夜帯を `#1B2A4A`、日中を `#2C3139`）、☀（起床）と ☾（就寝）の34ptハンドル（白地・黒シンボル）。ハンドルをタップすると既存の `DatePicker(.compact)` をポップオーバー/シートで出して時刻を変える（ドラッグ実装はしない）。下に `0:00 ／ 7:00 起床 ／ 23:00 就寝` のラベル（monospaced 11pt）。右上に nightOnly が有効なら「夜は完全ブロック」（既存文言再利用）。
5. **入口3行カード**: 通知（`bell.fill`、値＝有効な通知の要約「朝の目標 ・ 週次」など既存状態から生成、最大2項目＋「ほか」）／ロック画面の表示（`lock.iphone` or `iphone`、値＝現在テーマ名）／DopaBreak Pro（`star.fill`・ピンク `#F58FB4` 地、値＝Free/Pro）。各行 `NavigationLink` で子画面へ。
6. **Deep Focus の「いますぐ始める」「毎週の予定」**: Pro かつ強さが Deep Focus のときだけ、止める強さカードの直下に現行の操作UI（チップ＋開始ボタン／曜日丸チップ＋時刻）を**そのまま**出す（見た目は既存、配置だけ移動）。標準・夜だけ強化のときは出さない。Free は既存ロック行（`lock.fill` + Pro）を同位置に1行で出す。
7. **利用時間の通知セクション**は子画面「通知」の中へ移動（トグル・間隔・就寝前トグル・Free説明とロック行はそのまま）。
8. フッター: 「プライバシーと情報」の1行（`info.circle`）→ 子画面 About（プライバシーポリシー／利用規約／全データを削除／バージョン／フィードバック／DEBUG項目）。末尾注記「SNSなどのアプリを止める機能は…」は維持。

## 2. 子画面
- 通知: 既存 `lockSurfaceSection` のトグル5つ＋通知時刻＋利用時間の通知（`usageWatchSection` 全部）。各行にアイコンタイル。
- ロック画面の表示: テーマチップ横スクロール＋「ロック画面で確かめる」＋Live Activityトグル（既存）。
- Pro: `accountSection`（Pro状態／買い切り／購入を復元）。`ScrollViewReader` の着地IDは **トップの「DopaBreak Pro」行**に付け替え、通知から来た場合はその行を強調したあと子画面へ自動遷移しない（着地だけ）。
- About: `privacySection` + `appSection`。

## 3. ローカライズ
新規キー（ja/en/ko）: `settings.status.title`（いまの守り）、`settings.entry.notifications`（通知）、`settings.entry.lock_surface`（ロック画面の表示・既存があれば再利用）、`settings.entry.pro`（DopaBreak Pro）、`settings.entry.about`（プライバシーと情報）、`settings.timeline.wake`（起床）、`settings.timeline.sleep`（就寝）、`settings.automation.configured`（設定済み）、`settings.automation.not_configured`（未設定）、`settings.summary.more`（ほか%lld件）。既存文言は再利用。

## 4. スクリーンショット
`output/screenshots/redesign-phase3/settings-top.png`（Pro・標準）、`settings-top-free.png`、`settings-notifications.png`。

## 5. 報告
Phase 1 と同じ形式。移動したコードの元→先の対応表（関数名）を必ず書く。

## 追記（2026-08-24）
文言は `.claude/specs/functional-screens-redesign-copy-sheet.md` の「Phase 2〜4・既存文言の書き換え」を正とする（本ブリーフ内の文言例と食い違う場合はコピーシートが勝つ。例: settings.status.title=いまの守り→「止める設定」、stats.apps.title=アプリ別→「アプリごと」、goals.preview.title=「開こうとした瞬間に見える画面」）。既存キーの rewrite 42件（英語見出しSUMMARY系の日本語化・「週次」廃止・「戻す」→「解除する」等）も該当Phaseの画面を触るタイミングで同時に適用する。gate系文言は docs/11_ui_copy.md §6c を正とし変更しない。
