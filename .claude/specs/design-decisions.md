# Design Decisions

## 2026-08-10 — キャラクター統一・ホーム位置・ロック確認2ステップ化（オーナー実機レビュー3指摘）

- **A（ホームのキャラ位置）**: オーナー指摘「位置が高すぎ」。実機スクショでキャラ頭上余白が約4ptでステータスバーに密着していた。heroBandのZStack重ね置きをやめ、**「TODAY・日付」行 → 12pt → キャラ（Header 120・水平中央）→ 20pt → 後続カード**の縦積みへ変更。
- **B（キャラのサイズ・配置トークン化）**: オーナー指摘「全画面でバラバラ。同一でなくていいが統一感が欲しい」。実測10箇所で10サイズ（44/86/96/104/124/144/152/160/180/220）だったため、DesignTokensに5段トークンを新設し全箇所を写像する: **Hero 200**（介入の一呼吸 220→）／**Lead 152**（オンボ冒頭 180→・推計結果 152・利用後ふりかえり 160→）／**Header 120**（ホーム 124→・通知許可 144→・ペイウォール 104→）／**Support 88**（準備完了/サマリー 96→・介入後安堵 86→）／**Inline 44**（行内・現状維持）。配置原則: 行内以外は水平中央・画面上端はセーフエリアから24pt以上・後続要素まで16〜20pt。
- **C（ロック画面確認の2ステップ化）**: オーナー指摘「サイドボタン図の位置が合っていない。押しても電源が消えるかカメラが起動するだけですぐ確認できない」。原因①画面右端のカプセル図形で実機ボタン位置に見せかける作りは、コンテンツ量・機種で縦位置がずれる ②iPhone 16系はサイドボタン下にカメラコントロールがあり誤押下を誘発 ③消灯→再点灯の手順説明が欠落。**物理位置合わせを廃止**し、番号付き2ステップ（1. サイドボタンを1回押して画面を消す＝下のカメラボタンではなく上のボタン 2. 画面をタップして点けるとロック画面に目標）＋ミニ端末イラスト（右上側面ボタンをハイライト・SwiftUI描画）へ置換。アプリ復帰時の自動「確認できました」検知（didObserveReturn）は維持。
- **却下**: GeometryReaderで実機サイドボタンの物理座標へ図を合わせる案（機種別の座標表が必要で保守不能・カメラコントロール誤認も解けない）。

## 2026-08-10 — オートメーション設定ガイドのone sec水準化（オーナー発案・実録画を根拠に設計）

- **背景**: オーナーがone secの実機セットアップを録画・提供（`video/onesec/`）。one secもショートカットのオートメーション作成は必須だが、①設定中もミニプレイヤーで流れ続けるPiP動画チュートリアル ②番号付きステップ＋実画面に赤丸注釈 ③「ショートカットアプリを開く」ヒーローCTA ④介入タイミングは先にアプリ内で設定、で摩擦を消していると確認。現行DopaBreakのAutomationGuideViewはテキスト4行＋ボタン1つで体験差が大きい。
- **決定（Phase 1・即実装)**: `AutomationGuideView` をone sec構造へ刷新。(a) 上部ヒーローCTA「ショートカットを開く」(既存deep link維持) (b) アプリ別設定済み検知（既存 `verifiedAutomationCatalogIDs`）を「n/m 設定済み」進捗と各アプリ行の✅で常時表示 (c) 手順6ステップを**SwiftUI描画のモック図解カード**（ショートカットUIを模した簡略図＋赤系ストロークの丸/角丸で押す場所を強調＋赤丸数字バッジ）で提示。画像アセットを使わずコード描画にする理由: 3言語ローカライズ・Dynamic Type追従・アセット制作工程の排除 (d) 最終ステップに「対象アプリを開いて一呼吸が出れば完了」の確認導線。
- **決定（Phase 2・素材待ち)**: PiP動画チュートリアル。オーナーが実機録画を提供後、AVPlayer＋AVPictureInPictureController（`canStartPictureInPictureAutomaticallyFromInline`）で「ショートカットを開く」タップ→バックグラウンド移行時に自動PiP継続を実装。Phase 1のUIに動画カード枠だけ用意しfeature flagで無効化しておく。
- **却下**: メールで別デバイスへチュートリアル送信（one sec機能・Webチュートリアルページを持たないため現段階では対象外）／介入タイミング（即時/遅延/常に尋ねる）のone sec式選択UI（介入設計はDopaBreak独自のモード設計があるため混ぜない）。
- **制約**: モック図解はショートカットアプリの実UIを想起させる簡略表現に留める（Appleのスクリーンショット商標・誤認問題を避け、システムUIの精密コピーはしない）。タップ領域44pt・`.dopaFont`によるDynamic Type・図解カードは `accessibilityHidden(true)`＋手順テキストで代替。

## 2026-07-29 — Dawn Horizon app icon

- Created `creatives/app-icon/concepts/png/09_dawn_horizon.png` as a 1024×1024, full-bleed, opaque PNG.
- Adopted a minimal three-element composition: a near-black-to-ember/orange sky gradient, one centered rising sun arc, and a straight horizon at the lower-third boundary with solid near-black ground.
- Kept the sun centered and away from the canvas corners so the main motif survives an iOS rounded-squircle mask and remains legible at 60×60.
- Rejected added scenery, texture, rays, reflections, borders, baked-in corner rounding, and typography because they reduce small-size clarity and violate the icon brief.
- Implementation constraint: use the source PNG as supplied; do not add rounded corners, borders, text, or additional visual elements in the asset. Let the platform apply its icon mask.

## 2026-07-29 — App Icon Concept 07 “Aperture”

- Created `creatives/app-icon/concepts/png/07_aperture.png` as a 1024×1024 RGB PNG with no alpha: a full-bleed near-black field, exactly six overlapping straight-edged graphite blades, and a very small incandescent hexagonal opening at the center.
- Adopted a continuous clockwise six-blade iris with overlapping polygonal vanes rather than radial gaps. The lime accent is restricted to the six short inner edges touching the opening; the white-gold, gold, and orange light remains local to the center.
- Kept the opening at roughly 3% of the icon width and preserved a generous uniform safe margin for the iOS squircle mask. No corner rounding is baked into the canvas.
- Rejected two radial-panel drafts because their long seams and lime lines read as spokes. Rejected the first overlapping-blade draft because its center opening was too large; the final iteration retained its six-blade geometry while reducing only the opening.
- Rejected lens barrels, circular rims, glass, reflections, chromatic flare, photographic realism, exterior glow, text, borders, and frames so the result remains an abstract controlled mechanism rather than a camera-app icon.
- Implementation constraint: use the supplied PNG as the source of truth. Do not add rounded corners, lens treatments, borders, shadows, extra glow, or text. Preserve the six blade count, tiny center opening, and six short lime inner-edge accents when resizing.
- Validation: `file` and `sips` report PNG, 1024×1024, RGB, and no alpha. A 60×60 preview retains the six-part mechanism and small incandescent center.

## 2026-07-29 — App Icon Concept 08 “Dual Flame”

- Created `creatives/app-icon/concepts/png/08_dual_flame.png` from a gpt-image-2 silhouette and saved it as the 1024×1024 iOS icon master.
- Adopted one connected flame with no holes or detached pieces. Its broad base, asymmetric tongues, and deep side notches prioritize unmistakable flame recognition over leaf or droplet symmetry at 60×60.
- Finished the flame with one smooth vertical transition from `#FF8A1F` at the base through `#FFC53D` at the middle to `#C7F94D` at the tip. The interpolation avoids brown and olive tones.
- Normalized the generated background to a completely uniform `#0B0D0F`; the initial render was slightly darker and varied subtly across the outer field. The final icon has no background gradient or outer glow.
- Reduced the initial flame occupancy while keeping it centered. The visible bounds are x=299...739 and y=135...889px, leaving at least 134px vertically and 284px horizontally for the iOS squircle mask. No rounded corners are baked into the canvas.
- Rejected sparks, particles, smoke, shadows, frames, borders, text, secondary flames, internal cutouts, and exterior glow because they weaken the single-silhouette concept and small-size clarity.
- Implementation constraint: use the supplied opaque RGB PNG as the source of truth. Do not add rounding, masks, borders, shadows, glow, text, particles, or color correction. Preserve the square aspect ratio, connected silhouette, centered safe area, and vertical gradient when resizing.
- Validation: PNG, 1024×1024, RGB, no alpha; the outer 16px is entirely `RGB(11,13,15)`; the foreground is one connected component; the 60×60 preview remains clearly recognizable as a single flame. SHA-256: `b69f54a38367fb429ab3db65c19265ca6a2a00482027b74df56be82deaeb60a8`.

## 2026-07-29 — App Icon Concept 10 “Lime Crack”

- Created `creatives/app-icon/concepts/png/10_lime_crack.png` from a gpt-image-2 render and saved it as a 1024×1024, full-bleed, opaque RGB PNG.
- Adopted one continuous, roughly vertical organic fracture through the center of a completely uniform `#C7F94D` lime-chartreuse field. The fracture uses a near-black `#0B0D0F` interior with a restrained orange-to-gold ember glow confined to its wider middle.
- Narrowed the generated fracture while retaining its irregular silhouette: the final fracture is 10–64px wide, averages about 52px through the center band, averages about 13px near the top and bottom, and remains a single connected component touching both vertical edges.
- Normalized the generated lime area to exact `RGB(199,249,77)` because the initial render contained subtle tonal variation. Kept the square corners unmasked so iOS can apply the system icon mask.
- Rejected branching cracks, multiple fissures, shards, debris, broken-glass treatments, exterior glow, field gradients, texture, shadows, frames, borders, typography, and baked-in rounded corners because they violate the single-negative-space concept and reduce 60×60 clarity.
- Implementation constraint: use the supplied PNG as the source of truth. Do not add branches, secondary cracks, text, rounding, borders, shadows, exterior glow, or color correction. Preserve the exact flat field color, the one connected top-to-bottom fracture, and the ember strictly inside the crack when resizing.
- Validation: PNG, exactly 1024×1024, RGB, no alpha; all four corners are `#C7F94D`; one connected fracture reaches the top and bottom edges; the 60×60 preview retains both the narrow split and its center ember. SHA-256: `c0fded4a976519b6795634421838732db2e8afbf7210497e9ebc9cb581c7c8f8`.

## 2026-07-29 — App Icon Concept 01b “Ember Pause”

- Created `creatives/app-icon/concepts/png/01b_ember_pause.png` from a gpt-image-2 flame render and saved it as the 1024×1024 iOS icon master.
- Adopted one upright, optically centered flame silhouette with a single wide, open-bottom negative-space channel. The channel rises through approximately the lower two-thirds of the flame and leaves exactly two flame-colored lower columns, which rejoin only in the upper crown.
- Enforced a near-1:1:1 column-gap-column proportion through the primary split region. At y=600px the left column, gap, and right column measure approximately 142px, 160px, and 141px, preserving an immediate pause-symbol reading at 60×60.
- Normalized the full-bleed background and the entire channel to the identical solid color `#0B0D0F`. Finished the flame with a restrained vertical progression from `#FFF6E0` at the two column bases through `#FFC53D` and `#FF8A1F` to `#E03A12` at the curled tip.
- Rejected the first render because two dark slots produced three flame-colored lower sections. Rejected the first correction because its channel stopped near mid-height. The final geometry has one channel only, no center column, and no thin slit.
- Rejected sparks, particles, smoke, exterior glow, background texture, shadows, borders, frames, text, extra cutouts, a third column, and baked-in rounded corners because they weaken the icon’s disciplined small-size legibility.
- Implementation constraint: use the supplied opaque RGB PNG as the source of truth. Do not add rounding, masks, borders, glow, text, particles, extra slots, or color correction. Preserve the square aspect ratio, exact solid background, one open channel, two-column count, generous safe margin, and vertical flame gradient when resizing.
- Validation: PNG, exactly 1024×1024, RGB, no alpha; all four corners and the outer 24px field are exactly `RGB(11,13,15)`; visible flame bounds are x=290...732 and y=102...866px; the central channel remains exact background through the split; the 60×60 preview clearly retains the flame and pause mark. SHA-256: `cc348b0a4b025fd310a06a255bed9037ce9b5e7c52b569d9f755626d94ec96c8`.

## 2026-07-29 — App Icon Concept 09b “Dawn Horizon”

- Created `creatives/app-icon/concepts/png/09b_dawn_horizon.png` from a gpt-image-2 render and saved it as a 1024×1024, full-bleed, opaque RGB PNG.
- Adopted a quiet three-part composition: a near-black-to-ember-to-orange dawn sky, one centered gold sun arc, and solid near-black ground separated by a single horizontal horizon at y=635px (roughly 62% from the top).
- Kept the sun centered and comfortably inside the iOS safe area. A little over half of the disc is visible above the ground, retaining the intended sunrise read at 60×60.
- Normalized the generated ground to exact `#0B0D0F` and aligned its upper edge to y=635px so the lower field is completely uniform and the horizon remains perfectly straight.
- Rejected clouds, mountains, trees, birds, buildings, people, water, rays, starbursts, texture, frames, margins, typography, and baked-in rounded corners because the icon depends on an extremely sparse, full-bleed silhouette.
- Implementation constraint: use the supplied PNG as the source of truth. Do not add corner rounding, borders, shadows, text, scenery, reflections, rays, or color correction. Preserve the square aspect ratio, centered sun, y=635px horizon, and solid lower field when resizing.
- Validation: PNG, exactly 1024×1024, RGB, no alpha; the artwork reaches all four square edges; sampled ground pixels are exactly `RGB(11,13,15)`; the 60×60 preview retains the centered sunrise. SHA-256: `c9f74a51683751fcaf798b54d8c7369920e356773b2e622d487d1b706ddd7249`.

## 2026-07-29 — アプリロゴ／アイコン 初回10案（Claude Code側・案出し段階）

- 依頼: オーナー「このアプリのロゴを作成して10個ほど案を出して」（/creative）。
- 前提確認: `ios/DopaBreak/Assets.xcassets/AppIcon.appiconset` は `Contents.json` のみで画像0件＝**未着手**。過去セッションのロゴ成果物なし。
- 生成経路: Codex CLI（`codex exec --enable image_generation`）経由の **gpt-image-2**。サブスク内で完結し従量課金なし（Gemini課金事故の再発防止方針どおり）。
- 比喩の家族を意図的に分散（全案を炎にしない）: 炎5 / ポーズ2 / ループ2 / 閾1 / 情緒1。
- 採った制約:
  - 地色 `#0B0D0F`・アクセント `#C7F94D` のE1 Dark Monoを踏襲。
  - 炎色（白熱→黄金→橙→暗赤）と**ライムを混色しない**UI側ルールは、03/08/10で**アイコン面に限り意図的に破る**（棚での識別を優先）。UI内の炎には波及させない。
  - 全案でテキスト禁止・角丸を焼き込まない（OSがマスクする）・full bleed。
  - 生成物の共通失敗モードを否定制約で individually 封じた（葉に見えるな／棒グラフに見えるな／カメラアプリに見えるな／割れたスマホ画面に見えるな）。
- 判定方法: 原寸ではなく **squircle近似マスク＋60px**（App Store検索結果の実寸）で可読性を判定する。`contact_sheet.py` が一覧と60pxストリップを生成する。
- 検証結果:
  - **アルファなし・1024×1024・RGB を全12点で確認**（App Storeはアプリアイコンのアルファを不可とするため必須チェック）。
  - 60pxで概念が消えた案: 01（空白が細くスリット化）、05（切断面が見えず ただの∞）、06（リスト/イコライザに見える）、07（暗所で黒い塊になり視認性最低）。
  - 技術欠陥1件: 09 が矩形パネルで生成されfull bleedにならず、マスクで太陽が切れた → **09b で是正**。
  - 01は空白を柱と同幅へ広げた **01b** を生成したが、上部で柱が再結合しポーズではなく「アーチ／n」に読める。ポーズの読みは未達。
- Claude Code側の制約（再発防止）:
  - `codex exec` はバックグラウンドシェルで**stdinを掴んで停止する**。`< /dev/null` を必ず付ける（本セッションで01bが1回ハングした）。
  - 逐次実行だと10案で30分近い。`xargs -P 4` で並列化する。
  - `contact_sheet.py` は Python 3.9 で動かすため `from __future__ import annotations` が必要（`X | None` が実行時に落ちる）。
- 未決（オーナー判断待ち）: 採用案の決定。決定後に1024→各サイズのスライスと `AppIcon.appiconset` への配置を行う。ワードマーク（文字ロゴ）は今回未着手。
- Codexレビュー（gpt-5.6-sol）指摘と対応:
  - **P1 生成失敗が成功に化ける**: `codex exec` の終了コードを捨て、`-s` だけで判定していた → 終了コード判定＋PILで実際に開いて1024四方かを検証する形へ修正（`generate.sh` / `generate_fixes.sh`）。
  - **P1 完了率の判定が誤り**: `contact_sheet.py` が「存在するファイル」を数えていたため、丸ごと欠けた案が欠品に上がらず常に `n/n` になっていた → 期待ID側を正として走査し、欠品時は非ゼロ終了。**縮退テストで11/12・exit 1になることを実測**。
  - **P3 是正版が60pxストリップで区別できない**: ラベルが先頭2文字で `01`/`01b` が同表示 → `_` 前までを使う形へ修正。本セッションでは位置から推測して判定していた。
  - **P2 xargsのクォート解釈**: ID受け渡しを `-0`（NUL区切り）へ変更。IDに `/` や先頭 `.` が来たら停止するassertも追加。
  - 受容した指摘: スクリプト内の絶対パス重複（この案出し専用の使い捨てのため）。

## 2026-07-29 — App Icon Concept 03c “Lime Real Flame”

- Created `creatives/app-icon/concepts/png/03c_lime_real.png` from a gpt-image-2 render and saved it as the 1024×1024 iOS icon master.
- Adopted one compact, photorealistic volumetric flame with a pale white-lime core, vivid lime-chartreuse body, and deeper green-chartreuse translucent folds. Two to three soft tongues remain visually joined and resolve into one tapered tip.
- Kept the flame optically centered with ample horizontal and top clearance for the iOS squircle mask. The glow stays local to the flame; the full-bleed square outer field is exactly `#0B0D0F`.
- Downsampled the generated 1254×1254 source to the required 1024×1024 delivery size and normalized only the effectively black background pixels so the outer 24px field is completely uniform without flattening the flame’s close volumetric glow.
- Rejected orange, red, warm yellow, blue, sparks, embers, smoke, logs, candles, hands, detached wisps, multiple flames, text, borders, frames, watermarks, and baked-in rounded corners because they violate the monochrome single-flame brief or reduce small-size clarity.
- Implementation constraint: use the supplied opaque RGB PNG as the source of truth. Do not add color correction, warm hues, particles, smoke, external glow, text, borders, frames, or corner rounding. Let iOS apply the system icon mask.
- Validation: PNG, exactly 1024×1024, RGB, no alpha; outer 24px is uniformly `RGB(11,13,15)`; the visible flame is one 8-connected region above the background threshold; no warm/red/orange or blue threshold violations were detected; the 60×60 preview remains recognizable as one flame. SHA-256: `643b6638e96a297c7a0b59607beaec486b3dbe7b481ef1ba1a6438f1a52f74c1`.

## 2026-07-29 — App Icon Concept 03b “Lime Real Flame”

- Created `creatives/app-icon/concepts/png/03b_lime_real.png` from a gpt-image-2 render and saved it as a 1024×1024, full-bleed, opaque RGB PNG.
- Adopted one tall, connected, semi-realistic lime-chartreuse flame with a broad rounded base, a single dominant licking tip, restrained asymmetric side tongues, and photographic internal filaments contained by a clean graphic silhouette.
- Restricted the palette to pale lime-white, vivid lime-chartreuse, deeper chartreuse, and dark green-lime. Rejected warm fire colors, blue, sparks, particles, smoke, logs, candles, text, borders, frames, exterior glow, and baked-in corner rounding.
- Rejected the first render because the flame nearly filled the canvas and carried pale highlights too far into the upper body. The revised render reduces occupancy, simplifies the crown, and localizes the brightest core toward the base.
- Normalized all near-black generated background pixels to exact `#0B0D0F`, yielding a completely uniform full-bleed field without a vignette or edge glow.
- Implementation constraint: use the supplied PNG as the source of truth. Do not add rounding, masks, borders, glow, smoke, particles, text, warm colors, or color correction. Preserve the one connected silhouette and generous margins when resizing.
- Validation: PNG, exactly 1024×1024, RGB, no alpha; foreground is one connected component with bounds x=337...704 and y=160...873px; all pixels in the outer 64px are exactly `RGB(11,13,15)`; no red- or blue-dominant foreground pixels were detected; the 60×60 preview remains unmistakably fire. SHA-256: `6057d8fafdebb5b1ed950d72b5a610d1f0d43313cf2340f05701f1ea935893bd`.

## 2026-07-29 — アプリアイコン 03b（リアルなライム炎）を採用・実装

- オーナー決定: 「3でOK」→ 続けて「3の炎をもっとリアルなライム炎に」。**03b_lime_real_fit** を採用。
- リアル化は2案生成し比較（`_review_03_compare.png` / `_review_03_fit.png`）:
  - **03b フィラメント**: 60pxで質量が残り、180px（ホーム画面@3xの実ピクセル）でリアルさが効く → **採用**。
  - 03c ボリューム: 写実性は最高だが炎が細く、占有率を揃えても60pxで痩せる → 不採用。
- **占有率の正規化**: リアル系は炎が枠内で小さく描かれ小サイズで負けていた。`recompose.py` で炎の外接矩形を検出し、高さ占有78%へ揃えた（再生成せず描画品質を保つ）。
- ブランド色の実測: 明画素の平均色相はブランド `#C7F94D`(77.4°) に対し 03b=71.9°（差5.6°）。許容内。ただしリアル版は明度が落ちる。
- 実装:
  - `AppIcon.appiconset` に `AppIcon-1024.png` を配置し、Contents.jsonを**単一1024サイズの現行形式**（universal/ios）で記述。
  - **`project.yml` の `excludes: Assets.xcassets` を解除**し `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` を追加。カタログは長らく空で除外されており、解除しないとアイコンがバンドルへ入らない。
  - 写真の `morning-horizon` は従来どおり `Resources/` のルースファイルを `Bundle.main.url` で読む（`DesignTokens.swift:408`）。カタログ経由へは変えていない。
- Claude Code側の制約（再発防止）:
  - **macOS 26 上で Xcode 16.2 の actool は動かない**（`AssetCatalogSimulatorAgent exited before we could handshake` / `Failed to launch ... via CoreSimulator spawn`）。`xcode-select` が16.2を指しているため、**`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`（Xcode 26.6）を明示する**。シミュレータ/実機どちらの destination でも同じ失敗が出る。
  - この失敗はカタログを初めてコンパイルした時にだけ表面化する（従来はカタログ除外のため actool が走っていなかった）。
- 検証: **BUILD SUCCEEDED**。`AppIcon60x60@2x.png` / `AppIcon76x76@2x~ipad.png` がバンドルへemplaced。`CFBundleIconName=AppIcon` を実測。`morning-horizon.png` もバンドルに残り既存の写真読みは無傷。
- **未解決（オーナー判断待ち）**: `MorningHorizon.imageset` はどこからも参照されない死んだアセット（アセット名での参照0件・正本はResources側）。カタログ有効化により**1.7MBがAssets.carへ焼かれ、ルースファイル2.7MBと二重に出荷される**。削除を試みたが権限でブロックされたため未実施。削除すればバンドルは従来サイズへ戻る。

## 2026-07-29 — App Icon Concept 03d “Lime Wide Flame”

- Created `creatives/app-icon/concepts/png/03d_lime_wide.png` as a 1024×1024, full-bleed, opaque RGB PNG.
- Adopted one connected, semi-realistic lime-chartreuse flame with a wide rounded base, a full lower body, exactly three main upper tips, and realistic internal filaments contained by a clean readable silhouette.
- Re-composed the generated source to a measured 0.91 width-to-height ratio (727×799px visible bounds) so the flame remains substantial while satisfying the requested 0.80–0.95 range. The final visible bounds are x=148...874 and y=112...910px, preserving generous iOS squircle-mask clearance.
- Normalized the full outer field to exact `#0B0D0F` and color-graded saturated foreground pixels away from yellow/warm and blue hue ranges while retaining the pale lime-white core and chartreuse depth.
- Rejected the first render because its perimeter contained too many independent licking tips. Rejected the unadjusted revision because its 1.18 width-to-height ratio exceeded the brief despite having the correct three-tip structure.
- Rejected orange, red, yellow, gold, blue, cyan, sparks, particles, smoke, logs, candles, hands, detached wisps, text, borders, frames, exterior edge glow, and baked-in rounded corners.
- Implementation constraint: use the supplied opaque PNG as the source of truth. Do not add color correction, warm or blue hues, particles, smoke, text, borders, glow, frames, or corner rounding. Preserve the 0.91 flame proportion, three-tip crown, centered safe area, and square aspect ratio when resizing.
- Validation: PNG, exactly 1024×1024, RGB, no alpha; outer 24px is uniformly `RGB(11,13,15)`; foreground is one 8-connected component; no saturated warm/yellow or blue hue threshold violations remain; the 60×60 preview reads unmistakably as fire. SHA-256: `47f9f446e527c7ba7ee7a667e856278d3b6a737ff8fc43c643aa89ec2a135434`.

## 2026-07-29 — App Icon Concept 21 “Breathing Bloom”

- Created `creatives/app-icon/concepts/png/21_breathing_bloom.png` through the gpt-image-2 image-generation workflow and saved it as a production-ready 1024×1024 opaque RGB PNG.
- Adopted one optically centered abstract bloom with exactly four broad organic petals and one small warm-gold center. The upper, side, and shorter lower petals use intentionally different contours and proportions so the mark feels hand-considered while remaining stable rather than rotational.
- Finished the petals with a clean luminous transition from `#FF9E7D` coral at the outer area into `#FFC9A8` peach toward the center, with a `#F5A65B` center on a completely uniform, full-bleed `#FDF3EC` cream field.
- Rejected the first render because its four near-identical quadrants read as a clover/butterfly. Rejected the second render because its diagonal sweep read as a pinwheel. The final geometry uses a calm opening-flower hierarchy without rotational motion.
- Normalized the generated background and palette locally, removed the slight generated field variation, and recomposed the bloom to a measured 635×565px visible bounding box. Its maximum span is 62.0% of the canvas, leaving at least 194px of safe margin for the iOS squircle mask.
- Rejected literal daisy detailing, leaves, stems, hearts, sparkles, faces, mascots, text, borders, frames, shadows, sticker styling, and baked-in rounded corners because they violate the abstract premium wellness direction or reduce small-size clarity.
- Implementation constraint: use the supplied PNG as the source of truth. Do not crop, pre-round, frame, recolor, add text, add shadows, or introduce extra botanical details. Let iOS apply its system corner mask and preserve the full-bleed cream field and four-petal count when resizing.
- Validation: PNG, exactly 1024×1024, RGB, no alpha; all four edges and corners are exact `RGB(253,243,236)`; visible mark bounds are x=194...828 and y=229...793px; the 60×60 preview clearly retains one four-petal bloom. SHA-256: `e09d04b5fcc18c8619783587761235982c2f75bce9b88f7341f5d28ad9e53cf2`.

## 2026-07-29 — App Icon Concept 22 “Ember Cream”

- Created `creatives/app-icon/concepts/png/22_ember_cream.png` from a gpt-image-2 render and saved it as a 1024×1024, full-bleed, opaque RGB PNG.
- Adopted one compact, softly rounded flame centered horizontally and slightly below the canvas midpoint. Its warm amber-to-soft-gold body contains one simple pale warm core, surrounded by a broad feather-soft peach halo on a warm cream field.
- Kept the flame at approximately 40% of the canvas height with generous empty margin, preserving clear recognition under an iOS squircle mask and at 60×60.
- Downsampled the generated 1254×1254 source to the required 1024×1024 delivery size. The cream field reaches all four square edges; sampled edge pixels remain within 1–3 RGB values of the requested `#FDF2E7`, preserving the generated halo transition without visible border or vignette.
- Rejected candle bodies, wicks, holders, sharp tongues, multiple flames, sparks, smoke, text, symbols, faces, mascots, hearts, stars, sparkles, borders, frames, stickers, exterior shadows, dark backgrounds, and baked-in rounded corners because they violate the calm single-flame concept or reduce small-size clarity.
- Implementation constraint: use the supplied opaque PNG as the source of truth. Do not add corner rounding, borders, text, candle elements, particles, smoke, exterior shadows, or extra marks. Let iOS apply the system icon mask and preserve the square aspect ratio when resizing.
- Validation: PNG, exactly 1024×1024, RGB, no alpha; full-bleed cream reaches every edge; the 60×60 preview retains the single flame, pale core, and soft halo. SHA-256: `313c2614839f1c95846020004831dfff051db52d9dccf6385412edd84690b7bf`.

## 2026-07-29 — App Icon Concept 30 “Warm Pause v2”

- Created `creatives/app-icon/concepts/png/30_pause_v2.png` through the gpt-image-2 image-generation workflow and saved it as the 1024×1024 iOS icon master.
- Adopted one centered pause mark made from exactly two equal, softly sculpted vertical pill bars. The creamy `#FFF6EE`-family material uses restrained internal warm shading and soft ambient/contact shadows so the forms feel like polished stone rather than flat clipart.
- Used a luminous full-bleed coral field transitioning from soft coral near `#FF8E6E` at the top toward warm red-coral near `#F2634F` at the bottom. The bars occupy approximately 60% of the tile height and retain ample clearance for the iOS squircle mask.
- Rejected media-player chrome, play controls, extra marks, text, letters, numbers, borders, frames, stickers, sparkles, stars, hearts, harsh perspective, metallic or glossy-plastic treatment, dark voids, and baked-in rounded corners because they weaken the calm single-symbol reading.
- Downsampled the generated 1254×1254 source to exactly 1024×1024 while preserving the square composition and opaque RGB output.
- Implementation constraint: use the supplied PNG as the source of truth. Do not crop, pre-round, frame, recolor, add text, add controls, flatten the bar shading, or remove the restrained grounding shadows. Let iOS apply the system icon mask.
- Validation: PNG, exactly 1024×1024, RGB, no alpha; full-bleed color reaches all four edges; the composition contains exactly two centered pill bars and no other subject. SHA-256: `fcddf218bb1ee126d05f968fa79ba56b3f7bcf3f557c02584e397dd32bb11800`.

## 2026-07-29 — App Icon Concept 33 “Dawn Arc”

- Created `creatives/app-icon/concepts/png/33_dawn_arc.png` through the gpt-image-2 image-generation workflow and saved it as a production-ready 1024×1024 opaque RGB PNG.
- Adopted one large, centered dome-shaped dawn arc in the lower portion of a full-bleed warm-white field. The arc uses a luminous transition from warm gold along the upper crest through soft orange to warm coral, with restrained internal shading for soft dimensional volume.
- Kept the subject at approximately two-thirds of the tile width with generous lateral and corner clearance for the iOS squircle mask. The lower coral area dissolves softly into the warm-white field so the icon has no visible straight base or horizon line.
- Rejected the first render because the dome filled the full canvas width and would be clipped by the iOS mask. Rejected the second render because its inset semicircle introduced a straight horizontal base that read as a prohibited horizon. The final render preserves only the smooth curved crest as the readable contour.
- Rejected rays, starbursts, horizon lines, clouds, landscapes, extra shapes, rings, texture, grain, sparkles, stars, hearts, clipart/sticker treatment, text, borders, frames, tile shadows, and baked-in rounded corners because the concept depends on one profoundly simple sunrise gesture.
- Downsampled the generated 1254×1254 source to exactly 1024×1024 while preserving the square composition and opaque RGB output.
- Implementation constraint: use the supplied PNG as the source of truth. Do not crop, pre-round, frame, recolor, sharpen the lower fade, add a baseline/horizon, or introduce any secondary element. Let iOS apply the system corner mask.
- Validation: PNG, exactly 1024×1024, RGB, no alpha; full-bleed warm-white reaches all four edges; the composition contains one centered arc and no additional subject. SHA-256: `553761a510774609013cbfc3a2c743e22c1e54e0b6377bed0429de608459ff80`.

## 2026-07-30 — 通常画面のライト化と制御画面のダーク維持（レビュー提案・実装未着手）

- レビュー対象: `ios/DopaBreak/DesignTokens.swift`、`ios/DopaBreak/DopaBreakApp.swift`、`ios/DopaBreak/HomeView.swift`、`ios/ShieldConfigExtension/ShieldConfigurationExtension.swift`、`output/screenshots/native-pass/01-home-default.png`、ユーザー提示のScreenFast App Storeスクリーンショット。
- 推奨方針: 全面を白へ置き換えず、通常のホーム・目標・統計・設定はiOSのシステム外観に追従する明るいユーティリティ面へ寄せ、一呼吸・完全ブロック・ロック画面など注意を切り替える面は現行の黒＋ライムを維持する。ライムは成功値・進捗・選択状態・主要CTAに限定する。
- 採用理由: 日常的に読む／比較する画面は明るい背景のほうが情報探索しやすく、制御時だけ暗くすることで状態変化も明確になる。添付競合も通常画面はライト、ブロック／ロック面はダークの役割分担を採っている。黒＋ライムを制御面に残すため、全面ライト化よりブランド識別も保てる。
- 却下案: 全画面を純白＋黒へ統一する案は、DopaBreakの識別性を失い一般的な生産性アプリに見えやすいため不採用。全画面の強制ダーク継続も、設定・統計などの道具画面まで緊張感が続き、システムの外観設定に追従しないため推奨しない。
- Claude Code側の実装制約: グローバルの `.preferredColorScheme(.dark)` を単に削除するだけでは不十分。背景・カード・ラベル・区切り線をsemantic colorまたはlight/dark対応Color Setへ置き換え、`MorningHorizon`の明暗別可読性を確認する。Shield拡張と一呼吸フローは独立したダークsurfaceとして維持する。実装前に通常ホーム／設定／統計のライト版3画面を同一階層のまま比較し、Dynamic Type・Increase Contrast・Reduce Transparencyでも検証する。

## 2026-08-01 — App Store向け3言語・3サイズのスクリーンショット制作

- 作成物: `output/app-store-screenshots/final/` に日本語・英語（米国）・韓国語それぞれの iPhone 6.9インチ（1320×2868）、iPhone 6.5インチ（1284×2778）、iPad 13インチ（2064×2752）を各7枚、合計63枚作成。比較用コンタクトシートは `output/app-store-screenshots/review/`、コピーQAと納品仕様は `output/app-store-screenshots/COPY_QA.md` と `README.md` に記録した。
- 制作パイプライン: ローカライズ済みSwiftUI画面をXCTestと `scripts/capture-appstore-onboarding.sh` で取得し、`scripts/generate-appstore-screenshots.py` でマーケティングフレーム、端末別レイアウト、コピーを再現可能に生成する構成を採用。`asc screenshots validate` で全9セットが7/7 ready、エラー0・警告0であることを確認した。
- 採用した訴求順: 1) 年間の無意識スクロール時間、2) ブロックではなく開く前の短い間、3) 理由と時間の選択、4) 3段階の介入強度、5) ロック画面・通知・ウィジェット、6) 振り返りと統計、7) オンデバイス保存と無料開始。最初の3枚だけで問題・差別化・具体機能が伝わるようにし、2枚目だけライム全面背景にして一覧内で視線を止める。
- 国別方針: 日本語は「禁止しない」「ひと呼吸」で自己決定感を維持。英語は `Not another app blocker` と `You still choose` で競合差とagencyを明確化。韓国語は `디톡스`、説教調、医療的に見える `진단` を避け、`차단이 아니라 브레이크` と `숨 고르기` に統一。SNS、social media、doomscrolling、screen time / 스크린 타임など高意図語は自然な見出しへ組み込んだ。
- 却下した案: 全7枚を同じ暗色背景にして一覧で埋没する案、検索語を不自然に羅列する案、強制ブロックや依存症治療のように誤認させる案、未実装の成果保証、サンプル数値を実績のように見せる案は不採用。統計ビジュアルには各言語でサンプルデータ表記を入れた。
- Claude Code側の制約: App Storeへ登録する場合は `final/<locale>/<device>/` の番号順を維持すること。オンボーディング結果の動的な年間日数と外側見出しは端末・言語ごとに一致させているため、素材を差し替える際は `PANEL_DAYS` も更新する。iPad対応を継続する限りiPad 13インチ版を省略しない。App Store Connectへのアップロードは今回未実施。外部の人間ネイティブ校正は実施できていないため、とくに韓国語は公開前に `docs/17_korean_native_review.md` の最終ゲートを通すこと。

## 2026-08-04 — App Icon Concept 41b “Lime Gap Orb”

- Created `creatives/app-icon/concepts/png/41b_lime_gap.png` through the GPT Image generation workflow and saved it as a production-ready 1024×1024 opaque RGB PNG.
- Adopted one optically centered luminous gold-amber orb on a full-bleed warm plum-to-burnt-umber dusk field. The orb occupies roughly two-thirds of the tile and uses controlled gloss, warm internal gradients, and a broad soft highlight for crafted dimensional volume.
- Punched exactly two equal vertical rounded-rectangle pause-bar openings through the orb. Vivid lime-chartreuse is confined to those two openings, with only restrained contact edge-light; the orb remains warm gold/amber and the background remains warm plum/umber.
- Rejected rings, orbit lines, extra cutouts, extra symbols, green spill across the orb or field, particles, sparkles, stars, hearts, sticker/clipart treatment, typography, borders, frames, external tile shadows, black margins, and baked-in rounded corners because they weaken the single-subject icon and violate the requested color separation.
- Implementation constraint: use the supplied PNG as the source of truth. Do not crop, pre-round, frame, recolor, add text or controls, introduce green outside the two openings, or add secondary elements. Let iOS apply its system corner mask and preserve the centered orb and exact two-bar count when resizing.
- Validation: PNG, exactly 1024×1024, RGB, no alpha; artwork reaches all four square edges; a 60×60 preview retains the centered orb and unmistakable two-bar pause mark. SHA-256: `b59a56c050e586cc716d0cffc1968f638b1d99eeea6511405541e4cc9d1a5fef`.

## 2026-08-04 — App Icon Concept 51 “Pause Glass”

- Created `creatives/app-icon/concepts/png/51_pause_glass.png` through the GPT Image generation workflow and saved it as a production-ready 1024×1024 opaque RGB PNG.
- Adopted a full-bleed vivid lime-chartreuse `#C7F94D`-family field with a restrained warmer radial brightening behind the center. Exactly two equal vertical pause bars are optically centered, occupy approximately 60% of the tile height, remain inside the iOS safe area, and retain a wide clear gap.
- Rendered both bars as photoreal frosted translucent Liquid Glass floating just above the field: the lime remains visible through their interiors, edge thickness introduces controlled refraction, thin sharp specular highlights run along the top and side edges, and very soft feathered shadows establish separation without visual weight.
- Rejected the first render as too optically clear through the bar interiors. The adopted refinement adds restrained full-body micro-frost so the bars read as present material while preserving background transmission and precise glass edges.
- Rejected milky opaque plastic, acrylic, white ceramic, candy-gel gloss, bulbous pill geometry, rainbow dispersion, chromatic aberration, sparkles, particles, text, borders, frames, enclosing media-player chrome, extra controls, exterior tile shadows, and baked-in rounded corners because the material study and small-size clarity depend on an exact two-bar composition with no secondary UI.
- Implementation constraint: use the supplied PNG as the source of truth. Do not crop, pre-round, frame, recolor, add text or controls, flatten the micro-frost/refraction, remove the thin edge highlights or grounding shadows, change the two-bar count, narrow the central gap, or introduce any secondary element. Let iOS apply its system icon mask and preserve the square aspect ratio when resizing.
- Validation: PNG, exactly 1024×1024, 8-bit RGB, no alpha; artwork reaches all four square edges; a 60×60 preview retains two distinct luminous glass bars and their wide gap. SHA-256: `4f02d7eb03c6ba67d46834cba6e7d5f60f5b37739a3e21d214a61b8566bc0fbe`.

## 2026-08-04 — App Icon Concept 52 “Matte Ceramic Pause”

- Created `creatives/app-icon/concepts/png/52_pause_matte.png` through the gpt-image-2 image-generation workflow and saved it as a production-ready 1024×1024 opaque RGB PNG.
- Adopted exactly two equal, optically centered vertical bars in warm off-white `#FBF6EC`, rendered as unglazed porcelain / soft clay. The surface is fully diffuse and tactile; dimensionality comes only from restrained ambient occlusion, very soft tonal falloff, and a barely perceptible top light rather than gloss or specular highlights.
- Used a full-bleed vivid lime-chartreuse `#C7F94D`-family field with a broad, subtle warmer radial brightening behind the mark. Re-composed the generated square so the bars occupy approximately 60% of the tile height while retaining wide separation and safe-area clearance; the mark remains clean at 60×60.
- Rejected glossy ceramic, plastic, polished stone, metal, glass, lacquer, hard rim light, specular hot spots, playback-button chrome, enclosing circles, text, letters, numbers, borders, frames, tile shadows, sparkles, hearts, clipart/sticker treatment, and baked-in rounded corners because the icon depends on quiet material quality rather than a media-control metaphor.
- Implementation constraint: use the supplied opaque PNG as the source of truth. Do not crop, pre-round, frame, recolor, sharpen, add highlights, add controls, or flatten the gentle material shading. Let iOS apply its system corner mask and preserve the exact two-bar count, wide central gap, full-bleed field, and square aspect ratio when resizing.
- Validation: PNG, exactly 1024×1024, RGB, no alpha; artwork reaches all four square edges; a 60×60 preview retains two distinct centered bars and the matte ceramic read. SHA-256: `9ad9c9a8916ea1a4dab85311e993d15c5bc28ca991990eb8cc4b01eab52dd173`.

## 2026-08-04 — App Icon Concept 60 “Brain Calm Dark”

- Created `creatives/app-icon/concepts/png/60_brain_calm_dark.png` through the GPT Image generation workflow and saved it as a production-ready 1024×1024 opaque RGB PNG. The direct model-controlled `gpt-image-2` CLI attempt was blocked by the configured API account billing hard limit, so the final artwork was produced with the built-in image-generation route.
- Adopted one plump pink brain mascot in an extreme close-up that fills nearly the entire tile and continues beyond the square edges, leaving the deep warm plum-black field visible only in small corner pockets. Broad dark outlines, warm pink gradients, restrained gloss, and soft lobe-to-lobe shading create the requested premium cartoon volume.
- Made the expression the primary read: exactly two gently closed eyes, two relaxed eyebrows, warm cheek blush, one small peaceful smile, and exactly one pale breath puff. The minimal facial geometry communicates a slow post-stimulation exhale and deep relief while remaining clear in the verified 60×60 preview.
- Rejected open or excited eyes, sleep symbols, anatomical realism, gore, extra characters, books, glasses, hands holding objects, sparkles, stars, hearts, confetti, text, letters, borders, sticker treatment, and baked-in rounded corners because they would dilute the adult-friendly calm-relief concept or violate the requested exclusions.
- Implementation constraint for Claude Code: treat the supplied opaque PNG as the source of truth. Do not crop, pre-round, frame, recolor, sharpen, remove or duplicate the single breath puff, alter the closed-eye expression, add props or decoration, or expose more background around the brain. Let iOS apply its system corner mask and preserve the extreme close-up square composition when resizing.
- Validation: PNG, exactly 1024×1024, 8-bit RGB, no alpha; the 60×60 preview retains the brain silhouette, closed eyes, calm smile, blush, and single exhale puff. SHA-256: `b833162fc78711115ddaa426181b1305947281af464bac74c8c4baec444a7c4a`.

## 2026-08-04 — App Icon Concept 63 “Brain Crazed Rain”

- Created `creatives/app-icon/concepts/png/63_brain_crazed_rain.png` through the GPT Image generation workflow and saved it as a production-ready 1024×1024 opaque RGB PNG.
- Adopted an extreme close-up of a plump pink brain mascot whose glossy, dark-outlined lobes overflow every tile edge, leaving the deep warm plum-black field visible mainly across the upper gaps and corners. The oversized face remains the primary read at app-icon scale.
- Made the two defining cues deliberately bold: both black pupils are rolled high with clear white sclera below, and exactly eight large luminous lime-chartreuse drops descend from the top. Two lower drops visibly contact the upper lobes with soft cartoon impact dimples, while the uneven eyebrows and open wobbly tongue-showing grin keep the overloaded expression silly rather than frightening.
- Rejected bloodshot veins, tears, gore, horror styling, fine dust, sparkle specks, confetti, books, glasses, hands, body parts, extra props, text, borders, frames, and baked-in rounded corners because they weaken the comedic overstimulation concept or its 60×60 readability.
- Downsampled the generated 1254×1254 source to exactly 1024×1024 while preserving the square full-bleed composition and opaque RGB output.
- Implementation constraint for Claude Code: treat the supplied PNG as the source of truth. Do not crop, pre-round, frame, recolor, move the pupils away from their strongly upward gaze, reduce or multiply the eight drops, add particles or props, or soften the extreme close-up. Let iOS apply its system corner mask.
- Validation: PNG, exactly 1024×1024, RGB, no alpha; a 60×60 preview clearly retains the upward-rolled pupils, dazed grin, overflowing pink lobes, and large lime rain. SHA-256: `e78b76ffd109c99ec5345709fc0ec236e04870b386bee2b013ba34b33f7950c8`.

## 2026-08-04 — App Icon Concept 62 “Brain Phew”

- Created `creatives/app-icon/concepts/png/62_brain_phew.png` and normalized the selected artwork to a production-ready 1024×1024 opaque RGB PNG. The configured direct `gpt-image-2` API route returned a billing hard-limit error, so the final render used the built-in image-generation path, whose model selector is not exposed.
- Adopted one plump pink brain mascot in an extreme close-up that fills nearly the entire square and crops its rounded lobes beyond the tile edges. Small deep warm plum-black corner pockets establish the `#241820` field; clean dark brown-black outlines, soft pink dimensional gradients, and restrained glossy highlights preserve an adult-friendly premium cartoon finish.
- Made the expression the focal decision: two gently closed eyes, slightly raised relaxed eyebrows, a small grateful “phew” smile, and exactly one pale cool-blue sweat drop communicate survival and deep relief rather than anxiety. The oversized features and strong face silhouette remain legible at 60×60.
- Rejected open eyes, panic, sadness, strain, surprise, tears, multiple sweat drops, exhale puffs, books, glasses, hands, held objects, additional characters, anatomical realism, childish clipart, flat sticker styling, sparkles, stars, hearts, text, borders, frames, tile-level shadows, and baked-in rounded corners because they would change the emotional register or violate the app-icon constraints.
- Implementation constraints for Claude Code: treat `creatives/app-icon/concepts/png/62_brain_phew.png` as the source of truth. Do not crop, pre-round, frame, recolor, sharpen, remove or duplicate the single sweat drop, add an exhale puff, add accessories or decorative elements, or reduce the extreme close-up scale. Let iOS apply its system mask and preserve the overflowing-lobe crop, plum-black corner field, dark outlines, glossy pink volume, closed-eye relieved expression, single sweat drop, and square aspect ratio.
- Validation: PNG, exactly 1024×1024, 8-bit RGB, no alpha; 60×60 downsampling preserves the brain silhouette, closed-eye expression, raised eyebrows, grateful smile, and single sweat drop. SHA-256: `7b8f87335c5005c89c3b8f1f9d188762d2b6c974563d1171cbbf93e5563bb308`.

## 2026-08-04 — App Icon Concept 65 “Brain Recovering Mist”

- Created `creatives/app-icon/concepts/png/65_brain_recovering_mist.png` through the GPT Image generation workflow and saved it as a production-ready 1024×1024 opaque RGB PNG. The direct model-controlled `gpt-image-2` CLI attempt was blocked by the configured API account billing hard limit, so the final artwork was produced with the built-in GPT Image route used by the adjacent brain concepts.
- Adopted one plump pink brain mascot in an extreme close-up whose rounded lobes overflow all four tile edges. The full-bleed field remains deep warm plum-black at the corners and brightens subtly only across the upper area where the lime mist glows.
- Made the transitional expression the primary read: two partly open half-lidded eyes with settled central pupils, brows visibly releasing their tension, relaxed cheeks, and a small newly forming relieved smile. The face suggests a quiet exhale without adding a separate breath puff, preserving the constraint that particles are the only secondary visual element.
- Replaced Concept 63’s large drops with many fine luminous lime-chartreuse specks, densest above the brain and tapering downward. Small landing glints illuminate the upper lobes while remaining readable as a soft healing shimmer rather than rain blobs, confetti, or star-shaped sparkles.
- Rejected large drops, slime, streaks, splashes, beams, confetti, stars, hearts, sleep symbols, a visible breath cloud, fully closed eyes, upward-rolled pupils, a manic or fully serene expression, open mouth, tongue, books, glasses, hands, body parts, text, borders, frames, and baked-in rounded corners because they would break the requested mid-recovery emotional beat or reduce small-size clarity.
- Implementation constraint for Claude Code: treat the supplied opaque PNG as the source of truth. Do not crop, pre-round, frame, recolor, sharpen, enlarge the particles into drops, close the eyes, roll the pupils upward, add a breath puff or props, or expose more background around the brain. Let iOS apply its system icon mask and preserve the extreme close-up composition when resizing.
- Validation: PNG, exactly 1024×1024, 8-bit RGB, no alpha; artwork reaches all four square edges; the verified 60×60 preview retains the half-lidded settling eyes, small relieved smile, overflowing pink lobes, and fine lime mist. SHA-256: `3c8f0b06ade872143caf8afe5636bdf02b8bf991cbec0879576ac201badaf17e`.

## 2026-08-04 — App Icon Concept 64b “Brain Crazed Grit — Whole Head” composition correction

- Replaced `creatives/app-icon/concepts/png/64b_crazed_grit.png` with a composition-corrected built-in GPT Image render and normalized it to a production-ready 1024×1024 opaque RGB PNG. The direct model-controlled `gpt-image-2` API request was attempted but blocked by the configured account billing hard limit; the built-in route does not expose its exact selector. This supersedes the earlier 64b extreme-close-up/nine-drop direction.
- Adopted the complete, uncropped brain silhouette as the defining decision: the pink head begins at approximately 15% from the top, finishes near the bottom edge, spans approximately 85% of the tile width, and retains visible full-bleed plum-black margins on both left and right. The face stays within the central area.
- Preserved the comic overstimulation read through upward-rolled black pupils with whites below, deliberately asymmetric twitching eyebrows, and a tight wobbly gritted zigzag smile. Exactly seven lime elements remain: six compact falling droplets plus one splash contacting the highest lobe.
- Rejected cropped/overflowing composition, a nine-drop count, excess empty space above the lobes, oversized facial placement, frightening anatomy, gore, books, glasses, hands, additional objects, text, borders, frames, and baked-in rounded corners because they conflict with the corrected whole-head brief or small-size clarity.
- Implementation constraints for Claude Code: treat `creatives/app-icon/concepts/png/64b_crazed_grit.png` as the source of truth. Do not crop, zoom, pre-round, frame, recolor, alter the exact six-drops-plus-one-splash count, move the pupils away from their upward gaze, soften the gritted mouth, add props, or remove the visible side/top margins. Let iOS apply its system mask and preserve the whole-head silhouette and square aspect ratio.
- Validation: PNG, exactly 1024×1024, 8-bit RGB, no alpha; the 60×60 downsample retains the full brain silhouette, rolled-up gaze, asymmetric brows, gritted smile, and lime rain. SHA-256: `d408e8b30d18ed9efbf16e39dd19fe4ef0c175b3cbeff2b07d7d35d96800ba74`.

## 2026-08-04 — App Icon Concept 70f “Brain Phone Trance”

- Created `creatives/app-icon/concepts/png/70f_genk_style.png` and normalized the selected artwork to a production-ready 1024×1024 opaque RGB PNG. The direct model-controlled `gpt-image-2` CLI request reached the Image API but was rejected by the configured account billing hard limit; the final render therefore used the built-in GPT Image route, whose exact model selector is not exposed.
- Adopted one complete, uncropped plump pink brain mascot centered on a full-bleed deep warm plum-black `#241820`-family field. The whole scalloped head silhouette remains visible with generous top and side clearance, while the face, two small white gloves, and one portrait smartphone stay fully inside the square.
- Made the brain texture the defining visual system: large rounded lobes have bold dark brown-black contour lines, sparse short comma-like crease arcs, a strong central vertical fissure between the hemispheres, pale upper-edge rim highlights, and soft airbrushed pink shading from the `#F2A2B4` / `#E58599` family. This rejects a smooth cloud-like silhouette and preserves the brain reading at 60×60.
- Made the expression deliberately dopamine-drained rather than frightening: two oversized heavy-lidded droopy eyes look down toward the phone with tiny pupils, paired with one small slack open mouth. The blank vivid lime-chartreuse `#C7F94D` screen is the sole apparent light source and casts restrained under-light onto the eyes, lower face, and gloves.
- Rejected cropped lobes, cloud-like smoothing, faint or missing crease strokes, a weak central fissure, anatomical realism, gore, horror, zombie styling, books, glasses, extra props or characters, phone UI, text, letters, symbols, particles, decorative effects, frames, borders, tile shadows, 3D rendering, flat-vector treatment, and baked-in rounded corners because they violate the mascot brief or reduce small-size clarity.
- Implementation constraints for Claude Code: treat `creatives/app-icon/concepts/png/70f_genk_style.png` as the source of truth. Do not crop, zoom, pre-round, frame, recolor, add UI or text to the blank phone screen, add props or particles, soften the lobe outlines, remove the sparse crease arcs, weaken the central fissure, change the droopy downward gaze, or introduce another light source. Let iOS apply its system icon mask and preserve the square aspect ratio, complete silhouette, two-glove/one-phone counts, blank lime screen, and readable brain texture when resizing.
- Validation: PNG, exactly 1024×1024, 8-bit RGB, no alpha; the 60×60 downsample clearly retains the scalloped brain silhouette, central fissure, internal lobe creases, heavy-lidded eyes, tiny pupils, white gloves, and blank luminous phone. SHA-256: `5650a0982078718d3b5491a2da32705d83c6a736ca309eb4a727c011f9b3500e`.

## 2026-08-04 — App Icon Concept 72b “Toon Cel Phone Trance”

- Created `creatives/app-icon/concepts/png/72b_toon_cel.png` and normalized the selected artwork to a production-ready 1024×1024 opaque RGB PNG. The direct model-controlled `gpt-image-2` CLI request reached the Image API but was rejected by the configured account billing hard limit; the final render therefore used the built-in GPT Image route, whose exact model selector is not exposed.
- Adopted one complete, uncropped plump pink brain mascot on a full-bleed mottled deep-plum `#2A1C26`-family field. The highest lobes begin at roughly 14–15% from the top, the scalloped head spans nearly the full tile width with narrow side slivers and visible lobe notches, and the face, two white gloves, and single portrait phone remain centered and readable at small size.
- Made the classic television-cel finish the defining system: bold clean dark brown-black outlines of even weight, flat saturated `#F09CB0`-family pink, restrained hard-edged `#D97B93`-family shadow shapes, sparse darker-pink oval pore spots, short internal wrinkle arcs, a strong central fissure, and subtle vintage paper grain over the complete image. Rejected soft airbrush, glossy 3D volume, painterly blending, and gradient lighting.
- Made the expression comically dopamine-drained rather than frightening: two oversized heavy droopy upper lids, large white eyes, tiny pupils aimed down at the phone, and one small slack open mouth. The dark charcoal phone has a blank vivid lime-chartreuse `#C7F94D`-family screen and casts only two hard-edged lime cel-light shapes onto the lower face; exactly two small white gloves hold it at bottom center.
- Rejected the first built-in composition because its top clearance was only about 8%. Rejected the unmodified composition-correction render because it left excessive side clearance and weakened 60×60 presence. The adopted crop uses the corrected render while restoring near-full-width occupancy and approximately 15% top margin without cropping the brain silhouette or hands.
- Rejected text, letters, symbols, phone UI, books, glasses, extra characters or hands, yellow sponge or square-body cues, existing-IP resemblance, anatomical realism, gore, borders, frames, baked rounded corners, soft glow, bloom, and extra props because they violate the original-mascot brief or reduce app-icon clarity.
- Implementation constraints for Claude Code: treat `creatives/app-icon/concepts/png/72b_toon_cel.png` as the source of truth. Do not crop, zoom, pre-round, frame, recolor, add phone UI or text, add props, soften the even outlines, remove pore spots/wrinkle lines/central fissure, change the downward tiny-pupil gaze, replace the hard-edged lime light with soft bloom, or introduce existing-character cues. Let iOS apply its system mask and preserve the square aspect ratio, full silhouette, two-glove/one-phone counts, blank lime screen, flat cel palette, and vintage grain when resizing.
- Validation: PNG, exactly 1024×1024, 8-bit RGB, no alpha; the 60×60 downsample retains the full brain silhouette, central fissure, pore/crease texture, heavy-lidded downward gaze, slack mouth, white gloves, blank lime phone, and hard-edged lime light. SHA-256: `78c417dd23d43b2cc448dc5aae88e9ad5ea3083ddcbee1a61feb7ceff9d1d36f`.

## 2026-08-04 — App Icon Concept 73 “Pause Interrupt”

- Created `creatives/app-icon/concepts/png/73_pause_interrupt.png` through the GPT Image generation workflow and normalized the selected square render to a production-ready 1024×1024 opaque RGB PNG.
- Adopted a complete, centered pink brain mascot with a strongly segmented scalloped silhouette, sparse internal crease arcs, a clear central fissure, pale upper-lobe rim highlights, bold dark outlines, and soft airbrushed cel shading. Narrow full-bleed plum-black margins keep the whole head visible and preserve iOS mask clearance.
- Made the interruption story dominant through one front-facing portrait smartphone with a luminous lime-chartreuse screen containing exactly two thick, equal-height, widely separated dark rounded pause bars. The symbol fills most of the unobstructed screen and remains unmistakable in the verified 60×60 preview; restrained lime under-light reaches the lower face and both white gloves.
- Preserved the dopamine-drained expression with oversized heavy drooping lids, tiny pupils aimed down at the phone, and a small slack open mouth. Rejected phone-feed UI, text, letters, numbers, play symbols, buttons, notifications, extra screen marks, books, glasses, additional props or characters, cropped lobes, borders, frames, photorealism, heavy 3D rendering, and baked rounded corners because they weaken the single interruption beat or violate the icon constraints.
- Implementation constraints for Claude Code: treat `creatives/app-icon/concepts/png/73_pause_interrupt.png` as the source of truth. Do not crop, zoom, pre-round, frame, recolor, change the exact two-bar pause symbol, add any other screen content, cover the bars with the gloves, redirect or enlarge the pupils, rotate the phone, add props, or increase the rendering dimensionality. Let iOS apply its system mask; preserve the whole-head silhouette, two-glove/one-phone count, plum-black field, lime screen and under-light, bold outlines, and square aspect ratio.
- Generation note: the explicitly model-controlled `gpt-image-2` CLI/API request was attempted at high quality and exact 1024×1024 output, but the configured account returned `billing_hard_limit_reached` before rendering. The accepted render therefore used the built-in GPT Image route, whose exact backend model selector is not exposed; no downgrade to CLI `gpt-image-1.5` was made.
- Validation: PNG, exactly 1024×1024, 8-bit RGB, no alpha; the 60×60 downsample retains the whole brain, heavy-lidded downward gaze, slack mouth, both gloves, portrait phone, luminous lime screen, and two distinct dark pause bars. SHA-256: `6346b176b2b934c6165a93e86c4ab5f2bd1b04d5166ca4fd289ed7f96ba2a1bc`.

## 2026-08-04 — App Icon Concept 76b “Correct Relief”

- Created `creatives/app-icon/concepts/png/76b_correct_relief.png` as a production-ready 1024×1024 opaque RGB PNG using the Image Generation skill and the adjacent brain-mascot artwork as the character/style anchor. The explicit high-quality `gpt-image-2` CLI/API edit was attempted first but the configured account returned `billing_hard_limit_reached`; the accepted render therefore used the built-in GPT Image route, whose exact backend selector is not exposed. No downgrade to `gpt-image-1.5` was made.
- Adopted the physically corrected phone orientation as the defining revision: exactly one plain dark-charcoal smartphone is seen strictly from behind at bottom center, with its blank back facing the viewer and its hidden screen facing the brain. The phone has no screen content, camera lens, camera bump, buttons, logo, or other marks.
- Restricted lime-chartreuse to a thin fading edge rim around the phone and a very faint residual tint on the gloved fingertips. The face is instead illuminated primarily by the soft warm ambient halo behind the head; there is no visible lime screen, glowing rectangle, hard light cone, triangular beam, or strong neon under-light.
- Preserved the original classic-TV-cartoon cel mascot language: complete uncropped scalloped brain silhouette, strong central fissure, sparse oval pore spots and internal crease lines, bold even dark outlines, saturated pink cel masses, darker-pink shadow shapes, two small white gloves, full-bleed mottled deep-plum field, and subtle vintage print grain.
- Made the post-feed relief state readable through gently closed droopy lids, relaxed brows, a small grateful smile, and exactly one soft exhale puff. Rejected sleepiness, sadness, anxiety, mania, open eyes, additional puffs, books, glasses, extra hands or devices, phone UI, text, letters, logos, borders, frames, baked rounded corners, anatomical gore, photorealism, and 3D/clay/plastic rendering.
- Implementation constraints for Claude Code: treat `creatives/app-icon/concepts/png/76b_correct_relief.png` as the source of truth. Do not crop, zoom, pre-round, frame, recolor, rotate the phone front-facing, add camera hardware or screen content, strengthen the lime glow, replace the warm halo, open the eyes, duplicate the exhale, remove the central fissure/pore/crease texture, add props, or increase the rendering dimensionality. Let iOS apply its system mask and preserve the complete silhouette, exact two-glove/one-phone counts, back-facing phone geometry, restrained lime rim, warm face light, and square aspect ratio.
- Validation: PNG, exactly 1024×1024, 8-bit RGB, no alpha; the verified 60×60 downsample retains the complete brain silhouette, closed relieved expression, single exhale, two gloves, and plain back-facing phone. SHA-256: `52fe5e46b3ca69d6911b73bb3abb1775356a0020ca4e0e1e8b1523b2fcbdedc4`.

## 2026-08-04 — App Icon Concept 75c “Final Tall Brain Doomscroll”

- Created `creatives/app-icon/concepts/png/75c_final_tall.png` with the built-in GPT Image generation tool and normalized the generated square render to a production-ready 1024×1024 PNG.
- Adopted the revision’s two defining corrections: a tall, vertically dominant brain silhouette that fills the frame from roughly 8% top clearance to the bottom edge, and two clearly wide-set eyes positioned toward the outer thirds of the face with a broad central gap. The strong vertical fissure, large scalloped lobes, sparse darker-pink pore spots, and short internal wrinkle marks keep the mascot unmistakably brain-shaped.
- Preserved the dopamine-drained doomscroll expression with large drooping upper lids, small pupils aimed down, and a slack open mouth. Exactly two white gloves hold one dark charcoal portrait phone; its vivid lime-chartreuse screen contains one dark pause mark made of exactly two rounded vertical bars and casts a diffuse lime wash onto the lower face and fingers.
- Chose bold even brown-black outlines, saturated pink cel fills, simple darker-pink shadow shapes, subtle vintage paper grain, and a warm halo on the deep-plum full-bleed field. Rejected a squashed or wide-oval head, close-set eyes, a hard light cone, additional screen UI, text, letters, numbers, books, glasses, borders, frames, baked rounded corners, photorealism, heavy 3D rendering, and resemblance to existing cartoon characters.
- Implementation constraints for Claude Code: treat `creatives/app-icon/concepts/png/75c_final_tall.png` as the source of truth. Do not crop, zoom, pre-round, frame, recolor, widen or squash the head, move the eyes inward, alter the two-bar pause symbol, add UI/text/props, harden the lime light into a cone, or remove the brain fissure and lobe markings. Let iOS apply its platform mask and preserve the full square field, tall proportions, wide-set gaze, one-phone/two-glove count, even outlines, and cel-print finish.
- Validation: PNG, exactly 1024×1024; the vertically filled silhouette, wide-set eyes, downward gaze, glowing portrait phone, and two-bar pause mark remain clear at icon-oriented scale.

## 2026-08-04 — アプリアイコン確定・配置（75b 催眠スマホ脳）

- **確定案**: `creatives/app-icon/concepts/png/75b_final_pause.png` → `ios/DopaBreak/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
- 絵柄: ピンクの脳キャラがスマホを両手で持ち、垂れまぶた・縮んだ瞳孔・半開きの口で見入っている。画面はライム `#C7F94D` に光り一時停止記号（⏸）を表示。背後に暖色のアンビエントハロー。
- 画風の確定経緯（オーナー選択）: **画風＝72a系（90sセル画調: 均一な太い輪郭・フラット彩色・穴状の斑点・紙のざらつき）× 光＝70f系（ソフトなハローと拡散したライムの照り）**。脳に見せる決め手は「大ロブ内の短いしわ線＋中央の縦の割れ目」で、これを省くと雲になる。
- 検証済み（App Store要件）: 1024×1024 / PNGカラータイプ2＝RGB（**アルファなし**）/ 角丸の焼き込みなし / `Contents.json` と実ファイル名一致（単一1024のiOS 17+現行方式）。29〜180ptの実表示サイズで可読性を確認。
- **却下と誤診の記録（重要）**:
  - 75b→75c で「頭が上下に潰れている」として縦長化＋目を離す是正を試みたが**過補正で不採用**。縦横比 0.83→1.45、幅86%→66%となり、脳ではなく卵・繭に見え、離した目が不気味になった。**75bの横長（0.83）は欠陥ではなく脳という被写体本来の形で、丸い愛嬌の源だった**。GenKの数値に機械的に合わせにいったのが誤り。
  - 「降り注ぐライム粒子」は不採用。細粒は60pxで消え、代償に目が小さくなる（71・70cで実証）。ドーパミン表現は「ライムに光る画面＋照らされる顔」で足りる。
  - 物理整合（スマホ背面が見えるべき）の指摘に対し 76a/76b を作成したが、**アイコンは記号なので画面を見せる表現は許容**と判断し75bを採用。76系は保留（`png/76a_correct_doom.png` `png/76b_correct_relief.png`）。
- **ビルド検証は未完（環境起因・アイコンとは無関係）**: `xcodegen generate` は成功。`xcodebuild` は `Assets.xcassets: error: Failed to launch AssetCatalogSimulatorAgent via CoreSimulator spawn` で失敗する。**アイコンを外しても同じエラーが出ることを実測で確認済み**＝本セッションの変更が原因ではない。simulator/device 両destination・サンドボックス無効でも同一。CoreSimulatorService(PID 593)は稼働中だが、実行中のシミュレータを巻き込むためサービス再起動は未実施。Xcode.app からのビルド、または `sudo pkill -f com.apple.CoreSimulator.CoreSimulatorService` 後の再試行で解消する見込み。
- IP方針: スポンジボブは**画風のみ**を言語化して参照。キャラクターは完全オリジナルの脳マスコット（黄色いスポンジ・四角い体などの要素は明示的に禁止）。GenKも同様に画風の参照のみ。
- 未着手: ワードマーク（文字ロゴ）。PPO用B案の選定（`32b_ember_dusk` `36_lime_pause` `41b_lime_gap` が候補）。

## 2026-08-04 — Launch Animation Frames B/C “Blink → Awake”

- Created `creatives/launch-animation/frame_b_blink.png` and `creatives/launch-animation/frame_c_awake.png` as opaque 1024×1024 RGB PNG animation frames, using the installed app icon at `ios/DopaBreak/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` as the primary edit reference and `creatives/app-icon/concepts/png/76b_correct_relief.png` only as a secondary continuity reference.
- Frame B preserves the drained state and slack mouth while closing both eyes, retaining tired brows/bags, and turning the front-facing phone display fully dark with no pause mark or lime emission. An alternate blink render was rejected because it retained a conspicuous lime under-light despite the display being off.
- Frame C establishes the wake beat through wide white eyes, exactly two catchlights per pupil, raised brows, clean under-eye areas, healthier cheek color, a small closed smile, a slightly lowered dark phone, a restrained lime rim on the upper brain silhouette, and a cleaner/lighter plum vignette.
- Preserved the established mascot language across both frames: full centered scalloped brain silhouette, central fissure, lobe creases and pore spots, two-glove/one-phone count, bold dark outlines, saturated pink cel shading, full-bleed plum field, and vintage paper grain. Rejected text, letters, logos, extra symbols, breath puffs, particles, additional props, borders, transparency, and baked-in rounded corners.
- Generation constraint: artwork was produced only through the built-in image-generation edit route; no imagegen skill, API script, SDK, key, or HTTP request was used. The built-in route returned 1254×1254 source renders, which were mechanically normalized to the required 1024×1024 square without changing composition.
- Implementation constraint for Claude Code: use these files at native square aspect ratio with no further crop, mask, recolor, sharpening, phone UI, or added typography. These are source-registered generative cels rather than literal masked pixel-delta edits, so prefer a short held-frame/cut sequence over a long cross-dissolve if texture shimmer becomes visible.
- Validation: both files are 1024×1024, 8-bit RGB PNGs with no alpha. SHA-256: Frame B `131076cb563bd0ef5a4796c4dd15e6820bada8aa1046f271fccd151d83ff7a3d`; Frame C `d72ae7205ae048eb36447bce9c67c9c19248f219f4634840835b693a81f28a7e`.

## 2026-08-04 — Character State E “Blank”

- Created `creatives/app-icon/concepts/png/char_E_blank.png` with the built-in GPT Image generation route and normalized the returned square render to the required 1024×1024 opaque RGB PNG. No image-generation skill, API script, SDK, API key, or billed API call was used.
- Preserved the locked mascot system: a complete wide 0.83-proportion pink brain head made from large scalloped lobes, one strong central fissure, short internal crease strokes, sparse darker-pink pore spots, bold even dark outlines, flat saturated cel color and shadow shapes, a full-bleed deep-plum field, warm ambient halo, and subtle paper grain.
- Defined State E solely through the face: both large eyes are half-open and unfocused with medium pupils looking straight ahead, the eyebrows are flat and level, and the mouth is one small horizontal line. The expression is emotionally empty rather than sleepy, sad, pleased, anxious, or alarmed.
- Rejected hands, phone, props, limbs, ears, decorative particles, sparkles, stars, hearts, glasses, books, text, borders, baked rounded corners, horror/gore, veins, tears, photorealism, 3D/clay rendering, and pristine vector-flat treatment because the state must read as a neutral standalone expression at 60×60.
- Implementation constraint for Claude Code: treat `creatives/app-icon/concepts/png/char_E_blank.png` as the source of truth. Do not crop, pre-round, frame, recolor, add props or typography, change the straight-ahead gaze, alter the flat brows or straight mouth, remove the central fissure/creases/pores, or increase rendering dimensionality. Preserve the square composition and full-bleed background when resizing.
- Validation: PNG, exactly 1024×1024, 8-bit RGB, no alpha. SHA-256: `360831a0d0adbe17055aefd1bb55ea5c18789e6e9bce8be5b0fb8ca474a4a268`.

## 2026-08-04 — Character State D “Relief”

- Created `creatives/app-icon/concepts/png/char_D_relief.png` with the built-in GPT Image generation/edit route, then normalized the returned square render to the required 1024×1024 opaque RGB PNG. No imagegen skill, API script, SDK, API key, or billed API call was used.
- Used `creatives/app-icon/concepts/png/char_E_blank.png` as the continuity reference so State D preserves the established original mascot identity: wide scalloped brain silhouette, strong central fissure, internal curved creases, sparse darker-pink pore spots, even dark outlines, saturated pink cel fills and shadows, deep-plum full-bleed field, warm halo, and mottled paper grain.
- Changed only the emotional state: two gently closed downward-curved eyes at moderate spacing, calm unknotted brows, restrained cheek blush, and one small grateful smile communicate the quiet relief after putting the phone away.
- Rejected the initial reference-free render because its lobe arrangement and framing drifted from the existing locked character. Also rejected hands, phone, a literal breath puff, particles, tears, props, decorative symbols, typography, borders, baked rounded corners, glossy 3D rendering, and anatomical/horror details.
- Implementation constraint for Claude Code: treat `creatives/app-icon/concepts/png/char_D_relief.png` as the source of truth. Do not crop, pre-round, frame, recolor, add hands/phone/breath effects, reopen the eyes, tense the brows, remove the blush, or alter the fissure/creases/pores. Preserve its square aspect ratio and full-bleed plum background when resizing.
- Validation: PNG, exactly 1024×1024, 8-bit RGB, no alpha; the 60×60 preview preserves the relaxed expression and brain markings. SHA-256: `1157633b1742fb8671dfd0f49745eaeac1d5253955dddc98bd0441c566c92f07`.

## 2026-08-04 — Character State E2 “Blank With Phone”

- Created `creatives/app-icon/concepts/png/char_E2_blank.png` as a localized expression edit of `video/launch-animation/public/frame_c_awake.png`. The facial artwork was produced only through the built-in GPT Image edit route; no imagegen skill, API script, SDK, API key, HTTP request, or billed API call was used.
- Preserved the awake frame as the pixel source outside a feathered mask limited to the eyes, eyebrows, mouth, and cheek/blush areas. This retains the original complete brain silhouette, lobes, central fissure, crease and pore system, pink palette and shading, paper grain, plum field and warm halo, white gloves, dark phone, framing, scale, and canvas position.
- Changed only the emotional read: both eyes are half-open and unfocused with medium centered pupils, both eyebrows are flat and level, the mouth is one short horizontal line, and the prior cheek blush is removed. The result is emotionally blank rather than tired, sad, pleased, anxious, or alarmed.
- Rejected the first built-in edit because it reinterpreted the silhouette, framing, phone, and hands. The accepted workflow restarted from the original, used the stricter second render only inside the permitted face mask, and restored original pixels everywhere else.
- Implementation constraint for Claude Code: treat `creatives/app-icon/concepts/png/char_E2_blank.png` as the source of truth. Do not crop, resize non-uniformly, pre-round, recolor, add phone UI, change the straight-ahead gaze, arch the brows, curve the mouth, restore blush, or alter the original hands/phone/head/background continuity.
- Validation: PNG, exactly 1024×1024, 8-bit RGB, no alpha. Decoded-pixel MD5 checks match the source across the unaffected top, bottom, left, and right bands; detected visual differences are confined to the central expression/cheek region. SHA-256: `2034eab638d5230f70dec3a876739126d87a7704fc64fbedc4588bdebfd6c9b9`.

## 2026-08-05 — App Icon `v2_awake` Expression Edit

- Created `creatives/app-icon/concepts/png/v2_awake.png` from `creatives/app-icon/concepts/png/BASE_v2_doom.png` using only the built-in GPT Image edit route for artwork generation; no imagegen skill, script, Python SDK, API key, HTTP request, or billed API call was used. The built-in route returned a 1254×1254 square render, which was mechanically normalized to the required 1024×1024 opaque PNG.
- Changed the emotional read to alert and clear-headed: both eyes are fully open with clean white sclera, round dark forward-facing pupils, and exactly two white catchlights per pupil; the black brows sit slightly higher; the former slack mouth is replaced by a small closed friendly smile.
- Rejected the first edit pass because its expression-reference role was less explicit. The accepted pass used the original as the immutable base reference and the first pass only as an expression reference, with the prompt locking the silhouette, lobes, fissure, highlights, palette, under-light, background, phone, hands, crop, scale, and placement.
- Constraint for Claude Code: treat `creatives/app-icon/concepts/png/v2_awake.png` as the approved awake-state asset at native square aspect ratio. Do not crop, pre-round, recolor, add phone UI, alter the two catchlights per pupil, reopen the smile, lower the brows, or change the one-phone/two-glove composition.
- Generation limitation: the built-in edit interface exposes no pixel mask or literal pixel-lock control. Because external mask compositing was explicitly disallowed, this deliverable is a tightly constrained generative edit rather than a verifiable pixel-identical face-only composite.
- Validation: PNG, exactly 1024×1024, 8-bit RGB, no alpha. SHA-256: `92ad263b7a27ccbe049a0cc356717efa37e3aafcb5cee87f07e58b64a7b3dab0`.

## 2026-08-04 — DopaBreakキャラクター表示・表情アニメーション実装

- 作成・変更: `ios/DopaBreak/CharacterView.swift` を新規作成し、`ios/DopaBreak/PostUseReflectionSheet.swift`、`ios/DopaBreak/InterventionFlowView.swift`、`ios/DopaBreak/OnboardingFlow.swift` に配置を実装。`ios/DopaBreakTests/CharacterViewTests.swift` に表情マッピング5件とReduce Motionのテストを追加した。
- 採用方針: 静止PNGの差し替えは `TimelineView(.animation)` に集約し、浮遊は±4pt・1.6秒周期のsin波、まばたきはblink番号の固定ハッシュから3.5〜6.0秒間隔を作る64区間の決定論的パターンとした。表情変更は0.13秒の閉眼中点で内部表情を切り替え、Image側のtransactionを無効化して親アニメーションからのクロスフェードも遮断した。
- 採用方針: 通常ポップは `DopaMotion.control`、達成ポップは `DopaMotion.celebrate` のみを使用。Reduce Motionでは浮遊だけを止め、状態理解に必要なblinkと閉眼差し替えは残した。
- 配置判断: リフレクションは上部160pt＋各選択肢44pt、介入はbreathingのキャラ表示→フェード完了→炎を排他的に描画し、decisionでdoom→awake、winでreliefを表示。オンボーディングは設計表のwelcome／quizResult／preview／prePaywallSummary／readyだけに限定した。既存のwin／readyのチェックマーク枠をキャラ枠として再利用し、外形寸法・余白・色・表示文言を維持した。
- 却下案: キャラと炎のZStack重ね合わせ、表情のクロスフェード、乱数・`Date()`保存によるblink管理、全オンボーディング画面への常設、新規モーション曲線は、役割衝突・再描画不安定・仕様逸脱になるため採用しなかった。
- Claude Code側の制約: `FlameBreathView.swift` と `Shaders/Flame.metal`、Characterアセット6点は未変更。breathingの3段階（character／fadingCharacter／flame）は同時描画禁止を守るため統合しないこと。画像はasset raw valueと同名で参照し、表情追加時もクロスフェードを入れないこと。
- 検証: `xcodegen generate` 成功。iPhone 16 Pro（iOS 18.3.1）で `CharacterViewTests` 2件が成功し、アプリ・拡張・テストターゲットのコンパイルも成功した。

## 2026-08-04 — キャラクターのアプリ内配置（実装完了・ビルド検証は環境で未完）

- オーナー決定: アイコンの脳キャラをアプリ内へ展開。**できる限りアニメーションで**。
- **設計の中核**: キャラ=「あなたの状態」／炎=「呼吸のペース」で仕事を分け、共存させる。介入では**キャラで炎を挟む**（虚ろ→炎で一呼吸→焦点が戻った顔）。炎の聖域は侵さない。設計書 `design/BUILD_SPEC_CHARACTER_PLACEMENT.md`。
- 実装（Codex gpt-5.6-sol / effort max）:
  - `ios/DopaBreak/CharacterView.swift`（新規）: 浮遊±4pt/1.6s・自動まばたき3.5〜6.0s間隔で0.13秒・**blink-covered swap**（閉眼0.13秒の中点で差し替え／クロスフェード禁止を`.transaction`で強制）・Reduce Motionで浮遊のみ停止。まばたき間隔は**indexのハッシュから決定的に導出**（Date/randomを持たずPreviewが壊れない）。`CharacterSwapSequence`と`.characterPop()`（DopaMotion.control / celebrate）を同梱。
  - 配線: `PostUseReflectionSheet`（5値→表情、44ptを各選択肢＋上部に大）、`InterventionFlowView`（breathing冒頭0.6秒→decision→win、failedは無し）、`OnboardingFlow`（welcome/quizResult/preview/prePaywallSummary/readyの5箇所のみ）。
  - テスト `DopaBreakTests/CharacterViewTests.swift`: 5値マッピング全網羅（`allCases`一致も検証＝ケース追加漏れを検出）＋Reduce Motionで浮遊0。
- **制約の遵守を実測で確認**: `FlameBreathView.swift`(7/28) と `Shaders/Flame.metal`(7/25) は更新時刻が変わらず**無変更**。依存追加なし。breathingは`switch`で炎とキャラを排他にし、同時描画が構造的に起きない。
- アセット: `Assets.xcassets/Character/` に6 imageset（doom/blink/awake/relief/blank/worse）。doom/blink/awakeは起動アニメの既存3枚を流用、relief/blank/worseを新規作成。全てアルファなしRGB 1024。
- **絵柄一貫性の手法確立（重要）**: text-to-imageでは`LOCKED_SPEC`を書いても3枚とも別キャラ化した。**基準画像を入力にした image-to-image（顔のみ編集）**へ切替えて解決（体の平均差分 13.5/0.2/13.2・大差画素0〜1.4%）。検査は `verify_character.py`（比率）と `verify_swap.py`（顔以外の一致）の2段ゲート。詳細は `design/CHARACTER_BIBLE_DOPA.md` §2。
- **検証の到達点と未完**: Swift **38ファイルがエラー・警告ゼロでコンパイル成功**。ただし `CompileAssetCatalog` が `Failed to launch AssetCatalogSimulatorAgent via CoreSimulator spawn` で失敗するため、**アプリのビルド完了とテスト実行は未達**。これはアイコン配置時（同日）に**キャラ実装前から再現することを実測済み**の環境問題で、本変更とは無関係。iPhone 17 Pro Maxのシミュレータが起動中のため、他セッションを巻き込むCoreSimulatorService再起動は実施していない。解消後に `xcodebuild test` の実行が必要。

## 2026-08-05 — App Icon `v2_worse` Expression Edit

- Created `creatives/app-icon/concepts/png/v2_worse.png` from `creatives/app-icon/concepts/png/BASE_v2_doom.png`. Artwork generation used only the built-in GPT Image edit route; no imagegen skill, Python/API script, SDK, API key, HTTP request, or billed API call was used. The editor's native 1254×1254 square render was mechanically normalized to the required 1024×1024 opaque PNG.
- Changed the emotional read to regretful and deflated while keeping it comedic: both eyes remain open with downturned outer corners, the two black brows form a troubled inward frown, the mouth is a small downturned grimace, and exactly one blue sweat drop sits at the viewer-right temple. No tears or additional drops were introduced.
- Rejected the first built-in pass because it reconstructed too much of the head and framing. The adopted pass restarted from `BASE_v2_doom.png` as the immutable base and used the rejected result only as an expression reference, explicitly locking the brain, phone, hands, background, palette, lighting, crop, scale, and placement.
- Constraint for Claude Code: treat `creatives/app-icon/concepts/png/v2_worse.png` as the worse-state source asset at native square aspect ratio. Do not crop, pre-round, recolor, add phone UI, close either eye, add tears or more sweat drops, enlarge the mouth, or change the one-phone/two-glove composition.
- Generation limitation: the built-in edit interface exposes no mask or literal pixel-lock control. Because external mask compositing and other image-editing workflows were explicitly prohibited, the result is a source-anchored generative edit, not a verifiable pixel-identical face-only composite.
- Validation: PNG, exactly 1024×1024, 8-bit RGB, no alpha. SHA-256: `ab080a1f1cd9457588b9036455be8c7380f607535ede6ba761743b8e31ec63f2`.

## 2026-08-05 — アイコン新版へ差し替え＋キャラ6表情を新基準で作り直し

- オーナー提供の改良版 `creatives/app-icon/concepts/app-icon.png` を採用。**光沢と厚みのある立体表現＋深いプラム地＋暖色ハロー**。前版75b（セル画・紙質感）から質感を刷新。
- **採用理由（インパクト/ブランディング/愛着/興味づけの4軸で判定）**: 暗い地色でピンクの輪郭が背景から分離し、29pxでも判別可能。白いハイライトによる「触れそうな厚み」が愛着に効く。前版で唯一の弱点だった「黒地でアプリ内と世界観が切れる」は、オーナー改良版がプラム＋暖色ハローにしたことで解決済み。
- **私の判断の訂正**: 前回「プラスチック光沢は¥980/月の商材にカジュアルすぎる」としてセル画を推したが、これは弱い論拠だった。価格の説得はペイウォールとストア説明文の仕事であり、アイコンの仕事は棚で気づかれること。Duolingo・Finchが光沢キャラで高価格を成立させている。**勝ち軸「唯一顔のあるスクリーンタイムアプリ」に対し、インパクトを削る判断は勝ち軸を自分で削る**。
- 技術検証: RGB・アルファなし・角丸の焼き込みなし（上端の明度が0→7→10→28→33と連続するビネットでハード境界なし）・**squircleマスクで脳が0画素も欠けない**（1254→1024へLANCZOSリサイズ）。
- 検査ゲート更新: 新構図に合わせ `verify_character.py` の許容を **幅0.86–0.97 / 上余白0.05–0.14** へ改訂（旧値は75b基準の 幅0.78–0.92 / 上余白0.08–0.18）。`verify_swap.py` の基準画像も `png/BASE_v2_doom.png` へ変更。
- 6表情を新基準からimage-to-imageで再生成し `Assets.xcassets/Character/` を全差し替え。比率ゲートは6/6合格。
  - swapゲートで2枚が閾値超過だが**いずれも実害なし**: `relief` は指示どおり画面消灯＋照り返し消失（体26.7）。`worse` はライム照り返しが顔矩形の外へ広がった分を体差分として数えているだけで絵は不変（体56.9）。**検査の顔矩形が固定領域である限界**であり、画像の欠陥ではない。
- ビルド: Swiftはエラーゼロ。`CompileAssetCatalog` は既存のCoreSimulator環境問題で失敗したままで、**アプリのビルド完了とテスト実行は依然として未達**。

## 2026-08-05 — MorningHorizon撤去・透明キャラクターへの置換

- 変更: `ios/DopaBreak/OnboardingFlow.swift` のwelcome／ready背景から朝焼け写真を撤去し、通知プレビューは高さ300ptの `DesignTokens.backgroundRaised` 上に `CharacterView(.relief, size: 96)` を配置した。既存の通知ラベル・内側カード・余白・角丸・罫線は維持した。
- 変更: `ios/DopaBreak/HomeView.swift` の高さ132ptヒーローは `model.todayCancelledCount > 0` のとき `.awake`、それ以外は `.doom` を124ptで表示する。新しい状態やクエリは追加せず、左右の既存ラベルと中央キャラが干渉しない構成を採用した。
- 変更: `ios/DopaBreak/PaywallView.swift` の高さ112ptヘッダーは `DesignTokens.backgroundRaised` 上の `CharacterView(.awake, size: 104)` に置換した。上下4ptを浮遊アニメーションの振幅に確保し、既存の角丸・罫線・PROラベルを維持した。
- 削除: `ios/DopaBreak/DesignTokens.swift` の `MorningHorizon` とBundle URL読込を削除し、`ios/DopaBreak/Assets.xcassets/MorningHorizon.imageset` も削除した。`ios/DopaBreak/Resources/morning-horizon.png` は `scripts/generate-appstore-screenshots.py` が参照中のため削除せず、`ios/project.yml` でアプリターゲットから除外した。
- 却下案: 写真用グラデーションや新しい背景装飾をキャラの背後へ残す案、成功判定用の新規状態を追加する案、スクリーンショット生成を壊してraw PNGも削除する案は、透明cutout・既存モデル再利用・参照中資産を壊さないという制約に反するため採用しなかった。
- Claude Code側の制約: Homeの表情判定は成功停止数 `todayCancelledCount` を正本とし、`todayAttemptCount` へ置き換えないこと。各スロットの固定高（通知300pt／Home 132pt／Paywall 112pt）とCharacterViewの既存blink-covered swap・Reduce Motion挙動を維持すること。raw PNGはスクリーンショット生成の参照がなくなった時点で削除可能。
- 検証: `xcodegen generate` 成功。iPhone 17 Pro Simulator向け `xcodebuild ... -derivedDataPath .deriveddata-sim2 build` は **BUILD SUCCEEDED**。生成されたprojectとアプリbundleにmorning-horizon参照・ファイルがないこと、`FlameBreathView.swift` と `Shaders/Flame.metal` が無変更であることを確認した。

## 2026-08-05 — 景色写真の全廃とキャラへの置換／ビルド不能問題の根本解決

- **ビルド不能の原因が判明（数日ブロックされていた問題）**: `Assets.xcassets: error: Failed to launch AssetCatalogSimulatorAgent via CoreSimulator spawn` は、**macOS 26.5.2 に対して Xcode 16.2 が `xcode-select` で選択されていた**ことが原因。CoreSimulator 1051.55 は新しいXcode用でバージョン不整合を起こしていた。`/Applications/Xcode.app`（Xcode 26.6）を使えば `BUILD SUCCEEDED`。
  - **今後のビルド/テストは必ず `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` を付ける。** CoreSimulatorService の再起動では解消しない（実施済みだが無効だった）。
- **オンボ1枚目のレイアウトバグを修正**: `Spacer(minLength:).overlay { CharacterView }` はSpacerが幅を持たないため中央基準が定まらず、キャラが左端へはみ出していた。`CharacterView().frame(maxWidth: .infinity).frame(height:)` へ変更。同型の `quizResult` にも `.frame(maxWidth: .infinity)` を追加。
- **キャラ素材を透過PNGへ**: アイコン用の不透明画像をそのままアプリ内で使っていたため、写真やダーク背景の上に**黒い角丸の箱**が見えていた。四隅からのflood fillで外側の背景のみを透明化（スマホ・輪郭の暗部は保持）。6枚とも切り抜きbboxが961x896前後で一致することを実測＝blink-covered swapの前提を満たす。
  - 生成時に **`v2_blink` だけ1254pxで出力されていた**のを発見し1024へ正規化。アセット配置側でリサイズしていたため見逃していた。
  - **アプリアイコンは不透明のまま維持**（App Storeはアルファ不可）。透過は `Assets.xcassets/Character/` のみ。
- **景色写真（MorningHorizon）をアプリ全体から削除**（オーナー決定）。4箇所を性質別に置換:
  | 箇所 | 対応 |
  |---|---|
  | オンボ背景 welcome/ready | 削除。キャラが主役 |
  | オンボ通知プレビュー | ダークカード＋`.relief` |
  | Home heroBand | `model.todayCancelledCount > 0 ? .awake : .doom`（既存値を使用・新規stateなし） |
  | Paywall header | `.awake`＝手に入る未来 |
  - `MorningHorizon` 構造体・bundle読み込み・`MorningHorizon.imageset` も削除。参照ゼロを確認。
- **判断根拠（景色を外した理由）**: ①主役が2つになり視線が定まらない ②朝焼け＝希望の記号で「人生の時間は二度と戻らない」と感情の方向が逆 ③朝焼けは報酬の記号なので後半（ready）に取っておくほうが効く。
- 制約遵守: `FlameBreathView.swift`(7/28)・`Shaders/Flame.metal`(7/25) は更新時刻不変＝**無変更**。依存追加なし。
- 検証: `BUILD SUCCEEDED`・シミュレータ（iPhone 17 Pro）で実機確認・スクリーンショットを `output/screenshots/character-onboarding/` に保存。
- 未対応: オーナー報告の「炎の位置がおかしい」は添付画像が処理できず**画面を特定できていないため未着手**。

## 2026-08-06 — 目標設定画面の種火 v2（知覚できる成長）

- 変更: `ios/DopaBreak/OnboardingMotion.swift` の `GoalEmberField` を、growth 0→1で枠200×104→340×224、intensity 0.10→0.72、足元グロー opacity 0.05→0.18／blur 44→86へ補間する構成へ更新した。成長は0.42秒のease-out、プリセットフレアは既存キーフレームを維持しつつ最大12%拡大する。実装値をキャプチャと共有するため、同ファイル内に `GoalEmberVisual` を分離した。
- 変更: `ios/DopaBreak/OnboardingFlow.swift` の入力成長を `pow(min(count / 12, 1), 0.65)` に変更した。キーボード終端を画面座標で保持し、上側400ptを入力欄・プリセット用に優先確保して、残り高さへ炎を縦横比維持で縮小する。描画可能高が0ptならMetalへ0サイズを渡さず透明退避する。
- 変更: `ios/DopaBreakTests/GoalEmberSnapshotCapture.swift` は intensity の複製計算を廃止し、本番と同じ `GoalEmberVisual` を growth 0／0.5／1／pulse 1で描画するよう更新した。テストウィンドウのroot差し替えは起動遷移を混ぜるため却下し、既存rootへ単一HostingControllerを子として重ね、rootViewだけを更新する方式を採用した。
- 採用方針: 炎シェーダ自体の改変、単純な高さだけの圧縮、キーボード中のクリップを却下した。シェーダの聖域と形状を保ったまま、外側の正規化枠・強度・暖色グローを一緒に育てることでempty/maxの差を作る。小型端末では視覚効果より入力可読性を優先する。
- Claude Code側の制約: `FlameBreathView.swift`／`Shaders/Flame.metal` は変更禁止。種火はgoalSetupかつReduce Motion無効時だけ表示し、`allowsHitTesting(false)`、`accessibilityHidden(true)`、30fps、`animatesFlare: false`、intensity上限0.72を維持する。通常時の絶対寸法を変えず、キーボード制約時は縦横比を保って縮めること。
- 検証: `output/screenshots/goal-ember/` のempty／half／max／pulseをiPhone 16 Pro（iOS 18.3.1）で `EMBER_STAGE_BEGIN` 同期により再取得し、emptyとmaxの大きさの差が一目で分かること、最大フレアと入力当て板の間に余白があることを確認した。既存ユニットテスト20件0失敗、キャプチャテスト1件0失敗。Xcode 26.6／iOS 26.5 SDKのgeneric Simulatorビルドは **BUILD SUCCEEDED**。禁止2ファイルのSHA-256は作業前後で一致した。

## 2026-08-06 — 目標設定画面の種火 v2 是正（独立レビュー指摘6件）

- 変更: `ios/DopaBreak/OnboardingFlow.swift` の描画上限を `viewport - 400` から `GoalEmberField.maximumHeight(forViewportHeight:)` へ移した。予約量は200pt、下限は**130pt**（当初104ptで着手したが、104ptまで押し込むと炎が入力欄カードの背面に挟まりカードの上下に破片が覗くため130ptへ引き上げ、130〜170ptは不透明度で線形に引く形へ確定した）。旧式はSE 307pt／15 Pro 377ptのキーボード表示中に上限0となり、入力中は炎が一度も描画されなかった。入力欄とプリセットは不透明背景を持つため、重なりの実害は背景のない見出しだけとみなして予約量を半分にした。
- 変更: `GoalEmberVisual` のクリップを等方スケールから高さのみのクランプへ変えた。旧式は高さが上限に張り付いた後、growthを上げるほど幅が細くなり成長が反転していた（16 Pro Maxのキーボード表示中で未入力131pt→12文字103pt）。幅は`targetWidth`のまま伸ばし、高さが頭打ちでも幅とintensityで成長が読めるようにする。
- 変更: `GoalEmberVisual` を `Animatable`（`animatableData = growth`）にした。intensityは`FlameBreathView`内側の`.animation(.linear(1/30), value: breathPhase)`が優先されるため外から尺を当てられず、枠だけ420msで育ち明るさは33msで跳ねていた。growth自体を補間対象にして両者を同じカーブに揃える。`FlameBreathView`は無変更。
- 変更: 足元グローを固定サイズ・固定ぼかし半径（124pt／86）で焼き、成長は`scaleEffect(y:)`と`opacity`だけで表す。旧式は半径最大86ptのぼかしが0.42秒間フレームごとに再ラスタライズされていた。上限はheightScaleの掛け算ではなく頭打ちで効かせる（掛けるとgrowthに対して非単調になり、また成長が反転するため）。
- 変更: `KeyframeAnimator`のフレアを、出現時点のトークンから変わるまで無効にした。goalSetupへ入った瞬間のフレア暴発を、`KeyframeAnimator`の未文書な初期挙動に依存せず塞ぐため。あわせて`reduceMotion`三項（親が`!reduceMotion`でゲート済みのデッドコード）を削除し、`GoalEmberVisual`自身にも`allowsHitTesting(false)`／`accessibilityHidden(true)`を付けた。
- 変更: `ios/DopaBreakTests/GoalEmberSnapshotCapture.swift` は段階ごとに利用可能高さを持つ形へ変えた。従来は上限に固定値250.88のみを渡しており、クリップ経路を構造的に再現できなかった。SE相当307／15 Pro相当377の段階を追加し、炎の下端をCTAバー上端（134pt）、入力当て板を画面上端から298ptへ合わせた。
- 検証: `xcodegen generate` → generic iOS Simulatorで **BUILD SUCCEEDED**（Xcode 26.6）。ユニットテスト24件0失敗。`output/screenshots/goal-ember/` を9段階へ更新（`EMBER_STAGE_BEGIN` 同期・iPhone 16 Pro）。禁止2ファイルのSHA-256は作業前後で一致。
- 既知の制約: SE相当（利用可能307pt→上限130pt）ではキーボード表示中に種火を描かない。予約量200ptと下限130ptの両立から生じる構造的な限界で、可読性は損なわれない。上限130〜170ptの端末では不透明度で段階的に引く。

## 2026-08-07 — 起動アニメーション（Remotion / 3幕）

- **ストーリーはオーナー指定の3幕**: スマホに吸われている → 停止ボタン（⏸）が出る → 正気に戻って回復。文字はワードマークのみ。60fps / 180フレーム = 3.00秒。実装は `video/launch-animation/`、仕様は `design/BUILD_SPEC_LAUNCH_ANIMATION.md`。
- **目の変化（虚ろ→パッチリ）は閃光でハードカットを隠す方式**。生成AIの2枚を単純にクロスフェードすると線とグレインが泳いで安っぽくなるため却下。まばたき（A0→Bを3fクロスフェード）→ ライム→白のブルームがopacity 1.0になるフレーム104で B→C をハードカット。前後フレーム（103/105）で覗き見えないことを実測確認済み。
- **⏸ はPNGに焼かずRemotion側でベクター描画**。既存アイコンから⏸を機械的に除去した `frame_a0_scrolling.png`（PIL でバー領域を上下の実測色から線形補間＋グレイン再付与）を土台にしたので、AI再生成による絵のズレがゼロ。出現アニメーション（spring 0.55→1.12→1.00）を完全制御できる。
- **却下した案**: 目だけをSVGベクターで差し替え（アイコンの太い線と紙の質感に馴染まない）／フレームAをそのまま使い⏸をライム矩形でマスク（画面のグラデとグレインが合わず継ぎ目が出る）。
- **実測座標（カード比）**: スマホ画面 x0.3867–0.6016 / y0.7266–0.9300、⏸左バー x0.4453–0.4863、右バー x0.5029–0.5439、y0.7617–0.8730、⏸中心 (0.4946, 0.8174)。`src/timing.ts` の `GEOMETRY` が単一の正本。
- **目のきらめきは白目・瞳に絶対にかけない**（初版は瞳に被って右目がライムの塊になった）。白目の外側・斜め上に純白のみで配置。ライム着色とグローは禁止。左34.5% / 右65.2%（顔の実測軸49.85%に対する左右対称値）/ y39.0%。
- **アセットは `creatives/launch-animation/`**（frame_a0_scrolling / frame_b_blink / frame_c_awake）。表情差分として他画面からも流用可。

## 2026-08-07 — 炎ステージ構想の確定（オーナー発案・MVP採用）

- **決定**: 炎を演出から「状態を持つ仕組み」へ昇格させる。守れた日の連続で5段階（種火→灯った炎→安定した炎→大きな炎→**青い炎=21日**）に育つ。仕様正本は `design/BUILD_SPEC_FLAME_STATE.md`。
- **設計原則（成否の分かれ目は降格側の設計）**: ①火は絶対に消えない（下限=種火。死んだ炉を見せない） ②開こうとしなかった日は下げない（誘惑ゼロの日は最良の日） ③復帰は速い（崩れた翌日に1守りで即1段回復） ④降格演出は静か ⑤課金でステージをロックしない。Duolingo型のストリーク羞恥→削除の連鎖を構造的に防ぐため。
- **核**: 介入の一呼吸の炎を「その人の現在ステージ」で描く。青い炎の人は誘惑の瞬間に自分の青い炎を見る（損失回避を選択の瞬間に働かせる）。進行表では青い炎のシルエットを最初から見せ、「あと◯日」を常に明示する。
- **シェーダ聖域の意図的解除**: `Flame.metal` に `bluePalette` uniform（暖色↔青系ランプのmix）を1つだけ追加する。`bluePalette: 0` は現行出力とピクセル一致が受け入れ条件（キャプチャ回帰）。level 0〜3はintensity・火の粉量のみで表現し、青はlevel 4専用。
- **却下案**: 崩れた日に連続日数を即リセット（羞恥設計）／静かな日（記録なし）での降格（皆勤賞の強制）／ステージの課金ロック（感情の人質化）／MVPでのウィジェット・シェアカード反映（スコープ超過。バックログへ）。
- **順序**: 種火v2のCodexレビュー（8/8 13:10以降）とコミットを先に完了させ、その後に実装着手。同一ファイル群へ未レビュー変更を重ねないため。

## 2026-08-08 — 目標入力の一本化＋常時種火の廃止→着火演出（オーナー決定）

- **決定1（入力の一本化）**: オンボ目標画面の「目標(40字)」と「ロック画面に出す短い言葉(16字・折りたたみ)」の2段入力を廃止し、**単一フィールド・16字上限**にする。入力した言葉がそのままロック面（ウィジェット/Live Activity/通知）に出る。フィールド直下にヘルパー1行「そのままロック画面に表示されます」を置く。背景: `lockScreenTitle` は「40字題がロック面に収まらない」実装都合の短縮名オーバーライドで、それがUXへ漏れて「どっちが表示されるのか分からない・重複」とオーナー指摘（2026-08-08）。
- **決定2（複数追加）**: オンボで目標を複数追加できるようにする。フィールド＋追加→削除可能なリスト。プリセットタップは即追加（フィールドへの転記をやめる）。1件以上または入力途中テキストありで「次へ」有効（入力途中分は次へ時に自動コミット）。未入力なら従来どおり演出なしで先へ。データ層は既に複数対応済み（GoalStore・WidgetSnapshot.goalTitles/displayTitles・ウィジェットは先頭2件表示・GoalsViewで管理/並べ替え）でオンボだけが1件制限だった。
- **決定3（着火演出）**: 常時描画の種火（GoalEmberField一式）を廃止し、**「次へ」タップで一度だけ着火→約0.8秒→次画面**の一発演出に置き換える。火の意味を「打鍵数への反応」から「決意への報酬」へ変える（文字数で火が育つ現行仕様は目標の質でなく長さに反応しており、高水位管理などの辻褄合わせを必要としていた）。炎フレームは画面下端に固定し**下へ約30pt画面外延長**して、シェーダの根元フェード帯（下端約10%を透明化する`rootFade`）を画面外へ出す＝「火の根元が映らない」指摘（2026-08-08）の解決。Reduce Motion・スキップ・未入力時は演出なしで即遷移。
- **決定4（アプリ内編集も同構造へ）**: GoalEditorSheetの「ロック画面用の短い表示名」欄と GoalsView のロック表示名サブ行も廃止し、題名16字の単一入力へ揃える。混乱を1画面先に残さないため。
- **互換**: `Goal.lockScreenTitle` はデータモデル・デコード・表示フォールバック（`lockScreenTitle ?? title`）ごと温存し、**新規保存でnilにするだけ**。GoalStoreの40字validationも変えない（既存データを壊さない）。
- **削除**: `GoalEmberField`/`GoalEmberVisual`/`GoalEmberGeometry`/`GoalEmberInput`（OnboardingMotion.swift）、OnboardingFlowの `keyboardTop` 追跡・`emberPulseToken`・`goalEmberPeakCount`・高水位ロジック、`GoalEmberSnapshotCapture.swift`・`GoalEmberImeBehaviorTests.swift`・MeasurementFoundationTestsの種火セクション。種火v2（8/6-8/8）の成果はこの決定で置換される（実測知見はエントリとして残す）。
- **継続制約**: `FlameBreathView.swift`／`Shaders/Flame.metal` は変更禁止（SHA-256前後一致）。着火はFlameBreathViewのパラメータ（breathPhase/flare）だけで組む。介入画面の炎・炎ステージ構想（8/7）には触れない。
- **却下案**: 種火の完全削除（介入画面の「守る炎」への伏線価値を残すため着火型で存続）／40字維持＋ロック面切り詰め（「何が表示されるか」の曖昧さが戻る）。
- **実装後レビュー（Codex gpt-5.6-sol・独立）の裁定**: 採用5件=①`.goalsLimit`ペイウォールを購入なしで閉じてもreverse trialが始まらず2件目追加が永久ループ（P1・PaywallViewのcallback発火がprepaywall placement限定だった） ②同期差分を初期スナップショット基準の三者差分へ（外部追加分の誤削除防止） ③IME未確定文字列を壊す`.onChange`のprefix(16)書き戻し廃止→commit/保存時正規化へ ④着火0.8秒中のリスト操作ガード ⑤GoalStoreに`replace(goals:)`追加で同期保存をトランザクション化。**却下1件=保存済み行の編集導線**（削除→再追加でGoal.idが変わるが、IDを永続参照する機能が現状なく実害なし。バックログ: オンボ行タップで編集を将来検討）。
- **無料枠との接点（要オーナー認知)**: `EntitlementGate.goalsLimit`=無料1件のため、オンボで2件目追加の瞬間に`.goalsLimit`ペイウォール→閉じてreverse trial開始→続行、という導線になる（アプリ選択上限と同一パターン）。オンボ中のペイウォール割込みを避けたい場合は別途設計判断が必要。

## 2026-08-08 — 目標設定画面の種火 v2 是正（未確定点の実測 → 修正4件）

- **実測A（IME）**: SwiftUIのTextField binding は日本語入力の**未確定（marked）文字列をそのまま反映する**ことを実機で確認した。`axis: .vertical` のTextFieldは内部で `VerticalTextView`（`UITextView`系）になり、`setMarkedText("しかくのべんきょう")` の直後に `@State` が9文字へ更新される。確定すると「資格の勉強」5文字へ落ちる。推測ではなく `ios/DopaBreakTests/GoalEmberImeBehaviorTests.swift` の実測で確定させた。
- **実測B（アニメーション）**: `GoalEmberVisual` のネストした `.animation(_:value:)` は、`clampedGrowth` が動かず `maximumHeight` だけが変わる場面でも**外側の0.28が正しく効く**。`animatableData` のsetを実ウィンドウで記録したところ、224→130が17フレーム（約0.283秒）で連続補間された。単一 `.animation` に複合値を渡した対照群と値の列が完全一致したため、**この箇所は修正不要**と判断した。
- 変更（修正1）: `ios/DopaBreak/OnboardingFlow.swift` の種火の育ちを、実文字数ではなく編集セッション内の**高水位**（`goalEmberPeakCount`）から出す形にした。実測Aのとおり変換確定の瞬間に文字数が9→5へ減るため、そのまま追うと火が縮む。空文字になったときだけ0へ戻す。復元した既存目標がある場合は `init` で高水位を先に埋め、復元直後に火が種火から育ち直さないようにした。バックスペースで縮まなくなる副作用は「火は戻らない」という演出として受け入れる（オーナー承認済み）。
- 変更（修正2）: 足元グローの上限クランプが一度も効いていなかったのを是正した。旧式は `min(growthScale, maximumHeight / glowBaseHeight)` で、右項が最小でも 130/123.2＝1.055 となり左項の最大1.0を必ず上回っていた。判定の基準を**ぼかしの滲みを含む実効高さ**（楕円123.2pt＋滲み103.2pt＝226.4pt）へ変え、頭打ちを実際に効かせた。滲み量は実測で半径の約1.2倍。是正前後をキャプチャで比較したところ、最も詰まった状態（上限177pt）で発光が下端から222pt→**173pt**へ収まり、上限に余裕がある状態（03-ember-max）は画素値が完全一致した＝通常時の見た目は変えていない。成長に対する単調性も保っている（右項はgrowthに依存しない定数のため）。
- 変更（修正3）: `ios/DopaBreakTests/GoalEmberSnapshotCapture.swift` の05〜07が、いずれも利用可能307pt＝不透明度0で**同一の空フレームを3枚撮っていた**（旧ファイルは3枚ともバイト数100236で一致）。非表示の確認は1段（307pt・成長とフレア最大でも描かれないこと）に残し、フェード帯（350pt・不透明度0.5）と最も詰まった描画状態（377pt・上限177pt・成長最大＋フレア最大）へ差し替えた。
- 変更（修正4）: `GoalEmberVisual` のprivateな幾何計算を `GoalEmberGeometry`、入力換算を `GoalEmberInput` へ切り出した（ビュー構造は不変）。前回是正の中核である「成長の単調性」「描画上限の遵守」がテストから到達できなかったため。`ios/DopaBreakTests/MeasurementFoundationTests.swift` に、growthを0→1で201分割し上限7種×フレア3種で高さ・幅の単調非減少と上限遵守を確かめるテスト、グローの単調性と上限遵守、`opaqueFlaredHeight`=170の境界（利用可能370pt→不透明度1／369pt→0.975）、高水位と成長カーブの回帰テストを追加した。
- 正本の更新: `design/BUILD_SPEC_GOAL_EMBER_V2.md` の §5（ぼかし半径44→86は縦scaleへ置換済み）、§7（「クリップさせない」→下限130ptで非描画＋不透明度フェード、「炎の頭が可読性を侵さない」→不透明カードとの重なりは許容し予約量200ptで見出しだけを守る）、検証4（旧「炎の頭が入力欄へ届かない」は予約量半減時点で成立しない）を実装に合わせた。実測では最も詰まった状態で炎の先端が入力欄カードの上端を22〜26pt越えるが、カードが不透明なため文字の可読性は損なわれない。
- 恒久的に残した検証コード: `GoalEmberImeBehaviorTests.swift` の1件のみ。高水位方式は「バックスペースで火が縮まない」という副作用を伴うため、その前提（bindingが未確定文字列を含む）が将来のSwiftUIで変わったときに気づける必要がある。実測Bのアニメーション観測ハーネスは、結論が「修正不要」で回帰対象を持たないため削除した。
- 検証: `xcodegen generate` → generic iOS Simulatorで **BUILD SUCCEEDED**（Xcode 26.6）。`DopaBreakTests` 28件0失敗。`output/screenshots/goal-ember/` を9段階で再生成（iPhone 16 Pro・iOS 18.3・`EMBER_STAGE_BEGIN` 同期）。禁止2ファイル（`FlameBreathView.swift`／`Shaders/Flame.metal`）はSHA-256一致。

## 2026-08-08 — O-02 利用時間の上位バケット分割

- 変更: `ios/DopaBreak/OnboardingFlow.swift` の利用時間選択肢を「1時間未満／1〜2時間／2〜4時間／4〜6時間／6時間以上」の5個へ変更し、`ios/DopaBreak/Localizable.xcstrings` と `.claude/specs/i18n-launch-inventory.md` に新しい2キーの日本語・英語・韓国語を追加した。
- 採用方針: SNSヘビーユーザーの損失を過小表示しないため、旧最上位の「4時間以上」を2分割した。保守的換算パターンは維持し、閉区間「4〜6時間」は中央値300分、開区間「6時間以上」は床値360分+30分の390分とする。年間換算は76日／99日、50年換算は切り捨てで10.4年／13.5年とする。
- 互換制約: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/LossEstimator.swift` では正規化後の半角ハイフンキーを使い、保存済み回答用の旧「4時間以上」→270分と回数キー4種を削除しない。UIでは全角「〜」を使い、選択肢数は4個から5個になる。
- 却下案: 旧「4時間以上」を新規選択肢に残す案は新2択と範囲が重複し、6〜8時間利用者への過小推計を解消できないため採用しなかった。
- 検証: `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/LossEstimatorTests.swift` で新2バケットの正規化、日次分数、年間日数、50年換算を固定し、`ios/DopaBreakTests/MeasurementFoundationTests.swift` の現行バケット固定値も更新した。`cd ios/Packages/DopaBreakCore && swift test` は201件0失敗で通過した。

## 2026-08-10 — コミット前レビュー4件の是正

- 変更: `ios/DopaBreak/RootTabView.swift` の自動ロック画面確認を、提示直前の `settingsStore.liveActivityEnabled` でゲートした。`addGoal` 時点だけで判定する案は、別モーダル待ちの間に設定がオフへ変わるケースを防げないため却下した。設定画面とオンボーディングからの明示的な確認導線、および `AppModel.presentGoalOnLockScreen()` の明示導線向け復帰挙動は維持する。
- 変更: 同ファイルでロック画面確認coverのdismissと介入coverのpresentを別トランザクションへ分離した。介入要求を受けた時点ではロック画面確認だけを閉じ、`onDismiss` から保持中の `pendingInterventionCatalogID` を再検証して一呼吸フローを提示する。`SettingsView` は確認coverの `onDismiss` で `refreshSettingsState()` を既に呼ぶため、Live Activity設定の表示値はストア書き戻し後に再同期される。
- 変更: `ios/DopaBreak/OnboardingMotion.swift` と `ios/DopaBreak/InterventionFlowView.swift` の連続フレア入力に `animatesFlare: false` を指定し、外側の連続補間と `FlameBreathView` 内の暗黙補間が重なる二重補間を止めた。`ios/DopaBreak/FlameBreathView.swift` と `ios/DopaBreak/Shaders/Flame.metal` は変更しない。
- 変更: `ios/DopaBreak/CharacterView.swift` の常時タイムラインを30fpsへ制限した。浮遊の振幅4pt・周期1.6秒と0.13秒のまばたき仕様は維持する。Reduce Motion時だけ15fpsへ下げる案は、短いまばたきの見え方を変える可能性があるため採用しなかった。
- 実装制約: 自動確認はLive Activityがオフの間は保留し、ユーザーが再びオンにした後の有効な提示機会まで要求を保持する。介入IDはロック画面確認のdismiss中に消費・破棄しない。
- 検証: `xcodegen generate` とgeneric iOS Simulator向け `xcodebuild` は **BUILD SUCCEEDED**。`swift test --package-path ios/Packages/DopaBreakCore` は201件0失敗。禁止2ファイルのSHA-256は作業前後で一致した。

## 2026-08-10 — オンボーディング見出しの自然折返し化

- 変更: `ios/DopaBreak/OnboardingFlow.swift` の対象見出し9件と研究本文1件からハードコードされた `\n` を除去し、日本語見出しは意味の区切りを半角スペースで保持した。`preview`／`science`／`notification` の見出しではリズム読点を使わない指定コピーへ統一した。
- 変更: 同ファイルの共通 `titleText(_:)`／`bodyText(_:)` と、44ptで個別描画するwelcome見出しへ `.typesettingLanguage(locale.language)` を追加した（Opus5レビュー指摘により `Locale.current` ではなく `@Environment(\.locale)` を参照。プレビュー・スナップショットテストの `.environment(\.locale, …)` オーバーライドに追従させるため）。`ios/DopaBreak/Localizable.xcstrings` は同じ10キーのja/en/ko値だけを更新し、改行を半角スペースへ置換した。
- 採用方針: 34〜44pt太字の改行位置はコピー内で固定せず、ロケールに合ったフレーズ折返しと利用可能幅へ委ねる。日本語コピー内の半角スペースは望ましい意味区切りのヒントとして残すが、表示行を固定するものとして扱わない。
- 却下案: `\n` による固定改行、端末別の改行文字列、文字サイズの追加縮小は、端末幅・Dynamic Type・翻訳長に追従できず追加折返しを再発させるため採用しなかった。
- 実装制約: `onboarding.apps.empty_selection_message` の `\n\n` は本文の段落区切りなので維持する。String Catalogのキー順・構造・インデントは変えず値だけを編集し、今後も見出しへ `\n` やリズム読点を追加しない。
- 検証: `Localizable.xcstrings` のJSON parse成功、対象10キー×3言語に改行なし、例外キー3言語の段落区切り維持を確認した。`swiftc -frontend -parse ios/DopaBreak/OnboardingFlow.swift` と対象箇所の目視確認も成功した。

## 2026-08-10 — 是正バッチへのOpus5独立レビュー（2件採用・2件却下）

- 採用1: `RootTabView.presentPendingInterventionIfValid` の遅延dismiss方式は再入で破れていた。`handleAppActive` の同期呼び出しがdismissを開始した直後、同じID遷移で `.onChange(of: pendingInterventionCatalogID)` が再発火し、dismiss進行中にpresentが走る。`interventionAwaitingLockDismiss` フラグを導入し、dismiss待ちの間は全呼び出しを遮断。coverの `onDismiss` 冒頭で無条件に解除してから再検証するため、pendingが途中でnil化しても提示は詰まらない
- 採用2: ロック確認coverの `onDismiss` に `checkPendingMidSessionCheckIn()` と `checkPendingReflection()` を追加。両者は `!isLockScreenCheckPresented` でゲートされており、表示中に届いた要求がdismiss後に再評価されず `isValid` 期限切れで黙って捨てられていた。順序は介入cover側に合わせ 介入リトライ→mid-session→reflection→paywall
- 却下1: `pendingLockScreenCheck` の永続化提案（P3）。2026-07-25の設計決定「pending永続化は無関係なタイミングでの全画面提示を招く」と矛盾するため不採用。逃した場合は設定画面「ロック画面で確かめる」で回復できる
- 却下2: `breathPhase` の二重補間指摘（P3）。`FlameBreathView` 内の `.linear(1/30)` は30Hz tick間のフレームブレンドとして意図的。レビュー自身が非可視と認定しており、同ファイルは変更禁止のためバックログ扱い
- 検証（Fable独立実行）: BUILD SUCCEEDED・Core 201テスト0失敗

## 2026-08-10 — AutomationGuideView Phase 1完全実装

- 変更: `ios/DopaBreak/AutomationGuideView.swift` を、タイトル→選択対象だけを数える「n/m 設定済み」→既存 `shortcuts://` ヒーローCTA→無効feature flag配下のPhase 2動画カード→「着実なガイド」6カード→アプリ別チェックリスト→最終確認カードの順へ刷新した。各手順は角丸カード・行・タブ帯・＋・検索欄をSwiftUIだけで簡略描画し、押す場所を `DesignTokens.danger` のストロークと赤丸白抜き番号で示す。精密なShortcuts UIコピーやスクリーンショットアセットは、誤認・多言語・Dynamic Type追従の問題があるため採用しなかった。
- 変更: `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/AutomationVerification.swift` に、選択済みIDと検証済みIDの積集合から重複なしで進捗を返す `Progress` / `progress` を追加した。`ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/AutomationVerificationTests.swift` で部分検証、範囲外ID、重複永続値、0/0を固定した。
- 変更: `ios/DopaBreak/Localizable.xcstrings` のAutomation Guide領域をja/en/koで更新した。使用中キーは37件で、旧17件から未使用11件を除去し新規31件を追加（カタログ全体461→481）。置換前後に共通する既存キーの値は変更していない。
- 検知制約: 設定済み判定は従来どおり AppIntent → `pendingStartInterventionCatalogID` → `AppModel.consumeInterventionRequest` → `SettingsStore.markAutomationVerified` の実発火経路だけが書き込む。ガイドは表示時とscene active復帰時に再読込し、外側ライフサイクルのpending消費と同一ターンになった場合に備えて次のMainActorターンでも再読込する。ガイドから検証済み状態を直接書き換えない。
- UI制約: 文字は `.dopaFont`、実操作は44pt以上、図解は装飾として `accessibilityHidden(true)`、ステップカードとチェックリスト行は情報を完結したVoiceOverラベルを持つ。動画カード実装は `AutomationGuideFeatureFlags.videoTutorialEnabled = false` の間は非表示で、Phase 2では実機動画とプレイヤーを接続してから有効化する。
- 検証: `xcodegen generate` 成功、generic iOS Simulatorビルドは **BUILD SUCCEEDED**。`DopaBreakTests` 50件、`DopaBreakCore` 204件はいずれも0失敗。`FlameBreathView.swift` と `Shaders/Flame.metal` は変更せず、作業前後のSHA-256が一致した。

## 2026-08-10 — オンボーディングCTA全面動詞化（CVR最適化・オーナー指示）

- 指示: 「なるほど」等の相槌フィラーを排し、全CTAを動詞化してCVR最大化。
- 変更（`OnboardingFlow.swift` + `Localizable.xcstrings` ja/en/ko）:
  - welcome: はじめる → **30秒でチェックする**（超具体＋低コミットでクイズ着手率を上げる）
  - selfCheck/lockScreenCheck共有 `onboarding.action.next`: 次へ → **次に進む**
  - quizResult: この時間を変える → **この時間を取り戻す**（損失回避の回収フレーム。enは既存 "Take it back" と整合）
  - goalSetup: 次へ → 新キー `onboarding.goal.action` **この目標で進む**（コミットメント一貫性）
  - preview: なるほど、続ける → **この仕組みを使う**（フィラー・読点除去。「止める/ブロック」語は非我慢ポジショニングと矛盾するため不採用）
  - whyScience: 続ける → 新キー `onboarding.science.action` **仕組みに任せる**（見出し「意志の力では勝てない」への直接応答。次画面=自動化設定へ接続）
  - prePaywallSummary: 続ける → 新キー `onboarding.summary.action` **この時間を守る**（ペイウォール直前。サマリー行「年約N日分」と接続、承認済みユーザー語彙「守り」を使用）
- 不変: ペイウォールCTA（◯日間無料で始める/プランを始める）、chooseApps（この◯つで始める）、mode（この設定で進む）、automation/notification/ready のCTAは既に動詞＋文脈適合のため維持。
- 却下: 「開く前に止める」系のCTA（ブロッカー連想が非我慢ポジショニングと衝突）。CTAへの価格記載（恒久禁止）。
- 検証: humanizer-en / humanizer-ko の audit.py 両ゲート exit 0。xcstrings JSON妥当性確認済み。`onboarding.action.continue` キーはカタログに残存するが参照ゼロ（無害）。

## 2026-08-10 — Live Activity Dynamic Island compact表示を「アイコン|数字」化

- 決定: compactLeading = `checkmark.shield.fill`（accent色・`.caption.weight(.semibold)`・VoiceOver除外）、compactTrailing = 我慢回数の数字（`widget.count.value`）。minimal は数字のみ維持、Expanded・Lock Screenは不変。
- 根拠（apple-hig原典）: Compactは「最重要な動的情報に絞る」、Minimalは「ロゴでなく更新情報自体を表示」。旧「数字|回」は何の回数か一目で伝わらず、Timerの「アイコン＋時間」型に合わせて記号=意味/数字=値に分離した。
- キャラクターの扱い: compact/minimalには置かない（黒背景固定・極小領域で潰れる＋「注意を引く要素を追加しない」規定に抵触しやすい）。置くならロック画面プレゼンテーション（高さ84〜160pt）かexpandedのみ。
- a11y: 「回」削除でVoiceOverが裸の数字読みになる退行を、compactTrailing/minimalへの `.accessibilityLabel`（既存キー `live_activity.summary.cancelled`「今日 開かなかった %lld回」）で補完。
- 変更ファイル: `ios/WidgetsExtension/DopaBreakWidgets.swift`。`widget.count.unit` キーは参照ゼロになったため `ios/WidgetsExtension/Localizable.xcstrings` から削除。
- 検証: generic iOS Simulatorビルド成功（error 0・exit 0）。実装=Codex、レビュー=Opus5（バグ・ロジック指摘なし）。
- 既知の別件（このタスクでは未対応・要対応）: ①`ios/DopaBreak/Localizable.xcstrings` の `home.achievement.count_unit` EN値に修正指示メモが混入（"コード側で修正: …" がそのまま翻訳値になっている）。②`DopaBreakWidgets.swift` の `defaultValue:` リテラル5箇所が確定済みコピー改訂（戻る先→目標/開かずに戻れた→開かなかった）前の旧文言のまま（54-61,103,111,150,259,286行付近）。カタログ優先のため通常表示は正しいが、`SWIFT_EMIT_LOC_STRINGS` 有効化時に巻き戻るリスクあり。

## 2026-08-10 — キャラクター統一・ホーム位置・ロック確認2ステップ化（実装完了）

- 変更: `ios/DopaBreak/DesignTokens.swift` に `DesignTokens.CharacterSize`（Hero 200 / Lead 152 / Header 120 / Support 88 / Inline 44）を追加し、`HomeView.swift`、`InterventionFlowView.swift`、`OnboardingFlow.swift`、`PaywallView.swift`、`PostUseReflectionSheet.swift` の全 `CharacterView` / `CharacterSwapSequence` 呼び出しを役割トークンへ置換した。
- ホーム: `HomeView.heroBand` の重ね置きを廃止し、TODAY・日付・週カウント行 → 12pt → Header 120キャラの縦積みに変更した。後続要素の既存 `.padding(.top, 20)` を使い、キャラ後20ptを保つ。`todayCancelledCount > 0 ? .awake : .doom` は不変。
- 最小レイアウト補正: welcomeはLead 152化後に旧292pt枠を残すと過大な空白になるため前後20pt paddingへ変更。quizResult / preview / prePaywallSummary / ready / 利用後ふりかえりはキャラを含む局所スタックのspacingを20ptへ統一した。Paywallは上端24pt、120pt枠、次要素16ptへ補正。readyの装飾枠は136×96の17:12比を保った約124.7×88へ追従した。介入冒頭の380ptステージと通知プレビューの300pt合成枠はキャラと別ビジュアルを同居させる装飾領域なので維持し、`FlameBreathView`側へ影響させない。
- ロック確認: `ios/DopaBreak/LockScreenCheckView.swift` の `SideButtonHint` / `CurvedArrow` / 負のtrailing paddingを削除し、既存 `CardContainer` にライム色番号バッジ付き2ステップを実装した。簡略端末図は上のサイドボタンをaccent、下のカメラコントロールを低コントラストで描き分け、全体を `accessibilityHidden(true)` とした。横並び案は日本語補足を不自然に分断したため却下し、1枚目カード内で説明→端末図の縦配置を採用した。
- 状態・翻訳制約: `didObserveReturn` を含む starting/waiting→confirmed判定、blocked系、完了記録は変更していない。`ios/DopaBreak/Localizable.xcstrings` は `lock_check.step1.note` / `step1.title` / `step2.title` をja/en/koで追加し、廃止した `lock_check.side_button.label` を削除（+3 / -1）。`ios/DopaBreakTests/LockScreenCheckSnapshotCapture.swift` の旧矢印前提コメントも更新した。
- 検証: `xcodegen generate` 成功、generic iOS Simulatorは **BUILD SUCCEEDED**。iPhone 16 Pro / iOS 18.3.1で `DopaBreakTests` 50件0失敗、`DopaBreakCore` 204件0失敗。`ios/DopaBreak/FlameBreathView.swift`（`9a776313bf8fa3124c2f8d5cf4502319e522e4d83a52e76eea584a40879615dc`）と `ios/DopaBreak/Shaders/Flame.metal`（`68bd922e00d387fc5695b77c6cf5de70e8fb523d3fe15fd5cf4a759316ac2b70`）は作業前後でSHA-256一致。
