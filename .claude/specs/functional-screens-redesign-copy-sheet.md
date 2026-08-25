# 機能画面リデザイン コピーシート（2026-08-24）

正本。実装はこの表の文言を一字一句そのまま使う（defaultValue = ja）。原則: 見出し・ラベルは中身そのものを平易な名詞で・造語/英語eyebrow/内部用語禁止・短い表示コピーに読点句点なし・CTAに金額なし。

## Phase 1 新規・変更キー

| キー | ja | en | ko | 備考 |
|---|---|---|---|---|
| home.hero.today（変更） | 今日 ・ %@ | Today ・ %@ | 오늘 ・ %@ | 英語eyebrow廃止。%@=日付 |
| home.week.eyebrow（変更・旧THIS WEEK） | 今週 | This week | 이번 주 | |
| home.streak.days | 連続 %lld日 | %lld days in a row | 연속 %lld일 | チップ |
| home.reclaimed.title | 取り戻した時間 | Time you got back | 되찾은 시간 | eyebrow |
| home.reclaimed.week_label | 今週 | this week | 이번 주 | 数字の添え |
| home.reclaimed.yearly | この調子なら1年で約 %@日分 | About %@ days a year at this pace | 이 속도라면 1년에 약 %@일 | 条件付き表現を外さない |
| home.reclaimed.minutes | %lld分 | %lld min | %lld분 | 書式 |
| home.reclaimed.hours_minutes | %lld時間%lld分 | %lld hr %lld min | %lld시간 %lld분 | 書式 |
| home.targets.title | 止めているアプリ | Apps you're pausing | 멈춰 둔 앱 | eyebrow・設定画面の語彙に一致 |
| home.targets.empty | 止めるアプリを選ぶ | Choose apps to pause | 멈출 앱 고르기 | |
| home.targets.breath_line | 開く前に%lld秒の間が入ります | A %lld-second pause comes before they open | 열기 전에 %lld초 간격이 생겨요 | |
| home.targets.night_line | %@から朝まで開けません | Closed from %@ until morning | %@부터 아침까지 열 수 없어요 | 夜だけ強化ON時のみ |
| home.targets.focus_running | あと%@ 開けません | Closed for another %@ | 앞으로 %@ 동안 열 수 없어요 | Deep Focus/夜間実行中 |
| home.targets.focus_30 | 30分だけ開けなくする | Close them for 30 minutes | 30분만 열 수 없게 하기 | ボタン・金額なし |
| home.targets.focus_end | いま解除する | Unlock now | 지금 해제하기 | 実行中の差し替えボタン |
| home.apps.title | アプリごと | By app | 앱별 | eyebrow |
| home.apps.legend | 今日：開くのをやめた / 開こうとした | Today: chose not to open / tried to open | 오늘: 열지 않기로 함 / 열려고 함 | 注記 |
| home.apps.ratio | %lld / %lld | %lld / %lld | %lld / %lld | 書式のみ |
| home.reflection.top | 「%@」が多め | Mostly “%@” | ‘%@’가 많아요 | %@=満足度ラベル |
| home.reflection.count | 今週の%lld回中 %lld回 | %2$lld of %1$lld this week | 이번 주 %lld회 중 %lld회 | |

## 再利用（変更しない既存キー）
`home.hero.week_count` `home.achievement.summary` `stats.weekly_detail.comparison.less/more` `reflection.satisfaction.title` `reflection.satisfaction.*`（満足度ラベル）`stats.paywall.weekly_report` `settings.breath_duration.*`。

## オーナー訂正（2026-08-24・後勝ち）

「開かなかった」は目的語と意思決定が曖昧なため、画面表示では「開くのをやめた」に統一する。内部の `cancelled` 名・保存形式・集計ロジックは変更しない。

| キー | ja | en | ko |
|---|---|---|---|
| `home.achievement.title` | 開くのをやめた | Chose not to open | 열지 않기로 함 |
| `home.first_day.body` | 開くのをやめた回数がここに残ります | The times you choose not to open are recorded here | 열지 않기로 한 횟수가 여기에 남아요 |
| `home.week.summary` | 今週は%lld回、開くのをやめました | Chose not to open %lld times this week | 이번 주에는 %lld번 열지 않기로 했어요 |
| `stats.metric.cancelled` | 開くのをやめた | Chose not to open | 열지 않기로 함 |
| `stats.rate.title` | 開くのをやめた割合 | How often you chose not to open | 열지 않기로 한 비율 |

同じ集計を示すオンボーディング、介入成功、通知、ロック画面確認、Widget / Live Activityも同じ行動語彙を使う。文章内では助詞を補い「今週は%lld回、開くのをやめました」のように自然な文へする。

## Phase 2〜4・既存文言の書き換え

`copy-audit-2026-08-24.md` の最終提案を正本とし、`goals.preview.title` のみ Fable 裁定を優先する。既存 rewrite 42行、Phase 2〜4の新規22キー、rewrite 対象の合成表示例3行の計67行。合成表示例は実キーではなく、実装時は既存キーの組み合わせで作る。

### Home

| キー | ja | en | ko | 備考 |
|---|---|---|---|---|
| `settings.deep_focus.session.open_ended.label` | 自分で解除するまで | Until you unblock it | 직접 해제할 때까지 | 既存書き換え・Homeでも使用。Settingsに再掲 |
| `home.automation_status.body` | 止めるアプリを開いたときに一呼吸が出れば設定完了です | Setup is complete if one breath appears when you try to open an app to pause | 멈출 앱을 열려고 할 때 한 호흡이 뜨면 설정 완료예요 | 既存書き換え |

### Stats

| キー | ja | en | ko | 備考 |
|---|---|---|---|---|
| `stats.header.week.title` | 今週の記録 | This week's record | 이번 주 기록 | 既存書き換え |
| `stats.summary.today.label` | 今日の記録 | Today's record | 오늘의 기록 | 既存書き換え |
| `stats.summary.week.label` | 今週の記録 | This week's record | 이번 주 기록 요약 | 既存書き換え・要約ラベル |
| `stats.weekly_detail.label` | 今週の内訳 | This week's breakdown | 이번 주 내역 | 既存書き換え |
| `stats.weekly_detail.comparison.label` | 先週との比較 | Compared with last week | 지난주와 비교 | 既存書き換え |
| `stats.empty.description` | 開こうとした回数と、開くのをやめた回数がここに残ります | The times you tried to open and chose not to open are recorded here | 열려고 한 횟수와 열지 않기로 한 횟수가 여기에 남아요 | 既存書き換え |
| `stats.behavior.label` | 開くのをやめた回数と開いた回数 | Times you chose not to open and times you opened | 열지 않기로 한 횟수와 연 횟수 | 既存書き換え |
| `stats.all_time.label` | 全期間 | All time | 전체 기간 | 既存書き換え |
| `stats.title` | 記録 | Records | 기록 | Phase 2 新規 |
| `stats.period.week` | 今週 | This week | 이번 주 | Phase 2 新規 |
| `stats.period.today` | 今日 | Today | 오늘 | Phase 2 新規 |
| `stats.period.all` | 全期間 | All time | 전체 기간 | Phase 2 新規 |
| `stats.apps.title` | アプリごと | By app | 앱별 | Phase 2 新規・監査案で改稿 |
| `stats.apps.empty` | まだアプリごとの記録がありません | No records by app yet | 아직 앱별 기록이 없어요 | Phase 2 新規・監査案で改稿 |
| `stats.reflection.title` | 見たあとの気持ち | How you felt after scrolling | 보고 난 뒤의 기분 | Phase 2 新規・監査案で改稿 |
| `stats.intent.title` | 開こうとした理由 | Why you tried to open | 열려고 한 이유 | Phase 2 新規 |
| `stats.apps.ratio` | %lld/%lld | %lld/%lld | %lld/%lld | Phase 2 新規・書式 |

### Goals

| キー | ja | en | ko | 備考 |
|---|---|---|---|---|
| `goals.empty.description` | アプリを開こうとしたときに目標が表示されます 例 英語で話せるようになる | Your goal appears when you try to open an app. Example: Learn to speak English | 앱을 열려고 할 때 목표가 표시돼요. 예: 영어로 말할 수 있게 되기 | 既存書き換え |
| `goals.preview.title` | 開こうとした瞬間に見える画面 | Screen shown when you try to open | 열려고 할 때 보이는 화면 | Phase 4 新規・Fable裁定。`settings.entry.lock_surface` との重複を回避 |
| `goals.badge.on_lock_screen` | ロック画面に表示中 | Showing on the Lock Screen | 잠금 화면에 표시 중 | Phase 4 新規 |
| `goals.footer.unlimited` | 目標は何個でも追加できます | Add as many goals as you like | 목표를 원하는 만큼 추가할 수 있어요 | Phase 4 新規・監査案で改稿 |

### Settings

| キー | ja | en | ko | 備考 |
|---|---|---|---|---|
| `settings.deep_focus.session.option.until_stopped` | 解除するまで | Until you unblock it | 해제할 때까지 | 既存書き換え |
| `settings.device_only_note` | SNSなどのアプリを止める機能はiPhoneでのみ使えます | You can pause apps such as social media only on iPhone | SNS 같은 앱을 멈추는 기능은 iPhone에서만 사용할 수 있어요 | 既存書き換え |
| `settings.gate.description` | 開く前に必ず一呼吸が入りアプリごとに開ける回数と1回の長さを決められます | One breath always appears before opening and you can set how many times each app can be opened and how long each opening lasts | 열기 전에 항상 한 호흡이 들어가며 앱마다 열 수 있는 횟수와 한 번 열 때의 시간을 정할 수 있어요 | 既存書き換え |
| `settings.gate.automation_note` | Proでは止めるアプリのショートカット設定は不要です | Pro does not require a Shortcuts setup for apps to pause | Pro에서는 멈출 앱에 단축어 설정이 필요하지 않아요 | 既存書き換え・監査最終案 |
| `settings.gate.category_note` | カテゴリで選んだ分は完全ブロックだけに使います 一呼吸はアプリごとに設定します | Category selections work only with full block. Set one breath for each app | 카테고리 선택은 완전 차단에만 사용해요. 한 호흡은 앱마다 설정해요 | 既存書き換え・監査最終案 |
| `settings.gate.locked_notice` | Proではショートカットなしでアプリごとに開ける回数と1回の長さを決められます | With Pro you can set how many times each app can open and how long each opening lasts without Shortcuts | Pro에서는 단축어 없이 앱마다 열 수 있는 횟수와 한 번 열 때의 시간을 정할 수 있어요 | 既存書き換え |
| `settings.usage_watch.night_mode.title` | 就寝前は問いかけの間隔を短く | Shorter check-in intervals before bed | 취침 전에는 확인 간격 줄이기 | 既存書き換え |
| `settings.usage_watch.free_rule.description` | 選んだアプリを2時間続けて使うと1日1回通知します | Notify once a day after you use selected apps for 2 hours straight | 선택한 앱을 2시간 연속 사용하면 하루에 한 번 알려드려요 | 既存書き換え |
| `settings.lock_screen.weekly_report` | 毎週の記録通知 | Weekly record notification | 매주 기록 알림 | 既存書き換え |
| `settings.notifications.retention_support.title` | 設定確認と記録の通知 | Setup checks and record notifications | 설정 확인 및 기록 알림 | 既存書き換え |
| `settings.lock_screen.live_activity` | ロック画面に目標と記録を表示 | Show goals and records on the Lock Screen | 잠금 화면에 목표와 기록 표시 | 既存書き換え |
| `settings.lock_screen.theme` | 表示デザイン | Display style | 화면 디자인 | 既存書き換え |
| `settings.deep_focus.targets.label` | 完全ブロックするアプリ | Apps to fully block | 완전 차단할 앱 | 既存書き換え |
| `settings.deep_focus.schedule.active.session_notice` | 予定が終わっても手動で始めた分は続きます | A manually started session continues after the schedule ends | 예약이 끝나도 수동으로 시작한 차단은 계속돼요 | 既存書き換え |
| `settings.deep_focus.session.stop.action` | いま解除する | Unblock now | 지금 해제하기 | 既存書き換え・Phase 1語彙 |
| `settings.deep_focus.session.open_ended.label` | 自分で解除するまで | Until you unblock it | 직접 해제할 때까지 | 既存書き換え・Homeにも掲載 |
| `settings.deep_focus.schedule.no_weekday_notice` | 選んだ曜日と時間だけアプリを止めます | Pause apps only on selected days and times | 선택한 요일과 시간에만 앱을 멈춰요 | 既存書き換え |
| `settings.deep_focus.schedule.too_short_notice` | 開始から終了まで15分以上にしてください | Set at least 15 minutes between the start and end | 시작과 종료 사이를 15분 이상 띄워 주세요 | 既存書き換え |
| `settings.deep_focus.locked_notice` | 完全ブロックでは決めた時間だけ選んだアプリを止められます | Full block lets you pause selected apps for the times you set | 완전 차단에서는 정한 시간 동안 선택한 앱을 멈출 수 있어요 | 既存書き換え |
| `settings.deep_focus.standard_notice` | 一呼吸では開く前に待ち時間が入ります 完全ブロックでは決めた時間だけ開けなくなります | One breath adds a wait before opening. Full block keeps apps from opening for the times you set | 한 호흡은 열기 전에 대기 시간을 두어요. 완전 차단은 정한 시간 동안 앱을 열 수 없게 해요 | 既存書き換え・監査最終案 |
| `settings.deep_focus.empty_targets_notice` | 完全ブロックするアプリを選ぶと決めた時間だけ開けなくなります | Choose apps to fully block and they won't open for the times you set | 완전 차단할 앱을 고르면 정한 시간 동안 열 수 없어요 | 既存書き換え |
| `settings.night_only.description` | 選んだアプリは就寝から起床まで開けません 昼は開く前に一呼吸が入ります | Selected apps can't be opened from bedtime to wake time. During the day one breath appears before opening | 선택한 앱은 취침 시각부터 기상 시각까지 열 수 없어요. 낮에는 열기 전에 한 호흡이 들어가요 | 既存書き換え |
| `settings.deep_focus.no_window_notice` | いま止めているアプリはありません 時間を決めると選んだアプリが開けなくなります | No apps are paused right now. Set a time and selected apps won't open | 지금 멈춰 둔 앱은 없어요. 시간을 정하면 선택한 앱이 열리지 않아요 | 既存書き換え・監査最終案 |
| `settings.deep_focus.description` | 選んだアプリは決めた時間だけ開けなくなります いますぐ始めるか毎週の予定を設定できます | Selected apps won't open for the times you set. Start now or set a weekly schedule | 선택한 앱은 정한 시간 동안 열 수 없어요. 지금 시작하거나 매주 예약을 설정할 수 있어요 | 既存書き換え・監査最終案 |
| `settings.debug.replay_onboarding` | 最初の説明をもう一度見る | See the introduction again | 처음 안내 다시 보기 | 既存書き換え |
| `settings.debug.copy_event_log` | 操作記録をコピー | Copy activity history | 활동 기록 복사 | 既存書き換え |
| `settings.account.section` | プランと購入 | Plan and purchases | 플랜 및 구매 | 既存書き換え |
| `settings.account.pro_status` | 現在のプラン | Current plan | 현재 플랜 | 既存書き換え |
| `settings.authorization.title` | スクリーンタイムの許可 | Screen Time permission | 스크린 타임 권한 | 既存書き換え |
| `settings.authorization.denied_body` | スクリーンタイムを許可していないため開く前の一呼吸を使えません 設定からいつでも許可できます | One breath before opening is unavailable without Screen Time permission. You can grant permission anytime in Settings | 스크린 타임 권한이 없어 열기 전 한 호흡을 사용할 수 없어요. 설정에서 언제든 허용할 수 있어요 | 既存書き換え・監査最終案 |
| `settings.authorization.body` | 選んだアプリを開く前に一呼吸を出すためスクリーンタイムを使います 利用データは端末内に保存されます | We use Screen Time to show one breath before you open selected apps. Usage data stays on your device | 선택한 앱을 열기 전에 한 호흡을 띄우기 위해 스크린 타임을 사용해요. 이용 데이터는 기기 안에 저장돼요 | 既存書き換え |
| `settings.status.title` | 止める設定 | Pause settings | 멈춤 설정 | Phase 3 新規・監査案で改稿 |
| `settings.entry.notifications` | 通知 | Notifications | 알림 | Phase 3 新規 |
| `settings.entry.lock_surface` | ロック画面の表示 | Lock Screen display | 잠금 화면 표시 | Phase 3 新規 |
| `settings.entry.pro` | DopaBreak Pro | DopaBreak Pro | DopaBreak Pro | Phase 3 新規・製品名維持 |
| `settings.entry.about` | プライバシーとアプリ情報 | Privacy and app info | 개인정보 및 앱 정보 | Phase 3 新規・監査案で改稿 |
| `settings.timeline.wake` | 起床 | Wake | 기상 | Phase 3 新規 |
| `settings.timeline.sleep` | 就寝 | Bedtime | 취침 | Phase 3 新規 |
| `settings.automation.configured` | 設定済み | Set up | 설정 완료 | Phase 3 新規・既存自動化語彙 |
| `settings.automation.not_configured` | 未設定 | Not set up | 미설정 | Phase 3 新規・既存自動化語彙 |
| `settings.summary.more` | ほか%lld件 | %lld more | 외 %lld건 | Phase 3 新規・書式 |
| `settings.status.summary（表示例）` | 一呼吸の長さ 3秒 | One breath ・ 3 seconds | 한 호흡 길이 3초 | Phase 3 合成表示例・実キーではない・監査最終案 |
| `settings.notifications.summary（表示例）` | 朝の目標通知 ・ 毎週の記録通知 | Morning goal notification ・ Weekly record notification | 아침 목표 알림 ・ 매주 기록 알림 | Phase 3 合成表示例・実キーではない・監査最終案 |
| `settings.status.summary（Deep Focus実行中の表示例）` | 残り◯分 ・ いま解除する | ◯ min left ・ Unblock now | ◯분 남음 ・ 지금 해제하기 | Phase 3 合成表示例・実キーではない・Deep Focus名維持 |

## 検証記録
- ja: humanizer-jp 23パターン照合 — 読点0・句点0（本文注記の「/」区切りは可）・造語なし・体言止めはラベル用途のみ。英語構文カルク4テスト実施済み（「取り戻した時間」「開けません」は日本語話者の自然な述語）
- en / ko: `humanizer-en/scripts/audit.py`・`humanizer-ko/scripts/audit.py` を新規セット全文で実行し exit 0 を確認してから実装に渡す（結果は下に追記）

### 監査結果（2026-08-24）
- en: `humanizer-en/scripts/audit.py` 全ゲートPASS・exit 0（新規16行・UIラベルのため短文警告のみ）
- ko: `humanizer-ko/scripts/audit.py` 전 게이트 통과・exit 0（번역투0・이중피동0）
- ja: humanizer-jp照合済み（読点0・造語0）

### 監査結果（Phase 2〜4・既存書き換え、2026-08-24）
- 対象: 67行（既存 rewrite 42行・Phase 2〜4新規22キー・rewrite合成表示例3行）。監査用テキストは en / ko とも1文言1行とし、各行末にピリオドを付与
- en: `humanizer-en/scripts/audit.py` exit 0・全ゲートPASS（AI vocabulary 0・em/en dash 0・chat artifacts 0・15〜28語帯5.4%・56文・平均7.6語・SD 4.34・最小3・最大24）
- ko: `humanizer-ko/scripts/audit.py` exit 0・전 게이트 통과（번역투0・이중피동・AI 도입/결론 정형各0・同一終止最大連続2・65文・平均18.1字・SD 11.07・最小6・最大57）

## 追記（2026-08-24・オーナー指摘）: Freeぼかし解放CTAの差し替え
`stats.paywall.weekly_report` の「毎週のふりかえりを詳しく見られる」は不自然かつ課金誘導になっていないため差し替え（Home・Statsの統合CTAで共用）。

| キー | ja | en | ko | 備考 |
|---|---|---|---|---|
| stats.paywall.weekly_report（値変更） | 記録を全部見る | See all your stats | 기록 전부 보기 | 行動＋ベネフィット・金額なし・鍵アイコンは既存のまま |

## 追記（2026-08-25・恒久ルール違反の是正）: 週/日サマリーのリズム読点除去
「自然な文章にする」訂正の際に短い表示コピーへリズム読点を入れてしまった（オーナー恒久指示違反・2026-07-29の2度目指摘と同型）。区切りは半角スペース。

| キー | ja（正） | en | ko | 備考 |
|---|---|---|---|---|
| home.week.summary | 今週は%lld回 開くのをやめました | Chose not to open %lld times this week | 이번 주에는 %lld번 열지 않기로 했어요 | スクショ04に写る |
| lock_check.preview.cancelled | 今日は%lld回 開くのをやめました | （既存のまま） | （既存のまま） | スクショ07に写る・LockScreenCheckView側はa4が同梱 |

## 追記（2026-08-25）: ロック画面テーマ既定名の内部コード露出是正
`LockScreenTheme.e1.displayName` が「E1」（内部コード名）でUIとスクショ09に露出。他テーマと同じ平易な命名へ。
| 対象 | 旧 | 新 | 備考 |
|---|---|---|---|
| LockScreenTheme.e1 displayName（Core・ハードコード） | E1 | 黒とライム | 見た目そのもの（黒地＋ライム）。列挙子名・保存値は不変。※テーマ名はCore内ja固定でen/ko未ローカライズ（既存課題・今回対象外） |
