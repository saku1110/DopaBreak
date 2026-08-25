# ロック画面確認: サイドボタン位置マーカー（2026-08-25）

## 目的
オンボーディング「ロック画面に出しました」ステップで、**画面右端の、実際の物理サイドボタンと同じ高さ**に目印を出し、文言と矢印でそこを指す。参考は Lock Screen Notes アプリの案内画面（右端に縦バー・左に「クリックしてロック画面のノートを見る」＋矢印）。
いまの `SideButtonDeviceIllustration`（60×96ptの抽象端末図）は物理位置と無関係なので廃止する。
あわせて英語eyebrow `LOCK SCREEN` を削除する（オーナー指示: 装飾用の英語eyebrowは使わない）。

## 触ってよい／いけない範囲
- 対象: `ios/DopaBreak/LockScreenCheckView.swift`（`LockScreenCheckContent` / `verificationSteps` / `SideButtonDeviceIllustration` / `LockScreenCheckSheet` / `LockScreenStepRow`）、`ios/DopaBreak/OnboardingFlow.swift`（`lockScreenCheckContent` のみ）、`ios/DopaBreak/Localizable.xcstrings`（`lock_check.*` のみ）、新規 `ios/DopaBreak/DeviceSideButtonGeometry.swift`、テスト
- **触らない**: `LockScreenGoalPreview`（Phase 4で `GoalsView` と共有部品になった）、`phase` の状態機械（`Self.phase(for:didReturnFromLockScreen:current:)`）、`start()` / `refreshStatus()` / `LockScreenCheckAction`、`blocked` / `noGoal` の分岐、`OnboardingFlow` の他ステップ、`goals.*` / `settings.*` キー
- `.onboardingStagger` の**順序**は維持する（eyebrow削除で index を0から詰め直す。別セッションのモーション改修 Step D がこの順序に依存する）

## 1. 英語eyebrowの削除
- `LockScreenCheckContent.body` 先頭の `SmallLabel(text: String(localized: "lock_check.eyebrow", ...))` を削除
- `Localizable.xcstrings` から `lock_check.eyebrow` キーを削除（ja/en/ko）
- stagger を title 0 / lead 1 / 以降 +1ずつ詰める

## 2. サイドボタン位置マーカー

### 2-1. 端末ジオメトリ（新規 `DeviceSideButtonGeometry.swift`）
```swift
/// 物理サイドボタンの縦位置を、画面の論理座標（pt・画面上端基準・セーフエリア無視）で返す。
struct DeviceSideButtonGeometry {
    /// 画面上端からボタン上端までのpt
    let top: CGFloat
    /// ボタンの長さpt
    let length: CGFloat
    /// Camera Control（右側面の下側のボタン）があるか。iPhone 16系のみ true
    let hasCameraControl: Bool

    static func current() -> DeviceSideButtonGeometry
}
```
- 判定キーは `utsname.machine`。シミュレータでは `ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]` を使う
- 値は下の「端末寸法表」の **「サイドボタン上端Y / 画面論理高さ」「長さ / 画面論理高さ」の割合** をモデルごとに持ち、実行時の `UIScreen.main.bounds.height`（縦向き）に掛けて pt にする。**画面の論理高さは実行時に取り、固定値で持たない**
- 識別子が表にないとき: 画面論理サイズ（w×h pt）が一致する既知モデルの値を使う。それも無いときは **フォールバック割合**（表の Face ID 機の中央値。調査結果で確定）を使う
- **記憶で数値を書かない。** 下の寸法表の値だけを使い、表が「不明」のモデルは画面サイズ一致のフォールバックへ落とす
- 単体テスト（`DopaBreakTests`）: 代表モデル3つ（16 Pro / 15 / SE 3rd）で `top` / `length` / `hasCameraControl` が表の値どおりになること、未知識別子＋既知画面サイズでフォールバックすること、完全未知でデフォルトに落ちること

### 2-2. マーカーの見た目（`SideButtonEdgeMarker`）
参考画像と同じ構成。画面**右端に密着**した縦バー、その左に矢印と文言。
- 縦バー: 幅 5pt、高さ = `geometry.length`（**最小 56pt**。実寸が短い端末でも見えるように）、色 `DesignTokens.accent`、角は Capsule、右端は画面端に密着（safe area・`screenScroll` の横パディング20ptを無視して `ignoresSafeArea(.all, edges: .trailing)` で描く）
- 位置: バーの上端Y = `geometry.top`（画面上端基準）。上端がプログレスヘッダーと被る場合でも位置は動かさない（実物の位置が正）
- 文言ブロック（バーの左・右寄せ・複数行可・幅は画面幅の 60% 以内）:
  - 1行目〜: `lock_check.side_button.label` = 「サイドボタンを1回押して画面を消す」（`dopaFont(22, weight: .black, lineSpacing: 4)`、`primaryText`、`multilineTextAlignment(.trailing)`）
  - 注記（**`hasCameraControl == true` のときだけ**）: `lock_check.side_button.camera_control_note` = 「下のカメラボタンではなく上のボタン」（`dopaFont(13, weight: .semibold)`、`secondaryText`）
  - 矢印: SF Symbol `arrow.turn.right.up`（右上へ曲がる矢印。参考画像の「↗」に相当）を文言の下に右寄せで置く。サイズ 28pt、`primaryText`。バーが文言ブロックより上にある場合は `arrow.turn.right.up`、下にある場合は `arrow.turn.right.down` に切り替える
- 文言ブロックの垂直位置: ブロックの中心Y = バーの中心Y に揃える。ただしブロック上端が**プログレスヘッダー下端 + 8pt** より上に来るなら、そこまで下げる（このときバーはブロックより上になるので矢印は `arrow.turn.right.up`）
- 出す条件: `phase == .waiting`（掲出中でユーザーがまだ確認していない）のときだけ。`.confirmed` / `.blocked` / `.noGoal` / `.starting` では出さない
- 登場: `.waiting` になった時に opacity 0→1（`DopaMotion` の既存 fade を使う。Reduce Motion では即時表示）。装飾アニメは入れない
- a11y: `accessibilityElement(children: .combine)`、ラベルは文言＋注記。バーは `accessibilityHidden(true)`

### 2-3. 本文レイアウトとの共存（重なり防止）
マーカーは画面座標に固定されるので、スクロール本文と重ならないよう**本文側に空きを作る**。
- `LockScreenCheckContent` の `.waiting` 時の並び:
  1. タイトル「ロック画面に出しました」（今のまま・中央揃え）
  2. **空き（スペーサー）**: 高さ = max(0, マーカーブロック下端Y − タイトル下端Y + 16pt)。座標は `GeometryReader` + `PreferenceKey` で画面座標に変換して求める（iOS 17 のため `onGeometryChange` は使わない）
  3. 手順2カード（`LockScreenStepRow(number: 2, ...)` はそのまま）
  4. プレビュー（`LockScreenGoalPreview`・変更なし）
  5. 許可注記（`permissionNote`・変更なし）
- 手順1カード（`LockScreenStepRow(number: 1, ...)` ＋ 端末図）は削除する。手順1の役割はマーカーの文言が担う
- `.confirmed` / `.blocked` / `.noGoal` のレイアウトは変えない（スペーサー0・マーカー非表示）
- スクロールしても本文がマーカーの**下をくぐる**ことは許容する（マーカーが常に前面）

### 2-4. 組み込み先
- `OnboardingFlow.lockScreenCheckContent`: `screenScroll { ... }` に `.overlay(alignment: .topTrailing) { SideButtonEdgeMarker(...) }` を付け、overlay は `ignoresSafeArea()` で画面座標基準にする。プログレスヘッダーの下端Yは `OnboardingFlow` 側で `PreferenceKey` で取り、マーカーへ渡す
- `LockScreenCheckSheet`（目標追加後・設定からの単独表示）: 同じ overlay。ヘッダーが無いので「ヘッダー下端」は safe area top とする
- `LockScreenCheckSnapshotCapture`（既存テスト）: `01-waiting` の描画にマーカーを含める。`ImageRenderer` は overlay の `ignoresSafeArea` を解釈しないので、テスト側では 393×852 の `ZStack` に直接 `SideButtonEdgeMarker` を重ね、`DeviceSideButtonGeometry` は iPhone 15 相当の値を明示注入する（`current()` ではなく `init(top:length:hasCameraControl:)` を使う）

### 2-5. 文言（ja / en / ko・xcstrings に追加）
| キー | ja | en | ko |
|---|---|---|---|
| `lock_check.side_button.label` | サイドボタンを1回押して画面を消す | Press the side button once to turn off the screen | 측면 버튼을 한 번 눌러 화면을 끄세요 |
| `lock_check.side_button.camera_control_note` | 下のカメラボタンではなく上のボタン | The upper button, not the camera control below | 아래 카메라 버튼이 아니라 위쪽 버튼 |
- 既存 `lock_check.step1.title` / `lock_check.step1.note` は手順1カード削除に伴い**キーごと削除**
- `lock_check.step2.title` は維持

## 3. 端末寸法表（確定・2026-08-25 Opus5調査、Apple公式寸法図の右側面図から直読＋ピクセル検証PASS）

算出式（mmだけで完結・ptを経由しない）:
- `topFraction = (ボタン上端mm − 上ベゼルmm) ÷ 画面アクティブ領域高さmm`
- `lengthFraction = ボタン長さmm ÷ 画面アクティブ領域高さmm`
- 実行時: `top = topFraction × UIScreen.main.bounds.height`、`length = lengthFraction × UIScreen.main.bounds.height`（縦向きの論理高さ）

| モデル | 識別子 | 全高mm | 上ベゼルmm | 画面高mm | ボタン上端mm(端末上端基準) | 長さmm | 論理pt | 上端割合 `topFraction` | 長さ割合 `lengthFraction` | Camera Control | 出典 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| iPhone XS | `iPhone11,2` | 143.57 | 3.91 | 135.75 | 32.84 | 17.10 | 375×812 | **0.2131** | **0.1260** | なし | ADG2022 p.218 |
| iPhone XS Max | `iPhone11,6` `iPhone11,4` | 157.53 | 3.91 | 149.71 | 32.84 | 17.10 | 414×896 | **0.1932** | **0.1142** | なし | ADG2022 p.217 |
| iPhone XR | `iPhone11,8` | 150.91 | 5.57 | 139.78 | 34.10 | 17.10 | 414×896 | **0.2041** | **0.1223** | なし | ADG2022 p.219 (@2x) |
| iPhone 11 | `iPhone12,1` | 150.91 | 5.57 | 139.78 | 34.10 | 17.10 | 414×896 | **0.2041** | **0.1223** | なし | ADG2022 p.216 (@2x) |
| iPhone 11 Pro | `iPhone12,3` | 143.99 | 4.52 | 134.95 | 35.84 | 17.54 | 375×812 | **0.2321** | **0.1300** | なし | ADG2022 p.215 |
| iPhone 11 Pro Max | `iPhone12,5` | 157.95 | 4.52 | 148.91 | 35.84 | 17.54 | 414×896 | **0.2103** | **0.1178** | なし | ADG2022 p.214 |
| iPhone SE 2nd | `iPhone12,8` | 138.44 | 17.19 | 104.05 | 29.33 | 10.62 | 375×667 | **0.1167** | **0.1021** | なし | ADG2022 p.213 |
| iPhone 12 mini | `iPhone13,1` | 131.50 | 3.27 | 124.96 | 34.78 | 17.80 | 360×780 | **0.2522** | **0.1424** | なし | dwg/iphone-12-mini.pdf |
| iPhone 12 | `iPhone13,2` | 146.71 | 3.47 | 139.77 | 37.41 | 17.80 | 390×844 | **0.2428** | **0.1274** | なし | dwg/iphone-12.pdf |
| iPhone 12 Pro | `iPhone13,3` | 146.71 | 3.47 | 139.77 | 37.41 | 17.80 | 390×844 | **0.2428** | **0.1274** | なし | dwg/iphone-12-pro.pdf |
| iPhone 12 Pro Max | `iPhone13,4` | 160.84 | 3.47 | 153.90 | 44.75 | 17.80 | 428×926 | **0.2682** | **0.1157** | なし | dwg/iphone-12-pro-max.pdf |
| iPhone 13 mini | `iPhone14,4` | 131.50 | 3.27 | 124.96 | 34.61 | 18.14 | 360×780 | **0.2508** | **0.1452** | なし | dwg/iphone-13-mini.pdf |
| iPhone 13 | `iPhone14,5` | 146.70 | 3.47 | 139.77 | 43.46 | 18.14 | 390×844 | **0.2861** | **0.1298** | なし | dwg/iphone-13.pdf |
| iPhone 13 Pro | `iPhone14,2` | 146.71 | 3.47 | 139.77 | 43.48 | 18.10 | 390×844 | **0.2863** | **0.1295** | なし | dwg/iphone-13-pro.pdf |
| iPhone 13 Pro Max | `iPhone14,3` | 160.84 | 3.47 | 153.90 | 43.48 | 18.10 | 428×926 | **0.2600** | **0.1176** | なし | dwg/iphone-13-pro-max.pdf |
| iPhone SE 3rd | `iPhone14,6` | 138.44 | 17.19 | 104.05 | 29.33 | 10.62 | 375×667 | **0.1167** | **0.1021** | なし | dwg/iphone-se-3rd-generation.pdf (SE2同図面・上ベゼル17.19は"TO ACTIVE AREA"印字) |
| iPhone 14 | `iPhone14,7` | 146.71 | 3.47 | 139.77 | 43.36 | 18.34 | 390×844 | **0.2854** | **0.1312** | なし | dwg/iphone-14.pdf |
| iPhone 14 Plus | `iPhone14,8` | 160.84 | 3.47 | 153.90 | 43.36 | 18.34 | 428×926 | **0.2592** | **0.1192** | なし | dwg/iphone-14-plus.pdf |
| iPhone 14 Pro | `iPhone15,2` | 147.46 | 3.19 | 141.09 | 46.39 | 18.30 | 393×852 | **0.3062** | **0.1297** | なし | dwg/iphone-14-pro.pdf |
| iPhone 14 Pro Max | `iPhone15,3` | 160.71 | 3.19 | 154.34 | 46.39 | 18.30 | 430×932 | **0.2799** | **0.1186** | なし | dwg/iphone-14-pro-max.pdf |
| iPhone 15 | `iPhone15,4` | 147.64 | 3.27 | 141.09 | 44.52 | 17.70 | 393×852 | **0.2924** | **0.1255** | なし | dwg/iphone-15.pdf |
| iPhone 15 Plus | `iPhone15,5` | 160.89 | 3.27 | 154.34 | 43.64 | 17.70 | 430×932 | **0.2616** | **0.1147** | なし | dwg/iphone-15-plus.pdf |
| iPhone 15 Pro | `iPhone16,1` | 146.61 | 2.76 | 141.09 | 47.32 | 17.70 | 393×852 | **0.3158** | **0.1255** | なし | dwg/iphone-15-pro.pdf |
| iPhone 15 Pro Max | `iPhone16,2` | 159.86 | 2.76 | 154.34 | 47.32 | 17.70 | 430×932 | **0.2887** | **0.1147** | なし | dwg/iphone-15-pro-max.pdf |
| iPhone 16 | `iPhone17,3` | 147.64 | 3.27 | 141.09 | 46.48 | 17.70 | 393×852 | **0.3063** | **0.1255** | あり | dwg/iphone-16.pdf |
| iPhone 16 Plus | `iPhone17,4` | 160.89 | 3.27 | 154.34 | 46.48 | 17.70 | 430×932 | **0.2800** | **0.1147** | あり | dwg/iphone-16-plus.pdf |
| iPhone 16 Pro | `iPhone17,1` | 149.61 | 2.41 | 144.79 | 46.48 | 17.70 | 402×874 | **0.3044** | **0.1222** | あり | dwg/iphone-16-pro.pdf (上ベゼルは印字144.79から逆算2.41・印字は2.44) |
| iPhone 16 Pro Max | `iPhone17,2` | 163.03 | 2.36 | 158.31 | 46.48 | 17.70 | 440×956 | **0.2787** | **0.1118** | あり | dwg/iphone-16-pro-max.pdf |
| iPhone 16e | `iPhone17,5` | 146.71 | 3.47 | 139.77 | 43.36 | 18.34 | 390×844 | **0.2854** | **0.1312** | なし | dwg/iphone-16e.pdf |
| iPhone 17 | `iPhone18,3` | 149.61 | 2.41 | 144.79 | 46.47 | 17.70 | 402×874 | **0.3043** | **0.1222** | あり | dwg/iphone-17.pdf (上ベゼルは印字144.79から逆算2.41・印字は2.44) |
| iPhone 17 Pro | `iPhone18,1` | 150.01 | 2.64 | 144.73 | 46.68 | 17.70 | 402×874 | **0.3043** | **0.1223** | あり | dwg/iphone-17-pro.pdf |
| iPhone 17 Pro Max | `iPhone18,2` | 163.43 | 2.56 | 158.31 | 46.68 | 17.70 | 440×956 | **0.2787** | **0.1118** | あり | dwg/iphone-17-pro-max.pdf |
| iPhone Air | `iPhone18,4` | 156.18 | 2.575 | 151.03 | 46.43 | 17.80 | 420×912 | **0.2904** | **0.1179** | あり | dwg/iphone-air.pdf |
| iPhone 17e | `iPhone18,5` | 146.71 | 3.47 | 139.77 | 43.36 | 18.34 | 390×844 | **0.2854** | **0.1312** | なし | dwg/iphone-17e.pdf (論理ptは推定) |

注記:
- 上ベゼルは図面の「EXTERIOR OF HOUSING TO DISPLAY ACTIVE AREA」値。16 Pro / 17 は印字2.44だが `全高−画面高` から逆算した 2.41 を採用（印字値の丸め不整合をピクセル実測で確認済み）
- SE 2/3 はホームボタン機で上ベゼル 17.19mm（"TO ACTIVE AREA" 印字）。他機種と同じ式で計算済み
- 17e の論理pt 390×844 は HIG 未掲載のため Apple 公式仕様 2532×1170@460ppi ÷3 の推定
- 識別子は ipsw.me と AppleDB の2系統で相互一致した値（Apple公式一覧は存在しない）
- 一次資料: https://developer.apple.com/accessories/dimensional-drawings/ （`.../download/files/accessories/dimensional-drawings/<slug>.pdf`）／旧機種 XS・XR・11系・SE2 は Accessory Design Guidelines 2022-01-07 版 第44章 p.213–219（https://web.archive.org/web/20220202140316id_/https://developer.apple.com/accessories/Accessory-Design-Guidelines.pdf）／論理pt は HIG Layout（https://developer.apple.com/design/human-interface-guidelines/layout）

### フォールバック規則（確定）
1. 識別子が表にある → その行の値
2. 識別子が表にない（未知の新機種・シミュレータで環境変数が取れない等）→ **論理サイズ（w×h pt）が一致する行のうち最も新しいモデル**の値を使う。例: 390×844 → iPhone 17e の行（12/12 Pro の 0.2428 ではなく 0.2854）、393×852 → iPhone 16、402×874 → iPhone 17 Pro、430×932 → iPhone 16 Plus、440×956 → iPhone 17 Pro Max
3. それも無い → `topFraction = 0.2793`、`lengthFraction = 0.1223`（Face ID 機 27機種の中央値）、`hasCameraControl = false`
- `hasCameraControl` は識別子一致のときだけ true になり得る（フォールバック経路では常に false）
- 実装は表の値をそのまま Swift の静的テーブル（`[String: DeviceSideButtonGeometry.Spec]` と `[CGSize: Spec]`）に持つ。**この表以外の数値を書かない**

## 4. 検証
- `xcodebuild build` 成功、`DopaBreakTests` 0失敗
- `LockScreenCheckSnapshotCapture` で `01-waiting` を再出力し、右端バーが出ていること・文言と本文が重なっていないことを PNG で目視（Fable が受け入れ判定）
- 実機（オーナー所有機）でバーの高さが物理ボタンと合うかを最終確認する（これはオーナーに依頼する。シミュレータでは物理位置を検証できない）

## 5. 同梱する文言修正（表示コピーのリズム読点禁止・オーナー恒久ルール）
- `lock_check.preview.cancelled` の ja 値と `LockScreenCheckView.swift`（`LockScreenGoalPreview` 内 L347付近）の `defaultValue`: 「今日は%lld回、開くのをやめました」→「今日は%lld回 開くのをやめました」（読点を半角スペースへ）。en/ko は変えない。`LockScreenGoalPreview` への変更はこの1文字列だけ
- 文言変更後は `python3 scripts/audit-default-values.py`（カタログ値と `defaultValue` の一致検査）と `python3 scripts/lint-display-copy.py` を両方 exit 0 で通す

## 6. 是正バッチ1（2026-08-25 Opus5レビュー＋Fable目視の指摘。すべて必須）
1. **スクロールで空きが伸び続けるループを直す**（`LockScreenCheckView.swift` の spacer 計算）: タイトルの `frame(in: .global).maxY` はスクロールで動くため使わない。タイトルの**高さ**（`proxy.size.height`）と、スクロール容器のスクロール不変な上端Y（容器自身の global minY、または scroll content に付けた named coordinate space＋容器の静止原点）から `spacer = max(0, markerBlockBottomY − (containerTopY + topPadding + titleHeight) + 16)` を出す。スクロール中に本文が画面に固定されないこと・content 高さが伸びないことを実機/シミュレータで確認する
2. **文言ブロックをバー中心に揃える**: `@State blockSize` の preference→再レイアウトの往復を廃止。`alignmentGuide` か `ViewDimensions` を使い、ブロック自身の高さをレイアウト中に同期的に受け取って配置する。`SideButtonMarkerBottomPreferenceKey` はブロック自身の `GeometryReader` の `frame(in: .global).maxY` から発行する（`top + blockSize.height` の計算では出さない）。ImageRenderer のスナップショットでもブロックが最初のパスで正しい位置に出ること
3. **縦向きの論理高さに正規化**（`DeviceSideButtonGeometry.current()`）: `h = max(bounds.width, bounds.height)`、`w = min(...)` にしてからサイズ表の検索と `screenHeight` に使う。このケースと `SIMULATOR_MODEL_IDENTIFIER` 優先のテストを追加する
4. **文言とバーの間隔**: 文言ブロックの `.padding(.trailing)` を 5pt → **14pt**
5. **幅は上限**: `.frame(width: 0.6×幅)` → `.frame(maxWidth: 0.76×幅, alignment: .trailing)`。あわせてラベルのフォントを **22 → 20pt**（weight .black のまま）。目的は ja が「サイドボタンを1回押して／画面を消す」で折り返すこと（現状「押し／て」で語の途中で切れている）。360pt 幅でも「サイドボタンを1回押して」が1行に収まることを確認する（12文字×20pt=240pt ≤ 0.76×360=273pt）
6. **矢印の向き**: バー中心Yが文言ブロックの縦範囲内にあるときは `arrow.right`（真横のバーを指す）。ブロックがバーより下に押し下げられた（ヘッダークランプ）ときだけ `arrow.turn.right.up`、上にあるときだけ `arrow.turn.right.down`
7. **stagger を視覚順に**: `.waiting` の描画順に合わせて title 0 / lead 1 / 手順2カード 2 / プレビュー 3 / 許可注記 4 に振り直す（相対順を視覚順に一致させる。モーション改修 Step D 担当には変更後の index を通知済み）
8. `DeviceSideButtonGeometry.current()` を `body` 内で毎回呼ばない。`@State` で初回に1度取得して保持する
9. 是正後: build／`DeviceSideButtonGeometryTests`＋`LockScreenCheckSnapshotCapture`／`audit-default-values.py`／`lint-display-copy.py` を再実行し、`output/screenshots/lock-check/lock-check-01-waiting.png` を再出力する。PNG 上でバー 249〜356pt、文言ブロックがバー中心（302.5pt）を挟んで上下対称、文言右端とバーの間 ≥14pt、折返しが「押して」で切れていることを数値で確認して報告する
- 追記（42のスクショ整合監査）: プレビューは実 Live Activity（`WidgetsExtension` の `live_activity.summary.cancelled`）の模写なので語尾も実LAに揃える。ja「今日は%lld回 開くのをやめた」／ko「오늘은 %lld번 열지 않기로 함」／en は既に一致（`Chose not to open %lld× today`）。`defaultValue` も同時に更新

## 7. 是正バッチ2（2026-08-25 Opus5再レビュー。Swiftのみ・xcstrings には触らない）
1. **シート経路の safe area 二重計上**（`LockScreenCheckView.swift` の `LockScreenCheckSheet`、`scrollContainerTopY:` を渡している箇所）: `proxy.frame(in: .global).minY` → `proxy.frame(in: .global).minY + proxy.safeAreaInsets.top`。オンボーディング経路はヘッダーが safe area を消費しているので変更不要
2. **VStack 間隔の重複**: spacer は `VStack(spacing: 24)` の中にあり前後2つの spacing が足されるため、`waitingSpacerHeight` を `max(0, markerBlockBottomY − stableTitleBottomY + 16 − 48)` にする（実現される間隔を仕様どおり +16pt にする）
3. **コード内の `\n` 注入をやめる**（`markerText` の `replacingOccurrences(of: "押して画面", with: "押して\n画面")` を削除。表示コピーに `\n` をハードコードしない全体ルール）。折返しはレイアウトで制御する: ラベルの `maxWidth` を画面幅の割合ではなく **固定 240pt** にする（20pt の日本語で「サイドボタンを1回押して」=全角11字＋半角1字 ≈ 231pt が収まり、次の「画」を足した ≈ 251pt は収まらない想定）。PNG を再出力して1行目が「押して」で終わり2行目が「画面」で始まることを実測し、ずれる場合は 232〜248pt の範囲で調整して採用値を報告する。en/ko も3行以内で収まることを確認する
4. `SideButtonMarkerLayout.placeSubviews` の `guard subviews.count == 4 else { return }` に `assertionFailure` を添える（Debug で無音の空描画を防ぐ）
5. 再実行: build／`DeviceSideButtonGeometryTests`＋`LockScreenCheckSnapshotCapture`／`audit-default-values.py`／`lint-display-copy.py`、PNG 再出力と実測（バー 249〜356pt・ブロック中心 ≈302.5pt・文言右端とバーの間 ≥14pt・折返し位置）


---

## 追記: 登場アニメーションの統合（2026-08-25・モーション改修 Step D）

§2-2「登場」の opacity 0→1 は、マーカー内部の `isVisible` state から **overlay 側の `.transition(.opacity)` ＋ `.animation(reduceMotion ? nil : DopaMotion.morph, value: phase)` へ統合**した（`LockScreenCheckSheet` と `OnboardingFlow.lockScreenCheckContent` の両方）。Step D で `phase` の反映を `withAnimation` トランザクションへまとめたため、内部fadeを残すと同じ要素が二重に補間される。`.waiting` へ遷移した瞬間に1回fadeする挙動と、Reduce Motion での即時表示は従来どおり。表示条件・ジオメトリ計算・レイアウトは無変更。
