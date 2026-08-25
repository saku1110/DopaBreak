# ホーム主役指標を「永久累計の開かなかった時間」に変更（2026-08-25 オーナー決定）

## 決定（オーナー発言の要約・2026-08-25）
- ホームのヒーローは「開くのをやめた回数／割合」ではなく **開かなかった推定時間** にする
- その時間は **リセットされず永久に積み上がる**。単位が 分→時間→日→年 と繰り上がっていくこと自体が使い続ける理由になる
- 「この調子なら1年で約N日分」の **予測は出さない**（実績のみ）
- 目標との換算・並置は **しない**（目標は抽象・長期の可能性が高い）

## 画面仕様（HomeView の heroSection 内 achievementBlock を置き換え）

```
SNSに消えるはずだった時間            ← SmallLabel相当（既存の見出し語調に合わせる）
1日 3時間                             ← 累計。56pt black rounded。accent色。既存の数字スタイルを流用
今日 +47分                            ← 20pt black primaryText。今日の増分。0のときは「今日 +0分」ではなく下の空状態文
やめた3回 × 1回あたり約15分           ← 14pt semibold secondaryText。推定の根拠（今日の値）
[連続 N日]                           ← 既存のストリークカプセルはそのまま
```

- 今日まだ1回も開こうとしていない日: 増分行の代わりに既存文言 `home.achievement.empty_body`「今日はまだ開こうとしていません」を出す。累計は常に表示する
- 初日で累計も0のとき: 累計は「0分」。既存の `firstDayEmptySection` はそのまま
- 既存の `reclaimedTimeCard`（今週＋年換算予測）は **削除**（ヒーローと重複するため）。関連キー `home.reclaimed.week_label` `home.reclaimed.yearly` は不要になるので削除
- 累計が繰り上がる瞬間の演出（触覚・カード）は今回のスコープ外。数値は `contentTransition(.numericText())` のまま

### 累計の表示単位（自動繰り上げ・切り捨て）
| 累計 | ja | en | ko |
|---|---|---|---|
| 60分未満 | `47分` | `47 min` | `47분` |
| 24時間未満 | `9時間20分` | `9 hr 20 min` | `9시간 20분` |
| 365日未満 | `1日 3時間`（分は出さない） | `1 day 3 hr` | `1일 3시간` |
| 365日以上 | `1年 12日`（時間は出さない） | `1 yr 12 days` | `1년 12일` |
- 1日=24時間、1年=365日。端数の下位単位が0なら省略（例「1日」「2時間」）
- 今日の増分は既存の `home.reclaimed.minutes` / `hours_minutes` 形式に `+` を付ける

### 文言（xcstrings が正。3言語とも追加・置換）
| key | ja | en | ko |
|---|---|---|---|
| `home.hero.lifetime.title` | SNSに消えるはずだった時間 | Time social media didn't take | SNS에 뺏기지 않은 시간 |
| `home.hero.today_delta` | 今日 +%@ | Today +%@ | 오늘 +%@ |
| `home.hero.basis` | やめた%1$d回 × 1回あたり約%2$d分 | %1$d skipped × about %2$d min each | %1$d번 참음 × 1번에 약 %2$d분 |
- 見出しに句読点を入れない。`home.achievement.title`「開くのをやめた」と `count_unit` はヒーローから外れるので、他で未使用なら削除

## データ設計（最重要: 累計は単調増加でなければならない）

現行 `StatsService.reclaimedSeconds(from:to:)` は「直近30日に開いた選択時間の中央値 × やめた回数」を毎回再計算する。中央値が下がると **過去の累計が縮む**。永久カウンターが減るのは信頼を壊すので、次の台帳方式に変える。

1. **台帳テーブル** `reclaimed_ledger`（SQLiteLogStore にマイグレーション追加・user_version を上げる）
   - `attempt_id TEXT PRIMARY KEY`, `seconds INTEGER NOT NULL`, `recorded_at REAL NOT NULL`
2. **確定タイミング**: InterventionEngine が `decision: .cancelled` の AttemptLog を書く同じトランザクションで、**その時点の推定秒数**（既存ルール: 直近30日の opened の selectedDurationSeconds 中央値、無ければ300秒）を1行 INSERT する。以後この行は再計算しない
3. **既存ユーザーのバックフィル**: マイグレーション時に一度だけ、既存の cancelled 試行すべてを現在の中央値（無ければ300秒）で台帳に投入する。二重投入防止は PRIMARY KEY で担保
4. **読み出しAPI**（StatsService）
   - `reclaimedSecondsAllTime() -> Int` … `SUM(seconds)`
   - `reclaimedSeconds(from:to:)` … 台帳の `recorded_at` 範囲 SUM に置き換える（今日の増分用。既存呼び出しの意味を変えない）
   - 中央値の算出は Engine と StatsService の両方から使うので、Core 内の1か所（例 `ReclaimedTimeEstimator`）に寄せる
5. 試行ログの削除・リセット機能が既にある場合は台帳も同じ経路で消す。無ければ触らない

## テスト（DopaBreakCore / DopaBreakTests）
- 中央値が後から下がっても `reclaimedSecondsAllTime()` が減らない
- cancelled 記録1回につき台帳が1行だけ増える。opened では増えない
- バックフィルは1回だけ走り、2回目のマイグレーションで重複しない
- 表示フォーマッタの境界: 59分 / 60分 / 23時間59分 / 24時間 / 364日23時間 / 365日、下位単位0の省略、3言語
- 既存テストが通ること（`swift test` と xcodebuild test）

## 制約
- 省略・TODO禁止。既存の DesignTokens / dopaFont / CardContainer / SmallLabel を使い、新しい見た目部品を増やさない
- UI文言に内部用語（介入・シールド・ledger等）を出さない
- 変更後、`CoreScreensSnapshotCapture.swift` とスクショ生成スクリプトがヒーローの旧キーに依存していればビルドが通るよう追従する（見た目の再設計は不要）

## レビュー差し戻し（2026-08-25 Opus5レビュー → Codex修正指示）
以下を修正し、既存テスト＋各項目のテストを通すこと。

1. **[major] 今日の増分と根拠行の集計軸を揃える** — `todayReclaimedSeconds` は台帳の `recorded_at`（completedAt）で、`todayCancelledCount` は `attempt_logs.started_at` で今日を判定していて食い違う（23:59:50開始→00:00:10やめた、で「今日 +0分／やめた1回」になる）。根拠行の回数を **台帳の同一窓（recorded_at）から数える** API を StatsService に追加し、HomeView の根拠行はそれを使う。テスト: 日跨ぎ1件で増分と回数が同じ日に出る
2. **[major] 1回あたり分の捏造をやめる** — `estimatedMinutesPerCancellation` の `max(1, seconds/60)` は今日の秒数が0のとき「約1分」を出す。`todayReclaimedSeconds == 0` または回数0のときは現在の推定値（`estimatedSecondsPerCancellation`、既定300秒）へフォールバックする。テスト: 回数1・秒数0 → 約5分
3. **[minor] en の `home.reclaimed.years_days` に単数形** — `1 yr 1 days` になる。`years_days` / `years_days_plural`（"%1$lld yr %2$lld day" / "... days"）に分ける。境界テストに 366日 を追加
4. **[minor] バックフィルを毎回起動時に自己修復させる** — `INSERT OR IGNORE ... SELECT ... WHERE decision='cancelled'` は冪等で軽いので、`user_version` ゲートの外で **DBオープンごとに実行**する（旧ビルドへ戻って書かれた cancelled 行が永久に欠落するのを防ぐ）。テスト: 台帳なしで cancelled を直接挿入→再オープンで台帳に補完される
5. **[minor] 死にキー削除** — `home.achievement.summary` は参照が無いので xcstrings から削除
6. **[minor] スナップショット用フィクスチャの順序** — `CoreScreensSnapshotCapture.swift` の日次シードで cancelled が opened より先に入るため、初期の cancel が300秒フォールバックで推定される。各日で opened 行を先に挿入し、ヒーロー値がフィクスチャの件数から決まるようにする
- 変更しない: `deleteAllLogs()` で台帳も消える挙動（ローカルデータ全削除はユーザーの明示操作なので仕様どおり）。`scripts/*.py` は別セッションが編集中のため触らない

## 改訂2（2026-08-25 オーナー指示）: ヒーローは常に「時間」表記・横に日／年換算

「累計が日・年に繰り上がる」方式は廃止。数字が繰り上がりで小さく見える（24時間→1日）ため、主役は**時間の数字を伸ばし続け**、人生尺度は横の換算で見せる。

```
SNSに消えるはずだった時間
312時間  13日分          ← HStack(lastTextBaseline)。累計=56pt accent（既存）、換算=20pt semibold secondaryText
今日 +47分
やめた3回 × 1回あたり約15分
[連続 N日]
```

### 累計本体（56pt）
| 累計 | ja | en | ko |
|---|---|---|---|
| 60分未満 | `47分` | `47 min` | `47분` |
| 60分以上 | `312時間`（分は切り捨てて出さない） | `312 hr` | `312시간` |
- 既存の `home.reclaimed.minutes` / `home.reclaimed.hours` を使う。日・年への繰り上げは**しない**（`days*` / `years*` キーは換算側でのみ使用）

### 横の換算（20pt・累計の右・ベースライン揃え）
| 累計 | ja | en | ko |
|---|---|---|---|
| 24時間未満 | 非表示 | 非表示 | 非表示 |
| 24時間以上 365日未満 | `13日分` | `= 13 days` | `13일치` |
| 365日以上 | `1年 73日分`（日が0なら `1年分`） | `= 1 yr 73 days` | `1년 73일치` |
- 1日=24時間、1年=365日、切り捨て。en は `1 day` / `1 yr` の単数形を守る
- キーは新設 `home.hero.lifetime.days_equiv`（`%lld日分`）／`days_equiv_plural`／`years_days_equiv`（`%1$lld年 %2$lld日分`）／`years_days_equiv_plural`／`years_equiv`（`%lld年分`）／`years_equiv_plural`。既存の `home.reclaimed.days*` / `years*` キーが未使用になったら削除
- 「今日 +N分」は既存どおり（分／時間分）
- テスト: 59分／60分／23時間59分（換算なし）／24時間（`24時間  1日分`）／364日23時間／365日（`8760時間  1年分`）／366日（`1年 1日分`）を3言語で。既存の繰り上げ境界テストは置き換える
- スナップショット・撮影経路（`testCaptureRedesignPhase1Screens`）が通ること。フィクスチャ値は 6時間（換算なし）／今日 +2時間

## 撮影フィクスチャ追加（2026-08-25 オーナー指示「スクショのホーム累計時間は100時間以上」）
対象は `ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` のみ（アプリ本体は触らない）。
- 新規 `seedRedesignLifetimeHistory(in:ruleIDs:now:)` を追加し、**14日以上前**（-14 〜 -81 の68日間）に各日「opened 2件（selectedDurationSeconds 600・先に挿入）＋ cancelled 27件」を積む → cancelled 1,836件 × 600秒 ＝ 306時間。既存7日分（cancelled 36件・6時間）と合わせ **累計 312時間＝13日分**、やめた累計回数 1,872回
- 呼び出す箇所: ホームを撮る経路のみ＝ `testCaptureRedesignPhase1Screens`（現在 `seedRedesignAttemptLogs` を呼ぶ直後）と、ロケール別のホーム撮影 `testCaptureHomeScreen` の経路（`seedRedesignAttemptLogs`/`seedRedesignPreviousWeekAttempts` を呼んでいる箇所の直後）。**記録（stats）画面の撮影経路には入れない**
- 直近7日（今週36回・今日+2時間・やめた12回×約10分・連続7日）と前週（-13〜-8）の数値は変えない。連続日数の判定に影響しないよう -14 より前だけに置く（-14 に置くと連続が延びる場合は -15 以前にずらす）
- 挿入は既存の `logStore.insert` を使う（台帳が確定される）。完了後、各撮影経路でヒーローに出る累計時間・換算日数・やめた累計回数を報告する
