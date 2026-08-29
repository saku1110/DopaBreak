# 利用時間の通知（UsageWatch）機能の廃止（2026-08-28・オーナー決定）

## 決定と理由
iOSのDeviceActivityは「今アプリを開いているか」をリアルタイム判定できない（閾値到達コールバックのみ）。連続判定ギャップ20分のため、開いて閉じた後にも累計閾値をまたいで通知が飛ぶ。開いているか確認できないまま通知を出すのは逆効果 → 機能ごと廃止。**deepFocus/nightOnly のシールド、Gate（回数上限）、その他の通知（朝/週次/月次/D1・D3・D7/トライアル/課金誘導）は残す。**

## 廃止範囲（footprint: grep 済み）
### 完全削除
- `ios/DopaBreak/UsageWatchController.swift`（クラスごと）
- `ios/DopaBreak/SettingsNotificationsView.swift` の「利用時間の通知」セクション（Free警告行・Pro間隔ピッカー・就寝前トグル・ペイウォール導線 `settings_usage_watch_gate`）。ファイルが利用時間専用ならファイルごと、他通知設定も含むなら該当セクションのみ
- `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/UsageWatchPolicy.swift`（UsageWatchConfiguration/State/Decision/Question/Constants/evaluate）
- `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/UsageWatchStore.swift`
- 対応テスト: `UsageWatchControllerTests.swift`／`UsageWatchPolicyTests.swift`／`UsageWatchStoreTests.swift`
- `ios/MonitorExtension/DeviceActivityMonitorExtension.swift`: `case UsageWatchConstants.activityName`（intervalDidStart 内・:50-54付近）と `eventDidReachThreshold` の UsageWatch 通知 post（`postNotification(for:)`・`notificationCopy(for:)`）を削除。**DeepFocus/Night/Gate の callback は残す**
- `PaywallView.swift:198` の `PaywallFeatureRow paywall.feature.usage_watch`（「使いすぎたら15分ごとに声かけ」）を削除。残るPro特典5件（unlimited_apps/deep_focus/night_block/full_history/lock_theme）は不変。ペイウォールの価値は5件で十分と判断
- xcstrings: `paywall.feature.usage_watch`、`settings.usage_watch.*`、`shortcuts`ではない利用時間系キー、UsageWatch通知本文キーを削除（他で参照されていないことを grep で確認してから）

### 配線の除去（クラス削除に伴う）
- `AppContainer.swift`: `UsageWatchController` の生成・保持・`entitlementDidChange(isPro:)`・`configurationDidChange`・`recordIntervention`・`stopAndClearAllData` 呼び出し・DeviceActivity `startMonitoring/stopMonitoring(UsageWatchConstants.activityName)` を除去
- `StoreService.swift`: `usageWatchStore.configuration.isPro` 更新（:174-177・:605-607付近）を除去
- `RootTabView.swift`: 利用時間関連の呼び出しがあれば除去
- `NotificationDelegate.swift` / `NotificationRouting.swift`: UsageWatch通知の識別子ルーティングを除去（他通知のルーティングは不変）
- `SettingsStore.swift`: UsageWatch専用の保存キー（questionInterval/nightMode/threshold等）を除去。**他機能と共有しているキー（bedTime/wakeTime等・夜だけ強化で使用）は残す**——共有判定を必ず確認
- `NightWindowPolicy.swift`: コメントの参照（:5）のみなら文言修正。ロジック依存があれば残す

### データ
- `UsageWatchStore` の永続ファイル（usage_watch関連JSON）は次回起動時に無害化（読まれなくなるだけ）。マイグレーション不要だが、`stopAndClearAllData` 相当のクリアを削除前に1度だけ走らせる必要はない（DeviceActivity監視はアプリ削除まで残るが、`startMonitoring` を呼ばなくなり `MonitorExtension` 側も該当activityを無視するため無害。既存ユーザーは居ないため移行不問）

## 不変（絶対に壊さない）
- deepFocus/nightOnly シールド、Gate回数上限、朝/週次/月次/D1・D3・D7/トライアル/課金誘導の各通知、ロック画面、統計

## 検証
- `cd ios/Packages/DopaBreakCore && swift test`（UsageWatch系テスト削除後、残り全合格・ビルド通る）
- `cd ios && xcodebuild test -project DopaBreak.xcodeproj -scheme DopaBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` TEST SUCCEEDED
- `grep -rn "UsageWatch" ios --include=*.swift | grep -v /build/` が**0件**（テスト・コメント含め残骸なし）
- `python3 scripts/lint-display-copy.py` / `python3 scripts/audit-default-values.py` exit 0
- ペイウォールをシミュレータ撮影し特典5行になっていることを確認（`output/verify/paywall-after-usagewatch-removal.png`）
- 報告: 削除ファイル一覧＋残置ファイルの変更点＋3行要約＋検証結果。差分本文は貼らない
- 注意: 実行時に `AppContainer.swift`/`SettingsView.swift`/`PaywallView.swift`/`HomeView.swift` に他作業の未コミット差分がある場合は、UsageWatch該当箇所のみ触り、無関係ハンクを整形・移動しない
