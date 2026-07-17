# DopaBreak オンボーディング再設計スペック（Codex実装用）

対象ディレクトリ: `output/mockups/lifefocus_v2/`
アートディレクション: E1 Dark Mono（既存）。**`01_welcome.html` の `<head>`〜`</style>` ブロック（197行のデザイントークン＋全コンポーネントCSS）を1文字も変えず全ファイルにそのままコピーして使うこと。** 新しいCSSクラスは原則追加しない。既存クラス（.tag/.title/.subtitle/.choice/.btn/.plan/.benefit/.stats-big/.big-count/.goal-card/.mini-badge/.note/.pill 等）を再利用する。やむを得ず追加する場合のみ各ファイルの`<style>`末尾に最小限で足す。

共通仕様:
- 画面サイズ 402×874、ステータスバーSVGは既存ファイルからそのままコピー。
- 下部ホームインジケータ `<div class="home"></div>` を全画面に。
- 日本語の**見出し・短い表示コピーは句読点（、。）を使わない**。体言止め・改行で区切る。本文/noteは通常の句読点OK。
- 数字・分・時間・¥ は `<span class="num">…</span>` でSpace Grotesk。
- アクセント lime `#C7F94D` は1画面1役割に限定（見出しの強調語 or 選択中プラン or 主要CTA）。

レンダリング: 各HTMLを Chrome headless で 1206×2622 PNG 化（既存 `render.sh` のコマンド／`--force-device-scale-factor=3 --window-size=402,874 --virtual-time-budget=4000`）。新規・改訂した画面すべてを再レンダリングし、`sips -g pixelWidth -g pixelHeight` で 1206×2622 を確認。

---

## 改訂: 01_welcome.html
`<main class="page">` 内を以下に置換（損失回避フレーム・「取り戻す」廃止）:

```html
<main class="page" style="padding-top:30px;">
  <div class="tag">LIFEFOCUS</div>
  <div style="margin-top:auto;">
    <h1 class="title large">人生の時間は<br><span style="color:var(--accent);">二度と戻らない</span></h1>
    <p class="subtitle" style="width:300px;margin-top:18px;">そのスクロールが、いちばん高くついている。</p>
  </div>
  <div class="bottom-actions" style="margin-top:36px;">
    <div class="btn primary">はじめる</div>
    <div class="link-ghost">すでに使ったことがある</div>
  </div>
</main>
```

## 改訂: 02_self_check.html （自己診断 Q1 / 5）
- `.tag` を `STEP 01 / 04` → `質問 1 / 5` に。
- 見出しはそのまま「1日に何回、無意識にSNSを開いていますか？」（疑問文なので「？」可）。
- 選択肢そのまま（5〜15回 selected）。
- noteの下に小さいプライバシー表示を追加: 見出しの直下（`.tag`の次）に
  `<div class="pill" style="display:inline-flex;align-items:center;gap:7px;margin-top:14px;">回答は端末内にのみ保存</div>`
  （`.pill` 既存クラス。先頭に小さな鍵SVG任意）

## 新規: 02b_quiz_feelings.html （自己診断 Q2 / 5・PHQ型 頻度回答）
```html
<main class="page tight">
  <div class="tag">質問 2 / 5</div>
  <p class="note" style="margin-top:18px;">この2週間、次のことはどれくらい当てはまりますか</p>
  <h1 class="title mid" style="margin-top:10px;">気づけば、目的もなく<br>スクロールしている</h1>
  <div class="choice-list">
    <div class="choice"><span>全くない</span><span class="check"></span></div>
    <div class="choice"><span>数日</span><span class="check"></span></div>
    <div class="choice"><span>半分以上</span><span class="check"></span></div>
    <div class="choice selected"><span>ほとんど毎日</span><span class="check">✓</span></div>
  </div>
  <div class="bottom-actions"><div class="btn primary">次へ</div></div>
</main>
```

## 新規: 02c_quiz_cost.html （自己診断 Q3 / 5・後悔の顕在化）
Q2と同構造。
- tag: `質問 3 / 5`
- note: `SNSを閉じたあとの気持ちは`
- title: `「時間を溶かした」と<br>感じることがある`
- 選択肢: 全くない / 数日 / **半分以上(selected)** / ほとんど毎日
- CTA: 次へ

## 新規: 03_quiz_result.html （推計損失リビール＝顕在化のクライマックス）
損失数字を主役に。効果の約束ではなく「本人の回答からの推計」。
```html
<main class="page tight">
  <div class="tag">推計結果 / YOUR RESULT</div>
  <p class="note" style="margin-top:18px;">あなたの回答にもとづく推計では</p>
  <div class="stats-big"><span class="num">2.5</span><span style="font-size:40px;font-weight:700;">時間</span></div>
  <p class="subtitle" style="margin-top:2px;">が1日、SNSに溶けています</p>

  <div class="goal-card box" style="margin-top:26px;text-align:center;padding:22px;">
    <div class="goal-k" style="justify-content:center;">1年に換算すると</div>
    <div class="goal-v" style="font-size:30px;margin-top:14px;">約 <span class="num" style="color:var(--accent);">38</span> 日<span style="color:var(--muted);font-size:18px;font-weight:700;">（912時間）</span></div>
    <p class="note" style="margin-top:12px;">眠っている時間を除けば、起きている人生の<br>まるまる<span style="color:var(--ink);font-weight:700;">1年分以上</span>に相当します</p>
  </div>

  <div class="pill" style="display:inline-flex;margin-top:20px;">行動科学にもとづく設計</div>

  <div class="bottom-actions">
    <p class="fine" style="margin-bottom:14px;">※ご回答からの推計値です。医療診断ではありません。</p>
    <div class="btn primary">この時間を、変える</div>
  </div>
</main>
```
※ `.stats-big` は font-size:86px と大きいので、`2.5`は数字、「時間」は小さめインラインに。レイアウトが縦に溢れる場合は `.stats-big` を `font-size:72px` にインライン上書きして1画面に収める。

## 改訂: 04_goal_setup.html
推計損失からの橋渡し。冒頭見出し/サブのみ調整（目標入力UIは既存維持）:
- 見出しを「その時間で、何をしたい？」系に。例: `<h1 class="title mid">取り戻したこの時間で、<br>何をしますか？</h1>` ……ただし「取り戻す」は本文では1回まで許容。可能なら「空いたこの時間で、何をしますか？」に。
- サブ: `1年後、こうなっていたい。それが介入のたびに思い出す“理由”になります。`
（既存の目標カード/1年目標フィールドはそのまま）

## 新規: 08b_pre_paywall_summary.html （ペイウォール前サマリー・サンクコスト）
```html
<main class="page tight">
  <div class="tag">あなた専用プラン / READY</div>
  <h1 class="title" style="margin-top:22px;">準備が、整いました</h1>
  <p class="subtitle">この設定で、DopaBreakがあなたを守ります。</p>

  <div class="list-card card" style="margin-top:24px;">
    <div class="list-row"><span style="color:var(--muted);font-weight:500;">ブロックするアプリ</span><strong><span class="num">4</span> アプリ</strong></div>
    <div class="list-row"><span style="color:var(--muted);font-weight:500;">あなたの目標</span><strong>資格の勉強を続ける</strong></div>
    <div class="list-row"><span style="color:var(--muted);font-weight:500;">取り戻せる時間（推計）</span><strong>年 約<span class="num" style="color:var(--accent);">38</span> 日</strong></div>
  </div>

  <div class="bottom-actions"><div class="btn primary">続ける</div></div>
</main>
```

## 改訂: 22_paywall.html （価格をone sec同等〜やや下／推計損失からパーソナライズ）
`<main>` を以下に置換:
```html
<main class="page tight">
  <div class="tag">LIFEFOCUS PRO</div>
  <h1 class="title large" style="font-size:36px;margin-top:22px;">その <span class="num" style="color:var(--accent);">38</span> 日を、<br>人生に使う</h1>

  <section class="benefits" style="margin-top:18px;">
    <div class="benefit"><span class="tick">✓</span><span>すべてのアプリをブロック</span></div>
    <div class="benefit"><span class="tick">✓</span><span>ロック画面に人生の目標</span></div>
    <div class="benefit"><span class="tick">✓</span><span>詳細な統計と継続記録</span></div>
    <div class="benefit"><span class="tick">✓</span><span>複数の目標とモード</span></div>
  </section>

  <section class="plans" style="margin-top:14px;">
    <div class="plan selected">
      <div><strong>年額プラン</strong><div style="margin-top:5px;"><span class="mini-badge">7日間無料</span></div></div>
      <div style="text-align:right;"><span class="price">¥1,800<span style="font-size:12px;color:var(--muted);font-weight:500;">/年</span></span><div class="note" style="margin-top:3px;">¥150/月 相当</div></div>
    </div>
    <div class="plan">
      <div><strong>買い切り</strong><div class="note" style="margin-top:4px;">一回のみ・期限なし</div></div>
      <span class="price">¥12,000</span>
    </div>
  </section>

  <div class="bottom-actions" style="padding-bottom:30px;">
    <div class="btn primary">7日間無料ではじめる</div>
    <div class="fine">7日目に ¥1,800/年。終了前に通知 · いつでも解約可能 · 復元 · 利用規約</div>
  </div>
</main>
```
注: 縦に溢れる場合は benefits の各行高さを詰める（`.benefit{height:44px}` をこのファイルの`<style>`末尾に上書き）。

---

## 反映する付随作業
1. `anim_onboarding_flow.html` のパネル順を新フローに更新（任意・できれば）: 01_welcome → 03_quiz_result → 04_goal_setup → 08b_pre_paywall_summary → 22_paywall の5枚に差し替え、背景画像URLとコメントを対応させる。
2. `render.sh` に新規ファイル（02b/02c/03_quiz_result/08b_pre_paywall_summary）を追加し、改訂ファイル（01/02/04/22）を再レンダリング。
3. `_contact_sheet.png` を全画面で作り直し（montage/ffmpeg いずれか既存方式）。
4. `README.md` の画面一覧テーブルに新規4画面を追記し、オンボ順の説明を新フローに更新。

## 完了条件
- 新規・改訂PNGがすべて 1206×2622。
- 日本語の文字切れ・改行崩れなし、見出しに句読点が残っていない（推奨見出し）。
- アクセントlimeが各画面で1役割に収まっている。
- 価格は 年¥1,800 / 買い切り¥12,000 / 月額なし に統一。
