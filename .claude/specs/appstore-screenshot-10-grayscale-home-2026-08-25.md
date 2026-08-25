# App Storeスクリーンショット #10 差し替え: 白黒ホーム画面モック（2026-08-25 オーナー指示）

## 指示（原文要旨）
「スクショの『SNSを開くと画面が白黒になる』は訴求としておかしい。設定したらSNSだけでなくホーム画面も白黒になる。SNSアプリが並んでるスマホのホーム画面を白黒にしたスクショにしてくれ」

## 決定
- パネル10（slug `grayscale-guide`）の**画面ソースを AutomationGuideView の実画面から、PILで描く iOS ホーム画面モック（白黒）へ差し替える**。パネル05の `mock_lock()` と同じ方式（`SOURCE_PATHS` の該当要素を `None` にし、`source_for()` で `mock_home_grayscale(CANVAS_SIZE, LOCALE)` を返す）
- slug は `grayscale-home` に改名（出力ファイル名 `10-grayscale-home.png`。upload-order 側も同名）
- コピーは3言語とも書き直す（下表）。「SNSを開くと白黒になる」の機構説明を見出しから外し、**「色を消してSNSをつまらなくする」**を見出しに置く。機構（開くと自動／サイドボタン3回の手動切替）はサブへ移す
- 構図・ライム多角形・キャラ（`worse` 幅340・中心x220・下端y2500・接地影あり）・フォン幅1396・0°・上端 `center_for_visual_top` はすべて現行どおり変更しない
- `SCREEN_CHARACTER_COUNTS` の10は 0 のまま（モック内にキャラなし）

## コピー（確定・humanizer監査済み）

| locale | eyebrow | headline 1行目 | headline 2行目 | sub | surface |
|---|---|---|---|---|---|
| ja | 白黒フィルタ連携 | 色を消して | SNSをつまらなくする | SNSを開くと自動で白黒に サイドボタン3回の手動切替も | dark |
| en-US | GRAYSCALE SHORTCUT | Strip the color | and social media gets boring | Goes gray the moment you open social media. Or triple-click the side button. | dark |
| ko | 흑백 필터 연동 | 색을 없애면 | SNS가 시시해져요 | SNS를 열면 자동으로 흑백 측면 버튼 세 번으로 직접 전환도 돼요 | dark |

- ja: 読点・句点なし・体言/終止で2行。サブの区切りは半角スペース（既存規則）
- en: `humanizer-en/scripts/audit.py` exit 0（2026-08-25実測）
- ko: `humanizer-ko/scripts/audit.py` exit 0（2026-08-25実測）
- 薬機法/景表法: 生理効果（刺激が減る・依存が治る等）の断定なし。「つまらなくする」は設計意図の表現

## モック仕様 `mock_home_grayscale(size, locale)` → 1320×2868 RGB

描画はすべてカラーで行い、**最後に `ImageOps.grayscale(...).convert("RGB")` で全面白黒化**する（「スマホごと白黒」を画で伝える。部分的に色を残さない）。

### 背景
- `lock_wallpaper(size)` を流用（同じ雰囲気の暗い壁紙）

### ステータスバー（iOSホームの配置。ロック画面と違い時刻は左）
- 左: `9:41` SF weight 600 サイズ約56px、左端 x≈150・y≈70（Dynamic Islandを避けた位置）
- 右: Wi-Fi＋バッテリー。`draw_lock_status_icons` の右側部分と同じ座標・形（中央の錠アイコンは描かない）

### アプリグリッド
- 4列×最大6行のうち **上4行を使う**（残りは空きでよい）。アイコン辺 **196px**、角丸は辺の 0.225（iOS 継続曲線近似で `rounded_mask` を使う）
- 列の中心x: 258 / 526 / 794 / 1062（左右余白と間隔が均等）
- 行のアイコン上端y: 330 / 640 / 950 / 1260
- ラベル: アイコン下 +14px、`font(locale, 34, False)` 白（235,237,239）、中央揃え。ラベルはアイコン中心xに中央揃え
- 並び（左→右・上→下）:
  1. Instagram / X / TikTok / YouTube
  2. Facebook / Threads / LINE / Safari
  3. 汎用4つ: ja=写真/メモ/カレンダー/天気、en=Photos/Notes/Calendar/Weather、ko=사진/메모/캘린더/날씨
  4. 汎用4つ: ja=マップ/ミュージック/メール/設定、en=Maps/Music/Mail/Settings、ko=지도/음악/메일/설정
- SNS 8個のタイルは **アプリ内 `AppIconView.swift` の catalogTile と同じ配色・同じグリフの意味**で描く（白黒化後も「あの並び」に見えるよう明度差を保つ）:
  - instagram: 左下→右上グラデ `#F9CE34→#EE2A7B→#6228D7`、白のカメラ（角丸矩形＋中央円＋右上の小さな点）
  - x: 黒地、白の太い×（2本の斜線、線幅≈22px）
  - tiktok: 黒地、白の音符（`♪`をSF 600で描く。フォントで出ない場合は縦棒＋楕円で描く）
  - youtube: `#FF0033`地、白の角丸横長矩形の中に地色の▶（再生三角）
  - facebook: `#1877F2`地、白の「人2人」（頭2つ＋肩の半円2つ）
  - threads: 黒地、白の `@`（SF 600）
  - line: `#06C755`地、白の吹き出し（角丸矩形＋左下の小三角）
  - safari: `#2FB4FF→#0A84FF`グラデ、白の円リング＋中を指す針（細い菱形を斜め45°）
- 汎用8個は iOS標準を**連想させる程度の単純図形**で可（写真=花弁状の円3つ、メモ=横線3本、カレンダー=上帯＋数字なし、天気=太陽円＋雲、マップ=折れ線道路、ミュージック=音符、メール=封筒、設定=歯車風の円リング）。実物ロゴの複製は不要・ブランド名以外のテキストはタイルに描かない
- 各タイルに `AppIconView` と同じく細い内側リング（白 alpha≈40・幅2px）

### 下部
- 検索ピル: 中央 y≈2470、幅≈330・高さ≈72、白 alpha≈60 の角丸矩形＋虫眼鏡＋ラベル（ja「検索」/en「Search」/ko「검색」、`font(locale, 30)`）
- ページドット: 検索ピルの上ではなく iOS 18 と同じくピルに内包（描かなくてよい）
- Dock: 下端から y≈2560〜2800、幅 1240、角丸 80、白 alpha≈45 の半透明帯。中に4タイル（辺196・中心x 258/526/794/1062・上端y≈2600、ラベルなし）: **Instagram / TikTok / YouTube / LINE** の再掲でよい（SNSがDockにも居る＝「つい開く位置」の描写）
- ホームインジケータ: `draw_lock_bottom_controls` の最後の行と同じ `(500,2784)-(820,2800)` 白バー

### 白黒化
- すべて描き終えてから `ImageOps.grayscale(image).convert("RGB")`。壁紙・アイコン・ラベル・Dock 全部が白黒になる

## 検証
- `python3 scripts/generate-appstore-screenshots-v2.py` を3ロケール実行し、10枚×3が 1320×2868 RGB で生成される（スクリプト内の既存 raise で検証）
- `output/app-store-screenshots/v2/{ja,en-US,ko}/iphone-69/10-grayscale-home.png` を原寸で目視: ①白黒で色が1画素も残っていない（`Image.getcolors` または R==G==B の全画素チェックをテストコード内で実行）②SNS 8アイコンが上2行に並び名前が読める ③キャラ `worse` がフォン左縁に重なりライム面に接地 ④見出し2行がフォンと重ならない
- upload-order の `10-grayscale-guide.png` を `10-grayscale-home.png` へ置き換え（旧ファイルは削除）
- contact-sheet 3枚と `slots-*.json` を再生成
- 旧 `10-grayscale-guide.png`（v2/{locale}/iphone-69 配下）は削除

## 関連
- 旧仕様: `.claude/specs/appstore-screenshots-v2-diagonal.md` パネル10行（本書で上書き）
- raw `output/app-store-screenshots/raw-core/*/grayscale.png` と `CoreScreensSnapshotCapture` の grayscale 撮影は**残す**（AutomationGuideView の目視検証用途）。スクショ合成では使わなくなるだけ
