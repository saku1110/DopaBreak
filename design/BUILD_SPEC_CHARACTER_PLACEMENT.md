# キャラクター配置設計（DopaBreak）

作成: 2026-08-04 / 前提: [CHARACTER_BIBLE_DOPA.md](CHARACTER_BIBLE_DOPA.md)（絵柄の固定値）／確定アイコン=75b
実装方針: **静止PNG + SwiftUIのトランスフォーム**でアニメーションを作る。Lottie・動画・新規依存は入れない。

---

## 0. 設計の中核原則

**キャラは「あなたの状態」、炎は「呼吸のペース」。仕事が違うので共存させる。**

| 仕事 | 担当 | 理由 |
|---|---|---|
| 呼吸のペースを作る（吸う=大/吐く=小） | **炎**（既存 `FlameBreathView`・605行のMetal） | 顔が膨張収縮すると滑稽になり鎮静の逆。炎の揺らぎは催眠的 |
| 今の自分の状態を映す | **キャラ** | 炎に表情はない |
| 目標そのもの | **種火**（現状維持・別途置換検討） | — |

### 介入フローの設計思想（最重要）

キャラで炎を**挟む**。炎の聖域は侵さない。

```
虚ろなキャラ  →  炎で一呼吸  →  焦点が戻ったキャラ
（今のあなた）    （炎の担当）    （一呼吸の成果）
```

これで「一呼吸すると自分が変わる」というアプリの主張が、体験の中で目に見える。

---

## 1. アセット（全6枚・同一ボディで表情のみ差し替え）

`frame_a/b/c` は起動アニメ用に**作成済み**（`video/launch-animation/public/`）。流用する。

| ID | 表情 | 状態 | 用途 |
|---|---|---|---|
| **A** `doom` | 虚ろな垂れ目・縮んだ瞳孔・半開きの口 | 作成済 | 介入の入口、lostTime、オンボ前半 |
| **B** `blink` | 完全な閉眼 | 作成済 | **全遷移の目隠し**（下記2.2） |
| **C** `awake` | パッチリ・ハイライト2点 | 作成済 | 一呼吸の後、satisfied |
| **D** `relief` | 目を細めた安堵・小さな笑み | **要作成** | 勝ち画面(win)、達成、開かずに戻れた |
| **E** `blank` | 半開きの目・無表情・口は水平 | **要作成** | nothingGained |
| **F** `worse` | 眉が下がり口角も下がる・軽い汗一滴 | **要作成** | feltWorse |

`fun` は C を流用（新規作成しない）。

---

## 2. アニメーション機構（新規依存なし）

### 2.1 Idle Float + Blink — これだけで静止画が生きて見える

**1枚の静止PNGに、上下の浮遊と時々のまばたきを足すだけで生物感が出る。** 追加アセットは B（閉眼）1枚のみ。

```swift
// 浮遊: ±4pt / 周期1.6s（sin波）
// まばたき: 3.5〜6.0秒のランダム間隔で B を 0.13秒だけ挟む
// Reduce Motion: 浮遊を止め、まばたきのみ残す
```

- `TimelineView(.animation)` で時間を取り、`Image` を差し替える
- 実装は `CharacterView.swift`（新規・単一ビュー）に閉じ込め、全画面で使い回す

### 2.2 Blink-covered swap（表情の切替）

起動アニメで採用済みの手法をそのまま使う。**閉眼フレームBを0.13秒挟んで、その裏で差し替える。** クロスフェードは線とグレインが泳ぐので禁止。

```
A ──(B 0.13s)──> C     人間の目は閉眼中の差分を検知できない
```

### 2.3 リアクション（押下・達成）

- 選択時: `scale 1.0 → 1.06 → 1.0`（`DopaMotion.control`）
- 勝ち画面: `DopaMotion.celebrate` で1回だけ弾む（既存トークンを使う。新規イージングを作らない）

---

## 3. 画面ごとの配置

### 3.1 オンボーディング（`OnboardingFlow`・全15ステップ）

**全ステップには置かない。** 損失回避の質問中に顔があると茶化して見える。

| ステップ | キャラ | 演出 |
|---|---|---|
| `welcome` | **A** | Idle float + blink。初対面。ここでアイコンの期待と接続する |
| `selfCheck` `quizAimless` `quizRegret` | ✕ なし | 自己申告の重い問い。顔を出さない |
| `quizResult` | **A → B → F** | 推計結果（人生の◯年）提示の直後に表情が沈む。損失を絵で受ける |
| `chooseApps` `goalSetup` `chooseMode` | ✕ なし | 設定作業。邪魔をしない |
| `preview` | **A → B → C** | 介入の予告。ここで初めて「変われる」を見せる |
| `whyScience` `permission` `notificationGuide` `lockScreenCheck` | ✕ なし | 説明・許可。信頼性が要る場面 |
| `prePaywallSummary` | **C** | 期待した未来の顔 |
| `ready` | **D** | 安堵。「準備完了」と一致 |

### 3.2 介入フロー（`InterventionFlowModel.Step`）

| ステップ | キャラ | 炎 | 演出 |
|---|---|---|---|
| `breathing` | **A を 0.6秒だけ**表示 → フェードアウト | **主役（変更しない）** | 開幕に「今のあなた」を一瞬見せてから炎へ譲る。炎の描画中はキャラを出さない |
| `usageSummary` | ✕ | ✕ | 数字の画面 |
| `goalReminder` | ✕ | 種火 | 目標の領域 |
| `reasonSelection` | ✕ | ✕ | 6択の選択作業 |
| `decision` | **A → B → C** | ✕ | **ここが山場。**一呼吸を経た「焦点が戻った自分」を見せてから選ばせる |
| `durationSelection` | ✕ | ✕ | 時間選択 |
| `opening` | ✕ | ✕ | 遷移 |
| **`win`（開かずに戻れた）** | **D** + celebrate | ✕ | **最大の報酬点。**安堵の顔で祝う |
| `failed` | ✕ | ✕ | 責めない。顔で追い打ちをかけない |

### 3.3 利用後リフレクション（`PostUseReflectionSheet`）— 最も費用対効果が高い

`PostUseSatisfaction` の5値が、そのまま表情5種に対応する（[AppModels.swift:199](../ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Models/AppModels.swift#L199)）。

| 選択肢 | 表情 |
|---|---|
| `satisfied` | **C** awake |
| `fun` | **C** awake（流用） |
| `nothingGained` | **E** blank |
| `lostTime` | **A** doom |
| `feltWorse` | **F** worse |

- 選択肢ボタンの中に**小さな顔（44pt）**を置く。文字を読まずに選べる
- 選択すると、画面上部の大きなキャラが blink-covered swap でその表情へ変わる＝**自分の状態が反映される**
- アイコンで見た顔（A）がここで選択肢になる。ストア→アプリの導線が一本につながる

### 3.4 置かない画面（意図的）

| 画面 | 理由 |
|---|---|
| **Home** | 数字と実績の画面。常駐すると邪魔で、かつ飽きる |
| `MidSessionCheckInSheet` | 使用中の割り込み。軽くしたい |
| Stats / Settings | 実用画面 |
| ロック画面ウィジェット / Live Activity | 極小サイズ。表情が潰れる |

**例外候補**: Home の達成ゼロ状態（初日）だけ **A**、初成功時に **D** へ swap する案は検討に値する。ただし常設はしない。

---

## 4. 実装単位

| # | 成果物 | 内容 |
|---|---|---|
| 1 | `ios/DopaBreak/CharacterView.swift` | 表情enum・Idle float・自動blink・blink-covered swap・Reduce Motion対応を1ビューに封じる |
| 2 | `Assets.xcassets/Character/` | A〜F の6枚（@1x/@2x/@3x） |
| 3 | 各画面への差し込み | 上記3.1〜3.3のとおり。既存レイアウトを壊さない |
| 4 | テスト | 表情マッピング（`PostUseSatisfaction` → 表情）の網羅、Reduce Motion時に浮遊が止まること |

## 5. 制約（守る）

- **炎（`FlameBreathView`・`Flame.metal`）には一切触らない。** `breathing` ステップの描画中にキャラを重ねない
- 新規パッケージ依存を追加しない（Lottie等）
- 既存の `DopaMotion` トークンを使う。新しいイージングを発明しない
- 全キャラ画像は [CHARACTER_BIBLE_DOPA.md](CHARACTER_BIBLE_DOPA.md) の `LOCKED_SPEC` で生成し、`verify_character.py` の機械判定を通ったものだけ採用する
