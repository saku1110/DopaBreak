# キャラクター仕様書 — DopaBreak 脳キャラ（画像生成の一貫性を強制するための正本）

作成: 2026-08-04 / 根拠: 確定アイコン `ios/DopaBreak/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`（75b）の実測値

**目的**: 生成のたびに絵柄がブレる問題を、プロンプト側の固定で潰す。
**運用**: 下の `LOCKED_SPEC`（英語ブロック）を全キャラ画像プロンプトへ**一字一句そのまま**埋め込む。変えてよいのは `VARIABLE` セクションだけ。

---

## 1. 実測した不変値（確定アイコンより）

| 項目 | 固定値 |
|---|---|
| 頭の幅 | タイル幅の **86%** |
| 頭の高さ | タイル高の **71%** |
| 上余白 | **13%** |
| 左右余白 | 各 **7%** |
| **縦横比（高さ÷幅）** | **0.83（横長）** ← 縦長化は禁止。2026-08-04に1.45へ振って失敗済み |
| 脳の主要ピンク | `#F08484`（陰 `#D97B93`） |
| 地色（四隅） | `#170713`〜`#200C17` の深いプラム |
| スマホ画面のライム | `#CCF030` |

## 2. 生成方式（**text-to-image は禁止**・2026-08-04に実証）

**表情差分は必ず基準画像を入力にした image-to-image（顔だけ編集）で作る。**

`LOCKED_SPEC` のテキストだけで新規生成したところ、3枚とも別キャラになった（頭が平たく横長・目が小さい楕円・色が赤寄り・ハローが赤紫）。文章はスタイルを寄せられても、**同一の絵は再現できない**。

| 方式 | 体の差分（基準比） | 判定 |
|---|---|---|
| text-to-image（LOCKED_SPECのみ） | 別キャラ化。比0.67〜0.75で機械判定も不合格 | ❌ 使わない |
| **image-to-image（顔のみ編集）** | 平均13.5 / 0.2 / 13.2（大差画素 0.0〜1.4%） | ✅ 採用 |

手順:

1. 基準画像は `video/launch-animation/public/frame_c_awake.png`（スマホを下ろした状態・体の正本）
2. プロンプトで「顔（目・眉・口・頬）以外はピクセル単位で不変」を明示し、輪郭・ロブ・しわ・斑点・色・紙質感・背景・手・スマホ・構図・位置を列挙して固定する
3. `verify_character.py`（比率）と `verify_swap.py`（顔以外の一致）の**両方**を通す
4. `codex exec` は背景シェルで stdin を掴んで停止するため `< /dev/null` 必須。`export -f` は bash 専用（zshで直に書くと関数が渡らない）

`LOCKED_SPEC` は**新規ポーズを起こすときだけ**使う（体ごと描き起こす場合）。表情差分には使わない。

## 2b. LOCKED_SPEC（新規ポーズ用・プロンプトへそのまま貼る）

```
LOCKED CHARACTER SPEC — reproduce EXACTLY, these never change:
- Subject: an ORIGINAL cartoon brain mascot. Nothing else. No resemblance to any existing character.
- Head silhouette: made of LARGE rounded scallop lobes. The overall head is WIDER THAN TALL —
  its height is 0.83x its width. NEVER draw a tall, egg-shaped or narrow head.
- Head size and placement: head spans 86% of the tile width and 71% of the tile height,
  centered horizontally, with 13% empty background above the top lobes and 7% at each side.
- Brain markings (mandatory — without these it reads as a cloud and is REJECTED):
  (a) ONE strong central vertical fissure dividing the two hemispheres, from the crown down to the brow;
  (b) short curved crease strokes inside the lobes, drawn in the outline colour;
  (c) sparse darker-pink oval pore spots scattered over the lobes.
- Line work: bold, clean, EVEN-WEIGHT dark outline (#2A1420) around every shape. No thin tapering lines.
- Colour: flat saturated pink #F08484 with darker #D97B93 cel shadow shapes. No airbrush gradients on the body.
- Eyes: two large round eyes with off-white eyeballs, set at a MODERATE spacing —
  neither touching nor pushed to the outer edges of the face. Big soft pink upper lids sit over them.
- Rendering: classic 90s TV cartoon cel style, flat colours + simple shadow shapes,
  with a subtle mottled paper grain over the whole image. NOT photoreal, NOT 3D render, NOT clay, NOT vector-flat.
- Background: full-bleed deep plum #1C0A16, with a soft warm ambient halo glowing behind the head.
- Hands (only when the pose calls for them): small white cartoon gloves.
- Format: square 1024x1024. NO text, NO letters, NO numbers anywhere. NO baked rounded corners,
  NO border, NO outer drop shadow on the tile. Must read clearly at 60x60 pixels.
- Forbidden: sparkles, stars, hearts, glasses, books, limbs, ears, whiskers, accessories,
  fine falling particles (they vanish at 60px), horror or gore, bloodshot veins, tears.
```

## 3. VARIABLE（案ごとに変えてよいのはここだけ）

- 目の開き具合と瞳孔の大きさ
- 眉の角度
- 口の形
- 頬の赤み
- 手とスマホの有無・位置・画面の点灯状態
- ライムの照り返しの強さ

## 4. 検証（生成後に必ず実行）

`creatives/app-icon/concepts/verify_character.py` で実測し、下を満たさなければ**不採用にして再生成**する。

| 指標 | 許容 |
|---|---|
| 縦横比 | 0.75〜0.92 |
| 頭の幅 | 78%〜92% |
| 上余白 | 8%〜18% |

## 5. 経緯（同じ失敗を繰り返さないため）

- 「顔が大きすぎる」→ 頭幅85%・左右余白ありへ是正（GenK実測に合わせた）
- 「上下が潰れている」という**私の指摘は誤診**。縦長化（比0.83→1.45）したら卵・繭に見え、離した目が不気味になり不採用。**横長は欠陥ではなく脳本来の形で愛嬌の源**
- 細かい降下粒子は60pxで消え、代償に目が小さくなるため禁止
- スポンジボブ・GenKは**画風の参照のみ**。キャラクター自体は完全オリジナル（IP・審査対策）
