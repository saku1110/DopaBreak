# DopaBreak自身が一呼吸・完全ブロックの対象になる件の是正（2026-09-02）

オーナー報告: 「DopaBreakのアプリを開いた時にも一呼吸アニメーションやスクリーンタイムブロックが出る」
担当宣言: このバッチが触るのは下記の対象ファイルのみ。他セッションの未コミット差分には触れない（stash / checkout -- 禁止）。

---

## A. 自動化の起動要求が、ユーザー自身のDopaBreak起動で消費される

### 現象
アイコンからDopaBreakを開いただけで一呼吸が出る。対象アプリを触っていない場合も出る。

### 機構（コードで確定済み）
1. 一呼吸を終えると `InterventionFlowModel` がSNSのURLを開き、直前に `lastSelfOpenedCatalogID` / `lastSelfOpenedAt` を書く
2. SNSが開いたことでショートカット自動化が再発火し、`StartInterventionIntent.perform`（`ios/DopaBreak/StartInterventionIntent.swift:85-98`）が `pendingStartInterventionCatalogID` と `pendingStartInterventionRequestedAt` を書く
3. このときDopaBreakが前面に来ないと、その要求がApp Groupに残る
4. ユーザーが後でDopaBreakを開くと `handleAppActive`（`ios/DopaBreak/DopaBreakApp.swift:263` と `ios/DopaBreak/RootTabView.swift:414`）が残った要求を読む
5. `AutomationRequestPolicy.decision`（`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/AutomationRequestPolicy.swift`）は
   - 自己起動判定を `now - lastSelfOpenedAt < 8秒` で行うため、40秒後の起動では自己起動と判定されない
   - 鮮度判定が `now - requestedAt <= 60秒` と広いため通ってしまう
   → `.consume` になり一呼吸が出る

### 修正
`AutomationRequestPolicy.swift` の `decision` のみを変更する。呼び出し側のシグネチャは変えない。

1. **自己起動の判定基準を「消費時刻」から「要求が作られた時刻」へ変える**（本命）
   - 現行: `now.timeIntervalSince(lastSelfOpenedAt) < selfOpenSuppressionInterval`
   - 修正後: `requestedAt >= lastSelfOpenedAt` かつ `requestedAt.timeIntervalSince(lastSelfOpenedAt) < selfOpenSuppressionInterval`
   - 意図: 自分のURL起動の直後に生まれた要求は、ユーザーが何秒後にDopaBreakを開いても必ず捨てる。消費のタイミングに結果が依存しなくなる
   - `selfOpenSuppressionInterval = 8` は変えない
2. **鮮度 `freshnessInterval` を 60秒 → 10秒**
   - 根拠: `perform()` から `openAppWhenRun` の前面化までは実測で数秒。60秒はユーザー自身の起動を巻き込む幅として広すぎる
   - 判定順は現行どおり「stale を先に見る」を維持する
3. **一発限りのクリアは維持**（`AppModel` 側の `.discardSelfOpen` 後に `lastSelfOpened*` を消す既存処理は変更しない）

### 期待する挙動（これがテストの受け入れ条件）
| 状況 | requestedAt | lastSelfOpenedAt | 消費時刻 | 期待 |
|---|---|---|---|---|
| 自動化の正常起動 | T | なし/ずっと前 | T+1s | `.consume` |
| 自分のURL起動の反響 → 直後に前面化 | T1+0.5 | T1 | T1+1 | `.discardSelfOpen` |
| 自分のURL起動の反響 → 前面化せず後でユーザーが起動 | T1+0.5 | T1 | T1+40 | discard（stale か selfOpen のどちらでもよい。`.consume` は不可） |
| ユーザーがSNSを開き直した（自己起動から8秒超） | T1+30 | T1 | T1+31 | `.consume` |
| 古い要求 | T | なし | T+30s | `.discardStale` |

### テスト
`ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/AutomationRequestPolicyTests.swift` を更新する。
- 既存の「鮮度60秒の境界」を10秒の境界へ
- 既存の「自己起動8秒の境界」を requestedAt 基準の境界へ
- 上表5行をそのままケースとして足す
- `requestedAt < lastSelfOpenedAt`（自分のURL起動より前に生まれた要求）は自己起動扱いにしないこと

---

## B. 完全ブロックがDopaBreak自身を巻き込む

### 判明した制約（先に読むこと）
`ApplicationToken` は不透明で、**コードから「これは自分のアプリだ」と判別できない**。
- `Application(token:).bundleIdentifier` はピッカー由来のトークンでは nil
- `Application(bundleIdentifier:).token` は nil

したがって保存時に自分のトークンを除外するフィルタは実装しない。書いても常に何もしない関数になり、直ったように見えるだけで危険。**予防をUIで行う。**

巻き込みの経路は2つある。
- ユーザーがピッカーでDopaBreak自身を選ぶ
- ユーザーがカテゴリを選ぶ → `ShieldController.swift:169` の `applicationCategories = .specific(...)` でその分類のアプリが全部止まる。DopaBreakが同じ分類にあれば一緒に止まる（本人には見えない経路）

ブロック画面に解除口はない（`ios/ShieldActionExtension/ShieldActionExtension.swift` は全経路 `.close`）。窓が終わるまで開けない。

### B-1. ピッカー本体に注意書きを出す
`familyActivityPicker(headerText:footerText:isPresented:selection:)`（iOS 16+・本プロジェクトの deployment target は 17.0）へ差し替え、`footerText` に注意書きを渡す。
対象は2箇所。
- `ios/DopaBreak/SettingsView.swift:303`
- `ios/DopaBreak/OnboardingFlow.swift:396`

文言キー `block_picker.footer`（新規・3ロケール）。
- ja: `DopaBreak自身は選ばないでください。選んだ時間帯はDopaBreakを開けなくなります。カテゴリを選ぶと、その分類のアプリがすべて止まります。`
- en: `Don't select DopaBreak itself. If you do, you won't be able to open it during those hours. Selecting a category blocks every app in it.`
- ko: `DopaBreak는 고르지 마세요. 고르면 그 시간대에는 DopaBreak를 열 수 없습니다. 카테고리를 고르면 그 분류의 앱이 모두 멈춥니다.`

### B-2. カテゴリを含む選択は保存前に確認する
ピッカーを閉じた時点の選択に `categoryTokens` が1件でもあれば、保存の前に標準alertを出す。既存の確認alert（`OnboardingFlow.swift` の `showDeepFocusConfirmation`、`SettingsView.swift` のモード確定alert）と同じ組み方にする。

- 「このまま保存」→ 従来どおり `saveActivitySelection` / `saveBlockedAppSelection` を実行
- 「選び直す」→ 保存せずピッカーを開き直す。選択状態は保持する

対象は B-1 と同じ2箇所。カテゴリが0件のときはalertを出さず、従来どおり即保存する。

文言キー（新規・3ロケール）
- `block_picker.category_warning.title`
  - ja: `カテゴリはまとめて止まります`
  - en: `Categories block everything in them`
  - ko: `카테고리는 통째로 막힙니다`
- `block_picker.category_warning.message`
  - ja: `選んだ分類に入っているアプリがすべて止まります。DopaBreak自身が同じ分類にあると、その時間帯は開けなくなります。`
  - en: `Every app in the selected category will be blocked. If DopaBreak is in that category, you won't be able to open it during those hours.`
  - ko: `선택한 분류에 들어 있는 앱이 모두 막힙니다. DopaBreak가 같은 분류에 있으면 그 시간대에는 열 수 없습니다.`
- `block_picker.category_warning.save`
  - ja: `このまま保存` / en: `Save anyway` / ko: `이대로 저장`
- `block_picker.category_warning.reselect`
  - ja: `選び直す` / en: `Choose again` / ko: `다시 고르기`

---

## 守ること

- `ShieldController` のトークン適用ロジック、権利上限の数え方、ストア分割は変更しない
- `ShieldActionExtension` の `.close` は変更しない（解除口を作らない。ブロックの意味が消えるため）
- `saveBlockedAppSelection`（`ios/DopaBreak/AppContainer.swift:1207`）の保存内容・戻り値の契約は変更しない。呼び出す前にalertを挟むだけ
- `AutomationRequestPolicy` の呼び出し側シグネチャ、`AppModel` の一発クリア、検収マークの扱いは変更しない
- 文言は3ロケール（ja/en/ko）すべて `translated` で `ios/DopaBreak/Localizable.xcstrings` へ入れ、Swift側 `defaultValue` と一致させる
- 日本語の本文は一文の読点を2個までにする。見出し・ボタン文言に句読点を入れない
- 省略・TODO禁止。完全実装する

## 完了条件
- Core / アプリの全テストが失敗0
- lint 2本 exit 0
- `xcodegen` が必要な新規ファイルは無い想定（無ければ実行しない）

---

# レビュー後の修正（Opus5独立レビュー → Fable裁定・2026-09-03）

判定は accept with fixes（🔴なし）。下記5件を実装担当へ差し戻す。**既に入った実装の方針は変えない。**

## F1（🟡6・最優先）カテゴリ確認alertの提示をピッカーのdismissから切り離す
`ios/DopaBreak/SettingsView.swift:364-373` は、ピッカーのバインディングがfalseになった瞬間に `isBlockCategoryWarningPresented = true` を立てている。SwiftUIがこの提示を落とすと、フラグがtrueのまま残り、選択が保存されないうえ `isAnyChildModalPresented`（`:447-457`）が永久にtrueになって `presentAutomationGuideIfRequested` が死ぬ（D1/D3/D7通知からのガイド導線が二度と開かない）。

同ファイル `:334-338` に既にある `Task.sleep(for: .milliseconds(100))` の遅延パターンに合わせ、シートが閉じきってからalertを立てる。オンボーディング側も同じ形にそろえる。

## F2（🟡7）変更がないときはalertを出さない
`presentFamilyActivityPicker()`（`SettingsView.swift:2281-2284`）と `OnboardingFlow.swift:1655` は保存済みの選択をピッカーへ先読みする。そのため**すでにカテゴリを保存しているユーザーは、ピッカーを開いて何も変えずに閉じるだけで毎回警告を受ける**。しかも「選び直す」で開き直しても同じ警告に戻るため、「このまま保存」以外に抜け道がない。

保存済みの選択と比較し、**新しく増えたカテゴリが1件以上あるときだけ** alertを出す。カテゴリが減った・変わらない場合は従来どおり即保存する。設定・オンボーディングの両方。

## F3（🟡5）オンボーディング側のガードをそろえる
`OnboardingFlow.swift:398` のalert分岐には `selectedMode.usesShield` の検査がないが、`saveBlockedAppSelection()`（`:2599`）にはある。状態がずれると「このまま保存」が無言で何もしない。alert分岐にも同じガードを足す。

## F4（🟡3）ペイウォール分岐をalertより先に評価する
`saveActivitySelection`（`SettingsView.swift:2309-2313`）は上限超過のとき選択を巻き戻して return する。この判定はalertを出すかどうかを決める前に済ませる。いまはFreeがピッカーに到達できないため到達不能だが、権利条件が緩んだ瞬間に「保存されない選択に警告を出し、alertのアクションから `fullScreenCover` を出す」形になる。`shouldShowPaywallForSelectedTargets` を `onChange` 側へ引き上げる。

## F5（🟡10・Fable裁定）鮮度を10秒 → 20秒へ
レビュー指摘のとおり10秒は正規の経路を細くする。短すぎると「対象アプリを開いても一呼吸が出ない」という中核機能の失敗になり、長すぎる場合の実害（ユーザー自身の起動での誤発火）はF5より先に入れた**要求時刻基準の自己起動判定**がすでに捨てている。鮮度は二重の防御なので余裕を持たせる。

`AutomationRequestPolicy.freshnessInterval` を 20 にし、テストの境界値と関数名を20秒基準へ更新する。既存の「30秒経過は stale」ケースは20秒基準でも成立するため残す。**自己起動の判定（要求時刻基準・8秒）は変更しない。**

## 守ること
- `AutomationRequestPolicy.decision` の判定順、`.discardSelfOpen` 後の一発クリア、呼び出し側シグネチャは変更しない
- 文言は追加・変更しない（F1〜F4はいずれも提示条件の変更のみ）
- Core / アプリの全テスト失敗0、lint 2本 exit 0
