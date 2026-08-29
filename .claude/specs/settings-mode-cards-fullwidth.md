# 設定「止める強さ」選択カードの全幅化 v1（2026-08-29）

## 問題
`ios/DopaBreak/SettingsView.swift` の `modeSection` は3列 `LazyVGrid`。カード幅が狭く、
`detailText`（11pt・`lineLimit(2)`）が切れる。特に「夜だけ強化」の
「就寝時刻から起床時刻までアプリを開けなくする」（22文字）は2行に収まらない。
en/koでも同様の切り詰めリスクがある。

## 決定（Fable設計・実装はこのspecに従う）
3列グリッドを廃止し、**全幅の縦積み行カード3枚**へ変更する。
オンボーディングの `modeButton`（`OnboardingFlow.swift:1633`）と同じ選択言語
（全幅カード＋右端checkmark）を設定画面のトーンで踏襲する。

### modeSection
- `LazyVGrid(columns: modeColumns, ...)` → `VStack(spacing: 0) { ForEach(InterventionMode.selectable, id: \.self) { modeCard($0) } }`
- `modeColumns` プロパティは削除（1列固定になるためアクセシビリティサイズ分岐も不要）。
  `dynamicTypeSize` が他で未使用になる場合のみプロパティごと削除してよい。

### modeCard(_ mode:) 新レイアウト
```
Button { setSelectedMode(mode) } label:
  HStack(alignment: .center, spacing: 12)
    ├ SettingsIconTile（現行と同じ symbol / 選択時 accent 配色）
    ├ VStack(alignment: .leading, spacing: 3)
    │   ├ Text(mode.displayTitle)  .dopaFont(15, weight: .bold)  primaryText
    │   │   .fixedSize(horizontal: false, vertical: true)
    │   └ Text(mode.detailText)    .dopaFont(12, weight: .medium, lineSpacing: 2)  secondaryText
    │       .fixedSize(horizontal: false, vertical: true)   ← lineLimitは付けない（全文表示が本件の目的）
    │       .multilineTextAlignment(.leading)
    │   .frame(maxWidth: .infinity, alignment: .leading)
    ├ （isLockedのとき）Proカプセル: 現行の 9pt black / backgroundRaised / Capsule をそのまま移設
    └ （isSelectedのとき）Image(systemName: "checkmark")
        .dopaFont(16, weight: .bold) .foregroundStyle(DesignTokens.accent)
  .padding(14)
  .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)   ← HIG最小タップ領域
  背景・ストローク・角丸・外側リングは現行と同一:
    .background(isSelected ? accent.opacity(0.06) : backgroundRaised)
    .overlay(RoundedRectangle(12, continuous).stroke(isSelected ? accent : hairline, lineWidth: isSelected ? 2 : 1))
    .clipShape(RoundedRectangle(12, continuous))
    .padding(4)
    .overlay(RoundedRectangle(16, continuous).stroke(isSelected ? accent.opacity(0.12) : .clear, lineWidth: 4))
  .contentShape(Rectangle())
.buttonStyle(.plain)
.accessibilityAddTraits(isSelected ? [.isSelected] : [])
```
- isLocked と isSelected が同時に真なら Pro カプセル → checkmark の順で両方出す。
- `minHeight: 116` は廃止（行の自然高に任せる。実高は60pt超になり44ptを満たす）。

## 変えないもの
- `setSelectedMode` / `modeAllowedForCurrentEntitlement` / ペイウォール分岐などロジック一切
- `InterventionModeDisplay.swift` の文言・`Localizable.xcstrings`（コピー変更なし）
- `modeSymbolName`、SmallLabel「止める強さ」、CardContainer構造
- オンボーディング側のUI

## テスト（既存パターン踏襲）
- `ios/DopaBreakTests/MeasurementFoundationTests.swift` の実ビューホスト経路の書き方に倣い、
  設定画面の止める強さカード3枚が ja で `displayTitle`・`detailText` 全文を切り詰めなしで
  描画することを固定する回帰テストを追加する（text anchorの実測 or 描画収容判定。
  既存ヘルパーがあれば再利用。なければ同ファイルの流儀で最小のものを書く）。
- 検証用に設定画面（modeSection が見える状態）の 1320×2868 描画PNGを
  `output/verify/settings-mode-cards.png` へ保存する撮影を行う（既存の撮影テストの流儀）。

## 受け入れ条件
1. ja/en/ko いずれでも3カードの説明文が全文表示される（切り詰め・「…」なし）
2. 選択中カードの視覚状態（accentストローク＋checkmark）が現行トーンで維持される
3. ロック時Proバッジが表示される
4. ビルド成功・DopaBreakTests既存分にリグレッションなし
