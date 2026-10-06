# 対象アプリの入れ替え許可 ＋ 追加直後のショートカット案内（2026-09-04・オーナー承認済み）

正本。実装はこの文書に従う。オーナー承認は2026-09-04（選択肢①「入れ替えを許可」・②「追加直後に自動で出す」）。

## 背景（Fable が実機相当のシミュレータで再現・原因確定）

オーナー報告:
1. 「一度止めるアプリから外して もう一度止めるアプリを設定しようとすると有料ペイウォールが出てくる」
2. 「止めるアプリ追加時にショートカット案内がもう一度出てこない」

### ①の再現手順と真因（推測ではない・2026-09-04 実測）

無料アカウント（`entitlementCachedIsPro=false`・上限1個）で:
1. Instagram を対象から外す
2. 代わりに X を対象にする（無料枠1個が埋まる）
3. `dopabreak://intervene?app=instagram` 相当（＝残っているショートカット自動化の発火）
4. 「Instagramは一呼吸の対象外です」シートが出る。本文は「**対象に戻すか** 自動化を削除してください」なのに、
   主ボタンは「**Proを再開する**」→ タップでペイウォール（`.settingsTargetAppLimit`）

真因: `ios/DopaBreak/RootTabView.swift` の `canRestoreNonTargetAutomation(_:)` が
`entitlementGate.canAddTargetTokens(currentCount: selected.count)` で判定している。
枠がすでに埋まっていると「2個目の追加」と見なされ、**入れ替えのつもりでも課金導線へ落ちる**。

付随する不具合:
- 本文が案内する「対象に戻す」経路が、その画面に存在しない（本文とボタンの矛盾）
- 一度もProを買っていない人に「Pro**を再開**する」と出る（`.removed` 経路なのに失効時の文言）

### ②の真因

オンボーディング以外で対象アプリを追加したとき `AutomationGuideView` を出す経路がコード上に無い。
`isAutomationGuidePresented = true` は SettingsView の行タップ（2箇所）と HomeView のバナーボタンのみ。
追加直後はホームのバナー（`home.automation_status.*`）だけで、設定画面から追加した人はホームへ戻らない限り何も見ない。
※シミュレータで確認: X を追加 → 案内は出ず、ホームに「Xで一呼吸の設定が完了していません」バナーのみ。

## 実装（①入れ替え）

### A. Core に純関数を新設

`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/NonTargetAutomationRestorePolicy.swift`

```swift
public enum NonTargetAutomationRestorePolicy {
    public enum Decision: Equatable, Sendable {
        case add                                  // 枠に空きがある
        case swap(displacedCatalogIDs: [String])  // 枠が埋まっているので入れ替える
        case requiresPro                          // Pro失効クランプ経路（課金導線を維持）
    }

    public static func decision(
        reason: NonTargetAutomationReason,
        restoredCatalogID: String,
        selectedCatalogIDs: [String],
        limit: Int?
    ) -> Decision

    /// 決定に対応する保存後の並び。順序は決定的にする。
    public static func resultingCatalogIDs(
        restoredCatalogID: String,
        selectedCatalogIDs: [String],
        limit: Int?
    ) -> [String]
}
```

規則:
- `reason == .clampedByEntitlement` → 常に `.requiresPro`（2026-09-03の決定を維持。あちらはPro失効の課金導線であり、
  削除側だけ軽くすると再課金の理由が消えるため）
- `limit == nil`（Pro）または `selectedCatalogIDs.filter { $0 != restoredCatalogID }.count < limit` → `.add`
- それ以外 → `.swap(displacedCatalogIDs:)`。押し出される側は下の並びから決める
- `resultingCatalogIDs` = `Array((selectedCatalogIDs.filter { $0 != restoredCatalogID } + [restoredCatalogID]).suffix(limit ?? .max))`
  - 上限1・選択が `["x"]`・戻すのが `instagram` → 結果 `["instagram"]`・押し出しは `["x"]`
  - 既に含まれている場合は重複を作らない（`InterventionTargetStore.validate` が重複で throw する）
  - `limit == 0` は起こらないが、0のときは空配列を返し `.requiresPro` 扱いにしない（防御的に `.add` を返さないこと）

テスト `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/NonTargetAutomationRestorePolicyTests.swift`:
空き枠あり／枠が埋まって入れ替え／Pro（上限なし）／`.clampedByEntitlement`／既に対象に含まれている場合／順序の決定性。

### B. RootTabView を差し替え

- `canRestoreNonTargetAutomation` を廃止し、`restoreDecision(for:)` に置き換える
  （`entitlementGate.targetAppTokensLimit` と保存済み選択から `Decision` を作る）
- `NonTargetAutomationSheet` へ `Decision` を渡す（`canRestoreWithoutPurchase: Bool` は廃止）
- `restoreNonTargetAutomation(_:)` は `resultingCatalogIDs(...)` の結果を `model.setTargetCatalogIDs(...)` へ渡す。
  `setTargetCatalogIDs` は外れた分の `catalogAllowanceStore.revoke` とクランプ控えの破棄を既に行うのでそのまま使う
- 保存に失敗したときは従来どおり `model.alertMessage` を出し、シートは閉じない
- `.requiresPro` のときだけ `showProForNonTargetAutomation` へ流す（現状のペイウォール導線を維持）

### C. NonTargetAutomationSheet の表示

- 主ボタン
  - `.add` → `automation.non_target.action.restore`（「対象に戻す」・既存キー）
  - `.swap` → **新キー** `automation.non_target.action.swap` = 「\(押し出されるアプリ名)と入れ替える」
  - `.requiresPro` → `automation.non_target.action.pro`（「Proを再開する」・既存キー。失効した人にだけ出るので文言は正しくなる）
- 本文
  - `.add` → `automation.non_target.body.removed`（既存）
  - `.swap` → **新キー** `automation.non_target.body.removed_swap`
    ja: 「対象から外したあとも ショートカットの自動化は残っています。いま対象になっているのは\(押し出されるアプリ名)です。入れ替えると\(押し出されるアプリ名)は対象から外れます」
  - `.clampedByEntitlement` → `automation.non_target.body.clamped`（既存）
- 「自動化の削除方法」の中の「ショートカットを開く」は `reason == .removed` 限定のまま（2026-09-03の決定）

### D. 文言の制約（オーナー恒久ルール）

- 見出し・ボタンは**表示コピー**。読点を入れない。区切りは半角スペース
- 本文は通常文。一文の読点は1〜2個まで。接続助詞で節をつなげず短文に割る
- ja/en/ko の3ロケールを `ios/DopaBreak/Localizable.xcstrings` に追加する。既存エントリの書式（区切り・並び）を崩さない
- 内部用語（介入・シールド・トークン）をUIに出さない

## 実装（②追加直後のショートカット案内）

### E. TargetAppPickerSheet

- `let onTargetAdded: (String) -> Void` を追加（既定値は付けず、両方の呼び出し元で明示的に渡す）
- 追加分岐で `persist()` が成功したときだけ `onTargetAdded(item.catalogID)` を呼ぶ
- 削除分岐・ペイウォール分岐では呼ばない
- 既存の `onPaywallNeeded` と削除時アラートの挙動は変えない

### F. HomeView / SettingsView

- `@State private var pendingAutomationGuideAfterPicker = false`
- `onTargetAdded` で、`!model.verifiedAutomationCatalogIDs.contains(catalogID)` のときだけ `true` にする
  （検収済みのアプリを選び直しただけのときは出さない。ショートカットは既にあるため）
- ピッカーの `onDismiss`:
  - ペイウォール提示が保留なら **ペイウォールを優先**し、フラグは保持する
  - そうでなければ `pendingAutomationGuideAfterPicker` を消費して `isAutomationGuidePresented = true`
- ペイウォールの `onDismiss` でフラグが残っていれば、そこで案内を出す
  （HomeView の `fullScreenCover(item: $paywallPlacement)` には現状 `onDismiss` が無いので追加する。
   SettingsView は既存の `onDismiss: { refreshSettingsState() }` を拡張する）
- 案内から戻ったら既存の `refreshSettingsMirrors` / `refreshSettingsState` で検収状態を取り直す（既存のまま）
- モーダルの衝突を避けるため、提示は `onDismiss` からのみ行う。`isAnyChildModalPresented` の計算に変更は不要
  （`isAutomationGuidePresented` は既に含まれている）

### G. オンボーディングは変更しない

`OnboardingFlow` は既に `.ready` ステップで案内を出す。二重提示になるので触らない。

## 変更しないもの

- 無料枠の個数（1個）と `EntitlementGate` の上限定義
- `TargetAppPickerSheet` の「2個目を追加したらペイウォール」経路（無料枠の本来のゲート）
- `.clampedByEntitlement`（Pro失効）のペイウォール導線
- `setTargetCatalogIDs` の保存契約・`catalogAllowanceStore` の失効処理
- ShieldController / 完全ブロック側のルール

## 受け入れ条件（実測で確認する）

1. Core `swift test` 全件パス（新規テスト含む）
2. アプリ側 `xcodebuild test` 全件パス。**他セッションが使っていないシミュレータを指定**して実行し、
   ログ本文の `TEST SUCCEEDED` で判定する（`| tail` の終了コードで判定しない）
3. 実機相当の手順で再現しないこと:
   - 無料・Instagram を外す → X を対象にする → `dopabreak://intervene?app=instagram`
     → 主ボタンが「Xと入れ替える」になり、押すと**ペイウォールが出ずに**対象が `["instagram"]` へ入れ替わる
   - 無料・対象が空の状態で同じ経路 → 主ボタンは「対象に戻す」のまま
   - 無料・アプリ選択シートで X を追加して閉じる → ショートカット案内が自動で開く
   - 既に検収済みの Instagram を選び直して閉じる → 案内は開かない
4. xcstrings が有効（ja/en/ko すべて `translated`）

---

## 2026-09-05 追記（オーナー決定・F節の条件を上書き）

### 決定
- **検収済みのアプリを選び直したときも案内を出す**（オーナー「選び直した時も出して」2026-09-05）。F節の `!model.verifiedAutomationCatalogIDs.contains(catalogID)` 条件は廃止。`onTargetAdded` は常に予約する（実装済み・Codex Luna）
- 設定画面の行ラベル `settings.target.automation` を「ショートカットの設定方法」（en "How to set up the Shortcut" / ko "단축어 설정 방법"）へ変更（実装済み）

### 追加修正: 購入後に追加されるアプリにも案内を出す（Opus5レビュー指摘）
無料枠の上限で `TargetAppPickerSheet` が `onPaywallNeeded` を呼ぶ経路では、対象は購入後に `AppContainer.applyPurchaseContinuationIfNeeded` の `.addTargets` で黙って追加される。このとき `pendingAutomationGuideAfterPicker` は空のため案内が開かない。

設計:
1. `AppContainer` に `@Published var pendingAutomationGuideAfterPurchase = false` を追加。`applyPurchaseContinuationIfNeeded` の `case .addTargets` が成功したら `true` にする（`.applyMode` では立てない）
2. `HomeView` と `SettingsView` の **ペイウォール `fullScreenCover` の `onDismiss`** で、`presentAutomationGuideAfterPickerIfNeeded()` の前に `model.pendingAutomationGuideAfterPurchase` を見る。true なら false に戻して `pendingAutomationGuideAfterPicker` に空でない印（例: 追加されたcatalogID群、取れなければ `"purchase"` のような固定値）を入れてから `presentAutomationGuideAfterPickerIfNeeded()` を呼ぶ
   - ペイウォールを出していた側の `onDismiss` だけが走るので、Home/Settingsの二重提示は起きない
   - 既存の `pendingAutomationGuideRequest`（通知タップ用・SettingsViewの `onChange` が消費）は流用しない。流用するとHomeのペイウォール中にSettings側が非表示タブで消費してしまう
3. `isAnyChildModalPresented` はすでに `!pendingAutomationGuideAfterPicker.isEmpty` を数えているので変更不要
4. 単体テスト: `PurchaseContinuationPolicy` はCore側で変更なし。AppContainer側は既存テストパターンがあれば `.addTargets` 後にフラグが立つことを1件追加、なければ追加不要
