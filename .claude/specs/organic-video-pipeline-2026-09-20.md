# DopaBreak オーガニック短編動画パイプライン 設計書

作成: 2026-09-20 ／ 状態: **オーナー確認待ち（実装未着手）**
関連: [企画方針](../../docs/marketing/2026-09-10-the-silent-mind-reference.md)・[2D/3D比較計画](../../docs/marketing/2026-09-10-2d-vs-3d-trends.md)・[主人公 brain-v2](../../creatives/organic/characters/brain-v2/README.md)

---

## 1. 目的と成果物

**目的**: 海外向け（英語・米国中心）Instagram Reels / TikTok のオーガニック短編を、同じ主人公で量産する道具を作る。最初の仕事は「3題材 × 2画風 = 6本」の比較試験を回すこと。

**成果物**: `video/organic-pipeline/` 配下のPythonパイプライン。台本JSON1つと画風の指定から、完成動画（mp4・1080×1920）・投稿キャプション・制作記録を出す。

**完了条件**:
1. `dry-run` が台本の検証だけでAPIを叩かずに通る
2. 同じ台本を `--style pixar` と `--style illust` で回し、画風以外（尺・字幕・BGM・ナレーション・CTA）が同一の動画が2本出る
3. 完成動画に音声トラック（ナレーション＋BGM）があり、字幕がナレーションと同期している
4. `run.json` に所要時間・使ったモデル・費用目安が残り、`contact-sheet.png` でキャラの再現性を目視できる
5. Fable 5.1 サブエージェントのレビューで、バグ・セキュリティ・ロジックの指摘がゼロ

---

## 2. 決定事項（2026-09-19〜20 オーナー回答）

| 論点 | 決定 |
|---|---|
| コピー元 | **骨格は配布用 `~/Desktop/pixar-video-pipeline`**。画風の切替分岐だけ本家 `~/Desktop/biohackjapan/src/video` から移植（本家の企画立案は栄養DB専用、台本自動生成は `generate()` 不在で動かないため） |
| 2画風の作り分け | **1本のパイプライン＋プリセット切替**（`--style pixar\|illust`） |
| 尺・音声 | **25秒前後・3シーン前後。人物は喋らない。英語ナレーションを別録りで重ねる** |
| 言語 | 英語のみ。日本語版は作らない |
| ピクサー風の主人公 | **brain-v2 を3D化**（2Dと同じ識別要素: ピンクの脳頭部・生成りスウェット・青灰パンツ・靴下足） |
| 画像モデル | `gemini-3.1-flash-image`（公式ページで確認 2026-09-19。キャラ参照画像を複数入力可） |
| 動画モデル | `grok-imagine-video-1.5`（同上。`generate_audio=False` で無音、1〜15秒、720p/1080p、9:16） |
| ナレーションTTS | **ElevenLabs `eleven_v3`**（声を `voice_id` で固定。`/with-timestamps` で文字単位のタイミング取得。商用は Starter 以上） |
| 企画・台本 | **別途オーナーと議論して作る**。本設計書は台本の「形」だけ決める |
| 構成（2026-09-21追記） | **2階建て**: A型＝6〜15秒・無音・テロップ・1ギャグ（主体、20本）／B型＝25〜30秒・脳の白状ナレーション（10本）。根拠は `docs/marketing/2026-09-20-reels-benchmark-6.md` |
| 最初の試験（2026-09-21追記） | **試験1＝目標の物体あり／なし**（3題材×2・2D固定・A型）。2D/3Dは試験2。企画表 §4 |
| やらないこと | 投稿の自動化／本編をアプリ宣伝で締める構成／リップシンク／日本語版 |

---

## 3. 全体の流れ

```
台本JSON（場面の英文・動きの指示・ナレーション英文・キャプション）
  │
  ├─ ① 検証（guard）      英語NGワード・断定表現・数値主張・尺の妥当性。APIなし
  ├─ ② ナレーション（tts） シーンごとにElevenLabsで音声＋文字タイミング → 各シーンの秒数が確定
  ├─ ③ 画像（images）     キャラ参照シート＋画風プリセットでGeminiが各シーンの静止画
  ├─ ④ 動画化（clips）    Grok 1.5 が静止画→無音クリップ（秒数は②で確定した値）
  ├─ ⑤ 連結（assemble）   クリップをつなぎ、実測の長さでシーン境界の時刻を確定
  ├─ ⑥ 音声（assemble）   ナレーションをシーン境界に置き、BGMを声の下で自動的に下げて敷く
  ├─ ⑦ 字幕（subtitles）  ②のタイミング＋⑤の境界から字幕を作り焼き込む
  ├─ ⑧ キャプション       台本の caption 欄からテキスト出力
  └─ ⑨ 記録（record）     run.json と contact-sheet.png
```

**なぜ②が③④より先か**: シーンの秒数はナレーションの長さで決まる。先に音声を作れば、動画クリップを「ナレーション＋余白」ちょうどの長さで発注でき、無駄な尺と費用が出ない。

---

## 4. ディレクトリ構成

```
video/organic-pipeline/
├── README.md            人向けの使い方（セットアップ・コマンド・費用・エラー対処）
├── CLAUDE.md            AI向け: 台本JSONの書き方と実行手順（AGENTS.md も同内容）
├── main.py              入口（サブコマンド式）
├── config.yaml          共通設定（尺・解像度・字幕の見た目・BGM音量・モデルID）
├── styles/
│   ├── pixar.yaml       ピクサー風: キャラ記述・画風・動きの指示・参照画像
│   └── illust.yaml      手描き2D:   同上
├── topics.yaml          題材リスト（企画方針docの6ネタを転記。台本づくりの入口）
├── scripts/             台本JSON（git管理する）
├── pipeline/
│   ├── utils.py         設定読込・.env・ffmpeg確認・ログ・リトライ
│   ├── script.py        台本の読み書きと検証
│   ├── guard.py         英語NGワード・表現チェック
│   ├── tts.py           ElevenLabs 音声生成＋タイミング
│   ├── images.py        Gemini 画像生成（参照画像つき）
│   ├── clips.py         Grok 画像→動画（無音）
│   ├── subtitles.py     タイミング→SRT→焼き込み（複数行）
│   ├── assemble.py      連結・ナレーション配置・BGM
│   ├── caption.py       キャプション出力
│   └── record.py        制作記録・コンタクトシート
├── assets/
│   ├── bgm/             BGM（mp3。オーナーが用意）
│   └── refs/
│       ├── brain-2d/character-sheet.png   creatives/organic/characters/brain-v2 からコピー
│       └── brain-3d/character-sheet.png   make-ref で1回生成（ピクサー風の参照）
├── output/              git管理外
│   └── <台本id>/<style>/
│       ├── tts/scene_01.mp3 …  ＋ timing.json
│       ├── scenes/scene_01.png …
│       ├── clips/scene_01.mp4 …
│       ├── final.mp4
│       ├── caption.txt
│       ├── contact-sheet.png
│       └── run.json
├── requirements.txt
├── .env.example         GOOGLE_API_KEY / XAI_API_KEY / ELEVENLABS_API_KEY
└── .gitignore           .env, output/, .venv/
```

---

## 5. コマンド

```bash
# 仮想環境（Python 3.12）
python3.12 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt

# ピクサー風の参照シートを1回だけ作る（2Dシートを入力に3D化。目視で採用判断）
python main.py make-ref --style pixar

# 動画APIの小テスト（画像1枚→8秒無音クリップ。約$0.7）
python main.py smoke-test --image assets/refs/brain-2d/character-sheet.png --style illust

# 本番。--mode は dry-run | tts-only | images-only | full（既定 full）
python main.py run --script scripts/five-more-minutes.json --style illust
python main.py run --script scripts/five-more-minutes.json --style pixar,illust   # 比較試験

# 字幕だけ作り直す（APIなし）
python main.py redo-subtitles --run output/five-more-minutes/illust
```

---

## 6. 台本JSONの形（確定）

```json
{
  "id": "five-more-minutes",
  "title": "Five more minutes",
  "topic": "bedtime",
  "scenes": [
    {
      "n": 1,
      "scene_description": "After work, sitting on the edge of the bed in a dim room. Phone in hand, lock screen clock reads 23:48.",
      "motion": "Almost still. Only the thumb moves. Phone light flickers faintly on the face.",
      "narration": "Five more minutes, I told myself."
    },
    {
      "n": 2,
      "scene_description": "Same pose. Clock now reads 00:42. Tomorrow's calendar notification is visible at the top of the screen.",
      "motion": "Thumb stops. Eyes shift slightly toward the notification.",
      "narration": "I wasn't even enjoying it anymore."
    },
    {
      "n": 3,
      "scene_description": "Morning. Alarm on the phone shows 06:30. The character lies in bed, eyes half open.",
      "motion": "Phone vibrates once on the nightstand. Slow blink.",
      "narration": "Morning still came at six thirty."
    }
  ],
  "caption": {
    "body": "Five more minutes never means five minutes.",
    "cta": "Ready to cut back? Link in bio.",
    "hashtags": ["#doomscrolling", "#screentime", "#phoneaddiction"]
  }
}
```

**A型（無音・テロップ）のとき追加する欄（2026-09-21追記）**
```json
{
  "format": "A",
  "narration": null,
  "scenes": [
    {
      "n": 1,
      "seconds": 4.5,
      "scene_description": "...",
      "motion": "...",
      "overlays": [
        {"text": "Me at 11:48: \"five more minutes.\"", "start": 0.0, "end": 4.5, "position": "top"},
        {"text": "00:12", "start": 1.0, "end": 2.2, "position": "clock"},
        {"text": "00:42", "start": 2.2, "end": 3.4, "position": "clock"},
        {"text": "01:30", "start": 3.4, "end": 4.5, "position": "clock"}
      ]
    }
  ]
}
```
- A型は `narration` を省略でき、`seconds` を各シーンに必ず書く（ナレーション長から決められないため）。TTS工程はスキップ
- `overlays` は字幕と同じ描画系で焼く。`position` は `top`（上14%を避けた上部）／`bottom`（字幕位置）／`clock`（画面の時計の位置。台本で座標を上書き可）
- B型は従来どおり `narration` 必須・`seconds` 任意

**ルール**
- 台本は人とAIが書く（`CLAUDE.md` に書き方を置く）。パイプラインは台本を生成しない
- `narration` は必須。字幕は `narration` から自動で作るので別に書かない
- `scene_description` `motion` は英語。キャラの外見は書かない（プリセットが足す）
- シーン秒数は書かない（ナレーション長から自動決定）。強制したい時だけ `"seconds": 8` を任意で足せる
- 時刻・回数などの数字は**物語上の設定として使う**。実測やアプリの効果として見せない（企画方針・景表法）
- 本編の最後にアプリの宣伝を入れない。導線は `caption.cta` のみ

**制作前の企画チェック（人＋AI・パイプライン外）**
- 台本JSONを書く前に `.claude/skills/organic-buzz-checker/SKILL.md` で10項目採点。70未満は生成しない。3（気づきの層）が6以下は合計に関係なく差し戻し
- 採点結果は `scripts/<id>.score.md` に保存し、`run.json` に合計点を転記する（投稿後の実測と突き合わせるため）

**検証（guard + script）**
- ナレーション1シーン ≤ 12秒相当（英語 約30語）／合計 ≤ 40秒相当
- シーン数 2〜5
- 英語NGルール（新規作成。例: `cure`, `addiction is`, `scientifically proven`, `% of people`, 診断の断定, 医療効果）。`severity: warn|block` を持ち、block は実行停止
- `caption.cta` の行き先は1つ（Link in bio か Search DopaBreak のどちらか）

---

## 7. 画風プリセット（styles/*.yaml）

**画風で変えるのはこのファイルの中身だけ。** 尺・字幕・BGM・ナレーション・CTAは共通（比較試験で画風以外を変数にしないため）。

```yaml
# styles/illust.yaml
id: illust
label: "手描き風2D"
reference_images:
  - assets/refs/brain-2d/character-sheet.png
character_en: >
  （brain-v2/prompt.txt の識別要素を要約: rounded cartoon brain head in dusty rose-pink #CDA2AE,
   simple expressive eyes and brows, no nose/hair, oatmeal crewneck sweatshirt, slate-blue trousers,
   ivory sock feet, slender relaxed adult body）
image_style_en: >
  Softly textured hand-drawn 2D animation still. Gently irregular ink outlines, restrained cel shading,
  subtle painted paper texture. Muted navy and gray night interiors, single light source from the phone.
  NOT 3D, not glossy, not kawaii merchandise. No text, no logos, no UI, no watermark.
motion_style_en: >
  Quiet limited-animation feel. Minimal movement: breathing, blink, thumb, light flicker.
  No speech, no lip movement, no dialogue, no camera shake, no particle effects, no dynamic camera moves.
  Keep the exact character design, colors and outfit from the input image.
```

```yaml
# styles/pixar.yaml
id: pixar
label: "ピクサー風3D"
reference_images:
  - assets/refs/brain-3d/character-sheet.png    # make-ref で生成
  - assets/refs/brain-2d/character-sheet.png    # 識別要素の元
character_en: >（illust と同じ識別要素）
image_style_en: >
  Pixar-style 3D animated film still. Soft subsurface skin, matte fabric, cinematic shallow depth of field,
  restrained expressions suited to adult everyday life. Muted navy/gray night interiors lit by the phone.
  No exaggerated cartoon grin, no high-gloss plastic look. No text, no logos, no UI, no watermark.
motion_style_en: >（illust と同じ静かな動き指示。3Dの語彙に合わせて微修正）
```

**make-ref（3D参照シートの作り方）**: brain-2d のシートを参照画像に、`image_style_en` のピクサー風指定で「同じレイアウトの3Dキャラシート」を Gemini に1枚出させる。オーナーが目視で採用するまで本番に使わない。採用したら `creatives/organic/characters/brain-3d-v1/` にも複製し README を書く（既存キャラ管理の型に合わせる）。

---

## 8. 各工程の仕様

### 8.1 tts.py（ElevenLabs）
- `POST /v1/text-to-speech/{voice_id}/with-timestamps`、`model_id: eleven_v3`、出力 mp3 44.1kHz
- `voice_id` は `config.yaml` に置く（全話同じ声）。`stability` 等の声設定も config
- 返る `alignment.characters` / `character_start_times_seconds` / `character_end_times_seconds` を**単語に集約**して `timing.json` に保存（`{"words":[{"w":"Five","s":0.12,"e":0.41}, …], "duration": 2.9}`）
- シーン秒数の決定: `seconds = clamp(ceil(duration + lead_in + tail), min=4, max=15)`。`lead_in=0.5`、`tail=1.0`（config）。台本に `seconds` があればそれを優先（ナレーションより短ければ block）
- 失敗時: 3回リトライ。全滅なら実行停止（音声なしで先に進まない）

### 8.2 images.py（Gemini）
- モデル `gemini-3.1-flash-image`。`reference_images` を全部＋`character_en`＋`image_style_en`＋`scene_description` を1リクエストに
- 出力 9:16。1080×1920 に揃える（配布用の回転・リサイズ処理を流用）
- 1シーン1枚。`--mode images-only` で止められる

### 8.3 clips.py（Grok 1.5）
- `POST /v1/videos/generations`、`model: grok-imagine-video-1.5`、`image` に静止画、`duration: seconds`（8.1で確定）、`aspect_ratio: 9:16`、`resolution: 720p`（config で 1080p に変更可）、**`generate_audio: false`**
- プロンプト = `motion_style_en` ＋ 台本の `motion`。本家の "dynamic, particle effects, camera movement" 指示は使わない
- ポーリング・ダウンロード・失敗シーン一括リトライは配布用をそのまま
- 生成後 ffprobe で **音声トラックが無いこと**と**実尺**を確認。音声が付いていたら `-an` で落とす（無音指定が効かない場合の保険）

### 8.4 assemble.py
- 連結: 配布用 `_concatenate_clips`（`-c copy` → 失敗時再エンコード）。音声なし前提に `[i:a]` 参照を外す
- シーン境界: 各クリップの実尺（ffprobe）を累積して `offsets.json`
- ナレーション配置: 各 `scene_NN.mp3` を `offset_i + lead_in` に `adelay` で置き、1本のナレーショントラックに合成
- BGM: 本家 `_add_bgm` の **sidechaincompress（声の下でBGMを下げる）を流用**。入力を「ナレーショントラック」に差し替える。`bgm_volume` `fade_in` `fade_out` は config。`assets/bgm/` から `config.bgm_file` または台本の `bgm` を選ぶ
- 出力: `final.mp4`（h264 + aac、1080×1920、30fps）

### 8.5 subtitles.py
- 入力: `timing.json`（シーンごとの単語タイミング）＋ `offsets.json`。**Whisper は使わない**（依存もrequirementsから外す）
- 単語を行に詰める: 1行 ≤ 28文字、最大2行、1チャンク 1.2〜4.0秒、文末（. ? ! ,）で優先的に切る
- 絶対時刻 = `offset_i + lead_in + word.s`。SRT を保存（`redo-subtitles` の入力）
- 描画: 配布用 `burn_subtitles` / `_render_text` を流用し**複数行対応を追加**。フォントは英語太字（macOS: Helvetica Neue Bold → Arial Bold、Linux: DejaVu Sans Bold）。中央揃え・白文字・黒縁
- **位置**: 字幕ブロックの中心を高さの **60%** に置く（Reels/TikTok の上14%・下35%の安全領域を避ける。配布用の `margin_bottom=320` は下35%に入るので使わない）
- 透かし: 既定オフ（本編にブランド表示を入れない企画方針）

### 8.6 caption.py
- `caption.txt`: `body` → 空行 → `cta` → 空行 → hashtags。生成はしない（台本の転記）

### 8.7 record.py
- `run.json`: 台本id・style・開始/終了時刻・工程ごとの秒数・使ったモデルID・API呼び出し回数・費用目安（config の単価表から計算）・各クリップ実尺・失敗と再試行の回数
- `contact-sheet.png`: 各クリップの先頭フレームと中間フレームを横に並べた1枚。`--style pixar,illust` のときは2画風を上下に並べる（キャラ再現性の目視用）

---

## 9. 設定（config.yaml）

```yaml
models:
  image: gemini-3.1-flash-image
  video: grok-imagine-video-1.5
  tts: eleven_v3
video:
  width: 1080
  height: 1920
  fps: 30
  resolution: 720p          # grok に渡す。1080p 可
  scene_min_seconds: 4
  scene_max_seconds: 15
  lead_in_seconds: 0.5
  tail_seconds: 1.0
tts:
  voice_id: ""              # オーナーが選んだ声のID
  stability: 0.5
  similarity_boost: 0.75
subtitle:
  font_size: 60
  max_chars_per_line: 28
  max_lines: 2
  center_y_ratio: 0.60
  color: "#FFFFFF"
  stroke_color: "#000000"
  stroke_width: 4
audio:
  bgm_file: ""              # assets/bgm/ 内のファイル名。空なら最初の1曲
  bgm_volume: 0.25
  duck_ratio: 8             # 声の下でBGMを下げる強さ
  fade_seconds: 1.0
cost_hints_usd:              # run.json の費用目安用。実価格は各社の料金ページが正
  image_per_call: 0.10
  video_per_second: 0.08
  tts_per_1k_chars: 0.10
```

`.env`: `GOOGLE_API_KEY`, `XAI_API_KEY`, `ELEVENLABS_API_KEY`。起動時に必要なキーだけ確認（`dry-run` は不要）。

---

## 10. 移植表（どのファイルをどこから持ってきて何を変えるか）

| 新ファイル | 元 | 変更 |
|---|---|---|
| `utils.py` | 配布 `pipeline/utils.py` | そのまま＋ELEVENLABS キー確認 |
| `script.py` | 配布 `pipeline/script_generator.py` | スキーマを §6 に差替え。`narration_chunks`/`subtitle_chunks`/`voice_style` を削除。検証を追加 |
| `guard.py` | 配布 `pipeline/ng_word_filter.py` の機構＋本家の `severity` | ルールを英語で新規作成 |
| `images.py` | 配布 `pipeline/image_generator.py` ＋ 本家 `scene_image_generator.py` の style 分岐 | モデルID更新、参照画像の複数入力、3分岐 f-string → プリセット辞書 |
| `clips.py` | 配布 `pipeline/video_generator.py` | モデル1.5、`generate_audio:false`、per-scene duration（本家は config 固定10秒で台本の秒数を無視していた）、音声・演出ブロック削除、無音検査 |
| `subtitles.py` | 配布 `pipeline/subtitle_generator.py` の描画系のみ | Whisper 系削除、SRT源を timing.json に、複数行、位置60% |
| `assemble.py` | 配布 `pipeline/video_assembler.py` ＋ 本家 `_add_bgm` の sidechain | ナレーション配置を追加、`[0:a]` 前提を外す |
| `tts.py` `record.py` | 新規 | — |
| `caption.py` | 配布 `video_assembler._save_caption` | 独立モジュール化 |
| `main.py` | 配布 `main.py` | サブコマンド式、`--style` 複数指定、`make-ref` `smoke-test` `redo-subtitles` |

**コピーしないもの**: 本家 `db_topic_generator.py`（栄養DB専用）、`subtitle_generator.py` の Manus/Whisper 系（約1,000行）、`test_kling.py` `test_veo3.py`（APIキー平文）、biohack のハッシュタグ・透かし・CTA設定。

---

## 11. 小テスト（実装の途中で1回だけ・約$1）

`smoke-test` で確かめること。結果を `run.json` と同じ形で残す。

| 確かめる | 合格 | 不合格なら |
|---|---|---|
| Grok 1.5 の `generate_audio:false` が効く | ffprobe で音声トラックなし | `-an` で落とす保険で続行し、記録に残す |
| 2D の絵柄が8秒間崩れない | 先頭・中間・末尾フレームで頭部の形と色が保たれる | Kling 3.0（`generate_audio:false`）を第2候補として `clips.py` に差し替え口を用意 |
| 静かな動きになる | カメラが動かない・人物が喋らない | `motion_style_en` の否定語を強める |
| ElevenLabs `with-timestamps` が `eleven_v3` で返る | `alignment` が入る | `eleven_multilingual_v2` に落とす |

---

## 12. 実装の分け方（Codex へ出す単位）

すべて **L2（Astra medium）**: 3ファイル以上・外部API3社・新規設計を含むため。各バッチ後に Fable 5.1 サブエージェントがレビュー。

| バッチ | 中身 | 完了の確認 |
|---|---|---|
| B0 骨格 | ディレクトリ・`utils.py` `script.py` `guard.py` `config.yaml` `styles/*` `topics.yaml` `README.md` `CLAUDE.md` `requirements.txt` `.env.example` `.gitignore`・`main.py` の `dry-run` | サンプル台本で `dry-run` が通る。NGワードで block される |
| B1 生成 | `tts.py` `images.py` `clips.py`・`make-ref` `smoke-test`・`tts-only` `images-only` | 小テスト §11 を実施し記録 |
| B2 仕上げ | `subtitles.py` `assemble.py` `caption.py` `record.py`・`run`（full）・`redo-subtitles` | 台本1本を `pixar,illust` で回し §1 の完了条件を満たす |

---

## 13. オーナーに用意してもらうもの（実装と並行で可）

1. **ElevenLabs のアカウントと APIキー**（商用利用は Starter 以上）。声は英語ナレーション向けの落ち着いた声を1つ選び、`voice_id` を config に入れる
2. **BGM**: 静かな内省系（ピアノ・アンビエント・ローファイ）を2〜3曲、SNS投稿と広告転用が許諾された音源で。`assets/bgm/` に置く
3. **3D参照シートの採用判断**: `make-ref` の出力を見て採用/やり直し
4. **企画と台本**: 別途議論。台本の形は §6

---

## 14. 想定外への備え

| 起きうること | 対応 |
|---|---|
| Grok が指定秒数ちょうどを返さない（本家実測 10.04秒） | 実尺で境界を作る（§8.4）。字幕は実尺基準 |
| Grok が無音指定を無視する | ffprobe で検出し `-an`。記録に残す |
| Gemini が参照画像を無視してキャラが変わる | `contact-sheet.png` で目視。崩れたシーンだけ `images-only` で再生成できるよう、シーン単位の再実行を `--scenes 2` で許す |
| ElevenLabs のレート制限 | シーン間 1 秒待機・3回リトライ |
| 2画風で尺がずれる | 尺はナレーション長で決まるので同一。クリップ実尺の差（±0.1秒）は許容し記録 |
