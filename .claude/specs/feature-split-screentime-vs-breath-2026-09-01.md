# 機能別に分ける: 時間制御=スクリーンタイム / ひと呼吸=ショートカット — 設計（2026-09-01）

オーナー決定（2026-09-01）:
> いやそもそも機能別に変える。
> 夜だけとディープフォーカスの時間制御にはスクリーンタイムを使いその時間外はひと呼吸ショートカットを使う。
> 完全にブロックするアプリと一呼吸をはさむアプリは明確に分ける

---

## 背景（なぜこうするか）

スクリーンタイムでアプリの起動を捕まえる唯一の手段はシールドで、シールドはiOSが描く。
その結果:
- 対象アプリのアイコンが**常にグレー＋砂時計**になる
- SNSを押すと**iOSのシールドが先に出る**。DopaBreakの一呼吸アニメーションは最初に出せない

一呼吸アニメーションはこのプロダクトの核なので、常時シールドとは両立しない（オーナー指摘）。
一方、完全ブロックはショートカットでは実現できない。**用途で仕組みを分ける。**

## 到達したい状態

| 機能 | 仕組み | 対象リスト | アイコン |
|---|---|---|---|
| ひと呼吸（標準） | ショートカット自動化 → アプリ内の一呼吸アニメーション | **一呼吸をはさむアプリ** | 通常 |
| 夜だけ強化 | スクリーンタイム（時間窓のみ） | **完全にブロックするアプリ** | 窓の中だけ砂時計 |
| ディープフォーカス | スクリーンタイム（時間窓のみ） | **完全にブロックするアプリ** | 窓の中だけ砂時計 |

**窓の外ではスクリーンタイムのシールドを一切張らない。**

---

## 1. 常時ゲートの廃止

現在 `GateShieldController` が、選択済みアプリへ**24時間シールド**を張っている。
`.canUnlock`（開く前にひと呼吸→シールド経由で解除）の仕組み一式が該当する。

- 常時シールドの適用をやめる
- それに伴って**到達不能になるコードを残さない**。`GateShieldController` / `GateGrantController` /
  ゲート解除要求 / `ShieldActionExtension` のゲート経路 / `GateShieldState.canUnlock` など、
  参照されなくなったものは削除する。時間窓のシールド（`ShieldController` の
  `deepFocusManagedSettingsStore` / `nightManagedSettingsStore`）は**残す**
- 削除範囲は実際の参照を辿って決めること。**動いている時間窓の経路を巻き込まない**
- 先行して入れた `GateShieldScope`、`ScreenTimeSingleEntryPolicy`、
  `AppModel.isScreenTimeGateConfigured`、catalog抑止、抑止時の自動化案内も、
  常時ゲートが無くなれば不要になる。**同様に到達不能なら削除する**

## 2. 対象アプリを2つのリストに分ける

物理的には既に2系統ある。**画面の上で用途を明示して分ける。**

| リスト | 保存先 | 用途 |
|---|---|---|
| 一呼吸をはさむアプリ | `intervention_targets.json`（`targetStore.selectedCatalogIDs()`・カタログID） | ショートカット自動化の対象 |
| 完全にブロックするアプリ | ルールの `activitySelectionData`（FamilyControlsトークン） | 夜だけ強化・ディープフォーカスの対象 |

- 設定画面で**別々のセクション**にし、見出しでどちらが何に効くかを言い切る
- それぞれのセクションに、その機能が動くために何が要るかを書く
  （ひと呼吸=ショートカット設定 / 止める=スクリーンタイム許可）
- **片方にしか入っていないアプリがあることは正常**。エラー扱いにしない
- 用語は既存の語彙に揃える。内部用語（ゲート・トークン・シールド）を出さない

## 3. モードの意味を整理する

`TargetRule.mode` は現在 `standard` / `nightOnly` / `deepFocus`。

- `standard` は**スクリーンタイムを使わない**。ひと呼吸だけ。ルールにトークンがあっても常時シールドは張らない
- `nightOnly` / `deepFocus` は**時間窓の中だけ**シールドを張る（既存 `ShieldController.applyShield` の挙動を維持）

## 4. 移行（既存ユーザー）

既存ユーザーには「standardモード + スクリーンタイム選択あり」の状態が存在する。
この変更でそのアプリは**常時シールドが外れる**。

- スクリーンタイムの選択そのものは**消さない**。夜だけ強化・ディープフォーカスの対象として引き続き使う
- 常時シールドが外れることでアイコンのグレーアウトが解消される。これは意図した結果
- 既に張られている常時シールドは、**修正後の初回同期で必ず解除されること**（張りっぱなしを残さない）
- ひと呼吸を入れるアプリが未選択のユーザーは、標準モードで一呼吸が出なくなる。
  設定画面でそれが分かるようにする（未選択なら、その旨と選ぶ導線を出す）

## 5. 受け入れ条件

- 標準モードで対象SNSを開く → **アイコンは通常のまま**、DopaBreakの一呼吸アニメーションが出る
- 夜だけ強化 → **窓の中だけ**シールド。窓の外はアイコン通常でひと呼吸が動く
- ディープフォーカス → 同上
- 完全ブロック中の画面に、ひと呼吸の文言も目標も出ない（実装済み・維持すること）
- 既存の常時シールドが初回同期で解除される
- 到達不能なコードが残っていない

## 共通ルール
- 省略・TODO・死んだコード禁止
- **シミュレータのアプリを起動・終了しない**
- 担当外に触らない: `WinScreenView.swift` / `ReclaimedTimePresentation.swift` / `WakeSleepTimelinePolicy.swift`
- `SettingsView.swift` は2の対象になるため触ってよい。ただし起床・就寝タイムライン周り（別セッションが今日変更した箇所）は壊さない
- 表示コピー規則: 句点を打たない、リズム目的の読点を入れない、体言止めを基本にする

---

## 【2026-09-01 追記・オーナー決定で確定】

> 案X プロ機能として時間帯で自動的に夜や毎週ブロックを入れたい

### 確定事項

1. **案X を採用**: 対象アプリは2リストに分ける。**同じアプリを両方に入れられる**
   - 「夜は完全ブロック、日中は一呼吸」を成立させる。ここが案Xを選んだ理由なので、両方登録を必ず可能にする
2. **常時ゲートは削除**（既定オフで残す案は不採用）。Proの価値は「時間帯の自動ブロック」へ移る
3. **毎週ブロック（曜日＋時間帯）は次段の別作業**。本設計には含めない

### 2リストの仕様

| リスト | 保存先 | 効くもの | 必要なもの |
|---|---|---|---|
| 一呼吸をはさむアプリ | `intervention_targets.json`（カタログID） | ショートカット自動化の一呼吸 | ショートカット設定 |
| 完全にブロックするアプリ | ルールの `activitySelectionData`（FamilyControlsトークン） | 夜だけ強化・ディープフォーカスの窓 | スクリーンタイム許可 |

- 両方に入っているアプリ → **窓の中は完全ブロック、窓の外は一呼吸**
- 片方だけ → もう片方の機能は効かない。**これは正常**。エラー扱いしない
- 各セクションの見出しと補足で、そのリストが何に効くか・何が要るかを言い切る

### 絶対に壊してはいけないもの（並行セッションからの申し送り）

- `InterventionFlowModel` の `.durationSelection` ステージ。**常時ゲート廃止で消さない**
  - `ReclaimedTimeEstimator.estimatedSeconds` が過去30日の `selectedDurationSeconds` の中央値を使う。
    消すと全ユーザーが既定300秒に張り付き、「取り戻した時間」が意味を失う
  - `ReflectionLog.promptedAt` は選択時間の終了時刻。時間を決めないと予約が作れない
- `InterventionFlowModel` の `consecutiveDays` / `winReclaimedSeconds` / `winLifetimeReclaimedSeconds` /
  `winEstimatedMinutesPerCancellation` / `winMilestone`（開かなかった画面へ渡す値。ゲートと独立）
- `InterventionFlowView` の `DayTimeContext` バナー（`usageSummaryScreen` 内・target種別で分岐していない）
- `SettingsView` の `wakeSleepTimelineSection` / `wakeSleepTimelineDescription` / `timelineBar` /
  `timelineHandle` / `updateTimeline`（test-project-f3 の担当。据え置く）
- `settings.night_only.description` の文言（**f3 が案Xに合わせて書き換える。こちらは触らない**）

### 削除対象（参照を辿って到達不能なものだけ）
`GateShieldController` / `GateGrantController` / ゲート解除要求 / `ShieldActionExtension` のゲート経路 /
`GateShieldState.canUnlock` / `GateShieldScope` / `ScreenTimeSingleEntryPolicy` /
`AppModel.isScreenTimeGateConfigured` / catalog抑止と抑止時の自動化案内 / `shield.gate.*` の文言キー。

**時間窓のシールド（`ShieldController` の deepFocus / night ストア、`NightShieldScheduler`、`DeepFocusScheduler`）は残す。**
