# リリース前修正バッチ（2026-09-04）

出典: Opus5独立レビュー3本（ロジック／課金経路／リファクタ）。実装はCodex、受け入れはFable。

## 前提（触ってはいけないもの）
- `EntitlementResolutionPolicy` / `applyEntitlement` の fail-open 設計は**正しい**。取得失敗でPro維持・キャッシュ非上書きは変更しない
- `hasConfirmedEntitlement` を使った fail-closed 判定のうち、**ペイウォール表示・割引表示・クランプ**（`RootTabView:571` / `QuickActions:74` / `TargetClampPolicy`）は正しい。変更しない
- `ShieldController` のトークン適用・権利上限、`ShieldActionExtension` の `.close` は変更しない

---

## 修正1（最優先）: 夜だけ強化・Deep Focus の「UIは有効・実体は未武装」を可視化する

### 現象
UI解放は `isPro`（キャッシュ可・fail-open）、強制は `hasConfirmedEntitlement`（fail-closed）で判定が割れている。
StoreKit未到達だと設定画面は「残りXX分 ・ いま解除する」を出しながら、シールドもDeviceActivity窓も一切登録されない。無言で失敗する。

### 方針（**解放条件は変えない**）
権利判定は現状維持する（キャッシュProのユーザーを締め出さない意図は正しい）。**失敗を黙らせないことだけ**を直す。

1. `NightShieldScheduler.didLastRebuildFail` / `DeepFocusScheduler.didLastRebuildFail` は既に存在する。
   `hasConfirmedEntitlement == false` で早期returnした場合も、この2つが**未武装を表す状態**として真になるようにする
   （既存の失敗理由と区別が要るなら `lastRebuildOutcome` のような列挙へ広げてよい。命名は実装側の判断に任せる）
2. `AppModel` にその状態を公開し、**設定画面の夜だけ強化セクションとDeep Focusセッション行**に注意行を出す。
   文言は既存の語彙に合わせる（内部用語禁止・「介入」「シールド」等は使わない）
3. 文言（ja/en/ko の3ロケールを `Localizable.xcstrings` に追加。キー名は既存の `settings.*` 系に揃える）
   - ja: `いま端末がApp Storeに接続できないため 実際のブロックが始まっていません`
   - en: `This is not blocking anything yet because the device cannot reach the App Store.`
   - ko: `지금 기기가 App Store에 연결되지 않아 실제 차단이 시작되지 않았습니다`
   - **表示コピー規則**: 日本語はリズム目的の読点を入れない（区切りは半角スペース）。句点も打たない
4. 接続が回復して `syncShield()` が成功したら注意行は自動で消えること

### 受け入れ条件
- オフライン（StoreKit未到達）でキャッシュProのまま夜だけ強化をONにすると、注意行が出る
- 同条件でDeep Focusを開始すると、残り時間表示と一緒に注意行が出る
- 権利が解決してシールドが張れたら注意行が消える
- 既存の解放条件・クランプ・ペイウォール表示は**一切変わらない**（既存テストが全部通ること）

---

## 修正2: 廃止したゲートのDeviceActivity監視が止まらない

`GateGrantController` 削除で `dopabreak.gate.reshield.<uuid>` を `stopMonitoring` する経路が消えた。
`ManagedSettingsStore` 側（`ShieldController.swift:58`）の掃除だけ残り、`DeviceActivityCenter` 側が残留する。
旧ビルドから上げた端末で監視枠を食い続け、`MonitorExtension` を無駄に起こす。

### 方針
`ShieldController` の既存マイグレーション地点で、`DeviceActivityCenter().activities` を走査し
`dopabreak.gate` プレフィックスのアクティビティを `stopMonitoring` する。1回で足りるが冪等に書く。
`MonitorExtension` 側は `default: return` のままでよい。

---

## 修正3: 振り返りが30分〜3時間の間だけ届かない

`InterventionEngine.reflectionNotificationTapWindow = 3h` は事実上デッドコード。
`RootTabView.swift:554-560` が3時間で期限切れ判定した後、`pendingReflection()` を**既定30分**で引くため、
`PendingNotificationDestination.validityInterval = 30分`（`AppModels.swift:567`）で先に弾かれる。
宣言時間の終了から30分以上たって戻ったユーザーは振り返りを一度も見ずに `skip` 記録される。

### 方針
通知タップ由来の着地は3時間まで有効にする。
- `PendingNotificationDestination.validityInterval` を通知種別で分ける、または振り返り宛先だけ3時間を使う
- `presentReflectionFromNotification` が実際に3時間窓で引けるようにする
- 通知タップ**以外**（アプリを自分で開いた場合）の既定30分は変えない

### 受け入れ条件
- 宣言時間終了から2時間後に通知をタップ → 振り返りが出る
- 3時間を超えていれば出ない（従来どおり期限切れ）
- 自分でアプリを開いた場合の挙動は変わらない

---

## 共通の実装規律
- 省略・TODO禁止。3ロケール（ja/en/ko）の文言は `Localizable.xcstrings` と Swift の defaultValue を一致させる
- 既存テストを壊さない。修正1と修正3には回帰テストを追加する
- `scripts/lint-display-copy.py` と `scripts/audit-default-values.py` が exit 0 のままであること
