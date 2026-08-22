# 振り返りシートの1問化（2026-08-22 オーナー承認済み）

## 決定（オーナー発言の要約）
- 「幸福感や集中力は上がった？」の2問目は削除する。振り返りは1問目「SNSを見てどうだった？」のみにする
- App Storeスクショ06は1問目の画面を使う。1枚1体ルールのため、選択肢ボタン内の顔（CharacterView inline）を本体UIから外す
- 2問目の回答値 `happinessDelta` は満足度から導出して保存し、Stats側の内訳表示とCoreのデータ型は維持する

## 実装仕様

### 1. Core: 導出ロジック（`ios/Packages/DopaBreakCore`）
- `PostUseSatisfaction` に `public var impliedHappinessDelta: HappinessDelta` を追加
  - `.satisfied`, `.fun` → `.increased`
  - `.nothingGained` → `.unchanged`
  - `.lostTime`, `.feltWorse` → `.decreased`
- `recordPostUseReflection(id:satisfaction:happinessDelta:)` のシグネチャは変更しない
- DopaBreakCoreTests に導出の全5ケースのテストを追加

### 2. App: `ios/DopaBreak/PostUseReflectionSheet.swift`
- `happinessStep` と `HappinessDelta.displayTitle` 拡張（他で未使用なら）を削除。`@State satisfaction` は「選択済み・送信待ち」表示用に残す
- 選択肢ボタンはテキストのみ（`choiceButton` の `expression` 引数とinline `CharacterView` を削除）。ボタン高さ・角丸・余白は現状維持
- タップ時: `satisfaction = value` → 先頭キャラが `value.characterExpression` にポップ（既存 `.characterPop(trigger:)` を利用）→ 約0.55秒後に `finish(satisfaction:happinessDelta: value.impliedHappinessDelta)` を呼び `onFinished()`。待機中は全ボタンと「今回はスキップ」を無効化し二重送信を防ぐ（`Task.sleep` でよい。キャンセル考慮）
- 選択済み状態では、選択した行のみ視覚的にハイライト（`DesignTokens.accent` のストローク等、既存トークンのみ使用）。他行は通常のまま
- 見出し `reflection.satisfaction.title` の `\n` ハードコードを外し自然折返しにする（defaultValue と xcstrings の ja/en/ko すべて）。文言は変えない: ja「SNSを見てどうだった？」en「How did it feel after scrolling?」ko「SNS를 보고 나서 어땠나요?」
- DEBUG限定の `init(snapshotModel:...)` は不要になるため削除し、`ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` の `ReflectionSnapshotHost` を通常initへ切替（未選択状態＝先頭キャラ1体のみ）。撮影用シートはStatsView背景ごと提示する現行方式を維持

### 3. xcstrings（`ios/DopaBreak/Localizable.xcstrings`）
- `reflection.happiness.title` を削除。`reflection.happiness.increased/unchanged/decreased` はアプリ内で他に参照がなければ削除、あれば残す（`grep` で確認し結果を報告）
- `reflection.satisfaction.title` の3言語から `\n` を除去
- JSON整合（`plutil -lint` 相当）と3言語充足を確認

### 4. スクショ
- `CoreScreensSnapshotCapture` を ja / en-US / ko で実行し `output/app-store-screenshots/raw-core/{ja,en-US,ko}/reflection.png` を再撮影（指定Simulator `90F5A09F-D128-468C-AB02-7ABB1479B3AE`、status bar 9:41、手順は `.claude/specs/appstore-screenshots-v2-diagonal.md` と design-decisions.md の既存記録に従う）
- 撮影後、画面内キャラ数が1体であることを目視＋`scripts/generate-appstore-screenshots-v2.py` の `SCREEN_CHARACTER_COUNTS` コメントを「reflection（1問目・未選択）」へ更新し、v2一式（3言語）を再生成。slots.json の total ≤ 1 assert が通ること
- `.claude/specs/appstore-screenshots-v2-diagonal.md` の 06 記述（39行・42行・98行付近）を「1問目（満足度未選択）・選択肢は文字のみ・画面内1体」に更新

### 5. ドキュメント同期
- `docs/04_functional_requirements.md` FR-215（幸福感選択）→ 満足度から導出する旨に書き換え。FR-407 は維持
- `docs/11_ui_copy.md` 231-232行・264行、`docs/03_product_spec.md` 126行、`docs/05_detailed_design.md` 275-276行、`docs/07_onboarding_design_lifefocus.md` 748行、`docs/FABLE_BRIEF.md` 121行 を1問化に合わせて更新
- `.claude/specs/design-decisions.md` 末尾に本決定（理由: 2問目は1問目と相関が高く独立情報が薄い／1タップ化で回答率優先／スクショ1枚1体）を追記

## 検証（完了報告に必ず含める）
- `cd ios/Packages/DopaBreakCore && swift test` 全通過
- `cd ios && xcodegen generate` → 署名なしgeneric iOS Simulator向け `xcodebuild build` が `BUILD SUCCEEDED`
- `scripts/lint-display-copy.py` exit 0、`git diff --check` 通過
- raw reflection.png 3言語の再撮影結果と、v2再生成の成否

## 禁止
- Coreの保存API・`ReflectionLog` 型・Stats集計の変更
- スクショ専用の別画面を作ること（実画面のみ）
- 表示コピーに句読点を入れること、`\n` を新たにハードコードすること
