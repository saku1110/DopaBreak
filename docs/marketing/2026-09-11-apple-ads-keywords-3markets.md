# Apple Ads キーワード調査（英語圏・韓国・日本）— 2026-09-11

**結論: 3市場とも主力は「解決語」（スマホ制限／screen time／스크린타임・앱 잠금）で組む。「病名語」（スマホ依存／phone addiction／폰중독）は全市場で上位500圏外の低ボリュームだが意図が濃いので、低入札のexactで併走させる。競合の壁が最も低いのは韓国。**

2026-09-11。DopaBreak（App Store ID 6794221254）のApple Ads検索結果広告向けキーワード調査。Apple Ads Insights API（`asc ads insights search-term-popularity`）と公開App Store検索（`asc optimize keywords score`／iTunes Search API）の実測に基づく。配信・キャンペーン作成・支払いは行っていない。

## 0. 要点

- **英語圏**: 悩み語（screen time／app blocker／phone addiction／digital detox／doomscrolling）はUS/GB/CA/AUすべてで上位500圏外。圏内に入る関連語は指名語（brick 61・opal 59・forest 56）と機能語（focus 58＝Educationジャンル・habit tracker 58）で、悩み語は1語も無い。つまり英語圏の検索は「アプリ名」と「focus」に集まり、悩み語は1語あたりの量が小さい代わりに競合のタイトル一致が強い（Opal 8.8万・BePresent 6.3万・Unrot 5.7万・Brick 5.3万・ScreenZen 4.9万評価）。主力は screen time／app blocker 系のexactで、上限CPTを厳守する。ニッチは「stop scrolling／doomscrolling／block reels／block shorts」群で、競合が小規模かつ製品の機構（開く前に一呼吸）と一致する。
- **韓国**: 열품타 81（5/5）が示すとおり「勉強タイマー」が市場の中心。核は 스크린타임 53・앱 잠금 53・잠글시간 57（競合名）。競合の評価数が잠글시간 5.2千・터닝 3.6千・지키자 1.1千で、USの首位Opal 8.8万の1/17、JPの首位Blockin 1.9万の1/4。主力語の参入余地が3市場で最大。폰중독・디지털 디톡스・도파민は圏外だが競合が小さく、低入札exactで拾う価値がある。
- **日本**: 勉強 70／集中 60 が上位で、「集中」（13万評価の勉強記録アプリ）が検索面を占める。核は スマホ制限 58・スクリーンタイム 57・アプリ制限 52・アプリロック 51 で、自社タイトル語「スマホ制限」に実需がある。指名語は 集中旅行者 62・魚が育つ 56・focus flight 56・forest 56・opal 56・blockin 52。スマホ依存／デジタルデトックス／ドーパミンは圏外。
- **9/11媒体順序案への回答**: 「スマホ依存」「アプリブロック」「スクリーンタイム制限」は3語とも圏外（全15ジャンルの下限未満。JPの下限は最小47）。初回実験の主力は実測のある スマホ制限／スクリーンタイム／アプリ制限／アプリロック に置き、アプリブロック・スクリーンタイム制限は解決語の派生としてCP2-aに、スマホ依存は「依存・やめたい」のCP2-bに低入札exactで入れる（§5.3）。

## 1. 取得方法とデータの読み方

### 1.1 人気度（Apple Ads Insights）

- エンドポイント: `POST v1/insights/apps/search-term-popularity/query`（ad account 21218040）。
- 期間: 週 2026-08-30〜09-05（WEEKLY_SUN_SAT）を主、月 2026-08（MONTHLY）を安定性の照合に使用。両期間で順位はほぼ同じで、月の値は週より平均3.5〜4.6ポイント高く出る（語ごとの差は−17〜+21）。
- 対象: US・GB・CA・AU・NZ・IE・SG・KR・JP の9ストアフロント。データセットは国×15ジャンルの上位500語のみ（週: US 7,500語／GB 5,867／CA 4,032／AU 3,298／NZ 478／IE 565／SG 1,513／KR 4,370／JP 6,306）。
- 指標: `searchPopularity1to100`（1〜100の相対指数。各国の最上位語が100で、USはinstagram、JP・KRはx。tiktok/インスタ 96・인스타그램 98はその次）。表の5段階列はAppleが同じ行で返す `searchPopularity1to5`（週次）をそのまま載せた。指数との対応は実測で **42〜60＝3、60〜80＝4、80〜100＝5**（9市場33,929行から導出）。
- 表のジャンル列は、週次値が最大だった市場でAppleが返したジャンル（英語圏で市場により異なる語は、備考で補足）。
- **「圏外」の意味**: どのジャンルの上位500にも無い語。人気度がそのジャンルの500位（下限）未満というだけで、ゼロではない。下限は US Productivity 56／Health 48、GB Productivity 51、KR Productivity 52／Health 50、JP Productivity 55／Health 47。圏外語の実ボリュームはAPIでは測れず、配信後の検索語レポートでしか分からない。
- Appleのアプリ別キーワード提案（`asc ads suggestions keywords find`）は0件（9/6と同じ）。2026-09-12にストアフロント指定（`countriesOrRegions IN [JP]`／US／KR）でも再試行したが3市場とも0件（応答は `queries/suggestions-keywords-response-<国>.json`）。phrases／categoriesの提案はAppleが500を返す。公開中の1.0でも返らないため、提案APIは今回の根拠に使えない。

### 1.2 競合（公開App Store検索）

- 各候補語で公開検索の上位を取得し、上位3アプリの名前とストアフロント別の評価数を併記した（`asc optimize keywords score` の生シグナル、および iTunes Search API）。評価数は市場ごとに異なる（例: Opal はUS 87,603／GB 14,333／JP 2,818／KR 629）。
- 読み方: 上位に数万評価のタイトル一致アプリが並ぶ語は、CPTが高く1位表示の獲得が難しい。上位が小規模アプリだけの語は安く、意図が製品と一致していればCVRが高いと見込める。上位が別カテゴリ（ゲーム・プライバシー用ロック・フォロワー追跡・ショートドラマ）の語は意図不一致として除外する。
- 英語圏の表はUSの取得値（140語すべて取得済み）を載せた。GB/CA/AUの競合はUSと同じアプリが上位に来るが評価数は市場ごとに異なる（例: Opal はGB 14,333）。JP 83語・KR 86語も全語取得済み。取得は2026-09-11〜12の2回に分かれ、公開検索APIのレート制限（HTTP 403）で1時間以上止まった後に6秒間隔で再取得した。

### 1.3 判定の定義

| 判定 | 意味 | 一致方式 |
|---|---|---|
| 主力 | 実需または意図が最も濃く、キャンペーンの中心にする語 | exact |
| ニッチ高CVR | 圏外だが意図が濃く、競合が小規模。低入札で常時ONにする語 | exact |
| 競合指名 | 他社アプリ名。別キャンペーンで単独採算を見る | exact |
| 様子見 | 意図が混在、またはボリュームが極小。低入札テストかSearch Matchに任せる | exact/broad |
| 除外 | 意図不一致。ネガティブキーワードに登録する | — |
| 観測のみ | ボリュームの参考。出稿しない | — |

## 2. 英語圏（US・GB・CA・AU・NZ・IE・SG）

USを基準に、GB以下はUSのキーワード群を流用する。市場ごとの違いは次のとおり。

- **GB**: 学生タイマー市場が濃い（study bunny 66・flora 55・focustown 54・study 54・revision 50）。試験期に膨らむが、勉強アプリ意図なので主力にしない。forest 60 は Forest bike（自転車シェア）が混在。
- **CA**: screenzen 51 がUS/GBでは圏外なのにCAでは実測に入る。opal 56・forest 53・brick 53もCAで実測あり。freedom 52 は同じCA表に freedom mobile 62 があるため通信会社の検索が混じる可能性が高い（推定）。
- **AU**: opal 62 は同じAU表に opal travel 62・opal card 51 があるため交通ICの検索が混じる可能性が高い（推定）。除外語で分離する。
- **NZ・IE・SG**: 上位500に入る語自体が少なく（478／565／1,513語）、関連語はほぼ返らない。USの語をそのまま使い、入札はUSより低く始める。IEは studyclix 62・simple study 58・studytok 57 と試験対策語が目立つ。

### 実測ボリュームあり（上位500圏内）

| キーワード | US週 | GB週 | CA週 | AU週 | NZ週 | IE週 | SG週 | US月 | GB月 | 5段階（週・Apple実測） | ジャンル | 判定 | 競合上位（ストア評価数） | 備考 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| study bunny | - | 66 | - | - | - | - | - | - | 63 | 4(GB) | Productivity Utilities | 競合指名 | GB値: Study Bunny(14,134) / Daily Study Planner & (45) / Flora(84,463) | GB実測66・学生タイマー→低入札 |
| focus | 58 | 53 | 49 | - | - | - | - | 65 | - | 3(US) | Education | 様子見 | Firefox Focus(82,260) / BPS Focus(315) / Focus(4,982) | US実測58はEducationジャンル。US/GBとも検索上位はFirefox Focus/Focos/Flora＝ブラウザ・カメラ・勉強タイマーで意図が割れる。主力に混ぜず単独広告グループで低入札テスト |
| calm | 62 | 59 | 57 | 55 | - | - | - | 65 | 62 | 4(US) | Health Fitness | 除外 |  | 瞑想 |
| forest | 56 | 60 | 53 | 52 | - | - | - | - | 64 | 4(GB) | Travel | 競合指名 | Forest(49,278) / Forest(818) / Flora(82,594) | US/CA/AUで実測。GBはForest bike混在 |
| brick | 61 | 56 | 53 | 53 | - | - | - | 64 | 60 | 4(US) | Productivity Utilities | 競合指名 | Brick(53,406) / Block Blast！(2,700,143) / Huge Bricks(3,544) | US実測61＝指名語で最大。ゲーム（Block Blast/Bricks）は除外語で防ぐ |
| journal | 61 | 57 | 57 | 54 | - | - | - | 64 | 61 | 4(US) | Productivity Utilities | 除外 |  | 日記 |
| opal | 59 | 59 | 56 | 62 | - | - | - | 63 | 62 | 4(AU) | Productivity Utilities | 競合指名 | Opal(87,634) / Opal Travel(469) / ScreenZen(49,330) | US/GB/CA/AUで実測（最大の指名語）。AUはOpal card/travelを除外 |
| studyclix | - | - | - | - | - | 62 | - | - | - | 4(IE) | Education | 除外 |  | IE試験コンテンツ |
| habit tracker | 58 | 56 | 55 | 53 | - | - | - | 61 | 59 | 3(US) | Productivity Utilities | 除外 | Habit Tracker(146,594) / Habit Tracker(2,410) / Finch(750,148) | Habit Tracker/Finch＝別カテゴリ |
| insight timer | 57 | 52 | 52 | 53 | - | - | - | 61 | 57 | 3(US) | Health Fitness | 除外 |  | 瞑想 |
| study fetch | 59 | - | 51 | - | - | - | - | 60 | - | 3(US) | Education | 除外 |  | AI学習 |
| app lock | - | 52 | - | 50 | - | - | 58 | - | 56 | 3(SG) | Productivity Utilities | 除外 | App Lock(25,347) / AppLock(411) / App Lock(6,645) | プライバシー用アプリロック（意図不一致） |
| flora | - | 55 | - | - | - | 58 | - | - | 56 | 3(IE) | Productivity Utilities | 競合指名 | Flora(82,594) / FLORA(43) / Flora(2,567) | GB/IE実測 |
| space | - | 50 | 47 | 47 | - | - | - | - | 58 | 3(GB) | New Publication | 除外 | SkyView® Lite(18,773) / Spaceflight Simulator(97,584) / Solar System Sim(4,108) | 汎用 |
| focustown | - | 54 | - | - | - | - | - | - | 58 | 3(GB) | Productivity Utilities | 競合指名 | GB値: Focustown(1,744) / FocusFlight(3,207) / Focus Friend, by Hank (499) | GB実測 |
| simple study | - | - | - | - | - | 58 | - | - | - | 3(IE) | Education | 除外 |  | 同上 |
| studytok | - | - | - | - | - | 57 | - | - | - | 3(IE) | Education | 除外 |  | 同上 |
| structured | 56 | 53 | 53 | 49 | - | - | - | - | 56 | 3(US) | Productivity Utilities | 除外 | Structured(165,665) / Habit Tracker(146,631) / TickTick:To-Do List & (45,660) | プランナー |
| study | - | 54 | 50 | 50 | - | - | - | - | - | 3(GB) | Productivity Utilities | 様子見 | Quizlet(1,113,388) / Study Bunny(21,387) / Gizmo(13,774) | GB/CA/AUで実測。試験期に膨らむが勉強アプリ意図 |
| quittr | - | - | - | - | - | - | - | 53 | - | -（月のみ） | Health Fitness | 除外 | QUITTR(33,460) / Unchaind(38,728) / Days Since(19,112) | 別カテゴリ（依存克服・成人向け） |
| streaks | - | 45 | - | - | - | - | - | 53 | 50 | 3(GB) | Health Fitness | 除外 |  | 習慣 |
| freedom | - | - | 52 | - | - | - | - | - | - | 3(CA) | Productivity Utilities | 競合指名 | Freedom(5,842) / Freedom SuperApp(474) / Freedom Banker(61) | CAはFreedom Mobile混在 |
| screenzen | - | - | 51 | - | - | - | - | - | - | 3(CA) | Productivity Utilities | 競合指名 | ScreenZen(49,330) / Opal(87,634) / one sec(23,512) | CA実測51 |
| revision | - | 50 | - | - | - | - | - | - | 49 | 3(GB) | Education | 除外 | GB値: GCSE Quiz Revision(14) / Gizmo(12,796) / Quizlet(112,952) | 英国の試験対策コンテンツ |
| mindfulness | - | 44 | - | - | - | - | - | - | 49 | 3(GB) | Health Fitness | 除外 | Headspace(973,854) / The Mindfulness App(7,564) / Mindfulness Coach(11,125) | 瞑想アプリ |
| lock in | - | - | - | - | - | - | - | - | 49 | -（月のみ） | Health Fitness | ニッチ高CVR | Lock In(26,670) / Locked In(110) / Opal(87,634) | 若年スラング「集中する」。Lock In - Reset Your Life（US 2.7万評価）が上位で需要は大きい |

### 圏外（上位500に無い＝人気度がジャンル下限未満・意図で選ぶ）

| キーワード | 判定 | 競合上位（ストア評価数） | 備考 |
|---|---|---|---|
| screen time | 主力 | Opal(87,603) / ScreenZen(49,284) / BePresent(62,732) | 最重要・最高競合。Opal/ScreenZen/BePresent/Unrot/one secがタイトル一致。上限CPT厳守 |
| screen time app | 主力 | Opal(87,634) / ScreenZen(49,330) / BePresent(62,818) | screen timeの派生 |
| screen time control | 主力 | Opal(87,603) / ScreenZen(49,284) / BePresent(62,732) | 競合3社のタイトル語。CPT高め |
| screen time tracker | 主力 | Screen Time Tracker(115) / Opal(87,634) / Jolt(101) | 記録機能で受ける |
| reduce screen time | 主力 | Opal(87,634) / ScreenZen(49,330) / BePresent(62,818) | ClearSpaceのタイトル語 |
| limit screen time | 主力 | Limit(240) / Opal(87,603) / ScreenZen(49,284) | 競合弱め（Limit/Unglue） |
| screen time limit | 主力 | Opal(87,634) / ScreenZen(49,330) / BePresent(62,818) | 派生 |
| app blocker | 主力 | Opal(87,554) / ScreenZen(49,244) / Refocus(11,232) | Opal/ScreenZen/Refocus/AppBlock/Brick。第2の主力 |
| app blocker for iphone | 主力 | Opal(87,603) / Refocus(11,239) / ScreenZen(49,284) | 派生 |
| block apps | 主力 | Refocus(11,243) / Brick(53,487) / ScreenZen(49,330) | 派生 |
| app limit | 主力 | ScreenZen(49,284) / Opal(87,603) / Refocus(11,239) | 派生 |
| app limits | 主力 | one sec(23,508) / Opal(87,603) / ScreenZen(49,284) | 派生 |
| block social media | 主力 | Opal(87,634) / ScreenZen(49,330) / Refocus(11,243) | サブタイトル語と一致 |
| social media blocker | 主力 | Opal(87,634) / ScreenZen(49,330) / SocialLite-Block Reels(6,931) | 上位はOpal/ScreenZen。Barrier/SocialLiteは小規模 |
| screen time blocker | 主力 | Opal(87,634) / ScreenZen(49,330) / Refocus(11,243) | 派生 |
| limit apps | 主力 | ScreenZen(49,330) / Refocus(11,243) / Opal(87,634) | 派生 |
| block youtube | ニッチ高CVR | UnTrap for YouTube(492) / Refocus(11,239) / #blockit(166) | USの上位はUnTrap/Refocus/#blockit＝小規模＋競合。YouTube本体は上位に無い |
| block reels | ニッチ高CVR | SocialLite-Block Reels(6,895) / ScrollGuard(91) / Stillfeed(0) | SocialLite以外は小規模→勝ちやすい |
| block shorts | ニッチ高CVR | SocialLite-Block Reels(6,931) / WallHabit Block Shorts(32) / Shorts Blocker for You(132) | 同上 |
| stop scrolling | ニッチ高CVR | one sec(23,512) / ScreenZen(49,330) / DoomSafe(3) | 製品の機構（開く前に一呼吸）そのもの。競合小 |
| stop doomscrolling | ニッチ高CVR | SocialLite-Block Reels(6,895) / one sec(23,508) / No Scroll(683) | 同上 |
| doomscrolling | ニッチ高CVR | BibleSwipe(49) / one sec(23,512) / Deepstash(67,756) | 同上 |
| doom scrolling | ニッチ高CVR | one sec(23,512) / BibleLock(0) / Imprint(54,741) | 同上 |
| phone addiction | ニッチ高CVR | Opal(87,603) / BePresent(62,732) / Dumb Phone (dp)(3,714) | Opal/BePresent/Dumb Phone。意図は最濃 |
| phone addiction app | ニッチ高CVR | BePresent(62,732) / Opal(87,603) / Dumb Phone (dp)(3,714) | 同上 |
| digital detox | ニッチ高CVR | Detox(452) / Digital Detox ADHD App(29) / Opal(87,603) | タイトル一致は小規模アプリのみ |
| dopamine detox | ニッチ高CVR | Rewire(21) / Dumb Phone (dp)(3,717) / one sec(23,512) | one sec以外は小規模。ブランド名と親和 |
| brain rot | ニッチ高CVR | Brainrot(21,737) / Steal a Brainrot Game(49) / Merge Fellas(1,208) | 上位はBrainrot: Screen Time Control（競合）。他は極小のゲーム/サウンドボード。若年スラング |
| distraction blocker | ニッチ高CVR | Opal(87,634) / Focus Friend, by Hank (6,615) / Blank Spaces Launcher(8,283) | 競合小 |
| digital wellbeing | ニッチ高CVR | detoxi(0) / Screen Time Control(157) / Opal(87,634) | Android由来の語。USの上位はdetoxi/Screen Time Control（小規模）とOpal |
| phone usage | ニッチ高CVR | Opal(87,634) / ScreenZen(49,330) / ClearSpace(8,847) | USの上位はOpal/ScreenZen/ClearSpace（GBはBePresent/Roots/RealizD）。記録機能で受ける |
| phone usage tracker | ニッチ高CVR | BePresent(62,818) / RealizD(515) / Usage Log(8) | 同上 |
| quit tiktok | ニッチ高CVR | TikSave(37,402) / TikTok(18,358,395) / TrendTok Analytics & T(65,918) | 極小・意図最濃 |
| quit instagram | ニッチ高CVR | FollowMeter for Instag(23,931) / InSaver(5,725) / Followers Track & Like(54,733) | 極小・意図最濃 |
| phone detox | ニッチ高CVR | Opal(87,634) / BePresent(62,818) / Dumb Phone (dp)(3,717) | 極小 |
| social media detox | ニッチ高CVR | Opal(87,634) / ScreenZen(49,330) / one sec(23,512) | 競合小 |
| social media addiction | ニッチ高CVR | one sec(23,512) / ScreenZen(49,330) / Unscroll(5) | 極小 |
| tiktok addiction | ニッチ高CVR | OpenTik(4) / Scoopz(60,824) / Zigazoo(57,234) | 極小 |
| instagram addiction | ニッチ高CVR | InSaver(5,725) / FollowMeter for Instag(23,931) / Followers Track & Like(54,733) | 極小 |
| scroll less | ニッチ高CVR | Scroll Less Block Reel(21) / ClearSpace(8,847) / ScrollLess(0) | 同上・極小 |
| no scroll | ニッチ高CVR | No Scroll(683) / SocialLite-Block Reels(6,931) / one sec(23,512) | 同上・極小 |
| doom scroll | ニッチ高CVR | Scroll The Bible(13,731) / one sec(23,512) / No Scroll(683) | doomscrollingの派生 |
| reels blocker | ニッチ高CVR | SocialLite-Block Reels(6,931) / ScrollGuard(92) / UNDOOMED(101) | 同上 |
| shorts blocker | ニッチ高CVR | SocialLite-Block Reels(6,931) / WallHabit Block Shorts(32) / Shorts Blocker for You(132) | 同上 |
| youtube shorts blocker | ニッチ高CVR | ShortformBlock(10) / SocialLite-Block Reels(6,931) / ShortVidsBlocker(2) | 同上 |
| instagram blocker | ニッチ高CVR | SocialLite-Block Reels(6,931) / Opal(87,634) / ScreenZen(49,330) | 派生 |
| tiktok blocker | ニッチ高CVR | Refocus(11,243) / TikTok(18,358,395) / BlockerX:Adult Content(8,315) | 派生 |
| social media limit | ニッチ高CVR | Opal(87,634) / ScreenZen(49,330) / Social Media Blocker(3) | 派生 |
| dumb phone | 競合指名 | Dumb Phone (dp)(3,717) / Blank Spaces Launcher(8,283) / Minimalist Launcher(3,511) | Dumb Phone (dp)＝競合 |
| focus plant | 競合指名 | Focus Plant：forest app(5,421) / Forest(49,278) / Flora(82,594) | 圏外 |
| one sec | 競合指名 | one sec(23,512) / ScreenZen(49,330) / Opal(87,634) | 圏外 |
| jomo | 競合指名 | Jomo(2,387) / ScreenZen(49,330) / one sec(23,512) | 圏外 |
| clearspace | 競合指名 | ClearSpace(8,847) / Cleanup(714,840) / ScreenZen(49,330) | 圏外 |
| refocus | 競合指名 | Refocus(11,243) / Opal(87,634) / ScreenZen(49,330) | 圏外 |
| roots | 競合指名 | Roots Natural Kitchen (3,970) / Roots(2,606) / Root(73,302) | 圏外 |
| unpluq | 競合指名 | Unpluq(921) / Unpluq Family(7) / one sec(23,512) | 圏外 |
| blocksite | 競合指名 | BlockSite(6,176) / Refocus(11,243) / BlockerX:Adult Content(8,315) | 圏外 |
| appblock | 競合指名 | AppBlock(6,617) / Opal(87,634) / Refocus(11,243) | 圏外 |
| stayfree | 競合指名 | StayFree(112) / ScreenZen(49,330) / StayFree(195) | 圏外 |
| bepresent | 競合指名 | BePresent(62,818) / Opal(87,634) / ScreenZen(49,330) | 圏外 |
| be present | 競合指名 | BePresent(62,818) / Opal(87,634) / ScreenZen(49,330) | 同上 |
| unrot | 競合指名 | Unrot(56,788) / Unglue(2,673) / Brainrot(21,737) | US 5.7万評価の新興競合 |
| brainrot | 競合指名 | Brainrot(21,737) / Steal a Brainrot Game(49) / Merge Fellas(1,208) | Brainrot: Screen Time Control（競合） |
| unglue | 競合指名 | Unglue(2,673) / Blocus(226) / ScreenZen(49,330) | 圏外 |
| sociallite | 競合指名 | SocialLite-Block Reels(6,931) / Instagram(29,471,826) / Friendly Social Browse(84,311) | Reels/Shortsブロッカー |
| focus friend | 競合指名 | Focus Friend, by Hank (6,615) / Forest(49,278) / Study Bunny(21,387) | Hank Greenの集中アプリ |
| focus traveller | 競合指名 | Focus Traveller(3,954) / Study Bunny(21,387) / Flora(82,594) | フロータイマー |
| barrier | 競合指名 | Barrier(317) / Barrier(3) / Barrier(2) | 小規模 |
| realizd | 競合指名 | RealizD(515) / ScreenZen(49,330) / one sec(23,512) | 小規模 |
| unscreen | 競合指名 | Unscreen • Control dai(83) / Unscreen(8) / Video Background Erase(5,415) | 小規模 |
| forest app | 競合指名 | Forest(49,278) / Forest(818) / Flora(82,594) | 派生 |
| block tiktok | 様子見 | Slowth(1) / TikTok(18,358,395) / Refocus(11,243) | 結果はTikTok本体・Block Blast等。CVR低い見込み |
| block instagram | 様子見 | AppBlock(6,617) / FollowMeter for Instag(23,931) / Reports+ Unfollowers F(489,923) | USの上位はAppBlockとフォロワー追跡系（FollowMeter/Reports+）＝意図が割れる。低入札 |
| dopamine | 様子見 | Lock Screen 26(1,439) / Dopamine(0) / Update My Phone & Apps(1,360) | USの上位に制限系が無く意図が読めない（Lock Screen 26/Dopamine/Update My Phone）。ブランド名との親和だけで低入札テスト |
| focus app | 様子見 | Forest(49,271) / Opal(87,603) / Focus Traveller(3,953) | タイマー系が上位 |
| focus mode | 様子見 | Focus Friend, by Hank (6,615) / FlipMode(0) / Opal(87,634) | iOS機能名と混在 |
| stay focused | 様子見 | Stay Focused App/Site (922) / Opal(87,603) / Forest(49,271) | Stay Focusedブロッカー＋Opal |
| focus timer | 様子見 | Focus Keeper(31,598) / Focus Friend, by Hank (6,571) / Focus timer(1,851) | Focus Keeper等タイマー専用 |
| study focus | 様子見 | Focus Friend, by Hank (6,615) / Flora(82,594) / Study Bunny(21,387) | Flora/Study Bunny |
| study timer | 様子見 | Focus Friend, by Hank (6,615) / Flora(82,594) / Focus timer(1,851) | タイマー専用が上位 |
| study mode | 様子見 | Flow(1,746) / Focus Plant：forest app(5,420) / Focus To-Do(14,593) | 同上 |
| pomodoro | 様子見 | Focus Keeper(31,599) / FocusPomo · Pomodoro T(7,647) / Forest(49,278) | タイマー専用 |
| self control | 様子見 | Opal(87,603) / QUITTR(33,458) / Refocus(11,239) | QUITTR（別カテゴリ）が混在 |
| self control app | 様子見 | Opal(87,634) / QUITTR(33,460) / Refocus(11,243) | 同上 |
| willpower | 様子見 | WILLPOWER(0) / WillPower Books(26) / WillPower(51) | 極小 |
| procrastination | 様子見 | Flora(82,594) / Structured(165,665) / FocusMaxing(0) | Flora/Structured＝計画系 |
| mindful | 様子見 | Headspace(973,854) / Mindful Magazine & Cou(44) / Insight Timer(446,161) | タイトル語だが検索はHeadspace系 |
| intentional phone | 様子見 | Blank Spaces Launcher(8,283) / Simple Phone(40) / Corporate Phone(5,970) | 極小 |
| offscreen | 様子見 | OffScreen(2,536) / Opal(87,634) / ScreenZen(49,330) | 極小 |
| phone lock | 様子見 | Opal(87,603) / Focus Plant：forest app(5,420) / App Lock(25,343) | Opal/Focus Plantとプライバシー系ロックが混在 |
| lock apps | 様子見 | App Lock(25,347) / AppLock(411) / App Lock(6,645) | 同上 |
| lock phone | 様子見 | Opal(87,634) / App Lock(3) / App Lock(25,347) | 同上 |
| bedtime | 様子見 | Sleep Cycle Bedtime Ca(291) / Bedtime Fan(201,529) / Bedtime(388) | 汎用 |
| less phone | 様子見 | Minimalist Launcher(61) / ClearSpace(8,847) / Dumb Phone Mode(0) | 極小 |
| unplug | 様子見 | Unplug(6,270) / Unpluq(921) / Unplug App(9) | 極小 |
| minimalist phone | 様子見 | minimalist phone ® Blo(499) / Blank Spaces Launcher(8,283) / Minimalist Launcher(3,511) | 極小 |
| monk mode | 様子見 | Monk Mode(13) / Monk Mode(6) / Vigil(0) | 極小・スラング |
| deep work | 様子見 | Emphasis(1,060) / Deep Work(1) / Focus To-Do(14,596) | 極小 |
| time limit apps | 様子見 | ScreenZen(49,330) / Opal(87,634) / Refocus(11,243) | 派生 |
| touch grass | 様子見 | touch grass(2,989) / touch grass(1) / Touch-Grass(0) | スラング |
| offline time | 様子見 | EBMS Offline Time Cloc(2) / Offline Games(14,670) / Time Factory Inc(12,787) | 極小 |
| locked in | 様子見 | LockedIn(273) / Lock In(26,670) / Locked In(110) | 同上 |
| detox | 様子見 | Detox(452) / DetoxLock(483) / I Am Sober(186,585) | 広すぎる（食事・肌） |
| app timer | 様子見 | Opal(87,634) / ScreenZen(49,330) / one sec(23,512) | タイマー意図が混在 |
| exam focus | 様子見 | NBDE I & II Exam Prep (9) / GRE Prep guide 2026(2) / Study Bunny(21,387) | 極小 |
| phone jail | 様子見 | Phone Jail(40) / ConnectNetwork by GTL(301) / Securus Mobile(52,414) | 極小 |
| digital minimalism | 様子見 | Minimalist Launcher(3,511) / Blank Spaces Launcher(8,283) / Dumb Phone (dp)(3,717) | 極小 |
| screen time for adults | 様子見 | Parental Control App(40,068) / Circle Parental Contro(13,431) / BePresent(62,818) | 極小 |
| scrolling | 様子見 | Deepstash(67,756) / Imprint(54,741) / Fidget Widget(3,341) | 広すぎる |
| focus lock | 様子見 | Focus Lock(285) / Opal(87,634) / Focus Plant：forest app(5,421) | 極小 |
| study lock | 様子見 | Focus Plant：forest app(5,421) / Opal(87,634) / StudyLock(1) | 極小 |
| revision timer | 様子見 | GB値: Flora(84,463) / Study Bunny(14,134) / Focus Keeper(5,200) | タイマー |
| night mode | 除外 | Darker(1,271) / Night Eyes(20,381) / Nightcam Camera(2,555) | 画面モード |
| habit | 除外 | Habit Burger Grill(56,402) / Habit Tracker(146,631) / Habit Tracker(2,415) | 習慣トラッカー |
| adhd focus | 除外 | Focus Friend, by Hank (6,615) / Flora(82,594) / Focus Keeper(31,599) | 同上 |
| attention span | 除外 | Concentration training(42) / Focus Friend, by Hank (6,615) / Impulse(848,079) | 機能なし |
| downtime | 除外 | Opal(87,634) / Downtime(2) / Real Downtime(0) | iOS機能名 |
| phone free | 除外 | Phone(10,335) / TextNow(919,516) / Text Free(602,372) | 2nd phone number系が上位 |
| study with me | 除外 | StayMe(0) / Study Time With Rain(780) / Focustown(6,069) | 動画系 |
| study buddy | 除外 | Study Bunny(21,387) / Focus Friend, by Hank (6,615) / Focustown(6,069) | AI学習系 |
| pomodoro timer | 除外 | Focus Keeper(31,599) / FocusPomo · Pomodoro T(7,647) / Pomodoro(20) | タイマー専用 |
| focus keeper | 除外 | Focus Keeper(31,599) / FocusPomo · Pomodoro T(7,647) / Focus To-Do(14,596) | 他社名（タイマー） |
| time management | 除外 | Structured(165,665) / Focus Keeper(31,599) / ATracker Time Tracker(3,179) | プランナー系 |
| adhd | 除外 | Tiimo(19,518) / Finch(750,567) / Structured(165,665) | 機能なし・センシティブ |
| adhd app blocker | 除外 | Refocus(11,243) / one sec(23,512) / Brick(53,487) | 同上 |
| gcse revision | 除外 | GB値: GCSE Quiz Revision(14) / BBC Bitesize(9,064) / My Past Papers(2,935) | コンテンツ |
| a level revision | 除外 | GB値: Medly(4,867) / SimpleStudy(3,073) / BBC Bitesize(9,064) | コンテンツ |
| uni study | 除外 | GB値: Studydrive(51) / Study!(129) / StudySmarter(2,134) | コンテンツ |
| productivity | 観測のみ | Structured(165,665) / Finch(750,567) / Habit Tracker(146,631) | 圏外・広すぎる |


### 英語圏の除外語（ネガティブ・全ストアフロント共通）

block blast／block puzzle／blockudoku／bricks／huge bricks／brickit／brick breaker／screen recorder／screen mirroring／ad blocker／adblock／app lock／applock／parental control／parental／parent／kids／family link／habit tracker／calorie／period／sleep tracker／alarm／vpn／tiktok lite／instagram lite／youtube kids／study buddy／gcse／a level／revision／quizlet／second phone number。市場別: AU は opal card／opal travel／opal nsw、GB は forest bike／nottingham forest、CA は freedom mobile。

## 3. 韓国

### 実測ボリュームあり（上位500圏内）

| キーワード | KR週 | KR月 | 5段階（週・Apple実測） | ジャンル | 判定 | 競合上位（ストア評価数） | 備考 |
|---|---|---|---|---|---|---|---|
| 열품타 | 81 | 81 | 5 | Productivity Utilities | 競合指名 | 열품타(46,792) / 올클-공부타이머, 할일, 챌린지, 영단어(7,529) / Instagram(1,883,923) | 実測81＝5/5。学生向け勉強タイマー4.7万評価。低入札で試すのみ |
| 알람 | 72 | 74 | 4 | Health Fitness | 除外 |  | アラーム |
| 블록 | 64 | 67 | 4 | Games | 除外 | 블록 블라스트 (Block Blast)(67,380) / Block Out!(3,599) / Blockudoku(58,633) | ゲーム |
| iscreen | 60 | 65 | 3 | Productivity Utilities | 除外 |  | ウィジェット |
| 플래너 | 62 | 64 | 4 | Productivity Utilities | 除外 |  | プランナー |
| 공부 타이머 | 61 | 63 | 4 | Productivity Utilities | 様子見 | 열품타(46,792) / 올클-공부타이머, 할일, 챌린지, 영단어(7,529) / 순공시간(10) | 열품타の領域 |
| 마이루틴 | 57 | 63 | 3 | Productivity Utilities | 除外 |  | ルーティン |
| 언락 | 56 | 63 | 3 | Entertainment | 除外 |  | エンタメ |
| 루틴 | 57 | 62 | 3 | Productivity Utilities | 除外 | 마이루틴(24,885) / 투두메이트(107,616) / 마이턴(1,099) | ルーティン/プランナー |
| focus flight | 56 | 62 | 3 | Productivity Utilities | 競合指名 | FocusFlight-집중을 되찾고 싶은(15,978) / FocusTok(141) / Focus Traveller(2,196) | 実測56/62・1.6万評価 |
| 잠글시간 | 57 | 61 | 3 | Productivity Utilities | 競合指名 | 잠글시간(5,225) / 터닝(3,559) / 지키자(1,075) | 実測57/61。KR最大のロック系競合 |
| 캠퍼스락 | 61 | 57 | 4 | Education | 除外 | 캠퍼스락(130) / Mahjong Duels®(38) | 実測61だが別用途（出席/学内） |
| 수면 | 54 | 60 | 3 | Health Fitness | 除外 | Renight(나이틀리)(4,368) / Sleep Cycle(3,165) / Sleep Tracker(2,222) | 睡眠 |
| 의지의 히어로 | 55 | 60 | 3 | Games | 除外 |  | ゲーム |
| focustown | 53 | 59 | 3 | Productivity Utilities | 競合指名 | Focus Town(3,487) / FocusFlight-집중을 되찾고 싶은(15,978) / 열품타(46,816) | 実測53/59 |
| 스크린타임 | 53 | 58 | 3 | Productivity Utilities | 主力 | 잠글시간(5,225) / 터닝(3,559) / 스크린타임(18) | 実測53/58。競合は잠글시간/터닝/지키자＝US/JPより弱い |
| 앱 잠금 | 53 | 58 | 3 | Productivity Utilities | 主力 | 잠글시간(5,225) / 터닝(3,559) / 앱 차단, 앱 잠금, 웹사이트 차단(958) | 実測53/58。KRでは勉強用ロックの意味が主 |
| 뽀모도로 | 52 | - | 3 | Productivity Utilities | 様子見 | 얼티밋 포커스(8,444) / Focus To-Do：뽀모도로 기법 + (9,888) / 조구만 뽀모도로 타이머(29) | タイマー専用 |

### 圏外（上位500に無い＝人気度がジャンル下限未満・意図で選ぶ）

| キーワード | 判定 | 競合上位（ストア評価数） | 備考 |
|---|---|---|---|
| 스크린 타임 | 主力 | 잠글시간(5,225) / 터닝(3,559) / 스크린 타임 제어(37) | Apple表記（分かち書き） |
| 스크린타임 줄이기 | 主力 | Jomo(43) / Budli(0) / DopaBreak(0) | 自社KRタイトル語。結果42件のみ→安い |
| 앱차단 | 主力 | 터닝(3,559) / 지키자(1,075) / 앱 차단, 앱 잠금, 웹사이트 차단(958) | 結果は制限系のみ・意図一致 |
| 앱 차단 | 主力 | 터닝(3,559) / 지키자(1,075) / 앱 차단, 앱 잠금, 웹사이트 차단(956) | 同上 |
| 앱잠금 | 主力 | 잠글시간(5,225) / 터닝(3,559) / 앱 차단, 앱 잠금, 웹사이트 차단(958) | 同上 |
| 폰 잠금 | 主力 | 잠글시간(5,225) / 터닝(3,559) / 앱 차단, 앱 잠금, 웹사이트 차단(958) | 同上 |
| 핸드폰 잠금 | 主力 | 잠글시간(5,225) / 터닝(3,559) / Forest(15,930) | 同上 |
| 폰 사용 제한 | 主力 | App Blocker(774) / 터닝(3,559) / Tempozi(4) | 競合小 |
| 앱 사용 제한 | 主力 | 잠글시간(5,225) / 집중 식물(7,116) / 터닝(3,559) | 派生 |
| 앱 제한 | 主力 | 잠글시간(5,225) / 터닝(3,559) / 앱 차단, 앱 잠금, 웹사이트 차단(958) | 派生 |
| 폰중독 | ニッチ高CVR | 터닝(3,559) / 잠글시간(5,225) / Forest(15,930) | 意図最濃。터닝/잠글시간/Forest |
| 폰 중독 | ニッチ高CVR | Forest(15,930) / 터닝(3,559) / 도파민배리어(70) | 同上 |
| 스마트폰 중독 | ニッチ高CVR | 터닝(3,559) / Forest(15,927) / 앱 차단, 앱 잠금, 웹사이트 차단(956) | 同上 |
| 핸드폰 중독 | ニッチ高CVR | 터닝(3,559) / 잠글시간(5,225) / Forest(15,930) | 同上 |
| 디지털 디톡스 | ニッチ高CVR | 터닝(3,559) / Forest(15,930) / 앱 차단, 앱 잠금, 웹사이트 차단(958) | Forestがサブタイトルに保持 |
| 디지털디톡스 | ニッチ高CVR | 잠글시간(5,225) / Forest(15,930) / 터닝(3,559) | 同上 |
| 도파민 | ニッチ高CVR | 터닝(3,559) / 도파민배리어(70) / 상식도파민(153) | 結果は小規模のみ・ブランド名と親和 |
| 도파민 디톡스 | ニッチ高CVR | 도파민배리어(70) / 도파민 디톡스(88) / 터닝(3,559) | 同上 |
| 도파민디톡스 | ニッチ高CVR | 도파민 디톡스(88) / 도파민 디톡스(0) / 터닝(3,559) | 同上 |
| 숏폼 중독 | ニッチ高CVR | 앱 차단, 앱 잠금, 웹사이트 차단(961) / 미션락(17) / Soda TV(4) | サブタイトル語。競合極小（미션락） |
| 쇼츠 차단 | ニッチ高CVR | Dull(2) / 도파민배리어(70) / 도파민 디톡스(88) | 結果36件・極小競合 |
| 릴스 차단 | ニッチ高CVR | 도파민배리어(70) / UNDOOMED(12) / Dull(2) | 同上 |
| 유튜브 차단 | ニッチ高CVR | 진짜로?(28) / 지키자(1,075) / 잔소리앱(16) | 結果91件 |
| 틱톡 차단 | ニッチ高CVR | 도파민배리어(70) / Curfew(0) / 그만봐(1) | 結果19件 |
| sns 차단 | ニッチ高CVR | 잔소리앱(16) / Pocus(0) / 미션락(16) | 結果94件・小規模のみ |
| sns 중독 | ニッチ高CVR | 앱 차단, 앱 잠금, 웹사이트 차단(958) / 잔소리앱(16) / 미션락(16) | 結果100件 |
| 폰 사용시간 | ニッチ高CVR | 터닝(3,559) / 잠글시간(5,225) / 집중 식물(7,116) | 記録機能で受ける |
| 스마트폰 사용시간 | ニッチ高CVR | Striving(279) / 터닝(3,559) / 스크린타임(18) | 小規模のみ |
| 사용시간 줄이기 | ニッチ高CVR | 폰드(41) / Budli(0) / 마음스크린(0) | 結果23件・自社タイトルと親和 |
| 폰 그만 | ニッチ高CVR | 그만봐(1) / 노폰타(0) | 結果2件・自社領域 |
| 폰 끊기 | ニッチ高CVR | Forest(15,930) / Grounded(2) / Rewire(0) | 結果14件 |
| 폰 줄이기 | ニッチ高CVR | Budli(0) / 사진 압축기(977) / 클리너(93) | 結果31件 |
| 핸드폰 줄이기 | ニッチ高CVR | Velo(14) / Jomo(43) / Cleaner Kit(8,429) | 結果20件 |
| 스마트폰 줄이기 | ニッチ高CVR | Budli(0) / Jomo(43) / 마음스크린(0) | 結果33件 |
| 폰 덜 보기 | ニッチ高CVR | 덜봄(0) | 結果1件 |
| 포레스트 | 競合指名 | Forest(15,930) / 포레스트 아일랜드(4,172) / 집중 식물(7,116) | Forest・1.6万評価 |
| forest | 競合指名 | Forest(15,930) / Forest(14) / 집중 식물(7,116) | 同上 |
| opal | 競合指名 | Opal(629) / Opal Travel(326) / one sec(989) | KRは629評価と小さい |
| 원섹 | 競合指名 | one sec(989) / 원띵(1,993) / OpenVPN Connect(1,044) | one sec |
| one sec | 競合指名 | one sec(989) / 터닝(3,560) / ScreenZen(300) | 989評価 |
| 열정품은타이머 | 競合指名 | 열품타(46,792) / 열공시간(3,848) / 올클-공부타이머, 할일, 챌린지, 영단어(7,529) | 同上の正式名 |
| 터닝 | 競合指名 | 터닝(3,560) / 잠글시간(5,239) / 앱 차단, 앱 잠금, 웹사이트 차단(961) | 앱 잠금/폰 잠금の競合・3.6千評価 |
| 지키자 | 競合指名 | 지키자(1,076) / 잠글시간(5,239) / 앱 차단, 앱 잠금, 웹사이트 차단(961) | 앱 차단/스크린타임の競合・1.1千評価 |
| 락체스트 | 競合指名 | 앱 차단, 앱 잠금, 웹사이트 차단(961) / NumbBrain(0) | 앱 차단/웹사이트 차단の競合・958評価 |
| 집중 식물 | 競合指名 | 집중 식물(7,116) / PictureThis：식물 식별 및 관리(2,966) / Blossom(136) | Focus Plant・7.1千評価 |
| blockin | 競合指名 | Blockin -휴대폰 앱 잠금 & 스크(594) / 잠글시간(5,239) / 터닝(3,560) | Blockin韓国版・594評価 |
| 집중 | 様子見 | Forest(15,930) / FocusFlight-집중을 되찾고 싶은(15,970) / 열품타(46,792) | 圏外・Forest/FocusFlight/열품타と正面衝突 |
| 집중 앱 | 様子見 | Exocus:픽셀 행성 키우기 & 포모도(61) / Forest(15,930) / 열품타(46,792) | 同上 |
| 집중력 | 様子見 | Forest(15,930) / 집중력 훈련(14) / Orbis(133) | 同上 |
| 공부 집중 | 様子見 | FocusFlight-집중을 되찾고 싶은(15,978) / Forest(15,932) / 잼터디(24) | 同上 |
| 공부타이머 | 様子見 | 열품타(46,792) / 올클-공부타이머, 할일, 챌린지, 영단어(7,529) / 순공시간(10) | 同上 |
| 사용시간 | 様子見 | 터닝(3,559) / Striving(279) / Google Family Link(55,562) | Family Link混在 |
| 디지털 웰빙 | 様子見 | Jomo(43) / one sec(989) / 노파민(1) | Android語・結果84件 |
| 자제력 | 様子見 | 진짜로?(28) / 시선(49) / PAUSED(4) | 結果64件・小規模 |
| 딴짓 | 様子見 | 앱 차단, 앱 잠금, 웹사이트 차단(958) / 포모도로 타이머(4) / 월급냥이(0) | 結果33件 |
| 딴짓 방지 | 様子見 | 시험모드(0) / 집중기차(0) / 스크린타임 GoldTime(6) | 結果10件 |
| 미루기 | 様子見 | 칠리(0) / 현실도 피자(7) / 밀린 할 일(0) | ToDo系混在 |
| 스마트폰 절제 | 様子見 | 잠글시간(5,225) / Basic Mode(0) / 앱 차단, 앱 잠금, 웹사이트 차단(958) | 結果68件 |
| 스터디 타이머 | 様子見 | 얼티밋 포커스(8,444) / 올클-공부타이머, 할일, 챌린지, 영단어(7,529) / 열품타(46,792) | タイマー |
| 집중 타이머 | 様子見 | 얼티밋 포커스(8,444) / FocusFlight-집중을 되찾고 싶은(15,970) / Forest(15,930) | タイマー専用 |
| 몰입 | 様子見 | 몰입의 방(19) / 몰입 스터디카페(16) / 딥워크(1,518) | 小規模 |
| 사용 제한 | 様子見 | 잠글시간(5,225) / 집중 식물(7,116) / Blockin -휴대폰 앱 잠금 & 스크(594) | 上位は잠글시간/집중 식물/Blockin＝制限系だが単語が広い |
| 잠금 타이머 | 様子見 | 잠글시간(5,225) / 터닝(3,559) / 공부 타이머 & 뽀모도로 Focusi(1,118) | 勉強ロック系 |
| 폰 잠금 타이머 | 様子見 | 터닝(3,559) / 잠글시간(5,225) / 몰입의 방(19) | 同上 |
| 집중 모드 | 様子見 | 또보네(17) / 얼티밋 포커스(8,444) / 집중 타이머 FlightMode(153) | 小規模 |
| 공부 모드 | 様子見 | 잠글시간(5,225) / TimerTiTi(305) / JLPT 일본어 단어 공부, 일단공부(3,755) | 小規模 |
| 포커스 | 様子見 | Focus Town(3,481) / Focos(5,463) / FocusFlight-집중을 되찾고 싶은(15,970) | Focus Town/Focos |
| focus | 様子見 | Focus Town(3,481) / FocusFlight-집중을 되찾고 싶은(15,970) / Forest(15,930) | 同上 |
| 중독 | 様子見 | Quitzilla(399) / 터닝(3,559) / Forest(15,930) | 上位は터닝/Forest＝競合だが禁酒/禁欲系も混在。broadにしない |
| 숏폼 | 除外 | DramaBox(20,044) / Vigloo(7,854) / NetShort(14,422) | ショートドラマアプリ（DramaBox等） |
| 인스타 차단 | 除外 | 팔로워 추적 · 언팔로워(0) / Reports Followers+ Tra(13,465) / TrackFollows(67) | 結果はフォロワー追跡系 |
| 오팔 | 除外 | Opal Travel(326) / Opal(629) / TripView Lite(1,638) | Opal Travelが上位 |
| 스크린젠 | 除外 | 걸어서 스크린 타임 잠금 해제(0) / mLite(155) / 소셜 미디어 스크롤 그만(0) | 結果14件・ScreenZen本体が上位に無い |
| 습관 | 除外 | 마이루틴(24,885) / 데이스탬프(5,184) / 투두메이트(107,616) | 習慣トラッカー |
| 취침 | 除外 | Sleep Tracker(2,222) / 잠잘시간(time2sleep)(23) / Renight(나이틀리)(4,368) | 睡眠 |
| 절제 | 除外 | 금욕 타이머(1,158) / 그만봐(1) / 현자타임(3) | 禁欲タイマー系 |
| 공부 앱 | 除外 | 열품타(46,792) / 올클-공부타이머, 할일, 챌린지, 영단어(7,529) / Focus Town(3,481) | 学習アプリ |
| 자기관리 | 除外 | 마이루틴(24,885) / 마이턴(1,099) / 투두메이트(107,616) | プランナー |
| 시간관리 | 除外 | Structured(5,544) / 마이루틴(24,885) / 플렘(360) | プランナー |
| 수능 타이머 | 除外 | 실감(239) / 2027 수능타이머(수능디데이, 고1,2(2) / 열품타(46,792) | 受験カウントダウン |
| 차단 | 除外 | Unicorn HTTPS(171,484) / U+스팸차단(1,297) / 후스콜(40,677) | 迷惑電話ブロック |


### 韓国の除外語（ネガティブ）

블록／블록 블라스트／block blast／스팸 차단／전화 차단／스팸／후스콜／숏폼（ショートドラマ）／드라마／인스타 차단／언팔／팔로워／알람／수면／루틴／플래너／투두／계획표／시간표／자녀／자녀보호／패밀리 링크／폰트／캠퍼스락／iscreen／위젯／절제／금욕／오팔（Opal Travel）／수능／영어／일본어。

## 4. 日本

### 実測ボリュームあり（上位500圏内）

| キーワード | JP週 | JP月 | 5段階（週・Apple実測） | ジャンル | 判定 | 競合上位（ストア評価数） | 備考 |
|---|---|---|---|---|---|---|---|
| 日記 | 72 | 74 | 4 | Productivity Utilities | 除外 |  | 日記 |
| 勉強 | 70 | 73 | 4 | Productivity Utilities | 様子見 | Studyplus（スタディプラス）勉強記録(336,887) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / Duolingo-英語/韓国語などのリスニン(751,492) | 実測70/73＝4/5だが勉強アプリ意図。長尾のみ |
| ブロック | 70 | 73 | 4 | Games | 除外 | ブロックブラスト (Block Blast)(353,002) / Block Out!(20,713) / ウッドブロックパズルゲーム(53,198) | ゲーム（ブロックブラスト等） |
| 勉強アプリ | 70 | 72 | 4 | Productivity Utilities | 除外 |  | 学習アプリ |
| タイマー | 66 | 70 | 4 | Health Fitness | 除外 | Clock(2,956) / タイマー&アラーム ListTimer 勉強(24,122) / 筋トレ・タイマー(56,124) | 汎用 |
| 睡眠 | 66 | 70 | 4 | Health Fitness | 除外 | Sleep Meister(222,386) / リナイト(8,338) / 熟睡アラーム‐睡眠といびきを計測する目覚まし(24,891) | 睡眠アプリ |
| 広告ブロック | 65 | 70 | 4 | Productivity Utilities | 除外 |  | 広告ブロッカー |
| ショートドラマ | 65 | 69 | 4 | Entertainment | 除外 |  | ドラマアプリ |
| todo | 61 | 65 | 4 | Productivity Utilities | 除外 |  | ToDo |
| 集中 | 60 | 64 | 4 | Productivity Utilities | 様子見 | 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / 集中旅行者(20,559) / FocusFlight(24,958) | 実測60/64＝4/5だが広い語。「集中」アプリ13万評価・集中旅行者/FocusFlightと正面衝突。9/11案どおり主力に混ぜず、単独広告グループで低入札テスト |
| 集中旅行者 | 62 | 64 | 4 | Productivity Utilities | 競合指名 | 集中旅行者(20,559) / FocusFlight(24,958) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) | 実測62/64・2.1万評価（Focus Traveller） |
| focus flight | 56 | 64 | 3 | Productivity Utilities | 競合指名 | FocusFlight(24,958) / FocusTok(374) / 集中旅行者(20,559) | 実測56/64・2.5万評価 |
| ポモドーロ | 58 | 64 | 3 | Productivity Utilities | 様子見 | 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / Focus To-Do(35,234) / ポモドーロタイマー 勉強・仕事・作業用。シン(2,760) | 実測58/64・タイマー専用 |
| 勉強記録 | 60 | 64 | 3 | Productivity Utilities | 除外 |  | 記録アプリ |
| スマホ制限 | 58 | 63 | 3 | Productivity Utilities | 主力 | スマホ依存対策Blockinスクリーンタイム(19,137) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / スマホをやめれば魚が育つ(15,885) | 実測58/63・自社タイトル語 |
| studyplus | 59 | 63 | 3 | Productivity Utilities | 除外 |  | 学習記録 |
| スクリーンタイム | 57 | 62 | 3 | Health Fitness | 主力 | スマホ依存対策Blockinスクリーンタイム(19,129) / スクリーンタイム管理(124) / スマホ制限・スタロック｜アプリ制限・アプリロ(7,961) | 実測57/62。Blockin/Stay Off/スタロック/Opal |
| opal | 56 | 62 | 3 | Productivity Utilities | 競合指名 | Opal(2,827) / Opal Travel(327) / Forest(10,626) | 実測56/62・JPは2.8千評価 |
| 勉強時間記録 | 58 | 62 | 3 | Productivity Utilities | 除外 |  | 記録アプリ |
| 勉強タイマー | 56 | 61 | 3 | Productivity Utilities | 様子見 | 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / 勉強タイマー 超集中｜波音・雨音×ポモドーロ(6,191) / Studyplus（スタディプラス）勉強記録(336,887) | 実測56/61・タイマー専用 |
| forest | 56 | 60 | 3 | Productivity Utilities | 競合指名 | Forest(10,626) / フォレストアイランド(5,336) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) | 実測56/60 |
| タスク管理 | 56 | 60 | 3 | Productivity Utilities | 除外 |  | ToDo |
| blockin | 52 | 59 | 3 | Health Fitness | 競合指名 | スマホ依存対策Blockinスクリーンタイム(19,137) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / スマホ制限・スタロック｜アプリ制限・アプリロ(7,965) | 実測52/59・1.9万評価＝JP最大の制限系 |
| アプリ制限 | 52 | 58 | 3 | Health Fitness | 主力 | スマホ依存対策Blockinスクリーンタイム(19,129) / アプリ制限 Zentime(1,349) / スマホ制限・スタロック｜アプリ制限・アプリロ(7,961) | 実測52/58。Blockin/Zentime/スタロック |
| スマホをやめれば魚が育つ | 56 | 58 | 3 | Education | 競合指名 | スマホをやめれば魚が育つ(15,885) / スマホをやめれば魚が育つ｜レガシー(4,338) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) | 実測56/58・1.6万評価。学生中心 |
| 時間割 | 58 | - | 3 | Productivity Utilities | 除外 |  | 学生ツール |
| アプリロック | 51 | 56 | 3 | Health Fitness | 主力 | スマホ依存対策Blockinスクリーンタイム(19,137) / スマホ制限・スタロック｜アプリ制限・アプリロ(7,965) / アプリロック(361) | 実測51/56。スタロックがタイトルに含む語（アプリ制限の結果より） |
| 継続 | 51 | 55 | 3 | Health Fitness | 除外 | 継続する技術｜ダイエットも筋トレも記録・習慣(53,072) / 記録で習慣化 DotHabit 運動・勉強の(16,608) / my nicca(6,106) | 習慣アプリ |
| 目標 | 50 | 55 | 3 | Health Fitness | 除外 | 継続する技術｜ダイエットも筋トレも記録・習慣(53,066) / 記録で習慣化 DotHabit 運動・勉強の(16,605) / マイライフプラン(677) | 目標管理 |
| すまやめ | 48 | 53 | 3 | Education | 競合指名 | スマホをやめれば魚が育つ(15,874) / スマホをやめれば魚が育つ｜レガシー(4,338) / Forest(10,624) | 実測48/53（略称） |
| 継続する技術 | 48 | - | 3 | Health Fitness | 除外 |  | 他社名 |

### 圏外（上位500に無い＝人気度がジャンル下限未満・意図で選ぶ）

| キーワード | 判定 | 競合上位（ストア評価数） | 備考 |
|---|---|---|---|
| 使用時間 制限 | 主力 | スマホ制限・スタロック｜アプリ制限・アプリロ(7,965) / スマホ制限(1,313) / Google ファミリー リンク(63,884) | 派生 |
| スマホ制限アプリ | 主力 | スマホ依存対策Blockinスクリーンタイム(19,137) / スマホ制限・スタロック｜アプリ制限・アプリロ(7,965) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) | 派生 |
| アプリ 使用時間 | 主力 | スマホ依存対策Blockinスクリーンタイム(19,137) / Google ファミリー リンク(63,884) / ラムロック｜スマホ制限・スクリーンタイム・ス(399) | 派生 |
| スマホ 制限 時間 | 主力 | スマホ依存対策Blockinスクリーンタイム(19,137) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / スマホ制限・スタロック｜アプリ制限・アプリロ(7,965) | 派生 |
| アプリ 時間制限 | 主力 | スマホ依存対策Blockinスクリーンタイム(19,137) / アプリ制限 Zentime(1,351) / スマホ制限・スタロック｜アプリ制限・アプリロ(7,965) | 派生 |
| スマホ ブロック | 主力 | スマホ依存対策Blockinスクリーンタイム(19,137) / スマホ制限・スタロック｜アプリ制限・アプリロ(7,965) / one sec ・スマホ 依存 対策・集中タ(7,530) | 派生 |
| アプリ ブロック | 主力 | スマホ依存対策Blockinスクリーンタイム(19,137) / スマホ制限・スタロック｜アプリ制限・アプリロ(7,965) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) | 09-11媒体案の候補「アプリブロック」。圏外だが解決語なのでCP2-aの派生語 |
| スクリーンタイム制限 | 主力 | スマホ依存対策Blockinスクリーンタイム(19,137) / スマホ制限・スタロック｜アプリ制限・アプリロ(7,965) / アプリ制限 Zentime(1,351) | 09-11媒体案の候補。圏外だが解決語なのでCP2-aの派生語 |
| スマホ依存 | ニッチ高CVR | スマホ依存対策Blockinスクリーンタイム(19,153) / スマホをやめれば魚が育つ(15,872) / Forest(10,623) | 09-11媒体案の候補。圏外（全ジャンル下限未満・JPは最小47）だが意図最濃。Blockin/魚が育つ/集中/Forest |
| スマホ中毒 | ニッチ高CVR | Forest(10,626) / スマホ依存対策Blockinスクリーンタイム(19,137) / スマホをやめれば魚が育つ(15,885) | 同上 |
| スマホ依存症 | ニッチ高CVR | スマホ依存対策Blockinスクリーンタイム(19,129) / スマホ制限・スタロック｜アプリ制限・アプリロ(7,961) / スマホをやめれば魚が育つ(15,874) | 同上 |
| デジタルデトックス | ニッチ高CVR | スマホ依存対策Blockinスクリーンタイム(19,153) / スマホをやめれば魚が育つ(15,872) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,754) | 圏外。Blockin/魚が育つ/集中 |
| ドーパミンデトックス | ニッチ高CVR | シンプルフォン(72) / 退屈道場-ドーパミン中毒を解消～何もしないを(4) / ドーパミン・デトックス(0) | 同上 |
| SNS制限 | ニッチ高CVR | Clarymind｜スマホ依存対策・スクリー(500) / Applimits(53) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,758) | 競合はClarymind(500)など小規模→勝ちやすい |
| SNS依存 | ニッチ高CVR | そのSNSどうして開いたの？ スマホ依存制限(3) / Clarymind｜スマホ依存対策・スクリー(500) / 依存症克服SNS クイットメイト QuitM(203) | 同上 |
| SNSやめたい | ニッチ高CVR | やめたい習慣カウンター・禁煙・禁酒・SNS断(1) / つながらないSNS ilka（いるか） 本音(3,562) / 依存症克服SNS クイットメイト QuitM(203) | 結果38件・極小競合 |
| インスタ 制限 | ニッチ高CVR | 家に帰ったらSNSを使えなくするアプリ｜スマ(13) / スマホ制限・スタロック｜アプリ制限・アプリロ(7,965) / スマホ依存対策Blockinスクリーンタイム(19,137) | 派生 |
| tiktok 制限 | ニッチ高CVR | VPN 360：安全でプライベートな無制限V(794) / しずか｜スクリーンタイム・スマホ制限・アプリ(0) / もちのう(11) | 結果22件 |
| youtube 制限 | ニッチ高CVR | ABEMA(アベマ) 新しい未来のTV(535,097) / 音楽放題 Music HD 音楽が聴き放題の(76,989) / YouTube Kids(181,458) | 派生 |
| ショート動画 やめたい | ニッチ高CVR | 何しに？｜スマホ依存対策・スクリーンタイム・(8) / StopScroll(0) / AntiScroll -楽しく続くスマホ依存(3) | 結果8件・極小競合 |
| スマホ やめたい | ニッチ高CVR | Striving(234) / moku(52) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) | 意図最濃 |
| スマホ 使いすぎ | ニッチ高CVR | スギスマホでお薬-処方せん送信・お薬手帳アプ(3,403) / Offly -スマホの使い過ぎ防止／集中力向(28) / アプリ制限 Zentime(1,351) | 派生 |
| スマホ利用時間 | ニッチ高CVR | 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / スマホ依存対策Blockinスクリーンタイム(19,137) / 集中旅行者(4) | 記録機能で受ける |
| 夜 スマホ | ニッチ高CVR | 脱夜スマホ 早起き 寝不足 朝活 夜更かし (47) / BlankPage(950) / 夜スマホをやめるアプリ｜ヨハク・余白(30) | 結果55件・小規模。Pro夜だけ強化の訴求先 |
| 寝る前 スマホ | ニッチ高CVR | 夜スマホをやめるアプリ｜ヨハク・余白(30) / 脱夜スマホ 早起き 寝不足 朝活 夜更かし (47) / Bedside:寝る前にスマホを置く(0) | 結果34件 |
| 夜ふかし | ニッチ高CVR | ぽちゃガチョ！(45,566) / バレずに夜ふかし(0) / Nemuru(1) | 派生 |
| 夜更かし | ニッチ高CVR | 脱夜スマホ 早起き 寝不足 朝活 夜更かし (47) / まえぶれ(1) / SleepTown(463) | 派生 |
| 睡眠 スマホ | ニッチ高CVR | よひつじの森(2,352) / 睡眠｜眠りの記録と改善(2,410) / スマホ制限・スタロック｜アプリ制限・アプリロ(7,965) | 派生 |
| 依存 対策 | ニッチ高CVR | 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / スマホ制限・スタロック｜アプリ制限・アプリロ(7,965) / スマホ依存対策Blockinスクリーンタイム(19,137) | 派生 |
| スマホ やめる | ニッチ高CVR | 異星フォーカス(683) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / スマホ依存対策Blockinスクリーンタイム(19,137) | 同上 |
| one sec | 競合指名 | one sec ・スマホ 依存 対策・集中タ(7,530) / スマホ依存対策Blockinスクリーンタイム(19,137) / Opal(2,827) | 圏外 |
| スタロック | 競合指名 | スマホ制限・スタロック｜アプリ制限・アプリロ(7,965) / スマホ依存対策Blockinスクリーンタイム(19,137) / ラムロック｜スマホ制限・スクリーンタイム・ス(399) | 圏外・8千評価 |
| ドーパミン | 様子見 | オリパならDOPA（ドーパ）｜トレカ｜オンラ(36,309) / シンプルフォン(72) / 退屈道場-ドーパミン中毒を解消～何もしないを(4) | 圏外。JPの上位はトレカのDOPA（オリパ・3.6万評価）で意図が割れる。ブランド名との親和だけで低入札テスト |
| スマホ時間 | 様子見 | スマホ依存対策Blockinスクリーンタイム(19,137) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / スマホをやめれば魚が育つ(15,885) | 汎用 |
| 利用時間 制限 | 様子見 | アプリ制限 Zentime(1,349) / Google ファミリー リンク(63,863) / スマホ制限・スタロック｜アプリ制限・アプリロ(7,961) | Family Link混在 |
| 集中アプリ | 様子見 | 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / 集中旅行者(20,559) / FocusFlight(24,958) | 同上 |
| 集中力 | 様子見 | 集中旅行者(20,559) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / 毎日 脳トレ(69,179) | 同上 |
| 勉強 集中 | 様子見 | 集中旅行者(20,524) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,758) / FocusFlight(24,946) | 集中旅行者/集中/FocusFlight |
| 勉強 スマホ | 様子見 | スマホをやめれば魚が育つ(15,885) / スマホ依存対策Blockinスクリーンタイム(19,137) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) | 長尾 |
| 集中タイマー | 様子見 | 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / 集中旅行者(20,559) / FocusFlight(24,958) | タイマー専用 |
| スマホ断ち | 様子見 | 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / スマホをやめれば魚が育つ(15,885) / スマホ依存対策Blockinスクリーンタイム(19,137) | 極小 |
| スマホ断食 | 様子見 | 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / Clarymind｜スマホ依存対策・スクリー(502) / スマホ依存対策Blockinスクリーンタイム(19,137) | 極小 |
| スマホ ロック | 様子見 | スマホ依存対策Blockinスクリーンタイム(19,137) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / スマホ制限・スタロック｜アプリ制限・アプリロ(7,965) | プライバシー系混在 |
| 強制ロック | 様子見 | スマホ制限・スタロック｜アプリ制限・アプリロ(7,965) / スマホ依存対策Blockinスクリーンタイム(19,137) / ロックくん(2) | 小規模 |
| スマホ 触らない | 様子見 | スマホをやめれば魚が育つ(15,885) / Forest(10,626) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) | 極小 |
| スマホ 見ない | 様子見 | スマホをやめれば魚が育つ(15,885) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / フォーカス・プラント(7,982) | 極小 |
| デジタル 断捨離 | 様子見 | 終活アプリ SouSou(92) / アプリ断捨離：使ってないアプリを見つける(0) / スマホ依存から脱却(0) | 極小 |
| ながらスマホ | 様子見 | monap™(4) / フリマアプリはメルカリ(5,535,175) / AppBlock アプリ・サイトをブロックし(2,037) | 極小 |
| 集中 勉強 アプリ | 様子見 | 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / Studyplus（スタディプラス）勉強記録(336,887) / スマホ制限・スタロック｜アプリ制限・アプリロ(7,965) | 同上 |
| 受験 スマホ | 様子見 | 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / スマホ制限・スタロック｜アプリ制限・アプリロ(7,965) / スマホをやめれば魚が育つ(15,885) | 長尾・学生 |
| 勉強 アプリ 制限 | 様子見 | スマホ依存対策Blockinスクリーンタイム(19,137) / Forest(10,626) / スマホ制限・スタロック｜アプリ制限・アプリロ(7,965) | 長尾 |
| スマホ断ち アプリ | 様子見 | 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / スマホ断ち(234) / スマホ断ち(2) | 極小 |
| ショート動画 | 除外 | DramaBox（ドラマボックス） -ショー(135,090) / ReelShort(37,678) / NetShort(43,642) | ショートドラマ/TikTok本体 |
| 習慣化 | 除外 | 継続する技術｜ダイエットも筋トレも記録・習慣(53,072) / 記録で習慣化 DotHabit 運動・勉強の(16,608) / マイ ルーティン(6,473) | 習慣アプリ |
| 目標達成 | 除外 | 継続する技術｜ダイエットも筋トレも記録・習慣(53,086) / my nicca(6,107) / 習慣記録で継続 DotHabit 運動・勉強(16,610) | 同上 |
| 時間管理 | 除外 | 一日予定表(47,921) / 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / TimePod(443) | プランナー |
| 先延ばし | 除外 | 先延ばしタイプ診断(0) / タイムブロッキング OneFlow タスク管(43) / フォーカスチキン-トマトタイマー 自律学習タ(1,141) | ToDo系 |
| 自制 | 除外 | 手持手机弹幕(11) / 嗷呜猫狗食谱-自制猫饭狗饭喂养指南(4) / 英文法(1) | 汎用 |
| 我慢 | 除外 | Quitzilla(1,424) / Holdy(51) / 習慣記録で継続 DotHabit 運動・勉強(16,610) | 汎用 |
| 集中モード | 除外 | 集中｜勉強時間の記録・スマホ依存対策、資格学(132,765) / Flow(361) / Focus To-Do(35,234) | iOS機能名 |
| おやすみモード | 除外 | Necomi(3) / ShutEye(9,751) / おやすみ通知　就寝時間を通知でお知らせ(14) | iOS機能名 |
| 制限 | 除外 | スマホ依存対策Blockinスクリーンタイム(19,137) / アプリ制限 Zentime(1,351) / スマホ制限・スタロック｜アプリ制限・アプリロ(7,965) | 単語のみ |
| 依存 | 除外 | 依存症克服SNS クイットメイト QuitM(203) / スマホ依存対策Blockinスクリーンタイム(19,137) / Quitzilla(1,424) | 単語のみ |
| デトックス | 除外 | スマホ制限・スタロック｜アプリ制限・アプリロ(7,965) / スマホ依存対策Blockinスクリーンタイム(19,137) / スマホをやめれば魚が育つ(15,885) | 美容・食事系 |


### 日本の除外語（ネガティブ）

ブロックブラスト／ブロック パズル／ロブロックス／ブルーロック／広告ブロック／adblock／280blocker／ショートドラマ／日記／todo／タスク管理／時間割／睡眠アプリ／睡眠記録／筋トレ／ダイエット／食事 記録／体重／見守り／ペアレンタル／ファミリーリンク／子供／保護者／英語 勉強／韓国語 勉強／中国語 勉強／受験 英単語／勉強記録／studyplus／集中旅行者（指名CP以外）／継続する技術／瞑想／ストレス発散／おやすみモード／集中モード／通知／ラインスタンプ／youtube ダウンロード／twitter 動画 保存。

## 5. キャンペーン構造への落とし込み

### 5.1 市場×キャンペーン

docs/02c §5.2 の CP1〜CP4 を3市場に展開する。各ストアフロントは別キャンペーンにする（Apple Adsは国ごとに配信・入札が分かれる）。

| CP | 中身 | JP | US（GB/CA/AU/NZ/IE/SGも同じ語） | KR |
|---|---|---|---|---|
| CP1 ブランド防衛 | 自社名 exact | dopabreak／ドーパブレイク／ドパブレイク | dopabreak／dopa break | dopabreak／도파브레이크 |
| CP2-a 解決語（主力） | 表の「主力」 exact | スマホ制限／スクリーンタイム／アプリ制限／アプリロック／スマホ制限アプリ／スクリーンタイム制限／アプリ 時間制限／使用時間 制限／アプリ 使用時間／スマホ 制限 時間／スマホ ブロック／アプリ ブロック | screen time／screen time app／screen time control／screen time tracker／screen time blocker／reduce screen time／limit screen time／screen time limit／limit apps／app blocker／app blocker for iphone／block apps／app limit／app limits／block social media／social media blocker | 스크린타임／스크린 타임／스크린타임 줄이기／앱차단／앱 차단／앱 잠금／앱잠금／폰 잠금／핸드폰 잠금／앱 제한／앱 사용 제한／폰 사용 제한 |
| CP2-b 依存・やめたい（ニッチ） | 表の「ニッチ高CVR」 exact・低入札 | スマホ依存／スマホ依存症／スマホ中毒／デジタルデトックス／ドーパミンデトックス／SNS制限／SNS依存／SNSやめたい／スマホ やめたい／ショート動画 やめたい／tiktok 制限／スマホ 使いすぎ | phone addiction／phone addiction app／digital detox／dopamine detox／social media detox／block youtube／stop scrolling／stop doomscrolling／doomscrolling／doom scrolling／block reels／block shorts／reels blocker／shorts blocker／distraction blocker／phone usage／digital wellbeing／quit tiktok／quit instagram | 폰중독／폰 중독／스마트폰 중독／핸드폰 중독／디지털 디톡스／도파민／도파민 디톡스／숏폼 중독／쇼츠 차단／릴스 차단／유튜브 차단／sns 차단／sns 중독／폰 사용시간／사용시간 줄이기／폰 끊기／폰 줄이기 |
| CP2-c 夜・寝る前（Pro訴求） | 夜だけ強化のCPPへ着地 | 夜 スマホ／寝る前 スマホ／夜ふかし／夜更かし／睡眠 スマホ | （英語は極小。Search Matchで発掘） | （極小。Search Matchで発掘） |
| CP2-d 広い語（単独テスト） | 主力に混ぜない。1語1広告グループ・上限は§5.2の下限（JP ¥65／US $0.5） | 集中 | focus | （該当なし。집중は圏外） |
| CP3 競合指名 | 表の「競合指名」 exact | スマホをやめれば魚が育つ／すまやめ／forest／opal／focus flight／集中旅行者／blockin／スタロック／one sec | opal／brick／forest／screenzen／one sec／bepresent／unrot／clearspace／refocus／jomo／flora／focus plant／appblock／blocksite／freedom／roots／unpluq／dumb phone／brainrot／sociallite／unglue／study bunny（GB）／focustown（GB） | 잠글시간／터닝／지키자／락체스트／포레스트／forest／focus flight／focustown／집중 식물／열품타（低入札）／opal／원섹／one sec／blockin |
| CP4 Discovery | Search Match ON＋主力語のbroad。予算10% | スマホ制限／スクリーンタイム／スマホ依存 | screen time／app blocker／phone addiction | 스크린타임／앱 차단／폰중독 |

- CP2はさらに広告グループを a／b／c／d に分け、検索語レポートを群ごとに読む。CPP（カスタムプロダクトページ）は a＝制限・スクリーンタイム、b＝依存・やめたい、c＝夜だけ強化、d＝ディープフォーカス で分ける。
- この表のCP2-b/CP2-c/CP3は初回に載せる語だけを書いた。全語は§2〜4の表の判定列（ニッチ高CVR／競合指名）を正とし、初回の採算が見えたら順に足す。
- 競合指名は「ブロック型で挫折した人へ」のCPP-Cへ着地させる（02c §5.2）。열품타・study bunny・魚が育つ は学生層で課金力が低い可能性があるため、単独の広告グループで採算を見る。

### 5.2 入札上限の導き方（推定・02c §1.2の式をそのまま各市場の価格に当てる）

02c §1.1〜1.2 の式: 期待LTV＝年額×手取り85%×更新継続（1/(1−60%)＝2.5年）、許容CAC＝LTV÷3、ASA exact の install→有料 6〜8%、タップ→install 30〜40%。

| 市場 | 年額（docs/15） | 期待LTV | 許容CAC | 許容CPI | 許容CPT（上限） |
|---|---|---|---|---|---|
| JP | ¥4,980 | ≒¥10,500 | ¥3,500 | ¥210〜280 | **¥65〜110**（02c確定値） |
| US | $39.99 | ≒$85 | ≒$28 | $1.7〜2.3 | **$0.5〜0.9** |
| KR | ₩49,000 | ≒₩104,000 | ≒₩34,700 | ₩2,100〜2,800 | **₩620〜1,100** |

US・KRは同じ式で換算した推定値であり、実勢CPTではない。実際のCPTは配信2週で計測し、§5.4の剪定基準で切る。screen time／opal／brick／集中／열품타 のように上位が数万評価の語は上限に張り付きやすいため、上限を超えたら入札を上げずに外す。

### 5.3 初回実験（日本・9/11媒体順序案の修正）

- 主力（CP2-a）: スマホ制限／スクリーンタイム／アプリ制限／アプリロック／スマホ制限アプリ／スクリーンタイム制限／アプリ 時間制限／使用時間 制限／アプリ 使用時間／スマホ 制限 時間／スマホ ブロック／アプリ ブロック の12語をexact。上限CPT ¥100（02c §5.2のCP2と同じ）。9/11案の「アプリブロック」「スクリーンタイム制限」はここ。
- 依存・やめたい（CP2-b）: スマホ依存／スマホ依存症／スマホ中毒／SNS制限／SNS依存／SNSやめたい／スマホ やめたい／デジタルデトックス をexact。9/11案の「スマホ依存」はここ。上限CPT ¥80。「ドーパミン」はJPの検索上位がトレカのDOPAなので初回は外す。
- 夜（CP2-c）: 夜 スマホ／寝る前 スマホ／夜ふかし／夜更かし。上限CPT ¥80。
- Discovery（CP4）: Search Match ON、スマホ制限／スクリーンタイム のbroad。上限CPT ¥60、予算10%（02c §5.2と同じ）。
- 「集中」は9/11案どおり主力に混ぜない。入れるなら上限¥65（§5.2の下限）の単独広告グループ（CP2-d）で、ディープフォーカスCPPへ着地させる。
- 02c §5.2からの変更点: CP2は一律¥100だったが、CP2-b/c（圏外語）は量も質も未検証なので¥80から始め、試用CPAが基準内なら¥100へ上げる。CP2-dの¥65は§5.2の許容CPTの下限に置いた。
- 指名（CP3）は初回実験から外し、主力の採算が見えてから足す（9/11案「競合指名を主力に混ぜない」に整合）。

### 5.4 週次運用

- 検索語レポートで圏外語の実ボリュームを取り、タップが付いた語をCP2-a/bのexactへ昇格する。
- 剪定: キーワード別にCPA(試用)≤¥1,000／CPA(有料)≤¥3,500を毎週見て切る（02c §5.2。US/KRは§5.2の許容CACを同じ比率で割った値）。CPTが§5.2の上限を2週連続で超えた語も停止。TTR<5%はスクリーンショット側の問題としてCPP改修へ回す。
- 除外語は市場ごとの一覧（§2〜4）をキャンペーン単位で **exact** で登録する。broadで登録すると「차단」のような部分語が 앱 차단／쇼츠 차단 の主力群まで止めるため、単語だけの除外はexact限定にする。Search Matchで拾った不一致語を毎週追加する。

## 6. 限界と次のアクション

- 圏外語（悩み語のほぼ全部）の実ボリュームはAPIでは測れない。配信して検索語レポートで測るしかない。
- 競合の評価数は公開検索の上位のみで、実際のApple Adsの入札者や広告表示シェアではない。Apple Ads側の「Impression Share」レポートは配信開始後に使う。
- 競合欄は全語取得済み（2026-09-12再取得）。ただし公開検索の上位は日々入れ替わり、評価数も増えるため、配信直前に `output/asa/2026-09-11-keyword-research/README.md` のコマンドで取り直す。
- 出稿・キャンペーン作成はオーナー承認後。1.0.1（計測SDK入り）が審査通過・公開されてから開始すると、キーワード→試用→初回課金の帰属が最初から取れる（docs/marketing/2026-09-11-apple-ads-measurement-setup.md）。
- 公開前に作れるもの: PAUSED状態のキャンペーンとキーワード登録。作成すると管理画面でキーワード別の人気度（5段階）も見えるようになる。作成自体が承認対象。

## 7. 証跡

`output/asa/2026-09-11-keyword-research/`
- `popularity-weekly/stp_<国>.tsv`: 週次人気度の全件（語・ジャンル・順位・1-100・1-5・ジャンル内指数）
- `popularity-monthly/stpm_<国>.tsv`: 月次（US/GB/KR/JP）
- `candidates_EN.tsv` / `candidates_KR.tsv` / `candidates_JP.tsv`: 候補語×市場の実測値（週・月・ジャンル）
- `competition/comp_<国>.tsv`: 候補語ごとの公開検索上位（アプリ名・評価数・評価点）
- `queries/`: APIへ投げたリクエスト本文の例
- `README.md`: 再取得コマンド
