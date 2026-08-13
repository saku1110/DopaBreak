# Design decisions

## 2026-08-12 — Cute Tex app-icon concept C2

- Created `creatives/app-icon/concepts/cute-tex/png/texC2.png` as a 1024×1024 full-bleed iOS app-icon asset.
- Kept the locked composition: a wide pink brain mascot above two white gloves holding a charcoal portrait phone with a lime pause screen, on deep plum with a warm halo.
- Used a soft-vinyl, satin semi-matte 3D treatment, broad rounded brain lobes, oversized downcast eyes, simple mouth, and strong blush to increase cuteness and preserve recognition at small sizes.
- Rejected extra accessories, particles, typography, borders, baked corner rounding, a stand/base, and extra limbs because they violate the icon constraints and weaken 60×60 readability.
- Implementation constraints: treat the PNG as the unmasked 1024×1024 source; do not add baked corner rounding, borders, or a tile shadow. Let iOS apply the platform icon mask. Preserve the lime screen and exactly two dark pause bars when deriving sizes.

## 2026-08-12 — Cute troubled app-icon concept A

- Created `creatives/app-icon/concepts/cute-exp/png/expA.png` as an exact 1024×1024 full-bleed iOS app-icon PNG.
- Preserved the locked composition: an oversized, wider-than-tall pink brain mascot above two white gloves holding a charcoal portrait phone with a lime pause screen, on deep plum with a warm amber halo.
- Adopted a glossy soft-vinyl designer-toy treatment, 6–7 broad rounded lobes, a central groove, downcast eyes, inner-down worried brows, blush, and a tiny open O mouth to communicate cute but quietly overwhelmed rather than happy.
- Rejected smiling or upward-curved mouths, extra screen UI, accessories, particles, tears, sweat, anatomy details, text, borders, baked corner rounding, and extra limbs because they conflict with the brief and harm small-size legibility.
- Implementation constraints: use this PNG as the unmasked source and let iOS apply its icon mask. Preserve the exact lime screen with two black rounded pause bars and do not crop the tightly framed brain or add surrounding margin when deriving sizes.

## 2026-08-12 — Cute troubled app-icon concept B

- Created `creatives/app-icon/concepts/cute-exp/png/expB.png` as an exact 1024×1024 full-bleed iOS app-icon PNG.
- Preserved the locked composition: a tightly framed, wider-than-tall six-lobed pink brain mascot above two small white gloves holding a charcoal portrait phone with a lime screen and exactly two black rounded pause bars, on deep plum with a warm amber halo.
- Adopted a glossy gummy/jelly soft-body treatment with gentle subsurface glow, large downcast eyes, slightly lowered pink lids, strong cheek blush, and a tiny flat wavy mouth. The eyebrows use the specified inner-down orientation: their center endpoints sit lower than their outer endpoints.
- Rejected the initial roof-shaped eyebrow orientation because it contradicted the explicit inner-down requirement. Also excluded smiles, extra screen UI, accessories, particles, tears, sweat, veins, typography, borders, baked corner rounding, tile shadows, and extra limbs.
- Implementation constraints: treat the PNG as the unmasked source and let iOS apply the platform icon mask. Preserve its tight crop, worried expression, glove/phone placement, and the screen's exact two-bar pause glyph when deriving smaller sizes.

## 2026-08-13 — Cute CEL app-icon concept A

- Created `creatives/app-icon/concepts/cute-cel/png/celA.png` as an exact 1024×1024 full-bleed iOS app-icon PNG.
- Preserved the locked composition: a large wider-than-tall pink brain mascot, centered over two small white gloves holding a charcoal portrait phone with a lime screen and exactly two black rounded pause bars, against deep plum with a warm amber halo.
- Adopted a hand-drawn 1990s American TV cartoon CEL treatment: saturated flat pink fills, hard-edged darker-pink shadow masses, bold even dark outlines, crisp white upper rim highlights, and subtle paper grain. Simplified the outer silhouette into seven broad readable lobe masses and kept a strong central fissure, sparse crease marks and pores, large downcast eyes, thick inner-down worried brows, blush, and a short perfectly flat mouth.
- Rejected the first render's edge-hugging crop and overly segmented lobe contour because they conflicted with the specified breathing room and 6–7-lobe small-size silhouette. Also excluded smiling mouth curvature, extra screen UI, text, accessories, particles, tears, sweat, anatomy details, 3D/plastic modeling, borders, baked corner rounding, and extra limbs.
- Implementation constraints: use the PNG as the unmasked 1024×1024 source and let iOS apply its icon mask. Preserve the plum edge breathing room, top clearance, centered phone/gloves, flat mouth, and exact two-bar pause glyph when deriving sizes; do not add a border, tile shadow, or baked rounding.

### 2026-08-13 追記 — 構図固定のまま造形をcuteにする検討（**提案・未承認**）

構図（脳＋白手袋＋ライムのポーズ画面＋暗プラム背景＋見下ろす視線）を固定し、造形・質感・表情のみ振った。

- `cute-tex/` 質感3方向（グミ／プラッシュ／ソフビ）×2 — 全案とも口が笑顔化し「スマホを楽しんでいる」に見えたため訴求と逆。頭幅も86〜90%（現行94%）と縮んだ
- `cute-exp/` cute造形×困り顔 3案 — expC（困り眉＋平口＋大きい目）が最良。ただし質感は3Dソフビ
- `cute-cel/` **現行のセル画・太いアウトライン・紙質感を維持したまま造形のみcute化** 3案 — celA が最良

判断材料（実測）:
- appicons.store 46点の実物では3Dぷにぷにマスコットが最多。**紙質感つきセル画は0点** → 3D化は最も混んだレーンへの移動になる
- 60pxでは眉を太くすれば表情は読める（細い眉の案は消える）。現行は半目＋開き口が潰れて表情が伝わらない
- 幾何実測: celA 幅93%上16% / celB 比0.74 / celC 幅91%上10%（現行 幅94%上9%）

未解決: cel系3案は暖色ハローが現行より強くタイル外周が光る。採用時に弱める。
アイコン差し替えはオーナー承認後に着手する。キャラ正本が変わる場合 `design/CHARACTER_BIBLE_DOPA.md` と既存の表情差分（`frame_c_awake` 等）も作り直しが必要。

## 2026-08-13 — 価格設計の凍結（オーナー決定「このままでいこう。後で分析してからテストする」）

- 決定: docs/15 §3.4の3市場価格表（JP¥980/¥4,980/¥14,800・KR₩9,900/₩49,000/₩149,000・US$9.99/$39.99/$119.99）をローンチ価格として凍結。①JP¥4,980は値下げ・A/B前倒しをしない ②米国に週額は導入しない ③月額は維持（アンカー役） ④Lifetimeは非常設のまま維持（設定画面＋年額解約フローのみ）。
- 経緯: 2026-08-13経営会議（議事録=.claude/brainstorm/2026-08-13_価格戦略_課金導線_リリース優先順位.md）→ オーナーから買い切りの要否・米国週額の要否の追加検討指示 → SOSA実測（Productivity実売=年額77%/週額11%・年額RPI=週額約5倍・週額はペイドUA回収用）と競合実測（one sec/Jomoに週額なし・両社とも買い切りあり）で「現状維持」を進言 → オーナー裁可。
- 再検討はローンチ後90日ゲートの実測データでのみ行う（¥3,980 A/B・US週額置換A/B。詳細条件はdocs/15 §3.4に記載）。
