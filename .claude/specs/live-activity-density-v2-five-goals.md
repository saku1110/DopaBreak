# Live Activity 密度 v2 — 目標5件対応と3件時の余白是正

対象: `ios/WidgetsExtension/LockThemeLiveActivityView.swift`（全10テーマ）ほか
前提正本: `.claude/specs/live-activity-density-v1.md`（2026-08-29）。本書はその差分。

## 1. 直したい事象（オーナー実機指摘・2026-08-31）

目標3件のとき、行間・行高の余白が過大でデザインが崩れて見える。
原因は v1 の `e1GoalMinimumHeight` が「3件でも2行分（約40.57pt）の行高」を各行に強制していること。
実際の目標は1行に収まるため、文字20pt相当の行に対し倍の高さが確保され、行間が空きすぎる。
加えて e1 の外側縦paddingが3件時 `0` で、サマリー行がカード下辺に張り付いている。

## 2. 決定事項

### 2-1. 表示上限を3件 → 5件
- `LockThemeLiveActivityView.maximumGoals` を 5 にする
- `LockSurfaceCoordinator.liveActivityGoalLimit` を 5 にする（2箇所の整合を保つ）
- アプリ内の目標登録件数の上限は従来どおり無制限（2026-08-17オーナー決定）。変更しない

### 2-2. 密度分岐を1〜5件へ拡張
`densityValue(one:two:three:)` は5件分を取る形へ置き換える（例: `densityValue(one:two:three:four:five:)`）。
全10テーマの呼び出しを機械的に移行し、既存の1〜3件の値は原則そのまま引き継ぐ（3件は下記2-3で見直す）。

### 2-3. 目標フォント増分（`goalFontIncrease` が唯一の正本・全テーマ共用）

| 件数 | 増分 | e1基準15ptでの実サイズ |
|---|---|---|
| 1 | +5 | 20 |
| 2 | +4 | 19 |
| 3 | **+3**（v1は+2） | 18 |
| 4 | 0 | 15 |
| 5 | -2 | 13 |

サマリー増分 `summaryFontIncrease`: 1件1.5 / 2件1.5 / 3件1 / 4件0.5 / 5件0。

### 2-4. 行高を膨らませない（今回の本丸）
- e1 の2行表示（`lineLimit(2)`）は **1〜2件のときだけ**。3件以上は `lineLimit(1)`
- `e1GoalMinimumHeight`: 1件は60pt維持、2件は2行実高維持、**3〜5件は1行実高＋2pt以内**にする
- 余った縦の余りは行高へ再配分せず、フォント（2-3）とセクション間隔で吸収する

行間の目安（各テーマの `densityValue` の目標レンジ。テストが通る範囲で調整可）:
- 目標行どうしの間隔: 3件 5〜7pt / 4件 4〜5pt / 5件 3〜4pt
- eyebrow〜目標ブロック、目標ブロック〜divider、divider〜サマリーの各間隔: 3件 5〜7pt / 4件 4〜5pt / 5件 3〜4pt

### 2-5. 外側縦padding
どの件数でも **6pt以上**を確保する（現行の3件時 `0` を廃止）。カード下辺への文字の張り付きを作らない。

### 2-6. 縮小と切り詰め
4〜5件は `lineLimit(1)` + `minimumScaleFactor(0.55)` + `truncationMode(.tail)`。
極端に長いタイトルは7pt級まで縮めるより末尾省略を選ぶ（可読性優先）。

## 3. 変えてはいけないもの（v1からの継承）
- カード高160pt固定、四辺までの塗り、水平インセット16pt（noteの左46ptは例外）
- マーカーの `.firstTextBaseline` / `markerCenterAlignedToCapHeight` / `glyphCapCenterOffset` によるcap中心整列。ボックス中央へ戻さない
- 1件・2件時の「タイポグラフィ縦占有120pt以上（gaming 1件は122pt）」の下限
- asagiri中央揃え、K-POP全幅帯、blueprintセル内4pt以上、note英語`×`補正、`isMeasuring`経路
- `live_activity.*` の確定コピー、Home Widget／Dynamic Islandの構造、EntitlementGate（無料は`e1`のみ）

## 4. テスト（`ios/DopaBreakTests/LockThemeLiveActivityViewTests.swift`）
1. `testAdaptiveDensityUsesApprovedTypographyIncreases` を1〜5件の期待値へ更新（`e1GoalMinimumHeight` の実測期待値も再計算）
2. マーカー整列テストのループを `1...5` へ拡張（許容±0.75pt維持）
3. `testE1SupportedGoalCountsKeepRowsDividerAndSummarySeparated` を `1...5` へ拡張
4. 4件・5件で「長文タイトル×全10テーマが160pt内に収まり、文字が縦に潰れない」ケースを追加
5. 3件で「行間が行高を超えない」回帰を追加（行間 ≤ 目標行の実高。今回の崩れの再発防止）
6. 5件で `.goal` の実インク高が8pt以上あることを検査（e1の10pt検査に準じる）
7. 3〜5件でも外側縦paddingが6pt以上あること（カード下辺とサマリー下端の距離）を検査

## 5. 完了条件
- `xcodegen generate` 成功、`xcodebuild test`（iPhone 16 Pro）失敗0
- `scripts/lint-display-copy.py` と `scripts/audit-default-values.py` が exit 0
- `.claude/specs/design-decisions.md` へ本変更の記録を追記
