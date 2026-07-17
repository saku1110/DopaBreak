# Design Decisions

## 2026-07-12 — UI/UX多角監査の確定所見（オーナー未承認・モック作成待ち）

Claude Code側で6レンズ監査（ビジュアル/介入UX/オンボ/ペイウォール/a11y/コピー）→全所見を仕様整合・デザイン価値の2レンズで敵対検証し、確信の高いもののみ残した。却下済み案（全画面写真化・推測時間表示・呼吸強制等）への抵触なしを検証済み。

- モック作成対象（Codexで画像モック→承認後に実装）:
  1. **Home初日ゼロ状態**: 現状は0が5箇所+ライム82ptの「0回」。実績0の間はライム点灯とメトリクス/週カードを止め、誘い1枚に集約。ライムは「最初の1回」の報酬にする。
  2. **Paywall CTA固定ボトムバー**: 現状は単一ScrollViewでCTA・復元・規約が初期表示外。購入CTA+復元を`.safeAreaInset(.bottom)`固定バーへ。既委譲の2段化（年額+月額）と合わせた構成でモック化。
  3. **直行ルート時間選択に「開かずに戻る」**: 直行ルート（仕事/調べもの/連絡/投稿）に脱出手段がない袋小路。CTA下に控えめなテキストボタンで`chooseCancel()`→勝ち画面。
  4. **オンボ目標入力の軽量化**: 例文プリセットチップ（doc07:145の離脱対策・未実装）を追加、仕様外のカテゴリPickerをオンボから除去、見出しの1行目末尾読点を改行に修正。
- モック不要の直接修正（要点のみ・詳細はセッションログ参照）:
  - Paywall: 月額フォールバック780円→980円（PaywallView.swift:315・正本docs/15不一致）/「月あたり415円」を動的算出/見出し「38日」を本人推計値に/機能行「ロック画面に人生の目標」をPro実体（テーマ着せ替え等）へ。
  - 介入: S-02見出し「すでに開いています」→正本「今日はもう{N}回目」/6択ヘッダーに「{アプリ名}を開く前に」（モック正本に既存）/勝ち画面にsuccessハプティクス+springチェック+numericText。
  - オンボ: ショートカット起動と同時のadvance()廃止（手順書が消える）/「STEP XX/04」二重進行表示の廃止/未入力時に例文「英語で話す」を本人の目標として表示しない/CTA「ブロック」→「止める」。
  - その他: Stats「試行」→「開こうとした」/Stats初日の巨大「—」非表示/Home週バーの指標不一致（幅=率・文言=回数）統一/設定行にchevron/GoalsのScreenHeaderピン留め衝突/振り返り2段階目の選び直し/Dynamic Type全面未対応（固定pt全置換・最重要a11y）/44ptタップ領域/VoiceOver isSelected・日本語ラベル。
- 対象外にしたもの: ペイウォール2段化・47%→58%表示（既にCodex委譲済み計画）/Homeヒーロー数字とメトリクスの重複（承認モック通り）/docs/07の乖離（文書修正のみでUI不変）。

## 2026-07-12 — 現行SwiftUI実装に合わせて設計書を同期

- 作成・変更:
  - `docs/04_functional_requirements.md`: 目的確認先行の介入、5/10/15/30分の時間確定、通知による時間切れ案内、実測値だけを使うHome、フラット目標（Free 1件 / Pro 複数件）へ更新。
  - `docs/06_screen_design.md`: 朝焼け写真を使う5面、現行画面カタログ、目的別介入ルート、達成回数中心のHome、通知/振り返り方式へ更新。
  - `docs/07_onboarding_design_lifefocus.md`: 目的確認先行プレビュー、通知+Live Activity、5/10/15/30分、最初の目標1件、Welcome/Readyの現行コピーへ更新。
  - `docs/11_ui_copy.md`: 目的確認6択、判断、時間選択、起動中、勝ち画面、Home達成表示の現行文言へ更新。
  - `docs/12_hybrid_intervention.md`: 目的別分岐、時間選択後の明示CTA、通知と途中チェックインの制約を反映。
  - `design/BUILD_SPEC_E1.md` / `docs/FABLE_BRIEF.md`: 旧HTMLモックより現行SwiftUIと最新モックを優先する読み替え、および目標/介入/写真仕様を反映。
  - `docs/CHANGELOG.md`: 今回の実装と設計書同期の変更履歴を追加。
- 採用した方針:
  - 朝焼け写真はWelcome / Home / Ready / Paywall / Notification previewだけに使い、操作画面はE1 Dark Monoの無写真UIとする。
  - 介入は目的確認6択から開始。仕事・調べもの・連絡・投稿は呼吸を省き、暇つぶし・なんとなくだけ呼吸、回数、全目標、判断を通す。
  - 時間は5/10/15/30分から選び、`{N}分だけ開く`で確定する。時間切れは通知で知らせ、iOSが他アプリを自動で閉じるような表現はしない。
  - Homeの達成表示は実ログから出せる「自分で選べた回数」を使う。実利用時間はDeviceActivity等の実測ソースがある場合だけ表示する。
  - 目標は種類なしのフラットリスト。オンボでは1件だけ任意入力、Freeは1件、Proは複数件とする。
- 却下・廃止した案:
  - 全画面への自然写真、呼吸の全利用者強制、旧4択、1/3/5/10分、旧「あと1分」、ヒーロー目標＋1年目標の2枠固定、推測した未使用時間は現行仕様から除外。
- Claude Code側の制約:
  - 仕様の優先順位は現行SwiftUI、`docs/11_ui_copy.md`、`docs/12_hybrid_intervention.md`、最新モック、旧HTMLモックの順。
  - 写真正本は`ios/DopaBreak/Resources/morning-horizon.png`。写真面では暗色オーバーレイとDynamic Type時の可読性を維持する。
  - Homeへ時間指標を追加する場合は実測データ源を先に実装し、選択時間や回数から推測しない。
  - 旧仕様は履歴として残っていても、現行仕様として再実装しない。

## 2026-07-11 — 最新モックをSwiftUIへ実装

- 作成・変更:
  - `ios/DopaBreak/Resources/morning-horizon.png`: モックと同方向の朝焼け海背景を実画像資産として追加。
  - `ios/project.yml`: `DopaBreak/Resources`のPNGをアプリResourceへ含め、未使用の`Assets.xcassets`をsource走査から除外。
  - `ios/DopaBreak/DesignTokens.swift`: E1カラーを正確な値へ統一、ボタン/カード寸法を更新、`MorningHorizon`を追加。
  - `ios/DopaBreak/OnboardingFlow.swift`: Welcome/Readyの写真背景、通知+Live Activity案内、目的確認先行のPreview、横幅拘束を実装。
  - `ios/DopaBreak/HomeView.swift`: 朝焼けヒーロー、目標、達成ヒーロー、今日/週の実績へ全面更新。
  - `ios/DopaBreak/PaywallView.swift`: 朝焼けの細いヘッダーを追加。
  - `ios/DopaBreak/InterventionFlowModel.swift`: 時間を選択してからCTAで確定する状態を追加。
  - `ios/DopaBreak/InterventionFlowView.swift`: 6択カード密度、2×2時間選択、起動中、勝ち画面をモックへ整合。
  - `ios/DopaBreak/PostUseReflectionSheet.swift`: 2段階目に選択済み満足度カードを追加。
  - `ios/DopaBreak/MidSessionCheckInSheet.swift`: 戻る先カードを追加。
  - `design-qa.md`: モックと実機スクリーンショットの比較履歴。`final result: passed`。
- 採用した方針:
  - 朝焼け写真はWelcome/Home/Ready/Paywall/通知プレビューに限定。介入と設定は無写真E1 Dark Mono。
  - Homeは写真を132ptの帯に抑え、達成情報をファーストビュー内に残す。
  - 時間選択は即時起動ではなく、5/10/15/30分の選択状態を見せてCTAで確定する。
  - ImageGenアイコンは転用せず、実装はSF Symbolsで統一。
- 意図的な差分:
  - モックの「SNSを使わなかった時間 1時間42分」は、現行データから実利用時間を正確に算出できないため実装しない。推測値を表示せず、ログから正確に出せる「自分で選べた回数」を達成ヒーローにした。
- Claude Code側の制約:
  - 朝焼け正本は`ios/DopaBreak/Resources/morning-horizon.png`。`Assets.xcassets`は`project.yml`で除外され、使用しない。
  - Homeへ時間指標を追加する場合は、DeviceActivity等の実測ソースを先に実装し、選択時間や回数から推測しない。
  - `screenScroll`の`.containerRelativeFrame(.horizontal)`を外すとオンボ見出しが横にはみ出すため維持する。
  - モック比較の正本スクリーンショットは`output/screenshots/design-qa-*-comparison*.png`。
- 検証:
  - iPhone 16 Pro simulator向け`xcodebuild`成功。
  - DopaBreakCore 144テスト成功、失敗0。

## 2026-07-11 — 最新仕様の不足・変更モック21状態を生成

- 作成:
  - `output/imagegen/lifefocus_latest_spec/01_anchor_screens.png`: Welcome / Notification+Live Activity / Ready / Home達成表示 / Paywall。
  - `output/imagegen/lifefocus_latest_spec/02_direct_purpose_route.png`: 目的確認6択から、仕事等の明確目的で呼吸を省略するルート。
  - `output/imagegen/lifefocus_latest_spec/03_reflective_purpose_route.png`: 暇つぶし等の反射的目的だけに呼吸・回数・目標・判断を入れるルート。
  - `output/imagegen/lifefocus_latest_spec/04_support_sheets.png`: 2段階振り返り、途中チェックイン、目標編集、対象アプリ選択、自動起動ガイド。
  - `output/imagegen/lifefocus_latest_spec/README.md`: 画面対応表、生成プロンプト仕様、実装時の扱い。
- 採用した方針:
  - 朝焼け写真はWelcome/Home/Ready/Paywallなど「人生に戻る」感情を担う要所だけに限定。
  - 目的確認・介入・設定はE1 Dark Monoの無写真UIとし、判断速度と可読性を優先。
  - 目的確認を最初に置き、明確な目的は時間選択へ直行、反射的な目的だけ一呼吸へ分岐。
  - 時間選択は実装に合わせて5/10/15/30分。「自動で閉じる」は使わず通知表現に統一。
- 却下した案:
  - 全画面に海や空の写真を敷く案は、操作画面の情報密度と集中を損なうため不採用。
  - 旧モックの「呼吸を全利用者へ強制」「4択」「1/3/5/10分」「時間で自動終了」は最新仕様とiOS制約に合わないため不採用。
- Claude Code側の制約:
  - 画像は階層・余白・視覚方向の正本。文言の最終正本は`docs/11_ui_copy.md`と現行Swiftコード。
  - ImageGenのアイコンを画像として切り出さず、実装ではSF Symbolsを使用する。
  - 写真背景には暗色オーバーレイを固定し、主要テキストのコントラストを維持する。
  - 旧`lifefocus_v2`の介入順序より、本セットの目的確認先行ルートを優先する。

## 2026-07-11 — 全モック画像の完成度監査

- 確認対象:
  - `output/mockups/lifefocus_v2/` の全29 PNG / 29 HTML
  - `output/imagegen/lifefocus_nature_options/01_morning_horizon.png`
  - `output/imagegen/lifefocus_home_achievement/01_time_hero.png`
  - 現行SwiftUI実装 `ios/DopaBreak/`
- 作成:
  - `output/audits/mock-completeness-2026-07-11.md`: 画面群別の完成判定、不足画面、正本化条件を記録。
- 判定:
  - ファイル数としては29画面揃っているが、最新仕様と採用デザインに一致する正本セットではないため「未完成」。
  - 採用済みの朝焼け写真案はボード画像にしかなく、Welcome/Home/Ready/Paywall等の単体正本へ未反映。
  - 介入フローは旧モックが呼吸開始・4択・1/3/5/10分のまま。現行の目的確認先行、6択、目的別分岐、5/10/15/30分へ更新が必要。
  - `08_widget_guide`と`20_lock_widget`は廃止方式を含むため正本から除外・置換が必要。
- 採用方針:
  - 次回のモック更新では、朝焼け写真を要所（Welcome/Home/Ready/Paywall）だけに使い、操作密度の高い画面はE1 Dark Monoを維持する。
  - 目的別介入は「明確な目的」と「反射的な目的」を別ルートとして連続画面で示す。
- 却下した見方:
  - 「29枚存在するので完成」とする判定は、廃止画面・旧コピー・旧状態遷移を含むため不採用。
- Claude Code側の制約:
  - モック正本を更新するまで、`lifefocus_v2`の旧介入順序を実装仕様として参照しないこと。
  - 現行の正しい介入状態遷移は`InterventionFlowModel.swift`と`docs/12_hybrid_intervention.md`を優先すること。
  - 写真背景には可読性確保の暗色オーバーレイを設け、Dynamic Typeでも主要CTAが隠れない縦スクロール/セーフエリア設計を維持すること。

## 2026-07-11 — セッション中の軽量チェックイン通知

- 作成・変更:
  - `ios/DopaBreak/InterventionFlowModel.swift`: 10分以上の選択時に、経過時間の半分でチェックイン通知を1本追加。
  - `ios/DopaBreak/NotificationDelegate.swift`: 通知タップを識別し、App Groupの保留フラグへcatalogIDを書き込むデリゲートを追加。
  - `ios/DopaBreak/DopaBreakApp.swift`: 通知デリゲートを起動時に登録し、アプリのライフサイクル中は強参照で保持。
  - `ios/DopaBreak/MidSessionCheckInSheet.swift`: 目標1件のリマインドと「閉じる」だけを持つ軽量シートを追加。
  - `ios/DopaBreak/RootTabView.swift`: 起動時・アクティブ復帰時に保留フラグを一度だけ消費し、シートを表示。
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SettingsStore.swift`: `pendingMidSessionCheckInCatalogID`を追加。
  - `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/SettingsStoreTests.swift`: 新規設定値の保存・再読込・nil消去テストを追加。
  - `ios/DopaBreak.xcodeproj/project.pbxproj`: 新規Swiftファイル2件をDopaBreakターゲットへ登録。
- 採用した方針:
  - `docs/11_ui_copy.md` §10の文言だけを転記し、チェックインは通知タップ時のみ表示するソフトな呼びかけとした。
  - 通知IDは承認済みの`dopabreak.midsession.<catalogID>.<uuid>`形式を維持。現行のSNSAppCatalog IDが小文字英数字のみで`.`を含まないことを確認し、復元時はカタログ存在確認とUUID妥当性確認も行う。
  - 表示優先順位は全画面の介入フロー、チェックイン、既存の振り返りの順。介入または別シート表示中はチェックインの保留フラグを消費せず、シートを重ねない。
- 却下した案:
  - catalogIDとの区切りを`|`へ変える案は、現行ID形式で`.`が一意な区切りとして安全であり、承認済み識別子形式を変える必要がないため不採用。
  - チェックイン後の分岐、記録、SNSアプリを閉じる処理は、機能の非強制的な目的とiOSの技術制約に反するため追加していない。
- 実装上の制約:
  - 5分選択では追加通知を作らず、10・15・30分だけ半分の時点に通知する。既存の時間切れ通知は全選択肢で従来どおり1本作る。
  - `UNUserNotificationCenter.delegate`は弱参照のため、`DopaBreakApp.notificationDelegate`の強参照を維持すること。
  - シートは高さ280ptの単一detent。目標は`model.goals.first`のみを表示し、目標なしでは正本のフォールバック文言を使う。
  - `docs/11_ui_copy.md`は本実装では変更していない。

## 2026-07-14 — UI/UX監査4画面の単体モックを生成

- 作成:
  - `output/imagegen/ui_audit_2026-07-14/01_home_first_day_v2.png`: 初日ゼロ状態。ゼロ指標と週カードを外し、誘いの見出しへ集約。
  - `output/imagegen/ui_audit_2026-07-14/02_paywall_fixed_cta.png`: 年額/月額の2段プランと固定CTAバーを1画面に統合。
  - `output/imagegen/ui_audit_2026-07-14/03_direct_route_cancel.png`: 時間選択CTA直下へ控えめな`開かずに戻る`を追加。
  - `output/imagegen/ui_audit_2026-07-14/04_onboarding_goal_lightweight.png`: 目標入力を1項目、例文チップ、任意折りたたみに軽量化。
  - `output/imagegen/ui_audit_2026-07-14/README.md`: 最終参照ファイル、生成条件、プロンプト仕様、実装制約を記録。
- 採用した方針:
  - Home初日は達成色をタブ選択以外に使わず、最初の成功で初めて実績領域をライム点灯させる。初回画像の写真帯が深かったため、写真帯の高さだけを縮めた`v2`を最終参照にした。
  - Paywallはスクロールなしで2プラン、法務表示、CTA、復元、あとでを同時に見せる。年額選択をライム枠、月額を中立カードとした。
  - 直行ルートの`開かずに戻る`は、主CTAと競合しない補助色のテキストボタンとした。
  - オンボ目標は主入力1つ＋例文チップ＋任意折りたたみとし、スキップ文言は現行正本の`あとで設定する`を使った。
- 却下した案:
  - Home初日に巨大な0、0回メトリクス、週カードを残す案は、失敗感と情報重複を強めるため不採用。
  - Paywallの買い切り併記、旧780円フォールバック、CTA/復元をスクロール領域へ残す案は不採用。
  - `開かずに戻る`を枠付きボタンにする案は、主CTAとの視覚競合が起きるため不採用。
  - オンボにカテゴリPicker、2つ目の必須入力、架空の入力済み目標を残す案は不採用。
- Claude Code側の実装制約:
  - 画像は階層と余白の正本。コピーは`docs/11_ui_copy.md`と現行Swiftコードを優先し、価格はStoreKitの商品値から動的に表示する。
  - Homeのゼロ状態と実績あり状態は明示分岐し、0値を非表示にするだけでレイアウトが崩れないよう別コンポーネントまたは明確な状態ビューにする。
  - Paywall固定領域は`.safeAreaInset(.bottom)`相当とし、Dynamic Type/SE系端末では本文をスクロールさせてもCTA、復元、あとでの到達性を維持する。
  - `開かずに戻る`は現行`chooseCancel()`から勝ち画面へ接続し、時間選択エンジンを変更しない。
  - オンボのカテゴリは目標エディタに残し、オンボからのみ除去する。任意短縮名は折りたたみ、未入力時に例文を本人の目標として保存・再掲しない。

## 2026-07-15 — UI/UX監査4画面をSwiftUIへ実装

- 作成・変更:
  - `ios/DopaBreak/HomeView.swift`: 初日かつ当日/週の試行0を明示分岐し、巨大な0、当日メトリクス、週カードを外して目標カードと初回誘導へ集約。
  - `ios/DopaBreak/PaywallView.swift`: 年額/月額の2プラン、動的価格・割引・月換算、固定ボトムCTA、復元、常時表示の`あとで`、法務表示を実装。写真ヘッダーを112ptへ調整し、読み込みスピナーによるレイアウトシフトを除去。
  - `ios/DopaBreak/HomeView.swift` / `GoalsView.swift` / `SettingsView.swift` / `OnboardingFlow.swift`: Paywall表示を`fullScreenCover`へ統一。
  - `ios/DopaBreak/InterventionFlowView.swift`: 明確目的の時間選択だけに`開かずに戻る`を追加し、`chooseCancel()`から既存の勝ち画面へ接続。
  - `ios/DopaBreak/OnboardingFlow.swift`: 目標入力を1項目＋3プリセット＋任意短縮名のDisclosureへ軽量化。オンボ内カテゴリPickerと架空フォールバック目標を削除。
  - `output/screenshots/ui-audit-2026-07-15/`: iPhone 16 Proの4状態とモック横並び比較を保存。
  - `design-qa.md`: 今回の4画面を最新QA対象へ更新し、`final result: passed`。
- 採用した方針:
  - 初日Homeは0をopacityで隠さず、空状態と実績あり状態を別レイアウトにする。実績が1件発生した時点で従来の達成UIへ戻す。
  - Paywallは本文のみスクロール可能、購入CTA・復元・`あとで`は`.safeAreaInset(.bottom)`で固定。年額を初期選択し、買い切りは表示しない。
  - StoreKitの商品価格、無料トライアル適格性、年額割引、月換算を表示の正本とし、無料対象でないユーザーへ無料訴求を出さない。
  - 直行ルートの離脱は控えめなテキストボタンとし、反射的目的のフローや時間選択エンジンには影響させない。
  - オンボでは入力負荷を抑え、カテゴリは`.other`として保存する。短いロック画面文言は任意で、初期状態は折りたたむ。
- 却下した案:
  - Homeの0表示を残す案、Paywallへ買い切りを戻す案、`開かずに戻る`を枠付き副CTAにする案、オンボでカテゴリと2入力を常時見せる案は、承認モックの目的と競合するため不採用。
  - StoreKit適格性に関係なく`7日間無料`を固定表示する案は、誤認を生むため不採用。
  - 未入力目標を例文`英語で話す`で補う案は、本人が設定していない内容を保存・再掲するため不採用。
- Claude Code側の実装制約:
  - `HomeView.isFirstDayEmpty`は`todayAttemptCount == 0 && weekAttemptCount == 0`。判定を当日だけへ変えると週内実績がある日のレイアウトが初日に戻るため注意。
  - Paywallは全呼び出し元で全画面表示を維持する。固定領域には購入、復元、`あとで`の44pt以上の操作領域を残す。
  - PaywallのCTAと法務文言は`StoreService.isEligibleForAnnualIntroOffer`に従う。フォールバック価格は年額4,980円、月額980円。
  - `開かずに戻る`は`flow.selectedReason?.isDirect == true`の時だけ表示し、遷移先は既存`.win`のままにする。
  - オンボ目標ステップは現行14ステップの7番目なので`07 / 14`が正しい。モックの`06 / 14`へ表示だけを合わせない。
- 検証:
  - iPhone 16 Pro simulator向け`xcodebuild`成功。
  - DopaBreakCore 144テスト成功、失敗0。
  - Paywallの`あとで`、直行ルートの`開かずに戻る`→勝ち画面、目標プリセット反映、任意フィールド開閉を実操作で確認。

## 2026-07-17 — オンボーディング訴求文言の中央寄せ（オーナー指示）

- 作成・変更:
  - `ios/DopaBreak/OnboardingFlow.swift`: 全14ステップの訴求ブロック（アイブロウSmallLabel・見出しtitleText・リードbodyText）を中央寄せ化。共通ヘルパー`centeredEyebrow`/`centeredTitle`/`centeredLead`を新設し、各画面の該当要素を置換。
- 採用した方針:
  - 中央寄せの対象は訴求文言（アイブロウ・見出し・リード・推計結果のリビール・PNAS引用）。フォーム入力・選択肢ボタン・カード内・自動化手順・whyScienceの※免責3行は左寄せのまま。
  - welcome/quizResultは画面全体が訴求のためVStackごと中央化。selfCheckの質問見出し（optionSection title・当該画面のみ使用）も中央化。
  - `screenScroll`の`.containerRelativeFrame(.horizontal)`は維持（既存制約）。各要素は`frame(maxWidth: .infinity, alignment: .center)`+`multilineTextAlignment(.center)`で中央化しており、スクロール構造は不変。
- 意図的な差分（Codexレビュー指摘2件を検討のうえ不採用）:
  - selfCheckの「回答は端末内にのみ保存されます。」とquizResultの「※ご回答からの推計値です。」はCodexが「フォーム注記/免責のため左寄せに残すべき」と指摘したが、両画面は前後要素がすべて中央のため左寄せ混在の方が崩れて見えると判断し中央のまま採用。オーナーが実機で違和感を持てば個別に戻せる（centeredLead→bodyTextに戻すだけ）。
- 検証:
  - `xcodegen generate`→ simulator向け`xcodebuild` **BUILD SUCCEEDED**。
  - DopaBreakCore **144テスト0失敗**。
  - Codex独立レビュー実施（コンパイルレベルの問題なし・上記P2 2件のみ）。
