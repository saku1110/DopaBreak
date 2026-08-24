> 2026-08-24 オーナー訂正: 本監査の「開かなかった」をkeepとした判定は失効。画面表示は「開くのをやめた」へ統一し、`.claude/specs/functional-screens-redesign-copy-sheet.md` のオーナー訂正を正とする。

### home

| key | 現行ja | keep/rewrite | 提案ja | 理由(8語以内) |
|---|---|---|---|---|
| `home.hero.today` | 今日 ・ %@ | keep | — | 意味と対象が明確 |
| `home.hero.week_count` | %lld回 / 今週 | keep | — | 意味と対象が明確 |
| `home.achievement.count_unit` | 回 | keep | — | 意味と対象が明確 |
| `home.achievement.title` | 今日 開かなかった | keep | — | 意味と対象が明確 |
| `home.streak.days` | 連続 %lld日 | keep | — | 意味と対象が明確 |
| `home.achievement.empty_body` | 今日はまだ開こうとしていません | keep | — | 意味と対象が明確 |
| `home.achievement.summary` | 開こうとしたのは%lld回 | keep | — | 意味と対象が明確 |
| `home.reclaimed.title` | 取り戻した時間 | keep | — | 意味と対象が明確 |
| `home.reclaimed.week_label` | 今週 | keep | — | 意味と対象が明確 |
| `home.reclaimed.yearly` | この調子なら1年で約 %@日分 | keep | — | 意味と対象が明確 |
| `home.targets.title` | 止めているアプリ | keep | — | 意味と対象が明確 |
| `home.targets.focus_end` | いま解除する | keep | — | 意味と対象が明確 |
| `home.targets.focus_30` | 30分だけ開けなくする | keep | — | 意味と対象が明確 |
| `home.targets.empty` | 止めるアプリを選ぶ | keep | — | 意味と対象が明確 |
| `home.targets.night_line` | %@から朝まで開けません | keep | — | 意味と対象が明確 |
| `home.targets.focus_running` | あと%@ 開けません | keep | — | 意味と対象が明確 |
| `settings.deep_focus.session.open_ended.label` | 自分で戻すまで | rewrite | 自分で解除するまで | 戻す対象が曖昧 |
| `home.targets.breath_line` | 開く前に%lld秒の間が入ります | keep | — | 意味と対象が明確 |
| `home.week.eyebrow` | 今週 | keep | — | 意味と対象が明確 |
| `home.week.summary` | 今週 開かなかったのは%lld回 | keep | — | 意味と対象が明確 |
| `stats.weekly_detail.comparison.more` | 先週より%lld回多い | keep | — | 意味と対象が明確 |
| `stats.weekly_detail.comparison.less` | 先週より%lld回少ない | keep | — | 意味と対象が明確 |
| `stats.weekly_detail.comparison.same` | 先週と同じ | keep | — | 意味と対象が明確 |
| `home.apps.title` | アプリごと | keep | — | 意味と対象が明確 |
| `home.apps.legend` | 今日 開かなかった / 開こうとした | keep | — | 意味と対象が明確 |
| `home.apps.ratio` | %lld / %lld | keep | — | 意味と対象が明確 |
| `reflection.satisfaction.title` | SNSを見てどうだった？ | keep | — | 意味と対象が明確 |
| `home.reflection.top` | 「%@」が多め | keep | — | 意味と対象が明確 |
| `stats.paywall.weekly_report` | 毎週のふりかえりを詳しく見られる | keep | — | 意味と対象が明確 |
| `home.goal.label` | あなたの目標 | keep | — | 意味と対象が明確 |
| `home.first_day.title` | 開こうとした瞬間に一呼吸が入ります | keep | — | 意味と対象が明確 |
| `home.first_day.body` | 開かなかった回数がここに残ります | keep | — | 意味と対象が明確 |
| `home.automation_status.body` | 対象アプリを開いたときに一呼吸が出れば設定完了です。 | rewrite | 止めるアプリを開いたときに一呼吸が出れば設定完了です | 設定語彙に統一 |
| `home.automation_status.action` | 設定を確認 | keep | — | 意味と対象が明確 |
| `home.reflection.count` | 今週の%lld回中 %lld回 | keep | — | 意味と対象が明確 |
| `home.reclaimed.minutes` | %lld分 | keep | — | 意味と対象が明確 |
| `home.reclaimed.hours_minutes` | %lld時間%lld分 | keep | — | 意味と対象が明確 |
| `home.goal.fallback` | タップして目標を追加 | keep | — | 意味と対象が明確 |
| `home.automation_status.title_single` | %@の一呼吸はまだ動いていません | keep | — | 意味と対象が明確 |
| `home.automation_status.title_multiple` | %lld個のアプリで一呼吸がまだ動いていません | keep | — | 意味と対象が明確 |

### stats

| key | 現行ja | keep/rewrite | 提案ja | 理由(8語以内) |
|---|---|---|---|---|
| `stats.header.today.title` | 今日の記録 | keep | — | 意味と対象が明確 |
| `stats.header.week.title` | 今週の傾向 | rewrite | 今週の記録 | 傾向より中身が明確 |
| `stats.rate.title` | 開かなかった割合 | keep | — | 意味と対象が明確 |
| `stats.summary.today.label` | TODAY SUMMARY | rewrite | 今日の記録 | 英語見出しを日本語化 |
| `stats.summary.week.label` | WEEKLY SUMMARY | rewrite | 今週の記録 | 英語見出しを日本語化 |
| `stats.weekly_detail.label` | WEEKLY DETAIL | rewrite | 今週の内訳 | 英語見出しを日本語化 |
| `stats.weekly_detail.comparison.label` | VS LAST WEEK | rewrite | 先週との比較 | 英語見出しを日本語化 |
| `stats.weekly_detail.comparison.no_data` | 先週の記録なし | keep | — | 意味と対象が明確 |
| `stats.weekly_detail.comparison.more` | 先週より%lld回多い | keep | — | 意味と対象が明確 |
| `stats.weekly_detail.comparison.less` | 先週より%lld回少ない | keep | — | 意味と対象が明確 |
| `stats.weekly_detail.comparison.same` | 先週と同じ | keep | — | 意味と対象が明確 |
| `stats.weekly_detail.day.accessibility_label` | %1$@ 開こうとした%2$lld回 開かなかった%3$lld回 | keep | — | 意味と対象が明確 |
| `stats.empty.title` | まだ記録がありません | keep | — | 意味と対象が明確 |
| `stats.empty.description` | 開く前に選び直すたび、その記録がここに貯まります。 | rewrite | 開こうとした回数と開かなかった回数がここに残ります | 残る記録を具体化 |
| `stats.metric.cancelled` | 開かなかった | keep | — | 意味と対象が明確 |
| `stats.metric.attempted` | 開こうとした | keep | — | 意味と対象が明確 |
| `stats.metric.count` | %lld回 | keep | — | 意味と対象が明確 |
| `stats.paywall.weekly_report` | 毎週のふりかえりを詳しく見られる | keep | — | 意味と対象が明確 |
| `stats.paywall.full_history` | 記録を全期間さかのぼれる | keep | — | 意味と対象が明確 |
| `stats.behavior.label` | BEHAVIOR SIGNAL | rewrite | 開かなかった回数と開いた回数 | 英語と抽象語を排除 |
| `stats.behavior.cancelled` | 開かなかった | keep | — | 意味と対象が明確 |
| `stats.behavior.opened` | 開いた | keep | — | 意味と対象が明確 |
| `stats.all_time.label` | ALL TIME | rewrite | 全期間 | 英語見出しを日本語化 |
| `stats.all_time.cancelled` | これまでに開かなかった | keep | — | 意味と対象が明確 |
| `stats.rate.percentage` | %lld%% | keep | — | 意味と対象が明確 |
| `stats.rate.unavailable` | — | keep | — | 意味と対象が明確 |

### goals

| key | 現行ja | keep/rewrite | 提案ja | 理由(8語以内) |
|---|---|---|---|---|
| `goals.header.title` | 目標 | keep | — | 意味と対象が明確 |
| `goals.empty.label` | 目標 | keep | — | 意味と対象が明確 |
| `goals.empty.title` | 目標を決める | keep | — | 意味と対象が明確 |
| `goals.empty.description` | ここで決めた一言が、開こうとした瞬間に表示されます。例：英語で話せるようになる | rewrite | アプリを開こうとしたときに目標が表示されます 例 英語で話せるようになる | 一言を目標に統一 |
| `goals.action.add` | 目標を追加 | keep | — | 意味と対象が明確 |

### goal_editor

| key | 現行ja | keep/rewrite | 提案ja | 理由(8語以内) |
|---|---|---|---|---|
| `goal_editor.category.study` | 学び | keep | — | 意味と対象が明確 |
| `goal_editor.category.work` | 仕事 | keep | — | 意味と対象が明確 |
| `goal_editor.category.health` | 健康 | keep | — | 意味と対象が明確 |
| `goal_editor.category.sleep` | 睡眠 | keep | — | 意味と対象が明確 |
| `goal_editor.category.creative` | 創作 | keep | — | 意味と対象が明確 |
| `goal_editor.category.other` | その他 | keep | — | 意味と対象が明確 |
| `goal_editor.title.edit` | 目標を編集 | keep | — | 意味と対象が明確 |
| `goal_editor.title.add` | 目標を追加 | keep | — | 意味と対象が明確 |
| `goal_editor.action.close` | 閉じる | keep | — | 意味と対象が明確 |
| `goal_editor.goal.label` | 目標 | keep | — | 意味と対象が明確 |
| `goal_editor.goal.placeholder` | 例 英語で商談できる自分になる | keep | — | 意味と対象が明確 |
| `goal_editor.category.label` | カテゴリ | keep | — | 意味と対象が明確 |
| `goal_editor.action.save` | 保存 | keep | — | 意味と対象が明確 |
| `goal_editor.action.delete` | 削除 | keep | — | 意味と対象が明確 |
| `goal_editor.character_count` | %lld/%lld | keep | — | 意味と対象が明確 |

### settings

| key | 現行ja | keep/rewrite | 提案ja | 理由(8語以内) |
|---|---|---|---|---|
| `settings.deep_focus.session.option.thirty_minutes` | 30分 | keep | — | 意味と対象が明確 |
| `settings.deep_focus.session.option.one_hour` | 1時間 | keep | — | 意味と対象が明確 |
| `settings.deep_focus.session.option.two_hours` | 2時間 | keep | — | 意味と対象が明確 |
| `settings.deep_focus.session.option.until_stopped` | 戻すまで | rewrite | 解除するまで | 戻す対象が曖昧 |
| `settings.header.title` | 設定 | keep | — | 意味と対象が明確 |
| `settings.device_only_note` | SNSなどのアプリを止める機能は、iPhone実機でのみ動作します。 | rewrite | SNSなどのアプリを止める機能はiPhoneでのみ使えます | 実機は開発者用語 |
| `settings.delete_all.confirmation.title` | 全データを削除しますか？ | keep | — | 意味と対象が明確 |
| `settings.delete_all.confirmation.delete` | 削除する | keep | — | 意味と対象が明確 |
| `settings.delete_all.confirmation.cancel` | キャンセル | keep | — | 意味と対象が明確 |
| `settings.delete_all.confirmation.message` | 目標・記録・設定がすべて削除されます。この操作は取り消せません。 | keep | — | 意味と対象が明確 |
| `settings.gate.section` | 止めるアプリ | keep | — | 意味と対象が明確 |
| `settings.gate.description` | 開く前に必ず一呼吸。回数や長さはアプリごとに決められます | rewrite | 開く前に必ず一呼吸が入りアプリごとに開ける回数と1回の長さを決められます | 回数と長さの対象を明示 |
| `settings.gate.app_list` | アプリごとの設定 | keep | — | 意味と対象が明確 |
| `settings.target.automation` | 自動で一呼吸を出す設定 | keep | — | 意味と対象が明確 |
| `settings.gate.automation_note` | Proの止めるアプリではショートカットの自動化は不要です | rewrite | Proではショートカットの自動化は不要です | 主語を簡潔にする |
| `settings.gate.category_note` | カテゴリ選択は完全ブロックでだけ使われます。開く前の一呼吸はアプリ単位です | rewrite | カテゴリで選んだアプリには一呼吸を設定できません 完全ブロックだけ使えます | 適用範囲を具体化 |
| `settings.target.apps` | 止めるアプリ | keep | — | 意味と対象が明確 |
| `settings.gate.locked_notice` | Proにするとショートカット設定なしで開く前に必ず止まり回数や待ち時間も決められます | rewrite | Proではショートカットなしでアプリごとに開ける回数と1回の長さを決められます | 効果と設定項目を明示 |
| `settings.schedule.section` | 起床・就寝時刻 | keep | — | 意味と対象が明確 |
| `settings.schedule.wake_time` | 起床時刻 | keep | — | 意味と対象が明確 |
| `settings.schedule.bed_time` | 就寝時刻 | keep | — | 意味と対象が明確 |
| `settings.usage_watch.section.title` | 利用時間の通知 | keep | — | 意味と対象が明確 |
| `settings.usage_watch.enable.title` | 利用時間の通知を使う | keep | — | 意味と対象が明確 |
| `settings.usage_watch.apps.title` | 時間をはかるアプリ | keep | — | 意味と対象が明確 |
| `settings.usage_watch.night_mode.title` | 就寝前は間隔を短く | rewrite | 就寝前は問いかけの間隔を短く | 何の間隔か明示 |
| `settings.usage_watch.free_rule.description` | 連続で2時間になったら1日1回だけお知らせします | rewrite | 選んだアプリを2時間続けて使うと1日1回通知します | 何が2時間か明示 |
| `settings.usage_watch.interval.title` | 問いかけの間隔 | keep | — | 意味と対象が明確 |
| `settings.usage_watch.permission.description` | スクリーンタイムの許可が必要です。利用データはこの端末の外に出ません | keep | — | 意味と対象が明確 |
| `settings.usage_watch.start_failed.description` | 利用時間の通知を開始できませんでした。時間をはかるアプリを選び直してからもう一度お試しください | keep | — | 意味と対象が明確 |
| `settings.status.pro` | Pro | keep | — | 意味と対象が明確 |
| `settings.lock_screen.section` | ロック画面の表示 | keep | — | 意味と対象が明確 |
| `settings.lock_screen.morning_notification` | 朝の目標通知 | keep | — | 意味と対象が明確 |
| `settings.lock_screen.notification_time` | 通知時刻 | keep | — | 意味と対象が明確 |
| `settings.lock_screen.weekly_report` | 週次レポート通知 | rewrite | 毎週の記録通知 | 週次を平易にする |
| `settings.notifications.retention_support.title` | 継続サポートの通知 | rewrite | 設定確認と記録の通知 | 抽象的な機能名を排除 |
| `settings.notifications.plan.title` | プランに関する通知 | keep | — | 意味と対象が明確 |
| `settings.lock_screen.live_activity` | Live Activity | rewrite | ロック画面に目標と記録を表示 | 公式名より機能を明示 |
| `settings.lock_screen.check` | ロック画面で確かめる | keep | — | 意味と対象が明確 |
| `settings.lock_screen.theme` | テーマ | rewrite | 表示デザイン | 何のテーマか明示 |
| `settings.deep_focus.section` | 完全ブロック | keep | — | 意味と対象が明確 |
| `settings.mode.label` | 止める強さ | keep | — | 意味と対象が明確 |
| `settings.deep_focus.targets.label` | 完全ブロックの対象 | rewrite | 完全ブロックするアプリ | 対象をアプリに具体化 |
| `settings.deep_focus.session.label` | いますぐ始める | keep | — | 意味と対象が明確 |
| `settings.deep_focus.schedule.active.label` | 予定の時間帯 | keep | — | 意味と対象が明確 |
| `settings.deep_focus.schedule.active.session_notice` | 予定の時間帯が終わったあとも、いますぐ始めた分は続きます。 | rewrite | 予定が終わっても手動で始めた分は続きます | 表現を自然にする |
| `settings.deep_focus.schedule.active.until` | %@まで | keep | — | 意味と対象が明確 |
| `settings.deep_focus.session.stop.action` | いま解除 | rewrite | いま解除する | Phase 1語彙に統一 |
| `settings.deep_focus.session.open_ended.label` | 自分で戻すまで | rewrite | 自分で解除するまで | 戻す対象が曖昧 |
| `settings.deep_focus.session.remaining` | 残り%@ | keep | — | 意味と対象が明確 |
| `settings.deep_focus.session.start.action` | 開始 | keep | — | 意味と対象が明確 |
| `settings.deep_focus.schedule.label` | 毎週の予定 | keep | — | 意味と対象が明確 |
| `settings.deep_focus.schedule.start.label` | 開始 | keep | — | 意味と対象が明確 |
| `settings.deep_focus.schedule.end.label` | 終了 | keep | — | 意味と対象が明確 |
| `settings.deep_focus.schedule.no_weekday_notice` | 曜日を選ぶと、その曜日の決めた時間だけ止まります。 | rewrite | 選んだ曜日と時間だけアプリを止めます | 止まる対象を明示 |
| `settings.deep_focus.schedule.too_short_notice` | 15分より短い時間帯は設定できません。開始と終了を離してください。 | rewrite | 開始から終了まで15分以上にしてください | 離す操作が曖昧 |
| `settings.deep_focus.locked_notice` | ディープフォーカスにすると決めた時間だけ選んだアプリを止められます。 | rewrite | 完全ブロックでは決めた時間だけ選んだアプリを止められます | モード名を機能名へ |
| `settings.deep_focus.standard_notice` | 標準＝開く前に一呼吸。ディープフォーカスに変えると決めた時間だけ選んだアプリが開けなくなります。 | rewrite | 一呼吸は開く前に待ち時間を入れます 完全ブロックは決めた時間だけ開けなくします | モード名だけで説明しない |
| `settings.deep_focus.empty_targets_notice` | 完全ブロックの対象を選ぶと、決めた時間だけそのアプリが開けなくなります。 | rewrite | 完全ブロックするアプリを選ぶと決めた時間だけ開けなくなります | 対象をアプリに具体化 |
| `settings.night_only.description` | 選んだアプリは就寝から起床まで開けなくなります。昼は一呼吸の確認だけが出ます。 | rewrite | 選んだアプリは就寝から起床まで開けません 昼は開く前に一呼吸が入ります | 確認より動作を明示 |
| `settings.deep_focus.no_window_notice` | いまは何も止まっていません。時間を決めると選んだアプリが開けなくなります。 | rewrite | いま止めているアプリはありません 時間を決めると選んだアプリを開けなくします | 何もをアプリに具体化 |
| `settings.deep_focus.description` | 選んだアプリは決めた時間だけ開けなくなります。いま始めるか毎週の予定を組むかを選べます。 | rewrite | 選んだアプリを決めた時間だけ開けなくします 今すぐ始めるか毎週の予定を設定できます | 操作と結果を簡潔化 |
| `settings.value.not_set` | 未設定 | keep | — | 意味と対象が明確 |
| `settings.breath_duration.label` | 一呼吸の長さ | keep | — | 意味と対象が明確 |
| `settings.breath_duration.three_seconds` | 3秒 | keep | — | 意味と対象が明確 |
| `settings.breath_duration.five_seconds` | 5秒 | keep | — | 意味と対象が明確 |
| `settings.breath_duration.eight_seconds` | 8秒 | keep | — | 意味と対象が明確 |
| `settings.app.version` | バージョン | keep | — | 意味と対象が明確 |
| `settings.feedback.title` | フィードバックを送る | keep | — | 意味と対象が明確 |
| `settings.debug.replay_onboarding` | オンボーディングをもう一度見る | rewrite | 最初の説明をもう一度見る | 内部用語を排除 |
| `settings.debug.copy_event_log` | イベントログをコピー | rewrite | 操作記録をコピー | 内部用語を排除 |
| `settings.account.section` | アカウント/課金 | rewrite | プランと購入 | 存在しないアカウントを除外 |
| `settings.account.pro_status` | Pro状態 | rewrite | 現在のプラン | 状態より内容が明確 |
| `settings.status.free` | Free | keep | — | 意味と対象が明確 |
| `settings.account.lifetime_plan` | 買い切りプラン | keep | — | 意味と対象が明確 |
| `settings.value.unavailable` | — | keep | — | 意味と対象が明確 |
| `settings.account.restore` | 購入を復元 | keep | — | 意味と対象が明確 |
| `settings.error.product_load` | 商品情報を読み込めませんでした | keep | — | 意味と対象が明確 |
| `settings.privacy.section` | プライバシー | keep | — | 意味と対象が明確 |
| `settings.privacy.policy` | プライバシーポリシー | keep | — | 意味と対象が明確 |
| `settings.privacy.terms` | 利用規約 | keep | — | 意味と対象が明確 |
| `settings.privacy.delete_all` | 全データを削除 | keep | — | 意味と対象が明確 |
| `settings.privacy.deleted` | 削除しました | keep | — | 意味と対象が明確 |
| `settings.screen_time.label` | スクリーンタイム | keep | — | 意味と対象が明確 |
| `settings.screen_time.authorized` | 許可済み | keep | — | 意味と対象が明確 |
| `settings.screen_time.not_authorized` | 未許可 | keep | — | 意味と対象が明確 |
| `settings.authorization.title` | SNSの前で止める許可 | rewrite | スクリーンタイムの許可 | 許可対象を明示 |
| `settings.authorization.allow` | 許可する | keep | — | 意味と対象が明確 |
| `settings.authorization.denied_body` | 許可がないため、SNSを開く前の確認はまだ使えません。設定からいつでも有効にできます。 | rewrite | スクリーンタイムが未許可のため開く前の一呼吸を使えません 設定からいつでも許可できます | 確認を一呼吸に統一 |
| `settings.authorization.body` | 選んだSNSを開こうとした瞬間に確認画面を出すために、iOSのスクリーンタイムを使います。使用データは端末内に保存されます。 | rewrite | 選んだアプリを開く前に一呼吸を出すためスクリーンタイムを使います 利用データは端末内に保存されます | SNSと確認画面を具体化 |
| `settings.selection.app_count` | アプリ%lld個 | keep | — | 意味と対象が明確 |
| `settings.selection.category_count` | カテゴリ%lld個 | keep | — | 意味と対象が明確 |
| `settings.selection.website_count` | Webサイト%lld個 | keep | — | 意味と対象が明確 |
| `settings.error.data_load` | データを読み込めませんでした | keep | — | 意味と対象が明確 |
| `settings.usage_watch.interval.minutes_format` | %lld分ごと | keep | — | 意味と対象が明確 |
| `settings.error.data_save` | データを保存できませんでした | keep | — | 意味と対象が明確 |

### target_picker

| key | 現行ja | keep/rewrite | 提案ja | 理由(8語以内) |
|---|---|---|---|---|
| `target_app_picker.title` | 止めるアプリを選ぶ | keep | — | 意味と対象が明確 |
| `target_app_picker.description` | 開こうとした瞬間に一呼吸を出したいアプリを選びます。 | keep | — | 意味と対象が明確 |
| `target_app_picker.action.close` | 閉じる | keep | — | 意味と対象が明確 |
| `target_app_picker.limit.free` | 無料プランでは1つまで | keep | — | 意味と対象が明確 |
| `target_app_picker.error.save` | 保存できませんでした | keep | — | 意味と対象が明確 |

TOTAL 186 REWRITE 42

exec
/bin/zsh -lc "python3 - <<'PY'
sections = {
'phase2-new': [
('stats.title','記録','keep','—','内容を直接表す'),
('stats.period.week','今週','keep','—','期間が明確'),
('stats.period.today','今日','keep','—','期間が明確'),
('stats.period.all','全期間','keep','—','期間が明確'),
('stats.apps.title','アプリ別','rewrite','アプリごと','Phase 1語彙に統一'),
('stats.apps.empty','まだアプリ別の記録がありません','rewrite','まだアプリごとの記録がありません','見出し語彙に統一'),
('stats.reflection.title','開いた後の気持ち','rewrite','見たあとの気持ち','確定語彙に統一'),
('stats.intent.title','開こうとした理由','keep','—','内容を直接表す'),
('stats.apps.ratio','%lld/%lld','keep','—','書式のみで明確'),
],
'phase3-new': [
('settings.status.title','いまの守り','rewrite','止める設定','抽象的な造語を排除'),
('settings.entry.notifications','通知','keep','—','遷移先が明確'),
('settings.entry.lock_surface','ロック画面の表示','keep','—','内容を直接表す'),
('settings.entry.pro','DopaBreak Pro','keep','—','正式なプラン名'),
('settings.entry.about','プライバシーと情報','rewrite','プライバシーとアプリ情報','情報の対象を明示'),
('settings.timeline.wake','起床','keep','—','時点が明確'),
('settings.timeline.sleep','就寝','keep','—','時点が明確'),
('settings.automation.configured','設定済み','keep','—','状態が明確'),
('settings.automation.not_configured','未設定','keep','—','状態が明確'),
('settings.summary.more','ほか%lld件','keep','—','省略数が明確'),
('settings.status.summary（表示例）','標準 ・ 一呼吸 3秒','rewrite','開く前に3秒待つ','モード名だけで説明しない'),
('settings.notifications.summary（表示例）','朝の目標 ・ 週次','rewrite','朝に目標を通知 ・ 毎週の記録を通知','週次と省略語を排除'),
('settings.timeline.summary（表示例）','0:00 ／ 7:00 起床 ／ 23:00 就寝','keep','—','時刻と意味が明確'),
],
'phase4-new': [
('goals.preview.title','開こうとした瞬間に見える。','rewrite','ロック画面の表示','短い見出しの句点を排除'),
('goals.badge.on_lock_screen','ロック画面に表示中','keep','—','状態が明確'),
('goals.footer.unlimited','目標は何件でも追加できます','rewrite','目標は何個でも追加できます','既存の数え方に統一'),
],
}
for name, rows in sections.items():
    print(f'### {name}\\n')
    print('| key | 現行ja | keep/rewrite | 提案ja | 理由(8語以内) |')
    print('|---|---|---|---|---|')
    for row in rows:
        print('| "'`'"' + row[0] + '"'` | '"' + ' | '.join(row[1:]) + ' |')
    print()
print('rows', sum(map(len, sections.values())), 'rewrites', sum(1 for rows in sections.values() for r in rows if r[2]=='rewrite'))
PY" in /Users/solotech/Desktop/test-project
 succeeded in 0ms:
### phase2-new

| key | 現行ja | keep/rewrite | 提案ja | 理由(8語以内) |
|---|---|---|---|---|
| `stats.title` | 記録 | keep | — | 内容を直接表す |
| `stats.period.week` | 今週 | keep | — | 期間が明確 |
| `stats.period.today` | 今日 | keep | — | 期間が明確 |
| `stats.period.all` | 全期間 | keep | — | 期間が明確 |
| `stats.apps.title` | アプリ別 | rewrite | アプリごと | Phase 1語彙に統一 |
| `stats.apps.empty` | まだアプリ別の記録がありません | rewrite | まだアプリごとの記録がありません | 見出し語彙に統一 |
| `stats.reflection.title` | 開いた後の気持ち | rewrite | 見たあとの気持ち | 確定語彙に統一 |
| `stats.intent.title` | 開こうとした理由 | keep | — | 内容を直接表す |
| `stats.apps.ratio` | %lld/%lld | keep | — | 書式のみで明確 |

### phase3-new

| key | 現行ja | keep/rewrite | 提案ja | 理由(8語以内) |
|---|---|---|---|---|
| `settings.status.title` | いまの守り | rewrite | 止める設定 | 抽象的な造語を排除 |
| `settings.entry.notifications` | 通知 | keep | — | 遷移先が明確 |
| `settings.entry.lock_surface` | ロック画面の表示 | keep | — | 内容を直接表す |
| `settings.entry.pro` | DopaBreak Pro | keep | — | 正式なプラン名 |
| `settings.entry.about` | プライバシーと情報 | rewrite | プライバシーとアプリ情報 | 情報の対象を明示 |
| `settings.timeline.wake` | 起床 | keep | — | 時点が明確 |
| `settings.timeline.sleep` | 就寝 | keep | — | 時点が明確 |
| `settings.automation.configured` | 設定済み | keep | — | 状態が明確 |
| `settings.automation.not_configured` | 未設定 | keep | — | 状態が明確 |
| `settings.summary.more` | ほか%lld件 | keep | — | 省略数が明確 |
| `settings.status.summary（表示例）` | 標準 ・ 一呼吸 3秒 | rewrite | 開く前に3秒待つ | モード名だけで説明しない |
| `settings.notifications.summary（表示例）` | 朝の目標 ・ 週次 | rewrite | 朝に目標を通知 ・ 毎週の記録を通知 | 週次と省略語を排除 |
| `settings.timeline.summary（表示例）` | 0:00 ／ 7:00 起床 ／ 23:00 就寝 | keep | — | 時刻と意味が明確 |

### phase4-new

| key | 現行ja | keep/rewrite | 提案ja | 理由(8語以内) |
|---|---|---|---|---|
| `goals.preview.title` | 開こうとした瞬間に見える。 | rewrite | ロック画面の表示 | 短い見出しの句点を排除 |
| `goals.badge.on_lock_screen` | ロック画面に表示中 | keep | — | 状態が明確 |
| `goals.footer.unlimited` | 目標は何件でも追加できます | rewrite | 目標は何個でも追加できます | 既存の数え方に統一 |

rows 25 rewrites 9

exec
/bin/zsh -lc "python3 - <<'PY'
import re
from pathlib import Path
for p in ['.claude/specs/functional-screens-redesign-phase2-brief.md','.claude/specs/functional-screens-redesign-phase3-brief.md','.claude/specs/functional-screens-redesign-phase4-brief.md']:
  print('\\n##',Path(p).name)
  text=Path(p).read_text()
  for i,line in enumerate(text.splitlines(),1):
    vals=re.findall(r'「(["'^」]+)」'"',line)
    if vals: print(i, ' | '.join(vals))
PY" in /Users/solotech/Desktop/test-project
 succeeded in 0ms:

## functional-screens-redesign-phase2-brief.md
6 記録
8 今週 | 今日 | 全期間 | 今日 | 今週 | 全期間
9 開かなかった割合 | 先週より◯回少ない | 今日 | 全期間
10 開かなかった/開こうとした | まだアプリ別の記録がありません
11 まだ記録がありません
13 全期間
16 毎週のふりかえりを見る | 何が見られるか

## functional-screens-redesign-phase3-brief.md
10 いまの守り | {強さ名} ・ 一呼吸 {秒}秒 | 今日 開かなかった | 残り◯分 ・ いま解除
11 止める強さ
15 設定済み | 未設定
16 起床・就寝時刻 | 夜は完全ブロック
17 朝の目標 ・ 週次 | ほか
18 いますぐ始める | 毎週の予定
19 通知
20 プライバシーと情報 | SNSなどのアプリを止める機能は…
24 ロック画面で確かめる
25 DopaBreak Pro

## functional-screens-redesign-phase4-brief.md
13 目標
16  ・ ロック画面に表示中
17 目標を追加 | 複数追加できることを書く
21 ここで決めた一言が、開こうとした瞬間に表示されます
28 学び

codex
全件判定は完了しました。現在画面は186行中42行を書き換え、ブリーフは新規キーと新しい合成表示26行中10行を書き換える判定です。最後に並行更新の有無、キー件数、ja欠損、提案文の禁止語・句読点を再確認してから表を返します。
exec
/bin/zsh -lc "python3 - <<'PY'
import json
import re
from pathlib import Path

files = [
    Path('ios/DopaBreak/HomeView.swift'), Path('ios/DopaBreak/StatsView.swift'),
    Path('ios/DopaBreak/GoalsView.swift'), Path('ios/DopaBreak/GoalEditorSheet.swift'),
    Path('ios/DopaBreak/SettingsView.swift'), Path('ios/DopaBreak/TargetAppPickerSheet.swift'),
]
expected = [40, 26, 5, 15, 95, 5]
pat_any = re.compile(r'String\\s*\\(\\s*localized:')
pat_key = re.compile(r'String\\s*\\(\\s*localized:\\s*\"(["'^"]+)"'"')
catalog = json.load(open('ios/DopaBreak/Localizable.xcstrings'))
all_keys = []
for path, expected_unique in zip(files, expected):
    source = path.read_text()
    uses = len(pat_any.findall(source))
    keys = pat_key.findall(source)
    unique = list(dict.fromkeys(keys))
    missing_literal = uses - len(keys)
    missing_ja = [k for k in unique if not catalog['strings'].get(k, {}).get('localizations', {}).get('ja', {}).get('stringUnit', {}).get('value')]
    print(path.name, 'uses', uses, 'unique', len(unique), 'nonliteral', missing_literal, 'missing-ja', len(missing_ja), 'expected-ok', len(unique) == expected_unique)
    all_keys.extend(unique)
print('screen-rows', len(all_keys), 'cross-screen-unique', len(set(all_keys)))

proposals = [
'自分で解除するまで','止めるアプリを開いたときに一呼吸が出れば設定完了です',
'今週の記録','今日の記録','今週の内訳','先週との比較','開こうとした回数と開かなかった回数がここに残ります','開かなかった回数と開いた回数','全期間',
'アプリを開こうとしたときに目標が表示されます 例 英語で話せるようになる',
'解除するまで','SNSなどのアプリを止める機能はiPhoneでのみ使えます',
'開く前に必ず一呼吸が入りアプリごとに開ける回数と1回の長さを決められます',
'Proでは止めるアプリのショートカット設定は不要です',
'カテゴリで選んだ分は完全ブロックだけに使います 一呼吸はアプリごとに設定します',
'Proではショートカットなしでアプリごとに開ける回数と1回の長さを決められます',
'就寝前は問いかけの間隔を短く','選んだアプリを2時間続けて使うと1日1回通知します',
'毎週の記録通知','設定確認と記録の通知','ロック画面に目標と記録を表示','表示デザイン','完全ブロックするアプリ',
'予定が終わっても手動で始めた分は続きます','いま解除する','選んだ曜日と時間だけアプリを止めます',
'開始から終了まで15分以上にしてください','完全ブロックでは決めた時間だけ選んだアプリを止められます',
'一呼吸では開く前に待ち時間が入ります 完全ブロックでは決めた時間だけ開けなくなります',
'完全ブロックするアプリを選ぶと決めた時間だけ開けなくなります',
'選んだアプリは就寝から起床まで開けません 昼は開く前に一呼吸が入ります',
'いま止めているアプリはありません 時間を決めると選んだアプリが開けなくなります',
'選んだアプリは決めた時間だけ開けなくなります いますぐ始めるか毎週の予定を設定できます',
'最初の説明をもう一度見る','操作記録をコピー','プランと購入','現在のプラン','スクリーンタイムの許可',
'スクリーンタイムを許可していないため開く前の一呼吸を使えません 設定からいつでも許可できます',
'選んだアプリを開く前に一呼吸を出すためスクリーンタイムを使います 利用データは端末内に保存されます',
'アプリごと','まだアプリごとの記録がありません','見たあとの気持ち','止める設定','プライバシーとアプリ情報',
'一呼吸の長さ 3秒','朝の目標通知 ・ 毎週の記録通知','残り◯分 ・ いま解除する','ロック画面の表示','目標は何個でも追加できます'
]
banned = re.compile(r'介入|シールド|ゲート|守り|見守り|チェックイン|リフレクション')
print('proposal-count', len(proposals))
print('proposal-banned', [p for p in proposals if banned.search(p)])
print('proposal-comma-period', [p for p in proposals if re.search(r'[、。]', p)])
PY
stat -f '%Sm %N' -t '%Y-%m-%d %H:%M:%S' ios/DopaBreak/HomeView.swift ios/DopaBreak/StatsView.swift ios/DopaBreak/GoalsView.swift ios/DopaBreak/GoalEditorSheet.swift ios/DopaBreak/SettingsView.swift ios/DopaBreak/TargetAppPickerSheet.swift ios/DopaBreak/Localizable.xcstrings .claude/specs/functional-screens-redesign-phase2-brief.md .claude/specs/functional-screens-redesign-phase3-brief.md .claude/specs/functional-screens-redesign-phase4-brief.md" in /Users/solotech/Desktop/test-project
 succeeded in 0ms:
HomeView.swift uses 41 unique 40 nonliteral 0 missing-ja 0 expected-ok True
StatsView.swift uses 29 unique 26 nonliteral 0 missing-ja 0 expected-ok True
GoalsView.swift uses 5 unique 5 nonliteral 0 missing-ja 0 expected-ok True
GoalEditorSheet.swift uses 16 unique 15 nonliteral 0 missing-ja 0 expected-ok True
SettingsView.swift uses 114 unique 95 nonliteral 0 missing-ja 0 expected-ok True
TargetAppPickerSheet.swift uses 5 unique 5 nonliteral 0 missing-ja 0 expected-ok True
screen-rows 186 cross-screen-unique 181
proposal-count 50
proposal-banned []
proposal-comma-period []
2026-08-24 16:27:13 ios/DopaBreak/HomeView.swift
2026-08-14 13:20:59 ios/DopaBreak/StatsView.swift
2026-08-17 13:06:17 ios/DopaBreak/GoalsView.swift
2026-08-08 13:45:10 ios/DopaBreak/GoalEditorSheet.swift
2026-08-22 18:23:28 ios/DopaBreak/SettingsView.swift
2026-08-24 15:32:58 ios/DopaBreak/TargetAppPickerSheet.swift
2026-08-24 16:24:35 ios/DopaBreak/Localizable.xcstrings
2026-08-22 15:37:53 .claude/specs/functional-screens-redesign-phase2-brief.md
2026-08-22 15:40:36 .claude/specs/functional-screens-redesign-phase3-brief.md
2026-08-22 15:41:18 .claude/specs/functional-screens-redesign-phase4-brief.md

codex
最終走査時点（2026-08-24 16:27 JST）で、6画面210利用箇所・画面内重複除外186行を確認しました。ja欠損は0件、現行42行・ブリーフ10行を rewrite 判定しました。Phase 1確定語彙は再提案していません。`（表示例）` は実キーではなくブリーフ上の合成文言です。
