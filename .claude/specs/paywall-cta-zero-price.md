# ペイウォールCTAのゼロ価格化 — 実装仕様（2026-08-28・オーナー承認済み）

## 目的
年額カードは既に「7日間 ¥0」（`store.intro_offer.zero_price`）。CTAだけ「7日間無料で始める」のままで枠組みが割れているので、**適格時のCTAもゼロ価格表記に揃える**。決定記録: `.claude/specs/design-decisions.md` 2026-08-28エントリ。

## 変更（最小・これ以外は触らない）
1. `ios/DopaBreak/Localizable.xcstrings` に新キー **`paywall.action.start_zero_price`** を追加（state=translated・3言語・**位置指定子必須**。%1$@=期間テキスト・%2$@=ゼロ価格テキスト）
   - ja: `%1$@ %2$@で始める` → 「7日間 ¥0で始める」
   - en: `Start %1$@ for %2$@` → 「Start 7 days for $0」
   - ko: `%1$@ %2$@으로 시작하기` → 「7일간 ₩0으로 시작하기」（既存 `paywall.action.start_free` ko「%@ 무료로 시작하기」と語尾を揃える）
   - 既存 `paywall.action.start_free` は**フォールバックとして残す**（削除・変更しない）
2. `ios/DopaBreak/StoreService.swift`
   - `IntroOfferDisplayPolicy` に `static func ctaText(durationText: String?, zeroPriceText: String?) -> String?` を追加。`planCardStyle` と同じ判定で、`.durationWithZeroPrice` のときだけ `String(localized: "paywall.action.start_zero_price", defaultValue: "\(duration) \(zeroPrice)で始める")` を返し、それ以外は `nil`
   - `StoreService` に `@Published`（既存プロパティと同じ公開方式に合わせる）`annualIntroOfferCTAText: String?` を追加し、`updateAnnualIntroOfferInfo()` 内で `annualIntroOfferText` と同じ duration/zeroPrice から算出。ガード失敗時は nil
   - 通貨記号のリテラル記述は禁止。ゼロ価格は既存 `zeroPriceText(for:)`（`Product.priceFormatStyle`）を流用
3. `ios/DopaBreak/PaywallView.swift` の `primaryButtonTitle` **のみ**変更: `selectedPlan == .annual && storeService.isEligibleForAnnualIntroOffer` のとき `storeService.annualIntroOfferCTAText ?? 既存の start_free 文言`。他の行は一切触らない（**このファイルには別セッションの未コミット差分があるため、該当computed property以外を編集・整形しない**）
4. 不変: `paywall.legal.annual_intro`／`paywall.plan.annual.intro_fallback`／`paywall.trial_reminder.*`／`store.intro_offer.*`／適格false時の「年額プランを始める」／月額選択時

## テスト（新規ファイル。既存テストファイルは編集しない＝別セッションの未コミット差分と混ぜないため）
- `ios/DopaBreakTests/PaywallCTAZeroPriceTests.swift`（XCTest・`@testable import DopaBreak`）
  - `IntroOfferDisplayPolicy.ctaText`: 期間＋ゼロ価格あり→「7日間 ¥0で始める」型／ゼロ価格nil・空・記号のみ→nil／期間nil→nil
  - `Localizable.xcstrings` を読み、`paywall.action.start_zero_price` が ja/en/ko すべて translated で `%1$@` と `%2$@` を両方含むこと
- 新規ファイル追加後は `ios/` で `xcodegen generate`（pbxprojはxcodegen生成・未追跡）

## 検証（全て実行して結果を報告）
- `cd ios && xcodebuild test -project DopaBreak.xcodeproj -scheme DopaBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DopaBreakTests/PaywallCTAZeroPriceTests` が TEST SUCCEEDED
- `xcodebuild build-for-testing`（同スキーム）が成功
- `python3 scripts/lint-display-copy.py` と `python3 scripts/audit-default-values.py` が exit 0（スクリプトの場所は `scripts/` を確認。無ければその旨を報告）
- 報告は変更ファイル一覧＋3行要約＋検証結果のみ。差分本文は貼らない
