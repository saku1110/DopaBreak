# ロック画面テーマ伝播 / Live Activity角丸 / SNS起動時の旧画面露出 — 修正設計（2026-09-01）

オーナー報告の4件のうち、根本原因が確定した3件の設計。#2（黒い有料テーマでLive Activityが真っ黒）は
実機スクリーンショット待ちのため本書に含めない。

---

## 計測事実（iPhone 17 Pro Max / iOS 26.5 シミュレータの実測ログ）

WidgetRenderer_Activities のログに出るLive Activityコンテナの実寸:

```
[w:fix-412.00-h:dyn-64.00-160.00-cr:23.5-s:1.0.fam:medium]
```

- 幅 412pt 固定
- 高さ 64〜160pt の可変
- **コンテナ角丸 = 23.5pt**（端末により変わる想定。ハードコードしない）

---

## 不具合1: ホームでロック画面デザインを変えても目標画面に反映されない

### 根本原因
`AppModel.lockSurfaceState` / `liveLockTheme` / `savedLockTheme` は
`settingsStore`（UserDefaults）を読むだけの **computed property**。`@Observable` の
観測対象は保存プロパティのみのため、テーマを書き換えてもSwiftUIの再評価が発生しない。

- `HomeView` は自前の `@State savedLockTheme` を持つので、その画面だけは更新される。
- `GoalsView` は `model.lockSurfaceState.theme` を読むだけで、観測できる依存が無い。
  `onAppear` の `model.refresh()`（`goals` 代入）による巻き添え再評価に頼っており、
  タブ再表示で `onAppear` が再発火しない環境では古いテーマのまま残る。

### 修正方針
テーマの現在値を **AppModel の保存プロパティ**にして、変更が観測されるようにする。
UserDefaults は引き続き正本（プロセス間共有のため）で、AppModel はその写しを持つ。

`ios/DopaBreak/AppContainer.swift`:

1. 保存プロパティを追加する。
   ```swift
   /// ロック画面テーマの現在値。正本はUserDefaultsのままだが、
   /// computedのままだと@Observableが変更を配れないため写しを保持する。
   private(set) var lockThemeSelection: LockTheme
   ```
   `init` で `settingsStore.lockTheme` から初期化する。

2. 書き込み口をAppModelに一本化する。
   ```swift
   /// ロック画面テーマを保存し、掲出面と画面へ同時に反映する。
   func updateLockTheme(_ theme: LockTheme) {
       settingsStore.lockTheme = theme
       lockThemeSelection = theme
       refreshLockSurfaces(scheduleNotifications: false)
   }
   ```

3. 既存の読み出しを写し経由へ切り替える。
   ```swift
   var savedLockTheme: LockTheme { lockThemeSelection }

   var lockSurfaceState: LockSurfaceState {
       var state = settingsStore.lockSurfaceState
       state.theme = lockThemeSelection
       if !entitlementGate.lockThemeAllowed(state.theme) { state.theme = .e1 }
       return state
   }
   ```

4. `refresh()` の中で、他プロセス・オンボーディング経由の書き換えを取り込む。
   無駄な再評価を避けるため差分があるときだけ代入する。
   ```swift
   if lockThemeSelection != settingsStore.lockTheme {
       lockThemeSelection = settingsStore.lockTheme
   }
   ```

5. 呼び出し側を `model.updateLockTheme(_:)` へ差し替える（`settingsStore.lockTheme = ` の直接代入を消す）。
   - `ios/DopaBreak/HomeView.swift`（`selectHomeLockTheme` 内。`savedLockTheme` の @State 更新と
     `model.refreshLockSurfaces` の直接呼び出しは `updateLockTheme` に含まれるため整理する。
     ただしHomeViewの @State はピッカーの選択表示に使っているので、
     `model.savedLockTheme` を直接読む形へ寄せて @State を廃止してよい）
   - `ios/DopaBreak/SettingsLockSurfaceView.swift`
   - `ios/DopaBreak/OnboardingFlow.swift`

### 受け入れ条件
- ホームでテーマを変更 → 目標タブへ移動 → プレビューが新テーマで表示される（`onAppear` に依存しない）。
- 設定・オンボーディングから変更した場合も同様。
- 無料ユーザーがProテーマを選んだときの表示は現状維持（保存はされ、掲出は `.e1` へ丸める）。

---

## 不具合3: Live Activityで枠の四隅が切れる

### 根本原因
システムのコンテナ角丸は **23.5pt**（実測・端末依存）だが、テーマ側は自前の角丸で
カードを描いている:

- `gaming`: `RoundedRectangle(cornerRadius: 17, style: .continuous)` で `clipShape` + 2ptグラデ枠
- `kpop`: `cornerRadius: 18` の枠 + `clipShape`
- `note`: `cornerRadius: 18` / `15` の二重枠 + `clipShape`
- `liquidGlass`: `cornerRadius: 20` の `glassEffect` / `clipShape` / 枠
- `e1`(blackLime): 角丸なしの塗り + 左端3ptのライムバー

コンテナ側の角丸(23.5)のほうが大きいため、テーマ側の小さい角丸(17〜20)の四隅が
コンテナの外側にはみ出し、**四隅で切り落とされる**。枠線が角で途切れて見える。

### 修正方針
Live Activityでは**カード＝コンテナ**なので、外形をシステムのコンテナ角丸に一致させる。
WidgetKitの `ContainerRelativeShape` を使う（端末ごとの実値へ自動で合う）。
アプリ内プレビューにはコンテナが無く `ContainerRelativeShape` は矩形に退化するため、
固定値へ切り替えられるようにする。

`ios/WidgetsExtension/LockThemeLiveActivityView.swift`:

1. 外形の指定を型で持つ。
   ```swift
   enum LockThemeSurfaceShape: Equatable {
       /// Live Activity / ウィジェット本番。システムのコンテナ角丸へ自動一致。
       case containerRelative
       /// アプリ内プレビュー。コンテナが無いので実測値に近い固定値を使う。
       case fixed(CGFloat)
   }
   ```
   `LockThemeLiveActivityView` に `var surfaceShape: LockThemeSurfaceShape = .fixed(Self.previewCornerRadius)` を追加。
   `static let previewCornerRadius: CGFloat = 22`（実測23.5に近い代表値。コメントで実測値の出所を残す）。

2. 解決用のヘルパを1つ用意し、全テーマがこれを使う。
   ```swift
   private var surfaceClipShape: AnyShape {
       switch surfaceShape {
       case .containerRelative: return AnyShape(ContainerRelativeShape())
       case .fixed(let radius): return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
       }
   }
   ```

3. 各テーマの `clipShape(RoundedRectangle(cornerRadius: 17/18/20 ...))` と、
   外形を描く `overlay { RoundedRectangle(...).stroke(...) }` を `surfaceClipShape` ベースへ置換する。
   枠線は **`.stroke` ではなく `.strokeBorder`（内側インセット）** にして、
   コンテナ端でも線が半分削られないようにする。
   - `note` の内側破線枠（`cornerRadius: 15` + `.padding(7)`）のような
     「内側に寄せた装飾」は、外形より小さい角丸のままでよい（切れない）。
     外形と接する枠だけを対象にする。
   - `e1` の左端3ptバーは、`surfaceClipShape` でクリップして角丸に沿わせる。

4. Widget Extension 側の使用箇所で `.containerRelative` を渡す。
   `ios/WidgetsExtension/DopaBreakWidgets.swift` の `liveActivityView(state:)`。

5. アプリ内プレビュー側は `.fixed(LockThemeLiveActivityView.previewCornerRadius)` のまま。
   併せて `LockThemePreviewCard`（`ios/DopaBreak/LockThemePickerView.swift`）と
   `LockScreenGoalPreview`（`ios/DopaBreak/LockScreenCheckView.swift`）の
   ハードコード `cornerRadius: 18` を `LockThemeLiveActivityView.previewCornerRadius` へ寄せる。
   ピッカーカードは `scaleEffect` を掛けているので、角丸も同じ `scale` を掛けること（現行踏襲）。

### 受け入れ条件
- 実機のLive Activityで、全テーマの枠・角の装飾が四隅で切れない。
- アプリ内プレビューと実機の見た目の角丸が一致して見える。
- 既存の `LockThemeLiveActivityViewTests` / `LockThemeDensitySnapshotCapture` が通る。

---

## 不具合4: SNSを開いたときにDopaBreakで開いていた画面が出る

### 根本原因
ウォーム復帰の1フレームで、旧画面が露出している。

`BackgroundSnapshotShieldHost`（`ios/DopaBreak/BackgroundSnapshotShield.swift`）は
`.active` になった瞬間に、同一トランザクション内で
`consumePendingIntervention()`（= `model.pendingInterventionTarget` を立てる）を実行し、
**同時にシールドを外している**。

一方 `RootTabView` の介入オーバーレイは `@State interventionOverlay` で、
`.onChange(of: model.pendingInterventionTarget)` → `presentPendingInterventionIfValid` という
**body評価より後**の経路でしか立たない。

結果として「シールドは消えた／オーバーレイはまだ無い」フレームが必ず発生し、
直前に開いていたタブ（ホーム・設定など）が見えてしまう。

### 修正方針
**介入オーバーレイが実際に出るまでシールドを外さない。**

1. `ios/DopaBreak/AppContainer.swift` に観測可能なフラグを追加する。
   ```swift
   /// 介入オーバーレイが画面に出ているか。ウォーム復帰時に
   /// 背景シールドをいつ外してよいかの判断に使う。
   var isInterventionOverlayPresented = false
   ```
   `RootTabView` がオーバーレイを present / dismiss する両方の経路で必ず更新する
   （`presentPendingInterventionIfValid` の present 時に `true`、
   `interventionOverlay.dismiss()` を通る全経路で `false`）。

2. `BackgroundSnapshotShieldHost` に保持条件を渡す。クロージャは **body内で呼ぶ**こと。
   body内で呼べば `@Observable` の依存として登録され、値が変わった時点で再評価される。
   ```swift
   private let shouldHoldShield: () -> Bool
   ...
   if coordinator.isShieldVisible || shouldHoldShield() { シールド }
   ```

3. `ios/DopaBreak/DopaBreakApp.swift` で渡す。
   ```swift
   BackgroundSnapshotShieldHost(
       onAppActive: handleAppActive,
       shouldHoldShield: {
           model.pendingInterventionTarget != nil && !model.isInterventionOverlayPresented
       }
   ) { ... }
   ```

4. **ウォッチドッグ必須**。`presentPendingInterventionIfValid` は
   先行モーダルの解除待ち（`.waitForModalDismissal`）で早期returnする経路があり、
   そこで詰まると暗転したままになる。
   `BackgroundSnapshotShieldHost` 側で、保持を開始してから **1.5秒**経過したら
   保持を強制解除するタイマー（`Task` + `try? await Task.sleep`）を持つこと。
   保持条件が false に戻ったらタイマーはキャンセルする。
   「暗転したまま操作不能」は元の不具合より重いので、この安全弁は省略しない。

### 受け入れ条件
- 対象SNSアプリを開いてDopaBreakが立ち上がったとき、
  直前に開いていた画面が一瞬でも見えない（暗転→一呼吸画面）。
- 介入以外の理由でのウォーム復帰では、従来どおり即座にシールドが外れる。
- 何らかの理由で介入画面が出せなかった場合も、1.5秒以内にシールドが外れて操作できる。

---

## 実装上の共通ルール
- 省略・TODO禁止。既存テストを壊さない。
- 変更後に `xcodebuild -project ios/DopaBreak.xcodeproj -scheme DopaBreak -destination 'platform=iOS Simulator,id=DF6A380F-D0EC-42CA-A508-0D02CEE9F404' build` が通ること。
- UI文言は追加・変更しない（本件は挙動と描画の修正のみ）。
