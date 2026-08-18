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
