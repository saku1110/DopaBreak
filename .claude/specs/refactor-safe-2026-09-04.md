# リリース前リファクタリング（安全な範囲のみ・2026-09-04）

出典: Opus5リファクタ監査。**実行時の挙動を変えない項目だけ**を対象にする。
挙動が変わりうるものは「DEFER」としてリリース後へ回す（本ファイル末尾）。

前提: XcodeGenがディレクトリをglobするため、ファイル追加削除でプロジェクトファイルの手編集は不要。
ただし**削除・追加のあとは `cd ios && xcodegen generate` を必ず実行する**（生成物がずれていると
新しいテストが黙って除外され、緑に見えたまま実際は走っていない事故が起きる。2026-09-04に実際に発生）。

---

## A. 未参照コードの削除（全リポジトリgrepでゼロ参照を確認済み）

| # | 場所 | 対象 | 行数 |
|---|---|---|---|
| A1 | `ios/DopaBreak/OnboardingFlow.swift:176-247` | `private struct TimeLedgerMotif: View` | 72 |
| A2 | `ios/DopaBreak/DesignTokens.swift:329-352` | `struct ScreenHeader: View`（`.navigationTitle`移行で置換済み） | 24 |
| A3 | `ios/DopaBreak/DesignTokens.swift:354-368` | `struct SignalLabel: View` | 15 |
| A4 | `ios/DopaBreak/AppContainer.swift:1298-1313` | `func todayAttemptCountForCurrentRule(catalogID:)` | 16 |
| A5 | `ios/DopaBreak/AppContainer.swift:1005-1009` | `func consumePendingInterventionTarget()` | 5 |
| A6 | `ios/DopaBreak/QuickActions.swift:154-156` | `func clearPendingAction()` | 3 |
| A8 | `ios/Packages/DopaBreakCore/.../GoalStore.swift:15-17` | `public func allGoals()` | 3 |
| A9 | `ios/Packages/DopaBreakCore/.../RetentionNotificationPolicy.swift:139-141` | `public static func isFuture(_:relativeTo:)` | 3 |
| A10 | `ios/Packages/DopaBreakCore/.../DeepFocusWindowPolicy.swift:22` | `defaultSessionDurationMinutes` | 1 |

**A7（`EntitlementGate` の未配線4件 `heroGoalAllowed` / `yearGoalDisplayAllowed` / `themesAllowed` / `canDisplayYearGoal`）は
今回やらない。** 削除には `EntitlementGateTests` の4アサーション除去が伴い、リリース直前に課金関連の
テストを減らす判断はしない。リリース後に回す。

各削除の前に、その識別子でリポジトリ全体（テスト・拡張・xcstrings・plist・project.yml含む）を
再grepして0件であることを**実装者自身が再確認**すること。監査結果を鵜呑みにしない。

## B. 孤児ローカライズキーの削除（`ios/DopaBreak/Localizable.xcstrings`）

`ScreenHeader` 廃止などで参照が消えた21キー。**削除前に必ず1件ずつ再grepする**。

```
onboarding.result.per_day / onboarding.result.yearly.prefix / onboarding.result.yearly.suffix
settings.header.eyebrow / settings.lock_screen.section / settings.schedule.bed_time
settings.schedule.wake_time / settings.selection.app_count / settings.selection.category_count
settings.selection.website_count / settings.target.section / settings.deep_focus.section
settings.deep_focus.targets.label / app.error.goal_pro_required / goals.header.eyebrow
intervention.goal.fallback / intervention.usage_summary.attempt_count
intervention.usage_summary.title / stats.header.today.eyebrow / stats.header.week.eyebrow
automation_guide.mock.done
```

⚠️ **`settings.block.store_unreachable_notice` は2026-09-04に追加した新規キー。絶対に消さない。**
⚠️ xcstringsの再整形は禁止（過去に差分が2万行へ膨張した事故あり）。**該当キーのブロックだけを削る**。

## C. 完全重複の一本化

- **C1**: `oneShotTrigger(for:)` が
  `ios/DopaBreak/ReflectionNotificationScheduler.swift:100-108` と
  `ios/DopaBreak/LockSurfaceCoordinator.swift:724-732` にバイト単位で同一。
  アプリターゲット内の新規ファイルへ1本化する（Coreへ移すと `UserNotifications` 依存が増えるので移さない）
- **C2**: `emptyWeekDays` が `ios/DopaBreak/HomeView.swift:1042-1051` と
  `ios/DopaBreak/StatsView.swift:1035-1044` に重複（日付引数名だけ違う）。1本化する

## 完了条件（実装者が自分で測って報告する）
1. `cd ios && xcodegen generate`
2. Core `swift test` … 530件・失敗0 を下回らないこと
3. アプリ `xcodebuild test`（**シミュレータは `3CAEAD04-3EE1-4E0F-933F-0B003BE60BA8` 固定**）… 331件・失敗0 を下回らないこと
4. `python3 scripts/lint-display-copy.py` exit 0
5. `python3 scripts/audit-default-values.py` exit 0（missing=0 であること。孤児キー削除で参照エラーが出ないか見る）

---

## DEFER（リリース後・挙動が変わりうる）
- `LockSurfaceCoordinator.performNotificationReschedule`（376行）の分割 … `guard else return` が
  囲みの関数から抜ける制御フローで、抽出すると世代チェックを取りこぼす危険。テストも薄い
- `AppContainer.retentionNotificationSchedules`（168行）の分割 … 権利状態と期間境界の判断を含む
- `AppContainer` 内の「今日の範囲」5重複 … `Calendar.current` と `autoupdatingCurrent`、
  注入クロックと素の `Date()` が混在しており、**統一すると日跨ぎ・DST・タイムゾーンで挙動が変わる**。
  どちらが正かを決めてから直す
- `SettingsView.swift`(2410) / `OnboardingFlow.swift`(2696) の分割 … `private` を `internal` へ
  広げる大量の機械変更が必要でリスクに見合わない
- `A7` EntitlementGate未配線4件

---

# 追加: 独立レビューの指摘対応（2026-09-04・修正1〜3のレビュー結果）

レビュー結論は「🔴なし・出荷可」。以下は残った小さい指摘のうち、**安く直せてリスクが下がるものだけ**を採用する。

## R1（🟡・採用）: 廃止ゲート掃除のリトライが実質1回で終わる
`ios/DopaBreak/ShieldController.swift:192-195` — `didStopRetiredGateMonitoring = true` を
**問い合わせの前**に立てている。Screen Time認可が未解決などで `monitoredActivityNames` が
空を返すと、そのプロセスでは二度と再スキャンしない。

対応: **実際にスキャンが成立してからフラグを立てる**（空が返った場合はフラグを立てず次回に回す）。
`stopMonitoring` はthrowしないので例外処理は不要。冪等性は維持する。

## R2（🟢・採用）: 掃除の順番
`ios/DopaBreak/AppContainer.swift:680-692` — `nightShieldScheduler.rebuild` /
`deepFocusScheduler.rebuild` が `shield.syncShield`（＝廃止ゲート掃除を含む）より先に走る。
アップグレード直後の初回だけ、旧アクティビティが枠を占めたまま新規登録することになる。

対応: **廃止ゲートの掃除を rebuild より前に動かす**。挙動は変わらず、順序だけ安全側にする。

## R3（🟢・不採用）
- ルール読み取り失敗時に `.entitlementUnconfirmed` の理由が古いまま残る … 元々 `didLastRebuildFail` も
  同じ形で、ユーザーが未武装なのは事実。理由の精度だけの問題なのでリリース後
- `.failed` で注意行を出さない … 承認済みコピーがApp Store文脈のため。別の文言が要るのでリリース後
- `shouldSuppressPassThrough` の窓が30分→3時間に広がった副作用 … レビューが「無害」と確認済み。
  ただし**テストが無い**ので、R1/R2の実装ついでに回帰テストを1件足すこと

## 完了条件（追加分）
- R1: 空スキャン時にフラグが立たないことをテストで固定する
- R3: `shouldSuppressPassThrough` が3時間窓で効くことのテストを1件追加する
