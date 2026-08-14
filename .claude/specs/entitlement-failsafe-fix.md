# 課金フェイルセーフ修正 設計契約（2026-08-14・Fable設計・オーナー承認「全部修正しろ」）

2026-08-14監査（.claude/tasks/current.md 冒頭セクション）のP0-A①〜④＋P1を修正する。
実装は2ワークストリーム並列。**担当外ファイルへの変更は禁止**（コンフリクト防止）。

## ワークストリーム分担

| WS | 担当 | 所有ファイル |
|---|---|---|
| A | Codex (gpt-5.6-sol) | `ios/DopaBreak/StoreService.swift` / `ios/DopaBreak/DopaBreak.storekit` / `ios/DopaBreak/SettingsView.swift`（指定2点のみ）/ Core新規 `EntitlementResolutionPolicy.swift`＋テスト / Core `SettingsStore.swift`（キャッシュ用キー追加のみ） |
| B | Opus5 (worktree) | `ios/DopaBreak/AppContainer.swift` / `ios/DopaBreak/RootTabView.swift` / `ios/DopaBreak/PaywallView.swift` / Core `RuleStore.swift` / 対応テスト |

## インターフェース契約（両WSが依存する共通仕様）

`StoreService` に以下を追加する（実装はWS-A。WS-Bは存在を前提にしてよい）:

```swift
/// StoreKitへの到達が裏付けられた状態でentitlementを解決できたか。
/// true になる条件: currentEntitlements が非空、または
/// 空だった場合に Product.products(for: ProProductID.allIDs) が成功（＝ネットワーク到達の傍証）。
/// 取得空振り＋products失敗のときは false のまま（前回状態を維持する）。
private(set) var hasConfirmedEntitlement: Bool = false
```

- `hasResolvedEntitlement` は「1度でも解決試行を完了した」の意味で存続（ローディングUI用）。
- **破壊的・ユーザー可視の「Free確定」判断はすべて `hasConfirmedEntitlement && !isPro` に置き換える**（WS-B担当箇所）。

## WS-A: StoreService中核（Codex）

1. **キャッシュ永続化＋シード**: App Group UserDefaults（`SettingsStore`にキー追加: `entitlementCachedIsPro: Bool?` / `entitlementCachedAt: Date?`）。
   - `refreshEntitlement()` が confirmed で完走するたび書き込み。
   - `StoreService.init` で `isPro` の初期値をキャッシュから復元（キャッシュProなら起動直後からPro表示。監査P1「起動直後の一瞬Free」の解消手段）。
2. **取得失敗＝無料の禁止**: entitlements走査が空のとき `try await Product.products(for: ProProductID.allIDs)` で到達性を確認。
   - 成功→Free確定（isPro=false・キャッシュ更新・hasConfirmedEntitlement=true）。
   - throw→**前回の isPro を据え置き**。UsageWatch App Group への `isPro=false` 書き込みもしない。hasConfirmedEntitlement=false のまま。hasResolvedEntitlement=true は立ててよい。
   - 判定ロジックは純関数としてCore `EntitlementResolutionPolicy` に切り出しテスト（空+到達→free確定 / 空+不達→据え置き / 非空→pro確定 の3系統以上）。
3. **Grace Period即ロック解消**: `StoreService.swift:220-222` の手動 `expirationDate <= now` フィルタを**削除**。currentEntitlements の判断に委ねる（revocationDateチェックは維持可）。
4. **再入直列化**: `refreshEntitlement()` を単一実行に直列化（実行中Taskを保持し後続はawait合流）。加えて世代番号で「古い実行が新しい結果を上書きしない」ことを保証。
5. **unverified後始末**: purchase/listener双方で `.unverified` 時も `transaction.finish()` は行わず権利付与もしないが、**アラートと `onPurchaseOrRestoreFailure` の発火はproductIDごとに起動中1回に抑制**（毎起動の無限アラートループ防止）。unverifiedのerrorをログに残す。
6. **restore() catch時**: `AppStore.sync()` が throw しても `refreshEntitlement()` を1回実行してから戻る。
7. **SettingsView（2点のみ）**: ①paywall用 `.fullScreenCover(item: $paywallPlacement)` に `onDismiss: { refreshSettingsState() }` を追加 ②`setRuleEnabled` 系のdeepFocus→standard永続降格を `hasConfirmedEntitlement` ガード付きに（未確定中は書き込まない）。
8. **DopaBreak.storekit**: サブスクgroupNumberの逆転是正（annual系が月額より上位ランク＝小さいlevelになるよう並べ替え。annual=1, annual.launch=2, monthly=3）。ASC側の実ランクはオーナー確認事項として残す。

## WS-B: クランプ・UI・RuleStore（Opus5）

1. **クランプ厳格化**: `AppContainer.clampSelectedTargetsToEntitlementLimit()`（714-761）のガードを `storeService.hasConfirmedEntitlement` に変更（worktreeでは `hasResolvedEntitlement` しか無いため、**一時的に自前でStoreServiceにスタブprop追加してコンパイル**し、最終diffからStoreService.swiftを除外すること）。
2. **クランプのバックアップ＋自動復元**: クランプ実行前に元の選択IDリストを `SettingsStore` 経由で永続退避（新キー `preClampTargetCatalogIDs: [String]?`。キー追加はWS-AのSettingsStore変更と衝突しないようWS-B側はUserDefaults直書きではなくSettingsStoreのextensionまたは自前ストア追加ではなく——**衝突回避のためWS-BのキーはAppContainer内でSettingsStoreの汎用APIが無ければ新規Core小ファイル `TargetClampBackupStore.swift` を作って管理**）。isProがconfirmedでtrueへ復帰したとき退避があれば復元しクリア。ユーザーが手動で対象アプリを変更したら退避をクリア（既存の `targetAppClampKeptCatalogID` クリア箇所と同じ場所）。
3. **Free確定依存の出し分け**: `AppContainer.swift:765/824/843`（無料向け通知予約）と `RootTabView.swift:319`（週次ペイウォール自動提示）の `hasResolvedEntitlement && !isPro` を `hasConfirmedEntitlement && !isPro` へ。
4. **ペイウォール自動クローズ**: `PaywallView` に `.onChange(of: storeService.isPro)` → true で `dismiss()`。purchase戻り値依存を解消。
5. **RuleStoreモード上書きバグ**: `RuleStore.catalogTargetRule(for:mode:)` が既存ルール一致時に `rule.mode = mode`（既定 `.standard`）で上書きする問題を修正。**既存ルールがある場合は保存済みmodeを保持**し、明示的にモード変更したい呼び出し（OnboardingFlowのchooseMode等）は別メソッドまたは明示パラメータで行う。呼び出し元3箇所（`AppContainer.swift:625,645` / `InterventionFlowModel.swift:168`）の意図を確認して整合させる。回帰テスト必須（deepFocus設定済みルールが介入フロー経由で standard に落ちないこと）。
6. **回帰テスト**: ①未confirmed時にクランプが発火しない ②クランプ→Pro復帰で選択が復元される ③RuleStoreモード保持。

## 共通規律

- コミット禁止（Fableが最終検証後に扱う）。TODO/省略禁止。既存コードのスタイルに合わせる。
- 変更ファイル一覧と要約を報告して終了。
- テスト: Core `swift test` 0失敗、可能ならアプリターゲットビルド確認。
