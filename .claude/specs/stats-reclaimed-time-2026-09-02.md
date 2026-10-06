# 記録画面を時間中心にする（2026-09-02 オーナー決定）

## 決定（オーナー・2026-09-02）
1. 記録画面のヒーローを **取り戻した時間** にする（今日／今週／全期間の3期間とも）。割合は支える数字として残す
2. 内訳カード（アプリごと・開こうとした理由）も **時間** で表示する
3. **時間帯カードを新設**する（何時に開こうとしているか）
4. 1回あたりの推定は **アプリ別にしない**（全体中央値のまま。`ReclaimedTimeEstimator` は変更しない）
5. 名前は既存の「取り戻した時間」に統一する。「無駄にしなかった時間」という言い方は使わない

### 背景（なぜやるか）
- ホームのヒーロー（8/25）と一呼吸の完了画面（9/1）はすでに時間で喋っている。記録画面だけが回数と割合の世界に残っていた
- 記録画面のヒーロー「開かなかった割合」は悪い日に下がる。積み上がる数字のほうが使い続ける理由になる（8/25にホームで採った判断と同じ）
- **既知の限界**: 台帳の秒数は全体共通の中央値なので、アプリ別・理由別の時間は回数×定数と同じ並びになる。単位を変える価値は認めたうえで、情報量を足す役割は時間帯カードが担う

## 前提・制約
- 台帳 `reclaimed_ledger(attempt_id, seconds, recorded_at)` の確定値は**再計算しない**（累計が縮むと信頼を壊す。8/25決定）
- 表示する時間は推定値。**根拠行は1画面に1つだけ**置く（4か所に時間が出て根拠が無いと作り物に見える）
- UI文言に内部用語（台帳／ledger／介入／シールド）を出さない
- 見出し・短い表示テキストに句読点を入れない。造語・英語eyebrowを使わない
- **`Localizable.xcstrings` のカタログ値が実表示の正**。`defaultValue` と食い違っている既存キーがある（例: `stats.apps.title` のカタログ値は「一呼吸をはさんだアプリ」）。新規キーは ja/en/ko の3言語すべてに値を入れ、en/ko は近隣の `stats.*` キーの語調に合わせる
- 記録画面に課金ゲートは無い（3期間とも無料）。ゲートを新設しない
- 既存の `DesignTokens` / `dopaFont` / `CardContainer` / `SmallLabel` を使う
- 省略・TODO禁止

## 触らないもの
- `ReclaimedTimeEstimator`、台帳の確定タイミングとバックフィル
- ホーム画面、一呼吸、課金・権利判定
- `output/verify/*.png`、`scripts/*.py`（別セッションの領域）

---

## 1. Core に追加するAPI

### 1-1. `SQLiteLogStore`（`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SQLiteLogStore.swift`）

```swift
public func reclaimedSecondsByRule(from: Date, to: Date) throws -> [UUID: Int]
public func reclaimedSecondsByIntent(from: Date, to: Date) throws -> [IntentCategory: Int]
public func attemptStartTimes(from: Date, to: Date) throws -> [Date]
```

- 期間は `recorded_at >= from` かつ `< to`（既存 `reclaimedSeconds(from:to:)` と同じ境界規約）
- ルール別:
  ```sql
  SELECT a.rule_id, SUM(l.seconds)
  FROM reclaimed_ledger l
  JOIN attempt_logs a ON a.id = l.attempt_id
  WHERE l.recorded_at >= ? AND l.recorded_at < ?
  GROUP BY a.rule_id
  ```
- 理由別: 同じJOINで `GROUP BY a.intent`。`a.intent IS NULL` は除外する
- `attemptStartTimes` は `attempt_logs.started_at` を `started_at >= ? AND < ?` で取得する。`AttemptLog` を丸ごと組み立てず日付だけ返す（全期間で件数が伸びるため）
- 時刻の計算をSQLでやらない（タイムゾーンとDSTを壊す）

### 1-2. `StatsService`（同 `Services/StatsService.swift`）

```swift
public func reclaimedSecondsByRule(from: Date, to: Date) throws -> [UUID: Int]
public func reclaimedSecondsByIntent(from: Date, to: Date) throws -> [IntentCategory: Int]
/// 0...23 の時間帯 -> 試行件数。キーが無い時間帯は0件
public func hourlyAttemptBreakdown(from: Date, to: Date) throws -> [Int: Int]
```

- `hourlyAttemptBreakdown` は `attemptStartTimes` の結果を `StatsService` が持つ `calendar`（`Calendar.autoupdatingCurrent`）の `.hour` でバケットする
- 対象は **全試行**（cancelled も opened も）。「開こうとした時間帯」なので我慢できたかは問わない

---

## 2. ヒーローカード（`StatsView.heroCard`）

3期間で同じ構造にする。

```
取り戻した時間                     先週より +1時間20分     ← SmallLabel ／ 右は今週のみ
2時間30分   1日分                                        ← 56pt black rounded ＋ 20pt semibold（24時間以上のときだけ）
開かなかった12回 × 1回約15分                              ← 14pt semibold secondaryText（根拠行）
[DayBars（今週のみ）]
開かなかった 12回   開こうとした 15回   開かなかった割合 80%  ← 11pt bold secondaryText
```

### 2-1. 大きい数字
- 今日・今週: `ReclaimedTimeFormatter.detailedString(seconds:)`（「2時間30分」）
- 全期間: `ReclaimedTimeFormatter.string(seconds:)`（「312時間」）＋ 右に `equivalentString(seconds:)`（「13日分」。24時間未満なら非表示）。ホームのヒーローと同じ書式に揃える
- 既存 `rateDisplay` の 56pt / `.monospacedDigit()` / `.contentTransition(.numericText())` / `.dopaDisplayClamp()` をそのまま流用する
- 期間内の秒数は `statsService.reclaimedSeconds(from:to:)`、全期間は `reclaimedSecondsAllTime()`

### 2-2. 根拠行
- 既存キー `home.hero.basis`（「開かなかった%1$lld回 × 1回約%2$lld分」）を**再利用**する。新キーを作らない
- 回数は `reclaimedCancellationCount(from:to:)`（台帳と同じ窓で数える。日跨ぎのズレを避ける。8/25レビュー指摘1と同じ理由）。全期間は `cancelledAttemptsAllTime()`
- 1回あたりの分は `ReclaimedTimeFormatter.estimatedMinutesPerCancellation(todayReclaimedSeconds:todayCancellationCount:fallbackSeconds:)` を期間値で呼ぶ。fallback は `estimatedReclaimedSecondsPerCancellation(at:)`
- 回数0のときは根拠行を出さない

### 2-3. 先週比を時間にする
- 今週のみ。`WeeklyDetailReport.previous.days` の先頭日〜末日+1日を前週レンジとし、`reclaimedSeconds` の差分を取る
- 新キー（既存の `.same` / `.no_data` は再利用）:

| key | ja | en | ko |
|---|---|---|---|
| `stats.weekly_detail.comparison.more_time` | 先週より +%@ | %@ more than last week | 지난주보다 +%@ |
| `stats.weekly_detail.comparison.less_time` | 先週より -%@ | %@ less than last week | 지난주보다 -%@ |

- `%@` は差分の絶対値を `detailedString` で入れる
- 差分が0のときは `stats.weekly_detail.comparison.same`、前週データなしは `.no_data`
- 既存の accent 強調（数値部分だけ accent 色）は差分の時間文字列に対して行う

### 2-4. 割合を降格する
- 56ptの `rateDisplay` は時間に置き換わる。割合は legend 行に1項目として出す: `stats.rate.title`（「開かなかった割合」）＋ `stats.rate.percentage`
- legend は **3期間とも表示**する（現在は今週のみ）
- 試行0で割合が出せないときは割合項目だけ省く

### 2-5. `periodVisualization` の整理
- 今週: `DayBars` のまま（回数ベースで変更しない。時間は回数に比例するので形は同じ）
- 今日: `metricPair` を**削除**（legend と重複）
- 全期間: `MetricBlock`（`stats.all_time.cancelled`）を**削除**（ヒーローとlegendで足りる）
- 使われなくなった private ヘルパー・キーは削除する。**削除前に必ず grep で他の参照が無いことを確認する**（`MetricBlock` など共有部品は他画面で使っていれば残す）

---

## 3. 内訳カードを時間にする

### 3-1. アプリごと（`appsCard` / `appRow`）
- `StatsAppMetric` に `reclaimedSeconds: Int` を足す
- 右端の `stats.apps.ratio`（「12/15」）を **`detailedString(seconds:)` の時間表示**に置き換える。幅 50pt → 62pt
- 進捗バー（cancelled/attempts）は変更しない
- 並び順を **取り戻した時間の降順**にする（同値なら `localizedStandardCompare` で名前順）
- 回数は表示から消えるので、`accessibilityLabel` に「アプリ名 開かなかった%lld回 開こうとした%lld回 時間」を残す（既存キー `stats.metric.cancelled` / `stats.metric.attempted` / `stats.metric.count` を使う）
- `stats.apps.ratio` が未使用になったらカタログから削除する
- `stats.apps.caption`（完全ブロック除外の注記）はそのまま

### 3-2. 開こうとした理由（`intentCard`）
- チップを「理由 45%」から **「理由 62時間」**（`detailedString`）に変える
- 秒数は `reclaimedSecondsByIntent`。既存の legacy `.anxietyCheck` → `.communication` へのマージは**維持**する（秒数も合算する）
- 並び順は時間の降順。同値は `IntentCategory.allCases` の順
- **その期間に試行があった理由は、取り戻した時間が0でも表示する**（「0分」）。その理由では我慢できていないという事実が読み取れるため。表示対象の判定は従来どおり `intentBreakdown` の件数 > 0
- `intentPercentageText` は未使用になるので削除する

---

## 4. 時間帯カード（新設）

### 表示条件
- `period != .today`（1日分では24本のバーがスカスカで壊れて見える）
- かつ `dashboard.summary.attempts > 0`

### 位置
`detailContentSection` の中で **アプリごとの直後**（アプリごと → 時間帯 → 見たあとの気持ち → 開こうとした理由）

### 見た目
```
開こうとした時間帯                        ← SmallLabel
▁▁▂▁▁▃▅▃▂▂▄▆▃▂▃▄▅▇█▆▄▃▂▁                ← 24本（0時〜23時）
0        6        12        18            ← 11pt secondaryText
22時台がいちばん多い                       ← 12pt semibold secondaryText
```

- 新規ファイル `ios/DopaBreak/HourBars.swift` に `HourBars` を作る。`DayBars.swift` の作り（トークン・角丸・アクセシビリティ）に合わせる
- バーは `HStack(spacing: 2)`、各バー `frame(maxWidth: .infinity)`、高さ = `count / max * 56pt`、0件は 2pt の下地
- ピークの時間帯だけ `DesignTokens.accent`、他は `DesignTokens.hairline` より一段濃い secondary 系。ピークが複数あるときは最も早い時間帯だけを accent にする
- 目盛りラベルは 0 / 6 / 12 / 18 の4つ。`HStack` で等間隔配置
- 事実行は **合計試行が5件以上のとき**だけ出す。未満のときは行ごと省く（少ない件数で「いちばん多い」と言うと嘘になる）
- `accessibilityElement(children: .ignore)` ＋ ピークを読み上げるラベル

### 新規キー

| key | ja | en | ko |
|---|---|---|---|
| `stats.hourly.title` | 開こうとした時間帯 | When you reach for it | 열려고 한 시간대 |
| `stats.hourly.peak` | %lld時台がいちばん多い | Most often around %lld:00 | %lld시대가 가장 많아요 |

- en/ko は近隣の `stats.*` の語調に合わせて調整してよい（ko は「〜해요」体が既存の基調）
- 24時間表記でよい（ロケール別の12時間表記は今回のスコープ外）

---

## 5. カタログの整理
- 追加: `stats.weekly_detail.comparison.more_time` / `less_time` / `stats.hourly.title` / `stats.hourly.peak`
- 削除候補（grep で参照0を確認してから）: `stats.all_time.cancelled`、`stats.apps.ratio`、`stats.weekly_detail.comparison.more`、`stats.weekly_detail.comparison.less`
- **既存バグの修正**: `stats.metric.count` に **en の値が無い**（ja「%lld回」/ ko「%lld회」のみ）。en に `%lld times` を追加する

---

## 6. テスト

### DopaBreakCore
- `reclaimedSecondsByRule`: 期間境界（start含む・end含まない）／複数ルールの合算／期間外を含めない
- `reclaimedSecondsByIntent`: `intent IS NULL` を除外する／同一intentの合算
- `attemptStartTimes`: 境界／降順昇順を問わず件数が合う
- `hourlyAttemptBreakdown`: 固定タイムゾーンの `Calendar` を注入し、UTCとJSTで違うバケットに入ることを検証する／該当なしの時間帯がキーごと欠けても呼び出し側が0扱いできる

### DopaBreakTests（アプリ側）
- ヒーローの書式: 59分／60分／23時間59分（換算なし）／24時間（「24時間 1日分」）を3期間で
- 先週比: 増／減／同じ／前週データなしの4分岐
- 根拠行: 回数0で出ない／秒数0かつ回数ありのとき推定値へフォールバックする
- アプリ行が取り戻した時間の降順に並ぶ
- 理由チップが時間降順で、0秒の理由も表示される
- 時間帯カード: 今日で出ない／試行0で出ない／試行4件で事実行が出ない／5件で出る／ピークが正しい
- 既存テストが通ること

### スナップショット
- `ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` の記録画面の撮影経路がビルド・実行できること。削除したキーに依存していれば追従する。見た目の再設計は不要

---

## 受け入れ条件
- `xcodebuild` が通る。Core・アプリの全テストが失敗0
- SwiftLint 2本が exit 0
- xcstrings が有効なJSONで、追加キーに ja/en/ko の3言語すべて値がある
- 記録画面の3期間すべてでヒーローが時間になっている。割合は残っているが主役ではない
- アプリごと・理由が時間で表示される
- 今週と全期間に時間帯カードが出て、今日には出ない
- 内部用語・句読点付きの見出しが増えていない

---

# レビュー差し戻し（2026-09-03 Opus5レビュー → Codex修正指示）

判定は accept with fixes。以下を修正し、各項目のテストを足したうえで既存テストを通すこと。

## A. 【最優先】集計の窓を `started_at` に一本化する（🟡1 と 🟡2 を同時に解消）

いまカード内で2つの窓が混在している。

- ヒーローの秒数・根拠行の回数・アプリ別/理由別の秒数 → 台帳の `recorded_at`
- legend の回数・アプリ行/理由チップの**存在判定** → `attempt_logs.started_at`

このため (a) 同じ「開かなかった」が根拠行と legend で違う数になりうる（23:5x開始・00:0x キャンセルで日が割れる。8/25に同じ問題を踏んだ箇所）、(b) アプリ行が台帳側にしか無い秒数を拾えず、**アプリ別の合計がヒーローと一致しない**。

**修正方針: 記録画面の中では `attempt_logs.started_at` の窓ですべてを揃える。**

1. `SQLiteLogStore` に開始時刻窓で台帳を集計するAPIを追加する。JOINは既存の `reclaimedSecondsByRule` と同じ形で、**WHERE を `a.started_at >= ? AND a.started_at < ?` に変える**
   ```swift
   public func reclaimedSecondsByStartWindow(from: Date, to: Date) throws -> Int
   public func reclaimedSecondsByRuleInStartWindow(from: Date, to: Date) throws -> [UUID: Int]
   public func reclaimedSecondsByIntentInStartWindow(from: Date, to: Date) throws -> [IntentCategory: Int]
   ```
   `StatsService` に同名のラッパを足す。既存の `recorded_at` 版APIは**削除しない**（ホームが使っている）
2. `StatsView` の今日・今週は上記の start 窓APIへ切り替える。全期間は従来どおり `reclaimedSecondsAllTime()` / `cancelledAttemptsAllTime()`（窓が無いので影響なし）
3. 根拠行の回数を `reclaimedCancellationCount`（台帳窓）から **`dashboard.summary.cancelled`（started_at）** に変える。これで根拠行と legend が必ず一致する
4. 先週比も start 窓の秒数差で計算する
5. 受け入れ確認: **アプリ別の秒数の合計 = ヒーローの秒数** になること。理由別も intent が付いた試行に限れば同様。これをテストで担保する

## B. その他の修正

| # | 箇所 | 内容 |
|---|---|---|
| B-1 | `SQLiteLogStore` の新規集計2本 | `Dictionary(uniqueKeysWithValues:)` は重複キーでクラッシュする。`Dictionary(rows, uniquingKeysWith: +)` に変える |
| B-2 | `HourBars` バー高さ | 2ptの下限が「ちょうど0件」にしか効いていない。ピーク200件に対して1件のバーが0.28ptになり空と見分けがつかない。計算後の高さに `max(2, ...)` を掛ける |
| B-3 | `HourBars` アクセシビリティ | `shouldShowPeakFact` が false でも VoiceOver がピークを読み上げている。可視の事実行と同じ条件でピーク読み上げも抑止する |
| B-4 | `HourBars` レイアウト | 集計が失敗して全バーが2ptのとき、HStackの固有高さが2ptになり GeometryReader が上端に寄せる。56ptの箱の下端にそろえる |
| B-5 | `CoreScreensSnapshotCapture.swift`（340・449・901行付近） | `StatsService(logStore:)` が既定の `.current` カレンダーを使うため、時間帯カードの撮影結果がマシンのタイムゾーンで変わる。固定タイムゾーンのカレンダーを渡す |
| B-6 | `Localizable.xcstrings` | `stats.metric.count` に **en 値が入っていない**（§5で指示済みの未実装）。`%lld times` を追加する |
| B-7 | 死にコード | `MetricBlock`（`ios/DopaBreak/DesignTokens.swift`）と `stats.rate.unavailable` が参照0になった。**修正時点で改めて grep して参照0を確認してから**削除する |

**やらないこと**: `reloadDashboard` のバックグラウンド化。全期間タブで同期クエリが増えている件は認識済みだが、既存も同じ作り。別タスクとして切り出す

## C. 追加するテスト

1. **理由の legacy マージ**（`.anxietyCheck` → `.communication`）が**回数と秒数の両方**を合算していること。いまテストが1本も無い。`StatsView` の private を触れる形に切り出すか、Core側で検証できる形にする
2. 取り戻した秒数0の理由チップが「0分」で表示されること
3. アプリ行が取り戻した時間の降順に並ぶこと。比較関数だけでなく `appMetrics` の `reclaimedSeconds` 紐付けまで通ること
4. `comparisonText` の出力を ja/en/ko で検証すること。`result.range(of: deltaText)` はローカライズで書式がずれると accent が黙って消えるので、3言語で強調範囲が取れることまで見る
5. **A-5 の一致テスト**: 日跨ぎのキャンセルを含むシードで、アプリ別秒数の合計がヒーロー秒数と一致すること。根拠行の回数と legend の回数が一致すること

## D. 仕様確認（変更不要）

全期間のヒーローが分を切り捨てる（312時間47分 → 「312時間」）のは**意図どおり**。ホームのヒーローと同じ書式に揃えるため。§6の「23時間59分」という書き方が紛らわしかっただけで、実装は正しい。

## 受け入れ条件（差し戻し分）
- `xcodebuild test`（アプリ全スイート）と Core の `swift test` が失敗0
- lint 2本 exit 0、xcstrings が有効なJSONで新規・修正キーが3言語そろっている
- アプリ別秒数の合計がヒーロー秒数に一致することがテストで担保されている

---

# 再レビュー差し戻し（2026-09-03 Opus5再レビュー → Codex修正指示・第2回）

判定は accept with fixes。A/B-1〜B-4/B-6/B-7/C は正しく入っている。残す修正は下記2件のみ。

## E. 削除済みルールの秒数がアプリ別合計から落ちる（🟡）

`ios/DopaBreak/StatsView.swift` の `appMetrics(from:)` が `guard let rule = ruleByID[ruleID] else { return nil }` で、RuleStore に無いルールの行を丸ごと捨てている。対象アプリの選択を空にすると `AppContainer` が `deleteRule` を呼ぶ一方で `attempt_logs` と `reclaimed_ledger` は残るため、**ヒーローには時間が出ているのにアプリカードから消える**。全期間タブで顕著。無料プランは対象1アプリなので、乗り換えのたびに発生する。

**修正: 落ちた分を1行にまとめて末尾に出す。**

1. `appMetrics(from:)` で `ruleByID` に無い ruleID、および名前が空のルールを捨てずに、`attempts` / `cancelled` / `reclaimedSeconds` を合算した**集約行を1つ**作る
2. 表示位置は**常に最後**（取り戻した時間の降順ソートの対象外）
3. 見出しは新規キー `stats.apps.removed`

| key | ja | en | ko |
|---|---|---|---|
| `stats.apps.removed` | 対象から外したアプリ | Apps you removed | 대상에서 뺀 앱 |

4. アイコンは実体が無いので、既存 `AppIconView` のフォールバック経路を使う。フォールバックが無ければ `DesignTokens.hairline` の角丸矩形を同サイズで置く。新しい見た目部品を増やさない
5. 集約対象が0件のとき、この行は出さない
6. 進捗バーと右端の時間表示は通常行と同じ作り
7. `accessibilityLabel` も通常行と同じ形式

**受け入れ条件**: 削除済みルールの試行を含むシードで、**アプリカードの秒数合計（集約行を含む）＝ヒーロー秒数**になること。テストで担保する。

## F. 撮影フィクスチャが実行時刻依存のままで決定的でない（🟡）

B-5 で `CoreScreensSnapshotCapture.swift:348 / 460 / 915` の `StatsService` 生成には固定カレンダーが入ったが、**シード側（同 :1335 / :1405 / :1467 / :1514）が `Calendar.current` のまま**。このため JST 機では「ローカル8時開始」の試行が UTC の23時バケットへ落ち、週の窓も9時間ずれる。実測でも、同じコードで2回撮って曜日の並びとピーク時間帯（8時台 → 23時台）が変わった。

**修正**: シード側も `CoreScreensSnapshotCapturePolicy.fixedCalendar` に統一し、撮影結果が実行時刻とマシンのタイムゾーンに依存しないようにする。`:542` の `emptyStatsService` も同じカレンダーを渡す。撮影専用コードなので製品への影響はない。

**受け入れ条件**: `testCaptureRedesignPhase2StatsScreens` を続けて2回実行し、`output/screenshots/redesign-phase2/stats-pro.png` の SHA-256 が一致すること。報告にそのハッシュを書く。

## G. 対応しないと決めたもの（オーナー判断・2026-09-03）

- **ホームと記録で「今日」の境目が違う件**: ホームは台帳（`recorded_at`）基準、記録は試行開始（`started_at`）基準のまま。ずれるのは23時台に開始して0時台にやめた場合の1回分だけで、2画面を見比べる場面もほぼ無い。8/25にオーナー承認したホームの振る舞いを変えないことを優先する。**既知の限界としてここに記録し、ホームは触らない**
- **時間帯カードの粒度**: 24本のまま。3時間ずつ8本に束ねる案は、リリース後の実データを見てから判断する
- **全期間タブの同期クエリがメインスレッドで増えている件**: 既存も同じ作りなので別タスク
- 🟢指摘（全期間ヒーローの分切り捨てと行の分表示の見た目差／`.all` のアプリ別だけ `todayEnd` 上限／前週クエリが throw したとき黙って「先週の記録なし」に落ちる）はいずれも実害が無いため対応しない

## 受け入れ条件（第2回差し戻し分）
- `xcodebuild test`（アプリ全スイート）と Core の `swift test` が失敗0
- lint 2本 exit 0、xcstrings が有効なJSONで `stats.apps.removed` が3言語そろっている
- 削除済みルールを含むシードで「アプリカードの秒数合計＝ヒーロー秒数」がテストで担保されている
- 撮影2回のSHA-256一致
