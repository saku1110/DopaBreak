# スクリーンタイム有効時は自動化ルートを止める（案A）＋ シールド文言の是正 — 設計（2026-09-01）

オーナー決定（2026-09-01）:「A。ただスクリーンタイムの時間制御外の時は普通の一呼吸」
併せて:「砂時計の画面はひと呼吸と書くべきじゃない」

---

## 症状と原因（実測）

オーナー実機で、DopaBreak内で時間を選んで開こうとすると、SNSがスクリーンタイムのシールドで完全にブロックされる。

**決め手**: シールドの副題が「今日 1回目」だった。これは `GatePolicy` の `canUnlock(opensToday:)` が
`opensToday == 0` を返している状態を指す。ゲート経由で一呼吸して開いていれば `recordOpen` が走って
「今日 2回目」になる。つまりオーナーが通った一呼吸は**ゲート経由ではなくショートカット自動化（catalog）ルート**だった。

`InterventionFlowModel.openCatalogTarget(_:for:)` は `UIApplication.shared.open(urlScheme)` を叩くだけで、
**ManagedSettings のシールドを一切解除しない**。そのためSNSが起動した瞬間にゲートが再びブロックする。
一呼吸が二重にかかっている。

**解除できない理由（プラットフォーム制約）**: FamilyControls の `ApplicationToken` は不透明で、
アプリ側は「このトークンがどのアプリか」を知れない。catalogID から対応するトークンを引く手段が存在しない。
したがって「自動化ルートで一呼吸したのでゲートも開ける」は実装不可能。**片方を止めるしかない。**

---

## 方針（案A）

**スクリーンタイムのゲート対象が設定されているときは、自動化（catalog）ルートの介入を走らせない。**
シールドを唯一の入口にする。ゲート未設定のとき（＝スクリーンタイムがアプリを制御していないとき）は
従来どおり普通の一呼吸を出す。

### 1. ゲートが有効かの判定を1箇所に置く

`ios/DopaBreak/AppContainer.swift`（`AppModel`）に読み取り専用の判定を追加する。

```swift
/// スクリーンタイムのゲート対象が設定されているか。
/// 設定されているなら、そのアプリの入口はシールドであり、自動化ルートの一呼吸は二重になる。
var isScreenTimeGateConfigured: Bool
```

判定材料は既存の `gateAppSettingsStore` / `GateShieldController` が持つ選択内容。
**新しい永続状態は作らない。** 既存の保存済み選択が空でなく、かつスクリーンタイムの認可が下りていることを見る。
判定ロジックはCore側の純関数として切り出し、テストできる形にすること。

### 2. catalogルートの介入を抑止する

`ios/DopaBreak/RootTabView.swift` の `presentPendingInterventionIfValid(_:)` で、
target が `.catalog` かつ `model.isScreenTimeGateConfigured == true` のときは**提示せずに要求を捨てる**。

```
case .catalog:
    guard !model.isScreenTimeGateConfigured else {
        model.pendingInterventionTarget = nil
        return
    }
```

- `.gateToken` ルートは**一切変更しない**。シールド経由の一呼吸は従来どおり動く
- 捨てた要求で記録（attempt/open）を増やさない。ユーザーが実際に開こうとした事実はシールド側が数える
- 画面は出さない。DopaBreakは開いたままの状態で留まる

### 3. 自動化の案内を出し分ける

`ios/DopaBreak/AutomationGuideView.swift` と、設定・オンボーディングから自動化案内へ行く導線で、
`isScreenTimeGateConfigured == true` のときは**ショートカット自動化の手順を出さない**。
代わりに、スクリーンタイムが入口になっている旨と、**登録済みの自動化は削除してよい**ことを伝える1画面にする。

文言は新規に足さず、既存の語彙（「一呼吸」「対象アプリ」「開く前に」）の範囲で書く。
内部用語（介入・シールド・ゲート・トークン）は使わない。

### 4. シールドの文言（`canUnlock` のときだけ）

`ios/ShieldConfigExtension/ShieldConfigurationExtension.swift` の `.canUnlock` 分岐。
アプリ内の一呼吸画面と同じ言葉を使うと、まだ一呼吸していないのに済んだように見える。

| 現在 | 変更後 |
|---|---|
| 見出し `shield.gate.title` = 開く前にひと呼吸 | **このアプリは止めています** |
| 主ボタン `shield.gate.action.breathe` = 一呼吸して開く | **DopaBreakで開く** |
| 副ボタン `shield.gate.action.cancel` = 開かない | 開かない（変更なし） |

- 副題（今日 N回目 / N/M回）は変更しない
- `.alreadyOpen` 分岐も同じ `shield.gate.title` を参照しているので、同時に新しい見出しになる。これは意図どおり
- `ios/ShieldConfigExtension/Localizable.xcstrings` の ja / en / ko を3言語とも更新する。
  未翻訳stateを残さない。en/ko は日本語の意味に合わせて自然な表現にする（直訳しない）
- 表示コピーの規則を守る: 句点を打たない、リズム目的の読点を入れない、体言止めを基本にする

### 5. テスト

- ゲート設定あり + `.catalog` target → 介入が提示されず、要求が破棄されること
- ゲート設定あり + `.gateToken` target → 従来どおり提示されること
- ゲート設定なし + `.catalog` target → 従来どおり提示されること
- `isScreenTimeGateConfigured` の判定純関数の単体テスト（選択が空 / 非空 / 認可なし）
- シールド文言のキーが3言語とも `translated` であること

---

## 受け入れ条件
- スクリーンタイムでアプリを選んでいる状態で対象SNSを開く → シールドが出る → そこから一呼吸して開ける。
  **DopaBreak内で時間を選んだ後にシールドで止まる二重ブロックが起きない**
- スクリーンタイムを使っていない（ゲート未設定）ユーザーの体験は一切変わらない
- シールドに「ひと呼吸」の語が出ない

## 共通ルール
- 省略・TODO・死んだコード禁止
- **シミュレータのアプリを起動・終了しない**
- 担当外に触らない: `WinScreenView.swift` / `ReclaimedTimePresentation.swift` / `WakeSleepTimelinePolicy.swift` / `SettingsView.swift`
- `Localizable.xcstrings`（DopaBreak本体）を触る場合は最小限に留める
