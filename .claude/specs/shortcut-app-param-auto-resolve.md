# ショートカットの「どれですか?」プロンプトを構造的に無くす（2026-08-28・オーナー指示「いらない削除」）

## 事実
- `ios/DopaBreak/StartInterventionIntent.swift:70-77` の `@Parameter var app: SNSAppEnum` は**必須・既定値なし**。オートメーション作成時に手順7（アクション内の「アプリ」を選ぶ）を飛ばすと、ショートカットが実行のたびに既定文言「どれですか?」で8件（`SNSAppEnum` 全ケース）を聞く。オーナー実機で再現（スクショ: Instagram起動時）
- 対象アプリは `targetStore.selectedCatalogIDs()`（Free=1個・Proは複数）に保存済み。Freeユーザーは常に1個なので、アプリ側で確定できる

## 変更
### 1. `StartInterventionIntent`（`ios/DopaBreak/StartInterventionIntent.swift`）
- `var app: SNSAppEnum?` に変更（**省略可**。ショートカットは省略可パラメータが未設定でもプロンプトを出さない）。`init(app:)` も合わせる
- `perform()`: `app` が非nilなら従来どおり `pendingStartInterventionCatalogID = app.catalogID`。nilなら **自動解決要求**を残す（`SettingsStore` に新キー `pendingStartInterventionAutoResolve: Bool`。既存の catalogID キーと同じ App Group UserDefaults。両方立っていたら catalogID を優先）
- パラメータの `title` は既存キーのまま。`parameterSummary` があれば「アプリ（省略可）」相当の表示に（Shortcuts上で「任意」と分かるように。新キー不要ならAppleの既定表示でよい）

### 2. 解決ポリシー（Core・純関数・テスト必須）
`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/InterventionTargetResolutionPolicy.swift`
```swift
public enum InterventionTargetResolution: Equatable, Sendable {
    case target(catalogID: String)      // 確定
    case choose(catalogIDs: [String])   // 複数候補（アプリ内で選ばせる）
    case none                            // 対象アプリ未選択
}
public enum InterventionTargetResolutionPolicy {
    /// requested: ショートカットが渡したcatalogID（nil=省略）／selected: 設定済みの対象アプリ（保存順）
    public static func resolve(requested: String?, selected: [String]) -> InterventionTargetResolution
}
```
- requested が非nilかつカタログに存在 → `.target`（selectedに無くても従来どおり尊重。既存挙動を変えない）
- requested が nil: selected が1件 → `.target`／2件以上 → `.choose(selected)`／0件 → `.none`
- テスト（`DopaBreakCoreTests/InterventionTargetResolutionPolicyTests.swift`）: 上記4分岐＋requestedが未知IDのときの扱い（既存 `requestStartIntervention` と同じく無視＝`.none` か、selectedで解決するかを決めて固定）

### 3. アプリ側（`AppContainer.swift` / `DopaBreakApp.swift:226付近` の取り込み）
- AppIntentが残した要求を取り込む箇所で、`pendingStartInterventionAutoResolve` を読み `InterventionTargetResolutionPolicy.resolve` を適用
  - `.target` → 既存 `requestStartIntervention(catalogID:)`
  - `.choose(ids)` → `pendingInterventionTarget = .catalogChoice(ids)`（`InterventionTarget` に新ケース）
  - `.none` → 何もしない（対象未設定。既存のガイド導線に任せる）
- 取り込み後はフラグを必ず消す（既存の catalogID と同じ一回限り）

### 4. 介入フロー（`InterventionFlowView.swift`）— `.catalogChoice` のときだけ先頭に1画面
- タイトル（新キー `intervention.choose_app.title`）ja「どのアプリを開きましたか」／en「Which app did you open?」／ko「어떤 앱을 열었나요?」（**読点・句点なし**）
- 候補は selected の順に `SNSAppCatalog` の表示名で、既存の介入画面のカード様式（44pt以上）。選ぶと従来の `.catalog(target)` として通常フローへ
- 候補の下に案内1行（新キー `intervention.choose_app.hint`）ja「オートメーション作成時にアプリを選んでおくと次から出ません」／en「Pick the app when you create the automation and this won't show again」／ko「자동화를 만들 때 앱을 선택해 두면 다음부터 표시되지 않습니다」
- 背景（オーナー指摘 2026-08-28）: iOSのAppオートメーションはトリガーしたアプリをアクションに渡さない。特定のSNSを開いているのに選ばされる体験は最悪なので、この画面は「手順7を飛ばした複数アプリ利用者」だけに限定し、Freeユーザーには絶対に出さない
- 既存のE1 Dark Mono・文言規則（造語禁止・ユーザー語彙）に従う。1件のときはこの画面を出さない（ポリシーが `.target` を返すため）

### 5. ガイド文言（`Localizable.xcstrings` のみ・Swift側は不変）
- `automation_guide.step.7` ja: 「アクション内の「アプリ」で対象アプリを選び、右上のチェックで完了（止めるアプリが1つなら選ばなくても動きます）」。en/koも同義。読点は構造上必要な1箇所まで

### 6. 不変
- 既存の per-app オートメーション（パラメータ設定済み）は挙動不変。`dopabreak://intervene?app=` のURL経路も不変
- シールド経由（`.gateToken`）の経路は触らない

## 検証（全て実行して報告）
- `cd ios/Packages/DopaBreakCore && swift test`（新テスト含め全合格）
- `cd ios && xcodebuild test -project DopaBreak.xcodeproj -scheme DopaBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` TEST SUCCEEDED
- `python3 scripts/lint-display-copy.py` / `python3 scripts/audit-default-values.py` exit 0
- 新規ファイルがあれば `cd ios && xcodegen generate`
- 報告: 変更ファイル一覧＋3行要約＋検証結果。差分本文は貼らない
- 注意: `HomeView.swift` / `PaywallView.swift` / `OnboardingFlow.swift` / `SettingsLockSurfaceView.swift` には別セッションの未コミット差分があるため**触らない**

## 2026-08-28 訂正 — 選択画面も含めて完全に削除（オーナー再確認）

- オーナー指示「『どれですか？』はいらない、削除」は、Shortcutsの既定プロンプトだけでなく、DopaBreak内へ置き換えた「どのアプリを開きましたか」画面も出さないという意味。上記の `.choose`／`.catalogChoice`／`intervention.choose_app.*` の仕様は失効する。
- ショートカットがアプリを明示した場合はその対象を優先する。省略時は、設定済み対象のうち保存順で最初の有効IDへ自動解決する。0件なら何も表示しない。複数件でも選択UIを挟まない。
- iOSのAppオートメーションは発火元アプリをAppIntentへ渡さないため、複数対象かつ引数省略時に正しい発火元を推測することはできない。正確なアプリ別記録・再オープンが必要なオートメーションでは、作成時に任意パラメータを明示する。実行時の質問は出さない。
