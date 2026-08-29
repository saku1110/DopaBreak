# ロック画面テーマピッカー 独立レビュー指摘の是正（差し戻し）

- 元設計正本: `.claude/specs/lock-theme-picker-onboarding.md`（**§0の絶対制約は引き続き厳守**）
- 独立レビュー（Opus5）判定: **SEND BACK**
- 権利ガードの漏れは無し。`lockSurfaceState` / `EntitlementGate.lockThemeAllowed` / WidgetSnapshot / Live Activity の全経路がガード済みテーマを運んでいることは検証済み。**この構造を壊さないこと**

---

## F1 — 🔴 ブロッカー: 設定が保存済みProテーマを表示せず、追加した文言が到達不能

`ios/DopaBreak/SettingsView.swift:1923` の `refreshSettingsState()` が

```swift
selectedLockTheme = model.lockSurfaceState.theme   // ← ガード後の値
```

としており、この `@State` が `SettingsLockSurfaceView` へ `$selectedLockTheme` として渡っている（`SettingsView.swift:1071`）。

結果、**オンボでProテーマを選んだ無料ユーザー**（＝設計正本が「常態化する」と書いた当のケース）で:

- `SettingsLockSurfaceView.swift:38` の `!lockThemeAllowed(selectedLockTheme)` が常に false → 新規追加した `settings.lock_screen.pro_note` が**ja/en/ko とも一度も表示されない死んだ文字列**になっている
- `SettingsLockSurfaceView.swift:51` のチェックと枠が、保存済みテーマではなく `.e1` に付く

これは設計正本 §3.1 が未実装ということ。ユーザー自身の選択が設定画面から消え、購入動機を作るために足した注記も出ない。

**修正**: `SettingsLockSurfaceView` 内部で、ピッカーの `selectedTheme:` と注記の出し分けを **`settingsStore.lockTheme`（保存値）** から駆動する。`selectedLockTheme` は `SettingsView.swift:1083` の「いま実機に出ているもの」を示す親の行ラベル専用として残す。

---

## F2 — 🟠 オンボが課金済みユーザーに「Proにすると」と表示する

`ios/DopaBreak/OnboardingFlow.swift:544` と `:1389` が、注記の表示条件を entitlement ではなく `OnboardingThemeSummaryPolicy.showsThemeCard(for:)`（= `theme != .e1`）で判定している。

再インストールや復元でオンボを通る課金済みユーザーは `storeService.isPro` が true になるため、Proテーマを選ぶと「Proにすると このデザインで表示されます」、まとめ画面で「Proにすると このデザインになります」が出る。**すでに払っている人に事実と違う文言を見せている。** DEBUGのリプレイ経路（`SettingsAboutView.swift:170`）からも再現する。設定画面は正しく entitlement で判定できている。

**修正**: `showsThemeCard` は「カードを出すか」の判定として維持し、**注記2箇所だけ** `!model.entitlementGate.lockThemeAllowed(selectedLockTheme)` で出し分ける。

---

## F3 — 🟠 iPadでカードが実寸のまま中央に浮き、行の高さが破綻する

`ios/DopaBreak/LockThemePickerView.swift:92` は `scale = min(1, width/393)` でカードを縮めるが、外側の `.aspectRatio(393/160, .fit)` の箱はコンテナ幅いっぱいに広がったまま。レビューの実測では 700pt コンテナで **箱 700×285 に対しカードは 393×160 が中央描画**、1行あたり縦125pt・左右各154ptの死に領域が出る。

本アプリは `TARGETED_DEVICE_FAMILY = "1,2"` でiPadを含む。

**修正**: 比率を当てる前に幅を丸める。`GeometryReader` に `.frame(maxWidth: 393)` を先に当ててから `.aspectRatio(...)` を適用し、箱の高さが常に実描画カードの高さと一致するようにする。

---

## F4 — 🟠 固定332ptビューポートが画面を捨てている（**実機で確認済み・見た目の最大の問題**）

`LockThemePickerView.swift:36/70` が自前の `ScrollView` を固定高332ptで抱えている。

iPhone 16 Pro Max の実機スクリーンショットで確認した実害:

- オンボのテーマ選択画面（15/17）で**カードが2枚しか見えず、その下に約500ptの空白**。この画面には4枚入る余地がある
- iPhoneでは `scale = 1.0`（コンテナ幅≒400pt ≥ 393pt）なのでカードは実寸。160×2＋間隔12＝332ptちょうどで打ち切られている
- 「まだ他にもある」と伝えるのがこの画面の役目なのに、2枚で止まって下が真っ黒。**無駄な余白**として即座に目につく

さらに:
- `HomeView.homeThemePickerSheet` は `.presentationDetents([.large])` に332ptのリストを置いており、シート内に350〜400ptの空背景が残る
- `SettingsLockSurfaceView` と `lockThemePickContent`（`screenScroll` の内側＝すでに `ScrollView`）で**縦スクロールの入れ子**になる。カード上から始めたドラッグで外側のページが動かせない

**修正**: `LockThemePickerView` は `LazyVStack` だけを返し、スクロール容器は呼び出し側が持つ。
- ホームのシート: 自前の `ScrollView` で包み、シート高いっぱいに使う
- オンボ・設定: 外側の既存 `ScrollView` に乗せる（入れ子を解消し、空いた縦を全部カードに使う）

---

## F5 — 🟡 VoiceOverでロック済みテーマを区別できない

`LockThemePickerView.swift:64` の `.accessibilityLabel(theme.localizedDisplayName)` がラベル部分木を置換するため、Proバッジが読み上げられない。無料ユーザーは無料テーマとロック済みテーマを同じ読み上げで聞くことになる。

**修正**: `showsProBadge` のとき `settings.status.pro` をラベルへ追加する（または `.accessibilityValue` で露出する）。

---

## F6 — 🟡 テーマを1つ触るたびに通知の再スケジュールまで走る

`OnboardingFlow.swift:1346` / `SettingsLockSurfaceView.swift:122` / `HomeView.swift:768` がいずれも `model.refreshLockSurfaces()` を既定の `scheduleNotifications: true` で呼んでいる。10テーマを見比べると、スナップショット書き込み・`WidgetCenter` リロード・通知の全削除再登録・ActivityKit更新が各10回走る。

世代ガードがあるので不正動作ではないが、ActivityKitは高頻度更新をスロットルするし、**テーマは通知内容に一切影響しない**ので通知の再スケジュールは純粋な無駄。

**修正**: テーマ変更のみの経路は `model.refreshLockSurfaces(scheduleNotifications: false)` にする。設計正本 §2.2 は満たしたまま。

---

## F7 — 🟡 ホームのカードとシートの選択状態が食い違う

`HomeView.swift:701` はガード後のテーマ（無料なら黒とライム。設計正本 §4 のとおり正しい）を描くが、`:717` のシートは**保存値**にチェックを付ける。無料ユーザーはホームで黒とライムを見た直後に、シートで別のテーマが選択済みなのを理由の説明なしに見ることになる。

**修正**: `homeThemePickerSheet` でも、選択が未解放のとき既存キー `settings.lock_screen.pro_note` をピッカー上部に出す。

---

## F8 — ℹ️ 記録のみ。コードは変えない

`confirmLockThemeAndAdvance()` が `detail: "lock_theme_pick:<raw>"` を記録し、その後 `advance(from:)` が `detail: "lock_theme_pick"` を記録するため、このステップだけ `onboardingStepCompleted` が1人あたり2件出る。detail別に見る分には問題ないが、**イベント名だけで数えると1件多い**。設計正本 §2.4 の要求どおりの実装なので変更せず、`.claude/specs/lock-theme-picker-onboarding.md` に注記を追記すること。

---

## テスト強化（必須）

現状 `testLockedThemeUsesEntryPointSpecificPaywallPlacement` / `testLockThemePickerRendersEveryThemeInCaseOrder` / `testPrePaywallSummaryOnlyShowsCardForProThemeSelection` は小さなポリシーヘルパーだけを見ており、**呼び出し側を一切通っていない**。`HomeView` が誤って `entryPoint: .settings` を渡しても検出できない。これは課金導線のルーティングなので最も守るべき箇所。

追加すること:

1. **Home 経路が `.homeThemeGate`、Settings 経路が `.settingsThemeGate` を立てること**を、ヘルパー単体ではなく各画面の選択ハンドラを通して検証する
2. **F1の回帰**: free かつ保存値がProテーマのとき、設定のピッカーが**保存済みテーマ**を選択状態にし、`settings.lock_screen.pro_note` の表示条件が true になること
3. **F2の回帰**: Pro ユーザーがオンボでProテーマを選んだとき、注記2箇所がどちらも出ないこと
4. **F3の回帰**: 幅700ptでレンダリングしたとき、行の箱の高さがカード実寸の高さと一致すること（レターボックスが出ないこと）

## 完了条件

- generic iOS の全ターゲットで `BUILD SUCCEEDED`
- DopaBreakCore と DopaBreakTests が失敗0
- `scripts/lint-display-copy.py` と `scripts/audit-default-values.py` が exit 0
- 元設計正本 §0 の7項目に一切触れていないこと（**特に `AppContainer.lockSurfaceState` の権利ガード**）
