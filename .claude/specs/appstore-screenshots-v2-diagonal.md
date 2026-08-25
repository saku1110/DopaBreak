# App Store スクリーンショット v2 — 対角ライム×脳キャラ（設計仕様）

作成: 2026-08-20 / 設計: Fable / 実装: Codex / 根拠: オーナー提示の参考プレート（design-patterns 10案のChatGPT生成物・対角ライム分割）
オーナー指示: ①この参考デザインをベースに ②脳キャラ（Dopa）を入れる ③見て楽しく、ベネフィット・機能がわかりやすく ④**モックの見せ方と背景構成は毎枚変える。大まかなトンマナ・配色は共通** ⑤モック内はコア体験の実画面を使い、**画面内＋外乗せのキャラは1枚につき合計1体まで**

## スコープ（今回）

- ja / en-US / ko・iPhone 6.9インチ（1320×2868）各8枚をアップロード対象とし、生成画像9枚 + コンタクトシート + slots.jsonを管理
- 生成番号は `01,02,03,04,05,06,08,09,10` を維持し、削除済み07を詰めない。生成ID05のstatsは画像・raw・撮影経路を保持するが、ホームと内容が重複するため不採用

## 出力

| 成果物 | パス |
|---|---|
| 生成画像9枚×3ロケール | `output/app-store-screenshots/v2/{ja,en-US,ko}/iphone-69/`（`01〜06,08〜10`。05-statsは不採用） |
| アップロード対象8枚×3ロケール | `output/app-store-screenshots/v2/upload-order/{ja,en-US,ko}/iphone-69/`（01〜08） |
| コンタクトシート | `output/app-store-screenshots/v2/contact-sheet-{ja,en-US,ko}.png`（8枚横並び・各幅400px、3200×869） |
| 画面差し替え座標 | `output/app-store-screenshots/v2/slots.json`（各枚のスクリーン四隅座標。傾きあり枚は回転後の4点） |
| スクリプト | `scripts/generate-appstore-screenshots-v2.py` |

## 共通トークン（旧 `scripts/generate-appstore-screenshots.py` と同一系）

- `background #0B0D0F` / raised `(18,20,23)` / lime `#C7F94D` / lime_deep `#9FD52F` / ink `#0A0C0E` / off-white `#F4F5F2` / muted `#7E8694` / ライム面上のサブ文字 `(45,58,29)`
- ライム面は必ず縦グラデ `#C7F94D → #9FD52F`
- フォント: 見出し=ヒラギノ角ゴ W8 / サブ=W4 / 英数=SFNS（旧スクリプトの `font()` を流用）
- デバイスモック: `.claude/specs/appstore-screenshot-design-patterns.md` §3 の `draw_device` 仕様（チタン筐体・Dynamic Island・画面アスペクト厳密1320:2868・ガウス影）
- キャラ: `ios/DopaBreak/Assets.xcassets/Character/{doom,blink,awake,worse,relief}.imageset/*.png`（1024²・透過済み）。合成時はドロップシャドウ（黒35%・blur40・オフセット(0,30)）、接地時は下端Yの直下へ楕円影（幅=キャラ幅×0.7・高さ90・黒30%・blur30）を地面色の上・キャラの背面に描く

## 画面ソース（2026-08-20 実画面キャプチャへ更新）

`ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` を指定のiPhone 16 Pro Max Simulatorで実行し、ダークモード・ja・シードデータ入りの実ウィンドウを `drawHierarchy` で撮る。保存先は `output/app-store-screenshots/raw-core/ja/`。該当する非オンボーディング・非設定ルートのモード画面は存在しないため、04は許可された `home.png` フォールバックを採用する。

| # | slug | ソース | 画面内キャラ | 外乗せ | 合計 |
|---|---|---|---:|---|---:|
| 1 | hook | `raw-core/ja/stats.png`（記録あり） | 0 | doom | 1 |
| 2 | pause | `raw-core/ja/breath.png`（一呼吸ステージ） | 1 | なし | 1 |
| 3 | intent-time | `raw-core/ja/intent.png`（理由6カード） | 0 | awake | 1 |
| 4 | modes | `raw-core/ja/home.png`（modes不在時フォールバック） | 1 | なし | 1 |
| 5 | goal-lockscreen | v2専用`mock_lock()`（iOSロック画面＋3目標Live Activity） | 0 | awake反転 | 1 |
| 6 | reflection-stats | `raw-core/ja/reflection.png`（1問目・満足度未選択・シート表示） | 1 | なし | 1 |

※ `PostUseReflectionSheet` は1問目の満足度未選択状態を撮る。選択肢は文字のみで、画面内キャラは先頭の1体だけ。背景は記録入りStatsViewで、シートを実際に提示したウィンドウ全体を保存する。

## コピー（旧版・2026-08-25 v3反映で上書き。履歴として保持）

| # | eyebrow | headline（2行） | sub |
|---|---|---|---|
| 1 | SNS時間を見える化 | 「あと5分だけ」が／1年で35日になる | 回答から無意識スクロールの時間を推計 |
| 2 | 禁止しないアプリ制限 | SNSをブロックしない／開く前にひと呼吸 | 反射で開く瞬間にだけ短いブレーキ |
| 3 | 理由と時間を選ぶ | 何のために開く？／必要な時間だけ使う | 目的を言葉にして5〜30分から選べます |
| 4 | 取り戻した時間 | 開くのをやめた分が／時間になって戻る | 今週の合計と1年ぶんの目安をホームに表示 |
| 5 | ロック画面・通知・ウィジェット | SNSを開くたびに／目標を確認 | ロック画面に目標と開くのをやめた回数を表示 |
| 6 | 振り返りと統計 | SNSのあと本音を記録／開くのをやめた回数も積み上がる | 満足感と開こうとした回数を見える化 |

コピーブロックは**中央揃え**。eyebrow=ピル（角丸=高さ/2・パディング横34縦16・文字40 W8）、headline=112px W8・行間26、sub=44px W4。自然幅が1240pxを超える行は横方向へリサイズせず、`floor(基準フォントサイズ × 1240 / 自然幅)` の実フォントサイズで再描画する。これにより字形の縦横比と光学中心を維持する。
全9枚でコピーブロックのY座標を eyebrow/headline/sub=`240/340/680` に統一する。headline第2行は`340 + 112 + 26 = 478`から始め、sub下端は約740px以内へ収める。
ライム面上: ピル=ink塗り+ライム文字 / 見出し=ink / sub=(45,58,29)。ダーク面上: ピル=(35,42,28)塗り+ライム文字 / 見出し=off-white / sub=muted。

## 9枚の構図（毎枚変える。座標はキャンバス1320×2868）

フォン幅は外形幅。直立は外形1396px（ベゼル38px・スクリーン1320px）が理論上限。±7°は外形1111px（スクリーン1049×2279px・回転後x範囲0.54〜1319.46）、±8°は外形1081px（スクリーン1021×2218px・回転後x範囲0.13〜1319.87）が整数丸め込み後の最大値。05だけ承認済みコールアウト保護のため従来値を維持する。05以外の外形上端は回転後を含めy=820に揃える。

### 01 hook — 参考プレート忠実（ライム大帯・キャラ大）
- ライム多角形 `(0,200)(1320,80)(1320,1080)(0,1420)`。上のダーク三角は残し、コピー全体をライム面へ収める
- コピー: ライム面中央 cx660 / 共通Y=`240/340/680`
- フォン: 幅1396・回転0°・中心(660,2292)・上端y820・スクリーン左右端x=0/1320・下端クロップ・画面=stats実画面
- キャラ: **doom** 幅440・回転-6°・中心x1030・下端y1330・**フォンの手前**（右上角に重なり、頭はライム/ダーク境界に掛かる）

### 02 pause — ダーク主体・細リボン・傾きフォン
- 背景ダークグラデ。ライムリボン `(0,1720)(1320,1400)(1320,1560)(0,1880)` を**フォンの背後**に
- コピー: ダーク面・共通Y=`240/340/680`
- フォン: 幅1111・回転-7°・中心(660,2049.47)・回転後外形上端y820・下端クロップ・画面=breath実画面
- キャラ: 画面内の呼吸キャラ1体のみ。外乗せは置かない

### 03 intent-time — ライム右下ウェッジ・フォン左寄せ+8°・キャラ右接地
- ライム多角形 `(0,2100)(1320,1520)(1320,2868)(0,2868)`
- コピー: ダーク面・共通Y=`240/340/680`
- フォン: 幅1081・回転+8°・中心(660,2023.14)・回転後外形上端y820・下端クロップ・画面=intent実画面
- キャラ: **awake** 幅400・中心x1080・下端y2350（ライム面に接地・楕円影）・フォン右縁に重なる・手前

### 04 modes — ライム上半分・最大フォン・home実画面フォールバック
- ライム多角形 `(0,0)(1320,0)(1320,1450)(0,1170)`
- コピー: ライム面・共通Y=`240/340/680`
- フォン: 幅1396・回転0°・中心(660,2292)・上端y820・スクリーン左右端x=0/1320・下端クロップ・画面=home実画面（`HomeView`にDeep Focus窓/モードカードが存在せず、非オンボ・非設定ルートのmodes UIもないため）
- キャラ: HomeView画面内のawake 1体のみ。外乗せworseは置かない

### 05 goal-lockscreen — iOSロック画面＋3目標Live Activity
- ダーク背景に**ライム正円** 中心(660,1800)・半径680（縦グラデ）
- コピー: ダーク面・共通Y=`240/340/680`
- フォン: **変更対象外**。幅1000・回転0°・中心(660,1883.5)・上端y830・下端はキャンバス外（Live Activityカードまでは完全表示。下部操作はクロップ可）・画面=v2専用`mock_lock()`。生成時も既存承認画像を再利用し上書きしない
- ロック画面: ブランド`#0B0D0F`系の暗い抽象グラデ壁紙。上中央に南京錠、右上に白いWi-Fi/バッテリー（左上は空欄）。「8月20日 木曜日」、SFNS semibold寄りで画面幅約55%の「9:41」を実フォント描画する。最下部は半透明ダーク円のフラッシュライト/カメラと白いホームインジケータ。
- Live Activity: `ios/WidgetsExtension/DopaBreakWidgets.swift` の `liveActivityView()` を正本にする。カードは背景`rgb(20,23,27)`、左端3ptの`rgb(184,255,61)`アクセントバー、左右14pt相当の幅、角丸。内側16pt・VStack 10ptで、10pt boldの「あなたの目標」、5pt間隔の3目標（各行=10×2ptアクセント棒＋15pt bold）、1px区切り線、14pt間隔の12pt semibold実績行（アクセント色「今日は12回 開くのをやめた」／secondary `rgb(139,146,158)`「開こうとした 15回」）を置く。AppIcon・`DOPABREAK`・右寄せカウント・行別区切りは置かない。
- Live Activity拡大コールアウト: フォン縮小後の表示を拡大せず、1320×2868の`mock_lock()`正本からカード`[42,1860,1278,2280]`（1236×420）を直接切り出し、LANCZOSで1180×401へ縮小してキャンバス`[70,1390,1250,1791]`へ中央配置する。角丸52px、`#C7F94D` 3px枠、黒45%・blur50・offset`(0,24)`の影を付ける。実カード表示`[218.04,2188.15,1101.96,2488.50]`には同色2px角丸枠を描き、丸角の可視枠へ隙間なく接する上辺接線点`[257,2188]`／`[1063,2188]`から、コールアウト下辺接線点`[122,1791]`／`[1198,1791]`へ同色2px・60%の直線を引く。描画順はフォン→awake→実枠/接続線→コールアウト影→コールアウト本体/枠。四隅・接線端点・倍率は`slots[0].callout`へ記録する。
- キャラ: **awake（左右反転）** 幅300・回転-12°・中心x230・下端y1050（フォン左上角に重なる）・手前

### 06 reflection-stats — 03の鏡像・フォン右-8°
- ライム多角形 `(0,1520)(1320,2100)(1320,2868)(0,2868)`
- コピー: ダーク面・共通Y=`240/340/680`
- フォン: 幅1081・回転-8°・中心(660,2023.14)・回転後外形上端y820・下端クロップ・画面=reflection実画面（1問目・満足度未選択のシート、選択肢は文字のみ）
- キャラ: シート先頭のdoom 1体のみ。外乗せreliefは置かない

## 実装メモ

- 旧 `scripts/generate-appstore-screenshots.py` からは `font/gradient` だけを流用する（モジュール名にハイフンがあるため `importlib.util.spec_from_file_location` で読む）。05の`mock_lock()`はv2側で生成し、それ以外のアプリ画面は `raw-core/ja/*.png` を直接読む。旧ファイル存在ガードはモジュールロード前の`load_legacy()`内で行う
- 傾きフォンは「直立で描画→RGBAでrotate(expand=True)→ペースト」。slots.json には回転後の画面四隅を記録
- キャラの回転も RGBA rotate(expand)。反転は transpose
- `slots.json` へ画面内・外乗せ・合計のキャラ数を記録し、合計1体以下を生成時に検証する。各`slots[0]`は`ground_shadow`を常設し、影がない枚は`null`とする
- 生成後、9枚すべて 1320×2868 RGB、スクリーン四隅のxが0〜1320、外乗せキャラのalpha bboxがキャンバス内であることを`if not: raise`で検証する（`python -O`でも無効化されない）

## 追加パネル 08〜10（2026-08-20 オーナー指示「機能が少ない。白黒やブロック時間の細かい設定は？」への対応）

当初Apple上限10枚に対し7→10枚へ拡張し、2026-08-25に07を削除して9枚とした。テーマ着せ替えは枠の都合で見送り（入れ替え候補として保留）。

### コピー（sales-copywritingフロー適用・認知段階④/市場成熟度3-4・機能はメカニズム=証拠として提示・読点/句点なし・薬機法回避で生理効果の断定なし）

| # | slug | eyebrow | headline（2行） | sub |
|---|---|---|---|---|
| 8 | deep-focus | 時間指定の完全ブロック | 集中したい時間だけ／選んだアプリを止める | いますぐ30分〜2時間 曜日と時間帯の予約も |
| 9 | night-block | 夜だけ強化 | 就寝中は自動で／完全ブロック | 夜ふかしスクロールを就寝・起床の時刻で断つ |
| 10 | ~~grayscale-guide~~ → grayscale-home | 白黒フィルタ連携 | 色を消して／SNSをつまらなくする | SNSを開くと自動で白黒に サイドボタン3回の手動切替も |

※10は2026-08-25オーナー指示で画面ソース・コピーを差し替え（白黒ホーム画面モック）。正本は `.claude/specs/appstore-screenshot-10-grayscale-home-2026-08-25.md`。en/koのパネル10コピーも同書が正本

※9の見出しはペイウォール確定コピー「就寝中は自動で完全ブロック」の2行分割（改変なし）

### 画面ソース（実画面・CoreScreensSnapshotCaptureへ追加）

| # | 画面 | シード |
|---|---|---|
| 8 | SettingsViewの「完全ブロック」セクションが最上部に来るスクロール位置 | Deep Focus対象あり・「いますぐ始める」30分/1時間/2時間/戻すまでの選択肢と「毎週の予定」（曜日・開始/終了）が見える状態 |
| 9 | SettingsViewのモード＋起床・就寝時刻セクション | 夜だけ強化を選択・起床7:00/就寝23:00 |
| 10 | ~~AutomationGuideView~~ → PILモック `mock_home_grayscale()`（SNSアイコンが並ぶiOSホーム画面を全面白黒化・2026-08-25差し替え） | — |

### 構図（バリエーション継続・トンマナ共通）

- **08**: 01の左右鏡像。ライム多角形 `(0,80)(1320,200)(1320,1420)(0,1080)`（ダーク三角は右上）。コピーはライム面 y240/340/680。フォン幅1396・0°・中心(660,2292)・上端820・下端クロップ。キャラ **blink** 幅440・回転+6°・中心x290・下端y1330でフォン左上角に重なる
- **09**: 02の鏡像系・夜の雰囲気。ダークグラデ背景＋ライムリボン `(0,1400)(1320,1720)(1320,1880)(0,1560)`（02と逆勾配）をフォン背後に。コピーはダーク面 y240/340/680。フォン幅1111・回転+7°・中心(660,2049.47)・回転後外形上端820・下端クロップ。キャラ **relief** 幅400・回転+7°・中心x1050・下端y1300でフォン右上角に腰掛ける
- **10**: ライム下半分（04の上下反転）`(0,1450)(1320,1170)(1320,2868)(0,2868)`。コピーはダーク面 y240/340/680。フォン幅1396・0°・中心(660,2292)・上端820・下端クロップ。キャラ **worse** 幅340・中心x220・下端y2500でフォン左縁に重なりライム面に接地

### コピー設計メモ
- 認知段階: ④商品自覚（ストアページ閲覧者）／市場成熟度: 3-4（ブロック系はコモディティ→時間指定・自動化・白黒連携というメカニズムの具体で差別化）
- ビッグアイデア: 「強さと時間を自分で設計できるブロッカー」
- 法令: 生理効果（ドーパミン減等）の断定なし。9はペイウォール審査済みコピーの分割流用

## en-US / ko 展開（2026-08-21 オーナー指示「en-us ko展開して進めて」）

### 方針
- 01〜04・06は旧セット（2026-08-01・ネイティブ監査済みv2/v2.1）のen/koコピーをそのまま流用（改変禁止）
- 05は日本語側の差し替え（「SNSを開くたびに／目標を確認」）に合わせて再transcreation
- 08〜10は新規transcreation。**翻訳ではなく訴求ごと再設計**
- 全新規コピーは humanizer-en / humanizer-ko の `scripts/audit.py` で **exit 0（全ゲート通過）を実測済み**（2026-08-21）
- koは韓国語の自然な語尾（해요体）で統一。쉼표0%・동일 종결어미 연속1

### en-US 確定コピー（05・08〜10）

| # | eyebrow | headline（2行） | sub |
|---|---|---|---|
| 5 | LOCK SCREEN GOALS | Your goals, every time／you reach for social media | Your goals and skipped opens sit on the lock screen |
| 8 | BLOCK ON YOUR SCHEDULE | Pick the hours you need to focus／and those apps stay shut | Start 30 minutes to 2 hours now, or set weekly time slots |
| 9 | STRONGER AT NIGHT | Your bedtime hours／block themselves | Late-night scrolling stops at the bedtime and wake times you set |
| 10 | GRAYSCALE SHORTCUT | Open social media／and your screen turns gray | Color returns when you close it. Just follow the guide. |

### ko 確定コピー（05・08〜10）

| # | eyebrow | headline（2行） | sub |
|---|---|---|---|
| 5 | 잠금 화면 목표 | SNS를 열 때마다／목표를 확인해요 | 잠금 화면에 목표와 열지 않은 횟수가 보여요 |
| 8 | 공부·업무 시간 완전 차단 | 집중할 시간만 골라서／앱을 멈춰요 | 지금 30분에서 2시간 요일과 시간대 예약도 돼요 |
| 9 | 밤에만 강하게 | 잠든 사이엔 자동으로／완전 차단 | 늦은 밤 스크롤을 취침 기상 시각으로 끊어요 |
| 10 | 흑백 필터 연동 | SNS를 열면／화면이 흑백이 돼요 | 닫으면 색이 돌아와요 안내대로 설정만 하면 끝 |

### 実装要件
- `CoreScreensSnapshotCapture` を en-US（`-testLanguage en -testRegion US`）と ko（`ko`/`KR`）でも実行し、`raw-core/en-US/` `raw-core/ko/` へ9枚ずつ出力
- 05の`mock_lock()`はロケール対応（日付書式・LA文言・目標3件をロケール別に）。目標3件のローカライズ: en=`Hold my own in English meetings` / `Keep up my morning run` / `Read for 30 minutes`、ko=`영어로 상담할 수 있는 나 되기` / `아침 러닝 계속하기` / `30분 독서하기`
- フォント: en/koの見出しは日本語のヒラギノでは字形が崩れるため、en=SFNS（bold/regular）、ko=AppleSDGothicNeo（Bold/Regular）を使う。`font(locale, size, bold)` をロケール分岐させる
- 構図・座標・キャラ配置・LA拡大コールアウトは ja と完全同一（コピーの行幅だけロケール差を吸収＝自然幅1240px超はフォントサイズ縮小方式）
- 出力: `output/app-store-screenshots/v2/{en-US,ko}/iphone-69/01〜06,08〜10`、`contact-sheet-en-US.png`、`contact-sheet-ko.png`、`slots.json`はロケール別に保存

## 2026-08-22 追記: en-US 検索意図監査によるコピー差し替え＋アップロード順

根拠: Apple Ads Insights API（`asc ads insights search-term-popularity`）の実測（英語6市場・8/9-15週）と、同日設定したen-US/en-GBキーワード（dopamine,detox,focus,phone,addiction,social,media,quit,habit,tracker,scrolling,brainrot,adhd,sleep|study）。humanizer-en audit.py 全ゲート通過（行単位監査・SD 2.58→2.84）。
旧スクリプト `scripts/generate-appstore-screenshots.py` の承認コピー（validate_legacy_copy_reuseの正本）にも同一変更を反映済み。

| # | 変更 | 変更前 → 変更後 |
|---|---|---|
| 01 | sub | Estimate lost scrolling time from your answers → Answer a few questions to see how much time your phone takes. |
| 03 | sub | pick 5–30 minutes → pick 5 to 30 minutes（humanizerのダッシュゲート対応） |
| 04 | eyebrow/headline/sub | THREE PAUSE STRENGTHS / Make screen time / fit your real life / Standard, Deep Focus, or stronger at night → A DETOX YOU CAN ACTUALLY KEEP / Dopamine detox, / one skipped open at a time / Every open you skip gets counted, so the number keeps climbing. |
| 06 | eyebrow | REFLECTIONS AND STATS → HABIT TRACKER AND CHECK-INS |
| 06 | sub | Track satisfaction, focus, attempts, and skipped opens → Track satisfaction, attempts, and skipped opens |
| 06 | sub | Track satisfaction, attempts, and skipped opens → Log how you felt, then see your attempts and skipped opens（振り返り1問化でfocusを外した後も3項目列挙が残っていたため非列挙形へ差し替え。humanizer-en `audit.py` 全ゲート通過・triads 2→1・SD 2.92→2.99）|

アップロード順（2026-08-25オーナー指示で更新）: 01 hook（旧01）→ 02 pause（旧02）→ 03 night（旧09）→ 04 deep-focus（旧08）→ 05 modes（旧04）→ 06 intent（旧03）→ 07 lockscreen（旧05）→ 08 reflection（旧06）→ 09 grayscale（旧10）。
ja / ko は同日オーナー承認後、下記のとおり反映。

### ja（検索意図監査・2026-08-22オーナー承認済み）

根拠: `.claude/specs/appstore-screenshots-search-intent-audit-2026-08-22.md` のApple Ads Insights API実測。日本語表示コピー規則（読点禁止・体言止め・中央揃え）確認済み。
旧スクリプト `scripts/generate-appstore-screenshots.py` は現在6枚構成で#08を持たないため、#08の変更はv2のみへ反映。

| # | 変更 | 変更前 → 変更後 |
|---|---|---|
| 06 | sub | 満足感・集中・開こうとした回数を見える化 → 満足感と開こうとした回数を見える化 |
| 08 | eyebrow | 時間指定の完全ブロック → 集中タイマーで完全ブロック |
| 08 | sub | いますぐ30分〜2時間 曜日と時間帯の予約も → 勉強や仕事の30分〜2時間 曜日と時間帯の予約も |

アップロード順（2026-08-25オーナー指示で更新）: 01 hook（旧01）→ 02 pause（旧02）→ 03 night-block（旧09）→ 04 deep-focus（旧08）→ 05 modes（旧04）→ 06 intent-time（旧03）→ 07 goal-lockscreen（旧05）→ 08 reflection-stats（旧06）→ 09 grayscale-home（旧10・白黒ホーム画面モック）。

### ko（検索意図監査・2026-08-22オーナー承認済み）

根拠: `.claude/specs/appstore-screenshots-search-intent-audit-2026-08-22.md` のApple Ads Insights API実測。humanizer-ko `audit.py` exit 0確認済み。
#01・#06は承認コピー正本 `scripts/generate-appstore-screenshots.py` とv2へ同時反映し、`validate_legacy_copy_reuse`対象として一致を維持。旧スクリプトは6枚構成で#08を持たないため、#08の変更はv2のみへ反映。

| # | 変更 | 変更前 → 変更後 |
|---|---|---|
| 01 | eyebrow | SNS 시간 셀프 체크 → 숏폼·SNS 시간 셀프 체크 |
| 06 | eyebrow | 사용 후 돌아보기와 통계 → 사용 후 돌아보기와 루틴 통계 |
| 06 | sub | 만족감·집중력·시도·열지 않은 횟수를 한눈에 봐요 → 만족감·시도·열지 않은 횟수를 한눈에 봐요 |
| 08 | eyebrow | 시간을 정하는 완전 차단 → 공부·업무 시간 완전 차단 |

アップロード順（2026-08-25オーナー指示で更新）: 01 hook（旧01）→ 02 pause（旧02）→ 03 night-block（旧09）→ 04 deep-focus（旧08）→ 05 modes（旧04）→ 06 intent-time（旧03）→ 07 goal-lockscreen（旧05）→ 08 reflection-stats（旧06）→ 09 grayscale-home（旧10・白黒ホーム画面モック）。

2026-08-22 オーナー指示「揃えて」: パネル01の年間換算を35日へ統一した旧案。2026-08-25の最終正本では、35日の損失フックを不採用とし、下記の一呼吸コピーへ上書きする。

## 2026-08-25 オーナー指示反映 — 8枚アップロード構成（生成9枚）

この節は上記のv2／検索意図監査時点の画面ソース表・コピー表・アップロード順・構図割当を上書きする。コピーの正本は `.claude/specs/appstore-screenshots-v3-proposal.md`、生成実装は `scripts/generate-appstore-screenshots-v2.py`。rawは再撮影せず、`raw-core/{locale}/` の現行ファイルを使う。生成画像は `01,02,03,04,05,06,08,09,10` の9枚を維持し、アップロード順は `breath, lockscreen, deepfocus, home, night, intent, reflection, grayscale-home` の8枚とする。生成ID05のstatsはホームと内容が重複するため不採用（オーナー指示 2026-08-25）であり、生成画像・raw・撮影経路は削除しないが、`UPLOAD_ORDER`、upload-order、contact-sheet、slotsから除外する。上位3枚＝差別化機能（一呼吸→ロック画面の目標→集中タイマー[勉強70/集中60]）。成果の数字（ホーム312時間）は4枚目。記録はホームと重複のため不採用（オーナー指示 2026-08-25）。

### 画面ソースと構図

構図は原則としてアップロード位置のバリエーションを再利用する。ただしロック画面は直立前提のLive Activity拡大と一体の専用構図へ戻し、旧03の傾き構図は理由選択へ移す。画面ソースと構図の対応は次表を正本とする。

| upload | 生成ID | raw／mock | 構図 | フォン | マスコット |
|---|---:|---|---|---|---|
| 1 breath | 01 | `raw-core/{locale}/breath.png`（残り秒が見えるようsourceを400px上へ） | 旧01 ライム大帯 | 1396px・0°・上端Y820 | 画面内1体。外乗せなし |
| 2 lockscreen | 03 | `mock_lock()`＋LA拡大 | ダーク＋ライム正円＋LA拡大 | 1204px・0°・上端Y800（スクリーン上端Y833） | 外乗せawake反転 300px・左上角・全身表示 |
| 3 deepfocus | 06 | `raw-core/{locale}/deepfocus.png` | 旧06 左下ウェッジ | 1081px・-8°・上端Y820 | なし |
| 4 home | 02 | `raw-core/{locale}/home.png`（改訂2ヒーロー・累計312時間／13日分。ヒーロー全体と「止めているアプリ」カードまで表示） | ライム上半分 | 1396px・0°・上端Y820 | 画面内awake 1体。外乗せなし |
| 5 night | 04 | `raw-core/{locale}/nightmode.png` | ダーク＋ライム右下ウェッジ | 1081px・+8°・上端Y820 | 外乗せawake 200px・中心X1220・下端Y1820・右ウェッジ接地・楕円影 |
| 6 intent | 08 | `raw-core/{locale}/intent.png` | ライム上半分 | 1396px・0°・上端Y800・下端クロップ | 外乗せawake 300px・中心X1120・下端Y1420・画面右上の無文字域・楕円影 |
| 7 reflection | 09 | `raw-core/{locale}/reflection.png` | ダークグラデ＋細いライムリボン（`[(0,770),(1320,810),(1320,890),(0,850)]`） | 1396px・0°・上端Y800・下端クロップ | 画面内1体。合計1体ガードのため外乗せなし |
| 8 grayscale | 10 | `mock_home_grayscale()` | 旧10 ライム下半分 | 1396px・0°・上端Y820 | 外乗せworse 340px |

### 不採用の生成ID05（stats）

statsの原寸raw内キャラ数は5で、`SCREEN_CHARACTER_COUNTS` とstats専用の可視領域ガードは保持する。生成ID05の画像・`raw-core/{locale}/stats.png`・撮影経路・構図コードは削除せず、再生成時も壊さない。ただしホームと内容が重複するため、statsはアップロード構成から不採用とする。したがって `UPLOAD_ORDER`、3ロケールの`upload-order/{locale}/iphone-69/`、contact-sheet、slotsの8件にはstatsを含めない。全パネルは引き続き `visible screen + external <= 1` を生成時に例外で検証する。

### 2026-08-25 オーナー構図修正 — ロック画面直立化

- アップロード2枚目はロック画面専用構図とし、ダーク背景上へライム正円（中心`(660,1830)`・半径`640`）、外形1204pxの直立フォン（0°・外形上端Y800・スクリーン`[91,833,1229,3306]`）、awake反転（幅300・中心X230・下端Y1060）を置く。1204pxは`mock_lock()`正本のLive Activity下端`y=2280/2868`がキャンバスY2800以内へ収まる最大整数外形幅で、実測下端はY2798.98。awakeのalpha bbox`[88,781,373,1060]`は全身をキャンバス内へ収め、フォン左上角へ重ねる。
- Live Activityは`mock_lock()`の原寸カード`[42,1860,1278,2280]`を切り出し、1180×401へLANCZOS縮小して`[70,1410,1250,1811]`へ置く。時計`9:41`の実描画枠`[347.91,1134.80,972.95,1365.02]`との下余白は44.98px、実カード上辺との余白は625.83px。実カード枠は`[127.21,2436.83,1192.79,2798.98]`、上辺接線は`[174,2436]`／`[1146,2436]`、接続先はコールアウト下辺接線`[122,1811]`／`[1198,1811]`。枠と線はライム2px、線opacity 60%。コールアウトは角丸52px、ライム3px枠、黒45%・blur50・offset`(0,24)`を維持する。
- アップロード5枚目nightは旧intentのダーク＋右下ウェッジへ移し、外形1081px・+8°・上端Y820とする。`nightmode.png`はraw y=0を維持して`7:00`／`23:00`を表示し、外乗せawakeは幅200・中心X1220・下端Y1820でフォン右側のライム面へ接地させる。
- アップロード6枚目intentは旧nightのライム上半分へ移し、外形1396px・0°・上端Y800・下端クロップとする。コピーはライム面配色、外乗せawakeは幅300・中心X1120・下端Y1420で画面右上の無文字域に置き、理由6カードとUI文字を隠さない。
- アップロード7枚目reflectionはダークグラデ背景に細いライムリボンをサブ直下からフォン背後へ通し、外形1396px・0°・上端Y800・下端クロップとする。raw内の1体だけを表示し、外乗せは置かない。
- アップロード順の構図は、1帯（0°）／2円（0°）／3左下ウェッジ（-8°）／4ライム上半分（0°）／5右下ウェッジ（+8°）／6ライム上半分（0°）／7リボン（0°）／8ライム下半分（0°）。4と6の反復は非隣接で、隣接する同一構図はない。

### v3コピー（改変禁止）

| upload | locale | eyebrow | headline（2行） | sub |
|---|---|---|---|---|
| 1 | ja | 禁止しないアプリ制限 | SNSをブロックしない／開く前にひと呼吸 | 反射で開く瞬間にだけ短いブレーキ |
| 1 | en-US | NOT ANOTHER APP BLOCKER | Don’t block social media／Pause before you open | A short break interrupts the reflex. You still choose. |
| 1 | ko | 차단이 아니라 브레이크 | SNS를 막지 않아요／열기 전에 숨 고르기 | 반사적으로 여는 순간에만 잠깐 브레이크를 걸어요 |
| 2 | ja | SNSに消えるはずだった時間 | 「溶けた時間」が／人生の時間に変わる | 積み上がった時間が何日分かまでホームに |
| 2 | en-US | DOPAMINE DETOX, COUNTED IN HOURS | Hours you would have lost to scrolling／are yours again | See how many days it adds up to, right on the home screen. |
| 2 | ko | SNS에 뺏기지 않은 시간 | 녹아 없어질 뻔한 시간이／내 인생의 시간으로 돌아와요 | 쌓인 시간이 며칠치인지까지 홈에서 봐요 |
| 3 | ja | ロック画面の目標 | SNSを開くたびに／目標を確認 | ロック画面に目標と開くのをやめた回数を表示 |
| 3 | en-US | LOCK SCREEN GOALS | Your goals, every time／you reach for social media | Your goals and skipped opens sit on the lock screen |
| 3 | ko | 잠금 화면 목표 | SNS를 열 때마다／목표를 확인해요 | 잠금 화면에 목표와 열지 않은 횟수가 보여요 |
| 4 | ja | 集中タイマーで完全ブロック | 集中したい時間だけ／選んだアプリを止める | 30分から解除するまで 曜日と時間帯の予約も |
| 4 | en-US | BLOCK ON YOUR SCHEDULE | Pick the hours you need to focus／and those apps stay shut | From 30 minutes to until you lift it, plus weekly time slots |
| 4 | ko | 공부·업무 시간 완전 차단 | 집중할 시간만 골라서／앱을 멈춰요 | 30분부터 해제할 때까지 요일과 시간대 예약도 돼요 |
| 5 | ja | 夜だけ強化 | 就寝中は自動で／完全ブロック | 夜ふかしスクロールを就寝・起床の時刻で断つ |
| 5 | en-US | STRONGER AT NIGHT | Your bedtime hours／block themselves | Late-night scrolling stops at the bedtime and wake times you set |
| 5 | ko | 밤에만 강하게 | 잠든 사이엔 자동으로／완전 차단 | 늦은 밤 스크롤을 취침 기상 시각으로 끊어요 |
| 6 | ja | 理由を選ぶ | 何のために開く？／理由を決めてから使う | 目的を言葉にして反射で開くのを止める |
| 6 | en-US | CHOOSE A REASON | Know why you're opening／then decide to use it | Put the purpose into words and the reflex loses its grip |
| 6 | ko | 이유 선택 | 왜 여는지 먼저 확인／이유를 정하고 써요 | 목적을 말로 정하면 무심코 여는 손이 멈춰요 |
| 7 | ja | 見たあとの本音 | SNSを見たあと／本音を一つ選ぶだけ | 5つの気持ちから選ぶ 次に開く前の材料になる |
| 7 | en-US | HONEST CHECK-IN | After you scroll／pick one honest feeling | Five moods to choose from. It shapes your next decision. |
| 7 | ko | 본 뒤의 솔직한 기분 | SNS를 본 뒤／솔직한 기분 하나만 골라요 | 다섯 가지 기분에서 하나를 고르면 다음에 열기 전 판단 재료가 돼요 |
| 8 | ja | 白黒フィルタ連携 | 色を消して／SNSをつまらなくする | SNSを開くと自動で白黒に サイドボタン3回の手動切替も |
| 8 | en-US | GRAYSCALE SHORTCUT | Strip the color／and social media gets boring | Goes gray the moment you open social media. Or triple-click the side button. |
| 8 | ko | 흑백 필터 연동 | 색을 없애면／SNS가 시시해져요 | SNS를 열면 자동으로 흑백 측면 버튼 세 번으로 직접 전환도 돼요 |

1枚目の旧「あと5分だけ」／「1年で35日になる」などの35日の損失フックは不採用。承認済みの一呼吸訴求は、ブロックではなく反射の入口に短いブレーキを置き、ユーザーが選べることを伝える。

### 成果物

- 生成元: `output/app-store-screenshots/v2/{ja,en-US,ko}/iphone-69/` の各9枚
- アップロード用: `output/app-store-screenshots/v2/upload-order/{ja,en-US,ko}/iphone-69/01〜08-*.png`
- 接触シート: `contact-sheet-{ja,en-US,ko}.png`（8枚・3200×869）
- 構図メタデータ: `slots-{ja,en-US,ko}.json`（アップロード対象8件。ja互換用に`slots.json`も同内容）
