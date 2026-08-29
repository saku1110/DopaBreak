# ホームの目標カードを複数表示＋追加/編集ボタンへ（2026-08-28・オーナー指示）

オーナー指示: 「ホーム画面は現在の目標を表示して、追加ボタンと編集ボタンで目標画面に遷移させる方がいい」。
背景事実: 目標はFree/Proとも無制限（2026-08-17決定・`EntitlementGate.goalsLimit == nil`）。GoalsView（「目標」タブ）は複数対応済み。ホームだけ `goals.first` 1件表示（`home-screen-fact-copy-redesign.md` で「見送り」）。

## 変更（最小）
### 1. HomeView.swift — `goalCard` の作り替え（このcomputed propertyとその補助プロパティ以外は触らない。**作業ツリーには別セッションの未コミット差分（lockScreenCard等・+140行）があるので、それらの行を編集・整形・移動しない**）
- ヘッダー行: 左 eyebrow 既存キー `home.goal.label`（「あなたの目標」）／右に2ボタン **「追加」「編集」**（新キー `home.goal.add` / `home.goal.edit`。ja 追加／編集、en Add／Edit、ko 추가／편집。テキストボタン・44pt以上のタップ領域）
- 本文: `model.goals` を **全件** 行表示（`ForEach`）。各行 = `GoalCategoryTile(category:size: 32)` ＋ タイトル（既存の書体系に合わせ 17pt semibold・2行まで）。行タップ = 既存どおり `GoalEditorRoute(goal: そのgoal)`（その目標の編集シート）
- 先頭3件（Live Activityに出る件数 `LockSurfaceCoordinator.liveActivityGoalLimit`）以外の行には既存キー `goals.badge.on_lock_screen` を **付けない**。先頭3件にも付けない（ホームでは情報を増やさない。バッジは目標タブの役割）
- 空状態: 既存 `home.goal.fallback`（「タップして目標を追加」）の1行を残し、タップ = 「追加」と同じ動作
- 「追加」= 目標タブへ切替＋追加シートを開く。「編集」= 目標タブへ切替（一覧のEditButton／行タップ編集は既存）
- `primaryGoalTitle` / `primaryGoalCategory` / `hasPrimaryGoal` はホームで不要になるなら削除（他で参照があれば残す）

### 2. RootTabView.swift — ホーム→目標タブの導線
- `HomeView` に `onOpenGoals: (_ addRequested: Bool) -> Void` 相当のクロージャを追加（既存 `onOpenStats` と同じ流儀）。`selectedTab = .goals` に切替え、`addRequested` のときは GoalsView に「追加シートを開け」を伝える
- 伝達は `RootTabView` の `@State private var goalsAddRequest: UUID?` を `GoalsView` に渡し、`GoalsView` 側で `.onChange` → `editorRoute = GoalEditorRoute(goal: nil)`（GoalsView が既に持つ追加経路を再利用）。タブ切替と同フレームでシートを出すと崩れる場合は次のrunloopで提示

### 3. Localizable.xcstrings
- 新キー `home.goal.add` / `home.goal.edit`（3言語・translated）
- 既存 `onboarding.goal.multi_note` の3言語から「無料プランでは1つまで」相当を削除（ja「目標は複数追加できます」／en・koも同義に）。8/17決定との矛盾解消。**`OnboardingFlow.swift` の該当行（962付近）は文言キー参照のみで、Swift側は変更しない**（別セッションの未コミット差分あり）

### 4. 文言規則
- ボタン・見出しは平易な名詞のみ（造語・英語eyebrow禁止・読点なし）。既存画面（目標タブ）の語彙に揃える

## テスト（新規ファイルのみ・既存テストファイルは編集しない）
- `ios/DopaBreakTests/HomeGoalsCopyTests.swift`: `Localizable.xcstrings` を読み、`home.goal.add` / `home.goal.edit` が ja/en/ko で translated、`onboarding.goal.multi_note` の3言語いずれにも「1つまで」「one goal」「1개」等の上限表現が含まれないこと
- 新規ファイル追加後 `cd ios && xcodegen generate`

## 検証（全て実行して報告）
- `xcodebuild test -project ios/DopaBreak.xcodeproj -scheme DopaBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` が TEST SUCCEEDED（全体）
- `python3 scripts/lint-display-copy.py` / `python3 scripts/audit-default-values.py` が exit 0
- シミュレータでホームを撮影: `xcrun simctl` でスクショを `output/verify/home-goals-multi.png` に保存（目標3件を入れた状態が望ましい。データ投入が難しければ空状態＋1件で可）
- 報告: 変更ファイル一覧＋3行要約＋検証結果。差分本文は貼らない
