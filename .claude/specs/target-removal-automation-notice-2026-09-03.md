# 対象から外したアプリのショートカット自動化を消させる（2026-09-03・オーナー承認済み）

オーナー報告: 「対象アプリからインスタを外してもショートカットが設定されてるからSNSを開くとDopa Breakに遷移してしまう」

## 事実（調査結果・2026-09-03）

- iOSにはアプリ側からユーザーのオートメーションを削除・無効化するAPIがない。自動化が残る限り、対象外のアプリを開いてもDopaBreakは前面に出る。**この遷移自体はコードで止められない**
- 対象外アプリで発火した場合、一呼吸は出ない。`AppContainer.consumeInterventionRequest`（`ios/DopaBreak/AppContainer.swift:1093-1100`）が `selectedCatalogIDs` 未含有を検知し、理由 `.removed` で `pendingNonTargetAutomation` を立て `NonTargetAutomationSheet` を提示する
- 対象から外す操作（`ios/DopaBreak/TargetAppPickerSheet.swift:77-93` の `toggle()` → `persist()`）は保存するだけで、自動化が残る事実を伝えていない。**ここが本件の根本**
- 自動化の有無は `SettingsStore.verifiedAutomationCatalogIDs` / `isAutomationVerified(catalogID:)` で判定できる
- `shortcuts://` を開く実装は `OnboardingFlow.swift:2528` と `AutomationGuideView.swift:494` に既にある
- **バグ**: `NonTargetAutomationSheet` の「そのまま開く」（`ios/DopaBreak/RootTabView.swift:782` `openNonTargetAutomationApp`）は `UIApplication.shared.open` を呼ぶだけで自己起動を記録していない。通常の介入フローは `InterventionFlowModel.swift:389-390` / `:439-440` で `lastSelfOpenedCatalogID` と `lastSelfOpenedAt` を書き、`AutomationRequestPolicy.selfOpenSuppressionInterval`（8秒）で再発火を抑えている。非対象経路だけこれが抜けているため、対象アプリが前面に戻ると自動化が再発火して同じシートが返る

## オーナー決定（2026-09-03）

発火時の説明シートは残す（削除を促す唯一の接点であり「対象に戻す」導線も兼ねるため）。外す瞬間に削除を促す導線を足す。黙って元アプリへ返す案は不採用。

## 変更

### 1. Core: 案内可否の純関数（新規・テスト必須）

`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/TargetRemovalNoticePolicy.swift`

```swift
public enum TargetRemovalNoticePolicy {
    /// 対象から外した直後に「自動化が残っている」案内を出すか
    public static func shouldNotify(
        removedCatalogID: String,
        verifiedAutomationCatalogIDs: [String]
    ) -> Bool
}
```

- `SNSAppCatalog.contains(catalogID:)` を満たし、かつ `verifiedAutomationCatalogIDs` に含まれるときだけ `true`
- テスト（`DopaBreakCoreTests/TargetRemovalNoticePolicyTests.swift`）: 検収済み→true／未検収→false／未知ID→false／空配列→false

### 2. TargetAppPickerSheet: 外した直後に案内

- `toggle()` の削除分岐で `persist()` のあとに判定する。`true` なら Apple標準の `.alert` を出す。削除自体は従来どおり即保存する（案内は情報提示であって取り消しではない）
- 文言は `ios/DopaBreak/Localizable.xcstrings` に ja/en/ko を追加する

| キー | ja |
| --- | --- |
| `target_app_picker.automation_notice.title` | `\(displayName)の自動化が残っています` |
| `target_app_picker.automation_notice.body` | `ショートカットの自動化はDopaBreakからは消せません。残したままだと\(displayName)を開くたびにDopaBreakが開きます` |
| `target_app_picker.automation_notice.action.open` | `ショートカットを開く` |
| `target_app_picker.automation_notice.action.later` | `あとで` |

- 主操作は `shortcuts://` を開く。副操作は閉じるだけ
- 表示コピー規則に従う。タイトル・ボタンに句読点を入れない。本文は短文2つに割って読点を増やさない
- en/ko も同義。既存の `automation.non_target.*` の語彙と揃える

### 3. RootTabView: 「そのまま開く」のループ修正（純粋なバグ）

- `AppContainer` に `func markSelfOpened(catalogID: String)` を追加する（`settingsStore` が `private` のため外から書けない）。`lastSelfOpenedCatalogID` と `lastSelfOpenedAt = now()` を書く
- `openNonTargetAutomationApp` は `UIApplication.shared.open(url)` の直前にこれを呼ぶ
- `InterventionFlowModel.swift:389-390` と `:439-440` の直書きも同メソッドへ寄せる（挙動不変）
- テスト（`ios/DopaBreakTests/InterventionRoutingTests.swift`）: 非対象シートから開いた直後の自動化要求が `discardSelfOpen` で捨てられ、シートが再提示されないこと

### 4. NonTargetAutomationSheet: 削除手順にボタンを足す

- `showsDeleteSteps` 展開時、手順テキストの下に `SecondaryButtonStyle` の「ショートカットを開く」を置き `shortcuts://` を開く
- 文言キーは 2 と共有してよい。共有する場合はどちらか一方に寄せて重複キーを作らない

### 5. 不変

- `.clampedByEntitlement`（Pro失効でクランプ）経路の文言・導線は変えない
- 一呼吸フロー本体、シールド（`.gateToken`）経路、`dopabreak://intervene?app=` は触らない
- オンボーディングの対象選択（`OnboardingFlow.swift:2323`）は対象外。初回選択時点では自動化がまだ無い

## 検証（全て実行して報告）

- `cd ios/Packages/DopaBreakCore && swift test`
- `cd ios && xcodebuild test -project DopaBreak.xcodeproj -scheme DopaBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` TEST SUCCEEDED
- `python3 scripts/lint-display-copy.py` / `python3 scripts/audit-default-values.py` exit 0
- 新規ファイルを追加するので `cd ios && xcodegen generate --spec project.yml`
- 実機: ①Instagramを対象から外す→案内が出る→「ショートカットを開く」でショートカットアプリへ ②自動化を残したままInstagramを開く→説明シート→「そのまま開く」→Instagramに戻ってシートが**再表示されない**こと
- 報告は変更ファイル一覧と3行要約のみ。差分本文は貼らない

## 注意

- 2026-09-03 時点でこのリポジトリには157ファイル・約6,800行の未コミット差分がある（`Gate*` 一式の削除を含む）。`AppContainer.swift` は同日10:41に更新されている。並行セッション（`test-project-c4`）の作業中である可能性が高い。**着手前にその状態を確認し、衝突しないことを確かめる**
