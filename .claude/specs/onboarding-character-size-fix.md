# オンボーディング12・15のキャラクターサイズ是正仕様（2026-08-14 オーナー指摘）

## 背景
- オーナー指摘: 12枚目（notificationGuide）と15枚目（ready）のキャラクターが他ページより小さい
- 15枚目の額縁装飾（背景塗り＋枠線＋角丸クリップ）は旧チェックマークバッジの遺産で、キャラ差し替え時に引き継がれたもの（git 116bd74 で確認済み）

## 変更（ios/DopaBreak/OnboardingFlow.swift）

### 1. notificationGuideContent（12枚目）
- `CharacterView(.relief, size: DesignTokens.CharacterSize.support)` → `size: DesignTokens.CharacterSize.header`（88→120pt）
- ロック画面モックパネル（高さ300pt）内の `.overlay(alignment: .top)` 配置と `.padding(.top, 16)` は維持
- 下部の通知プレビューカードとキャラが視覚的に重なりすぎないことを確認（必要なら top padding を微調整）

### 2. readyContent（15枚目）
- `CharacterView(.relief, size: DesignTokens.CharacterSize.support)` → `size: DesignTokens.CharacterSize.header`
- 旧チェックマークバッジ由来の装飾を削除する:
  - 横長 frame（`support * 17/12`）
  - `.background(DesignTokens.accent.opacity(0.09))`
  - `.overlay(RoundedRectangle... stroke accent 0.42)`
  - `.clipShape(RoundedRectangle(cornerRadius: 28))`
- 他ページと同じ素置きにする
- **祝福演出は維持**: `.scaleEffect(readyCheckmarkScale)` と `.opacity(isReadyCelebrated ? 1 : 0)`、Reduce Motion分岐はそのまま。変数名 `readyCheckmarkScale` は実態に合わせ `readyCharacterScale` へリネームしてよい

## 制約
- 他ページのキャラクターサイズ（welcome/quizResult=lead、preview/prePaywallSummary=header）は変更しない
- DesignTokens.CharacterSize の値自体は変更しない（役割別サイズの原則を維持）
- 推計結果画面の再構成（onboarding-result-restructure.md）の変更と衝突させない

## 検証
- xcodebuild build（Simulator向け）が通ること
- 12枚目でキャラと通知カードのレイアウト破綻がないこと
