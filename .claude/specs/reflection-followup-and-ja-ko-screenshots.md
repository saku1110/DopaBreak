# フォローアップ: 振り返りシートのレビュー是正 ＋ スクショ06サブコピー ＋ ja/ko検索意図監査の反映（2026-08-22）

## Part A: PostUseReflectionSheet のレビュー指摘是正（`ios/DopaBreak/PostUseReflectionSheet.swift`）
1. 選択後550ms待機中はシートのスワイプ閉じを禁止: `.interactiveDismissDisabled(satisfaction != nil)` を付ける（待機中のタップ結果が無言で捨てられる穴を塞ぐ）
2. 待機中の無効状態を視覚化: `satisfaction != nil` の間、選択していない4行と「今回はスキップ」を `opacity(0.4)` に落とす。選択行は現状のアクセントストロークのまま
3. VoiceOver: 選択確定時に `AccessibilityNotification.Announcement(<選択行の displayTitle>).post()` を発行する（自動で閉じるため、何を記録したか読み上げる）
4. 他は変更しない。Coreの保存APIは触らない

## Part B: スクショ06サブコピーの是正（実画面と不一致のため）
振り返りは1問化され「集中」を聞かなくなった。`scripts/generate-appstore-screenshots-v2.py` と承認正本 `scripts/generate-appstore-screenshots.py` の**両方**で06サブコピーを次に置換（validate_legacy_copy_reuse が通ること）:
- ja: 「満足感・集中・開こうとした回数を見える化」→「満足感と開こうとした回数を見える化」
- en-US: "Track satisfaction, focus, attempts, and skipped opens" → "Track satisfaction, attempts, and skipped opens"
- ko: 「만족감·집중력·시도·열지 않은 횟수를 한눈에 봐요」→「만족감·시도·열지 않은 횟수를 한눈에 봐요」
en-US はこの1行以外一切触らない。

## Part C: ja/ko 検索意図監査の反映（オーナー承認済み・正本 `.claude/specs/appstore-screenshots-search-intent-audit-2026-08-22.md` を必ず読むこと）
同spec「ja: 実施事項」「ko: 実施事項」「共通」をすべて実施する。要点:
- ja/ko のアップロード順を 01,02,09,08,04,03,05,06,07,10 にし、`output/app-store-screenshots/v2/upload-order/{ja,ko}/iphone-69/` へ en-US と同形式（READMEつき）で配置
- ja #8 sub を「勉強や仕事の30分〜2時間 曜日と時間帯の予約も」に（読点禁止・体言止め）。#8 eyebrow「集中タイマーで完全ブロック」は実機能（Deep Focus＝時間指定の完全ブロック）との齟齬がないか判断し、齟齬がなければ採用、あれば据え置いて理由を報告
- ko #8 eyebrow「공부·업무 시간 완전 차단」、#1 eyebrow「숏폼·SNS 시간 셀프 체크」。#6 eyebrow への 습관/루틴 追加は任意（入れるなら自然さ優先）
- 旧スクリプト（承認正本）とv2の両方に反映し、ja/ko を再生成（コンタクトシート・slots.json含む）。1枚1キャラ・実画面のみの制約は維持
- ja コピーは `~/.claude/skills/humanizer-jp` のパターン検出を通し、ko コピーは `~/.claude/skills/humanizer-ko/scripts/audit.py` を書く前と後の2回実行して exit 0 にする（結果の数値を報告）
- `.claude/specs/appstore-screenshots-v2-diagonal.md` 末尾に ja/ko の反映内容を追記（en-US の2026-08-22追記と同形式）
- 依頼外メモ（ko #1「33일」とja/en「35日」の不一致）は変更せず、報告に1行だけ残す

## 検証（報告に必ず含める）
- `cd ios && xcodegen generate` → 署名なしgeneric iOS Simulator向け `xcodebuild build` が `BUILD SUCCEEDED`
- `python3 scripts/lint-display-copy.py` exit 0、`git diff --check` 通過
- v2再生成: ja/ko 各10枚＋contact sheet＋slots（total ≤ 1）、upload-order ディレクトリの中身一覧
- humanizer-ko audit の前後の数値、humanizer-jp の検出結果
- 変更ファイル一覧と、最終コンタクトシートのパス（ja/ko/en-US）
