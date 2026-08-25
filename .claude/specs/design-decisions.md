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

## 2026-08-13 — Cute CEL app-icon concept A4

- Created `creatives/app-icon/concepts/cute-cel2/png/celA4.png` as an exact 1024×1024 full-bleed iOS app-icon PNG.
- Preserved the locked composition: a very large, wider-than-tall bright-pink brain mascot over exactly two white gloves holding a charcoal portrait phone with a lime screen and exactly two dark pause bars, on a near-black tile.
- Adopted a hand-drawn 1990s American TV cartoon CEL treatment with seven broad perimeter lobes, bold even dark outlines, crisp white upper rim highlights, sparse pore/crease marks, and subtle paper grain. The expression uses large downcast eyes, short thick brows whose inner ends form a lower center valley, blush, and a tiny open O mouth to stay cute but troubled rather than happy.
- Rejected earlier passes with an over-segmented silhouette, smooth/glossy lighting, and incorrectly rising inner brow ends because they conflicted with the seven-lobe small-size silhouette, flat CEL treatment, and required worried-brow geometry.
- Implementation constraints: treat this PNG as the unmasked source and let iOS apply its platform icon mask. Preserve the tight 94%-scale framing, seven-lobe silhouette, clean-pink body, small O mouth, two gloves, and exact pause-only lime screen when deriving sizes. Do not add a border, baked rounding, tile shadow, text, extra limbs, particles, or glow at the corners.

## 2026-08-13 — 法務ページのホスティング先をGitHub Pagesに確定（オーナー決定「ドメインじゃなくGithubPagesでいい」）

- 決定: dopabreak.appドメインの取得は行わない。利用規約/プライバシー/特商法/サポートは **https://saku1110.github.io/dopabreak-legal/** で公開する（リポジトリ=saku1110/dopabreak-legal・public・Pages有効）。
- 構成: shapegap-legal / bestswipe-legal と同一の確立パターン（アプリ別公開リポジトリ・静的HTML）。ページ11枚=terms/privacy/support×ja/en/ko＋tokushoho-ja＋index。全ページ200確認済み（2026-08-13）。
- 内容の要点: ①プライバシーは「全データ端末内・運営者サーバーなし・外部送信ゼロ・アカウントなし」を明記（Privacy Nutrition Label "Data Not Collected"の根拠と整合） ②スクリーンタイム情報（FamilyControls/DeviceActivity）は端末内処理・第三者アクセス不可を明記 ③規約に効果非保証・非医療の免責条項（第5条） ④App Store特則（Apple第三者受益者条項一式） ⑤**KRページには価格を記載しない**（KR価格はオーナー未サインオフのため。JP=¥980/¥4,980/¥14,800、EN=$9.99/$39.99/$119.99は記載）。
- 実装: `ios/DopaBreak/AppURLs.swift` を言語別URL（Bundle.main.preferredLocalizationsでja/ko/enを出し分け）へ変更。`AppURLs.support` 新設（ASCのSupport URL欄用）。BUILD SUCCEEDED確認済み。
- 運営者表記: 桜谷俊輝・住所/電話は請求時開示（shapegap-legalで公開済みの確認済み情報を転記）。
- 効果: preflightブロッカー①（Terms/Privacyデッドリンク・3.1.2）が解消。ASCメタデータのPrivacy Policy URL / Support URLにもこのPagesを使用する。

## 2026-08-13 — Glossy enamel brain app icon

- Created `creatives/app-icon/concepts/gloss/png/glossB.png` as an exact 1024×1024 full-bleed iOS app icon.
- Preserved the locked composition: an oversized wider-than-tall brain mascot, downward gaze, two white gloves, and a centered portrait phone with a lime pause screen containing only two rounded black bars.
- Adopted a simplified large-lobe silhouette, bright clean pink enamel gradients, broad soft white highlight bands, soft overlap shadows, and a thin outer silhouette outline so the mascot remains glossy and readable at 60×60.
- Kept the mood cute but drained with heavy downward-looking lids, thick worried brows, blush, and a short flat closed mouth. Rejected smiles, busy small lobes, matte or grainy rendering, thick internal outlines, decorative particles, extra limbs, and warm corner glow because they conflict with the brief.
- Implementation constraint: retain the near-black full-bleed square with a tight central amber halo and near-black corners; do not add baked rounded corners, a border, tile shadow, text, accessories, or any phone-screen content beyond the pause glyph.

## 2026-08-13 — Glossy enamel brain app icon concept C

- Created `creatives/app-icon/concepts/gloss/png/glossC.png` as an exact 1024×1024 full-bleed RGB iOS app-icon PNG.
- Preserved the locked composition: an oversized, wider-than-tall bright-pink brain mascot with a downward gaze, two small white gloves, and a centered front-facing charcoal phone whose lime screen contains exactly two rounded black pause bars.
- Adopted six large calm lobes, a soft central fissure, three sparse curved crease grooves, understated darker-pink pore spots, continuous glossy enamel gradients, broad airbrushed white highlight bands, soft lobe-overlap shadows, and a thin dark silhouette outline. The worried expression uses large downcast eyes, short thick inner-down brows, blush, and a tiny open O mouth.
- Rejected the first pass because its many small lobes weakened small-size readability and its phone showed camera hardware. Rejected a marking-free intermediate pass because the brief mandated sparse creases and pore spots. Excluded smiles, extra phone UI, matte/grainy texture, thick internal outlines, limbs, accessories, particles, text, borders, baked rounding, tile shadows, and amber glow at the corners.
- Implementation constraints: use this PNG as the unmasked 1024×1024 source and let iOS apply the platform mask. Preserve the tight crop, near-black corners, six-lobe silhouette, bright clean pink body, tiny O mouth, front-facing pause-only lime screen, and glove placement when deriving sizes.

### 2026-08-13 決着 — **アプリアイコンは現行を維持する（オーナー判断）**

キャラの可愛さ検討は打ち切り。全18案（`cute/` `cute-tex/` `cute-exp/` `cute-cel/` `cute-cel2/` `gloss/`）が現行に及ばず、
オーナーが「今のままでいい」と判断。**`AppIcon-1024.png` の差し替えは行わない。**

得られた資産は仕様書の訂正3点（`design/CHARACTER_BIBLE_DOPA.md` §6）:
主要ピンク `#F08484`→`#FD90AB` / 地色「深いプラム」→ほぼ純黒 `#010001` / 質感「フラットなセル画＋紙質感」→**エナメル光沢**。
記載が実物と違っていたため、仕様書どおりに生成すると赤くマットな別物になっていた。
次にキャラ画像を作るときは仕様書の文言ではなく実測に合わせる。

### 2026-08-13 追記 — 上記法務ページエントリ⑤の訂正（KR価格）

⑤の「KRページには価格を記載しない（未サインオフのため）」は旧情報に基づく誤りだった。同日の価格凍結決定（本ファイル「価格設計の凍結」エントリ・docs/15 §3.4）により KR=₩9,900/₩49,000/₩149,000 は確定済み。並行セッションからの訂正を受け、terms-ko.html 제4조へ価格を追記しpush済み。結果、価格は3言語とも記載（JP=¥980/¥4,980/¥14,800、EN=$9.99/$39.99/$119.99、KR=₩9,900/₩49,000/₩149,000）。

### 2026-08-13 追記 — 法務ページのCodex独立レビュー結果（6指摘→採用5・オーナー判断1）

採用・是正済み（push・公開反映確認済み）: ①Apple EULA特則の制裁条項に「テロ支援」指定国・地域を補完（3言語） ②プライバシーに「お問い合わせで受け取る情報」§新設（メール問い合わせで受領する情報の目的・削除・第三者提供例外を明記。「データを一切保有しない」との矛盾を解消・3言語） ③7日無料トライアルの明記（**年額プランのみ**・対象条件つき。.storekit実査でmonthlyはintroなしを確認・terms3言語+特商法） ④責任上限に無償時5,000円の下限を設定（消費者契約法8条の全部免責化を回避・3言語） ⑤en免責"fit for a particular purpose"→"useful"（ja/koの「有用性」と整合）。

オーナー判断待ち1件: Apple最小EULA条項は開発者の**住所・電話番号のEULA内明記**を求める（現状は「請求時開示」）。推奨=ASCでカスタムEULAを添付せず**Apple標準EULA**を使用（この場合ページは補足的な利用規約であり最小条項の適用外・shapegap/bestswipeと同運用）。住所を公開する場合のみterms第12条8項へ追記する。

## 2026-08-13 — 無料ユーザー向け月次レポート通知＋炎ステージ昇格通知の削除（オーナー決定）

- 決定①: 炎ステージ昇格通知をバックログから削除（オーナー「いらない」）。炎ステージ機能本体（2026-08-07オーナー発案・MVP採用）は別項目として存続。
- 決定②: 無料ユーザー向け月次レポート通知を新設（オーナー「無料の人に毎月レポート送って課金誘導は必要」）。仕様: 無料のみ対象（Pro/トライアルは既存month1と排他・エンタイトルメント未解決時は登録しない）／firstLaunchDate月周年（月末丸め）／QuietHours 9-21時／先行予約ladder3本（dopabreak.freeMonthly1-3・直近1本=実数「開かなかったN回/開こうとしたM回」・2/3本目=固定文・アプリを開くたび実数更新で積み直し・休眠者へは最大3通で追撃停止）／着地=Stats（無料の当日制限statsが課金誘導の実体・通知文言に価格や宣伝は入れない）／継続サポートトグル配下。新キー lock_surface.notification.free_monthly.fixed_body（ja「この1ヶ月の記録がまとまりました」/ en "Your monthly review is ready" / ko "이번 달 기록이 정리됐어요"）。
- 実装=Codex（FreeMonthlyReportNotificationPolicy新設・カバレッジ100%）→ Opus5独立レビュー **ACCEPT WITH FIXES**: P2×1=試行0件の休眠ユーザーに「0回/0回」通知が飛ぶ→ポリシー内で0件時は全3本固定文へフォールバック（テスト先行で修正確認）。P3=集計窓の既知制約コメント移植・境界回帰テスト3件追加（月周年ちょうど/当日通過済み/深夜帯繰り延べの月跨ぎ）。レビューで健全確認: 課金者向けmonth1との排他は全状態で成立（isPro導出の構造上disjoint）・月末丸めはドリフトなし（1/31→2/28→3/31）・generation競合は既存パターン準拠・ルーティング衝突なし。
- 検証: Core 285テスト0失敗・BUILD SUCCEEDED・lint-display-copy exit 0・xcstrings 3言語完備。並行セッションと担当分担調整済み（法務ページ側はKR価格をdocs/15 §3.4正で公開・キャラ仕様書は実測値へ訂正済み=コミット時はパス指定addで巻き込まない）。

## 2026-08-15 — オンボーディング科学訴求へドーパミン機序を追加（法令審査済みの範囲で）

- オーナー依頼「科学的にドーパミン抑制に効果的など事実に基づいた訴求を入れて」→ 既存の whyScience 画面（bb74008でコミット済み・PNAS 57%＋免責3行）を土台に**差分のみ追加**。
- 法令裁定: **「本アプリがドーパミン抑制に効果的」という直接表現は不可**。①本アプリ対象の実証なし（景表法・不実証広告）②「ドーパミン抑制」は身体機能への作用標榜（非医療機器アプリに薬機法系リスク）③科学的にも機序は行動変容でありドーパミン量の抑制ではない。
- 採用した構成: **ドーパミンは敵（SNS）の説明に使い、効果は研究実績で語る**。追加キーは2つ: `onboarding.science.dopamine`（SNSの変動報酬がドーパミン回路を刺激する設計＝確立した一般科学知識・スロットマシン比喩）／`onboarding.science.mechanism`（DopaBreakは反射の入口に割り込みひと呼吸を差し込む＝機能の事実記述で効果主張なし）。ja/en/ko 3言語。
- 既存のPNAS行・免責3行・4原則・タイトルは不変（審査済み構成を崩さない）。「生理的鎮静効果を訴求に使わない」（2026-08-14決定）とも整合。
- コピーは読点ルール・英語構文カルク検査済み。文言の勝手な変更は禁止（Codexへ一字一句指定で委譲）。

## 2026-08-14 — 炎表現の全削除（オーナー決定・下記「丸い根元」エントリを同日中に無効化）

- オーナー決定: 「火の表現の質が悪いから火は全て削除しよう」。丸い根元の是正を実機確認した後の判断であり、質感修正ではなく撤去が確定。
- 削除範囲（オーナー確認済みの3判断）: ①呼吸画面（介入フロー）は炎の代わりに**キャラ（ドーパ）を常時表示** ②オンボーディングの着火演出は**演出ごと削除**（目標決定後は即時遷移） ③SF Symbol `flame.fill` も削除対象 → **`wind` へ置換**（自動化ガイド2箇所・文言「DopaBreakで一呼吸」は不変）。
- 削除ファイル: `Shaders/Flame.metal`（ディレクトリごと）・`FlameBreathView.swift`・`FlameSnapshotCapture.swift`。`InterventionFlowModel` の炎用位相（flarePhase等）は削除、呼吸タイマー・秒数カウントは維持。
- 関連整理: 炎ステージ機能（2026-08-07オーナー発案・MVP採用として存続していた構想）は前提の炎ビジュアルが消えたため**実装不可**。再開するならオーナーの再判断が必要。
- 実装=Codex → 検証: xcodegen成功・BUILD SUCCEEDED・Core 285テスト0失敗・`flame/ignition/着火/炎` 残存grep 0件（**対象はSwift/Metalのみ**）。Opus5独立レビュー: コード5観点問題なし。付随指摘: `scripts/generate-appstore-screenshots.py` が炎スクショ・炎コピー（3言語）を残存＝再生成すると審査2.3リスク（→是正）、旧BUILD_SPEC（FLAME_BREATH/FLAME_STATE）に廃止注記（→実施）。
- 下記「炎シェーダーの丸い根元シルエット」エントリは本決定により無効（コードごと削除済み）。

## 2026-08-14 — 炎シェーダーの丸い根元シルエット（同日の全削除決定により無効）

- `ios/DopaBreak/Shaders/Flame.metal` の根元フェードを、実シルエット幅で正規化した `normalizedCurrentX` に基づく円弧へ変更。中央を最も低く、左右端を最大0.150持ち上げ、既存ノイズは振幅0.018の有機的な揺らぎとして残した。
- 根元の熾火グローを横方向1.45倍、縦中心0.045／広がり0.075、アルファ0.050〜0.090へ強化し、円弧状の根元を視覚的に支える方針を採用した。
- 旧 `rootEdge` の小さな端リフトは、下端が水平な切断面に見えるため却下。炎本体・ノイズ・flare倍率・Swift側を含むその他のロジックは変更しない。
- 実装制約: `rootFade` は `smoothstep(rootStart, rootStart + 0.050, y)` を維持し、`rootGlow` のflare倍率は `(1.0 + flare * 0.72)` のまま。指定のiOS Simulator向け `xcodebuild` で `BUILD SUCCEEDED` を確認済み。

## 2026-08-14 — 呼吸演出を1呼吸へ統一・進捗ドットと数字カウントを廃止（オーナー決定「Aで進めて」）

- 問い: オーナー「カウントの数字とかいらない? 科学的に」→ 隣接文献を調査して回答し、その過程で**呼吸ペースの設計不良**を発見。オーナーが是正案Aを裁可。
- 決定①: **数字のカウントダウンは出さない**（初版から不採用。今回あらためて根拠を確定）。根拠=注意ゲートモデル（Zakay & Block 1995/1997）で、時間そのものへ注意を向けるほど主観的持続時間が伸びる。カウントダウンは3秒を3秒以上に感じさせる。占有時間は非占有時間より短く感じる（Maister）ため、呼吸アニメーションのほうが体感が短い。
- 決定②: **進捗ドットを廃止**。1呼吸化でドットが常に1個になり進捗の意味を失うため。有限性の担保（Maister「不確実な待ちは長く感じる」）は**拡縮の弧**が担う（膨らみ切って収縮へ転じた時点で折り返しが分かる非数値の連続指標）。
- 決定③: **呼吸サイクルを常に1回へ統一**（旧 `cycleCount = round(total/3)` を廃止）。旧仕様は3s:20回/分・5s:24回/分・8s:22.5回/分で、成人安静時12〜20回/分の上限〜超過。共鳴周波数呼吸は5.5〜6回/分であり、旧仕様は忠実に追従すると**速い呼吸を誘導**する設計だった。画面文言「ひと呼吸おきましょう」が3呼吸を要求する齟齬も解消。8秒設定は7.5回/分となり共鳴帯域に近づく。
- 前提の限界（訴求で誤用しないこと）: 3〜8秒はHRVが変化するには短すぎる。この介入の機序は生理的鎮静ではなく**自動化された行動を意識へ引き上げること**（行動的機序）。one secのPNAS研究（2023・280人・6週間）で効いたのも摩擦＋熟慮メッセージであり、カウントダウン表示ではない（介入時36%が閉じる・6週後に利用57%減）。生理効果を訴求文言・ASO・LPに使わない。
- 出典: Zakay & Block (1995/1997) An Attentional-Gate Model of Prospective Time Estimation ／ Maister, The Psychology of Waiting Lines ／ Grüning et al. (2023) PNAS "Directing smartphone use through the self-nudge app one sec" ／ HRV slow-paced breathing文献（5.5〜6回/分）
- 正本仕様: `design/BUILD_SPEC_BREATH_CHARACTER.md` §2・§3（2026-08-14改訂）

## 2026-08-14 — 介入呼吸ステージ「ドーパと一緒に呼吸」演出（オーナー承認）

- 決定: 炎の代替として、呼吸ステージにキャラ呼吸同期演出+ハプティクスを採用（オーナー「OKそれでいこう」）。/brainstormで検討し、呼吸円（one sec型・差別化なし）・カウントダウンリング（待たされ感）・水面/煙/粒子系（炎と同じ品質リスク構造）は却下。議事録=`.claude/brainstorm/2026-08-14_介入呼吸演出_炎の代替.md`
- 仕様（正本=`design/BUILD_SPEC_BREATH_CHARACTER.md`）: 拡縮1.00〜1.06（PNGボケ回避で上限厳守）／表情 blink（吸気）→doom（呼気）→relief（完了0.8秒前・遷移は遅らせない）／cycleCount=round(total/3)で3s:1回・5s:2回・8s:3回／進捗ドットはcycleCount>=2のみ・秒数の数字表示は廃止／CoreHapticsで吸気0.2→0.6・呼気0.6→0.15のintensityカーブ・supportsHaptics=falseは完全no-op／Reduce Motionはスケール停止・表情とハプティクス維持
- 制約: InterventionFlowModel（タイマー・世代ガード・遷移）変更禁止。新規アセット・新規カラー・新規ローカライズキー・Metal/パーティクル禁止
- 未解決: 既存3表情で「一緒に呼吸している」と感じられるか。実機確認後、不足なら中間表情の追加をオーナーへ提案

## 2026-08-14 — Launch animation face states as vectors over one glossy bitmap

- Changed `video/launch-animation/src/LaunchAnimation.tsx`, added `video/launch-animation/src/Face.tsx`, and updated explanatory comments in `video/launch-animation/src/timing.ts`. Verification stills live under `video/launch-animation/out/fix/`.
- Kept `public/frame_a0_scrolling.png` as the only character/card bitmap for every frame. The blink is now a curved SVG lid sweep; the awake state uses cream-gradient sclera, plum outlines, vertical glossy pupils with two highlights, a feathered local-glow mouth patch, and a thin smile. All face vectors share the existing `GEOMETRY.ART_SCALE` registration wrapper.
- Rejected the former `frame_b_blink.png` / `frame_c_awake.png` swap because their flat outlined, paper-grain rendering and lighter plum tile cannot match A0's near-black glossy enamel art through color correction. Also rejected vertically scaling separate upper/lower lid shapes after intermediate-frame stills showed detached horizontal bands; a continuous curved sweep mask produced a coherent blink.
- Measured/tuned on the 1024px A0 source: left eye cover `x=285–508, y=369–639` (ratios `.2783–.4961, .3604–.6240`); right `x=511–727, y=368–639` (`.4990–.7100, .3594–.6240`); mouth feather ellipse center `(507,626)`, radii `(88,72)`, clipped at `y=672`; smile spans `x=456–558`. These deliberately extend below the baked sclera to hide primary under-eye lines without painting cheek patches.
- Implementation constraints for Claude Code: keep every timing value unchanged; close is derived from `BLINK_START + BLINK_CROSSFADE + 2`, the closed hold covers `SWAP`, and opening ends at `BURST_END` (`SWAP+8`). Keep `FaceOverlay` in the same 1024-based `ART_SCALE` wrapper as A0. Do not reintroduce bitmap face swaps or move the overlay outside that wrapper; both `LaunchSquare` and `LaunchPortrait` rely on ratio geometry.

## 2026-08-14 — Launch animation vector-face review fixes (batch 2)

- Changed `video/launch-animation/src/PhoneScreen.tsx`, `LaunchAnimation.tsx`, `Face.tsx`, and `timing.ts`; updated `design/BUILD_SPEC_LAUNCH_ANIMATION.md`; removed the unused `public/frame_b_blink.png`, `frame_c_awake.png`, and `frame_a_doom.png`; verification stills are in `video/launch-animation/out/fix2/`.
- Added a rounded vector screen-off patch over `GEOMETRY.SCREEN`. It fades in as `1 - screenKill` over frames 92–100, using a dark-neutral vertical gradient (`rgb(58,55,58)` to `rgb(38,37,40)`) plus a faint diagonal reflection and inset glass shading. It is registered inside `ART_SCALE`, above A0 and below the feed/⏸ overlays; after frame 100 no live screen overlay remains.
- Recomputed the sparkle centres against `Face.tsx`'s current `awakePath` shapes: left `(304,352)` / `(0.296875,0.34375)`, right `(711.5,352)` / `(0.69482421875,0.34375)`. They mirror about the actual face axis `x=507.75` and retain at least 28.86px of empty space after accounting for the sparkle arm and sclera outline. Rejected the retired awake-bitmap coordinates because both stars landed inside the new white sclera.
- The awake-eye opening now interpolates over frames 105–112. Frame 105 remains fully closed, eliminating the first-visible-frame lid jump after the frame-104 white-out. `BLINK_CLOSE_DURATION` replaces the bitmap-era `BLINK_CROSSFADE`; unused `BLINK_END` and `SPARKLE_END` markers were removed.
- Rejected a flat black screen cover because it looked pasted over the glossy phone; retained the subdued gradient/reflection treatment. Implementation constraints: preserve the screen patch/feed/⏸ layer order, keep all screen and face geometry in the `ART_SCALE` wrapper, and keep the glint pair symmetric around `507.75/1024` if eye geometry is retuned.
- Verification: `npx tsc --noEmit` and `npx eslint src` pass. Reviewed `f30`, `f100`, `f104`, `f105`, `f112`, `f117`, `f160`, and `f179`; the screen is dark from frame 100 onward, both sparkles are visible at frame 117, and frames 104/105 show no premature lid opening.

## 2026-08-14 — 炎削除後のApp Store呼吸スクショ・呼吸タイマー是正

- 変更: `scripts/generate-appstore-screenshots.py` の呼吸モックから旧炎スクショ素材を完全に外し、実アプリと同じ `ios/DopaBreak/Assets.xcassets/Character/doom.imageset/doom.png` を透過のまま暗背景中央へ合成した。表示幅は実装の `CharacterSize.hero = 200pt` に合わせ、iPhoneは画面幅の46%、iPadは20%とした。既存のライム色グローはキャラ背面に限定して維持した。
- コピー: `breath_sub` は ja「ドーパと一緒にひと呼吸」／en-US “Take a breath with Dopa”／ko「도파와 함께 한 호흡」へ変更。炎素材の再利用・クロップ案は、実装との不一致とApp Review 2.3リスクを残すため却下した。
- タイマーとテスト: `ios/DopaBreak/InterventionFlowModel.swift` の呼吸ティックを33.3msから250msへ変更し、秒数計算・完了遷移・generation guardは維持した。`ios/DopaBreakTests/MeasurementFoundationTests.swift` では再開前に残り秒数が実際に減ったことを検証し、旧flarePhaseアサーション相当の保証を回復した。
- Claude Code向け制約: 呼吸スクショには炎由来のパス・変数・コピーを再導入せず、キャラ正本を直接参照する。呼吸ティックは描画フレーム駆動ではなく250msのカウント更新として扱い、経過時間は引き続き`systemUptime`から算出する。
- 検証: Python生成は3言語×3端末、各7枚（計63枚）で成功し、iPhone/iPadの呼吸画面を目視確認。スクショ生成スクリプト内の `flame`／`炎`／`불꽃` は0件。指定の `MeasurementFoundationTests` は14件・失敗0で `TEST SUCCEEDED`。

## 2026-08-14 — Launch animation screen-off lime-rim polish

- Changed `video/launch-animation/src/timing.ts` and `video/launch-animation/src/PhoneScreen.tsx`; verification stills are in `video/launch-animation/out/fix3/`.
- Measured `public/frame_a0_scrolling.png` with Python/PIL. The single connected lime component (`G > R + 5` and `G > B + 5`) occupies inclusive source pixels `x=391–621`, `y=733–960` (44,552 pixels). Its rounded top profile fits a 25px source radius.
- Added patch-only `GEOMETRY.SCREEN_OFF` bounds `x=389–624`, `y=731–963` and `SCREEN_OFF_RADIUS=25/1024`. The symmetric 2px guard is the smallest one that contains every measured lime pixel with that radius; a 1px guard left 19 corner-fringe pixels outside. Rejected reusing or enlarging `GEOMETRY.SCREEN`, because that would also alter the feed clip; the feed and ⏸ rectangles, all timing, layer order, gradients, and other overlays remain unchanged.
- Claude Code constraint: keep `ScreenOffPatch` on `SCREEN_OFF` and keep `PhoneScreen` on `SCREEN`; do not merge those bounds. Both remain inside the shared `ART_SCALE` registration wrapper.
- Verification: `npx tsc --noEmit` passes. Re-rendered `f100.png`, `f160.png`, and `f179.png`; PIL found zero lime-classified pixels across generous phone/screen edge regions at all three frames, and visual inspection confirmed no lime rim remains.

## 2026-08-14 — オンボーディング推計結果を年・3年・50年へ再構成

- 変更: `ios/DopaBreak/OnboardingFlow.swift` の `quizResultContent` を、年間損失日数の70ptカウントアップを主役にし、直下へSNS損失コピー、3年分の月換算、1日想定時間を含む免責、50年の人生換算を順に置く構成へ変更した。`ios/DopaBreak/Localizable.xcstrings` には新規4キーと変更2キーをja/en/koの3言語で反映した。
- 換算: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/LossEstimator.swift` に3年前提と月換算を追加し、実値を上回らないよう1桁小数へ切り捨てる方針を採用した。`ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/LossEstimatorTests.swift` で年間11/23/38/76/99/68日の全6バケットを固定した。
- 採用方針: 日次利用時間は直前回答の繰り返しになるためヒーローから外し、日→月→年と損失期間が拡大する情報階層を採用した。3年値までカウントアップさせる案は主役が競合するため却下し、年間日数だけ既存の`OnboardingCountUp`で動かす。eyebrow、lead、`CharacterSwapSequence`、50年換算は維持した。
- Claude Code向け制約: `onboardingStagger`は0〜4の既存順、Reduce Motion時の即時確定を含む`OnboardingCountUp`の仕組み、doom→worseの1.35秒切替を維持する。3年値は常に1桁小数の静的表示とし、`dailyTimeText(minutes:)`は免責の前提時間に使うため残す。削除済みの`countingDailyTimeText`や日次ヒーローを戻さず、表示コピーへハードコード改行や免責以外の句読点を追加しない。
- 検証: Simulator向け`xcodebuild`は`BUILD SUCCEEDED`。DopaBreakCoreは339テスト・失敗0。xcstringsのJSON解析、新規・変更6キーの3言語充足、表示コピーlint、`git diff --check`も通過した。

## 2026-08-14 — オンボーディング推計結果レビュー指摘3件の是正

- 変更: `ios/DopaBreak/OnboardingFlow.swift` の `quizResultContent` で、年間日数と3年月数の数字へ既存の `dopaDisplayClamp()` を適用した。両行のprefix/suffixは `lineLimit(1)`・`minimumScaleFactor(0.5)`・`allowsTightening(true)` で1行のまま縮小可能にし、数字へ高いlayout priorityを与えた。これによりENの長いsuffixも`lastTextBaseline`行内で折り返さない。
- 桁数ジッター: 年間日数は最終値と同一書式の不可視TextをZStackへ置き、カウント開始前から最終桁幅を確保した。`monospacedDigit()`だけでは1桁→2桁の幅変化を止められず、固定ptの`minWidth`はDynamic Typeと書体変更に追従しないため却下した。
- VoiceOver: ヒーロー行と3年行をそれぞれ単一アクセシビリティ要素にし、ローカライズ済みprefix・最終数値・suffixを連結した単位込みラベルを設定した。途中値は引き続き読み上げず、年間行の内部 `OnboardingCountUp.accessibilityText` も同じ完全なラベルへ更新した。
- Claude Code向け制約: `OnboardingCountUp`本体、Reduce Motion時の即時確定、1.1秒カウントアップ、`onboardingStagger` 0〜4、doom→worseの1.35秒切替は変更していない。幅予約用Textは視覚・VoiceOverの双方から隠したまま、最終値と同じ70pt rounded/monospaced/clamp書式を維持する。
- 検証: `cd ios/Packages/DopaBreakCore && swift test` は340テスト・失敗0。READMEと同じ署名なしgeneric iOS Simulator向け`xcodebuild build`は`BUILD SUCCEEDED`。`git diff --check`も通過した。

## 2026-08-14 — オンボーディング12・15のキャラクターサイズ是正

- 変更: `ios/DopaBreak/OnboardingFlow.swift` の `notificationGuideContent`（12枚目）と `readyContent`（15枚目）だけで、`.relief` キャラクターを `DesignTokens.CharacterSize.support`（88pt）から `header`（120pt）へ変更した。直前に再構成された `quizResultContent` と他ページのサイズは変更していない。
- 12枚目: 300pt高のロック画面モック、top overlay、上16pt余白、下部通知カードをすべて維持した。役割トークンの差し替えだけで整合するため、追加の固定サイズや余白調整は採用しなかった。
- 15枚目: 旧チェックマークバッジ由来の横長frame、アクセント背景、枠線、角丸clipを削除し、他ページと同じキャラクターの素置きを採用した。祝福時のscale/opacityとReduce Motion分岐は維持した。`readyCheckmarkScale` のリネームは対象外への差分を増やすため見送った。
- Claude Code向け制約: `DesignTokens.CharacterSize` 自体、12枚目の300ptパネルと上16pt配置、15枚目の祝福アニメーションを維持する。`quizResultContent` の年・3年・50年構成とレビュー是正を差し戻さない。
- 検証: README記載の署名なしgeneric iOS Simulator向け `xcodebuild build` は `BUILD SUCCEEDED`。`ios/DopaBreak/OnboardingFlow.swift` の `git diff --check` も通過した。

## 2026-08-14 — 介入呼吸ステージのキャラクター呼吸同期演出を実装

- 変更: `ios/DopaBreak/InterventionFlowView.swift` の呼吸ビジュアルを `BreathingCharacterView` へ差し替え、`ios/DopaBreak/BreathingCharacterView.swift` と `ios/DopaBreak/BreathHapticsController.swift` を新設した。描画はビュー表示開始を基準にした `TimelineView(.animation)` が担い、3/5/8秒を1/2/3サイクルへ分割して、既存キャラを1.00〜1.06でeaseInOut拡縮する。表情は吸気=`blink`、呼気=`doom`、完了0.8秒前=`relief` とし、3秒設定だけは短時間の表情過多を避けて `blink`→`relief` を直結した。`InterventionFlowModel.swift` は本タスクでは変更していない。
- 進捗とアクセシビリティ: 2サイクル以上だけ6pt・間隔8ptの進捗ドットを表示し、完了は既存 `DesignTokens.accent`、未完は既存 `DesignTokens.secondaryText` の輪郭とした。Reduce Motion時はスケールだけを1.00へ固定し、表情、進捗、Core Hapticsは維持する。新規アセット・カラー・ローカライズキー、Metal、Canvas、パーティクルは追加していない。
- ハプティクス: サイクルごとのcontinuousを吸気0.2→0.6、呼気0.6→0.15、sharpness 0.3で構成し、reliefのtransient（0.5/0.5）は独立playerで1回だけ予約した。単一playerへ混在させる案はcontinuousのintensity control curveがtransientへ干渉し得るため却下。未対応端末はエンジン自体を生成しない完全no-opとし、離脱・バックグラウンドで停止、復帰時は`systemUptime`から残りパターンを再構成する。`stoppedHandler`/`resetHandler`、世代ガード付き非同期stop、有限回リトライで失敗時も視覚演出を継続する。
- 検証ハーネス: `ios/DopaBreakTests/BreathCharacterSnapshotCapture.swift` を実ウィンドウ方式で新設し、8秒設定の `01-inhale` / `02-exhale` / `03-relief` を各10秒保持して `BREATH_STAGE_BEGIN <name>` を出力する。各表情帯の範囲内を往復するプレビューにより、10秒保持中も不連続なスケールジャンプなく呼吸を確認できる。`ios/DopaBreakTests/BreathingCharacterViewTests.swift` ではサイクル数、3秒の表情直結、relief境界、スケール上限、ドット完了境界を固定した。
- Claude Code向け制約: 描画フレームをモデルへ戻さず、モデルの250msタイマー・世代ガード・`.usageSummary`遷移を維持する。relief開始を完了0.8秒前から遅らせず、スケール上限1.06と3秒時のdoom省略を維持する。実ウィンドウハーネスのプレビューinitializerはテスト用の内部APIであり、本番ではハプティクスを伴う単発タイムラインだけを使う。
- 検証: `xcodegen generate` 成功。指定のgeneric iOS Simulator向けbuildは `BUILD SUCCEEDED`。指定Simulator `DF6A380F-D0EC-42CA-A508-0D02CEE9F404` で `MeasurementFoundationTests` 14件、`BreathingCharacterViewTests` 5件、`BreathCharacterSnapshotCapture` 1件がすべて失敗0で `TEST SUCCEEDED`。ハーネスは3つのbegin/endマーカーを順番に出力し、relief表示を実ウィンドウで目視確認した。触覚の強度・同期感と実機上の割り込み復帰は実機確認が必要。

## 2026-08-14 — オンボーディング結果・通知プレビューの再レビュー是正

- 変更: `ios/DopaBreak/OnboardingFlow.swift` の `quizResultContent` で、年間ヒーロー行と3年行の各 `HStack` に `.dynamicTypeSize(...DynamicTypeSize.accessibility1)` を付与した。数字だけでなくローカライズ済みprefix/suffixを含む行全体をAX1で頭打ちにし、ENの長い文言でも既存の `minimumScaleFactor(0.5)` を割らず省略表示を避ける。結果画面の他要素、カウントアップ、VoiceOverラベル、staggerは変更していない。
- 通知プレビュー: `notificationGuideContent` の固定300pt `ZStack` とキャラクターoverlayを、`VStack(spacing: 0) { CharacterView; Spacer(minLength: 12); notification card }` へ置き換え、パネル高を `.frame(minHeight: 300)` とした。キャラクターとカードを通常レイアウトへ入れたため、xxxL以上でも両者は重ならず、AX5ではパネルが内容に合わせて伸びる。固定高のまま位置オフセットで逃がす案は、さらに大きい文字サイズで再び衝突するため採用しなかった。
- Claude Code向け制約: パネルの `backgroundRaised`、角丸24pt、hairline枠、`onboardingStagger(3)`、120ptキャラクターの上16pt余白、キャラクターとカード間の最小12pt、通知カードの18pt内側padding・16pt外側padding・角丸18ptを維持する。`readyContent` と `quizResultContent` の上記2行以外は本是正の対象外。
- 検証: README記載の署名なしgeneric iOS Simulator向け `xcodebuild build` は `BUILD SUCCEEDED`。`cd ios/Packages/DopaBreakCore && swift test` は356テスト・失敗0。`git diff --check`も通過した。

## 2026-08-14 — 介入呼吸ステージのレビュー指摘4件を是正

- 変更: `ios/DopaBreak/BreathHapticsController.swift` のinitializerから `prepareEngineIfNeeded()` を外し、実際の再生開始まで `CHHapticEngine` を生成しない構造へ変更した。ハプティクスの `Session` は `BreathCharacterTimeline` を保持し、サイクル数・サイクル長・relief開始を映像タイムラインと同じ正本から参照する。コントローラ側の `reliefDuration = 0.8` と `round(total / 3)` の二重定義は削除した。
- 再表示復帰: `ios/DopaBreak/BreathingCharacterView.swift` の再表示では、`onDisappear` の `stop()` 後に無効となる `resume()` を使わず、`Date().timeIntervalSince(startedAt)` を `systemUptime` から差し引いた開始時刻で `start(totalSeconds:startedAtUptime:)` を張り直す。バックグラウンド復帰はセッションを保持する既存 `pause()` / `resume()` のままとし、ビュー再表示だけを新規セッション扱いにした。
- 進捗裁定: `elapsed >= reliefStart` は呼吸完了の意味として `completedCycleCount == cycleCount` を返し、画面遷移前のrelief帯で全ドットを塗る。最終サイクル境界まで未完了表示を続ける案は、reliefの「呼吸完了」意図と矛盾するため却下した。
- テスト: `ios/DopaBreakTests/BreathingCharacterViewTests.swift` に、3秒タイムライン全域を1ms刻みでスイープしてdoom不在を保証するテストと、5秒タイムラインの `reliefStart == 4.2` 前後でdoom→reliefを保証するテストを追加した。既存進捗テストも4.20秒で2/2完了する裁定へ更新し、対象は計7テストになった。
- Claude Code向け制約: 3秒時のblink→relief直結、relief開始0.8秒前、スケール上限1.06、モデルの250msタイマーと遷移条件は維持する。ハプティクスの周期・relief時刻を再定義せず、必ず `BreathCharacterTimeline` から導出する。`onDisappear` は引き続き完全停止、scenePhaseのbackground/activeは引き続きpause/resumeとする。
- 検証: 指定Simulator向け `build-for-testing` は `TEST BUILD SUCCEEDED`。対象suiteは指定コマンドへ `-parallel-testing-enabled NO` を加えた実行で7件・失敗0、`TEST SUCCEEDED`。追加フラグなしの指定原文コマンドはCoreSimulator/testmanagerd再起動後もXcodeの `waiting for workers to materialize` でテスト開始前に停止する環境側の並列worker障害を再現したため、無関係なscheme設定は変更していない。

## 2026-08-14 — オンボーディングQ1をタップ即進みに統一

- 変更: `ios/DopaBreak/OnboardingFlow.swift` の `selfCheckContent` で、利用時間を選ぶと `usageBucket` を設定して直ちに `advance()` するよう変更した。`bottomBar` と `primaryAction` では `.selfCheck` をQ2・Q3と同じボタン非表示ケースへ合流し、`singleSelectOptions` は選択値とactionクロージャを受け取る形へ揃えた。`docs/07_onboarding_design_lifefocus.md` のO-02モックから `[次へ]` を削除し、2026-08-14のオーナー承認による即進み方針を明記した。
- 採用方針: Q1〜Q3を「選択肢の1タップで次へ」に統一し、選択値の代入後に遷移することで、戻る操作では直前のQ1回答とチェックマークを保持する。Q1だけ確認CTAを残す案は、直後のQ2で操作規則が変わり戸惑いを生むため却下した。selfCheck専用の選択ボタン実装は増やさず、既存ヘルパーの責務をselection + actionへ変更した。
- Claude Code向け制約: Q2・Q3の即進み、Q3の `persistSelfCheckSnapshot()`、`progressHeader` の戻る操作、進捗・stagger・ファネルイベント、`markSelectionFeedback()` を維持する。`quizResultContent`・`notificationGuideContent`・`readyContent` は本変更の対象外。`onboarding.action.next` は `lockScreenCheck` で引き続き使うためxcstringsから削除しない。表示コピーへ読点・句点を追加しない。
- 検証: 署名なしgeneric iOS Simulator向け `xcodebuild build` は `BUILD SUCCEEDED`。`cd ios/Packages/DopaBreakCore && swift test` は356テスト・失敗0。

## 2026-08-14 — 介入呼吸演出を1介入1呼吸へ統一

- 変更: `ios/DopaBreak/BreathingCharacterView.swift` の `BreathCharacterTimeline` を3/5/8秒すべて `cycleCount = 1`、`cycleDuration = totalDuration` に統一し、複数サイクル用の剰余計算を廃止した。`reliefStart = totalDuration - 0.8`、スケール1.00〜1.06、3秒だけの `blink`→`relief` 直結は維持し、3秒特例の判定を旧 `cycleCount == 1` から `totalDuration == 3` へ分離した。
- 進捗削除: `BreathingCharacterView` からドットの `Circle` 描画、`cycleDots`、`completedCycleCount`、完了数計算、`cycleCount >= 2` 分岐、6pt/8ptのドット用数値をすべて削除した。1呼吸に1個だけのドットを残す案は進捗情報にならず、改訂仕様の「拡縮の弧を非数値の進捗にする」方針と競合するため却下した。
- ハプティクスとハーネス: `ios/DopaBreak/BreathHapticsController.swift` は `BreathCharacterTimeline.cycleDuration` から作る単一continuousイベントへ整理し、吸気0.2→0.6、呼気0.6→0.15と `reliefStart` のtransient 1回を維持した。`ios/DopaBreakTests/BreathCharacterSnapshotCapture.swift` の8秒プレビューは吸気0.2〜3.9秒、呼気4.1〜7.1秒、relief 7.25〜7.95秒の各帯域内で往復する。
- テスト: `ios/DopaBreakTests/BreathingCharacterViewTests.swift` はドット完了状態のテストを削除し、3/5/8秒がすべて1呼吸かつサイクル長=総時間であること、3秒全域のdoom不在、5秒の4.2秒relief境界、8秒の4.0秒呼気境界、全設定の1.00〜1.06上限を固定した。指定Simulator `1DCBD618-3BBB-4CB9-8E86-03F58AECD9E0` で対象6件・失敗0、スナップショットハーネス1件・失敗0。
- Claude Code向け制約: `InterventionFlowModel.swift` の250msタイマー・世代ガード・遷移条件は変更しない。ドット状態や複数サイクル式を戻さず、視覚とハプティクスの時刻は引き続き `BreathCharacterTimeline` を正本にする。新規アセット・カラー・ローカライズキーは追加していない。Core Hapticsの強度と同期感は引き続き実機確認が必要。

## 2026-08-14 — オンボーディングクイズ即進みの二重タップ退行を是正

- 変更: `ios/DopaBreak/OnboardingFlow.swift` の遷移APIを `advance(from:)` へ変更し、冒頭で現在stepと遷移元の一致を検証するようにした。既存の全呼び出しは各画面の固定 `OnboardingStep` を渡すため、遷移中に残った旧画面や完了が遅れた非同期処理からの呼び出しは無作用になる。pagerのremoval transitionには `PagerHitTestingModifier(allowsHitTesting: false)` を組み合わせ、Reduce Motion時のフェードを含めて離脱ビューをタップ不可にした。
- 欠損時の裁定: `persistSelfCheckSnapshot()` の3回答guardが失敗した場合は、既存の保存エラーalertを表示してその場に留める。不完全な回答を補完して保存する案は、自己申告データの意味を変えるため却下した。`docs/07_onboarding_design_lifefocus.md` のO-02から実装に存在しない時間帯質問を削除し、「利用時間の1タップで即次へ」と整合させた。
- Claude Code向け制約: 今後の遷移追加でも `advance(from:)` へ呼び出し元画面の固定stepを渡し、現在の `step` を引数として渡してガードを形骸化させない。Q1〜Q3の即進み、回答代入後の遷移、戻る操作、ファネルイベントを維持する。`quizResultContent`・`notificationGuideContent`・`readyContent` は変更していない。
- 検証: README記載の署名なしgeneric iOS Simulator向け `xcodebuild build` は `BUILD SUCCEEDED`。`cd ios/Packages/DopaBreakCore && swift test` は356テスト・失敗0。`git diff --check`も通過した。

## 2026-08-14 — オンボーディング推計結果の医療否認を削除（オーナー判断）

- 変更: `ios/DopaBreak/Localizable.xcstrings` の `onboarding.result.disclaimer` から医療診断の否認だけをja/en/koの3言語で削除し、推計値である旨と1日あたり想定時間 `%@` は維持した。enはja/koの「推計値」に対応させるため `An estimate` を補った。`ios/DopaBreak/OnboardingFlow.swift` の同キーの日本語 `defaultValue` も一致させ、`docs/04_functional_requirements.md` のFR-012を推計値と推計根拠（1日あたり想定時間）の明示を必須とする要件へ改訂した。
- 採用方針: 5枚目が示すのは時間の推計であって健康状態の評価ではないため、医療の枠組みを持ち込まず損失回避の感情ピークを保つ。前半の推計根拠は景表法上の実質的な守りとして残す。5枚目にも医療否認を残す案は、10枚目との重複になり訴求を弱めるため却下した。
- Claude Code向け制約: 医療・治療目的でない旨は10枚目（科学的根拠画面）の `onboarding.science.disclaimer.medical` が担うため、このキーと表示箇所は変更しない。`onboarding.result.disclaimer` の `%@` は各言語1個を維持する。`quizResultContent` のヒーロー行・3年行・人生換算行、`onboardingStagger`、免責上の8pt paddingは変更しない。
- 検証: `Localizable.xcstrings` のJSON解析、3言語の完全一致、各言語の `%@` 1個、10枚目免責セットの変更前後ハッシュ一致を確認した。README記載の署名なしgeneric iOS Simulator向け `xcodebuild build` は終了コード0。`cd ios/Packages/DopaBreakCore && swift test` は356テスト・失敗0。

## 2026-08-14 — 介入呼吸演出レビュー指摘5件の是正

- 変更: `ios/DopaBreak/BreathingCharacterView.swift` で、Reduce Motion時だけ吸気0.85→1.00・呼気1.00→0.85の不透明度呼吸を追加した。スケールと不透明度は同じeaseInOutの呼吸レベルを共有し、通常時の不透明度は1.00、Reduce Motion時のスケールは1.00、relief帯の不透明度は1.00固定とした。進捗ドットを戻す案と表情変化だけに依存する案は、改訂仕様§3・§5の有限性要件に反するため採用していない。
- 計時と整理: 同ビューの描画経過時間を`Date`差分から`ProcessInfo.processInfo.systemUptime`差分へ統一し、初回`onAppear`で開始uptimeを保持してハプティクスにも同じ値を渡す。`previewLoop`の往復計算は維持した。`BreathCharacterTimeline.cycleCount`は削除し、`ios/DopaBreak/BreathHapticsController.swift`では常に0だった`cycleStart`と`max(elapsed, cycleStart)`、`intensity`の定数引数だけを除去して強度カーブを変えていない。
- テスト: `ios/DopaBreakTests/BreathingCharacterViewTests.swift` は3/5/8秒の全区間を1ms刻みでスイープし、通常時スケールとReduce Motion時不透明度の上昇→下降の極大が各1回だけであることを挙動で固定した。不透明度とスケールがrelief前まで同一カーブであること、通常時1.00固定、relief帯1.00固定も追加検証し、8秒relief境界は`timeline.reliefStart`参照へ統一した。
- Claude Code向け制約: `InterventionFlowModel.swift`、`ios/DopaBreakTests/BreathCharacterVideoCapture.swift`、`isAutoShutdownEnabled = false`は本変更で触っていない。1介入1呼吸、3秒時のblink→relief直結、relief開始=終了0.8秒前、スケール1.00〜1.06、previewLoopの往復、視覚とハプティクスのuptime基準を維持する。
- 検証: `cd ios`相当の作業ディレクトリで`xcodegen generate`成功。指定Simulator `1DCBD618-3BBB-4CB9-8E86-03F58AECD9E0`、`-parallel-testing-enabled NO`、`-only-testing:DopaBreakTests/BreathingCharacterViewTests`で7件・失敗0、`TEST SUCCEEDED`。

## 2026-08-14 — 起動アニメ awake 目デザイン4案の比較（未採用・既定V0）

- 変更: `video/launch-animation/src/Face.tsx` に `V0`〜`V3` の比較切替を追加し、`video/launch-animation/src/LaunchAnimation.tsx` の任意 `eyeVariant` propから渡せるようにした。既定値は必ず現行の `V0`。frame 150の正方形コンポジションを `video/launch-animation/out/eyes/V0.png`〜`V3.png` に書き出し、顔を同一座標（x=340, y=390, 400×300）で切り出した左からV0/V1/V2/V3の `compare.png` も作成した。
- 比較値: V0は現行値（左 pupil=399/493/40/61、右=619/491/39/60）。V1以降は左=399/505/60/92、右=619/503/59/91。既存2ハイライトの位置・縦横径は各眼の pupil rx/ry 比率で拡大し、瞳内に収めた。V2以降は既存blinkの `sweepFill`、`launch-lid`、`launch-lid-eye-N`、`launch-lid-shadow` を増設せず、awake時の最小 `lidCoverage=0.13` として上まぶたを残す。V3は下弧を左 `M300 613 C318 642 350 657 390 660`、右 `M629 660 C669 657 700 641 716 612`、`#2D1923` / 5.2px / roundで追加した。
- 採用方針: 今回は選定材料の作成だけで、どの修正版も本採用していない。比較切替を任意propに閉じ込めてV0を既定にする方式を採用した。A0ビットマップの差し替え、眉・口・スマホ・背景・タイミング・`GEOMETRY.ART_SCALE`ラッパーの変更、比較専用コンポジションの常設は対象外として却下した。
- Claude Code向け制約: オーナー決定までは `eyeVariant` の既定 `V0` を変更しない。採用時は選定variantを既定にしてSquare/Portrait両方のblink開閉区間と最終holdを再レンダー確認する。親リポジトリの `.gitignore` は `video/` 全体を除外しているため、追跡する場合は対象を明示的に扱い、`node_modules`まで追加しない。
- 検証: 編集前V0と編集後V0のframe 150 PNGはSHA-256 `864181969f1ab3a4a45786d6d30d0a040bcb8258f9c601bc63ebda967a218ff9`で完全一致。4静止画は各1080×1080、比較画像は1632×308。`npx tsc --noEmit` と `npx eslint src` は終了コード0。

## 2026-08-14 — 起動アニメ awake 目V2を本番採用（オーナー承認「V2でおｋ」）

- 変更: `video/launch-animation/src/Face.tsx` から `EyeVariant`、V0/V1/V3用の旧瞳・下弧・条件分岐を削除し、`video/launch-animation/src/LaunchAnimation.tsx` から比較用 `eyeVariant` propを削除した。今後はV2だけを描く。比較版V2と固定後productionのframe 150はSHA-256 `a5a9c4d4310ae9627887a17765934640b97fdf08b75d3b3a08f42cd626558622`で完全一致した。
- 採用値（1024基準、`cx/cy/rx/ry`）: pupilは左 `399/505/60/92`、右 `619/503/59/91`。ハイライトは左H1 `379.5/471.819672/15.75/19.606557`、左H2 `420/536.672131/11.25/12.819672`、右H1 `599.333333/469.633333/15.884615/19.716667`、右H2 `640.179487/534.85/11.346154/12.891667`（H1 opacity 1.0、H2 0.96）。上まぶたは既存blink形状をawake時の最小 `lidCoverage=0.13` として固定した。
- 遷移裁定: animated lidと静的上まぶたを別レイヤーにせず、同じ形状のcoverageを `Math.max(animatedLidCoverage, 0.13)` で連続的に収束させる。frame 100/104/105/112/117に加えて106〜111を連続目視し、二重まぶた、1フレームの跳ね、眉との干渉がないため、静的まぶたの出現タイミングは追加変更しなかった。
- 却下: V3の下まぶた弧は隈または作画ミスに見えるため本番不採用。V0/V1/V3へ戻せる切替足場も将来の誤操作を防ぐため残さない。眉は唯一のキャラビットマップ `video/launch-animation/public/frame_a0_scrolling.png` に焼き込まれているため不変で、awake SVGへ別眉を足さない。
- 出力: `video/launch-animation/out/launch-portrait-v3.mp4`（1290×2796）と `launch-square-v3.mp4`（1080×1080）をH.264・60fps・180フレームで生成。既存 `-v2` は保持した。検証静止画は `video/launch-animation/out/fix3/` の `f30/f100/f104/f105/f112/f117/f150/f179.png`。
- Claude Code向け制約: `public/frame_a0_scrolling.png` を唯一のキャラビットマップとして維持し、口・スマホ・タイル背景・タイミング定数・パーティクル・他コンポーネントを本変更から差し戻さない。awake目を変更する場合もproductionコードへvariant switchを再導入せず、オーナー承認済みの単一形状として扱う。
- 検証: `npx tsc --noEmit`、`npx eslint src`、`npx prettier --check src`、対象ドキュメントの `git diff --check` はすべて終了コード0。production frame 150の承認済みV2との同一性、指定8静止画の1080×1080出力、portrait frame 112での上まぶた可読性も目視確認した。

## 2026-08-14 — 「夜だけ強化（nightOnly）」モード実装（オーナー指示「夜だけ強化を実装して」）

- 変更: 止める強さが3択（標準/ディープフォーカス/夜だけ強化）へ。夜だけ強化は就寝時刻→起床時刻（設定>起床・就寝時刻を流用・既定23:00→7:00）のあいだ対象アプリを完全ブロックし、日中は通常介入のみ。Pro専用。詳細設計と裁定は `.claude/specs/nightonly-implementation.md` §0 に集約。
- 主要裁定: 夜専用の時間帯設定UIは新設しない（就寝・起床を唯一の情報源にする）／夜間シールドは専用ManagedSettingsStore `dopabreak.night` で deepFocus常時ブロックと分離／窓が15分未満は「窓なし」扱い（DeviceActivityの最小監視時間）／降格は非破壊（モード設定保持・解除のみ）で処理順は「監視停止→控え削除→シールド解除」。
- 表示コピー: 夜だけ強化のdetailは「就寝から起床まで完全ブロックする」（3言語同期済み）。設定footnoteに夜専用説明キー `settings.night_only.description` を追加。
- Codex側への制約: 就寝・起床時刻のUIを変更する場合、Date↔分の変換は成分ベース（`date(bySettingHour:minute:second:of:)`）を維持する（DST切替日に±1時間ずれるためstartOfDay+分加算へ戻さない）。MonitorExtensionの夜境界ハンドラは控えのbed/wakeで窓内検算をしてから適用・解除する構造を崩さない。
- 検証: swift test 389件0失敗・BUILD SUCCEEDED。実機の夜境界発火は release-monetization-check の未実施項目として残る。

## 2026-08-15 — オンボーディング目標入力の再設計（オーナー承認「OK。あとちゃんと目標複数追加できること書いてね」）

- 決定: 目標プリセットチップ3つ（読書を30分/筋トレを続ける/資格の勉強）を廃止。理由はタップ一発でテンプレ文が目標になり「自分の言葉で書く」ことを阻害するため（介入時に表示される錨としての効きが落ちる）。参考例は「押せない例」＝プレースホルダの3例ローテーション（なりたい姿/習慣/行動、約3.5秒間隔、Reduce Motion時は1例目固定）で見せる。
- 追加コピー: リード「なりたい姿でも やることでもいい」＋複数追加注記「目標は複数追加できます。無料プランでは1つまで」（ja/en/ko 3言語、アプリ選択画面の注記パターンに準拠）。目標タブ空状態の例「例：読書30分」も「例：英語で話せるようになる」へ統一。
- 補足: 「今日の目標」表記はソースからは既に削除済み（8/14の時制ラベル禁止対応）。残っているのはDerivedData内の古いビルド産物のみ。
- 詳細仕様: `.claude/specs/onboarding-goal-input-redesign.md`

## 2026-08-15 — オンボーディング目標入力の再設計を実装

- 変更: `ios/DopaBreak/OnboardingFlow.swift` から `goalPresets`、`goalPresetChip(_:)`、`LazyVGrid` を削除し、タイトル直下へリードと複数追加注記を追加した。目標入力は3例を3.5秒間隔でクロスフェードする非操作オーバーレイへ変更し、staggerをeyebrow 0／title 1／lead 2／注記 3／入力欄 4／追加済みリスト 5へ振り直した。`ios/DopaBreak/Localizable.xcstrings` は旧placeholder 1キーとpreset 3キーを削除し、新規6キーをja/en/koで追加、`goals.empty.description` の例も英語で話せる目標へ統一した。
- 採用方針: ローテーションを入力バインディングから分離する `RotatingGoalPlaceholder` を採用した。`heroGoal.isEmpty` の間だけ存在するSwiftUIのキャンセル可能な `.task` で計時するため、入力開始と画面離脱の両方で確実に破棄される。Reduce Motion時はtask内で1例目へ戻してローテーション自体を開始しない。オーバーレイはhit testingとaccessibility treeから外し、TextFieldへ安定した読み上げラベルを付けた。
- 却下: TextFieldの標準promptだけを周期的に差し替える案は、クロスフェードと読み上げ内容を入力バインディングから明確に分離しにくいため採用しなかった。独立した常駐Timerを親Viewへ持たせる案も、画面離脱時の破棄責務が増えるため採用しなかった。
- Claude Code向け制約: IME保護コメントと `$heroGoal` のbinding、追加・保存・無料上限/paywall・スキップ・文字数カウンタ・helperは変更していない。ローテーション例の目標部分は全言語16文字以内を維持し、オーバーレイの `.allowsHitTesting(false)` / `.accessibilityHidden(true)`、TextFieldのaccessibility label、Reduce Motion時の1例目固定、View lifecycleに紐づくtask cancellationを外さない。
- 検証: `cd ios && xcodegen generate` 成功。generic iOS Simulator向け署名なし `xcodebuild ... build` は `BUILD SUCCEEDED`、`build-for-testing` は `TEST BUILD SUCCEEDED`。`OnboardingMotionCapture` は01-goal-empty / 02-goal-filledを含む5ステージを完走し1件・失敗0。iOS 18.3 Simulatorで非キャプチャ8 suiteは70件・失敗0、`cd ios/Packages/DopaBreakCore && swift test` は389件・失敗0。xcstringsのJSON解析、新規6キーの3言語完全一致、旧4キー不在、3例の16文字上限、`git diff --check`も確認済み。iOS 26.5 Simulatorでの非キャプチャsuite一括実行はコード実行前の `waiting for workers to materialize` で停止したため中断し、iOS 18.3 Simulatorで再実行して成功した。

## 2026-08-15 — オンボーディング目標入力の独立レビュー指摘8件を是正

- 変更: `ios/DopaBreak/OnboardingFlow.swift` のプレースホルダとTextFieldをfirst text baselineで揃え、ローテーションTextへ範囲外フォールバック、環境localeのtypesetting language、`minimumScaleFactor(0.85)`、`DesignTokens.secondaryText`を適用した。TextFieldには固定ラベルに加えて1例目を読むaccessibility hintを追加した。`ios/DopaBreak/GoalsView.swift` の空状態defaultValueをString Catalogのjaへ同期した。
- i18n台帳: `.claude/specs/i18n-launch-inventory.md` に2026-08-15更新行を追加し、旧placeholder/presetの4キーを新規6キーへ置換、main app総数を462へ更新した。`onboarding.goal.multi_note`の句点は承認済みコピーとして維持した。
- 採用方針: 入力前後で同じfirst baselineを共有して縦位置ジャンプを防ぎ、18pt未満の例示文はsecondary textへ上げてHIGの4.5:1目安を満たす。視覚上は3例を回しつつ、VoiceOverには安定した代表例をhintとして伝える。空配列または状態再生成時のindex不整合は空文字／先頭例へ安全にフォールバックする。
- 却下・制約: `multi_note`の句点削除はレビュー指摘#9として却下済みのため行わない。IME保護用の`$heroGoal` binding、commit時正規化、追加・保存・無料上限/paywall、進行条件、スキップ導線、Reduce Motion時の先頭固定、View lifecycleに紐づくtask cancellationは変更していない。
- 検証: `xcodegen generate`成功、署名なしgeneric iOS Simulator向けbuildは`BUILD SUCCEEDED`。iOS 26.5では`waiting for workers to materialize`でテスト本体開始前に停止したため中断し、iOS 18.3.1へ切替。`OnboardingMotionCapture`は1件・失敗0、非キャプチャ8 suiteは70件・失敗0で、両方ともxcresult status `succeeded`。旧4キー不在、GoalsのdefaultValueとカタログja一致、`multi_note`維持、`git diff --check`も確認した。

## 2026-08-15 — オンボーディング科学訴求の2ブロックを実装

- 変更: `ios/DopaBreak/OnboardingFlow.swift` の `whyScienceContent` で、既存lead直後へ `onboarding.science.dopamine`、4原則カード直後かつPNAS研究行の前へ `onboarding.science.mechanism` を追加した。表示順に合わせて `onboardingStagger` をeyebrow 0／title 1／lead 2／dopamine 3／4原則カード 4／mechanism 5／research 6／免責 7へ振り直した。
- ローカライズ: `ios/DopaBreak/Localizable.xcstrings` に上記2キーを追加し、法令審査済みの指定文言を一字一句変えずja/en/koへ登録した。6個のstring unitはすべて `state: translated`。
- 採用方針: 追加2ブロックは既存の情報階層と画面リズムを保つ `centeredLead` に統一した。同格の `CardContainer` をもう1枚増やす案は、4原則カードとの主従が曖昧になり画面が重くなるため採用していない。
- Claude Code向け制約: 追加コピーを改変せず、既存のタイトル・eyebrow・lead・4原則・PNAS研究行・免責3行を維持する。「ドーパミンを抑制/減らす/整える」「脳をデトックス」など本アプリの身体機能への効果表現、およびHRV・リラックスなど生理的鎮静効果の訴求を追加しない。表示順とstagger 0〜7も維持する。
- 検証: 新規6翻訳の完全一致、既存科学画面コピー一式のHEAD比較一致、`jq empty`、`plutil -convert xml1 -o - ... | plutil -lint -`、`scripts/lint-display-copy.py`（exit 0）、`git diff --check`を確認した。`cd ios && xcodegen generate`成功後、指定の署名なしgeneric iOS Simulator向け `xcodebuild` は `BUILD SUCCEEDED`。

## 2026-08-15 — ホーム画面の事実コピー再設計（オーナー承認「おｋ」）

- 決定: ホーム画面の文言は「事実・問い・行動」のみ（詩・比喩・掛詞の禁止を恒久ルール化）。行動語彙は「開こうとした ↔ 開かなかった」ペアに全統一し、「戻れた」「選べた」「立ち止まれた」等の解釈語を廃止。「戻る」は行動カウントの動詞に使わない（iOSの戻るボタンと衝突・戻り先が曖昧）。
- 変更: 初日タイトル「最初のひと呼吸から今日が始まる」→「開こうとした瞬間に一呼吸が入ります」（8/14指摘の解消）、実績見出し「今日 自分で選べた」→「今日 開かなかった」、metricsCard削除（実績と重複）、週サマリ事実化、キャラ状態は「今日開こうとして全敗」の時だけdoom（毎朝doom顔の解消）、目標カード空状態をアクション風表示に。
- 根本対策: コード内defaultValueとxcstringsカタログの不一致を全数監査して同期（「SNSの先ではなく、戻りたい先を決める」等の古いdefaultValueが実表示と誤認される事故の再発防止。実行時の正はカタログ）。
- 詳細仕様: `.claude/specs/home-screen-fact-copy-redesign.md`

## 2026-08-15 — ホーム画面の事実コピー再設計を実装

- ホーム画面: `ios/DopaBreak/HomeView.swift` で承認済み6キーのdefaultValueを事実コピーへ変更し、`home.first_day.title` のハードコード改行と達成率引数を撤去した。重複していた `metricsCard` / `homeMetric` と日次成功率の未使用計算を削除し、achievement→weekの間隔を24ptへ再調整した。キャラは `todayAttemptCount > 0 && todayCancelledCount == 0` のときだけdoom、それ以外はawake。目標未設定時だけ既存Dynamic Type対応の `dopaFont` でaccent・20pt・boldとし、設定済みの22pt/29pt black表示とarrowは維持した。
- ローカライズ: `ios/DopaBreak/Localizable.xcstrings` の指定6キーをja/en/koで更新し、`home.metric.count` / `.cancelled` / `.attempted` を削除した。en/koは既存の `Tried to open` / `Didn't open` / `a breath appears` と `열려고 함` / `열지 않음` / `숨 고르기` を組み合わせ、英語の件数コピーは既存と同じplural variationにした。新しい詩的表現や「戻る」系の訳語を足す案は、事実コピー方針と既存用語再利用の制約に反するため採用していない。
- defaultValue監査: `scripts/audit-default-values.py` を追加し、全Swiftの `String(localized:defaultValue:)` を対象ターゲットのxcstringsと照合できるようにした。Swift補間と `%lld` / `%@` 等を正規化し、条件式で切り替えるキーも両分岐を検査する。変更前は626呼び出し中29箇所・25キーが不一致（欠損0・未解決0）。カタログを正として11 Swiftファイルを同期し、metrics削除後の再走査は622呼び出し・不一致0・欠損0・未解決0。
- Claude Code向け制約: `home.first_day.title` へ改行を戻さない。metricsビューと3キーを再導入しない。目標空状態のaccent 20pt boldは `hasPrimaryGoal == false` のときだけ適用し、設定済み目標のタイポグラフィを変えない。ローカライズdefaultValueを追加・変更したら `python3 scripts/audit-default-values.py` を必ず0件まで実行する。
- 検証: `cd ios && xcodegen generate` 成功、generic iOS Simulator向け署名なしbuildは `BUILD SUCCEEDED`。iOS 26.5はテスト本体開始前の `waiting for workers to materialize` で停止したため中断し、iOS 18.3.1へ切替。キャプチャ4 suiteを除くDopaBreakTests全9 suiteは78件・失敗0で `TEST SUCCEEDED`。全xcstringsのJSON解析、変更6キーの3言語translated/非空、初日タイトル3言語の改行なし、削除3キーとSwift参照の不在、defaultValue再監査0件、`scripts/lint-display-copy.py` exit 0、`git diff --check`を確認した。

## 2026-08-15 — ホーム画面再設計の独立レビュー指摘6件を是正

- 監査器: `scripts/audit-default-values.py` の書式指定子を型付きセンチネルで正規化し、明示的に推定できるSwift補間型とカタログ型の差を `specifier-type` として本文差分から分離した。推定不能な補間は `?` のまま許容し、書式を含む各呼び出しにdefault/catalog双方の指定子列を出す。`LocalizedStringResource(_:defaultValue:)` の第1無ラベル引数も走査し、`ios/DopaBreak/StartInterventionIntent.swift` の12件を監査対象へ追加した。
- ターゲット解決: main catalogを使えるルートを `DopaBreak` に限定し、カタログ対応表にない `ShieldActionExtension` 等は暗黙フォールバックせず `unknown-target` にする。`ios` 配下のドット始まりディレクトリはSwift走査結果から除外する。未知の式へ変数名ベースで型を決め打ちする案は誤判定になるため採用せず、明示的constructor/cast/specifierだけを推定対象にした。
- i18n: `.claude/specs/i18n-launch-inventory.md` のホーム6キーを現行jaへ同期し、削除済み `home.metric.*` 3行を除去。JSON実数へ合わせてmain appを552キー、WidgetsExtensionを12キーに訂正した。`ios/DopaBreak/Localizable.xcstrings` はko 3件だけを既存の自然な文末へ統一し、ja/enの6キーとSwiftコードは変更していない。
- Claude Code向け制約: 新しいターゲットでlocalization APIを使う場合は `TARGET_CATALOGS` へ対応カタログを明示する。型推定不能の `?` はカタログ指定子列を人間が確認する。`intervention.success.title`（「自分で選べた」）はオーナー判断まで変更しない。
- 検証: 最終監査は634 calls、mismatches/missing/unresolved/specifier-type/unknown-targetすべて0。HomeViewの整数補間を一時的に `String(...)` 化すると `specifier-type=1`・`mismatches=0` になり、復元後0へ戻ることを確認した。未知ターゲットfixtureは `unknown-target=1`、同時に置いた隠しディレクトリfixtureは件数外。全4 xcstringsのJSON解析、ko 3件の `state=translated`、main catalog 552キー、`git diff --check`、`xcodegen generate`、署名なしgeneric iOS Simulator build（`BUILD SUCCEEDED`）を確認した。

## 2026-08-16 — 起動スプラッシュの独立レビュー指摘を是正

- 変更: `ios/DopaBreak/LaunchSplashView.swift` の純粋な表示ポリシーへVoiceOver状態を追加し、`UIAccessibility.isVoiceOverRunning` が有効なら `.voiceOver` 理由で即時スキップするようにした。表示中のVoiceOver有効化通知も非アニメで即完了する。scenePhaseによる中断は `.background` のみに限定し、`.inactive` では再生を継続する。`.backgroundResume` の終了は既存のease-outクロスフェードで統一した。
- 再生ガード: 0.8秒のstartup timeoutは再生開始前だけを監視し、3秒動画の上限は `.playbackStarted` を初めて受信した時点から動画長3.0秒＋完了マージン0.4秒を計測するよう分離した。再度のplaying通知で上限が延長されないよう状態遷移成立時だけタイマーを作る。ローカルの新規`AVPlayerItem`に不要な先頭seekは削除し、`automaticallyWaitsToMinimizeStalling = false`を設定した。
- URLとテスト: `ios/DopaBreak/DopaBreakApp.swift` のURL検証を副作用クロージャ注入型の `DopaBreakOpenURLHandler` へ最小抽出し、唯一の呼び出し元がBoolを使うため`@discardableResult`を削除した。`ios/DopaBreakTests/LaunchSplashTests.swift` へ、完了後の再表示禁止、Coordinator完了の冪等性、`.firstColdLaunchOnly`だけのUserDefaults記録、無効URL4分類、時間定数の不変条件、VoiceOverスキップを追加した。
- 却下・制約: VoiceOver中にフォーカス可能なスキップUIを追加する案は、起動時に待たせないという採用要件に反するため不採用。`.inactive`で終了する旧挙動と、`onAppear`基準の全体上限は戻さない。Reduce MotionとVoiceOverのスキップはアニメーションさせない。`ios/DopaBreak/Resources/launch-animation.mp4`を含むアセットは変更していない。
- 検証: `cd ios && xcodegen generate`成功。指定Simulator `1DCBD618-3BBB-4CB9-8E86-03F58AECD9E0`で、指定コマンドの`LaunchSplashTests`は18件・失敗0（`TEST SUCCEEDED`）。同じproject・scheme・destination・DerivedData・署名なし設定の通常buildも`BUILD SUCCEEDED`。

## 2026-08-15 — オンボーディング1枚目タグラインの是正（オーナー承認「Aでいいよ」）

- 指摘: 「開く前に選び直す」は何を選ぶのか伝わらない。原因は言い回しでなく構成で、**日本語版だけ見出しとリードの両方が問題提示**になっており、アプリが何をするかを一度も言っていなかった（en/koはリードで「ブロックではない・開く直前にブレーキ」と機構を説明済み）。
- 変更: `onboarding.welcome.tagline` ja を「開く前に選び直す」→**「ブロックしない 開く直前のひと呼吸」**。en/koはリードで機構を説明済みのため変更しない（3言語で訴求の役割分担が揃う）。
- 選定理由: 市場成熟度3〜4（Opal/one sec/スクリーンタイム）ではストレートな約束より機構の差別化が通る。インストール直後の最大の離脱理由「どうせまた使えなくするだけのアプリ」を先に潰す。「ひと呼吸」はガイド・ホーム・介入画面の既存語彙。
- 検証: humanizer-jp 23パターン検出0・英語構文カルク4テスト通過・defaultValue監査 mismatches=0・BUILD SUCCEEDED・シミュレータ実表示で1行に収まることを確認。
- 残課題（依頼外・未着手）: カタログ内で「一呼吸」と「ひと呼吸」が混在。表記統一は別途オーナー判断。

## 2026-08-15 — オンボーディング1枚目CTAの再設計（3言語transcreation・オーナー承認「ネイティブとhuminezerチェックで問題なければいいよ」）

- 指摘: 「30秒でチェックする」は何をチェックするのか画面上に手がかりがなく、離脱要因。加えて「30秒」（摩擦低減の材料）がベネフィットを置くべきボタンを占有していた。
- 構造裁定: **CTAの欠陥は3言語共通**（en "Take the 30-second check" / ko「30초 체크 시작하기」も同じく参照先なし）。タグラインがja固有だったのと対照的に、これは1枚目→クイズという導線の問題のため全言語で是正した。
- 直し方は翻訳ではなくtranscreation。結果画面の語彙が言語ごとに違うため（ja「溶けています」/ en "lost to your feed" / ko「녹고 있어요」）、各言語の結果画面と一致する語を選んだ。
- 確定文言: ja「どれだけ溶けているか見る」／ en "See the time you're losing"／ ko「1년에 며칠 녹는지 보기」。新規キー `onboarding.welcome.action_note`（ボタン直下13pt）: ja「質問3つ・30秒」／ en "3 questions, 30 seconds"／ ko「질문 3개 · 30초」。
- ネイティブレビューの反映: **en** = 英語版1枚目だけ画面に「時間」の語がなく（ja=人生の時間・ko=시간 순삭）"losing"の目的語が金銭に読めるため "the time" を明示。**ko** = ①`-고 있는지`は英語カルクで現在形`녹는지`が正 ②韓国語の「시간이 녹다」は数量が付かないと損失に読めない（中立〜肯定でも使う語）ため結果ヒーロー「1년에 약 N일」と単位を揃えた。区切り記号なしだと「1問あたり30秒」と誤読されるため全言語に区切りを入れ、enのみVoiceOver対策でカンマ。
- 実装体制の例外: **Codexが利用上限（8/20 13:22まで）**のためFableが実装し、独立性確保のためOpus5がレビュー（指摘0件）。
- 検証: humanizer-en / humanizer-ko とも exit 0（最終文言で再実行）・lint-display-copy exit 0・audit-default-values mismatches=0（calls=635）・キー総数553・BUILD SUCCEEDED・ja/en/ko 3言語をシミュレータ実表示で1行に収まることを確認。
- Claude Code向け制約: ボタン文言と`action_note`は対で扱う（片方だけ変えると「何を」「どれだけ時間がかかるか」の役割分担が崩れる）。結果画面の語彙（溶けています/lost to your feed/녹고 있어요）を変える場合はCTAも同時に見直すこと。

## 2026-08-17 — ペイウォール機能6行・目標のFree無制限化・Deep Focus説明の実動作合わせ（WS-F / オーナー決定）

- 承認の経緯（引用可能な記録・2026-08-17セッション）: 目標無料化はオーナー自身の発案「目標は無料で何個も追加できてよくないか？」→ Fableが賛成理由と影響を提示し「GO 4件」（①ペイウォール6行差し替え ②目標の無料無制限化 ③モード説明2キー修正 ④Deep Focus窓機能）として明示確認 → オーナー「OK進めて」で承認。設計書側の先行記載による昇格ではない。

- 目標のFree制限を撤廃（オーナー決定・2026-08-17）: `EntitlementGate.goalsLimit` をFree/Proとも `nil` にし、`AppContainer.canAddGoal`・`addGoal` の権利ガード・`replaceGoals` の件数チェック・`GoalsView` の追加ボタン分岐・`OnboardingFlow.addDraftGoal` の権利ガードを除去した。目標データとUIそのものは変えていない（ゲートだけを外した）。理由: 目標は「開こうとした瞬間に何のために我慢するのか」を出す介入体験の中核で、1件に絞ると使い込むほど窮屈になり継続を毀損する。一方で件数はPro購入の押し出しとして弱く、課金の主軸（アプリ数・完全ブロック・記録の全期間）と競合しない。
- 掲出箇所が消えたため `PaywallPlacement.goalsLimit`（rawValue `goals_limit`）を削除した。過去に記録済みの計測イベントは文字列としてそのまま残る（列挙からの復元経路はない）。
- ペイウォール機能リストを確定6行・確定順へ差し替えた: `unlimited_apps` → `deep_focus` → `night_block`(新規) → `usage_watch`(新規) → `full_history` → `lock_theme`。`paywall.feature.unlimited_goals`・`paywall.feature.weekly_report` は行ごと廃止しキーも削除。ja/en/koは設計契約の確定値をそのまま入れており（en/koはhumanizer監査ゲート通過済み）、改変していない。`unlimited_apps` ja だけ「〜追加できる」→「〜追加」へ短縮し全6行を言い切りで統一した。
- モード説明2キーを窓の意味論（WS-EのDeep Focus窓機能）へ合わせた: `intervention_mode.deep_focus.detail` = ja「決めた時間は選んだアプリを完全ブロック」/ en "Fully blocks your chosen apps during the times you set" / ko「정한 시간에는 고른 앱을 완전 차단」。`onboarding.mode.deep_focus.confirmation.message` = ja「Deep Focus中は選んだアプリを開けません。時間はいつでも変えられます。」で、en/koは直訳せずtranscreation（koはカタログの既存表記「딥 포커스」に揃えた）。旧文言の「作業中」「集中時間中」は実動作と一致していなかった。
- 却下・制約: `app.error.goal_pro_required` はキーだけ残した（WS-Fのxcstrings変更範囲を `paywall.feature.*` / `intervention_mode.*` / `onboarding.mode.deep_focus.confirmation.message` に限定する取り決めのため）。参照は全て消えているので、掃除は別バッチで行う。`goalsLimit`・`canAddGoal` のAPIは無制限を返す形で残してある（呼び出し側の型と既存テストの構造を保つため）。ペイウォール6行のja/en/ko値とその並び順は確定値なので、後続の作業で言い換えない。
- 検証: Core `swift test` 389件・失敗0。`xcodegen generate` → 署名なしgeneric iOS Simulator build `BUILD SUCCEEDED`。Simulator `1DCBD618-3BBB-4CB9-8E86-03F58AECD9E0` の `DopaBreakTests` 112件・失敗0（`TEST SUCCEEDED`）。`python3 scripts/lint-display-copy.py` exit 0（検出2件は本作業と無関係の既存 `onboarding.preview.step2/3`）。xcstringsのJSON解析OK・キー総数557。

## 2026-08-17 — Opal競合分析3施策: 「取り戻せる時間」ステップ・ショートカット選択モック・トライアル通知の事前選択（オーナー承認「1,3,4進めていい」）

- 経緯: オーナーがOpalのオンボーディング動画を提示→活かせる点6件を提案→「1,3,4進めていい」で3件のみ承認（回答エコー/名前入りサマリー/ブランド比喩回収は未承認・見送り）。無料トライアルは既存（年額の7日導入オファー・docs/15 §2）で、8/11廃止のリバーストライアルとは別物と確認済み。
- 施策A: `OnboardingStep` に `recovery`（id `recovery_estimate`）を quizResult 直後へ新設し15→16ステップ化。損失側（1年で約◯日が溶ける）と対になるグッドニュース画面で、`max(1, yearlyDays / 2)` の**条件付き算術**（「開く回数を半分にできた場合」）のみを表示。効果の断定・保証表現は景表法対応で不使用。ヒーロー数値はquizResultと同じ作法（桁幅確保hidden・monospacedDigit・OnboardingCountUp・accessibilityLabel）、キャラはdoom→awakeで損失側のdoom→worseと対。
- 施策B: `automationGuideContent` に「選択画面のイメージ」モックカードを追加。つまずき2箇所（「開かれたとき」vs「閉じられたとき」・「すぐに実行」vs「実行の前に尋ねる」）を正解=アクセントリング＋「ここを選ぶ」バッジ／誤答=減光で図解。OS UIのクローンではなくDesignTokensの模式図。モックは1要素にまとめた要旨accessibilityLabel付き。信頼コピー「検知するのは選んだアプリを開いたことだけです。〜」を追加（Opalの権限プライミングの翻案）。
- 施策C: 固定Day5トライアル通知を選択制へ一般化。Core側 `TrialReminderLeadDays`（standard=2 / allowed=[2,3] / normalized丸め）＋ `trialReminderDate(from:leadDays:)`（fireDay=7-leadDays・1...6クランプ）。既存 `trialDay5Date` はleadDays=2の互換ラッパー。`SettingsStore.trialReminderLeadDays`（既定2・resettable）。PaywallViewは年額選択中かつ導入オファー対象時のみ planList と legalArea の間にカード表示（セグメント2日前/3日前・購入処理中はdisabled）。通知identifier（dopabreak.trialday5）と本文は不変（「7日目に年額プランへ切り替わります」は3日前でも事実として正）。
- ko判断: モックのラベルは既存カタログ `onboarding.automation.step3/4` の確定表記（「'열림' 선택」「'즉시 실행' 선택」）に揃え「열림/닫힘」を採用（同一画面内の表記割れ回避を優先）。
- 実装体制: **Codex利用上限（〜8/20 13:22）のため実装=Opus5サブエージェント／レビュー=Fable**（8/15前例と同じ独立性確保）。レビュー指摘0件で受け入れ。
- Claude Code向け制約: recoveryの数値は条件付き試算のまま維持し「◯%減らせます」等の効果断定へ言い換えない。quizResultの語彙（溶けています系）を変える場合はrecoveryの対語彙（戻ります系）も同時に見直す。トライアル通知の許容値を増やす場合は `TrialReminderLeadDays.allowed` とペイウォールPickerのtagを対で更新する。
- 検証: xcodegen成功・署名なしgeneric Simulator build `BUILD SUCCEEDED`・Core swift test 454件/失敗0・DopaBreakTests（UDID 1DCBD618・キャプチャ除外）130件/失敗0 `TEST SUCCEEDED`・audit-default-values 0（calls=678）・lint-display-copy exit 0・xcstrings新規20キー3言語translated・humanizer-en/ko両audit exit 0・`git diff --check` clean。
- 残課題（未実装・依頼外）: OnboardingMotionCaptureへのrecoveryステージ追加（`("03b-recovery", .recovery, false)` で足りる）／購入後にリマインダー日を変える設定導線なし（購入前選択が主経路）／オンボ16ステップ化に伴うrecovery_estimate離脱率の計測観察。
- 追記（2026-08-17・オーナー決定「OK維持で」）: ペイウォールの「無料期間が終わる前に通知でお知らせします」カードは**維持で確定**。オーナーから「CV逃す設計では」「離脱よりCVRが上回るのか」と2度問われ、①Blinkist A/B実測（トライアル開始+23%・トライアル継続+4%＝解約は増えず減少・苦情-55%）②自動更新の法定表示（3.1.1）とAppleの終了前メールにより「課金の恐怖」は元から画面と導線にあり、カードは安全弁のみ追加 ③Duolingo・Opalも常設という3点を提示して承認。判定指標はDL→トライアル開始率（SOSA中央値5.7%/目標8%）で観察。**このカードの存廃を再提案する場合はこの決定を先に示すこと**。

## 2026-08-18 — ペイウォールのゼロ価格フレーミング「7日間無料」→「7日間 ¥0」（オーナー承認「OK入れよう」）

- 経緯: オーナーがXのポスト（@kedytcom・「7 days free」→「7 days $0」の1語変更でCVR+35%と主張）を提示し `/brainstorm` で評価を依頼。**+35%は自己申告・n不明・メトリクス未公開（リプで請求され「Tomorrow」のまま）のため採用しない**が、①「無料」はセールス語として説得知識モデルの警戒フィルタに掛かる／「¥0」は数字＋通貨記号で価格スキーマとして処理される ②同一カード内の「¥4,980」と数字同士で対比が成立 ③コストほぼゼロ・完全可逆、の3点で期待値が正と判断し条件付き採用。効果の期待値は1桁%（未確認の推定）。議事録: `.claude/brainstorm/2026-08-18_paywall-zero-price-framing.md`
- 🔴 **通貨記号のリテラル記述を恒久禁止**（本件で確立）: 「¥0」を文字列やxcstringsへ直書きすると、日本語UIでも米国ストアの利用者（USD課金）に¥0が出て実際の請求通貨と食い違う。景表法・審査3.1.1の両面でリスク。**必ず `Product.priceFormatStyle` に通貨を決めさせる**。シミュレータ実査で「$39.99の隣に¥0が並ぶ」状態が実際に再現可能と確認済み（ローカル.storekitはJPY定義だが実効環境はUSDだった）。
- 実装: `ios/DopaBreak/StoreService.swift` に純粋enum `IntroOfferDisplayPolicy`（既存 `PaywallDismissalPolicy` と同じポリシー分離パターン）を新設。`zeroPriceText` は `product.priceFormatStyle.precision(.fractionLength(0)).format(0)`（precision指定なしだとUSDで "$0.00" になるため必須。現行SDKでそのまま通る）。`updateAnnualIntroOfferInfo` のguardで `activeAnnualProduct` を束縛し `freeTrialText(for:product:)` へ渡す。
- 3段フォールバック: ①期間＋ゼロ価格が揃う→`store.intro_offer.zero_price`（正常系）②ゼロ価格がnil/空白/**数字を含まない**（書式崩れで記号だけになった場合）→既存 `store.intro_offer.free`（「7日間無料」）③期間も取れない→`store.intro_offer.available`（「無料期間あり」）。空文字や壊れた表示にはならない。
- 新規キー `store.intro_offer.zero_price`（**位置指定子必須**・語順が言語で逆転するため）: ja `%1$@ %2$@`→「7日間 ¥0」／ en `%2$@ for %1$@`→「$0 for 7 days」／ ko `%1$@ %2$@`→「7일 ₩0」。%1$@=期間・%2$@=ゼロ価格。
- Claude Code向け制約: **CTA `paywall.action.start_free`（「7日間無料で始める」）をゼロ価格化しない**（CTAに金額を入れないオーナー恒久指示・2026-07-28）。`paywall.legal.annual_intro`（自動更新の法定表示）・`paywall.plan.annual.intro_fallback`（商品未取得時の異常系のため通貨不明）・`paywall.trial_reminder.*`（散文）・`store.intro_offer.duration.*` も不変。`store.intro_offer.free` はフォールバックで現役のため削除しない。位置指定子を1つでも落とすと3言語のいずれかで表示が壊れる。
- 検証: xcodegen成功・署名なしgeneric Simulator build `BUILD SUCCEEDED`・Core swift test 454件/失敗0・DopaBreakTests（UDID 1DCBD618・キャプチャ除外）**142件/失敗0**（新規 `IntroOfferDisplayTests` 15件含む）`TEST SUCCEEDED`・audit-default-values 0（calls=679）・lint-display-copy exit 0・`jq empty`と3言語translated・`git diff --check` clean。**実機表示（UDID DF6A380F）で「年間$39.99を一括請求・7日間 $0」を確認し、¥が混入しないことを実査**。Fableレビューで位置指定子の語順逆転を `String(format:)` により独立検証（en→"$0 for 7 days"）。指摘0件で受け入れ。
- 実装体制: Codex利用上限（〜8/20 13:22）のため実装=Opus5サブエージェント／レビュー=Fable。
- 効果測定: リリース前でトラフィックがゼロのためA/B検出不能。**理論で選んで置く変更**であり、リリース後はDL→トライアル開始率（SOSA中央値5.7%・目標8%）の方向監視のみ。下振れしたら1語戻す（二方向ドア）。

## 2026-08-20 — App Storeスクリーンショット v2 対角ライム×Dopa（ja / iPhone 6.9インチ）

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` を新設し、`output/app-store-screenshots/v2/ja/iphone-69/01-hook.png`〜`07-privacy-settings.png`、`output/app-store-screenshots/v2/contact-sheet-ja.png`、`output/app-store-screenshots/v2/slots.json` を生成した。既存 `scripts/generate-appstore-screenshots.py` は変更していない。
- 採用方針: `.claude/specs/appstore-screenshots-v2-diagonal.md` の7構図・確定コピー・色面座標・キャラ表情/レイヤー順を固定値で実装した。旧ジェネレータは `importlib.util.spec_from_file_location` で読み、font・縦グラデ・`source_for`（raw 3枚＋mock 4枚）を正本として再利用した。デバイスは画面比1320:2868から高さを導出し、W_out×2.75%ベゼル、W_out×14.8%外形角丸、チタン縦グラデ、1pxリム、Dynamic Island、12%ガウス影を一つの描画経路に統一した。
- キャラ合成: 指定幅で1024² RGBAをリサイズし、反転→回転（expand）の順で処理した。指定の中心X/下端Yは回転後の透明余白ではなく実ピクセルのalpha bboxへ合わせ、黒35%・blur40・(0,30)影を付けた。03/06/07は幅70%×高さ90の接地楕円影（黒30%・blur30）を追加した。02の腰掛け位置は透明な回転バウンディング角ではなく、丸角リム左上の45°実輪郭点へ接触させた。
- コピー裁定: 全文字列、40px W8ピル（横34/縦16）、112px W8見出し、26px行間、44px W4サブを維持した。06の確定2行目だけは112pxの縦スケールと文字列を保ったまま横幅1240pxへ収めた。原寸のHiragino W8では1568pxとなり、無処理だと左右124pxずつ欠けて「改変禁止」の全文表示を満たせないためである。文字削除、3行化、フォントサイズ縮小は却下した。
- `slots.json`: 各画面について回転前のデバイスローカル `x/y/width/height`、回転中心・角度、回転後の画面四隅、画面外を含むcanvas bounds、キャラの実alpha bboxを記録した。画面差し替え時は `screen_corners` の順（top_left→top_right→bottom_right→bottom_left）を維持する。
- Claude Code向け制約: 本版はja / `iphone-69` / 1320×2868専用。コピー・座標・レイヤー順をレスポンシブ換算しない。raw UIを更新する場合も外枠と`slots.json`の幾何は変えず、`source_for`の1320×2868ソースだけを差し替える。旧ジェネレータへの逆移植、キャラの透明余白基準配置、02の透明バウンディング角への接地は戻さない。
- 検証: スクリプト内assertと独立再検査の両方で7枚すべてPNG/RGB/1320×2868、コンタクトシートPNG/RGB/2800×869、`slots.json` 7件・各1スロットを確認した。7枚横並びの原寸コンタクトシートと全7枚を目視し、コピー欠け、キャラ/フォンの不正な前後関係、丸角接地点の浮きを確認・是正した。

## 2026-08-20 — App Storeスクリーンショット v2 の04キャラ前面化・接地影強化

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` の04 `modes` を、フォン描画後に `worse`（幅340・回転+8°・中心x1105・下端y2000）を合成する前面構成へ変更した。旧い左端・フォン背後の描画順は削除し、キャラのドロップシャドウが画面と右ベゼルへ落ちるようにした。03/06/07の接地キャラは楕円本体を各キャラ下端Yから下側へ描く方式に変更し、07のフォンにも幅527（620×0.85）・高さ110・黒35%・blur40の接地影を追加した。
- 出力更新: `output/app-store-screenshots/v2/ja/iphone-69/01-hook.png`〜`07-privacy-settings.png`、`output/app-store-screenshots/v2/contact-sheet-ja.png`、`output/app-store-screenshots/v2/slots.json` を再生成した。詳細仕様 `.claude/specs/appstore-screenshots-v2-diagonal.md` も新しい04構図と接地影仕様へ同期した。
- 採用方針・却下案: 接地楕円を下端Y中心へ置く旧方式は影の上半分がキャラやフォンに隠れて視認性が落ちるため却下した。楕円本体を下端直下へ全置きし、blurだけを接点側へ戻す方式を採用した。これにより地面→接地影→対象物のレイヤー順を明確にしつつ、浮いて見えない接点を維持する。
- Claude Code向け制約: 04は必ずフォンを先、キャラを後に描く。03/06/07のキャラ影は幅=キャラ幅×0.70・高さ90・黒30%・blur30、07のフォン影は幅=フォン外形幅×0.85・高さ110・黒35%・blur40を維持し、どちらも未ぼかし楕円の上端を対象物の可視下端Yに合わせる。`slots.json` の `character.ground_shadow` と07 `slots[0].ground_shadow` は接点・box・寸法・濃度・blurの検証情報として維持する。
- 検証: ジェネレータを再実行し、内蔵assertと独立検査で7枚すべてPNG/RGB/1320×2868、コンタクトシートPNG/RGB/2800×869、`slots.json` 7件・各1スロットを確認した。04は可視alpha bbox `(943,1688,1266,2000)` でキャンバス内に収まり、フォン右端x1090をまたぐ前面配置を確認。03/06/07は原寸クロップで影を目視し、影中心と同Yの未遮蔽ライム地面との平均輝度差を03=54.0、06=47.0、07フォン=69.7、07キャラ=49.3として視認性を確認した。

## 2026-08-20 — App Storeスクリーンショット v2をコア実画面へ差し替え

- 作成・変更: `ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` を新設し、`ios/DopaBreak/InterventionFlowView.swift` と `ios/DopaBreak/PostUseReflectionSheet.swift` にDEBUG限定の撮影初期化経路を追加した。実ウィンドウ＋`drawHierarchy`、ダークモード、ja、専用一時コンテナのシード（目標「英語で商談できる自分になる」・本日15試行/開かなかった12回・7日分記録）で `output/app-store-screenshots/raw-core/ja/{breath,intent,home,stats,goals,reflection}.png` を生成した。非オンボーディング・非設定ルートの独立modes UIは存在しないため、仕様どおり04は`home.png`へフォールバックした。
- v2差し替え: `scripts/generate-appstore-screenshots-v2.py` の01/02/03/04/06/07を順にstats/breath/intent/home/reflection/goals実画面へ変更し、05だけ`mock_lock()`を維持した。既存コピー・背景色面・フォン幅/回転/座標は変えていない。`output/app-store-screenshots/v2/ja/iphone-69/`の7枚、`contact-sheet-ja.png`、`slots.json`を再生成し、`.claude/specs/appstore-screenshots-v2-diagonal.md`の画面ソースと構図説明も同期した。
- 1枚1体の裁定: 実測で画面内キャラはstats=0 / breath=1 / intent=0 / home=1 / reflection=1 / goals=0。したがって外乗せを02 blink・04 worse・06 reliefから外し、01 doom・03 awake・05 awake反転・07 reliefだけ維持した。`slots.json`へ`character_count.screen/external/total`を記録し、生成時に合計1以下をassertする。満足度未選択の`PostUseReflectionSheet`は先頭1体＋選択肢5体で計6体になるため却下し、満足感を選択した直後の「幸福感や集中力は上がった？」実入力段階（シートをStatsView背景ごと提示）を採用した。
- Claude Code向け制約: DEBUG限定initializerは撮影専用で、本番の`flow.start()`・理由選択・反映保存経路を置き換えない。04は独立modes実画面が追加されるまでhomeフォールバックを維持する。raw差し替え時は必ず画面内キャラ数を再実測し、外乗せとの合計を1体以下にする。reflectionを満足度未選択段階へ戻す場合はアプリ実画面だけで6体になるため不可。
- 検証: 指定iPhone 16 Pro Max Simulator `90F5A09F-D128-468C-AB02-7ABB1479B3AE`へ`status_bar override --time 9:41`を適用し、`CODE_SIGNING_ALLOWED=NO`・ja/JP・対象XCTestの`xcodebuild test`は1件/失敗0で`TEST SUCCEEDED`。raw 6枚と最終7枚はすべてPNG/RGB/1320×2868、contact sheetはPNG/RGB/2800×869、slotsは7件・各1スロット・全total=1。raw 6枚、最終7枚、contact sheetを目視し、日本語、シード値、シート表示、コピー欠けなし、各枚キャラ合計1体を確認した。

## 2026-08-20 — App Storeスクリーンショット v2の05全面再設計・Opus5レビュー是正

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` を一括修正し、`output/app-store-screenshots/v2/ja/iphone-69/01-hook.png`〜`07-privacy-settings.png`、`output/app-store-screenshots/v2/contact-sheet-ja.png`、`output/app-store-screenshots/v2/slots.json` を再生成した。設計正本 `.claude/specs/appstore-screenshots-v2-diagonal.md` も新しい05構図と02/03/04/06の確定座標へ同期した。
- 05方針: 旧日の出壁紙＋単一目標カードを廃止し、`#0B0D0F`系の控えめな抽象グラデ壁紙、中央の南京錠、右上Wi-Fi/バッテリー、日付「8月20日 木曜日」、SFNS variable fontのsemibold寄り・画面幅55%の「9:41」、フラッシュライト/カメラ、ホームインジケータを持つiOSロック画面へ全面置換した。Live Activityは壁紙ぼかし＋暗色半透明＋上辺ハイライトのliquid glassカードとし、AppIcon/`DOPABREAK`、メイン目標「英語で商談できる自分になる 今日 開かなかった 12回」、補助目標「朝のランニングを続ける 8回」「読書を30分する 5回」をヒラギノ/SFNSの実フォントで描画した。旧写真壁紙、7:00、1目標だけのカードは訴求と指定状態に合わないため却下した。
- 05構図: ライム円を中心`(660,1800)`・半径680、フォンを外形幅900・回転0°・上端y880・全体表示（box=`[210,880,1110,2777]`）、awake反転を幅320・回転-12°・可視中心x250・可視下端y1150へ変更した。画面内キャラ数は0、外乗せ1、合計1を維持する。AppIcon内のブランド図像はLive Activityのアプリアイコンであり、画面内キャラクター表示としては数えない。
- レビュー是正: 共通中央テキスト関数から横方向`resize`を削除し、自然幅超過時は`floor(base_size × max_width / natural_width)`のフォントサイズで実フォントを再描画する。06第2行は自然幅1568pxから88px W8（描画幅1232px）となり、第1行112pxとともに横スケール比1.0・中心x660を維持した。02中心を`(660,2030)`、03を`(475,2020)`、04上端を1080、06を`(845,2020)`へ変更し、03/06の外形左右端は連続座標で`-0.02`/`1320.02`（旧5px超過を解消、アンチエイリアス誤差0.02px）となった。
- 堅牢化: `LEGACY_PATH`ガードを`load_legacy()`のモジュール実行前へ移し、全`assert`を明示的な`if not: raise`検証へ置換した。全`Image.open`は`with`内で即`convert`する。キャラ接地影幅は`place_character(width=...)`内部で`width × 0.70`から算出し、キャラ幅リテラルの二重管理を廃止した。`slots[0].ground_shadow`は全7枚に常設し、影なしは`null`とする。
- 04キャプチャ判断: `ios/DopaBreak/HomeView.swift`を全体確認したが、存在するのはヒーロー、目標、今日/今週実績、自動化確認であり、Deep Focus窓または標準/Deep Focus/夜だけ強めのモードカード・コントロールは存在しない。実在しない状態を作らず、`output/app-store-screenshots/raw-core/ja/home.png`を現状維持した。将来`HomeView`へ該当UIが追加された場合のみ、スクロール位置を固定した再キャプチャを行う。
- Claude Code向け制約: 05のロック画面は旧ジェネレータの`mock_lock()`へ戻さず、v2側の`mock_lock()`を正本にする。時計はSFNS variable font、和文はヒラギノを維持し、文字入り画像へ置換しない。06の横リサイズを復活させず、`copy_geometry.headline_metrics[].horizontal_scale_ratio`は常に1.0とする。slotsを読む側は全slotに`ground_shadow`がある前提で、`null`を影なしとして扱う。
- 検証: `PYTHONDONTWRITEBYTECODE=1 python3 -O scripts/generate-appstore-screenshots-v2.py` が成功。独立PIL/JSON/AST検査で7枚すべてPNG/RGB/1320×2868、contact sheet PNG/RGB/2800×869、slots 7件・各1slot・全slotに`ground_shadow`、キャラ合計`[1,1,1,1,1,1,1]`、05=`screen 0 / external 1 / total 1`、スクリプト内`ast.Assert` 0件を確認した。05/06/コンタクトシートと全7枚を原寸目視し、05の3目標、時計/日付/上部・下部システム要素、06の非圧縮字形、コピー欠けなしを確認した。

## 2026-08-20 — App Storeスクリーンショット v2 オーナー差し戻し2件（フォン大型化・05実装準拠）

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` の全7枚でコピーYを eyebrow/headline/sub=`240/340/680`へ統一し、フォン外形幅を01=`1060`、02=`1000`、03=`980`、04=`1060`、05=`1000`、06=`980`、07=`780`へ拡大した。角度は指定どおり`0/-7/+8/0/0/-8/0°`、位置は01上端1050、02中心`(660,2100)`、03中心`(560,2050)`、04上端1000、05上端830、06中心`(760,2050)`、07下端2620へ固定した。外乗せは01 doom=`440/-6°/(cx1030,bottom1330)`、03 awake=`400/(cx1080,bottom2350)`、05 awake反転=`300/-12°/(cx230,bottom1050)`、07 relief=`340/(cx1140,bottom2620)`へ変更し、02/04/06は外乗せなしを維持した。
- 05 Live Activity: `ios/WidgetsExtension/DopaBreakWidgets.swift` の `liveActivityView()` を正本として全面差し替えた。カードは左右14pt相当、背景`rgb(20,23,27)`、左端3ptの`rgb(184,255,61)`バー、内側16pt、VStack 10pt、eyebrow 10pt bold、3目標は各15pt bold＋10×2ptバー／行間5pt、1px区切り、実績行12pt W6相当・間隔14ptで構成した。AppIcon、`DOPABREAK`、`LIVE ACTIVITY`、右寄せ回数、目標ごとの区切り線、旧liquid-glass処理は実装と異なるため削除した。カードsource boxは`[42,1860,1278,2280]`、最終canvas boundsは`[218.04,2188.15,1101.96,2488.50]`で全体表示する。
- 採用方針・却下案: フォン幅と回転角はオーナー指定を厳守し、下端クロップを許容して機能画面の占有率を上げた。キャラ座標だけを可視alpha bbox基準で微調整し、全身をキャンバス内に残した。05のフォン全体表示チェックは下端クロップ要件と衝突するため廃止し、代わりにLive Activity source boxをフォン画面座標からcanvasへ射影して完全表示を検証する方式へ変更した。見出しの横リサイズ、旧05ヘッダー、1枚2体以上になる外乗せは採用していない。
- 仕様同期: `.claude/specs/appstore-screenshots-v2-diagonal.md` を新しいコピー座標、フォン／キャラ座標、05カード仕様へ更新した。`output/app-store-screenshots/v2/ja/iphone-69/01-hook.png`〜`07-privacy-settings.png`、`output/app-store-screenshots/v2/contact-sheet-ja.png`、`output/app-store-screenshots/v2/slots.json` を再生成した。
- Claude Code向け制約: 各フォンの外形幅・回転角と共通コピーYは固定値として維持する。05は端末下端がキャンバス外でもよいが、`slots[0].live_activity_card.fully_visible`は常にtrueでなければならない。外乗せキャラは指定4枚だけ、可視alpha bboxを1320×2868内へ収め、画面内キャラとの合計を1以下にする。見出しは実フォントサイズで収め、`horizontal_scale_ratio=1.0`を崩さない。
- 検証: `PYTHONDONTWRITEBYTECODE=1 python3 -O scripts/generate-appstore-screenshots-v2.py` は成功。独立PIL/JSON/AST検査で7枚PNG/RGB/1320×2868、contact sheet PNG/RGB/2800×869、指定7幅・7角度・7位置、全コピー`240/340/680`、sub下端740以下、キャラ合計全枚1、外乗せ4体の全身収まり、05カード完全表示、全14見出し行の横スケール1.0、旧05要素不在、カード／アクセントの指定RGB、`ast.Assert` 0件を確認した。全7枚とcontact sheetを原寸目視し、主要UI非遮蔽、01/03/05/07の重なり、03/07の接地影、05の3目標と実績行、見出し字形の非歪みを確認した。

## 2026-08-20 — App Storeスクリーンショット v2の01コピー面・07目標3件を是正

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` の01ライム多角形を `(0,200)(1320,80)(1320,1080)(0,1420)` へ拡大し、`ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` のシードへ「朝のランニングを続ける」「読書を30分する」を追加した。`testCaptureGoalsScreenInJapanese()` を追加して `output/app-store-screenshots/raw-core/ja/goals.png` だけを再キャプチャし、`output/app-store-screenshots/v2/ja/iphone-69/`の7枚、`contact-sheet-ja.png`、`slots.json` を再生成した。詳細仕様 `.claude/specs/appstore-screenshots-v2-diagonal.md` も同期した。
- 01の採用方針: 上のダーク三角を残したまま、eyebrow/headline/sub=`240/340/680` の全コピー矩形をライム面へ入れた。コピーを下へ動かす案は共通Y固定とフォン上端1050の構図を崩すため却下した。フォン幅1060・上端1050、doomの幅440・中心x1030・下端y1330は変更していない。生成時は4倍AAの多角形マスクに対し、ピル・見出し2行・サブの各矩形が全ピクセル255かを必須検証し、結果を `copy_geometry.lime_surface_validation` へ記録する。
- 07の採用方針: 3目標は「英語で商談できる自分になる」「朝のランニングを続ける」「読書を30分する」の順で、カテゴリはその他／健康／学びとした。全6画面を撮り直す案は既存rawの不要な差分を生むため却下し、同じシード経路を使うgoals専用XCTestだけを指定Simulatorで実行した。他のraw 5枚はSHA-256と更新時刻が撮影前後で不変。
- Claude Code向け制約: 01の多角形、共通コピーY、フォンとdoomの幾何、ピクセルマスク検証を維持する。07を更新するときは `testCaptureGoalsScreenInJapanese` を `-only-testing` で実行し、他rawを上書きしない。3目標のタイトルと並びは05 Live Activityの文言と一致させ、画面内キャラ0＋外乗せrelief 1の合計1体を維持する。
- 検証: Simulator `90F5A09F-D128-468C-AB02-7ABB1479B3AE` のstatus barを9:41へ固定し、goals専用XCTestは1件・失敗0で `TEST SUCCEEDED`、rawはPNG/RGB/1320×2868。macOS Vision OCRはrawと最終07の双方から3目標を完全一致で認識した。独立PIL検査では01の4コピー矩形すべてでライムマスクextrema=`(255,255)`、ピル上端y=240・その幅内の上境界最大y=161・余白79px。最終7枚はすべてPNG/RGB/1320×2868、contact sheetはPNG/RGB/2800×869、slotsは7件・各1slot、キャラ合計は全枚`[1,1,1,1,1,1,1]`。01・07・contact sheetも原寸目視で確認した。

## 2026-08-20 — App Storeスクリーンショット v2へ追加パネル08〜10を実装

- 作成・変更: `ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` に追加3画面専用の `testCaptureAdditionalSettingsScreensInJapanese()` を実装し、`output/app-store-screenshots/raw-core/ja/{deepfocus,nightmode,grayscale}.png` を生成した。`scripts/generate-appstore-screenshots-v2.py` は08 `deep-focus`、09 `night-block`、10 `grayscale-guide` と確定コピー／ソース／キャラ数を追加し、`output/app-store-screenshots/v2/ja/iphone-69/01-hook.png`〜`10-grayscale-guide.png`、4000×869の `contact-sheet-ja.png`、10件の `slots.json` を再生成した。
- 実画面キャプチャ: 既存と同じ実ウィンドウ＋`drawHierarchy`、ダーク、`ja_JP`、Dynamic Type Largeを維持した。Deep Focus対象はテスト用 `ApplicationToken` 1件、即時4択、月〜金、20:00〜22:00、起床7:00／就寝23:00をシードした。08/09は縦`UIScrollView.contentOffset`を直接60へ指定（調整後実値112）して「完全ブロック」節見出しから必須UIまでを表示した。10はLazyVStackの遅延レイアウトでcontentSizeが伸びるため最大6回、直接bottomへ合わせ、最終offset=maximum=3207として白黒ガイドのステップ1/2とオン／オフを同居させた。初回のoffset 255/180は節先頭または「夜だけ強化」行を隠すため却下した。
- 構図・コピー: 設計正本 `.claude/specs/appstore-screenshots-v2-diagonal.md` の「追加パネル 08〜10」をそのまま採用した。08は鏡像ライム多角形＋幅1060の直立フォン＋blink 440/+6°、09は逆勾配ライムリボン＋幅1000/+7°フォン＋右上のrelief 400/+7°、10は下半分ライム＋幅1060の直立フォン＋左接地のworse 340とした。コピーは全てeyebrow/headline/sub=`240/340/680`、確定文字列を改変せず、長文も横リサイズせず実フォントサイズで再描画する。
- 1枚1体の裁定: raw 3画面を原寸目視し、画面内キャラはいずれも0体だったため指定マスコットを維持した。08=`screen 0 / blink 1`、09=`screen 0 / relief 1`、10=`screen 0 / worse 1`で、全10枚の合計を各1体に固定した。将来rawにキャラが入る場合は、対応する外乗せマスコットを外して `SCREEN_CHARACTER_COUNTS` と `slots.json` を同期する。
- Claude Code向け制約: 追加rawの名前、スクロール方式、シード時刻、3スラッグ、背景多角形、フォン幅／角度／位置、キャラasset／幅／角度／位置、確定コピーを変更しない。10のbottom合わせを1回へ減らすとステップ2が画面外になるため、遅延レイアウトへの再追従を維持する。contact sheetは10枚×400pxの横一列=4000×869、slotsは必ず10件とする。
- 検証: 指定Simulator `90F5A09F-D128-468C-AB02-7ABB1479B3AE`へstatus bar 9:41を設定し、追加キャプチャXCTestは1件・失敗0で `TEST SUCCEEDED`。raw 3枚は1320×2868、最終10枚はすべてPNG/RGB/1320×2868、contact sheetはPNG/RGB/4000×869、slotsは10件・各1slot・キャラ合計は全枚1。全見出し／subの `horizontal_scale_ratio=1.0` を確認した。macOS Vision OCRは最終08から「いますぐ始める」4択・曜日・20:00/22:00、09から選択済み「夜だけ強化」・7:00/23:00、10からステップ1/2・「開いている/閉じている」・オン/オフを認識した。追加3枚と10枚横並びcontact sheetを原寸目視し、コピー欠け・字形歪み・キャラ重複がないことを確認した。

## 2026-08-20 — App Storeスクリーンショット v2 パネル05コピー差し替え（オーナー指示）

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` の05 `goal-lockscreen` を、eyebrow「ロック画面・通知・ウィジェット」は維持したまま、headlineを「SNSを開くたびに」／「目標を確認」、subを「ロック画面に目標と開かなかった回数を表示」へ差し替えた。`.claude/specs/appstore-screenshots-v2-diagonal.md` のコピー表5行目も同一文言へ同期し、`output/app-store-screenshots/v2/ja/iphone-69/05-goal-lockscreen.png` と `output/app-store-screenshots/v2/contact-sheet-ja.png` だけを再生成した。
- 採用方針・却下案: オーナー指定コピーを一字一句そのまま採用し、共通コピーY、フォント、中央揃え、ロック画面、Live Activity、フォン、キャラの構図は変更していない。全10枚の一括再生成は対象外パネルと`slots.json`へ不要な更新を生むため却下し、既存ジェネレータの`render_panel(5)`と`make_contact_sheet()`だけを呼ぶ部分生成にした。
- Claude Code向け制約: 05 headlineの2行分割とsub、eyebrowを上記確定値から言い換えない。横方向の画像リサイズを導入せず、見出し・subとも実フォント描画の`horizontal_scale_ratio=1.0`を維持する。コピーだけの再生成では01〜04・06〜10と`slots.json`を更新しない。
- 検証: 05はPNG/RGB/1320×2868、contact sheetはPNG/RGB/4000×869。05のheadline 2行とsubはrequested/rendered font sizeがそれぞれ112/112/44px、自然幅942/560/880pxで、3行すべて`horizontal_scale_ratio=1.0`・`uniform_font_scale_ratio=1.0`、sub下端722px、Live Activity完全表示を確認した。05とcontact sheetを原寸目視し、指定コピー、中央揃え、コピー欠けなし、字形無歪みを確認。更新前後のSHA-256とmtime比較で、変更された画像は05とcontact sheetだけで、01〜04・06〜10および`slots.json`は不変だった。

## 2026-08-20 — App Storeスクリーンショット08〜10の最終状態・クロップ是正

- 作成・変更: `ios/DopaBreak/AppContainer.swift` に利用時間通知ストア／選択ストア／監視センターの依存注入口を追加し、既定値では従来どおりApp Groupと`DeviceActivityCenter`を使う経路を維持した。`ios/DopaBreak/SettingsView.swift` にはDEBUG限定の撮影initializerを追加し、`AuthorizationCenter.shared`の実認可状態を変更せず「スクリーンタイム 許可済み」の表示だけをテストから注入できるようにした。`ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` は専用`UserDefaults`と成功する監視fakeへ、利用時間通知ON・対象1件・15分ごと・就寝前短縮ONをシードし、10のスクロールを最下端から24pt戻す`bottomInset`へ変更した。
- 再生成: `output/app-store-screenshots/raw-core/ja/{deepfocus,nightmode,grayscale}.png`をiPhone 16 Pro Max Simulatorで再撮影し、`output/app-store-screenshots/v2/ja/iphone-69/{08-deep-focus,09-night-block,10-grayscale-guide}.png`だけを既存の固定構図で再合成した。続けて`output/app-store-screenshots/v2/contact-sheet-ja.png`を10枚から再生成した。01〜07と`slots.json`の幾何は変更していない。
- 採用方針・却下案: Family Controls実認可をSimulator XCTestから偽装する案は実API直結で決定的に注入できず、本番の認可経路を変えるため却下した。09の利用時間通知セクションを画面外へ逃がす案も、ON・対象設定済み・15分ごとの完成状態を見せられるため採用しなかった。10をmaximum offsetのまま撮る案はタイトル上端がナビゲーションバーに隠れるため、LazyVStackへの6回追従を維持したままmaximum−24ptを採用した。
- Claude Code向け制約: `SettingsView(snapshotModel:..., screenTimeAuthorized:...)`はDEBUG撮影専用で、通常initializerと`ScreenTimeCenter.refresh/requestAuthorization`を置換しない。利用時間通知の撮影シードは必ずテスト専用defaults・選択ストア・監視fakeを使い、App Groupの実データや`DeviceActivityCenter`へ書かない。10は`bottomInset(24)`とbottom系の6回再調整を維持する。raw差し替え後も08〜10は画面内0＋外乗せ1＝各1体を守る。
- 検証: 対象XCTestは1件・失敗0で`TEST SUCCEEDED`（deepfocus/nightmode offset=112、grayscale offset=3183・maximum=3207）。macOS Vision OCRで最終08は「許可済み」を認識し「未許可」なし、09は「許可済み」「夜だけ強化」「7:00」「23:00」「利用時間の通知を使う」「時間をはかるアプリ」「15分ごと」を認識し「未許可」「未設定」なし、10は「画面を白黒にする（任意）」を完全一致で認識した。最終3枚はPNG/RGB/1320×2868、contact sheetはPNG/RGB/4000×869、`slots.json`の08〜10はscreen 0 / external 1 / total 1。署名なしRelease Simulator buildも`BUILD SUCCEEDED`。

## 2026-08-20 — App Storeスクリーンショット パネル09を起床・就寝時刻中心へ再クロップ

- 作成・変更: `ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` の `nightmode.png` 専用 `verticalScrollTarget` を `.offset(60)` から `.offset(280)` へ変更した。iPhone 16 Pro Max / iOS 18.3.1での解決後offsetは332pt。`output/app-store-screenshots/raw-core/ja/nightmode.png`を再撮影し、固定済みの09構図へ `output/app-store-screenshots/v2/ja/iphone-69/09-night-block.png` だけを再合成、10枚から `output/app-store-screenshots/v2/contact-sheet-ja.png` を再生成した。
- 採用方針・却下案: ナビゲーション直下を「選んだアプリは就寝から起床まで開けなくなります。昼は一呼吸の確認だけが出ます。」から始め、直後の起床7:00／就寝23:00カードを最初のフルカードにした。`.offset(240)`（解決後292pt）は最上部に「完全ブロックの対象」が1行残り、08との重複を解消し切れないため却下した。「止める強さ／スクリーンタイム／完全ブロックの対象」の3行はすべて画面外とした。
- Claude Code向け制約: 09だけ `.offset(280)` を維持し、08の `.offset(60)` と10の `.bottomInset(24)` は共有・統一しない。09のフォン幅1000・回転+7°・中心、relief 1体、確定コピー、`slots.json`の幾何は変更しない。raw更新時も説明文→起床・就寝時刻の順を最上部に保ち、画面内0＋外乗せ1＝合計1体を維持する。
- 検証: 対象XCTestは1件・失敗0で`TEST SUCCEEDED`（nightmode offset=332）。macOS Vision OCRは最終09から説明文全文、`7:00`、`23:00`を認識し、「未許可」「未設定」は認識なし。rawと最終09はPNG/RGB/1320×2868、contact sheetはPNG/RGB/4000×869。`slots.json`の09はscreen 0 / external 1 / total 1。`git diff --check`も通過した。

## 2026-08-21 — App Storeスクリーンショット v2 パネル05へLive Activity拡大コールアウトを追加

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` に05専用のLive Activity拡大描画・角丸枠・接続線・影・非重複検証を実装し、設計正本 `.claude/specs/appstore-screenshots-v2-diagonal.md` を同期した。`output/app-store-screenshots/v2/ja/iphone-69/05-goal-lockscreen.png`と10枚版`output/app-store-screenshots/v2/contact-sheet-ja.png`を再生成し、`output/app-store-screenshots/v2/slots.json`は05レコードだけを最新幾何へ更新した。
- 採用方針: ロック画面全体を残したまま、フォン縮小前の1320×2868 `mock_lock()`からLive Activity source box `[42,1860,1278,2280]`（1236×420）を直接cropし、LANCZOSで1180×401へ縮小した。コールアウトは中央`[70,1390,1250,1791]`、角丸52px、`#C7F94D` 3px枠、黒45%・blur50・offset`(0,24)`の影で、実表示幅883.92pxに対して1.334962倍。既存コピー、ライム正円`(660,1800,r=680)`、フォン幅1000・上端830、awake反転`300/-12°/(cx230,bottom1050)`、`mock_lock()`本体は変更していない。
- 接続とレイヤー: 実LA表示`[218.04,2188.15,1101.96,2488.50]`へ同色2px角丸枠を追加し、実枠上辺の丸角接線点`[257,2188]`／`[1063,2188]`からコールアウト下辺接線点`[122,1791]`／`[1198,1791]`へ同色2px・不透明度60%の直線を引いた。描画順はフォン→キャラ→実枠/接続線→コールアウト影→コールアウト本体/枠。外接矩形の数学的な角同士を結ぶ案は、丸角の可視枠との間に空きが出るため却下した。フォン内の884×300表示をアップスケールする案も文字がぼけるため却下した。
- Claude Code向け制約: 05コールアウトは必ず`source_for(5)`の1320幅画像から`prepare_device()`前に切り出し、1180幅より小さい画像を拡大しない。`slots[0].callout.canvas_corners`の四隅、`source_outline.connector_anchors`、`connector_anchors`、2本の`connector_lines`を対で維持する。コールアウトはy=1390〜1791を保ち、コピー矩形とawakeの可視alpha bboxへ重ねない。部分更新時は01〜04・06〜10を再保存しない。
- 検証: 05はPNG/RGB/1320×2868、contact sheetはPNG/RGB/4000×869で、contact sheet内05は最終05の400×869 LANCZOS縮小とピクセル一致。macOS Vision OCRは拡大内の「あなたの目標」「英語で商談できる自分になる」「今日 開かなかった 12回」を完全一致で認識した。独立PIL/JSON/AST検査でcrop 1236×420→1180×401の縮小、倍率1.334962、四隅、3px/2px枠、45%影、2px/60%接続線、端点一致、コピー/キャラ非重複、05=`screen 0 / external 1 / total 1`、`ast.Assert` 0件を確認した。`python3 -O`で全10パネルを再描画し全て1320×2868 RGB・キャラ合計1。更新前後SHA-256では出力差分は05・contact sheet・slotsだけで、01〜04・06〜10は不変。

## 2026-08-21 — App Storeスクリーンショット撮影経路の決定性・上書き安全性を修正

- 作成・変更: `ios/DopaBreak/AppContainer.swift` と `ios/DopaBreak/StoreService.swift` に、StoreKitのバックグラウンド処理、起動時通知同期、Night Shield／Deep Focus／利用時間監視、Deep Focus通知をテストから停止・注入できる経路を追加した。`ios/DopaBreak/DopaBreakApp.swift` はXCTestホスト起動時だけ起動副作用を無効化する。`ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` は明示的opt-in、6.9インチ画像サイズの事前・保存直前検証、黒画像拒否、全DeviceActivity／通知fake、Pro状態の保存直前検証を備えるよう修正した。通常起動の既定値と本番挙動は変更していない。
- 採用方針・却下案: 撮影モデルへキャッシュ済みPro状態だけを入れる案は非同期StoreKit更新との競合が残るため却下し、撮影時はStoreKit更新タスク自体を開始しない。`XCTAssert`だけでサイズ不一致を報告する案は、その後も誤端末画像を上書きするため却下し、書き込み前に`XCTSkip`で中断する。黒画像時に`UIWindow.layer.render`へ切り替える案はSwiftUIの`InvalidTransition removedFromContainer`を起こしたため却下し、対象`UIHostingController.view.layer`だけをfallback描画する。見た目・構図・スクロール位置は変更していない。
- Claude Code向け制約: 手動raw撮影は`DOPABREAK_CAPTURE_APPSTORE_SCREENSHOTS=1`が必須で、xcodebuildから実行する場合はSimulatorのlaunchd環境へ設定し、終了後に必ず解除する。保存できる画像は厳密に1320×2868かつ可視輝度差があるものだけ。撮影モデルには3種のDeviceActivityスケジューラとDeep Focus通知fakeをすべて渡し、`automaticallyRefreshEntitlement=false`、`scheduleNotificationsOnInit=false`を維持する。`AppLaunchPolicy`と各initializerの本番既定値を反転させない。
- 検証: iPhone 17 Pro Max Simulatorで追加3画面を再撮影し、deepfocus／nightmode／grayscaleはいずれも1320×2868・非黒・Proロックなしを原寸目視した。opt-inなしでは撮影3件が即skipする。DopaBreakTestsは手動撮影4クラスを除いて150件（skip 3件）・失敗0、DopaBreakCoreは454件・失敗0、generic iOS Simulator buildは`BUILD SUCCEEDED`。v2ジェネレータは10枚すべて1320×2868 RGB、contact sheet 4000×869、slots 10件を生成し、`git diff --check`も通過した。

## 2026-08-22 — App Storeスクリーンショット v2をen-US / koへ展開

- 作成・変更: `ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` を `-testLanguage` / `-testRegion` 対応にし、優先言語から `ja` / `en-US` / `ko` のSwiftUI locale、目標3件、保存先を一体で解決するようにした。既存の実ウィンドウ撮影、明示opt-in、1320×2868事前・保存前検査、非黒検査、テスト専用defaults／監視fake、08=`offset(60)`、09=`offset(280)`、10=`bottomInset(24)`は維持した。指定Simulator `90F5A09F-D128-468C-AB02-7ABB1479B3AE` のstatus barを9:41へ固定し、`output/app-store-screenshots/raw-core/{en-US,ko}/`へ `stats/breath/intent/home/reflection/goals/deepfocus/nightmode/grayscale` の各9枚を撮影した。
- ジェネレータ: `scripts/generate-appstore-screenshots-v2.py` に `COPY[ja/en-US/ko]`、`--locale`（反復指定可、未指定は3ロケール）、ロケール別raw／最終／contact sheet／slots経路を実装した。en-US / koの01〜04・06〜07は旧 `scripts/generate-appstore-screenshots.py` のCOPYと生成時に完全一致検査し、05・08〜10は設計正本の確定コピーをそのまま登録した。出力は `v2/{locale}/iphone-69/`、`contact-sheet-{locale}.png`、`slots-{locale}.json` とし、jaだけ従来互換の `v2/slots.json` も同内容で維持した。
- ロック画面とフォント: `mock_lock()` の日付、Live Activity eyebrow／実績行、目標3件をロケール化した。LAのeyebrowと実績行は実装正本 `ios/WidgetsExtension/Localizable.xcstrings` の `live_activity.*` を実行時に読み、英語のuppercaseは実Viewの `.textCase(.uppercase)` と同じ表示変換を適用した。フォントはja=`ヒラギノ角ゴシック W4/W8.ttc`、en-US=`SFNS.ttf`（variable weight 400/700）、ko=`AppleSDGothicNeo.ttc`（face index 0 Regular / 6 Bold）を採用し、全て実在・読込成功、代替使用なし。各slotsへ実パス・face index・fallback有無を記録した。
- 採用方針・却下案: 3言語別に撮影クラスを複製する案は、決定性ガードとスクロール位置が分岐するため採用せず、`Locale.preferredLanguages`を `-testLanguage/-testRegion` で切り替える単一路線にした。`AppleLanguages`をlaunch環境変数で直接渡す案もXCTestの標準言語指定と競合するため採用していない。文字列画像の横リサイズやロケール別の構図調整は行わず、1240px超だけ実フォントサイズを下げ、全スロット幾何をjaと完全同一にした。
- Claude Code向け制約: raw再撮影は従来どおり `DOPABREAK_CAPTURE_APPSTORE_SCREENSHOTS=1` をSimulator launchdへ一時設定し、完了後に必ず解除する。en-US=`-testLanguage en -testRegion US`、ko=`-testLanguage ko -testRegion KR`を使い、言語判定や目標文言を別の環境変数へ分離しない。COPY、目標3件、LA文言、日付書式、フォントface、10枚の構図・キャラ数・コールアウト幾何を変更しない。通常の全生成は引数なし、部分生成は `--locale {ja,en-US,ko}` を使う。
- 検証: en-US / koとも対象XCTest 2件・失敗0で各raw 9枚を1320×2868 PNGとして保存し、一時opt-in環境変数は解除した。`python3 -O scripts/generate-appstore-screenshots-v2.py` で3ロケール30枚を再生成。独立PIL/JSON/Markdown/legacy COPY照合で各10枚PNG/RGB/1320×2868、コピー10/10完全一致、キャラ合計各1、headline/sub `horizontal_scale_ratio=1.0`、全スロット幾何3言語一致、contact sheet 4000×869、slots各10件、ja互換slotsのbyte一致を確認した。macOS Vision OCRはen-US / koの全20枚で全外乗せコピーを認識し豆腐・置換文字0、05全文では日付・9:41・LA eyebrow・目標3件・実績2行、raw goalsでは各言語の目標3件を認識した。原寸contact sheet／05／raw goalsも目視し文字化け・字形歪みなし。`ast.Assert` 0件、3言語でboldの描画ink量がregularを上回ること、`git diff --check`も確認した。

## 2026-08-22 — 一呼吸画面へ残り時間リング・秒数と拡大キャラクターを追加（オーナー承認済み）

- 作成・変更: `ios/DopaBreak/BreathingCharacterView.swift` の `BreathCharacterTimeline` に、残り割合を1→0で返す `progress(at:reduceMotion:)` と、端数切り上げの `remainingSeconds(at:)` を追加した。同じ `TimelineView` のuptime基準`elapsed`から、線幅6ptの `DesignTokens.accent` リング、同色18%トラック、32pt bold相当のmonospaced残り秒、表情・拡縮・不透明度をすべて導出する。リングは12時起点の時計回りtrimで、Reduce Motion時だけ整数秒境界の段階更新。リングとキャラはVoiceOverから除外し、残り秒へ文脈付きの読み上げラベルを付けた。
- レイアウト: `ios/DopaBreak/InterventionFlowView.swift` の呼吸ビュー枠を最大380×固定高380から `maxWidth/maxHeight=520` へ拡大した。リング径に対してキャラを82%でレスポンシブ描画するため、狭い端末ではaspect-fitし、広い端末では従来の200pt heroより大きくなる。上下Spacerは両方4pt、呼吸ビューとタイトルのspacingは20pt、タイトルは中央・最大2行とし、iPhone SE相当の高さでも固定520ptを強制せず切れない構造にした。
- 採用方針・却下案: 2026-08-14の「数値進捗を置かず拡縮だけにする」旧裁定は、2026-08-22のオーナー明示承認（円形プログレス＋残り秒、キャラ拡大＋余白圧縮）で上書きする。旧ドットや複数呼吸サイクルは復活させない。`InterventionFlowModel.breathRemainingSeconds`を表示へ流用する案と新規Timerは、視覚・表情・ハプティクスの正本が分裂するため却下した。タイムラインは終了時0を返す一方、遷移直前の最終描画だけは画面を1秒表示に保持し、見える並びを8→…→1に限定する。
- ローカライズ: `ios/DopaBreak/Localizable.xcstrings` の既存 `intervention.breath.countdown`（ja/en/koとも `%lld`）を数字表示へ再利用した。新規 `intervention.breath.remaining_seconds.accessibility` はja=`残り%lld秒`、en=`%lld seconds remaining`、ko=`%lld초 남음`。不要になった `intervention.breath.timer_label`（`BREATHE · %lld SEC`）は参照とキーを削除した。
- テスト・Claude Code向け制約: `ios/DopaBreakTests/BreathingCharacterViewTests.swift` に3秒・8秒それぞれの開始／中間／終了／範囲外clamp、全整数秒境界の切り上げ、Reduce Motion段階進捗を固定する4件を追加した。今後もリング・秒数・表情・呼吸ハプティクスは `BreathCharacterTimeline` と同一uptimeを使い、独立Timerやモデルの250ms表示値へ分岐させない。6pt/18%、12時起点、最大520、比率82%、Spacer 4、spacing 20、リング非読み上げ、秒数読み上げを維持する。
- 検証: iPhone 16 Pro / iOS 18.3.1で対象11件・失敗0、手動スクリーンショット生成5 suiteを除くアプリ自動テスト151件・失敗0、DopaBreakCore 454件・失敗0。署名なしgeneric iOS Simulatorの全ターゲットbuildは終了コード0。`Localizable.xcstrings`のJSON解析・新旧キーと3言語充足、`scripts/lint-display-copy.py` exit 0、`git diff --check`を確認した。指示どおりスクリーンショットは再生成していない。

## 2026-08-22 — 一呼吸スクリーンショットを中盤位相で3ロケール再生成

- 作成・変更: `ios/DopaBreak/InterventionFlowView.swift`のDEBUG撮影initializerだけに`breathPreviewLoop`の注入口を追加し、本番initializerは常に`nil`を使う。`ios/DopaBreak/BreathingCharacterView.swift`は空の`previewLoop`で位相を静止するときだけ、`CharacterView`の独立浮遊・自動まばたきも止める。本番の`nil`と動画用の非空`previewLoop`は従来どおりアニメーションする。`ios/DopaBreakTests/CoreScreensSnapshotCapture.swift`に一呼吸だけを上書きする`testCaptureBreathScreen()`を追加し、既存rawの他画面を再撮影しない経路にした。
- 撮影位相: 8秒設定の4.0秒地点を、既存`previewLoop`のspan=0経路（`4..<4`）で固定。表示は3ロケールとも残り`4`秒。リング成分の明部ピクセル比は全言語`0.4921`で、約50.8%減の同一位相。単に`settleTime=4`へ伸ばす案はテストホスト起動時間と描画フレームで位相がずれ、ロケール間の決定性を持てないため却下。新しいTimerは作っていない。
- 再生成: Simulator `90F5A09F-D128-468C-AB02-7ABB1479B3AE`、iOS 18.3.1、status bar `9:41`、`-testLanguage/-testRegion`=`ja/JP`, `en/US`, `ko/KR`で`output/app-store-screenshots/raw-core/{ja,en-US,ko}/breath.png`を撮影。続けて`output/app-store-screenshots/v2/{ja,en-US,ko}/iphone-69/02-pause.png`と`contact-sheet-ja.png` / `contact-sheet-en-US.png` / `contact-sheet-ko.png`を再生成した。全30パネルを決定的に再合成したが、SHA-256差分は3ロケールの02だけで、他27パネルは不変。撮影後に`DOPABREAK_CAPTURE_APPSTORE_SCREENSHOTS`はSimulator launchdから解除した。
- bbox実測（`[left,top,right,bottom)`、raw 1320×2868）: ja / en-US / koの3言語すべて`[136,919,1184,1893)`=1048×974pxで完全一致。フォン幅1000・-7°の02に射影した可視ピクセルbboxも全言語`[281,1728,1029,2443)`=748×715pxで一致。旧hero 200ptを同一アセットalphaと従来撮影位相0.8秒で換算したbboxは約567×529pxのため、新rawは幅・高さとも約1.85倍、bbox面積は約3.4倍。
- 検証: 3言語のrawはPNG/RGBA/1320×2868、最終02はPNG/RGB/1320×2868。ジェネレータのキャラ数は各`screen 1 / external 0 / total 1`で、独立連結成分検査も各1体。リングbboxは3言語共通`[9,730,1311,2032)`、残り秒数の可視bboxは共通`[631,2069,688,2139)`で、呼吸領域`(0,700)-(1320,2150)`のRGBAピクセルSHA-256も3言語で完全一致。原寸raw・最終02の両方で半周リングと`4`を目視確認した。contact sheetは各PNG/RGB/4000×869で、02スロットは最終02の400×869 LANCZOS縮小とピクセル一致。対象XCTestは3言語各1件・失敗0で、`git diff --check`も通過した。

## 2026-08-22 — 一呼吸カウント数字の視認性・配置をオーナー指摘どおり修正

- 作成・変更: `ios/DopaBreak/BreathingCharacterView.swift` の残り秒を32ptから **76pt bold / rounded / monospacedDigit** へ拡大し、色を`DesignTokens.primaryText`からリングと同じ`DesignTokens.accent`（`#C7F94D`）へ変更した。リングとの`countdownSpacing`は8ptから24ptへ変更し、数字を縦横`fixedSize`にして狭い高さでは数字でなく上の`GeometryReader`内リングが縮むようにした。`ios/DopaBreak/InterventionFlowView.swift` は順序をヘッダー→タイトル→リング＋キャラ＋数字へ変更し、タイトルと呼吸ブロックの20pt、上下の同一`Spacer(minLength: 4)`、最大520ptの呼吸ブロックを維持した。タイトルも縦方向を固定し、最大2行を先に確保する。
- 採用方針・却下案: 大きな数字をリング内へ重ねる案はキャラ／スマホと競合し、白のまま拡大する案はリングへの帰属が弱いため却下した。SE向けに数字を縮小する案と呼吸ブロックを固定520pt高にする案も、オーナー指定の76pt維持または小型端末対応に反するため不採用。数字の固有高を確保し、残余高だけで正方形リングをaspect-fitする既存構造を採用した。大画面ではタイトル移動によって従来の上部黒余白を情報領域として使い、上下Spacerは同率のまま全体を均等化する。
- 小型端末制約: iPhone SE（第3世代、iOS 18.3.1、750×1334 / 375×667pt）で、既存の実ウィンドウハーネスを本番より厳しい呼吸ブロック高380ptにして3位相を実行し、リングだけが縮んで76pt数字・キャラとも欠けないことを実画像で確認した。外側のヘッダー、タイトル、20pt間隔、呼吸ブロック、上下最小Spacerの必要高もSEの可用高内に収まる。今後も小型端末対応で数字サイズ、タイトルサイズ、20pt、24ptを縮めず、リング径だけを可変にする。
- 再撮影・生成: Simulator `90F5A09F-D128-468C-AB02-7ABB1479B3AE`、status bar `9:41`、8秒中4.0秒の空Range固定で、`output/app-store-screenshots/raw-core/{ja,en-US,ko}/breath.png`を再撮影した。各ロケールの`output/app-store-screenshots/v2/{locale}/iphone-69/02-pause.png`と`contact-sheet-{locale}.png`を再生成。全30パネルの生成前後SHA-256比較では変更は3ロケールの02だけで、他27枚は不変。撮影opt-in環境変数は完了後に解除した。
- 画像検証・bbox（`[left,top,right,bottom)`）: raw 3枚はPNG/RGBA/1320×2868、最終02はPNG/RGB/1320×2868、contact sheetはPNG/RGB/4000×869。rawの数字可視bboxは3言語共通`[593,2156,729,2323)`=136×167px（旧32ptは`[631,2069,688,2139)`=57×70px）、フォンへ合成後の最終02は共通`[538,2611,638,2735)`=100×124px。`(0,780)-(1320,2360)`の呼吸領域RGBA SHA-256は3言語とも`f5a19eb8fd243661383ee6b6f8e5a6d0df2862bd90ce541db87d21b46813b05b`で同一位相。各02は`screen 1 / external 0 / total 1`で、原寸raw・最終02・3本のcontact sheetを目視し、大きなライムの`4`、半周リング、キャラ1体、コピー欠けなしを確認した。
- ビルド・テスト: `xcodegen generate`成功、署名なしgeneric iOS Simulator全ターゲットは`BUILD SUCCEEDED`。DopaBreakCore 454件・失敗0、手動撮影ハーネス5 suiteを除くアプリ自動テスト151件・失敗0、`BreathingCharacterViewTests`単独11件・失敗0、SE実ウィンドウ3位相1件・失敗0、3ロケールraw撮影は各1件・失敗0。`git diff --check`も通過した。

## 2026-08-22 App Storeスクショ en-US コピー差し替え＋並び順（Claude Code / Fable）
- 検索意図監査の結果、en-USの#4を「Dopamine detox, one skipped open at a time」（コアKWへの応答）に差し替え、#1 subにphone、#6 eyebrowにhabit trackerを反映。#3 subの「5–30」は「5 to 30」へ（humanizer-enダッシュゲート）。
- アップロード順を 01,02,09,04,08,03,05,06,07,10 に変更（先頭3枚で doomscroll / blocker代替 / sleep を押さえる）。ライム面の#4と旧#8(=新05)が隣接するため、視覚リズムが気になる場合は05↔06の入れ替えで解消可。
- 詳細は `.claude/specs/appstore-screenshots-v2-diagonal.md` 末尾の追記を参照。ja/koは監査のみで未変更。

## 2026-08-22 — 利用後リフレクションを満足度1問へ統合（オーナー承認済み）

- 作成・変更: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Models/AppModels.swift` に `PostUseSatisfaction.impliedHappinessDelta` を追加し、`ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/PostUseSatisfactionTests.swift` で5回答すべてを固定した。`ios/DopaBreak/PostUseReflectionSheet.swift` は幸福感の2問目と選択肢内CharacterViewを削除し、満足度選択→先頭キャラの既存pop→550ms後の保存・終了へ変更した。`recordPostUseReflection(id:satisfaction:happinessDelta:)`、`ReflectionLog`、Stats集計は変更していない。
- 採用方針・却下案: 2問目は1問目と相関が高く独立情報が薄いため、回答率を優先して1タップへ短縮した。幸福感変化をnilにする案とStats項目を削る案は既存分析を失うため却下し、満足感があった／楽しかった=`increased`、何も得られなかった=`unchanged`、時間を失った／気分が下がった=`decreased`としてCoreで導出する。選択直後に即dismissする案はフィードバックが見えないため却下し、選択行のaccent枠と先頭キャラの表情popを550ms見せる。待機中は全回答とスキップを無効化し、SwiftUIの`.task(id:)`で画面離脱時のsleepをキャンセル可能にした。既存54pt行高・14pt角丸・24pt外余白・44ptスキップ領域は維持し、選択行へVoiceOverのselected traitを付けた。
- ローカライズ・文書: `ios/DopaBreak/Localizable.xcstrings` からSwift参照0件だった `reflection.happiness.title/increased/unchanged/decreased` を削除し、`reflection.satisfaction.title` のja/en/koから固定改行を外した。`docs/01_business_design.md`、`docs/03_product_spec.md`、`docs/04_functional_requirements.md`、`docs/05_detailed_design.md`、`docs/06_screen_design.md`、`docs/07_onboarding_design_lifefocus.md`、`docs/11_ui_copy.md`、`docs/FABLE_BRIEF.md` を1問UIと満足度導出へ同期した。今後も表示文言へ固定改行を戻さず、幅とDynamic Typeによる自然折返しを使う。
- スクリーンショット: App Store素材は1枚1体を優先し、満足度未選択の実シートをStatsView背景から通常initializerで提示する。DEBUGの選択済みinitializerは削除し、`ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` に他rawを上書きしない `testCaptureReflectionScreen()` を追加した。指定Simulator `90F5A09F-D128-468C-AB02-7ABB1479B3AE`、status bar 9:41、ja/JP・en/US・ko/KRで `output/app-store-screenshots/raw-core/{locale}/reflection.png` を各1枚再撮影し、先頭doom 1体・文字のみ5択・2問目なしを原寸目視した。`scripts/generate-appstore-screenshots-v2.py` と `.claude/specs/appstore-screenshots-v2-diagonal.md` も未選択1問へ同期し、v2は3言語30枚を再生成、各slots 10件すべてキャラ合計1以下、06はscreen 1／external 0／total 1。撮影後のSimulator launchd opt-inは解除した。
- Claude Code向け制約: 保存APIのシグネチャとStatsの幸福感内訳を維持し、新しい満足度caseを追加するときは導出switchとテストを同時更新する。選択待機中の二重送信防止、550msのキャンセル可能な遅延、保存失敗時の選択解除、テキストのみの54pt回答行、自然折返し、通常initializerを維持する。raw更新にはreflection専用XCTestを使い、他9画面を再撮影しない。画面内＋外乗せキャラは1枚1体以下を維持する。
- 検証: DopaBreakCoreは459件・失敗0。`xcodegen generate`成功、署名なしgeneric iOS Simulator全ターゲットは`BUILD SUCCEEDED`。reflection撮影XCTestは3言語各1件・合計3件・失敗0、raw 3枚は1320×2868。v2は3言語30枚すべて生成成功し、slotsの`total <= 1`検査を通過した。xcstringsは`jq`解析・en/ja/ko充足・Xcodeの`xcstringstool compile`成功を確認し、`python3 scripts/lint-display-copy.py`はexit 0、`git diff --check`も通過した。

## 2026-08-22 — App Storeスクリーンショット ja / ko を検索意図監査に基づき更新（オーナー承認済み）

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` のja #08 eyebrow/sub、ko #01/#06/#08 eyebrowを承認文字列へ差し替えた。7枚構成の承認コピー正本 `scripts/generate-appstore-screenshots.py` には存在するko #01/#06を同時反映し、存在しないja/ko #08はv2のみを変更した。`output/app-store-screenshots/v2/{ja,ko}/iphone-69/`をロケール限定で再合成し、差分画像はja #08、ko #01/#06/#08と各`contact-sheet-{locale}.png`だけ。raw実画面は再撮影していない。
- アップロード順: `output/app-store-screenshots/v2/upload-order/{ja,ko}/iphone-69/`へ、生成番号`01,02,09,08,04,03,05,06,07,10`をアップロード番号01〜10としてコピーした。各ロケール直下の`README.md`へ生成元、対応表、監査根拠、`asc screenshots upload`例を記録した。仕様正本 `.claude/specs/appstore-screenshots-v2-diagonal.md` にja/koの変更表と同じ順序を追記した。
- 採用方針・却下案: Apple Ads Insights実測に合わせ、ja #08で集中・勉強・タイマー、ko #01/#06/#08で숏폼·SNS・루틴・공부を明示する。コピー以外の構図・座標・実画面・キャラ・フォント・ロケール固有表記は維持した。全ロケール生成やraw再撮影は依頼範囲外かつen-US不変条件に不要なため採用せず、`--locale ja --locale ko`だけを実行した。旧7枚スクリプトへ存在しない#08を新設する案も、正本の構成を不必要に変えるため却下した。
- Claude Code向け制約: 上記5文字列は改変しない。ko #01/#06は旧正本とv2を常に同時更新し、`validate_legacy_copy_reuse`を通す。アップロード順は両ロケールとも`01,02,09,08,04,03,05,06,07,10`を維持する。en-USのCOPY、10枚、`contact-sheet-en-US.png`、`upload-order/en-US/`をja/ko作業から更新しない。
- 検証: ja/ko各10枚はPNG/RGB/1320×2868、各slotsのキャラ合計は全20枚で1、contact sheetは各PNG/RGB/4000×869。macOS Vision OCRの上位候補で指定5文字列を完全一致検出し、原寸パネルとcontact sheetも目視確認した。upload-order 20枚は指定元PNGとバイト一致。`python3 scripts/lint-display-copy.py`はexit 0。en-USの10枚＋contact sheet 11件、および既存upload-orderのREADME＋10枚11件は作業前後のSHA-256が全件一致した。

## 2026-08-22 — App Storeスクリーンショット01の年間換算を35日に統一（オーナー指示「揃えて」）

- 作成・変更: `scripts/generate-appstore-screenshots.py` の `PANEL_DAYS` をja / en-US / ko × iphone-69 / iphone-65 / ipad-13の全9組で35へ統一し、`scripts/generate-appstore-screenshots-v2.py` のko #01直書きを「1년에 35일이 돼요」へ変更した。仕様正本 `.claude/specs/appstore-screenshots-v2-diagonal.md` に統一根拠を1行追記した。
- 採用方針・却下案: 共通前提 `1日2.3時間 × 365日 ÷ 24 = 34.979166…日` を最も近い整数日へ丸めた35を採用した。ロケール別丸め、端末別の別前提、koだけ33日を維持する案は、計算・コピー・実画面シードのいずれにも異なる韓国向け前提が存在しないため却下した。ジェネレータ内に別の換算式はなく、v2のen-US / koは旧正本との一致検証を通る。
- 再生成・同期: `python3 -O scripts/generate-appstore-screenshots-v2.py --locale ja --locale en-US --locale ko` で3ロケール各10枚とcontact sheetを決定的に再合成し、ja / koの生成元01を各`upload-order/{locale}/iphone-69/01-hook.png`へ再コピーした。内容差分はkoの`01-hook.png`、`contact-sheet-ko.png`、`slots-ko.json`、upload-orderのko `01-hook.png`だけで、jaの01/contact/upload-order 01とen-USの10枚＋contact sheetはSHA-256不変だった。
- Claude Code向け制約: パネル01の年間日数は今後も全ロケール・全端末で35を維持し、端末レイアウト調整を数値変更で吸収しない。ko #01を変更する場合は旧正本の`PANEL_DAYS`とv2直書きを同時更新し、`validate_legacy_copy_reuse`を通す。
- 検証: macOS Vision OCRでja=`1年で35日になる`、en-US=`can become 35 days a year`、ko=`1년에 35일이 돼요`を各01から完全一致検出した。3本のcontact sheetはPNG 4000×869、ja / ko upload-order 01は生成元とSHA-256一致。全9組の`PANEL_DAYS == 35`、旧31/33/34日スクショ文言0件、`python3 scripts/lint-display-copy.py` exit 0、`git diff --check` exit 0を確認した。

## 2026-08-22 — 振り返り待機状態とスクリーンショット06／ja・ko検索意図のフォローアップ

- 作成・変更: `ios/DopaBreak/PostUseReflectionSheet.swift` で回答確定から保存までの550msだけスワイプ閉じを無効化し、未選択4行と「今回はスキップ」を不透明度0.4へ落とした。選択行は既存のアクセント枠と不透明度1を維持し、確定時は `AccessibilityNotification.Announcement` で選択行のローカライズ済み表示名を通知する。シート全体を減光する案は確定内容の視覚フィードバックまで弱めるため却下し、UIKit通知へ戻る案はSwiftUI標準APIで完結できるため採用しなかった。Coreの保存APIと550msのキャンセル可能な遅延は変更していない。
- コピー正本: `scripts/generate-appstore-screenshots.py` と `scripts/generate-appstore-screenshots-v2.py` の06サブコピーをja「満足感と開こうとした回数を見える化」／en-US “Track satisfaction, attempts, and skipped opens”／ko「만족감·시도·열지 않은 횟수를 한눈에 봐요」へ同時更新した。v2のja #08は承認値「集中タイマーで完全ブロック」「勉強や仕事の30分〜2時間 曜日と時間帯の予約も」に揃え、`.claude/specs/appstore-screenshots-v2-diagonal.md` の3言語変更表も同期した。Deep Focus実装には30分・1時間・2時間・手動解除と曜日／開始／終了の毎週予約が存在するため、集中タイマー訴求との機能齟齬なしと判断した。
- 再生成・順序: `output/app-store-screenshots/v2/{ja,ko}/iphone-69/`を各10枚、`contact-sheet-{ja,ko}.png`、`slots-{ja,ko}.json`を再生成し、`output/app-store-screenshots/v2/upload-order/{ja,ko}/iphone-69/`を生成番号`01,02,09,08,04,03,05,06,07,10`の順へバイト一致で同期した。Part Bの実画像を正本へ合わせるためen-USも再生成し、生成06を`upload-order/en-US/iphone-69/08-habit-tracker.png`へ同期した。3本のcontact sheetと変更対象パネルを原寸目視し、コピー欠け・字形崩れ・構図崩れなしを確認した。
- 並行決定: 本フォローアップ仕様にあったko #01「33일」の据え置きメモは、同時進行のClaude Code側で末尾に追記された後発のオーナー決定「3言語・全端末を35日に統一」により失効した。並行作業を差し戻さず、最終生成物はkoも「35일」を維持する。
- Claude Code向け制約: 550ms待機中は選択行だけを強調したまま閉じ操作・再回答・スキップを受け付けない。保存失敗で`self.satisfaction=nil`へ戻ったときは減光と閉じ禁止も同時解除する。06サブコピーは旧正本とv2を常に同時更新し、koは`validate_legacy_copy_reuse`を通す。ja/koのアップロード順と各枚キャラ合計1体以下を維持する。
- 検証: humanizer-jpは23パターン検出0・日本語読点0。humanizer-koは変更前10文／平均58.8字／SD 5.79／読点0%／同一語尾連続1、変更後10文／平均59.1字／SD 5.75／読点0%／同一語尾連続1で、両方exit 0・全18パターン0。ja/ko各10枚はPNG/RGB/1320×2868、contact sheetは各PNG/RGB/4000×869、slotsは各10件・`max(total)=1`、upload-order全20枚は生成元とバイト一致。`xcodegen generate`成功、署名なしgeneric iOS Simulator向け全7ターゲットは`BUILD SUCCEEDED`、`python3 scripts/lint-display-copy.py`は既存の要確認2件のみでexit 0。

## 2026-08-22 — 機能画面（ホーム・記録・目標・設定・止めるアプリ）の視覚リデザイン提案（提案・オーナー承認待ち・未実装）

- 背景: オーナー指摘「オンボーディング以外の機能画面がただの設定画面・SNSアイコンもないテキストページ・業務ツールになっている」。現状調査で判明した事実: `Label(ApplicationToken)` はアプリ全体で未使用（実アプリアイコンがどこにも出ない）／Dopaは機能画面6箇所のみ／`StatsService` の理由別・ルール(アプリ)別・満足度別・前週比が実装済みで未表示／`GoalCategory` にアイコン・色なし／設定で使うSF Symbolは chevron・arrow・lock の3種のみ／TargetAppPickerは32pt円＋汎用SFシンボル。
- 提案（モック: `.claude/specs/functional-screens-redesign-proposal.md` 参照・Artifact公開済み）: ①SNSは常にアイコンで見せる（カタログ8アプリはブランド色タイル＋SFグリフ、Screen Timeトークンは `Label(token)` を30pt前後の行用途に限定。ロゴ画像は同梱しない）②Dopaを毎画面に常駐（ホームのリング／記録の満足度5表情／目標のロック画面プレビュー／設定のステータスカード）③数字に形（リング・7本日別バー・アプリ別バー・理由チップ）④設定は「いまの守り」ステータスカード→止める強さ3枚モードカード→対象・長さ・自動化→起床就寝タイムライン、通知・ロック画面・Proは子画面へ。
- 競合根拠（App Storeページ調査）: Opal/Jomo/OffScreenはホーム＝今日の合計＋アプリアイコン列、one sec/Jomo/Opalはアプリ別回数、5社ともマスコット不使用。ストリークは採用しない（モデルになく8/14炎表現削除と相反）。
- 技術制約メモ: `Label(ApplicationToken)` は描画解像度約25px相当・色スキーム制御不可・多数描画で重い（Apple Forums 731387/732567/727437）。ヒーロー大アイコンには使わない。AttemptLogはruleIdのみ保持（catalogID未記録）のためアプリ別は「ルール=アプリ」前提。
- オーナー判断待ち: A トークンなしアプリのアイコン（推奨ブランド色タイル） B Freeの記録画面でProカードをぼかし表示するか C 設定トップの範囲（子画面分割）。承認後はPhase1（AppIconView＋止めるアプリ＋ホーム）→2（記録）→3（設定）→4（目標）。実装はOpus5サブエージェント（Codex上限中）、レビューは別Opus5。

## 2026-08-22 — 機能画面リデザイン提案をオーナー承認（「全部推奨でOK」）

- 確定: A トークンなしアプリはブランド色タイル＋SFグリフ（ロゴ画像は同梱しない）／B Freeの記録画面はProカードを「ぼかし＋解放ボタン」で見せる／C 設定トップは「いまの守り・止める強さ・対象/長さ/自動化・起床就寝」＋通知/ロック画面/Proの入口3行、残りは子画面。
- 実装順: Phase1 AppIconView＋止めるアプリ＋ホーム → Phase2 記録 → Phase3 設定 → Phase4 目標＋編集シート。各Phase末に実機スクショで確認。

## 2026-08-22 — シールド解除フロー＋回数上限＋クールダウン＋アプリ別設定（v1.1・オーナー決定B）

- 決定: Pro向けに常時シールド「ゲート」を追加し、Clarymindと同じ制御系（1日の回数上限・解除間クールダウン・1回の長さ・アプリ別設定）をManagedSettingsで強制する。設計正本 `.claude/specs/shield-unlock-flow-v1_1.md`
- 体験: シールドは入口のみ（静的）。ボタンでDopaBreak本体を開き（iOS 26.5+ `ShieldActionResponse.openParentalControlsApp`・旧OSは通知タップ＝Clarymind/one sec方式）、既存の一呼吸→理由→時間選択→振り返りをそのまま使う。2026-07-08「シールドは静的でone sec体験にならない」問題はこの構成で解消
- 2026-07-18却下「アプリ内スイッチの24hクールダウン」との関係: 当時の却下理由はショートカット経路の執行力ゼロ。本件はシールドで強制するため前提が異なる（backlog v1.1項目の実行）
- 不変条件の継承: 非破壊降格（Freeでは剥がすだけ・設定/台帳は残す）・閉じ込め禁止（上限/クールダウンは設定変更で即解除可）・拡張は権利判定をしない・再シールドは3層（DeviceActivity開始=終了時刻・≥15分／前面復帰同期／台帳タイムスタンプ再検証）
- 既定値: 上限なし・クールダウンなし・1回10分（「禁止でなく気づき」を維持。オーナー確認事項）。ペイウォール行・スクショ・説明文への反映は別タスク
- 却下: A=標準モードに摩擦版だけ載せる（7/18の判断と矛盾・回避可能な上限は低評価を招く）/ C=ローンチ優先でv1.1送り（オーナーがBを選択）

## 2026-08-22 — シールド解除フロー v1.1 Batch 1（Core＋拡張）実装

- 作成・変更: Coreへ `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Models/GateModels.swift`、`Services/GatePolicy.swift`、`Services/GateStores.swift`、`Services/GateSyncPolicy.swift` を追加し、`DopaBreakCore.swift`、`Services/EntitlementGate.swift`、`Storage/JSONSnapshotStore.swift`へゲート定数・Pro権利・3つのSnapshotFileを追加した。`Tests/DopaBreakCoreTests/{GatePolicyTests,GateStoresTests,GateSyncPolicyTests}.swift`を追加し、`EntitlementGateTests.swift`を拡張した。アプリ層の`AppContainer`／`SettingsView`／`InterventionFlow*`とペイウォール文言は変更していない。
- 拡張: `ios/ShieldConfigExtension/ShieldConfigurationExtension.swift`を`GatePolicy.shieldState`の優先順へ切り替え、夜専用タイトル、ja/en/koの§8.1文言、カテゴリ由来シールドのDeep Focus／夜表示を実装した。`ios/ShieldActionExtension/ShieldActionExtension.swift`へ要求台帳→通知→応答、再送、直接SQLiteキャンセル記録を実装し、通知文言は`Bundle.main`が拡張バンドルを指すため同拡張の新規`Localizable.xcstrings`へ置いた。`project.yml`と同拡張`Info.plist`へja/ko/enを登録した。`ios/MonitorExtension/DeviceActivityMonitorExtension.swift`は再シールド活動の開始／終了を同じ処理へ集約し、再適用→台帳期限切れ→自活動停止の順にした。
- 採用方針: 完全ブロックは時刻だけでなく対象トークン／カテゴリも照合し、別ルールの窓を他アプリへ誤表示しない。カテゴリ・Webはv1.1ゲート対象外のため解除ボタンを出さない。欠損設定とトークン不一致は上限なし／10分／待ち時間なし、破損読み取りは既存の最小シールドへ倒す。Coreの`tokensToShield`はmacOSでも`swift test`できるよう`Codable & Hashable`のジェネリックにし、iOSでは`Set<ApplicationToken>`を無変換で受ける。全トークンへ解除を出す案、拡張からアプリ本体の文字列カタログを参照する案、Monitor内で監視を張り直す案は却下した。
- Claude Code向けBatch 2制約: `ApplicationToken`の`tokenData`は同じ`JSONEncoder`で符号化し、同期判断は`GateSyncPolicy`を使う。未確認はpreserve、Free確定はゲートストアと`gate_shield_snapshot.json`をclear/removeする一方、設定と台帳は降格で消さない。全データ削除時だけsettings／ledger／snapshotをすべて消す。要求消費後は`dopabreak.gate.unlock.<requestId>`の8秒保険通知を取り消し、前面復帰同期とGrantControllerの再整合を追加する。Deep Focus／夜の別ストアとカテゴリ／Web挙動をゲート側から変更しない。
- 検証: `xcodegen generate`成功。`cd ios/Packages/DopaBreakCore && swift test`は481件・失敗0。iOS 26.5 SDKで`.openParentalControlsApp`を直接コンパイルでき、`xcodebuild -project ios/DopaBreak.xcodeproj -scheme DopaBreak -destination 'generic/platform=iOS Simulator' build`は全7ターゲット`BUILD SUCCEEDED`。両xcstringsは`jq`解析成功、対象差分は`git diff --check`成功、TODO／プレースホルダ0件。

## 2026-08-22 — O-03r クイズ結果へ50年の人生グリッドを追加（オーナー指示）

- 作成・変更: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/LossEstimator.swift` に、年数を満マス数と次マスの横幅比率へ分解して0...50へクランプする純関数 `lifeGridFill(lifetimeYears:)` を追加し、`Tests/DopaBreakCoreTests/LossEstimatorTests.swift` へ指定8入力の表形式テストを追加した。`ios/DopaBreak/OnboardingMotion.swift` に50マス固定・10列×5行の `OnboardingLifeGrid` を実装し、`ios/DopaBreak/OnboardingFlow.swift` の `quizResultContent` で既存lifetime行の直下へグリッドと凡例をstagger 5／6として接続した。`ios/DopaBreak/Localizable.xcstrings` へ `onboarding.result.life_grid.legend` のja/en/koを追加し、`docs/07_onboarding_design_lifefocus.md` のO-03r節へ表示・算出・切り捨て・3言語凡例を同期した。`ios/DopaBreakTests/OnboardingMotionCapture.swift` は結果画面だけ170ptスクロールし、期限までRunLoopを駆動して最終値を確定してから撮影する。
- 採用方針・却下案: 50年を数字だけでなく面積として一目で比較できるよう、1年＝1マス、5.2年＝満5マス＋次マス左側20%を採用した。端数を1マスへ切り上げる案は推計を過大表示するため却下し、新色・追加キャラクター・新しい科学説明画面も既存結果画面の焦点とオーナー指定範囲を広げるため採用していない。塗りは既存 `DesignTokens.accent`、未塗りは `DesignTokens.hairline` を使う。
- Claude Code向け制約: マス数は `LossEstimator.lifetimeHorizonYears` の50、10列×5行、最大幅320pt、間隔6pt、角丸4ptを維持する。端数は次の1マスを左から横幅比率で塗り、常に切り上げない。表示順とstaggerは disclaimer→lifetime=4→grid=5→legend=6。通常時はstagger 5の出現完了後に左上から約25ms/マスで点灯し、Reduce Motion時は即時確定する。VoiceOverでは既存lifetime表示を読み上げ対象から外し、同じ文言をラベルに持つグリッド全体だけを1要素として読み、個々のマスは隠す。Dynamic Typeでマス寸法を変えず、画面内キャラクターは既存1体のままにする。
- 検証: DopaBreakCore全481件・失敗0。`xcodegen generate`成功、署名なしgeneric iOS Simulator向け全7ターゲットは`BUILD SUCCEEDED`、撮影用`build-for-testing`は`TEST BUILD SUCCEEDED`。日本語オンボーディング撮影XCTestは1件・失敗0で`TEST EXECUTE SUCCEEDED`、`output/app-store-screenshots/life-grid-verification/ja/onboarding/03-quiz-result.png`（1320×2868）を原寸目視し、38日／3.7か月／5.2年、50マス、満5マス＋次マス20%、凡例を確認した。xcstringsは`jq`解析と新キーja/en/ko完全一致、`python3 scripts/lint-display-copy.py` exit 0（既存要確認2件のみ）、`git diff --check` exit 0、追加TODO／プレースホルダ0件。

## 2026-08-22 — O-03r 人生グリッド是正（初期位置・可視トリガー・読み上げ）

- 作成・変更: `ios/DopaBreak/OnboardingFlow.swift` は `quizResultContent` だけを調整し、結果画面の通常時を外側12pt／hero内8pt／キャラクター120pt／上端-16pt、スクロールviewport高700pt未満を外側8pt／hero内4pt／キャラクター104pt／上端-20ptとした。iPhone 16（6.1インチ）でも初期スクロール位置0のままグリッド50マスと凡例まで収め、グリッドの最大幅320pt・10列×5行・6pt間隔・4pt角丸は変更していない。`ios/DopaBreak/OnboardingMotion.swift` は `.scrollView(axis: .vertical)` 座標の実寸交差率が50%以上になった時だけ一度ラッチし、左上から25ms/マスで点灯する。固定620ms待機は廃止し、fill・可視ラッチ・Reduce Motionを `.task(id:)` のIDへ含めた。Reduce Motionは `@State` の初期値を最終fillにして空白フレームを作らない。
- アクセシビリティ・撮影: 後発の是正仕様を優先し、lifetime本文は通常の読み上げ対象、グリッド全体と個別マスは読み上げ対象外、凡例は通常要素とした。`ios/DopaBreakTests/OnboardingMotionCapture.swift` は結果画面のScrollViewを明示的にoffset 0へ戻して±0.5ptでassertし、カウントアップとグリッドの確定を待ってから `ONB_STAGE_BEGIN` を出す。170ptの自動スクロールは削除した。
- 採用方針・却下案: 小画面だけ結果の余白とキャラクターを圧縮し、大画面の既存バランスを維持する高さ分岐を採用した。グリッド縮小、共有 `screenScroll` や固定CTAの変更、時間ベースだけの開始判定、撮影時スクロールは、比較可能性・初期画面要件・実可視性を損なうため採用していない。Claude Code側は上記700pt分岐とグリッド寸法を維持し、表示項目追加時もoffset 0で凡例までCTA上に収まることを両端末で再確認する。
- 検証: DopaBreakCoreは481件・失敗0、`xcodegen generate`成功、署名なしgeneric iOS Simulator全ターゲットbuildは終了コード0。日本語撮影XCTestは iPhone 16 Pro Max（1320×2868）とiPhone 16（1179×2556）で各1件・失敗0、いずれもoffset 0 assertionを通過した。原寸目視で50マス、満5マス＋次マス20%、凡例の全体がCTAに隠れず表示されることを確認した。最終PNGは `output/app-store-screenshots/life-grid-verification/iphone-16-pro-max/ja/03-quiz-result-scroll-0.png` と `output/app-store-screenshots/life-grid-verification/iphone-16/ja/03-quiz-result-scroll-0.png`。`python3 scripts/lint-display-copy.py` はexit 0（既存要確認2件のみ）、`git diff --check`はexit 0。

## 2026-08-22 — シールド解除フロー v1.1 Batch 2（アプリ層）実装

- 作成・変更: `ios/DopaBreak/GateShieldController.swift` と `GateGrantController.swift` を追加し、専用ManagedSettingsストアへのアプリトークン限定同期、権利未確認時のpreserve、Free確定時のストア／控えだけの解除、台帳に基づく一時開放、最大5件、16分の一回きり監視、前面復帰回収を実装した。`AppContainer.swift`、`DopaBreakApp.swift`、`NotificationDelegate.swift`、`RootTabView.swift`へ同期順、保留要求のTTL消費、通知取消、通知タップ／activeの入口、自動化起動抑止、全削除を接続した。降格では`gate_app_settings.json`と`gate_ledger.json`を残し、全削除時だけ両方と`gate_shield_snapshot.json`を消す。
- 一呼吸フロー: `InterventionFlowModel.swift`／`InterventionFlowView.swift`は`InterventionTarget.catalog`と`gateToken`へ一般化した。ゲート対象は`GateAppSetting.sessionMinutes`を既定選択にし、確定直前に`GatePolicy.canGrant`を再検証する。拒否時は`recordCancel`で取消ログを残して専用画面へ進み、許可時は既存`recordOpen`後にGrantControllerを呼ぶ。トークンからURL起動は行わず、上部のアプリ表示だけFamilyControlsの`Label(ApplicationToken)`を使い、文章中は「このアプリ」へ倒す。既存のカタログ起動、時間切れ／中間通知、呼吸モーションは維持した。
- 設定UI: `ios/DopaBreak/GateAppSettingSheet.swift`を追加し、Proの`SettingsView.swift`で既存FamilyActivityPickerの選択を共用、選択済みアプリを`Label(token)`の44pt以上の行で表示し、回数（なし/1/2/3/5/10）、長さ（5/10/15/30）、待ち時間（なし/5/10/30/60）をシステムForm／menu Pickerで編集する。Freeは既存カタログ／自動化UIを維持し、`PaywallPlacement.settingsGateGate`のロック行だけ追加した。ペイウォール本文は変更していない。モードPickerは完全ブロック欄に維持し、標準の説明を「標準＝開く前に一呼吸」へ更新した。
- 採用方針・却下案: 日常の一呼吸はアプリトークンだけを専用ストアへ適用し、カテゴリ／Webは常にnilへ戻す。カテゴリを個別解除する案はv1.1正本どおり不採用。設定と台帳を降格で削除する案、通知タップだけに依存する案、ゲート対象をURLスキームで起動する案も、非破壊降格・旧OS／openParentalControlsApp復旧・FamilyControls制約に反するため採用していない。§8.4のlocked_noticeにあった読点は同節の「読点なし」を優先して除いた。
- Claude Code向け制約: `GateShieldController.sync`は夜／Deep Focus／従来シールド同期の後、最後に実行する。`GateGrantController`の監視開始失敗は一時開放を取り消さず`activityName == ""`を保存する。選択一覧は`ApplicationToken`から名前を取り出そうとせず`Label(token)`を使い、Dynamic Typeとシステムシートを維持する。アプリ別設定保存後はreconcile→syncを必ず通す。Free確定時にアプリ別設定／台帳を消さず、全削除時だけ停止中監視を止めて3ファイルと専用ストアを消す。夜／Deep Focusのストア、カテゴリ／Web動作、ペイウォールコピーをこの機能から変更しない。
- 文言・文書: `ios/DopaBreak/Localizable.xcstrings`へ実使用する§8.3／§8.4キーをja/en/ko・manual・画面コメント付きで追加し、通知文言は投稿元である`ShieldActionExtension/Localizable.xcstrings`を正として本体には重複追加しなかった。`docs/11_ui_copy.md`へ指定見出しの§6cと§8.1〜8.4日本語表を追記した。
- テスト・生成: `ios/DopaBreakTests/GateGrantControllerTests.swift`、`GateUnlockConsumptionTests.swift`、`InterventionFlowGateTests.swift`を追加。`xcodegen generate`成功。iPhone 16／iOS 26.5でDopaBreak全168件中163件成功・失敗0・既存条件付き5件skip、追加8件成功。DopaBreakCore全481件成功・失敗0。xcstringsは`jq`解析と対象17キーのja/en/ko／manual充足を確認し、表示コピーlintは既存オンボーディング要確認2件だけで新規指摘0。

2026-08-22 — O-03r人生グリッド小修正: `ios/DopaBreak/OnboardingMotion.swift` は可視ラッチ後250ms待機＋45ms/セル（Reduce Motion即時）、`ios/DopaBreak/OnboardingFlow.swift` は6.1インチもheader規格120pt（104pt案はiPhone 16 scroll 0実写で50セル＋凡例下端からCTA上端まで20pt空いたため却下）、`ios/DopaBreakTests/OnboardingMotionCapture.swift` は1.5秒settle後・マーカー直前にoffset 0±0.5を再assertし、両指定端末の同一パスPNGを更新した；今後も点灯開始をstagger 5の可視開始後、キャラを120pt以上、撮影をscroll 0に保つ。

## 2026-08-22 — シールド解除フロー v1.1 独立レビュー修正（Fix pass）

- 作成・変更: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/{DopaBreakCore.swift,Models/GateModels.swift,Services/GatePolicy.swift,Services/GateStores.swift,Services/LocalDataResetter.swift,Storage/JSONSnapshotStore.swift}`で、要求を台帳から新規`gate_unlock_request.json`へ分離し、`GateUnlockRequestStore`と共通`GateTokenCoding`を追加した。`GateLedgerStore.update`は`NSFileCoordinator(.forMerging)`の単一区間内でread/mutate/atomic writeを完結し、台帳writer（アプリgrant/reconcile、Monitor期限回収）をすべて同APIへ寄せた。要求ファイルのsave/条件付きclearも同じファイル調停で競合を閉じた。`GatePolicy`は日付繰越、日跨ぎcooldown、境界等号、欠損entry作成、終了時刻非退行、`alreadyOpen`、最大5件からの最古回収、古い要求無視、設定token不一致時の既定値、符号化不能tokenのshield維持を実装した。
- 拡張: `ios/ShieldConfigExtension/ShieldConfigurationExtension.swift`と`ios/ShieldActionExtension/ShieldActionExtension.swift`は、`GateShieldSnapshot.selectionDataList`をblob単位で復号し、対象`ApplicationToken`が含まれる場合だけゲート状態／要求投稿へ進む。非memberは窓内なら従来のDeep Focus／夜表示、窓外ならtitle＋「閉じる」の最小表示へ倒す。設定表示側のgoal／窓snapshotは独立した`try?`で読み、破損goalはsubtitleだけを劣化させる。通知応答はNSLockのsingle-shot wrapper＋2秒watchdogで必ず一度だけ完了する。cooldown時刻は`DateFormatter.timeStyle = .short`と`Locale.autoupdatingCurrent`を使う。`ios/MonitorExtension/DeviceActivityMonitorExtension.swift`は自activityを全出口で停止し、壊れたselection blobだけを飛ばし、30秒許容を当該grant IDだけの期限回収に限定し、shield集合は実時刻で計算する。
- アプリ・削除: `ios/DopaBreak/{AppContainer.swift,GateGrantController.swift,ShieldController.swift,SettingsView.swift,InterventionFlowModel.swift,InterventionFlowView.swift,Localizable.xcstrings}`は要求の単一消費／grant時clear、二重grant防止、5件超過監視停止と再shield、共通token codec、`alreadyOpen`防御表示を接続した。`LocalDataResetter`と`AppModel.deleteAllLocalData`はゲート4snapshotを削除し、`ShieldController.clearShield()`は`dopabreak.gate`も解除する。Free降格は専用ManagedSettingsとgate snapshotだけを消し、settings／ledgerを保存する契約を`ios/DopaBreakTests/GateShieldControllerTests.swift`で固定した。
- 採用方針・却下案・制約: legacy `dopabreak.rules`や残存Night／Deep Focusストアをgate根拠へ流用する案、選択blob 1件の破損で全gate集合を空にする案、30秒許容の未来時刻を他grant判定へ流用する案を却下した。Claude Code側は`pendingUnlockRequest`を`GateLedger`へ戻さず、台帳のread-modify-writeは必ず`GateLedgerStore.update`内、FamilyControls tokenのData化は必ず`GateTokenCoding`、Monitorの集合計算は実時刻を維持する。Deep Focus／夜のManagedSettings契約とペイウォールコピーは変更していない。
- 検証: 新規／更新テストは`GatePolicyTests.swift`、`GateStoresTests.swift`、`LocalDataResetterTests.swift`、`GateGrantControllerTests.swift`、`GateUnlockConsumptionTests.swift`、`GateShieldControllerTests.swift`。`xcodegen generate`成功。`cd ios/Packages/DopaBreakCore && swift test`は493件・失敗0。iOS 26.5 iPhone 16（UDID `2483CBE3-7A64-4BC3-A2B3-77BDFD7B41CF`）のDopaBreak XCTestは全170件中165件成功・失敗0・既存条件付き5件skip、result=`Passed`。同destinationの全7ターゲットbuildは`BUILD SUCCEEDED`。3つのxcstringsは`jq`解析成功、対象差分は`git diff --check`成功、追加TODO／FIXME 0件。

## 2026-08-22 — シールド解除フロー v1.1 独立レビュー修正（Fix pass 2・アプリ層）

- 作成・変更: `ios/DopaBreak/RootTabView.swift` と `SettingsView.swift` は、ゲート利用可否を「確認済みFreeだけ拒否、権利未確認はfail-open」で統一し、設定対象をprimary ruleだけでなく全非空ルールのトークン和集合へ変更した。`AppContainer.swift` はshield snapshotまたはキャッシュ済みPro権利があれば確認状態に依存せずgrant再整合を行い、要求のrule解決前消費をやめ、TTL満了／消費成功時に保留通知と配信済み通知を両方消す。全削除のゲート4ファイルは`LocalDataResetter`の成否と独立したbest-effort削除にした。自動化検証はactive grantによる全体抑止より先に記録する。
- grantとフロー: `ios/DopaBreak/GateGrantController.swift` は公開`validate(tokenData:)`でrecordOpen前に上限／cooldown／already-openを確定し、recordOpen後の内部再確認はadvisoryに限定した。already-open競合は既存grantを再利用し、limit/cooldown競合は既に記録済みのopenを取り消さずgrantを進める。台帳commit後のreapply失敗は回復可能として飲み込み、期限切れ監視停止を必ず実行する。activity名の2回目保存失敗では生きているgrantと監視を維持してpending grantを返す。`InterventionFlowModel.swift` はdenialをrecordOpen前だけに出し、成功時はrecordOpen→grant→openingを維持し、ゲート対象だけ中間check-in通知を省いてtime-up通知を残した。
- テスト: `ios/DopaBreakTests/{GateGrantControllerTests,GateUnlockConsumptionTests,InterventionFlowGateTests,GateShieldControllerTests}.swift`へ、未確認権利の表示許可、snapshot／cached tier回復、commit後reapply失敗、2回目save失敗、already-open再利用、recordOpen前拒否、recordOpen→grant→opening成功、rule読取失敗時の要求保持、保留／配信済み通知取消、active grant中の自動化検証＋画面抑止、grant期限後の非抑止、全ruleトークンの重複除去を追加した。
- 採用方針・却下案・制約: GateSyncPolicyの未確認preserveと対になるfail-openを採用し、未確認をFree同様に拒否する案は永久lockoutになるため却下した。recordOpen後にpolicy denialをUIへ返す案、commit済みgrantを後処理失敗として扱う案、rule解決前に要求を消す案、catalogIDのないゲートへ中間通知を送る案も状態不整合またはno-opになるため却下した。Claude Code側は「確認済みFreeだけ拒否」、`recordOpen`後はdenialなし、2回目save失敗でも監視継続、要求はtarget解決後だけ消費、active grantでもautomation verified記録を維持する。Deep Focus／Night、ペイウォールコピー、並行作業中の`OnboardingFlow.swift`／`OnboardingMotion.swift`／`LossEstimator.swift`は変更していない。
- 検証: focused回帰19件・失敗0。`cd ios/Packages/DopaBreakCore && swift test`は493件・失敗0。iOS 26.5 iPhone 16（UDID `2483CBE3-7A64-4BC3-A2B3-77BDFD7B41CF`）のDopaBreak XCTestは179件実行・失敗0・既存条件付き5件skipで`TEST SUCCEEDED`。同destinationの全7ターゲットbuildは`BUILD SUCCEEDED`。対象差分は`git diff --check`成功、追加TODO／FIXME／placeholder／fatalError 0件。

## 2026-08-22 — シールド解除フロー v1.1 独立レビュー修正（Fix pass 3・時刻境界と拡張フェイルセーフ）

- 作成・変更: `ios/DopaBreak/GateGrantController.swift`はgrant終了時刻を分単位へ切り捨てず、次の分境界へ切り上げた時刻をDeviceActivityの`intervalStart`、その16分後を`intervalEnd`にした。`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/GatePolicy.swift`へ純関数`GateReshieldPolicy.decision(grant:now:tolerance:)`を追加し、`ios/MonitorExtension/DeviceActivityMonitorExtension.swift`はgrant欠損／期限回収時だけ監視を止め、`endsAt - 30秒`より早いcallbackでは監視を維持して`intervalDidEnd`を残す。`GateGrantControllerTests.swift`へ`endsAt.second == 45`の分境界回帰、`GatePolicyTests.swift`へ欠損／早着／許容境界の3判断を追加した。
- 拡張・設定・ストア: `ios/ShieldConfigExtension/ShieldConfigurationExtension.swift`の`alreadyOpen`はDeep Focusの最小表示へ落とさず、既存`shield.gate.title`＋subtitleなし＋「閉じる」だけの中立ゲート表示へ変更した。`ios/ShieldActionExtension/ShieldActionExtension.swift`はsingle-shot完了器と2秒watchdogをprimary処理の先頭、全ストアread/writeより前に置き、watchdogを常に`.close`へ固定した。`ios/DopaBreak/GateShieldController.swift`と`SettingsView.swift`は無効ルールをゲート適用／アプリ別設定一覧から除外し、`GateShieldControllerTests.swift`で控えと一覧の両方を固定した。`GateStores.swift`のNSFileCoordinator書込みoptionはatomic replaceの実装に合わせ`.forReplacing`へ変更した。
- 採用方針・却下案: 分境界の切り上げと早着callback時の監視維持を組み合わせ、開始callbackがgrant終了前に来て監視まで消える穴を両側から閉じた。Monitor内で監視を再登録する案は同名登録のデッドロック回避契約を壊すため採用せず、既存`intervalDidEnd`を保険として残した。`alreadyOpen`へ新規コピーを足す案は却下し、Apple UIの予測可能性と安全な退出を保つ既存ゲートタイトル＋単一の「閉じる」を再利用した。
- Claude Code向け制約: DeviceActivityの開始は常に`intervalStart >= grant.endsAt`、終了はその開始から16分後を維持する。`GateReshieldPolicy`はgrant欠損=`reshield false / stop true`、許容より早い=`false / false`、期限回収=`true / true`の契約を崩さない。ShieldActionのwatchdogはストレージ処理より前、応答は`.close`、遅着した実応答はsingle-shotで無視する。ゲート選択と設定対象は`rule.isEnabled`のみ。Deep Focus／Night、ペイウォール文言、並行作業中の`OnboardingFlow.swift`／`OnboardingMotion.swift`／`LossEstimator.swift`は変更していない。
- 検証: focused Core 3件・iOS 12件はいずれも失敗0。`cd ios/Packages/DopaBreakCore && swift test`は496件・失敗0。iOS 26.5 iPhone 16（UDID `2483CBE3-7A64-4BC3-A2B3-77BDFD7B41CF`）の`xcodebuild test`は181件実行・既存の手動撮影5件skip・失敗0で`TEST SUCCEEDED`。新規ファイルなしのため`xcodegen generate`は不要。対象tracked差分の`git diff --check`と対象untrackedファイルの末尾空白監査はclean。

## 2026-08-23 — App Storeスクショ ja／ko パネル04をホーム画面訴求へ是正（オーナー指摘対応）

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` と承認コピー正本 `scripts/generate-appstore-screenshots.py` のja／ko #04を、モード訴求からホームの目標・今日／今週実績に一致する指定コピーへ同時変更した。旧スクリプトにも両ロケールの該当エントリが存在したためv2だけにはせず、koを含む `validate_legacy_copy_reuse` の一致を維持した。`.claude/specs/appstore-screenshots-v2-diagonal.md` のja #04正本も同期した。en-USコピーは変更していない。
- 再生成・同期: `output/app-store-screenshots/v2/{ja,ko}/iphone-69/04-modes.png` と `contact-sheet-ja.png`／`contact-sheet-ko.png` をロケール限定生成で更新し、生成04を `output/app-store-screenshots/v2/upload-order/{ja,ko}/iphone-69/05-modes.png` へ再コピーした。コピー幾何を記録する `slots-ja.json`／`slots-ko.json` とja互換の `slots.json` も同時更新した。他のja／koパネル18枚は作業前後のSHA-256が不変だった。
- 採用方針・却下案: #04の画面は引き続き `raw-core/{ja,ko}/home.png` を使い、コピーを画面内容へ合わせる方針を採用した。モード選択UIはオンボーディングと設定にしかないため、ホーム画面側の変更、実在しないモード状態の合成、raw再撮影は採用していない。Claude Code側は独立したモード実画面が追加されない限り#04のhomeフォールバック、生成04→アップロード05の対応、画面内1体／外乗せ0体、見出しの `horizontal_scale_ratio=1.0` を維持する。ja／ko #04を変更する場合は今後も旧正本とv2を同時更新し、en-US出力を再生成しない。
- 検証: ja／ko #04はApp Store CLIプリフライトで各1320×2868・問題0、独立PIL／slots検査でPNG／RGB・キャラ合計1体・home source・見出し2行の横スケール各1.0を確認した。macOS Vision OCRは両言語のeyebrow・見出し2行・subを指定文字列どおり完全一致で認識し、画面内の目標、今日12回、試行15回、今週36回も認識した。生成04とupload-order 05のSHA-256はja=`3d589371ec270cede373c9c41a3ee4a82c153cc69e3bd450696b1d17ed792b4d`、ko=`d559bed7285ab88eeb0b445d5a0b756a6468f0601a804a562c180c983a022f4b`で各ペア一致。en-USの生成10枚＋contact sheet＋upload-order 10枚の計21件は作業前後で全SHA-256不変。`python3 scripts/lint-display-copy.py`は既存要確認2件のみでexit 0、対象差分の`git diff --check`もexit 0。

## 2026-08-24 — 機能画面リデザイン Phase 1（Home／止めるアプリ／共通部品）

- 作成・変更: `ios/DopaBreak/AppIconView.swift` にカタログ8種のブランド色タイル、30pt上限のScreen Time token分岐、重なり表示と`+N`を持つ`AppIconStack`を追加した。`DopaRing.swift`、`DayBars.swift`、`TargetAppGrid.swift`を新設し、`TargetAppPickerSheet.swift`と`OnboardingFlow.swift`は同じ選択グリッドを使用する。`HomeView.swift`は日付／横組みヒーロー／連続日数／取り戻した時間／止めているアプリ／週7日バー／アプリ別内訳／満足度／目標の順へ再構成した。`StatsService.swift`と`StatsServiceTests.swift`へルール別試行・取消、直近満足度、連続日数、中央値ベースの取り戻し時間を追加した。
- 文言・撮影: `ios/DopaBreak/Localizable.xcstrings`へPhase 1の新規23キーをja/en/koで追加し、既存`home.hero.today`と`home.week.eyebrow`から英語だけの装飾見出しを除いた。正本文言は`.claude/specs/functional-screens-redesign-copy-sheet.md`へ記録した。`ios/DopaBreakTests/CoreScreensSnapshotCapture.swift`へ他rawを上書きしない専用撮影テストを追加し、`output/screenshots/redesign-phase1/{home,home-free,target-picker}.png`をiPhone 16 Pro Max・ja/JP・ダーク・1320×2868で生成した。
- 採用方針: 2026-08-24のHome追記を親ブリーフより優先し、Homeでは`DopaRing`を使わず112ptのDopaと56ptの実績を横組みにした。Apple HIGに合わせ、操作領域は44pt以上、Deep Focus CTAは48pt、シートはNavigationStack＋標準dismiss、狭幅は`ViewThatFits`で縦組み、アクセシビリティ文字サイズでは選択グリッドを2列から1列へ切り替える。ライムは今日・選択・進行だけに限定し、Freeの分析2カードは実データと高さを保持したままblur＋同一CTAを重ねる。アプリ別対応はスキーマを増やさず、空selectionのカタログルール名と選択中カタログ名の完全一致だけを使う。
- 却下案・未対応理由: 他社ロゴ画像／SVGの同梱、tokenアイコンの44〜60pt拡大、Homeヒーローのリング、独自sheet遷移、新しいcatalogID列は商標・描画品質・承認モック・既存保存契約の理由で採用していない。ピッカーの「今週◯回」サブラベルは、永続化されたcatalogID↔ruleID対応がなく、同名の任意Screen Timeルールを誤集計し得るためPhase 1では表示しない。Home内訳は「選択中カタログ＋空selection＋完全一致」という限定条件でのみ対応する。
- Claude Code向け制約: `HomeView`のStatsService注入経路は撮影決定性のため残し、本番では共有SQLiteの既定値を使う。`HomeStatsProvider`と日付窓は読み取り専用とし、新しい計測イベントを増やさない。`TargetAppGrid`はTargetAppPickerとOnboardingの共用品で、Free上限／保存／遷移は各親に残す。Dynamic Typeの1列フォールバック、各アイコンの8pt稼働ドット、DayBarsの古い順7件とindex 6の今日強調、Free blurの同一高さ、同数満足度のcase順、初日で取り戻し時間・アプリ別・満足度を隠す条件を維持する。Homeの30分CTAは仕様どおり`AppModel.startDeepFocusSession(durationMinutes: 30)`を呼ぶだけとし、保護対象の`AppContainer.swift`やシールド解除フローは変更していない。このAPIは既存のDeep Focus用Screen Time selection／rule modeを前提とし、カタログ選択からtokenやmodeを新規生成しないため、Claude側で契約を変える場合はモード復元を含む別仕様として扱う。
- 検証: `xcodegen generate`成功。指定iPhone 16 Pro Max向け署名なしbuildは`BUILD SUCCEEDED`。DopaBreakCore全505件・失敗0、専用撮影XCTest 1件・失敗0。`Localizable.xcstrings`は`jq`解析成功、`python3 scripts/lint-display-copy.py`は既存オンボーディング要確認2件のみでexit 0、`git diff --check`成功。`audit-default-values.py`はPhase 1追加キーにmissing／mismatch／unresolved／specifier-typeなしだが、保護対象の並行変更に既存`SettingsView.swift` mismatch 1件と`ShieldActionExtension.swift` unknown-target 2件が残るため、全体summaryのみ0にはなっていない。

## 2026-08-24 — 機能画面リデザイン Phase 1 最終是正・検証

- 作成・変更: `ios/DopaBreak/{AppIconView,DopaRing,DayBars,TargetAppGrid}.swift`を共通部品として確定し、`TargetAppPickerSheet.swift`と`OnboardingFlow.swift`を共通2列グリッドへ接続した。`HomeView.swift`は2026-08-24追記の横組みHome、取り戻した時間、止めているアプリ、週バー、アプリ別・満足度のPro/Free表示、目標カードを実装した。`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/StatsService.swift`の`appRuleBreakdownDetailed`は指定どおり`[UUID: (attempts: Int, cancelled: Int)]`を返し、連続日数・取り戻した秒数と合わせて`StatsServiceTests.swift`で固定した。`CoreScreensSnapshotCapture.swift`にはraw-coreを上書きしないPhase 1専用撮影を追加した。
- 文言の訂正: 直前記録の「新規23キー」は誤りで、正しくはコピーシート20キーのうち**新規18キー＋既存2キー更新**。`ios/DopaBreak/Localizable.xcstrings`はその20キーだけをja/en/ko正本へ一致させ、他キーを並べ替えていない。部品固有の新規アクセシビリティ文言を増やす案はコピーシート限定条件に反するため却下し、既存`stats.*`／`shortcuts.*`キーと`.isSelected` traitを再利用した。
- 採用方針・制約: 選択インジケータは承認仕様どおりチェックを置かないライム塗り丸、未選択は灰の輪郭丸とした。アクセシビリティ文字サイズではグリッドを1列へ落とし、ホームのカード本文とCTAは別のタップ領域を維持する。共有`PrimaryButtonStyle`は最小56pt固定で、追記仕様の48ptと同時に満たせないため、既存トークンと同じ色・モーションを使うHome専用48pt styleを採用し、共有style自体は変更していない。保護対象の`AppContainer.swift`等は編集せず、30分CTAは公開済み`startDeepFocusSession`／`endDeepFocusSession`だけを呼ぶ。
- 撮影・検証: `output/screenshots/redesign-phase1/{home,home-free,target-picker}.png`を日本語・ダーク・iPhone 16 Pro Maxで各1320×2868として再生成し、原寸目視した。専用XCTest 1件・失敗0、DopaBreakCore全505件・失敗0、`xcodegen generate`成功、指定UDID・署名なしbuildは`BUILD SUCCEEDED`、copy sheet照合20キー×3言語一致、xcstringsの`jq`解析、表示コピーlint、`git diff --check`はいずれも成功。全体defaultValue監査だけはPhase 1外かつ編集禁止の現HEADにある`SettingsView.swift` 1件と`ShieldActionExtension.swift` 2件で失敗するため、Phase 1ファイルを変更せず残した。

## 2026-08-24 — 機能画面リデザイン Phase 1 独立レビュー Fix pass

- Deep Focus契約: `ios/DopaBreak/{DeepFocusScheduler,ShieldController,AppContainer}.swift`、`ios/MonitorExtension/DeviceActivityMonitorExtension.swift`、Coreの`DeepFocusShieldSnapshot.swift`／`DeepFocusWindowPolicy.swift`／`ShieldSyncPolicy.swift`を更新した。手動セッションは保存済みモードを変更せず、有効かつselectionを持つ全ルールを一時的に完全ブロックする。週次予定用の`selectionDataList`と手動用の`sessionSelectionDataList`を分け、旧snapshotはoptional欠損時に従来リストへフォールバックする。手動と予定の重複中は和集合、片方の終了後は残った窓の集合へ戻す。アプリ側はDeep Focus／Nightの別ManagedSettingsストアを維持し、夜ルールが手動セッションにも含まれる場合は同じ制限済みtoken集合を両ストアへ流すため、手動終了で夜ブロックを消さない。
- Homeと共通判定: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/InterventionModeResolver.swift`を新設し、確認済みFreeのshieldモードだけを`.standard`へ丸め、未確認時は保存値を保持するSettings相当の契約を`HomeView.swift`へ適用した。Homeの手動Deep Focus表示は現在モードに依存させず、満足度件数は「回答総数、最多満足度件数」の順へ修正した。30秒tickで日付境界を検出してdashboardを再読込し、夜の残り時間算出不能時は夜ラインへフォールバック、年換算は整数なら小数部を省き非整数だけ1桁を残す。
- UI是正: `ios/DopaBreak/DayBars.swift`は1列1GeometryReaderの共通スケールで取消／開いた回数を積み、0日はライムを描かず中立hairlineだけを置く。今日ラベルは既存accent背景＋background文字色の高コントラストchipにした。`HomeView.swift`のFree blurはカードと同じ連続角丸でZStack全体をclipする。`TargetAppGrid.swift`へ任意のstagger baseを持たせ、`OnboardingFlow.swift`は各行を元の`4 + index`で登場させる。
- 採用方針・却下案: 手動開始時にルールの保存モードを`.deepFocus`へ書き換える案はセッション終了後の標準／夜設定を破壊するため却下した。Deep FocusとNightを同一ストアへ統合する案は片方の終了が他方を解除するため却下した。DayBarsの上下を別GeometryReaderへ分ける案、今日文字を半透明ライム上のライムで残す案、blurだけをclipする案も、比例関係・可読性・角丸境界を壊すため採用していない。Apple Design／HIGの確認に基づき、既存token内でコントラストと44pt以上の操作領域を維持した。
- Claude Code向け制約: 手動セッション判定と週次予定判定を再び`currentMode == .deepFocus`へ束ねない。snapshotの予定／手動selectionを混同せず、片方の窓が終わるたび有効集合を再適用する。手動終了時にNightストアを直接clearせず、Shield同期で現在の夜窓を再評価する。`InterventionModeResolver`は確認済みFreeだけをclampし、通信失敗時に保存値を書き換えない。DayBarsは週最大totalに対する単一比例スケール、TargetAppGridのOnboardingはbase 4＋item index、満足度文字列の引数順はanswered→topCountを維持する。`SettingsView.swift`、`InterventionFlow*`、`Gate*`は本Fix passで変更していない。
- 検証: `cd ios/Packages/DopaBreakCore && swift test`は512件・失敗0。追加Scheduler回帰は20件・失敗0。`xcodegen generate`成功。指定iPhone 16 Pro Max（`90F5A09F-D128-468C-AB02-7ABB1479B3AE`）向け署名なしbuildは`BUILD SUCCEEDED`。`audit-default-values.py`と`lint-display-copy.py`はexit 0、`git diff --check`成功、追加TODO／FIXMEなし。Phase 1専用撮影XCTestは1件・失敗0で、`output/screenshots/redesign-phase1/{home,home-free,target-picker}.png`を日本語・ダーク・1320×2868で再生成し原寸目視した。

## 2026-08-24 — Home Freeの週次振り返りCTA重複を統合

- 作成・変更: `ios/DopaBreak/HomeView.swift` のFree向け分析表示を `dashboardInsightsSection` にまとめ、アプリ別カードと満足度カードは個別のぼかしプレビューを維持しながら、`weeklyReviewButton` を2枚全体に対して1回だけ表示する構成へ統合した。`output/screenshots/redesign-phase1/home-free.png`を日本語・ダーク・iPhone 16 Pro Maxで再生成した。
- 採用方針・却下案: 同じ文言・同じ `.statsHistoryGate` へ進むCTAをカードごとに反復する案は、別機能に見えて情報階層を乱すため却下した。プレビューを1枚へ減らす案もProで見られる内容が伝わらなくなるため却下し、2枚の形と高さは残して共通CTAだけ1個にした。
- Claude Code向け制約: Freeでも各カードの実データ・高さ・blur 10・`backgroundRaised` 60%を維持する。CTAの遷移先は `.statsHistoryGate`、タップ領域は44pt以上、Pro時は同じ2カードをぼかさず表示する。カードが片方だけ存在する場合もCTAは1個だけにする。
- 検証: `HomeView.swift`内の `stats.paywall.weekly_report` 参照は1箇所、`git diff --check -- ios/DopaBreak/HomeView.swift`は成功。署名なしSimulatorビルドは成功し、再生成した`home-free.png`を原寸目視してCTAが1個だけであることを確認した。撮影XCTestは3枚のPNG保存後にテストホストがsignal killとなりexit 65のため、テスト完走扱いにはしていない。

## 2026-08-24 — 週グラフ・設定秒数・行動コピーのオーナー是正

- 作成・変更: `ios/DopaBreak/DayBars.swift` は取消／開いた回数の積み上げを廃止し、週の「開くのをやめた回数」だけをライムの単系列で表示するよう変更した。`ios/DopaBreak/HomeView.swift` は固定の行動保証に見えた「開く前にN秒の間」を、保存済み `breathDurationSeconds` を明示する「一呼吸の設定：N秒」へ変更した。`ios/DopaBreak/StatsView.swift` は週グラフの灰色系列・灰色凡例を外し、試行総数は色を割り当てない補助テキストとして残した。またFreeの3つの分析プレビューに対する週次CTAを1個へ統合した。
- コピー: 画面・通知・オンボーディング・ロック画面・ウィジェット・App Storeスクリーンショット原稿に残っていた、結果だけを機械的に述べる「開かなかった」を、本人の選択が伝わる「開くのをやめた」へ統一した。`ios/DopaBreak/Localizable.xcstrings` と `ios/WidgetsExtension/Localizable.xcstrings` はja/en/koを同時更新し、`.claude/specs/functional-screens-redesign-copy-sheet.md` とPhase 1/2ブリーフへ後発のオーナー決定として記録した。Coreのコメントと内部フィールド名 `cancelled` は保存・集計契約のため変更していない。
- 採用方針・却下案: 灰色を「開いた回数」として積む案は、週カードの主題が取消回数なのに母数との差分まで同じグラフへ持ち込み、棒の意味と高さを曖昧にするため却下した。8秒を普遍的な挙動として断定する案も、ユーザー設定で変わる値のため却下した。同一遷移先のCTAをカードごとに反復する案は、複数の権利に見えるためHome／記録ともグループ単位1個にした。日本語はhumanizer-jpの観点で、否定結果ではなく選択した行動として読める表現を優先した。
- Claude Code向け制約: `DayBars` はcancelledの週最大値で正規化する単系列を維持し、0日はデータ棒ではなく3ptの中立基準点だけを置く。attemptsはVoiceOverと補助テキストでは参照できるが、灰色系列として再導入しない。秒数表示は必ず `settingsStore.breathDurationSeconds` を参照し、CTAはHome分析グループにつき1個、StatsのPro分析グループにつき1個、遷移先は `.statsHistoryGate`、最小タップ高44ptを維持する。
- 検証: `audit-default-values.py` はmismatch／missing／unresolved／specifier-typeすべて0、`lint-display-copy.py`は既存オンボーディング要確認2件のみでexit 0、両xcstringsの`jq`解析と`git diff --check`は成功した。DopaBreakCoreは513件・失敗0、generic iOS Simulator向け全7ターゲットは`BUILD SUCCEEDED`。`output/screenshots/redesign-phase1/{home,home-free}.png` と `output/screenshots/redesign-phase2/{stats-pro,stats-free}.png` を日本語・ダーク・1320×2868で再生成・目視し、緑単系列、実設定値「8秒」、CTA各1個、「開くのをやめた」を確認した。Phase 1専用撮影は完走、Phase 2専用撮影は画像保存後のテストホスト切替でUIScrollView取得失敗が残るためテスト完走扱いにはしていない。

## 2026-08-24 — 機能画面リデザイン Phase 2（記録）実装完了

- 作成・変更: `ios/DopaBreak/StatsView.swift` を期間チップ（今週／今日／全期間）、率＋期間別可視化のヒーロー、アプリごと、見たあとの気持ち、開こうとした理由の順へ再構成した。Phase 1の `AppIconView` と `DayBars`、既存 `MetricBlock`／`CardContainer`、既存 `StatsService.appRuleBreakdownDetailed` を再利用し、StatsServiceの重複APIや新しい計測・保存列は追加していない。Freeは今日だけを選択可能とし、今週／全期間は `.statsHistoryGate`、3つの実データカードはblur 10＋`backgroundRaised` 60%を維持してグループ全体に既存CTAを1個だけ置く。
- 文言: `ios/DopaBreak/Localizable.xcstrings` はコピーシート指定どおり、新規9キー `stats.title`、`stats.period.{week,today,all}`、`stats.apps.{title,empty,ratio}`、`stats.reflection.title`、`stats.intent.title` をja/en/koで追加した。既存8キー `stats.header.week.title`、`stats.summary.{today,week}.label`、`stats.weekly_detail.label`、`stats.weekly_detail.comparison.label`、`stats.empty.description`、`stats.behavior.label`、`stats.all_time.label` だけを正本へ更新し、既存キーの順序とそれ以外の値は変更していない。`stats.apps.title=アプリごと`、`stats.reflection.title=見たあとの気持ち` をブリーフ例より優先した。
- 採用方針・却下案: 週グラフは後発オーナー決定どおり `DayBars` のライム単系列を維持し、試行総数は色を持たない補助テキストとした。灰色系列／灰色凡例の再導入、Free用サンプルデータ、カードごとのCTA反復、ruleId→catalogIDの新規保存スキーマは採用していない。ルール表示は既存RuleStoreを引き、空selection＋カタログ名完全一致、単一ApplicationToken、最後にTargetRule.name＋中立アイコンの順で解決し、ルールまたは名前が欠ける行だけを除外する。旧 `anxietyCheck` は記録を捨てず、現行の承認済み「連絡を確認」へ集約する。
- UI制約: Apple Design／HIGの確認に基づき、期間チップとCTAは44pt以上、native `NavigationStack`＋large title、狭幅は `ViewThatFits`、理由は幅追従Layout、数値はmonospaced／numeric transitionを使う。前週比は数値だけaccent、アプリ名は74pt・1行省略、tokenアイコンは30pt、気持ちは固定40pt・5列を維持する。Free/Proで分析カードの形と高さを変えず、アンロック時も選択期間が今日なら勝手に今週へ戻さない。
- Core・撮影: `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/ShieldSyncPolicyTests.swift` に `testManualDeepFocusSessionDoesNotApplyWithoutConfirmedProEntitlement` を追加し、手動Deep Focus中でも権利未確認はpreserve、確認済みFreeはclearでapplyしない契約を固定した。`ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` のPhase 2専用テストはPro／Freeを独立Windowへ載せ、内容が画面高に収まるScrollViewも最上端へ戻せる候補選択へ修正した。直前記録の「画像保存後に失敗」は解消し、専用XCTest 1件・失敗0で完走する。
- 検証・成果物: `audit-default-values.py` は全不一致項目0、`lint-display-copy.py` は既存オンボーディング要確認2件のみでexit 0、`xcodegen generate`成功、指定iPhone 16 Pro Max（`90F5A09F-D128-468C-AB02-7ABB1479B3AE`）向け署名なしbuildは `BUILD SUCCEEDED`、DopaBreakCore全513件・失敗0、`git diff --check`成功。`output/screenshots/redesign-phase2/stats-pro.png`（Pro・今週）と `stats-free.png`（Free・今日・ぼかし）を日本語・ダーク・1320×2868で再生成し原寸目視した。未対応項目はない。

## 2026-08-24 — オーナー訂正完了パス（行動コピー・Free共通CTA）

- 作成・変更: 正本 `.claude/specs/functional-screens-redesign-copy-sheet.md` と Phase 1 Home追記末尾を後勝ちで照合し、`ios/DopaBreak/{DesignTokens,HomeView,InterventionFlowView,PaywallView,LockScreenCheckView,LockSurfaceCoordinator,StatsView}.swift`、`ios/DopaBreak/Localizable.xcstrings`、`ios/WidgetsExtension/{DopaBreakWidgets.swift,Localizable.xcstrings}`、`scripts/{generate-appstore-screenshots.py,generate-appstore-screenshots-v2.py}`、`.claude/specs/{appstore-screenshots-v2-diagonal.md,home-screen-fact-copy-redesign.md}` の同一行動ラベルを「開くのをやめた」へ統一した。内部の `cancelled`、保存形式、集計ロジック、`gate.*`、行動ラベルではないオンボーディング物語文は変更していない。
- 孤児diffの裁定: `DesignTokens.swift`、`PaywallView.swift`、`LockScreenCheckView.swift`、`LockSurfaceCoordinator.swift` とWidgetsの基本ラベルは正本一致のため採用した。`InterventionFlowView.swift` の成功見出しは独自言い換えから正本語彙へ、Live Activityは名詞列から「今日はN回 開くのをやめた」へ、Home／Statsの共通CTAは `stats.paywall.weekly_report=記録を全部見る` へ修正した。破棄した訂正diffはない。今回の訂正外にある既存の未コミット差分は上書き・巻き戻しをしていない。
- ローカライズ: 今回のcatalog差分は既存4キーだけで、mainの `intervention.success.title`／`stats.paywall.weekly_report` とWidgetの `live_activity.summary.cancelled`／`widget.summary.today_cancelled` をja/en/koで更新した。キー追加・並べ替えはない。変更した英語5文はhumanizer-enで平均4.6語・SD 1.20・min 4・max 7・全パターン0、韓国語5文は平均11.6字・SD 3.88・min 9・max 19・読点率0%・全パターン0、どちらもexit 0。`gate.*` はHEAD／作業ツリーの抽出SHA-256が同一だった。
- UI方針・制約: Home Freeの「アプリごと」「SNSを見てどうだった？」は実データ、個別カード高、blur 10、`backgroundRaised` 60%を維持し、2カードを包む `ZStack` の中央へ `.statsHistoryGate` CTAを1個だけ重ねる。Stats Freeも同じグループCTA方式を維持する。カードごとの同一CTA反復は別権利に見えるため却下した。Apple HIG／Apple Designに従いCTAのタップ領域は44pt以上、CTAに金額を含めない。撮影シードの2.3時間/日・週6時間0分・連続7日・週36回は変更しない。
- 検証・成果物: `audit-default-values.py` はcalls 765、mismatches／missing／unresolved／specifier-type／unknown-targetすべて0。`lint-display-copy.py` は既存オンボーディング要確認2件だけでexit 0。両xcstringsの`jq`解析、`xcodegen generate`、全体`git diff --check`は成功した。指定iPhone 16 Pro Max（`90F5A09F-D128-468C-AB02-7ABB1479B3AE`）向け署名なし7ターゲットは `BUILD SUCCEEDED`、DopaBreakCoreは513件・失敗0、Phase 1／Phase 2専用撮影XCTestは各1件・失敗0。`output/screenshots/redesign-phase1/{home,home-free}.png` と `output/screenshots/redesign-phase2/{stats-pro,stats-free}.png` を日本語・ダーク・各1320×2868で再生成して原寸目視し、新語彙、自然な週文、Freeの共通CTA各1個、実データぼかしを確認した。撮影opt-in環境変数は実行後に解除し、空であることを確認した。

## 2026-08-24 — 止めるアプリ選択シートのカード拡大（オーナー指示・実装済み）

- 指示: 選択シートのアプリ要素が小さく下余白が多すぎる → カードを大きくする。
- 実装: `TargetAppGrid.swift` に `Style`（.regular/.large）を追加。regularは従来値そのまま（アイコン50/文字15/縦11/minHeight72/間隔8/インジケータ22）でオンボーディングは無変更。largeはアイコン60/文字17/横14/縦16/minHeight96/間隔12/インジケータ24。`TargetAppPickerSheet.swift` は `.large` を使用し下余白60→32pt。
- 体制: 実装=Codex（gpt-5.6-sol Fast/effort max）、レビュー=Opus5サブエージェント（指摘なし）、ビルド成功確認済み。

## 2026-08-24 — Homeと統計の役割重複を解消（オーナー承認仕様）

- 作成・変更: 正本 `.claude/specs/home-stats-dedup.md` に従い、`ios/DopaBreak/HomeView.swift` から `dashboardInsightsSection`、アプリ別／満足度カード、Freeのぼかしプレビュー、週次CTA、対応する集計データ・補助型・先週比較を削除した。旧位置には初日空以外で常時出る1行の統計導線カードを追加した。`ios/DopaBreak/RootTabView.swift` は `HomeView.onOpenStats` から `.stats` を選択し、`ios/DopaBreakTests/HomeStatsLinkDestinationTests.swift` はPro／Freeの2分岐を固定する。
- 採用方針・却下案: Homeは現在の状態と操作、Statsは振り返りと分析に一本化する。直前履歴にある「Home Freeへ実データのぼかし分析カードを残す」案は、本オーナー承認仕様により上書きした。Proは `home.stats_link.title` と右chevronで統計タブへ進み、Freeは既存 `stats.paywall.weekly_report` と左lockで `.statsHistoryGate` を維持する。StatsViewと共有の分析ロジック／キーは変更していない。
- 文言・UI制約: `ios/DopaBreak/Localizable.xcstrings` に `home.stats_link.title` をja/en/koで追加し、jaのcatalog値とdefaultValueを「アプリごとの内訳と振り返りを見る」で一致させた。Home専用で未使用になった `home.apps.*` と `home.reflection.{count,top}` は削除し、共有 `reflection.satisfaction.title` は残した。表示文言は句読点・造語・内部用語なし。Apple HIGに従い行全体をButtonとし、既存 `CardContainer`／`dopaFont`／色トークンと44pt以上の内容高を維持する。
- Claude Code向け制約: `HomeView` の `onOpenStats` は既定 `{}` を維持してプレビュー／撮影テストを壊さない。導線の表示条件は `!isFirstDayEmpty` だけで、アプリ別データの有無へ戻さない。Homeへ `weeklyDetailReport`、`appRuleBreakdownDetailed`、reflection集計、先週比較、ぼかしカードを再導入せず、比較と分析はStats側だけに置く。
- 検証: `xcodegen generate`、新規分岐テスト2件、手動撮影5スイートを除くDopaBreakTests全175件、DopaBreakCore全513件が失敗0。README記載の署名なしgeneric iOS Simulator向け全7ターゲットは `BUILD SUCCEEDED`。`audit-default-values.py` はmismatch／missing／unresolved／specifier-type／unknown-targetすべて0、`lint-display-copy.py` は既存オンボーディング要確認2件のみでexit 0、xcstringsの`jq`解析と`git diff --check`も成功した。スクリーンショットは再生成していない。

## 2026-08-24 — 60fps MCP モーション監査（提案・未実装）

- 確認範囲: `ios/DopaBreak/TargetAppGrid.swift`、`TargetAppPickerSheet.swift`、`StatsView.swift`、`DayBars.swift`、`LockScreenCheckView.swift`、`PostUseReflectionSheet.swift`、`CharacterView.swift`、`OnboardingMotion.swift`、`InterventionFlowView.swift` と、最新の `output/screenshots/redesign-phase1/`／`redesign-phase2/`／`output/app-store-screenshots/raw-core/ja/` を監査した。60fps MCPでは `outlook-select-multiple-animation`、`harvee-tab-switch-graph-morph-interaction`、`google-todo-check-interaction`、`gentler-streak-pause-wellbeing-sad-reaction` の完全なmotion breakdownを参照した。アプリコードは変更していない。
- 優先提案1（記録）: 期間ピルは `withAnimation(DopaMotion.control)` で変わるが、`reloadDashboard()` のdashboard一括代入と `DayBars` の高さには連続性がなく、グラフ／カード内容が硬く差し替わる。Harveeの「同じデータ面を保ったままmorph＋crossfadeする」考え方だけを採用し、選択ピルの共有インジケータ、数値の既存numeric transition、棒高の補間、週／今日／全期間の内容crossfadeを同じ状態変更へ束ねる。60fpsの具体的な時間値は提供されていないため新規数値を作らず、既存 `DopaMotion.control`／`transition` を実装値として使う。
- 優先提案2（止めるアプリ）: 選択時はカード枠と右端の丸が即時に切り替わり、押下scaleだけが動く。Outlookの高速・subtle springによる選択マーカー変形を、承認済みの「チェックを置かないライム塗り丸」へ翻訳し、丸のscale/fillと枠色だけを `DopaMotion.control` で補間しselection hapticを返す。チェックマークへの変更、カードの再配置、複数項目の連続staggerは現行仕様と単発タップの文脈に合わないため採用しない。
- 優先提案3（ロック画面確認）: `phase` 更新で手順カード／成功badge／プレビュー減光が同時に差し替わり、成功の確定感が弱い。Google Todoの「進行状態をfade/scaleで成功checkへ受け渡す」構造を採用し、手順をcollapse＋fade、プレビューを0.5→1.0、成功badgeをsubtle scale＋fade、確定時にsuccess hapticとする。画面全体の祝福演出や粒子は実用的な設定確認に対して過剰なので採用しない。
- 維持判断: 一呼吸は単一uptimeからリング・秒数・表情・呼吸・ハプティクスを同期し、Reduce Motion経路もあるため、追加演出を載せない。振り返りは表情blink swap＋1.06 pop＋未選択行減光＋550ms保持がすでに選択結果を伝えている。Gentler Streakの全幅色面拡大は情緒が強すぎるため採用せず、必要ならselection hapticだけを追加する。オンボーディングも40ms stagger、count-up、可視域起点のlife-grid、Reduce Motion代替が揃っているため全面改修対象外。
- Claude Code向け制約: 実装する場合も、選択インジケータはチェックなし、Statsのカード形状・実データ・Free blur、ロック画面確認の状態機械と非同期判定、振り返りの550ms二重送信防止を維持する。Reduce Motionではscale/slide/morphを止め、opacity/colorと非モーションの状態表示へ縮退する。60fps参照のブランド、コピー、アセットは移植せず、相互作用の論理と知覚的な階層だけをDopaBreakへ適応する。

## 2026-08-24 — Phase 2 correction batch（空状態・期間別凡例・表示コピー）

- 作成・変更: `ios/DopaBreak/StatsView.swift` は、選択期間の `dashboard.summary.attempts == 0` ならヒーローと分析カードを置かず、`stats.empty.title` と `stats.empty.description` の空状態へ置き換えるよう接続した。ヒーロー下の凡例は `period == .week` の場合だけ表示し、今日／全期間の数値重複を外した。`ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` には空DBのProモデルを使う `stats-empty.png` 撮影を追加した。
- コピー: `.claude/specs/functional-screens-redesign-copy-sheet.md`、`ios/DopaBreak/Localizable.xcstrings`、`ios/DopaBreak/HomeView.swift` の `home.targets.breath_line` を正本の「開く前に%lld秒の間が入ります」／`A %lld-second pause comes before they open`／`열기 전에 %lld초 간격이 생겨요`へ戻した。Widgetは `widget.summary.today_cancelled` を「今日 開くのをやめた」系へ、Live Activityとロック画面プレビューの英語複数形を `%lld×` 形式へ統一し、韓国語の `stats.metric.attempted` はラベル形「열려고 함」とした。`scripts/generate-appstore-screenshots.py` のen-US／ko表示行も `Chose not to open`／`열지 않기로 함` 系へ同期し、v2は同スクリプトの再利用検証を通した。シード数値は変更していない。
- カタログ整理: Swiftとscriptsを先に検索し、参照0だった `stats.paywall.full_history`、`stats.behavior.label`、`stats.behavior.opened`、`stats.header.today.title`、`stats.header.week.title`、`stats.summary.today.label`、`stats.summary.week.label`、`stats.weekly_detail.label`、`stats.weekly_detail.comparison.label`、`stats.weekly_detail.day.accessibility_label`、`stats.all_time.label` の11キーを削除した。空状態で使用する `stats.empty.description` は保持した。
- Home整合: 本batch開始時の「ぼかしカードが2枚とも無い場合は孤立CTAを出さない」という条件は、後発の承認済み `.claude/specs/home-stats-dedup.md` により、ぼかしカード群とそのCTA自体をHomeから削除する形で吸収された。別役割の1行統計導線は同正本どおり `!isFirstDayEmpty` で維持し、旧 `appMetrics`／`topSatisfaction` 条件やぼかし分析を再導入していない。
- 採用方針・制約: 空状態はデータ不足を率や0値カードとして見せず、期間ピッカーだけを残して説明へ置換する。`DayBars` の意味を説明する凡例は週だけに置き、今日／全期間には再表示しない。空判定は選択期間の試行数で行い、`stats.empty.description` を削除しない。Apple HIG／Apple Designに沿い、既存NavigationStack、期間ピッカー、色・文字トークンを保った。
- 検証・成果物: `audit-default-values.py` はcalls 759、不一致項目すべて0。`lint-display-copy.py` は既存オンボーディング要確認2件のみでexit 0。humanizer-enは6文、humanizer-koは5文で各exit 0・全ゲート通過。両xcstringsの`jq`、`validate_legacy_copy_reuse(en-US, ko)`、`xcodegen generate`、`git diff --check`が成功した。指定iPhone 16 Pro Max（`90F5A09F-D128-468C-AB02-7ABB1479B3AE`）向け署名なしbuildは `BUILD SUCCEEDED`、DopaBreakCoreは513件・失敗0、再撮影XCTestは2件・失敗0。`output/screenshots/redesign-phase1/{home,home-free}.png` と `output/screenshots/redesign-phase2/{stats-pro,stats-free,stats-empty}.png` を日本語・ダーク・各1320×2868で再生成し、5枚を目視確認した。`ios/DopaBreak/BreathingCharacterView.swift` と同テストの別セッション差分には触れていない。

## 2026-08-24 — App Storeスクリーンショット ja #06 見出し重複の解消

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` と承認コピー正本 `scripts/generate-appstore-screenshots.py` のja #06 headline 2行目だけを「開くのをやめた回数も記録」から「開くのをやめた回数も積み上がる」へ変更した。v2の1行目「SNSのあと本音を記録」と旧正本の読点入り1行目「SNSのあと、本音を記録」は、それぞれの現状を維持した。
- 採用方針・却下案: 語彙統一済みの「開くのをやめた」は保持し、koの「열지 않은 횟수도 쌓여요」と揃う蓄積のニュアンスを「積み上がる」で復活させた。1行目の「記録」を言い換える案、ko／en-USを変更する案、2行目へ読点・句点を加える案は、依頼範囲と表示コピー規則に反するため採用していない。
- Claude Code向け制約: ja #06を今後変更する場合も旧正本とv2を同時更新し、両ファイル固有の1行目は維持する。ko／en-USは本変更の対象外。機能画面リデザイン完了後にまとめて再撮影・再生成するため、今回は画像成果物を更新していない。
- 検証: `validate_legacy_copy_reuse(en-US, ko)` は成功。`scripts/lint-display-copy.py` は今回と無関係な既存オンボーディング要確認2件のみでexit 0。対象スクリプトの`git diff --check`も成功した。

## 2026-08-25 — 60fps MCP モーション改修候補の照合（8/24監査の差分検証・未実装）

- 接続経路: Claude Codeに登録済みの60fps MCPは `SIXTYFPS_PRO_KEY` が起動プロセスへ渡らず接続に失敗する。`~/.zshrc:11` の鍵で `https://mcp.60fps.design/mcp` へJSON-RPCを直接投げて照合した。恒久対応はログインシェル経由での起動か、`~/.claude/settings.json` の `env` へ鍵を置くこと。アプリコードは変更していない。
- 照合方法: 2026-08-24の提案3件を、Phase 1・2適用後の現行コード（未コミット）で再検証した。あわせて `60fps_get_motion_code` で各参照の motion_params を取得した。8/24に「具体的な時間値は提供されていない」と記録した数値が今回は取得できたため、既存 `DopaMotion` トークンとの対応まで確定させた。参照のブランド・コピー・アセットは移植しない方針は変わらない。
- 提案1（記録・期間切替）は現存する。`selectPeriod` は `withAnimation(DopaMotion.control)` で `period` だけを包む（`StatsView.swift:231`）。`dashboard` の再代入は `.onChange(of: period)` 経由の `reloadDashboard()`（`StatsView.swift:150`・`StatsView.swift:671`）で走るため、同じトランザクションに入らない。`periodVisualization`（`StatsView.swift:305`）は週・今日・全期間で別のViewを返すが `transition` 指定がない。`DayBars`（`DayBars.swift:47`）も棒高をデータから直接引くだけで補間しない。
- 提案1の参照を差し替える。8/24のHarveeはドット行列で、DopaBreakの棒グラフとは形が違った。今回 `go-club-steps-graph-switch-animation` を取得した。週→月の切替で棒グラフがmorphし、数値がtickerで転がる構造そのものが一致する。値は `spring(response: 0.45, dampingFraction: 0.72)`・stagger 0.04。morphできない部分には `flighty-stats-by-year` の `easeOut(duration: 0.25)` crossfadeが対応する。
- 提案2（止めるアプリ）は現存する。`TargetAppGrid.swift:66` の枠線は色と太さが即時に切り替わり、`selectionIndicator`（`TargetAppGrid.swift:98`）の丸も補間しない。動くのは押下scaleだけである（`TargetAppGrid.swift:138`）。
- 提案2の参照も差し替える。Outlookはアバターをチェックマークへmorphさせる例で、承認済みの「チェックを置かない」制約と噛み合わなかった。`mymind-spaces-color-picker` は選択リングの移動と中央の丸のscale popだけで選択を伝えるため、こちらが合う。値は `spring(response: 0.25, dampingFraction: 0.72)`・staggerなし。枠線側は `cred-interest-selection` の `easeOut(duration: 0.25)` による色の移り変わりが対応し、枠を跳ねさせない根拠になる。
- 提案3（ロック画面確認）は現存する。`phase` は `start()`（`LockScreenCheckView.swift:252`）と `refreshStatus()`（`LockScreenCheckView.swift:260`）で `withAnimation` なしに代入される。手順カードと成功badgeの入れ替え（`LockScreenCheckView.swift:84`）もプレビューの減光も同時に飛ぶ。
- 提案3の参照も差し替える。Google Todoはチェックボックスの例だった。`smallcase-wealth-office-setup-check-animation` はシステムイベントで設定完了を伝える構造で、説明文のfade outとdown、badgeのspring scale up、成功文のfade inとupという順序がこの画面に一致する。値は `spring(response: 0.45, dampingFraction: 0.72)`・stagger 0.09。
- トークン対応（新しい数値を作らない方針の帰結）:
  - 参照の `spring(0.25, 0.72)` は既存 `DopaMotion.momentum`（`.snappy(duration: 0.3, extraBounce: 0.1)` ≒ damping 0.75）でほぼ再現できる。提案2の丸はここに載せる。
  - 参照の `spring(0.45, 0.72)` に対応するトークンはない。`DopaMotion.transition` は `.smooth(duration: 0.4)` で damping 1.0 のため、わずかなオーバーシュートが落ちる。`DesignTokens.swift:48` の「祝福以外で跳ねさせない」規律を優先し、提案1の棒高と提案3のbadgeは `transition` を実装値とする。オーバーシュートを入れるかはオーナー判断であり、勝手にトークンを追加しない。
  - crossfadeの `easeOut(0.25)` は既存コードの `easeInOut(0.2)`（`PostUseReflectionSheet.swift:62`）や `easeInOut(0.24)`（`OnboardingFlow.swift:98`）と同じ帯にあるため、新規数値の追加にはあたらない。
- 8/24監査が記録していなかった実装前提（今回の照合で判明）:
  - ハプティクスの土台がない。アプリにあるのは呼吸用の `BreathHapticsController`（CoreHaptics）だけで、`UISelectionFeedbackGenerator` や `UINotificationFeedbackGenerator` の共通経路は存在しない。提案2の selection haptic と提案3の success haptic は、小さな共通ヘルパーの新設を伴う。
  - Reduce Motionの分岐が対象3画面にない。`accessibilityReduceMotion` を読むのは `InterventionFlowView`・`CharacterView`・`OnboardingMotion`・`OnboardingFlow` だけである。`StatsView`・`TargetAppGrid`・`LockScreenCheckView` は環境値の追加から必要になる。
- 8/24以降に増えた画面の確認結果: 新規の設定5ファイル（`SettingsAboutView`・`SettingsAccountView`・`SettingsComponents`・`SettingsLockSurfaceView`・`SettingsNotificationsView`）、`RootTabView` のタブ切替、ホームの統計導線には新しい改修候補は出なかった。設定の画面遷移はNavigationStackの標準挙動が担い、押下feedbackは共通ボタンスタイル（`DesignTokens.swift:262`・`DesignTokens.swift:287`）が持つ。ホームの回数は既に `DopaMotion.control` で補間している（`HomeView.swift:209`）。
- 実装可否は未判断のまま据え置く。着手する場合の順序は、ハプティクス共通ヘルパーとReduce Motion分岐を先に用意し、そのあとで提案2、提案3、提案1の順に入れる。提案1はStatsのカード形状・実データ・Freeぼかしを保つ必要があり、影響範囲が最も広い。

## 2026-08-25 — 機能画面リデザイン Phase 3（設定）の完成と検証

- 引き継ぎ経緯: 別セッション（test-project-a8）が実装途中で消滅し、未コミットのまま作業ツリーに残っていた分を検証・補完した。コミットはしていない。
- 移動対応（元 `SettingsView.swift` → 先）: `lockSurfaceSection` のトグル4つ＋通知時刻＋`usageWatchSection` → `SettingsNotificationsView`／`lockSurfaceSection` のテーマチップ・ロック画面確認・Live Activityトグル → `SettingsLockSurfaceView`／`accountSection` → `SettingsAccountView`／`privacySection`＋`appSection` → `SettingsAboutView`／`settingsRow`・`divider`・`toggleRow`・`timePickerRow`・`dateForTime`・`minutes`・`normalizedMinutes` → `SettingsComponents.swift`（`SettingsRow`・`SettingsDivider`・`SettingsIconTile`・`SettingsIconNavigationRow`・`SettingsIconToggleRow`・`SettingsIconTimePickerRow`・`SettingsTime`）。`targetSection`＋`deepFocusSection` は `statusSection`・`modeSection`・`targetLengthAutomationSection`・`wakeSleepTimelineSection`・`entrySection`・`aboutEntrySection` へ再構成した。`modePickerRow`／`modeBinding`／`appSelectionSummary`／`targetAppsSummary`／`freeCatalogTargetRows`／`proGateTargetRows`／`deepFocusTargetsRow` はブリーフどおり廃止し、選択操作は `handleAppSelectionTap()`／`isTargetPickerPresented` の既存経路のまま残した。`ruleEnabledBinding`／`setRuleEnabled` は再構成前から未使用だったため削除した。
- 引き継ぎ時に欠けていた点と是正3件:
  1. `screenTimeRow`（スクリーンタイムの許可状態と再要求の入口）が丸ごと落ちていた。`snapshotScreenTimeAuthorized` のDEBUG撮影initも読み手を失い、App Storeパネル08・09の「許可済み」表示が成立しなくなっていた。`targetLengthAutomationSection` の末尾へ復帰させ、表示条件は再構成前と同じ `isDeepFocusUnlocked` を維持した。`screenTimeAuthorizedForDisplay` も復元し、本番経路は実状態のままにしてある。
  2. `modeCard` の名前が `lineLimit(1)` で、3列だと「ディープフォーカス」が「ディープフォー…」と切れていた。どの強さを選んでいるか読めなくなるため名前だけ2行折り返しにした。説明はブリーフどおり11pt2行のまま。
  3. `statusIconSources` と `targetRowIconSources` が別々の優先順位（前者はカタログ優先、後者は `isGateUnlocked` で分岐）で組まれており、同一画面で片方だけ「未設定」になる食い違いが出ていた。`targetIconSources` に一本化した。
- 文言: コピーシート `functional-screens-redesign-copy-sheet.md` の Settings 42行を ja/en/ko で機械照合し、`settings.gate.*` 4キーを除く38行が一致していることを確認した。`settings.gate.*` はブリーフ追記の「gate系は docs/11_ui_copy.md §6c を正とし変更しない」に従い、コピーシート案を適用していない。Phase 3 新規10キーは3言語とも投入済みで、`defaultValue` はカタログのja値と一致する。
- 撮影: `CoreScreensSnapshotCapture.swift` に `testCaptureRedesignPhase3SettingsScreens` と `SettingsNotificationsSnapshotHost` を追加した。既存Phase 1・2と同じ実ウィンドウ＋`drawHierarchy`・ダーク・ja・1320×2868。撮影シードは Phase 1・2 と同一の `seedRedesignAttemptLogs`（今日15回中12回・週36回）で凍結値を変えていない。`output/screenshots/redesign-phase3/{settings-top,settings-top-free,settings-notifications}.png` を生成した。
- 撮影ハーネスの制約（既知・Phase 1と共通）: `automaticallyRefreshEntitlement: false` のため `hasConfirmedEntitlement` が false のままで、`isGateUnlocked` はフェイルオープン側に倒れる。`settings-top-free.png` は強さのProバッジと完全ブロックのロック行は正しく写るが、gate関連の説明文は権利未確定時の見え方になる。確定Freeの見え方は実機で確認する。
- 検証: DopaBreakCore 513件・失敗0。アプリ 187件・8スキップ・失敗0。`build-for-testing` は BUILD SUCCEEDED。`scripts/lint-display-copy.py` は既存オンボーディング要確認2件のみで exit 0。`scripts/audit-default-values.py` は calls 771・mismatches 0・missing 0 で exit 0。

## 2026-08-25 — モーション改修 Step A・B の実装

- 作成・変更: `ios/DopaBreak/DesignTokens.swift` に `DopaMotion.select` / `morph` を追加し、`ios/DopaBreak/HapticFeedback.swift` にUIKitのselection / success共通経路を新設した。`ios/DopaBreak/TargetAppGrid.swift` は選択・解除時のselection haptic、ライム丸のscale popとfill補間、カード枠の非バウンド補間、Reduce Motion分岐を追加した。`ios/DopaBreakTests/HapticFeedbackTests.swift` で両ジェネレータをテストターゲットから実行した。
- 採用方針・却下案: 選択丸は既存のチェックなしライム塗りを維持し、`phaseAnimator` で1.0→1.08→1.0の単発popだけを `DopaMotion.select` に載せた。枠線を同じspringで跳ねさせる案、カード再配置、stagger、押下scale値の変更は仕様と高頻度操作への節度に反するため採用していない。Step C / D は未実装で、Stats・DayBars・LockScreenCheckのコードには触れていない。
- Claude Code向け制約: `DopaMotion.control` / `transition` / `momentum` / `celebrate` の値と用途を維持し、`select` / `morph` を祝福用途へ流用しない。TargetAppGridの通常時押下scale 0.985、カード構成、複数項目の配置、ライム丸を維持する。Reduce Motionでは選択popと押下scaleを止め、色・opacity・ハプティクスを残す。
- 検証: `xcodegen generate` と署名なしgeneric iOS Simulator向け `xcodebuild build` は成功。DopaBreakCoreは513件・失敗0、DopaBreakTestsは189件・9スキップ・失敗0で `TEST SUCCEEDED`。`git diff --check`も成功した。

## 2026-08-25 — モーション改修 Step A・B レビュー指摘の是正

- 変更: `ios/DopaBreak/TargetAppGrid.swift` からタップ時点のselection hapticを外し、`ios/DopaBreak/TargetAppPickerSheet.swift` と `ios/DopaBreak/OnboardingFlow.swift` の選択集合が実際に増減する経路へ `HapticFeedback.selection()` を移した。上限ゲートで拒否されてpaywallへ遷移する経路は無触覚のままで、ゲート判定・paywall placement・永続化は変更していない。
- モーション方針: `ios/DopaBreak/TargetAppGrid.swift` の明示的な `.animation` は選択丸のfill / strokeより内側、`phaseAnimator` より前へ移し、色補間だけを担当させた。scaleは引き続き`phaseAnimator`だけが1.0→1.08→1.0を所有し、Reduce Motion時はscaleを1.0へ固定する。
- Claude Code向け制約: ハプティクスは試行ではなく選択集合のcommit時だけ発火する。Onboardingの当該toggleでは既存`markSelectionFeedback()`との二重発火を避け、UIKit共通ヘルパーへ置換した。ライム丸、枠線、押下scale、ゲート、paywall、永続化の既存構造を維持する。
- 検証: 署名なしgeneric iOS Simulator向け `xcodebuild build` は成功。DopaBreakCoreは513件・失敗0、DopaBreakTestsは189件・9スキップ・失敗0で `TEST SUCCEEDED`。`git diff --check`も成功した。コミットはしていない。

## 2026-08-25 — モーション改修 Step C（記録の期間切替）

- 作成・変更: `ios/DopaBreak/StatsView.swift` に `updatePeriod(_:)` を新設し、期間の切替と `reloadDashboard` を1つの `withAnimation(DopaMotion.morph)` トランザクションへ束ねた。二重反映を避けるため `.onChange(of: period)` は削除した。`reloadDashboard` と `fallbackDashboard` は期間を引数で受け取れるようにした。同一トランザクション内では `period` の状態がまだ更新されていない可能性があるため、状態を読まず引数で渡す。`ios/DopaBreak/DayBars.swift` は棒高を `barHeight` へ束ね、`.animation(reduceMotion ? nil : DopaMotion.morph, value: barHeight)` で補間する。
- 採用方針・却下案: 形の違うView同士（週の棒グラフ・今日の2値・全期間の1値）は無理にmorphさせず、`.id(period)` と `.transition(.opacity)` に `easeOut(0.25)` を当てて crossfade とした。棒の高さだけが同じ面の変形にあたるため `morph` を使う。数値は既存の `.contentTransition(.numericText())`（`StatsView.swift:296`）をそのまま使い、新しい指定を足していない。
- Claude Code向け制約: `isStatsHistoryLocked` の分岐と `paywallPlacement` の判定は不変。`.task`・シーン復帰・`weekAttemptCount` 変化からの `reloadDashboard()` は従来どおり引数なしで現在の期間を読む。空状態（`stats.empty.*`）、週だけに出す凡例、カード形状、実データ、Freeのぼかしを維持する。Reduce Motion時は棒高補間とmorphを止め、crossfadeだけ残す。
- 検証: `xcodegen generate` と署名なしgeneric iOS Simulator向け `xcodebuild build` は Fable 側でも再実行して BUILD SUCCEEDED。Codex 実行時点で DopaBreakCore 513件・失敗0、`lint-display-copy.py` と `audit-default-values.py` はいずれも exit 0。DopaBreakTests の件数は同じ作業ツリーで並行するPhase 4が撮影ハーネスを編集中のため変動する。
- 残: Step D（ロック画面確認）は `LockScreenCheckView.swift` をPhase 4が編集中のため未着手。

## 2026-08-25 — ペイウォール年額割引バッジの根拠連動

- 作成・変更: `ios/DopaBreak/PaywallView.swift` の年額割引率を `Int?` にし、両商品の価格が揃い、月額価格が正で、四捨五入後の割引率が正の場合だけ割引率を返す `AnnualDiscountPolicy` へ算出を切り出した。商品欠損時の58%フォールバックは削除し、割引率がない場合は同じCapsuleスタイルの「一番人気」だけを表示する。`ios/DopaBreak/Localizable.xcstrings` に `paywall.plan.annual.popular_badge` を既存コピー先頭セグメントのja/en/koで追加し、`ios/DopaBreakTests/AnnualDiscountPolicyTests.swift` に正常・年額欠損・月額欠損・月額0・割引0以下の回帰5件を追加した。
- 採用方針・却下案: バッジを消す案、価格未取得時も固定58%を出す案、新しい人気訴求コピーを作る案は採用していない。人気表示は価格根拠を必要としない既存先頭セグメントに限定し、割引率の計算式・四捨五入、既存 `paywall.plan.annual.savings_badge` の値と `%lld%%`、フォント・accent背景・Capsule・paddingを維持した。
- Claude Code向け制約: `AnnualDiscountPolicy.percent` はアプリターゲット内の純関数で、`annualPrice`／`monthlyPrice` のどちらかがnil、`monthlyPrice <= 0`、または算出整数率が0以下ならnilを返す。価格未取得時に割引率フォールバックを再導入しない。CTA、法定表示、trial reminder、plan detail／price、StoreService、購入・復元、annual＋monthly構成、StoreKitの通貨書式には触れない。
- 検証: `xcodegen generate`成功。DopaBreakスキームのgeneric iOS Simulatorビルドはアプリ・4拡張・Core依存を含め `BUILD SUCCEEDED`。iOS 26.5 iPhone 16のDopaBreakTestsは194件・手動撮影9件skip・失敗0、DopaBreakCoreは513件・失敗0。`xcstringstool`を含むビルド、`jq`、`audit-default-values.py`（mismatch／missing／specifier-type／unknown-targetすべて0）、`lint-display-copy.py`、対象差分の`git diff --check`も成功した。

## 2026-08-25 ロック画面確認: サイドボタン位置マーカー＋英語eyebrow削除（Claude Code a4・設計正本 `.claude/specs/lock-check-side-button-marker.md`）
- 決定: 「サイドボタンを1回押して画面を消す」の案内を、抽象的な端末図（60×96pt）から**画面右端・実際の物理サイドボタンと同じ高さの縦バー＋矢印＋文言**へ置き換える（参考: Lock Screen Notes の案内画面。オーナー指示）。位置は Apple 公式寸法図（Accessory dimensional drawings）から機種ごとに読み取った「ボタン上端÷画面アクティブ高さ」「長さ÷画面高さ」の割合を静的テーブルで持ち、実行時の論理高さに掛けて出す。34機種（XS〜17系・Air・SE2/3）を収録、未知機種は同一論理サイズの最新機種→中央値でフォールバック
- 決定: `LOCK SCREEN` eyebrow を削除（装飾用英語eyebrow禁止・2026-08-24オーナー指示の適用漏れ）。手順1カード＋端末図を廃止し、手順2カードとプレビューは維持
- 決定: 「下のカメラボタンではなく上のボタン」注記は Camera Control のある iPhone 16 / 16 Plus / 16 Pro / 16 Pro Max / 17 / 17 Pro / 17 Pro Max / Air だけに出す（16e・17e・15以前には出さない）
- 却下: 端末図の縮尺を変えて正確に描く案（画面上の位置と物理位置が一致しないので目印にならない）／マーカーをスクロール内容の中に置く案（スクロールで物理位置からずれる）
- Codex向け制約: `DeviceSideButtonGeometry` の数値は設計書 §3 の表以外を書かない。`LockScreenGoalPreview`（GoalsView と共有）と `phase` 状態機械は変更しない。`.onboardingStagger` の順序は維持（eyebrow削除で index を0から詰める。モーション改修 Step D がこの順序に依存）

## 2026-08-25 — 機能画面リデザイン後のApp Storeスクリーンショット再撮影・再生成

- コピー: `scripts/generate-appstore-screenshots-v2.py` と承認正本 `scripts/generate-appstore-screenshots.py` の04を同時更新した。jaは「取り戻した時間／開くのをやめた分が／時間になって戻る／今週の合計と1年ぶんの目安をホームに表示」、en-USは「TIME YOU GOT BACK／Every open you skip／turns back into time／Your weekly total and yearly pace sit on the home screen」、koは「되찾은 시간／열지 않기로 한 만큼／시간이 돌아와요／이번 주 합계와 1년 예상치를 홈에서 확인해요」。`validate_legacy_copy_reuse` は3ロケールで成功した。
- 撮影: `ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` に `testCaptureRedesignedStoreScreens` を追加し、既存の `breath.png`／`intent.png` を上書きせず `home.png`／`stats.png`／`goals.png`／`reflection.png` だけを撮る限定経路にした。既存 `testCaptureAdditionalSettingsScreens` と合わせ、Simulator `90F5A09F-D128-468C-AB02-7ABB1479B3AE`、iOS 18.3.1、ダーク、status bar 9:41、ja/JP・en/US・ko/KRで `output/app-store-screenshots/raw-core/{ja,en-US,ko}/{stats,home,reflection,goals,deepfocus,nightmode,grayscale}.png` を更新した。各ロケール2テスト・失敗0で、一時 `DOPABREAK_CAPTURE_APPSTORE_SCREENSHOTS` は撮影後に解除した。
- 再生成: `output/app-store-screenshots/v2/{ja,en-US,ko}/iphone-69/` の01・04・06・07・08・09・10、`contact-sheet-{ja,en-US,ko}.png`、`slots-{ja,en-US,ko}.json`、ja互換 `slots.json`、`upload-order/{ja,en-US,ko}/iphone-69/` を更新した。02・03・05は撮影元を更新せず、作業前SHA-256との一致を3ロケールすべてで確認した。アップロードの生成番号順は全ロケール `01,02,09,08,04,03,05,06,07,10`、各localeの既存READMEはバイト不変で維持した。
- デザイン方針: 新ホームの主役である「取り戻した時間」を04の訴求と実画面の両方で一致させ、Phase 1〜4の刷新後UIを画面ソースにする。02／03／05まで一律に差し替える案は撮影元が変わっておらず不要な差分になるため却下した。撮影シード（2.3時間/日、週6時間0分、連続7日、週36回、今日15試行12停止、ローカライズ済み目標3件）は変更していない。
- Claude Code向け制約: raw-core更新では今回追加した限定テストを使い、breath／intentを巻き込まない。04コピーは旧正本とv2を常に同時更新する。最終30枚は1320×2868 RGB、各slotsのキャラ合計1以下、アップロード順は上記生成番号列を維持する。08／09は許可済み表示を保ち、10のモックラベルは `automation_guide.grayscale.mock.apps` のja/en/koを使う。
- 検証: 最終30枚はPNG／RGB／1320×2868、contact sheet 3枚はPNG／RGB／4000×869、slots各10件・キャラ最大1。Vision OCRで04の指定コピー3言語、07の目標3件、08／09の「未許可／Not authorized／미허용」不在、10 en-US「Select all target apps」・ko「대상 앱 모두 선택」を確認した。日本語OCRに `%lld回、` 型の読点表示なし。`python3 scripts/lint-display-copy.py` は既存の要確認2件のみでexit 0。upload-order 30枚は生成元とSHA-256一致、README 3本は作業前後SHA-256一致。

## 2026-08-25 ロック画面確認のサイドボタンマーカー実装
- 作成・変更: `ios/DopaBreak/DeviceSideButtonGeometry.swift` に設計正本 §3 の識別子テーブル、論理サイズ別の最新機種フォールバック、中央値フォールバックを実装した。`ios/DopaBreak/LockScreenCheckView.swift` は待機中だけ画面右端マーカーを出し、PreferenceKey でタイトル下端とマーカー文言下端を測って本文の空きを作る構成へ変更した。`ios/DopaBreak/OnboardingFlow.swift` と `LockScreenCheckSheet` の両方から同じ overlay を利用する。
- 採用方針: バーはスクロールと無関係な画面座標に固定し、文言だけをヘッダー下端にクランプする。従来の抽象端末図と手順1カードは削除し、手順2カード、プレビュー、許可注記をマーカー下へ逃がした。マーカーをスクロール内容へ入れる案は物理位置とずれるため不採用。
- ローカライズ・テスト: `ios/DopaBreak/Localizable.xcstrings` の eyebrow / step1 キーを削除し、side-button 2キーをja/en/koで追加。`lock_check.preview.cancelled` のja読点を半角スペースへ変更した。`ios/DopaBreakTests/DeviceSideButtonGeometryTests.swift` に代表3機種と2種のフォールバックを追加し、`LockScreenCheckSnapshotCapture.swift` は393×852のZStackに iPhone 15 相当マーカーを直接合成する。
- Claude Code向け制約: `DeviceSideButtonGeometry` の割合は必ず設計書 §3 を正本とし、サイズフォールバックで Camera Control を true と推定しない。`LockScreenGoalPreview`、phase状態機械、`start()` / `refreshStatus()` / `LockScreenCheckAction`、blocked / noGoal 分岐を変更しない。iOS 17対応のため `GeometryReader` + `PreferenceKey` を維持し、`onGeometryChange` へ置き換えない。
- 検証: iPhone 16 Pro Simulator向けbuildは `BUILD SUCCEEDED`。幾何テスト5件＋スナップショットハーネス1件は失敗0で `TEST SUCCEEDED`。`audit-default-values.py` は mismatches / missing / unresolved / specifier-type / unknown-target がすべて0、`lint-display-copy.py` は既存の要確認2件のみでどちらもexit 0。

## 2026-08-25 — App Storeパネル04の対象アプリ選択済みシード

- 作成・変更: `ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` に home 専用の `testCaptureHomeScreen` を追加した。Phase 1 と同じ `instagram` / `youtube` / `tiktok` のカタログIDを `setTargetCatalogIDs` へ投入し、同じ3件を `verifiedAutomationCatalogIDs`、DEBUG用のキャッシュPro状態を注入する。専用分岐は `output/app-store-screenshots/raw-core/{ja,en-US,ko}/home.png` だけを保存して直ちに戻るため、stats / reflection / goals / deepfocus / nightmode / grayscale のraw撮影を実行しない。
- 再撮影・再生成: iPhone 16 Pro Max Simulator `90F5A09F-D128-468C-AB02-7ABB1479B3AE`、iOS 18.3.1、status bar 9:41、ja/JP・en/US・ko/KRでhome専用XCTestを各1件実行した。3言語の `04-modes.png`、`contact-sheet-{ja,en-US,ko}.png` を再生成し、生成04をupload-order 05（ja/ko=`05-modes.png`、en-USは既存ファイル名=`05-deep-focus.png`）へ同期した。`slots-{ja,en-US,ko}.json` とja互換 `slots.json` は再生成したが、画面ソースと幾何が不変なのでSHA-256も不変だった。
- 採用方針・却下案: アプリ本体の表示ロジックやFamilyControlsの新規注入APIは作らず、既存Phase 1のカタログID・検証済みID・キャッシュ権利シードだけをhome専用経路で流用した。全画面再撮影、通常シードの恒久変更、画像へのアイコン合成は、他パネルへの波及または実画面でない状態になるため採用していない。全パネル再合成で未コミット中のロック画面変更が05へ混入したため、既存upload-order 07に保持されていたバイト一致の旧05へ戻し、contact sheetだけを新04＋旧05で作り直した。
- Claude Code向け制約: パネル04だけを直す場合は `testCaptureHomeScreen` を使い、3カタログIDの順序、8秒、既存ログ／目標シードを変えない。04の生成元は引き続き `raw-core/{locale}/home.png`、キャラは画面内1体・外乗せ0体、upload-orderは生成04→アップロード05を維持する。home以外のrawや生成01/06/07/08/09/10を同時更新しない。
- 検証: home専用XCTestは3言語とも1件・失敗0。rawのアイコン領域を画素判定し、Instagramのマゼンタ系、YouTubeの赤、TikTokのシアンと、独立したライム点3成分を全言語で検出した。Vision OCRは8秒コピー3言語を認識し、空状態コピー `止めるアプリを選ぶ` / `Choose apps to pause` / `멈출 앱 고르기` は0件。最終04は全言語1320×2868 RGB、slots上のキャラ合計1。生成04とupload-order 05のSHA-256はja=`6b1b01566b028b753cac0386d8c05a0f52b07064afec71bda5d537f70ce98282`、en-US=`2aa194c5135c00bbd94c5898e1eed4439a13e5af8fb5ad4ecdf764795ab50609`、ko=`397889450bb0f78f17f06bb4d13e26aa4f68bb755f54eb29c9ef1a36c847c005`で各ペア一致。生成01/06/07/08/09/10は3言語18枚すべて作業前SHA-256と一致した。

## 2026-08-25 — App Storeパネル01のPro記録画面

- 作成・変更: `ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` にstats専用の `testCaptureStatsScreen` を追加した。Phase 2と同じ `entitlementCachedIsPro = true`、3カタログID、`seedRedesignAttemptLogs`、前週ログ、回答済み振り返りを流用し、`output/app-store-screenshots/raw-core/{ja,en-US,ko}/stats.png` だけを保存してreturnする。`scripts/generate-appstore-screenshots-v2.py` は01の端末幅を1060pxから860pxへ変更し、期間チップ、アプリ別、見たあとの気持ち、開こうとした理由の3カードを1320×2868内へ収めた。
- 再生成・同期: 3言語の `output/app-store-screenshots/v2/{locale}/iphone-69/01-hook.png` と `contact-sheet-{ja,en-US,ko}.png` を更新し、各 `upload-order/{locale}/iphone-69/01-hook.png` へ生成01を同期した。全パネル再合成時に並行中のロック画面変更が05へ混入したため、upload-order 07に保持されていた作業前バイトを生成05へ戻し、新01と保持済み02〜10からcontact sheetを再構成した。
- 採用方針・却下案・制約: 新しい権利注入APIや画像上のロック除去は作らず、Phase 2のDEBUG用キャッシュ権利と既存シード関数だけを採用した。Freeのまま撮る案、全raw再撮影、カード3枚目を切ったままにする案は却下した。Claude Code側は01更新に `testCaptureStatsScreen` を使い、3カタログIDの順序、2.3時間/日、週6時間0分、連続7日、週36回、今日15試行12停止、目標3件の既存シードを変更しない。01の端末幅860pxと上端1050pxを維持し、理由カードまで表示する。
- 検証: stats専用XCTestはja/en-US/ko各1件・失敗0。Vision OCRで3言語の最終01から期間、3アプリ、気持ちカード、理由カードと理由チップを認識し、課金CTA相当と `Pro` は0件。raw OCRと原寸目視で気持ち件数を確認した。最終01は全言語1320×2868 RGB、slots上のキャラ合計1。生成01とupload-order 01は各言語でSHA-256一致し、生成02〜10の27枚は作業前SHA-256と一致した。撮影opt-in環境変数は完了後に解除した。

## 2026-08-25 — App Storeモック最大化・パネル07削除

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` の生成IDを `01,02,03,04,05,06,08,09,10` の9枚へ変更し、3ロケールの07コピー・source・panel分岐を削除した。直立フォンは外形1396px（スクリーン1320px）、±7°は1111px、±8°は1081pxへ最大化し、05以外の回転後外形上端をy=820、中心xを660へ統一した。`scripts/generate-appstore-screenshots.py` も3ロケールの07コピーと旧7枚目生成を削除した。`output/app-store-screenshots/v2/` の3ロケール各9枚、9枚横並びcontact sheet、slots、upload-order、各READMEを再生成・更新した。設計正本は `.claude/specs/appstore-screenshots-v2-diagonal.md`。
- 採用方針: フォン筐体のクリップを許し、スクリーン左右端だけを制約にした。整数丸め込み後のスクリーン寸法で回転四隅を計算し、±7°はx=0.54〜1319.46、±8°はx=0.13〜1319.87、直立はx=0〜1320を上限とした。背景図形、コピー座標・フォント・色、回転角、マスコット寸法と既存の重なり関係は維持した。全マスコットが既存座標のままalpha bbox内へ収まるため移動は不要だった。フォン中心を左右へ寄せたまま幅だけ増やす案は03/06でスクリーンがはみ出すため却下し、07の連番を詰める案は後続のコピー差し替え・並び替えを妨げるため却下した。
- Claude Code向け制約: 05はLive Activityコールアウトの承認済み画像を再利用し、ジェネレーターは既存05を上書きしない。未コミット中のロック画面文言を再合成へ混入させないこと。生成IDは欠番07を維持する。upload-orderは生成元ID `01,02,09,08,04,03,05,06,10` の順で9枚。各localeのslotsは9件、contact sheetは3600×869 RGB。フォン幅を変更する場合は外形ではなく回転後スクリーン4隅のxを0〜1320で再検証する。
- 検証: v2 generatorは3ロケール完走し、`validate_legacy_copy_reuse` もen-US/koで通過。最終27枚は1320×2868 RGB、キャラ合計最大1、外乗せalpha bboxは全件キャンバス内。05は作業前SHA-256と3ロケール一致。upload-orderは各9枚が生成元とSHA-256一致。`lint-display-copy.py` は既存の要確認2件のみでexit 0、構文確認と`git diff --check`もexit 0。

## 2026-08-25 — ロック画面テーマ既定名の表示修正
- 変更: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Models/AppModels.swift` の `LockTheme.e1.displayName` を「E1」から「黒とライム」へ変更し、`docs/11_ui_copy.md` のテーマ名一覧も同期した。
- 方針: 黒地＋ライムの見た目をそのまま表す平易な日本語名を採用した。列挙子 `.e1` と保存用 `rawValue` は変更していない。
- 却下・制約: `ios/DopaBreak/Localizable.xcstrings` と `ios/DopaBreak/LockScreenCheckView.swift` は並行作業中のため触れていない。`LOCK_THEME_E1` など内部識別子、enum参照のみのテスト名、旧値を記録する設計仕様は変更しない。

## 2026-08-25 — ロック画面テーマ名のアプリ層ローカライズ
- 作成・変更: `ios/DopaBreak/LockScreenThemeDisplay.swift` に Core の `LockTheme` へ `localizedDisplayName` を追加し、`ios/DopaBreak/Localizable.xcstrings` に7テーマの `lock_surface.theme.*` キーをja/en/koで追加した。`ios/DopaBreak/SettingsLockSurfaceView.swift` と `ios/DopaBreak/SettingsView.swift` の設定画面表示だけを新プロパティへ切り替えた。
- 採用方針・却下案: Core の `displayName` は日本語フォールバックとして維持し、保存・共有モデルや既存のロック画面確認／オンボーディング表示は変更しない。依頼文の概念名 `LockScreenTheme` ではなく、リポジトリの実体である `LockTheme` を拡張した。テーマ名の英語・韓国語は設定画面の短いラベルとして指定値を採用し、句読点やレイアウト変更は加えていない。
- Claude Code向け制約: `LockScreenCheckView.swift`、`OnboardingFlow.swift`、Core、テストは触れない。7キーは既存String Catalogエントリの末尾に追加したため、既存エントリの並び・書式を変更しない。新規SwiftファイルはDopaBreakアプリターゲットに含める。

## 2026-08-25 — en-US白黒ガイドrawのスクロール位置修正

- 作成・変更: `ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` に `testCaptureGrayscaleScreen()` と `grayscaleOnly` 分岐を追加し、`output/app-store-screenshots/raw-core/en-US/grayscale.png` だけを再撮影した。en-USのみ `verticalScrollTarget` を `.bottomInset(270)` にし、解決後の `UIScrollView.contentOffset.y` は `3270pt`（`maximumY=3540pt`）。ja/koは従来の `.bottomInset(24)` を維持した。
- 採用方針・却下案: en-USの長いstep1で下端固定だとバッジと指示文が画面外へ出るため、LazyVStackのbottom反復位置合わせを維持するbottomInset差分を採用した。直接 `.offset(3380)` は初回の仮想化レイアウトが未確定で中間ステップへ止まったため却下した。パネル画像、contact sheet、slots、upload-order、生成スクリプトは変更していない。
- Claude Code向け制約: raw専用テストは `testCaptureGrayscaleScreen` を使い、`grayscaleOnly=true` でdeepfocus/nightmodeを保存しない。en-USの最終contentOffsetは3270pt、ja/koは24ptのまま。status bar 9:41、dark、指定UDID、1320×2868、localeは `-testLanguage en -testRegion US` を維持する。
- 検証: Vision OCRで `1`（badge crop）、`Create a new automation...`、`Is Opened`、`Make your screen grayscale (optional)` を認識。en-US rawはPNG/1320×2868/RGB。ja/ko grayscale SHA-256は変更前と一致（ja=`6b4bfab35a1e9d08bb4c1fd46787b2dc2b7172b2d8baf7a2a7e84ae98ec66312`、ko=`5060a5516676dca52fe42aff1411f996b884c5b09a1b27d05141f1003a7483d3`）。コミットしていない。
