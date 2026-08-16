# オンボーディング質問Q1の即進み統一（2026-08-14 オーナー承認済み）

## 背景・決定
質問3問のうちQ1（selfCheck）だけが「選択→[次に進む]ボタン」で、Q2・Q3（quizAimless/quizRegret）はタップで即進む実装だった（docs/07 §O-02b の「タップで即次へ」に準拠）。
Q1で「選ぶ→確認する」と学習させた直後にQ2で予告なく画面が飛ぶ順序が最も戸惑わせるため、**3問とも即進みに統一する**（オーナー承認 2026-08-14）。
誤タップは全ステップ共通の戻るボタン（progressHeader）で回収でき、Q1の回答は直後の結果画面から戻れば選び直せる。

## 変更（ios/DopaBreak/OnboardingFlow.swift）

### 1. selfCheckContent（:505-521）
- `singleSelectOptions(usageOptions, selection: $usageBucket)` を、タップで `usageBucket` を設定してから `advance()` する即進み型に変更する
- `singleSelectOptions`（:1144-1159）はこの1箇所からしか呼ばれていない。`frequencyButtons`（:1161-1173）と同じ「selection + action クロージャ」の形へ揃えるか、selfCheck専用に書き換えるかは実装者判断でよいが、**両者で重複した実装を増やさないこと**（共通ヘルパーに寄せるのが望ましい）
- `markSelectionFeedback()` の呼び出しは維持する（触覚フィードバック）
- 選択済みチェックマーク表示（optionButton の isSelected）は維持する。戻ってきたときに前回の選択が見える必要がある

### 2. bottomBar（:357-365）
- `case .quizAimless, .quizRegret: EmptyView()` に `.selfCheck` を追加する

### 3. primaryAction（:378-447）
- `case .selfCheck:` の分岐（:384）を削除し、末尾の `case .quizAimless, .quizRegret: EmptyView()` に `.selfCheck` を合流させる

### 4. 未使用キーの扱い
- `onboarding.action.next` は :436（lockScreenCheck）でも使われているため **xcstrings から削除しない**

## ドキュメント更新
- `docs/07_onboarding_design_lifefocus.md` の O-02（Quiz Q1）節: モック内の `[次へ]` を削除し、O-02b と同じ「UI: タップで即次へ」の記述へ更新する。決定日（2026-08-14）とオーナー承認である旨を残す
- `.claude/specs/design-decisions.md` に決定と制約を追記する

## 制約
- Q2・Q3の既存挙動（`persistSelfCheckSnapshot()` を通してからの advance を含む）は変更しない
- 進捗表示・stagger・戻るボタン・ファネルイベント記録の挙動を壊さない
- 表示コピーに読点・句点を入れない

## 検証
- generic iOS Simulator向け `xcodebuild build` が BUILD SUCCEEDED
- `cd ios/Packages/DopaBreakCore && swift test` が全緑
- Q1をタップすると即Q2へ進み、戻るとQ1の選択が保持されていること
