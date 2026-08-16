# オンボーディング推計結果画面の再構成仕様（2026-08-14 オーナー承認済み）

## 背景・決定
直前の質問で「1日あたりの利用時間」を回答させた直後に、ヒーロー数字として「2時間30分 / 日」を見せ返すのは情報増分がほぼゼロ（オーナー指摘 2026-08-14）。
損失回避の驚きが生まれる換算値を主役にし、日→月→年と単位がエスカレートする3段構成へ変更する。

## 新構造（ios/DopaBreak/OnboardingFlow.swift の quizResultContent）

| 位置 | 内容 | 例（2〜4時間回答時） | スタイル |
|------|------|------|------|
| eyebrow | 変更なし（推計結果 / YOUR RESULT） | — | 現状維持 |
| lead | 変更なし（あなたの回答にもとづく推計では） | — | 現状維持 |
| キャラクター | 変更なし（CharacterSwapSequence doom→worse） | — | 現状維持 |
| ヒーロー行 | **1年の損失日数**（カウントアップ維持） | 1年で 約 **38** 日 | prefix 20pt bold / 数字 70pt black rounded monospacedDigit accent / suffix 28pt black |
| ボディ行 | がSNSに溶けています | — | centeredLead（現 daily_body を文言変更して再利用） |
| 3年行 | 3年換算（月表記・カウントアップなし・静的表示） | 3年なら 約 **3.7** か月 | prefix 18pt bold / 数字 58pt black rounded monospacedDigit accent / suffix 28pt black（現 yearly 行のスタイルを踏襲） |
| 免責行 | 推計根拠（1日想定値）を統合 | ※1日約2時間30分の想定にもとづく推計値です。医療診断ではありません。 | centeredLead（現 disclaimer 位置） |
| 人生換算行 | 変更なし | このままなら50年で 人生の約5.2年 | 現状維持 |

- 「◯◯分 / 日」の70ptヒーローと `onboarding.result.per_day` の表示は削除する（キーは xcstrings に残してよいが未使用になる）
- onboardingStagger の順序は現状の意味を保って振り直す（lead→数値ブロック→免責→人生換算）
- カウントアップはヒーロー行（年間日数）のみ。3年行は静的テキスト
- 見出し・表示コピーに読点・句点を入れない（免責＝本文は句点可）
- コード内に `\n` をハードコードしない

## DopaBreakCore の変更（ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/LossEstimator.swift）

追加:
```swift
/// 3年換算の前提年数。
public static let threeYearHorizonYears = 3

/// 年間損失日数を3年分に伸ばし、月単位へ換算する。
/// 実値より大きい数字を出さないため、四捨五入せず1桁小数へ切り捨てる（lifetimeYears と同方針）。
public static func threeYearMonths(fromYearlyDays yearlyDays: Int) -> Double
```
- 換算式: `yearlyDays * 3 / (365.0 / 12.0)` を1桁小数へ切り捨て
- 期待値: yearlyDays 11→1.0, 23→2.2, 38→3.7, 76→7.4, 99→9.7, 68→6.7
- LossEstimatorTests.swift に上記全バケットのテストを追加（金融計算ではないが換算ロジックは全分岐カバー）

## ローカライズ（ios/DopaBreak/Localizable.xcstrings・ja/en/ko）

| キー | ja | en | ko |
|------|----|----|----|
| `onboarding.result.hero_yearly.prefix`（新規） | `1年で 約` | `About` | `1년에 약` |
| `onboarding.result.hero_yearly.suffix`（新規） | `日` | `days a year` | `일` |
| `onboarding.result.daily_body`（変更） | `がSNSに溶けています` | `lost to your feed` | `이 SNS에 녹고 있어요` |
| `onboarding.result.three_year.prefix`（新規） | `3年なら 約` | `In 3 years about` | `3년이면 약` |
| `onboarding.result.three_year.suffix`（新規） | `か月` | `months` | `개월` |
| `onboarding.result.disclaimer`（変更・%@=1日想定時間） | `※1日約%@の想定にもとづく推計値です。医療診断ではありません。` | `*Based on an assumed %@ a day. Not a medical diagnosis.` | `※하루 약 %@ 사용 가정에 기반한 추정치입니다. 의료 진단이 아닙니다.` |

- 免責行の `%@` には既存の `dailyTimeText(minutes:)`（onboarding.result.duration.* を使う整形）を渡す
- 3年の数値表示は `String(format: "%.1f", ...)` 相当で1桁小数（3.7）。言語間で数値フォーマットを変えない

## 検証
- `swift test`（DopaBreakCore パッケージ）が全緑
- OnboardingFlow.swift のコンパイルが通ること（xcodebuild build まで確認できれば尚可）
- 免責・人生換算の50年前提明示（docs/07 §O-03r）を壊さない
