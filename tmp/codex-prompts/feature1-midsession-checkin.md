# タスク: セッション中の軽量チェックイン通知

DopaBreak（iOS/SwiftUI/iOS 17+）への機能追加。設計は`.claude/plans/crystalline-imagining-shannon.md`の「1. セッション中の軽量チェックイン通知」に承認済み。文言正本は`docs/11_ui_copy.md` §10（既に追記済み・変更不要、そこから転記のみ）。省略・TODO禁止、完全なコードを出力すること。

## 背景・重要な制約
DopaBreakはiOS Shortcutsのパーソナルオートメーションが対象アプリの起動を検知してDopaBreakを一瞬起動し、ユーザーが「時間を決めて開く」を選ぶと`UIApplication.shared.open(url)`でSNSアプリへ制御を渡す。**その後DopaBreakはSNSアプリ内で何が起きているか一切検知できず、強制的に中断させることもできない。** 今回追加する「セッション中チェックイン」は、時間の半分が経過した時点でローカル通知を1本追加するだけの、ソフトな呼びかけである。通知をタップしたときだけ、軽量な確認シートを表示する（強制力は一切ない）。

## 現状（実装済みの参考パターン）
- `ios/DopaBreak/InterventionFlowModel.swift`の`selectDuration(_:)`→`scheduleTimeUpNotification(after:)`が、選択時間経過後に1本のローカル通知（`UNTimeIntervalNotificationTrigger(timeInterval:, repeats: false)`、識別子`"dopabreak.timeup.\(UUID().uuidString)"`）をスケジュールしている。これと同じ書き方を踏襲する
- 現在`UNUserNotificationCenterDelegate`は未実装（アプリ全体で通知タップのハンドリングなし）。通知タップは単にアプリをフォアグラウンドにするだけで、`RootTabView`が`scenePhase == .active`のたびに`checkPendingIntervention()`/`checkPendingReflection()`を呼んでApp Group経由の保留フラグをチェックする、というポーリング的な設計になっている。今回追加する通知はデリゲートで能動的に検知が必要（時間半分経過時点という「今」を捉える必要があるため）
- App Group経由の保留フラグの既存例: `SettingsStore.pendingStartInterventionCatalogID`（`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SettingsStore.swift`）

## 実装項目

### 1. `SettingsStore.swift`
既存の`Key`enum + computed propertyパターンに倣い追加:
- `Key.pendingMidSessionCheckInCatalogID = "pendingMidSessionCheckInCatalogID"`
- `public var pendingMidSessionCheckInCatalogID: String?`（`pendingStartInterventionCatalogID`と全く同じ実装パターン、`setOptional`ヘルパー再利用）

### 2. `InterventionFlowModel.swift`の`selectDuration(_:)`/`scheduleTimeUpNotification(after:)`周辺
- 選択された`duration.seconds`が600秒（10分）以上のときだけ、`scheduleTimeUpNotification`と同じ呼び出し箇所で追加のローカル通知をスケジュールする新規メソッド`scheduleMidSessionCheckIn(after duration: InterventionDuration)`を追加
- 通知内容: タイトル「まだ見てる？」本文「戻る先を思い出す時間です」、`.default`サウンド
- トリガー: `UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(duration.seconds / 2), repeats: false)`
- 識別子: `"dopabreak.midsession.\(target.catalogID).\(UUID().uuidString)"`（プレフィックス`dopabreak.midsession.`＋catalogIDをこの順で埋め込む。後述のデリゲートでパースする）

### 3. 新規: `NotificationDelegate.swift`（`ios/DopaBreak/`配下）
```swift
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let identifier = response.notification.request.identifier
        let prefix = "dopabreak.midsession."
        guard identifier.hasPrefix(prefix) else { return }
        let remainder = identifier.dropFirst(prefix.count)
        // remainder は "<catalogID>.<uuid>" 形式。catalogID自体にピリオドを含まない前提（SNSAppCatalogのIDが英数字のみであることを確認して実装すること。含む可能性があるならUUID側から区切る等、確実にcatalogIDを取り出せるロジックにする）
        guard let catalogID = remainder.components(separatedBy: ".").first, !catalogID.isEmpty else { return }
        settingsStore.pendingMidSessionCheckInCatalogID = catalogID
    }
}
```
上記は方針例。`SNSAppCatalogItem.catalogID`の実際の値の形式（英数字のみかどうか）を`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/`内のSNSAppCatalog定義から確認し、識別子のパースが確実に一意復元できる形式にすること（不安なら区切り文字を`|`など catalogIDに出現しない文字にする）。

`ios/DopaBreak/DopaBreakApp.swift`の起動時（`init`または`.onAppear`最初期）に`UNUserNotificationCenter.current().delegate = notificationDelegate`を設定する。`NotificationDelegate`インスタンスは`AppContainer.swift`の`AppModel`か`DopaBreakApp`自体が保持し、アプリのライフサイクル中ずっと生存させること（弱参照で消えないように注意）。

### 4. 新規: `MidSessionCheckInSheet.swift`（`ios/DopaBreak/`配下、`PostUseReflectionSheet.swift`と同程度の軽量`.sheet`）
- 見出し「まだ見てる？」
- 目標がある場合: 「戻る先 {目標}」（`model.goals.first`があればそのタイトル、モデルなければ「何のために開いたか思い出せますか」）
- ボタン1つのみ「閉じる」（dismiss）。それ以上の分岐・記録は行わない（強制力がないことに誠実な最小UI）

### 5. `RootTabView.swift`
- 既存の`checkPendingIntervention()`/`checkPendingReflection()`と並列に`checkPendingMidSessionCheckIn()`を追加し、`.onAppear`と`scenePhase == .active`のタイミングで呼ぶ（既存2つの呼び出し箇所と同じ場所に追加）
- `settingsStore.pendingMidSessionCheckInCatalogID`を読んで`nil`でなければ`@State`にセットして`.sheet`で`MidSessionCheckInSheet`を表示し、読み取り後は`nil`に戻す（消費パターンは`pendingStartInterventionCatalogID`の消費と同様）
- 既存の`checkPendingIntervention()`（fullScreenCover）が優先表示中はこのチェックインシートを重ねて出さない（既存の優先順位ロジック=pendingReflectionはpendingInterventionがない場合のみチェックしている、のパターンに倣う）

## 禁止事項
- SNSアプリを実際に閉じる・強制する表現やロジックを一切書かない（技術的に不可能）
- 既存のS-01〜S-05フロー・`scheduleTimeUpNotification`の既存動作には触れない（新規メソッド追加のみ）
- docs/11_ui_copy.mdは変更しない（既に§10として追記済み）
- コード省略・TODO・プレースホルダ禁止

## 完了条件
1. `swift test --package-path ios/Packages/DopaBreakCore` 全件パス
2. `cd ios && xcodebuild build -scheme DopaBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` が `BUILD SUCCEEDED`
3. `SettingsStore`の新規プロパティに対するユニットテストを追加（既存の設定ラウンドトリップテストと同じ場所・パターン）
4. 変更/新規ファイル一覧とテスト結果を最後に要約すること
