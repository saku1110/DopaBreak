# マーケティング戦略

作成日: 2026-06-27

## 1. 戦略サマリー

GoalGateのマーケティングは、スクリーンタイム管理市場の中で「禁止」ではなく「意図確認と利用後の気づき」に寄せる。

最新のDopaBreak方針では、自己啓発/アファメーションよりも「SNS依存を減らして深く集中する」価値を前面に出す。利用後リフレクションは、スクリーンタイム系アプリを使っても続かなかった人に対して、「禁止」ではなく「SNS後の実感を見て自分で減らす」訴求として使う。

主張:

> SNSを開く前に、あなたの目標を思い出す。

DopaBreak版の主張:

> SNSを開く前に止まり、見た後に本当に満たされたかを知る。

90日間の重点:

1. 日本語MVPで「小型ロック画面ウィジェットの複数設置」と「介入継続」を検証する。
2. TikTok/Reels/Xで、添付画像のような開く前の介入体験を短尺で見せる。
3. ASOは「スマホ依存」「スクリーンタイム」「目標達成」「集中」「デジタルデトックス」を分けて検証する。
4. 利用後リフレクションで「SNSを見ても何も得られなかった」と気づく体験を訴求する。

## 2. ポジショニング

### Category Claim

目標に戻るスクリーンタイムアプリ。

### Tagline候補

- SNSを開く前に、目標を思い出す。
- スマホを、理想の自分に戻る入口に。
- 無意識の1タップを、意図ある選択に。
- 開く前に一呼吸。戻る先は、あなたの目標。
- SNSを見た後の自分に、正直になる。
- 開く前に止まり、見た後に気づく。
- そのSNS時間は、本当に満たされた？

### Avoid

- 願いが叶う
- 依存症が治る
- 人生が変わる
- 脳を書き換える

### Use

- 目標を思い出す
- 意図的に使う
- 無意識スクロールを減らす
- 自分の時間を取り戻す
- 見た後の満足感を記録する
- SNS後の気分を見える化する
- 自分でやめたくなる

## 3. AARRR戦略

### Acquisition

| チャネル | 目的 | 実行内容 |
| --- | --- | --- |
| TikTok/Reels/Shorts | 体験理解 | 「Xを開こうとしたら目標が出る」実演動画 |
| X | 早期ユーザー獲得 | スマホ依存、作業集中、目標達成文脈で投稿 |
| App Store Search | 顕在層獲得 | スクリーンタイム/スマホ依存/目標達成系キーワード |
| インフルエンサー | 信頼形成 | 勉強垢、副業垢、筋トレ垢、美容垢、自己啓発系 |
| SEO/LP | 説明需要 | 「スマホ依存 対策」「SNS 時間 減らす」「目標 ウィジェット」記事 |

### Activation

初回体験は3分以内に価値を出す。

1. 目標を1つ作る
2. 制限したいアプリを1つ選ぶ
3. 介入文言を選ぶ
4. ウィジェットを追加する
5. テスト介入を体験する

Activation完了条件:

- `primary_goal_created = true`
- `blocked_app_count >= 1`
- `widget_setup_started = true`
- `test_intervention_completed = true`

### Retention

| タイミング | 施策 |
| --- | --- |
| D0 | セットアップ完了後に小型ロック画面ウィジェットの追加を案内。1件は大きく、複数は小さく表示できることを見せる |
| D1 | 昨日の開こうとした回数/止まれた回数を通知 |
| D3 | 「あなたが一番SNSを開きやすい時間」を提示 |
| D7 | 週次レポートと次週の目標更新 |
| D14 | Deep Focusテーマと夜のSNSオフ設定を提案 |
| D30 | Before/Afterレポート |

利用後リフレクションをRetentionの中心にする。

| タイミング | 施策 |
| --- | --- |
| 利用時間終了時 | 「SNSを見てどうだった？」を1問だけ表示 |
| DopaBreak復帰時 | 直前のSNS利用について短く振り返る |
| 夜 | その日の「何も得られなかったSNS時間」をまとめる |
| D7 | 「SNS後の幸福感が増えた/減った」比率を週次で見せる |

### Referral

共有されるのは「使用制限」ではなく「取り戻した時間」と「止まれた回数」。

共有導線:

- 今日SNSを開くのをやめた回数
- 1週間で取り戻した時間
- 取り戻した時間カード
- 友達と「夜のSNSオフ」チャレンジ

### Revenue

課金タイミング:

1. 2個目の対象アプリを追加するとき
2. ロック画面に2個目以降の目標ウィジェット、または1つのウィジェット内の複数目標表示を設定するとき
3. 週次レポート詳細を見るとき
4. 厳格モードを使うとき
5. Deep Focusテーマやロック画面表示をカスタムするとき
6. 利用後リフレクションの詳細分析を見るとき

## 4. 国別戦略

### Japan First

狙う理由:

- 日本語圏では「スマホ依存対策」と「目標達成/習慣化」の検索意図が明確。
- one secは日本でも使われているが、利用後リフレクションとロック画面の戻る先表示との接続はまだ弱い。
- ユーザー自身の言語で目標や意図を表示する体験が重要。

訴求:

- 「SNSを開く前に、今日の目標を思い出す」
- 「スマホ依存対策を、根性ではなく仕組みで」
- 「小さなロック画面ウィジェットで、戻る先を忘れない」

初期チャネル:

- TikTok: 勉強垢、副業垢、筋トレ垢、美容垢
- X: 仕事術、スマホ依存、集中、習慣化
- App Store: `スマホ依存`, `スクリーンタイム`, `アプリ制限`, `集中`, `目標達成`, `習慣化`, `デジタルデトックス`

価格:

- 月額 780円
- 年額 4,980円（7日無料・デフォルト。2026-07-02確定 → doc01 §8）
- Lifetime 14,800円

### United States

狙う理由:

- 自己啓発、ADHD、dopamine detox、digital wellbeing の市場が大きい。
- 競合が強いため、米国は日本MVPで勝ち筋を確認後に展開する。

訴求:

- "Pause before you scroll."
- "Your goals, before your feed."
- "Turn impulse opens into intentional choices."

チャネル:

- TikTok creator ads
- Productivity YouTubers
- Reddit: r/productivity, r/nosurf, r/getdisciplined
- App Store Search Ads

価格:

- Monthly $5.99
- Annual $34.99（7日無料・デフォルト。2026-07-02確定 → doc01 §8）
- Lifetime $99.99

### South Korea

狙う理由:

- SNS利用密度が高く、美容/勉強/キャリア/自己改善文脈が強い。
- 名言/モチベーション系アプリの受容性がある。

訴求:

- 勉強、外見管理、キャリア、恋愛、自己管理のテンプレートをローカライズ。
- UIは日本よりもさらに美的/カスタム性重視。

チャネル:

- TikTok
- Instagram Reels
- Studygram / planner系インフルエンサー

### Germany / UK

狙う理由:

- デジタルウェルビーイング、プライバシー、科学的介入に反応しやすい。
- ただしone secが強いため後発展開。

訴求:

- Evidence-based self-nudge
- Privacy-first, on-device
- Intentional use, not forced blocking

## 5. App Store戦略

### 日本語タイトル候補

30文字以内を目安に調整。

- GoalGate - スマホ依存対策
- GoalGate - 目標リマインダー
- 目標ゲート - SNS時間を減らす

### サブタイトル候補

- SNSを開く前に目標を確認
- スクリーンタイムと習慣化
- 目標達成のためのアプリ制限

### キーワード候補

日本:

- スマホ依存
- スクリーンタイム
- アプリ制限
- SNS制限
- 集中
- 目標達成
- 習慣化
- 深い集中
- SNS制限
- 自己啓発

英語:

- screen time
- app blocker
- focus
- digital detox
- dopamine detox
- goal tracker
- intentional screen time
- deep focus
- intentional
- productivity

## 6. クリエイティブ戦略

### 勝ちやすい動画フォーマット

1. Before/After
   - Before: Xを18回開こうとしている
   - After: 開く前に「英語を話せるようになる」が出る

2. POV
   - 「寝る前にTikTokを開こうとしたら、明日の自分に止められた」

3. Screen recording
   - 実際の介入画面、戻る先の表示、時間選択を見せる

4. Founder story
   - 「自分がSNSで目標を忘れるから作った」

5. Template UGC
   - 勉強用、筋トレ用、美容用、副業用の戻る先表示例

6. After-scroll honesty
   - Before: TikTokを10分見た
   - App: 「SNSを見てどうだった？」
   - User: 「何も得られなかった」を選ぶ
   - After: 週次レポートで「何も得られなかった 62%」を表示

7. Self-realization
   - 「禁止されるからやめる」ではなく、「見た後の自分の答えを見てやめたくなる」構成にする。

### 広告コピー例

- Xを開く前に、今日やるべきことを思い出す。
- SNSを禁止するんじゃなく、意図して使う。
- その1タップ、本当に今必要？
- ロック画面に小さな目標、アプリを開く前に意図確認。
- 無意識スクロールを、目標に戻るきっかけに。
- 見終わった後、「何も得られなかった」と気づける。
- SNS後の満足感を記録すると、自然と開く回数が減っていく。
- 開く前に止める。見た後に振り返る。
- スクリーンタイムで止まれなかった人へ。禁止ではなく、気づきで減らす。

## 7. 90日実行計画

| 期間 | 目的 | 施策 |
| --- | --- | --- |
| Week 1-2 | 基盤 | LP、Waitlist、ブランド仮決め、App Store仮キーワード |
| Week 3-4 | MVP動画 | Figma/プロトタイプ動画を10本投稿、反応を見る |
| Week 5-6 | TestFlight | 50-100人の早期ユーザーを集める |
| Week 7-8 | Activation改善 | オンボーディング、ウィジェット設置率、初回介入を改善 |
| Week 9-10 | 課金検証 | Paywall、年額、Lifetime、価格A/B |
| Week 11-12 | 公開準備 | App Store Listing、PR、インフルエンサー10名、初回レビュー獲得 |

## 8. 計測

| AARRR | 指標 |
| --- | --- |
| Acquisition | LP CVR、App Store CVR、CPI、クリエイティブ別CTR |
| Activation | 目標作成率、対象アプリ設定率、ロック画面ウィジェット設置率、複数ウィジェット設置率、初回介入完了率 |
| Retention | D1/D7/D30、制限ON継続率、介入継続率、利用後リフレクション回答率 |
| Referral | 共有カード作成率、招待率、UGC数 |
| Revenue | Trial開始率、Trial to Paid、ARPPU、解約率、LTV |

利用後リフレクション指標:

- reflection_prompted
- reflection_answered
- reflection_answer_rate
- post_use_satisfaction_distribution
- happiness_delta_distribution
- wasted_time_realization_rate
- reflection_to_stricter_setting_rate

## 9. Launch Checklist

- App Storeスクリーンショット10枚
- 15秒プレビュー動画
- 日本語LP
- 英語LPの最小版
- Privacy Policy / Terms
- TestFlight 100人
- 初回レビュー依頼フロー
- TikTok/Reels 30本分の台本
- Creator向け説明資料
