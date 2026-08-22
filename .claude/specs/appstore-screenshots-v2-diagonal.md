# App Store スクリーンショット v2 — 対角ライム×脳キャラ（設計仕様）

作成: 2026-08-20 / 設計: Fable / 実装: Codex / 根拠: オーナー提示の参考プレート（design-patterns 10案のChatGPT生成物・対角ライム分割）
オーナー指示: ①この参考デザインをベースに ②脳キャラ（Dopa）を入れる ③見て楽しく、ベネフィット・機能がわかりやすく ④**モックの見せ方と背景構成は毎枚変える。大まかなトンマナ・配色は共通** ⑤モック内はコア体験の実画面を使い、**画面内＋外乗せのキャラは1枚につき合計1体まで**

## スコープ（今回）

- ja / iPhone 6.9インチ（1320×2868）7枚 + コンタクトシート + slots.json
- en-US / ko / 6.5" / iPad はオーナーのデザイン承認後に展開

## 出力

| 成果物 | パス |
|---|---|
| 7枚 | `output/app-store-screenshots/v2/ja/iphone-69/01-hook.png` 〜 `07-privacy-settings.png`（スラッグは旧版と同一） |
| コンタクトシート | `output/app-store-screenshots/v2/contact-sheet-ja.png`（7枚横並び・各幅400px） |
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
| 7 | privacy-settings | `raw-core/ja/goals.png`（目標3件設定済み） | 0 | relief | 1 |

※ `PostUseReflectionSheet` は1問目の満足度未選択状態を撮る。選択肢は文字のみで、画面内キャラは先頭の1体だけ。背景は記録入りStatsViewで、シートを実際に提示したウィンドウ全体を保存する。

## コピー（確定・改変禁止。読点規則適用済み＝旧版から「、」だけ除去）

| # | eyebrow | headline（2行） | sub |
|---|---|---|---|
| 1 | SNS時間を見える化 | 「あと5分だけ」が／1年で35日になる | 回答から無意識スクロールの時間を推計 |
| 2 | 禁止しないアプリ制限 | SNSをブロックしない／開く前にひと呼吸 | 反射で開く瞬間にだけ短いブレーキ |
| 3 | 理由と時間を選ぶ | 何のために開く？／必要な時間だけ使う | 目的を言葉にして5〜30分から選べます |
| 4 | 生活に合う3つの強さ | スクリーンタイム対策を／自分に合う強さで | 標準・Deep Focus・夜だけ強めから選択 |
| 5 | ロック画面・通知・ウィジェット | SNSを開くたびに／目標を確認 | ロック画面に目標と開かなかった回数を表示 |
| 6 | 振り返りと統計 | SNSのあと本音を記録／「開かなかった」も積み上がる | 満足感と開こうとした回数を見える化 |
| 7 | オンデバイスで安心 | 記録は端末の中だけ／無料で始められます | 対象アプリ・呼吸時間・通知をいつでも調整 |

コピーブロックは**中央揃え**。eyebrow=ピル（角丸=高さ/2・パディング横34縦16・文字40 W8）、headline=112px W8・行間26、sub=44px W4。自然幅が1240pxを超える行は横方向へリサイズせず、`floor(基準フォントサイズ × 1240 / 自然幅)` の実フォントサイズで再描画する。これにより字形の縦横比と光学中心を維持する。
全7枚でコピーブロックのY座標を eyebrow/headline/sub=`240/340/680` に統一する。headline第2行は`340 + 112 + 26 = 478`から始め、sub下端は約740px以内へ収める。
ライム面上: ピル=ink塗り+ライム文字 / 見出し=ink / sub=(45,58,29)。ダーク面上: ピル=(35,42,28)塗り+ライム文字 / 見出し=off-white / sub=muted。

## 7枚の構図（毎枚変える。座標はキャンバス1320×2868）

### 01 hook — 参考プレート忠実（ライム大帯・キャラ大）
- ライム多角形 `(0,200)(1320,80)(1320,1080)(0,1420)`。上のダーク三角は残し、コピー全体をライム面へ収める
- コピー: ライム面中央 cx660 / 共通Y=`240/340/680`
- フォン: 幅1060・回転0°・上端y1050・下端はキャンバス外（クロップ）・画面=stats実画面
- キャラ: **doom** 幅440・回転-6°・中心x1030・下端y1330・**フォンの手前**（右上角に重なり、頭はライム/ダーク境界に掛かる）

### 02 pause — ダーク主体・細リボン・傾きフォン
- 背景ダークグラデ。ライムリボン `(0,1720)(1320,1400)(1320,1560)(0,1880)` を**フォンの背後**に
- コピー: ダーク面・共通Y=`240/340/680`
- フォン: 幅1000・回転-7°・中心(660,2100)・下端クロップ・画面=breath実画面
- キャラ: 画面内の呼吸キャラ1体のみ。外乗せは置かない

### 03 intent-time — ライム右下ウェッジ・フォン左寄せ+8°・キャラ右接地
- ライム多角形 `(0,2100)(1320,1520)(1320,2868)(0,2868)`
- コピー: ダーク面・共通Y=`240/340/680`
- フォン: 幅980・回転+8°・中心(560,2050)・下端クロップ・画面=intent実画面
- キャラ: **awake** 幅400・中心x1080・下端y2350（ライム面に接地・楕円影）・フォン右縁に重なる・手前

### 04 modes — ライム上半分・最大フォン・home実画面フォールバック
- ライム多角形 `(0,0)(1320,0)(1320,1450)(0,1170)`
- コピー: ライム面・共通Y=`240/340/680`
- フォン: 幅1060（最大）・回転0°・上端y1000・下端クロップ・画面=home実画面（`HomeView`にDeep Focus窓/モードカードが存在せず、非オンボ・非設定ルートのmodes UIもないため）
- キャラ: HomeView画面内のawake 1体のみ。外乗せworseは置かない

### 05 goal-lockscreen — iOSロック画面＋3目標Live Activity
- ダーク背景に**ライム正円** 中心(660,1800)・半径680（縦グラデ）
- コピー: ダーク面・共通Y=`240/340/680`
- フォン: 幅1000・回転0°・上端y830・下端はキャンバス外（Live Activityカードまでは完全表示。下部操作はクロップ可）・画面=v2専用`mock_lock()`
- ロック画面: ブランド`#0B0D0F`系の暗い抽象グラデ壁紙。上中央に南京錠、右上に白いWi-Fi/バッテリー（左上は空欄）。「8月20日 木曜日」、SFNS semibold寄りで画面幅約55%の「9:41」を実フォント描画する。最下部は半透明ダーク円のフラッシュライト/カメラと白いホームインジケータ。
- Live Activity: `ios/WidgetsExtension/DopaBreakWidgets.swift` の `liveActivityView()` を正本にする。カードは背景`rgb(20,23,27)`、左端3ptの`rgb(184,255,61)`アクセントバー、左右14pt相当の幅、角丸。内側16pt・VStack 10ptで、10pt boldの「あなたの目標」、5pt間隔の3目標（各行=10×2ptアクセント棒＋15pt bold）、1px区切り線、14pt間隔の12pt semibold実績行（アクセント色「今日 開かなかった 12回」／secondary `rgb(139,146,158)`「開こうとした 15回」）を置く。AppIcon・`DOPABREAK`・右寄せカウント・行別区切りは置かない。
- Live Activity拡大コールアウト: フォン縮小後の表示を拡大せず、1320×2868の`mock_lock()`正本からカード`[42,1860,1278,2280]`（1236×420）を直接切り出し、LANCZOSで1180×401へ縮小してキャンバス`[70,1390,1250,1791]`へ中央配置する。角丸52px、`#C7F94D` 3px枠、黒45%・blur50・offset`(0,24)`の影を付ける。実カード表示`[218.04,2188.15,1101.96,2488.50]`には同色2px角丸枠を描き、丸角の可視枠へ隙間なく接する上辺接線点`[257,2188]`／`[1063,2188]`から、コールアウト下辺接線点`[122,1791]`／`[1198,1791]`へ同色2px・60%の直線を引く。描画順はフォン→awake→実枠/接続線→コールアウト影→コールアウト本体/枠。四隅・接線端点・倍率は`slots[0].callout`へ記録する。
- キャラ: **awake（左右反転）** 幅300・回転-12°・中心x230・下端y1050（フォン左上角に重なる）・手前

### 06 reflection-stats — 03の鏡像・フォン右-8°
- ライム多角形 `(0,1520)(1320,2100)(1320,2868)(0,2868)`
- コピー: ダーク面・共通Y=`240/340/680`
- フォン: 幅980・回転-8°・中心(760,2050)・下端クロップ・画面=reflection実画面（1問目・満足度未選択のシート、選択肢は文字のみ）
- キャラ: シート先頭のdoom 1体のみ。外乗せreliefは置かない

### 07 privacy-settings — 締め・唯一のフルフォン・接地バンド
- ライム接地バンド `(0,2320)(1320,2240)(1320,2868)(0,2868)`
- コピー: ダーク面・共通Y=`240/340/680`
- フォン: 幅780・回転0°・**全体表示**・下端y2620（バンドに沈めて接地感）・画面=goals実画面（「英語で商談できる自分になる」「朝のランニングを続ける」「読書を30分する」の3件設定済み）・下端直下に楕円影（幅=フォン幅×0.85・高さ110・黒35%・blur40）
- キャラ: **relief** 幅340・中心x1140・下端y2620（フォン右にライム接地・楕円影）

## 実装メモ

- 旧 `scripts/generate-appstore-screenshots.py` からは `font/gradient` だけを流用する（モジュール名にハイフンがあるため `importlib.util.spec_from_file_location` で読む）。05の`mock_lock()`はv2側で生成し、それ以外のアプリ画面は `raw-core/ja/*.png` を直接読む。旧ファイル存在ガードはモジュールロード前の`load_legacy()`内で行う
- 傾きフォンは「直立で描画→RGBAでrotate(expand=True)→ペースト」。slots.json には回転後の画面四隅を記録
- キャラの回転も RGBA rotate(expand)。反転は transpose
- `slots.json` へ画面内・外乗せ・合計のキャラ数を記録し、合計1体以下を生成時に検証する。各`slots[0]`は`ground_shadow`を常設し、影がない枚は`null`とする
- 生成後、7枚すべて 1320×2868 RGB であることを`if not: raise`で検証する（`python -O`でも無効化されない）

## 追加パネル 08〜10（2026-08-20 オーナー指示「機能が少ない。白黒やブロック時間の細かい設定は？」への対応）

Apple上限10枚に対し7→10枚へ拡張。テーマ着せ替えは枠の都合で見送り（入れ替え候補として保留）。

### コピー（sales-copywritingフロー適用・認知段階④/市場成熟度3-4・機能はメカニズム=証拠として提示・読点/句点なし・薬機法回避で生理効果の断定なし）

| # | slug | eyebrow | headline（2行） | sub |
|---|---|---|---|---|
| 8 | deep-focus | 時間指定の完全ブロック | 集中したい時間だけ／選んだアプリを止める | いますぐ30分〜2時間 曜日と時間帯の予約も |
| 9 | night-block | 夜だけ強化 | 就寝中は自動で／完全ブロック | 夜ふかしスクロールを就寝・起床の時刻で断つ |
| 10 | grayscale-guide | 白黒フィルタ連携 | SNSを開くと／画面が白黒になる | 閉じると色は戻る ガイドどおり設定するだけ |

※9の見出しはペイウォール確定コピー「就寝中は自動で完全ブロック」の2行分割（改変なし）

### 画面ソース（実画面・CoreScreensSnapshotCaptureへ追加）

| # | 画面 | シード |
|---|---|---|
| 8 | SettingsViewの「完全ブロック」セクションが最上部に来るスクロール位置 | Deep Focus対象あり・「いますぐ始める」30分/1時間/2時間/戻すまでの選択肢と「毎週の予定」（曜日・開始/終了）が見える状態 |
| 9 | SettingsViewのモード＋起床・就寝時刻セクション | 夜だけ強化を選択・起床7:00/就寝23:00 |
| 10 | AutomationGuideViewの「画面を白黒にする（任意）」セクション | ガイドのステップとオン/オフのモック表示が見える位置 |

### 構図（バリエーション継続・トンマナ共通）

- **08**: 01の左右鏡像。ライム多角形 `(0,80)(1320,200)(1320,1420)(0,1080)`（ダーク三角は右上）。コピーはライム面 y240/340/680。フォン幅1060・0°・上端1050・下端クロップ。キャラ **blink** 幅440・回転+6°・フォン左上角に重なる（中心x~290・下端y~1330）
- **09**: 02の鏡像系・夜の雰囲気。ダークグラデ背景＋ライムリボン `(0,1400)(1320,1720)(1320,1880)(0,1560)`（02と逆勾配）をフォン背後に。コピーはダーク面 y240/340/680。フォン幅1000・回転+7°・中心(660,2100)・下端クロップ。キャラ **relief** 幅400・回転+7°・フォン右上角に腰掛け（目を閉じた安眠顔＝夜訴求）
- **10**: ライム下半分（04の上下反転）`(0,1450)(1320,1170)(1320,2868)(0,2868)`。コピーはダーク面 y240/340/680。フォン幅1060・0°・上端1000・下端クロップ。キャラ **worse** 幅340・フォン左縁に重なりライム面に接地（中心x~220・下端y~2500・白黒でつまらない顔）

### コピー設計メモ
- 認知段階: ④商品自覚（ストアページ閲覧者）／市場成熟度: 3-4（ブロック系はコモディティ→時間指定・自動化・白黒連携というメカニズムの具体で差別化）
- ビッグアイデア: 「強さと時間を自分で設計できるブロッカー」
- 法令: 生理効果（ドーパミン減等）の断定なし。9はペイウォール審査済みコピーの分割流用

## en-US / ko 展開（2026-08-21 オーナー指示「en-us ko展開して進めて」）

### 方針
- 01〜04・06・07 は旧セット（2026-08-01・ネイティブ監査済みv2/v2.1）のen/koコピーをそのまま流用（改変禁止）
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
- 出力: `output/app-store-screenshots/v2/{en-US,ko}/iphone-69/01〜10`、`contact-sheet-en-US.png`、`contact-sheet-ko.png`、`slots.json`はロケール別に保存

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

アップロード順（`output/app-store-screenshots/v2/upload-order/en-US/iphone-69/`）: 01 hook → 02 pause → 03 night(旧09) → 04 dopamine-detox(旧04) → 05 deep-focus(旧08) → 06 intent(旧03) → 07 lockscreen(旧05) → 08 habit-tracker(旧06) → 09 privacy(旧07) → 10 grayscale(旧10)。
ja / ko は同日オーナー承認後、下記のとおり反映。

### ja（検索意図監査・2026-08-22オーナー承認済み）

根拠: `.claude/specs/appstore-screenshots-search-intent-audit-2026-08-22.md` のApple Ads Insights API実測。日本語表示コピー規則（読点禁止・体言止め・中央揃え）確認済み。
旧スクリプト `scripts/generate-appstore-screenshots.py` は7枚構成で#08を持たないため、#08の変更はv2のみへ反映。

| # | 変更 | 変更前 → 変更後 |
|---|---|---|
| 06 | sub | 満足感・集中・開こうとした回数を見える化 → 満足感と開こうとした回数を見える化 |
| 08 | eyebrow | 時間指定の完全ブロック → 集中タイマーで完全ブロック |
| 08 | sub | いますぐ30分〜2時間 曜日と時間帯の予約も → 勉強や仕事の30分〜2時間 曜日と時間帯の予約も |

アップロード順（`output/app-store-screenshots/v2/upload-order/ja/iphone-69/`）: 01 hook（旧01）→ 02 pause（旧02）→ 03 night-block（旧09）→ 04 deep-focus（旧08）→ 05 modes（旧04）→ 06 intent-time（旧03）→ 07 goal-lockscreen（旧05）→ 08 reflection-stats（旧06）→ 09 privacy-settings（旧07）→ 10 grayscale-guide（旧10）。

### ko（検索意図監査・2026-08-22オーナー承認済み）

根拠: `.claude/specs/appstore-screenshots-search-intent-audit-2026-08-22.md` のApple Ads Insights API実測。humanizer-ko `audit.py` exit 0確認済み。
#01・#06は承認コピー正本 `scripts/generate-appstore-screenshots.py` とv2へ同時反映し、`validate_legacy_copy_reuse`対象として一致を維持。旧スクリプトは7枚構成で#08を持たないため、#08の変更はv2のみへ反映。

| # | 変更 | 変更前 → 変更後 |
|---|---|---|
| 01 | eyebrow | SNS 시간 셀프 체크 → 숏폼·SNS 시간 셀프 체크 |
| 06 | eyebrow | 사용 후 돌아보기와 통계 → 사용 후 돌아보기와 루틴 통계 |
| 06 | sub | 만족감·집중력·시도·열지 않은 횟수를 한눈에 봐요 → 만족감·시도·열지 않은 횟수를 한눈에 봐요 |
| 08 | eyebrow | 시간을 정하는 완전 차단 → 공부·업무 시간 완전 차단 |

アップロード順（`output/app-store-screenshots/v2/upload-order/ko/iphone-69/`）: 01 hook（旧01）→ 02 pause（旧02）→ 03 night-block（旧09）→ 04 deep-focus（旧08）→ 05 modes（旧04）→ 06 intent-time（旧03）→ 07 goal-lockscreen（旧05）→ 08 reflection-stats（旧06）→ 09 privacy-settings（旧07）→ 10 grayscale-guide（旧10）。

2026-08-22 オーナー指示「揃えて」: パネル01の年間換算は `1日2.3時間 × 365日 ÷ 24 = 34.979…日` を四捨五入した35日とし、ja / en-US / ko・iphone-69 / iphone-65 / ipad-13の全組み合わせを35へ統一する。
