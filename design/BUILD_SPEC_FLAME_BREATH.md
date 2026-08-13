# BUILD SPEC — 一呼吸「リアルな炎」呼吸アニメーション（Codex実装用）

作成: 2026-07-24 / オーケストレーター: Fable / 実装: Codex(gpt-5.6-sol, xhigh)
対象アプリ: DopaBreak (iOS 17.0+, SwiftUI, @Observable)

---

## 0. 目的（オーナー依頼）

介入フローの「一呼吸」画面を、**リアルな炎のアニメーション**に差し替える。

- 炎が**小さくなったり大きくなったり**して、ユーザーの呼吸を導く（吸う＝大きく／吐く＝小さく のリズム）。
- **最後はさらに大きな炎**になって締める（呼吸完了の合図＝フレア）。
- 「リアルな」＝写実的に揺らめく炎。ゲーム的・チープなパーティクルや平板なアイコンにしない。

現状の一呼吸画面（差し替え対象）: `ios/DopaBreak/InterventionFlowView.swift` の `breathingScreen`（数字カウントダウン＋細いプログレスバー＋「ひと呼吸おきましょう」）。

---

## 1. 採用技術（厳守）— SwiftUI Metal Shader による手続き的な炎

**SwiftUIのShader API（iOS 17+）で手続き的に炎を描く。** 外部依存・外部画像アセット・Lottie・SpriteKitは使わない。

理由（この方針から外れないこと）:
- iOS 17.0以上が確定（`project.yml` deploymentTarget=17.0）なので `View.colorEffect(_:)` / `ShaderLibrary` が使える。
- 手続き的なノイズ炎なら、**炎の強さ（大きさ・高さ・明るさ・乱流）をuniformで完全に制御でき**、呼吸の拡縮と最後のフレアを滑らかに表現できる。
- 外部アセット不要＝バンドル肥大・ライセンス・解像度問題なし。E1ダークモノ背景（near-black）に発光する炎が映える。
- GPUで軽く、60fpsを維持しやすい。

**却下する実装**（採用しないこと）:
- `CAEmitterLayer`／SpriteKitパーティクル（粒子テクスチャ画像が必要・写実性が出にくい・ダサくなりがち）。
- Lottie（依存追加＋写実的な炎JSONが必要・スタイライズされた炎になる）。
- SwiftUI Canvas + 手描きベジェのみ（写実性が出ない・CPU負荷）。

---

## 2. 成果物ファイル

1. `ios/DopaBreak/Shaders/Flame.metal` — 手続き的な炎のフラグメントシェーダ（新規）。
2. `ios/DopaBreak/FlameBreathView.swift` — 炎を描くSwiftUIビュー（新規）。`TimelineView(.animation)` + `Rectangle().colorEffect(ShaderLibrary.flame(...))` + グロー。
3. `ios/DopaBreak/InterventionFlowView.swift` — `breathingScreen` を `FlameBreathView` 主体へ改修（既存の見出し/ラベル/タイトルは維持、数字カウントダウンと細いバーは撤去）。
4. `ios/DopaBreak/InterventionFlowModel.swift` — 呼吸フェーズ(0..1)とフレア状態を公開し、カウントダウン終了時に**最終フレア区間**を追加してから `.usageSummary` へ進む。
5. 必要なら `ios/project.yml` / `xcodegen generate` による `.metal` のターゲット取り込み（下記§6で検証）。
6. 追加/更新テスト（§7）。

---

## 3. シェーダ仕様 `Flame.metal`

### 3.1 シグネチャ（`.colorEffect` 契約）

```metal
#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 flame(
    float2 position,      // colorEffectが渡す描画座標（ビューのローカルpt座標）
    half4  currentColor,  // 元ピクセル色（Rectangleの塗り。使わず自前で計算）
    float2 size,          // ビューのpt寸法（uniformで渡す）
    float  time,          // 経過秒（TimelineViewから）
    float  intensity,     // 呼吸フェーズ 0.0(最小)〜1.0(最大)
    float  flare,         // 最終フレア 0.0〜1.0（intensity上限をさらに押し上げる）
    float  reduceMotion   // 1.0ならモーション抑制モード（下記3.4）
)
```

### 3.2 炎の形状（domain-warped FBM）

- `uv = position / size`。炎は**下端中央**から立ち上る。`uv.y=1`が下、`0`が上になるよう反転して扱う（`float y = 1.0 - uv.y;` 下=0, 上=1）。
- **value noise + fbm**（4〜6オクターブ）を自前実装（`hash`→`valueNoise`→`fbm`）。`Math.random`等は使わずハッシュ関数で決定的に。
- **上方向ドメインワープ**: ノイズのサンプル座標を時間で上にスクロール（`p.y += time * riseSpeed`）し、炎が上に舐めるように揺らぐ。横方向にも低周波の揺らぎを足す。
- **炎の芯マスク**: 中央 `x=0.5` からの水平距離で幅を絞る。高さ方向に上へ行くほど細く先細り、上端で0へフェード。幅・高さは `intensity` と `flare` でスケール:
  - `float energy = mix(0.45, 1.0, intensity) + flare * 0.9;` のように、intensityで基礎の大きさ、flareで最後の増大。
  - 炎の到達高さ `flameHeight = energy`（uv基準で上方向にどこまで届くか）。
  - 芯の幅 `width = mix(0.10, 0.26, intensity) + flare * 0.10`（下太・上細のテーパー）。
- **フリッカー**: 高周波ノイズで `energy` を微揺らし（±数%）、炎先端をちらつかせる。`reduceMotion` 時はフリッカー振幅と riseSpeed を大幅に下げる。

### 3.3 配色（リアルな火）

下から上へ: **白熱の芯(near-white) → 黄 → オレンジ → 赤/深いエンバー → 透明**。
- 炎の密度/温度フィールド `heat`（0..1）を、芯からの距離と高さから作り、温度→色のグラデーションにマップ:
  - `heat > 0.85`: `half3(1.0, 0.95, 0.80)`（白熱コア）
  - `~0.6`: `half3(1.0, 0.78, 0.28)`（黄〜山吹）
  - `~0.35`: `half3(1.0, 0.42, 0.10)`（オレンジ）
  - `~0.15`: `half3(0.75, 0.12, 0.03)`（赤/エンバー）
  - それ以下: アルファ0へ。
- **アルファ**は炎の密度に比例（`smoothstep`でエッジを柔らかく）。背景（near-black `#0A0B0D`）に対して**加算的に光る**質感。ビュー側で `.blendMode(.plusLighter)` またはシェーダで自発光色を返す。
- アクセントのライム（#C7F94D）は**炎には使わない**。炎は本物の火の色。これはE1「アクセントはライム1色」規則に対する意図的な例外（朝焼け写真と同じヒーロー例外扱い）。ライム使用はビューの周辺UI（見出し等）に限定。

### 3.4 Reduce Motion（必須）

`reduceMotion==1.0` のとき: riseSpeed・フリッカー振幅・乱流オクターブを落とし、**穏やかにゆっくり脈動するだけ**の炎にする（激しい明滅を避ける）。色形状は維持。呼吸フェーズによる拡縮は残す（それが機能の本体だから）。

---

## 4. ビュー仕様 `FlameBreathView.swift`

```swift
struct FlameBreathView: View {
    var breathPhase: Double   // 0..1（モデルから。0=吐き切り/最小, 1=吸い切り/最大）
    var flare: Double         // 0..1（最終フレア）
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // TimelineView(.animation) で time を進め、Rectangle().colorEffect(ShaderLibrary.flame(...)) を適用。
    // size は GeometryReader で取得しuniformへ。glow用に軽いblur+plusLighterの重ねを1〜2層。
}
```

要件:
- `TimelineView(.animation)` の `context.date` から**単調増加のtime秒**を作る（基準時刻を`onAppear`で保持しての差分。`Date.now`直読みでの不連続を避ける）。
- 炎は画面中央下寄りに大きく配置（高さ ~320–420pt目安）。E1背景 `DesignTokens.background` 上。周囲に柔らかいグロー（炎色の放射ハロー）。
- **60fps・省電力**: 画面を離れたら描画を止める（`breathingScreen`から遷移＝ビュー破棄でTimelineView停止）。重い多重ブラーは避ける。
- `breathPhase`/`flare` の変化は `.animation(...)` でシェーダuniformへ滑らかに反映（モデルは離散更新でもよいが、ビューで補間 or モデルが連続値を出す—§5参照）。
- 新規の可視テキストは増やさない。増やす場合は §8 i18n を厳守。

---

## 5. モデル仕様 `InterventionFlowModel.swift`（呼吸リズム＋最終フレア）

### 5.1 現状（壊さない前提）
- `beginBreathing()` は `settingsStore.breathDurationSeconds`（{3,5,8}、既定3）秒をカウントダウンし、終了で `stage = .usageSummary`。
- **`startGeneration` 世代トークン**でキャンセル/冪等化済み（7/24修正）。`breathTask?.cancel()`。この保証を**必ず維持**する。
- 一呼吸に入るのは**reflectiveルートのみ**（`selectReason`→`.reflective`→`beginBreathing()`）。**このルーティングは変更しない**。

### 5.2 追加する公開状態
- `private(set) var breathPhase: Double`（0..1）— 呼吸曲線の現在値。
- `private(set) var flarePhase: Double`（0..1）— 最終フレア。
- 既存の `breathRemainingSeconds/breathTotalSeconds` は内部保持でよいが、画面の数字表示は撤去するので未使用なら整理（他参照がないこと確認）。

### 5.3 呼吸曲線（小さく↔大きく）
- カウントダウン中、`breathPhase` を**なめらかな正弦系カーブ**で 0↔1 に脈動させる（`Task`内で ~30–60fpsに更新、`startGeneration`と`Task.isCancelled`でガード）。
- 目安周期: 1呼吸 ≈ 3.0–4.0秒（吸う≒吐く）。総長{3,5,8}秒に対し、3秒で約1呼吸、8秒で約2呼吸見えるように。開始は小(吐き切り)から**吸う=大きく**へ。
- **総尺（{3,5,8}秒）と、reflectiveのみ表示、というプロダクト仕様は変えない**（介入摩擦のチューニング済みのため延長しない）。呼吸回数は総尺の自然な帰結でよい。

### 5.4 最終フレア（さらに大きな炎）
- カウントダウン満了時、`stage=.usageSummary`へ進む**前に**、短いフレア区間（≈0.7–0.9秒）を挟む:
  1. `breathPhase` を最大付近へ持ち上げつつ `flarePhase` を 0→1 へアニメ（炎が一気に大きく・明るく吹き上がる）。
  2. フレア完了後に `stage = .usageSummary`。
- このフレア区間も **`startGeneration`世代トークン＋`Task.isCancelled`＋`stage==.breathing`ガード**で保護（途中で別介入・キャンセルが来たら破棄。7/24の再入対策を踏襲）。
- 実装は既存 `beginBreathing()` のTask内に統合してよい（カウントダウン→フレア→advance を1つの世代ガード下で）。タイマーは `Task.sleep`ベースでよいが、UI更新は`@MainActor`で。

### 5.5 触覚（任意・軽微）
- フレアのピークで `.impact`ハプティクスを1回入れてよい（勝ち画面の success ハプティクスと整合。過剰にしない）。

---

## 6. Metalファイルのターゲット取り込み（検証必須）

- `.metal` は `ios/DopaBreak/Shaders/Flame.metal` に置く（DopaBreakターゲットの `sources: - path: DopaBreak` 配下なのでXcodeGenが自動でコンパイルソースに含める想定）。
- `cd ios && xcodegen generate` 後、`.metal` が **DopaBreakターゲットのCompile Sources** に入り、`default.metallib`にコンパイルされることを確認。`ShaderLibrary.default`（＝`ShaderLibrary.flame`）で解決できること。
- 万一 `ShaderLibrary.flame` が実行時に見つからない場合の対処（この順で試す。ワークアラウンドでなく正攻法で解決すること）:
  1. project.ymlでmetalがcompile phaseに入っているかpbxproj生成結果を確認。
  2. `SwiftUI/SwiftUI_Metal.h` のinclude・`[[ stitchable ]]`・関数名一致を確認。
  3. それでも不可なら project.yml に明示のbuildPhase/設定を追加（TODO/HACKコメントは残さない）。

---

## 7. テスト・検証

- 既存テストを壊さない: `swift test --package-path Packages/DopaBreakCore`（現状 **192テスト0失敗**）。
- モデルのフレア/呼吸タイミングはアプリ層。アプリ層テストの仕組みがあるなら、**フレア後に必ず`.usageSummary`へ到達すること**・**別介入start()割り込み時に旧世代のフレアが`.usageSummary`へ進めないこと**（世代ガード回帰）を最低1件追加。難しければモデルの純粋部分（呼吸曲線関数・フレア長）を関数抽出してユニットテスト。
- ビルド: `cd ios && xcodegen generate && xcodebuild -project DopaBreak.xcodeproj -scheme DopaBreak -destination 'generic/platform=iOS Simulator' -derivedDataPath .deriveddata CODE_SIGNING_ALLOWED=NO build` → **BUILD SUCCEEDED**必須。
- 省電力: 画面離脱でアニメ停止を確認（TimelineViewがビュー破棄で止まる構成）。

---

## 8. 厳守事項（レビューで機械チェックする）

1. **`startGeneration`世代トークン＋`breathTask`キャンセルの冪等性を維持**（7/24修正の回帰禁止）。カウントダウンもフレアも同一世代ガード下。
2. **reflectiveのみ一呼吸表示・総尺{3,5,8}秒を変えない**。directルートに炎を出さない。
3. **外部依存/外部画像アセットを追加しない**（SPM追加禁止・PNG等追加禁止）。純Metal手続き生成。
4. **i18n維持**: 可視テキストは `String(localized:defaultValue:)`。新規キーを足す場合は `ios/DopaBreak/Localizable.xcstrings` に ja/ko/en 全ロケール分を登録（未翻訳放置禁止）。原則、新規可視テキストは足さない（既存「ひと呼吸おきましょう」等は維持）。
5. **Reduce Motion対応**（§3.4/§4）。激しい明滅で誘発しない。
6. **E1ダークモノ整合**: 炎は背景上のヒーロー。ライム(#C7F94D)は炎に使わない（意図的例外を design-decisions に私が記録する）。
7. **省電力・60fps**。多重重ブラー・毎フレームの重い割当を避ける。
8. コード省略・TODO/HACK・未実装マーカーを残さない（完全実装）。
9. 変更は必要範囲のみ（無関係リファクタ禁止）。

---

## 9. 完了条件

- `Flame.metal` + `FlameBreathView.swift` 実装、`breathingScreen` が炎主体に差し替わり、モデルが呼吸フェーズ＋最終フレアを駆動。
- `xcodegen generate` → `xcodebuild ... build` = BUILD SUCCEEDED。
- `swift test --package-path Packages/DopaBreakCore` = 全パス（既存192＋追加分）。
- 上記§8を全て満たす。
- 変更ファイルの要約と、手動確認手順（シミュレータで reflective ルート＝暇つぶし/なんとなくを選び一呼吸画面に到達→炎の拡縮とフレアを目視）を出力。

---

# 追補 A — 舞い上がる火の粉（EMBERS）の追加

追加: 2026-07-25 / 理由: オーナー確認「火の粉が舞ってるようなリアルな炎になってるか？」→ 現状は炎本体のみで火の粉なし。**初版仕様の漏れ**。リアルな焚き火の説得力は炎本体より舞い上がる火の粉が担うため追加する。

## A-1. 何を足すか

炎の先端付近から生まれ、**上へ加速しながら左右に揺れて、瞬きながら消えていく火の粉（スパーク）**を追加する。既存の炎本体・呼吸の拡縮・最終フレアの挙動は変えない（火の粉は上に重なる加算レイヤー）。

## A-2. 実装方針（厳守）

- **同じ `flame` シェーダー内で手続き的に生成する**。パーティクルシステム（CAEmitterLayer/SpriteKit）・画像テクスチャ・新規SPM依存は使わない（初版§1の却下方針を維持）。
- **解析的スパーク方式**: N個（既定 28個程度・要調整）のスパークをループで評価し、各スパークの位置・明るさ・大きさを `time` とハッシュシードから解析的に決める。ピクセルごとにスパークへの距離で放射状の光を加算する。
  - 各スパーク `i`: `seed = hash(i)` から 生成位置のx方向オフセット、寿命の長さ、上昇速度、揺れの周波数・振幅、明滅の位相 を決定（決定的・乱数関数は使わない）。
  - **寿命ループ**: `lifeProgress = fract(time * speed_i + phase_i)`（0→1で1周期）。0で誕生、1で消滅して再生成される。
  - **上昇**: 炎の先端付近（`flameHeight` の 0.55〜0.95 あたりのランダムな高さ）で生まれ、`lifeProgress` に対して**加速しながら**上昇する（例: `rise = pow(lifeProgress, 0.72)` で序盤速く後半緩やか、または逆に加速。実際の火の粉は上昇気流で加速→減速するので、加速後に頭打ちになるカーブが望ましい）。フレーム上端に達する前に消える。
  - **横揺れ**: `x += sin(time * swayFreq_i + phase_i) * swayAmp_i * lifeProgress`（上に行くほど揺れ幅が大きい＝乱流で流される）。既存の `broadWarp` のノイズを流用して横流れを足してもよい。
  - **減衰**: 明るさは寿命後半で急速に落ちる（例: `fade = (1 - lifeProgress)^2`）。サイズも上昇に伴い小さくなる。
  - **明滅**: 高周波の瞬き（`flicker = 0.6 + 0.4 * noise(time * f + seed)`）を掛け、チカチカと爆ぜる感じを出す。
  - **色**: 火の粉は炎本体より高温側に寄せる（黄白〜オレンジ）。上昇して冷えるほど赤/暗いエンバー色へ遷移させると写実性が上がる。ライム(#C7F94D)は使わない。
  - **合成**: 加算（`plusLighter`相当）。既存の premultiplied alpha 出力規約を守り、`half4(color * alpha, alpha)` の形で整合させること。

## A-3. 呼吸・フレアとの連動（重要）

- **`intensity`（呼吸フェーズ）で火の粉の量と勢いが変わる**: 吸って炎が大きい時は火の粉が増え、高く舞う。吐いて小さい時は数が減り、低くまばらになる。
- **`flare`（最終フレア）で一気に吹き上がる**: フレア時は火の粉の個数・上昇速度・明るさを大きく増やし、**クライマックスとして大量の火の粉が舞い上がる**画にする。ここが「最後はさらに大きい炎」の演出の主役になる。
- 実装上は、各スパークの `alpha` に `intensity`/`flare` 由来の係数を掛け、係数が0付近のスパークは実質不可視にする（動的な個数変更の代替）。ループ回数自体は固定でよい（分岐発散を避ける）。

## A-4. Reduce Motion

`reduceMotion==1.0` のとき: 火の粉の**個数・上昇速度・揺れ幅・明滅の振幅を大きく落とす**（消してもよい）。激しくチカチカさせない。

## A-5. 性能

- ループは固定回数・早期`break`なしで分岐発散を避ける。28個程度なら 380×380pt で問題ないはずだが、**Instruments等での厳密計測までは不要。ビルドとシミュレータ描画で破綻がないこと**を確認する。
- 既存のFBM呼び出し回数を無闇に増やさない（火の粉はノイズを1〜2回程度に抑え、主に解析式で表現する）。

## A-6. 厳守（初版§8に追加して全て維持）

- 既存の炎本体・呼吸曲線・最終フレアのタイミング・`startGeneration`世代ガード・reflective限定・総尺{3,5,8}秒を**変更しない**。変更はシェーダー内の描画のみ（＋必要なら`FlameBreathView`のグロー微調整）。
- 新規SPM依存・画像アセットを追加しない。新規可視テキストを追加しない。
- `isfinite` によるuniformサニタイズ（2026-07-25追加）を維持する。
- TODO/HACK禁止・完全実装。

## A-7. 完了条件

- 火の粉が炎から生まれて舞い上がり、揺れて瞬いて消える。呼吸で量が変わり、最終フレアで大量に吹き上がる。
- `cd ios && xcodegen generate && xcodebuild ... build` = BUILD SUCCEEDED
- `swift test --package-path ios/Packages/DopaBreakCore` = 192テスト0失敗維持
- アプリ層テスト（DopaBreakTests）も維持。
