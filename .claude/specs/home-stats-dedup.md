# ホーム×統計の重複解消（2026-08-24 オーナー承認済み）

## 方針
ホーム＝いまの状態と操作、統計（Stats）＝振り返りと分析。ホームから記録系カードを外し、統計タブへの導線カードに置き換える。Pro誘導（statsHistoryGateペイウォール）は殺さない。

## 変更対象
- `ios/DopaBreak/HomeView.swift`
- `ios/DopaBreak/RootTabView.swift`
- `ios/DopaBreak/Localizable.xcstrings`（カタログが正。新キーは既存の全言語分を追加）
- 影響するテスト（`ios/DopaBreakTests/` 内でHomeView関連があれば更新）

## 1. HomeViewから削除するもの
- `dashboardInsightsSection` / `appMetricsCard` / `appMetricRow` / `reflectionCard` / `lockedDashboardPreview` / `weeklyReviewButton`
- 上記だけが使う補助プロパティ（`topSatisfaction`・`reflectionColor`・`reflectionCountText`・`isDashboardLocked` など。他で使うものは残す）
- `HomeDashboardData` の `appMetrics` / `reflectionCounts` / `recentSatisfactions` と、`reloadDashboard` 内の対応する計算・`HomeAppMetric` 型（未使用になる場合のみ削除）
- 未使用になるローカライズキー（`home.apps.*`、`home.reflection.top` 等）はカタログから削除。**他画面と共有しているキー（`reflection.satisfaction.title` 等）は残す**

## 2. 置き換え: 統計導線カード（新規）
- 位置: 旧`dashboardInsightsSection`と同じ（`weekCard`の後・`goalCard`の前）。表示条件も同じ `!isFirstDayEmpty`（appMetrics条件は廃止し、初日空以外は常時表示）
- 見た目: `CardContainer` 内に1行。左にテキスト、右にトレーリングアイコン。既存カードのフォント/トークン（`dopaFont`・`DesignTokens`）に合わせる。タップ領域は行全体・minHeight 44pt
- 分岐（`model.entitlementGate.weeklyReportAllowed`）:
  - **許可あり（Pro等）**: テキスト＝新キー `home.stats_link.title` defaultValue「アプリごとの内訳と振り返りを見る」、右は `chevron.right`。タップで統計タブへ切替
  - **許可なし**: テキスト＝既存キー `stats.paywall.weekly_report`（「記録を全部見る」）、左に `lock.fill`。タップで `paywallPlacement = .statsHistoryGate`（旧weeklyReviewButtonと同じ）
- 文言規則: 句読点なし・造語なし・平易な名詞。内部用語（介入/シールド等）禁止

## 3. タブ切替の仕組み
- `HomeView` に `let onOpenStats: () -> Void` を追加（initのデフォルト引数 `= {}` にしてプレビュー/テストを壊さない）
- `RootTabView` から `HomeView(model:settingsStore:onOpenStats: { selectedTab = .stats })` で注入

## 4. weekCardの先週比較を統計側へ一本化
- `weekSummaryText` は base（「今週は○回、開くのをやめました」）のみ返す。`weekComparisonText` と `dashboard.weeklyDetail` 依存（他に使途がなければ）を削除
- StatsView側の比較表示は変更しない

## 5. やらないこと
- StatsViewの変更なし（成功率・アプリごと・振り返り・何をしに開いた・期間切替はそのまま）
- ホームの hero / reclaimedTimeCard / targetAppsCard / weekCard(DayBars) / goalCard は維持

## 受け入れ条件
- ビルドが通る（`xcodebuild`）。既存テストが通る
- 非Proでホームにブラーカードが出ない。導線カードのタップでペイウォール（statsHistoryGate）が開く
- Proで導線カードのタップで統計タブに切り替わる
- ホームに「アプリごと」「SNSを見てどうだった？」「先週より○回」の表示が残っていない
- xcstrings: 新キーは既存全言語（ja/en/ko等、カタログにある言語すべて）に値を追加。defaultValueとカタログja値を一致させる
