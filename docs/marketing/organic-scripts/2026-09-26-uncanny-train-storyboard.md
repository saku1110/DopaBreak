# 絵コンテ: Just checking one thing（不気味な実写・20秒）

- 作成: 2026-09-26（オーナー依頼「まずはストーリーボード作成して」）
- 型: A型を基本に20秒へ延長（正気に戻る流れに時間を取るため。無音でも成立・テロップ最大2行）。海外（英語・米国）アカウント向け
- 参考: Instagram reel DdQtUVmsVJx「LOOK UP」（15秒・いいね7.5万）。構造（不気味な誇張→反転→見上げる）だけを借り、首輪などの見た目は使わない
- 制作: Seedance 2.5（絵コンテ画像を参照に入れて20秒を1回で生成。2.5は30秒まで1回で作れる）。下書き480p、仕上げ720p
- 絵コンテ画像: `output/organic/2026-09-26-uncanny-train/storyboard-v22/`、一覧 `storyboard-22.png`（gpt-image-2で作成。14a〜14cは実際のアプリの一呼吸画面を録画して合成）
- 動く一呼吸画面: `recovery/14-dopabreak-breathing.mp4`（3.5秒・実機と同じ呼吸アニメーションとカウントダウン）、プレビュー用 `.gif`

## 企画の芯

| 項目 | 内容 |
|---|---|
| 誰もがやる場面 | 通勤電車で「ちょっと1つだけ確認」と言ってスマホを開く |
| 誇張装置（1つ） | **体がスマホに合わせて変形していく**。高速スクロール → 首がまっすぐ突き出る（ストレートネック） → 手とスマホが糸を引いて離れない → 目が充血してよだれ → 車両の全員が同じ姿、の順で見せる |
| 仕組みの1行 | You don't open it. Your thumb does.（開くと決める前に親指が動いている。習慣化した行動は意思決定より先に始まる） |
| 反転 | アプリを開いた瞬間、画面に自分の目標が出る → 顔を上げると体が元に戻る（DopaBreakの差別化の瞬間。ロゴやアプリ名は出さない） |
| 送りたくなる瞬間 | **12〜13枚目**。並んだ全員がストレートネック・充血・よだれで、手がスマホから糸を引いて離れない |
| 明るさ | 全カット昼の車内。窓からの日差しで明るく保つ（暗い画は1秒で読めないため使わない） |

## 絵コンテ（22枚・9:16・24fps・20秒）

変化する場面は「変化の前」と「変化の後」の2枚で見せる。Seedanceにはこの2枚を区間の最初と最後の参照として渡す。

| # | 秒 | 画像の内容 | テロップ（英／訳） |
|---|---|---|---|
| 01 | 0.0 | 昼の通勤電車。女性が座ってスマホを見る。姿勢はまだ普通 | Me: "just checking one thing" ／ 私「ちょっと1個だけ確認」 |
| 02 | 0.5 | 親指がSNSのアイコンを押す | （継続） |
| 03 | 1.0 | 指で高速スクロール。親指の残像が重なり、投稿が流れてにじむ | （継続） |
| 04 | 1.8 | 首が前に傾き始める | （継続） |
| 05 | 2.6 | ストレートネック。首が一直線の棒のように斜め前下へ伸び、頭がスマホの真上に突き出る | （継続） |
| 06 | 3.4 | 手元。まだ普通に持っている | You don't open it. Your thumb does. ／ 開くのはあなたじゃない 親指だ |
| 07 | 4.2 | 手を離そうとすると、指とスマホの間で皮膚が糸を引いて離れない | （継続） |
| 08 | 5.0 | 顔のアップ。まだ普通 | （継続） |
| 09 | 5.8 | 目が真っ赤に充血し、開いた口からよだれが垂れる | （継続） |
| 10 | 6.6 | 車両全体。全員がスマホを見ている（まだ普通） | （継続） |
| 11 | 7.4 | 車両の全員の首が同じ一直線の形で伸びる | （継続） |
| 12 | 8.4 | 並んだ4人の正面。全員ストレートネック・充血・よだれ（送りたくなる瞬間その1） | （継続） |
| 13 | 9.4 | 並んだ全員の手元。全員の手がスマホから糸を引いて離れない | （継続） |
| 14a〜14c | 10.5〜13.5 | **DopaBreakの一呼吸画面が動く**（実際の画面を録画して合成）。Remember your goals の下に目標3つ（Live in Spain for a year／Be present with the people I love／Start my own business）。緑の輪が減り、脳が呼吸し、カウントダウン3→2→1。指にはまだ皮膚の糸が残る | なし |
| 15 | 13.5 | 画面を見て深く息を吸う。目の赤みが引き、よだれが止まり、口が閉じる | なし |
| 16 | 14.5 | 突き出ていた首が縮み、頭が肩の上へ戻っていく | なし |
| 17 | 15.3 | 皮膚の糸が切れて消え、指がほどけ、スマホが手のひらで自由になる | なし |
| 18 | 16.2 | **彼女だけ元の姿で顔を上げる。隣の3人はまだ首が突き出て、よだれを垂らしている**（送りたくなる瞬間その2） | なし |
| 19 | 17.6 | スマホを伏せて横に置き、ひざの上でスペイン語の本を開く | なし |
| 20 | 19.0 | 窓の外の日差しと街を見る | なし |

テロップは上14%と下35%を避けた帯（画面の高さ14〜65%）に置く。後処理で焼き込み、Seedanceには文字を描かせない。

**14の画面の作り方**: 動画ではスマホを動かさずに持つカットにし、Seedanceには画面を緑一色で出させる。そこへ録画済みの一呼吸画面（`scratchpad` の録画から切り出した3.5秒。撮影用テスト `testHoldBreathingScreenForOrganicVideo` を `-testLanguage en` で実行し `simctl io recordVideo` で撮る）を合成する。AIに画面の文字を描かせると崩れるため。

## Seedance 2.5 用プロンプト（1回で15秒・複数カット）

参照画像: storyboard-v22 の全枚（14a〜14cの代わりに緑画面版 recovery/14-green.png を渡す）（同じ人物・同じ車内を保ち、変化の前後を指定するため）。Seedance 2.5は参照画像を最大30枚まで入れられる。

```
Photorealistic surreal short film, 20 seconds, vertical 9:16, 24fps, bright daylight inside a modern commuter train with large windows. Same woman throughout: late 20s, shoulder-length dark brown hair, beige knit sweater, jeans, crossbody bag, maintains exact appearance from the reference images. Obvious surreal body deformation from phone use, clean and eerie, no blood, no wounds, no gore.
[Shot 1, 0-2s] Medium shot (frames 01-03). She sits, taps an app icon, then her thumb flicks up the screen at frantic speed, the feed a motion-blurred smear. Tapping and fast scrolling sounds, steady train hum.
[Shot 2, 2-4s] Strict side profile (frames 04-05). Her neck slowly stretches into one long perfectly straight rigid line running diagonally forward and down from her shoulders, like a straight pole, until her head hovers right above the phone. No curve, no hump, no arch. Her torso stays upright. Faint creaking sound.
[Shot 3, 4-6s] Extreme close-up of her hands (frames 06-07). Her thumb keeps scrolling. When she tries to pull one hand away, thin strands of stretched skin like melted wax connect her fingertips and palm to the phone; the strands stretch but do not break.
[Shot 4, 6-8s] Close-up of her face lit by the screen glow (frames 08-09). Unblinking eyes turn heavily bloodshot with dense red veins; her mouth hangs open and a thin clear string of drool drips toward the phone.
[Shot 5, 8-11s] Wide shot down the aisle, then a frontal shot of four passengers side by side, then a close-up across their laps (frames 10-13). Every passenger has the same straight rigid diagonal neck, bloodshot eyes, drool dripping, and hands stuck to their phones by stretched skin strands; only their thumbs move in sync. Layered scrolling sounds.
[Shot 6, 10.5-13.5s] Close over-the-shoulder shot, phone held still (frames 14a-14c). The phone screen is a flat solid pure green (#00FF00) for compositing. Skin strands still connect her fingers to the phone. Train hum returns.
[Shot 7, 13.5-16s] (frames 15-17) Close-up: she takes a slow deep breath; the red veins fade from her eyes, the drool stops and her mouth closes. Side profile: her long straight neck shortens and retracts until her head sits normally above her shoulders. Extreme close-up: the skin strands snap loose and dissolve, her fingers relax and the phone rests freely in her open palm. Soft inhale and exhale.
[Shot 8, 16-17.5s] Medium frontal shot of the four passengers (frame 18). She is completely normal and calmly looks up, while the three passengers around her still have long straight necks, bloodshot eyes and drool dripping onto the phones stuck to their hands. Layered scrolling sounds from them only.
[Shot 9, 17.5-20s] (frames 19-20) She turns the phone face down on the seat, opens a small Spanish phrasebook on her lap in warm sunlight, then glances out the window at the passing city with a content expression. Gentle train hum.
Absolutely NO text, subtitles, captions, logos or brand names on screen.
```

言い換えの注意: 生成が止められないよう blood / wound / gore / horror は使わない。充血は "thin red veins"、一体化は "merges / one seamless object" で書く。

## 投稿キャプション（英語・本編にCTAは入れない）

```
Me: "just checking one thing." Forty minutes later.
If you're trying to quit social media, check my profile.
```
訳: 私「ちょっと1個だけ」。40分後。SNSをやめたいならプロフィールへ。

## 費用の目安

| 工程 | 内容 | 費用 |
|---|---|---|
| 絵コンテ画像 | gpt-image-2 × 20枚 | サブスク内 |
| 下書き | Seedance 2.5 480p 20秒 × 3〜5回 | 約$6.2〜10.3 |
| 仕上げ | 720p 20秒 × 1〜2回 | 約$4.6〜9.2 |
| 合計 | | 約$11〜20（1ドル150円で約1,700〜3,000円） |

## 表現の決定（2026-09-26 オーナー指摘）

- 首は「折れて垂れる」形ではなく**ストレートネック**（首が一直線の棒のように斜め前下へ伸び、頭が前に突き出る）。折れる形は参考動画の見た目にも近いため使わない。生成で曲線になりやすいため、姿勢の見本図 `keyframes/pose-straight-neck-sketch.png` を参照に付けて描かせた
- 全員に「手とスマホが糸を引いてくっつく・よだれ・充血」を入れる。引きの画では細部が消えるため、並んだ4人の正面（12）と手元（13）を別の絵にした
- 指で高速スクロールする場面（03）を追加。アプリを開いた直後に置き、「高速で延々とスクロール」が体の変形の原因に見える順番にした
- 14枚目以降（2026-09-26 オーナー指摘）: 目標だけの仮画面をやめ、実際のDopaBreakの一呼吸画面（英語）を合成。その後に「息を吸う → 目と口が戻る → 首が縮む → 皮膚の糸が切れる → 自分だけ元に戻り周りはまだ中毒 → スペイン語の本を開く → 窓の外を見る」の正気に戻る流れを足し、20秒に延長
- 目標（2026-09-26 オーナー指示「3つにして人生で大切な目標」）: Live in Spain for a year／Be present with the people I love／Start my own business（夢・人・仕事）。スペイン語は英語圏で最も学ばれている外国語（Duolingo 2025年版で米英とも1位）で、最後のスペイン語の本につながる。「子ども」など対象を狭める語は避けた
- 一呼吸画面は静止画ではなく、実際のアプリを録画した動きを合成（呼吸アニメーション・カウントダウン3→2→1）

## 制作ログ（2026-09-26 Gemini Omni で試作）

- 出力: `output/organic/2026-09-26-uncanny-train/just-checking-one-thing-v2.mp4`（720×1280・約29.6秒・音声つき）
- モデル: `gemini-omni-1.1-flash`（Gemini API の Interactions。最初と最後のコマに絵コンテの「変化の前」「変化の後」を渡し、1本3〜4秒で12区間を生成）。14（一呼吸画面）は生成せず、実機の録画を合成した動画をそのまま挟んだ
- 費用: 13回生成（s07を1回作り直し）× 約$0.32 ＝ 約$4.2（720p・出力約5,800トークン/秒・$17.50/100万トークン）
- 学び: ①前後のコマの間を自然な動きでつなぐのは得意（首・手・目・車両の変化はすべて一発で成功） ②顔が映っていない絵を渡すと別人の顔を作る（s07で発生。「顔を映さない・カメラを上げない」と明記して解決） ③このMacのffmpegには文字描画が無いため、テロップは透明画像で重ねた
- 生成スクリプト: scratchpad の `gen_segment.py`（最初と最後のコマ＋指示文）と `assemble.py`・`telops.py`（区間の切り出し・速度調整・連結・テロップ）
- v3（オーナー指摘「手がスマホともっと一体化する場面がない」）: 一体化の絵を Gemini 3 Pro Image で作成（`fusion/fused-gemini-2.png`・皮膚がスマホを覆い画面だけ残る。gpt-image-2は弱く不採用）。Omniで「一体化」と「ほどける」の2本を生成。一体化側は最後まで一体化しきらなかったため、ほどける側（完全一体化から始まる）の前半を逆再生して一体化の場面に使い、音は一体化側の伸びる音を当てた。出力 `just-checking-one-thing-v3.mp4`（約32.7秒）。Omniの累計は15回・約$5
- v4（オーナー指摘「右手なのに左手の形になってる」）: v3の一体化の絵は、右腕の先で手の甲が見えているのに親指が上にあり、左手の形だった。ほどける動画は途中（約1.5秒）で右手の形へ入れ替わっていた。一体化の絵を右手の形（甲が見えて指が左向き＝親指は下側）に直し（`fusion/fused-v4.png`・Gemini 3 Pro Imageで生成→上に残った出っ張りを消す修正を1回）、ほどける動画 `takes/s11c.mp4` を作り直した。一体化の場面は今回もその前半の逆再生（`conform/s03f-fuse.mp4`）。順方向の一体化 `takes/s03e.mp4` は手が画面に触れるだけで一体化せず不採用。出力 `just-checking-one-thing-v4.mp4`（32.7秒）。Omniは17回・約$5.9
- 音（2026-09-27 オーナー質問「BGMいる？」）: v4の音量は−30LUFSで、SNSの目安（−14前後）より16dB小さかった。Omniの音に曲は入っていないが、全員の場面（10.8〜16.8秒）と一呼吸の画面がほぼ無音で、区間の切れ目ごとに音が変わる。比較用に2本を作った。`v5-loud` は音量だけ−14LUFSにそろえた版。`v5-bgm` は、ffmpegで合成した低いうなり・車両の走行音・高い空気音・上がっていく音を0〜16.8秒に敷いた版。一呼吸の画面で約1秒の余韻を残して止め、回復後は薄い走行音だけにした（合成スクリプト `audio/make_bgm.py`・権利の問題なし）。Geminiの聞き比べは、順番を入れ替えた3回で結果が割れた（低音のある方を当てたのは2回、良いとしたのは1回、毎回1本目を「足した音がある方」と回答）。AIの耳では判断できないため、判断はオーナーの試聴で行う
