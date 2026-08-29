# 09. 市場・審査・名称の事実確認レポート

確認日: **2026-07-02**（WebSearchによる一次確認。★印はオーナー/後続セッションでの再確認推奨）
目的: 設計・価格・名称・審査対応の判断根拠を最新事実で固める（FABLE_BRIEF Phase 0 / T1-T2成果物）。

---

## 1. 競合の現在地と価格（2026年時点）

| アプリ | アプローチ | 価格（USD） | トライアル | 備考 |
| --- | --- | --- | --- | --- |
| **one sec** | 摩擦型（深呼吸→意図確認） | $2.99/月・$19-20/年・$50買切 | あり | PNAS掲載研究が最大の信頼資産。日本App Storeは年¥1,990程度 |
| **Opal** | ハードブロック型 | **$99.99/年** | 7日（自動課金でCS苦情多数） | 最高価格帯。Deep Focus（途中解除不可）が看板 |
| **Jomo** | ブロック＋集中 | **$29.99/年**・$99.99買切・学生$14.99/年 | 3日 | 中価格帯の代表。買切をアンカーに使う構成 |
| **ScreenZen** | 軽量摩擦型 | ほぼ無料（〜$5/月） | - | 無料勢の代表。「まず無料で試すならこれ」枠 |
| **Roots** | ドーパミン計測型 | $59/年 | あり | 「digital dopamine」計測を訴求 |

**日本ローカル競合**: スタロック（ロック型勉強タイマー・30万ユーザー訴求）/ Offly / StayFree / Blockin / Detoxロック等。マイベスト・アプリブ等の比較記事が上位を占める＝**SEO記事経由の指名獲得余地あり**。

**含意**:
- 市場価格は $19〜$99.99/年 と広い。**差別化が立っていれば$30〜60/年帯は成立**（Jomo/Rootsが実証）。
- モック22_paywallの年額¥2,400はone sec対抗の最安帯＝**差別化ポジションと矛盾**（→ §4 価格再設計）。
- ブロック型は「解除して挫折」「$100は高い」の不満レビューが定着。**「禁止しない・気づかせる」ポジションの空白は健在**。ただし摩擦型クローン（TimeBack/Unscroll系が各5本以上）が乱立しており、**「利用後リフレクション＋ロック画面の戻る先」の二枚看板を切り口にした訴求が必須**。

## 2. 科学的根拠の取り扱い（06b_why_science画面・LP・広告の表現規範）

- one secのPNAS研究（Max Planck研究所・ハイデルベルク大学、被験者280人・6週間）: **SNS利用が平均57%減**。内訳=介入時に36%が開くのをやめた＋6週間で開こうとする試行自体が37%減。参加者の消費満足度も上昇。
- **表現ルール（必須）**: これは one sec の研究であり本アプリの実証ではない。
  - ✅ OK: 「開く前にワンクッション置く手法は、査読付き研究（PNAS, 2023）でSNS利用を平均57%減らすことが示されています」（一般手法への言及＋出典明記）
  - ❌ NG: 「このアプリでSNSが57%減る」「科学的に証明されたアプリ」（景表法優良誤認＋App Review虚偽表示リスク）
- 自社データが貯まり次第、「本アプリ利用者の実測値」に差し替える（Statsの匿名集計を将来のマーケ資産にする設計をdoc05に反映済み）。

## 3. App Review・Screen Time API制約（2026年時点）

| 項目 | 事実 | 対応 |
| --- | --- | --- |
| **FamilyControls entitlement** | `com.apple.developer.family-controls`（distribution用）は**Appleへの申請制**。用途の明確な説明が必要で、承認に日数がかかる | ★**backlog最優先タスクに「entitlement申請」を固定**（第1スプリント技術検証と並行。申請が通らないと配布不可） |
| 2026年プライバシー強化 | データ収集の明示・Privacy Labels厳格化・SDK Privacy Manifest必須・第三者（特にAIサービス）共有への同意必須 | オンデバイス原則＋匿名bucket計測（doc05方針）で適合。使用SDKのPrivacy Manifest確認をpreflightに追加 |
| 健康・医療表現 | 診断/治療/測定の主張は根拠文書が必要。診断的表現は高リスク | 「依存症の治療/診断」を名乗らない。「気づき・自己観察・習慣」の語彙で統一（FABLE_BRIEF §5 の避ける言葉を維持） |
| 閉じた瞬間の非検知 | 変更なし（他社アプリを閉じた瞬間とリアルタイム使用時間の直接検知は不可） | 通常起動では時間通知と自動リフレクションを行わない。シールド一時解除だけ、再シールド/復帰を根拠にする（doc05どおり） |

## 4. 価格再設計の判断材料（→ 決定は doc01 §8）

- 発見時の矛盾（本日解消済み）: 旧FABLE_BRIEF §9 = ¥780月/¥5,400年/¥12,800買切 vs 旧モック = ¥700月/**¥2,400年**/¥15,000買切 → **月¥780/年¥4,980/買切¥14,800に統一**。
- 競合レンジ: one sec ¥1,990年（最安・単機能）〜 Jomo $29.99年 〜 Roots $59年 〜 Opal $99.99年。
- 本アプリは「摩擦＋リフレクション＋人生の戻る先ウィジェット」の複合価値で、**Jomo〜Roots帯（$30-59 ≒ ¥4,500-8,800）が適正ゾーン**。¥2,400は複合価値の自己否定＝収益最大化に反する。
- 結論（推奨・詳細計算はdoc01 §8）: **月¥780 / 年¥4,980（7日無料・デフォルト）/ 買切¥14,800**。ローンチ時に年額 ¥3,980 vs ¥4,980 のA/B価格テストを実施。

## 5. 正式アプリ名の調査結果

**前提**: 「LifeFocus」は使用不可（`lifefocus.app` ドメイン既存＋App Storeに「LifeFocus360: Pomodoro Timer」等の近似名あり）。
英語の一般語ネーミングは飽和が確認された:

| 候補 | 空き状況（App Store実名検索） | 判定 |
| --- | --- | --- |
| LifeFocus | LifeFocus360ほか近似多数＋ドメイン取得済み | ✗ |
| Regain | 「Regain: Screen time control」既存（同カテゴリ・iOS18対応） | ✗ |
| TimeBack | 同名アプリ4本以上（全て同カテゴリ） | ✗ |
| Unscroll | 同名アプリ5本以上（全て同カテゴリ） | ✗ |
| Scrolless | iOS 2本＋Android 1本既存 | ✗ |
| Ibuki | 呼吸モニター「IBUKI」既存（ヘルス系・商標衝突リスク） | ✗ |
| **AfterScroll** | App Store該当なし | **◎（第2候補）** |
| **Modoru** | App Store該当なし（modoru.io という米スタートアップは存在） | **◎（第1候補・推奨）** |

**2026-07-02 追記（オーナーフィードバック）**: Modoru・AfterScrollは「ASO観点・海外展開観点でなし」として却下。想起しやすい語（Dopamine / SNS / LIFE）を含む方向で再調査。

| 候補（第2次） | 空き状況（App Store実名検索） | 判定 |
| --- | --- | --- |
| Lifeback / LifeBack | 「Lifeback: Screen Time Control」ほか同カテゴリ2本既存 | ✗ |
| Dopamine Detox | 同名アプリ複数（Dopamine Detox / Restrict apps / FocusZone等）乱立 | ✗（ただし検索需要の強さの証拠） |
| **DopaBreak** | 該当なし（近縁: DopaPause=SNSブロック系が2025年から存在） | **◎（第1候補・推奨）** |
| LifeDetox | iOS該当なし（Androidに小規模「lifedetox」あり） | ○（第2候補） |
| DopaLife | 該当なし（ただし「Dopa AI」=習慣/過剰刺激系が近接、IG @dopa.life 既存） | △（第3候補） |

**推奨: DopaBreak（ドーパブレイク）**

1. **ASO**: 「dopamine detox」「dopamine」は米国で強いトレンド検索語（dopamine detox / dopamine menu）であり、ブランド名自体が検索キーワードの部分一致になる。日本でも「ドーパミン」「ドーパミン中毒」は認知上昇中でICP（ドーパミン中毒自覚層）の自己認識語と一致。
2. **プロダクト一致**: Break ＝ S-01「一呼吸（ブレイク）」そのもの＋「ループを断つ（break the loop）」の二重義。禁止型（Block/Lock）の連想を避けつつ行動を表す。
3. **海外展開**: 英語圏でそのまま通用。韓国でも도파민（ドーパミン）はバズワード（도파민 디톡스）。
4. タイトル構成案: 日本「DopaBreak − SNS依存対策・スクリーンタイム」／米国「DopaBreak: Screen Time & Dopamine Detox」→ **「SNS」はブランドに入れず日本のタイトル/サブタイトル/キーワード欄で拾う**（SNSは和製略語で英語圏では通じないため、ブランドに入れると海外展開の足かせになる）。
5. リスク: 近縁名 DopaPause（同コンセプト・2025年〜）が存在。ブランドの識別はクリエイティブとアイコンで立てる。商標（J-PlatPat第9類/42類・USPTO）確認は必須。

**2026-07-02 追記（第3次・最終）**: オーナー指摘「日本でBreakは"壊す"の印象にも読める」→ 多義に読める名前を避け、日英韓すべてで単義・ポジティブに通る語尾で再調査。

| 候補（第3次） | 空き状況（App Store実名検索） | 日英韓での読まれ方 | 判定 |
| --- | --- | --- | --- |
| **DopaReset** | ◎ 該当なし（近縁: 「Reclaim − Dopamine Reset」がサブタイトルに同句を使用＝検索語として機能する証拠） | リセット/reset/리셋 — 全市場で「仕切り直す」の単義。禁止型連想なし | **◎ 最終推奨** |
| DopaDetox | ◎ 該当なし | デトックス/detox/디톡스 — 通るが、乱立する「Dopamine Detox」系と混同されやすく記述的で商標が弱い | ○ 第2候補 |
| DopaOff | ◎ 該当なし | オフ/off/오프 — 短いが「遮断」寄りの連想 | △ |
| DopaClear | ◎ 該当なし | クリア/clear/클리어 — 結果訴求だが検索語と接続しない | △ |

**最終推奨: DopaReset（ドーパリセット / 도파리셋）**

1. **全市場で単義**: 「リセット」は日本語で完全に定着した外来語で「仕切り直す・やり直す」の一義。破壊・禁止の連想がない。英韓も同じ。
2. **ASO**: 「dopamine reset」は英語圏で実在する検索フレーズ（既存アプリがサブタイトルに採用している＝検索価値の証拠）。日本語「ドーパミン リセット」も自然な検索文字列。
3. **心理設計との一致**: 損失リビール（年38日）→「リセットしてやり直せる」という希望の導線と一語で接続。「責めずに気づかせる」ポジショニングを損なわない。
4. タイトル構成案: 日本「DopaReset − SNS依存対策・スクリーンタイム」／米国「DopaReset: Dopamine Detox & Screen Time」／韓国「DopaReset − 도파민 디톡스」。
5. 留意: 「Dopa-」接頭辞空間は DopaPause / DopaFast / Dopaflow が既存（この型が機能している証拠でもある）。識別はアイコン・クリエイティブで立てる。商標（J-PlatPat第9類/42類・USPTO）確認は必須。

**2026-07-02 最終判断（第4次・確定推奨）**: オーナー指摘「このアプリにリセット要素はあるか？」→ **正直に言えば弱い**。本アプリの動詞は「止まる・気づく・選ぶ・戻る」であり、期間型の断ち/作り直し（＝Reset/Detoxプログラム）ではない。名が体を表さないと、ストア説明・審査・ユーザー期待とズレる（Reclaim等の習慣再構築プログラム系がResetを名乗る領域）。**DopaResetは撤回**。

改めて全観点（製品一致・日英韓の語義・ASO・空き・マーケ）で比較した結果、**最終推奨: DopaBreak**。

- **製品と字義が一致する唯一の候補**: Break＝「一呼吸（ブレイクタイム）」＝S-01そのもの＋「習慣ループを断つ（break the loop）」。アプリが毎回していることを名前が言っている。
- **日本語の「壊す」懸念の再検証**: カタカナ「ブレイク」の支配的語義は「休憩（コーヒーブレイク/ブレイクタイム）」と「ブレイクする（売れる）」。破壊の意では通常「破壊/クラッシュ」が使われる。さらに万一「壊す」と読まれても、目的語がドーパミン（依存）なので「ドーパミン漬けを断ち切る」という**意図どおりの意味に着地する**＝誤読しても事故らない。
- **韓国語**: 브레이크は「ブレーキ」の意が強く「도파민에 브레이크（ドーパミンにブレーキ）」と読まれる→これも製品と一致。
- **Dopaの要否**: Dopa無し案（Pause/Moment/Reclaim/Regain/NoScroll等の製品一致語）は英語圏でほぼ埋まっている。Dopa接頭辞は (1)ICP（ドーパミン中毒自覚層）の自己認識語 (2)検索トレンド語 (3)まだ空きがある、の3点で実利があり、外す理由がない。
- 念のためのローンチ前検証: 広告クリエイティブテスト時に名前の読まれ方（休憩/断つ/壊す）をX検索・少人数ヒアリングで確認する。

★2026-07-02 完了: DopaBreakオーナー承認 → docs一括リネーム＋商品ID（`dopabreak.pro.*`）・App Group（`group.com.dopabreak.shared`）変更済み。ドメイン取得はオーナー判断で見送り。Webクイック検索でDopaBreakの既存アプリ・商標の痕跡なし（2026-07-02）。J-PlatPat（第9類/42類）・USPTOの正式DB検索は提出前チェック（/preflight）で最終確認。

## 6. ASO所見（日本）

- 「スマホ依存」「スクリーンタイム 制限」「アプリ制限」は比較メディア（マイベスト/アプリブ/Ameba)が検索上位＝**個別アプリの指名獲得はストア内検索とSEO記事の両輪**で取る。
- 競合タイトルの型は「◯◯ − スマホ依存対策・スクリーンタイム・アプリ制限」。同型でキーワードを詰めつつ、サブタイトルで差別化軸（「禁止しない」「見た後の気づき」）を立てる。
- 詳細キーワード設計は Phase 4（/seo-aso）で実施。

---

### Sources
- [App Review Guidelines - Apple Developer](https://developer.apple.com/app-store/review/guidelines/)
- [Configuring Family Controls | Apple Developer](https://developer.apple.com/documentation/xcode/configuring-family-controls)
- [A Developer's Guide to Apple's Screen Time APIs | Medium](https://medium.com/@juliusbrussee/a-developers-guide-to-apple-s-screen-time-apis-familycontrols-managedsettings-deviceactivity-e660147367d7)
- [Directing smartphone use through the self-nudge app one sec | PNAS](https://www.pnas.org/doi/10.1073/pnas.2213114120)
- [Research | one sec (Max Planck Study)](https://one-sec.app/max-planck-study/)
- [Opal, Forest, Freedom: 5 Screen Time Apps Ranked (2026) | Unstar](https://unstar.app/blog/opal-forest-freedom-one-sec-jomo-screen-time-apps-ranked-2026)
- [7 Best Screen Time Apps in 2026 | Habi](https://habi.app/insights/best-screen-time-apps/)
- [One sec app review | Blok](https://www.blok.so/resources/one-sec-app-review-does-adding-friction-actually-reduce-screen-time)
- [Jomo Pricing](https://jomo.so/pricing)
- [スマホ依存対策アプリのおすすめ人気ランキング | マイベスト](https://my-best.com/6402)
- [【2026年】スマホ依存対策アプリおすすめ8選 | アプリブ](https://app-liv.jp/education/methods/3354/)
- [LifeFocus360: Pomodoro Timer - App Store](https://apps.apple.com/us/app/lifefocus360-pomodoro-timer/id1367887988)
- [Regain: Screen time control - App Store](https://apps.apple.com/in/app/regain-screen-time-control/id6749575953)
- [TimeBack: Screen Time Control - App Store](https://apps.apple.com/us/app/timeback-screen-time-control/id6748564790)
- [Unscroll: Scroll Less. Do More - App Store](https://apps.apple.com/us/app/unscroll-scroll-less-do-more/id1545149937)
- [Social Media Blocker Scrolless - App Store](https://apps.apple.com/us/app/social-media-blocker-scrolless/id6741134096)
- [IBUKI - App Store](https://apps.apple.com/us/app/ibuki/id1259085427)
- [Lifeback: Screen Time Control - App Store](https://apps.apple.com/us/app/lifeback-screen-time-control/id6636464956)
- [Dopamine detox - App Store](https://apps.apple.com/us/app/dopamine-detox/id6502594874)
- [DopaPause | social media block - AppBrain](https://www.appbrain.com/appstore/dopapause-%7C-social-media-block/ios-6741738900)
- [Dopa AI - App Store](https://apps.apple.com/us/app/dopa-ai/id6760188555)
- [Reclaim - Dopamine Reset - App Store](https://apps.apple.com/us/app/reclaim-dopamine-reset/id6752120497)
- [DopaFast: Social media blocker - App Store](https://apps.apple.com/us/app/dopafast-social-media-blocker/id6479438945)
