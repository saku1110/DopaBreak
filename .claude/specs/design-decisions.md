# Design Decisions

## 2026-07-17 — コピー方向のオーナー決定2件（確定）

- **JPオンボWelcomeは現行維持**:「人生の時間は 二度と戻らない」。L1への差し替え提案は却下。
- **「ドーパミンに選ばれる」という受動表現は却下**（オーナー: 意味がわからない）。doc13 L1「人生を選ぶか ドーパミンに選ばれるか」はこの形では採用しない。

## 2026-07-18 — ペイウォール見出しの検証完了（確信度high・オーナー実装承認待ち）

4ラウンド計146エージェントの多段検証（14候補×5ペルソナのコールドリード→敵対3審→修正→再ゲート×2）で確定:

- **最終推奨見出し**: 「あと5分だけ」が年{N}日 ＼ 開く前に、一拍おく（{N}=本人推計の動的値。推計画面と数値一致必須=景表法前提）
- 現行「その38日を、人生に使う」は3審全kill（機構理解1/5・4/5がブロック系と誤読→one sec挫折者=最重要課金層が離脱リスク＋誤認課金→返金リスク）
- オーナー却下のL1（理解2/5）・「人生か、ドーパミンか」（理解0/5・最下位）はデータでも却下裏付け。**「人生vsドーパミン」軸はJP見出しでは機能しない**（whyScience説明文に留める）
- 最終案Dのゲート実測: 機構理解5/5・プラン選択勘ぐり0/5・購入正当化の空白1/5・摩擦1/5
- サブコピー案（one sec挫折者の「また続かない」への反論担当）と逐次コホート検証計画（返金率・one sec経験セグメント監視）は output/audits/onboarding-copy-strategy-by-country-2026-07-17.md 最終節を参照
- 確信度highの対象は「候補中の選定の正しさ」。実CVRは市場の逐次コホート比較が最終判定

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

## 2026-07-17 — Settingsプライバシー節と端末内データ全削除

- 作成・変更:
  - `ios/DopaBreak/SettingsView.swift`: アカウント/課金の直後に、プライバシーポリシー・利用規約・全データ削除の3行を持つ`プライバシー`節を追加。削除前の確認ダイアログと、成功後2秒間の行内フィードバックを実装。
  - `ios/DopaBreak/AppURLs.swift` / `ios/DopaBreak/PaywallView.swift`: 法務URLを`AppURLs`へ集約し、SettingsとPaywallで共有。
  - `ios/DopaBreak/AppContainer.swift`: `deleteAllLocalData()`を追加。ルール削除より先に`ShieldController.clearShield()`を実行し、Coreの一括削除経路を呼ぶ。
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/LocalDataResetter.swift`および各Store: 目標・ルール・対象アプリ・試行/振り返り・ファネル・設定と一時スナップショットを空/defaultへ戻す経路を追加。
  - `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/LocalDataResetterTests.swift`: 全Store、集計、設定既定値、進行中状態の削除後状態を検証する2テストを追加。
  - `docs/11_ui_copy.md`: `Settings — プライバシー`節へ全表示文言を登録。
- 採用した方針:
  - 既存のE1 Dark Mono、`SmallLabel`＋`CardContainer`＋settings rowの階層を維持し、不可逆操作だけをネイティブの`confirmationDialog`で確認する。
  - 削除行は既存の`DesignTokens.danger`、完了表示はaccentを使い、別トーストを新設せず操作した行の中で因果関係が分かるフィードバックにする。
  - 現在の画面はそのまま保ち、目標・統計等を既存の空状態へ更新する。永続設定の`onboardingCompleted`はdefaultへ戻るため次回起動時はオンボーディングになるが、削除直後に強制遷移はしない。
- 却下した案:
  - 確認なしの即時削除は取り消せない操作の誤タップ防止がないため不採用。
  - JSON/SQLiteだけを消してManagedSettingsを残す案は、削除済みルールを参照する孤立シールドを生むため不採用。
  - StoreKit購入・Entitlementを削除対象へ含める案は、Apple管理の取引履歴であり端末内ユーザーデータではないため不採用。
- Claude Code側の実装制約:
  - 一括削除の順序は`clearShield()`をStore削除より先に維持する。Core側ではInterventionEngineをidle化してからルールとログを消す。
  - `SettingsStore.resetToDefaults()`はDopaBreakが所有するキーだけを個別削除する。UserDefaultsのpersistent domain全体を消さない。
  - URL正本は`AppURLs`。PaywallまたはSettingsへ法務URL文字列を再度直書きしない。
- 検証:
  - `swift test --package-path ios/Packages/DopaBreakCore`: 146テスト成功、失敗0。
  - `xcodegen generate`後、generic iOS Simulator向け`xcodebuild`: `BUILD SUCCEEDED`。

## 2026-07-17 — 全データ削除の独立レビュー修正

- 作成・変更:
  - `ios/DopaBreak/AppContainer.swift`: SQLite初期化失敗時の早期returnを廃止し、通知キャンセル後にCoreのbest-effort削除を常に実行。削除直後のrefreshでは通知を再スケジュールしない。
  - `ios/DopaBreak/LockSurfaceCoordinator.swift`: pending/delivered通知を全件削除する経路と、進行中・待機中の再スケジュールを世代番号で無効化する直列タスク管理を追加。週次通知は実試行が1件以上ある場合だけ作成。
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/LocalDataResetter.swift`: `SQLiteLogStore`/`InterventionEngine`をoptional化し、各Storeと各snapshotを独立して削除。SQLiteがnilまたはSQL削除失敗時はDB本体と`-wal`/`-shm`/`-journal`を直接削除。
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SQLiteLogStore.swift`: DBファイル名をfallbackと共有する単一定義へ集約。
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SettingsStore.swift`: `firstLaunchDate`をreset対象から除外。
  - `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/LocalDataResetterTests.swift`: `firstLaunchDate`保持と、SQLite初期化不能時にも他Storeを消去してDB/sidecarを物理削除する回帰テストを追加。
- 採用した方針:
  - プライバシー削除はStoreごとのbest-effortとし、1箇所の破損で残りのデータ削除を止めない。SQLiteの正常系は従来どおり行削除、初期化不能/SQL失敗だけファイル削除へfallbackする。
  - 通知はDopaBreak以外が同じnotification centerへ登録する用途がないため、識別子列挙ではなくpending/deliveredを全件削除する。削除と競合する旧スケジュールも世代番号で無効化する。
  - `firstLaunchDate`はユーザー作成コンテンツではなくFree枠のanti-abuse基準なので、オンボーディング状態などを初期化しても保持する。
- 却下した案:
  - SQLiteがnilなら一括削除全体を失敗させる案は、JSON/UserDefaults側の消去機会まで失うため不採用。
  - 削除後に既定値の通知設定で通常refreshする案は、ゼロ値週次通知や競合中の古い通知を復活させるため不採用。
  - `firstLaunchDate`を他設定と一緒に削除する案は、14日間のFree枠を繰り返し再取得できるため不採用。
- Claude Code側の実装制約:
  - 削除順は`clearShield()`→`cancelAllNotifications()`→best-effort Store削除→通知なしrefreshを維持する。
  - SQLiteのファイル名を追加・変更する場合は`SQLiteLogStore.databaseFileNames`を正本とし、sidecar削除対象も維持する。
  - `SettingsStore.resetToDefaults()`へ`firstLaunchDate`を再追加しない。週次通知の`attempts > 0`ガードを外さない。
- 検証:
  - `swift test --package-path ios/Packages/DopaBreakCore`: 147テスト成功、失敗0。
  - `xcodegen generate`後、generic iOS Simulator向け`xcodebuild`: `BUILD SUCCEEDED`。

## 2026-07-17 — Goal型の2枠残骸削除とShield選択の統一

- 作成・変更:
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Models/AppModels.swift`: `GoalType` enumと`Goal.goalType`、initializer引数を削除。`GoalCategory`を含む他フィールドは維持。
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/GoalStore.swift`: 種類別取得/削除APIと旧2枠順へのmigration並べ替えを削除し、保存配列をそのまま返すよう変更。
  - `ios/ShieldConfigExtension/ShieldConfigurationExtension.swift`: `.hero`検索を`primaryGoal()`へ置換。
  - `ios/DopaBreak/AppContainer.swift`: 新規Goal作成から旧`goalType`指定を削除。
  - `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/{GoalStoreTests,DopaBreakCoreTests,LocalDataResetterTests}.swift`: 新initializerへ同期し、旧migrationテストを保存順・`primaryGoal()`・`moveGoal`のフラットリスト挙動へ適応。
  - `docs/05_detailed_design.md` / `docs/CHANGELOG.md`: Free 1件／Pro複数件の現行モデルと実装結果を同期。
- 採用した方針:
  - 種類なしのフラットリストを唯一のGoalモデルとし、配列の先頭をHome・Shield・介入面で共通の主目標として扱う。
  - 順序は追加時の末尾挿入と`moveGoal`だけで管理し、読込時の暗黙並べ替えは行わない。
- 却下した案:
  - 旧JSON向けに`GoalType`や種類別APIを互換shimとして残す案は、廃止済み2枠モデルへの依存を再発させるため不採用。JSONDecoderは未知の旧`goalType`キーを無視できるため、モデルへ残す必要はない。
  - Shieldだけ`.hero`を検索し続ける案は、フラットリストの先頭を使う他画面と不一致になり、Pro複数目標で表示欠落や誤選択を起こすため不採用。
- Claude Code側の実装制約:
  - 目標の表示優先度は保存配列順。主目標を変える場合は`moveGoal`で先頭を変更し、種類フィールドや暗黙ソートを再導入しない。
  - `Goal.category`は現行FR-004の分類フィールドなので削除しない。
  - `ios/DopaBreak/StoreService.swift`の`.year`はStoreKitのSubscriptionPeriod.Unitであり、本変更の対象外。
- 検証:
  - `swift test --package-path ios/Packages/DopaBreakCore`: 147テスト成功、失敗0。
  - `xcodegen generate`後、ShieldConfigExtensionを含むgeneric iOS Simulator向け`xcodebuild`: `BUILD SUCCEEDED`。

## 2026-07-17 — Measurement foundation batch 1（端末内ファネル計測）

- 作成・変更:
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/FunnelEventStore.swift`: `onboardingStepCompleted` / `paywallDismissed` / `prePaywallSkipped` / `appOpened`を追加。
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/DailyAppOpenRecorder.swift` / `Storage/SettingsStore.swift`: ユーザーのローカルCalendar日付キーで`appOpened`を1日1回にするCoreサービスと`lastAppOpenedDateKey`を追加。
  - `ios/DopaBreak/OnboardingFlow.swift`: 全14ステップの安定snake_case IDを定義し、全完了遷移を`advance()`へ集約して離脱前stepを記録。実在していた`prePaywallSummary`の「あとで」では`prePaywallSkipped`も記録。
  - `ios/DopaBreak/PaywallView.swift` / `StoreService.swift` / `GoalsView.swift` / `SettingsView.swift`: Bool提示状態を型付き`PaywallPlacement`へ変更し、表示元を`paywallShown.detail`へ保存。「あとで」だけ`paywallDismissed`を保存し、購入・復元成功後のdismissでは保存しない。
  - `ios/DopaBreak/RootTabView.swift` / `AppContainer.swift`: 初回`onAppear`とscenePhase `.active`を共通処理へまとめ、どちらが先でも日次dedupeを実行。
  - `ios/DopaBreak/HomeView.swift`: 代入元がなく到達不能だった未属性Paywall coverを削除。
  - `ios/DopaBreakTests/MeasurementFoundationTests.swift` / `ios/project.yml`: アプリ層テストターゲットと、14 step ID・9 placement ID・Paywallイベントdetailの回帰テストを追加。
  - `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/{DailyAppOpenRecorderTests,FunnelEventStoreTests,SettingsStoreTests,LocalDataResetterTests}.swift`: 新イベント、東京日付境界のdedupe、設定永続化、全削除時のキー消去を検証。
- 採用した方針:
  - placementは`goals_limit`、`settings_target_app_limit`、`settings_family_activity_limit`、`settings_pro_status_row`、`settings_theme_gate`、`settings_mode_gate`、`onboarding_prepaywall_summary`、`onboarding_mode_gate`、`onboarding_target_app_gate`の9値。非表示で温存中のFamilyActivityPicker上限経路は、現行カタログPickerと分析上区別する。
  - step IDは表示文言やenumのInt順に依存せず、`welcome`から`ready`まで14個を明示する。Ready CTAも`advance()`へ通し、14番目の完了を欠落させない。
  - `appOpened`はイベント書込み成功後だけ日付キーを更新する。Calendarは`.autoupdatingCurrent`を使い、端末の現行Calendar/timezoneに追従する。
- 却下した案:
  - PaywallViewへplacement文字列のdefault/unknownを持たせる案は、将来の提示元追加で無属性イベントを再発させるため不採用。全到達可能な提示元でenum指定を必須にした。
  - `prePaywallSkipped`を省く案は、現行UIに`prePaywallSummary`の「あとで」導線が実在したため不採用。新しいUIは追加していない。
  - foreground復帰ごとの`appOpened`記録は、要件の1日1回とD1/D7/D30ローカル集計の粒度に合わないため不採用。
- Claude Code側の実装制約:
  - Paywall提示元を追加する場合は`PaywallPlacement`へ安定IDを追加し、`fullScreenCover(item:)`へ必ず渡す。購入/復元成功dismissを`paywallDismissed`へ数えない。
  - Onboardingの順序・名称を変える場合も既存identifierを分析互換の正として扱い、意味が同じなら変更しない。完了CTAは`advance()`を通す。
  - `lastAppOpenedDateKey`は端末内データ全削除のreset対象から外さない。外部analytics SDKやnetwork送信は本batchの範囲外。
- 検証:
  - `swift test --package-path ios/Packages/DopaBreakCore`: 151テスト成功、失敗0。
  - iPhone 16 Pro Simulatorの`DopaBreakTests`: 3テスト成功、失敗0（`TEST SUCCEEDED`）。
  - `xcodegen generate`後、generic iOS Simulator向け`xcodebuild`: `BUILD SUCCEEDED`。

## 2026-07-17 — Measurement foundation 独立レビュー修正

- 作成・変更:
  - `ios/DopaBreak/DopaBreakApp.swift`: `WindowGroup`内のオンボーディング/メインタブ両分岐を`AppLifecycleView`で包み、cold launchとscene `.active`の`appOpened`記録を常設ルートへ移動。
  - `ios/DopaBreak/RootTabView.swift`: タブ配下に限定されていた`appOpened`記録を削除し、タブ固有のrefresh・保留処理だけを維持。
  - `ios/DopaBreak/StoreService.swift` / `PaywallView.swift`: Pro権利取得済み、またはStoreKit購入が`.pending`の間は`paywallDismissed`を記録しない判定を追加。Transaction更新でPro取得後はpending状態を解消。
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/DailyAppOpenRecorder.swift`: 保存済み最大日付キーより新しい日だけ記録する単調増加dedupeへ変更。
  - `ios/DopaBreakTests/MeasurementFoundationTests.swift`: オンボーディング未完了の共通ルート表示で`appOpened`が保存されるアプリ層テストと、Pro/pending時のPaywall離脱抑止テストを追加。
  - `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/DailyAppOpenRecorderTests.swift`: D→D-1→D→D+1でDを二重計上しない回帰テストを追加。
- 採用した方針:
  - `appOpened`のライフサイクル責務はオンボーディング状態に依存しない`WindowGroup`直下の単一choke pointへ置く。`onAppear`とforeground復帰の双方から呼ぶが、Coreの日次dedupeで同日重複を防ぐ。
  - `paywallDismissed`は確定した「未購入離脱」だけを表す。既にProなら記録せず、Ask to Buy等のpendingも結果未確定なので記録しない。
  - 時計/タイムゾーン巻き戻し対策は全日付集合を保存せず、既存の`lastAppOpenedDateKey`を最大キーとして扱う低コストな単調増加方式にした。
- 却下した案:
  - OnboardingFlowとRootTabViewの両方へ記録処理を複製する案は、将来のroot分岐追加時に欠落しやすいため不採用。
  - 記録済み全日付キーを無期限保存する案は、低頻度の端末時計エッジケースに対して状態管理が過剰なため不採用。
  - async購入完了時にPaywallを外部から強制dismissする案は画面所有権を広げるため今回は行わず、誤った離脱イベントの抑止に限定。
- Claude Code側の実装制約:
  - `AppLifecycleView`はオンボーディングと`RootTabView`の外側に維持する。`appOpened`をタブ配下だけへ戻さない。
  - Paywallの「あとで」は`StoreService.recordPaywallDismissedIfNeeded`を通し、`isPro`/`hasPendingPurchase`確認を迂回しない。
  - 単調増加方式では端末時計を未来へ大きく進めて戻した場合、その最大日付を越えるまで新規記録を抑止する。重複によるretention水増しを避ける方を優先した既知のトレードオフ。
- 検証:
  - `swift test --package-path ios/Packages/DopaBreakCore`: 152テスト成功、失敗0。
  - `xcodegen generate`後、generic iOS Simulator向け`xcodebuild`: `BUILD SUCCEEDED`。
  - iPhone 16 Pro Simulatorの`DopaBreakTests`: 5テスト成功、失敗0（`TEST SUCCEEDED`）。

## 2026-07-18 — コピー確定改訂（オーナー承認・Q1再設計＋ペイウォール2行目差し替え）

- オーナー決定:
  - ペイウォール見出し2行目: 検証済みD案「開く前に、一拍おく」を**却下**（「一拍おく」はどの層にも響きにくい語彙）。代案Aを採用し、さらに**読点を削除**して「**開く前にブレーキ**」で確定。アプリ名（Break）の回収・KR版「브레이크」と背骨統一。
  - 読点の癖への指摘: 「なんでも読点を入れるな」。以後、短い表示コピーでは読点をデフォルトで入れない（doc11 §0の運用を厳格化）。
  - Q1（O-02）: 「1日に何回、無意識にSNSを開いていますか？」は**却下**（回数は覚えていない→迷って進めない＝離脱要因。96回アンカーは三人称統計で「へー」で終わる）。**時間質問へ変更**: 「SNSを見ている時間は／1日どれくらいですか？」＋補助線「ざっくりでOKです」（選択肢の直前）＋時間バケット4択。案A（「SNSを見ている時間」先頭立て）をオーナーが選択。
- 設計上の発見:
  - doc07 O-02の原設計はもともと時間バケットであり、実装が回数＋96回アンカーへドリフトしていた。今回は正本回帰。
  - LossEstimatorは時間キー（1時間未満/1-2時間/2-4時間/4時間以上→45/90/150/270分）を実装済みのためCore変更ゼロ。回数キーは過去の保存データ互換のため残す。
  - EntitlementGate.statsDays（Free=1日/Pro=無制限）が実在するため、ペイウォール機能行は「記録を全期間さかのぼれる」で誠実に書ける（C3の空約束「詳細な統計と継続記録」を置換）。
- 正本改訂: doc07 §5末尾「2026-07-18 文言確定改訂」表＋doc11 §5「2026-07-18 ペイウォール見出し・機能行の確定改訂」を追加。矛盾時はこの2表が正。
- 保留（本改訂に含めない）: ペイウォールサブコピー差し替え（「取り返した」の語の可否）、勝ち画面doc13案、US/KR全文言（ローンチ前にJPと同じコールドリード検証必須）。

## 2026-07-18 — 確定コピーをSwiftUIへ反映

- 作成・変更:
  - `ios/DopaBreak/OnboardingFlow.swift`: O-02を時間質問・時間バケットへ変更し、補助線を設問と選択肢の間へ配置。推計結果、対象アプリCTA、STEP表記、科学説明、オートメーション案内、準備画面の確定文言を反映。
  - `ios/DopaBreak/PaywallView.swift`: 見出しを2行化し、`SelfCheckSnapshot.estimatedYearlyDays`から一度だけ解決した個人推計値を数字アクセントで表示。機能行2件を実際のPro差分へ更新。
  - `ios/DopaBreakTests/MeasurementFoundationTests.swift`: ペイウォール年間日数のsnapshotあり／nil時fallbackを検証するアプリ層テストを追加。
  - `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/LossEstimatorTests.swift`: オンボーディングの確定時間バケットへテスト文言を同期。
- 採用した方針:
  - O-02の`ざっくりでOKです`は既存`centeredLead`を`optionSection`内で使い、折り返す中央見出しと選択肢の間に置いた。既存の中央寄せ階層と`screenScroll`構造は維持。
  - ペイウォールは既存の`DefaultContainerProvider`＋`JSONSnapshotStore`パターンをinitializerの既定依存として使い、body再評価ごとの読み込みを避けた。表示値の決定は純粋な`resolvedYearlyDays(snapshot:)`へ分離。
  - 2行見出しは既存30pt black、tracking -1、minimumScaleFactor 0.78を各行に維持し、1行目の動的な数字だけaccent色とした。
- 却下・変更しなかった案:
  - 年間日数38の直接固定表示、補助線を選択肢の下へ残す案、ペイウォールサブコピー変更、画面構造のリファクタは確定仕様外のため不採用。
- Claude Code側の実装制約:
  - ペイウォール年間日数はsnapshot値を最優先し、未取得時は`LossEstimator.estimate(usageBucket: "2-4時間")`、その推計自体が失敗した場合だけliteral 38を使う順序を維持する。
  - `screenScroll`の`.containerRelativeFrame(.horizontal)`、オンボーディング訴求文の中央寄せ、ペイウォールサブコピーは変更しない。
- 検証:
  - `swift test --package-path ios/Packages/DopaBreakCore`: 152テスト成功、失敗0。
  - `cd ios && xcodegen generate`: 成功。
  - generic iOS Simulator向け`xcodebuild`: `BUILD SUCCEEDED`。
  - iPhone 16 Pro Simulatorの`DopaBreakTests`: 6テスト成功、失敗0（`TEST SUCCEEDED`）。

### 同日追記 — Codex独立レビュー裁定（2026-07-18）

- 指摘#1「PaywallView initの同期ファイルI/O（9箇所×毎構築）」→ **却下**。self_check_snapshot.jsonは1KB未満の単発読みでOSキャッシュも効き、初回フレームへの実測影響は無視できる。キャッシュ化すると全データ削除→再オンボーディング時に古い{N}を表示する鮮度バグを生む。プリペイウォール直前にスナップショットが更新される本アプリでは毎構築時読みが正しい。プロファイリングでjank実測が出た場合のみ再検討。
- 指摘#2「レガシー回数バケツの回帰テスト消失」→ **採用**。互換キー維持（過去の保存データ対応）は設計判断のため、専用回帰テストを復元。
- 指摘#3「永続化経路・破損データfallbackの統合テスト不在」→ **部分採用**。書き込み→注入→解決の統合テストと破損JSON→38 fallbackテストを追加。レンダリング/Dynamic Typeのスナップショットテストはハーネス未導入のため不採用（導入判断は別タスク）。
- 採用2件の反映後の最終検証（Fable独立実行）: Core 158テスト0失敗・アプリ層 7テスト0失敗・generic Simulator向け `BUILD SUCCEEDED`。

## 2026-07-18 — 7/17監査コアループ不具合 B1・B2・B3・B9・B11 修正

- 作成・変更:
  - `ios/DopaBreak/AppContainer.swift` / `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Models/AppModels.swift`: 本体側の介入要求消費点で期限内の`temporarilyAllowed`を判定し、再介入要求を破棄。期限切れは既存`reshieldIfExpired()`を通してから通常フローへ進める。
  - `ios/DopaBreak/InterventionFlowModel.swift` / `ios/DopaBreak/InterventionFlowView.swift`: URL起動完了の成功確認後にだけ`recordOpen`と通知予約を実行し、完了待ち中は画面を自動終了しない。理由・決定・時間選択系メソッドへstage再入ガードを追加し、通知予約前に認可状態を確認。
  - `ios/DopaBreak/NotificationDelegate.swift` / `ios/DopaBreak/RootTabView.swift`: チェックイン保留をcatalogID＋書込時刻へ変更し、書込後のアプリ内通知でRootの再チェックを確実に起動。30分超過または未来時刻の保留は破棄。
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SettingsStore.swift`: `pendingMidSessionCheckInCatalogID`を時刻込みの単一Dataキー`pendingMidSessionCheckIn`へ置換。
  - `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/PendingInterventionPolicyTests.swift` / `SettingsStoreTests.swift` / `LocalDataResetterTests.swift`: 一時開放期限、チェックイン30分境界、永続化、全データ削除の回帰テストを追加・同期。
- 採用した方針:
  - AppIntentは従来どおりpendingキー書込だけとし、エンジン参照は本体プロセスの単一消費点に限定する。
  - URLスキームなし／URL起動失敗は「ホーム画面から{アプリ名}を開いてください」を表示し、手動起動前提として記録と通知を1回だけ維持する。
  - チェックインのレース対策は永続フラグを正本にし、`NotificationCenter`は書込後の再消費トリガーとしてのみ使う。
- 却下・変更しなかった案:
  - Intent側で`InterventionEngine`を読む案は単一ライター原則に反するため不採用。
  - `InterventionFlowModel.start()`へ`temporarilyAllowed`をresumableとして足す案は、フル画面を一度提示して許可中状態をリセットし得るため不採用。
  - B4〜B8・B10・B12〜B14、CVR施策、通知未認可時の新規UI文言、docs変更はスコープ外のため未変更。
- Claude Code側の実装制約:
  - `consumeInterventionRequest`の期限内ガードをIntentへ移さない。期限内はpending要求を消費して何も表示しない。
  - URL起動成功時は`UIApplication.open`完了→`recordOpen`→通知予約→opening画面終了の順序を維持する。手動フォールバック分岐と二重記録させない。
  - `PendingMidSessionCheckIn.validityInterval`は30分。SettingsStoreのcatalogID単独旧キーへ戻さず、書込後の`.pendingMidSessionCheckInDidChange`通知を外さない。
- 検証:
  - `swift test --package-path ios/Packages/DopaBreakCore`: 154テスト成功、失敗0。
  - `cd ios && xcodegen generate`: 成功。
  - iPhone 16 Pro Simulator向け`xcodebuild build`: `BUILD SUCCEEDED`。
  - iPhone 16 Pro Simulatorの`DopaBreakTests`: 6テスト成功、失敗0（`TEST SUCCEEDED`）。

## 2026-07-18 — バグ修正バッチ独立レビュー採用4件の是正

- 作成・変更:
  - `ios/DopaBreak/AppContainer.swift` / `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Models/AppModels.swift`: 一時開放判定へ対象ルールIDを渡し、同一ルールの有効期限内だけ介入を抑止。自動化検収マークと`automationVerified`記録を抑止判定より前へ移動。
  - `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/PendingInterventionPolicyTests.swift`: ルール一致・不一致・期限切れ・ステップ違いの回帰テストを追加。
  - `ios/DopaBreak/RootTabView.swift`: 介入fullScreenCover終了後にチェックイン→振り返りを再評価し、振り返りシート終了後にも保留チェックインを再評価。
  - `ios/DopaBreak/InterventionFlowModel.swift`: 通知認可状態をフロー開始時にキャッシュし、アプリ起動完了ハンドラ内では認可済みの場合にcompletion-handler版`add`を即時発行。
  - `ios/DopaBreak/InterventionFlowView.swift`: 通知未認可時は`通知がオフのため時間のお知らせは届きません`を時間選択・起動中の案内へ表示。
- 採用した方針:
  - 一時開放はグローバル状態ではなく`InterventionState.ruleId`と受信`catalogID`から解決したルールIDの一致で判定する。ルール解決に失敗した場合は介入を表示する。
  - モーダル競合中に通知経由の再チェックが来ても、介入・振り返りのdismiss後に再評価して30分TTL内の表示機会を失わない。
  - 通知予約直前の認可状態awaitを廃止し、対象アプリへのバックグラウンド遷移前に予約要求を通知センターへ渡す。
- 却下・維持した方針:
  - URLスキームなし／URL起動失敗時に`recordOpenAndScheduleNotifications`を維持する既存分岐は、オーナー裁定どおり変更していない。
- Claude Code側の実装制約:
  - `hasActiveTemporaryAllowance(at:for:)`からルール一致条件を外さない。検収マークと`automationVerified`は一時開放による早期returnより前に維持する。
  - 通知予約メソッドへ`notificationSettings()`のawaitを戻さない。表示文言は`notificationsAuthorized`キャッシュと同期させる。
- 検証:
  - `swift test --package-path ios/Packages/DopaBreakCore`: 157テスト成功、失敗0。
  - `cd ios && xcodebuild build -scheme DopaBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`: `BUILD SUCCEEDED`。

## 2026-07-20 — 勝ち画面・サブコピー・「我慢」置換の確定（オーナー承認）

- オーナー決定（3点同時承認）:
  - ペイウォールサブコピー: 修正版を採用し**読点を全削除**。「がんばって我慢するアプリではありません。開く前に毎回ひと呼吸が入るだけ。開かずに戻れた回数が毎日ホームに積み上がります。」（原案3文目の「年{N}日換算で毎日見え続けます」は実在しない表示のため機能の嘘として棄却済み）
  - 勝ち画面: 「勝ち」フレームを却下（「勝ちとかじゃなくね？」）。doc13案を句読点なしで採用: 「開かなかった／今日も自分で選べた」+サブ「今日{N}回目」（旧サブ「意図した選択」は見出しと同義反復のため回数のみに縮小）
  - 「開かずに我慢」→「開かずに戻れた」全UI置換を承認（StatsView割合ラベル・週次通知・ウィジェットの3箇所。2026-07-02の旧語彙指定を上書き）
- 正本: doc11 §14に確定表を新設。doc13冒頭の承認状態を更新（§4・§5該当行のみ承認済み）。メモリ（feedback_user_facing_copy）も更新済み。

## 2026-07-20 — 確定コピー改訂の実装反映

- 作成・変更: `ios/DopaBreak/InterventionFlowView.swift`（勝ち画面2行）、`ios/DopaBreak/PaywallView.swift`（サブコピー）、`ios/DopaBreak/StatsView.swift`（割合ラベル）、`ios/DopaBreak/LockSurfaceCoordinator.swift`（週次通知本文）、`ios/WidgetsExtension/DopaBreakWidgets.swift`（ウィジェット文言）。
- 採用したデザイン方針: 「勝ち」「意図した選択」「我慢」の旧語彙を廃止し、「今日も自分で選べた」「今日{N}回目」「開かずに戻れた」へ統一。Paywallは正本どおり、我慢を否定する説明と毎日の積み上げを1つのサブコピーで伝える。
- 却下した案: 旧文言の併記、勝負フレームの再導入、対象画面以外のコピー変更は行わない。
- Claude Code側の実装制約: `InterventionFlowView.swift` の既存未コミット変更を保持し、指定された2行以外は変更しない。旧文言のテストアサーションは存在しないため、テストコードは変更しない。

## 2026-07-20 — 監査バグ修正バッチA（B4・B5・B6・B8・B10）

- 作成・変更:
  - `ios/DopaBreak/OnboardingFlow.swift` / `ios/DopaBreak/AppContainer.swift`: オンボで生成した目標UUIDを`@State`に保持し、再通過時は同一Goalの`updateGoal`へ分岐。
  - `ios/DopaBreak/PostUseReflectionSheet.swift` / `ios/DopaBreak/RootTabView.swift`: 振り返り保存を`do/catch`化し、失敗時は既存の`model.alertMessage`へ正本文言を設定。
  - `ios/DopaBreak/RootTabView.swift`: `NSCalendarDayChanged`受信時に`model.refresh()`を呼び出し。
  - `ios/DopaBreak/TargetAppPickerSheet.swift` / `ios/DopaBreak/SettingsView.swift`: 対象アプリ上限時のpaywall提示をシート`onDismiss`後へ移し、100ms遅延を追加。
  - `ios/WidgetsExtension/DopaBreakWidgets.swift`: 翌日0時エントリのみ今日の試行・成功カウントを0にしたsnapshotを使用。
- 採用した方針:
  - オンボの保存済みUUIDが見つからない場合は新規追加せず保存エラーにする。Free上限回避のための暗黙重複を作らない。
  - 振り返りの成功経路は従来の完了コールバックを維持し、失敗時だけシートを残してアプリ共通エラー通知へ渡す。
  - 日跨ぎ更新は既存scenePhase監視と同じRootTabViewへ置き、Home固有の状態管理を増やさない。
  - ウィジェットの翌日エントリでは目標・短縮表示・テーマ・更新日時を維持し、当日カウント2項目だけをクリアする。timeline policyは変更しない。
- 却下した案:
  - 目標再通過時にタイトル一致で既存Goalを探す案は、同名目標を誤更新するため不採用。
  - TargetAppPickerSheet内からpaywallを直接提示する案は、dismiss中のpresentation競合を残すため不採用。
  - 日跨ぎでsnapshot全体を作り直す案は、目標・テーマ等の非カウント情報を失うため不採用。
- Claude Code側の実装制約:
  - `savedGoalID`の一致確認なしにオンボの再通過を`addGoal`へ戻さない。目標編集は既存`model.updateGoal`の経路を使う。
  - `NSCalendarDayChanged`では`model.refresh()`を呼び、既存のscenePhase `.active`処理と別のカウントロジックを追加しない。
  - paywallはTargetAppPickerSheetのdismiss完了後にだけ`paywallPlacement`を設定する。オンボから同シートを再利用する場合も同じdismiss後提示制約を守る。
- 検証:
  - `swift test --package-path ios/Packages/DopaBreakCore`: 158テスト成功、失敗0。
  - `cd ios && xcodebuild build -scheme DopaBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`: `BUILD SUCCEEDED`。

## 2026-07-20 — 監査修正バッチB（B7・B13・B14・C3後半）

- 作成・変更:
  - `ios/DopaBreak/PaywallView.swift`: 年額月割りを`Product.priceFormatStyle`で商品通貨表示。商品ロード中を購入・復元・あとでのBusy状態へ追加。CTAと法務文言の無料期間をStoreKit導出値へ接続。Stats用の`statsHistoryGate` paywall placementを追加。
  - `ios/DopaBreak/StoreService.swift`: `introductoryOffer.period`から無料期間の表示文字列と期間文字列を同じ導出経路で保持。
  - `ios/DopaBreak/StatsView.swift`: `model.entitlementGate.statsDays`を参照し、Freeは今日の記録だけを表示。週次表示は鍵付きの「記録を全期間さかのぼれる」導線からPaywallへ遷移。Proに全期間の開かずに戻れた回数を追加。
  - `ios/DopaBreak/AppContainer.swift`: StatsServiceから全期間のcancelled件数をrefreshしてStatsViewへ公開。
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/StatsService.swift` / `Storage/SQLiteLogStore.swift`: 日付範囲を持たないcancelled専用COUNT APIを追加。
  - `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/StatsServiceTests.swift`: 全期間カウントが日付に依存せずcancelledだけを数える回帰テストを追加。
- 採用したデザイン方針:
  - FreeのStatsは今日の割合と今日の件数に限定し、週次ブロックは実データを露出せず鍵アイコンと「記録を全期間さかのぼれる」ラベルでPro導線にする。
  - Proの累計は回数だけを表示し、実測ソースのない時間換算・推定時間は表示しない。
  - Paywallの価格・無料期間は商品情報を正とし、商品未ロード時だけ既存の日本語フォールバックを維持する。
- 却下した案:
  - `annualDiscountPercent`のような通貨を表示しない比率計算の変更は不要なため対象外。
  - `EntitlementGate`自体を変更する案は、既存のFree=1日／Pro=無制限仕様をそのまま使うため不採用。
  - 「取り戻した時間」の累計や「開かずに我慢」など旧文言の追加は、設計ログ制約と現行コピーに反するため不採用。
- 新規・動的化した表示文言:
  - 「今日の記録」
  - 「記録を全期間さかのぼれる」
  - 「これまでに開かずに戻れた」＋回数
  - StoreKit導出の「{N}日間無料で始める」／「{N}日間の無料期間終了後」
- Claude Code側の実装制約:
  - StatsのFree/Pro判定は必ず`model.entitlementGate.statsDays`を使い、Gateの値をUI側で再定義しない。
  - 全期間値は`Decision.cancelled`のCOUNTのみを使う。「回数×推定分」等の時間推測表示を追加しない。
  - Paywallの未ロード時フォールバックは既存の「7日間」「月あたり4,980円」等を維持し、ロード済み商品では通貨ハードコードをしない。
- 検証:
  - `swift test --package-path ios/Packages/DopaBreakCore`: 159テスト成功、失敗0。
  - `cd ios && xcodebuild build -scheme DopaBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`: `BUILD SUCCEEDED`。

## 2026-07-20 — 監査C2 Day14クランプを課金モーメント化

- 作成・変更:
  - `ios/DopaBreak/OnboardingFlow.swift`: 対象アプリ選択に正本のFree初回14日枠説明を追加。
  - `ios/DopaBreak/LockSurfaceCoordinator.swift` / `AppContainer.swift`: Freeかつ対象2個以上だけにDay12通知を固定IDで一度だけ予約し、条件外では解除。実績あり/なしの本文は`docs/11_ui_copy.md` §15を転記。
  - `ios/DopaBreak/NotificationDelegate.swift` / `RootTabView.swift` / `PaywallView.swift`: 通知タップを24時間TTLのApp Group保留フラグへ渡し、`day14_warning` placementのPaywallを表示。
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/EntitlementGate.swift`: Day14通知対象判定と、試行最多・選択順タイブレークの純粋関数を追加。
  - `ios/DopaBreak/AppContainer.swift` / `SettingsView.swift` / `SettingsStore.swift`: 直近14日のAttemptLogからクランプ対象を決め、実発生時だけ正本の設定補足を表示。
  - `ios/DopaBreak/AppContainer.swift`: automationVerifiedを先に記録したまま、受信catalogIDをクランプ後のselectedCatalogIDsと照合し、対象外は介入を起動しない。
- 採用したデザイン方針:
  - 新規文言は創作せず、オンボは§4c、Day12通知とクランプ後補足は§15をそのまま使用。
  - 通知タップは既存の中間チェックインと同じApp Group保留フローを踏襲し、既存モーダル終了後にPaywallを表示する。
- 却下した案:
  - クランプ対象を従来どおり選択順の先頭に固定する案は、実利用に基づく継続対象選択にならないため不採用。
  - クランプ対象外のショートカットでも介入を起動し続ける案は、Free枠の実効性を失うため不採用。
- Claude Code側の実装制約:
  - 通知識別子は`dopabreak.day14warning`固定、繰り返しなし、毎回replaceする。Pro化・対象1個以下・14日経過後は必ず解除する。
  - クランプのログ取得失敗は従来のprefixフォールバック。同数・試行ゼロは現在の選択順先頭を残す。
  - ターゲット照合はautomationVerified記録より後ろへ移動しない。一時開放判定より前に行う。
- 検証:
  - Core 166テスト成功、失敗0。
  - iPhone 16 Pro Simulator向け`xcodebuild build`成功。

## 2026-07-20 — 監査バッチA/B/C採用8件の是正

- 作成・変更:
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/EntitlementGate.swift`: 対象アプリのクランプを現在の上限件数まで試行回数降順で選定し、同数は選択順を維持。
  - `ios/DopaBreak/AppContainer.swift` / `ios/DopaBreak/RootTabView.swift`: 介入要求を表示直前に現在選択中の対象アプリへ再照合。Day14保留通知もEntitlement・対象数・14日境界を再照合。
  - `ios/DopaBreak/LockSurfaceCoordinator.swift`: Day14関連通知の配信済み解除、週次通知の朝通知+30分化、Day14通知時刻の遅延再予約計算を追加。
  - `ios/DopaBreak/PaywallView.swift`: 年額/月額/Lifetimeの法務文言を`docs/11_ui_copy.md` §5へ同期し、未ロード時の年額月換算を415円へ修正。
  - `ios/DopaBreak/OnboardingFlow.swift` / `ios/DopaBreak/DopaBreakApp.swift` / `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SettingsStore.swift`: オンボ保存目標IDを永続化し、再開時は既存Goal更新として復元。完了・全データ削除で消去。
  - `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/EntitlementGateTests.swift` / `SettingsStoreTests.swift` / `ios/DopaBreakTests/MeasurementFoundationTests.swift`: クランプ、永続化、Day14境界の回帰テストを追加。既存のPaywallPlacement期待値も現行enumへ同期。
- 採用した方針:
  - UI表示前の対象照合をRootの表示状態へ分離し、無効な保留要求はfullScreenCoverへ渡さず破棄する。
  - Day14保留Paywallは権利解決済みのFreeかつ対象2件以上かつ初回起動から14日未満の場合だけ表示する。
  - 週次通知は朝通知時刻を基準に30分後へずらし、日跨ぎ時は翌曜日へ繰り上げる。
- 却下した案:
  - 指摘#4のfirstLaunchDate未設定ユーザーへの14日枠再付与は、未リリース前提とG1修正を尊重して変更しない。
  - 既存のクランプ後フォールバックや通知識別子・非強制の介入フローは変更しない。
- Claude Code側の実装制約:
  - `targetAppTokensLimit`を上限の正本とし、Proは無制限、上限内の選択順は保持する。
  - Day14通知は固定ID・繰り返しなしを維持し、候補時刻が過去の場合だけ`now+1時間`と境界12時間前から未来の早い方を使う。
  - Paywall法務文言は商品価格・トライアル日数の動的表示と併存させ、Apple ID請求行を省略しない。
  - オンボ再開時に保存目標が見つからない場合は暗黙の重複追加をせず、既存の保存エラー経路を使う。
- 検証:
  - `swift test --package-path ios/Packages/DopaBreakCore`: 171テスト成功、失敗0。
  - `cd ios && xcodebuild build -scheme DopaBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`: `BUILD SUCCEEDED`。
- 同Simulatorの`xcodebuild test`: 10テスト成功、失敗0。

## 2026-07-20 — 監査R1 アクティベーションの崖の可視化

- 作成・変更:
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/AutomationVerification.swift`: 選択済みIDと検証済みIDの差分を選択順で返す純粋関数を追加。
  - `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/AutomationVerificationTests.swift`: 対象0件・一部未検証・全件検証済みの3ケースを追加。
  - `ios/DopaBreak/HomeView.swift` / `ios/DopaBreak/RootTabView.swift`: 未検証対象がある間だけ、既存`CardContainer`構成の最上部にR1状態バナーを表示し、`AutomationGuideView`をHomeからsheet提示。
  - `ios/DopaBreak/OnboardingFlow.swift`: Ready画面にURLスキームを持つ先頭対象だけ「最初のテストをする」と正本説明を追加。完了ボタンは維持。
  - `ios/DopaBreak/LockSurfaceCoordinator.swift` / `ios/DopaBreak/AppContainer.swift`: `dopabreak.d1activation`を初回起動24時間後へ予約し、認可済みの場合だけ登録。検証成立時はpending/deliveredの両方を即時解除。
- 採用したデザイン方針:
  - `docs/11_ui_copy.md` §16の見出し・本文・CTAをそのまま転記し、新しい説明文は追加しない。
  - Homeバナーは写真や新しいカード種類を増やさず、既存の`CardContainer`・Dark Mono階層で設定状態だけを最上部に露出する。
  - Ready画面のテストは任意操作として既存の完了導線を置き換えず、選択順先頭のアプリを開く既存テスト起動相当へ接続する。
- 却下した案:
  - 検証状態を新しい永続モデルや手動の「設定済み」トグルで持つ案は、Intent実発火を検証点とする既存`SettingsStore`の正本を重複させるため不採用。
  - SafariのようにURLスキームを持たない対象へReadyテストCTAを出す案は、注記と手順を複雑化するため不採用。
- Claude Code側の実装制約:
  - 未検証判定はCoreの`AutomationVerification.unverifiedCatalogIDs`を使い、選択順を保持する。対象0件・全件検証済みではHomeバナーを描画しない。
  - ReadyのテストCTAは`selectedTargets.first`のURLスキームがある場合だけ表示する。先頭がSafariの場合、後続対象へ自動で繰り上げない。
  - D1通知は固定識別子・非反復・初回起動から`24 * 60 * 60`秒後。通知認可がなければ登録せず、検証が1件でも成立したらpending/deliveredを両方削除する。通知タップの特別ルーティングは追加しない。
- 検証:
  - `swift test --package-path ios/Packages/DopaBreakCore`: 174テスト成功、失敗0。
  - `cd ios && xcodebuild build -scheme DopaBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`: `BUILD SUCCEEDED`。

## 2026-07-20 — 監査C5＋C4後半：トライアル防衛線と週次ペイウォール

- 作成・変更:
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/RetentionNotificationPolicy.swift`: StoreKitに依存しない年額introductory trial判定、Day5/Month1/Month12の日付計算、週次ペイウォール間隔判定を純粋関数として追加。
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/StatsService.swift`: 指定期間のattempts/cancelled同時集計を追加。
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SettingsStore.swift`: `onboardingCompletedAt`と`lastWeeklyPaywallShownAt`を追加し、データリセット対象へ含めた。
  - `ios/DopaBreak/StoreService.swift`: 現在のverified entitlement Transactionから`offerType == .introductory`を読み、現行サブスク／年額トライアル情報を再スケジュールへ公開。entitlement更新revisionで、isProの真偽が変わらない更新もRootへ通知。
  - `ios/DopaBreak/AppContainer.swift` / `ios/DopaBreak/LockSurfaceCoordinator.swift`: Day5、Month1、Month12を固定ID・非反復で登録し、実績値を登録時に焼き込み。再スケジュール時はpending/deliveredを先に削除し、条件外では登録しない。
  - `ios/DopaBreak/RootTabView.swift` / `ios/DopaBreak/PaywallView.swift` / `ios/DopaBreak/DopaBreakApp.swift`: scenePhase activeのpending処理最下段へ週次placementを追加。オンボ未完了、オンボ後7日未満、介入・振り返り・チェックイン・他Paywall表示中は抑制し、表示時刻を保存。
  - `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/RetentionNotificationPolicyTests.swift` ほか: 判定、日付、週次間隔、設定永続化、集計のテストを追加。`ios/DopaBreakTests/MeasurementFoundationTests.swift`のplacement一覧を更新。
- 採用したデザイン方針:
  - 新規通知文言は創作せず、`docs/11_ui_copy.md` §17のDay5/Month1/Month12文言をそのまま転記。Paywallは既存`PaywallView`を`weekly` placementで再利用する。
  - 週次提示は既存のRootTabViewの保留提示優先順位へ接続し、オンボ直後の課金導線と近接しないようオンボ完了日時を正本として7日待つ。
  - Month1は`originalPurchaseDate`、Month12は現行年額Transactionの`purchaseDate`を基準にし、更新年にも更新前サマリーを再スケジュールできる形とした。
- 却下した案:
  - StoreKitのoffer情報がnilのときに商品IDや無料期間表示だけでDay5を推定する案は、誤発火を避ける要件に反するため不採用。
  - 週次PaywallをRootの既存pending処理より前へ割り込ませる案は、介入・振り返り・チェックインとの競合を作るため不採用。
  - 通知本文を起動時に動的解決する案は、固定通知の仕様とローカル通知制約に合わせて採用せず、再スケジュール時の最新値焼き込みとした。
- Claude Code側の実装制約:
  - 通知識別子は`dopabreak.trialday5`、`dopabreak.month1report`、`dopabreak.month12renewal`を固定し、毎回の再スケジュールでpending/deliveredを削除してから条件付き登録する。
  - Day5は現在entitlementの年額商品かつintroductory offerのみ。課金後・失効後・offer情報不明時は登録しない。StoreKit更新revisionを経由してisPro不変の状態変化も再評価する。
  - 週次Paywallの表示判定はCoreの`WeeklyPaywallPolicy`を使い、`lastWeeklyPaywallShownAt`は提示をキューへ入れる時点で記録する。placementは必ず`weekly`。
- 検証:
  - `swift test --package-path ios/Packages/DopaBreakCore`: 182テスト成功、失敗0。
  - `cd ios && xcodebuild build -scheme DopaBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`: `BUILD SUCCEEDED`。
  - `cd ios && xcodebuild test -scheme DopaBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`: 10テスト成功、失敗0。

## 2026-07-20 — 監査C4前半：オンボ閉鎖後のリバーストライアル

- 作成・変更:
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/ReverseTrialPolicy.swift`: `reverseTrialDays = 3`、有効期限、切り上げ残日数、期限切れ後の再提示条件をStoreKit/UI非依存の純粋関数として追加。
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SettingsStore.swift`: `reverseTrialStartedAt` と `reverseTrialEndPaywallShown` を追加し、開始日時の初回記録と全データ削除の対象へ接続。
  - `ios/DopaBreak/AppContainer.swift`: 実購入の`storeService.isPro`とリバーストライアル有効状態を`entitlementGate`生成時だけ合成。統計・対象アプリ上限・テーマ等の既存Gate利用箇所へ反映。
  - `ios/DopaBreak/PaywallView.swift` / `ios/DopaBreak/OnboardingFlow.swift`: `.onboardingPrepaywallSummary` の購入なし閉鎖だけを開始記録へ接続。購入成功・復元成功、設定/週次等の別placementは開始しない。`reverse_trial_end` placementを追加。
  - `ios/DopaBreak/HomeView.swift`: §18確定文言の体験中バナーを追加し、残日数は切り上げ表示。
  - `ios/DopaBreak/RootTabView.swift`: scenePhase active後の既存モーダル優先順位へ期限切れ再提示を追加し、Day14クランプ後に`reverse_trial_end`を1回だけ提示。既存のクランプ後補足を流用。
  - `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/ReverseTrialPolicyTests.swift` ほか / `ios/DopaBreakTests/MeasurementFoundationTests.swift`: 境界、永続化、リセット、Gate合成、placementのテストを追加。
- 採用した方針:
  - 新規表示文言は創作せず、Homeバナーと補足を`docs/11_ui_copy.md` §18からそのまま転記。
  - Paywallは既存Viewを再利用し、開始フックはオンボの`onboarding_prepaywall_summary`に限定。実購入のStoreKit entitlementを変更せず、Gateの生成箇所でだけ一時Proを合成。
  - 期限切れ時は`AppModel.refresh()`が既存の試行最多・現在上限件数のクランプを先に冪等実行する。Day14と同日に判定されても同じクランプ関数を使うため、選択順・試行数の既存タイブレークを変えない。
- 相互作用の確認:
  - Day14: 体験中はGateがProとなり対象アプリクランプ対象外。期限切れ後はFree Gateへ戻り、firstLaunchDate基準のDay14ロジックと既存クランプが再評価される。
  - Day12通知: 体験中は`day14WarningSchedule()`のFree条件から外れ、scenePhase active後の`refreshLockSurfaces()`で通知を解除。期限切れ後はFree条件を再評価して再スケジュールされる。
  - statsDays: `StatsView`が`model.entitlementGate.statsDays`を参照するため、体験中は全期間、終了後は今日のみへ戻る。
  - モーダル競合: 介入・振り返り・途中チェックイン・Day14・週次Paywallの既存保留条件を満たさない間は`reverse_trial_end`をキューせず、同じ優先順位の再チェックへ持ち越す。
- Claude Code側の制約:
  - `reverseTrialStartedAt`は既存値を上書きしない。実購入成功時は開始日時を記録しない。全データ削除では開始日時と再提示フラグの両方を消去する。
  - Home文言は`docs/11_ui_copy.md` §18と一致させ、残日数は開始直後3日、期限直前1日、期限ちょうどは非表示とする。
  - 実購入判定は常に`StoreService.isPro`、機能開放判定は`AppModel.entitlementGate`を使い、両者を同一状態として永続化しない。
- 検証:
  - `swift test --package-path ios/Packages/DopaBreakCore`: 190テスト成功、失敗0。
  - `cd ios && xcodebuild build -scheme DopaBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`: `BUILD SUCCEEDED`。
  - 同Simulatorの`xcodebuild test`: 11テスト成功、失敗0。

## 2026-07-20 — バッチD/E/F独立レビュー7件の是正

- 作成・変更:
  - `ios/DopaBreak/RootTabView.swift` / `ios/DopaBreak/AppContainer.swift`: 子画面モーダル状態を`AppModel.isChildModalActive`で共有し、週次・Day14・リバーストライアル終了のルートPaywallを子画面表示中は保留。途中チェックイン終了後は振り返りを再評価。
  - `ios/DopaBreak/PaywallView.swift`: Paywallの実表示`onAppear`を記録の単一地点とし、`lastAnyPaywallShownAt`、週次表示時刻、リバーストライアル終了表示済みフラグをここで更新。
  - `ios/DopaBreak/HomeView.swift` / `ios/DopaBreak/StatsView.swift` / `ios/DopaBreak/GoalsView.swift` / `ios/DopaBreak/SettingsView.swift`: 各タブが自分のsheet/fullScreenCover/Picker/confirmationDialogの表示状態をAppModelへ反映。
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Storage/SettingsStore.swift`: 全Paywall共通の`lastAnyPaywallShownAt`を追加し、リセット対象へ含めた。
  - `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/RetentionNotificationPolicy.swift` / `ios/DopaBreak/StoreService.swift` / `ios/DopaBreak/AppContainer.swift`: 週次Paywallの24時間クールダウンと、StoreKit 2 `RenewalInfo.willAutoRenew`がtrueのときだけDay5/Month12を登録する判定を追加。Month1は変更なし。
  - `ios/DopaBreak/LockSurfaceCoordinator.swift`: 通知再スケジュールを直列化し、個別解除はD1識別子だけをpending/deliveredから削除。世代競合時も無効化対象以外を巻き込まない。
  - `ios/DopaBreak/OnboardingFlow.swift`: 通知許可直後に再スケジュールを完了待ちし、オンボ完了前でもD1を登録。
  - `ios/Packages/DopaBreakCore/Tests/DopaBreakCoreTests/RetentionNotificationPolicyTests.swift` / `SettingsStoreTests.swift`: 週次24時間クールダウン、willAutoRenew true/false/nil分岐、設定保存を追加検証。
- 採用したデザイン方針:
  - ルート提示の判定は従来の優先順位を維持し、子画面が閉じたタイミングで同じ判定を再実行する。Paywall表示時刻はキュー投入時ではなく実表示時に確定する。
  - Paywallの表示記録は各呼び出し元へ分散させず、`PaywallView.onAppear`へ集約する。表示競合で消えた場合はフラグを消費せず、次回activeで自然に再試行する。
  - Day5/Month12は自動更新状態が取得できない場合も登録しない。解約済みユーザーへ更新前提の文言を出さず、既存登録は再スケジュール時の固定ID削除で解除する。
- 却下した案:
  - ルートの提示判定時に表示済みフラグを保存する案は、別モーダルに負けた未表示Paywallを消費してしまうため不採用。
  - 個別通知解除で共通通知ID一覧を削除する案は、世代競合時に他の通知を巻き込むため不採用。
  - RenewalInfo不明時に商品IDやofferTypeから更新を推定する案は、誤発火を避ける要件に反するため不採用。
- Claude Code側の実装制約:
  - 新しいPaywall提示経路は必ず`PaywallView`を使い、実表示記録を別の提示元へ追加しない。週次判定には`lastAnyPaywallShownAt`を渡す。
  - `LockSurfaceCoordinator.cancelD1ActivationNotification()`は`dopabreak.d1activation`だけを対象にする。全件削除は全データ削除など明示的な全体操作だけで使う。
  - Day5/Month12の登録条件は`RetentionNotificationPolicy.shouldScheduleRenewalNotification(willAutoRenew:)`を通す。Month1の登録条件へ同じガードを追加しない。
- 検証:
  - `swift test --package-path ios/Packages/DopaBreakCore`: 192テスト成功、失敗0。
  - `cd ios && xcodebuild build -scheme DopaBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`: `BUILD SUCCEEDED`。

## 2026-07-24 — メインアプリのString Catalog基盤（ja / ko / en）

- 作成・変更:
  - `ios/DopaBreak/Localizable.xcstrings`: 開発言語を`ja`とし、`en` / `ko`を全237キーに空値・`new`状態で登録。日本語は`translated`状態で、既存Swiftの表示文言をそのまま格納。
  - `ios/project.yml` / 生成物`ios/DopaBreak/Info.plist`: `developmentLanguage: ja`、`useBaseInternationalization: false`、`CFBundleLocalizations`の`ja` / `ko` / `en`を追加。カタログはDopaBreakターゲットのResourcesへ登録される。
  - `ios/DopaBreak/PaywallView.swift` / `OnboardingFlow.swift` / `HomeView.swift` / `SettingsView.swift`: 起動重要4画面のユーザー向け文字列を、画面・要素を表す安定キー付き`String(localized:defaultValue:)`へ移行。
  - `.claude/specs/i18n-launch-inventory.md`: 作成した237キーの`key | ja source string | screen`完全表と、メインアプリに残る未移行ユーザー向けリテラル222箇所のファイル別台帳を追加。
- 採用した方針:
  - `docs/11_ui_copy.md`と現行Swiftの日本語を正本とし、句読点・空白・改行を変更しない機械抽出に限定。
  - キーは`paywall.*`、`onboarding.*`、`home.*`、`settings.*`の`screen.element`形式とし、同一意味・同一表示の再利用だけ同じキーを使う。
  - Swift補間はString Catalogの型付き書式（`%lld` / `%@` / `%lf`）として保持し、翻訳表でもプレースホルダー位置を監査できるようにした。
  - 永続化・判定に使う日本語raw value（利用時間帯、頻度選択肢など）は変更せず、表示時だけローカライズ値へ変換して既存データ互換性を維持。
- 却下した案:
  - `en` / `ko`を機械翻訳または日本語で仮埋めする案は、レビュー済み翻訳表を後から投入する要件に反するため不採用。
  - 日本語本文そのものをキーにする案は、コピー変更で翻訳マッピングが壊れるため不採用。
  - `SWIFT_EMIT_LOC_STRINGS`でアプリ全体を自動抽出する案は、今回対象外の画面や数値だけのリテラルまで不安定な原文キーで混入するため不採用。
  - Widget / Shield各拡張の文字列移行は今回のメインターゲット限定スコープ外とし、後続バッチへ延期。
- Claude Code側の実装制約:
  - 翻訳投入時は既存キーと`ja`値を変更せず、`en` / `ko`の空`new` string unitだけをレビュー済み値へ更新する。
  - 改行を含む値と`%lld` / `%@` / `%lf`プレースホルダーの個数・順序を各言語で維持する。
  - 今後のメインアプリ移行は`.claude/specs/i18n-launch-inventory.md`の残件台帳を起点にし、analytics key、product ID、URL scheme、識別子、ログ文言はローカライズ対象にしない。
  - Widget / Shield拡張には今回のカタログを暗黙共有させず、各ターゲットのリソース構成を決める後続バッチで扱う。
- 検証:
  - `cd ios && xcodegen generate && xcodebuild -project DopaBreak.xcodeproj -scheme DopaBreak -destination 'generic/platform=iOS Simulator' -derivedDataPath .deriveddata CODE_SIGNING_ALLOWED=NO build`: `BUILD SUCCEEDED`。
  - `swift test --package-path ios/Packages/DopaBreakCore`: 192テスト成功、失敗0。
  - カタログ整合性: 237 catalog keys = 237 source references = 237 compiler-emitted defaults、差分0。全`en` / `ko`値が空かつ`new`状態であることを確認。

## 2026-07-24 — i18n batch 2（残存メイン画面 + Widget / Shield）

- 作成・変更:
  - `ios/DopaBreak/AppContainer.swift`、`AutomationGuideView.swift`、`GoalEditorSheet.swift`、`GoalsView.swift`、`InterventionFlowModel.swift`、`InterventionFlowView.swift`、`InterventionModeDisplay.swift`、`LockSurfaceCoordinator.swift`、`MidSessionCheckInSheet.swift`、`PostUseReflectionSheet.swift`、`RootTabView.swift`、`StartInterventionIntent.swift`、`StatsView.swift`、`StoreService.swift`、`TargetAppPickerSheet.swift`: 残存台帳222箇所を203個の安定キーへ移行。
  - `ios/DopaBreak/Localizable.xcstrings`: 上記203キーを追加し、合計440キーへ更新。`ja`は現行表示を保持し、`ko` / `en`は空値・`new`状態のまま登録。
  - `ios/WidgetsExtension/DopaBreakWidgets.swift` / `Localizable.xcstrings`: WidgetとLive Activityの20箇所を13キーへ移行し、拡張専用カタログを追加。
  - `ios/ShieldConfigExtension/ShieldConfigurationExtension.swift` / `Localizable.xcstrings`: Shield表示4箇所を4キーへ移行し、拡張専用カタログを追加。
  - `ios/project.yml` / 生成物`ios/WidgetsExtension/Info.plist` / `ios/ShieldConfigExtension/Info.plist`: 両拡張へ`ja` / `ko` / `en`を登録。
- 採用した方針:
  - 日本語の文言、句読点、空白、改行を変更せず、同一画面・同一意味の重複表示だけ同一キーへ集約。
  - 数値や動的文字列もローカライズ対象にし、Swift補間を`%lld` / `%@` / `%%`へ対応させた。App Intentは型要件に合わせて安定キー付き`LocalizedStringResource`を使用。
  - 拡張は本体Bundleへ依存させず、実際に表示文字列を持つWidgetとShield Configurationだけに専用String Catalogを置いた。
- 却下・対象外:
  - Shield ActionとMonitor拡張はユーザー向け文字列がないため、空のカタログやローカライズ設定を追加しない。
  - analytics key、product ID、URL scheme、SF Symbol名、永続化キー、通知識別子、ログ専用文字列は移行しない。
- Claude Code側の実装制約:
  - 翻訳投入時は3つのカタログをターゲットBundle単位で更新し、既存`ja`値とキーを変更しない。
  - `ko` / `en`へ値を入れる際は、`%lld` / `%@` / `%%`の個数と型を各キーの`ja`値と一致させる。
  - 新しいWidgetまたはShield表示文言はメインアプリのカタログへ追加せず、各拡張の`Localizable.xcstrings`へ追加する。
- 検証:
  - `cd ios && xcodegen generate && xcodebuild -project DopaBreak.xcodeproj -scheme DopaBreak -destination 'generic/platform=iOS Simulator' -derivedDataPath .deriveddata CODE_SIGNING_ALLOWED=NO build`: `BUILD SUCCEEDED`。
  - `swift test --package-path ios/Packages/DopaBreakCore`: 192テスト成功、失敗0。
  - 整合性: メイン203キー / 222参照、Widget 13キー / 20参照、Shield 4キー / 4参照。全キー参照・全カタログ収録・`ko` / `en`空`new`を確認。

## 2026-07-24 — コミット前レビュー実バグ6件の最小是正

- 作成・変更:
  - `ios/DopaBreak/InterventionFlowModel.swift`: `startGeneration`で再startを世代管理し、旧呼吸タスクの取消・呼吸完了時の取消/世代/stageガード・通知権限結果の世代ガードを追加。時間終了/中間チェックイン通知は権限取得完了を待たず常にnotification centerへ登録する。
  - `ios/DopaBreak/RootTabView.swift`: Day14通知タップの保留フラグをentitlement未解決時は保持し、解決済みかつ対象外の場合だけ削除する。
  - `ios/DopaBreak/LockSurfaceCoordinator.swift`: 通常再予約ではpendingだけを置換し、delivered削除を廃止。Day14フォールバックを境界未満へ限定。D1取消から全体通知世代の更新を外し、処理中のD1再追加だけを識別子単位で防止する。
  - `ios/DopaBreakTests/MeasurementFoundationTests.swift`: 呼吸中の再start後に旧タスクがstageを上書きしない回帰テストと、Day14境界30分前にフォールバックしない境界テストを追加。
- 採用した方針:
  - 既存の状態遷移ガードと通知構成を維持し、レビュー6件に必要な競合ガードと条件変更だけを追加する。画面構成・コピー・表示デザインは変更しない。
  - 通知権限は表示文言の分岐だけに使い、予約可否は`UNUserNotificationCenter.add`へ委ねる。権限状態の3値化は不要な状態追加になるため採用しない。
  - delivered通知の削除は全データ削除とD1検証成立などの明示操作だけに残す。通常refresh/rescheduleでは通知センター上の配信済み導線を保持する。
- 却下した案:
  - D1取消時に全体世代を更新して再予約を起動し直す案は、全pending削除後の取りこぼしを再発させ得るため不採用。D1固定識別子だけを無効化し、追加中の競合も追加直後に再確認する。
  - Day14境界直前でも`now + 1時間`を登録する案は、対象外になった後の通知を生むため不採用。境界まで候補がなければ予約しない。
- Claude Code側の実装制約:
  - `InterventionFlowModel.start()`と呼吸完了の世代/stageガードを外さない。通知権限取得結果も同じ世代でのみ表示状態へ反映する。
  - `LockSurfaceCoordinator.performNotificationReschedule()`へdelivered一括削除を戻さない。`cancelD1ActivationNotification()`で`notificationGeneration`を更新しない。
  - Core層は純Foundationを維持し、StoreKit / FamilyControls / UIKitをimportしない。
- 検証:
  - 追加したアプリ層2テストは修正前に2件失敗、修正後に2件成功、失敗0。
  - iPhone 16 Pro Simulatorの`DopaBreakTests`: 追加2件を含む13テスト成功、失敗0。
  - `swift test --package-path ios/Packages/DopaBreakCore`: 192テスト成功、失敗0。
  - `cd ios && xcodegen generate`後のgeneric iOS Simulator向け`xcodebuild`: `BUILD SUCCEEDED`。
