# 利用後リフレクションの提示タイミング変更（案A）＋ 装飾英語eyebrow撤去 — 設計（2026-09-01）

オーナー決定（2026-09-01）:
- リフレクションは**案A**。開く導線から外し、時間窓を縮め、DopaBreakに戻ったときだけ聞く。過ぎたものは黙って捨てる
- `INTENT` / `PAUSE` などの装飾英語eyebrowは**不要**。撤去する

---

## 1. リフレクション: 開く導線から外す（案A）

### 現状の不具合
`InterventionFlowModel.start()` が、SNSを開こうとした瞬間の先頭で未回答リフレクションを出す。

```swift
if let reflection = try engine.pendingReflection() {   // 既定の時間窓が24時間
    stage = .reflection(reflection)
    return
}
try beginInterventionAndBreathing(using: engine)
```

時間窓が24時間あるため、前回の利用から何時間も経ってから「SNS見た後の気持ち」を突きつけられる。
ユーザーはその利用を覚えていない。しかも回答/スキップの後にさらに一呼吸が入るため、
開くまでに2画面挟まってループ感が出る（オーナー報告 2026-09-01）。

### 変更内容

#### 1-1. 時間窓を30分にする
`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/InterventionEngine.swift`

```swift
/// 利用直後の実感が残っている間だけ聞く。24時間窓では前回の利用を覚えていない状態で
/// 出てしまい、開く導線を塞ぐだけになっていた（2026-09-01オーナー決定）。
public static let reflectionPromptWindow: TimeInterval = 30 * 60
```
`pendingReflection(within:)` の既定値をこの定数にする。

#### 1-2. 期限切れは黙って捨てる
同ファイルに追加する。

```swift
/// 時間窓を過ぎた未回答リフレクションをスキップ扱いで畳む。
/// 溜め込むと `pendingReflection` が毎回何かを返し続けるため、前面復帰のたびにここを通す。
@discardableResult
public func expireStaleReflections(
    olderThan window: TimeInterval = InterventionEngine.reflectionPromptWindow
) throws -> Int
```
- 対象は `answeredAt == nil && !skipped` かつ `promptedAt` が `now - window` より古いもの
- 1件ずつ `skipReflection(id:)` と同じ経路（`ReflectionSkipWriter.markSkipped` → `resolveReflectionFlow`）で畳む
- 戻り値は畳んだ件数（テスト用）

#### 1-3. 介入フローからリフレクション段階を削除する
`ios/DopaBreak/InterventionFlowModel.swift`
- `start()` の `pendingReflection` 分岐を削除し、常に `beginInterventionAndBreathing` へ進む
- `InterventionStage` の `.reflection(ReflectionLog)` ケースを削除
- `recordReflection(_:)` と `skipReflection()` を削除

`ios/DopaBreak/InterventionFlowView.swift`
- `case .reflection(let reflection):` の分岐（`PostUseReflectionContent` を出している箇所）を削除

**死んだコードやTODOを残さない。** 参照が壊れるテストがあれば新しい挙動に合わせて直す。

#### 1-4. DopaBreakに戻ったときに聞く
`ios/DopaBreak/RootTabView.swift`

既存の `checkPendingLockScreenCheck` / `checkPendingPaywalls` と同じ作法で、前面復帰時の提示を1つ足す。
`PostUseReflectionSheet`（`ios/DopaBreak/PostUseReflectionSheet.swift`）は既に実装済みで未使用のため、これを使う。

```swift
@State private var pendingReflectionLog: ReflectionLog?

private func checkPendingReflection() {
    guard settingsStore.onboardingCompleted,
          pendingReflectionLog == nil,
          model.pendingInterventionTarget == nil,
          interventionOverlay.target == nil,
          pendingPaywallPlacement == nil,
          !isLockScreenCheckPresented,
          !model.isChildModalActive,
          let engine = model.interventionEngine else { return }
    try? engine.expireStaleReflections()
    pendingReflectionLog = try? engine.pendingReflection()
}
```

- `handleAppActive()` の末尾で呼ぶ
- `runPostInterventionDismissalChecks()` と各 `fullScreenCover` の `onDismiss` からも呼ぶ（先行モーダルが閉じたときに拾うため）
- `.sheet(item: $pendingReflectionLog)` で `PostUseReflectionSheet` を出し、`onFinished` で `pendingReflectionLog = nil` と `model.refresh()` を行う
- `InterventionModalBlocker` に `.reflection` を追加し、`presentedInterventionModal` / `InterventionPresentationPolicy` に既存2つと同じ扱いで組み込む。
  **一呼吸（介入）が常に最優先。** リフレクションのシートが出ている最中に介入要求が来たら、シートを畳んで介入を出す

### 受け入れ条件
- SNSを開く導線でリフレクションが出ない（必ず一呼吸から始まる）
- 利用終了から30分以内にDopaBreakを開いたときだけリフレクションが出る
- 30分を過ぎた未回答は次の前面復帰で黙って畳まれ、二度と出ない
- リフレクション表示中に対象アプリを開いた場合、シートが畳まれて一呼吸が出る

---

## 2. 装飾英語eyebrowの撤去

`String(localized:defaultValue:)` の既定値ではなく **`Localizable.xcstrings` の実値が表示に出る**。
実測でja/enとも英語のままだった。ビューとカタログの両方から消すこと。

### 撤去する（ビューごと削除。日本語への置き換えはしない）
| ファイル | キー | 現在のja表示 |
|---|---|---|
| `ios/DopaBreak/InterventionFlowView.swift` | `intervention.breath.eyebrow` | PAUSE |
| 同上 | `intervention.intent.eyebrow` | INTENT |
| 同上 | `intervention.duration.eyebrow` | TIME |
| 同上 | `intervention.opening.eyebrow` | OPENING |
| `ios/DopaBreak/PostUseReflectionSheet.swift` | `reflection.eyebrow` | REFLECTION |
| `ios/DopaBreak/OnboardingFlow.swift` | `onboarding.apps.eyebrow` | TARGET APPS |
| 同上 | `onboarding.mode.eyebrow` | STRENGTH |
| 同上 | `onboarding.preview.eyebrow` | PREVIEW |
| 同上 | `onboarding.automation.eyebrow` | SETUP |
| 同上 | `onboarding.notification.eyebrow` | NOTIFICATION |

- 一呼吸画面の `HStack { SmallLabel("PAUSE"); Spacer(); targetLabel }` は、SmallLabelだけ消して行と `targetLabel` は残す
- 見出しが先頭になるぶんの上下間隔が詰まりすぎないか確認し、必要なら既存の spacing の範囲で整える。新しい装飾は足さない
- `ios/DopaBreak/Localizable.xcstrings` から上記キーを削除する（ja/en/ko すべて）

### 残す（ブランド名・モック表示のため装飾ラベルではない）
- `onboarding.welcome.eyebrow` = DOPABREAK
- `onboarding.notification.preview.app_name` = DOPABREAK（通知モックのアプリ名）
- `paywall.brand.pro` = DOPABREAK PRO

### 文言を揃える（削除ではない）
- `ios/WidgetsExtension/Localizable.xcstrings` の `widget.goal.eyebrow` が ja/en とも `YOUR GOAL`。
  Live Activity の `live_activity.goal.eyebrow`（ja「あなたの目標」）と同じ値へ揃える。koは既に「나의 목표」なので変更しない

---

## 共通ルール
- 省略・TODO・死んだコードを残さない
- 既存テストを壊さない。挙動が変わるテストは新しい仕様に合わせて更新する
- ビルド確認:
  `xcodebuild -project ios/DopaBreak.xcodeproj -scheme DopaBreak -destination 'platform=iOS Simulator,id=DF6A380F-D0EC-42CA-A508-0D02CEE9F404' build`
- **シミュレータのアプリを起動・終了しない**（テスト実行中のホストを殺すため）
