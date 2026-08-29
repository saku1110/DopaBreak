# live-activity-density-v1 レビュー指摘（Opus5・2026-08-29）全件修正必須

対象: ios/WidgetsExtension/LockThemeLiveActivityView.swift / ios/DopaBreakTests/LockThemeLiveActivityViewTests.swift

1. **e1の固定行高がlineLimit(2)を殺す（1〜2件時のリグレッション）** — LockThemeLiveActivityView.swift:147
   `.frame(height: densityValue(one: 48, two: 34, three: 25))` により、旧実装（非dense時は高さ制約なし）で許されていた2行折返しが収まらない。
   2件時: 19pt×2行≈46.6ptが34pt行に入らず隣行・仕切り線と衝突。1件時も20pt×2行≈48.9ptで48ptぎりぎり。
   `minimumScaleFactor(0.6)`は幅にしか反応せず救済しない。
   → 1〜2件分岐は `height:` でなく `minHeight:` にする、または `lineLimit(2)×行高` から行高を導出する。

2. **e1 3件時の+2ptが長文オーバーフローを悪化** — :138 / :147
   17pt×2行≈41ptが据え置き25pt行に入らない（旧≈36ptより悪化）。既存テストはHStack枠のアンカーでgapを測るためグリフ重なりを検出できない。行高もフォントに追随させ、Textアンカーで検査するテストを足すこと。

3. **1件時の新規回帰テストが10テーマ中6テーマで無意味** — LockThemeLiveActivityViewTests.swift:96-108
   e1/asagiri/monochrome/liquidGlass/kpop/kawaiiPinkは `.contentBounds` が `.frame(maxHeight: .infinity)` の後段に付くため常に160−padでpassする。
   タイポグラフィの実サイズを反映する測定（例: 最初と最後のテキスト要素間の縦スパン）へ変えること。

4. **2件分岐のテストカバレッジがゼロ** — 全ての収容・非切詰・160pt検査は3件、新規テストは1件のみ。
   `densityValue(two:)` の全値（+4pt目標・+1.5ptサマリー・行高・間隔）が未検証。2件時の全テーマ収容・非切詰スイープを追加すること。

5. **1件テストに上限アサーションがない** — :96-108 は `≥120` のみ。`measured.height == 160`（accuracy 0.5）とカード・要素収容も3件テストと同水準で検査すること（2件テストも同様）。

6. **スコープ外のコピー変更を元に戻す** — LockThemeLiveActivityView.swift:76
   `live_activity.summary.cancelled` のdefaultValueを「今日は%lld回 開くのをやめた」へ戻すこと（コピーは本タスクのスコープ外。別途オーナー判断）。

修正後、LockThemeLiveActivityViewTests全件を再実行して成功を確認すること。
