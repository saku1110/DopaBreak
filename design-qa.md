# Design QA — UI/UX監査4画面の実装

## Evidence

- Source visual truth:
  - `output/imagegen/ui_audit_2026-07-14/01_home_first_day_v2.png`
  - `output/imagegen/ui_audit_2026-07-14/02_paywall_fixed_cta.png`
  - `output/imagegen/ui_audit_2026-07-14/03_direct_route_cancel.png`
  - `output/imagegen/ui_audit_2026-07-14/04_onboarding_goal_lightweight.png`
- Rendered implementation screenshots:
  - `output/screenshots/ui-audit-2026-07-15/01_home_first_day.png`
  - `output/screenshots/ui-audit-2026-07-15/02_paywall_fixed_cta.png`
  - `output/screenshots/ui-audit-2026-07-15/03_direct_route_cancel.png`
  - `output/screenshots/ui-audit-2026-07-15/04_onboarding_goal_lightweight.png`
- Same-input comparison images:
  - `output/screenshots/ui-audit-2026-07-15/comparisons/01_home_first_day_comparison.png`
  - `output/screenshots/ui-audit-2026-07-15/comparisons/02_paywall_fixed_cta_comparison.png`
  - `output/screenshots/ui-audit-2026-07-15/comparisons/03_direct_route_cancel_comparison.png`
  - `output/screenshots/ui-audit-2026-07-15/comparisons/04_onboarding_goal_lightweight_comparison.png`
- Viewport: iPhone 16 Pro、402×874pt。実装スクリーンショットは1206×2622px。比較画像では参照モックと実装を同じ603×1311pxへ正規化した。
- States: 初日かつ実績0のHome / 年額選択中のPaywall / 明確目的「仕事で使う」の10分選択 / 未入力かつ任意項目折りたたみ中の目標設定。

## Findings

- P0/P1/P2の未解決差分なし。
- P3 — 参照モックのオンボ進捗は`06 / 14`、実装は現行14ステップ順の7番目なので`07 / 14`。状態遷移の正しさを優先し、表示だけを偽装しない。
- P3 — モックのPaywall CTAは無料トライアル対象例。実装はStoreKitの適格性がfalseのため`年額プランを始める`を表示した。対象ユーザーだけ`7日間無料で始める`へ切り替わる。
- P3 — Dynamic Island、ステータスバー、ディープリンク元表示、SF Symbolsはシステム描画のため静止モックと細部が異なる。
- P3 — MorningHorizonは既存の実画像コンポーネントを同じクロップ規則で使用しており、ImageGenの写真クロップとは水平線位置がわずかに異なる。

## Required Fidelity Surfaces

- Fonts and typography: システム日本語フォントのBlack/Bold/Semibold、monospaced小見出し、2行見出しを維持。402pt幅でクリップなし。
- Spacing and layout rhythm: 20pt水平余白、カード間10〜20pt、主CTA 56pt、補助操作44pt以上。Paywall CTAはsafe-area固定。
- Colors and tokens: 既存E1の背景、カード、補助文字、ライム`DesignTokens.accent`を再利用。初日Homeは選択中タブ以外の実績ライムを出さない。
- Image fidelity: `MorningHorizon`の実ラスタ資産をHomeとPaywallで使用し、代替図形やプレースホルダーは使っていない。
- Copy and content: 初日誘導、年額/月額、`開かずに戻る`、3つの目標プリセット、`あとで設定する`を正本どおり実装。価格・割引・月換算・無料期間はStoreKit値から動的表示する。

## Interaction Verification

- Paywall: 年額/月額を選択可能。固定CTA、購入復元、`あとで`が同時に表示され、`あとで`で閉じることを確認。
- Direct route: `仕事で使う`を選ぶと呼吸を省いて時間選択へ遷移。`開かずに戻る`を押すと`開かなかった。あなたの勝ち`へ遷移することを確認。
- Onboarding goal: 3つのプリセットが主入力へ反映され、選択状態もVoiceOverへ公開される。任意短縮名の開閉と入力欄の出現を確認。
- Home: 実績0では巨大な0、メトリクスカード、週カードを描画せず、実績が発生すると従来の実績ビューへ戻る明示分岐を確認。

## Comparison History

1. 初回実装比較
   - P2: Paywallがシート表示で背面の設定画面が上端に見え、参照モックの全画面階層と不一致。
   - P2: Paywallの写真が72ptでタイトルが2行になり、参照の感情ヒエラルキーより弱かった。
2. 修正
   - Paywallの全呼び出しを`fullScreenCover`へ統一。
   - 写真を112ptへ拡大し、`DOPABREAK PRO`を画像へ重ね、タイトルを1行へ調整。
   - 読み込み中の年額カード内スピナーを外し、価格更新時のレイアウトシフトを防止。
3. 最終比較
   - `02_paywall_fixed_cta_comparison.png`を再生成。固定CTA、2プラン、法務表示を含む全要素が同一ビューポートに収まり、P2差分を解消。

## Verification

- `xcodebuild`: iPhone 16 Pro simulator / Debug / code signing disabledで成功。
- DopaBreakCore: 144 tests passed、0 failures。
- 4状態をSimulatorで表示し、主要CTA・補助導線・入力・開閉を実操作。ランタイムクラッシュなし。

final result: passed
