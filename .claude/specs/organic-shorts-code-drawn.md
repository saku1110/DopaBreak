# 海外オーガニック短編: コード描画アニメの作り方（2026-09-23）

次の回を同じ方式で作る・直すための正本。台本と根拠は `docs/marketing/organic-scripts/2026-09-23-three-videos.md`。
企画の方向は `docs/marketing/2026-09-20-organic-video-topics-30.md`、バズ度の事前評価は `.claude/skills/organic-buzz-checker/SKILL.md`。

## 方式

- Remotion 4.0.527（React→MP4）。人物・背景・小物を SVG で毎フレーム描く
- CSSアニメ・`Math.random`・状態は使わない（並列レンダーで結果が変わるため）。乱数は Remotion の `random(seed)` だけ
- 1080×1920・30fps。SVGの座標単位は画面ピクセルと同じ
- AI画像にズームを足す方式は2026-09-23にオーナーが却下した（「キャラに動きがなさすぎる」）。以後は人物をコードで動かす

## ファイル構成（`video/organic-shorts/`）

| パス | 役割 |
|---|---|
| `src/rig/anim.ts` | 瞬き・呼吸・親指のスワイプ・スクロール・動作の包絡線（`envelope` `activeAct`）・居眠り（`dozeAt`）・累積スクロール（`phaseAt` `thumbFromPhase`） |
| `src/rig/Tube.tsx` | 黒フチ付きの太線（手足・胴） |
| `src/rig/Head.tsx` | 丸い頭。表情は Face（blink / look / lids / brows / mouth / bags / grey / hair）。口は flat / smile / sly / frown / o / wavy / yawn / grin |
| `src/rig/Phone.tsx` | スマホ。画面の投稿がスクロールし、振動もする |
| `src/rig/Stage.tsx` | 全画面SVG・カメラ（zoom / cx / cy）・線の揺れ（4フレームごと）・手持ち風の揺れ（drift） |
| `src/rig/CouchSlouch.tsx` | ソファ。slump / lean / lookUp / age、acts（getup / smirk / yawn / scratch / shift）、lapse（早回しで姿勢が飛ぶ）、thumb（速さが変わる親指） |
| `src/rig/BedLie.tsx` | 横になってスマホ。dozes（まぶたが下がってはっと開く）、kick（布団の中の足）、giggle |
| `src/rig/BedSitUp.tsx` | 朝のベッドで座る。droop（頭が落ちてはっと起きる）、buzz、acts の rub（目をこする） |
| `src/rig/DeskSit.tsx` | 職場の机。typing、nod（居眠り）、pings（通知でびくっ→ため息） |
| `src/sets/` | 背景。LivingRoom（季節・昼夜・植物・ソファのへたり・床のゴミ）、Bedroom（夜・朝）、Office（壁時計・ノートPCの通知数）、Clutter（床のゴミ7種） |
| `src/scenes/Scenes.tsx` | 背景・人物・カメラをまとめた場面（CouchScene / BedNightScene / BedMorningScene / OfficeScene） |
| `src/components/` | 字幕（単語ハイライト）・冒頭の箱・時刻タグ・音（ナレーション・効果音・下地） |
| `src/v1` `src/v2` `src/v3` | 各本。ナレーションの単語タイミング（`src/data/*.json`）から、場面と動作の時刻を決める |
| `scripts/tts.py` `scripts/prep.py` | ナレーション生成（Gemini TTS）と単語タイミング（faster-whisper）。出力は `src/data/*.json` と `public/<id>/*.wav` |
| `scripts/make_sfx.sh` | 効果音を ffmpeg で合成 |
| `scripts/stills.mjs` | 任意フレームの静止画を書き出す（確認用） |
| `scripts/finish.py` | レンダー→ -14 LUFS / -1.5 dBTP に正規化→ `creatives/organic/videos/2026-09-23/` |

## 動きの原則

- 静止画にズームを足しただけの画は不可。人物は常にどこかが動く（瞬き・呼吸・親指・頭の揺れ・線の揺れ・カメラの揺れ）
- 2〜4秒ごとに、読める動作を1つ入れる（あくび・頭をかく・姿勢を直す・通知でびくっとする等）。置く時刻は台本の単語に合わせる
- 時間の経過は早回しで見せる。窓の昼夜が点滅し、姿勢が3フレームごとに別の日へ飛び、床に物がたまる
- 確認は静止画1枚でしない。連続8〜12フレームを並べて、動きの大きさを目で見る
- 親指の速さが途中で変わる場面は `phaseAt` と `thumbFromPhase` を使う。周期を直接切り替えると画面の投稿が巻き戻る（Codexレビューで検出）

## レイアウト

- 上14%（〜269px）と下35%（1248px〜）に文字を置かない。冒頭の箱は SAFE_TOP=292
- 字幕の中心は1120px（分割画面の間は956px）。顔が600〜900px、手元が900〜1050pxに来るようにカメラを置く（zoom 1.3〜1.6）
- 同時に描く Stage の id を重複させない（SVGフィルタのIDが衝突する）。分割画面の下側は cx=0 なので drift=0 にする

## 新しい回の手順

1. 英語の台本を humanizer-en で監査し（前後2回 exit 0）、`scripts/lines.json` に入れる
2. `scripts/tts.py` → `scripts/prep.py` で音声と単語タイミングを作る
3. `src/vN/` に場面と動作を組み、`src/Root.tsx` に登録する
4. `npx eslint src && npx tsc --noEmit`
5. `node scripts/stills.mjs '[...]'` で要所の静止画と連続フレームを確認する
6. `python3 scripts/finish.py <CompositionId>` で書き出す
7. 0.5秒ごとのコマ並べと音量（ebur128）を確認し、Codex にレビューを出す

## 既知の制約

- 声の質は制作側で聴けない。書き起こしで台本との一致だけを確認している
- BGMは合成した仮の音
- ポーズはソファ・横寝・朝の座り・机の4つだけ。食卓や歩く場面には新しいポーズが要る
