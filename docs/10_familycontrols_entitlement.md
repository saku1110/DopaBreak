# FamilyControls Distribution Entitlement 申請パッケージ

作成: 2026-07-02 / 対象: **DopaBreak**（Phase 2 最優先・死活項目）

> **✅ 2026-07-08 完了**: entitlement承認済み（2026-07-03・アカウント単位）＋ App Group／5 App ID登録＋4 App IDのCapability有効化まで全て完了。**FamilyControls関連のポータル作業は全て終了**。TestFlight配布・App Store提出のブロッカーは完全に解消。
>
> ~~**なぜ最優先か**: `com.apple.developer.family-controls`（Distribution）はApple申請制で、承認まで**1日〜4.5週間**のばらつきがある（2026年時点のDeveloper Forums報告）。承認されるまで**TestFlight配布・App Store提出ができない**。開発自体はDevelopment entitlementで進められるため、**申請だけ先に投げて実装と並行**させる。~~ ← 旧プロセスの前提。実際はTeam単位・即日承認だった

---

## 0. 確定した識別子（2026-07-02・実装と共通）

| 用途 | 識別子 | FamilyControls entitlement |
| --- | --- | --- |
| 本体アプリ | `com.dopabreak.app` | **要申請** |
| ShieldConfiguration拡張 | `com.dopabreak.app.shieldconfig` | **要申請** |
| ShieldAction拡張 | `com.dopabreak.app.shieldaction` | **要申請** |
| DeviceActivityMonitor拡張 | `com.dopabreak.app.monitor` | **要申請** |
| Widget/Live Activity拡張 | `com.dopabreak.app.widgets` | 不要 |
| App Group | `group.com.dopabreak.shared` | —（全ターゲットに付与） |

- 接頭辞 `com.dopabreak` はドメイン非依存の逆DNS（ドメイン取得見送りのため）。**App ID登録時に万一衝突したら接頭辞のみ変更**（`ios/Configs/Shared.xcconfig` の1行）。リリース後は変更不可なので提出前に確定させる。
- Forums報告（2026年）: **拡張（Shield等）も本体と別に承認が必要**。本体だけ申請して拡張を忘れると配布ビルドが弾かれる → **4件申請する**。

## 1. オーナー実行手順（人間作業・合計15分＋承認待ち）

前提: Apple Developer Program加入済み。申請フォームは**Account Holder**のみ送信可（個人アカウントなら本人）。

### Step 1 — App ID / App Group登録（5分）
[developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers/list) で:
1. App Groups → `group.com.dopabreak.shared` を登録
2. App IDs → 上表の5つのBundle IDを「App」タイプで登録（Capabilitiesは後で有効化するので最低限でOK。App Groupsだけチェックして紐付けると後が楽）

### Step 2 — 申請フォーム送信（10分・**4回**）
フォーム: **[developer.apple.com/contact/request/family-controls-distribution](https://developer.apple.com/contact/request/family-controls-distribution)**

Bundle IDごとに1回、計4回送信（`com.dopabreak.app` / `.shieldconfig` / `.shieldaction` / `.monitor`）。説明欄は下の英文をそのまま貼り付け（拡張は末尾1文を差し替え）。

### Step 3 — 承認後（メール到着後・10分）
1. Identifiers で各App IDの **Family Controls (Distribution)** capabilityを有効化
2. Xcode自動署名なら provisioning profile は自動再生成。手動なら再生成
3. 承認が来ない場合: 確認番号が発行されない事例が多数報告されている。**2週間音沙汰なしなら同フォームから再送信**（Forums定番の対処）

### 承認待ちの間（開発はブロックされない）
- Xcodeの **Family Controls (Development)** capabilityは申請不要・即使用可 → **実機での開発・技術検証6項目はすべて進められる**
- FamilyControls/Shieldは**シミュレータでは動作しない（実機必須）**
- ブロックされるのはTestFlight配布とApp Store提出のみ

## 2. 申請フォーム貼り付け英文

**共通（本体 `com.dopabreak.app` 用）:**

```text
DopaBreak is a screen-time self-management app for adults who want to
reduce compulsive social media use. It is NOT a parental-control app:
the user manages their own device via individual authorization
(AuthorizationCenter, .individual).

How the app uses the Family Controls entitlement:
1. FamilyActivityPicker lets the user privately choose which apps they
   want to limit (app tokens never leave the device).
2. ManagedSettings + ShieldConfiguration display a custom shield when
   the user tries to open a selected app, encouraging a short pause and
   an intention check instead of a hard block.
3. The user can open the app for a self-chosen duration; DeviceActivity
   schedules re-shielding when that time ends, followed by a brief
   post-use reflection inside DopaBreak.
All usage data stays on device. We request the distribution entitlement
for this bundle ID to ship these features via TestFlight and the App
Store.
```

**拡張用の差し替え文（最終段落をこれに置換）:**

| Bundle ID | 末尾段落 |
| --- | --- |
| `com.dopabreak.app.shieldconfig` | `This bundle ID is the ShieldConfiguration extension of com.dopabreak.app. It renders the custom shield UI and therefore requires the same Family Controls distribution entitlement.` |
| `com.dopabreak.app.shieldaction` | `This bundle ID is the ShieldAction extension of com.dopabreak.app. It handles the shield buttons ("Don't open" / "Open with intention") and therefore requires the same Family Controls distribution entitlement.` |
| `com.dopabreak.app.monitor` | `This bundle ID is the DeviceActivityMonitor extension of com.dopabreak.app. It schedules shielding windows and re-applies the shield when the user-chosen time ends, and therefore requires the same Family Controls distribution entitlement.` |

### コピペ用・拡張3件の全文（差し替え済み）

**`com.dopabreak.app.shieldconfig` 用:**

```text
DopaBreak is a screen-time self-management app for adults who want to
reduce compulsive social media use. It is NOT a parental-control app:
the user manages their own device via individual authorization
(AuthorizationCenter, .individual).

How the app uses the Family Controls entitlement:
1. FamilyActivityPicker lets the user privately choose which apps they
   want to limit (app tokens never leave the device).
2. ManagedSettings + ShieldConfiguration display a custom shield when
   the user tries to open a selected app, encouraging a short pause and
   an intention check instead of a hard block.
3. The user can open the app for a self-chosen duration; DeviceActivity
   schedules re-shielding when that time ends, followed by a brief
   post-use reflection inside DopaBreak.
This bundle ID is the ShieldConfiguration extension of
com.dopabreak.app. It renders the custom shield UI and therefore
requires the same Family Controls distribution entitlement.
```

**`com.dopabreak.app.shieldaction` 用:**

```text
DopaBreak is a screen-time self-management app for adults who want to
reduce compulsive social media use. It is NOT a parental-control app:
the user manages their own device via individual authorization
(AuthorizationCenter, .individual).

How the app uses the Family Controls entitlement:
1. FamilyActivityPicker lets the user privately choose which apps they
   want to limit (app tokens never leave the device).
2. ManagedSettings + ShieldConfiguration display a custom shield when
   the user tries to open a selected app, encouraging a short pause and
   an intention check instead of a hard block.
3. The user can open the app for a self-chosen duration; DeviceActivity
   schedules re-shielding when that time ends, followed by a brief
   post-use reflection inside DopaBreak.
This bundle ID is the ShieldAction extension of com.dopabreak.app. It
handles the shield buttons ("Don't open" / "Open with intention") and
therefore requires the same Family Controls distribution entitlement.
```

**`com.dopabreak.app.monitor` 用:**

```text
DopaBreak is a screen-time self-management app for adults who want to
reduce compulsive social media use. It is NOT a parental-control app:
the user manages their own device via individual authorization
(AuthorizationCenter, .individual).

How the app uses the Family Controls entitlement:
1. FamilyActivityPicker lets the user privately choose which apps they
   want to limit (app tokens never leave the device).
2. ManagedSettings + ShieldConfiguration display a custom shield when
   the user tries to open a selected app, encouraging a short pause and
   an intention check instead of a hard block.
3. The user can open the app for a self-chosen duration; DeviceActivity
   schedules re-shielding when that time ends, followed by a brief
   post-use reflection inside DopaBreak.
This bundle ID is the DeviceActivityMonitor extension of
com.dopabreak.app. It schedules shielding windows and re-applies the
shield when the user-chosen time ends, and therefore requires the same
Family Controls distribution entitlement.
```

**申請文の原則**（リジェクトされにくくする）:
- 「本人の自己管理（individual）」と明言し、ペアレンタルコントロールを装わない
- 使用するAPI（FamilyActivityPicker / ManagedSettings / DeviceActivity）と対応機能を1:1で書く
- オンデバイス保存・トークン非送信を明記（プライバシー審査観点）
- 医療・治療・依存症の治癒は書かない（App Review表現規範 → docs/09 §2）

## 3. ステータス管理

| 項目 | 状態 | 日付 |
| --- | --- | --- |
| 申請フォーム送信 | ✅ 送信済み（新形式・Team単位） | 2026-07-03 |
| 承認メール | ✅ **承認済み（即日・アカウント単位）** | 2026-07-03 |
| App ID / App Group登録 | ✅ **完了**（App Group＋5 App ID） | 2026-07-08 |
| Capability有効化（4 App ID） | ✅ **完了**（Family Controls Distribution＋App Groups） | 2026-07-08 |

**✅ 2026-07-03 解決: フォーム・承認プロセスは2026年に変更されていた**
- フォームは Name / Email / Team ID の自動入力のみ（Bundle ID・利用目的欄なし）
- 承認は**アカウント（Team）単位**で付与される方式に変更: 「The entitlement for Family Controls (Distribution) has been assigned to your account, and you can now configure this capability for eligible apps.」（承認メール原文）
- **本ドキュメント作成時の前提（Bundle IDごとに4件申請・1日〜4.5週間待ち）は旧プロセス。追加申請は不要**
- §2の申請英文は使わずに済んだが、App Review審査時のメモ（Review Notes）に転用できるので残す

**残作業: なし（2026-07-08 全完了）**
- ~~Step 1: App Group + 5つのApp IDを登録~~ → ✅ 完了
- ~~各App ID（`.app` / `.shieldconfig` / `.shieldaction` / `.monitor` の4つ）で **Family Controls (Distribution)** capabilityを有効化~~ → ✅ 完了（＋App Groups も付与）
- Xcode自動署名なら provisioning profile は次回ビルド時に自動再生成される

## 出典（2026-07-02 WebSearch確認）
- [Requesting the Family Controls entitlement — Apple Developer Documentation](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement)
- [申請フォーム](https://developer.apple.com/contact/request/family-controls-distribution)
- [3+ weeks of waiting for Family Controls entitlement — Developer Forums](https://developer.apple.com/forums/thread/725036)（承認リードタイムの実例）
- [Family Controls Distribution Entitlement — Developer Forums](https://developer.apple.com/forums/thread/812332)（拡張の個別承認・未応答時の再送信）
