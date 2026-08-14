# 夜だけ強化（nightOnly）実装スペック

- 作成: 2026-08-14（Fable設計・オーナー指示「夜だけ強化を実装して」による承認済み）
- 前提: docs/12 §1「nightOnly = 日中は介入フロー、夜間は完全ブロック」
- 実装担当: Codex（gpt-5.6-sol Fast・effort max）／レビュー: Opus5

## 0. 設計決定（Fable裁定）

| 論点 | 決定 | 理由 |
|---|---|---|
| 夜の時間帯 | **既存の就寝時刻→起床時刻を再利用**（`SettingsStore.bedTimeMinutes` デフォルト1380=23:00 / `wakeTimeMinutes` デフォルト420=7:00） | 設定UIが既にあり（設定>起床・就寝時刻）、新規UIゼロで意味も自然 |
| Pro制限 | **deepFocusと同じPro専用**（`strictModeAllowed`） | シールド＝完全ブロックはPro機能（docs/12 §5、docs/15） |
| シールドストア | **夜間用に別ストア `ManagedSettingsStore(named: "dopabreak.night")` を新設** | MonitorExtensionが夜明けに夜間分だけ解除でき、deepFocus常時ブロック（"dopabreak.rules"）に触れない |
| 夜境界の駆動 | **DeviceActivitySchedule（就寝→起床・repeats）+ MonitorExtension** ＋ **アプリ前面時のsyncShieldでフォールバック再計算** | 拡張のコールバックは取りこぼしがあるため二重化 |
| 拡張への受け渡し | **アプリ側が事前計算したスナップショット `night_shield_snapshot.json`（AppGroup）** | 拡張内で権利判定・RuleStore読取をしない。Pro確定時のみアプリが書き、降格時に消す |
| 降格 | **非破壊**（2026-08-14 Fable裁定を踏襲）: ルールの`mode`は書き換えない。両ストア解除＋スナップショット削除＋監視停止のみ | 再Proで設定が戻る |
| 就寝=起床が同時刻 | 夜の窓なし（常に昼扱い）。監視も張らない | 縮退ケースを明確化 |
| 15分未満の窓 | **同じく「窓なし」扱い**（`NightWindowPolicy.minimumWindowMinutes = 15`）。監視も夜適用もしない | DeviceActivityが15分未満を受け付けず必ず`intervalTooShort`になる。失敗してから気づく形にしない（2026-08-14レビュー指摘3） |
| 降格時の順序 | **「監視停止 → 控え削除 → シールド解除」**。解除を最後に置く。拡張は適用直前にもう一度控えの存在を確認する | 解除を先にすると、まだ生きている監視と古い控えで拡張が張り直せる。プロセス間の完全な排他は不可能で、残る窓は「次のアプリ前面時の`syncShield`で必ず剥がれる」（2026-08-14レビュー指摘1） |
| 控え削除の失敗 | 握りつぶさない。監視停止だけは必ず通し、失敗として残して次の`syncShield`で消し直す | 消し残しを黙って成功扱いにしない |
| `rebuild`の順序 | **「控え書き込み →（成功時のみ）stopMonitoring → startMonitoring」**。書き込み失敗時は既存監視に触らない | 先に監視を止めると、書き込みに失敗した端末が朝の解除まで失う（2026-08-14レビュー指摘2） |
| `startMonitoring`失敗 | 夜間ストアを解除する（掛けっぱなしにしない）。朝の解除はアプリ前面時の再計算が受け持つ | 解除の担い手がいないままProの利用者を一晩締め出す被害の方が大きい |
| 拡張の境界コールバック | 控えの`bed/wake`で**いまが窓内かを検算**してから動く（開始=窓内のみ適用／終了=窓外のみ解除） | 就寝・起床を変えた直後は古いスケジュールぶんが遅れて届く。時刻を見ずに従うと新しい窓の最中に解除が走る（2026-08-14レビュー指摘4） |
| 時刻Pickerの往復 | `startOfDay`＋分の加算をやめ、`date(bySettingHour:minute:second:of:)`と`dateComponents([.hour,.minute])`の成分変換で往復する | 夏時間の切替日（23時間・25時間の日）に表示が1時間ずれる（2026-08-14レビュー指摘5） |

## 1. Core（DopaBreakCore）

### 1-1. NightWindowPolicy（新規・純関数）
`Sources/DopaBreakCore/Services/NightWindowPolicy.swift`

```swift
public enum NightWindowPolicy {
    /// bed==wake は常にfalse。跨日（例 23:00→7:00）と同日内（例 1:00→5:00）の両方を扱う。
    public static func isNight(now: Date, bedTimeMinutes: Int, wakeTimeMinutes: Int, calendar: Calendar) -> Bool
}
```
- 分は `0...1439` へ正規化（`SettingsStore.normalizedMinutes` と同じ丸め）。
- 判定は「その日の分数 `m`」で: bed<wake なら `bed <= m < wake`、bed>wake なら `m >= bed || m < wake`。

### 1-2. ShieldSyncPolicy 拡張
- `rulesToShield(...)` / `action(...)` に `isNightWindow: Bool` を追加。
- フィルタ条件を `rule.mode == .deepFocus || (rule.mode == .nightOnly && isNightWindow)` へ。
- **既存の非破壊降格・preserve/clear到達性の意味は一切変えない**（未確定=preserve、Free確定=ルール読取前に無条件clear、throw時preserve）。
- 既存呼び出し側は明示的に引数を渡す形へ更新（デフォルト引数で隠さない）。

### 1-3. NightShieldSnapshot（新規・拡張との共有データ）
- `SnapshotFile` に `case nightShieldSnapshot = "night_shield_snapshot.json"` を追加。
- 構造:
```swift
public struct NightShieldSnapshot: Codable, Equatable, Sendable {
    public var selectionDataList: [Data]   // 有効なnightOnlyルールのactivitySelectionData（非空のみ）
    public var bedTimeMinutes: Int
    public var wakeTimeMinutes: Int
    public var updatedAt: Date
}
```
- 読み書きは `JSONSnapshotStore` 経由（AppGroupなのでMonitorExtensionから読める）。

### 1-4. InterventionModeAvailability 更新
- `selectable = [.standard, .deepFocus, .nightOnly]`
- `persistable` は selectable準拠のまま（nightOnlyが保存可能になる）。
- ドキュメントコメントの「未実装のため出さない」を削除し、経緯を1行残す。

## 2. アプリ側

### 2-1. ShieldController 拡張
- 夜間用ストア `ManagedSettingsStore(named: .init("dopabreak.night"))` を追加。
- `applyShield` はルールを mode で分割: deepFocus → 既存ストア、nightOnly → 夜間ストア。
- `clearShield()` は**両方**解除（Free確定時の無条件clearで夜間分も必ず剥がれる）。
- `syncShield(...)` に現在時刻の夜判定を注入（`NightWindowPolicy.isNight` + SettingsStoreのbed/wake）。昼なら夜間ストアだけ解除し、deepFocus分は従来どおり。
- トークン上限（`targetAppTokensLimit`）はProでは無制限のため実質影響なしだが、既存のクランプ順序は変えない。

### 2-2. NightShieldScheduler（新規）
`ios/DopaBreak/NightShieldScheduler.swift`
- 責務: スナップショットの書き出し/削除と、DeviceActivity監視の張り直し。
- activity名: `"dopabreak.nightwindow"`（定数はCoreの `NightShieldConstants` に置く。MonitorExtensionと共有）。
- `rebuild(entitlementGate:hasConfirmedEntitlement:)`:
  - Pro確定 かつ 有効なnightOnlyルール（selectionData非空）あり → スナップショット書き込み → `DeviceActivityCenter.startMonitoring`（`DeviceActivitySchedule(intervalStart: bed, intervalEnd: wake, repeats: true)`）。
  - それ以外（Free確定・対象なし・bed==wake）→ `stopMonitoring` ＋ スナップショット削除。
  - **未確定（hasConfirmedEntitlement=false）は何もしない**（preserveと同じ思想）。
  - `startMonitoring` throw時は監視停止状態に戻し、失敗を握りつぶさずログ相当の状態を返す（UsageWatchControllerのrebuildMonitoringと同じ流儀）。
- 呼び出し点: `AppContainer.syncShield()` の直後（deferの同期と同じ経路）、`applyInterventionMode` 後、設定画面で起床・就寝時刻を変更した時。

### 2-3. SettingsView
- 「止める強さ」ピッカー: `InterventionMode.selectable` を回しているので自動で3択になる。
- Pro未解放時のガード（SettingsView.swift:1505付近）を `mode != .deepFocus` 単独判定から「シールドを使うモード（deepFocus/nightOnly）」判定へ拡張。ロック行UI（deepFocusLockedRow）も同様に共通化。
- 起床・就寝時刻の変更ハンドラから `NightShieldScheduler.rebuild` を呼ぶ。
- 夜モード選択時の説明: `InterventionModeDisplay.detailText` を「夜は完全ブロック」が伝わる文へ更新（下記コピー）。

### 2-4. MonitorExtension
- `intervalDidStart(dopabreak.nightwindow)`: スナップショットを読み、selectionDataListをデコードして夜間ストアへ適用。読めなければ何もしない（適用失敗で昼の状態を壊さない）。
- `intervalDidEnd(dopabreak.nightwindow)`: 夜間ストアのみ解除。
- 既存のUsageWatch activityの分岐と衝突しないよう activity名で分岐。

### 2-5. 表示コピー（InterventionModeDisplay）
- displayTitle: 「夜だけ強化」（既存のまま・xcstrings 3言語は既存キーを流用）。
- detailText 日本語: 「就寝から起床まで完全ブロックする」（読点なし・体言止め回避・自動詞カルク回避）。en/koはLocalizable.xcstringsの既存キー `intervention_mode.night_only.detail` を同義へ更新。

## 3. テスト（DopaBreakCoreTests・ポリシーは100%）

1. `NightWindowPolicyTests`: 跨日窓の夜側/昼側、同日内窓、境界値（bed丁度=夜、wake丁度=昼）、bed==wake=常に昼、分の正規化。
2. `ShieldSyncPolicyTests` 追記: isNightWindow=true/false × deepFocus/nightOnly/standard、Free確定時の無条件clearが夜間にも効く、未確定preserve不変、throw時preserve不変。
3. `InterventionModeAvailabilityTests` 更新: nightOnlyがselectable/persistableになる（既存の逆アサーションを反転）。
4. `NightShieldSnapshot` のエンコード/デコードのラウンドトリップ。

## 4. やらないこと（スコープ外）

- 夜専用の時間帯設定UI新設（就寝・起床を流用するため不要）。
- ShieldConfigExtensionの文言分岐（現行コピーはモード非依存で成立している）。
- nightOnly用の別FamilyActivityPicker導線（対象選択は既存ルール共通のまま）。

## 5. 検証コマンド

```bash
cd ios/Packages/DopaBreakCore && swift test
cd ios && xcodebuild -project DopaBreak.xcodeproj -scheme DopaBreak -destination 'generic/platform=iOS Simulator' build
```

※ シールドの実機発火（夜境界での適用/解除）は release-monetization-check の実機検証項目として残す。コード存在で✅を付けない。
