# DopaBreak i18n launch inventory

Generated: 2026-07-24

Updated: 2026-07-25 (added the lock-screen check screen: 23 keys)

Updated: 2026-08-08 (goal-input redesign: removed 4 `onboarding.goal.lock_screen_*` keys, 2 `goal_editor.lock_title.*` keys, and orphaned `onboarding.goal.category` (dead-code cleanup); added `onboarding.goal.add` / `onboarding.goal.helper` / `onboarding.goal.remove` / `onboarding.goal.character_count` with ja/en/ko shipped in-catalog)

Updated: 2026-08-15 (onboarding goal-input redesign: retired `onboarding.goal.placeholder` and the 3 `onboarding.goal.preset.*` keys; added `onboarding.goal.lead` / `onboarding.goal.multi_note` / 3 rotating `onboarding.goal.placeholder.*` keys / `onboarding.goal.field.accessibility` with ja/en/ko shipped in-catalog)

Updated: 2026-08-15 (home fact-copy redesign: updated the 6 `home.first_day.*` / `home.achievement.*` / `home.week.summary` Japanese values to the live catalog and retired `home.metric.count` / `home.metric.cancelled` / `home.metric.attempted`)

Updated: 2026-08-15 (welcome CTA transcreation: `onboarding.welcome.tagline` ja + `onboarding.welcome.action` ja/en/ko rewritten and new `onboarding.welcome.action_note` added in 3 languages; native review + humanizer-en/ko audits exit 0)

Updated: 2026-09-04 (paywall headline v2: `paywall.header.line1.prefix` / `.suffix` rewritten to the lifetime-years unit and new `paywall.header.estimate_note` added in ja/en/ko; the stale `paywall.header.body` row was corrected to the live catalog value; en line 1 is `“5 more min” = {Y} years gone` — the first draft ` years of life` was shortened to keep the headline on one line)


Scope: main app target (`ios/DopaBreak/*.swift`) plus the user-facing strings in `WidgetsExtension` and `ShieldConfigExtension`.

Completion status:

- Main app: 222 source locations migrated to 203 stable keys; remaining user-facing hardcoded strings from this inventory: **0**
- WidgetsExtension: 20 source locations migrated to 13 stable keys; remaining user-facing hardcoded strings: **0**
- ShieldConfigExtension: 4 source locations migrated to 4 stable keys; remaining user-facing hardcoded strings: **0**
- Catalog totals (live JSON count on 2026-08-15): main app 553 keys, WidgetsExtension 12 keys, ShieldConfigExtension 4 keys
- `ja` preserves the exact source text. At batch 2 completion, `ko` / `en` were empty with `new` state; any later transcreation updates are tracked separately from this plumbing inventory.

The source strings below are the exact Japanese values stored in `Localizable.xcstrings`. Swift interpolations appear in their String Catalog format-specifier form (for example `%lld`, `%@`, `%lf`). Literal line breaks are rendered as `\n` so their placement remains auditable.

## Created keys

| key | ja source string | screen |
|---|---|---|
| home.achievement.count_unit | 回 | Home |
| home.achievement.empty_body | 今日はまだ開こうとしていません | Home |
| home.achievement.summary | 開こうとしたのは%lld回 | Home |
| home.achievement.title | 今日 開かなかった | Home |
| home.automation_status.action | 設定を確認 | Home |
| home.automation_status.body | 対象アプリを開いたときに一呼吸が出れば設定完了です。 | Home |
| home.automation_status.title_multiple | %lld個のアプリで一呼吸がまだ動いていません | Home |
| home.automation_status.title_single | %@の一呼吸はまだ動いていません | Home |
| home.first_day.body | 開かなかった回数がここに残ります | Home |
| home.first_day.title | 開こうとした瞬間に一呼吸が入ります | Home |
| home.goal.fallback | タップして目標を追加 | Home |
| home.goal.label | あなたの目標 | Home |
| home.hero.today | TODAY ・ %@ | Home |
| home.hero.week_count | %lld回 / 今週 | Home |
| home.week.eyebrow | THIS WEEK | Home |
| home.week.summary | 今週 開かなかったのは%lld回 | Home |
| lock_check.action.done | 完了 | Lock Screen Check |
| lock_check.action.later | あとで | Lock Screen Check |
| lock_check.action.retry | もう一度出す | Lock Screen Check |
| lock_check.action.settings | 設定を開く | Lock Screen Check |
| lock_check.eyebrow | LOCK SCREEN | Lock Screen Check |
| lock_check.lead.blocked | 端末の設定でライブアクティビティをオンにすると出せます。 | Lock Screen Check |
| lock_check.lead.confirmed | 開こうとするたび この言葉が先に目に入ります。 | Lock Screen Check |
| lock_check.lead.failed | もう一度出すと表示できることがあります。 | Lock Screen Check |
| lock_check.lead.no_goal | 目標を決めると ロック画面に出せます。 | Lock Screen Check |
| lock_check.permission_note | はじめて出るときは「許可しますか」と聞かれます。「許可」を選ぶとロック画面に残ります。 | Lock Screen Check |
| lock_check.preview.attempted | 開こうとした %lld回 | Lock Screen Check |
| lock_check.preview.cancelled | 今日 開かなかった %lld回 | Lock Screen Check |
| lock_check.preview.eyebrow | あなたの目標 | Lock Screen Check |
| lock_check.preview.goal_fallback | あなたの目標 | Lock Screen Check |
| lock_check.settings_path.label | 設定の場所 | Lock Screen Check |
| lock_check.settings_path.value | 設定 > DopaBreak > ライブアクティビティ | Lock Screen Check |
| lock_check.side_button.label | サイドボタンを押して確かめる | Lock Screen Check |
| lock_check.status.visible | ロック画面に表示中 | Lock Screen Check |
| lock_check.title.blocked | ロック画面の表示がオフ | Lock Screen Check |
| lock_check.title.failed | いま出せませんでした | Lock Screen Check |
| lock_check.title.no_goal | まず目標をひとつ | Lock Screen Check |
| lock_check.title.ready | ロック画面に出しました | Lock Screen Check |
| onboarding.action.close | 閉じる | Onboarding |
| onboarding.action.continue | 続ける | Onboarding |
| onboarding.action.later | あとで | Onboarding |
| onboarding.action.next | 次へ | Onboarding |
| onboarding.aimless.eyebrow | 質問 2 / 3 | Onboarding |
| onboarding.aimless.lead | この2週間、次のことはどれくらい当てはまりますか？ | Onboarding |
| onboarding.aimless.title | 気づけば目的もなく\nスクロールしている | Onboarding |
| onboarding.apps.action.empty | アプリを選ぶ | Onboarding |
| onboarding.apps.action.selected | この%lldつで始める | Onboarding |
| onboarding.apps.empty_selection_message | まずは1つだけ選びましょう。\n\n一番無意識に開いてしまうSNSから始めるのがおすすめです。 | Onboarding |
| onboarding.apps.free_limit_note | 無料プランでは1つまで | Onboarding |
| onboarding.apps.lead | いつでも変更できます。 | Onboarding |
| onboarding.apps.title | 止めたいアプリを選ぶ | Onboarding |
| onboarding.automation.action | ショートカットを開く | Onboarding |
| onboarding.automation.action_note | 設定できたかどうかは 対象アプリを開いたときに自動で確認されます | Onboarding |
| onboarding.automation.apps_empty | 先に止めるアプリを選んでください。 | Onboarding |
| onboarding.automation.apps_label | 設定するアプリ | Onboarding |
| onboarding.automation.lead | ショートカットのオートメーションで、選んだアプリを開いたときにDopaBreakを起動します。設定は一度だけ・約2分です。 | Onboarding |
| onboarding.automation.step1 | 1. オートメーションを開く | Onboarding |
| onboarding.automation.step2 | 2. ＋を押してAppを選ぶ | Onboarding |
| onboarding.automation.step3 | 3. 対象アプリを選び開かれたときを選ぶ | Onboarding |
| onboarding.automation.step4 | 4. すぐに実行を選ぶ | Onboarding |
| onboarding.automation.step5 | 5. アクションでDopaBreakで一呼吸を選ぶ | Onboarding |
| onboarding.automation.title | 自動で一呼吸を出す設定 | Onboarding |
| onboarding.error.save.message | データを保存できませんでした | Onboarding |
| onboarding.error.save.title | 保存できませんでした | Onboarding |
| onboarding.frequency.option.almost_daily | ほとんど毎日 | Onboarding |
| onboarding.frequency.option.more_than_half | 半分以上 | Onboarding |
| onboarding.frequency.option.never | 全くない | Onboarding |
| onboarding.frequency.option.some_days | 数日 | Onboarding |
| onboarding.goal.action.later | あとで設定する | Onboarding |
| onboarding.goal.add | 追加 | Onboarding |
| onboarding.goal.character_count | %lld/%lld | Onboarding |
| onboarding.goal.eyebrow | あなたの目標 / GOAL | Onboarding |
| onboarding.goal.field.accessibility | 目標を入力 | Onboarding |
| onboarding.goal.helper | そのままロック画面に表示されます | Onboarding |
| onboarding.goal.lead | なりたい姿でも やることでもいい | Onboarding |
| onboarding.goal.multi_note | 目標は複数追加できます。無料プランでは1つまで | Onboarding |
| onboarding.goal.placeholder.action | 例: 資格の勉強を進める | Onboarding |
| onboarding.goal.placeholder.aspiration | 例: 英語で話せるようになる | Onboarding |
| onboarding.goal.placeholder.habit | 例: 寝る前に本を読む | Onboarding |
| onboarding.goal.remove | %@を削除 | Onboarding |
| onboarding.goal.title | 取り戻した時間で\n何をしたいですか？ | Onboarding |
| onboarding.mode.action | この設定で進む | Onboarding |
| onboarding.mode.deep_focus.confirmation.message | 集中時間中は、簡単にはSNSを開けません。 | Onboarding |
| onboarding.mode.deep_focus.confirmation.standard | 通常モードにする | Onboarding |
| onboarding.mode.deep_focus.confirmation.start | Deep Focusで始める | Onboarding |
| onboarding.mode.deep_focus.confirmation.title | Deep Focusは強めの設定です | Onboarding |
| onboarding.mode.lead | 生活に合う強さを選べます。 | Onboarding |
| onboarding.mode.title | どのくらい強く\n止めますか？ | Onboarding |
| onboarding.notification.action | 通知をオンにする | Onboarding |
| onboarding.notification.eyebrow | NOTIFICATION | Onboarding |
| onboarding.notification.fallback | 通知はあとで設定できます。 | Onboarding |
| onboarding.notification.lead | ライブアクティビティで目標を毎日ロック画面に表示します 記録と振り返りの通知もここでオンにできます | Onboarding |
| onboarding.notification.preview.app_name | DOPABREAK | Onboarding |
| onboarding.notification.preview.cancelled | 開かずに戻れた | Onboarding |
| onboarding.notification.preview.count | %lld回 | Onboarding |
| onboarding.notification.preview.goal_fallback | 目標を設定すると、ここに表示されます | Onboarding |
| onboarding.notification.preview.now | 今 | Onboarding |
| onboarding.notification.preview.today | 今日 | Onboarding |
| onboarding.notification.title | ロック画面に、\n戻る先を | Onboarding |
| onboarding.preview.action | なるほど、続ける | Onboarding |
| onboarding.preview.card.cancel | 開かない | Onboarding |
| onboarding.preview.card.continue | 理由を選んで続ける | Onboarding |
| onboarding.preview.card.title | 何のために開く？ | Onboarding |
| onboarding.preview.eyebrow | PREVIEW | Onboarding |
| onboarding.preview.lead | 目的を確かめて、必要なときだけ意図して開けるようにします。 | Onboarding |
| onboarding.preview.step1 | 1. 何のために開くか確認する | Onboarding |
| onboarding.preview.step2 | 2. 仕事や連絡なら、すぐ時間を選ぶ | Onboarding |
| onboarding.preview.step3 | 3. 暇つぶしなら、一呼吸して選び直す | Onboarding |
| onboarding.preview.step4 | 4. 使った後の満足感を振り返る | Onboarding |
| onboarding.preview.title | SNSを開こうとすると、\nこうなります | Onboarding |
| onboarding.ready.action | DopaBreakをはじめる | Onboarding |
| onboarding.ready.body | 今日から、開く前に選び直す。 | Onboarding |
| onboarding.ready.goal_label | あなたの目標 | Onboarding |
| onboarding.ready.test_action | 最初のテストをする | Onboarding |
| onboarding.ready.test_body | %@を開いて一呼吸が出れば成功です。 | Onboarding |
| onboarding.ready.title | 準備完了 | Onboarding |
| onboarding.regret.eyebrow | 質問 3 / 3 | Onboarding |
| onboarding.regret.lead | SNSを閉じたあとの気持ちは | Onboarding |
| onboarding.regret.title | 「時間を溶かした」と\n感じることがある | Onboarding |
| onboarding.result.action | この時間を変える | Onboarding |
| onboarding.result.daily_body | が毎日SNSに溶けています | Onboarding |
| onboarding.result.disclaimer | ※ご回答からの推計値です。医療診断ではありません。 | Onboarding |
| onboarding.result.duration.decimal_hours | %lf時間 | Onboarding |
| onboarding.result.duration.hours | %lld時間 | Onboarding |
| onboarding.result.duration.minutes | %lld分 | Onboarding |
| onboarding.result.eyebrow | 推計結果 / YOUR RESULT | Onboarding |
| onboarding.result.lead | あなたの回答にもとづく推計では | Onboarding |
| onboarding.result.lifetime | このままなら50年で 人生の約%@年 | Onboarding |
| onboarding.result.per_day | / 日 | Onboarding |
| onboarding.result.yearly.prefix | 1年に換算すると 約 | Onboarding |
| onboarding.result.yearly.suffix | 日 | Onboarding |
| onboarding.science.disclaimer.effect | ※本アプリの効果を保証するものではありません。 | Onboarding |
| onboarding.science.disclaimer.medical | ※医療・治療を目的としたアプリではありません。 | Onboarding |
| onboarding.science.disclaimer.study | ※他社アプリ(one sec)を対象とした研究です。 | Onboarding |
| onboarding.science.eyebrow | WHY IT WORKS / 科学的背景 | Onboarding |
| onboarding.science.lead | つい開いてしまうのは、あなたが弱いからではありません。SNSは無意識の起動を狙って設計されています。 | Onboarding |
| onboarding.science.principle1.detail | 反射的な起動に一拍置く | Onboarding |
| onboarding.science.principle1.title | 1. 摩擦 | Onboarding |
| onboarding.science.principle2.detail | 開く前に理由を言語化する | Onboarding |
| onboarding.science.principle2.title | 2. 実行意図 | Onboarding |
| onboarding.science.principle3.detail | 今日何回目かを見る | Onboarding |
| onboarding.science.principle3.title | 3. 自己モニタリング | Onboarding |
| onboarding.science.principle4.detail | 見た後の満足感を記録する | Onboarding |
| onboarding.science.principle4.title | 4. 自己観察 | Onboarding |
| onboarding.science.research | one secを使った査読付き研究（PNAS, 2023）では、6週間継続した参加者が対象アプリを実際に開いた回数が平均57%減少しました。 | Onboarding |
| onboarding.science.title | 意志の力では、\n勝てない | Onboarding |
| onboarding.self_check.eyebrow | 質問 1 / 3 | Onboarding |
| onboarding.self_check.hint | ざっくりでOKです | Onboarding |
| onboarding.self_check.option.four_to_six_hours | 4〜6時間 | Onboarding |
| onboarding.self_check.option.less_than_hour | 1時間未満 | Onboarding |
| onboarding.self_check.option.one_to_two_hours | 1〜2時間 | Onboarding |
| onboarding.self_check.option.six_plus_hours | 6時間以上 | Onboarding |
| onboarding.self_check.option.two_to_four_hours | 2〜4時間 | Onboarding |
| onboarding.self_check.privacy_note | 回答は端末内にのみ保存されます。 | Onboarding |
| onboarding.self_check.title | SNSを見ている時間は\n1日どれくらいですか？ | Onboarding |
| onboarding.summary.additional_apps | %@ ほか%lld件 | Onboarding |
| onboarding.summary.apps | 止めるアプリ | Onboarding |
| onboarding.summary.eyebrow | あなた専用プラン / READY | Onboarding |
| onboarding.summary.footer | 開く前に選べる状態を、今日から始めます。 | Onboarding |
| onboarding.summary.goal | 戻る先 | Onboarding |
| onboarding.summary.lead | この設定で、開く前の一呼吸が増えます。 | Onboarding |
| onboarding.summary.time | 対象の時間 | Onboarding |
| onboarding.summary.title | 準備が整いました | Onboarding |
| onboarding.summary.yearly_days | 年 約%lld日分 | Onboarding |
| onboarding.value.not_set | 未設定 | Onboarding |
| onboarding.welcome.action | どれだけ溶けているか見る | Onboarding |
| onboarding.welcome.action_note | 質問3つ・30秒 | Onboarding |
| onboarding.welcome.eyebrow | DOPABREAK | Onboarding |
| onboarding.welcome.lead | なんとなく開くだけで1日が終わる | Onboarding |
| onboarding.welcome.ledger.accessibility_label | 今日の24時間のうち、現在時刻までの経過を示しています | Onboarding |
| onboarding.welcome.ledger.body | 今日という時間は、いまも減り続けている。 | Onboarding |
| onboarding.welcome.ledger.elapsed_time | 過ぎた時間 | Onboarding |
| onboarding.welcome.ledger.eyebrow | TODAY / 1,440 MINUTES | Onboarding |
| onboarding.welcome.tagline | 開く前に選び直す | Onboarding |
| onboarding.welcome.title | 人生の時間は\n二度と戻らない | Onboarding |
| paywall.action.close | 閉じる | Paywall |
| paywall.action.later | あとで | Paywall |
| paywall.action.restore | 購入を復元 | Paywall |
| paywall.action.start_free | %@無料で始める | Paywall |
| paywall.action.start_plan | %@プランを始める | Paywall |
| paywall.alert.error.title | エラー | Paywall |
| paywall.brand.pro | DOPABREAK PRO | Paywall |
| paywall.error.product_load | 商品情報を読み込めませんでした | Paywall |
| paywall.feature.deep_focus | 選んだアプリを完全にブロック | Paywall |
| paywall.feature.lock_theme | ロック画面のデザインを選べる | Paywall |
| paywall.feature.night_block | 就寝中は自動で完全ブロック | Paywall |
| paywall.feature.unlimited_apps | 対応アプリの登録数制限を解除 | Paywall |
| paywall.feature.strict_block | 解除に30秒待つ強いブロック | Paywall |
| paywall.feature.weekly_schedule | 毎週のブロック予定を2つ設定 | Paywall |
| paywall.header.body | ずっと我慢するためのアプリではありません。SNSを開く前に一呼吸はさみ、開かずにすんだ回数をホームに残します。 | Paywall |
| paywall.header.estimate_note | 1日約%@が50年続いた場合の推計 | Paywall |
| paywall.header.line1.prefix | 「あと5分」が人生の | Paywall |
| paywall.header.line1.suffix | 年 | Paywall |
| paywall.header.line2 | 開く前にブレーキ | Paywall |
| paywall.legal.annual_intro | %@の無料期間終了後、年額%@で自動更新。いつでも解約できます。購入はApple IDに請求されます | Paywall |
| paywall.legal.auto_renew | 解約しない場合、期間終了時に自動更新されます\n購入はApple IDに請求されます | Paywall |
| paywall.legal.privacy | プライバシー | Paywall |
| paywall.legal.terms | 利用規約 | Paywall |
| paywall.plan.annual.charge | 年間%@を一括請求 | Paywall |
| paywall.plan.annual.intro_duration_fallback | 7日間 | Paywall |
| paywall.plan.annual.intro_fallback | 7日間無料 | Paywall |
| paywall.plan.annual.monthly_equivalent | %@/月 | Paywall |
| paywall.plan.annual.savings_badge | 一番人気・%lld%%お得 | Paywall |
| paywall.plan.annual.title | 年額 | Paywall |
| paywall.plan.monthly.price | %@/月 | Paywall |
| paywall.plan.monthly.title | 月額 | Paywall |
| paywall.value.unavailable | — | Paywall |
| settings.account.lifetime_plan | 買い切りプラン | Settings |
| settings.account.pro_status | Pro状態 | Settings |
| settings.account.restore | 購入を復元 | Settings |
| settings.account.section | アカウント/課金 | Settings |
| settings.app.version | バージョン | Settings |
| settings.authorization.allow | 許可する | Settings |
| settings.authorization.body | 選んだSNSを開こうとした瞬間に確認画面を出すために、iOSのスクリーンタイムを使います。使用データは端末内に保存されます。 | Settings |
| settings.authorization.denied_body | 許可がないため、SNSを開く前の確認はまだ使えません。設定からいつでも有効にできます。 | Settings |
| settings.authorization.title | SNSの前で止める許可 | Settings |
| settings.breath_duration.eight_seconds | 8秒 | Settings |
| settings.breath_duration.five_seconds | 5秒 | Settings |
| settings.breath_duration.label | 一呼吸の長さ | Settings |
| settings.breath_duration.three_seconds | 3秒 | Settings |
| settings.debug.copy_event_log | イベントログをコピー | Settings |
| settings.debug.replay_onboarding | オンボーディングをもう一度見る | Settings |
| settings.delete_all.confirmation.cancel | キャンセル | Settings |
| settings.delete_all.confirmation.delete | 削除する | Settings |
| settings.delete_all.confirmation.message | 目標・記録・設定がすべて削除されます。この操作は取り消せません。 | Settings |
| settings.delete_all.confirmation.title | 全データを削除しますか | Settings |
| settings.device_only_note | SNSなどのアプリを止める機能は、iPhone実機でのみ動作します。 | Settings |
| settings.error.data_load | データを読み込めませんでした | Settings |
| settings.error.data_save | データを保存できませんでした | Settings |
| settings.error.product_load | 商品情報を読み込めませんでした | Settings |
| settings.header.eyebrow | SETTINGS | Settings |
| settings.header.title | 設定 | Settings |
| settings.lock_screen.check | ロック画面で確かめる | Settings |
| settings.lock_screen.live_activity | Live Activity | Settings |
| settings.lock_screen.notification_time | 通知時刻 | Settings |
| settings.lock_screen.section | ロック画面の表示 | Settings |
| settings.lock_screen.theme | テーマ | Settings |
| settings.lock_screen.weekly_report | 週次レポート通知 | Settings |
| settings.mode.label | 止める強さ | Settings |
| settings.privacy.delete_all | 全データを削除 | Settings |
| settings.privacy.deleted | 削除しました | Settings |
| settings.privacy.policy | プライバシーポリシー | Settings |
| settings.privacy.section | プライバシー | Settings |
| settings.privacy.terms | 利用規約 | Settings |
| settings.schedule.bed_time | 就寝時刻 | Settings |
| settings.schedule.section | 起床・就寝時刻 | Settings |
| settings.schedule.wake_time | 起床時刻 | Settings |
| settings.screen_time.authorized | 許可済み | Settings |
| settings.screen_time.label | スクリーンタイム | Settings |
| settings.screen_time.not_authorized | 未許可 | Settings |
| settings.selection.app_count | アプリ%lld個 | Settings |
| settings.selection.category_count | カテゴリ%lld個 | Settings |
| settings.selection.website_count | Webサイト%lld個 | Settings |
| settings.status.free | Free | Settings |
| settings.status.pro | Pro | Settings |
| settings.target.apps | 止めるアプリ | Settings |
| settings.target.automation | 自動で一呼吸を出す設定 | Settings |
| settings.target.section | 対象 | Settings |
| settings.value.not_set | 未設定 | Settings |
| settings.value.unavailable | — | Settings |

## Migrated batch 2 source inventory (remaining: 0)

The inventory below is retained as the historical source-location checklist used for batch 2. Every listed location has been migrated. It excludes non-user-facing identifiers, analytics values, URL schemes, SF Symbol names, storage keys, log text, and empty fallback strings.

### AppContainer.swift

| file:line | string | screen/context |
|---|---|---|
| AppContainer.swift:141 | `記録データを準備できませんでした` | Global startup error |
| AppContainer.swift:175 | `データを読み込めませんでした` | Global load error |
| AppContainer.swift:285 | `無料プランのため、よく開こうとしていた\(app.displayName)を残しました` | Settings / target-app limit notice |
| AppContainer.swift:319 | `データを削除できませんでした` | Settings / data reset error |
| AppContainer.swift:345 | `目標の追加にはProが必要です` | Goals / entitlement error |
| AppContainer.swift:385 | `目標を保存できませんでした` | Goal editor / save error |
| AppContainer.swift:397 | `目標を削除できませんでした` | Goal editor / delete error |
| AppContainer.swift:410 | `並び替えできませんでした` | Goals / reorder error |

### AutomationGuideView.swift

| file:line | string | screen/context |
|---|---|---|
| AutomationGuideView.swift:20 | `自動で一呼吸を出す設定` | Automation guide / title |
| AutomationGuideView.swift:24 | `ショートカットのオートメーションで、選んだアプリを開いたときにDopaBreakを起動します。` | Automation guide / description |
| AutomationGuideView.swift:29 | `ショートカットを開く` | Automation guide / primary action |
| AutomationGuideView.swift:36 | `オートメーションを開く` | Automation guide / step 1 |
| AutomationGuideView.swift:37 | `＋を押してAppを選ぶ` | Automation guide / step 2 |
| AutomationGuideView.swift:38 | `対象アプリを選び開かれたときを選ぶ` | Automation guide / step 3 |
| AutomationGuideView.swift:39 | `すぐに実行を選ぶ` | Automation guide / step 4 |
| AutomationGuideView.swift:40 | `アクションでDopaBreakで一呼吸を選ぶ` | Automation guide / step 5 |
| AutomationGuideView.swift:46 | `設定するアプリ` | Automation guide / app section |
| AutomationGuideView.swift:50 | `先に止めるアプリを選んでください。` | Automation guide / empty state |
| AutomationGuideView.swift:67 | `設定できたかどうかは 対象アプリを開いたときに自動で確認されます` | Automation guide / verification note |
| AutomationGuideView.swift:80 | `閉じる` | Automation guide / close action |
| AutomationGuideView.swift:117 | `Safariはホーム画面から開いて確認してください` | Automation guide / Safari note |
| AutomationGuideView.swift:122 | `テストする` | Automation guide / test action |
| AutomationGuideView.swift:132 | `設定済み` | Automation guide / verified status |
| AutomationGuideView.swift:132 | `未確認` | Automation guide / unverified status |
| AutomationGuideView.swift:147 | `\(index)` | Automation guide / visible step number |

### GoalEditorSheet.swift

| file:line | string | screen/context |
|---|---|---|
| GoalEditorSheet.swift:16 | `学び` | Goal editor / category |
| GoalEditorSheet.swift:18 | `仕事` | Goal editor / category |
| GoalEditorSheet.swift:20 | `健康` | Goal editor / category |
| GoalEditorSheet.swift:22 | `睡眠` | Goal editor / category |
| GoalEditorSheet.swift:24 | `創作` | Goal editor / category |
| GoalEditorSheet.swift:26 | `その他` | Goal editor / category |
| GoalEditorSheet.swift:63 | `目標を編集` | Goal editor / existing-goal title |
| GoalEditorSheet.swift:63 | `目標を追加` | Goal editor / new-goal title |
| GoalEditorSheet.swift:67 | `閉じる` | Goal editor / close action |
| GoalEditorSheet.swift:84 | `目標` | Goal editor / field label |
| GoalEditorSheet.swift:89 | `例 英語で商談できる自分になる` | Goal editor / goal placeholder |
| GoalEditorSheet.swift:104 | `カテゴリ` | Goal editor / category label |
| GoalEditorSheet.swift:106 | `カテゴリ` | Goal editor / picker label |
| GoalEditorSheet.swift:120 | `ロック画面用の短い表示名` | Goal editor / lock-screen label |
| GoalEditorSheet.swift:125 | `ロック画面用の短い表示名` | Goal editor / lock-screen placeholder |
| GoalEditorSheet.swift:139 | `保存` | Goal editor / save action |
| GoalEditorSheet.swift:168 | `削除` | Goal editor / delete action |
| GoalEditorSheet.swift:204 | `\(count)/\(limit)` | Goal editor / character counter |

### GoalsView.swift

| file:line | string | screen/context |
|---|---|---|
| GoalsView.swift:23 | `YOUR GOAL` | Goals / header eyebrow |
| GoalsView.swift:23 | `目標` | Goals / header title |
| GoalsView.swift:69 | `目標` | Goals / empty-state label |
| GoalsView.swift:70 | `戻りたい自分を決める` | Goals / empty-state title |
| GoalsView.swift:74 | `目標は、あなたを連れ戻す錨です。開く前に思い出せる言葉を置きましょう。` | Goals / empty-state description |
| GoalsView.swift:128 | `目標を追加` | Goals / add action |

### InterventionFlowModel.swift

| file:line | string | screen/context |
|---|---|---|
| InterventionFlowModel.swift:33 | `仕事で使う` | Intervention / reason option |
| InterventionFlowModel.swift:34 | `調べもの` | Intervention / reason option |
| InterventionFlowModel.swift:35 | `連絡を確認` | Intervention / reason option |
| InterventionFlowModel.swift:36 | `投稿する` | Intervention / reason option |
| InterventionFlowModel.swift:37 | `暇つぶし` | Intervention / reason option |
| InterventionFlowModel.swift:38 | `なんとなく` | Intervention / reason option |
| InterventionFlowModel.swift:67 | `\(rawValue)分` | Intervention / duration option |
| InterventionFlowModel.swift:123 | `記録データを準備できませんでした` | Intervention / preparation error |
| InterventionFlowModel.swift:140 | `準備できませんでした` | Intervention / preparation error |
| InterventionFlowModel.swift:193 | `進められませんでした` | Intervention / progression error |
| InterventionFlowModel.swift:205 | `記録できませんでした` | Intervention / cancellation-record error |
| InterventionFlowModel.swift:238 | `記録できませんでした` | Intervention / opening-record error |
| InterventionFlowModel.swift:246 | `そろそろひと休み` | Intervention / duration notification title |
| InterventionFlowModel.swift:247 | `そろそろ\(duration.rawValue)分。見てどうだった？` | Intervention / duration notification body |
| InterventionFlowModel.swift:267 | `まだ見てる？` | Intervention / check-in notification title |
| InterventionFlowModel.swift:268 | `戻る先を思い出す時間です` | Intervention / check-in notification body |
| InterventionFlowModel.swift:285 | `ホーム画面から\(target.displayName)を開いてください` | Intervention / app-open fallback |

### InterventionFlowView.swift

| file:line | string | screen/context |
|---|---|---|
| InterventionFlowView.swift:80 | `INTERCEPTED` | Intervention / breath eyebrow |
| InterventionFlowView.swift:91 | `\(flow.breathRemainingSeconds)` | Intervention / breath countdown |
| InterventionFlowView.swift:120 | `ひと呼吸おきましょう` | Intervention / breath title |
| InterventionFlowView.swift:123 | `BREATHE · \(flow.breathTotalSeconds) SEC` | Intervention / breath timer label |
| InterventionFlowView.swift:140 | `USAGE SUMMARY` | Intervention / usage-summary label |
| InterventionFlowView.swift:141 | `\(flow.todayAttemptDisplayCount)回` | Intervention / today-attempt count |
| InterventionFlowView.swift:146 | `すでに開いています` | Intervention / direct-open title |
| InterventionFlowView.swift:150 | `開く目的を確かめる` | Intervention / goal fallback |
| InterventionFlowView.swift:149 | `YOUR GOAL` | Intervention / goal label |
| InterventionFlowView.swift:157 | `目標を思い出す` | Intervention / continue action |
| InterventionFlowView.swift:167 | `何のために開きますか？` | Intervention / goal reminder title |
| InterventionFlowView.swift:169 | `YOUR GOAL` | Intervention / goal reminder label |
| InterventionFlowView.swift:170 | `戻りたい自分` | Intervention / goal reminder heading |
| InterventionFlowView.swift:175 | `・` | Intervention / goal list separator |
| InterventionFlowView.swift:187 | `どうするか選ぶ` | Intervention / decision action |
| InterventionFlowView.swift:196 | `INTENT` | Intervention / intent eyebrow |
| InterventionFlowView.swift:197 | `何のために\n開きますか？` | Intervention / intent title |
| InterventionFlowView.swift:198 | `目的が明確なら、一呼吸を省いてすぐ進めます` | Intervention / intent description |
| InterventionFlowView.swift:237 | `DECISION` | Intervention / decision eyebrow |
| InterventionFlowView.swift:238 | `本当に今、\n必要ですか？` | Intervention / decision title |
| InterventionFlowView.swift:253 | `開かない` | Intervention / cancel action |
| InterventionFlowView.swift:254 | `必要な時間だけ開く` | Intervention / open action |
| InterventionFlowView.swift:262 | `TIME` | Intervention / duration eyebrow |
| InterventionFlowView.swift:263 | `何分だけ\n開きますか？` | Intervention / duration title |
| InterventionFlowView.swift:274 | `目的が明確なため、一呼吸を省きました` | Intervention / fast-path note |
| InterventionFlowView.swift:282 | `必要な用事が終わる時間だけ選びましょう` | Intervention / duration guidance |
| InterventionFlowView.swift:320 | `\(flow.selectedDuration.rawValue)分だけ開く` | Intervention / timed-open action |
| InterventionFlowView.swift:325 | `開かずに戻る` | Intervention / cancel action |
| InterventionFlowView.swift:333 | `SNSを開かずに達成画面へ進みます` | Intervention / cancel accessibility hint |
| InterventionFlowView.swift:342 | `OPENING` | Intervention / opening eyebrow |
| InterventionFlowView.swift:346 | `を開いています` | Intervention / opening title suffix |
| InterventionFlowView.swift:348 | `\(reason.displayTitle) ・ \(flow.selectedDuration.rawValue)分` | Intervention / opening summary |
| InterventionFlowView.swift:364 | `閉じる` | Intervention / opening-fallback action |
| InterventionFlowView.swift:373 | `時間になったら通知でお知らせします` | Intervention / notification status |
| InterventionFlowView.swift:374 | `通知がオフのため時間のお知らせは届きません` | Intervention / notification-disabled status |
| InterventionFlowView.swift:393 | `開かなかった\n自分の時間に戻る` | Intervention / success title |
| InterventionFlowView.swift:401 | `今日\(flow.todayAttemptDisplayCount)回目` | Intervention / daily attempt |
| InterventionFlowView.swift:408 | `YOUR GOAL` | Intervention / success goal label |
| InterventionFlowView.swift:418 | `開かずに戻れた` | Intervention / success metric |
| InterventionFlowView.swift:422 | `開こうとした` | Intervention / attempt metric |
| InterventionFlowView.swift:428 | `閉じる` | Intervention / success action |
| InterventionFlowView.swift:438 | `閉じる` | Intervention / failure action |
| InterventionFlowView.swift:447 | `\(flow.todayCancelledCountForDisplay)` | Intervention / success count |
| InterventionFlowView.swift:451 | `\(flow.todayAttemptCountForDisplay)` | Intervention / attempt count |
| InterventionFlowView.swift:499 | `起きてすぐの数分` | Intervention / morning banner title |
| InterventionFlowView.swift:499 | `その日の集中を決める時間` | Intervention / morning banner body |
| InterventionFlowView.swift:501 | `眠る前の数分` | Intervention / night banner title |
| InterventionFlowView.swift:501 | `その日の睡眠の質を決める時間` | Intervention / night banner body |

### InterventionModeDisplay.swift

| file:line | string | screen/context |
|---|---|---|
| InterventionModeDisplay.swift:7 | `ディープフォーカス` | Intervention mode / title |
| InterventionModeDisplay.swift:9 | `標準` | Intervention mode / title |
| InterventionModeDisplay.swift:11 | `夜だけ強化` | Intervention mode / title |
| InterventionModeDisplay.swift:18 | `作業中はSNSを開く前に強く止める` | Intervention mode / detail |
| InterventionModeDisplay.swift:20 | `SNSを開く前にひと呼吸と理由確認` | Intervention mode / detail |
| InterventionModeDisplay.swift:22 | `夜は確認を強くして開きすぎを防ぐ` | Intervention mode / detail |

### LockSurfaceCoordinator.swift

| file:line | string | screen/context |
|---|---|---|
| LockSurfaceCoordinator.swift:122 | `今日の戻る先` | Morning notification / title |
| LockSurfaceCoordinator.swift:123 | `・` | Morning notification / goal separator |
| LockSurfaceCoordinator.swift:145 | `今週のふりかえり` | Weekly notification / title |
| LockSurfaceCoordinator.swift:146 | `開かずに戻れた \(weeklySummary.cancelled)回 / 開こうとした \(weeklySummary.attempts)回` | Weekly notification / body |
| LockSurfaceCoordinator.swift / TrialReminderNotificationSchedule | `無料期間はあと\(leadDays)日です` | Trial reminder / title; selected 2 or 3 days |
| LockSurfaceCoordinator.swift:198 | `ここまでに開かずに戻れた \(trialDay5.cancelledCount)回。7日目に年額プランへ切り替わります。解約はいつでもできます。` | Trial day-5 notification / body with count |
| LockSurfaceCoordinator.swift:200 | `7日目に年額プランへ切り替わります。解約はいつでもできます。` | Trial day-5 notification / fallback body |
| LockSurfaceCoordinator.swift:215 | `この1ヶ月のふりかえり` | Month-1 notification / title |
| LockSurfaceCoordinator.swift:216 | `開かずに戻れた \(month1.cancelledCount)回 / 開こうとした \(month1.attemptCount)回` | Month-1 notification / body |
| LockSurfaceCoordinator.swift:230 | `まもなく1年の更新です` | Month-12 notification / title |
| LockSurfaceCoordinator.swift:231 | `この1年で開かずに戻れた \(month12.cancelledCount)回。更新の確認はApp Storeの設定からできます。` | Month-12 notification / body |
| LockSurfaceCoordinator.swift:250 | `一呼吸の設定は終わっていますか` | D1 activation notification / title |
| LockSurfaceCoordinator.swift:251 | `対象アプリを開いたときに一呼吸が出れば設定完了です。設定はアプリからいつでも確認できます。` | D1 activation notification / body |

### MidSessionCheckInSheet.swift

| file:line | string | screen/context |
|---|---|---|
| MidSessionCheckInSheet.swift:11 | `まだ見てる？` | Mid-session check-in / title |
| MidSessionCheckInSheet.swift:31 | `閉じる` | Mid-session check-in / close action |
| MidSessionCheckInSheet.swift:46 | `何のために開いたか思い出せますか` | Mid-session check-in / no-goal message |
| MidSessionCheckInSheet.swift:48 | `戻る先　\(goal.title)` | Mid-session check-in / goal message |

### PostUseReflectionSheet.swift

| file:line | string | screen/context |
|---|---|---|
| PostUseReflectionSheet.swift:20 | `REFLECTION` | Reflection / eyebrow |
| PostUseReflectionSheet.swift:28 | `今回はスキップ` | Reflection / skip action |
| PostUseReflectionSheet.swift:47 | `SNSを見て\nどうだった？` | Reflection / outcome title |
| PostUseReflectionSheet.swift:52 | `必要な時間を使い終えました。次の選択のために記録します。` | Reflection / description |
| PostUseReflectionSheet.swift:79 | `幸福感や集中は\n増えた？` | Reflection / impact title |
| PostUseReflectionSheet.swift:126 | `データを保存できませんでした` | Reflection / outcome-save error |
| PostUseReflectionSheet.swift:135 | `データを保存できませんでした` | Reflection / impact-save error |
| PostUseReflectionSheet.swift:143 | `満足感があった` | Reflection / outcome option |
| PostUseReflectionSheet.swift:144 | `楽しかった` | Reflection / outcome option |
| PostUseReflectionSheet.swift:145 | `何も得られなかった` | Reflection / outcome option |
| PostUseReflectionSheet.swift:146 | `時間を失った` | Reflection / outcome option |
| PostUseReflectionSheet.swift:147 | `気分が下がった` | Reflection / outcome option |
| PostUseReflectionSheet.swift:155 | `上がった` | Reflection / impact option |
| PostUseReflectionSheet.swift:156 | `変わらない` | Reflection / impact option |
| PostUseReflectionSheet.swift:157 | `下がった` | Reflection / impact option |

### RootTabView.swift

| file:line | string | screen/context |
|---|---|---|
| RootTabView.swift:29 | `ホーム` | Root tabs / system tab label |
| RootTabView.swift:35 | `目標` | Root tabs / system tab label |
| RootTabView.swift:41 | `統計` | Root tabs / system tab label |
| RootTabView.swift:51 | `設定` | Root tabs / system tab label |
| RootTabView.swift:59 | `エラー` | Root / global alert title |
| RootTabView.swift:60 | `閉じる` | Root / global alert action |
| RootTabView.swift:314 | `ホーム` | Root tabs / custom tab label |
| RootTabView.swift:315 | `目標` | Root tabs / custom tab label |
| RootTabView.swift:316 | `統計` | Root tabs / custom tab label |
| RootTabView.swift:317 | `設定` | Root tabs / custom tab label |

### StartInterventionIntent.swift

| file:line | string | screen/context |
|---|---|---|
| StartInterventionIntent.swift:17 | `SNSアプリ` | Shortcuts / app-enum type name |
| StartInterventionIntent.swift:20 | `Instagram` | Shortcuts / app option |
| StartInterventionIntent.swift:21 | `X` | Shortcuts / app option |
| StartInterventionIntent.swift:22 | `TikTok` | Shortcuts / app option |
| StartInterventionIntent.swift:23 | `YouTube` | Shortcuts / app option |
| StartInterventionIntent.swift:24 | `Facebook` | Shortcuts / app option |
| StartInterventionIntent.swift:25 | `Threads` | Shortcuts / app option |
| StartInterventionIntent.swift:26 | `LINE` | Shortcuts / app option |
| StartInterventionIntent.swift:27 | `Safari` | Shortcuts / app option |
| StartInterventionIntent.swift:37 | `DopaBreakで一呼吸` | Shortcuts / intent title |
| StartInterventionIntent.swift:38 | `対象アプリを開く前にDopaBreakの一呼吸フローを表示します。` | Shortcuts / intent description |
| StartInterventionIntent.swift:41 | `アプリ` | Shortcuts / parameter title |

### StatsView.swift

| file:line | string | screen/context |
|---|---|---|
| StatsView.swift:12 | `STATS · 今日` | Stats / locked header eyebrow |
| StatsView.swift:12 | `STATS · 今週` | Stats / unlocked header eyebrow |
| StatsView.swift:13 | `今日の記録` | Stats / locked header title |
| StatsView.swift:13 | `今週の傾向` | Stats / unlocked header title |
| StatsView.swift:69 | `開かずに戻れた割合` | Stats / success-rate title |
| StatsView.swift:76 | `TODAY SUMMARY` | Stats / today summary label |
| StatsView.swift:80 | `WEEKLY SUMMARY` | Stats / week summary label |
| StatsView.swift:90 | `まだ記録がありません` | Stats / empty-state title |
| StatsView.swift:94 | `開く前に選び直すたび、取り戻した記録がここに貯まります。` | Stats / empty-state description |
| StatsView.swift:101 | `開かずに戻れた` | Stats / cancelled metric |
| StatsView.swift:101 | `\(cancelled)回` | Stats / cancelled value |
| StatsView.swift:102 | `開こうとした` | Stats / attempt metric |
| StatsView.swift:102 | `\(attempts)回` | Stats / attempt value |
| StatsView.swift:119 | `記録を全期間さかのぼれる` | Stats / paywall action |
| StatsView.swift:137 | `BEHAVIOR SIGNAL` | Stats / behavior label |
| StatsView.swift:138 | `戻れた` | Stats / success signal |
| StatsView.swift:139 | `開いた` | Stats / open signal |
| StatsView.swift:147 | `ALL TIME` | Stats / all-time label |
| StatsView.swift:149 | `これまでに開かずに戻れた` | Stats / all-time metric |
| StatsView.swift:150 | `\(model.allTimeCancelledCount)回` | Stats / all-time value |
| StatsView.swift:170 | `\(Int((value * 100).rounded()))%` | Stats / chart percentage |
| StatsView.swift:183 | `—` | Stats / unavailable weekly rate |
| StatsView.swift:184 | `\(Int((weeklySuccessRate * 100).rounded()))%` | Stats / weekly rate |
| StatsView.swift:193 | `—` | Stats / unavailable daily rate |
| StatsView.swift:194 | `\(Int((dailySuccessRate * 100).rounded()))%` | Stats / daily rate |

### StoreService.swift

| file:line | string | screen/context |
|---|---|---|
| StoreService.swift:21 | `購入を確認できませんでした` | Store / entitlement-verification error |
| StoreService.swift:110 | `商品情報を読み込めませんでした` | Store / product-load error |
| StoreService.swift:138 | `購入の確認が保留中です` | Store / pending purchase |
| StoreService.swift:141 | `購入を完了できませんでした` | Store / unverified purchase |
| StoreService.swift:145 | `購入を完了できませんでした` | Store / purchase error |
| StoreService.swift:180 | `復元できる購入がありませんでした` | Store / no-restorable-purchase status |
| StoreService.swift:184 | `購入を復元できませんでした` | Store / restore error |
| StoreService.swift:260 | `購入を確認できませんでした` | Store / transaction-update error |
| StoreService.swift:315 | `無料期間あり` | Store / introductory-offer label |
| StoreService.swift:317 | `\(durationText)無料` | Store / introductory-offer label |
| StoreService.swift:325 | `\(totalValue)日間` | Store / offer duration |
| StoreService.swift:328 | `\(totalValue * 7)日間` | Store / offer duration |
| StoreService.swift:330 | `\(totalValue)か月` | Store / offer duration |
| StoreService.swift:332 | `\(totalValue)年間` | Store / offer duration |

### TargetAppPickerSheet.swift

| file:line | string | screen/context |
|---|---|---|
| TargetAppPickerSheet.swift:18 | `止めるアプリを選ぶ` | Target-app picker / title |
| TargetAppPickerSheet.swift:22 | `開こうとした瞬間に一呼吸を出したいアプリを選びます。` | Target-app picker / description |
| TargetAppPickerSheet.swift:58 | `閉じる` | Target-app picker / close action |
| TargetAppPickerSheet.swift:109 | `無料プランでは1つまで` | Target-app picker / trial limit |
| TargetAppPickerSheet.swift:111 | `無料プランでは1つまで` | Target-app picker / free limit |
| TargetAppPickerSheet.swift:142 | `保存できませんでした` | Target-app picker / save error |

Files in `ios/DopaBreak` that were already clear before batch 2: `AppURLs.swift`, `DesignTokens.swift`, `DopaBreakApp.swift`, `NotificationDelegate.swift`, `ScreenTimeCenter.swift`, and `ShieldController.swift`.

Extension completion: `ios/WidgetsExtension/DopaBreakWidgets.swift` uses `ios/WidgetsExtension/Localizable.xcstrings`; `ios/ShieldConfigExtension/ShieldConfigurationExtension.swift` uses `ios/ShieldConfigExtension/Localizable.xcstrings`. Shield Action and Monitor contain no user-facing strings, so no empty catalog was added for those targets.

## 2026-09-05 競合監査の改善で追加（ja/en/ko）

| キー | ja |
| --- | --- |
| home.block.check | ブロックの準備を確認してください |
| home.block.continues | 設定したブロックが続いています |
| settings.block.check_notice | ブロックの準備を確認できません。権限と通信状態を確認して、再試行してください。既存のブロックは残る場合があります。 |
| settings.block.retry | 再試行 |
| settings.schedule.add | 予定を追加 |
| settings.schedule.continuous | 予定が続く間 |
| settings.schedule.first | 予定1 |
| settings.schedule.night_optin | 就寝中のブロックに予定を追加 |
| settings.schedule.remove | 予定2を削除 |
| settings.schedule.scope | 予定は2件まで設定できます。夜だけ強化では、就寝中のブロックと両方が適用されます。 |
| settings.schedule.second | 予定2 |
| settings.schedule.section | 起床・就寝時刻 |
| settings.schedule.select | 編集する予定 |
| settings.strict.change_blocked | 強いブロック中は変更できません。必要な場合は、セッションの解除から緊急解除してください。 |
| settings.strict.description | 終了まで通常の解除と対象・モードの変更を止めます。緊急解除には30秒の待機が必要です。iOS設定での権限取り消しは防げません。 |
| settings.strict.exit.confirm | 手動セッションを緊急解除 |
| settings.strict.exit.continue | ブロックを続ける |
| settings.strict.exit.countdown | 解除まであと%lld秒 |
| settings.strict.exit.description | 終了時刻まで続ける設定です。緊急で必要なときは、30秒待って手動セッションを解除できます。毎週の予定と就寝中のブロックは別に続きます。 |
| settings.strict.exit.done | セッションは終了しました |
| settings.strict.exit.request | 緊急解除の待機を始める |
| settings.strict.exit.title | 緊急解除 |
| settings.strict.toggle | 途中で解除しにくくする |
| stats.insight.action | ブロックの設定を見直す |
| stats.insight.evidence | この期間の回答%lld件のうち%lld件が「時間を失った」「気分が悪くなった」でした。 |
| stats.insight.suggestion | 見たくない時間が決まっているなら、その時間だけブロックする予定を試してみませんか。設定は自分で選べます。 |
| stats.insight.title | 次の使い方を決める |
