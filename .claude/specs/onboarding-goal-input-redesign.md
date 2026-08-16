# オンボーディング目標入力の再設計（プリセットチップ廃止・例文ローテーション）

- 日付: 2026-08-15
- 承認: オーナー（「OK。あとちゃんと目標複数追加できること書いてね」）
- 対象: `ios/DopaBreak/OnboardingFlow.swift` の `goalSetupContent`、`ios/DopaBreak/Localizable.xcstrings`

## 背景・決定

- プリセットチップ（読書を30分/筋トレを続ける/資格の勉強）は誰もタップしない上、タップ一発でテンプレ文がそのまま目標になり「自分の言葉で書く」ことを阻害するため廃止する
- 参考例は「押せない例」としてプレースホルダのローテーションで見せる。抽象的な長期目標でも具体的な行動でもよいことをリード一行で伝える
- 目標は複数追加できること（無料プランでは1つまで）を明記する（オーナー指示）
- 目標例に「今日の」等の時制ラベルを付けない既存ルールは維持

## 変更仕様

### 1. プリセットチップ削除（OnboardingFlow.swift）

- `goalPresets` 定数（L165-169）、`goalPresetChip(_:)`（L1347〜）、`goalSetupContent` 内の `LazyVGrid` ブロック（L765-774）を削除
- xcstringsから `onboarding.goal.preset.reading` / `.workout` / `.study` の3キーを削除
- `onboardingStagger` の番号は欠番が出ないよう振り直す（eyebrow 0 → title 1 → lead 2 → 複数追加注記 3 → 入力欄 4 → 追加済み目標リスト 5）

### 2. リード＋複数追加注記の追加

タイトル直下に `centeredLead` を2行追加（アプリ選択画面 `onboarding.apps.lead` + `free_limit_note` と同じパターン）:

| キー | ja | en | ko |
|---|---|---|---|
| `onboarding.goal.lead` | なりたい姿でも やることでもいい | A big dream or a small habit. Either works. | 되고 싶은 모습도 할 일도 좋아요 |
| `onboarding.goal.multi_note` | 目標は複数追加できます。無料プランでは1つまで | You can add multiple goals. Up to 1 on the free plan | 목표는 여러 개 추가할 수 있어요. 무료 플랜은 1개까지 |

- koの文体は既存オンボーディングkoストリングの語尾に合わせて微調整してよい（意味は変えない）

### 3. プレースホルダのローテーション

入力欄が空のあいだ、以下3例を約3.5秒間隔で切り替える:

| キー | ja | en | ko |
|---|---|---|---|
| `onboarding.goal.placeholder.aspiration` | 例: 英語で話せるようになる | e.g. Learn English | 예: 영어로 말할 수 있게 되기 |
| `onboarding.goal.placeholder.habit` | 例: 寝る前に本を読む | e.g. Read every night | 예: 자기 전에 책 읽기 |
| `onboarding.goal.placeholder.action` | 例: 資格の勉強を進める | e.g. Pass my exam | 예: 자격증 공부하기 |

- 旧 `onboarding.goal.placeholder` キーは削除（置き換え）
- 例文の目標部分は全言語 `OnboardingGoalList.titleLimit`（16文字）以内であること（実際に入力可能な例を見せる）
- 切替はクロスフェード等の穏やかなトランジション。**Reduce Motion時はローテーションを停止し1例目を固定表示**
- 実装はTextField標準プロンプトの差し替えでも、`heroGoal.isEmpty` 時のみ表示するオーバーレイText方式でもよい。オーバーレイ方式の場合は `.allowsHitTesting(false)` と `.accessibilityHidden(true)` を付け、TextField側に安定した `accessibilityLabel`（新キー `onboarding.goal.field.accessibility` ja: 目標を入力 / en: Enter a goal / ko: 목표 입력）を付ける
- タイマーは画面離脱時に確実に破棄する
- **L730-732のIMEコメントと入力バインディングのロジックには一切触れない**（変換中の切り詰め禁止）

### 4. 目標タブ空状態の例文統一

`goals.empty.description` の末尾例「例：読書30分」を「例：英語で話せるようになる」に変更（ja）。en/koも同じ趣旨で対応する既存文の例部分だけ差し替える。

## スコープ外（触らない）

- `canLeaveGoalSetup` の進行条件、「あとで設定する」スキップ導線、追加ボタン、文字数カウンタ、helper「そのままロック画面に表示されます」
- `EntitlementGate.canAddGoal`（無料1/Pro無制限）と2つ目追加時の `paywallPlacement = .goalsLimit`
- GoalsView / GoalEditorSheet のUI構造

## 検証

- `xcodegen generate` → ビルド成功
- `OnboardingMotionCapture`（01-goal-empty / 02-goal-filled）がコンパイル・実行可能なこと
- 既存テストが全件パス（プリセット参照テストがあれば削除・更新）
