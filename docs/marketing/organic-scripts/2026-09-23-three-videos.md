# 試作3本（2026-09-23）: 台本・根拠・作り方

状態: オーナー確認待ち（投稿しない）
動画: `creatives/organic/videos/2026-09-23/`（V1-SixHundredDays.mp4 / V2-Revenge.mp4 / V3-Want.mp4）
コード: `video/organic-shorts/`（Remotion。人物も背景もSVGでコード描画し、毎フレーム動かしている。画像生成AI・動画AIは使っていない）
作り方の正本: `.claude/specs/organic-shorts-code-drawn.md`

## 経緯

- 初版はAI画像の静止画に、ズームと字幕を重ねたものだった。オーナーが「キャラに動きがなさすぎる。なんで静止画なの？javascriptで動画作って」と却下した。初版は `_rejected-stills/` に移してある
- 現行版は人物をコードで組んでいる。瞬き・呼吸・親指のスワイプは常に動く。そのうえで台本に合わせた動作を入れた（起き上がりかけて戻る・あくび・頭をかく・通知でびくっとする・布団の中で足をばたつかせる・居眠りしてはっと起きる・身を乗り出して肩を落とす）

## 共通の作り

- 人物は1人。脳を別キャラにしない。代償は言葉で断定せず、画面の変化で見せる
- 冒頭0〜2.7秒は黒い箱の一行で状況を確定する。本編にアプリの宣伝は入れない
- 絵は明るい2D。太い黒線とフラットな塗り。線は4フレームごとにわずかに揺れ、カメラも手持ち風にゆっくり揺れる
- 英語ナレーション（Gemini TTS・声 Charon・1.08〜1.15倍速）。字幕は黒い箱で、読んでいる単語が黄色になる
- 効果音と下地の音は ffmpeg で合成した。他者の音源を使っていないので権利の問題がない
- 音量は -14.0〜-14.2 LUFS、true peak -1.3〜-1.4 dBFS（実測）
- 英文は humanizer-en 監査 exit 0（書く前と後の2回）
- 文字は上14%・下35%を避ける。字幕の中心は高さ1120px（分割画面の間だけ956px）

## V1「Six hundred days」18.8秒

| 秒 | 画と動き | 文字・声 |
|---|---|---|
| 0.0 | 夜のソファでスマホ。秋の窓。1.0〜2.7秒で起き上がりかけて、またソファに沈む | 箱: Me: "one more video, then I'm getting up." |
| 1.3 | 3.9秒で動画を見て吹き出す | Four hours a day doesn't feel like a lot. |
| 5.1〜5.8 | 早回し。窓が昼夜で点滅し、秋から冬へ。姿勢が3フレームごとに別の日に飛ぶ。親指が速くなる。床にゴミが2つ出る。年タグ 2026→2027 | It adds up to sixty days a year. |
| 6.7〜9.2 | あくび、続いて頭をかく | （同上） |
| 9.3〜10.2 | 早回し。冬から夏へ。植物が伸びる。床のゴミが4つになる。年タグ 2031 まで | Keep it up for ten years, |
| 10.9〜12.0 | 早回し。夏から雨へ。植物が枯れる。白髪と隈が出て、ソファがへたる。床のゴミが7つになる。年タグ 2036 | and you've spent over six hundred days of your life right here. |
| 12.5 | 「600」で画面が一瞬寄り、心音が鳴る | （同上） |
| 13.3 | 年を取った人物があくび | （同上） |
| 16.5〜18.8 | スマホから目を上げて、こちらを見る。雨の音だけ | （無音） |

計算: 4時間×365日＝1,460時間＝60.8日／年。10年で608日（「over 600 days」）。数字は視聴者の実測ではなく、物語の人物の使い方の計算。

## V2「Revenge」32.0秒

| 秒 | 画と動き | 文字・声 |
|---|---|---|
| 0.0 | 夜のベッド。まぶたが下がっては、はっと開いてまたスクロールする（2回） | 箱: There's a name for why you're still up. ／ 11:48 PM |
| 1.1 | 同じ | You're exhausted. You could fall asleep right now. |
| 6.0 | 夕方の職場。頬杖でタイピングする。吹き出しが届くたびに顔を上げてノートPCを見て、ため息をつく（3回） | But your whole day belonged to your job and everybody else. ／ 7:40 PM |
| 11.2 | ベッドに戻る。にやけて肩を揺らし、布団の中で足をばたつかせる | So you take the night back. ／ 12:30 AM |
| 14.0 | 名前カード。後ろでベッドの人物が動き続ける | Psychologists call it bedtime procrastination. |
| 17.9 | 赤い判「REVENGE」 | The internet calls it revenge. |
| 21.0 | 上下分割。上は今夜 1:40 AM で、足をばたつかせてスクロールする。下は明日 6:30 AM で、アラームで起きて目をこすり、頭が落ちてははっと起きる。「1 hour」が下から上へ3つ飛ぶ。そのたびに SLEEP が 7h→4h と減り、下の画面が色あせ、頭の落ち方が深くなる | Here's the catch. Every hour you take back comes out of tomorrow. |
| 26.8 | 翌日の職場。通知でびくっと起きるが、その後は居眠りを繰り返す | And tomorrow, the day won't be yours either. ／ NEXT DAY 7:40 PM |
| 30.8 | 夜のベッド 11:48 PM に戻る（ループ）。まぶたが下がる | （無音） |

根拠: bedtime procrastination の定義は Kroese et al. 2014, Front Psychol, doi:10.3389/fpsyg.2014.00611（「予定した時刻に寝られず、外的な理由もない」）。「revenge」は2020年に英語圏に広まったネット上の呼び名で、研究者の用語ではない（ナレーションもその区別どおり）。Europe PMC で実在を確認済み。

## V3「Want」32.1秒

| 秒 | 画と動き | 文字・声 |
|---|---|---|
| 0.0 | 夜のソファ。無表情でスクロールする。姿勢を直す・頭をかく・あくび。床に空き缶とスナックと持ち帰りの箱 | 箱: Why 2 hours of scrolling felt like nothing ／ 11:10 PM |
| 1.1 | 同じ | You scrolled for two hours and didn't enjoy a minute of it. |
| 6.0 | WANT／ENJOY のメーターが出る | Your brain runs wanting and enjoying on separate systems. |
| 11.6 | コードで描いたスマホの寄り。スワイプのたびに WANT が跳ね、ENJOY は下がる | Scrolling mostly feeds the wanting one. |
| 15.6 | 次の投稿の前に口を開けて身を乗り出し、出てくると肩が落ちる。「？」が出るたびに繰り返す。WANT は上がり続ける | It fires hardest when it can't predict what's next, and a feed never lets it predict. |
| 23.2 | 1:10 AM。少しずつずり落ちていき、あくびをする。WANT ×100／ENJOY ×2 | So two hours later, you've wanted a hundred things and enjoyed almost none of them. |

根拠: 「欲しい」と「楽しい」が別の仕組み＝Berridge & Robinson 1998, Brain Res Rev, doi:10.1016/s0165-0173(98)00019-8（dopamine systems are necessary for 'wanting' incentives, but not for 'liking' them）。「先が読めない時に一番強く反応する」＝Fiorillo, Tobler & Schultz 2003, Science, doi:10.1126/science.1077349（報酬の不確かさが最大の P=0.5 で持続的な活動が最大）。どちらも Europe PMC で要旨を確認済み。「×100／×2」は物語上の演出で、測定値ではない。

## 検証

- 書き出し: 1080×1920・30fps・H.264。3本とも0.5秒ごとのコマを並べて目視した。字幕・箱・メーターの重なりと画面外へのはみ出しはない
- 動き: 各動作を連続8〜12フレームで確認した（起き上がり・早回しの姿勢の飛び・居眠り・足のばたつき・通知への反応・身を乗り出し・あくび）
- 独立レビュー（Codex Astra medium）の指摘は1件。V1で親指の速さが変わる瞬間に、スマホ画面の投稿が巻き戻っていた。スクロール量を累積で計算する方式に直し、全560フレームで巻き戻りが0であることを確認した
- ナレーション音声は初版と同じファイル。faster-whisper の書き起こしが台本と一字一句一致することは初版時に確認済み

## 制作メモ

- 費用: Gemini TTS 約25回（数セント）。画像・動画の生成は0円
- 制作者は音声を聞けないため、声の質は未確認。女性の声の見本: `voice-sample-Sulafat-V1.m4a`
- BGM は合成したパッド音で仮。投稿前に、SNS投稿と広告転用が許諾された曲に差し替えるか判断が必要
- ElevenLabs のキーは未設定のため、設計書（`.claude/specs/organic-video-pipeline-2026-09-20.md`）の ElevenLabs 前提とは異なる
- `src/Checks.tsx` の `Check-*` は各ポーズ単体の確認用。本番の3本とは別
