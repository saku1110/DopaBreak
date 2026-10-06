# 実写風AI短編（Gemini Omni）の作り方と費用

作成: 2026-09-26 ／ 状態: 試作v3まで完了・オーナー確認待ち
関連: 絵コンテ [2026-09-26-uncanny-train-storyboard.md](../../docs/marketing/organic-scripts/2026-09-26-uncanny-train-storyboard.md)・出力 `output/organic/2026-09-26-uncanny-train/`
方針の経緯: 2026-09-26 オーナー決定「オーガニック短編は実写風AI動画（コード描画アニメは品質で却下）」。旧 [organic-video-pipeline-2026-09-20.md](organic-video-pipeline-2026-09-20.md) のPixar/イラスト2画風案はこの決定で止まっている

---

## 1. 手順

1. **絵コンテの絵**: 各場面の「変化の前」「変化の後」を作る。**画像は必ず gpt-image-2（Codex CLI の内蔵ツール・サブスク内）で作る**（`env -u OPENAI_API_KEY codex exec --skip-git-repo-check --enable image_generation -i <参照> -- "<指示>" < /dev/null`。`-i` は複数値を取るので指示の前に `--` が要る）。**Gemini 3 Pro Image など従量課金の画像生成は使わない**（2026-09-26 オーナー指示「今後画像はcodex cli経由で作れ必ず」。変形が弱いときは指示文と参照画像で補う。`scripts/gen_image.py` は使用禁止）
2. **区間ごとの動画**: `scripts/gen_segment.py first.png last.png prompt.txt out.mp4 [720p]`。1区間3〜4秒で作り、あとで切り出す
3. **画面の文字が要る場面**（DopaBreakの一呼吸画面）はAIに描かせない。シミュレータの実録画を挟む（撮影用テスト `testHoldBreathingScreenForOrganicVideo` を `-testLanguage en -testRegion en_US` で回し、`xcrun simctl io <UDID> recordVideo` で撮る）
4. **連結**: `scripts/assemble.py plan.json`（区間ごとに開始位置・長さ・速度を指定。実例 `omni/plan-v3.json`）
5. **テロップ**: `scripts/telops.py` で透明PNGを作り、ffmpeg の overlay で焼き込む（このMacのffmpegは drawtext が使えない）。画面の上14%と下35%には置かない

スクリプトの正本は `output/organic/2026-09-26-uncanny-train/omni/scripts/`（scratchpadは日をまたぐと消えるため移した）

## 2. Omni API の要点

- `POST https://generativelanguage.googleapis.com/v1beta/interactions`、ヘッダ `x-goog-api-key`。鍵は humanize-with-gemini スキルの `api_key()` で読み、値は表示しない
- モデル `gemini-omni-1.1-flash`。input は [最初の絵, 最後の絵, 文章] の順
- `response_format: {type: "video", aspect_ratio: "9:16", resolution: "720p", delivery: "uri"}`。完了までポーリングし、files の `:download` で取得
- 1回3〜10秒。音は自動で付く。無料枠なし
- 料金: 720pで1秒あたり5,792トークン × $17.50/100万 ≒ $0.10/秒（今回の実測は約$0.107/秒）

## 3. 分かったこと

- 最初と最後の絵を渡すと、動きは安定してつながる
- 最初の絵で顔が映っていないと、途中で別人の顔を作る。「顔は最後まで映さない」「糸は指から外れない」と指示に書くと防げた
- 変形を最後までやり切らないことがある。逆向き（変形しきった状態から元に戻る）を作って逆再生すると使える。v3の一体化の場面はこの方法（`omni/conform/s03c-fuse.mp4`）
- 手の左右を必ず確かめる。腕がどちらから来ているか・甲と手のひらのどちらが見えているか・親指の位置の3点で判定する（甲が見えて指が左を向く右手なら親指は下側）。v3は一体化の絵だけ左手の形で、Omniは前後の絵とつなぐ途中で手の形を入れ替えていた。前後の絵と左右をそろえた絵に直すと、入れ替わりは消えた
- 変形の途中のコマは6コマ程度を並べて見る。キー画像が正しくても途中で崩れることがある
- gpt-image-2 は変形を弱めて描く。ストレートネック（首が前に真っすぐ突き出る）は下描き `keyframes/pose-straight-neck-sketch.png` を参照に渡すと守られた

## 4. 費用の実績（v1〜v4）

Omni 17回・生成57.1秒で約$5.9（v4で2本追加）。完成動画で使ったのは32.7秒。撮り直しと切り捨てで、使う長さの約1.7倍を生成した

## 5. 他モデルとの単価比較（720p・音あり・2026-09-26確認）

| モデル | 1秒 | 20秒1本 | 今回と同じ49秒分 | 出典 |
|---|---|---|---|---|
| Gemini Omni 1.1 Flash | 約$0.10 | 約$2.0 | 約$5.0（実績） | Google公式の料金 |
| Kling 3.0 Standard Turbo | $0.112 | $2.24 | 約$5.5 | [fal](https://fal.ai/models/fal-ai/kling-video/v3/turbo/standard/image-to-video) |
| Kling 3.0 Standard | $0.126（音なし$0.084） | $2.52 | 約$6.2 | [fal](https://fal.ai/models/fal-ai/kling-video/v3/standard/image-to-video) |
| Seedance 2.5 | $0.2312 | $4.62 | 約$11.4 | BytePlus公式（[CellCog 2026-08-22集計](https://cellcog.ai/blog/seedance-2-5-pricing/)） |

- Kling の公式APIページ（kling.ai/dev/pricing）は料金が表示されず、公式価格は未確認。表は販売元 fal の価格
- 販売元で価格が変わる。Seedance 2.5 は fal 経由だと$0.473/秒で公式の約2倍
- 最後の絵の指定: Omni は可。Kling 3.0 Standard は fal に「End Image Url」欄あり。Turbo は未確認
- 1回で作れる長さ: Omni 3〜10秒、Seedance 2.5 4〜30秒。Kling 3.0 の上限は未確認
