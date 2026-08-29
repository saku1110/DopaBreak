# ホーム目標複数表示 — Opus5レビュー指摘の是正（2026-08-28）

元仕様: `.claude/specs/home-goals-multi.md`。以下6件を全て直す。**並走中の別Codexが `StartInterventionIntent.swift` / `InterventionFlowView.swift` / `AppContainer.swift` / `DopaBreakApp.swift` / `Localizable.xcstrings` / Core を編集中なので、これらは触らない。** 本是正で触ってよいのは `HomeView.swift`（goalCard/goalHeaderButton 周辺のみ）・`RootTabView.swift`・`GoalsView.swift`・`OnboardingFlow.swift` の962行付近1行・`scripts/audit-default-values.py`・新規テスト。

1. **監査例外の撤回（HIGH）**: `scripts/audit-default-values.py` の `ALLOWED_DEFAULT_VALUE_MISMATCHES` と `continue` を**完全に元に戻す**（`git checkout -- scripts/audit-default-values.py` 相当）。代わりに `ios/DopaBreak/OnboardingFlow.swift:962` 付近の `onboarding.goal.multi_note` の `defaultValue` を `"目標は複数追加できます"` に変更（句点も除去）。着手前に `git diff -U0 ios/DopaBreak/OnboardingFlow.swift` でその行が他セッションの変更ハンクに含まれないことを確認し、含まれていたら変更せず報告する
2. **初回タップで追加シートが開かない（MEDIUM-HIGH）**: `GoalsView` の body 未評価時（目標タブ未訪問）は `.onChange(of: addRequest)` が遷移を観測できない。`@State private var consumedAddRequest: UUID?` を持ち、`.onAppear` と `.onChange` の両方で `addRequest != nil && addRequest != consumedAddRequest` なら消費して `editorRoute = GoalEditorRoute(goal: nil)`（次runloop提示は維持）
3. **トークン未消費（MEDIUM）**: `RootTabView.goalsAddRequest` を `Binding` で渡し、GoalsView が提示後に `nil` へ戻す（または消費コールバック）。2の `consumedAddRequest` と併用し二重発火なし
4. **ヘッダーボタンの44pt（MEDIUM）**: `goalHeaderButton` の `.frame(minWidth: 44, minHeight: 44)` をラベル内側へ移し `.contentShape(Rectangle())` を付ける（既存パターン HomeView.swift:470 と同じ）
5. **行・空状態の死角（MEDIUM）**: 各行ラベルと空状態ラベルに `.contentShape(Rectangle())` を追加し、行全体（Spacer部・上下パディング含む）をタップ可能にする
6. **編集シート上書き（LOW）**: `GoalsView` の `DispatchQueue.main.async { editorRoute = ... }` に `guard editorRoute == nil` を追加

## テスト
- 新規 `ios/DopaBreakTests/GoalsAddRequestTests.swift`: 追加要求の消費ロジックを純関数化（例 `GoalsAddRequestPolicy.shouldPresent(request:consumed:) -> Bool`、Core か App のどちらでも可）して、①初回nil→UUID ②同一UUID再評価で再提示しない ③新UUIDで再提示 を固定
- 既存テストファイルは編集しない。新規追加後 `cd ios && xcodegen generate`

## 検証
- `xcodebuild test`（アプリ全体）TEST SUCCEEDED／`python3 scripts/audit-default-values.py` が**例外なしで** exit 0／`lint-display-copy.py` exit 0
- 報告: 変更ファイル一覧＋3行要約＋検証結果。差分本文は貼らない
