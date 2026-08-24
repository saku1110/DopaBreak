# Phase 1 実装ブリーフ — AppIconView ＋ 止めるアプリ ＋ ホーム（2026-08-22・オーナー承認済み）

親仕様: `.claude/specs/functional-screens-redesign-proposal.md`（オーナー「全部推奨でOK」で確定）。モック: `output/mockups/functional-screens-redesign-2026-08-22.html`（§01 ホーム・§05 止めるアプリ）。

## 0. 守ること（全Phase共通）
- 既存の `DesignTokens`（色・角丸16・`dopaFont`・`CardContainer`・`SmallLabel`・`PrimaryButtonStyle`）をそのまま使う。新しい色の追加はブランド色タイル用に限定する。ライムは「選択・進行・今日」にだけ使い、塗り面積を増やさない。
- 文言は **8/15承認の事実コピーを維持**（`home.*` の既存キー文字列は変更しない）。新規キーは ja / en / ko の3言語を `ios/DopaBreak/Localizable.xcstrings` に追加し、`String(localized:defaultValue:)` のdefaultValueはjaと一致させる。短い表示コピーに読点・句点を入れない。内部用語（介入/シールド等）をUIに出さない。
- 完了条件（全部必須）: `python3 scripts/audit-default-values.py` が mismatches/missing/unresolved 0 ／ `python3 scripts/lint-display-copy.py` exit 0 ／ `cd ios && xcodegen generate` ／ iPhone 16 Pro Max シミュレータ（UDID `90F5A09F-D128-468C-AB02-7ABB1479B3AE`）向け `xcodebuild build` が `BUILD SUCCEEDED`（`CODE_SIGNING_ALLOWED=NO`）／ `cd ios/Packages/DopaBreakCore && swift test` 失敗0 ／ `git diff --check`。
- TODO・省略・スタブ禁止。他のPhaseの画面（Stats/Settings/Goals）には触らない（AppIconViewを他画面で使うのは次Phase）。
- 商標: 他社ロゴ画像・SVGを同梱しない。ブランド色＋SFシンボルだけで表現する。

## 1. 新規共通部品（`ios/DopaBreak/` に追加）

### 1-1 `AppIconView.swift`
```swift
enum AppIconSource { case catalog(SNSAppCatalogItem); case token(ApplicationToken) }
struct AppIconView: View { let source: AppIconSource; var size: CGFloat = 44 }
```
- `.catalog`: 角丸 `size * 0.25`（continuous）のタイルに **ブランド色**を敷き、中央に `Image(systemName: item.symbolName)` を白・`size*0.46`・semibold で置く。内側に `rgba(255,255,255,0.08)` の1pxリング。
  - ブランド色テーブル（catalogID → 塗り）: instagram = 対角グラデ `#F9CE34 → #EE2A7B → #6228D7`（左下→右上）／ x = `#000000`（枠 `#2A2A2A`）／ tiktok = `#000000`（枠 `#2A2A2A`、シンボルに cyan `#25F4EE` 左上・pink `#FE2C55` 右下の1.5ptずれ影）／ youtube = `#FF0033`／ facebook = `#1877F2`／ threads = `#000000`（枠 `#2A2A2A`）／ line = `#06C755`／ safari = 縦グラデ `#2FB4FF → #0A84FF`。テーブルにないIDは `DesignTokens.card` 地＋`primaryText` シンボル。
- `.token`: `Label(token).labelStyle(.iconOnly)` を `size` の枠に収める。**30pt以下の行・スタック用途に限定**（描画解像度が低くぼやけるため）。Phase 1 ではこの分岐は実装するが使用箇所は増やさない。
- `accessibilityLabel` に displayName（tokenは「アプリ」）。

### 1-2 `AppIconStack.swift`
`[AppIconSource]` を左から `-size*0.3` ずつ重ねて表示。`maxVisible: Int = 4`、超過分は `+N` の灰タイル。外周に `DesignTokens.background` の2pt縁で切り抜き感を出す。

### 1-3 `DopaRing.swift`
`BreathingCharacterView` のリング描画（背景リング ライム18%・線幅6／進捗リング ライム100%・12時始点・`.round` cap）を一般化したもの。
```swift
struct DopaRing: View { let progress: Double /*0...1*/; let expression: CharacterExpression; var diameter: CGFloat = 188 }
```
中央に `CharacterView(expression, ...)` を `diameter * 0.72` で置く。`progress` 変化は `DopaMotion.transition` でアニメーション。BreathingCharacterView 自体は触らない（呼吸同期ロジックがあるため）。

### 1-4 `DayBars.swift`
```swift
struct DayBars: View { let days: [WeeklySummary.Day] /*7件・古い順*/; var height: CGFloat = 62 }
```
各日を1列: 上に「開かなかった」バー（ライム）、下に「開いた」バー（白12%）、列幅の62%・角丸4。最大値で正規化（全0なら高さ3ptのプレースホルダ）。今日（index 6）はライム45%塗り＋1.5ptライム枠で区別。下に曜日ラベル（`SmallLabel` 相当 10pt monospaced、今日だけライム）。曜日は `Calendar.current` のローカライズ短縮表記（ja: 月火水…）。VoiceOver: 各列に「金曜日 開かなかった5回 開こうとした7回」。

## 2. 止めるアプリ（`TargetAppPickerSheet.swift`）
現行: 見出し→説明→Free注記→`CardContainer` に8行（32pt円＋SFシンボル＋名前＋チェック）。
変更:
- 8行リストを **2列グリッド（`LazyVGrid`, spacing 8）**のカードへ。各カード: `AppIconView(.catalog(item), size: 50)` ＋ 名前（15pt semibold、1行で省略）＋ 右端に選択インジケータ（選択=ライムの塗り丸、未選択=灰の輪郭丸）。選択中カードは `inset 0 0 0 2px accent` の内側リング（枠線色替えではなく `overlay` の `RoundedRectangle.strokeBorder`）。カードは `DesignTokens.card` 地・角丸16・最小高さ72・タップ領域全体。
- 見出し・説明・Free上限の注記・保存ロジック・上限超過時の挙動・オンボーディング側（`OnboardingFlow.swift:848` 付近の同型リスト）は **同じグリッド部品**を使うよう共通化する（`TargetAppGrid` を切り出して両方から使う）。オンボーディングの文言・遷移は変えない。
- 「今週◯回」のサブラベルは、`StatsService.appRuleBreakdown` のキー（ruleId）を catalogID に対応付けられる既存経路がある場合のみ表示する。対応付けが存在しなければ表示せず、報告に「未対応の理由」を1行で書く（新しいスキーマ変更はしない）。
- 「ほかのアプリを選ぶ（スクリーンタイム）」ボタンは **Phase 1では追加しない**（ショートカット自動化の対象外になるため。別途判断）。

## 3. ホーム（`HomeView.swift`）
上→下を次の構成に組み替える。`model` / `settingsStore` の既存プロパティと `StatsService.weeklySummary()` を使い、新しい計測は追加しない。
1. 1行目: 左 `SmallLabel "TODAY ・ 8月22日"`（既存）、右 `home.hero.week_count` のカプセル（既存）。
2. **ヒーロー `DopaRing`**: `progress = todayAttemptCount == 0 ? 0 : todayCancelled/todayAttempt`、表情は現行ロジック維持（`todayAttemptCount > 0 && todayCancelledCount == 0 ? .doom : .awake`）。diameter 188、中央寄せ。
3. 数字ブロック（中央寄せ）: 既存の `achievementSection` の文言・キーをそのまま（`回` 付きライム数字 → 「今日 開かなかった」→ `home.achievement.summary`）。数字は 66pt `.black .rounded`（82→66に縮小）。末尾に「・ 80%」の率を**追加しない**（承認済みコピーの維持。率はリングで表す）。
4. **「守っているアプリ」カード（新規）**: eyebrow 新規キー `home.targets.title` = 「守っているアプリ」／右に `home.targets.breath_seconds` = 「一呼吸 %d秒」（`settingsStore` の一呼吸の長さ）。本文: `targetStore.selectedCatalogIDs()` に対応する `SNSAppCatalogItem` を `AppIconView(size:44)` で横並び（最大5、超過は `AppIconStack` の `+N`）。各アイコン右上にライム点（8pt・`background` 2pt縁）＝一呼吸ON。末尾に破線の `＋` タイル（44pt）。カード全体タップで `TargetAppPickerSheet` を `.sheet` で開く（既存の sheet 管理に合わせて `isAnyChildModalPresented` に含める）。選択が0件なら `＋` タイルと新規キー `home.targets.empty` = 「止めるアプリを選ぶ」（accent 15pt semibold）だけ表示。
5. **週カード**: 既存 `weekSignal` の5ptバーを `DayBars(days: weeklySummary.days)` に置き換える。見出し eyebrow `THIS WEEK`（既存）、右上に既存 `home.week.summary`（「今週 開かなかったのは%d回」）をそのまま。`weeklySummary()` の取得失敗時は現行どおり非表示にせず、全0のDayBarsを出す。
6. **目標カード**: 既存 `goalSection` の見た目を「左にカテゴリタイル44pt（`GoalCategory` → SFシンボル: study=book.fill / work=briefcase.fill / health=figure.run / sleep=moon.stars.fill / creative=paintbrush.fill / other=star.fill、地は accent 14%・シンボルは accent）＋ eyebrow（既存「あなたの目標」＋「 ・ 」＋カテゴリ名）＋ タイトル（既存 `primaryGoalTitle`、20pt bold・2行まで）＋ chevron」のカードに変更。目標未設定時の既存表示（accent 20pt bold のアクション風）は維持。タップ挙動（GoalEditorSheet）は変更しない。カテゴリ名の表示文字列は GoalsView / GoalEditorSheet で既に使っているローカライズを再利用する（新規キーを作らない）。
7. `firstDayEmptySection`（初日）・`automationStatusBanner` は位置を維持（初日でもヒーローリングと守っているアプリカードは表示する）。
- 初日（試行0）のリングは progress 0（背景リングのみ）。

## 4. スクリーンショット（完了報告に必須）
`ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` の撮影経路（環境変数 `DOPABREAK_CAPTURE_APPSTORE_SCREENSHOTS=1`・iPhone 16 Pro Max・ja・ダーク・シード「英語で商談できる自分になる」/本日15試行12開かなかった/7日分）を使い、`output/app-store-screenshots/raw-core/ja/home.png` を**上書きせず** `output/screenshots/redesign-phase1/home.png` と `target-picker.png`（ピッカーを3件選択済みで表示）を出力する。撮影経路に新しい画面を足す場合はDEBUG限定の既存パターンに倣う。出力PNGのパスを報告に書く。

## 5. 報告フォーマット
変更ファイル一覧／新規キー一覧（ja/en/ko）／検証コマンドと結果（ビルド・テスト・audit・lint・diff --check）／スクショのパス／未対応と理由（あれば）。設計逸脱があれば理由を明記。

## オーナー訂正（2026-08-24・後勝ち）

- `DayBars` は「開くのをやめた」回数のライム1系列だけを全高で正規化する。「開いた」グレー系列はHomeで意味が伝わらず、凡例なしでは別指標に見えるため削除する。0件だけ中立hairlineを置く。
- 画面表示の「開かなかった」は「開くのをやめた」へ変更する。内部の `cancelled` 名と集計は維持する。
- `home.targets.breath_line` は「一呼吸の設定：%lld秒」。明確な目的の経路は一呼吸をスキップするため、「開く前に必ず%lld秒」を断定しない。
