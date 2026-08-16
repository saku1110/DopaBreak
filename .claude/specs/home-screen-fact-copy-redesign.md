# ホーム画面の事実コピー再設計＋defaultValue同期監査

- 日付: 2026-08-15
- 承認: オーナー（改訂版提案に「おｋ」）
- 対象: `ios/DopaBreak/HomeView.swift`、`ios/DopaBreak/Localizable.xcstrings`、全SwiftファイルのdefaultValue同期

## 決定事項（背景）

- ホーム画面の文言は「事実・問い・行動」のいずれかに分類できるものだけにする。詩・比喩・掛詞は禁止（7/2「アプリを守り始める」8/14「最初のひと呼吸から今日が始まる」8/15「戻りたい先」で3度指摘された族の恒久対策）
- 行動語彙は **「開こうとした ↔ 開かなかった」** のペアに全統一。「戻れた」「選べた」「立ち止まれた」等の解釈語は使わない
- 「戻る」は操作語（iOSの戻るボタン）と衝突し戻り先も曖昧なため、行動カウントの動詞には使わない。既存の自然な用法（この時間を取り戻す/二度と戻らない/標準へ戻す）はそのまま
- **実行時の正はLocalizable.xcstringsカタログ**。コード内defaultValueはカタログと同期させる（ズレの放置が誤認と巻き戻りリスクの根本原因）

## 変更仕様

### 1. 文言変更（カタログja + コードdefaultValue + en/ko）

| キー | 現行カタログja | 新ja |
|---|---|---|
| `home.first_day.title` | 最初のひと呼吸から\n今日が始まる | 開こうとした瞬間に一呼吸が入ります |
| `home.first_day.body` | 対象アプリを開こうとすると、ここに記録がつきます | 開かなかった回数がここに残ります |
| `home.achievement.title` | 今日 自分で選べた | 今日 開かなかった |
| `home.achievement.summary` | 開こうとした%lld回のうち、%@は開きませんでした | 開こうとしたのは%lld回 |
| `home.achievement.empty_body` | 対象アプリを開こうとすると、ここに今日の記録がつきます | 今日はまだ開こうとしていません |
| `home.week.summary` | 今週 %lld回、自分で選び直しました | 今週 開かなかったのは%lld回 |

- `home.first_day.title` の改行はコード・カタログとも撤去し自然折返しに任せる（見出しへの`\n`ハードコード禁止ルール準拠）
- `home.achievement.summary` は%@（成功率）引数が不要になるためSwift側の書式引数も削除する
- en/ko: 既存カタログの対応訳語を再利用して整合させる。特に「一呼吸」「開かなかった」「開こうとした」は削除前の `home.metric.cancelled` / `home.metric.attempted` / `home.automation_status.*` の既存訳語を必ず流用し、新規の言い回しを発明しない。文体は各言語の既存ホーム画面キーに合わせる

### 2. metricsCard削除

- `metricsCard` ビューと `homeMetric(value:label:accent:)` を削除（実績セクションと同一数字の重複表示）
- 未使用になるキー `home.metric.count` / `home.metric.cancelled` / `home.metric.attempted` をカタログから削除（他所で未使用であることをgrepで確認してから）
- レイアウト: metricsCard跡地の余白を調整し、achievementSection→weekSignalの間隔が不自然に空かないようにする

### 3. キャラクター状態ロジック

- 現行: `model.todayCancelledCount > 0 ? .awake : .doom`（毎朝必ずdoom）
- 新: **doomは「今日開こうとして1回も開かなかったことがない」状態のみ** = `model.todayAttemptCount > 0 && model.todayCancelledCount == 0 ? .doom : .awake`
- reliefは使わない（「安堵は呼吸をやり遂げた報酬」の8/14決定を維持）

### 4. 目標カード空状態の見た目

- 文言「タップして目標を追加」は維持（カタログは既に正常）
- 現在は目標本文と同じ29pt/22pt黒字primaryTextで表示され、本物の目標と見分けがつかない。**空状態のときだけアクション風に**: `DesignTokens.accent` の20pt bold程度＋既存のarrow.up.rightアイコン維持。目標設定済みのときの表示は変えない
- `primaryGoalTitle` のdefaultValue「SNSの先ではなく、戻りたい先を決める」もカタログ値「タップして目標を追加」へ同期

### 5. defaultValue同期の全数監査（根本対策）

- 全Swiftファイルの `String(localized:...defaultValue:)` を走査し、カタログjaと意味が異なるdefaultValueをカタログ値へ同期する（スクリプト化推奨: xcstringsをパースしてキーごとに比較）
- 書式引数はSwift側の文字列補間の形（`\(...)`）を保ちつつ、文言部分をカタログに合わせる
- 判明済みのズレ: `home.goal.fallback`、`home.metric.cancelled`、`intervention.goal_reminder.title`（戻りたい自分→あなたの目標）、`goals.empty.title`（戻りたい自分を決める→目標を決める）、`home.achievement.*`ほか多数。監査結果の一覧（キー・旧defaultValue・新defaultValue）を報告に含める
- カタログ側が正である前提で同期する。カタログ側を書き換えるのは§1の6キーのみ

## スコープ外（触らない）

- heroBandの構成（日付ラベル・週カプセル・キャラ配置）
- automationStatusBanner
- 目標カードの複数目標対応（§6は今回見送りとオーナー確認済み）
- 介入フロー・オンボーディングの文言（§1と§5の同期以外）

## 検証

- `xcodegen generate` → ビルド成功
- DopaBreakTests非キャプチャ全suite 0失敗（iOS 26.5 simがworkers materializeで停止する場合はiOS 18.3系へ切替）
- xcstrings: 削除3キーの参照残ゼロ・変更6キーのja/en/ko充足・JSONパース成功
- defaultValue監査: 同期後に再走査してズレ0件を確認
