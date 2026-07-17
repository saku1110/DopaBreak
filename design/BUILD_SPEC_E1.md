# DopaBreak — E1 "Dark Mono" 全画面ビルド仕様（Codex実装用）

> **2026-07-12 現行実装への読み替え（この注記を本文より優先）**
> - 最新の視覚正本は `output/imagegen/lifefocus_latest_spec/` と `design-qa.md`。本文の旧HTMLモック22画面仕様は履歴として残す。
> - 朝焼けの海写真をWelcome / Home / Ready / Paywall / Notification previewに限定して使用する。介入・設定・入力画面は無写真E1 Dark Mono。
> - 介入は「目的確認6択」が最初。仕事/調べもの/連絡/投稿は呼吸を省略し、暇つぶし/なんとなくだけ呼吸へ進む。
> - 時間は5/10/15/30分。選択後に`[N分だけ開く]`で確定し、「自動で閉じる」と表現しない。
> - Homeは推測時間を表示せず、実ログの「自分で選べた回数」を達成ヒーローにする。
> - SwiftUIの正本資産は `ios/DopaBreak/Resources/morning-horizon.png`。

あなた（Codex）のタスク: この仕様に従い、DopaBreakアプリの **全22画面を HTML/CSS で実装**する。
1ファイル＝1画面。出力先 `output/mockups/lifefocus_v2/NN_screen.html`。
すべて **同一のデザインシステム**（下記）を共有し、iPhone 16 Pro 論理サイズ **402×874pt** で組む。
Chrome headless で `--force-device-scale-factor=3` レンダリングして **1206×2622px** のPNGを得る前提。

参照テンプレート（この世界観・コンポーネントを踏襲する正典）: `design/_reference_E1_intervention.html`
参考レンダリング: `design/_reference_E1_intervention.png`, `design/_reference_E1_lockwidget.png`

省略・TODO・プレースホルダ禁止。全ファイルを完全なHTMLとして出力すること（`output-skill` 準拠）。

---

## 0. アートディレクション（厳守）

"Dark Mono" — Oura / Linear / Whoop / Teenage Engineering の系譜。冷たい規律・計測アプリ・外科的精度。
イラスト・多色・カジノゴールド・ドロップシャドウ・装飾リングは禁止。写真は上記5面の朝焼け海に限定し、固定の暗色オーバーレイを必須とする。操作画面はタイポグラフィが主役。

## 1. デザイントークン（全画面共通の :root）

```css
:root{
  --bg:#0A0B0D;        /* near-black 背景 */
  --bg2:#101216;       /* やや明るい面 */
  --card:#14171C;      /* カード面 */
  --ink:#F4F5F2;       /* 主テキスト off-white */
  --muted:#7E8694;     /* 副テキスト cool grey */
  --line:rgba(255,255,255,.08); /* hairline divider */
  --accent:#C7F94D;    /* 唯一のアクセント electric lime。使用は最小限 */
  --accent-dim:rgba(199,249,77,.14);
  --danger:#FF6B5A;    /* 警告/赤系（使うのは最小限） */
}
```

背景は `radial-gradient(120% 80% at 50% -10%, #15181E 0%, var(--bg) 55%)`。

## 2. フォント（Google Fonts / 各HTMLの<head>でlink）

```html
<link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&family=Zen+Kaku+Gothic+New:wght@400;500;700;900&display=swap" rel="stylesheet">
```

- 日本語本文/見出し: `'Zen Kaku Gothic New'`（400/500/700/900）
- 数字・英語の見出し/時計: `'Space Grotesk'`（500/600/700、字間 -.02em）
- 極小ラベル（セクションタグ）: `'JetBrains Mono'`、UPPERCASE、letter-spacing .3em前後、色 --muted

`body{font-family:'Zen Kaku Gothic New','Space Grotesk',sans-serif;}`

## 3. 画面の枠・共通コンポーネント

- `html,body{width:402px;height:874px;}` `overflow:hidden;` `-webkit-font-smoothing:antialiased;`
- `.screen{width:402px;height:874px;padding:0 26px;display:flex;flex-direction:column;position:relative;}`
- **ステータスバー**（全アプリ内画面の最上部・高さ54px・9:41＋信号/wifi/電池SVG）: 参照テンプレートの `.status` ブロックのSVGをそのまま流用（色は --ink）。
- **ホームインジケータ**: `.home{position:absolute;left:50%;transform:translateX(-50%);bottom:9px;width:134px;height:5px;border-radius:3px;background:rgba(255,255,255,.32);}`
- **極小タグ**: `.tag{font-family:'JetBrains Mono';font-size:11px;letter-spacing:.34em;color:var(--muted);text-transform:uppercase;}`
- **primaryボタン**: 高さ58px・`border-radius:16px`・`background:var(--accent)`・文字 `#0A0B0D`・700。
- **ghostボタン**: 透明・`border:1px solid var(--line)`・文字 --muted・500。
- **カード**: `background:var(--card);border:1px solid var(--line);border-radius:18px;`
- **タブバー**（コア4画面のみ・最下部）: 高さ約72px・4アイコン（ホーム/目標/統計/設定）・選択中のみライム、他は --muted。アイコンはinline SVG（線画・線幅1.6）。

## 4. レンダリング・スクリプト（あなたが作成して実行）

`output/mockups/lifefocus_v2/render.sh` を作り、各HTMLを Chrome headless で 1206×2622 PNG 化する:

```bash
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
DIR="$(cd "$(dirname "$0")" && pwd)"
for f in "$DIR"/*.html; do
  name="$(basename "${f%.html}")"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=3 --window-size=402,874 \
    --virtual-time-budget=4000 \
    --screenshot="$DIR/$name.png" "file://$f" >/dev/null 2>&1
  echo "rendered $name"
done
```

実行後 `sips -g pixelWidth -g pixelHeight output/mockups/lifefocus_v2/01_welcome.png` 等で1206×2622を確認すること。

---

## 5. 全22画面の内容（各画面の確定コピー・レイアウト）

すべて日本語UI。SNS実ロゴは使わず汎用アイコン（円＋記号）。数値・統計はリアルなダミー。

### オンボーディング（9）

**01_welcome** — ファイル名 `01_welcome.html`
- 上部小タグ `LIFEFOCUS`。中央やや上に細いライム弧の集中マーク（控えめ・見出しに被らせない／余白に退避）。
- 大見出し（Zen Kaku 900, 約40px）「人生は、/ スクロールより広い。」2行。
- 副文（--muted, 16px）「開く前に目的を選び、必要な時間だけ使う。」
- 最下部 primaryボタン「はじめる」。下に ghost文字リンク「すでに使ったことがある」。

**02_self_check** — `02_self_check.html`
- タグ `STEP 01 / 04`。見出し「1日に何回、無意識にSNSを開いていますか？」
- 選択肢カード4つ（縦積み・タップ選択UI、2つ目を選択状態＝ライム枠）: 「5回未満」「5〜15回」「15〜30回」「30回以上」。各カード右に小さなチェック領域。
- 下に補足「平均的な人は1日96回スマホを手に取ります。」 primaryボタン「次へ」。

**03_choose_apps** — `03_choose_apps.html`
- タグ `STEP 02 / 04`。見出し「止めたいアプリを選ぶ」。副文「いつでも変更できます。」
- グリッド（2列）でアプリ汎用アイコン＋名称＋トグル: X / Instagram / TikTok / YouTube / Facebook / LINE（実ロゴ使わず汎用の幾何アイコン）。X・Instagram・TikTokをON（ライム）状態に。
- primaryボタン「3つのアプリをブロック」。

**04_goal_setup** — `04_goal_setup.html`（NEW・ヒーロー機能）
- タグ `STEP 03 / 04`。見出し「あなたの人生の目標は？」副文「開く前に毎回これを思い出します。」
- 入力欄2つ（カード型・ラベル付き）:
  - `あなたの目標 / YOUR GOAL`（大）入力済み風テキスト「英語で商談できる自分になる」
  - `1年後の自分 / 1 YEAR`（中）入力済み風「TOEIC 900 / 海外チームと働く」
- 補足「目標は短く、心が動く言葉で。」 primaryボタン「次へ」。

**05_choose_mode** — `05_choose_mode.html`
- タグ `STEP 04 / 04`。見出し「どのくらい強く止めますか？」
- 3つの選択カード（縦）: 
  - 「ディープフォーカス」— 開くのに3秒呼吸＋意図確認＋時間制限。説明「最も効果が高い」。選択状態（ライム枠）。
  - 「スタンダード」— ひと呼吸＋意図確認。
  - 「ナイトオンリー」— 21時以降だけ強化。
- primaryボタン「この設定で進む」。

**06_intervention_preview** — `06_intervention_preview.html`
- タグ `PREVIEW`。見出し「SNSを開こうとすると、こうなります」。
- 縦フロー図（3ステップを小カードで縦に）: ①ひと呼吸（3秒リング縮図）→ ②目標を思い出す（目標カード縮図）→ ③意図を選ぶ（開かない/必要な時間だけ）。各ステップ間に細いライム縦コネクタ。
- primaryボタン「なるほど、続ける」。

**07_permission** — `07_permission.html`
- タグ `PERMISSION`。中央にスクリーンタイムの抽象アイコン（盾＋時計の線画SVG）。
- 見出し「スクリーンタイムへのアクセスを許可」。副文「アプリの起動を検知してブロックするために必要です。使用データは端末内に留まり、外部に送信されません。」
- primaryボタン「許可する」。ghost「あとで」。

**08_notification_guide** — 旧`08_widget_guide.html`を置換
- タグ `NOTIFICATION`。見出し「ロック画面に、戻る先を」。副文「朝の通知とLive Activityで、目標を毎日思い出します。」
- 中央に朝焼け写真付きのLive Activityプレビュー（目標＋「今日 N回 開かずに戻れた」）。
- primaryボタン「通知をオンにする」。ghost「あとで」。

**09_ready** — `09_ready.html`
- 中央に細いライム弧が閉じたチェック（◯にライムの✓・線画）。見出し（大）「準備完了。」
- 副文「必要なときだけ、必要な時間だけ。」目標の再掲（小カード「英語で商談できる自分になる」）。
- primaryボタン「DopaBreakをはじめる」。

### コア（4タブ）

**10_home** — `10_home.html`（タブ: ホーム選択）
- 上部: 朝焼け海の132pt帯、日付小タグ `TODAY · 7月12日`、右に今週の回数。
- ヒーロー: `あなたの目標` ラベル＋大テキスト「英語で商談できる自分になる」。
- 達成ヒーロー: `14回`＋「今日、自分で選べた」。下に「開かずに戻れた / 開こうとした」の2メトリクス。
- 週カード: ライムの細いバー＋「今週N回、自分で選び直しました」。推測の節約時間は表示しない。
- 最下部タブバー（ホーム/目標/統計/設定）。

**11_goals** — `11_goals.html`（タブ: 目標選択）
- タグ `YOUR GOAL`。大カードに「英語で商談できる自分になる」＋小さな編集アイコン。
- `1年後の自分` カード「TOEIC 900 / 海外チームと働く」。
- 軽量に留める（タスク管理・期限・チェックリストは置かない）。下に静かな一文「目標は、あなたを連れ戻す錨です。」
- タブバー。

**12_stats** — `12_stats.html`（タブ: 統計選択）
- タグ `STATS · 今週`。上部に大数字「82%」＋ラベル「開かずに我慢できた割合」。
- 内訳: 時間帯別の小ヒートマップ風バー（朝/昼/夜）、理由別リスト（暇つぶし42% / 通知22% / 習慣20% / 連絡16%）を細バーで。
- 週次推移の折れ線（控えめ・ライム1本）。タブバー。

**13_settings** — `13_settings.html`（タブ: 設定選択）
- タグ `SETTINGS`。グループ化リスト（カード内に行）: 介入の強さ / 対象アプリ / ロック画面ウィジェット / 通知 / DopaBreak Pro（右にライム小バッジ「Pro」）/ プライバシー / 利用規約。
- 各行は左ラベル＋右シェブロン。区切りはhairline。タブバー。

### 介入フロー（Shield・6）

**14_s01_breath** — `14_s01_breath.html`
- = 参照テンプレートとほぼ同型（ただしボタンはまだ出さない、呼吸に集中）。
- タグ `INTERCEPTED` / 右 `X · 今日 18回目`（18ライム）。中央に大リング＋数字「3」、下に「ひと呼吸おきましょう」＋mono「BREATHE · 3 SEC」。下部は空白（呼吸の余白）。

**15_s02_usage_summary** — `15_s02_usage_summary.html`
- タグ `今日のX`。見出し数字「18回」＋「すでに開いています」。
- 目標カード（ライムドット＋`あなたの目標`＋「英語で商談できる自分になる」）。
- 小さな比較文「合計 2時間14分。英語学習に換算すると…」。primaryボタン「それでも開く理由を選ぶ」、ghost「やめておく」。

**16_s03_intent** — 現行フローの最初の画面
- タグ `INTENT`。見出し「何のために開きますか？」
- 理由カード（2列×3段）: 「仕事で使う」「調べもの」「連絡を確認」「投稿する」「暇つぶし」「なんとなく」。
- 選択に応じた問い（--muted）「それは、今日の目標に近づきますか？」＋目標小カード。
- primaryボタン「必要な時間だけ開く」、ghost「開かない」。

**17_s04_time** — `17_s04_time.html`
- タグ `TIME`。見出し「何分だけ開きますか？」
- 2列×2段で5 / 10 / 15 / 30分（10分を選択＝ライム枠）。
- 補足「時間になったら通知でお知らせします。」primaryボタン「10分だけ開く」。

**18_s05_cancel_success** — `18_s05_cancel_success.html`
- 中央に角丸カード＋ライムの✓。見出し（大）「開かなかった。あなたの勝ち」。
- 副文「今日 15回目の『開かない』。」目標小カード再掲。
- 小メトリクス「今日 N回 開かずに戻れた」。primaryボタン「閉じる」。

**19_s06_reintervention** — `19_s06_reintervention.html`
- タグ `TIME UP`。見出し「そろそろひと休み」。副文「そろそろN分。見てどうだった？」。
- 通知タップ後は見たあとの振り返りへ進む。アプリを自動で閉じる、または時間を強制延長する表現は使わない。

### ウィジェット（2）

**20_lock_widget** — `20_lock_widget.html`
- = ロック画面全体（参照 `design/_reference_E1_lockwidget.png` の構図、ただし精密に）。
- 暗いロック壁紙、上部に大時計「9:41」（Space Grotesk）。中央に目標ウィジェットカード（hairlineライム縁）: mono `YOUR GOAL · あなたの目標`＋大「英語で商談できる自分になる」＋小ライム進捗。
- その下に小円ウィジェット「今日 0回 開いた」（ライムドット）。最下部にライト/カメラのロック画面アイコン＋ホームインジケータ。
- ※Gemini版にあった右下のライム小箱の描画ブレは作らない（正確に組む）。

**21_home_widget** — `21_home_widget.html`
- ホーム画面の壁紙（暗・抽象）上に DopaBreak ウィジェットを2種類並べて見せる:
  - Small（正方）: 大数字「14」＋ラベル「今日 開かなかった」＋ライムドット。
  - Medium（横長）: 左に目標「英語で商談できる自分になる」、右に小リング「82%」。
- 下に他アプリアイコンのダミー数個（モノクロ円）でホーム画面らしさ。

### マネタイズ（1）

**22_paywall** — `22_paywall.html`
- タグ `LIFEFOCUS PRO`。見出し「人生を、本気で取り戻す。」
- ベネフィット行（4・チェック付き）: 「すべてのアプリをブロック」「ロック画面ウィジェット」「詳細な統計とコホート」「複数の目標とモード」。
- プラン選択カード3つ（横/縦）: 月額 ¥600 / 年額 ¥3,600（小バッジ「2ヶ月分お得」・選択状態ライム）/ 買い切り ¥9,800。
- primaryボタン「7日間無料ではじめる」。下に極小 --muted「いつでも解約可能 · 利用規約 · 復元」。

---

## 6. 品質チェック（実装後あなたが確認）

- 全22 PNG が 1206×2622 で出力されている（`sips` 確認）。
- 日本語の改行・文字切れが無い。見出しに装飾が被って可読性を損なっていない。
- アクセント(ライム)は各画面で「ひとつの役割」に絞られている（多用しない）。
- primaryボタンが下部・十分なタップ領域。トーン/トークンが全画面で一貫。
- 介入フローが「目的確認→目的別分岐→時間選択→通知→振り返り」で筋が通る。明確目的では呼吸を省き、反射的目的だけ呼吸・回数・目標確認を通る。
</content>
