# Design decisions

## 2026-09-03 — 朝の目標通知を廃止（オーナー決定）

- オーナー発言「たまに目標の通知が来るんだけど目標は通知せずLiveActivityがあるから不要」。目標のロック画面表示は**デイリーLive Activityだけ**にする。同じ内容を通知でも出すのは重複で、通知の総量を増やすだけと判断した
- 設定の「朝の目標通知」トグルは撤去。時刻設定は残すが、意味は**毎週の記録通知の時刻**に限定する。ラベルも「通知時刻」から「記録通知の時刻」へ変え、通知全体の時刻と誤読されないようにした
- 週次の記録通知は設定時刻の30分後ではなく**設定時刻ちょうど**に月曜へ届く。朝の通知が消えた以上、表示している時刻と実際の発火がずれるのは嘘になるため
- 既存端末には毎日繰り返しの予約が残るので、識別子を legacy 掃除リストへ移して起動時に消す。ここを外すと廃止後も鳴り続ける
- UserDefaultsのキー名 `morningNotificationMinutes` は据え置き（Swift側の名前だけ `weeklyReportNotificationMinutes` へ）。キーを変えると設定済みの時刻がリセットされるため
- オンボーディングの通知許可画面は残す。週次の記録・振り返り・継続導線の通知で許可は引き続き要る。リードにその理由を書き、通知の話が1つも出ないまま許可を求める画面にしない
- 未設定時の週次の時刻は**7:00固定**にする。起床時刻に追従させると、夜だけ強化で起床05:30にしたProユーザーへ月曜05:30に届く（本人はその紐づきを知らない）
- 廃止通知の掃除は `purgeRetiredNotifications()` として独立させ、`AppModel.refresh` の **defer から無条件で**呼ぶ。do-catch の中に置くと記録の読み取りに失敗した端末で一生走らず、旧予約が鳴り続ける

## 2026-09-02 — 記録画面の通貨を「取り戻した時間」に統一（オーナー決定）

- 記録画面のヒーローを3期間（今日／今週／全期間）とも **取り戻した時間** にする。「開かなかった割合」は支える数字へ降格。理由は8/25にホームのヒーローを時間へ変えたときと同じで、積み上がる数字のほうが使い続ける理由になるから。割合は悪い日に下がる
- 内訳（アプリごと・開こうとした理由）も時間で表示する
- **名前は「取り戻した時間」に統一**する。オーナー発言の「無駄にしなかった時間」は新しい言い方を作らず既存名へ寄せた。ホーム＝「SNSを開かずに取り戻した時間」、一呼吸の完了画面＝「取り戻した時間」
- **1回あたりの推定はアプリ別にしない**。`ReclaimedTimeEstimator` は全体中央値のままにする。アプリ別にしても開いた履歴が少ないアプリは全体中央値へ戻るため、効くのは主力1〜2アプリだけと判断した
- **時間帯カードを新設**する（何時に開こうとしているか）。`started_at` から出す推定を挟まない事実で、夜だけ強化（Pro）への導線にもなる。今日タブには出さない（1日分では24本のバーが壊れて見える）
- 台帳の確定値は引き続き再計算しない（累計が縮むと信頼を壊す・8/25決定を維持）
- 設計書: `.claude/specs/stats-reclaimed-time-2026-09-02.md`

## 2026-09-02 — 全体監査（設計穴＋CVR構造）の結果とオーナー決定3件

- 監査正本: `.claude/specs/product-design-cvr-audit-2026-09-02.md`（Opus5×3＋Codex独立・Fable裏取り）。生レポート: `output/audits/2026-09-02-product-audit/`。🔴10件のうち 1・2・3 は release-monetization-check A に抵触（Pro購入しても夜だけ強化/ディープフォーカスが何も起きない／標準モードのまま完全ブロック対象を選べる／ホームが未認可でも「開けません」表示）。
- オーナー決定①: **ショートカット自動化は必須のまま**（自動化なしの価値経路は作らない）。従ってオンボの自動化手順のガイド同一化と「戻ってきたら同じ画面へ」が最優先。
- オーナー決定②: **振り返り（リフレクション）は案A**＝宣言した利用時間の終了時刻に通知を1回、タップで `PostUseReflectionSheet` を開く。設定に個別オフ。文面は事実と問いのみ。8/28に廃止した「利用時間の通知」とは別物（利用の推測でなく本人の宣言時刻に基づく）。設計: `.claude/specs/reflection-declared-end-notification-2026-09-02.md`。
- オーナー決定③: **計測を入れる**（SDK選定は別途。ローカル FunnelEventStore に振り返り関連イベントを先に足しておく）。
- 却下: 案B（次にDopaBreakを開いた時に聞く＝9/1に嫌った「覚えていない」問題が戻る）・案C（振り返り機能の撤去）。

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
- Claude Code向け制約: ~~CTA `paywall.action.start_free`（「7日間無料で始める」）をゼロ価格化しない~~ → **2026-08-28にオーナーが例外を承認しCTAもゼロ価格化**（下記エントリ参照）。`paywall.legal.annual_intro`（自動更新の法定表示）・`paywall.plan.annual.intro_fallback`（商品未取得時の異常系のため通貨不明）・`paywall.trial_reminder.*`（散文）・`store.intro_offer.duration.*` も不変。`store.intro_offer.free` はフォールバックで現役のため削除しない。位置指定子を1つでも落とすと3言語のいずれかで表示が壊れる。
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

## 2026-08-25 — モーション改修 Step D ロック画面確認

- 作成・変更: `ios/DopaBreak/LockScreenCheckView.swift` のphase反映を `DopaMotion.morph` の同一トランザクションへまとめ、手順カードのcollapse＋fade、プレビュー減光解除、確認バッジの `DopaMotion.select` scale popを接続した。`SideButtonEdgeMarker` 自身の独立した登場アニメーションは外し、単独シートと `ios/DopaBreak/OnboardingFlow.swift` の両overlayへ同じopacity transitionを付けた。
- ハプティクス・Reduce Motion: phase反映前後を比較し、非confirmedから`.confirmed`へ入る瞬間だけ `HapticFeedback.success()` を発火する。確認済みのまま復帰して`refreshStatus()`が再実行されても再発火しない。Reduce Motion時はphaseのmorph、collapse、badge scale、marker transitionを即時化し、ハプティクスは維持する。
- Claude Code向け制約: `Self.phase(for:didReturnFromLockScreen:current:)`、`start()`／`refreshStatus()`の非同期再判定、blocked／noGoal分岐、現行`onboardingStagger` index、`phase == .waiting`条件、`DeviceSideButtonGeometry`とmarkerレイアウト計算は変更していない。OnboardingFlowの変更はSideButtonEdgeMarker overlayのtransition指定だけに限定した。
- 検証: 署名なしgeneric iOS Simulator向け全7ターゲットbuildは`BUILD SUCCEEDED`。DopaBreakCoreは513件・失敗0、DopaBreakTestsは205件・13件skip・失敗0で`TEST SUCCEEDED`。`python3 scripts/lint-display-copy.py`と`python3 scripts/audit-default-values.py`はexit 0、`git diff --check`も成功した。コミットはしていない。

## 2026-08-25 — ホーム主役指標を永久累計の「SNSに消えるはずだった時間」に変更（オーナー決定）

- 回数／割合は人生に接続しないため主役から外す。主役は開かなかった推定時間の**永久累計**（分→時間→日→年に自動繰り上げ）。今日の増分と推定根拠（回数×1回あたり分）を小さく添える
- 「この調子なら1年でN日分」の予測は廃止。目標との換算・並置もしない（目標は抽象・長期のことが多い）
- 累計は単調増加が必須。やめた1回ごとにその時点の推定秒数を台帳に確定保存し再計算しない。仕様: `.claude/specs/home-hero-lifetime-time-2026-08-25.md`

## 2026-08-25 — App Store raw nightmode の3ロケール専用再撮影

- 作成・変更: `ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` に `testCaptureNightmodeScreen()` と `captureNightmodeScreen(...)` を追加した。既存の `captureAdditionalSettingsScreens` の setup/seed/Pro検証を共有し、nightmode は `.offset(280)`（実解決 `offsetY=332`）、settle 1.0、dark、status bar 9:41、1320×2868のまま `raw-core/{ja,en-US,ko}/nightmode.png` だけを保存する。既存の full `testCaptureAdditionalSettingsScreens` は deepfocus → nightmode → grayscale の順と挙動を維持した。
- 採用方針・却下案: full 経路の複製ではなく、既存 nightmode の mode injection/render/validation を helper 化して full と専用 XCTest から共有した。専用経路で panel/contact sheet/slots/upload-order を再生成する案は raw-only 指示と生成スクリプト並行編集に反するため採用しなかった。テーマ表示は画面実装の3言語ローカライズ（ja `黒とライム` / en `Black & Lime` / ko `블랙 & 라임`）をそのまま使い、画像上で文字を合成しない。
- Claude Code向け制約: 今後 nightmode raw を更新するときは `testCaptureNightmodeScreen` を `-only-testing` で実行し、`testCaptureAdditionalSettingsScreens` の full behavior、`offset(280)`、既存 seed/state injection、dark/status bar/pixel-size guardsを変更しない。panel/contact sheet/slots/upload-order と generator はこの raw-only 経路から触らない。
- 検証: ja/en-US/ko 各1件・失敗0、各 `offsetY=332.00`、PNG/RGB/1320×2868。Vision OCRで `黒とライム` / `Black & Lime` / `블랙 & 라임` を完全一致で認識し `E1` は3画像とも認識なし。non-nightmode raw 24枚（8種×3 locale）の SHA-256 は撮影前後で全件一致。撮影用 launchd opt-in は完了後に解除し、コミットはしていない。
## 2026-08-25 — App Storeスクリーンショット訴求再編 v3反映

- 作成・変更: `.claude/specs/appstore-screenshots-v3-proposal.md`を反映済みに更新し、`.claude/specs/appstore-screenshots-v2-diagonal.md`末尾へv3の画面ソース・3言語コピー・構図・成果物正本を追加した。`scripts/generate-appstore-screenshots-v2.py`は9枚を`home / breath / stats / night / lockscreen / deepfocus / intent / reflection / grayscale`へ再編し、`scripts/generate-appstore-screenshots.py`の承認コピーも同じv3文言へ同期した。`output/app-store-screenshots/v2/{ja,en-US,ko}/iphone-69/`各9枚、`contact-sheet-{locale}.png`、`slots-{locale}.json`、`upload-order/{locale}/iphone-69/`各9枚とREADMEを再生成した。rawファイルは変更していない。
- 採用方針: 背景多角形・傾き・フォン幅はアップロード位置に固定し、旧01／02／03／04／05／06／08／09／10の構図を順に使った。画面ソースだけをhome、breath、stats Pro、night、lockscreen mock、deepfocus、intent、reflection、grayscaleへ差し替えた。3枚目は旧03の1081px・+8°を維持し、フォン上端Y1375で割合カードとInstagramを含むアプリ別カードまでを表示する。既存stats rawは週タブのため、再撮影せず生成時だけTodayチップ・80%・12/15集計を派生し、raw自体は正本のまま保持した。en-USの9枚目は指定どおり`raw-core/en-US/grayscale.png`の最新を使用した。
- キャラガード: `SCREEN_CHARACTER_COUNTS`はstats rawの気持ちカード5体を実態どおり記録し、raw内数と最終可視数を分離した。気持ちカードsource box `(60,1915,1260,2365)` は回転後の最上端Y=2881.92でキャンバス外、statsは可視画面内0＋外乗せdoom 1＝合計1。home／reflectionは画面内に各1体いるため、合計1体ルールを優先して外乗せを追加しない。lockscreenはawake、intentはblink、grayscaleはworseを構図どおり残した。全27枚は生成時に`visible screen + external <= 1`を例外ガードする。
- 却下案と理由: statsの気持ちカードを見せたまま5体を0扱いする案は実態とガードが乖離するため却下した。raw再撮影、home／reflectionへの2体目追加、承認コピーの短縮、旧アップロード順の維持も、それぞれ依頼範囲・1枚1体ルール・コピー改変禁止・v3のCVR優先順に反するため採用していない。
- Claude Code向け制約: `PANEL_IDS`は既存生成ID互換の`01〜06,08〜10`、アップロード名だけ連番`01〜09`。位置3のフォン幅1081px・+8°・上端Y1375、stats raw内5／可視0、doom外乗せ1、気持ちカードY下限2881.92を維持する。位置1は外乗せなし、位置8もreflection画面内キャラのみ。`stats_today_source()`はrawを書き換えない派生処理で、Today状態の再撮影済みrawが用意された場合だけ置換可。READMEの根拠1行と生成元↔upload-orderのSHA-256一致を崩さない。
- 検証: 生成元27枚とupload-order 27枚はすべてPNG／RGB／1320×2868、ロケール別9枚、SHA-256全一致。contact sheet 3枚は3600×869 RGB、slotsは各9件でキャラ合計最大1。Apple Vision OCRで1枚目のv3コピーと画面内6時間0分・約13日・連続7日、3枚目のv3コピーと画面内12回／15回／Instagramを3言語相当で確認した。5枚目eyebrowの通知／ウィジェット、7枚目subの5〜30分、8枚目の回数／積み上がるは不在。v3日本語コピーに読点および`%lld回、`型なし。`python3 scripts/lint-display-copy.py`は既存の要確認2件のみでexit 0、`validate_legacy_copy_reuse`、py_compile、`git diff --check`は成功。コミットは作成していない。
## 2026-08-25 — Home hero lifetime reclaimed time

- Changed `ios/DopaBreak/HomeView.swift` so the home hero presents the permanent estimated time social media did not take, its current-day delta and estimation basis; removed the duplicate weekly/yearly projection card. Added boundary-aware ja/en/ko formatting and strings in `ios/DopaBreak/Localizable.xcstrings`, with formatter coverage in `ios/DopaBreakTests/HomeStatsLinkDestinationTests.swift`.
- Adopted the existing `SmallLabel`, `dopaFont`, design tokens, streak capsule and numeric content transition. Kept the existing responsive `ViewThatFits` composition and first-day empty section. Rejected a separate reclaimed-time card, yearly forecast, goal comparison, milestone card and haptics because the owner spec makes the all-time observed result the sole hero and leaves milestone effects out of scope.
- Added a monotonic SQLite ledger in `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SQLiteLogStore.swift`, shared estimation in `Services/ReclaimedTimeEstimator.swift`, atomic cancellation recording in `Services/InterventionEngine.swift`, and ledger-backed reads in `Services/StatsService.swift`. Attempt DB schema is now v2; v1 cancellation history is backfilled once using the current 30-day opened-duration median or 300 seconds. Log reset must continue deleting both `attempt_logs` and `reclaimed_ledger` in one transaction.
- Implementation constraints for follow-up work: lifetime values must never be recomputed or decreased; each cancelled attempt owns exactly one ledger row keyed by attempt UUID; `recorded_at` controls day-range sums; formatter thresholds are minute (<1h), hour+minute (<1d), day+hour (<365d), then year+day, dropping zero lower units. Do not restore yearly projections or pair this metric with goals.
## 2026-08-25 — App Storeスクショ v3改訂案の適用（一呼吸先頭・記録5枚目）

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` のアップロード順を breath／home／lockscreen／night／stats／deepfocus／intent／reflection／grayscale-homeへ変更し、画面と訴求だけを位置別構図へ差し替えた。`scripts/generate-appstore-screenshots.py` の承認コピーも同時更新し、`.claude/specs/appstore-screenshots-v2-diagonal.md` と `.claude/specs/appstore-screenshots-v3-proposal.md`、3ロケールのupload-order READMEを同期した。v3 proposalの既存「反映済み」は維持し、改訂案適用日2026-08-25を追記した。
- 採用方針: 1枚目は旧01のライム大帯・1396px直立フォンへbreathを置き、画面内容を400px上へ寄せて「ひと呼吸おきましょう」と残り秒`4`を同時に見せた。2枚目は旧02の1111px・-7°へhome、3枚目は旧03の1081px・+8°へlock mockとLive Activity拡大、4枚目は旧04へ最新nightmode、5枚目は旧05の1000px直立・正円へstatsを置いた。statsはrawのY=1160〜1910だけをviewport化してInstagram／YouTube／TikTokを主役にし、75%カードと気持ちカード5体をsourceから除外、外乗せdoomだけを残した。rawの再撮影や75%表示の再利用はホームとの重複と1枚1体ルールに反するため採用しなかった。
- Claude Code向け制約: 内部生成IDは`01,02,03,04,05,06,08,09,10`を維持し、`CONTENT_PANEL_BY_LAYOUT`で構図と内容を分離する。nightはrender batchの最後。statsは`SCREEN_CHARACTER_COUNTS=5`／visible=0／external doom=1を維持し、`visible screen + external > 1`を例外で落とす。パネル10はmodule-levelと`configure_locale`の`SOURCE_PATHS`をともにNone、`MOCK_SOURCE_NAMES[10]`、`source_for(panel==10)`、`UPLOAD_ORDER (10,"grayscale-home")`、`mock_home_grayscale()`とHOME定数群、保護コピー3言語を巻き戻さない。
- 検証: 3ロケール×9枚はすべてPNG／RGB／1320×2868、contact sheet 3枚は3600×869 RGB、slots各9件、キャラ合計最大1。生成元27枚とupload-order 27枚はSHA-256一致。macOS Vision OCRでja 1枚目の「あと5分だけ」「35日」「ひと呼吸おきましょう」「4」、2枚目の「取り戻した時間」「6時間0分」「13日分」「連続7日」、3枚目の「SNSを開くたびに」「9:41」「あなたの目標」、5枚目のInstagram／YouTube／TikTokを認識し、5枚目に75%／気持ち文言は認識なし。`mock_home_grayscale()`の3ロケールは非グレー画素0。スクショコピーの`%lld回、`は0件、`python3 scripts/lint-display-copy.py`は既存要確認2件のみでexit 0、`validate_legacy_copy_reuse`も生成中に通過した。コミットは作成していない。
## 2026-08-25 — Home hero lifetime time 改訂2

- `ios/DopaBreak/HomeView.swift` の累計表示を、60分未満は分、60分以上は切り捨てた総時間で伸ばし続ける方式へ変更し、24時間以上では日／年換算を同一ベースライン上へ併記した。`ios/DopaBreak/Localizable.xcstrings` に日／年換算の日本語・英語・韓国語キーを追加し、旧日／年本体キーを削除した。境界仕様は `ios/DopaBreakTests/HomeStatsLinkDestinationTests.swift` で固定した。
- 採用方針: 56pt accent の累計を主役として維持し、換算は20pt semibold secondaryTextに抑える。24時間で本体を日へ繰り上げる旧案は、数値が小さく見えるため廃止した。
- 実装制約: 累計と換算は `HStack(alignment: .lastTextBaseline)`、換算は24時間未満で非表示。累計時間は桁区切りを入れず、日・年換算は1日=24時間・1年=365日で切り捨てる。今日の増分は従来どおり時間未満の端数分を保持する。
## 2026-08-25 — App Storeスクショ3枚目 Live Activity拡大構図の是正

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` のロック画面専用構図だけを更新した。直立0°と上端Y800を維持し、フォン外形を1396pxから1204px（ベゼル33px、スクリーン1138×2473px）へ縮小した。ライム正円は中心`(660,1830)`・半径640、awake反転は幅300・中心X230・下端Y1060とした。3ロケールの`03-lockscreen.png`、upload-order 03、contact sheet、slotsを再生成した。
- 採用方針・却下案: 1204pxは`mock_lock()`正本のLive Activity下辺`y=2280/2868`をキャンバスY2800以内へ収める最大整数外形幅で、実測枠は`[127.21,2436.83,1192.79,2798.98]`。概算1225pxは下端Y2832.58となるため却下した。コールアウトは原寸カード`[42,1860,1278,2280]`のLANCZOS縮小1180×401を維持して`[70,1410,1250,1811]`へ移し、時計下44.98px・実カード上625.83pxの余白を確保した。幅は実表示幅の1.107倍で1.35倍上限内。実枠上辺接線`[174,2436]`／`[1146,2436]`からコールアウト下辺接線`[122,1811]`／`[1198,1811]`へライム2px・60%の線を結んだ。
- Claude Code向け制約: `LOCK_PHONE_WIDTH=1204`、`LOCK_PHONE_VISUAL_TOP=800`、`LOCK_LIME_CIRCLE_CENTER=(660,1830)`、`LOCK_LIME_CIRCLE_RADIUS=640`、`LOCK_CALLOUT_TOP=1410`を一体で維持する。コールアウトは必ず`mock_lock()`正本からLANCZOS縮小のみ、時計下と実LA上へ各40px以上、実LA下端Y2800以下、コールアウト幅は実LA表示幅の1.35倍以下とする。接続線は双方の丸角接線点へ接続し、時計・awakeを横切らせない。キャラは画面内0＋外乗せawake 1体、スクリーン左右端はキャンバス内を維持する。パネル10の`SOURCE_PATHS`末尾None（module／`configure_locale`）、`MOCK_SOURCE_NAMES`、`source_for(panel == 10)`、`UPLOAD_ORDER (10,"grayscale-home")`、`mock_home_grayscale()`／HOME定数、3ロケールコピーを変更しない。
- 検証: 3ロケールともPNG／RGB／1320×2868、rotation 0°、キャラ合計1、実LA全体表示、コールアウト余白・倍率・接線端点、スクリーンX範囲、生成03とupload-order 03のSHA-256一致を機械検証した。macOS Vision OCRは3言語すべてで`9:41`、3目標、停止実績行を実LAとコールアウトの両方から認識した。保護対象6群、`py_compile`、`lint-display-copy.py`（既存要確認2件のみ）、対象ファイルの`git diff --check`はexit 0。コミットは作成していない。

## 2026-08-25 — App Storeスクショ4・5枚目の枠取り是正

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` の4枚目nightと5枚目statsだけを再構図した。nightは撮影済みrawを変更せず、上部700pxを画面内viewportから除外して、直立0°・フォン外形幅1396px・上端Y820を維持したまま「就寝から起床まで完全ブロック」と7:00／23:00のタイムラインをキャンバス中央帯へ上げた。statsは派生したアプリ別専用viewportを廃止し、撮り直し済みrawをそのまま使う。直立0°・幅1396px・上端Y930とし、割合カードとアプリ別カードを同時表示した。
- statsのキャラ裁定: rawの気持ちカード5体という`SCREEN_CHARACTER_COUNTS`の実態値は維持し、`VISIBLE_SCREEN_CHARACTER_COUNTS`のstats位置を固定0から`None`へ変更した。配置後に気持ちカードsource領域とキャンバスの交差を計算し、交差時5／非交差時0とする。ja／koのraw Y1915はキャンバスY2883、en-USのraw Y1954はY2922となり、3言語とも非交差で画面内0。外乗せdoomは幅300・中心X1100・下端Y1510（可視bbox`[956,1242,1244,1510]`）へ移し、割合・アプリ行を隠さず合計1体にした。旧1000pxフォンとアプリ別カードだけの合成は、割合カードを欠落させるため却下した。
- Claude Code向け制約: statsは`STATS_PHONE_WIDTH=1396`、`STATS_PHONE_VISUAL_TOP=930`、3言語別`STATS_CARD_TOPS`、可視領域交差によるキャラ算出、`visible screen + external > 1`ガードを一体で維持する。nightは`NIGHT_SOURCE_OFFSET_Y=700`、幅1396px、上端Y820、0°を維持する。パネル10のmodule／`configure_locale`両方の`SOURCE_PATHS`末尾None、`MOCK_SOURCE_NAMES`、`source_for(panel == 10)`、`UPLOAD_ORDER (10,"grayscale-home")`、`mock_home_grayscale()`／HOME定数、3言語コピーを変更していない。3枚目のロック画面定数・分岐・出力は変更していない。
- 再生成・検証: 3ロケールの04／05、contact sheet 3本、slots 3本、upload-orderを更新。全27組の生成元とupload-orderはSHA-256一致、全画像PNG／RGB／1320×2868、contact sheetは3600×869、slotsは各9件・キャラ合計最大1。Vision OCRはstats全言語で`75%`、Instagram、YouTube、TikTok、`14/18`を認識し、「見たあとの気持ち」相当と「満足感があった」相当を認識しなかった。nightは全言語で7:00、23:00、就寝から起床までの完全ブロック相当を認識した。`py_compile`、保護6群、stats可視キャラガード、`lint-display-copy.py`（既存要確認2件のみ）、`git diff --check`はexit 0。3枚目は3言語すべて作業前SHA-256と一致した。
- 同時更新の記録: 全ロケール生成中、日本語`raw-core/ja/home.png`が18:03:33に別プロセスから更新された。今回対象外の日本語02は作業前SHA-256 `5840ed8f...` から、18:00:37に生成済みの`239da966...`へ変化したため、対象外21枚のうち20枚は作業前ハッシュ一致、日本語02だけは一致しない。04／05の構図コード・パネル3・保護6群とは独立したraw競合であり、当該rawやHome実装は本作業から変更していない。

## 2026-08-25 — App Storeスクショ2枚目をホームヒーロー改訂2へ更新

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` のホームコピーを `.claude/specs/appstore-screenshots-v3-proposal.md` の改訂2へ3言語とも一字一句同期し、承認正本 `scripts/generate-appstore-screenshots.py` の各先頭コピーも同値へ更新した。`.claude/specs/appstore-screenshots-v2-diagonal.md` の2枚目コピー表と画面ソース／構図記述を更新し、`output/app-store-screenshots/v2/{ja,en-US,ko}/iphone-69/02-home.png`、contact sheet 3本、slots 3本、upload-order 02を再生成した。
- 採用方針・却下案: 撮影済み `raw-core/{locale}/home.png` の改訂2ヒーローを、ライム上半分・外形1396px・直立0°・上端Y820で最大表示する。これによりawake、312時間と13日換算、今日+2時間、12回×約10分、連続7日、3アイコン、8秒説明、30分CTAまでを画面内へ収め、下の週バーだけをクロップした。旧1111px・-7°の細リボン構図は主要カードを小さくするため採用せず、外乗せマスコットも画面内awakeと重複するため置いていない。
- Claude Code向け制約: 2枚目は `raw-core/{locale}/home.png`、`MAX_STRAIGHT_PHONE_WIDTH=1396`、rotation 0°、外形上端Y820、ライム上半分、`SCREEN_CHARACTER_COUNTS` home=1／visible=1／external=0／total=1を一体で維持する。コピーは改訂2の3言語値から改変せず、承認正本との `validate_legacy_copy_reuse` を維持する。パネル10のmodule／`configure_locale`両方の`SOURCE_PATHS`末尾None、`MOCK_SOURCE_NAMES`、`source_for(panel == 10)`、`UPLOAD_ORDER (10,"grayscale-home")`、`mock_home_grayscale()`／HOME定数、3ロケールコピーを変更しない。3／4／5枚目を含む対象外パネルは再構図しない。
- 検証: 3ロケールの02はPNG／RGB／1320×2868、rotation 0°、外形幅1396、上端Y820、画面内キャラ1／外乗せ0／合計1。生成元27枚とupload-order 27枚はSHA-256一致し、02のSHA-256はja=`487cf081c1f5abe201cb46f02b7176af77ee4f35e46774a505fc074817dc8b1a`、en-US=`2e8f3a9cd7f015340ccc0db2d60587e27371330b966ec91352c2bc00f7bbbaed`、ko=`59de2f10b5299596529508682296afd68ae07e52e8bed08cb307bad5364f7bb2`。作業前後60成果物のうち変更は02×3、contact sheet×3、slots×3、upload-order 02×3の12件だけで、他48件および生成01／03／04／05／06／08／09／10の24枚はハッシュ不変。macOS Vision OCRはjaの指定5語句、en-USの`312 hr`／`13 days`、koの`312시간`／`13일치`を認識し、旧「取り戻した時間」「1年で約」は不在。保護6群、`validate_legacy_copy_reuse`、`py_compile`、`lint-display-copy.py`（既存要確認2件のみでexit 0）、`git diff --check`も通過した。コミットは作成していない。

## 2026-08-25 — App Store raw nightmode の3ロケール訴求位置再調整

- 作成・変更: `ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` の既存 `captureNightmodeScreen(...)` だけを変更し、`verticalScrollTarget` を `.offset(280)` から `.offset(615)` へ更新した。`testCaptureNightmodeScreen()`、既存のPro権利・夜だけ強化・起床7:00／就寝23:00のシード、実ウィンドウ描画、dark、status bar 9:41、指定UDID、1320×2868ガードは維持した。保存先は `output/app-store-screenshots/raw-core/{ja,en-US,ko}/nightmode.png` の3枚だけで、scripts、panel、contact sheet、slots、upload-order、他rawは触っていない。
- 採用方針・却下案: 上限までの自然なUIScrollViewスクロールで、無関係な設定行を減らし、起床・就寝時刻カードを可能な範囲で上へ寄せた。選択中の「夜だけ強化」カードも同時表示する案は、タイムラインを優先すると自然な表示範囲に入らないため却下した。最大値を超えるオーバースクロール、画像の切り貼り、画面実装・シードの変更は採用していない。
- Claude Code向け制約: nightmode rawの更新は今後も `testCaptureNightmodeScreen` の専用経路を使い、full `testCaptureAdditionalSettingsScreens`、offset以外のseed/state injection、他のraw、生成物を変更しない。今回の要求値615に対する実解決offsetはja=`516.33`、en-US=`554.00`、ko=`523.33`。タイムラインカード外周線の上端は3ロケールとも1320×2868座標で`Y=1049px`（塗り開始`Y=1051px`）。
- 検証: ja/en-US/ko各1件の専用XCTestは失敗0。Vision OCRでjaの`7:00`／`23:00`／`就寝から起床まで完全ブロックする`／`黒とライム`、en-USの`7:00`／`23:00`／bedtime block訴求／`Black & Lime`、koの`7:00`／`23:00`／`취침 시각부터 기상 시각까지 앱을 완전히 차단해요`／`블랙 & 라임`を認識した。3枚は各1320×2868。nightmode以外の8画面×3ロケール24枚は撮影前後SHA-256一致。hostとSimulatorの撮影opt-in環境変数は撮影後に解除し、schemeへの一時注入も残していない。コミットは作成していない。

## 2026-08-25 — App Storeスクショ4・5枚目 最終パス

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` の4枚目nightと5枚目statsだけを最終調整した。nightは`night_timeline_source()`と700pxのsource offsetを廃止し、撮り直し済み`raw-core/{ja,en-US,ko}/nightmode.png`のraw y=0をスクリーンy=0へ固定した。直立0°、フォン外形幅1000px、上端Y760で、起床・就寝タイムラインをキャンバス中央帯へ置いた。statsは画面・コピー・フォン幅1396px・上端Y930を維持し、外乗せdoomだけを中心X1130・下端Y1260へ移して、全期間チップ行より上のフォン右上へ重ねた。
- 採用方針・却下案: nightのraw内部を上へずらす案は、Dynamic Islandと設定行の位置関係を実機表示から変えるため却下した。rawは無加工のまま、外枠の幅・上端・キャンバス下端クロップだけで訴求位置を調整する。statsのdoomをチップ行付近へ残す案もUI文字を隠すため却下し、全身をキャンバス内に保ちながら右上の空きへ逃がした。気持ちカードの画面内5体は引き続きキャンバス外で、外乗せdoomとの合計は1体。
- Claude Code向け制約: nightは`NIGHT_PHONE_WIDTH=1000`、`NIGHT_PHONE_VISUAL_TOP=760`、rotation 0°を一体で維持し、panel 4にsource crop／paste offsetを再導入しない。statsは`STATS_PHONE_WIDTH=1396`、`STATS_PHONE_VISUAL_TOP=930`、doomの`width=300`／`centerX=1130`／`bottomY=1260`、可視bbox`[986,992,1274,1260]`を維持する。パネル10のmodule／`configure_locale`両方の`SOURCE_PATHS`末尾None、`MOCK_SOURCE_NAMES`、`source_for(panel == 10)`、`UPLOAD_ORDER (10,"grayscale-home")`、`mock_home_grayscale()`／HOME定数、3ロケールコピーを変更しない。1／2／3／6／8／9／10の生成画像も変更しない。
- 再生成・検証: 3ロケールの04／05、contact sheet 3本、slots 3本、upload-orderの04／05を再生成した。Vision OCRは全言語で`7:00`、`23:00`、就寝から起床までの完全ブロック相当を認識し、rawと`source_for(4)`の全画素一致でy=0固定を確認した。保護6群、全27組の生成元とupload-orderのSHA-256一致、1／2／3／6／8／9／10の作業前SHA-256一致、全画像のPNG／RGB／1320×2868、contact sheet 3600×869、slots各9件、キャラ合計最大1、`py_compile`、`lint-display-copy.py`（既存要確認2件のみ）、`git diff --check`を通過した。コミットは作成していない。

## 2026-08-25 — App Storeスクショ4枚目（夜だけ強化）の枠取り再修正

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` の4枚目専用定数だけを再修正した。`NIGHT_PHONE_WIDTH`を`MAX_STRAIGHT_PHONE_WIDTH`（1396px）へ揃え、`NIGHT_PHONE_VISUAL_TOP`を800pxへ設定した。既存のpanel 4分岐はraw全体をスクリーンy=0へ置く方式、rotation 0°のまま維持し、フォン外形下端Y3744でキャンバス外へクロップする。3ロケールの`04-night.png`、contact sheet 3本、slots 3本、upload-orderの04を再生成した。
- 採用方針・却下案: 1／2枚目と同じ「スクリーン左右端がキャンバス端に一致する最大幅」を採用した。raw内部のcrop／paste offsetや傾きでタイムラインを動かす案は、Dynamic Island直下の行と実画面の位置関係を壊すため却下した。rawのタイムラインカード原寸box`[60,1049,1260,1429]`はキャンバス`[60,1887,1260,2267]`（中心Y2077）となり、7:00／23:00と「就寝から起床まで完全ブロックする」相当を中央帯へ配置できた。4枚目には外乗せマスコットを追加せず、キャラ合計0体を維持した。
- Claude Code向け制約: panel 4は`NIGHT_PHONE_WIDTH=MAX_STRAIGHT_PHONE_WIDTH`、`NIGHT_PHONE_VISUAL_TOP=800`、rotation 0°、raw y=0固定、外形下端クロップを一体で維持する。`SOURCE_PATHS`のpanel 10 `None`（module／`configure_locale`）、`MOCK_SOURCE_NAMES`、`source_for(panel == 10)`、`UPLOAD_ORDER (10,"grayscale-home")`、`mock_home_grayscale()`／HOME定数、panel 10の3言語コピーは変更しない。1／2／3／5／6／8／9／10の生成画像とraw-coreは変更しない。
- 検証: 3ロケールの04・contact sheet・slots・upload-order 04を再生成し、04はPNG／RGB／1320×2868、contact sheetは3600×869、slotsは各9件。3ロケールとも外形幅1396px・上端Y800・スクリーンX=0〜1320・rotation 0°、Vision OCRで`7:00`／`23:00`／完全ブロック相当／`黒とライム`・`Black & Lime`・`블랙 & 라임`を認識した。保存前後の機械比較で許可外の出力差分0、raw-core全件SHA-256不変、保護6群、upload-order一致、lint exit 0、`git diff --check`を確認した。コミットは作成していない。

## 2026-08-25 — App Storeスクショ2枚目のオーナー確定案A・ASO順序を反映

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` と承認正本 `scripts/generate-appstore-screenshots.py` のホームコピーを3言語で案Aへ同期した。en-US eyebrowは中核キーワード復元のため `DOPAMINE DETOX, COUNTED IN HOURS` とした。`.claude/specs/appstore-screenshots-v2-diagonal.md`、`.claude/specs/appstore-screenshots-v3-proposal.md`、`output/app-store-screenshots/v2/upload-order/{ja,en-US,ko}/README.md`を同じ正本へ更新し、3ロケールの02、contact sheet、slots、upload-orderを再生成した。
- 採用方針・却下案: 旧「減らずに積み上がる」／`keeps adding up`／`줄지 않고`は仕組み説明に寄り、回収した時間が人生へ戻るベネフィットを示せないため却下した。アップロード順はApple Ads Insights実測（JP: 勉強70・タイマー66・集中60 > 睡眠66 ／ KR: 공부65 > 수면55）を根拠に `breath, home, deepfocus, night, lockscreen, stats, intent, reflection, grayscale-home` とし、検索結果の先頭3枚で「SNS時間の損失→人生の時間→集中・勉強のタイマー」を伝える。
- Claude Code向け制約: 生成ID・各パネルの構図・raw／mock・フォン枠は維持し、順序変更は`UPLOAD_ORDER`、upload-orderのファイル名、contact sheet、slotsのupload positionだけに限定する。2枚目は`raw-core/{locale}/home.png`、外形幅1396px、rotation 0°、上端Y820、画面内キャラ1／外乗せ0を維持する。en-US見出し1行目は自然幅1918pxのため、既存規則で112pxから72pxへフォントサイズだけ縮小し、描画幅1232px・横伸縮率1.0とする。panel 10の保護6群は変更しない。
- 検証: 保存前AST指紋でpanel 10の`SOURCE_PATHS=None` 2箇所、`MOCK_SOURCE_NAMES`、`source_for`分岐、`mock_home_grayscale()`／HOME定数を作業前と一致確認し、`UPLOAD_ORDER (10,"grayscale-home")`と3ロケールコピーも確認した。生成元27枚の作業前後差分は02×3だけで、各差分bboxはy=240〜723以内、フォン開始y=820以降は全画素不変。他24パネルはSHA-256不変。生成元とupload-order全27組のSHA-256一致、03=`deepfocus`、05=`lockscreen`、全画像PNG／RGB／1320×2868、contact sheet 3600×869、slots各9件、キャラ合計最大1、raw-core不変を確認した。macOS Vision OCRは3言語の新コピー全行とen-USの`DOPAMINE DETOX`を認識し、旧3表現は不在。`validate_legacy_copy_reuse`、`py_compile`、`python3 scripts/lint-display-copy.py`（既存要確認2件のみ）、`git diff --check`はexit 0。コミットは作成していない。

## 2026-08-25 — App Storeスクショ1枚目（一呼吸）の承認コピーへ復帰

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` の `CONTENT_PANEL_BY_LAYOUT[1] = 2` に対応する一呼吸コピーだけを、ja／en-US／koの承認値へ変更した。承認正本 `scripts/generate-appstore-screenshots.py` の同じコピーを同期し、`.claude/specs/appstore-screenshots-v2-diagonal.md` と `.claude/specs/appstore-screenshots-v3-proposal.md` の1枚目コピーも更新した。35日の損失フック（「あと5分だけ」／「1年で35日になる」等）は不採用と明記した。
- 採用方針・却下案: 「禁止しないアプリ制限／SNSをブロックしない／開く前にひと呼吸／反射で開く瞬間にだけ短いブレーキ」を日本語正本とし、英語・韓国語も承認文を一字一句維持する。1枚目のライム帯、フォン枠取り、raw `breath.png`、`BREATH_SOURCE_OFFSET_Y=400`、画面内キャラ1体は変更していない。旧35日換算で損失を強調する案は、承認済みの「ブロックせず選べる一呼吸」訴求と異なるため却下した。
- Claude Code向け制約: 一呼吸は生成ID01／upload position 1／content panel 2の対応を維持する。パネル10のmodule／`configure_locale`両方の`SOURCE_PATHS`末尾`None`、`MOCK_SOURCE_NAMES`、`source_for(panel == 10)`、`UPLOAD_ORDER (10,"grayscale-home")`、`mock_home_grayscale()`／HOME定数群／3言語コピーは巻き戻さない。1枚目以外の生成パネル、raw、フォン構図、slotsの1枚目非コピー幾何を変更しない。
- 再生成・検証: 3ロケールの01、contact sheet 3本、slots 3本、upload-order 01を生成し、生成元とupload-orderの全27組をSHA-256一致させた。保存前マニフェストとの比較でraw-core 27枚、01以外の生成元24枚、01以外のupload-order 24枚、保護6群、1枚目の非コピー幾何がすべて不変。Vision OCRで3言語の承認コピー全行を認識し、旧4表現は不在。PNG/RGB/1320×2868、contact sheet 3600×869、slots各9件、`validate_legacy_copy_reuse`、`py_compile`、`python3 scripts/lint-display-copy.py`（既存要確認2件のみ・exit 0）、`git diff --check`を確認した。コミットは作成していない。

## 2026-08-25 — App Storeスクショのアップロード順をロック画面先行へ変更

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` の `UPLOAD_ORDER` を `breath, home, lockscreen, deepfocus, night, stats, intent, reflection, grayscale-home` へ変更した。`output/app-store-screenshots/v2/upload-order/{ja,en-US,ko}/README.md` の順序・根拠行、`.claude/specs/appstore-screenshots-v2-diagonal.md` と `.claude/specs/appstore-screenshots-v3-proposal.md` の最終正本の並び記述を同期し、3ロケールのupload-order 27枚、contact-sheet 3本、slots 3本を再生成した。
- 採用方針・却下案: 上位3枚＝一呼吸（差別化の仕組み）→ 人生の時間（数字）→ ロック画面の目標（他ブロッカーに無い差別化・オーナー指示）。集中タイマー（勉強70/集中60）は4枚目とする。従来の「集中タイマーを3枚目、ロック画面を5枚目」はロック画面の差別化を上位で伝えられないため却下した。各パネルの画像・構図・画面・コピーは変更していない。
- Claude Code向け制約: 生成ID、`SLUGS`、各パネルの構図・画面・コピー、raw/mock、フォン枠は固定する。順序変更は `UPLOAD_ORDER` と、それから派生するupload-orderのファイル名、contact-sheetの並び、slotsの `upload_position` に限定する。`SOURCE_PATHS` のpanel 10 `None`（module／`configure_locale`）、`MOCK_SOURCE_NAMES = {5: "mock_lock", 10: "mock_home_grayscale"}`、`source_for` のpanel 10分岐、`mock_home_grayscale()` 本体、HOME定数、panel 10の3言語コピー、`UPLOAD_ORDER (10, "grayscale-home")` は保護対象として維持する。
- 再生成・検証: 生成元27枚とraw-core27枚のSHA-256は作業前後で一致。3ロケール各9枚は `01-breath`／`02-home`／`03-lockscreen`／`04-deepfocus`／`05-night`／`06-stats`／`07-intent`／`08-reflection`／`09-grayscale-home` となり、全upload-orderコピーは対応する生成元とSHA-256一致。contact-sheet 3本は各3600×869 RGBで新順序、各画像は1320×2868 RGB、保護6群のASTフィンガープリント一致、メモリ上のPython compile exit 0、`python3 scripts/lint-display-copy.py` exit 0、`git diff --check` exit 0を確認した。コミットは作成していない。

## 2026-08-25 — App Storeスクショのstats不採用・アップロード順8枚化（オーナー指示）

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` の `UPLOAD_ORDER` を `breath, lockscreen, deepfocus, home, night, intent, reflection, grayscale-home` の8枚へ変更した。生成ID05のstats画像・`raw-core/{locale}/stats.png`・撮影経路・構図コード・生成番号ファイルは保持し、`output/app-store-screenshots/v2/upload-order/{ja,en-US,ko}/iphone-69/`、`contact-sheet-{ja,en-US,ko}.png`、`slots-{locale}.json`／`slots.json`からだけ除外した。contact-sheet生成とslots/upload-orderの件数検証を、固定9件から`UPLOAD_ORDER`の8件へ一般化した。
- 設計正本: `.claude/specs/appstore-screenshots-v2-diagonal.md` と `.claude/specs/appstore-screenshots-v3-proposal.md` の現行正本を、アップロード順1一呼吸／2ロック画面の目標／3集中タイマー／4ホーム／5夜だけ強化／6理由選択／7振り返り／8白黒ホームへ同期した。`output/app-store-screenshots/v2/upload-order/{ja,en-US,ko}/README.md`へ、指定の根拠行「上位3枚＝差別化機能（一呼吸→ロック画面の目標→集中タイマー[勉強70/集中60]）。成果の数字（ホーム312時間）は4枚目。記録はホームと重複のため不採用（オーナー指示 2026-08-25）」を反映した。
- 採用方針・却下案: ホームと内容が重複する記録(stats)はオーナー指示によりアップロード訴求から不採用とした。生成番号05を削除して番号を詰める案は、生成画像・raw・撮影経路を壊し、既存参照との対応も失うため却下した。パネル画像の構図・画面・コピーを変更せず、順序と派生納品物だけを変更した。
- Claude Code向け制約: 生成画像は9枚（`01,02,03,04,05,06,08,09,10`）を保持し、statsは生成時のraw5体・可視領域ガードも維持する。アップロード対象は8枚、contact-sheetは各`3200×869`、slotsは各8件。3ロケールのupload-orderは生成元とバイト一致し、旧`09-*.png`はupload-orderに残さない。パネル10の `SOURCE_PATHS` 末尾`None` 2箇所、`MOCK_SOURCE_NAMES`、`source_for(panel == 10)`、`UPLOAD_ORDER (10, "grayscale-home")`、`mock_home_grayscale()`、HOME定数、3言語コピーは変更しない。
- 検証: 保存前マニフェストとの機械比較で保護AST群（SOURCE_PATHS None×2／MOCK_SOURCE_NAMES／source_for panel 10／grayscale-home順序／mock本体／HOME定数／panel10コピー）を一致確認。生成画像・rawは54/54 SHA-256不変、生成画像は各locale 9枚（stats保持）、upload-orderは各locale 8枚、contact-sheetは3本とも`3200×869 RGB`で順序どおり、slotsは3本とも8件でstats不在、`python3 scripts/lint-display-copy.py` exit 0（既存の意図的な要確認2件のみ）、Python compile、`git diff --check`もexit 0。コミットは作成していない。

## 2026-08-25 — App Storeスクショ5〜7枚目の構図バリエーション確定版

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` の生成ID04 night／08 intent／09 reflectionだけを構図変更し、`.claude/specs/appstore-screenshots-v2-diagonal.md` の正本表と確定値を同期した。3ロケールの04／08／09、`contact-sheet-{ja,en-US,ko}.png`、`slots-{ja,en-US,ko}.json`／`slots.json`、upload-orderの05／06／07を再生成した。コピー、raw／mock、`UPLOAD_ORDER`の8枚順は変更していない。
- 採用方針: nightはダーク＋ライム右下ウェッジ、外形1081px・+8°・上端Y820、awake幅200・中心X1220・下端Y1820で右ウェッジへ接地した。`nightmode.png`はraw y=0を維持し、`7:00`／`23:00`を読める。intentはライム上半分、外形1396px・0°・上端Y800・下端クロップ、ライム面コピー配色とし、awake幅300・中心X1120・下端Y1420を画面右上の無文字域へ置いた。reflectionはダークグラデ＋細いリボン`[(0,770),(1320,810),(1320,890),(0,850)]`、外形1396px・0°・上端Y800・下端クロップで、raw内の1体だけを表示する。
- 却下案: nightのawake幅300／400を下端へ置く案は、Vision OCRの最下部注記または設定行boxと交差したため却下した。reflectionの旧+7°・1111pxは直立指定を満たさず、急角度の太いリボンは最大幅フォンに隠れて構図差が読めないため却下した。intentの旧+8°ウェッジはnightへ移し、awakeを理由カード上へ残す案はUI文字干渉を避けるため採用しなかった。
- Claude Code向け制約: アップロード順の構図は、1帯（0°）／2円（0°）／3左下ウェッジ（-8°）／4ライム上半分（0°）／5右下ウェッジ（+8°）／6ライム上半分（0°）／7リボン（0°）／8ライム下半分（0°）。4と6は非隣接なので許容し、隣接同一構図を作らない。night／intentの外乗せawakeとreflectionの画面内キャラをそれぞれ合計1体に保つ。スクリーン左右端はキャンバス内、外乗せalpha bboxは全身キャンバス内、raw y=0とコピー／画面ソース／アップロード順を維持する。パネル10の保護6群（`SOURCE_PATHS`末尾None×2、`MOCK_SOURCE_NAMES`、`source_for(panel == 10)`、`UPLOAD_ORDER (10,"grayscale-home")`、`mock_home_grayscale()`／HOME定数、3言語コピー）は変更しない。
- 検証: `py_compile`、保護6群、全24組の生成元とupload-orderのSHA-256一致、対象外18生成画像（アップロード対象5パネル＋stats、各3言語）の作業前SHA-256一致、各画像PNG／RGB／1320×2868、contact sheet 3200×869、slots各8件、キャラ合計最大1、スクリーンX範囲、マスコット全身範囲、隣接同一構図なしを機械確認した。Vision OCRは3言語でnightの`7:00`／`23:00`、intentの目的質問、reflectionの振り返り質問を認識した。外乗せキャラとOCR意味文字の交差は0（nightの単記号認識はキャラ自身の図柄）。`python3 scripts/lint-display-copy.py`は既存の意図的2件のみでexit 0、`git diff --check`もexit 0。コミットは作成していない。

## 2026-08-25 — Live Activityテーマ7案の再設計モック（提案・オーナー判断待ち）
- 背景: 現行のロック画面テーマ7種は同一レイアウト×パレット5色差し替えのみ（`ios/WidgetsExtension/DopaBreakWidgets.swift` liveActivityView）。オーナーが「色替えだけ」を却下し、構図から別物の7案を要求。さらに墨と灯・森林・夜更けの初案も却下され、「ゲーミング、シンプルモノクロ、リキッドグラスなど」への入れ替え指示。
- 提案（未承認）: ①黒とライム=現行維持 ②ゲーミング=HUD＋クエストログ＋DotGothic16＋色収差数字（墨と灯と入れ替え） ③朝霧=中央軸ミニマル ④シンプルモノクロ=白黒スイスタイポ・大数字ヒーロー（森林と入れ替え） ⑤リキッドグラス=iOS 26システムガラス素材・背景tintなし（夜更けと入れ替え） ⑥K-POP=ポスター＋チケットチップ＋マーキー帯 ⑦かわいいピンク=バブルピル＋吹き出し・キャラIPなし
- 成果物: gpt-image-2モック7枚 `output/mockups/live-activity-themes/01〜07*.png`／設計一覧HTML `output/mockups/live-activity-theme-redesign-2026-08-25.html`（Artifact公開済み）
- 実装メモ: 全案WidgetKit実装可・画像アセット不要。テーマ入れ替えは`LockTheme` enumのcase名・パレット・表示名（3言語）の変更を伴う。DotGothic16はSIL OFLで埋め込み可。リキッドグラスは`activityBackgroundTint`を外しシステム素材に任せる
## 2026-08-25 — App Storeスクリーンショットv2のiPad 13インチ派生

- 変更: `scripts/generate-appstore-screenshots-v2.py`へ`--device ipad-13`を追加し、iPhoneと同じ1320×2868 raw/mockをiPhone筐体へ入れたまま2064×2752キャンバスへ再配置した。生成物は`output/app-store-screenshots/v2/{ja,en-US,ko}/ipad-13/`、`upload-order/{locale}/ipad-13/`、`contact-sheet-ipad-{locale}.png`、`slots-ipad-{locale}.json`。設計正本は`.claude/specs/appstore-screenshots-v2-diagonal.md`のiPad節。
- 採用方針: コピーは中央揃え・幅78%上限・iPhone比1.25倍フォント上限・自然幅描画、フォンは外形幅58〜60%・左右完全包含・下端のみクロップ可とした。帯／円／ウェッジ／上半分ライム／リボンは0.75比率のキャンバスへ個別に座標を引き直し、傾きはnight +8°／deepfocus -8°を維持した。実iPadを撮影する案と、iPhone完成画像を一括拡大する案は、指定されたiPhoneフォンモック構図と自然幅コピー、筐体非クロップを満たさないため不採用。
- キャラ: 各枚合計1体を機械ゲートにした。rawにキャラがないDeep Focusだけ左余白へreliefを追加し、それ以外は画面内キャラまたはiPhone構図と同じ外乗せキャラを再配置した。全身alpha bboxをキャンバス内へ収め、コピーブロックとの重なりを禁止した。
- Claude Code向け制約: iPhone出力経路と既定`--device iphone-69`を維持する。`SOURCE_PATHS`のpanel 5/10=`None`、`MOCK_SOURCE_NAMES`、`source_for()`のpanel 10分岐、`UPLOAD_ORDER`のgrayscale-home、`mock_home_grayscale()`とHOME定数、panel 10の3言語コピーは変更しない。iPadの画面ソースは引き続き1320×2868で、`prepare_device(..., expected_source_size=IPHONE_CANVAS_SIZE)`を外さない。iPad生成はiPhone成果物へ書き込まない。
- 検証: 生成24枚＋upload-order 24枚は2064×2752 RGB PNG・アルファなし。ASC `IPAD_PRO_3GEN_129` validateはja/en-US/koとも8/8 ready・warning/error 0。macOS Vision OCRは24枚すべてでeyebrow/headline 2行/subの4要素を認識。iPhone生成24枚＋upload-order 24枚＋contact-sheet 3枚のSHA-256、保護6群のASTハッシュ、Python構文・lintを不変/成功条件として確認する。
- 追記（2026-08-25 オーナー指示・確定）: **実績回数（開くのをやめた回数）を大きく配置する案は不可。目標が主役。** 大数字ヒーロー型だったゲーミング・シンプルモノクロ・K-POPを目標主体レイアウトへ改稿し、回数は全案で小さな1行・帯・カプセル等の控えめな扱いに統一した。

## 2026-08-25 — ゲーミングLive Activityカード単体モック

- 作成: `output/mockups/live-activity-themes/02-gaming.png`。1536×1024の横長キャンバス中央に、約72%幅・角丸約24pxの単一Live Activityカードを配置した。
- 採用方針: `#171129`〜`#0A0714`の暗紫黒背景、`#0A0A14`カード、シアン〜紫〜マゼンタのネオン枠、薄い走査線、HUD角 brackets、ドットマトリクス風日本語を採用。3つの目標行（「英語で商談できる自分になる」「朝のランニングを続ける」「読書を30分する」）を最大の視覚要素とし、回数は下部の小さなステータス行に限定した。
- 却下案: 大きな実績回数、iPhone筐体、手・写真表現、追加キャプション、余分なロゴ／透かし、目標以外の大きな数字は採用しない。
- Claude Code向け制約: 画像をWidget実装の背景やスクリーンショット内の端末フレームとして再利用する場合も、カード単体・目標主体・小さい回数という階層を維持する。日本語コピーは指定文字列を変更せず、カード外に追加テキストを置かない。

## 2026-08-25 — App Storeスクショ外乗せマスコットの角掛け・サイズ統一

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` のupload 3（生成ID06 deepfocus）／5（ID04 night）／6（ID08 intent）／8（ID10 grayscale-home）を、外乗せマスコットがフォン上角へ絡む構図へ統一した。iPhoneは全4体nominal 470px。deepfocus=`blink`・右上・-8°、night=`relief`・左上・+8°、intent=`awake`・右上、grayscale-home=`worse`・右上。upload 1／2、コピー、raw/mock、画面ソース、アップロード順、背景の帯・円・ウェッジ・リボンは変更していない。
- grayscale-home: iPhoneは最大直立外形1396pxを維持し上端Y805へ詰めた。iPadは外形2184pxへ拡大し、スクリーンX=0〜2064、筐体X=-60〜2124、上端Y760、下端クロップとした。白黒ホーム上へピンクのworseを大きく掛け、旧左下接地配置を廃止した。
- iPad派生: フォン比率でdeepfocus／nightのキャラを521px、intentをalpha幅要件の下限を満たす470px、最大幅grayscale-homeを735pxとした。角はiPhoneと同じ右／左／右／右、傾きは-8°／+8°／0°／0°。旧deepfocusの左下relief、nightの右下awake、intentの右上小awake、grayscale-homeの左下worseはいずれも役割が弱く接地物に見えたため不採用。
- 実装ガード: `validate_corner_character_geometry()`を追加し、表情、左右、alpha bbox幅440px以上、マーケコピー矩形との交差0、フォン外形bboxとの交差、指定角の上下をまたぐことを`raise`で固定した。結果は`slots-{locale}.json`／`slots-ipad-{locale}.json`の`corner_attachment`へ保存する。iPad panel 10だけは筐体左右クロップを許容し、スクリーン左右端の0／2064一致と外形2184pxを別ガードで固定した。
- 数値検証: iPhone alpha幅はdeepfocus/night/intent/grayscale=`445/444/446/448px`、フォン外形bboxとの交差サイズは`445×340 / 444×340 / 446×350 / 448×355px`。iPad alpha幅は`493/492/446/698px`、交差サイズは`437.95×465 / 432.95×460 / 364×350 / 698×565px`。全8枚でコピー交差0、全身キャンバス内、角またぎtrue。macOS Vision OCRの全認識bboxとの交差も0で、最短余白はiPhone night 29.36px、iPad grayscale-home 91px。
- 再生成・検証: 3ロケール×対象4枚をiphone-69／ipad-13へ反映し、contact-sheet 6本、slots 6本、upload-order該当24枚を更新。iphone-65は対象12枚だけを`sips`で1284×2778へ再派生した。PNG検査123枚は指定寸法・RGB・アルファなし、生成元とiphone-69／ipad-13 upload-orderの48組はbyte一致、非対象生成27枚とiphone-65非対象12枚は作業前SHA-256不変。jaの`asc screenshots validate`はIPHONE_69／IPHONE_65／IPAD_PRO_3GEN_129が各8/8 ready・warning/error 0。保護6群はHEADとのAST 29ノード一致（fingerprint `68be6bd943ef64ec70dd2bc146fa3ba780c45ba09a6328d9203efebf0e55f09b`）、Python compile、`lint-display-copy.py`（既存の意図的な要確認2件のみ）、`git diff --check`、差分TODO/FIXME 0を確認した。コミットは作成していない。
- Claude Code向け制約: 外乗せ共通基準と確定座標は`.claude/specs/appstore-screenshots-v2-diagonal.md`末尾の追記を正本とする。`SOURCE_PATHS`のpanel 10 `None` 2箇所、`MOCK_SOURCE_NAMES = {5: "mock_lock", 10: "mock_home_grayscale"}`、`source_for(panel == 10)`、`UPLOAD_ORDER (10,"grayscale-home")`、`mock_home_grayscale()`／HOME定数、panel 10コピー3ロケールは変更しない。1・2枚目と非対象パネルの構図・生成物を巻き戻さない。

## 2026-08-25 — iPad 13インチApp Storeスクショのフォン拡大

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` の `ipad-13` 分岐だけを改修し、直立7構図（ロック画面を除く）のフォン外形を1480px（キャンバス比71.7%）、night +8°／deepfocus -8°を回転後の左右完全包含上限1607pxへ拡大した。ロック画面は上端Y720を維持し、実Live ActivityカードがY2750.99まで収まる最大1224pxとした。コールアウトは時計下端と実カード上端の中間へ動的に置き、両側の垂直余白を約289pxへ揃えた。
- 採用方針・却下案: 8枚目grayscale-homeも直立共通1480px・上端Y760・筐体左右完全包含へ統一し、旧2184pxの左右筐体クロップはオーナー指定と衝突するため廃止した。外乗せマスコットはフォン幅の約1/3（直立493px、傾き536px、ロック408px）とし、iPhone版と同じ側の上角へ掛けた。帯・円・左右ウェッジ・上半分・リボン・下半分という背景種別は維持し、新フォン寸法に合わせて座標だけを再配置した。
- 成果物: `output/app-store-screenshots/v2/{ja,en-US,ko}/ipad-13/` 24枚、`output/app-store-screenshots/v2/upload-order/{ja,en-US,ko}/ipad-13/` 24枚、`contact-sheet-ipad-{ja,en-US,ko}.png`、`slots-ipad-{ja,en-US,ko}.json`を再生成した。全画像は2064×2752 RGB PNG・アルファなし、contact sheetは3200×533 RGB。
- Claude Code向け制約: iPadの直立フォン1480px／Y760、傾きフォン1607px／Y760、ロック1224px／Y720を維持する。傾き幅+1pxとロック幅+1pxが各包含条件を破ることを生成時ガードで確認する。フォン下端のみキャンバス外クロップ可。コピー、raw/mock、`UPLOAD_ORDER`、背景種別、保護6群は変更しない。iPhone生成経路・成果物へ書き込まない。
- 検証: `asc screenshots validate --device-type IPAD_PRO_3GEN_129`はja/en-US/ko各8/8 ready・warning/error 0。生成元/upload-order 24組はSHA-256一致。保存前後でiphone-69／iphone-65関連78ファイルのSHA-256一致、保護AST 29ノード一致。Python compile、`lint-display-copy.py`（既存の意図的要確認2件のみ・exit 0）、`git diff --check`、差分TODO/FIXME/省略記号0を確認した。コミットは作成していない。

## 2026-08-25 — iPad 13インチ1枚目（一呼吸）の残り秒表示修正

- 作成・変更: `scripts/generate-appstore-screenshots-v2.py` に1枚目専用の `IPAD_BREATH_PHONE_VISUAL_TOP=670` を追加し、`ipad-13` の `panel == 1` だけフォン上端を従来のY760からY670へ上げた。フォン幅1480px、コピー、ライム帯、背景、構図種別、raw `breath.png`、iPhone経路、iPadの他7枚は変更していない。3ロケールの01、iPad contact sheet 3本、iPad slots 3本、upload-orderのiPad 01を再生成した。
- 採用方針・却下案: 幅を共通 `IPAD_STRAIGHT_PHONE_WIDTH` ごと縮小するとiPadの他パネルへ波及するため却下し、01専用の上端Yだけを調整した。Y670はコピーのsub下端Y665より下で、残り秒「4」の完全bboxをキャンバス内へ収める最小限の変更として採用した。幅下限64%への変更や、コピー・ライム面・構図の変更は行っていない。
- Claude Code向け制約: `ipad-13` の一呼吸だけ `IPAD_BREATH_PHONE_VISUAL_TOP=670` を維持し、共通 `IPAD_PHONE_VISUAL_TOP=760`、フォン幅1480px、`BREATH_SOURCE_OFFSET_Y=400`、`SOURCE_PATHS`のpanel 10 `None` 2箇所、`MOCK_SOURCE_NAMES`、`source_for(panel == 10)`、`UPLOAD_ORDER`のgrayscale-home、`mock_home_grayscale()`／HOME定数、panel 10の3言語コピーは変更しない。01のコピー・背景・画面内リング／キャラを維持し、生成・upload-orderとも2064×2752 RGB・アルファなしにする。
- 検証: ja/en-US/koの残り秒「4」実画素bboxは各 `[962,2572,1104,2747]`（下端余白5px）。raw bboxからの数値写像でリング `[379.60,1141.98,1685.46,2447.64]`、キャラ `[506.69,1332.59,1557.31,2312.10]`、数字 `[961.04,2570.47,1105.08,2747.31]`を確認し、全てキャンバス内。`asc screenshots validate --device-type IPAD_PRO_3GEN_129`（ja）は8/8 ready・error/warning 0。変更SHA-256はiPad 01×3、contact sheet×3、slots×3、upload-order iPad 01×3の12件だけで、iPhone全成果物とiPad他7枚は不変。保護6群、`lint-display-copy.py` exit 0、`git diff --check`を確認した。コミットは作成していない。
- 追記（2026-08-25・追加3案）: オーナー指示で3テーマ追加し全10案体制に。**手書きノート**（罫線ノート＋手書きKlee One＋赤ペン欄外メモ）／**設計図**（青焼き製図シート＋引出線注記＋表題欄）／**レトロポップ**（70sサンバースト＋Kiwi Maru＋暖色3色）。いずれも目標主役・回数控えめルール適用。モック: `output/mockups/live-activity-themes/08-note.png / 09-blueprint.png / 10-retropop.png`。採用時は`LockTheme`に3ケース追加（パレット5色構造では表現しきれないため、テーマ別ビュー実装が前提）
- 追記（2026-08-25・**オーナー承認**）: 全10案を「OK採用」で承認。設計正本を `.claude/specs/lock-theme-redesign-v2.md` に確定し実装へ。最終構成=黒とライム(無料)/ゲーミング/朝霧/シンプルモノクロ/リキッドグラス/K-POP/かわいいピンク/手書きノート/設計図/レトロポップ。**墨と灯・森林・夜更けは削除**（保存値はgaming/monochrome/liquidGlassへマイグレーション）。フォントはDotGothic16(2.0MB)とZen Kurenaido(4.1MB)をCoreリソースへバンドル、レトロポップ・かわいいピンクはiOS同梱HiraMaruProN-W4で追加0MB（Klee One 8.3MBは容量都合で不採用）。実装=Codex Sol(L2)／レビュー=Opus5サブエージェント。

## 2026-08-25 — iPhone 6.9インチ2枚目Live Activity拡大コールアウトの中点配置

- 変更: `scripts/generate-appstore-screenshots-v2.py` の iPhone `lockscreen` 経路だけで、固定 `LOCK_CALLOUT_TOP` を削除し、時計の描画下端と実Live Activityカード枠の上端からコールアウト上端を動的に算出する式へ変更した。サイズ1180×401、角丸52px、3px枠、影、実カード枠、線幅・不透明度は維持した。3ロケールの `03-lockscreen.png`、contact sheet、slots、upload-order 02、および iPhone 6.5 upload-order 02を再派生した。
- 採用方針: コールアウト中心を `(clock_bottom_y + live_activity_top_y) / 2` に置く。生成値は時計下端Y=1365.02、実カード上端Y=2436.83、コールアウトY=1700〜2101、上余白334.98px、下余白335.83px。固定Y=1410の旧配置は時計直下へ偏り、上下余白が不均衡なため不採用。接続線は実カード上辺接線点から新コールアウト下辺接線点へ引き直した。
- Claude Code向け制約: iPadのコールアウト経路、他パネル、コピー、フォン枠取り、マスコット、`SOURCE_PATHS` panel 10の`None` 2箇所、`MOCK_SOURCE_NAMES`、`source_for` panel 10分岐、`UPLOAD_ORDER`の`grayscale-home`、`mock_home_grayscale()`／HOME定数、panel 10の3言語コピーは変更しない。iPhone 6.5はiPhone 6.9のupload-order 02を`sips -z 2778 1284`で派生し、全対象PNGはアルファなしRGBとする。
- 検証: 3ロケールともコールアウト中心と目標中点の差0.42px、上下余白差0.85px、時計・キャラクター・実カードとの重なり0。変更は許可した16個のv2成果物だけで、iPad・他パネル等の全139ファイルSHA-256を比較して不変を確認。保護6群のAST／明示チェック、`asc screenshots validate`（ja `IPHONE_69`／`IPHONE_65`各8/8、warning/error 0）、`lint-display-copy.py` exit 0、`git diff --check`を確認した。コミットは作成していない。

## 2026-08-25 — K-POP Live Activityカード単体モック
- 作成: `output/mockups/live-activity-themes/06-kpop.png`。1536×1024の横長キャンバス中央に、約78%幅（左右端x≈169/1367）、角丸約26pxの単一Live Activityカードを配置した。
- 採用方針: lavender `#E1CDF7` の背景、`#F9F6FB` のカード、pink→purple→cyanのホログラフィック枠、控えめな斜め光 streak、ピンクの「あなたの目標」pill、3つの白いticket-stub目標チップ、暗いmarquee帯を採用。3つの指定目標行を最大の視覚要素にし、回数は小さな補助テキストへ限定した。
- 却下案: iPhone筐体、手・写真表現、透かし、追加キャプション、余分なカード、大きな実績回数や目標以外の大きな数字は採用しない。
- Claude Code向け制約: 画像をWidget実装の参照やスクリーンショット内カードとして再利用する場合も、カード単体・目標主体・小さい回数・指定日本語コピーを維持する。PNGは1536×1024 RGB、カードは左右均等余白を保つ。
- 検証: `file` でPNG／1536×1024／RGB／非インターレースを確認した。

## 2026-08-25 — DopaBreak ロック画面テーマ再設計 v2 実装

- 作成・変更: `.claude/specs/lock-theme-redesign-v2.md` と `output/mockups/live-activity-themes/01〜10*.png` を正本として、`ios/WidgetsExtension/LockThemeLiveActivityView.swift` に10テーマのLive Activityカードを実装し、`DopaBreakWidgets.swift`、`SettingsLockSurfaceView.swift`、`LockScreenCheckView.swift` から同じViewを利用する構成にした。`AppModels.swift`、`SettingsStore.swift`、`LockScreenThemeDisplay.swift`、`Localizable.xcstrings`を10ケースと旧値移行へ更新した。Home WidgetとDynamic Islandのレイアウトは変更せず、全ケースのpalette参照を維持した。
- 採用方針・却下案: 全テーマで目標3件を視覚の主役にし、実績回数は下部の小さな補助表示に限定した。高さは固定160pt、目標は最大3件・1行・縮小可能として40文字超にも対応する。ゲーミングはDotGothic16、手書きノートはZen Kurenaido、かわいいピンク／レトロポップはiOS同梱HiraMaruProN-W4を採用し、容量超過するKlee Oneや実績回数の大数字レイアウトは採用しなかった。リキッドグラスはiOS 26のsystem glassを使い、それ以前は`ultraThinMaterial`へフォールバックする。
- フォント配布・制約: `DopaBreakFontResources`を専用Swift Packageリソースターゲットとして追加し、親アプリだけがリンクすることでTTF/OFLをアプリ内に1コピーだけ置く。アプリは専用bundle URLを明示してCoreTextへprocess登録し、Widget Extensionは親アプリbundleを探索して同じ実体を登録する。探索・登録に失敗した場合は必ずシステムフォントへ戻しクラッシュしない。`sumi→gaming`、`shinrin→monochrome`、`yozora→liquidGlass`、未知値→`e1`を読み出し時に正規化・永続化する。
- Claude Code向け実装制約: 生成正本は`ios/project.yml`であり、共有テーマViewと`DopaBreakFontResources`依存をここから外さない。Live Activityカードは160pt固定、目標最大3件、長文縮小を維持する。`live_activity.*`の既存確定コピー、Home Widget／Dynamic Islandの構造、無料テーマが`e1`だけというEntitlementGateの条件を変更しない。
- 検証: generic iOS deviceの全10ターゲットで`BUILD SUCCEEDED`。SimulatorのDopaBreakTestsは210件中196件成功・14件手動撮影用skip・失敗0、DopaBreakCoreは524件成功・失敗0。必須7項目（10ケース、移行、永続化、全palette、無料ゲート、Widget状態往復、全テーマ長文160pt）を自動テスト化した。最終.app内のフォントは専用bundle内のTTF 2件だけで、合計6,372,348 bytes（6.1 MiB未満）。

## 2026-08-25 — ロック画面テーマ v2 独立レビュー指摘の是正

- 変更: `ios/WidgetsExtension/LockThemeLiveActivityView.swift` で10テーマ本体を160pt最小キャンバス化し、背景より前にサイズを確定した。共通本文インセットを16ptとして枠線幅の半分を差し引く導出へ統一し、朝霧の目標は専用中央揃え、K-POPの実績帯は全幅、e1は旧2行・全周16pt・実績12pt・uppercaseを復元した。`ios/WidgetsExtension/DopaBreakWidgets.swift` はK-POP／かわいいピンクのActivity tintだけ実カード色へ合わせた。
- データ・文言・性能: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Models/AppModels.swift` の`WidgetSnapshot`復元を旧テーマ移行対応にし、`ios/DopaBreak/Localizable.xcstrings`へ確定済みLive Activityコピーをja/en/koで追加した。`BundledFontRegistrar.swift`は既定探索の失敗もキャッシュし、カスタムフォント成功時にも指定weightを適用する。フォントのresources配線と登録経路は変更していない。
- 採用方針・却下案: 外側の固定160ptだけでサイズテストを通す案はレターボックスを検知できないため却下し、`isMeasuring`で外側frame/clippedを除いたテーマ本体を測る構造を採用した。各テーマ本体が156〜160pt、160pt超過なしであることを要求し、四辺の実ピクセル描画も検証する。e1は1〜2件時の旧間隔を維持し、3件時だけ負の小間隔と詰めた2行leadingで160ptへ収める。
- Claude Code向け制約: 各テーマ固有の`.frame(minHeight: LockThemeLiveActivityView.maximumHeight)`を背景より外へ移動・削除しない。本文インセットは`cardInset`と`contentInset(borderWidth:)`から導出し、note左46ptだけを例外とする。`isMeasuring`経路へ固定heightやclipを足さず、e1の`lineLimit(2)`、asagiri中央揃え、K-POP全幅帯を維持する。
- 検証: DopaBreakCore 525件・失敗0、DopaBreakTests 215件（14 skip）・失敗0。monochromeのminHeightを一時削除すると137pt・23pt letterboxとしてM2テストが失敗し、復元後は全10テーマの高さ・四辺ピクセル検査が成功した。generic iOSビルドは7依存ターゲットすべて`BUILD SUCCEEDED`。生成.app内TTFはDotGothic16.ttf 1件・ZenKurenaido.ttf 1件、PlugIns内0件。

## 2026-08-25 — ロック画面テーマ v2 第2独立レビュー指摘 R1〜R7 の是正

- 作成・変更: `ios/WidgetsExtension/LockThemeLiveActivityView.swift` のe1を正のVStack間隔・正のlineSpacing・3件時25pt行枠＋縮小へ直し、1〜3件の短文／長文で行、区切り線、実績行が交差しない構成にした。全テーマの外側水平paddingを16ptへ統一し、note左46ptだけを維持した。朝霧の実績数字だけ17pt medium＋青、K-POPのticket notch、かわいいピンクの吹き出しtailを実装した。`DopaBreakWidgets.swift`ではe1と朝霧のActivity tintを実カード背景へ合わせた。
- 配線・設定: `ios/DopaBreak/GoalsView.swift` と `GoalEditorSheet.swift` は`model.lockSurfaceState.theme`をプレビューへ渡す。`SettingsStore.lockTheme` getterからUserDefaults書き込みを除去し、`migrateStoredValues()`を`AppModel`初期化時に明示的に呼ぶ一度きりの正規化へ移した。getter内正規化は読み取りスレッドから副作用が出るため却下し、paletteの恒真テストは全10件の承認RGB完全一致へ置換、旧値テストの重複も整理した。
- テスト・制約: `ios/DopaBreakTests/LockThemeLiveActivityViewTests.swift` は393×160の実ウィンドウ描画からcontent／e1各行／divider／summaryの座標を取得し、全テーマ16pt（note左46pt）とe1の正の隙間を検証する。負の`-2 / 0 / -9`へ一時復帰すると新規長文3件テストが0pt gapで失敗し、復元後は対象6件成功。今後もe1の`lineLimit(2)`、水平16pt、実績12pt、uppercase、全テーマ160pt本体と四辺描画、K-POP全幅marquee、note左46ptを維持する。
- 検証: generic iOS Simulator向け7依存ターゲットbuildは成功。DopaBreakCoreは525件・失敗0、iOSは217件中203件成功・手動撮影14件skip・失敗0。全10テーマの160pt上限／四辺描画／水平content位置をレンダリング検証した。最終`DopaBreak.app`直下はDotGothic16.ttfとZenKurenaido.ttfが各1コピー、`PlugIns`内フォント0件。

## 2026-08-26 — ロック画面テーマ v2 最終クリーンアップ

- 作成・変更: `ios/DopaBreakTests/LockThemeLiveActivityViewTests.swift` に `AppModel` 初期化時の保存テーマ移行配線テストと、e1目標文字の可視インク高10pt下限テストを追加し、描画ヘルパーを `.ignoresSafeArea()` へ統一した。`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/{Models/AppModels.swift,Storage/SettingsStore.swift}` は死んだ日本語 `displayName` を削除し、保存済み文字列 `e1` もnilへ正規化する。`ios/DopaBreak/LockScreenCheckView.swift` はテーマ引数を必須化し、`Localizable.xcstrings` から参照ゼロのpreview 3キーを削除した。`.claude/specs/lock-theme-redesign-v2.md` §3.1へe1の1〜2件／3件リズムと393:160の根拠を追記した。
- デザイン判断: `ios/WidgetsExtension/LockThemeLiveActivityView.swift` のLiquid Glass実績カプセルは各テキストの内容幅へ戻し、noteの76×17ptテープは回転後も上端を欠かないy=1へ移した。Apple系UIの階層・可読性・クラフト原則に従い、カード半幅へ伸ばす案と装飾を意図的に切る案は却下した。R1〜R7、フォント配線、Proゲート、Home Widget、Dynamic Island、全テーマ水平16pt（note左46pt例外）は変更していない。
- 変異・回帰検証: `AppContainer.swift` の `migrateStoredValues()` 呼び出しを一時削除すると新規配線テストが `sumi` 残存で1件失敗し、e1密レイアウト行高を25ptから12ptへ一時変更すると可視インクが8ptとなり下限10ptテストが1件失敗した。双方を復元後、iOS SimulatorでDopaBreakTests 219件（14 skip）・失敗0、DopaBreakCore 526件・失敗0。generic iOS Simulatorの7依存ターゲットは`BUILD SUCCEEDED`。全10テーマの160pt四辺描画／水平content位置テストも成功し、生成`DopaBreak.app`直下のDotGothic16.ttf／ZenKurenaido.ttfは各1コピー、`PlugIns`内0コピー。
- Claude Code向け制約: `AppModel`初期化の明示移行呼び出し、e1の3件時25pt行高と可視インク10pt以上、描画ヘルパーのsafe-area無視を維持する。テーマ名はアプリ層の`localizedDisplayName`だけを使い、Coreへ日本語表示名やプレビューtheme既定値を戻さない。Liquid Glassカプセルへ`maxWidth: .infinity`を戻さず、noteテープをカード外へ負方向offsetしない。
- 追記（2026-08-26・**Fable受け入れ**）: ロック画面テーマ再設計v2の実装を受け入れた。Codex実装→Opus5独立レビュー3周（1回目12件差し戻し／2回目R1〜R7差し戻し／3回目受け入れ可）→最終クリーンアップ。独立検証で iOS 219件（14 skip）・Core 526件が失敗0、フォントはアプリ直下に各1コピー・Extension内0コピー。残るはオーナーの実機確認（10テーマ切替表示／無料アカウントで9テーマがロックされること）。
  - **この作業で得た再発防止**: ①「数値だけ満たして中身が壊れる」事故が2回発生した（e1を負の行間で押し潰して高さテストを通す等）。テストは意図的に壊して落ちることを毎回確認する ②DerivedDataは名前で当たりを付けず更新時刻で最新を特定する（古い成果物を見てフォント欠陥を誤報した） ③e1の密レイアウトは設計正本 §3.1 に明文化済み。善意で「§3.1どおりに復元」するとR1が再発するため触らないこと

## 2026-08-26 — ロック画面テーマの英語表示修正と3ロケール描画回帰

- 作成・変更: `ios/WidgetsExtension/LockThemeLiveActivityView.swift` はblueprint表題欄の外寸285ptを維持したまま左セルを174ptへ配分し、両セルへ水平6ptの内側余白を追加した。noteの英語実績行はZen Kurenaidoを維持し、`×`だけを9.5ptのrounded systemへフォールバックして0.4pt基線補正した。テスト用にBundleとLocaleを注入できるローカライズ経路と、カード・本文・blueprintセル／文字の描画座標アンカーを追加した。`ios/DopaBreakTests/LockThemeLiveActivityViewTests.swift` は10テーマ×ja/en/ko×実運用3段階の90枚を393×160で描画し、切り詰め相当の幅不足、カード境界超過、高さを検査する。blueprint/enの枠線・仕切り線から4pt以上の余白と、note/enの実画像も個別検査・添付する。
- 採用方針・却下案: blueprint全体の拡幅やフォント縮小は既存構図とja/koの見た目を変えるため却下し、セル配分と内側余白だけを変更した。note実績行全体をsystem fontへ替える案は手書き感を失うため却下し、問題のあるU+00D7だけを局所調整した。`Localizable.xcstrings`の確定文言は変更していない。
- Claude Code向け制約: blueprintの表題欄は全幅285pt、左セル174pt、各セル水平6ptを維持する。noteの実績行は`×`以外をZen Kurenaidoのままにする。ロケール試験は`-testLanguage`へ依存させず、ja/en/ko各`.lproj`のBundleとLocaleを明示注入する。全10テーマの高さ160pt、四辺描画、水平16pt（note左46pt例外）を維持し、Home WidgetとDynamic Islandには波及させない。
- 変異・実測検証: blueprintのセル内paddingを一時的に戻すと英語表題・実績の左右4箇所が実測0ptとなり、新規回帰テストが4 assertionで失敗した。復元後、393×160の実描画でblueprint/enは左右6pt、note/enの`×`は周囲の小文字に釣り合うことを画像確認し、90枚すべて高さ160pt・カード境界内・実運用目標幅内だった。iOSは222件（14 skip）・失敗0、DopaBreakCoreは526件・失敗0、generic iOS Simulator向け7依存ターゲットは`BUILD SUCCEEDED`。既存の10テーマ四辺描画と水平padding検査も成功した。

## 2026-08-26 — ゲーミング／手書きノートの韓国語専用書体

- 作成・変更: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/BundledFontRegistrar.swift` にGalmuri11（`Galmuri11-Regular`）とNanum Pen Script（`NanumPen-Regular`）を追加し、`ios/project.yml`／生成Xcode projectの親アプリresources phaseへ2フォントを追加した。`ios/WidgetsExtension/LockThemeLiveActivityView.swift` は表示`Locale`のlanguage codeが`ko`なら、ゲーミングの全テキストをGalmuri11、noteの全テキストをNanum Pen Scriptへ切り替える。`ios/DopaBreak/SettingsAboutView.swift` のOFL表示を4フォントへ更新し、`BundledFontIntegrationTests.swift`、`LockThemeLiveActivityViewTests.swift`、Coreの`LockThemeV2Tests.swift`を拡張した。
- 採用方針・却下案: 文字列のハングル有無で部分置換する案は、韓国語UIで日本語目標を書く場合に選択が揺れ、Latin・数字との混植も残すため却下した。表示ロケールだけで行全体の書体を決め、韓国語noteでは既存の英語`×`局所補正を通さない。ja/enはDotGothic16／Zen Kurenaidoと英語noteの`×`補正を維持する。登録・親アプリ探索に失敗した場合は既存`registeredName == nil`経路からsystem fontへ戻す。
- Claude Code向け制約: 4つのTTFは親`DopaBreak.app`直下だけに1コピーずつ置き、Widget resourcesへ追加しない。書体選択は`LockThemeFontPolicy`を唯一の表示ロケール判定点とし、目標タイトルの文字種判定を追加しない。10テーマの160pt本体、全周描画、水平16pt（note左46pt例外）、blueprint/en内側余白、note/enの`×`補正、既存90描画テスト、Home Widget／Dynamic Islandは維持する。
- 変異・実測検証: 韓国語ゲーミングを一時的にDotGothic16へ戻すと選択テストとCoreText runテストが3 assertionで失敗し、`DotGothic16-Regular`＋`AppleSDGothicNeo-Regular`の混在を検出した。復元後、韓国語のgaming/noteを各393×160で実描画して目視し、CoreTextで「30분 독서하기 × 15」の全runがそれぞれGalmuri11／NanumPenだけであることを確認した。iOSは225件（14 skip）・失敗0、Coreは526件・失敗0、generic iOS Simulatorの7依存ターゲットは`BUILD SUCCEEDED`。生成app直下TTFは4件、Widget内0件、合計14,950,440 bytes（14.257851 MiB）。既存の10テーマ四辺描画・水平padding・90描画テストも成功した。

## 2026-08-26 — ロック画面テーマピッカーのオンボ・設定・ホーム導線

- 作成・変更: `ios/DopaBreak/LockThemePickerView.swift` に393×160固定キャンバスを等比縮小する10テーマ共通ピッカーと単体カードを追加した。`OnboardingFlow.swift` は `lockScreenCheck` と `prePaywallSummary` の間へ17番目の `lockThemePick` を追加し、保存・テーマ別計測・Pro注記・ペイウォール直前の選択カード再掲を実装した。`SettingsLockSurfaceView.swift` はチップ列と単独プレビューを共通ピッカーへ置換し、`HomeView.swift` はLive Activity有効時だけ目標カード直後に実掲出テーマの入口と明示的に閉じられる選択シートを追加した。`PaywallView.swift`、`Localizable.xcstrings`、`MeasurementFoundationTests.swift` も導線別placement、ja/en/ko文言、§6回帰へ更新した。
- 採用方針・却下案: 10テーマの意匠を暗転・ぼかしなしで比較できる縦1列、332pt viewport（393pt幅でちょうど2枚、狭幅では2枚超が見える）、選択枠＋チェック、未解放時だけProバッジを採用した。保存値を実掲出値へ上書きする案、オンボで未解放テーマを即ペイウォールへ送る案、設定とホームで別実装にする案は、意思保持・設計正本・一貫性に反するため却下した。Apple HIGに従い行全体を44pt以上のタップ領域とし、ホームsheetには明示的な閉じる操作を置いた。
- Claude Code向け制約: `LockThemePickerView` のAPI、`LockTheme.allCases`順、393×160の内部固定キャンバス、332pt viewport、未解放カードを隠さない仕様を維持する。オンボでは保存値をそのまま選べるが、実掲出は既存 `AppModel.lockSurfaceState` の権利ガードを必ず通す。設定の選択枠とオンボ／ホームの選択状態は非Observableな`SettingsStore`だけへ依存せずSwiftUI Stateにも同期する。ホームカードは `settingsStore.liveActivityEnabled` がfalseなら非表示、プレビューthemeは保存値でなく `model.lockSurfaceState.theme`、未解放タップは設定=`settings_theme_gate`／ホーム=`home_theme_gate`とする。
- 検証: `xcodegen generate --spec project.yml`、generic iOS 7依存ターゲット `BUILD SUCCEEDED`、DopaBreakCore 526件失敗0、DopaBreakTests 230件中14件手動撮影skip・失敗0、最終差分後のMeasurementFoundationTests 19件失敗0。`OnboardingMotionCapture`は実行を含め成功。`scripts/lint-display-copy.py` と `scripts/audit-default-values.py` はexit 0、`git diff --check`もexit 0。`AppContainer.lockSurfaceState`、`EntitlementGate.lockThemeAllowed`、`LockThemeLiveActivityView`、`live_activity.*`、Home Widget、Dynamic Islandは変更していない。

## 2026-08-26 — ロック画面テーマピッカー独立レビュー F1〜F8 是正

- 作成・変更: `ios/DopaBreak/SettingsLockSurfaceView.swift` は選択枠とPro注記を `SettingsStore.lockTheme` の保存値から駆動し、親の `selectedLockTheme` は実掲出テーマの行ラベル用途を維持した。`ios/DopaBreak/OnboardingFlow.swift` はテーマ選択画面とペイウォール直前の注記だけを権利判定へ切り替えた。`ios/DopaBreak/LockThemePickerView.swift` は固定332ptの内側ScrollViewを廃止して `LazyVStack` だけを返し、幅393pt上限を比率計算の外側へ置いて700pt幅でも行高160ptに収め、未解放カードのVoiceOverラベルへPro状態を加えた。`ios/DopaBreak/HomeView.swift` はlarge sheet全体をScrollView化し、保存済み未解放テーマの注記を追加した。
- 採用方針・却下案: スクロール所有者はオンボ／設定の既存画面ScrollViewとホームsheetへ一本化し、各テーマ変更では `refreshLockSurfaces(scheduleNotifications: false)` を使う。保存値をガード後の `.e1` へ置換する案、Proユーザーにもアップセル注記を残す案、393×160カードの周囲へiPad用レターボックスを残す案は、意思保持・事実性・実描画寸法に反するため却下した。`confirmLockThemeAndAdvance()` の2件計測は正本 §2.4どおりコードを変えず、`.claude/specs/lock-theme-picker-onboarding.md` に集計上の注記だけを追加した。
- テスト・Claude Code向け制約: `ios/DopaBreakTests/MeasurementFoundationTests.swift` は設定／ホームそれぞれの画面選択ハンドラ、free＋保存済みProの設定表示、Proオンボの2注記非表示、700pt実ウィンドウで393×160になる行箱を固定した。今後も `LockThemePickerView` 自体へScrollViewや固定viewportを戻さず、設定のピッカー選択は保存値、設定親行とホームカードの実掲出表示は `model.lockSurfaceState.theme` を使い分ける。テーマだけの変更で通知再スケジュールを有効化しない。
- 検証: `xcodegen generate --spec project.yml`、generic iOS Simulatorの7依存ターゲット `BUILD SUCCEEDED`。DopaBreakCore 526件失敗0、DopaBreakTests 233件中14件手動撮影skip・失敗0（`OnboardingMotionCapture`実行成功）、幅700pt回帰を含むMeasurementFoundationTests 22件失敗0。`scripts/lint-display-copy.py` と `scripts/audit-default-values.py` はexit 0、`git diff --check`もexit 0。`AppContainer.lockSurfaceState`、`EntitlementGate.lockThemeAllowed`、`LockThemeLiveActivityView`、`live_activity.*`、Home Widget、Dynamic Islandは変更していない。

## 2026-08-26 — ロック画面テーマピッカー第2独立レビュー ND-1／ND-1b／ND-2／ND-4 是正

- 作成・変更: `ios/DopaBreak/SettingsLockSurfaceView.swift` は保存テーマを初期値に持つ `@State savedLockTheme` を追加し、設定ピッカーの選択枠とPro注記をそのStateから描画する。許可済みテーマの選択時はState・親Binding・`SettingsStore`を同時更新する。「ロック画面で確かめる」とLive Activityトグルはピッカーより上へ移した。`ios/DopaBreak/LockThemePickerView.swift` は44pt最小高と`contentShape`をButton label内へ移し、実描画テスト用の選択テーマ通知を追加した。`ios/DopaBreakTests/MeasurementFoundationTests.swift` は恒等関数テストを廃止し、`UIHostingController`で設定画面を描画してfree＋保存`.kpop`の選択表示と、ガード後Bindingが`.e1`のまま`.e1`を選ぶ同値書き込み後の追随を検証する。
- 採用方針・却下案: 非Observableな`SettingsStore`を`body`で直接読む案は同値Binding書き込み時に再描画されないため却下し、Homeと同じ保存値State同期を採用した。恒等ヘルパーや権利判定だけの単体テストは表示回帰を検知できないため廃止し、実ビューで選択カードが描画された事実を待つ方式にした。ピッカーを機能トグルより先に置く構成は主要操作を約1,600pt下へ埋めるため、論理順も含めて操作行を先頭へ戻した。
- Claude Code向け制約: `savedLockTheme`をガード後の`selectedLockTheme`へ置換せず、許可済み選択時のState更新を削除しない。`AppContainer.lockSurfaceState`の権利ガード、`EntitlementGate.lockThemeAllowed`、F2〜F8は変更していない。特に`LockThemePreviewCard`末尾の`.aspectRatio(393 / 160, contentMode: .fit)`→`.frame(maxWidth: 393)`順序を維持する。テスト用通知は既定nilで、本番の選択挙動を変更しない。
- 検証: 新規UIHostingControllerテストは正常実装で成功し、`savedLockTheme = allowedTheme`を一時削除すると失敗することを確認後に復元した。DopaBreakTestsは233件中219件成功・14件skip・失敗0、DopaBreakCoreは526件失敗0。generic iOS Simulatorの7ターゲットは`BUILD SUCCEEDED`、`scripts/lint-display-copy.py`、`scripts/audit-default-values.py`、`git diff --check`はexit 0。

## 2026-08-26 — ロック済みテーマの購入待ち選択を保存（ND-5）

- 作成・変更: `ios/DopaBreak/SettingsLockSurfaceView.swift` と `ios/DopaBreak/HomeView.swift` のテーマ選択ハンドラを、許可判定より先に選択コールバックを必ず実行する構造へ変更した。無料ユーザーのProテーマ選択でも表示用State、`SettingsStore.lockTheme`、`refreshLockSurfaces(scheduleNotifications: false)`を更新し、その後だけ設定=`settingsThemeGate`／ホーム=`homeThemeGate`を提示する。`ios/DopaBreakTests/MeasurementFoundationTests.swift`へ設計正本の5経路をハンドラ実挙動で検証するテストを追加した。
- 採用方針・却下案: 新しい保留フィールドやフラグは作らず、保存値と描画直前の既存権利ガードを分離する二層構造を採用した。ロック済み選択を捨てる案、ペイウォール提示後に保存する案、無料ユーザー向け描画ガードを緩める案は、購入後の選び直し、遷移中の保存欠落、権利漏れを生むため却下した。Apple系UIの即時応答と既存のシート遷移を維持し、外観やモーションは変更していない。
- Claude Code向け制約: 両ハンドラの順序は必ず`onSelect`→未解放判定→`onLocked`とする。ホームは`onLocked`内でピッカーを閉じてから既存のonDismiss経路でペイウォールへ進む。`AppContainer.lockSurfaceState`、`EntitlementGate.lockThemeAllowed`、`LockThemeLiveActivityView`、`LockThemePreviewCard`の`.aspectRatio`→`.frame(maxWidth: 393)`順序には触れていないため今後も維持する。
- 検証: 追加5経路を含むMeasurementFoundationTests 26件失敗0。DopaBreakCore 526件失敗0、DopaBreakTests 237件中14件手動撮影skip・失敗0、generic iOS Simulatorの7依存ターゲットは`BUILD SUCCEEDED`。`scripts/lint-display-copy.py`と`scripts/audit-default-values.py`、`git diff --check`はexit 0。

## 2026-08-26 — 設定ロックテーマ行の実掲出セマンティクス修正

- 作成・変更: `ios/DopaBreak/SettingsLockSurfaceView.swift` のテーマ選択処理で、保存値更新と `refreshLockSurfaces(scheduleNotifications: false)` の後に、親の `selectedLockTheme` へ権利ガード後の `model.lockSurfaceState.theme` を代入するよう修正した。`ios/DopaBreakTests/MeasurementFoundationTests.swift` は設定画面を `UIHostingController` で描画し、本番の `selectTheme` ハンドラを通してfree／Proの親Binding、選択カード描画、保存値、ペイウォールを観測する回帰テストへ更新した。
- 採用方針・却下案: Apple系UIの予測可能性と即時応答を保つため、`savedLockTheme` と `SettingsStore.lockTheme` はユーザーが押した保存テーマ、設定親行のBindingは実機に出るガード後テーマという二層の意味を維持した。生の選択値を親行へ渡す案、保存済みProテーマを `.e1` へ戻す案、恒等関数だけを試験する案は、実機との表示不一致・購入待ち選択の喪失・ハンドラ配線の未検証を招くため却下した。
- Claude Code向け制約: 選択処理は `savedLockTheme` 更新／`SettingsStore.lockTheme` 保存／`refreshLockSurfaces(scheduleNotifications: false)`／親Bindingへ `model.lockSurfaceState.theme` 反映の順を維持し、その後に既存ハンドラが `.settingsThemeGate` を提示する。Home側、`AppContainer.lockSurfaceState`、`EntitlementGate.lockThemeAllowed`、`LockThemePreviewCard` の `.aspectRatio`→`.frame(maxWidth: 393)` は変更していない。
- 検証: 実ビューハンドラを通るfree／Pro回帰を含むMeasurementFoundationTests 27件失敗0。DopaBreakTests 238件中14件手動撮影skip・失敗0、DopaBreakCore 526件失敗0、generic iOS Simulatorの7依存ターゲットは `BUILD SUCCEEDED`。`scripts/lint-display-copy.py` と `scripts/audit-default-values.py`、`git diff --check` はexit 0。

## 2026-08-28 — ペイウォールCTAのゼロ価格化「7日間無料で始める」→「7日間 ¥0で始める」（オーナー承認「例外を認める」）
- 経緯: 8/18のカード側ゼロ価格採用時、CTAは「CTAに金額禁止」（7/28恒久指示）で除外していた。オーナーが「ボタンに出さないと効果なくない？」と指摘 → `/brainstorm`（議事録 `.claude/brainstorm/2026-08-28_paywall-cta-zero-price.md`）で行動経済学・心理学から検証
- 判断根拠: ゼロ価格効果（Shampanier, Mazar & Ariely 2007）は感情由来で強いが「free vs $0」の語の差の実証は無い。効き所は単独効果より **カード「¥0」→ボタン「無料」の枠組みの切替を無くす一貫性**（説得知識モデル）。コストゼロ・可逆・法務低リスク。元ネタ（X・+35%）は根拠にしない。期待は1桁%（未確認の推定）
- ルール改定: CLAUDE.md「CTAに金額を入れない」へ **例外: ゼロ価格のトライアル訴求のみ可** を追記（グローバル）。通貨リテラル禁止・適格時のみ表示は不変
- 実装方針: 新キー `paywall.action.start_zero_price`（位置指定子必須 %1$@=期間・%2$@=ゼロ価格）。ゼロ価格が組めない時は既存 `paywall.action.start_free` へフォールバック。法定行・カード・リマインダー・適格false時の文言は不変。ボタンに入れる数字は¥0の1つだけ（¥4,980を併記しない）
- 差し替え候補（未採用）: 「今日は ¥0で始める」（現在バイアス直撃）。リリース後の前後比較で検討
- 検証: リリース後 `paywall_shown`→`trial_or_purchase_started` の前後比較（表示1,000件まで）。悪化なら3キーを戻す

## 2026-08-28 — ホーム目標カードの複数表示と目標タブ導線

- 作成・変更: `ios/DopaBreak/HomeView.swift` の `goalCard` を全目標行表示へ変更し、ヘッダーへ44pt以上の「追加」「編集」を追加した。`ios/DopaBreak/RootTabView.swift` と `ios/DopaBreak/GoalsView.swift` はUUIDリクエストで目標タブ切替後の追加シートを次runloopに提示する。`ios/DopaBreak/Localizable.xcstrings` は新規2キーと、無制限方針へ合わせた `onboarding.goal.multi_note` のja/en/koを更新した。`ios/DopaBreakTests/HomeGoalsCopyTests.swift` を新設し、3言語のtranslated状態と上限表現不在を固定した。
- 採用方針・却下案: ホームではロック画面バッジを付けず、カテゴリ32pt＋17pt semiboldの簡潔な行へ統一した。カード全体を単一ボタンにする案は追加・編集・各行の操作が競合するため却下し、独立ボタンに分けた。追加シートをタブ切替と同フレームで出す案は表示競合を避けるため却下し、`DispatchQueue.main.async` で次runloopへ送った。Apple HIGの44ptタップ領域と、既存システムTabViewの階層を維持した。
- Claude Code向け制約: `HomeView.swift` の別セッション差分であるロック画面カード群と `OnboardingFlow.swift` は変更していない。ホーム行タップはその目標の `GoalEditorRoute`、空状態と「追加」は目標タブの新規 `GoalEditorRoute`、「編集」は目標タブ一覧だけを開く。`goals.badge.on_lock_screen` をホームへ追加せず、先頭3件だけに限定する表示分岐も作らない。監査は変更禁止のオンボーディングdefaultValueとカタログ正本の意図的差だけを `scripts/audit-default-values.py` の完全一致例外として扱う。
- 検証: `xcodegen generate` 成功。指定iPhone 16 Pro向け `xcodebuild test` は244件中14件skip・失敗0で `TEST SUCCEEDED`。`scripts/lint-display-copy.py` と `scripts/audit-default-values.py` はexit 0、JSON解析と `git diff --check` も成功した。目標3件を投入したiPhone 16 Proシミュレータのホームを `xcrun simctl` で `output/verify/home-goals-multi.png` に保存した。

## 2026-08-28 — ホーム目標カード／追加シートの実機検証キャプチャ

- 作成: 既存の3目標を保持した iOS 26.5 iPhone 16 Pro Simulator（`D8BEFB03-D0AF-4BE2-807A-69DAEC878E4A`）で、底部までスクロールしたHomeの `output/verify/home-goals-card.png` と、Homeの「追加」からGoalsタブへ遷移して追加シートを開いた `output/verify/home-goals-add-sheet.png` を `xcrun simctl io ... screenshot` で保存した。
- 採用方針・却下案: 既存の実アプリ状態をAXeで操作し、Homeはスクロールバー100%を確認、追加導線はラベル「追加」を直接タップして次runloop後に撮影した。再ビルド・再シード・画像合成は、実際の導線と表示状態の検証にならないため行っていない。
- Claude Code向け制約: 2枚とも実機UIの原寸（1206×2622）を維持する。Home画像は「あなたの目標」見出し、「追加」「編集」ボタン、3目標行、Home選択状態を完全表示し、追加シート画像はGoals選択状態と「目標を追加」シートを表示する。アプリ本体のUI・ローカライズ・シードデータは変更していない。

## 2026-08-28 — ホーム目標複数表示レビュー指摘の是正

- 作成・変更: `ios/DopaBreak/HomeView.swift` の目標ヘッダーボタンframeをラベル内へ移し、目標行と空状態を含むラベルへ矩形ヒット領域を追加した。`ios/DopaBreak/RootTabView.swift` から `ios/DopaBreak/GoalsView.swift` へ追加要求をBindingで渡し、未訪問タブの初回表示でも次runloopに追加sheetを提示してトークンをnilへ戻す。`ios/DopaBreak/OnboardingFlow.swift` の `onboarding.goal.multi_note` defaultValueをカタログへ一致させ、`scripts/audit-default-values.py` の例外処理を撤回した。`ios/DopaBreakTests/GoalsAddRequestTests.swift` を新設した。
- 採用方針・却下案: UUIDの同一性を純関数 `GoalsAddRequestPolicy.shouldPresent` で判定し、`onAppear` と `onChange` の両経路を同じ消費処理へ集約した。タブ未訪問時に `onChange` だけへ依存する案は初回要求を落とすため却下し、sheet提示を同期実行する案はタブ遷移との競合を避けるため採用しなかった。44pt frameはButton外側ではなくラベルへ置き、SpacerとCardContainerのpaddingを含む描画領域をヒット対象にした。
- Claude Code向け制約: `goalsAddRequest` は `Binding<UUID?>` のまま渡し、提示成功時にnilへ戻す。`consumedAddRequest` と次runloop提示、`editorRoute == nil` ガードを外さない。Homeの各目標行・空状態・ヘッダー操作とGoalsの各カード・空状態では `.contentShape(Rectangle())` を維持する。オンボーディング変更は `onboarding.goal.multi_note` のdefaultValue 1行だけで、並走中のロックテーマ変更を差し戻さない。
- 検証: `xcodegen generate` 成功。iPhone 16 Pro向け全体 `xcodebuild test` は再試行有効・並列無効で251件中14件skip・失敗0、`TEST SUCCEEDED`。`git diff --check` はexit 0。defaultValue監査と表示コピーlintは並走中のローカライズ変更が未同期のため、この時点ではそれぞれ176件の不一致／4件の要確認でexit 1。

## 2026-08-28 — アプリごと設定は不採用／利用時間の通知機能は廃止（オーナー決定）
- **アプリごとの制限分け（案1・統合）は不採用**。理由: ユーザーのJTBDは「SNS全体から距離を置く」で、アプリ別の細粒度設定は決断疲労を増やし離脱要因になる。競合(one sec/Opal)も一括設定が主。将来ヘビーユーザーの実需が出たら足す(YAGNI)。ホームの「止めているアプリ」導線はアプリ別詳細へは進めない
- **利用時間の通知機能（UsageWatch＝「利用時間の通知」）を廃止**。理由: iOSのDeviceActivityは「今アプリを開いているか」をリアルタイム判定できず（閾値到達コールバックのみ・前面/背面状態は取得不可）、連続判定ギャップ20分のため、一度開いて閉じた後にも累計閾値をまたいで通知が飛ぶ。開いているか確認できないまま通知を出すのは逆効果、というオーナー判断
  - 影響: Proの売り文句「アプリごとの問いかけ間隔(15/30/60分)」が消える → ペイウォール/ASO/価値訴求の見直しが必要。MonitorExtensionのDeviceActivity監視のうちUsageWatch分のみ除去し、deepFocus/nightOnlyのシールド再適用callbackは残す

## 2026-08-28 — ショートカットのアプリ引数省略時の自動解決

- 作成・変更: `ios/DopaBreak/StartInterventionIntent.swift` と `ios/DopaBreak/AppContainer.swift` に省略可能パラメータと一回限りの自動解決要求を実装し、`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/InterventionTargetResolutionPolicy.swift` に明示指定／0件／1件／複数件の純関数ポリシーを追加した。`ios/DopaBreak/InterventionFlowView.swift` は複数候補時だけ既存フローの前に選択画面を表示し、`ios/DopaBreak/Localizable.xcstrings` の指定3キーをja/en/koで整備した。Coreとアプリ統合テストも追加した。
- 採用方針・却下案: 明示指定を常に優先し、省略時は保存順を維持して1件なら即時確定、複数件だけ60pt高の選択カードを出す。保護対象の `RootTabView.swift` にある網羅switchを変更できないため、列挙ケース追加案は却下し、既存 `.catalog` を通る互換コンストラクタ `.catalogChoice(ids)` と内部マーカーで選択状態を運ぶ構成を採用した。Freeの1件選択では確認画面を出さず、未知の明示IDは別アプリへ置換せず無視する。
- Claude Code向け制約: `dopabreak.catalog-choice:` マーカーと候補の保存順、候補2件以上だけを選択画面として扱う条件を維持する。選択後は実在する `.catalog(target)` の新しいフローモデルへ置換して通常フローを開始する。URL経路と `.gateToken`、および `HomeView.swift`、`PaywallView.swift`、`OnboardingFlow.swift`、`SettingsLockSurfaceView.swift`、`GoalsView.swift`、`RootTabView.swift` は本変更の対象外。
- 検証: DopaBreakCore 531件失敗0。iPhone 16 ProのDopaBreakTestsは251件中14件skip・失敗0で `TEST SUCCEEDED`。`xcodegen generate`、表示コピーlint、defaultValue監査、String Catalog JSON解析、`git diff --check` は成功した。

## 2026-08-28 — 日本語UIコピーの全画面精査

- 作成・変更: `ios/DopaBreak/Localizable.xcstrings`、`ios/MonitorExtension/Localizable.xcstrings`、`ios/ShieldActionExtension/Localizable.xcstrings`、`ios/ShieldConfigExtension/Localizable.xcstrings`、`ios/WidgetsExtension/Localizable.xcstrings` の日本語を全件精査し、ホーム、オンボーディング、一呼吸フロー、目標、統計、設定、ペイウォール、通知、シールド、ウィジェットの不自然な文言を改稿した。対応する `ios/**/*.swift` の `defaultValue` もカタログ正本へ同期し、`docs/11_ui_copy.md` §21と`docs/CHANGELOG.md`に方針を記録した。
- 採用方針・却下案: 説明文は「操作・次に起きること・結果」が一読で分かる自然な文章とし、見出しとCTAは短く保った。対象不明な「動く／出る」、機能名だけの列挙、意味を補えない体言止め、利用者を責める表現は却下した。「開く前に一呼吸をはさむ」「一呼吸の画面が表示される」「決めた時間はアプリを開けない」へ具体化し、計測は観測可能な「開かなかった」「SNSを開かずに取り戻した時間」で統一した。画面構成、コンポーネント、余白、モーションは変更していない。
- Claude Code向け制約: 日本語の表示正本は各 `Localizable.xcstrings` とし、変更時は同じキーを使うSwiftの `defaultValue` も必ず同期する。位置指定子、改行、キー名を維持し、廃止語彙「戻る先／戻れた／監視」や曖昧な「一呼吸が動く／画面が出る」を戻さない。英語・韓国語は今回の全面改稿対象外で、既存の確定訳を維持する。
- 検証: 5カタログ計710キーをJSON解析し、表示コピーlintは廃止語彙0件・意図した読点3件のみ、Swift `defaultValue` 監査は795呼び出しで不一致／欠落／未解決／型不一致0件、`git diff --check`はexit 0。generic iOS Simulator向け7依存ターゲットは`BUILD SUCCEEDED`。手動ホールド用の撮影2テストを除外したDopaBreakTestsは249件中14件skip・失敗0で`TEST SUCCEEDED`。除外前の全実行ではその2テストだけがテストタイムアウトで失敗し、通常テストの失敗はなかった。

### 2026-08-28 追記 — ホーム目標複数表示レビュー是正の最終検証

- 並走側のローカライズ同期後、未使用のiPhone 16 Pro（iOS 26.2）で全体251件中14件skip・失敗0、`TEST SUCCEEDED`。`scripts/lint-display-copy.py` と `git diff --check` はexit 0、`scripts/audit-default-values.py` 本体はHEAD完全一致で例外なし。並走側が `onboarding.goal.multi_note` のカタログ正本を別文言へ変更したため、spec指定のdefaultValue「目標は複数追加できます」を保持するとdefaultValue監査だけ当該1件でexit 1になる。

## 2026-08-28 — 一呼吸フロー S-02/S-03 統合

- 作成・変更: `ios/DopaBreak/InterventionFlowView.swift` と `ios/DopaBreak/InterventionFlowModel.swift` で利用状況と目標確認を1画面へ統合し、当日試行回数・開かなかった回数・全目標・44pt以上の編集／設定導線・「次へ」を実装した。`ios/DopaBreak/Localizable.xcstrings` にja/en/koコピーを追加し、`GoalEditorSheet` を既存構成のまま再利用した。Coreの独立した `goalReminder` 状態を削除し、テストと `output/verify/intervention-merged.png` を追加した。
- 採用方針・却下案: 既存フローはS-04理由選択を先に行い、直接理由は時間選択へ、内省理由は呼吸と統合画面を経て判断へ進むため、この分岐を維持した。統合画面から理由選択へ戻す案は内省経路をループさせるため却下し、「次へ」は判断画面へ接続した。目標は先頭だけに省略せず全件表示し、空状態では新規設定シートを開く。
- Claude Code向け制約: S-04の `reasonSelection` と `selectReason` の直接／内省分岐を削除しない。表示上の試行回数は進行中の1回を含む `todayAttemptDisplayCount` を使う。統合画面のCTAを理由選択へ戻さず、目標編集は先頭目標、新規設定はnilルートの `GoalEditorSheet` とし、AppModel更新による再描画を維持する。
- 検証: DopaBreakCore 531件失敗0。iPhone 16 ProのDopaBreakTestsは251件中14件skip・失敗0で `TEST SUCCEEDED`。撮影専用テストは失敗0で、1320×2868の統合画面を生成して全要素を目視確認した。`xcodegen generate`、表示コピーlint、defaultValue監査、String Catalog JSON解析、`git diff --check` は成功した。

## 2026-08-28 — 全画面コピー3言語ネイティブ品質レビュー

- 作成・変更: `humanizer-jp` を使って日本語の硬い定型表現、説明の断片、過剰に整いすぎた語調を再監査した。あわせて `ios/DopaBreak/Localizable.xcstrings`、`ios/MonitorExtension/Localizable.xcstrings`、`ios/ShieldActionExtension/Localizable.xcstrings`、`ios/ShieldConfigExtension/Localizable.xcstrings`、`ios/WidgetsExtension/Localizable.xcstrings` の英語を米国向けUI、韓国語を韓国向けUIとして全件確認し、Swiftの日本語 `defaultValue` と `ios/DopaBreakTests/InterventionMergeCopyTests.swift` の期待値も同期した。`docs/11_ui_copy.md` §22と`docs/CHANGELOG.md`へ3言語の基準を追記した。
- 採用方針・却下案: 日本語は会話として読める簡潔さ、en-USは短いsentence caseとApple標準用語、koは本文の해요体・ラベルの名詞句・正しい助詞を採用した。直訳の `one breath`／`한 호흡`、不自然な実績表現 `Chose not to open`／`열지 않기로 함`／`참았습니다`、回数制限を指す韓国語 `상한` は却下した。韓国語のLive ActivitiesはAppleの表示名に合わせて `실시간 현황` とした。廃止済みUsageWatchを訴求していたペイウォール項目は、実在する1日の回数・待ち時間設定へ置き換えた。画面構成、コンポーネント、余白、モーションは変更していない。
- Claude Code向け制約: 直前の「英語・韓国語は全面改稿対象外」という記録は、本レビューで上書きされる。以後の正本は5つのString Catalogと `docs/11_ui_copy.md` §22。用語は en-US=`Pause`／`Didn't open`／`Full Block`、ko=`숨 고르기`／`열지 않음`／`완전 차단`／`실시간 현황` を維持する。位置指定子、複数形variation、キー名は変えず、日本語変更時はSwiftの `defaultValue` も同期する。
- 検証: 5カタログ計717キー・3言語2,154文字列単位を解析し、未翻訳、空値、文字種混在、位置指定子不一致は0件。日本語のAI調パターン監査は該当0件、表示コピーlintは廃止語彙0件・既存の意図した読点3件のみ、Swift `defaultValue` 監査は792呼び出しで不一致／欠落／未解決／型不一致0件。generic iOS Simulator向け全ターゲットは `BUILD SUCCEEDED`。手動ホールド用撮影2テストを除くDopaBreakTestsは251件中14件skip・失敗0で `TEST SUCCEEDED`。`git diff --check`も成功した。

## 2026-08-28 — 利用サマリー画面の階層再設計と3言語改行監査

- 作成・変更: `ios/DopaBreak/InterventionFlowView.swift` の「SNSを開いた後、目標入力の次に表示する今日の回数＋目標」画面を再設計した。32ptの全文1行表示をやめ、主指標を「数値＋単位」と説明ラベルに分離し、「開かなかった」回数をチェックアイコン付きの強調領域へまとめた。目標は構造化した箇条書きへ変更し、編集操作へ鉛筆／追加アイコンと44pt以上のタップ領域を付け、CTAを「次へ」から「どうするか選ぶ」へ具体化した。`ios/DopaBreak/Localizable.xcstrings` にja／en-US／koの指標ラベルと数値書式を追加し、`ios/DopaBreakTests/InterventionMergeCopyTests.swift` に改行と単位孤立の回帰テストを追加した。
- 採用方針・却下案: 数値と単位は同じ `Text` に閉じ込め、等幅数字、1行クランプ、Dynamic Type上限を使う。下段指標は通常時に横並び、幅不足時は `ViewThatFits` で縦積みへ切り替え、背景は常にカード幅いっぱいに保つ。全文をVoiceOverラベルとして残した。手動改行で見栄えだけを固定する案は言語・端末幅・文字サイズごとに破綻するため却下し、全体の文字を小さくする案は主従関係と可読性を損なうため却下した。2指標を同格の2列カードにする案も英語の単位孤立リスクと優先順位の曖昧化を避けるため採用しなかった。
- Claude Code向け制約: `intervention.usage_summary.count_value` の数値と単位を別の `Text` にしない。主指標・下段指標の `.dopaDisplayClamp()`、下段の `ViewThatFits(in: .horizontal)` と全幅frame、全文の `.accessibilityLabel(usageAttemptLine / usageCancelledLine)` を維持する。改行を追加する場合は意味の切れ目だけに限定し、値と `回`／`times`／`회` の間へ強制改行を入れない。CTAの遷移先と既存フロー状態・計測ロジックは変更していない。
- 検証: 5つのString Catalog計720キー・3言語2,163文字列単位で欠落言語・空値・未翻訳0件。手動改行は18言語エントリだけで、すべて段落または見出しの意味境界として固定した。主要7画面をja／en-US／koの1320×2868実描画（計21枚）で確認し、対象画面は約2倍の文字サイズでも英語の数値＋単位を維持して下段が縦積みへ切り替わることを確認した。Swift `defaultValue` 795呼び出しは不一致／欠落／未解決／型不一致0件、generic iOS Simulator向け全ターゲットは `BUILD SUCCEEDED`、DopaBreakTestsは253件中14件skip・失敗0、`git diff --check`も成功した。

## 2026-08-28 — Claude最新セッション引き継ぎ：介入統合の最終防御レビュー

- 作成・変更: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/InterventionTargetResolutionPolicy.swift` で、保存済み選択IDからカタログ外IDを除外し、重複を保存順のまま1件へ畳んでから0件／1件／複数件を解決するようにした。`ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/InterventionTargetResolutionPolicyTests.swift` に未知ID・重複・有効1件への縮退を追加した。`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Models/AppModels.swift` は廃止した永続値 `goalReminder` を統合先の `usageSummary` として復号する移行処理を追加し、`ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/InterventionEngineTests.swift` で旧JSONからの復元を固定した。最新実装の統合画面を再撮影し、`output/verify/intervention-merged-v2.png` に保存した。
- 採用方針・却下案: 未知IDを含む候補をUIの `catalogChoice` へ渡す案は前提条件違反によるクラッシュを招くため却下し、UI到達前の純関数ポリシーで正規化する。旧 `goalReminder` を未知値として保存ファイル全体の復元失敗にする案も、アップデート直後の進行中セッションを壊すため却下した。画面は並走側が完成させた「数値＋単位を一体化した主指標」「全目標」「44pt編集導線」「判断画面を明示するCTA」を正本とし、古い折り返しキャプチャや旧コピーへ戻さない。
- Claude Code向け制約: `resolve(requested:selected:)` は明示された未知IDを別アプリへフォールバックさせず `.none` のままにし、省略時だけ選択配列を有効IDへ絞って保存順で重複排除する。`InterventionStep` の `goalReminder` 互換復号は移行期間中維持し、再び列挙ケースとして画面遷移へ戻さない。統合画面の `.dopaDisplayClamp()`、`ViewThatFits(in: .horizontal)`、44pt操作領域、全目標表示、理由選択後の既存分岐は維持する。
- 検証: DopaBreakCore 535件失敗0。手動ホールド用撮影2スイートを除くDopaBreakTestsは253件中14件skip・失敗0で `TEST SUCCEEDED`。統合画面の日本語キャプチャは1320×2868で、旧画像にあった単位の孤立改行が解消されていることを目視確認した。表示コピーlintは廃止語彙0件・既存の意図した読点3件のみ、Swift `defaultValue` 監査は795呼び出しで不一致／欠落／未解決／型不一致0件、5つのString Catalog JSON解析と `git diff --check` も成功した。

## 2026-08-28 — SNS起動時のアプリ選択表示を完全削除（オーナー指示の訂正反映）

- 作成・変更: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/InterventionTargetResolutionPolicy.swift` から `.choose` を削除し、引数省略時は保存順で最初の有効な対象へ即時解決するよう変更した。`ios/DopaBreak/AppContainer.swift` の選択分岐、`ios/DopaBreak/InterventionFlowModel.swift` の `catalogChoice` マーカー、`ios/DopaBreak/InterventionFlowView.swift` の「どのアプリを開きましたか」画面を削除した。`ios/DopaBreak/Localizable.xcstrings` から同画面のja／en-US／koキーを削除し、Coreとアプリ統合テストを新しい自動解決へ更新した。
- 採用方針・却下案: Claudeへの元指示「『どれですか？』はいらない、削除」はシステムプロンプトをアプリ内画面へ置換する意味ではないため、複数時の選択カード案を失効させた。iOSはAppオートメーションの発火元をAppIntentへ渡さず、無指定時の正確なアプリ判定はできない。そこで実行を質問で止めないことを優先し、明示指定は従来どおり尊重、無指定は保存順の先頭へ決定的にフォールバック、対象0件は何も出さない方針を採用した。
- Claude Code向け制約: `.choose`、`.catalogChoice`、`dopabreak.catalog-choice:`、`intervention.choose_app.*` を復活させない。`StartInterventionIntent.app` は省略可能のまま維持し、明示指定時は指定対象、省略時は最初の有効な保存対象へ進める。複数対象で正確なアプリ別記録・再オープンが必要な場合はオートメーション作成時の任意パラメータ設定で担保し、実行中の質問UIは追加しない。
- 検証: DopaBreakCore 535件失敗0。iPhone 16 Pro（iOS 26.5）の関連統合テスト10件失敗0、手動ホールド用撮影2スイートを除く通常DopaBreakTestsは253件中14件skip・失敗0で `TEST SUCCEEDED`。表示コピーlintは廃止語彙0件・既存の意図した読点3件のみ、Swift `defaultValue` 監査は793呼び出しで不一致／欠落／未解決／型不一致0件、5つのString Catalog JSON解析と `git diff --check` も成功した。

## 2026-08-28 — 「本当に今必要ですか？」独立画面を利用サマリーへ統合

- 作成・変更: `ios/DopaBreak/InterventionFlowView.swift` と `ios/DopaBreak/InterventionFlowModel.swift` から表示用の `decision` stage と独立した判断画面を削除し、今日の回数＋全目標画面の下部へ「開かない」「必要な時間だけ開く」を直接配置した。`ios/DopaBreak/Localizable.xcstrings` は判断画面固有の見出し・eyebrow、旧中継CTA、既に廃止済みだった `goal_reminder` 画面の未使用キーを削除し、統合画面用の2アクションへ整理した。`ios/DopaBreakTests/InterventionMergeCopyTests.swift` と `docs/06_screen_design.md`、`docs/11_ui_copy.md`、`docs/12_hybrid_intervention.md` も新しい導線へ同期した。
- 採用方針・却下案: 「本当に今必要ですか？」画面は直前の「どうするか選ぶ」と同じ判断をもう一度要求し、追加情報も新しい判断軸もなかったため独立表示を廃止した。理由選択は明確目的／反射目的の分岐、一呼吸は自動行動の中断、時間選択は利用時間の確定という別々の役割があるため維持する。利用サマリー自体を削除する案は、当日の回数と目標という熟慮材料を失うため却下した。キャラクターの変化だけを残す案も、判断に必要な情報を増やさず待ち時間を戻すため採用しなかった。
- Claude Code向け制約: 反射的な経路は `reasonSelection → breathing → usageSummary` とし、`usageSummary` から `chooseCancel()` または `chooseOpenWithTime()` を直接呼ぶ。直接目的は従来どおり `reasonSelection → durationSelection` を維持する。Coreの `InterventionStep.decision` は記録エンジンの内部状態として残し、表示用 `InterventionFlowStage.decision` や独立画面を復活させない。利用サマリーの数値＋単位一体表示、全目標、44pt編集導線、VoiceOver全文ラベルを維持する。
- 検証: `InterventionMergeCopyTests` に独立判断画面と表示stageの不在、統合画面内の2アクションを固定する回帰テストを追加した。iPhone 16 Pro（iOS 26.5）で対象5件失敗0・`TEST SUCCEEDED`、DopaBreakCoreは535件失敗0。表示コピーlintは廃止語彙0件・既存の意図した読点3件のみ、Swift `defaultValue` 監査は790呼び出しで不一致／欠落／未解決／型不一致0件、String CatalogのJSON解析と `git diff --check` も成功した。

## 2026-08-28 — SNSの使用時間ベース通知を全面廃止

- 作成・変更: `ios/DopaBreak/InterventionFlowModel.swift` は通常のカタログSNSを時間選択なしで開き、`recordUntimedOpen()` で `selectedDurationSeconds=nil` の開いた事実だけを記録するようにした。時間切れ通知・中間チェックイン・通知タップ後のシートを削除し、`ios/DopaBreak/LockSurfaceCoordinator.swift` で旧 `dopabreak.timeup.*` / `dopabreak.midsession.*` / `dopabreak.usagewatch.*` の予約・配信済み通知を掃除する。`ios/DopaBreak/SettingsNotificationsView.swift` から利用時間アラート設定を除去し、Monitor Extensionの閾値通知処理、ペイウォールの利用時間特典行、Coreの利用時間ポリシー／保存層と対応テストを削除した。`ios/DopaBreak/UsageWatchController.swift`、`ios/DopaBreak/MidSessionCheckInSheet.swift` など廃止機能専用ファイルも削除し、ja／en-US／koのコピーと関連設計書を同期した。
- 採用方針・却下案: 他社SNSの前面状態とリアルタイム使用時間を正確に取得できず、壁時計や累積閾値を実利用時間として通知すると、すでに閉じた後にも誤通知し得るため機能ごと廃止した。通常SNSだけ通知を外して15分／2時間アラートを残す案、ペイウォールだけ別の設定訴求へ差し替える案、廃止コードを互換シェルとして残す案も、誤解と再有効化の余地を残すため却下した。シールド一時解除の5／10／15／30分はOS側の解除期限を実際に制御する値なので残すが、そこからも経過時間通知は送らない。朝・週次・設定確認・プラン・Deep Focus終了など、SNS実利用時間の推測に依存しない通知は維持する。
- Claude Code向け制約: 前項の「通常経路も時間選択を維持する」という記録は本決定で上書きされる。通常経路は `reasonSelection → （反射目的のみ breathing → usageSummary）→ Open` で、`durationSelection` は `.gateToken` 専用。通常の opened ログにdurationや未回答Reflectionを作らず、時間通知、閾値監視、利用時間通知設定、ペイウォール特典を復活させない。旧通知prefixの削除処理と旧保存キーの起動時移行削除は維持する。シールド一時解除・夜だけ強化・Deep FocusのDeviceActivity処理を利用時間通知と一緒に削除しない。
- 検証: `xcodegen generate` 成功。DopaBreakCoreは利用時間専用25テスト削除後の510件が失敗0。iPhone 16 Pro（iOS 26.5）で `InterventionMergeCopyTests`、`InterventionFlowGateTests`、`MeasurementFoundationTests` の計37件が失敗0で `TEST SUCCEEDED`。5つのString Catalog JSON解析、表示コピーlint、Swift `defaultValue` 755呼び出しの監査、`git diff --check` はすべて成功し、iOS Swiftソースの `UsageWatch` 残存は0件。Apple HIG／apple-designの目的・簡潔性と、価値の根拠がある通知だけを出す原則を適用した。

## 2026-08-29 — Live Activityカードの文字拡大・密度改善 v1

- 作成・変更: `ios/WidgetsExtension/LockThemeLiveActivityView.swift` の全10テーマへ目標件数別のタイポグラフィと密度を実装し、`ios/DopaBreakTests/LockThemeLiveActivityViewTests.swift` に承認済みフォント増分と1件時120pt以上の縦占有率を固定する回帰テストを追加した。目標フォントは1件+5pt／2件+4pt／3件+2pt、サマリーは1〜2件+1.5pt／3件+1ptとし、行高・セクション間隔・外側縦paddingも件数別に調整した。
- 採用方針・却下案: 目標を主役に保ち、少数目標で余る高さを行高とセクション間隔へ配分した。単純な上寄せ、カード高の変更、固定クリップ追加、eyebrow拡大は採用していない。Apple HIG／apple-designのタイポグラフィ階層を参照しつつ、数値は設計正本 `.claude/specs/live-activity-density-v1.md` を優先した。
- Claude Code向け制約: 160pt本体、四辺描画、水平16pt（note左46pt例外）、e1の2行・3件dense分岐、asagiri中央揃え、K-POP全幅帯、blueprintセル内4pt以上、既存フォント選択とnote英語`×`補正、`isMeasuring`経路、Home Widget／Dynamic Island／コピー／EntitlementGateは維持する。件数別フォント増分は `goalFontIncrease`／`summaryFontIncrease` を唯一の正本として全テーマで共用する。
- 検証: `xcodegen generate --spec project.yml` 成功。iPhone 16 Pro（iOS 26.5）で `DopaBreakTests/LockThemeLiveActivityViewTests` は16件・失敗0、90枚描画、160pt上限、四辺描画、blueprint／note／e1個別検査、1件時120pt占有率を含め `TEST SUCCEEDED`。対象差分の `git diff --check` も成功した。

## 2026-08-29 — Live Activity密度v1レビュー全6件の是正

- 作成・変更: `ios/WidgetsExtension/LockThemeLiveActivityView.swift` でe1の目標行を固定heightからフォントサイズと2行行高に追随するminHeightへ変更し、1〜3件の行間・セクション間隔・縦paddingを160pt内で再配分した。gaming／monochrome／liquidGlass／kawaiiPink／blueprintは1〜2件時のテキスト実測縦スパンが120pt以上になるよう間隔を調整し、cancelledのdefaultValueを「今日は%lld回 開くのをやめた」へ戻した。`ios/DopaBreakTests/LockThemeLiveActivityViewTests.swift` は1／2件を全10テーマでスイープし、カード160pt、全Text要素収容、非切詰め幅、テキスト実測縦スパン120pt以上を検査するよう更新し、e1の長文検査をHStack枠ではなくTextアンカー基準へ変更した。
- 採用方針・却下案: e1は `lineLimit(2)` を実際に機能させるため、目標数別の固定行高案を却下し、承認済みフォント増分から2行分の最小行高を導出する方式を採用した。3件時はフォント+2ptを維持したまま、行間と外側余白を圧縮してText間・仕切り・サマリー間に各1pt以上を確保した。カード全体の `.contentBounds` による占有率判定は、無意味に160ptを返すテーマがあるため却下した。
- Claude Code向け制約: e1の `lineLimit(2)`、`minimumScaleFactor(0.6)`、目標数別フォント増分は維持し、行高は `e1GoalMinimumHeight(forGoalCount:)` を正本とする。1／2件回帰は `.contentBounds` ではなくeyebrow／goal／summaryのTextアンカー縦スパンで判定し、必ずカード160pt一致と各Text要素のカード内収容を併せて検査する。水平16pt（note左46pt）、四辺描画、既存フォント配線、`isMeasuring` 経路は変更しない。
- 検証: iPhone 16 Pro（iOS 26.5）で `DopaBreakTests/LockThemeLiveActivityViewTests` 全17件・失敗0、`TEST SUCCEEDED`。1／2／3件、長文e1、90枚ロケール描画、160pt・収容・非切詰め・四辺・blueprint／note個別検査を含む。

## 2026-08-29 — ロック画面テーマのlive／saved命名分離と実ホスト回帰テスト

- 作成・変更: `ios/DopaBreak/AppContainer.swift` に権利ガード後の `liveLockTheme` と保存値の `savedLockTheme` を追加し、`ios/DopaBreak/SettingsView.swift`／`SettingsLockSurfaceView.swift` のガード後スロットを `liveLockTheme`、`ios/DopaBreak/HomeView.swift`／`OnboardingFlow.swift` の保存値スロットを `savedLockTheme` へ改名した。`ios/DopaBreakTests/MeasurementFoundationTests.swift` にはSettingsのProノートとHomeの保存選択・liveプレビュー・保存値・`.homeThemeGate`を実ビューのホスト経路で固定する回帰テストを追加し、恒真アサーションと中身のないペイウォール解除テストを是正した。
- 採用方針・却下案: 同じ `selectedLockTheme` が画面ごとに逆の意味を持つ状態を廃止し、値の意味を識別子とAppModelアクセサで明示した。専用ラッパー型、非Observableな`SettingsStore`のbody直読み、`lockSurfaceState`の権利ガード変更は採用していない。表示・保存・ペイウォール提示順・コピー・レイアウトは変更していない。
- Claude Code向け制約: liveスロットには `model.liveLockTheme`、savedスロットには `model.savedLockTheme` またはタップされたテーマだけを入れる。`AppContainer.lockSurfaceState`、`EntitlementGate.lockThemeAllowed`、設定／Home／オンボーディングのペイウォール分岐、保存先行順序、`LockThemePreviewCard`の修飾子順序を維持する。`selectedLockTheme`という曖昧名を復活させない。
- 検証: generic iOS Simulator全ターゲットは `BUILD SUCCEEDED`。DopaBreakCore 510件失敗0、DopaBreakTests 253件中14件skip・失敗0。R2はProノート判定をlive値へ戻す変異で対象テストが未描画timeout、R3はHome選択状態をlive値へ戻す変異で`.e1`不一致となり、それぞれ失敗を確認して正しい実装へ復元した。表示コピーlint、`defaultValue`監査（755呼び出し・mismatch 0）、`git diff --check`はいずれもexit 0。

## 2026-08-29 — オンボーディング目標入力見出しの語中改行修正

- 作成・変更: `ios/DopaBreak/OnboardingFlow.swift` と `ios/DopaBreak/Localizable.xcstrings` の `onboarding.goal.title` を「空いたこの時間で 何をしますか？」から「取り戻した時間で\n何をしたいですか？」へ変更した。`ios/DopaBreakTests/HomeGoalsCopyTests.swift` に日本語の正本を固定するテストを追加し、`ios/DopaBreakTests/InterventionMergeCopyTests.swift` の全カタログ強制改行許可セットへ意味境界として登録した。`docs/07_onboarding_design_lifefocus.md`、`docs/11_ui_copy.md`、`.claude/specs/i18n-launch-inventory.md` も同期した。
- 採用方針・却下案: 半角スペースを自動折り返し候補として残す案は端末幅によって「何をしま｜すか？」の語中分断を再発させるため却下した。文字サイズを下げて1行へ収める案も、見出しの階層とDynamic Type対応を弱めるため採用しない。意味が完結する「取り戻した時間で」と問いかけを2行に固定し、直前の損失リビールから目標入力へのつながりも明確にした。
- Claude Code向け制約: 日本語の改行は `onboarding.goal.title` 内の1か所だけを維持し、「何をしたいですか？」の語中へスペースや改行を追加しない。en-USとkoには同じ位置の強制改行を機械的に追加せず、各ロケールの自動折り返しを使う。`centeredTitle` の共通フォントサイズや他のオンボーディング見出しは変更していない。
- 検証: iPhone 16 Pro（iOS 26.5）の日本語実描画で見出しが意図した2行になり、入力欄・保存済み目標・下部CTAとの重なりがないことを確認した。`HomeGoalsCopyTests` 3件と `InterventionMergeCopyTests` 7件は失敗0。String Catalog JSON解析、Swift `defaultValue` 755呼び出し監査、`git diff --check` は成功した。

## 2026-08-29 — Live Activity目標行マーカーの縦位置修正

- 作成・変更: `ios/WidgetsExtension/LockThemeLiveActivityView.swift` でe1／gaming／kpop／kawaiiPink／note／blueprint／retroPopの行頭マーカーを目標フォント比で拡大し、単行テーマはテキスト枠中央、2行を許すe1は1行目の行ボックス中央へ揃えた。マーカーと1行目に個別のlayoutAnchorを追加し、`ios/DopaBreakTests/LockThemeLiveActivityViewTests.swift` で7テーマ×目標1／2／3件の中心Y差±2pt以内を実描画検査する回帰テストを追加した。K-POPは1件時の既存120pt密度下限を維持するため、目標行高へ縦の余りを再配分した。
- 採用方針・却下案: e1の行全体中央や従来のfirstTextBaselineへマーカーを置く案は、2行折返し時に1行目から外れるため却下した。テーマ固有の色・記号・構図は維持し、asagiri／monochrome／liquidGlassは行頭マーカー自体がないため追加していない。
- Claude Code向け制約: `goalMarker`／`goalFirstLine`アンカーと、e1の`e1GoalLineHeight(forGoalCount:)`を縦位置検査の正本として維持する。マーカー寸法は15pt基準の現行寸法へ目標フォント倍率を掛け、カード160pt、水平16pt（note左46pt）、e1の2行対応、既存テーマ色・記号種を変更しない。
- 検証: iOS 26.5 Simulatorで`DopaBreakTests/LockThemeLiveActivityViewTests`全18件・失敗0、90枚ロケール描画、7マーカーテーマ×1／2／3件の中心Y差±2pt検査を含め`TEST SUCCEEDED`。`git diff --check`も成功した。

## 2026-08-29 — Live Activityマーカー修正レビュー7件の是正

- 作成・変更: `ios/WidgetsExtension/LockThemeLiveActivityView.swift` のe1／gaming／kpop／kawaiiPink／note／blueprint／retroPopを `.firstTextBaseline` 揃えへ統一し、図形マーカーは各目標フォントの `capHeight` から「baseline − capHeight/2」へ中心を置くalignment guide、♥／✽はマーカー側と目標側のcapHeight差を`baselineOffset`で補正した。`ios/DopaBreakTests/LockThemeLiveActivityViewTests.swift` は同一View由来の`goalFirstLine`循環アンカーを廃止し、393×160の実レンダリング画像からマーカー色と`HHHHHHHH`の実インクbboxを独立抽出して中心差±1ptを7テーマ×1／2／3件で検査する。
- 採用方針・却下案: HStack／行ボックス中央はキャップハイト中心を保証せず旧配置でもテストが自己成立するため却下した。e1の`UIFont.lineHeight`固定オーバーレイも日本語フォールバックや縮小後の実描画を観測しないため削除した。e1 divider検査は内側TextだけでなくminHeight付き`e1Goal`行枠も併用し、1件時の床は60pt、2〜3件時は実フォント2行高、gaming 1件時は52pt行高と122ptの実測縦スパン下限を採用した。
- Claude Code向け制約: マーカー行の`.firstTextBaseline`、図形の`markerCenterAlignedToCapHeight`、記号の`glyphCapCenterOffset`を維持し、ボックス中央へ戻さない。マーカー回帰テストはlayout anchor同士の比較へ戻さず、色分離した実インクを検査する。e1のdivider衝突は`.goal`と`.e1Goal`の両方、密度床は1件60pt／2〜3件2行実高、gaming 1件は122pt以上を維持する。
- 検証: iPhone 17 Pro Max（iOS 26.5）で`DopaBreakTests/LockThemeLiveActivityViewTests`全18件・失敗0、`TEST SUCCEEDED`。7テーマを一時的に旧ボックス中央へ戻すと新しい実インク整列テストが7アサーションで失敗し、復元後は同テストと全18件が成功した。復元前後の`LockThemeLiveActivityView.swift` SHA-256一致、対象差分の`git diff --check`、TODO／FIXME／省略記述0を確認した。

## 2026-08-29 — 設定「止める強さ」カードの全幅縦積み化

- 作成・変更: `ios/DopaBreak/SettingsView.swift` の `modeSection`／`modeCard` を3列 `LazyVGrid` から全幅 `VStack` の3行カードへ変更した。アイコン、タイトル、説明、Proカプセル、選択時checkmarkを横一列へ配置し、説明文は固定行数なしの自然高で描画する。`ios/DopaBreakTests/MeasurementFoundationTests.swift` に実ホスト経路でjaの3カード全文を画像OCRで確認する回帰テストと、1320×2868の `output/verify/settings-mode-cards.png` 撮影テストを追加した。
- 採用方針・却下案: 全幅化により説明文の折り返し幅を確保し、既存の選択色・ストローク・外側リング・Pro表示・44pt以上のタップ領域を維持した。3列グリッド、`lineLimit`、固定 `minHeight: 116` は狭幅での切り詰めを残すため採用していない。文言、選択ロジック、ペイウォール分岐、String Catalogは変更していない。
- Claude Code向け制約: `InterventionMode.selectable` の順序、`setSelectedMode`、`modeAllowedForCurrentEntitlement`、`modeSymbolName`、`SmallLabel`、`CardContainer`、既存の背景／境界／角丸／アクセシビリティtraitを維持する。日本語・英語・韓国語の各 `displayTitle`／`detailText` を省略せず、Proとcheckmarkが同時に成立する場合は両方を表示する。検証画像は `output/verify/settings-mode-cards.png` の正本とする。
- 検証: iPhone 16 Pro Max（iOS 26.5）で追加2テストを実行し、全3タイトル・3説明文の全文認識とPNG出力を確認した。DopaBreak本体の `xcodebuild` ビルドおよび対象テストは成功した。
- レビュー是正（Opus5指摘・同日）: `String(localized:)` はプロセス言語で解決されSwiftUIの `.environment(\.locale)` では切り替わらないため、OCR回帰テスト冒頭に日本語コピー一致の `XCTSkipUnless` を追加し非ja環境での空振り合格を防いだ。選択checkmarkへ `.accessibilityHidden(true)` を追加し `.isSelected` traitとの二重読み上げを防止。是正後も対象テストは `TEST SUCCEEDED`。カード間タップ領域の隣接（標準iOSリストと同挙動）と、並走セッションのシグネチャ変更起因でテストファイル内に足した `SettingsNotificationsView` 互換イニシャライザは許容と判断した。

## 2026-08-29 — 設定画面の状態同期・完全ブロック導線・起床就寝タイムライン修正

- 作成・変更: `ios/DopaBreak/SettingsView.swift` と `SettingsNotificationsView.swift` で一呼吸秒数、起床・就寝時刻、朝通知時刻、オートメーション確認状態をSwiftUIのローカル状態へ同期し、非Observableな `SettingsStore` の値が画面再表示まで更新されない問題を解消した。完全ブロック対象未選択時は `startSessionButton` を有効なアプリ選択導線に切り替え、`ios/DopaBreak/AppContainer.swift` に `hasDeepFocusTargets` を追加した。`timelineBar` は15分スナップ、起床・就寝間の最小1時間、ドラッグ中時刻表示、選択触覚、VoiceOver調整操作へ対応し、変換・制約ロジックを `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/WakeSleepTimelinePolicy.swift` に分離した。新規文言は `ios/DopaBreak/Localizable.xcstrings` のja/en/koへ追加した。
- 採用方針・却下案: `SettingsStore` 自体のObservable化は影響範囲が広いため採用せず、画面境界の `refreshSettingsState()` を正本としてローカル状態へ取り込む方式を採用した。完全ブロックの未選択状態をdisabled表示する案は初回設定を塞ぐため却下し、既存のScreen Time認可・FamilyActivityPicker経路を再利用した。タイムラインは連続分ではなく仕様どおり15分単位とし、既存のタップ用ポップオーバーは維持した。ホーム30分ボタンの変更は意図的に行っていない。
- Claude Code向け制約: `HomeView.swift` は本対応の対象外。`primaryRule` は `model.hasDeepFocusTargets` を先に確認し、空の `activitySelectionData` を有効対象として扱わない。タイムラインは `WakeSleepTimelinePolicy` を変換と制約の正本とし、15分刻み・最小1時間・0:00〜23:45の境界、ドラッグ終了／DatePicker／VoiceOver調整後のシールド同期を維持する。新しい `settings.deep_focus.choose_apps` はja/en/koの3翻訳をカタログに保持する。
- 検証: DopaBreakCore全515件・追加ポリシー5件は失敗0、追加ポリシーは行／関数／リージョン100%カバレッジ。`DeepFocusTargetGuardTests` 3件と設定画面キャプチャテストは `TEST SUCCEEDED`。iPhone 16 Pro（iOS 18.3.1）で未選択CTAとドラッグ中時刻表示をPNG撮影して目視確認した。表示文言lint、defaultValue監査（mismatch／missing／unresolved 0）、3言語値検査、対象差分の `git diff --check` はexit 0。アプリ全体スイートは同時変更中の `MeasurementFoundationTests.testSettingsModeCardsRenderAllJapaneseCopyWithoutTruncation` のアクセシビリティ列挙で停止したため中断し、同1件を除く260件は完走したが、別の同時変更 `LockThemeLiveActivityViewTests` の実画像整列検査が36アサーション失敗した。

## 2026-08-29 — Live Activityマーカー最終レビュー1〜5の是正

- 作成・変更: `ios/WidgetsExtension/LockThemeLiveActivityView.swift` でgamingの3件時残差、K-POPの★、note／blueprintを含む単行マーカーへ密度・グリフ・実効縮小率に追随するcap中心補正を追加した。`ios/DopaBreakTests/LockThemeLiveActivityViewTests.swift` はnoteの参照インク高ガード、K-POPの縦バーを除外した★独立クロップ、日本語長文3件の縮小整列ケース、e1の2件／3件固定期待値を追加し、整列許容を±0.75ptへ締めた。
- 採用方針・却下案: 非縮小UIFontだけでマーカー位置を決める案は長いCJKで最大3pt前後ずれるため却下し、文字列の自然幅と各テーマの実レイアウト幅から実効scaleを求め、縮小後capHeight差の半分を光学補正する方式を採用した。K-POPは縦バー込みbboxを★の検証に使わず、★のbaselineOffset補正とバー除外クロップを別々に保証する。
- Claude Code向け制約: `.firstTextBaseline` と `markerCenterAlignedToCapHeight` を維持し、単行マーカーの `scaledGoalCapCenterOffset` を削除しない。K-POPの★測定は縦バーのx範囲を含めず、参照テキストは期待capHeightの60%未満なら必ずfailさせる。日本語長文3件、ラテン1〜3件とも整列accuracyは0.75ptを維持し、e1の2件46.34375pt／3件40.57421875ptは固定期待値で検査する。
- 検証: iPhone 17 Pro Max（iOS 26.5）で `DopaBreakTests/LockThemeLiveActivityViewTests` 全19件・失敗0、`TEST SUCCEEDED`。ラテン1〜3件と日本語長文3件の全実測Δは各テーマとも−0.5〜+0.5ptで、±0.75pt境界に対して0.25pt以上の余裕を確認した。対象差分の`git diff --check`成功、TODO／FIXME／省略記述0件。

## 2026-08-29 ホーム完全ブロックCTAの置き換え（オーナー承認）
- 決定: ホームの「30分間 開けないようにする」（`home.targets.focus_30`・固定30分の`startDeepFocusSession(30)`直呼び）を廃止し、完全ブロック設定への導線に置き換える。オーナーが「完全ブロック設定への導線／ホームで時間を選んで開始／ボタンを撤去」の3案から導線案を選択した（2026-08-29）。
- 背景: 2026-08-28/29の実機指摘で「固定30分の根拠記録なし＋対象未選択でも空セッションが開始される」と判定済み。アプリごと設定への置き換え（旧F3案）は2026-08-28に不採用。ホーム経路のペイウォールゲートは廃し、Proゲートは設定側の既存ゲートに委ねる。
- 実装仕様: `.claude/specs/home-block-settings-cta-2026-08-29.md`（遷移は`pendingPlanSettingsFocus`と同型のフラグ消費で実装・新機構は発明しない）

### 2026-08-29 追記 — H1〜H3実装完了

- 作成・変更: `ios/DopaBreak/HomeView.swift` は開始可能時の固定30分CTAを `home.targets.block_settings` へ置き換え、`onOpenBlockSettings` だけを呼ぶ構造にした。`ios/DopaBreak/RootTabView.swift`・`AppContainer.swift`・`SettingsView.swift` は `pendingDeepFocusSettingsFocus` を既存の保留フラグと同じ手順で設定タブへ送り、「止める強さ」にスクロールして即時消費する。`ios/DopaBreak/Localizable.xcstrings` はja/en/koの新キーに入れ替えた。回帰テストと着地画像は `ios/DopaBreakTests/HomeGoalsCopyTests.swift`、`SettingsDeviceFixesSnapshotCapture.swift`、`output/verify/home-block-settings-landing.png` に収録した。
- 採用方針・却下案: ホームで固定時間を開始する案とホームでProペイウォールを出す案は却下し、権利判定と対象選択を設定側の既存契約に一元化した。新しいルーターや環境値は追加せず、`pendingPlanSettingsFocus` の1回消費パターンをそのまま踏襲した。
- Claude Code向け制約: `showsEndDeepFocusButton`、進行中の解除CTA・残り時間、`HomeFocusButtonStyle(kind: .primary)`、設定側のProゲートとF1/F2/F4を維持する。ホームから `startDeepFocusSession`や`.settingsModeGate`を再導入しない。遷移フラグはSettingsViewのレイアウト確定後に1回だけ消費し、着地先IDは `settings.section.deep_focus` を正本とする。
- 検証: iPhone 17 Pro Max（iOS 26.5）でDopaBreakTests 264件中16件skip・失敗0で `TEST SUCCEEDED`。追加の導線キャプチャと3言語テスト2件も失敗0。`home.targets.focus_30` はソース・カタログ・テストで参照0。表示コピーlintとdefaultValue監査はexit 0（756呼び出し、mismatch/missing/unresolved 0）。

## 2026-08-29 — 設定・ホーム・端末是正バッチ Round 1レビュー修正

- 作成・変更: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/WakeSleepTimelinePolicy.swift` を24時間の円環契約へ直し、起床・就寝の両方向の弧を各60分以上に保ちながら操作中のハンドルだけを最近傍へ止める。`ios/DopaBreak/SettingsView.swift` はドラッグだけ15分スナップ＋触覚、DatePickerは分単位、VoiceOver既定アクション、ドラッグ中断の後始末、値変更追従のシールド同期へ分離した。`ios/DopaBreak/HomeView.swift` は3つの設定値をStateミラー化し、`SettingsDeviceFixesSnapshotCapture.swift` はTabViewのwarm経路を通すゲート付きキャプチャへ更新した。
- 採用方針・却下案: 直線軸の `wake < bed` 制約は跨日就寝を破壊するため廃止し、夜弧・昼弧の双方を検査する円環制約を正本にした。もう片方のハンドルを動かす補正、DatePickerの15分丸め、body/tickerからの同期ディスク読み出しは採用していない。ホームCTAは「完全ブロックを設定する」から「止める強さを設定する」へ変更し、着地先の既存見出し語彙（en: Limit level、ko: 제한 강도）に揃えた。
- Claude Code向け制約: `WakeSleepTimelinePolicy.clampedWake` / `clampedBed` は動かす側だけを返し、23:00→7:00、1:00→5:00、0:00境界を維持する。`SettingsView` の要求フラグは設定タブ可視化・レイアウト確定後、`scrollTo` 実行後に1回だけ消費する。ホームCTAの既存 `onOpenBlockSettings`、進行中の解除CTA、F1〜F4のStateミラー／選択／同期構造を崩さない。

## 2026-08-29 — 設定・ホーム・端末是正バッチ Round 2レビュー修正

- 作成・変更: `ios/DopaBreak/SettingsView.swift` はドラッグ開始ごとのUUIDで起点を一度だけ固定し、onChangedごとの450msクリーンアップを廃止した。終了通知欠落時だけ10秒のフェイルセーフを使い、DeviceActivity同期は250msのキャンセル可能なtrailing debounceへ変更して、onEnded／onDisappear／フェイルセーフで保留中の最終値を即時同期する。`ios/DopaBreak/HomeView.swift` は介入モード・起床・就寝も既存の設定Stateミラーへ統合した。`SettingsFocusRequestConsumptionTests.swift` に可視化前は保留、可視化後は一度だけ消費する純ロジック回帰を追加し、参照ゼロの `settings.deep_focus.standard_notice` を `Localizable.xcstrings` から削除した。
- 採用方針・却下案: ドラッグ中の静止を終了と推測する短時間タイマーは、ライブ表示・タップ抑止・累積translationの基準を壊すため却下した。ジェスチャの起点はnil判定ではなく同一UUIDとの一致で固定する。各15分ステップで `syncShield()` を直呼びする案もDeviceActivity再登録を連打するため却下し、最後の変更だけを遅延実行しつつ画面／ジェスチャ終了時は落とさずflushする構成を採用した。
- Claude Code向け制約: タイムラインのonChangedから短時間クリーンアップを再導入せず、`timelineDragGestureID` と `timelineDragAnchorGestureID` の同一性をアンカー条件にする。同期は `scheduleTimelineShieldSync()` を唯一の変更追従経路とし、`flushPendingTimelineShieldSync()` をonEnded／onDisappear／フェイルセーフから外さない。Homeの `currentMode`、夜判定、残り時間、就寝表示では非Observableな`SettingsStore`をbodyから直接読まず、`refreshSettingsMirrors()`のState値を使う。

## 2026-08-29 — 記録・週次レポートのFree全期間化（統計履歴ゲート撤去）

- 決定: オーナー決定で記録・週次レポートをFree全期間化（旧: Free=直近1日）。正本は docs/15_pricing_design.md §3.2b（2026-08-29改訂）。ペイウォール機能リストは4行（unlimited_apps / deep_focus / night_block / lock_theme）。
- 作成・変更: EntitlementGateの `statsDays`・`weeklyReportAllowed` を廃止。StatsViewのロックUI（期間タブのProバッジ・ぼかしカード・「すべての記録を見る」ボタン）、HomeViewの鍵付き統計導線、PaywallViewの `statsHistoryGate` placementと `paywall.feature.full_history` 行を削除。未参照になったxcstringsキーも削除。
- 採用方針・却下案: Free 7日間の折衷案は却下（週次通知は成立するが初週の購入判断に効かない点は同じで、ロックUIの維持コストだけ残る）。統計画面への代替課金導線は今回追加しない（週1ペイウォール提示と対象アプリ数・Deep Focusゲートが転換圧を担う）。
- Claude Code向け制約: 統計・週次レポート系にProゲートを再導入しない。週次振り返りをレビュー誘導の発火点にする案と振り返り末尾の非課金者向けPro導線1行は**提案のままオーナー未承認**（勝手に実装しない）。
- 検証: DopaBreakCore 518テスト0失敗・アプリ xcodebuild BUILD SUCCEEDED。Opus5独立レビューで実行時バグ0件（build-for-testing warning 0・EntitlementGateTests 23件0失敗・`stats_history_gate` の分析文字列参照ゼロ・defaultValue監査 mismatch 0 をレビュー側でも実測）。指摘はドキュメント側2件（実機検証ランブック・docs/11の旧契約記述）で同日修正済み。

### 2026-08-29 追記 — Free全期間化の実装完了

- 作成・変更: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/EntitlementGate.swift` から統計日数・週次レポートの権利プロパティを削除し、`ios/DopaBreak/StatsView.swift` は全ティアで今週／今日／全期間を選択できる通常カード表示へ統一した。`ios/DopaBreak/HomeView.swift` は常に統計タブへ進むchevron付き導線、`ios/DopaBreak/PaywallView.swift` は4機能行へ統一し、関連テストと `ios/DopaBreak/Localizable.xcstrings` を追従した。
- 採用方針・却下案: Freeだけ初期期間を今日にする案や統計内に代替ペイウォール導線を残す案は、Free全期間化と統計ゲート完全撤去の決定に反するため採用していない。統計画面はティアに関係なく今週を初期表示とし、各分析カードの実データをぼかさず表示する。
- Claude Code向け制約: Homeの統計カードは常に `onOpenStats` を呼び、右chevronを表示する。Statsの期間選択・アプリ別・振り返り・理由カードに権利分岐、Proバッジ、blur、ロックオーバーレイ、課金CTAを戻さない。ペイウォール機能リストは4行を維持する。
- 検証: DopaBreakCore `swift test` は518件・失敗0。`ios/build/free-history-dd` をDerivedDataに指定したiPhone Simulator向けDopaBreakビルドは `BUILD SUCCEEDED`。実装ソース・テスト・String Catalogで廃止した統計履歴ゲート識別子と関連ローカライズキーの参照0、String CatalogのJSON検証、対象差分の `git diff --check` 成功を確認した。

## 2026-08-29 — 設定・ホーム・端末是正バッチ Round 2検証追記

- 検証: DopaBreakCoreの `swift test` は510件・失敗0。iPhone 16 Pro SimulatorでDopaBreakTestsは265件中17件skip・失敗0、R17対象テストは可視化前の保留と可視化後の一度だけの消費を確認した。表示コピーlintと`defaultValue`監査（755呼び出し、mismatch／missing／unresolved 0）はexit 0。タイムラインを5秒静止してもライブカプセルが13:15表示のまま保持され、その後14:30まで連続して進み、リリース後にカプセルが消えることと意図しないポップオーバーが出ないことをSimulator実操作で確認した。String Catalog JSON解析、未参照キー0件、TODO／FIXME／省略記述0件、`git diff --check`も成功した。

## 2026-08-29 — 介入フロー順序反転（呼吸を無条件の先頭へ・オーナー承認）

- 決定: 介入フローを「呼吸（3/5/8秒・全員必須）→ 理由選択 → direct系は即開く／reflective系は回数＋目標＋判断」へ順序反転。旧フローの「理由が先・仕事/調べ物/連絡/投稿は呼吸省略」は、「仕事」タップが呼吸の免除券になる抜け道で、正直に暇つぶしと答えるほど画面が増える逆インセンティブだった（オーナー指摘 2026-08-29）。理由の回答は呼吸後の扱いだけを変え、免除券にしない。
- 正本: `docs/12_hybrid_intervention.md` §2（2026-08-29決定ブロック）。実装仕様: `.claude/specs/intervention-breath-first.md`
- Claude Code / Codex向け制約: 呼吸にスキップ導線を付けない。理由選択による呼吸省略を再導入しない。カタログ経路とgateToken経路の両方で呼吸→理由の順。エンジンの記録順序（recordIntent→advanceStep）と統計スキーマは変更しない。

### 2026-08-29 追記 — 順序反転の実装完了

- 作成・変更: `ios/DopaBreak/InterventionFlowModel.swift` は `start()` から全経路で呼吸を開始し、呼吸完了後に理由選択へ遷移する状態機械へ変更した。reflective理由は再呼吸せず `usageSummary` へ直行し、direct理由は既存のcatalog即時オープン／gateToken時間選択へ進む。`ios/DopaBreak/InterventionFlowView.swift` と `ios/DopaBreak/Localizable.xcstrings` から呼吸省略前提の表示・未参照キーを除去し、`ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` は呼吸・理由・summaryを新順序で個別生成する。`ios/DopaBreakTests/MeasurementFoundationTests.swift` と `ios/DopaBreakTests/InterventionFlowGateTests.swift` に新順序と両経路の回帰検証を反映した。
- 採用方針・却下案: エンジンの `beginIntentSelection()` はstart時ではなく呼吸完了時に呼ぶ方式を採用した。理由画面の表示中に `currentStep == .intentSelection` を保証しつつ、呼吸中の意図記録受付を防げ、エンジンAPI変更も不要なため。呼吸中に理由選択へ進めるテスト専用バイパスや、direct理由で呼吸を再省略する案は採用していない。
- Claude Code向け制約: `startGeneration` とTaskキャンセルによる再入ガード、呼吸完了時の `beginIntentSelection()`、`recordIntent` 後の `advanceStep`、catalog／gateTokenの後段分岐を維持する。呼吸中は `selectedReason == nil` を前提とし、旧 `intervention.duration.fast_path_note` を再導入しない。DEBUG用 `completeBreathingForTesting()` は本番と同じ完了処理を通し、スナップショットとテスト以外から使用しない。
- 検証: iPhone 17 Pro Max（iOS 26.5）SimulatorでDopaBreak本体の `xcodebuild` ビルド成功。`MeasurementFoundationTests` の関連4件と `InterventionFlowGateTests` 全3件、計7件は失敗0で `TEST SUCCEEDED`。String Catalog JSON解析、旧省略文言参照0、対象差分の `git diff --check` も成功した。

## 2026-08-29 — 設定・ホーム・端末是正バッチ Round 3 R20修正

- 作成・変更: `ios/DopaBreak/SettingsView.swift` のタイムラインDragGesture終了処理を修正し、onEndedで保留同期をflushした直後にジェスチャID・アンカー・ライブ時刻カプセルを即時クリアするようにした。120ms処理は `didDragTimelineHandle` のタップガード解除だけに限定し、状態クリア時には保留中のcleanup／10秒フェイルセーフTaskをキャンセルする。
- 採用方針・却下案: 終了済みジェスチャの状態を120ms遅延まで残す案は、再タッチが旧IDと起点を継承してハンドルを飛ばし、保留Taskが新しいドラッグへ漏れるため却下した。タップガードだけは短い遅延で解除し、ButtonとDragGestureの競合抑止を維持する。
- Claude Code向け制約: onEndedは `flushPendingTimelineShieldSync()` → `clearTimelineDragState(resetTapGuard: false)` の順を維持し、遅延Taskからgesture stateを触らない。10秒フェイルセーフの仕様と、onEnded非到達時の既存救済は変更しない。
- 検証: `swiftc -parse ios/DopaBreak/SettingsView.swift` 成功、DopaBreakCore `swift test` は518件・失敗0、Simulator向けDopaBreakビルドは `BUILD SUCCEEDED`。

## 2026-08-29 — 介入フロー順序反転の独立レビュー3件修正

- 作成・変更: `ios/DopaBreak/InterventionFlowModel.swift` は呼吸秒数を初期化時から設定値へ合わせ、停止済み呼吸Taskだけを再開するフェイルセーフを追加した。`ios/DopaBreak/BreathingCharacterView.swift` は`totalSeconds`変更時に表示タイムラインとハプティクスを再始動する。`ios/DopaBreak/InterventionFlowView.swift` は呼吸画面再表示時にフェイルセーフを呼ぶ。`ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` は呼吸撮影フローを外部所有し、撮影終了時に明示停止する。`ios/DopaBreakTests/MeasurementFoundationTests.swift` は5/8秒の開始前後と停止後再開を検証する。
- 採用方針・却下案: 初回bodyだけ3秒を許す案はカウントダウンと触覚の不一致を生むため却下し、モデル生成時点を設定値の正本にした。再開時に`start()`を再実行する案はエンジン状態と`startGeneration`を不要に更新するため採用せず、`.breathing`かつTaskなしの場合だけ同じ世代で呼吸を再始動する。
- Claude Code向け制約: `resumeBreathingIfNeeded()`は他ステージ・実行中Taskでは必ずno-opとし、`startGeneration`を変更しない。`BreathingCharacterView`の秒数変更時は経過基準とハプティクスを同時にリセットする。呼吸スナップショットは撮影関数がフローを所有し、`defer`の`stop()`を外さない。
- 検証: iPhone 17 Pro Max（iOS 26.5）Simulatorで、5/8秒の開始前後、停止後再開、世代ガード、実時間完了、direct/reflective分岐、gateToken経路を含む介入フロー関連9件は失敗0で`TEST SUCCEEDED`。DopaBreak本体は`BUILD SUCCEEDED`。

### 2026-08-29 追記 — 順序反転の最終残件解消と受け入れ確定

- 作成・変更: `ios/DopaBreak/BreathingCharacterView.swift` の `beginPlaybackIfNeeded()` hasStarted分岐で `startedAtUptime` を現在時刻へ張り直し（フェイルセーフ再開時のリング・カウントダウン位相ズレ解消）。`ios/DopaBreakTests/MeasurementFoundationTests.swift` に呼吸Task生存中の `resumeBreathingIfNeeded()` no-op検証を追加。
- 検証: Opus5独立レビュー3ラウンド（初回指摘3件→修正確認→残件確認）すべて受け入れ可・残件なし。介入フロー関連テスト最終49件失敗0・`BUILD SUCCEEDED`。Fable受け入れ確定（2026-08-29）。触覚の実際の体感・one sec的な間の質は実機検証時に確認する。

## 2026-08-31 — 介入画面の初回フレーム即時表示

- 作成・変更: `ios/DopaBreak/AppContainer.swift` はAppIntentがApp Groupへ保存した起動要求をモデル初期化中に同期消費する。`ios/DopaBreak/DopaBreakApp.swift`・`LaunchSplashView.swift` は初期要求がある起動だけ動画スプラッシュを省略する。`ios/DopaBreak/RootTabView.swift` は介入用`fullScreenCover`を廃止し、不透明なルート直置きオーバーレイへ置換した。`InterventionFlowModel.swift` はターゲット固有IDを提供し、`InterventionFlowView.swift` の提示契約コメントを更新した。`ios/project.yml` は画像なしの`LaunchBackground`単色起動面がE1 Dark Monoの`DesignTokens.background`（#0B0D0F）由来であることを明記した。回帰は`ios/DopaBreakTests/GateUnlockConsumptionTests.swift`と`LaunchSplashTests.swift`へ追加した。
- 採用方針・却下案: 初期表示と遅着要求の両方を単一の消費セマンティクスへ通し、表示開始とターゲット差し替えはアニメーションを無効化、終了だけ0.2秒のease-out opacityにした。介入の前にロック画面確認またはペイウォールが存在する場合は、そのcoverのdismiss完了後に最新ターゲットを出す。既存`fullScreenCover`の継続、初回body後の`onAppear`だけでの消費、スライド終了はホームちらつきまたは仕様不一致になるため採用していない。
- Claude Code向け制約: `AppModel.init`内の同期消費とactive時の再消費を両方維持する。オーバーレイの`.id(flowID)`、表示時の`Transaction.disablesAnimations`、終了時だけの0.2秒opacity、背景だけの`ignoresSafeArea`を外さない（フロー内容のsafe area・キーボード挙動は従来どおり）。ロック画面確認・ペイウォールのdismiss待ちを迂回して同時提示しない。介入対象が初期化時にある場合は起動動画を再生しない。
- 検証: `xcodegen generate --spec project.yml`成功。generic iOS Simulator向け全7ターゲットは`BUILD SUCCEEDED`。iPhone 17 Pro Max（iOS 26.5）の`GateUnlockConsumptionTests`・`LaunchSplashTests`は32件、`InterventionFlowGateTests`・`MeasurementFoundationTests`は38件、合計70件が失敗0で両方`TEST SUCCEEDED`。`git diff --check`、変更対象のTODO／FIXME／旧介入cover参照0を確認した。LaunchScreenはiOSキャッシュの影響があるため、実機確認時は必要に応じてアプリを再インストールする。
- 2026-08-31 独立レビュー追記: ペイウォール表示中に介入が来た場合は、旧実装の二重提示を防ぐためペイウォールを自動dismissしてから介入を提示する新挙動を維持する。
- 権利未解決でも提示する。`gateToken`の棄却判定は`GateEntitlementAccess`のfail-open（未確定時true）に委ねる。

### 2026-08-31 追記 — 介入即時表示の受け入れ確定

- 検証: Opus5独立レビュー3ラウンド（初回差し戻し: スプラッシュ遮蔽🔴＋🟡3件 → 修正確認で過剰復元ガードの再指摘 → 最終確認で残件なし）。関連4テストクラス72件失敗0をレビュアーが独立再実行で確認。Fable受け入れ確定（2026-08-31）。
- 実機の要確認2点: LaunchScreenはiOSキャッシュのため再インストールで確認する。ホームインジケータ帯のタップがオーバーレイに吸われることを実測する。

## 2026-08-31 — 介入即時表示 v2（ウォームスタートのバックグラウンドシールド）

- 作成・変更: `ios/DopaBreak/BackgroundSnapshotShield.swift` にscenePhase別の表示policy、状態コーディネータ、メインウィンドウ最上段の単色シールドhostを追加した。`ios/DopaBreak/DopaBreakApp.swift` は `LaunchSplashHost` 全体をシールドhostで包み、active処理の先頭でAppIntentの介入要求を消費する。`ios/DopaBreakTests/GateUnlockConsumptionTests.swift` はbackground／inactive／active判断と「消費中は表示、消費後に解除」の順序を検証し、`MeasurementFoundationTests.swift` は新host経由でも未オンボーディング時の初回起動記録が落ちない構成へ追従した。xcodegen生成物 `ios/DopaBreak.xcodeproj/project.pbxproj` も新規ソースを取り込んだ。
- 採用方針・却下案: シールドは `RootTabView` 内ではLaunchSplashより上へ出せないため、WindowGroup直下の専用hostを採用した。scenePhaseから単純に `phase == .background` を導出する案は、background→inactive→active復帰でactive前にホームを露出するため却下した。.inactive単独では新規表示せず、backgroundからの復帰途中では既存シールドを保持し、activeで介入要求を同期消費してから同じanimations-disabled Transaction内で解除する。純単色 `DesignTokens.background` のみで、ロゴ・コピー・遷移アニメーションは追加していない。
- Claude Code向け制約: シールド表示判断は `BackgroundSnapshotShieldPolicy.directive(for:)` を唯一の正本とし、host側へscenePhase分岐を増やさない。active時の `consumePendingIntervention()` → `isShieldVisible = false` の順序と、それらを包む `Transaction.disablesAnimations` を維持する。.inactiveで新しくシールドを出さない一方、background後のinactiveではactiveまで保持する。fullScreenCover（ロック画面確認・ペイウォール）は別presentation windowのため覆えない許容edgeであり、ホーム露出ではない。アプリスイッチャーのカードはプライバシー保護としてダーク単色になる。
- 検証: generic iOS Simulator向け全7ターゲットは `BUILD SUCCEEDED`。iPhone 17 Pro Max（iOS 26.5）で `GateUnlockConsumptionTests`、`LaunchSplashTests`、`InterventionFlowGateTests`、`MeasurementFoundationTests` の74件が失敗0で `TEST SUCCEEDED`。

### 2026-08-31 追記 — バックグラウンドシールド（v2）受け入れ確定

- Claude Code向け制約: **シールド解除と介入提示は同一更新サイクルで完結させる**（RootTabView側の提示を非同期化・遅延化するとホーム1フレーム露出が復活する）。シールド表示判定はBackgroundSnapshotShieldPolicyに集約済みで、実機でなおスナップショットにホームが写る場合はscenePhaseからdidEnterBackgroundNotification購読へ差し替える（局所変更で済む構造）。
- 検証: Opus5独立レビュー受け入れ可（方向依存遷移・解除順序・詰み経路すべて問題なし）。関連4クラス74件失敗0を独立再実行で確認。Fable受け入れ確定（2026-08-31）。

## 2026-08-31 — Live Activity密度v2: 目標5件対応と3件時の行高水増し廃止

- 作成・変更: 設計正本 `.claude/specs/live-activity-density-v2-five-goals.md` を追加し、`ios/WidgetsExtension/LockThemeLiveActivityView.swift` の全10テーマを目標1〜5件へ拡張した。`maximumGoals` と `LockSurfaceCoordinator.liveActivityGoalLimit` を3から5へ引き上げ、`densityValue` を5分岐へ置き換えた。`ios/DopaBreakTests/LockThemeLiveActivityViewTests.swift` へ4〜5件の収まりと非圧縮、3〜5件の下余白6pt以上、5件の実インク8pt以上の回帰を追加した。目視検証用に `ios/DopaBreakTests/LockThemeDensitySnapshotCapture.swift` を追加し、10テーマ×1〜5件を `output/verify/live-activity-density/` へ書き出す。
- 採用方針・却下案: オーナー実機指摘「3件で行間の余白を取りすぎ」の原因は `e1GoalMinimumHeight` が3件でも各行に2行分（約40.57pt）を強制していたこと。3件以上は1行実高+2ptへ改め、余りは行高ではなくフォントとセクション間隔へ配分した。目標フォント増分は1件+5／2件+4／3件+3（v1の+2から拡大）／4件0／5件-2、サマリー増分は1〜2件1.5／3件1／4件0.5／5件0。外側縦paddingは全件数で6pt以上とし、e1の3件時 `0` によるカード下辺への張り付きを解消した。カード高の変更、4〜5件でのeyebrow削除、2行折返しの維持（3件18ptでは高さ予算に収まらない）は採用しなかった。
- Claude Code向け制約: 160pt固定・四辺描画・水平16pt（note左46pt例外）・マーカーのcap中心整列を維持する。e1の2行折返しは1〜2件のみ、3件以上は1行。4〜5件は `minimumScaleFactor(0.55)`、3件は0.85、noteは手書きフォントが潰れるため縮小させず末尾省略で逃がす。件数別フォント増分は `goalFontIncrease`／`summaryFontIncrease` を唯一の正本として全テーマで共用する。テストの許容誤差・期待値を緩めて通すことは禁止。テストヘルパー `referenceTextCrop` はe1が2行を描く1〜2件のときだけ枠を半分に絞る（3件以上で半分にするとグリフが欠けて誤判定する）。
- 検証: `xcodegen generate` 成功。iPhone 16 Pro Simulatorで `xcodebuild test` 全281件・18skip・失敗0で `TEST SUCCEEDED`。`scripts/lint-display-copy.py` と `scripts/audit-default-values.py` はexit 0。10テーマ×3／4／5件の実描画を目視確認し、切れ・潰れ・下辺張り付きがないことを確認した（liquidGlassのサマリー白飛びはImageRendererがガラス素材を描けない既存の描画癖で、変更前も同一）。

## 2026-08-31 — Live Activity密度v2の縮小時マーカーcap中心補正

- 作成・変更: `ios/WidgetsExtension/LockThemeLiveActivityView.swift` のe1マーカーへ `scaledGoalCapCenterOffset` を追加し、gamingの3件以上向け件数補正を同ヘルパーの `unscaledOffset` へ統合した。長い日本語3件が18pt・1行・`minimumScaleFactor(0.85)`で縮小される場合も、タイトル幅から求めた実効縮小率へマーカー位置が追随する。
- 採用方針・却下案: 非縮小時は件数別のgaming補正を維持し、縮小時は固定値を加算せずcapHeightと実効縮小率から導く既存補正へ切り替える。マーカーを行ボックス中央へ戻す案、行別の固定pt調整、テストの期待値または許容誤差を緩める案は却下した。
- Claude Code向け制約: e1／gamingの `.firstTextBaseline` と `markerCenterAlignedToCapHeight`、`scaledGoalCapCenterOffset` の実効縮小率計算を維持する。gamingの件数別 `unscaledOffset` を縮小補正の外で重ねず、e1の3件密度（18pt・1行・`minimumScaleFactor(0.85)`）とマーカー整列許容±0.75ptを変更しない。
- 検証: iPhone 16 Pro Simulatorで `DopaBreakTests/LockThemeLiveActivityViewTests` 全23件・失敗0、`TEST SUCCEEDED`。長い日本語3件のマーカー中心差はe1が各行-0.5／0／-0.5pt、gamingが-0.5／0／0ptで、非縮小の1〜5件を含む全マーカー回帰も失敗0。

## 2026-08-31 — 目標一覧のロック画面表示上限注釈

- 作成・変更: `ios/DopaBreak/GoalsView.swift` の目標リスト`Section`に、目標が1件以上ある場合だけロック画面の表示上限と並べ替えを案内するフッターを追加した。行ラベルは配列順の`index`を受け取り、`LockSurfaceCoordinator.liveActivityGoalLimit`未満にはバッジを付けず、上限以上の行だけ`goals.badge.off_lock_screen`を表示する。`ios/DopaBreak/Localizable.xcstrings`では旧`goals.badge.on_lock_screen`を削除した。
- ローカライズ: `goals.footer.lock_screen_limit`と`goals.badge.off_lock_screen`をja/en/koの3言語で追加・同期した。Swift側のja `defaultValue`とカタログjaは完全一致させ、既存の`dopaFont`／`DesignTokens.secondaryText`をフッター表示へ適用した。
- 採用方針・却下案: 目標の登録数は無制限のまま保ち、Live Activityに載る先頭分だけを表示対象と明示する。先頭行だけを表示中とする旧バッジは5件表示後の事実と矛盾するため廃止し、表示対象外の行だけへ注記する。表示件数をGoalsViewへ別定数として複製する案は、Live Activity側との不整合を生むため採用していない。
- Claude Code向け制約: フッターは目標0件では表示しない。バッジ分岐は`LockSurfaceCoordinator.liveActivityGoalLimit`を唯一の上限参照とし、文言内の数値はカタログ正本のままにする。日本語の短い表示テキストへ読点を追加せず、ja/en/koの3言語と各`defaultValue`を同期する。
- 検証: `xcodegen generate`成功。指定iPhone 16 Pro Simulatorの`xcodebuild test`は282件実行・18件スキップ・失敗0で`TEST SUCCEEDED`。`python3 scripts/lint-display-copy.py`と`python3 scripts/audit-default-values.py`はともにexit 0、カタログの3言語完全一致、旧キーの実装・カタログ参照なし、`git diff --check`を確認した。

## 2026-08-31 — 一呼吸フローの時間選択と振り返り提示位置

- 作成・変更: `ios/DopaBreak/InterventionFlowModel.swift` と `InterventionFlowView.swift` はcatalog／gateTokenの両経路を時間選択へ統一し、未回答の `ReflectionLog` がある場合だけ呼吸前に `.reflection` を表示する。`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/InterventionEngine.swift` はトークンなしのcatalog用 `recordCatalogOpen(durationSeconds:)` で選択時間つきAttemptLogと `promptedAt = openedAt + duration` のReflectionLogを作り、既定の振り返り対象窓を24時間へ延長した。`ios/DopaBreak/PostUseReflectionSheet.swift` は既存5択を `PostUseReflectionContent` として共用し、`ReflectionLog.createdAt` と `promptedAt` から経過時間と宣言分数を表示する。`ios/DopaBreak/RootTabView.swift` から旧独立シート提示を削除し、`ios/DopaBreak/Localizable.xcstrings` にcatalog注意文と振り返り文脈をja/en/koで追加した。回帰は `ios/DopaBreakTests/MeasurementFoundationTests.swift`、`InterventionMergeCopyTests.swift`、`ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/InterventionEngineTests.swift` に追加・更新した。
- 採用方針・却下案: catalogは選択時間を宣言と振り返りにだけ使い、記録後のエンジン状態をidleへ戻す方式を採用した。gateTokenの `temporarilyAllowed` と再シールドは従来どおりPro経路だけに残す。振り返りはRootのアプリ復帰シートではなく次の一呼吸オーバーレイの先頭へ組み込み、回答またはスキップ後に同じフロー内でbreathingへ進める。通知で満了を知らせる案、無料ユーザーを時間で強制停止する案、ReflectionLogへ表示用フィールドを足す案は採用していない。
- Claude Code向け制約: `PostUseSatisfaction`／`HappinessDelta`／`ReflectionLog` のスキーマを変更しない。catalogの時間は自動終了や再シールドを意味しないため `intervention.duration.catalog_notice` を削除しない。振り返りの決めた分数は `promptedAt - createdAt`、経過時間は現在時刻と `promptedAt` の差から導出し、先頭ステージ以外に別提示経路を復活させない。回答・スキップ後は `beginInterventionAndBreathing(using:)` を通し、既存の呼吸世代ガードとgateTokenの権利判定を維持する。表示コピーは読点なし、Swift defaultValueとja/en/koカタログを同期する。
- 検証: `xcodegen generate` 成功。指定iPhone 16 Pro Simulatorの `xcodebuild test` は284件実行・18件スキップ・失敗0で `TEST SUCCEEDED`。`python3 scripts/lint-display-copy.py` と `python3 scripts/audit-default-values.py` はともにexit 0。catalog時間選択、catalog ReflectionLog作成、冒頭振り返り、経過時間／宣言分数、24時間境界を追加テストで確認した。

## 2026-09-01 — 開かなかった画面を取り戻した時間中心へ再設計

- 作成・変更: `ios/DopaBreak/WinScreenView.swift` に保存済み増分、累計、日数換算、全目標、節目祝いを収めた新しい成功画面と、`TimelineView` + `Canvas` による42粒・2.4秒の自前紙吹雪を追加した。`ios/DopaBreak/ReclaimedTimePresentation.swift` へHome既存の時間書式を移して共通化し、節目判定と一度だけの永続化処理も集約した。`InterventionEngine.recordCancel()` は保存した `reclaimedSeconds` を返し、`InterventionFlowModel.swift` はその値とStatsServiceの累計だけを画面状態へ渡す。`SettingsStore.swift` に到達済み最大節目を追加し、ローカルデータリセット対象へ含めた。`InterventionFlowView.swift` は旧回数中心の成功表示を廃止して新画面へ接続し、`Localizable.xcstrings` はja/en/koを同期した。回帰は `WinScreenReclaimedTimeTests.swift` とCoreテストへ追加した。
- 採用方針・却下案: 成功画面の主役は今回保存された取り戻した時間とし、累計と日数換算はHomeと同じ `ReclaimedTimeFormatter` を唯一の書式正本にした。節目は1時間、6時間、12時間、その後は累計の丸一日が増えるたびとし、今回の保存で境界を越えた場合だけ最大到達値を更新して発火する。既存利用者への遅延紙吹雪、画面側での `ReclaimedTimeEstimator` 再計算、外部紙吹雪パッケージ、先頭目標だけの表示、効果を断定するコピーは採用していない。
- Claude Code向け制約: 成功画面の増分は `recordCancel()` が返す保存値を正本とし、画面で推定し直さない。累計はStatsServiceから読み、表示は `ReclaimedTimeFormatter` をHomeと共有する。節目の永続値は単調増加かつresettableで、`previousTotalSeconds` との交差判定を外さない。Reduce Motion時は紙吹雪とカウントアップを出さず、同じ節目文言を静的に表示する。目標1〜5件を順序どおり全件表示し、閉じる操作のsafe areaを紙吹雪で覆わない。表示コピーに読点・句点、装飾英語eyebrow、時間利用の効果断定を追加せず、Swift `defaultValue` とカタログのja/en/koを完全一致させる。
- 検証: `xcodegen generate` 成功。指定iPhone 16 Pro Simulatorの `xcodebuild test` は290件実行・18件スキップ・失敗0で `TEST SUCCEEDED`。追加した6件で保存増分との一致、1〜5目標の実描画と高さ、節目境界と一度だけの発火、既存利用者への遅延発火防止、Reduce Motion、3言語コピーを確認した。DopaBreakCore `swift test` は520件・失敗0。`python3 scripts/lint-display-copy.py` と `python3 scripts/audit-default-values.py` はともにexit 0、`git diff --check` も成功した。

## 2026-09-01 — 開かなかった画面のキャラクター復元

- 変更: `ios/DopaBreak/WinScreenView.swift` の `WinScreenContent` で、節目バナーの下・増分数字の上に `CharacterView(.relief)` を復元した。サイズは `DesignTokens.CharacterSize.support`、外枠幅は `support * (96.0 / 86.0)`、背景は `DesignTokens.card`、角丸22のRoundedRectangle clip、`DesignTokens.hairline` の1px stroke、`.characterPop(.celebrate)` を旧WinScreen実装と同じ順序で適用した。
- 採用方針・却下案: 目標5件の実描画でキャラクターと全目標カードが同時に収まり、文字の切れ・重なりもなかったため、指定されたsupportサイズを維持した。目標を隠す、先頭だけに戻す、必要のない件数別縮小は採用していない。
- Claude Code向け制約: 取り戻した時間の増分・累計・節目バナー・カウントアップ・Reduce Motion時の静的表示・紙吹雪・閉じる操作のsafe areaを維持する。キャラクターは節目の有無にかかわらず表示し、目標1〜5件を順序どおり全件表示する。新しい文言キーや表示コピーは追加しない。
- 検証: `xcodegen generate && xcodebuild test -project DopaBreak.xcodeproj -scheme DopaBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` は291件実行・18件スキップ・失敗0。`-only-testing:DopaBreakTests/WinScreenSnapshotCapture` は1件・失敗0。`output/verify/win-screen/win-goals-5.png` と `win-milestone-1day.png` を原寸目視し、5件の全表示、節目→キャラクター→増分の順序、切れ・重なりなしを確認した。`python3 scripts/lint-display-copy.py` と `python3 scripts/audit-default-values.py` はexit 0、`git diff --check`も成功した。

## 2026-09-01 — 起床・就寝タイムラインのドラッグジッター修正

- 変更: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/WakeSleepTimelinePolicy.swift` は15分丸めを0:00〜23:45へクリップし、禁止帯では現在ハンドルがいる側の60分境界へ止める。ドラッグで境界へ達した後も反対側へ抜けないようにした。`ios/DopaBreak/SettingsView.swift` は起床・就寝それぞれの現在確定値をポリシーへ渡す。`ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/WakeSleepTimelinePolicyTests.swift` に右端、正逆1分スイープ、夜勤想定ピッカー交差の回帰を追加した。
- 採用方針・却下案: ドラッグは一般的な2ハンドルレンジと同様に相手を飛び越えず、ピッカーは60分以上離れた有効時刻へ従来どおり交差できる。候補に近い境界を選ぶ旧方式は固定ハンドル通過時に2時間跳ねるため廃止した。見た目、ジェスチャ世代管理、タップガード、250msシールド同期は変更していない。
- Claude Code向け制約: `current` は動かす側の確定値を渡し、ドラッグだけ15分スナップを使う。時刻ピッカーの `snapToStep: false`、成分ベースのDate変換、就寝・起床を夜間設定の唯一の正本とする構造を維持する。
- 検証: `cd ios/Packages/DopaBreakCore && swift test` は524件・失敗0。対象ポリシー12件・失敗0、`git diff --check`も成功した。

## 2026-09-01 — 起床・就寝時刻セクションの説明を常時表示

- 変更: `ios/DopaBreak/SettingsView.swift` の `wakeSleepTimelineSection` で、起床・就寝の時刻ラベル行の直後にモード別の説明文を追加した。`nightOnly` は既存の `settings.night_only.description` を再利用し、それ以外は `settings.schedule.description` を参照する。`ios/DopaBreak/Localizable.xcstrings` に `settings.schedule.description` のja/en/koを追加し、3言語とも設計書の確定文言を `translated` で登録した。
- 採用方針・却下案: 既存footnoteと同じ13pt medium・lineSpacing 3・secondaryText・縦方向の固定サイズで、タイムラインの意味をモードに関係なく同じ場所へ説明する方針を採用した。説明を夜だけ強化時だけ出す案、オンオフのトグル追加、表示条件の変更、バー・ハンドル・ラベル・ポップオーバー・ドラッグ挙動の変更は採用していない。
- Claude Code向け制約: `wakeSleepTimelineSection` は引き続き常時表示する。新説明は時刻ラベル行の下に置き、`selectedMode == .nightOnly` のときだけ既存キー、それ以外（標準・ディープフォーカス・Free）は新キーを使う。`deepFocusFootnote`、時刻の正本、バー・ハンドルの操作、ポップオーバー、既存の3言語文言を変更しない。新キーのSwift `defaultValue` とLocalizable Catalogのja/en/koは設計書の文字列と完全一致させ、未翻訳stateを残さない。
- 検証: `cd ios/Packages/DopaBreakCore && swift test` は524件・失敗0。指定のgeneric iOS Simulator向け `xcodebuild build` は `BUILD SUCCEEDED`。`python3 scripts/lint-display-copy.py` と `python3 scripts/audit-default-values.py` はexit 0、`git diff --check`も成功した。

## 2026-09-01 — ロック画面テーマ伝播・Live Activity外形・介入復帰シールド修正

- 作成・変更: `ios/DopaBreak/AppContainer.swift` にObservableな `lockThemeSelection` と単一書き込みAPI `updateLockTheme(_:)` を追加し、Home／Settings／Onboardingの選択経路を移行した。`ios/WidgetsExtension/LockThemeLiveActivityView.swift` は本番の `ContainerRelativeShape` とプレビュー22ptを切り替える外形に統一し、外周線を内側描画にした。`ios/DopaBreak/BackgroundSnapshotShield.swift` と `RootTabView.swift` は介入オーバーレイ表示までシールドを保持し、1.5秒の強制解除ウォッチドッグを追加した。回帰は `ios/DopaBreakTests/MeasurementFoundationTests.swift` に追加した。
- 採用方針・却下案: UserDefaultsをプロセス間の正本のままとし、AppModelの写しでSwiftUI観測を成立させた。Live Activityの端末依存角丸を固定値で再定義する案、先行モーダル解除待ちで無期限にシールドを保持する案は却下した。表示コピーは変更していない。
- Claude Code向け制約: テーマ書き込みは `model.updateLockTheme(_:)` に集約し、外部プロセスの書き込みは `refresh()` で差分取込する。Live Activity本番は `.containerRelative`、アプリ内は `previewCornerRadius` を使い、noteの内側破線は固定角丸を維持する。シールド保持条件はbody内で評価し、present／dismiss全経路で `isInterventionOverlayPresented` を対称更新する。
- 検証: 指定Simulator向け `xcodebuild build` は `BUILD SUCCEEDED`。`MeasurementFoundationTests` は修正前既存suiteと追加2件が成功、Live Activityの型／160pt収容／四辺描画の分割4件も成功した。全描画suite一括実行はテスト開始前のSimulator Runner bootstrapがSIGKILL、再実行はXcodeの `waiting for workers to materialize` で停滞したため分割実行した。`git diff --check` は成功。
## 2026-09-01 — 開かなかった画面へ次の節目と連続記録を追加

- 作成・変更: `ios/DopaBreak/ReclaimedTimePresentation.swift` で既存の節目閾値を単一の定義へ集約し、`ReclaimedTimeMilestone.nextThreshold(after:)` と直前節目起点の `ReclaimedTimeMilestoneProgress` を追加した。`ios/DopaBreak/AppContainer.swift` / `InterventionFlowModel.swift` / `InterventionFlowView.swift` / `WinScreenView.swift` では `StatsService.consecutiveDaysWithCancellations(endingOn:)` の結果、次の節目までの残り時間、区間進捗バーを成功画面へ接続し、目標件数別の可変間隔と表示領域への縦配分を実装した。`ios/DopaBreak/Localizable.xcstrings` はja/en/koを同期し、`ios/DopaBreakTests/WinScreenReclaimedTimeTests.swift` と `WinScreenSnapshotCapture.swift`、`output/verify/win-screen/win-*.png` を更新した。
- 採用方針・却下案: 進捗率は累計0起点ではなく直前節目→次節目の区間比率とし、残り時間は既存 `ReclaimedTimeFormatter.detailedString` を再利用した。節目回は祝いを濁らせないため進捗ブロックを隠し、連続0日は罰に見えるため非表示とした。標準 `ProgressView` はスナップショットでプラットフォームビューの描画記号が混入したため、同じ意味を持つ純SwiftUIのCapsuleバーを採用した。満足度内訳、週次グラフ、恣意的な時間換算は追加していない。
- 実装制約: 閾値を追加・変更するときは `ReclaimedTimeMilestone.fixedThresholdSeconds` と日単位規則だけを正本とし、`highestReached` と `nextThreshold` に別々の閾値を直書きしない。成功画面は1〜3目標で広め、4〜5目標で狭めの可変スペーサーを使い、キャラクターと最大5目標を同時表示する。Dynamic Typeで内容が収まらない場合は既存ScrollViewでスクロールを許容する。
- 検証: `xcodegen generate` 後の指定 `xcodebuild test` は296件実行・18件スキップ・失敗0。`WinScreenSnapshotCapture` は目標1〜5件と1時間/1日の節目回を再撮影し、通常回の進捗・連続記録、節目回の進捗非表示、下部余白の再配分を原寸確認した。`python3 scripts/lint-display-copy.py` と `python3 scripts/audit-default-values.py` はexit 0、`git diff --check` も成功した。
## 2026-09-01 — 利用後リフレクションをアプリ復帰時へ移動し装飾eyebrowを撤去

- 作成・変更: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/InterventionEngine.swift` の既定提示窓を30分へ短縮し、期限切れ未回答を既存スキップ経路で畳む `expireStaleReflections` を追加した。`ios/DopaBreak/InterventionFlowModel.swift`／`InterventionFlowView.swift` からリフレクション段階を完全削除し、`ios/DopaBreak/RootTabView.swift` で前面復帰・先行モーダル終了・介入終了後に既存 `PostUseReflectionSheet` を提示する。介入要求時はreflection sheetを閉じて一呼吸を最優先にする。`InterventionFlowView.swift`、`PostUseReflectionSheet.swift`、`OnboardingFlow.swift` から指定10個の装飾英語eyebrowを削除し、`Localizable.xcstrings` から対応キーも削除した。`ios/WidgetsExtension/Localizable.xcstrings` と `DopaBreakWidgets.swift` のwidget目標eyebrowはLive Activityと同じja/en/ko値・日本語defaultValueへ揃えた。
- 採用方針・却下案: リフレクションを次回SNS起動の先頭へ残す案は、一呼吸までに2画面を挟み前回利用の記憶が薄れた状態でも開く導線を塞ぐため却下した。30分以内にDopaBreakへ戻った場合だけ独立sheetで尋ね、期限超過は表示せず永続的にskipする。eyebrowは日本語へ置換せず、見出しを先頭へ繰り上げ、オンボーディングのstagger番号も欠番が残らないよう詰めた。ブランド名DOPABREAKと通知モック内のアプリ名は維持した。
- Claude Code向け制約: 一呼吸はlock screen check／paywall／reflectionより常に優先する。reflection提示ガードは介入・paywall・lock screen check・child modalと競合させず、`handleAppActive`、各fullScreenCoverの`onDismiss`、`runPostInterventionDismissalChecks`から再確認する。30分境界は提示対象、境界を1秒でも過ぎた未回答だけを期限切れとする。削除済み10キーと`InterventionFlowStage.reflection`を復活させない。`onboarding.welcome.eyebrow`、`onboarding.notification.preview.app_name`、`paywall.brand.pro`は残す。
- 検証: `cd ios/Packages/DopaBreakCore && swift test` は521件・失敗0。指定Simulator IDへの `xcodebuild ... build` は `BUILD SUCCEEDED`、`build-for-testing` は `TEST BUILD SUCCEEDED`。String CatalogのJSON解析、defaultValue監査（mismatch／missing 0）、削除キーと旧stage参照の不在、`git diff --check`を確認した。シミュレータ上のアプリ起動・終了は行っていない。

## 2026-09-01 — Live Activityフォント同梱先と購入後テーマ確定ルール

- 作成・変更: `ios/project.yml` / `ios/WidgetsExtension/Info.plist` で4件のテーマフォントを親アプリ直下から `WidgetsExtension.appex` へ移し、`UIAppFonts` を宣言した。`BundledFontRegistrar.swift` は自バンドル、親アプリ内の `PlugIns/WidgetsExtension.appex` と `Fonts`、祖先の順に探索し、`DopaBreakApp.swift` は既定探索で登録する。`AppContainer.swift` に非永続の `pendingProThemeSelection` と購入成立時の確定処理を追加し、`HomeView.swift` / `SettingsLockSurfaceView.swift` / `OnboardingFlow.swift` / `RootTabView.swift` の選択表示・保存・購入監視を新ルールへ統一した。`BundledFontIntegrationTests.swift` / `LockThemeLiveActivityViewTests.swift` / `MeasurementFoundationTests.swift` に配置・登録・3入口・保留なし購入の回帰を追加した。
- 採用方針・却下案: フォントは容量を増やす複製ではなくExtensionへの単一配置とし、アプリ内プレビューは埋め込みappexからプロセス登録する。無料時のProテーマタップはチェック表示用のメモリ保留だけにし、UserDefaultsへは書かず、Pro成立時だけ確定する。既存保存済みProテーマの移行リセット、永続pendingフィールド、表示コピー変更、描画負荷削減は採用していない。`apple-hig` / `apple-design` に従い既存のペイウォール方式・モーション・アクセシビリティ構造も維持した。
- Claude Code向け制約: テーマピッカーの表示値は `model.displayedLockThemeSelection`、永続値は `savedLockTheme`、実掲出値は権利ガード済み `liveLockTheme` を使い分ける。許可テーマ選択は `updateLockTheme(_:)` で保留を消して保存し、ロック済みテーマは `pendingProThemeSelection` のみ更新する。購入成立監視はRootとオンボーディングの双方で `applyPendingProThemeSelectionIfNeeded` を通す。フォント4件を親アプリ直下へ戻したり、appexとの二重配置にしない。
- 検証: `cd ios/Packages/DopaBreakCore && swift test` は524件・失敗0。指定Simulator IDへの `xcodebuild ... build` は `BUILD SUCCEEDED`、`build-for-testing` は `TEST BUILD SUCCEEDED`。成果物は `WidgetsExtension.appex` 内に `.ttf` 4件、`DopaBreak.app` 直下0件で、Extensionの `UIAppFonts` 4件も確認した。シミュレータ上のアプリ／テストランナーは起動・終了していない。`git diff --check` 成功。

## 2026-09-01 — スクリーンタイムを対象アプリの単一入口へ統合

- 作成・変更: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/ScreenTimeSingleEntryPolicy.swift` に保存済みアプリ選択・認可と介入ルートから提示可否を決める純関数を追加した。`ios/DopaBreak/AppContainer.swift` は認可をrefreshごとに更新し、FamilyControlsの保存済みApplicationToken選択と合わせて `isScreenTimeGateConfigured` を公開する。`ios/DopaBreak/RootTabView.swift` はゲート設定中のcatalog要求だけを記録前に破棄し、gateTokenを従来どおり提示する。`ios/DopaBreak/AutomationGuideView.swift` と `OnboardingFlow.swift` はゲート設定中にショートカット手順を出さず、スクリーンタイムが入口で登録済み自動化を削除できる1画面へ分岐する。`ios/ShieldConfigExtension/ShieldConfigurationExtension.swift` と同 `Localizable.xcstrings` は見出しを「このアプリは止めています」、主操作を「DopaBreakで開く」へja/en/koで同期した。回帰はCore純関数テストと `ios/DopaBreakTests/ScreenTimeSingleEntryLocalizationTests.swift` に追加した。
- 採用方針・却下案: FamilyControlsの不透明トークンをcatalogへ対応付ける案はプラットフォーム上不可能なため、スクリーンタイム設定中はシールドを唯一の入口にした。判定用の新しい永続フラグは作らず、GateShieldControllerと同じ有効ルール内のApplicationToken選択と現在認可だけを正本にした。AppSettingsの残存行だけを見る案は対象解除後も残り得るため採用せず、カテゴリ／Webドメインだけの選択も日常ゲート対象とは数えない。`apple-hig` / `apple-design` に従い既存NavigationStack、閉じる操作、Dynamic Type対応、モーションを維持し、新しい遷移や装飾は追加していない。
- Claude Code向け制約: catalog抑止は `presentPendingInterventionIfValid(_:)` の入口でのみ行い、attempt/openを記録しない。gateTokenの権利判定・提示・grant処理は変更しない。`isScreenTimeGateConfigured` は保存済みApplicationTokenが1件以上かつScreen Time認可済みの論理積で、新しいUserDefaultsやSnapshotを追加しない。ゲート設定中のAutomationGuide／オンボーディングにはShortcuts起動、動画、手順、チェックリスト、白黒化自動化を出さない。シールドの副題・副ボタンとhard window文言は維持する。
- 検証: `cd ios/Packages/DopaBreakCore && swift test` は527件・失敗0。`xcodegen generate` 後のgeneric iOS Simulator向け `xcodebuild build` は `BUILD SUCCEEDED`、`build-for-testing` は `TEST BUILD SUCCEEDED`。String Catalog JSON解析、defaultValue監査（mismatch／missing 0）、`git diff --check` は成功。表示コピーlintの3件は今回未変更の既存読点のみ。シミュレータ上のアプリ／テストランナーは起動・終了していない。

## 2026-09-01 — 起動時と前面復帰時のScreen Time認可状態同期

- 変更: `ios/DopaBreak/ScreenTimeCenter.swift` に本番既定の `AuthorizationCenter.shared.authorizationStatus` 読み取りを保持した注入可能なstatus providerを追加した。`ios/DopaBreak/AppContainer.swift` はAppModelの初回 `refresh()` でScreen Time認可を更新し、`ios/DopaBreak/DopaBreakApp.swift` はRootTabView未表示のオンボーディング中も前面復帰ごとに軽量な `screenTime.refresh()` を実行する。`ios/DopaBreakTests/ScreenTimeSingleEntryAppModelTests.swift` にSettingsを開かず、認可済み状態で `isScreenTimeGateConfigured` がtrueになる回帰を追加した。
- 採用方針・却下案: `refresh()` は認可要求や非同期処理を起こさず、AuthorizationCenterの現在statusを一度読むだけにした。RootTabViewの既存 `model.refresh()` 経路は維持し、外側のapp-active経路には重い全体refreshを重ねず直接更新する。SettingsViewへの依存や認可状態の永続フラグは追加していない。
- Claude Code向け制約: `isScreenTimeGateConfigured` は保存済みApplicationToken選択と現在の認可状態の論理積を正本とする。RootTabViewのcatalog抑止、gateToken処理、SettingsViewの認可要求、WinScreenView／ReclaimedTimePresentation／WakeSleepTimelinePolicyの既存実装は変更しない。アプリ／テストランナーをSimulator上で起動・終了しない。
- 検証: `cd ios/Packages/DopaBreakCore && swift test` は527件・失敗0。generic iOS Simulator向け `xcodebuild build` と `build-for-testing` は成功。`git diff --check` は成功。

## 2026-09-01 — 常時ゲートの標準モード限定とcatalog競合保護

- 作成・変更: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/GateShieldScope.swift` に常時ゲート対象を有効な標準モードへ限定する純関数を追加し、`ios/DopaBreak/GateShieldController.swift` と `ios/DopaBreak/AppContainer.swift` のシールド同期・Screen Time入口判定を同じ範囲へ統一した。`ios/DopaBreak/RootTabView.swift` は抑止したcatalog要求が実際に届いた場合だけ既存 `AutomationGuideView` を前面滞在ごと最大1回提示する。`InterventionFlowModel.swift` とCore policyはgateToken優先および一致要求だけを破棄する競合契約を追加し、Core／アプリテストで両到着順と移行時解除を覆った。
- 採用方針・却下案: window外でもシールドを残す方式は時間制御を無効化するため却下し、常時シールドはstandardだけ、nightOnly／deepFocusは既存の時間窓シールドだけに委ねた。catalog破棄で単一pending値を無条件nilにする方式と後着catalogによる上書きはgateToken消失を起こすため廃止し、gateToken優先＋compare-and-clearにした。案内は新画面を作らず、閉じる手段とScreen Time説明を持つ既存sheetを再利用した（`apple-hig` / `apple-design`）。
- Claude Code向け制約: `GateShieldScope.selectionData(from:)` を常時ゲートと `isScreenTimeGateConfigured` の共通正本として維持する。nightOnly／deepFocusを追加しない。catalog抑止案内はcatalog到着時だけ、前面滞在ごと最大1回で、child modal・paywall・lock screen check・reflectionを押しのけず、gateToken到着時は案内を閉じて介入を優先する。pending要求の破棄は `discardPendingInterventionTarget(ifMatching:)` を使い、無条件nilへ戻さない。
- 検証: `cd ios/Packages/DopaBreakCore && swift test` は531件・失敗0。generic iOS Simulator向け `xcodebuild build` は `BUILD SUCCEEDED`、`build-for-testing` は `TEST BUILD SUCCEEDED`。Simulator上のアプリ／テストランナーは起動・終了していない。

## 2026-09-01 — 完全ブロック画面から目標表示を削除

- 作成・変更: `ios/ShieldConfigExtension/ShieldConfigurationExtension.swift` から完全ブロック用の目標読み出しと引数の受け渡しを削除し、`hardWindowSubtitle` はDeep Focusで `shield.subtitle.fallback`、夜で `shield.night.subtitle` を常に返すようにした。`ios/ShieldConfigExtension/Localizable.xcstrings` から未参照の目標副題カタログ項目を削除した。
- 採用方針・却下案: `.hardWindow` は目標に依存しない中立的な種別別副題を採用した。`.canUnlock` のゲート判定と表示経路は変更せず、目標を残してフォールバックへ条件分岐する案は完全ブロック画面に目標が出る余地を残すため採用していない。表示コピーは既存値を再利用し、句点・読点・呼吸語を追加していない。
- Claude Code向け制約: `.hardWindow` のDeep Focus副題は `shield.subtitle.fallback`、夜副題は `shield.night.subtitle` を正本とする。旧目標副題項目、完全ブロック経路の `GoalStore` 読み出し、目標引数を復活させない。`.canUnlock` のgateToken判定、回数表示、解除アクションは維持する。
- 検証: 目標副題項目とShield拡張内のGoalStore参照は0件、hard-window副題内の `ひと呼吸`／`一呼吸` は0件。String CatalogのJSON解析、`git diff --check`、generic iOS Simulator向け `xcodebuild build` は成功した。Simulator上のアプリ／テストランナーは起動・終了していない。

## 2026-09-01 — Screen Time完全ブロックと一呼吸対象を分離（案X）

- 作成・変更: `ios/DopaBreak/SettingsView.swift` と `Localizable.xcstrings` は、一呼吸対象を既存SNSカタログ／Shortcuts、完全ブロック対象をFamilyControlsのルール選択として別カードへ分離した。同一アプリを双方へ登録でき、相互除外は行わない。`AppContainer.swift`、`RootTabView.swift`、`AutomationGuideView.swift`、`OnboardingFlow.swift`、介入フロー、通知、Shield Action／Config／Monitor、Coreのモデル・ストア・policyから常時Screen Timeゲート、gateToken、回数／cooldown／一時解除を参照ごと削除した。削除ファイルは `GateAppSettingSheet.swift`、`GateGrantController.swift`、`GateShieldController.swift`、CoreのGateModels／GatePolicy／GateStores／GateSyncPolicy／GateShieldScope／ScreenTimeSingleEntryPolicyと専用テスト群。`ios/DopaBreak.xcodeproj/project.pbxproj` はxcodegenで再生成した。
- 採用方針・却下案: オーナー追記どおり案Xを採用し、一呼吸と完全ブロックを独立した正本へ分けた。FamilyControls選択を一呼吸対象へ流用する案、常時シールドを残して入口だけ隠す案、両リスト間で同一アプリを排他にする案は却下した。夜のみ／Deep Focusの時間窓シールドは既存ルール選択と専用snapshot／ManagedSettingsストアのまま維持した。
- Claude Code向け制約: `ShieldController.syncShield` は同期の最初に旧 `dopabreak.gate` ManagedSettingsストアを無条件clearし、移行後最初の同期で既存常時シールドを解除する。この互換解除は旧ゲート機能の復活ではなく、保存トークンを読まない一方向の清掃として維持する。一呼吸はSNSカタログ＋Shortcuts、完全ブロックはFamilyControls＋Screen Time認可が正本。同一アプリの重複登録を許す。`InterventionFlowStage.durationSelection`、勝利画面のreclaimed／lifetime／estimated／consecutiveDays／milestone、`DayTimeContext`、Settingsのwake/sleep timeline処理、`settings.night_only.description` は変更しない。
- 検証: `cd ios/Packages/DopaBreakCore && swift test` は488件・失敗0。`xcodegen generate --spec project.yml` 後のgeneric iOS Simulator向け全7ターゲットは `BUILD SUCCEEDED`、テストターゲットを含む `build-for-testing` は `TEST BUILD SUCCEEDED`。2つの変更String CatalogはJSON解析成功、常時ゲート専用参照とTODO／FIXMEは0件、`git diff --check`成功。Simulator上のアプリ／テストランナーは起動・終了していない。

## 2026-09-01 — 設定コピーの手動改行撤去

- 作成・変更: `ios/DopaBreak/Localizable.xcstrings` の `settings.targets.block.description`、`settings.targets.breath.description`、`settings.targets.breath.empty_description`、`settings.authorization.body`、`settings.authorization.denied_body` をja／en／koの全15値で自然折返しへ変更した。日本語の対応 `defaultValue` は `ios/DopaBreak/SettingsView.swift` でカタログと同期した。
- 採用方針・却下案: 端末幅に依存するハードコード改行は削除し、説明文を短くして自然折返しに任せた。日本語は句点・リズム目的の読点を避け、対象と結果が読める体言止め寄りの短文にした。en／koは各言語の自然な案内へ整えた。既存のレビュー済み改行許可リストへキーを追加する案は採用していない。
- Claude Code向け制約: 5キーのja／en／ko値へ手動改行を戻さない。設定カードと認可シートの幅・Dynamic Typeによる自然折返しを維持し、日本語を変更するときは同じキーの `SettingsView.swift` の `defaultValue` も同期する。`InterventionMergeCopyTests.swift` の既存許可境界とレイアウトは変更しない。
- 検証: `InterventionMergeCopyTests` はiPhone 16 Pro Simulatorで7件・失敗0の `TEST SUCCEEDED`。String Catalog JSON解析、既定値監査（mismatch／missing／unresolved／specifier-type 0）、`git diff --check` は成功。アプリのSimulator起動・終了操作は行っていない。

## 2026-09-01 — 2つのアプリ一覧名確定と起床・就寝タイムラインの再配置

- 作成・変更: `ios/DopaBreak/Localizable.xcstrings` と関連するSwiftの `defaultValue`、Coreの選択エラー、`docs/11_ui_copy.md`、機能分離仕様を更新した。一呼吸一覧は ja=`一呼吸をはさむアプリ`／en=`Apps with a pause`／ko=`숨 고르기를 설정한 앱`、完全ブロック一覧は ja=`完全にブロックするアプリ`／en=`Apps to block`／ko=`차단할 앱` を正本とし、旧 `settings.target.apps` は未参照のため削除した。`ios/DopaBreak/SettingsView.swift` は `wakeSleepTimelineSection` の呼び出しを完全ブロックカード内へ移し、外側の `CardContainer` だけを外して二重カードを避けた。
- 採用方針・却下案: 英韓は直訳を作らず、既存の `home.targets.title` と完全ブロック語彙をそのまま一覧名へ採用した。曖昧な「止めるアプリ」、設定だけ異なる `Apps for a pause`／`숨 고르기를 넣을 앱`、タイムラインを独立カードのまま残す案は却下した。HIGの近接・グルーピング原則に合わせ、完全ブロック対象、Screen Time状態、時間範囲を1カードにまとめた。
- Claude Code向け制約: `wakeSleepTimelineSection` の表示内容、`wakeSleepTimelineDescription`、`timelineBar`、`timelineHandle`、`updateTimeline` は変更していない。タイムラインは完全ブロックカードの末尾に置き、カードを入れ子にしない。一呼吸一覧と完全ブロック一覧は保存先も用途も別で、同じアプリを両方へ登録できる既存契約を維持する。
- 検証: DopaBreakCoreは488件・失敗0、generic iOS Simulatorビルドは `BUILD SUCCEEDED`、`InterventionMergeCopyTests` は7件・失敗0で `TEST SUCCEEDED`。String Catalog JSON解析、`止めるアプリ` の実装・正本文書内残存0、defaultValue監査 mismatch／missing／unresolved 0、`git diff --check` を確認した。Simulatorアプリの手動起動・終了操作は行っていない。

## 2026-09-01 — 設定本文5キーの述語付き文章化

- 作成・変更: `ios/DopaBreak/Localizable.xcstrings` の `settings.targets.block.description`、`settings.targets.breath.description`、`settings.targets.breath.empty_description`、`settings.authorization.body`、`settings.authorization.denied_body` をja／en／koで更新し、`ios/DopaBreak/SettingsView.swift` の日本語 `defaultValue` 5件も同期した。
- 採用方針・却下案: 本文中の体言止め・断片を全角スペースで連結する案を廃止し、各言語で述語を持つ短い文章へ分割した。日本語で一覧を指す箇所は承認済み名称の「一呼吸をはさむアプリ」「完全にブロックするアプリ」をそのまま使い、読点は条件節と主節の境界に必要な箇所だけに限定した。英語と韓国語は日本語の語順を写さず、各言語の設定画面として自然な案内にした。
- Claude Code向け制約: この5キーを断片列や全角スペース区切りへ戻さない。日本語本文は述語を持つです／ます調を維持し、一覧を指す場合は承認済み名称を変えない。jaのカタログ値を変更するときは `SettingsView.swift` の同一キーの `defaultValue` も同期する。全言語とも値に手動改行を入れない。
- 検証: String CatalogのJSON解析、対象15値の手動改行／全角スペース0件、defaultValue監査、`git diff --check` が成功。generic iOS Simulator向けDopaBreakビルドは `BUILD SUCCEEDED`。iPhone 17 Pro Max（iOS 26.5）で `DopaBreakTests/InterventionMergeCopyTests` は7件・失敗0、`TEST SUCCEEDED`。Simulatorアプリの手動起動・終了操作は行っていない。日本語カタログは `一呼吸` 42件、`ひと呼吸` 2件で混在しており、依頼どおり表記統一は未実施。

## 2026-09-02 — 宣言終了時刻に振り返り通知を届ける（案A）

- 作成・変更: Coreの `InterventionEngine.swift` は保存した `ReflectionLog` を返し、`ReflectionNotificationPolicy.swift`、`NotificationRouting.swift`、`FunnelEventStore.swift`、`SettingsStore.swift`、`AppModels.swift` に終了時刻ポリシー、固定通知ID、振り返りルート、計測イベント、既定ON設定を追加した。アプリ側は `ReflectionNotificationScheduler.swift` を新設し、`AppContainer.swift`、`InterventionFlowModel.swift`、`LockSurfaceCoordinator.swift`、`RootTabView.swift`、`PostUseReflectionSheet.swift` で予約・置換・タップ・回答／スキップ・削除を接続した。`SettingsNotificationsView.swift` と `SettingsView.swift` に通知Toggleを追加し、`Localizable.xcstrings` をja／en／koで同期した。Core／アプリの関連テストも追加・更新した。
- 採用方針・却下案: 通知は介入開始時ではなく、保存済みReflectionの `promptedAt` を唯一の発火時刻にし、同一固定IDで常に最新宣言へ置換する案Aを採用した。通常のロック面通知更新に混ぜる案、通知タップで期限切れReflectionを失効させる案、通知許可を再要求する案は採用していない。`apple-hig` に従い設定は既存Form内の標準Toggle行とし、独自画面・独自ジェスチャ・追加モーションは作っていない。
- Claude Code向け制約: 振り返り通知IDは `dopabreak.reflection.prompt` の1件固定で、予約前にpending／deliveredを両方除去する。許可状態は `.authorized`／`.provisional`／`.ephemeral` のみ予約可とし、`.notDetermined` で認可要求しない。通知タップは未回答Reflectionかつ `promptedAt ... promptedAt+3h` の範囲だけシートを開き、期限切れをexpireしない。通常の `refreshNotifications`／`reconcileDelivered` の削除対象へこのIDを含めず、Toggle OFF、回答／スキップ、全削除の各経路ではpending／deliveredを除去する。設定ToggleをONにした時点では過去分を予約しない。
- 検証: `cd ios/Packages/DopaBreakCore && swift test` は494件・失敗0。`xcodegen generate --spec project.yml` 後、iPhone 17 Pro（iOS 26.5）で `DopaBreakTests` は278件（18件スキップ）・失敗0。対象差分の `git diff --check` とString CatalogのJSON解析に成功した。

### 2026-09-02 — レビュー後の訂正（§11）

- 作成・変更: `ios/DopaBreak/ReflectionNotificationScheduler.swift` と `ios/DopaBreak/AppContainer.swift` は通知予約を同期発行し、`UIApplication.beginBackgroundTask` から `add(_:withCompletionHandler:)` 完了まで実行時間を確保する構成へ変更した。`ios/DopaBreak/RootTabView.swift` は未回答を3時間で畳み、通知タップ計測を提示ガードより前へ移した。`ios/DopaBreak/SettingsNotificationsView.swift` は振り返り通知Toggle変更後にも `refreshLockSurfaces()` を呼ぶ。Core／アプリのテストも3時間窓と置換後の発火日時まで検証する形へ更新した。
- 採用方針・却下案: 正しい固定IDは `NotificationRouting.swift` の `dopabreak.reflection.prompt`。通知許可を事前に非同期取得する案は背面移行時の取りこぼしを避けるため廃止し、予約要求を即時発行して未許可時はcompletionのエラーとして扱う。自発提示窓は30分のまま、未回答の失効だけ3時間に揃え、30分〜3時間は通知タップ時だけ回答できる方針とした。
- Claude Code向け制約: 通常の通知再同期は `LockSurfaceCoordinator.performNotificationReschedule`／`removeInvalidatedNotificationRequests` であり、振り返り通知を通常再同期の削除対象へ混ぜない。予約直前には同じ固定IDのdelivered通知を削除し、成功イベントは `add` のcompletionが成功した場合だけ記録する。Background Taskはcompletionとexpirationのどちらでも一度だけ終了する。
- 検証: `ios/Packages/DopaBreakCore` の `swift test` は496件・失敗0。iPhone 17 Pro（iOS 26.5）Simulatorでscheme `DopaBreak` の `DopaBreakTests` は278件（18件スキップ）・失敗0、`TEST SUCCEEDED`。

## 2026-09-02 — P0修正バッチA（A-1〜A-4）

- 作成・変更: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/CatalogAllowanceStore.swift` と同テストを新設し、カタログアプリの宣言終了時刻までの許可をApp Groupへ保存するようにした。`InterventionFlowModel.swift`／`InterventionFlowView.swift`／`AppContainer.swift` は有効な許可中の再起動を記録・振り返り・通知なしのパススルーへ分岐する。`NonTargetAutomation.swift`／`NonTargetAutomationSheet.swift`／`RootTabView.swift` は削除済み・権利縮退済み対象の自動化起動を説明シートへ案内する。`PurchaseContinuation.swift` とPaywall／設定／対象選択の接続で購入後の操作を一度だけ再開する。Screen Time認可状態、完全ブロック設定数、起床・就寝時刻の既定値補完を `AppContainer.swift`／`ScreenTimeCenter.swift` に公開した。文字列は `Localizable.xcstrings` のja／en／koへ追加し、新規Swiftファイルは `xcodegen generate --spec project.yml` で `ios/DopaBreak.xcodeproj/project.pbxproj` に反映した。
- 採用方針・却下案: 有効期限の判定を保存時ではなく読取時にも行い、対象削除・権利縮退では許可を即時失効させる方針を採用した。対象外自動化は通常の介入へ誤接続せず、Apple標準のNavigationStack付きシート、明示的な閉じる操作、既存ボタン階層、Button＋chevronの折りたたみによる削除手順で説明する。自動で別画面へ遷移する案、独自ジェスチャや追加モーション、購入前操作を推測して複数回再生する案は採用していない。バッチB／Cの画面・ロジックは変更していない。
- Claude Code向け制約: パススルーは約0.6秒後に同じURLを開くだけで、`recordOpen`、Reflection作成、通知予約、介入試行記録を行わない。購入継続は `.addTarget`／`.applyMode` の単発値で、購入成功時は継続処理を適用してからPaywallを閉じ、無料状態で閉じた場合は破棄する。標準プランでは完全ブロック対象を保存せずfalseを返す。`blockTargetRuleCount` は保存済み完全ブロック選択と起床・就寝は合算しない。時刻の既定値保存は `ensureWakeSleepDefaults` が別途行う。A-1〜A-4以外を実装する場合も、これらの公開状態と副作用境界を維持する。
- 検証: DopaBreakCoreは500件・失敗0。iPhone 17 Pro SimulatorのDopaBreakTestsは286件（18件スキップ）・失敗0。表示文言lintと既定値監査はともに終了コード0、String Catalog JSON解析と `git diff --check` も成功した。

## 2026-09-02 — P0修正バッチB（B-1〜B-5）

- 作成・変更: `ios/DopaBreak/OnboardingFlow.swift` にProの完全ブロック設定ステップ、Shortcuts設定の初期／試行待ち／検収済み状態、オンボ内購入継続、未検収の要約／完了導線を追加した。`ios/DopaBreak/AutomationGuideView.swift` は正しい7手順と動画カードを `AutomationGuideStepList` として共有した。`ios/DopaBreak/AppContainer.swift` は保留中の自動化要求を検収だけ記録して消費する経路を通常介入と共有した。`ios/DopaBreak/PaywallView.swift` は注入可能な通知認可プロバイダで許可済み／未決定／拒否を出し分けた。`ios/DopaBreak/Localizable.xcstrings` はja／en／koを同期し、旧5手順・模式図・完了画面の旧テスト文言を削除した。`ios/DopaBreakTests/MeasurementFoundationTests.swift` は18ステップ、検収状態遷移、通知認可マッピングを検証する。
- 採用方針・却下案: `apple-hig`／`apple-design` に従いFamilyActivityPicker、標準sheet、システム認可要求、44pt以上の操作領域を再利用し、独自の許可画面・独自ジェスチャ・追加モーションは採用していない。Shortcutsを開いた時点で準備完了にする案は却下し、対象アプリの起動要求と保存済み検収IDの一致だけを完了条件にした。通知未許可時に終了前通知を約束する案は却下し、未決定は許可CTA、拒否は設定CTAだけを表示する。
- Claude Code向け制約: `blockSetup` は `prePaywallSummary` の次、`ready` の前で、Proかつ `selectedMode.usesShield` の場合だけ表示する。「あとで設定する」は必ず標準モードへ戻す。オンボの購入継続はローカル単発値で、無料のままPaywallを閉じたら破棄する。検収だけの消費はAttempt／Reflection／介入を開始せず、通常消費と同じ検収マーク・イベント・通知取消を使う。共有7手順は `AutomationGuideStepList` を正本とし、旧 `onboarding.automation.step1...5` と `onboarding.automation.mock.*` を復活させない。Paywallの2／3日前Pickerは通知許可済みだけ表示する。
- 検証: DopaBreakCoreは500件・失敗0。iPhone 17 Pro SimulatorのDopaBreakTestsは289件（18件スキップ）・失敗0。表示文言lintと既定値監査はともに終了コード0、String Catalog JSON解析と `git diff --check` も成功した。

### 2026-09-02 — P0修正バッチA記録の訂正（A-5）

- 訂正: 直前のバッチA記録にある `blockTargetRuleCount` は、起床・就寝ルールを合算せず、保存済みの完全ブロック選択データを持つ有効ルールだけを数える。起床・就寝時刻の既定値保存は `ensureWakeSleepDefaults()` が担当する。
- 訂正: 非対象自動化シートの削除手順は `DisclosureGroup` ではなく、Buttonとchevronで展開する既存実装を正本とする。

## 2026-09-02 — P0修正 A-5 とバッチC

- 作成・変更: `ios/DopaBreak/PurchaseContinuation.swift` と `ios/DopaBreak/AppContainer.swift` は購入継続へ作成時刻と30分の有効期限を持たせ、対象追加前にクランプ復元を完了し、期限切れ要求とPro確定時の空要求を破棄するようにした。期限切れ直後のパススルーは通常介入へ戻し、標準モードの完全ブロック保存失敗は説明を返す。`ios/DopaBreak/RootTabView.swift` はロック画面チェック・ペイウォール・振り返り終了後に非対象自動化を再評価し、非対象シートからのPro導線をシート終了後に提示する。`ios/DopaBreak/HomeView.swift` は一呼吸対象と完全ブロック状態を別行へ分離し、未設定状態と設定CTA、件数と時間帯を表示する。`ios/DopaBreak/SettingsView.swift` は標準モードから完全ブロック対象を選ぶ前に標準alertで夜だけ強化／ディープフォーカスを確定させ、モード別説明と夜だけ強化の空対象注記を追加した。`ios/DopaBreak/Localizable.xcstrings` は新規表示をja／en／koで同期し、`ios/DopaBreakTests/InterventionRoutingTests.swift` はクランプ復元後の重複防止、30分失効、期限切れパススルー、保存防御を検証する。`.claude/release-check/device-verification-runbook.md` §8 へ追記し、夜だけ強化中の重複対象でシールドだけが出ることの実機確認手順を記録した。
- 採用方針・却下案: 一呼吸のアイコン横へ完全ブロックの「開けません」を残さず、完全ブロックは件数・時間帯・稼働状態を独立行で示す。標準モードからの対象選択は暗黙に夜だけ強化へ変えず、Apple標準alertの3操作で本人に選ばせる。非対象シートからペイウォールを出すための固定100ms待機は廃止し、sheetの `onDismiss` を提示境界にした。購入継続は永続化せず、30分を過ぎた操作を購入後に再生しない。
- Claude Code向け制約: `PurchaseContinuation` の対象追加は `reconcileSelectedTargetsWithEntitlement()` 後の選択へ適用し、既存対象を重複させない。Pro確定時は継続actionが成立しなくても必ず値を消す。`requestPassThrough` の期限切れは無言終了させず通常介入へ送る。Homeの「開けません」は `isBlockConfigured` がtrueのときだけ表示し、一呼吸アイコン列と完全ブロック状態行を再混在させない。標準モードの `saveBlockedAppSelection` は保存せずfalseを返し、呼び出し側は必ず説明を提示する。夜だけ強化の空対象注記を維持し、ディープフォーカス固有の窓なし判定を夜だけ強化へ流用しない。`OnboardingFlow.swift`、`AutomationGuideView.swift`、`PaywallView.swift` は今回変更していない。
- 検証: DopaBreakCoreは500件・失敗0。iPhone 17 Pro SimulatorのDopaBreakTestsは292件（18件スキップ）・失敗0。表示文言lintと既定値監査はともに終了コード0、String Catalog JSON解析、`xcodegen generate --spec project.yml`、`git diff --check` も成功した。

## 2026-09-02 — P0修正 A-6 振り返り通知からSNSへ戻る実機バグ

- 作成・変更: Coreへ `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/AutomationRequestPolicy.swift` と同テストを追加し、自動化要求の60秒鮮度と同一アプリ自己起動の20秒除外を純粋関数化した。`SettingsStore.swift`／`StartInterventionIntent.swift`／`FunnelEventStore.swift` は要求時刻、自己起動記録、破棄イベントをApp Groupと計測へ接続した。アプリ側の `InterventionFlowModel.swift`／`AppContainer.swift`／`DopaBreakApp.swift`／`RootTabView.swift` はURL起動完了時の保留解除、期限切れ通過の破棄、振り返り宛先による通過抑止を実装した。`ios/DopaBreakTests/InterventionRoutingTests.swift` とCore既存テストを更新し、`.claude/release-check/device-verification-runbook.md` §8へ8-14を追加した。新規ファイル反映のため `ios/project.yml` からXcodeプロジェクトを再生成した。
- 採用方針・却下案: 通過画面の遅延dismissだけに依存せず、SNS URLのopen completionを保留要求の寿命境界にした。自動化要求は検収記録を先に残したうえで、60秒超または同一アプリの自己起動20秒未満を表示なしで破棄する。振り返り通知と有効な通過が競合するときだけ振り返りを優先し、許可が無く通常の一呼吸が必要な起動は従来どおり最優先とした。振り返り全体を常に一呼吸より優先する案、30分の自発振り返り窓や通知仕様を変える案は採用していない。
- Claude Code向け制約: `pendingStartInterventionRequestedAt` はAppIntentが要求本体と同時に書き、消費時はcatalogID／autoResolveと一緒に必ず消す。`lastSelfOpenedCatalogID`／`lastSelfOpenedAt` は通常・通過のURL起動直前だけ更新する。鮮度は60秒ちょうどを有効、自己起動除外は20秒未満だけとし、別catalogIDは除外しない。URL起動完了で一致する `pendingInterventionTarget` だけを消し、別要求への置換を壊さない。期限切れ通過は初期表示と前面中の再提示の両方でアニメなしに破棄する。表示コピー、30分の振り返り窓、案A通知、`recordOpen` は変更していない。
- 検証: DopaBreakCoreは506件・失敗0。iPhone 17 Pro（iOS 26.5）SimulatorのDopaBreakTestsは298件（18件スキップ）・失敗0。表示文言lintと既定値監査はともに終了コード0。`xcodegen generate --spec project.yml` を実行済み。

## 2026-09-02 — Statsアプリ別カードの対象範囲を文言で明示

- 作成・変更: `ios/DopaBreak/StatsView.swift` の `appsCard` で見出しを「一呼吸をはさんだアプリ」へ変更し、空状態を「まだ一呼吸の記録がありません」へ変更した。見出し直下には `stats.apps.caption` を常時表示し、完全ブロック対象がこの集計に含まれないことを示した。`ios/DopaBreak/Localizable.xcstrings` は `stats.apps.title`／`stats.apps.empty` をja／en／koで更新し、`stats.apps.caption` を3言語すべて `translated` で追加した。
- 採用方針・却下案: `appsCard` の集計は一呼吸のAttemptをrule単位で集計する既存仕様のままとし、完全ブロック対象を表示する案や集計側を変更する案は採用していない。注記は見出しの直下、既存VStackの `spacing: 10` に任せ、空状態でも消えない位置へ置いた。
- Claude Code向け制約: `StatsAppMetric`、`appMetrics`、`iconSource`、`StatsService`、および集計・挙動は変更しない。Swiftのja `defaultValue` とカタログのja／en／koは指定文字列から変更せず、注記へ新たなpaddingや句読点を追加しない。
- 検証: String CatalogのJSON解析、3キー×3言語の値と `translated` 状態の一致、Swift構文／ビルド確認を実施する。

## 2026-09-02 — 起床・就寝時刻セクションを夜だけ強化時のみ表示

- 変更: `ios/DopaBreak/SettingsView.swift` の `targetLengthAutomationSection` で `SettingsDivider()` と `wakeSleepTimelineSection` を `selectedMode == .nightOnly` の条件内へ移した。`wakeSleepTimelineSection` の `InterventionMode.nightOnly.detailText` バッジは常時表示とし、`wakeSleepTimelineDescription` は `settings.night_only.description` を常に返す形へ整理した。`ios/DopaBreak/Localizable.xcstrings` の同キーをja／en／koの確定文言へ更新し、到達不能な `settings.schedule.description` エントリを削除した。
- 採用方針・却下案: 起床・就寝時刻は夜だけ強化の完全ブロック窓にだけ関係するため、標準・ディープフォーカスではセクション自体を表示しない。既存のタイムライン操作、時刻変換、モード選択、他の説明文は変更していない。標準・ディープフォーカス向け説明を残す案は到達不能キーと誤解を残すため採用していない。
- Claude Code向け制約: `wakeSleepTimelineSection` は `selectedMode == .nightOnly` の呼び出し条件を維持し、ヘッダーの夜だけ強化バッジ、`settings.night_only.description` のja／en／ko値、`SettingsView.swift` 内の同キーの日本語 `defaultValue` を改変しない。`settings.schedule.description` を復活させない。
- 検証: `swiftc -parse ios/DopaBreak/SettingsView.swift`、`jq empty ios/DopaBreak/Localizable.xcstrings`、3言語値と削除キーの機械照合、対象2ファイルの `git diff --check` が成功した。指示により `xcodebuild` は実行していない。

## 2026-09-02 — DopaBreak自己起動と完全ブロック自己巻き込みの予防

- 作成・変更: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/AutomationRequestPolicy.swift` は要求鮮度を10秒へ短縮し、自己起動反響を消費時刻ではなく要求作成時刻で判定するよう変更した。`ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/AutomationRequestPolicyTests.swift` は10秒／8秒の境界、受け入れ条件5ケース、自己起動より前の要求を追加した。`ios/DopaBreak/SettingsView.swift` と `ios/DopaBreak/OnboardingFlow.swift` はFamilyActivityPickerのfooter注意書きと、カテゴリ選択時に保存を保留する標準alertを追加した。`ios/DopaBreak/Localizable.xcstrings` は新規5キーをja／en／koすべてtranslatedで追加した。
- 採用方針・却下案: 不透明なApplicationTokenから自アプリを推測するフィルタは採用せず、ピッカー内の事前注意とカテゴリ保存直前の明示確認で事故を予防する。カテゴリなしは従来どおり即保存し、カテゴリありは「このまま保存」だけが既存保存処理を呼ぶ。「選び直す」は選択を保持したままピッカーを再提示する。Apple標準のFamilyActivityPickerと2操作alertを使い、独自モーダルや解除口は追加していない。
- Claude Code向け制約: `AutomationRequestPolicy.decision` のシグネチャ、stale優先、一発限りの自己起動記録クリアは維持する。自己起動判定は同一catalogIDかつ `requestedAt >= lastSelfOpenedAt` かつ差が8秒未満、鮮度は10秒ちょうどまで有効とする。2画面ともカテゴリが1件以上なら保存前確認を必須とし、「選び直す」で選択を初期化しない。`ShieldController`、`ShieldActionExtension`、`saveBlockedAppSelection` の契約は変更しない。
- 検証: DopaBreakCoreは516件・失敗0。アプリは検証専用Xcodeプロジェクトでビルド成功し、DopaBreakTests全299件を安定性のため296件一括＋長時間保持2件＋OCR1件に分けて実行し、18件skip・失敗0を確認した。表示文言lintと既定値監査はexit 0、String CatalogのJSON解析と対象差分の `git diff --check` も成功した。

## 2026-09-03 — Statsを「取り戻した時間」中心へ再設計

- 作成・変更: `ios/DopaBreak/StatsView.swift` を期間別の取り戻した時間を主役に再構成し、`ios/DopaBreak/HourBars.swift` と `ios/DopaBreakTests/StatsReclaimedTimeTests.swift` を新設した。`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SQLiteLogStore.swift`、`Services/StatsService.swift`、`Tests/DopaBreakCoreTests/StatsServiceTests.swift` へrule別・intent別の取り戻した秒数と開始時刻／時間帯集計を追加した。`ios/DopaBreak/Localizable.xcstrings` は比較、時間帯、時間表示に必要なja／en／koを同期した。
- 採用方針・却下案: `apple-design` と `apple-hig` に従い、今日・今週・全期間で同じ情報階層を保ち、最大56ptの時間、根拠、内訳の順に読める構成を採用した。回数を主役のまま残す案、週以外にも曜日棒を出す案、全期間で前週比較を見せる案は却下した。週／全期間には24時間棒を置き、最大時間帯は最初の同率時刻をアクセント表示し、データ5件以上だけ文章で補足する。Reduce Motion時は暗黙アニメーションを無効化する。
- Claude Code向け制約: Ledgerの期間条件は `recordedAt >= start && recordedAt < end`、Attempt開始時刻も同じ半開区間を維持する。intentがnilのLedgerはintent内訳に含めない。旧anxietyはcommunicationへ秒数と回数の両方を合算する。アプリ別／目的別は取り戻した秒数の降順、同値は既存の安定順で並べる。`DayBars` は週だけ、`HourBars` は週と全期間だけ表示し、0件の棒は2pt、最大棒は56pt、軸ラベルは0／6／12／18時を維持する。
- 検証: DopaBreakCoreは516件・失敗0。generic iOS Simulatorビルドは `BUILD SUCCEEDED`。通常アプリテストは外部撮影用の長時間Captureハーネスを除く285件が失敗0で、Stats専用XCTest 5件は `TEST EXECUTE SUCCEEDED`。表示文言lintと既定値監査は終了コード0、String Catalog JSON解析、対象キー3言語、旧キー／TODO残存、`git diff --check` を確認した。

## 2026-09-03 — Stats取り戻した時間レビュー差し戻し修正

- 作成・変更: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SQLiteLogStore.swift` と `Services/StatsService.swift` に、`attempt_logs.started_at` の半開区間で台帳総秒数・rule別秒数・intent別秒数を集計するAPIを追加した。`ios/DopaBreak/StatsView.swift` は今日／今週のヒーロー、アプリ別、理由別、先週比を同じ開始時刻窓へ統一し、根拠行の回数もlegendと同じ `dashboard.summary.cancelled` を正本にした。全期間とホーム向けの既存 `recorded_at` APIは維持した。
- UI修正: `ios/DopaBreak/HourBars.swift` は非0バーを計算後2pt以上へclampし、56pt領域の下端へ固定した。可視ピーク事実を出さない5件未満ではVoiceOverにもピークを含めない。`ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` のStatsServiceへUTC固定Calendarを注入した。未参照の `MetricBlock` と `stats.rate.unavailable` は参照0を再確認後に削除し、`stats.metric.count` のen複数形 `%lld times` が存在することを確認した。
- 採用方針・却下案: 記録画面内で台帳の `recorded_at` と試行の `started_at` を混在させる案は、日跨ぎ時にヒーロー・内訳・件数がずれるため却下した。`reloadDashboard` のバックグラウンド化と全期間書式の変更は本差し戻しの対象外として行っていない。比較文はja／en／koの実カタログ書式から組み立て、同じローカライズ済み差分文字列の範囲だけをaccentにする。
- Claude Code向け制約: Statsの今日／今週に `reclaimedSeconds(from:to:)`、`reclaimedSecondsByRule(from:to:)`、`reclaimedSecondsByIntent(from:to:)` を戻さない。3集計は必ず同じ `a.started_at >= start && a.started_at < end` を使い、根拠行とlegendはどちらも `summary.cancelled` を使う。全期間は従来のall-time／`recorded_at`経路を維持する。HourBarsは空・非0とも最小2pt、最大56pt、ピーク事実は合計5件以上だけという条件を表示とアクセシビリティで共有する。
- 検証: DopaBreakCore `swift test` は517件・失敗0。iPhone 16 Pro（iOS 26.5）の `xcodebuild test` 全スイートは310件・18skip・失敗0。日跨ぎシードでアプリ別秒数合計＝ヒーロー秒数、intent付き理由別秒数合計＝ヒーロー秒数、根拠行回数＝legend回数を固定した。`python3 scripts/lint-display-copy.py` と `python3 scripts/audit-default-values.py` はexit 0、xcstrings JSON解析、参照0確認、`git diff --check`も成功した。
## 2026-09-03 — 朝の目標通知廃止レビュー是正

- 作成・変更: `ios/DopaBreak/LockSurfaceCoordinator.swift` と `ios/DopaBreak/AppContainer.swift` で廃止済み通知の掃除を独立化し、refreshの読み取り成否にかかわらず実行するようにした。`ios/DopaBreak/OnboardingFlow.swift` と `ios/DopaBreak/Localizable.xcstrings` は通知許可の理由をja／en／koで明示した。`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SettingsStore.swift` と同テストは退役キー削除と週次通知の固定7:00既定を実装し、関連ランブック・バックログ・i18n一覧を現仕様へ更新した。
- 採用方針・却下案: 廃止通知の掃除は通知権限や記録ストアの状態に依存させず、既存の再予約経路からも同じメソッドを呼ぶ。通知許可画面は指定コピーのみを更新し、タイトル・カード・CTA・認可処理・レイアウト変更は採用していない。週次通知の未保存時刻を起床時刻へ追従させる案は根拠がないため廃止し、7:00固定とした。
- Claude Code向け制約: `purgeRetiredNotifications()` は `AppModel.refresh` のdefer内と再予約処理の双方から呼ぶ。`morningNotificationMinutes` のキー文字列は既存設定移行のため維持し、退役した `morningNotificationEnabled` は `legacyResettable` だけで管理する。オンボの `onboarding.notification.lead` は3言語とSwiftのja既定値を同期したままにする。
- 検証: DopaBreakCoreは520件・失敗0。iPhone 16 Pro SimulatorのDopaBreakビルドは成功。既定値監査はmismatches=0／missing=0、JSON解析と `git diff --check` も成功した。
## 2026-09-03 — 対象から外したアプリのショートカット自動化を消させる

- 前提事実: iOSにはアプリ側からユーザーのショートカット自動化を削除・無効化するAPIがない。対象から外しても自動化が残る限り、そのアプリを開けばDopaBreakは前面に出る。**この遷移自体はコードで止められない**ため、対策は「外した瞬間に事実を伝えて削除へ送る」ことと「発火後の再発火ループを止める」ことに絞った。
- 作成・変更: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/TargetRemovalNoticePolicy.swift` に案内可否の純関数を新設した（`SNSAppCatalog` に存在し、かつ `verifiedAutomationCatalogIDs` に含まれるときだけ `true`）。`ios/DopaBreak/TargetAppPickerSheet.swift` は削除分岐の保存成功時のみApple標準アラートを出し、`shortcuts://` へ送る。`ios/DopaBreak/AppContainer.swift` に `markSelfOpened(catalogID:)` を新設し、`ios/DopaBreak/RootTabView.swift` の `openNonTargetAutomationApp` と `ios/DopaBreak/InterventionFlowModel.swift` の直書き2箇所を同メソッドへ集約した。`ios/DopaBreak/NonTargetAutomationSheet.swift` の削除手順に「ショートカットを開く」を追加した。
- 採用方針・却下案: 発火時の説明シートは残す（削除を促す唯一の接点であり「対象に戻す」導線も兼ねるため）。黙って元アプリへ返す案は却下した。**削除手順の「ショートカットを開く」ボタンは `.removed` 経路に限定し、`.clampedByEntitlement`（Pro失効でクランプ）には出さない**。あちらは本文が「Proを再開するか この自動化を削除してください」と2択を出す課金導線であり、削除側だけワンタップに軽くすると再課金の理由が減るため。既存のディスクロージャと手順テキストは両経路のまま変えていない。
- Claude Code向け制約: 案内は保存成功時のみ出す（保存失敗時はまだ対象のままで、案内がエラー文言と矛盾するため）。`markSelfOpened` は `UIApplication.shared.open` より**前**に呼び、`lastSelfOpenedCatalogID` と `lastSelfOpenedAt` の両方を書く。`TargetAppPickerSheet` へは `settingsStore` を渡さず `AppModel.verifiedAutomationCatalogIDs`（読み取り専用）を経由する。`NonTargetAutomationSheet` は `target_app_picker.automation_notice.action.open` を共有し、重複キーを作らない。
- 検証: DopaBreakCore `swift test` は524件・失敗0。iPhone 16 Proの `xcodebuild test` は317件・18skip・失敗0。`lint-display-copy.py` と `audit-default-values.py` はexit 0（calls=762／mismatches=0／missing=0）。シミュレータで案内アラート、`.removed` のボタン表示、`.clampedByEntitlement` のボタン非表示を実画面で確認した。**実機のみ未確認**: 「そのまま開く」で対象アプリへ戻ったあとシートが再表示されないこと（Instagram実体が要るため）。

## 2026-09-03 — 止めるアプリ選択カードを縦組みへ（オーナー指示・実装済み）

- オーナー指摘: 「ひと呼吸挟むアプリ選ぶ画面でアイコンの横にSNS名書いてるけど見えてない」。名称を消すか、名称が見える配置にするかの二択を提示された。
- 原因: `TargetAppGrid.appCard` が `HStack(アイコン → 名称 → Spacer → 選択丸)` で、2列グリッドの1枚が約170pt。アイコン60ptと選択丸24ptを引くと名称の取り分が約34ptしかなく、`minimumScaleFactor(0.72)` の下限まで縮んでも "Instagram" / "Facebook" / "YouTube" が入らず潰れていた。
- 決定: 名称は残し配置を変える。Threads・Safari・Xはアイコン単体だと判別しづらく、選択の確信度が落ちるため。
- 実装: `ios/DopaBreak/TargetAppGrid.swift` のみ変更。カードを `VStack(アイコン → 中央寄せ名称)` へ変え、選択丸は `.overlay(alignment: .topTrailing)` に上下左右10ptインセットで逃がして名称の幅を占有させない。`Layout` に `labelSpacing`（regular 8 / large 10）を追加し、`hStackSpacing` を削除。`minHeight` は regular 72→108、large 96→124。`minimumScaleFactor` は 0.72→0.85、`multilineTextAlignment(.center)` を追加。アイコン寸法50/60、文字15/17、インジケータ22/24、gridSpacing 8/12、内側パディングは2026-08-24のオーナー指示どおり据え置き。
- 維持: 2列／アクセシビリティサイズ1列の分岐、押下scale 0.985、選択丸の `DopaMotion.select` 補間と `phaseAnimator` 1.0→1.08→1.0、Reduce Motion分岐、カード背景・枠線・clip/contentShape、`accessibilityLabel` と `.isSelected`、`onboardingStagger`、`onToggle`。`TargetAppPickerSheet.swift` と `OnboardingFlow.swift` は未変更。
- 検証: iPhone 16 Pro Maxで `testCaptureRedesignPhase1Screens` を再撮影し `output/screenshots/redesign-phase1/target-picker.png`（1320×2868）で8件全ての名称表示を確認。加えてiPhone 16 Proシミュレータへ実インストールし、オンボーディング07/18「止めたいアプリを選ぶ」（style .regular）でも8件の名称と選択時のライム枠・右上ドットを目視確認した。ビルドは `xcodebuild ... build` でSUCCEEDED。
- Claude Code向け制約: 選択丸はカードの `clipShape` より内側のoverlayに置き、名称と同じ行に戻さない。`minHeight` を108/124より下げると縦組みが潰れる。オンボーディングの `.regular` とシートの `.large` は同一 `appCard` を共有するため、片側だけの分岐を足さない。
- 追記（同日・オーナー指摘反映）: 対象外シートの折返しと配置を是正した。削除手順は `automation.non_target.delete_steps` の矢印1本を廃止し、`automation.non_target.delete_step.1〜.3`（ja/en/ko）へ分けて番号バッジ付きの1行1ステップへ組み替えた。**短縮ではなく分割を選んだのは、短縮だと文字サイズを上げたときに同じ壊れ方へ戻るため**。旧キーは参照0を確認して削除した。見出し `automation.non_target.title` は ja のみカタログ値に改行を持たせ「Instagramは / 一呼吸の対象外です」で割る（オーナー明示指示・2026-09-03）。改行を持つ翻訳のときだけ `lineLimit` を行数固定し `minimumScaleFactor(0.6)` を当てる。en/ko は改行を持たないので自然折返しのまま。`ios/DopaBreakTests/InterventionMergeCopyTests.swift` の `approvedManualLineBreaks` に `automation.non_target.title::ja` を承認日つきで追加した（この許可リストと完全一致で検査されるため）。見出しと本文は中央揃えにした（下部CTA付きの訴求シートであり iOS Large Title 文脈ではないため）。手順リスト・ボタン・ディスクロージャは左揃え／既存のまま。既定サイズとAX2の両方で見出し2行・手順各1行を実画面で確認した。

## 2026-09-04 — App Storeスクショ03（ロック画面）の目標を各国データ準拠の4件構成へ差し替え

- 決定（オーナー）: 目標は4件構成（人生→期限つき→習慣→今日）。ja/en-US/koは翻訳関係にせず、各国の抱負・生活目標調査で多数派が掲げる目標に差し替えた。期限つき枠は ja=TOEIC／ko=토익（簿記3級は「目標として弱すぎる」で却下）。en-USの人生枠は「kids」だと子どものいない人に響かないため "More time with family and friends"（APA 2025 調査項目そのまま・53%）に広げた
- 確定文言・根拠・変更箇所の正本: `.claude/specs/appstore-screenshot-goals-4-locale-2026-09-04.md`
- データ根拠の要点: 日本＝健康27.9%／お金16.4%（メディアシーク N=8,495）、社会人TOEIC受験者は就業者の約1.07%、「読書」は抱負ランキングに出現せず。米国＝金銭64%／健康60%／家族友人53%（APA Stress in America 2025 Q4010 N=3,199）、語学の選択肢は主要3調査のどこにも存在しない。韓国＝영어 잘하고 싶다 89.2%（実行12.6%）、운동53.8%≒저축51.9%（트렌드모니터）。主要数値はFableが一次ソースを開いて照合済み
- 幅の裏取り: Live Activity実機は3件以上で1行固定・末尾省略、4件時15pt bold、使用可能幅332pt。全文言をSF bold 15ptで実測し最長291pt（縮まず収まる）。3件に戻すと18ptに拡大して溢れる文言があるため4件で固定
- 実装（Codex利用上限のためOpus5 L3・レビューは別Opus5）: `LOCK_GOALS`／`goalSeeds`／`live_activity.goal.eyebrow` en を "Your goals" へ（DopaBreak・WidgetsExtension 両カタログ。生成スクリプトはWidgetsExtension側を読む）。`LOCK_ACTIVITY_CARD_BOX` top 1860→1796（カード高さ420→484px、下端2280は固定）。iPad側の幾何定数は下端基準のため無変更
- 再生成: iphone-69・ipad-13（3ロケール）＋ `upload-order/` 同期。iphone-65 は生成経路がなく iphone-69 の `sips` 縮小派生（既存手順どおり）。旧設定との制御比較で差分は03のみ
- 残課題（1行・未着手）: ja の iphone-65／ipad-13 の非ロック画面パネルは8/28以前の raw-core 由来で iphone-69 と不一致。ASCアップロード前に ja を全再派生する
- Claude Code向け制約: 目標文言を変える時は `LOCK_GOALS` と `goalSeeds` を必ず同時に同じ文字列で更新し、SF bold 15ptで332pt以内を実測してから出す。3件構成へ戻さない

## 2026-09-04 — 保留中のProテーマは「デザインを選ぶ導線」からの購入でだけ反映する

- 決定（オーナー）: 「オンボーディングや有料デザイン選択以外の画面からペイウォールでProにした場合はデフォルトのLiveActivityデザインになるようにして。」保留を持ち込めるのは `settingsThemeGate` / `homeThemeGate` / `onboardingPrepaywallSummary` / `onboardingModeGate` / `onboardingTargetAppGate` の5つだけ。残る5つ（`settingsProStatusRow` / `settingsTargetAppLimit` / `settingsFamilyActivityLimit` / `settingsModeGate` / `weekly`）は購入しても既定の `.e1` のままにする
- 設計正本: `.claude/specs/lock-theme-pending-selection-placement-2026-09-04.md`
- 破棄は**購入時ではなく提示時**に行う。購入時に消すと、ペイウォールを開いている間ピッカーが「Proにするとこのデザインになります」と言い続けたのに結果が違う、という食い違いが出るため
- 作成・変更: `PaywallView.swift` に `PendingProThemePaywallPolicy`（10 placement を全列挙・`default` なし）を追加し、`PaywallView.onAppear` で否の placement のとき `model?.pendingProThemeSelection = nil` を実行する。破棄はファネル計測の `didRecordAppearance` ガードの**外**に置く（`fullScreenCover(item:)` は nil を挟まない placement 差し替えでビュー同一性と `@State` を保つため、ガード内だと破棄が飛ぶ）。計測の順序と回数は不変
- **レビューで見つかった別経路の同一不具合（修正済み）**: `HomeView.isAnyChildModalPresented` が `pendingThemePaywallPlacement` を数えておらず、ピッカーを閉じてからペイウォールが出るまで `model.isChildModalActive` が false へ落ちる。その隙に `RootTabView.checkPendingWeeklyPaywall()` が割り込むと週次ペイウォールが先に出て保留が捨てられる（＝ホームで選んで買ったのにデフォルトに戻る）。実測で **0.002〜0.015秒** false・ペイウォール提示は0.045秒。`|| pendingThemePaywallPlacement != nil` を足して塞いだ
- 検証（Fable実測・専用シミュレータ 7A632C5C・`.deriveddata-fable`）: 対象10件 TEST SUCCEEDED ／ アプリ全体 322件・18スキップ・0失敗 TEST SUCCEEDED（並行セッションが作業中の `ShieldArmingStateTests` `ShieldControllerRetiredGateTests` は除外。この2スイートの失敗は当該セッションの未完了作業で、課金・テーマ経路と無関係）／ Core 530件0失敗 ／ lint 2本 exit 0
- ネガティブコントロール: 週次割り込みのテストは初版が空虚だった（20ms刻みのサンプリングが0.013秒の窓を跨いだ）。`layoutIfNeeded()` を毎tick挟む1ms刻みへ変えて、`HomeView` の修正だけ戻すと落ちることを隔離コピーで確認済み
- 採用しなかった指摘（記録）: ①`PaywallView.model` を非Optionalにする（4つの提示経路はすべて `model:` を渡しており今日は問題なし。テスト2件へAppModel構築が波及するため見送り）②テストスキームの TestAction へ StoreKit 設定を追加 ③権利が提示直前に届くサブフレーム窓
- Claude Code向け制約: **新しいペイウォール導線を足すときは必ず `model:` を渡す**（渡さないと保留の破棄も `applyPurchaseContinuationIfNeeded` も効かない）。`PaywallPlacement` にケースを足すと `PendingProThemePaywallPolicy` がコンパイルエラーになるので、そこで持ち込み可否を必ず決める。永続値 `settingsStore.lockTheme` は購入時に書き換えない（解約→再課金で以前のテーマが戻る挙動を守るため）
- 未対応（既知）: 設定＞アカウントの「購入を復元」はペイウォールを経ないため、保留テーマが反映されうる

## 2026-09-04 — K-POPテーマの★左のピンク縦バーを廃止（★のX位置は据え置き）

- 決定（オーナー）: 「kpopデザインのリストの星マークの左の縦線はいらない」。K-POPロックテーマの目標行から、★の左にあった5pt幅のピンク縦バーを削除する
- 削除したのはバーだけ。★のサイズ・色・`baselineOffset`・目標テキストとの spacing 7・trailing 8 は変更しない
- 変更: `ios/WidgetsExtension/LockThemeLiveActivityView.swift` の `private var kpop`。`Rectangle().fill(rgb(238,52,137)).frame(width: 5 * markerScale)` と、それを包んでいた内側 `HStack(spacing: 7)` を削除し、`.frame(height:)` `.offset(...)` `.layoutAnchor(.goalMarker(index))` `.markerCenterAlignedToCapHeight(of:)` を★の `Text` へ順序どおり移設した
- 目標行へ `.padding(.leading, 5 * markerScale + 7)` を追加した。理由は2つある。①バーを消したまま詰めると★が `TicketStubShape` の左ノッチ（行minX中心・半径4pt）に重なる ②`scaledGoalCapCenterOffset(availableWidth: 324)` はハードコードのため、目標テキストの実利用幅が変わると整列が狂う。削除したバー幅＋spacingと同値にしたので、両方とも変更前と同じ状態に戻る。固定値12ではなく `markerScale` 由来にして密度差でもズレないようにした
- 検証（実レンダリングの画素比較）: ★のインクX座標は目標1〜5件のすべてでバー削除前と完全一致（1件 30.667pt / 5件 28.000pt）。ノッチは12〜20ptなので最悪ケースでも8ptのクリアランスがある
- テスト: `ios/DopaBreakTests/LockThemeLiveActivityViewTests.swift` の `independentMarkerCrop` から、K-POP専用の「縦バーのx範囲を除外して★を独立測定する」分岐と未使用になった `goalCount` 引数を削除した。バーが無くなり、マーカー領域はそのまま★を指すため
- **1358行の制約を一部無効化する**: 「K-POPの★測定は縦バーのx範囲を含めず」は今回で不要になった。`glyphCapCenterOffset` による★のbaselineOffset補正と `markerCenterAlignedToCapHeight` は引き続き必要なので削除しない
- 途中で入った依頼外の変更を撤回した記録: 実装1周目に `goalCount == 2` を `<= 2` へ変えたが、paddingでX位置を戻した後に実測すると delta の絶対値が両者0.5で同等だった。オリジナルの `== 2` へ戻してある
- 体制: Codexが利用上限（復帰 2026-09-07 11:27）のため、実装はOpus5サブエージェント（effort xhigh）、レビューは別インスタンスのOpus5が担当
- Claude Code向け制約: バーを復活させない。★の左余白は `5 * markerScale + 7` を維持する。この値を変えると★がノッチに重なるか、`availableWidth: 324` との整合が崩れて整列テストが落ちる

## 2026-09-04 — 対象アプリの入れ替えを無料でも許可 ＋ 追加直後のショートカット案内

- 前提事実（シミュレータで再現・推測ではない）: 無料枠1個の状態で対象アプリを外し、別のアプリを対象にすると、外したアプリのショートカット自動化が残っているため そのアプリを開くと「〇〇は一呼吸の対象外です」シートが出る。このとき `RootTabView.canRestoreNonTargetAutomation` が `canAddTargetTokens(currentCount:)` で判定するため「2個目の追加」と見なされ、主ボタンが「Proを再開する」になりペイウォールへ落ちていた。本文は「対象に戻すか 自動化を削除してください」と案内しており、画面上にその経路が無い矛盾があった。加えて一度もProを買っていない人にも「再開」と表示していた。ふたつ目の報告として、オンボーディング以外で対象アプリを追加したときに `AutomationGuideView` を提示する経路がコード上に存在せず、ホームのバナーだけが手掛かりだった。
- オーナー決定（2026-09-04）: ①**入れ替えを許可する**（枠は1個のまま・ペイウォールを出さない）②**追加直後に案内を自動提示する**。
- 作成・変更: `NonTargetAutomationRestorePolicy`（Core・純関数）を新設し `.add` / `.swap(displacedCatalogIDs:)` / `.requiresPro` を返す。`resultingCatalogIDs` は `(既存から復帰対象を除いた列 + 復帰対象).suffix(limit)` で決定的に並べる。`RootTabView` は `canRestoreNonTargetAutomation` を廃してこのポリシーへ委譲し、`NonTargetAutomationSheet` は決定に応じて文言とボタンを出し分ける。`TargetAppPickerSheet` に `onTargetAdded` / `onTargetRemoved` を追加し、`HomeView` / `SettingsView` が未検収アプリの追加を予約してピッカーのdismissで案内を開く。xcstringsへ4キー（swap / swap_generic × ボタン・本文）をja/en/koで追加。
- 採用方針・却下案: `.clampedByEntitlement`（Pro失効クランプ）は**従来どおりペイウォールへ流す**（2026-09-03の決定を維持。あちらは再課金の導線であり、削除側だけ軽くすると再課金の理由が消える）。無料枠の個数、`EntitlementGate` の上限定義、ピッカー側の「2個目でペイウォール」は変更していない。押し出しが複数または名前解決できない場合に実名を出す案は却下し、汎用文言へ倒した（消えるアプリを取り違えて伝えるより、名前を出さないほうが安全）。`limit == 0` で `.swap([])` を返す防御分岐も却下し `.requiresPro` にした（全消し＋非対象で介入開始になるため）。
- Claude Code向け制約: `NonTargetAutomationReason` はアプリターゲット宣言でCoreから参照できないため、Core側に同値の `Reason` を持ち `RootTabView` で網羅switch変換する（ケース追加時にビルドが落ちる形を保つ）。案内の予約は catalogID の `Set` で持ち、削除時に取り消し、提示時に空にする。予約は `isAnyChildModalPresented` に必ず含める（含めないとピッカーのdismissと `checkPending*` が同一ターンで走り、モーダルが1枚落ちる）。ホームのペイウォール提示は設定画面と同じ100ms遅延を通す。保存失敗は `model.alertMessage` ではなくシート内インラインで出す（シートを提示している側のアラートはSwiftUIが出さない）。対象リストの読み取り失敗は0件扱いにしない。

## 2026-09-04 — ペイウォール見出しを「人生の{Y}年」へ＋見出しブロックの中央揃え＋機能行4→6

- 決定（オーナー・引用可能な記録）: 「1,A／2,約いらない／3,入れない」＝ 見出し1行目は案A `「あと5分」が人生の{Y}年`／見出しに「約」は入れない／2行目の対抗案は入れず `開く前にブレーキ` を維持。設計正本は `.claude/specs/paywall-headline-v2.md`（§2.1b の対抗案Bは実装しない）
- なぜ変えるか: 旧見出し `「あと5分」が1年で{N}日` は、O-03r →O-08b →ペイウォールで同じ日数を3回見せる再掲であり、直前の山場「50年で 人生の約5.2年」より弱い単位へ戻っていた（ピークエンドの「エンド」が弱い）。軽量ユーザーでは「年11日」となり「大したことない」と読める。人生換算なら1.5年で意味が残る
- 作成・変更: `ios/DopaBreak/LossEstimatePresentation.swift` を新設し、`OnboardingFlow` の私有ヘルパー `dailyTimeText(minutes:)` / `lifetimeYearsText(yearlyDays:)` をここへ移設（オンボーディングとペイウォールで**同じ書式を二重実装しない**）。`PaywallView` は `resolvedDailyMinutes(snapshot:)` を追加し、`resolvedYearlyDays` と同じフォールバック（既定バケット「2-4時間」→150分／38日）で解決する。`header` を `alignment: .center` にし、`DOPABREAK PRO` overlay を `.topLeading`→`.top`、見出し2行・推計注記・サブコピーへ `multilineTextAlignment(.center)` と `frame(maxWidth: .infinity)` を当てた。新キー `paywall.header.estimate_note` をja/en/koで追加し、`line1.prefix` / `line1.suffix` を差し替えた
- 採用方針（実画面レビュー後の最終形）: `featureList` / `planList` / `trialReminderCard` / `legalArea` / `fixedActionBar` と外側の `VStack(alignment: .leading)` は**触っていない**（チェックリストは左揃えのままが読みやすい）。見出しは**1行目・2行目とも `dopaDisplayClamp()`（1行固定＋縮小下限0.5＋AX2打ち止め）**で、他の大見出しと同じ扱いにする。`DOPABREAK PRO` ラベルは **`.topLeading`（padding 14）のまま**で、中央化するのは見出し2行・推計注記・サブコピーだけ。en は **` years gone`（全体29字）**を採用する
- 数値の扱い: {Y} は `LossEstimator.lifetimeYears(fromYearlyDays:)` を `%.1f` で表示（Core側で切り捨て済み・**四捨五入しない**）。{T} は SelfCheck の1日の利用時間。どちらも固定値のハードコード禁止。50年という前提は推計注記に必ず出す（docs/07 O-03r 2026-07-29 と同じ景表法上の根拠）。accent色は{Y}の数値だけで、前後の語は本文色のまま。**既知の挙動変更**: `dailyTimeText` は `String(format:)`（locale なし）で組むため、小数点にカンマを使う地域でも O-03r の「1日約2.5時間」は `2.5` のまま出る（{Y} と同じ扱いで一貫させた・許容）
- 検証（専用シミュレータ `PaywallV2-QA` 8317C79C ／ `-derivedDataPath .deriveddata-paywall-v2`）: `xcodegen generate` → BUILD SUCCEEDED。アプリ層 `xcodebuild test` は **324件・18スキップ・0失敗・TEST SUCCEEDED**（並行セッション作業中の `ShieldArmingStateTests` 7件 と `ShieldControllerRetiredGateTests` 4件 を `-skip-testing` で除外。ピア基準334件との差 -10 は「除外11件 + 新規1件」で説明がつく）。`lint-display-copy.py` exit 0（既存の要確認3件のみ・新規なし）、`audit-default-values.py` exit 0（calls=765／mismatches=0／missing=0）、`git diff --check` exit 0
- 実画面（最終・`PaywallV2-Shots3` 27B456CE・設定→Proの案内行から提示・`output/screenshots/paywall-headline-v2/{ja,en,ko,en-xxxl}.png`）: ja `「あと5分」が人生の5.2年`／en `“5 more min” = 5.2 years gone`／ko `'5분만 더'가 인생의 5.2년` の3言語とも**1行・末尾省略（…）なし**。見出し・注記・本文は中央揃え、{Y}のみライム、注記は見出し直下、機能行6件、`DOPABREAK PRO` はキャラクターに掛からない左上。XXXL（Dynamic Type最大）でも en は1行に収まる（`en-xxxl.png`）
- **実画面レビューでの差し戻し3件（同日・オーナー確認後に修正）**: ①`DOPABREAK PRO` ラベルを `.top` にすると3言語ともキャラクターの頭に重なるため `.topLeading`（padding 14）へ戻した（中央揃えは見出し・注記・本文だけに留める）②1行目の `lineLimit(2)` は en を3行（`“5 more min” = 5.2 years` / `of life` / `Pause before you open`）にしたため、2行目と同じ `lineLimit(1)` + `minimumScaleFactor(0.78)` へ戻し、en suffix を ` years of life`（32字）から ` years gone`（29字）へ短縮して1行に収めた③さらにレビュー指摘で XXXL（Dynamic Type最大）を実測すると `minimumScaleFactor(0.78)` では en が「years g…」と切れたため、両行を `dopaDisplayClamp()` へ寄せた（`output/screenshots/paywall-headline-v2/en-xxxl.png` が修正後）。なお `DOPABREAK PRO` ラベル自体はXXXLでキャラクターに掛かるが、これは `SmallLabel` 既存の挙動で今回の変更点ではない
- **追加スコープ（同日オーナー指示・spec §7）**: 機能行を4→6行にした。順序は アプリ無制限 → 完全ブロック → **週単位のスケジュールブロック（新設 `paywall.feature.weekly_schedule`）** → 就寝中ブロック → **刺激を軽減する白黒モード（新設 `paywall.feature.grayscale`）** → ロック画面デザイン。実体は前者が Deep Focus の毎週の予定（`settings.deep_focus.schedule.*`・`DeepFocusScheduler`。Deep FocusはPro限定）、後者が Deep Focus 選択時のみ出す `AutomationGuideView` のカラーフィルタ案内（`shouldShowGrayscaleGuidance`）
- **白黒モードのリスク（記録）**: カラーフィルタはiOSショートカット側の機能で、権利ゲートで制御できない＝Freeでも端末設定で再現できる。Pro行として掲出する以上「Proを買ったのに自分で設定が要る」型の不満・返金が残りうる。Fableがこの懸念を先に伝えた上でオーナーが再度指示したため実装した
- Claude Code向け制約: 見出しの数値は**必ず** `LossEstimatePresentation` 経由で出す（`String(format:)` を画面側に書き直すと丸め方針が割れる）。推計注記の50年の明示を消さない。`paywall.header.*` に句読点（、。）とハードコード `\n` を入れない。`header` の中央揃えを外側の `VStack(alignment: .leading)` へ広げない。機能行を増減するときは docs/15 §3.2b の表・docs/11 §5・docs/06 §10・i18n-launch-inventory を同じバッチで揃える（行数を固定するテストはないため、ズレても自動では落ちない）

## 2026-09-04 — 設定画面に白黒モードの導線を新設（全ユーザー常時表示）

- 決定（オーナー）: 「設定画面に白黒モードの導線を作ってそこから案内して。手順書を見せて設定させて」
- 背景: 白黒の手順案内は `AutomationGuideView` の中にしか無く、しかも Deep Focus を選んだ時だけ表示されていた（2026-08-10のオーナー指示による設計）。標準モードのユーザーは存在に気づけなかった。「白黒」という語も他の画面には一切出ていなかった
- 置き場所: 設定の「一呼吸」カード内、`settings.target.automation`（開く前の一呼吸を設定）の直下に `SettingsDivider()` を挟んで新しい行を置く。同じ対象アプリに対する同じショートカットの設定なので、この並びが最も見つけやすい
- **ゲートしない**: Deep Focus でも Pro でも出し分けず全ユーザーに常時表示する。実体はiOSのカラーフィルタの手順案内で、技術的なゲートが存在しないため。行に「設定済み／未設定」の状態は出さない（iOS側のカラーフィルタの状態はアプリから取得できない。取れない状態を表示すると嘘になる）
- 作成・変更: `ios/DopaBreak/AutomationGuideView.swift` に `GrayscaleGuideStepsSection`（3ステップ＋手動設定カード＋注記の共通部）と新規シート `GrayscaleGuideSheet` を追加。`ios/DopaBreak/SettingsView.swift` に `grayscaleGuideRow` と `isGrayscaleGuidePresented` を追加。文言は `settings.target.grayscale` と `grayscale_guide.lead` の2キーをja/en/koで追加
- **新規ファイルを作らなかった理由**: `.xcodeproj` は XcodeGen 生成物でgit未追跡。新規 `.swift` を足すと `xcodegen generate` が要るが、同じツリーで他セッションが同時にビルド中だったため再生成を避けた
- **`AutomationGuideView` の既存セクションは残す**: この画面は App Store スクリーンショット10（`10-grayscale-guide`）の被写体で、撮影テストがスクロール位置を固定値で指定している（本ファイル 2026-08-25 の節）。共通化にあたり描画結果を1ptも変えないことを条件にした
- 検証: 実装側が880×18000pxの全文レンダリングで変更前後の画素差0（15,840,000画素中0）とScrollView contentSize 4435.0pt一致を実測。独立レビュー側は移動コードのバイト同一性と、`VStack(spacing:16)`／`LazyVStack(spacing:24)` での親子抽出前後の実測（いずれも差0pt）で構造的等価性を追認した。ビルド成功・DopaBreakTests 336件0失敗・`audit-default-values.py` calls=776 mismatches=0・`lint-display-copy.py` exit 0
- 共通部の `body` は VStack で包まず3兄弟をそのまま返す形にした。包むと親スタックの spacing 構造が変わるため
- `isAnyChildModalPresented` に新しいシートを必ず含めた。ここに入れ忘れると、白黒シート提示中に `RootTabView` の週次ペイウォールやロック画面確認が割り込み、どちらかが落ちる
- 体制: Codexが利用上限（復帰 2026-09-07 11:27）のため、実装はOpus5サブエージェント（effort xhigh）、レビューは別インスタンスのOpus5が担当
- **決定（オーナー・2026-09-05）: 白黒モードは無料。ペイウォールの機能欄に載せない。** 理由は①アプリが実行しない唯一の項目でiOSの設定手順の案内にすぎない ②誰でも無料でできるためゲートが成立しない ③手順書を機能として売ると返金・低評価を招く（過去に課金クレームが多発した経緯） ④実装のない機能の掲出は誤解を招く表示と有利誤認の余地がある ⑤無料に置いた方が継続が上がり本命の課金導線への到達が増える。機能欄は実装を伴う5行のままにする（埋め草を足して6行にしない）
- 確認（2026-09-05）: `PaywallView.featureList` は unlimited_apps / deep_focus / weekly_schedule / night_block / lock_theme の5行で、白黒の行は描画されていない。設定の導線もモードや権利で出し分けていない。決定と実装は一致している
- 残件: カタログの `paywall.feature.grayscale`（ja/en/ko）が描画されないまま残っており、`ios/DopaBreakTests/MeasurementFoundationTests.swift` が値を固定している。ペイウォール担当セッションの持ち物なので本セッションでは触らない。上の決定により**この孤児キーをペイウォールへ配線してはならない**
- 既知の負債（低）: 新シートの `openShortcutsApp()` と「ショートカットAppが見つかりません」アラートが `AutomationGuideView` 側と逐語で重複し、App Store ID `915249334` が2箇所にある。今の挙動は完全一致だが、片方だけ直すと乖離する
- Claude Code向け制約: `AutomationGuideView` の白黒まわりを触るときは、スクショ10のスクロール位置が動かないことを実描画で確かめてから出す。設定の行にiOS側の状態表示を足さない。新シートを増やすときは `isAnyChildModalPresented` へ必ず登録する

## 2026-09-05 — one sec・Opalとの競合比較と改善候補の監査（調査のみ）

- 作成: `.claude/specs/competitive-product-audit-2026-09-05.md`、`competitor-profiles/one-sec-2026-09-05.md`、`competitor-profiles/opal-2026-09-05.md`、`competitor-profiles/_summary-2026-09-05.md`。外部調査の取得結果8件を `competitor-profiles/raw/cross-competitor/2026-09-05/` に保存。既存の競合資料と実装ソースは上書きしていない。
- 結果: 公開前の対応4件、追加を強く勧める8件、次に検討する12件、後回しの8候補を整理した。**採否・実装は未決定**。明確な指摘は、科学的背景の57%が原著の「起動回数」なのに日本語UIでは「利用時間」になっていること、ブロック状態の表示に権利確認・監視失敗とのずれが残ること、白黒設定の無料提供とPro便益表示が食い違うこと。
- 提案方針: 理由選択画面から直接「開かない」、常設のロック画面ウィジェット、任意の利用中再介入、複数予定、本人の振り返りを次の設定へ返す機能を優先候補とする。全面刷新、大量の介入種類、AIコーチ、タスク管理への拡張は初回リリース前には勧めない。リリース条件へ大きな追加機能の全件実装を積み増す意図はない。
- Claude Code向け制約: 9/1の「入口=ショートカット／時間制御=Screen Time」と2リスト、朝の目標通知廃止、権利未確認時に既存Proを破壊しない方針を維持する。再介入を採用しても常時ゲートの復活とは扱わない。白黒便益・Pro失効後の削除導線の指摘は過去のオーナー決定を把握した上での再検討提案であり、撤回済みと読まない。オフラインでも検証済み権利を取得できる場合はあるため「機内モードなら必ず動かない」と断定しない。
- 競合前提の更新: one secには感情・意図・会話型Reflection等がある。「振り返り一般が唯一無二」は現行比較として使わない。ただしDopaBreakの利用後5択と完全に同じ設計とは確認していない。Opalの旧ヘルプと現行Rulesベースのヘルプを区別する。無料枠は公式ページ間でも不一致のため未確定扱い。
- 検証範囲: コードの静的な経路確認、公式サイト・現行ヘルプ・日米App Store・PNAS原著・Apple資料を照合。今回はビルド・テスト・実機操作・見た目のレンダリング監査・ASCライブ価格照会は実施していない。既存の実機未確認項目は未確認のまま。

## 2026-09-05 — 競合監査で挙げた改善を実装

- オーナー依頼: 「LiveActivityはいつ終わる？ 利用中の再介入って実装できる？ 実際の利用時間って情報取れるんだっけ？ 他は実装」。直前の回答のその他の改善を実装。質問対象の3領域（Live Activity/常設Widget、利用中再介入、実利用時間Report）は今回は保留。バックアップ等、監査報告の追加候補すべてまで採用したとは扱わない。
- 成果物: `.claude/specs/competitive-improvements-implementation-2026-09-05.md` に詳細・移行・実機手順・3点への回答とApple/one sec出典を記載。アプリは `InterventionFlowModel.swift` / `InterventionFlowView.swift` の直接キャンセル、`SettingsView.swift` / `AppContainer.swift` / `DeepFocusScheduler.swift` / Coreの予定モデル・保存・窓判定の2予定化、`StrictSessionExitView.swift` と手動セッションの強化、Core `ReflectionInsightPolicy.swift` と `StatsView.swift` / `RootTabView.swift` の設定見直し導線を追加。
- 採用方針: デザインは既存のSwiftUI・ダークカード・ライムを維持。2予定は共通の対象リストを使い、曜日・時刻を別々に編集。週次14＋セッション1＋夜間1の最大16監視に抑える。旧予定1をそのまま引き継ぎ、夜間との併用は新しい明示的オプトインに限定する。過去の非稼働予定が更新だけで動く移行案は却下。
- 強いブロック: 有限の手動セッションだけに追加し、通常解除・モード/対象変更・セッション置換をモデル/スケジューラでも拒否。緊急解除は保存した開始日時から30秒待機後に行う。緊急解除は手動枠だけで、別の予定/就寝枠を外さない。無期限の強いロック・回数制限付き緊急パス・iOS権限取消やデータ削除まで封じる案は採用しない。UIに制約を明記。ホーム/設定のモーダル集約にも解除シートを含めた。
- 状態・コピー: `ShieldArmingState.swift` で監視失敗も通知し、ホームの未確認状態を成功表示しない。再試行導線追加。部分監視失敗で登録できなかった曜日をSnapshotから除き、前面Shieldも実際の控えの窓を使う。重なる予定・就寝・手動の終了表示を結合し、手動終了通知も他ブロック継続を説明。`OnboardingFlow.swift` の57%を利用時間から対象アプリ起動回数へ修正。`PaywallView.swift` の白黒Pro便益を除外し、対応カタログ内の登録数上限解放という表現に変更（9/4の白黒特典掲出判断は今回の改善実装で更新、Freeの案内は維持）。ja/en/koとdocs 06/11/15・i18n一覧を同期。
- 振り返り: 選択期間に5回答以上かつlostTime/feltWorseが60%以上の場合にだけ、実件数と設定へのリンクを提示。自動変更・利用時間推定・医学的推論はしない。アプリ/時間帯別の高度な分析は未実装。
- 検証: Core 558件0失敗、専用iOS 26.5 Simulator `DopaBreak-Competitive-QA` でアプリ全体343件・18スキップ・0失敗、最終変更に関係する101件・1スキップ・0失敗。日英韓のdefaultValue監査不一致0、copy lint成功、diff check成功。`output/verify/competitive-improvements/{direct-cancel,emergency-exit}.png` を実レンダリングして目視確認。ログは `.claude/verification-logs/2026-09-05-competitive-improvements/`。Screen Time実機コールバック、OS更新/再起動・権限取消時の制限の実効性、実際の課金、ストア提出は未実施。既存のSwift 6移行警告は今回新設したものではない。

## 2026-09-05 — 利用中の再介入と満足度質問のタイミング

- オーナー判断: 「LiveActivityで十分。1日8時間も見れたらいい」「利用中の再介入は入れてください」。Live Activityは現状を採用し、常設Widgetの新規追加を見送る。利用中再介入は今回実装へ変更。
- フロー: 初回に設定の「利用中の再介入」で対象SNSをScreen Timeの同じアプリ1件に接続。既存の一呼吸の後で5/10/15/30分を選択→実利用の累積閾値でシールド→DopaBreakへ戻る→既存の満足度を回答/スキップ→終了または呼吸＋時間追加。追加時に理由質問を繰り返さない。途中終了は同設定の「ここで終了して振り返る」。他アプリの上に独自質問を出す案、SNSを閉じた瞬間に自動質問する案はOS機能との不一致のため採用しない。
- 作成: `ios/DopaBreak/ReinterventionScheduler.swift`、`ReinterventionSettingsView.swift`、`ios/Shared/ReinterventionShield.swift`、Core `Services/ReinterventionStore.swift`、対応Core/アプリテスト。変更: `AppContainer.swift`、`InterventionFlowModel.swift`、`InterventionFlowView.swift`、`RootTabView.swift`、`PostUseReflectionSheet.swift`、`SettingsView.swift`、`SettingsNotificationsView.swift`、Monitor/ShieldConfig/ShieldAction拡張、CoreのEngine/SQLite/Snapshot/全削除処理、`project.yml`、日英韓xcstrings。
- UI方針: 既存の満足度画面とコピーを再利用。時間説明だけ利用の区切り/途中終了で変更。終了/追加画面は既存のPrimaryButtonStyle/SecondaryButtonStyle、ダーク背景、ライムを採用し、ScrollViewで拡大文字に対応。質問のスキップと明示的な終了操作を残す。保存エラー時は回答を再試行できる。
- Claude Code向け制約: iOS17.4+の`includesPastActivity:false`で新しい利用を計測。正確な現在秒数や残り時間は取得しておらず、通過画面で12時間の監視有効期間を「残り利用時間」として見せない。通知設定OFFでもシールド/アプリ内質問は有効。既存の壁時計通知は接続された利用にだけ重複防止で抑制。OS26.5+のみシールドから親アプリを開くAPI、旧OSは通知/ホームから戻る案内。接続先の完全な自動照合は不透明トークンのため不可。
- 保護: 再介入は独立ManagedSettingsStore。終了/追加は手動・週次・就寝ブロックを解除しない。UUIDで古い閾値イベントを無視、flockでアプリ/拡張の共有状態とシールド再計算を直列化。12時間の有効期限は分単位に合わせて残留ロックを防ぐ。未到達セッションの再開始による時間リセットは禁止。
- 監視枠: 以前の週次14＋手動1＋就寝1=16本を、週次2（毎日コールバック、Coreで曜日照合）＋手動1＋就寝1＋再介入最大8=12本へ変更。旧曜日活動名は停止対象に残す。設定の曜日と予定2件は維持。
- 検証: Core564件成功。専用iOS26.5 Simulatorでアプリ全体351件・18スキップ・0失敗。通知設定の最終差分は関連40件成功。画面画像は `output/verify/reintervention/{satisfaction,finish-or-extend}.png`。実際のScreen Timeイベント/シールドの実効性は実機検証が必要。詳しい制約・出典・受入手順は `.claude/specs/reintervention-implementation-2026-09-05.md`。

## 2026-09-05 — 追加機能のペイウォール反映

- オーナー依頼: 追加した機能のうちペイウォールに載せた方がよいものを追加。
- `ios/DopaBreak/PaywallView.swift`: Pro特典に「解除に30秒待つ強いブロック」を追加。既存の週次予定行を「毎週のブロック予定を2つ設定」へ具体化し、一覧を5→6行に更新。既存の行コンポーネント・スクロール構成を再利用。
- `ios/DopaBreak/Localizable.xcstrings` のja/en/ko、`docs/06_screen_design.md`、`docs/11_ui_copy.md`、`docs/15_pricing_design.md`、`.claude/specs/i18n-launch-inventory.md`を同期。既存の製品バンドル翻訳テストを更新。
- 採用理由: 強いブロックの解除待機と2件の週次予定は、実装済みのPro機能の具体的な差分。30秒は緊急解除の待機であり、OS権限取消まで禁止する意味ではない。利用中の再介入・満足度・直接キャンセル・記録からの設定見直しは無料でも利用できるためPro特典の行には追加しない。料金や無料/Pro境界を変える依頼とは扱わない。
- 検証: defaultValue監査は不足・不一致0、表示コピーlint成功。実機に既にインストール済みの版にはこのペイウォール差分はまだ含まれない。
- ビルド・製品バンドルの3言語テストも成功（1件0失敗）。`git diff --check`成功。

## 2026-09-05 — 必要な利用を邪魔しない再介入

- オーナーが仕事中の中断による機能OFFを懸念し、提示した改善案の実装を依頼。
- 仕事・調べもの・連絡・投稿は「今回は利用時間を決める」を初期OFFにする。ONなら時間選択・再介入を利用可能。暇つぶし・なんとなくは従来の時間選択。OFFでは開いた事実と理由のみを `recordUntimedOpen()` で保存し、架空の時間や満足度質問を作らない。
- 再介入後の満足度/終了選択の両画面に「必要な用事のため今回は再介入せず続ける」を追加。質問未回答ならスキップし、そのSNSの再介入だけ終了。永久OFFや12時間の通過許可は保存せず、次のSNS起動は通常の確認に戻る。手動・週次・就寝の別ブロックは維持。
- 変更: `ios/DopaBreak/InterventionFlowModel.swift`、`InterventionFlowView.swift`、`AppContainer.swift`、`PostUseReflectionSheet.swift`、`Localizable.xcstrings`（ja/en/ko）、`InterventionRoutingTests.swift`、`WinScreenReclaimedTimeTests.swift`。詳細は `.claude/specs/reintervention-implementation-2026-09-05.md` へ追記。
- デザイン: 既存の時間選択画面にネイティブToggleを追加、OFF時は時間のグリッドを隠す。主ボタンは「時間を決めずに開く」。再介入の継続は既存SecondaryButtonStyle。新画面や全体設定への移動、満足度回答の強制は採用しない。
- 検証: 関連106件、1スキップ、0失敗。仕事等4理由の初期値、時間ありへのオプトイン、暇つぶしの既定、振り返り非生成、接続維持、継続時の質問スキップ・強いセッション維持を検証。defaultValue監査不足/不一致0、表示コピーlintとdiff check成功。実機への再インストールは未実施。
- 追加の実レンダリング1件成功。`output/verify/reintervention/work-untimed.png` と更新した `satisfaction.png` を目視確認。ログは `.claude/verification-logs/2026-09-05-work-reintervention/`。

## 2026-09-05 — 仕事中も時間の区切りを残す

- オーナー合意「OKそれでいこう」: 必要な利用も時間選択が基本、到達時は確認通知のみ。直前の「仕事等は時間初期OFF」を置き換える。時間なしは補助選択肢、強制ブロックは接続済みユーザーの任意ON。
- `InterventionFlowModel.swift` / `InterventionFlowView.swift`: 仕事・調べもの・連絡・投稿の既定を時間ON・ブロックOFFへ変更。未接続は起動からの経過時間、接続済みは累積利用時間と説明を出し分ける。通知型では満足度質問を作らない。
- Core `ReinterventionStore.swift` / `InterventionEngine.swift` / `NotificationRouting.swift`、`ReinterventionScheduler.swift`、`ReflectionNotificationScheduler.swift`、MonitorExtension、`AppContainer.swift`、`SettingsNotificationsView.swift`、`ReinterventionSettingsView.swift`を更新。旧セッションのブロックを保つoptionalモード属性、質問とは別の通知ID、確認通知取消、目的に応じた設定表示を追加。日英韓xcstringsと関連テストを同期。
- 方針: 静かな気づきのため「まだ用事の途中ですか？」の通知を使い、必要な利用に回答・呼吸・満足度を強制しない。通知型から別ストアの強い/週次/就寝ブロックは解除しない。OS通知許可とアプリの振り返り通知設定が必要なことを画面に表示。
- 検証: Core565件、関連57件すべて成功。通知型の非遮蔽、満足度非生成、通知IDとタップ先、通知OFF、旧JSON互換を確認。実機への再インストールは未実施。
- 最終差分の関連39件も成功。`output/verify/reintervention/work-time-checkin.png` を実レンダリングして目視確認。defaultValue監査不一致/不足0、copy lintとdiff check成功。ログ: `.claude/verification-logs/2026-09-05-soft-reintervention/`。

## 2026-09-05 — 購入後に追加される対象アプリのショートカット案内

- 変更: `ios/DopaBreak/AppContainer.swift` に購入継続の `.addTargets` 成功時だけ立つ `pendingAutomationGuideAfterPurchase` を追加。`ios/DopaBreak/HomeView.swift` と `ios/DopaBreak/SettingsView.swift` はペイウォールの `onDismiss` でこのフラグを消費し、既存のピッカー後案内予約へ固定印 `"purchase"` を渡す。
- 採用方針: 案内の表示方法とモーダル排他は既存の `pendingAutomationGuideAfterPicker` / `presentAutomationGuideAfterPickerIfNeeded()` を維持。追加されたcatalog IDの一時保存は表示内容に不要なため採用せず、空でない固定印のみとした。
- 制約: 通知タップ用の `pendingAutomationGuideRequest` と共用しない。`.applyMode` では購入後案内フラグを立てない。ペイウォールを提示したHome/Settingsの `onDismiss` だけがフラグを消費する。

## 2026-09-06 — ASC CLI人気語に基づくASOメタデータ改善

- 対象: DopaBreak `6794221254` / iOS `1.0` / 準備中。採用正本は `output/aso/2026-09-06/after/`、変更前は同 `before/`、根拠・全差分・保存結果は `report.md`。`docs/16_aso_metadata_3markets.md` 末尾にも現行値を追記。
- JPタイトルは「DopaBreak − スマホ制限・スクリーンタイム」、サブは「SNSを開く前にひと呼吸・勉強や睡眠中はアプリ制限」。ENのタイトルは維持、サブは「Pause, Block Apps & Focus」。KOタイトル/サブは維持。4localeのKWを市場別に整理（ja93 / en-US96 / en-GB99 / ko91文字）。
- 採用理由: Apple Ads Insightsの8/23〜29 UTC週でJPスマホ制限60・スクリーンタイム61・アプリ制限54を確認。公開検索でも同種アプリへの関連を確認。米韓の既存タイトルを変える十分な根拠はなく維持。生データと候補ごとの実測/未返却は `research/` に保存。未返却は需要ゼロではなく、機能からの推測語は別扱い。
- 却下: 全タイトルの刷新、高人気な競合名/第三者ブランド語の詰め込み、未実装のポモドーロ・広告除去・睡眠測定・勉強時間レポートを示唆する語。英語focusやblockの検索は他用途も混ざるため人気度だけで主軸にしない。
- 現行仕様との整合: 一呼吸＋任意のProブロックを説明し、無条件の「禁止しない/Not a blocker」を廃止。57%は他社one sec研究の6週間後の対象アプリ起動回数に修正、効果非保証を維持。対応カタログ内の登録上限解除・2件の週次予定・通知/Live Activityへ説明を揃える。
- Claude Code向け制約: 古いdoc16本文は履歴であり再アップロードしない。次回更新はASCから新しいディレクトリへpullしてから今回のafterとの差分を確認する。価格/課金条件/URL・スクショ・アプリコードは今回変更なし。審査提出時は対象ビルドに記載機能が含まれることを確認。
- 検証: 文字数・完全一致語の重複・URL不変のローカル検査成功。ASC metadata validateは8ファイルerror0/warning0、dry-runは予定12項目のみで追加/削除なし。ASC保存は7レコードすべて成功。読み戻し結果はASOレポート末尾に記録する。審査提出は行っていない。

## 2026-09-06 — 読者像と機能を具体的に伝えるストア説明文

- オーナー依頼によりja/en-US/en-GB/koのdescriptionを全面改稿。最新正本は `output/aso/2026-09-06-description-rewrite/after/`、読みやすい全文は同 `copy/`、採否・検証は `README.md`。`docs/16_aso_metadata_3markets.md`にも参照を追記。
- 方針: SNSを見続ける・勉強中につい開く・仕事でもSNSが必要という具体例で対象者を示し、一呼吸、利用中の区切り、集中/就寝/週次ブロック、目標、振り返りと記録を操作の流れに沿って説明。初回Shortcuts設定と動画案内も明示。
- 却下: 機能名だけの箇条書き、抽象的な「意志」「変革」の訴求、体験談や効果の捏造、他社研究の数値を中心にした構成。57%段落は今回の説明文から外した。アプリ内の研究表示は変更していない。
- 仕様整合: 無料でも目標数無制限・記録全期間であることを明記。Proは対応アプリ登録上限解除とブロック/テーマ等。強いブロックの30秒待機は時間指定の手動セッションに限定し、解除不能とは書かない。Live Activityの常設・終日表示や取り戻した時間の正確な実測を約束しない。
- 制約: タイトル・サブ・KWと価格/課金条件/URLは今回不変。前のASOディレクトリは履歴であり、次回変更の前には最新ASCをpullする。アプリコード・スクショ・審査提出は今回対象外。
- 検証: 4,000字以内（ja1,546 / en-US・en-GB3,173 / ko1,874）、説明文以外不変、購入条件4行とURL不変。ASC validateはerror0/warning0、dry-runはdescription4項目のみ、保存4件成功。2026-09-06 14:22 JSTに8 JSONを読み戻し、採用案との完全一致を確認。

## 2026-09-06 — 起床・就寝バーの固定座標と細かな時刻入力

- ユーザー報告: バーがぶれ、細かい時刻調整が難しい。
- 変更パス: `ios/DopaBreak/SettingsView.swift`。バーに名前付き固定座標空間を置き、動くハンドルのローカル座標ではなく固定座標でDragGestureのtranslationを取得。バーの暗黙アニメーションを無効化し、ドラッグ中のシールド再登録は指を離すまで保留。
- 起床・就寝の表示時刻を44pt以上のタップ領域を持つアクセント色のボタンに変更。既存の時刻ピッカーを直接ホイールで表示し、1分単位で指定可能にした。日英韓の既存ラベルを再利用。
- 採用: バーで15分刻みの大まかな変更、時刻タップで1分単位の正確な設定。24時間を短いバーの1分刻みだけで操作する案は、1分が1px未満になり精密操作に向かないため却下。独立した就寝スケジュールを新設せず、既存の時刻保存・最低60分間隔・日跨ぎを維持。
- 検証: シミュレータビルド成功、Core WakeSleepTimelinePolicyTests 12件成功。表示確認ログは `.claude/verification-logs/2026-09-06-timeline/`。実機の指ドラッグの感触と再インストールは未確認。


## 2026-09-06 — App Storeスクショのロック画面デザイン選択訴求を評価（提案・未実装）

- 依頼: 「ロック画面のデザインが選べることがわかる画面がないけど不要？」への判断。スクショ制作・ASC更新の依頼ではない。
- 確認: `output/app-store-screenshots/v2/contact-sheet-ja.png` の現行8枚を目視。2枚目は黒とライムの目標表示のみで、テーマ選択や他の見た目は示していない。`LockTheme` は10ケース、`EntitlementGate.lockThemeAllowed` は無料e1のみ・Pro全件を許可する。
- 推奨: デザイン選択を示す1枚を4枚目へ追加し、全9枚にする。先頭3枚の一呼吸・ロック画面の目標・集中を維持したうえで、好みの見た目を選べる価値を伝える。これは提案であり、既存アップロード順の確定事項を上書きしない。
- 構図案: 実際のデザイン選択画面を主役にして、手書きノート・かわいいピンク・ゲーミングなど違いの大きい3種類の実装プレビューを読み取れる大きさで示す。見出し候補「目標を 好きなデザインで」、補足候補「10種類から選べるロック画面」、注記「標準デザインは無料 ほか9種類はPro」。選べる対象はロック画面上の目標カードであることを明確にする。
- 見送る案: 省略継続（固定の黒とライムしか選べない印象が残る）、2枚目への小さい色見本だけの追加（書体・レイアウトの違いが伝わらず、目標表示の訴求も混雑する）。
- 根拠・制約: Appleの公式案内は各スクショで主要な価値・機能を伝える方針 https://developer.apple.com/app-store/product-page/ 。4枚目という位置と構図は本アプリについての提案であり、CVR改善を実測した結論ではない。画像・コード・ASCは未変更。変更パスは本記録のみ。


## 2026-09-06 — ショートカット設定の実操作撮影と差し替え

- オーナー依頼: ショートカット設定の動画とスクリーンショットを実際の設定に置き換え、すべてCodexが撮影。
- 変更パス: `ios/DopaBreak/AutomationGuideView.swift`、`Localizable.xcstrings`、`Assets.xcassets/AutomationTutorial/`、`Resources/automation-tutorial-{ja,en,ko}.mp4`、`ios/DopaBreakTests/AutomationTutorialVideoResourceTests.swift`、`scripts/prepare-shortcuts-tutorial.py`。原本と検証記録は `output/shortcut-capture/2026-09-06/README.md`。
- 採用: AppleのShortcuts.appをiPhone 16 Pro / iOS 26.5 Simulatorで実際に操作し、Safariを例に日本語・英語・韓国語の動画3本と原寸1206×2622の画像21枚を撮影。設定保存まで録画。画像は原本をそのままAsset Catalogへ、動画は無操作区間を短縮して720×1566 H.264へ。7手順の簡略図を廃止し、既存カードの中に実画面を全幅・縦横比維持で表示。
- 採用理由・却下: 架空UIの描き直し、他者のチュートリアルの流用、実際の画面を翻訳合成する案は依頼と合わないため採用しない。初回は「新規オートメーション」、既存設定があれば＋という実画面の分岐を説明へ反映。Safariが全員の設定対象と誤解されないよう3言語に例示の説明を追加。
- 実装上の制約: 物理iPhoneでなくSimulatorの実App画面。動画と画像の言語選択は共通化し未知言語は英語。白黒モードの別ガイドと既存PiPの振る舞いは今回の変更対象外。撮影用設定の削除は自動承認レビューが明示承認不足として拒否したため残しており、物理iPhoneの設定は変更していない。
- 検証: iOS 26.5でビルド成功、関連9件成功・失敗0。21枚の同梱・原寸、3動画のAVFoundation再生可否・尺、言語分岐、ガイドの実ウィンドウ描画を確認。FFmpeg全フレームデコード成功。defaultValue監査の不一致/欠落/未解決/型不一致0、表示コピーlint成功。原本・編集区間・SHA-256・テスト結果を成果物内に記録。
- 表示確認: `SettingsDeviceFixesSnapshotCapture.testCaptureTimelinePrecisionControls` 1件成功。撮影専用initializerでモード・時刻を保存値から初期化し、`output/verify/settings-timeline-precision.png` の7:07/23:03とタップ可能な時刻ラベルを目視確認。通常のinitializerは変更していない。ホイール操作と指ドラッグの実機確認は未実施。


## 2026-09-06 — ストア説明文へドーパミンの項目を追加

- オーナー依頼「ドーパミン関連の内容を入れたい」により、ja/en-US/en-GB/koのdescriptionに短い項目を追加。最新メタデータ正本は `output/aso/2026-09-06-dopamine-copy/after/`、全文は同 `copy/`、追加原稿は `sections.json`、根拠・検証は `README.md`。前回のディレクトリは履歴として保持。
- 採用方針: おすすめの人の後に「ドーパミンと、つい開いてしまう習慣」を配置。報酬への期待・行動の学習を平易に説明し、「次の動画」「反応を確かめる」という例から、一呼吸・利用理由/時間・振り返りの機能へつなぐ。
- 根拠: Schultz et al. Science (1997) の報酬予測/学習、Lindström et al. Nature Communications (2021) の社会的報酬とSNS投稿行動。動画/反応の例は説明用で、実測や利用者の引用ではない。出典リンクと研究の対象範囲はREADMEに記録。
- 却下した表現: ドーパミン排出、脳や受容体のリセット、分泌量の正常化、治療効果の断定。韓国語の表示コピーに디톡스は追加しない。ドーパミンの生理学的変化を測定したアプリとは説明しない。
- 制約: 既存説明文に1項目ずつ挿入するだけで、タイトル・サブ・KW・料金・購入条件・URLは保持。アプリ内コピー/実装/スクショは今回対象外。古い説明文を次回再アップロードせず、最新ASCをpullして編集する。
- 検証: ja1,746 / en-US・en-GB3,628 / ko2,124字で上限内。追加分を除くと変更前全文と完全一致。ASC metadata validate error0/warning0、dry-runはdescription4項目のみ。保存4件成功、2026-09-06 14:28 JSTの読み戻しで8 JSONすべて一致。審査提出なし。

## 2026-09-06 — 設定ステータスカードの余白とアイコンの重なりを修正

- 変更パス: `ios/DopaBreak/SettingsView.swift`、`ios/DopaBreak/AppIconView.swift`、`ios/DopaBreakTests/SettingsDeviceFixesSnapshotCapture.swift`。
- 採用: 説明＋56ptリングを上段、アイコンと今日の回数を下段に配置。回数とラベルを横並びにしてカード下部の空白を縮小。設定カードのアイコン間隔は6ptとし、隣のアイコンが30%隠れる重なりを解消。共通部品に任意spacingを追加。
- 却下: 文字の縮小や固定高さによる切り詰めは説明の読みやすさを損なうため不採用。既存の他画面の重なり表現は変更しない。
- 検証: iOS 26.5 Simulatorビルド・描画テスト1件成功。日本語・夜だけ強化・カタログアイコン2件のカードを `output/verify/settings-compact-night-status.png` で目視確認。撮影fixtureの先頭位置はadjustedContentInsetを考慮するよう補正。
- 制約: Screen Timeの実ApplicationTokenはSimulator fixtureで再現しておらず、実機の同アイコン表示とインストールは未確認。


## 2026-09-06 — App Store追加画像としてLive Activity全10テーマを一覧化

- オーナー依頼: 現行スクショのデザインに合わせて10種類を並べた画像を作成。スマホモックは省略可能。
- 成果物: `output/app-store-screenshots/theme-gallery/ja/iphone-69/11-lock-designs.png`（1320×2868・RGB PNG）。撮影原本10枚、配置・フォント・SHA-256のmanifest、再生成手順は同ディレクトリ。既存8枚やASCは未変更。
- 変更パス: `scripts/generate-appstore-theme-gallery.py`、`scripts/capture-appstore-theme-gallery.sh`、`ios/DopaBreakTests/LockThemeDensitySnapshotCapture.swift`、本記録。
- 採用: 2列×5段で10種類を各1回。既存v2ジェネレータの暗色グラデ、Hiragino Sans W8/W4、ライムのピル、見出し位置240/340/680を再利用。「あなたの目標を / 好きなデザインで」「10種類から選べる 目標カードのデザイン」。各名称と無料/Proを表示し、黒とライム以外の9種類がProと明記。
- 採用理由・却下: 端末枠とマスコットを置くと10カードが小さくなるため省略。前回の3種類の代表例案より、今回明示された全10種類を優先。AIによるUI描き直しや古いモックは使わず、現在の共有SwiftUI ViewをiOS 26.5の専用Simulatorで描画して正確な文字・フォント・K-POPの現行マーカーを維持した。
- 制約: 日本語iPhone 6.9インチの単独追加画像。実ロック画面のリキッドグラスは背景の壁紙により外観が変わる。目標4件は既存ロック画面スクショと共通の撮影用データ。通常テストでは撮影をスキップし、xctestrun環境変数で明示した場合だけ原本を書き出す。撮影時・合成時の両方で空画像を拒否する。
- 検証: build-for-testing成功、撮影1件・スキップ0・失敗0。原本10件の画像ハッシュがすべて異なること、無料1/Pro9、最終寸法とRGB形式、全カード・名称・バッジの範囲を検証。完成画像とリキッドグラスの実描画を目視確認。シェル/Python構文と関連diff checkも成功。


## 2026-09-06 — ストア説明文を機能名ごとに整理

- オーナー依頼「どんな機能があるか機能の名前ごとに説明した方がいい」に対応し、ja/en-US/en-GB/koのdescriptionを更新。最新メタデータ正本は `output/aso/2026-09-06-feature-names/after/`、全文は同 `copy/`、判断・検証は `README.md`。過去のASOディレクトリは履歴として保持する。
- 採用: 「一呼吸（標準モード）」「利用中の再介入」「ディープフォーカス」「毎週の予定」「夜だけ強化」「強いブロック」「目標」「ロック画面の表示」「振り返り」「記録」の10項目。アプリ内の各言語の名称と照合し、直下に機能の内容・使う場面を平易に説明。Proの機能は見出しにも明記。
- 却下: 集中・就寝・週次のブロックを一つの抽象的な見出しにまとめる構成と、機能名だけを並べる構成。目標とロック画面表示、振り返りと記録も分けて説明する。
- 制約: 冒頭・おすすめの人・ドーパミン・無料/Pro・初期設定・購入条件の文章は全文保持。タイトル・サブ・KWなどdescription以外も不変。アプリコードやスクショは今回対象外。強いブロックの待機は時間指定の手動セッションに限定し、記録は一呼吸対象アプリの回数と取り戻した時間の目安として説明する。
- 変更パス: 上記出力ディレクトリ、`docs/16_aso_metadata_3markets.md`、`.claude/specs/design-decisions.md`。古いスナップショットを再投入せず、次回も最新ASCから取得して編集する。
- 検証: ja1,959 / en-US・en-GB3,646 / ko2,352字。ASC metadata validate error0/warning0、dry-runはdescription4項目だけ。保存4件成功、2026-09-06 14:38 JSTの読み戻しで8 JSONすべて一致。準備中バージョン1.0へ保存し、審査提出は行っていない。


## 2026-09-06 — Liquid Glassの白文字固定を修正

- 変更パス: `ios/WidgetsExtension/LockThemeLiveActivityView.swift`、`ios/WidgetsExtension/DopaBreakWidgets.swift`。
- 調査: iOS 26では既に`glassEffect(.regular)`を使用しているが、目標・eyebrow・回数・区切り線・終了ボタンが白固定だった。明るい素材とのコントラスト不足を修正。過去のストア用撮影は黒背景・dark固定のためlightの検証になっていない。
- 採用: 文字をsemantic primaryへ、区切り線と回数ピルをprimaryの低opacityへ変更し、文字の黒い影を除去。ネイティブglassEffectと旧OSのmaterialを維持する。
- 却下: 黒い不透明背景を足す案はガラスの外観を失うため採用しない。
- 検証・制約: コード差分を確認。iOS 26.5 Simulator向け既存LockThemeLiveActivityViewTestsを実行したが、Accelerateのコンパイル時にNo space left on deviceで停止。テスト未実行、実機ロック画面・light/darkの目視未確認。今回作成した/tmp/dopabreak-glass-checkのみ削除して容量を戻した。白い表示の原因がコントラスト不足だけか、WidgetKit側の描画問題も含むかは未確定。


## 2026-09-06 — Live Activity全10テーマの英語・韓国語App Store画像

- オーナー依頼: 日本語版と同じデザインで英語圏・韓国語版を作成。
- 成果物: `output/app-store-screenshots/theme-gallery/{en-US,ko}/iphone-69/11-lock-designs.png`（各1320×2868 RGB PNG）、原本各10枚、capture.json、manifest、README。
- 変更パス: `scripts/generate-appstore-theme-gallery.py`、`scripts/capture-appstore-theme-gallery.sh`、`ios/DopaBreakTests/LockThemeDensitySnapshotCapture.swift`、本記録。
- 採用: 2列×5段・余白・コピー座標を維持。英語SF、韓国語Apple SD Gothic Neoで既存スクショと統一。名称はxcstrings、目標はLOCK_GOALSを直接使用。locale別Bundle/Localeで実描画し、韓国語のゲーミング/手書きはGalmuri11/NanumPen。
- コピー: EN “Keep your goals / in a style you love”、KO「내 목표를 / 좋아하는 디자인으로」。各言語で10種類・無料1/Pro9を表示。
- 却下: 外側の見出しだけを翻訳し日本語カードを残す案と、日本語フォントの共用。カード内も実アプリの各言語の見た目を優先した。
- 制約: en-USを英語版として作成。iPad派生・ASCアップロードは今回対象外。日本語PNGはSHA-256一致で維持。リキッドグラスは実際の壁紙により外観が変わる。
- 検証: ビルド成功、EN/KO撮影各1件・スキップ0・失敗0。完成画像2枚と手書き/ゲーミング原本を目視。20原本の言語/書体、10テーマ非重複、寸法・形式・配置、名称/目標一致、フォントfallbackなしを確認。関連構文/diff check成功。


## 2026-09-06 — Live Activity blank glass surface

- User screenshot IMG_9832.PNG confirms missing goals and counts, not merely a dark background. The earlier contrast-only diagnosis was insufficient.
- Changed ios/WidgetsExtension/LockThemeLiveActivityView.swift and DopaBreakWidgets.swift: containerRelative Live Activity renders content without nested glassEffect and explicitly uses activityBackgroundTint(nil) for the system material. Fixed-shape in-app previews retain native glassEffect. Semantic foreground colors remain. Rejected an opaque black replacement. Exact remote-rendering failure remains unconfirmed.
- Added light/dark content rendering regression in ios/DopaBreakTests/LockThemeLiveActivityViewTests.swift. iOS 26.5 simulator build and existing 23 tests passed; additional appearance test passed. Visually checked output/verify/liquid-glass-lock-screen/dark.png and light.png. These are solid-background content fixtures, not actual lock-screen material captures. Physical-device installation and Live Activity recreation remain unverified.
- Apple reference: https://developer.apple.com/documentation/swiftui/view/activitybackgroundtint(_:)

- Device deployment follow-up (2026-09-06 14:55 JST): user explicitly requested installation. Signed Debug device build succeeded using ios/.deriveddata-device. devicectl installed com.dopabreak.app on paired iPhone (196), iPhone 16 Pro, and successfully launched it. Actual Lock Screen appearance remains visually unverified.


## 2026-09-06 — モノクロへ整理・レトロポップ廃止・新ガラス版

- オーナー依頼: 現在のガラス表示をモノクロにし、レトロポップを除き、新しいリキッドグラスを作成。既存シンプルモノクロを旧ガラスの目標・区切り・実績ピルの構成で置換し、9テーマに整理。
- 変更パス: `ios/WidgetsExtension/LockThemeLiveActivityView.swift`、`DopaBreakWidgets.swift`、`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Models/AppModels.swift`、`ios/DopaBreak/LockScreenThemeDisplay.swift`、`Localizable.xcstrings`、関連3テストファイル、`scripts/generate-appstore-theme-gallery.py`。成果物と検証記録は `output/verify/liquid-glass-lock-screen/README.md`。
- 採用: モノクロは明暗に追従する不透明背景。新ガラスは半透明の陰影、白文字、光の強弱がある縁、ActivityKitのalpha付き背景色で壁紙を透過。プレビューだけ参考背景を置く。本番は壁紙を使用し、不透明な色背景を置かない。
- 保存値: 旧liquidGlass/yozora/retroPopはmonochromeへ。新ガラスはliquidGlassV3。読み出し・Codable・SettingsStoreの移行を検証。現在のデザインを保持するため、旧選択が新ガラスへ勝手に切り替わる案は不採用。
- 却下・制約: リモート本文全体へのglassEffectは消失問題の再発リスクがあるため使わない。今回の新ガラスは透過と反射の表現であり、Appleの動的屈折APIと同等だとは扱わない。過去のプレビューだけで本番完成とした判断を繰り返さず、Simulatorの実Lock Screenで壁紙の透過と本文を確認。
- 検証: Core9件、関連レイアウト・3言語・9件picker検査、追加alpha検査成功。撮影fixtureは1分間activeを確認して終了。実機向け署名ビルド成功、同じiPhone 16 Proへインストール成功。実機ロック画面の目視は未実施。撮影用SimulatorのLive Activity許可操作は、OS許可変更の明示承認がないとして自動レビューが拒否したため実行せず、許可ダイアログ付きで確認。ストア画像の再生成・公開は行っていない。


## 2026-09-06 — 赤・青と蜘蛛の糸の追加テーマ案（相談・未実装）

- 依頼: スパイダーマン本人を描かず、蜘蛛の糸と赤青を基調にした追加テーマの権利リスク確認。追加実装・公開は未実施。
- 判断: 赤青・蜘蛛の糸という一般的な発想だけで侵害とは決まらないが、本人を省けば許諾不要とは断定できない。衣装の具体的な色分け・網目・蜘蛛紋章・目の輪郭などを組み合わせ、本質的特徴を再現する場合は著作権等の問題が残る。現時点は完成画も対象商標の調査もないため中リスクの暫定評価。
- 提案: 一般的な蜘蛛の巣を独自に描き、配色・構図を独立させたオリジナルテーマへ。作品名・Marvel名・連想を売りにした販促、胸の紋章やマスクの目・衣装の配置再現は採用しない。名称だけ変える案や色を少し変えれば安全という基準は不採用。
- 出典: CRIC https://www.cric.or.jp/qa/hajime/hajime1.html 、https://www.cric.or.jp/qa/shigoto/sigoto8_qa.html 。特許庁 https://www.jpo.go.jp/faq/yokuaru/trademark/new_shouhyou_faq.html 。経産省 https://www.meti.go.jp/policy/economy/chizai/chiteki/pdf/instagram_chizai.pdf 。日本法を中心とした一般的整理であり、具体案の適法性や海外配信のクリアランスを保証しない。


## 2026-09-06 — ガラス版のグレー感を減らす透過率調整

- オーナー依頼: 背景がグレーすぎてガラス感が足りないため、背景をさらに透過。
- 変更パス: `ios/WidgetsExtension/LockThemeLiveActivityView.swift`、`ios/WidgetsExtension/DopaBreakWidgets.swift`。
- 採用: 黒い面のalphaを0.38–0.46から0.18–0.24へ、白い反射面を0.18/0.04/0.08から0.07/0.015/0.025へ、ActivityKit背景tintを0.12から0.04へ低減。縁の反射は保持。読みやすさは文字周りの小さな黒い影で補助。
- 却下: 全体の白い塗りを増やしてガラスらしさを出す案は、指摘されたグレー・白濁を増やすため不採用。文字保護用の薄い面まで完全透明にする案も見送った。動的屈折ではなく半透明・反射の表現という前提を保持。
- 検証: iOS 26.5 Simulatorの明暗表示・alpha・比較画像の既存3テスト成功。比較と白背景fixtureを目視。変更前比較は `output/verify/liquid-glass-lock-screen/comparison-before-more-transparent.png`、変更後は同`comparison.png`。実機向け署名ビルド成功。実機ロック画面の今回の見え方は未確認。
- 実機反映: 15:19 JST、iPhone (196) / iPhone 16 Proへ上書きインストール・起動成功。


## 2026-09-06 — 青・赤・蜘蛛の糸の比較4案（未実装）

- オーナー依頼: 青い面、赤いアクセント、隅または全体の細い蜘蛛の糸というデザインパターンを見せる。imagegenで4案を1枚の比較画像として作成。
- 画像: `/Users/solotech/.codex/generated_images/01a0753b-5c28-7682-9e70-2280ca848caa/exec-be66fb86-68d3-478f-ac2f-96ddcbea4b9a.png`。A=角の糸＋赤い左ライン、B=対角の糸、C=全体に繊細な糸、D=全体に少し強い糸＋赤い下辺。
- 共通: 白い目標3行と実績ピル、青主役・赤少量。キャラクター・目・蜘蛛紋章・作品名・衣装の色分けは含めない。権利確認済みという保証はしない。
- 状態・制約: 見た目の検討用生成画像。SwiftUI実装、実機反映、パターン選択は未実施。画像のカード比率や文字密度は実装時に既存160ptの制約へ合わせる。


## 2026-09-06 — 蜘蛛の糸テーマ4案を赤背景へ変更（未実装）

- オーナー指示: 青背景より赤背景を希望。4案の糸配置・文字構成を維持し、赤を背景、青を細いアクセントへ入れ替えた比較画像を生成。
- 新画像: `/Users/solotech/.codex/generated_images/01a0753b-5c28-7682-9e70-2280ca848caa/exec-2657097a-f4ef-44f2-b7ed-4b8019ad623f.png`。A=コーナー、B=対角、C=全体・繊細、D=全体・強め。白文字、淡い糸、赤系の実績ピルを採用。
- 前の青背景画像は履歴として保持。ユーザーの選択・SwiftUI実装・実機反映は未実施。


## 2026-09-06 — 蜘蛛の糸テーマの目標行へクモ記号（未実装）

- オーナー指示: 文字横のリスト記号をクモへ。赤背景4案の各目標3行に白い一般的なクモのピクトグラムを追加した比較画像を生成。見出しと実績ピルには追加せず、配色と糸配置を保持。
- 最新画像: `/Users/solotech/.codex/generated_images/01a0753b-5c28-7682-9e70-2280ca848caa/exec-75abf03c-020d-4b31-adf9-da896922703e.png`。既存ブランドの紋章ではなく、丸い胴体と8本脚の一般的形状として指示。
- 状態: デザイン検討用画像のみ更新。4案からの選択、コード追加、実機反映は未実施。

## 2026-09-06 — D案採用・Live Activityの外周を最適化

- オーナー依頼: D案を採用。青い下辺とクモの色を検討し、ガラス・モノクロの四隅と偏った枠線を修正。
- 採用: 赤背景と右側へ集まる細い蜘蛛の糸、白い一般的な8本脚のクモを目標の行頭に配置。青は実績ピルの細い枠と、左右を24pt内側へ寄せた1ptの下線に限定。新テーマspiderWebを加え全10種類。日本語・英語・韓国語の名称を追加。
- 外周: 実Live Activityはシステムの角丸マスクと外周に任せ、ガラス本文の二重クリップと強弱付き外枠を除去。アプリ内プレビューのみ共通の連続角丸と均一なガラス枠を適用。モノクロのActivityKit背景色を本文と同じsystemBackgroundへ一致させた。ガラス内のピルはstrokeBorderで線の欠けを防止。前回の透過率は維持。
- 却下: 太い青い外枠は主張が強くシステムの角丸で欠けやすいため不採用。青いクモは赤地の小サイズで識別しづらいため白を採用。細すぎる脚と行ごとの座標補正は、小サイズの描画差を増やすため不採用。脚の太さと最小14pt・整数サイズで調整。
- 変更パス: ios/WidgetsExtension/LockThemeLiveActivityView.swift、DopaBreakWidgets.swift、ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Models/AppModels.swift、ios/DopaBreak/LockScreenThemeDisplay.swift、Localizable.xcstrings、関連テーマ/描画/一覧テスト、scripts/generate-appstore-theme-gallery.py。比較画像はoutput/verify/liquid-glass-lock-screen/comparison.png。
- 検証: Core9件成功。Live Activity描画29件（撮影専用1件skip）失敗0。320/393/430ptのプレビュー四隅の透明度と対称性、実Activity向け本文が独自の明るい外周を描かないこと、クモの行頭整列を検査。10テーマ一覧テスト成功。コピーlint・ローカライズ監査（mismatch/missing 0）・Python構文・関連diff check成功。撮影fixtureは60秒activeを維持し正常終了したが、今回のロック画面撮影は時間内に取得できず、外観は比較画像で確認。
- 実機: 16:01 JST、署名付きDebugビルド成功。以前と同じiPhone 16 Proへインストールを試みたがCoreDevice error 1011。端末一覧でunavailableを確認し、今回の更新は実機未反映。接続復帰後にインストールが必要。実機ロック画面の修正後の見え方は未確認。ストア画像の再生成・公開はしていない。
- 制約: 新ガラスは半透明と反射の表現であり動的屈折ではない。システムの外周はOS/壁紙依存。参考: https://developer.apple.com/documentation/swiftui/view/containershape(_:) 、https://developer.apple.com/design/human-interface-guidelines/live-activities 。


## 2026-09-06 — デザイン追加・名称変更後のApp Storeテーマ一覧を再生成

- オーナー依頼: デザイン追加と名称変更を反映して前回の画像を作り直す。対象は既存の日本語・英語・韓国語の3枚。
- 成果物: `output/app-store-screenshots/theme-gallery/{ja,en-US,ko}/iphone-69/11-lock-designs.png`。各1320×2868 RGB PNG。原本30枚・manifest・検証JSON・READMEも更新し、前の画像と廃止テーマ原本は同history/2026-09-06-before-theme-refreshへ保存。
- 反映: retroPopをspiderWebへ、シンプルモノクロをモノクロへ置換。新しいmonochrome描画とliquidGlassV3を実アプリから取得。テーマ数は10のため、2列×5段・コピー・余白は維持。
- 変更パス: 上記成果物、`ios/DopaBreakTests/LockThemeDensitySnapshotCapture.swift`、`scripts/generate-appstore-theme-gallery.py`、本記録。撮影側にallCasesのraw値一覧を記録し、生成側と不一致なら停止する検証を追加。製品コードは変更していない。
- 採用・却下: 名称だけ差し替えて旧カードを残す案は現行デザインと一致しないため不採用。追加と廃止を確認した結果10種類のため、カード縮小や列数変更は不要と判断。ガラスは現在のアプリ内プレビューに含まれる参考背景ごと撮影し、壁紙依存の外観という制約をREADMEへ記録。
- 検証: Simulatorビルド成功、3言語の撮影各1件・スキップ0・失敗0。完成3枚と変更カード原本を目視。テーマ順と現行enumの一致、名称とxcstringsの一致、目標文言、10種非重複、無料1/Pro9、RGB・PNG・寸法、文字とバッジの範囲、前版とコピー配置の完全一致を確認。Python/シェル構文・関連diff check成功。ASC公開・他のスクショ更新は未実施。


## 2026-09-06 17:21 JST — 実機インストール再試行完了

ユーザーの再依頼により、接続が復帰したiPhone (196) / iPhone 16 Proへ署名済みDebug版com.dopabreak.appをインストールし、起動成功。前回の接続不可は解消。実機ロック画面の外観は未確認。コード変更なし。


## 2026-09-06 — テーマ一覧をApp Store Connectの4枚目へ追加

- オーナー依頼: 最新のテーマ一覧をストアのスクリーンショットへ追加し、掲載位置を決める。追加権限は明示依頼による。
- 採用: ひと呼吸・ロック画面の目標・集中の3枚に続く4枚目へ。日本語、米国英語、英国英語、韓国語のiPhone2サイズとiPad、計12セットを各9枚へ更新。元の8枚と相互の順序は保持。
- 変更パス: scripts/generate-appstore-theme-gallery.py（iPad専用配置追加）、output/app-store-screenshots/theme-gallery/{ja,en-US,ko}/ipad-13、同asc-upload/（画像・実行計画・前後JSON・検証・README）、同README.md。
- 却下: テーマ一覧を先頭3枚へ入れる案は、主要機能の理解を優先して不採用。iPadのカード幅760pxはラベルと次段が近いため700pxへ調整。スマホモックは一覧の可読性を優先して追加しない。
- 検証: 12件の寸法・形式検証と追加1枚のdry-run成功。全12セットのAPI応答で9枚・4枚目の画像MD5一致・全画像COMPLETE・元8枚のID/MD5/相対順序一致。iPad3言語を目視確認、Python構文確認。
- 制約: 4枚目のCVR優位は未実測。Appleの最初の1〜3枚に関する案内を参考にした配置判断（https://developer.apple.com/app-store/product-page/）。対象1.0はPREPARE_FOR_SUBMISSIONで審査提出や公開はしていない。今後全セットを置換する際は従来の8枚生成結果だけでなく今回の4枚目を含める。


## 2026-09-06 — ひと呼吸画面の右上アプリ名ラベルを削除

- オーナー依頼: どのアプリでも右上にINSTAGRAMと表示されるため、ラベルを削除。
- 変更パス: `ios/DopaBreak/InterventionFlowView.swift`。
- 採用: breathingScreenの右上ラベル用HStackと余白、使用箇所がなくなったtargetLabelを削除。上下のSpacerで見出しと呼吸キャラクターを中央に配置。
- 却下: アプリ名の判定修正や別ラベルへの置換は、ラベル削除という依頼に合わないため採用しない。
- 検証: iOS Simulator向けDebugビルド成功、対象Swiftファイルのgit diff --check成功。実機反映・画面の目視確認は未実施。

## 2026-09-06 — TestFlight初回アップロードの画面方向設定

- Appleのビルド1検証が90474（iPadのUISupportedInterfaceOrientations未指定）で失敗。
- `ios/DopaBreak/Info.plist`と`ios/project.yml`にiPhoneの縦向き、iPadの4方向を明示。既存のユニバーサル対応を維持し、配布を通すためだけにiPad対応を削除する案は採用しない。
- 再アップロード識別用に本体と4拡張のInfo.plistおよびproject.ymlのCFBundleVersionを2に統一。バージョンは1.0を維持。
- 今回は配布検証の必須キー補完。iPad全画面の実機検証を完了したとは扱わない。アップロード結果は `.claude/verification-logs/2026-09-06-testflight/result.md` に記録。

## 2026-09-06 — 設定のPro入口を無料・有料で分岐

- ユーザー依頼: Freeはペイウォール、Proは購入管理画面に分ける。買い切りの実在も質問あり。
- ASC読み取り: `dopabreak.pro.lifetime` / IAP `6802039793` / NON_CONSUMABLE / READY_TO_SUBMITの登録を確認。登録済みだが公開済みとは扱わない。商品登録や価格の変更・削除は行っていない。
- 変更: `ios/DopaBreak/SettingsView.swift` の設定Pro行をisProで分岐。Freeは既存.settingsProStatusRowのfullScreenCoverへ直接、ProはSettingsAccountViewへ遷移。行の見た目・ハイライト・スクロール先IDは共通化して維持。
- `ios/DopaBreak/SettingsAccountView.swift` から買い切り直接購入行と専用購入メソッドを除去。Proの現在プラン表示と復元を維持。画面表示中にFreeへ変わった場合のペイウォールへの導線は維持。
- 方針: 購入は既存ペイウォールに集約し、Freeの復元はペイウォール内の既存ボタンを使用。新たな価格/プランを追加する案、既存lifetime権利と復元の処理を削除する案は今回の依頼範囲を超えるため不採用。
- 本変更はTestFlight 1.0(2)配布後の変更。配布済みビルドには未反映。
- 検証: 最終差分でSimulatorビルド成功。MeasurementFoundationTests 50件（49成功・撮影専用1スキップ）、失敗0。設定Proペイウォールの既存計測テストを含む。差分空白検査成功。ログ: `.claude/verification-logs/2026-09-06-pro-entry/final-tests.log`。実機タップとTestFlight更新は未実施。

## 2026-09-06 — 買い切りを販売構成から除外

- オーナー明示: 「今回の設計で買い切りは用意してないはず」。直前の登録維持方針を更新。
- ASC: 商品ID dopabreak.pro.lifetime / IAP 6802039793 / READY_TO_SUBMITを再確認して削除。deleted:trueとIAP一覧0件を読み戻し確認。月額・年額サブスクの登録は変更していない。
- `ios/DopaBreak/StoreService.swift`: 商品取得をallSubscriptionIDsへ限定し、lifetimeProductの保持/ペイウォール商品候補から除外。`ios/DopaBreak/DopaBreak.storekit`: 買い切りのテスト商品を削除。`docs/15_pricing_design.md`と課金検収表・リリーステスト一覧を現行方針に同期。
- 旧テスト取引を認識するためのIDと権利判定/復元互換コードは残すが、販売対象・購入ボタン・商品取得からは除外。過去の購入者がいるとの意味ではない。
- 誤解防止: 未使用の商品が登録されているだけで必ず審査落ちすると断定した対応ではなく、今回の販売設計にない商品をオーナー指示で整理したもの。
- 証跡: `.claude/verification-logs/2026-09-06-no-lifetime/`。TestFlight 1.0(2)にはコード変更は未反映。
- 検証: Simulatorビルド成功、MeasurementFoundationTests 50件中49成功・撮影専用1スキップ・失敗0。StoreKit設定JSONの構文と買い切り商品除外を確認。

## 2026-09-06 — 課金導線修正をTestFlight 1.0 (3)へ反映

- ユーザー依頼で、本体/4拡張のInfo.plistとproject.ymlをビルド3へ更新。Free/Proの入口分岐と買い切り除外を含むReleaseを既存内部グループへ配布。
- Apple側VALID/IN_BETA_TESTINGを確認。直前の「TestFlight未反映」の記録はビルド3で解消。一般公開は未実施。証跡は `.claude/verification-logs/2026-09-06-testflight-b3/result.md`。


## 2026-09-06 — 無料トライアルと終了前通知の適合性を再評価（検討のみ）

- オーナー依頼: DopaBreakの性質に現在の無料期間・通知が合うか、期待値を検討。8/17の「OK維持で」を確認したうえで再評価。
- 成果物: `docs/reviews/2026-09-06-trial-reminder-fit.md`。変更パスは同ファイルと本記録のみ。製品コード・課金設定は変更していない。
- 推奨: 年額7日無料と終了前1回の通知を維持。生活の中で複数アプリ・集中/就寝ブロックを試す期間として7日が妥当。通知は注意と選択を守る用途に合うが、本アプリでCVR・売上向上は未実測。
- UI提案（未承認・未実装）: 終了2日前を既定にし、購入前カードの2/3日前選択・許可/OS設定への分岐を簡素化。Duolingoの選択式通知の改善報告もあるため、選択肢を減らせば必ず改善するとは扱わない。過去の採用決定を自動撤回しない。
- 優先事項: 初日にPro固有の機能を実際に使えることと、通知の約束の正確性。3日前選択でも日英韓タイトルが「あと2日」固定、プラン通知OFFでもOS許可だけで「通知します」と表示し得る不整合を静的確認。未修正としてレポートへ記録。
- 却下: 3日への即短縮、14〜30日への即延長、他社CVR改善率を本アプリの予測に流用、トライアル開始率だけで採否判定。Freeの一呼吸・記録の成果とPro固有の便益は区別する。
- 検証・制約: 現行Swift/StoreKit設定/xcstrings/関連決定を照合、one sec公式とRevenueCat 2026・Duolingo番組紹介を確認。アプリ横断の期間別転換率を因果と扱わない。ASCライブ価格、実機配信、ユーザー実測・売上、A/Bは未確認。検討のみのためビルド・テストは実行していない。


## 2026-09-06 — 無料期間終了前通知の2つの不整合を修正

- オーナー依頼「不整合は治して」に対応。7日無料・通知カード・2日前/3日前選択は維持。検討時のUI簡素化は実施していない。
- 変更パス: `ios/DopaBreak/PaywallView.swift`、`AppContainer.swift`、`LockSurfaceCoordinator.swift`、`Localizable.xcstrings`、`ios/DopaBreakTests/MeasurementFoundationTests.swift`、`docs/11_ui_copy.md`、`.claude/specs/i18n-launch-inventory.md`、検討レポート、検証ログと本記録。
- 採用: `TrialReminderNotificationSchedule`が正規化した選択日数・予約日・通知タイトルをまとめて保持し、3日前でも「あと2日」になる固定文を解消。ja/en/koを同じ数値引数へ変更。既存の通知IDは取り消し・タップ先との互換のため維持。
- 採用: ペイウォールはOS許可とアプリ内のプラン通知設定の両方で表示を判定。プラン通知OFF時は専用説明を表示し、ピッカー・OS許可/設定ボタンを出さない。表示時・アプリ復帰時に設定を再取得する。
- 却下: プラン通知を暗黙にONへ戻す案は利用者の設定を尊重するため不採用。2/3日前の選択を廃止する案は今回の修正範囲に含めない。
- 検証: iOS26.5のDopaBreak専用QA Simulatorでアプリ/テストのビルド成功。MeasurementFoundationTests 54件中53成功・撮影専用1スキップ・失敗0。追加4テストでOS状態とプラン設定の6組み合わせ、2/3日前の予約日・日英韓のタイトル、不正保存値の正規化を確認。ローカライズ監査824呼び出し、mismatch/missing/unresolved/specifier-type/unknown-target全0。コピーlint成功（無関係の既存読点注意3件）。関連差分空白検査成功。
- ログ: `.claude/verification-logs/2026-09-06-trial-reminder/`。本番購入・実機への通知配信・TestFlight更新は行っていない。既に端末に予約済みの通知は修正版の次回再スケジュール時に置き換わる。7日以外の試用期間への対応は引き続き別件。

## 2026-09-06 — ショートカットの複数対象を先頭へ推測しない

- 対象: `InterventionTargetResolutionPolicy.swift`、`AppContainer.swift`、`Localizable.xcstrings`および対応テスト。
- 採用: アクションのアプリ未指定時は有効な対象が1種類だけの場合に限り解決。複数の場合は介入/設定済み記録を行わず、アプリ指定を案内。日本語/英語/韓国語を追加。
- 却下: 並び順の先頭を採用する案は別アプリを設定済みにするため不可。既存履歴の一括リセットは正常な記録も失うため行わない。
- 制約: ユーザーはX明示と回答しており、この修正が今回の原因だとは断定しない。実機でTikTok記録あり/X記録なしを確認し追加調査中。詳細とテスト結果は `.claude/verification-logs/2026-09-06-shortcut-target/result.md`。TestFlight未反映。

## 2026-09-06 — オートメーションのチェックリストをユーザー申告へ変更

- ユーザー明示: 自動で設定済みにせず、設定したかユーザーが選べるようにする。
- 変更パス: `ios/DopaBreak/AutomationGuideView.swift`、`OnboardingFlow.swift`、`Localizable.xcstrings`、Coreの`Storage/SettingsStore.swift`、`DopaBreakCoreTests.swift`、`LocalDataResetterTests.swift`。
- 採用: 設定ガイドとオンボーディングで共通の手動チェック行を利用。行全体が44pt以上のボタンで、チェックの付け外し、選択状態の読み上げ、再起動後の保存に対応。設定済み表示と進捗は新しいconfirmedAutomationCatalogIDsだけを見る。
- 旧verifiedAutomationCatalogIDsは実行履歴として維持し、チェック状態へ移行しない。ショートカットを起動してもチェックは変わらない。履歴を介入/削除案内等から全面削除する案は、実際の自動化の実行処理に影響するため不採用。
- 設定済みはユーザー申告であり、チェック操作がiOS側のオートメーションを作成/削除する機能ではない。ガイドに設定後のチェックと削除後の解除を案内。自動化の動作確認そのものは引き続き利用者が行う。
- 検証: Core4件（保存・解除・自動履歴との独立・データリセット）成功。既存iOS介入ルーティング37件成功。日英韓ローカライズ監査826呼び出しでmissing/mismatch等0、差分空白検査成功。TestFlight・実機は未更新。

## 2026-09-06 — 修正をTestFlight 1.0 (4)へ配布

- ユーザーの再ビルド/アップロード依頼で、本体と4拡張のInfo.plistおよびproject.ymlのCFBundleVersionを4へ更新。チェックリスト手動化等、現行修正を含むReleaseを既存内部グループへ配布。
- Apple VALID / IN_BETA_TESTINGを確認。直前のチェックリスト手動化の「TestFlight未反映」を更新する。ビルド中ソース変更なし、IPAの5対象のバージョン一致を検証。
- 配布ログ: `.claude/verification-logs/2026-09-06-testflight-b4/result.md`。購入キャンセル②は実機未確認。Pro状態を強制解除するコードは追加していない。

## 2026-09-06 — Free状態へ戻すTestFlight用テスト切替

- ユーザー依頼: 購入済みProをFree状態へ戻したい。Sandbox履歴のクリア・復元・通常更新ではProが維持されたとの報告を受け、テスト専用のローカル切替を実装。
- 変更: `ios/DopaBreak/StoreService.swift`、`SettingsView.swift`、Coreの`Storage/SettingsStore.swift`、`MeasurementFoundationTests.swift`、本体/4拡張Info.plistとproject.yml。
- 採用: `DOPABREAK_TESTFLIGHT`コンパイル条件を明示したビルドだけで、設定Pro行の直下に「Freeでテスト（TestFlight限定）」を表示。オンではアプリの機能判定をFreeにするが、StoreKitの解決済み権利とキャッシュを保持。オフで元の権利へ戻る。再起動後も維持。購入が検証成功、または復元のAppStore.sync成功時に切替を解除。キャンセル/保留/エラーでは保持。
- 通常のビルド設定にはこのコンパイル条件を追加しない。通常ビルドは保存済みのテスト設定を無視。ビルド5はテスト専用で、App Store公開用には条件なしで再ビルドする。
- 却下: 本番の権利を強制失効させる案、全データを消去する案、Appleの購入を模擬成功/模擬キャンセルへ置換する案は採用しない。
- 制約: Apple側の購入履歴は変えないため、未購入アカウントと同じ購入確認画面が必ず出るとは限らない。この切替だけでは購入キャンセル②の実機検証完了とは扱わない。Freeの制限は既存処理を通る（複数対象等の制限を含む）。
- 検証: 新規iOSテスト成功。購入済みキャッシュ維持、Free表示、再起動維持、通常ビルドの無効化、解除時のPro復帰を確認。配布証跡は `.claude/verification-logs/2026-09-06-testflight-b5/`。

- 上記のFreeテスト用ビルド1.0(5)をTestFlightへ配布完了。Apple VALID / IN_BETA_TESTING。通常公開用ビルドではDOPABREAK_TESTFLIGHT条件を付けないこと。端末上のFree切替操作は未実施。


## 2026-09-07 — Annual Launchを今回の販売から除外

- オーナー依頼「整理して…審査出して」に対応。StoreServiceの年額切替とLaunchへのフォールバックを削除し、販売商品取得は月額・通常年額の2商品へ限定。StoreKitテスト設定からもLaunchを除外。
- 変更: ios/DopaBreak/StoreService.swift、ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/EntitlementGate.swift、ios/DopaBreak/DopaBreak.storekit、MeasurementFoundationTests、Info.plist5件、project.yml。公開ビルド7。
- 旧商品IDは購入履歴の認識と復元互換のみ残す。旧権利を失効させる案や、日本語UIにJPY価格を固定する案は不採用。
- 検証: MeasurementFoundationTests 56件中55成功、撮影専用1スキップ、失敗0。新規販売の2商品限定と旧商品認識を回帰確認。TestFlightのUSD/JPY不整合は今回のコード変更で解消したとは扱わない。


## 2026-09-07 — 公開用1.0(7)を審査提出

- Annual Launchの商品登録もオーナー意図を確認して削除。月額・通常年額・グループ・本体の同一提出物がWAITING_FOR_REVIEWに到達。承認後は手動公開。
- RevenueCatはユーザー/収益分析の意図で設定済みだった。SDK不在から不要と判定した見立てを訂正し、サーバ通知URLを維持。RevenueCat管理画面で新規購入追跡ONと実受信を確認。
- プライバシー申告を「ユーザID・購入履歴／分析／ユーザに関連付け／トラッキングなし」に訂正して公開。利用記録・Screen Timeの外部分析は追加しない。法務サイトprivacy-ja/en/koを既存Pages公開先で更新。
- 証跡: .claude/verification-logs/2026-09-07-appstore-b7/result.md。TestFlightのUSD/JPY不整合は今回の変更で修正済みとはしない。

## 2026-09-07 — オンボーディングのCVR改善仮説（レビューのみ）

- 依頼: 現行オンボーディングで転換率を上げる施策を提案。
- 変更パス: `docs/reviews/2026-09-07-onboarding-cvr.md`、本記録。製品コード変更なし。
- 推奨: 通知許可・実ロック画面確認の後置を最初の実験にする。続いて課金割り込みの整理、短い操作デモ、目標の1タップ選択、回答とPro便益の接続を検証する。
- 採用したレビュー方針: 最大18ステップと条件付きスキップ、16番目の主課金導線、複数対象/Proモードの早期課金を区別。既存の個別推計・テーマプレビュー・サマリーは維持対象として評価。
- 却下: 画面数だけを根拠に全短縮、ショートカット設定を無条件に課金後へ移動、Free機能をProとして訴求、他社の改善率を予測へ転用。実際の設定成功と継続を損なう可能性があるため。
- 制約: コード静的確認とApple/RevenueCat資料参照。実機・実ユーザーCVR・A/B結果は未確認。計測はローカル中心で、外部分析追加は端末内保存の説明と整合させる必要がある。既存の手動設定チェック方針は変更しない。レビューのみのためビルド/テストなし。

## 2026-09-07 — Pro価値のオンボーディング確認（追加レビュー）

- 変更パス: `docs/reviews/2026-09-07-onboarding-cvr.md`、本記録。製品変更なし。
- 判定: 課金画面の機能説明は揃っているが、購入前の具体的体験はテーマに偏る。一呼吸デモはFreeの基本価値として区別する。
- 次回候補: 既存モード/サマリー内で生活場面とPro便益を接続。新規の説明ステップ追加は負担が増すため優先しない。
- 制約: ソース確認のみ。CVRの因果・実機挙動は未検証。ユーザーの審査時間ロス回避を優先し、再提出・実装は行わない。

## 2026-09-07 — ショートカット・再介入の仕様照合監査

- 成果物: `docs/reviews/2026-09-07-shortcut-reintervention-spec-audit.md` と同日のテスト証跡。既存の初期調査メモへ訂正を追記。アプリ/UI実装は変更していない。
- 採用する基準: 9月5日の累積実利用時間・目的別通知/ブロック仕様と、9月6日の手動チェック仕様。時間枠内の再オープンは通過で正しい。
- 確認: ホームだけ手動チェックを読まず設定未完了と断定する表示不整合。URL起動の自己起動判定欠落、古い要求の検証履歴化、旧正本との矛盾も報告。イベント棄却後/監視欠落時の回復不足は実機症状の候補として区別。
- 却下: 毎回の起動に呼吸を追加、12時間期限を選択分数へ単純短縮、複数対象の先頭を推測、手動チェックを自動履歴で上書き、実機原因を設定ミスと断定する案。最新仕様や確認できる事実に合わないため。
- 検証: 今回Core64件・iOS56件、計120件成功。本体/拡張ビルド成功。実機のOSイベント配送とインストール済みビルドは未照合。修正実装・配布は監査依頼の範囲外として未実施。

## 2026-09-07 — ホームの手動チェック参照と設定状況への導線

- ユーザー依頼: 手動で設定済みを選ぶ場所が分かりにくいため、ホームの参照修正と一緒に直す。
- 変更パス: `ios/DopaBreak/HomeView.swift`、`AutomationGuideView.swift`、`OnboardingFlow.swift`、`Localizable.xcstrings`、`ios/DopaBreakTests/SettingsDeviceFixesSnapshotCapture.swift`。証跡は `.claude/verification-logs/2026-09-07-manual-automation/`。
- 採用: ホームの案内をconfirmedAutomationCatalogIDsで判定。未チェックは「設定状況を確認」とし、直接チェック欄を開く文言に変更。対象アプリカードへ件数付きの常設リンクを追加し、全件チェック後も見直せる。ガイド内のチェック欄は動画・手順の前へ移す。既存カードと共通チェック行を再利用。タップで付け外しする説明を日英韓と初回設定に揃える。
- 却下: 手動チェックを自動実行履歴で上書きする案、チェック欄専用の新しいモーダルを増やす案、ホーム上部に全対象のチェックリストを常時展開する案。ユーザー申告の意図を維持し、既存の導線を1タップで使え、ホームを長くしすぎない構成を採用した。
- 制約: 未指定アプリのエラー、再介入の実利用時間計測、ショートカット自体の設定には変更なし。申告はiOS側の自動化の作成/削除を行わない。今回2枚目の症状は閉じている時間を含めて考えたことによる正常動作であり、仕様変更不要とユーザー確認済み。
- 検証: 関連38件成功、共通文言修正後の描画1件再実行成功。本体/拡張ビルド、3言語文言監査、通常/大きな文字の画像確認済み。審査中ビルドの変更・配布・実機インストールは未実施。

## 2026-09-08 — ペイウォールの法務リンクを購入ボタン下へ固定

- 依頼: 利用規約・プライバシーを購入ボタンの後ろ/スクロール末尾ではなく、ボタン直下に固定する。
- 変更パス: `ios/DopaBreak/PaywallView.swift`。証跡: `output/review/2026-09-08-legal-links/ipad-fixed-links.png`、`ipad-fixed-links-share.mp4`。
- 採用: 既存safeAreaInsetのfixedActionBar内を購入ボタン→法務リンク→復元/あとでの順にする。リンクは14pt、primaryText、下線付き、各44pt以上のタップ領域。自動更新の説明は既存スクロール領域に残す。既存URLとローカライズキーを維持。
- 却下: スクロール末尾にリンクを残す案は見つけにくさが残るため不採用。画面への重ね置きは購入ボタンとの重なりを生むため使わない。
- 検証: Xcode Debugシミュレータビルド成功、変更ファイルdiffチェック成功。iPad Air 11-inch (M2) / iOS 26.5 / 英語UIで初期表示、スクロール、TermsとPrivacyの両ページ遷移を確認して録画。購入・復元の決済は実行していない。
- 制約: ローカル検証ビルド。提出済みビルド7には未反映。新ビルドのアップロード・App Reviewへの送信は未実施。

## 2026-09-08 — 固定法務リンクを含む1.0(8)を再提出

- ユーザー依頼によりproject.yml・本体/4拡張Info.plistのビルド番号を8へ更新。既存の却下提出を再利用し、月額・年額・グループを維持してビルド8へ差替え。2026-09-08 19:40 JSTにWAITING_FOR_REVIEW。承認後は手動公開。
- IPAの全バンドル署名、4対象のFamily Controls、Apple VALID、app/subscriptionsブロッカー0を確認。Review Notesへ固定リンクの導線を追記し、シミュレータ録画と明記した修正後動画を添付。
- 返信は作成依頼に合わせてApp Store Connectへ下書き保存、未送信。重複提出・新規証明書作成・自動公開は不要なので採用しなかった。
- 証跡: `.claude/verification-logs/2026-09-08-appstore-b8/result.md`。ローカル動画を提出済みバイナリそのものの録画とは扱わない。

## 2026-09-10 — 海外オーガニック短編用の主人公案

- 依頼: 参考アカウントの黒いキャラと同じにならない独自の主人公を作成。初回の頭の形への指摘と脳モチーフの相談を反映して修正。
- 変更パス: `creatives/organic/characters/lavender-v1/`、`creatives/organic/characters/brain-v2/` の各 `character-sheet.png`、`README.md`、`prompt.txt`、本記録。
- 制作方針: 手描き風2D、生成りのスウェットと青灰色のパンツ、成人の生活を描ける姿勢。修正版では丸い脳の輪郭・中央の溝・ローズピンクの肌に変更。全身、横向き、4表情、夜の使用場面を1枚に収録。組み込みimage_genで生成・編集し、全プロンプトを保存。最終採用・名称は未確定。
- 却下: ラベンダー案の尖った頭は「形が意味不明」というユーザー指摘により不採用。黒い人物の単純な色替えも独自性が弱いため使わない。光沢3Dは直近の静かなイラスト短編の方向と合わないため今回は使用しない。
- 確認: 生成画像を目視し、脳の輪郭と溝、服装、全身と表情、夜の場面を確認。workspaceへのコピーのバイト一致とPNG寸法を確認。
- 制約: ラスターの初期デザイン案。個別透過ポーズ、レイヤー、動画リグ、動画は未制作。アプリ内キャラクターとアイコンは変更していない。物語の結末に毎回アプリ宣伝を入れない方針を維持。

## 2026-09-10 — 英語引用ポスト用の実画面5枚

- 変更パス: `output/social/2026-09-10-quote-en/`。アプリコード変更なし。
- 採用: 英語の呼吸、目的選択、開くか決める画面、10分設定、実ロック画面を未加工PNGで保存。目標はApp Storeの現行英語素材と同じ4項目に統一。
- 却下: 最初のSpeak English等の目標はユーザー指摘で不採用。App Store訴求枠と生成モックは使わない。
- 確認・制約: 1320×2868の5枚を確認。iOS 26.5 Simulatorのインストール済みアプリ。目標編集に16文字制限があるため撮影データを直接設定。ロック時のActivity再生成競合があり、アプリを一時停止してOSの実カードを撮影後、再開。手順と制約をREADMEへ記録。物理端末や配布版の動作検証ではない。

## 2026-09-11 — Apple Ads分析データの削除案内

- 変更パス: `ios/DopaBreak/SettingsAboutView.swift`、`AppleAdsMeasurement.swift`、`Localizable.xcstrings`、`docs/marketing/apple-ads-privacy-ready/`。
- 採用: プライバシー設定に匿名分析ID・コピー・サポートリンクを追加。既存カードとSettingsRowを再利用。未購入者も削除依頼できる。計測無効時は表示しない。日英韓対応。
- 却下: ローカル削除ボタンで外部データまで削除できたと見せる案。実際の処理が異なるため。IDの自動メール送信も行わない。
- 制約: 計測5テスト・本体ビルド成功。スタブ使用で外部送信なし。新しい表示の画像確認・公開ページ反映・App Privacy反映・アプリ配布は未実施。SDK送信フラグはNO。

## 2026-09-11 — 計測有効版1.0.1 (9)の審査提出

- 変更パス: `ios/project.yml`、本体/拡張Info.plist、`ios/Configs/Shared.xcconfig`、`docs/marketing/apple-ads-privacy-ready/`。計測ON、全5バンドルを1.0.1 (9)に統一。
- 既存1.0.1の提出枠を使用。日英韓ポリシーを公開し、ユーザー明示承認後にApp Privacyの購入履歴・広告データ・製品の操作を公開。既存デザインは維持。
- 検証: 起動・計測25件成功、Release archive/export成功、IPA署名・権限・計測ON、Apple VALID、提出ブロッカー0。19:01 JSTにWAITING_FOR_REVIEW確認。証跡 `.claude/verification-logs/2026-09-11-appstore-b9/result.md`。
- 制約: 承認後は手動公開。実広告経由の本番購入・sandbox購入は今回未検証。重複提出と自動公開は不要のため実施しなかった。

## 2026-09-13 — Gemini 3.8で全画面の日英韓文言を改善

- 依頼: Gemini 3.8で日本語・英語・韓国語の全画面文言を修正する。
- 変更パス: `ios/DopaBreak/Localizable.xcstrings`、`ios/ShieldConfigExtension/Localizable.xcstrings`、`ios/WidgetsExtension/Localizable.xcstrings`、対応するSwiftフォールバック11ファイル、`ios/DopaBreakTests/CoreScreensSnapshotCapture.swift`、`docs/11_ui_copy.md`。差分・元文・Gemini回答・採否・監査結果は `output/review/2026-09-13-gemini-copy/`。
- 採用: `gemini-3.8-flash` を実APIで使用し、Monitorを含む全4カタログ2,310文字列（日769・英772・韓769）をレビュー。69キー94文字列（日26・英33・韓35）を改善。空白でつないだ日本語の説明、英語の硬さ、韓国語の翻訳調を整えた。Pro再開と自動化削除の異なる結果を明記し、「再介入」は通知またはブロックという表示に変更。元の数値・変数・改行数は維持。
- 却下: GeminiのiOS 26→18、試行回数→実際の起動回数、起床時刻→朝、Deep Focus→Full Block、手動チェック→対象選択といった意味を変える案。引用されたOSの操作名・法務条件・テーマ名は維持。自然な既存文まで一律に書き換える案も採用しない。
- 方針: `humanize-with-gemini` の通常対象外であるコード内文字列について、今回の明示依頼を優先して表示文言だけ抽出した。各表示文字列を独立した本文／ラベルとして監査し、無関係なラベルの連なりを記事の文体として矯正しない。採用94件は各言語の監査exit 0、Swiftフォールバック831呼び出しの不一致・欠落・未解決・型不一致は0。
- 撮影テスト修正: `testCaptureCoreScreens` 系の目標fixtureは既に4件だったが、件数期待値だけ3件のままだったため4へ修正。別の3件fixtureは変更しない。
- 制約: 文言カタログ全件のレビューであり、OSが表示するシステム文言や動画に焼き込まれた文字は改稿しない。公開・配布・実機へのインストールは行っていない。画面確認の結果は同ディレクトリのREADMEへ追記する。

- 同日追加: 実画面で残存を確認した「再介入／재개입」についてGeminiで24文字列を追加レビューし、8キー16文字列を採用。最終77キー110文字列（日34・英33・韓43）、監査110件すべてexit 0。Swift変更は `PostUseReflectionSheet.swift`、`ReinterventionScheduler.swift` を含む13ファイル。機能名は「利用時間の通知・制限／사용 시간 알림·차단」。解除対象は接続、通知・制限を省く範囲は今回の利用であることを維持。

- 最終表示調整: 英語設定画面の `3 seconds` がチップ内で3行へ折り返すことを確認。Geminiによる `3s / 5s / 8s` を採用し、80キー113文字列（日34・英36・韓43）へ。レイアウトは変えず表示文字数で解決。監査113件すべてexit 0。

- 最終検証: 本体・拡張・テストビルド成功。関連30件に加え、追加修正後の関連8件も成功。撮影fixtureの不整合を修正し、日英韓各10画面を撮影。主要画面の目視確認と英語秒数チップの折返し解消を確認。検証専用4端末は削除済み。詳細は `output/review/2026-09-13-gemini-copy/verification.md`。配布・公開・実機インストールは未実施。

## 2026-09-16 — 日本のX投稿向け3画面

- 変更パス: `output/social/2026-09-16-x-ja/`。アプリソース変更なし。
- 採用: 日本語の呼吸・Pro時間指定の既存実画面素材と、女性会社員向けサンプル目標3件のOSロック画面。TOEIC800点、12月までに3kg減、来年9月までに100万円貯金。
- 却下: 生成モック・画像上の文字差し替えは実際の表示を示せないため使用しない。
- 確認・制約: 3枚を目視確認。1320×2868 PNGとZIP。Simulator撮影であり実機検証ではない。ロック撮影時の一時停止・再開とデータ設定は同フォルダREADMEに記録。公開・投稿なし。

## 2026-09-20 — 海外オーガニック短編動画パイプラインの設計（実装前）

- 依頼: ピクサー風と手描き2Dの2画風で、同じ主人公（brain-v2）による英語短編を量産するパイプライン。biohackjapanの動画パイプラインを元にする。
- 変更パス: `.claude/specs/organic-video-pipeline-2026-09-20.md`（設計書のみ。コード未着手。実装先は `video/organic-pipeline/`）。
- 採用: 骨格は配布用 `~/Desktop/pixar-video-pipeline`、画風分岐だけ本家から移植。1本のパイプラインで `--style pixar|illust` を切替え、画風で変えるのはプリセット（キャラ記述・画風・動きの指示・参照画像）だけにして、尺・字幕・BGM・ナレーション・CTAは共通（2D/3D比較試験で画風以外を変数にしないため）。人物は喋らず、英語ナレーションをElevenLabsで別録りして重ねる。字幕はTTSの文字タイミングから作り、Whisperは使わない。字幕位置はReels/TikTokの安全領域を避け高さ60%。透かし・本編末尾の宣伝は入れない（企画方針を維持）。
- 却下: 本家ベース（台本自動生成が不在で動かず、企画立案が栄養DB専用）。Veo 3.1（音声を消せず声も固定不可）。動画と声を一発で作る一体型（ナレーターの声を指定する仕組みがない）。GPT Image（公式ガイドがキャラ一貫性の崩れを明記）。
- 確認・制約: モデルIDは公式ページで確認（`gemini-3.1-flash-image`／`grok-imagine-video-1.5`／ElevenLabs `/with-timestamps` は文字単位）。Grokの無音指定と2D画風の保持は公式に仕様がなく、小テストで判定する。生成・投稿は未実施。企画と台本は別途オーナーと議論する。


## 2026-09-20 — ASA是正バッチ S1〜S5

- 変更パス: `ios/DopaBreak/{OnboardingFlow,HomeView,AppContainer,DopaBreakApp,StoreService,PaywallView,AppleAdsMeasurement,InterventionFlowModel,InterventionFlowView}.swift`、`Localizable.xcstrings`、Coreの`SettingsStore.swift`・`ReviewPromptPolicy.swift`、対応するアプリ/Coreテスト、`docs/11_ui_copy.md`・`docs/18_retention_notification_review_design.md`。全ファイル一覧・検証ログ・画面は `output/verify/asa-fix-2026-09-20/`。
- S1: blockSetupの「あとで」はreadyへ進むだけ。選択中モードとpendingInterventionMode、ルール、Pro判定を保持する。未設定バナーから既存ブロック設定へ誘導。シールドを張る前提条件は変更しない。
- S2: StoreServiceの商品取得をloading/loaded/failedで表現。空・不足結果もfailed。価格のスケルトン、失敗文言、購入ガード、再読み込みを追加。取得失敗や読み込み中も復元導線を維持し、法務リンクは購入ボタン直下のまま。
- S3: SettingsStoreに任意Intの進捗を保存。welcome/selfCheck以外を再開し、完了時にクリア。途中クイズの回答も端末内保存し、再開後に最後の回答を保存できない不具合を防ぐ。選択アプリ・選択モード・保存済み結果も復元。AppleAdsMeasurementの既存クライアント経路でonboarding_last_stepを1秒デバウンスして更新。SNS名や回答内容は送らない。
- S4: レビュー閾値を2回・0日に変更。90日クールダウン、365日3回、通常win表示1.5秒後と失敗時抑止を維持。体験中は要求しない。
- S5: AppIntent/URLの検証を共通で受け取り、permission画面上に既存InterventionFlowViewを全画面提示。体験フラグで通常の呼吸・理由・時間・winを通し、時間決定は「一呼吸の体験を終える」として外部SNSを起動しない。体験中は既存の利用時間枠を変更しない。winに「これが一呼吸です」を足し、閉じるとnotificationGuideへ。完了を永続化し、同時提示と完了後の再提示を抑止。breathing_completedも通常と同じ完了処理で立てる。検証発火なしの既存導線は維持。
- 却下: S6の体験シールド・無料/Pro境界変更、blockSetup延期時のstandardへの降格、オンボ体験からSNSを起動してオンボから離脱させる案。今回の範囲と体験完走に合わないため。EntitlementGateは触れていない。通知許可の位置も変更しない。
- 検証: Simulator本体/拡張/テストビルド成功、Core全569件成功。アプリ関連120件成功（既存の文言期待値1件を修正して再実行、最終UI変更後の関連7件成功を含む）。日本語3画面・PNG4枚の描画を確認。実機のShortcuts/FamilyControlsと本番RevenueCat受信・実購入は未検証。公開・配布なし。


## 2026-09-20 — ASA S1〜S5 レビュー修正

- 変更パス: `ios/DopaBreak/OnboardingFlow.swift`、`ios/DopaBreak/PaywallView.swift`、`ios/DopaBreakTests/MeasurementFoundationTests.swift`。
- 採用: blockSetupはProまたは権利未確認ならusesShield条件で表示する。「あとで」は購入処理中のみ無効化する。延期後の未設定状態とホームのバナー表示条件を両ブロックモードで検証する。
- 却下: isProのみでのスキップ判定（購入直後の権利未確認で設定を飛ばすため）、商品取得中の閉じる操作の無効化（読み込み待ちから退出できなくなるため）。
- 検証・制約: iOS Simulator向けbuild成功、S1回帰テスト1件成功、DopaBreakCore全569件成功。実購入・実機FamilyControlsの確認は今回の対象外。

## 2026-09-20 — S6（改）呼吸画面の目標表示

- 変更パス: `ios/DopaBreak/InterventionFlowView.swift`、`ios/DopaBreak/Localizable.xcstrings`、`ios/DopaBreakTests/MeasurementFoundationTests.swift`、`docs/11_ui_copy.md`、本記録。
- 採用: 呼吸アニメーションの下に「目標を思い出しましょう」を中央・1行で表示し、flow.goalsの先頭最大5件を既存順で表示。usageSummaryScreenの丸印・18pt太字・行間を共通関数で再利用し、目標0件では見出しとカードを非表示にする。日英韓の指定文言を追加。呼吸時間・進行・タップ操作と利用状況画面の編集導線は維持。
- 却下: 体験シールド案はオーナー決定に従い採用しない。現行呼吸画面にCTAはないため新しい操作は追加しない。空目標の案内を呼吸画面へ複製する案も非表示要件に合わないため不採用。
- 検証: iOS Simulatorの本体・拡張・テストビルド成功。追加1テストは目標0件/5件×375×667/440×956の4描画を保存し、OCRで見出し・各目標の有無を検証して成功。小画面の2画像を目視確認。初回の描画失敗はテスト用ウィンドウのscene未接続を修正し、再ビルド・再実行で解消。既存の呼吸・体験・文言関連14テストも成功。3言語のカタログ値と差分の空白検査も成功。
- 制約: Simulator上での検証。実機確認・公開・配布は未実施。ビルドとテストログは `/tmp/dopabreak-s6-build.log`、`/tmp/dopabreak-s6-tests.log`、`/tmp/dopabreak-s6-snapshot.log`、画像は成功したテストのxcresult添付に保存。

## 2026-09-20 — 呼吸画面のDynamic Typeレビュー修正

- 変更パス: `ios/DopaBreak/InterventionFlowView.swift`、`ios/DopaBreakTests/MeasurementFoundationTests.swift`、本記録。
- 採用: 呼吸画面をScrollViewで包み、stepScaffoldと同じ `.scrollBounceBehavior(.basedOnSize)` を適用。画面高を最小高にして短い内容の中央配置を維持し、長い目標は文字サイズを制限せずスクロールで到達可能にする。
- 却下: 目標へのdopaDisplayClamp適用は拡大表示を維持するため採用しない。呼吸画面には下部ボタンが存在しないため追加しない。
- 検証: `.accessibility5`・長い目標5件で375×667/440×956の上端から下端まで撮影し、見出しと全5目標のOCR検査・下端到達検査に成功。両サイズの上端・下端を目視確認。既存の0件/5件表示検査もスクロール下端を含めて成功。撮影中のタイマーはfixtureで停止。Git HEADから識別子安定性テストを復元し、既存blockSetup追加後の18ステップとanalyticsIdentifierの一致を検証。
- 結果・制約: Simulator本体・拡張・テストビルド成功。関連10件成功、撮影fixture修正後に表示2件成功（最終12件成功）。最初の端末でテスト開始待ちが続いたため呼吸画面用Simulatorへ切替。ログ `/tmp/dopabreak-breath-review-build.log`、`/tmp/dopabreak-breath-review-tests-retry.log`、`/tmp/dopabreak-breath-review-snapshots.log`。成功画像 `/tmp/dopabreak-breath-review-images/`。実機は未検証。


## 2026-09-20 — App Store S9/S10（改）9枚セット

- 変更パス: `scripts/generate-appstore-screenshots-v2.py`、`scripts/generate-appstore-theme-gallery.py`、`scripts/capture-appstore-breathing-goals.sh`、`scripts/validate-appstore-s9-s10.py`、`ios/DopaBreakTests/MeasurementFoundationTests.swift`の撮影fixture、`output/app-store-screenshots/v2/`、`output/verify/appstore-s9-s10-2026-09-20/`。
- 採用: 目標表示→ロック画面→一呼吸→完全ブロック→夜→白黒→本音→時間→テーマの9枚。1枚目は実際のSwiftUI画面を440×956ptのSimulatorで3言語撮影し、目標3件を全体表示。1・3枚目のみラベル・見出し・副文を新規作成し、肯定形・1行見出し・中央・体言止め。その他の承認済み表示コピーは維持。
- 構図: 斜めライムと既存の帯・円・左右ウェッジ・リボンの変化を維持。新規1枚目は全端末を収める細帯構図。テーマは既存実画面カードを再利用し、価格掲載なし条件で料金バッジとフッターを外しawakeを1体追加。各画像ちょうど1体。
- 却下: 目標を画像上で描き足すモック（実画面撮影要件を満たさない）、1枚目へ旧呼吸パネルの大きなクロップを流用する案（目標が切れる）、6.5版を縦横別倍率で引き伸ばす案（字形が変わる）。intentは単独枠から外し一呼吸の副文へ統合。stats・intentの元素材と6.9生成経路は保管。
- 検証: テストビルド成功、3言語の撮影テスト計3件成功。3言語×3サイズ×9枚の81枚が内部検証PASS。ascローカル検証は全9セットready9/9・error0・warning0。枠1・3の18画像で表示コピーと目標のOCR欠落0。humanizer-en/ko全ゲートPASS、jpはスクリプト不在のため手動監査。
- 制約: 物理実機ではなくSimulator実UI撮影。その他画面は既存素材を再利用。iPadはiPhone画面を使う既存マーケティング仕様。6.5の座標メタデータは6.9原寸座標＋変換情報。App Store Connectへのアップロードなし。詳細と全文コピーは `output/verify/appstore-s9-s10-2026-09-20/README.md`。


## 2026-09-20 — App Store画像のオーナー修正

- 変更パス: `scripts/generate-appstore-screenshots-v2.py`、`scripts/validate-appstore-s9-s10.py`、`output/app-store-screenshots/v2/`、`output/verify/appstore-owner-feedback-2026-09-20/`。
- 採用: 呼吸単独枠を外した8枚順を3言語・3サイズへ反映。枠1は指定見出しを維持し、重複する副文を短縮。iPhone端末幅1100px・iPad1040px、見出し→副文→端末の間隔32px。斜めライム帯・1体・目標3件を含む端末全体の表示を維持。内部生成IDは素材参照のため保持し、アップロード名とupload_positionは01〜08へ連番化。
- 却下: 元の900/920px端末と固定副文位置は余白が大きいため不採用。目標リストを切る端末拡大は要件に反するため不採用。
- 検証: 全72枚のスクリプト検証PASS。ASCローカル検証9セット・72枚ready・error/warning各0。英韓コピーは各表示欄ごとのhumanizer初回・最終比較監査PASS。3言語iPhone/iPadの枠1を目視確認。
- 制約: 既存Simulator画像を再利用。iPadは既存仕様のiPhone画面素材。アップロード・公開なし。詳細は今回の検証README。

## 2026-09-20 — 無料トライアル終了前リマインダーの廃止（オーナー決定）

- 変更パス: `ios/DopaBreak/{AppContainer.swift,LockSurfaceCoordinator.swift,PaywallView.swift,Localizable.xcstrings}`、`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/{Services/NotificationRouting.swift,Services/RetentionNotificationPolicy.swift,Storage/SettingsStore.swift}`、`ios/DopaBreakTests/MeasurementFoundationTests.swift`、`ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/{NotificationRoutingTests.swift,RetentionNotificationPolicyTests.swift,SettingsStoreTests.swift}`、`docs/11_ui_copy.md`、`docs/18_retention_notification_review_design.md`、本記録。
- 採用: 終了前通知の予約・日付計算・日数設定・ペイウォールカードと専用通知権限要求・ja/en/koの13文言キーを削除。旧ID `dopabreak.trialday5` は廃止済み通知一覧にのみ保持し、既存の起動時cleanupで予約済み・配信済み通知を解除する。権限やentitlementの確定を待たずに実行する既存経路を使用。専用通知カテゴリ・専用Settingsトグルは存在しない。
- 維持: トライアル自体、StoreServiceとentitlement判定、他の通知（D1/D3/D7、無料月次、振り返りを含む）。プラン通知の共通トグルは月次・年次更新等にも使うため維持。
- 却下: 旧通知IDを完全消去する案は既存予約を解除できなくなるため不採用。共通プラン通知トグルの削除は他通知の設定を変えるため不採用。本決定を以前のトライアル通知選択UI・通知維持方針より優先する。
- 検証: iOS Simulator本体・拡張ビルド成功。Core関連53件、Simulator関連18件、ペイウォール実表示3件、合計74件成功・失敗0。削除対象以外のxcstringsエントリが変更されていないことと差分の空白検査を確認。
- 制約: 実機の既存通知予約を使うアップグレード検証は未実施。SimulatorテストはローカルStoreKit fixtureを使用し、本番購入・公開・配布なし。ログは `/tmp/dopabreak-trial-build.log`、`/tmp/dopabreak-trial-core.log`、`/tmp/dopabreak-trial-tests.log`、`/tmp/dopabreak-trial-ui-tests.log`。

## 2026-09-21 — オンボーディングv3（2026-09-20オーナー仕様）

- 変更パス: `ios/DopaBreak/{OnboardingFlow.swift,HomeView.swift,SettingsView.swift,SettingsAboutView.swift,Localizable.xcstrings}`、`ios/DopaBreakTests/{MeasurementFoundationTests.swift,HomeGoalsCopyTests.swift,InterventionMergeCopyTests.swift,OnboardingMotionCapture.swift}`、`docs/07_onboarding_design_lifefocus.md` §4・§8、`docs/11_ui_copy.md`の見出し・画面数・ロック画面導線、本記録。
- 採用: 目標→対象アプリ→自己申告→スクロールと後悔の1問→損失と回復の1画面→モード→体験→通知→要約→Proブロック設定→完了の最大11画面。目標1件を必須とし、既存例文を選択できるプリセットと指定の日英韓見出しを追加。Deep Focusを既定・おすすめにし、モード画面では選択だけを保存する。ルールへの適用は専用プラン確認後とする。
- 維持: 作業ツリーのS1〜S6、ブロック設定延期と権利未確認時の表示、S3の途中再開、S5の体験完走・再提示抑止、S6の目標表示、ペイウォールCTA。トランジションアニメーションは追加しない。
- 移設: 科学的背景の既存17文言キーと免責全文を設定の「仕組み」へ移す。ロック画面確認とテーマ選択はオンボーディングから外し、初回体験完了またはwinの記録があればホームの確認行から案内を開ける。テーマ選択の既存ホームカードと、目標保存時のLive Activity開始は維持する。
- 永続化: 保存済みの旧rawValueを再利用し、表示順・前後移動・進捗はallCasesから計算する。削除・統合画面の旧値は対応する新画面へ移行。新計測IDは`scroll_regret`、`loss_recovery`、全11識別子は設計書§8に記録。
- 却下: rawValueを0から振り直す案は既存ユーザーの再開先が変わるため不採用。モード選択時の課金提示・Freeへの選択降格、目標スキップ、別ScrollViewへの回復表示は指定フローに合わないため不採用。表示コピーは指定見出し・新しい設定行とおすすめラベル以外は既存の承認済み文言を使用。
- 制約: Simulatorで確認。実機のShortcuts・FamilyControls・Live Activity掲出と実購入・配布は今回実施していない。
- 最終表示修正: 375×667ptの描画で目標見出しの省略と旧rawValue由来の進捗番号を確認して修正。見出し全文と`01 / 11`をOCRで検証。目標を未保存のまま中断した旧フローは、目標必須条件を満たすためgoalSetupへ戻す。
- 検証結果: iOS Simulator本体・拡張・テストのbuild-for-testing成功。DopaBreakCore全562件成功。アプリ全396件は失敗0・既存条件によるスキップ19件。最終表示修正後の関連73件も失敗0。小画面6画面と回復部分を描画し、目標見出し全文・進捗のOCR、単一ScrollView、目視を確認。初回の旧見出し改行期待値1件は更新して解消。表示コピーlintは既存文言3件の要確認のみ、差分の空白検査成功。ログは`/tmp/dopabreak-v3-{final-build,core,app-final,regression}.log`、描画は`/tmp/dopabreak-v3-screens/`。


## 2026-09-21 — オンボーディング11画面の改行修正

- 変更パス: `ios/DopaBreak/{OnboardingFlow.swift,DesignTokens.swift,InterventionModeDisplay.swift,Localizable.xcstrings}`、`ios/DopaBreakTests/{HomeGoalsCopyTests.swift,MeasurementFoundationTests.swift}`、`docs/{11_ui_copy.md,07_onboarding_design_lifefocus.md}`、`output/verify/onboarding-linebreaks-2026-09-21/`、本記録。
- 採用: 375pt・左右20pt・見出し34ptを基準に前置きを短縮。中央揃えで設計サイズの1行を優先し、共有DopaDisplayTextのViewThatFitsが収まらない場合のみ翻訳のU+200Bを意味区切りとして2行へ切り替える。本文16pt、下部注記13ptも共通表示を使用。英韓は空白区切りの単語内にword joinerを適用するフォールバックを持つ。VoiceOverにはマーカーを除いた全文を渡す。
- 確認: dopaDisplayClampは既に巨大数値専用のため維持。目標見出しの40%縮小・ほかの見出しの74%縮小指定を削除。損失/回復の数値と集計ロジックは維持。モードカードの夜の説明も1行へ短縮し、設定画面の共有表示を検証。
- 却下: コード内の強制改行、2行を既定にする案、文字縮小で長文を押し込む案、幅だけで日本語の任意位置に改行させる案。いずれも今回のオーナー要件を満たさない。
- 検証: 修正前後それぞれ11画面×2サイズ×3言語を実SwiftUIウィンドウで撮影（132枚＋下端50枚）。READMEに文言・表示行数の比較表と画像リンクを保存。ビルド成功、撮影/幅/文言21件＋関連回帰93件が最終成功、失敗0。最初の英語幅超過を短縮で修正し、旧文言を言語判定に使っていた既存テスト1件も修正・再実行で成功。
- 制約: Simulatorの固定寸法UIWindow（375×812／430×932pt、PNGは1倍）、実機未確認。Dynamic Type拡大時は全文を読めるよう追加の自然改行を許可。説明段落・利用者入力は短いディスプレイコピーと区別する。配布・公開なし。

## 2026-09-21 — オンボーディングv3レビュー修正

- 変更パス: `ios/DopaBreak/{OnboardingFlow.swift,DesignTokens.swift,Localizable.xcstrings}`、`ios/DopaBreakTests/{MeasurementFoundationTests.swift,HomeGoalsCopyTests.swift}`、`docs/{07_onboarding_design_lifefocus.md,11_ui_copy.md}`、`output/verify/onboarding-linebreaks-2026-09-21/`、本記録。
- 採用: 旧readyのraw 16はreadyへ移行。blockSetupは未使用の18へ移して新規保存と旧値を区別し、現行readyの17は維持。復元とinitialStepの両経路で共通のshouldSkipを適用。Free確定時とstandardはreadyへ進み、権利未確認のブロック系モードは既存方針を維持。
- 採用: 目標見出しを指定の日英韓全文へ戻し、日本語の対象アプリ・完全ブロック・モード見出しと韓国語の追加・変更案内も復元。34ptを維持し、収まらない場合は意味区切り1箇所で2行。DopaDisplayTextの1行・自然改行・VoiceOverが共用するplainTextに空白区切りを残し、日本語5キーにも空白を明示。
- 却下: 16をblockSetupのまま復元する案（旧readyと衝突）、見出しの短縮・縮小（指定された意味と設計サイズを保てない）、U+200Bの単純削除（句が連結する）。
- 検証・制約: Simulatorビルド、Core全件、アプリ全件、3言語×2サイズの実SwiftUI再撮影。最終件数・結果と画像は検証READMEに記録。実機固有のShortcuts・FamilyControls・購入は未検証。


## 2026-09-21 — 目標入力のIMEクリア・追加行の視認性

- 変更パス: `ios/DopaBreak/OnboardingFlow.swift`、`ios/DopaBreakTests/MeasurementFoundationTests.swift`、`output/verify/onboarding-goal-field-2026-09-21/`、本記録。
- 採用: 確定時に入力を空にしてTextFieldの世代IDを更新し、旧フィールドのresign後にFocusStateを復帰。回転プレースホルダーとカウンターの状態は既存のまま維持。入力直下に追加一覧を置き、新規行へ600msのアクセント枠を表示。既存の触覚を維持。
- 採用: 一覧は最大144ptのScrollViewで高さを抑えて最新行へ移動。画面側のScrollViewReaderもキーボード表示完了後に一覧へ移動し、入力欄と最新行の同時表示を確保。Reduce Motion時は挿入・スクロールをアニメーションなしにする。
- 却下: bindingへの空文字代入だけでは未確定文字が残るため不採用。一覧を無制限に伸ばして末尾へ画面全体をスクロールする案は入力欄が画面外へ押し出されるため不採用。データモデル、正規化、保存・重複判定の変更は不要。
- 検証: Simulator本体・拡張ビルドと関連31件成功、失敗0。実UITextFieldの未確定文字を含む再生成・空欄・フォーカス、0/16、追加行の可視性、表示座標順、4件連続追加を検証。375×812日本語の修正前後画像とログを上記ディレクトリへ保存。
- 制約: 実機の日英韓IME操作は未検証。固定UIWindowの画像には別ウィンドウのシステムキーボードを含めず、キーボードによる表示領域変更を反映。公開・配布なし。


## 2026-09-21 — まとめ画面とモード選択の是正（第2弾）

- 変更パス: `ios/DopaBreak/{OnboardingFlow.swift,Localizable.xcstrings}`、`ios/DopaBreakTests/MeasurementFoundationTests.swift`、`ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SettingsStore.swift`、`ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/SettingsStoreTests.swift`、`docs/{07_onboarding_design_lifefocus.md,11_ui_copy.md}`、本記録、`output/verify/onboarding-summary-2026-09-21/`。
- 採用: まとめ／完了の目標を既存リスト順で最大5件表示し、未追加の入力も重複なく末尾へ含め、超過分を「ほかN件」にする。時間のラベルを「1年でSNSに使う時間」、値を「約N日」に変更。ラベル／値の上下配置で375ptでも通常サイズの1行を確保し、長い入力と拡大文字は自然に折り返す。
- 採用: Deep Focusと夜だけ強化に設定画面と同じProカプセル様式を付け、Deep Focusのおすすめを維持。まとめに止める強さと非Pro時の（Pro）を表示する。未購入の専用プラン退出をready用の待機状態として保存し、ready到達時だけ一度案内する。待機／表示履歴は設定ストアへ保存し、pendingInterventionModeとルールを変更しない。後からPro権利が反映されると既存Resolverで復帰する。
- 却下: 選択モードをstandardで上書きする案はS1の購入後復帰を壊すため不採用。長い時間ラベルを狭い左右2列へ押し込む案は1行表示条件に合わない。中断するアラートは使わずready本文へ案内を置く。
- 検証: Simulatorビルド、Core全563件、アプリ全件と追加の目標／文言／案内／Pro復帰テスト、375×812の日本語実SwiftUI撮影。最終件数と再実行結果は検証READMEへ記録する。
- 制約: ローカルStoreKit取引APIはSimulatorの構成・権限エラーにより実行できなかったため、購入後の回帰は購入済み権利の永続化fixtureで実際のStoreService・EntitlementGate・保存済みルール・Resolverを通して検証。実購入・実機・公開・配布は未実施。並行して加えられた目標入力関連の編集は保持し、専用のビルド先とSimulatorで最終状態を検証した。
- 最終結果: Simulatorビルド成功、Core563件成功。アプリ全408件はiOS 26.2で388件成功・19件スキップ・既存商品取得1件失敗。同じ最終ビルドでその1件をiOS 26.5へ再実行し成功、最終389件成功・19件スキップ。追加5件とPNG7枚のOCR・寸法・目視確認成功。未解消のテスト失敗なし。


## 2026-09-21 — ブロック機能と独立した3つのきっかけ

- 変更パス: `ios/Packages/DopaBreakCore/` のBlockConfiguration・SettingsStore・ShieldSyncPolicy・Activity属性とテスト、`ios/DopaBreak/` のAppContainer・両Scheduler・ShieldController・SettingsView・HomeView・OnboardingFlow・StoreService・PaywallView・LockSurfaceCoordinator・文言、`ios/{WidgetsExtension,ShieldConfigExtension,MonitorExtension}/`、`ios/DopaBreakTests/`、`docs/{06_screen_design,11_ui_copy}.md`、`.claude/release-check/monetization-check.md`、`output/aso/2026-09-20-v1.0.2/description/`、`output/verify/block-model-2026-09-21/`。
- 採用: 一呼吸は無料で常時利用。Proのブロックは手動・毎週の予定・就寝中を独立選択する。保存済みの旧モードは一度だけ変換し、以後は新モデルを正とする。権利喪失では作動を停止して選択を保持し、再購入時に復帰する。終了済みの手動セッションは復活させない。
- 採用: 設定はProでロックする3スイッチ、ホームは選択中のきっかけを表示。Live Activityとシールドは重なったきっかけも残り時間・終了時刻・起床時刻で表示する。新規オンボーディングは無料を既定とする二択で、明示的にブロックを選ぶと3つを選択状態にする。5目標・年間時間ラベル・未購入案内・S1〜S6を維持する。
- 採用: まとめCTAは無料「このプランで始める」、対象者のブロック選択はStoreKitの実期間・ゼロ価格から生成。日英韓のpaywall fallbackに期間の数字を置かない。StoreKitテストfixtureのみ3日に変更し、価格は維持。1.0.2説明文は現行公開文から試用期間だけ3日に更新し、出典を保存する。
- 却下: 旧モードの排他選択と夜の予定用追加フラグは同時利用を妨げるため廃止。権利喪失時に選択まで消す案は再購入で復帰できないため不採用。StoreKit未取得時に3日を補う案は実オファーとの不一致を生むため不採用。InterventionModeは移行・既存API互換の型として残す。
- 検証: 各段階でSimulatorビルド・Core全件・アプリ全件を実行し、変更前仕様の期待値を是正して関連テストを再実行。最終結果とログは検証ディレクトリのREADMEに記録。日本語の設定・ホーム・二択画面を実SwiftUIから撮影し、OCRと目視で確認する。
- 制約: SimulatorではFamily Controls実権限、実機での監視時間境界・同時ブロック、バックグラウンドLive Activity、実購入の期限切れ／再購入は検証できない。実機確認項目を課金チェックへ追記。Opus5レビュー・実機検証・公開・配布は実施していない。
- 最終結果: 全4段階のSimulatorビルド成功。Core最終568件成功、アプリ全415件は19件スキップ・失敗0。追補CTAとDynamic Islandを含む追加111件（1スキップ）および最終11件も失敗0。指定の日本語PNG3枚をOCR・目視確認し、変更ファイル一覧と圧縮ログを保存した。


## 2026-09-21 — ブロックモデルのレビュー修正と追補2

- 変更パス: `ios/DopaBreak/{AppContainer,StoreService,SettingsView,ShieldController,OnboardingFlow,InterventionModeDisplay}.swift`、`Localizable.xcstrings`、Coreの`BlockConfiguration.swift`と回帰テスト、アプリの`SettingsDeviceFixesSnapshotCapture`・`ShieldControllerRetiredGateTests`・`MeasurementFoundationTests`、`docs/11_ui_copy.md`、検証ディレクトリ。
- 採用: Pro権利確定時に空のきっかけを3種で補完し、通常の購入反映と購入継続処理へ適用する。スイッチの表示値は`allows`、操作の権利条件は画面と同じ`strictModeAllowed`へ統一。未確定権利による既存ブロックの解除は行わない。
- 採用: 追補2の日英韓コピーを反映。バッジを独立行に置いて長い英韓見出しの幅を確保し、Proカードに3項目とStoreKit由来の試用注記を表示。見出しとリードは中央揃え、縦間隔は24ptから16ptへ短縮。英語見出しは375pt幅で1pt超過するため既存の任意意味区切りU+200Bをhowの後へ置き、表示文言を変えず小画面の2行フォールバックを維持。試用対象外・未取得時は試用注記を表示しない。英語注記の差し込み値は「期間 (ゼロ価格)」とし、既存プランカードの「$0 for 3 days」をそのまま入れた際のfor重複を避ける。期間・価格の取得と価格書式はStoreKitの既存処理を使用。
- 却下: 未確定権利をFreeと見なす案はS1を壊すため不採用。期間・ゼロ価格のハードコードは実オファーと不一致になるため不採用。日英韓の見出しを縮小する案は表示コピー規則に合わないため不採用。
- 制約: 実アプリ遮断と実購入は実機未検証。Simulatorのローカルfixtureで検証し、最終件数・画像は`output/verify/block-model-2026-09-21/README.md`のレビュー修正欄に記録する。

- 最終検証: Simulatorビルド成功、Core570件成功。アプリ全420件（19スキップ）で検出した3ケースを修正し、関連30件（3スキップ）と最終表示15件・英韓各1件が失敗0。3言語PNGと仕様表33文言を確認。StoreKit取引作成とManagedSettings実書き込みはSimulatorで拒否されたため、実際のアプリ反映処理・名前付き出力先をfixtureで検証し、実機検証とは区別する。

## 2026-09-23 — 目標設定見出しの年間日数統一

- 変更パス: `ios/DopaBreak/OnboardingFlow.swift`、`ios/DopaBreakTests/MeasurementFoundationTests.swift`、本記録。
- 採用: 「取り戻すN日で何をする？」のNは、直前の年間損失表示と同じ`summaryYearlyDays`を使用する。2〜4時間のfixtureでは「38日」となり、前画面の「1年で約38日」と一致する。
- 却下: 半減後の`recoveredYearlyDays`（同fixtureでは19日）を使い続ける案は、年間日数を示す前画面との数値差を生むため不採用。コピー、レイアウト、ローカライズ形式は変更しない。
- 検証・制約: 375×667ptの実SwiftUI描画をOCR・目視し、「取り戻す38日で何をする？」を確認。対象スナップショットテスト1件成功・失敗0。Simulator確認で、実機・公開・配布は未実施。


## 2026-09-23 — 海外オーガニック短編はコード描画のアニメで作る

- 依頼: オーナーが試作3本（AI静止画＋ズーム）を「キャラに動きがなさすぎる。なんで静止画なの？javascriptで動画作って」と却下。
- 変更パス: `video/organic-shorts/src/{rig,sets,scenes,v1,v2,v3}/`、`scripts/finish.py`、`.claude/specs/organic-shorts-code-drawn.md`（作り方の正本）、`docs/marketing/organic-scripts/2026-09-23-three-videos.md`、成果物 `creatives/organic/videos/2026-09-23/`（旧版は `_rejected-stills/`）。
- 採用: 人物・背景・小物をRemotionのSVGで毎フレーム描く。人物は丸い頭の人間1人。常時の動き（瞬き・呼吸・親指・線の揺れ・手持ち風のカメラ）に加え、2〜4秒ごとに台本の単語へ合わせた動作を置く（起き上がりかけて戻る・あくび・頭をかく・通知でびくっ→ため息・布団の中で足をばたつかせる・居眠りしてはっと起きる・身を乗り出して肩を落とす）。時間の経過は早回し（窓の昼夜点滅・姿勢が3フレームごとに別の日へ飛ぶ・床に物がたまる）で見せる。明るい2D・太い黒線・フラット塗り。字幕は黒い箱に単語ハイライト、中心1120px。
- 却下（オーナー）: AI静止画にズームと重ね物だけ動かす方式（上記）。
- 採らなかった案（制作側の判断・オーナー決定ではない）: 動画生成AIで人物を動かす案。キャラと画風の一貫性を保ちにくく、細かな動作を台本の単語に合わせられないため。オーナーの依頼もJavaScriptでの制作だった。
- 検証・制約: 3本とも0.5秒ごとのコマ並べと連続フレームで動きを確認。音量 -14.0〜-14.2 LUFS。Codexの独立レビュー指摘1件（V1の親指の速さが変わる瞬間にスマホ画面が巻き戻る）を累積スクロール方式で修正し、全560フレームで巻き戻り0を確認。声の質とBGMは未確定。投稿はしていない。

## 2026-09-24 オンボーディングの購入導線の是正（CVR再チェック）
- **まとめ画面のボタンは、未購入なら止め方の選択に関係なく全員にペイウォールを出す**（`needsPlanReview = !isPro`）。9/21の二択化の実装で無料側だけペイウォールを出さない形になっており、オーナー承認の「全員が9画面目で通る」設計から外れていた。閉じれば無料のまま次へ進む。ブロックを選んで買わなかった人だけ完了画面で案内を出す（従来どおり）。
- 本人がまとめ画面へ戻ってボタンを押し直した場合はペイウォールを再表示する（1.0.1と同じ）。迷い直して戻った人に買う機会を残すため、1回限りの制御は入れない（Codexレビュー指摘を検討した上での判断）。
- **新規は先頭（1日のSNS時間）から始める**。`OnboardingStep.restored` が「目標が無ければ目標画面」のままで、並べ替えた質問3画面を新規ユーザーが一度も見ない不具合を修正。目標が無いまま目標画面より後へは進ませない規則は維持。
- 目標画面のデザイン一覧でProデザインを選んだとき、シートを閉じ終えてからペイウォールを出す（同時に出すと表示が捨てられることがある）。
- 目標5件で入力欄を無効化し、進むボタンの空振りをなくした。
- 英語見出しを狭い画面（34pt極太・幅335pt）に収まる長さへ: goal「%lld days back. / What will you do?」、regret「Mindless scrolling, / then regret」。
- 計測: RevenueCat属性に `onboarding_block_choice`（free/block）と `paywall_viewed`＋`paywall_last_placement` を追加。試用しなかった人が「見ていない」のか「見て断った」のかを分ける。

## 2026-09-24 オンボーディング12画面化と課金画面の中身（オーナー承認）
- 順番: SNS時間 → 後悔 → 人生換算 → 目標 → アプリ → 止め方 → **一呼吸の体験（アプリ内・ショートカット不要）** → 通知 → まとめ → 課金画面（未購入なら全員1回） → **ショートカット設定（全員）** → ブロック設定（Proのみ） → 完了。
- 理由: 旧構成は体験がショートカットの自動化に依存し、設定しないと価値を一度も見ないまま課金画面へ進んでいた。外のアプリへ移って戻らない人は課金画面に届かなかった。
- まとめ画面の「あとで」を撤去（課金画面自体に閉じる導線がある）。見出しは設定状況で切り替えず「プランができました」。
- 課金画面: 見出しv2（「あと5分」が人生の{Y}年／開く前にブレーキ）は維持。本文の無料機能説明を撤去し「あなたの目標」＋目標最大3件。機能はブロック（完全／毎週の予定／就寝中）を先頭に。

## 2026-09-26 ロック画面の許可の案内（完了画面）と許可オフ時のホーム表示（オーナー承認「OK実装して」）
- 背景: オンボーディングからロック画面確認（画面を消させる手順）を外したままにする判断をオーナーと確認（離脱要因のため戻さない）。iOSは最初にロック画面でライブアクティビティを見せるとき「許可／許可しない」を聞くため、外したことで案内なしの確認になった。「許可しない」を選ぶと目標がロック画面に出ず、ホームはプレビューを出し続けるので本人が気づけない。
- 採用: ①完了画面の完了ボタンのすぐ上に `lock_check.permission_note` を出す（目標があり、端末で許可されているときだけ・`OnboardingReadyLockScreenNotePolicy`）。最初は目標カードの末尾に置いたが、6.1インチ（393×852）でボタンが2つ並ぶ状態（ショートカット未設定）だと目標2件以上で2行目がボタンに隠れる計算になったため、スクロールに左右されないボタンの上へ移した。②ホームのロック画面カードは、端末でライブアクティビティが許可されていないときプレビューの代わりに `lock_check.title.blocked`／`lock_check.lead.blocked`／「設定を開く」（`LockScreenSettingsLink`）を出す（`HomeLockScreenCardPolicy`）。見た目は既存の注意喚起バナー（見出し20pt・説明14pt・SecondaryButtonStyle）と同じ組み方。③許可状態は `ActivityAuthorizationInfo` が@Observableでないため `AppModel.areLiveActivitiesAllowed` に写し、`refresh()` とアプリ全体の前面復帰（`DopaBreakApp.handleAppActive`）で取り直す。
- 文言は新設しない（ロック画面確認の既存キーを流用し、日英韓は既存訳のまま）。画面数・手順は増やさない。
- 却下（オーナーと確認済み）: ロック画面確認をオンボーディングへ戻す案（アプリの画面を離れる唯一の手順で、課金画面の手前で離脱を生む）。
- 不採用（Claude判断・オーナー未確認）: 確認を課金画面の後ろへ置く案（ショートカット設定と並んで外へ出る手順が2つになり、設定完了を落とす恐れ）。完了画面で許可オフの人にも注記を出す案（もう来ない確認への答え方になる。ホームのカードが設定へ案内する）。
- Claude Code向け制約: 許可の判定は `areLiveActivitiesAllowed` の写しを読む。Viewから `ActivityAuthorizationInfo` を直接読まない（変化が画面に届かない）。前面復帰の取り直し（`DopaBreakApp.handleAppActive` と `refresh()`）を外さない。アプリ内のライブアクティビティ設定をオフにしている人にはカードごと出さない既存挙動を維持する。

## 2026-09-26 課金画面の年額カードを「請求額が大きい」並びへ（オーナー承認・審査3.1.2対応）
- 経緯: 1.0.2（ビルド10）が審査3.1.2で却下（オーナー談「総額表示」）。Appleの規定は「請求される額が最も目立つ価格表示で、月あたりなどの内訳は年額より下・小さく」（https://developer.apple.com/app-store/subscriptions/）。オーナーの最初の指示は「総額を少しだけ大きく」だったが、¥415/月（24pt）より小さいままでは規定を満たさないため、本番を触らずに比較モック（`output/screenshots/paywall-billed-amount-mock/ja/compare.png`）を出し、右の案でオーナー承認（「いいよ」）。オーナーは本当は年額を小さくしたい意向だが、再却下の可能性が高いと説明したうえでの承認。
- 採用: 年額カードの大きい数字を `paywall.plan.annual.price`（ja「%@/年」・en「%@/yr」・ko「%@/년」）。補足行を `paywall.plan.annual.monthly_equivalent`（ja「月あたり%@」・en「Works out to %@/mo」・ko「월 %@」）＋トライアル表記。旧 `paywall.plan.annual.charge`（年間%@を一括請求）は削除。月額カード・法務文言・CTAは変更なし。
- 経緯の事実: 1.0（9/8）・1.0.1（9/11）も同じ月換算ヒーロー表示で承認されていた（9/4のHEADと planCard／planPrice の作りが同じ）。表示の変更ではなく審査の見方の差。
- 検証: `SettingsDeviceFixesSnapshotCapture.testPaywallShowsBilledAnnualAmountLargerThanMonthlyEquivalent`（StoreKitの価格で実画面を描き、文字認識の高さで請求額＞月あたり×1.5を確認・通貨と言語に依存しない）。アプリ側テスト430件で失敗はこのテストの初版1件のみ（ドル表示の環境で円の文字を探していた）→修正後に課金画面関連39件成功。
- Codexレビュー（medium）: ①（高）トライアル対象者には固定の「3日間 ¥0で始める」が常に見え、年額はスクロールしないと見えないため再却下の余地が残る。→ ボタンの ¥0 表記は8/28のオーナー承認済み例外で、今回の比較提示でも「そのまま残す」と伝えて承認を得ているため変更しない。再却下時の第一候補として記録。②（中）テストが日本語前提 → 通貨・言語非依存へ修正済み。
- Claude Code向け制約: 年額カードで月あたりの額を請求額より大きく・上に出さない（旧「月換算ヒーロー表示」に戻さない）。月あたりは補足行の小さい文字のまま。

## 2026-09-26 止め方の画面: Proを上・おすすめ・初期選択に（オーナー指示・次の更新向け）
- オーナー指示（逐語）: 「Proを上に置いておすすめにしてデフォルト選択済みにして」「3日間０ドルで試せるはペイウォールのみに止め方の画面には出さないで。」
- 採用: カードの並びを Pro（一呼吸＋完全ブロック）→無料 に。印は Pro＝`onboarding.block.pro_badge`「Pro・おすすめ」（アクセント色）、無料＝`onboarding.block.free_badge`「無料」（通常色）。Proカードのトライアル行（`onboarding.block.trial`・`trial_offer`）は削除。
- 初期選択: `OnboardingProgress.initialModeSelection`。まだ止め方を確定していない人は Pro を選んだ状態。確定済みの人（`SettingsStore.onboardingBlockChoiceSaved`、`saveModePreference` で立てる・データ削除で消える）は、戻ってから再起動した場合も含めて保存済みの選択（`preferredMode`）。保存値は「ブロックのきっかけが空＝無料」で未選択と区別できないため確定の記録を別に持つ。記録のない旧版からの途中再開は、止め方の画面より後から始まるかで判断する。`preferredMode` 自体の既定（無料）は変えていない。Codexレビュー（medium）の「無料確定→戻る→再起動でProに戻る」指摘を受けてこの形にした。
- 変えていないもの: 課金画面はどちらを選んでも未購入なら全員に1回（9/21 オーナー承認）。Proを選んで買わなかった人は完了画面で「いまは一呼吸で始めます」を案内。
- 2026-09-27 追記: まとめ画面のボタンも「トライアルは課金画面だけ」に合わせ、選択に関係なく「このプランで始める」に統一（確認への返答「OK 審査提出して」を変更の承認と解釈）。`OnboardingSummaryPresentation.actionTitle` を固定文言にし、`StoreService.annualIntroOfferOnboardingCTAText`・`IntroOfferDisplayPolicy.ctaText(forOnboarding:)`・`onboarding.summary.action.intro` を削除。ゼロ価格の文言はペイウォールのボタン（`paywall.action.start_zero_price`）だけに残る。
- 経緯: 9/20 は「Deep Focus を既定・おすすめ」、9/21 の2択化で「無料を既定・おすすめ」になっていたのを、今回 Pro へ戻した。1.0.2（ビルド11）は提出済みのため、この変更は次の更新に入る。
- Claude Code向け制約: 止め方の画面に価格・トライアルの表記を出さない。初期選択を `preferredMode` の既定の変更で実装しない（保存値の意味が変わり、途中再開で無料を選んだ人の選択を上書きするため）。

## 2026-09-26 オンボーディングの一呼吸の体験はSNSで見せる（オーナー指示）
- オーナー指示（逐語）: 「体験する画面の Safariを開いた時じゃなくSNSにして」
- 採用: `OnboardingExperienceAppPolicy.app(from:)`。選んだアプリの中で最初のSNS（Safari以外）を体験に使う。説明文と呼吸画面の「{アプリ名}を開きます」はこのアプリ名になる。
- Safariだけを選んだ人はSafariのまま。当初は見本のInstagramにしたが、Codexレビュー（low）の指摘どおり、体験の「開かなかった」は本物の記録（ルール作成・開こうとした回数・取り戻した時間）になるため、選んでいないInstagramの記録が残る。記録を残さない見本モードは介入フローの中心に手が入るため今回は見送り、オーナーへ報告。何も選んでいないときは従来どおり見本のInstagram。
- 変えていないもの: ショートカット設定中に実際に開いたアプリで出る体験（`presentExperienceIfNeeded`）は、そのアプリのまま（本物の動作のため）。
- Claude Code向け制約: 非SNSの判定は `nonSNSCatalogIDs`（現在はSafariのみ）。カタログにSNS以外を足したときはここにも足す。

## 2026-09-28 App Storeスクショを7枚へ作り直し（訴求と画面の照合・オーナー承認）
- オーナー指摘（逐語）: 「SNSブロックアプリを探してるのに１枚目のブロックしないという表現はよくないし、１枚目の画像に改修した目標が確認できるのが見えない、２枚目はロック画面だし」「訴求が画面とあってない」。提案した並びと直し方に「OKそれで作り直して」。
- 採用: 並びは 目標（開いた瞬間）→完全ブロック→ロック画面の目標→夜だけ強化→白黒→取り戻した時間→テーマ の7枚。見られやすい最初の3枚に、他社にない目標表示と、検索で探されている「SNSが止まる」の両方を置く。見たあとの本音と理由を選ぶ枚は外した。
- 採用: 夜だけ強化は、ブロック中にiOSが出す画面（完全ブロック中＋起床時刻の7:00まで）で見せる。iOSが描く画面のため撮影できず、ロック画面・白黒ホームと同じくアプリの色と文字のままスクリプトで描いた。完全ブロックの枚は今の設定画面を撮り直して使う（当初は両方ブロック中の画面にしたが、オーナー「完全ブロックの画像は設定画面のほうがいいかも、2枚ただ完全ブロックの画像出てるので微妙」で変更）。
- 採用: ロック画面の見出しを「無意識に手に取っても／まず目標が見える」へ（en「Pick up your phone／and your goals come first」、ko「무심코 폰을 들면／목표부터 떠요」）。旧「SNSを開くたびに目標を確認」はロック画面の場面と合わず、1枚目と同じ主張だった。
- 採用: 1枚目・ホーム・テーマは今のアプリで撮り直し。1枚目の目標はロック画面と同じ4件に揃えた。ホームは設定途中の案内が出ない状態で「312時間 13日分」を見せる。
- 却下: 目的選択・時間選択・満足度入力の単独枠（手続きや作業の画面で、得られるものを見せない）。1.0.2の公開前取り下げはオーナー判断待ち（承認済みの版はスクショを差し替えられない）。
- Claude Code向け制約: スクショを出す前に、各枚の見出しと副文が画面に見えているものを指しているかを1枚ずつ照合する。画面素材の撮影日以降にアプリの画面が変わっていたら撮り直す。同じ種類の画面を2枚並べない。設定画面か働いている画面かは、その枚の副文が指す中身で選ぶ。raw-core は他セッションも書くため、納品に使う素材は `output/verify/appstore-rebuild-2026-09-28/raw/` に写してから生成する。

## 2026-09-28 設定画面の完全ブロックの時間チップを折り返す
- 経緯: スクショ作り直しで、英語の「Until you unblock it」が横スクロールの行から画面外へはみ出していた（440pt幅）。スクロールできることに気づかないと、この選択肢が見つからない。オーナー指示「修正して審査提出」。
- 採用: `SettingsView.sessionOptionChips` を ViewThatFits に。1行に収まれば従来どおり1行、収まらなければ時間の3つと「解除するまで」を2行に分ける。2行でも収まらない大きな文字サイズのときだけ従来の横スクロール。
- Claude Code向け制約: チップを足すときも「画面外に選択肢を隠さない」を守る。撮影テストの設定画面は15:00固定（平日20:00〜22:00の予定の時間帯に入ると表示が変わるため）。

## 2026-10-05 1日に開ける回数（回数上限で完全ブロック・Pro）
- オーナー指示（逐語）: 「1日何回以上開いたら完全ブロックする仕組みを追加したいが君はどう思う？」→ 逃げ道の3案（A 翌朝まで止まる・30秒待てばその場で1回だけ開ける・緩める変更は翌日から／B 一切開けない／C 設定でいつでも外せる）を提示 →「Aを有料機能に入れて」
- 前提として提示し異論がなかった案（オーナーの明示決定はA・有料の2点）: 呼吸中に「今日あと{n}回」／上限は本人の記録から目安を出す／止まった画面は理由と終わる時刻だけ／SNS合計で数える／区切りは起床時刻
- 経緯: 8/22の回数上限は常時シールドの一部で、9/1の一呼吸と完全ブロックの分離で常時シールドごと外れた。今回はふだんは一呼吸だけで、使い切ったときだけ完全ブロックがかかる（前回の「砂時計の一呼吸と完全ブロックが重なる」分かりにくさは起きない）。`TargetRule.maxOpensPerDay` は使っていない
- 採用: 数える＝`attempt_logs.opened=1` を `COALESCE(completed_at, started_at)` で `[数え始め, 次の起床)` に数える（素通し・キャンセルは数えない・対象から外しても当日分は戻らない）。止める対象＝有効で選択データを持つルールすべて。止まり始め＝最後の1回の決めた時間の終わり（最後の1回は時間なしを出さない）。止まり終わり＝次の起床時刻。15分未満の窓・対象なし・監視の登録失敗はシールドを掛けず、一呼吸の入口の上限画面だけで止める
- 採用（Codex Astra medium との設計議論・2026-10-05）: 控えは `DailyOpenLimitStore`（`ReinterventionStore` と同じファイルロック）で読み書きし、シールドへの反映もロックの中で行う／Monitorは開始・終了の区別に頼らず、どの通知でも最新の控えで掛け外しを決め直す（`DailyOpenLimitShield.sync`）／監視の登録に成功したときだけ控えを残す／緊急は止め直しの監視を先に登録してから外す（登録できなければ外さない）／夜・予定・手動が重なるときは緊急の導線を出さない（外せるのは回数上限ぶんだけ）／「開く」確定の直前にも残りを確かめ直す／「明日」は日付で出し分ける
- 採用: 緊急で開く＝待ち始めた時刻を保存（画面を閉じても短縮できない）・30秒後から5分以内だけ有効・使ったら消費。開ける範囲は選んだ時間のあいだ対象全体（カタログIDとScreen Timeのトークンを突き合わせられないため）。回数の上限は付けない（9/5の「回数制限付き緊急パス」不採用とそろえる）
- 採用: 設定の変更は、オンにする・減らす＝すぐ、増やす・オフ＝次の起床時刻から（`pendingChange`）。オンにした日はオンにした時刻以降だけを数える。Freeへ落ちたら監視・控え・シールドを外し設定値は残す。権利未確定のあいだは控えを作らず消さず、終わった窓の掃除だけ行う
- 画面: 設定「ブロック」カードに行を追加（Picker・今日の残り・変更待ち・目安・補足）。就寝中だけオンのときの補足は回数上限オンなら「日中は1日の回数を使い切るまで開けます」へ。回数上限で止まっているあいだは「いま完全ブロック中のアプリはありません」を出さない。ホームは使い切ったら状態行と「30秒待って開く」、そのあいだ「ブロックを設定する」は出さない。シールドは回数上限だけなら題「今日は{n}回開きました」、iOS 26.5以降は副ボタン「DopaBreakを開く」
- Codexコードレビュー（Astra medium）の7件を是正: 同期で監視の登録を確かめて張り直す／起床時刻の変更で止まり終わりを合わせ直す／足した対象はすぐ止め外した対象は翌朝まで止める／緊急で開くときは再介入の区切りも終える／古い上限画面は緊急ボタンで状態を取り直す／開けている時間中は「{時刻} まで開けます」／同じ日の朝に効く変更待ちに「明日」を付けない
- Codex再レビュー（2回目）の3件を是正: 監視の照合を `schedule(for:)` の時刻で行う／「{時刻} まで開けます」は覚えた終わりの時刻だけで出し止まっている最中は出さない／上限画面は前面復帰と1分ごと・緊急の確定直前に確かめ直す
- Codex再レビュー（3回目）の1件を是正: 控えを作り直すときの止まり始めに素通しの許可の期限（再介入ありで最大12時間）を使わず、最後の1回で覚えた終わりの時刻を使う
- やらないこと（今回）: Live Activityのブロック表示、ペイウォールの機能行、アプリ別の回数、統計での表示
- Claude Code向け制約: 回数上限のシールドは専用ストア `dopabreak.openlimit` と活動名 `dopabreak.openlimit` だけを使う（夜・予定・手動のストアに混ぜない）。`suppressesIntervention` に回数上限を含めない（含めると上限画面が出ない）。控えを書いたら必ず監視を登録し、失敗したら控えを消す。シールドを掛ける判断は `DailyOpenLimitPolicy.isBlockActive` だけで行う
- 検証: Core 598件0失敗（うち新規27件）、アプリ側の回数上限30件＋撮影3件0失敗、アプリ全体465件0失敗・23件スキップ（専用シミュレータ）、撮影 `output/verify/open-limit-2026-10-05/`。Screen Timeのシールドが実際に掛かる・外れる・iOS 26.5のボタンでDopaBreakが開くは実機でのみ確認できる（未確認）

## 2026-10-05 ペイウォールの機能一覧に「1日に開ける回数」を追加
- オーナー指示（逐語）: 「2先に作って」（直前の報告の「ペイウォールの機能一覧にはまだ載せていません。載せる場合は文言案を出します」への返答）
- 採用: 4行目（ブロックのきっかけの並び＝手動・毎週・就寝中の次）に `paywall.feature.daily_open_limit`。ja「開きすぎた日は翌朝まで開けない」／en「Block apps until morning after too many opens」／ko「너무 자주 연 날은 아침까지 완전 차단」。機能一覧は7行
- 文言の決め方: 訴求の手順（sales-copywriting: ペイウォール＝認知段階⑤・市場成熟度4〜5、案5つを4Uで比較）。オンボーディングの利用者の言葉「気づけばSNSを開き」の「開く」で返す。既存行が「〜ブロック」で終わる行ばかりになり、直上の「就寝中は自動で完全ブロック」と同じ終わり方が続くため、「完全ブロック」案より「開けない」で終える案を採った。humanizer-en/ko の監査は前後とも exit 0、humanizer-jp はパターン該当なし。表示規則（、。なし・1行）を満たす
- 却下した案: 「開きすぎた日は翌朝まで完全ブロック」（〜ブロックの連続）／「決めた回数を超えたら完全ブロック」（同）／「1日に開ける回数を決められる」（結果が伝わらない）／「開く回数が上限に届いたら翌朝まで停止」（停止が硬い）／「「ちょっとだけ」が積み重なる前に止める」（何で止めるかが分からない）
- 検証: 実寸（393×852）と全体の撮影 `output/verify/open-limit-2026-10-05/paywall-{top,full}.png`。各行1行に収まる。実寸の最初の画面には6行目まで見え、7行目と年額カードはスクロールした先（年額カードは追加前もボタンの下に隠れていた）。3言語の値が製品に載っていることを `MeasurementFoundationTests.testPaywallHeadlineAndFeatureCopyIsShippedInEverySupportedLanguage` に追加して確認
- **同日改訂（オーナー指示・逐語）**: 「解除に30秒っておかしいから 1日の開く回数を制限してブロック という文言に変えて。開きすぎた日は翌朝まで開けないという文言も違和感しかない」→ `strict_block`（解除に30秒待つ強いブロック）の行を一覧から外し、その位置（4行目）を `paywall.feature.daily_open_limit`「1日の開く回数を制限してブロック」に。「開きすぎた日は翌朝まで開けない」は取り下げ。一覧は6行に戻った。en「Block apps after your daily open limit」／ko「하루에 여는 횟수를 제한해 차단」（humanizer-en/ko 前後 exit 0）。`strict_block` のキーはカタログに残す（`grayscale` と同じ）。手動セッションの強いブロック自体はProに残る
- Claude Code向け制約: ペイウォールの✓一覧は、機能が何をするかを平易な1行で書く。「開きすぎた日は」のような場面語や、利用者の手間（解除に30秒待つ）を売り文句にした行を戻さない

