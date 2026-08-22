# DopaBreak — Fable 依頼マスターブリーフ

作成日: 2026-07-01
対象アプリ: **DopaBreak**（SNS依存改善 / iOSネイティブアプリ・2026-07-02名称確定）
このファイルの役割: 次に Fable モデルが入ったとき、既存 `docs/` を1本ずつ読み直さなくても、**設計・マーケ・実装・レビューを高品質かつ低トークンで進められる**ための単一入口（Single Source of Truth）。

---

## 0. このドキュメントの使い方（Fableへ）

1. **まずここだけ読めば全体像がわかる**ように圧縮してある。詳細が要る時だけ該当 `docs/NN_*.md` を開く（各節にリンクを置いた）。
2. 役割分担（オーナー方針・必須）:
   - **要件定義・調査・設計・レビュー = Fable（あなた）**
   - **実装（コード生成）= `codex exec` に委譲**（セッション節約が目的）。Fableは設計を固め、Codexに完全なコードを書かせ、出力を検証する。
   - レビューは **Fable + Codex 両方**で行う。
3. 着手前に **§10 未決定事項** を確認し、必要なら `AskUserQuestion` でオーナーに1回だけ確認してから動く。憶測で分岐を増やさない。
4. 出力・実装は「省略・TODO・プレースホルダ禁止」（`output-skill` 準拠）。
5. コピー生成時は日本語ディスプレイタイポグラフィ規則（見出しは句読点を使わず改行で割る・体言止め）を守る。本文はこの限りでない。

---

## 1. プロダクト一行定義

> SNSを開こうとした瞬間に「一呼吸→意図確認→必要時間だけ開放」を挟み、**使った後に「見てどうだった？」を振り返らせて、禁止ではなく気づきで自発的にSNSを減らす** iOSアプリ。

- **土台**: competitor「one sec」の「開くまでの遅延・摩擦」。ただし完全コピーはしない（IP/コモディティ回避）。
- **唯一無二の武器（主役）**: `利用後リフレクション`（「何も得られなかった」の可視化＝損失回避の体験化）。one sec / Opal が「ブロックで矯正」なのに対し、本アプリは「本人が自発的にやめたくなる」。
- **看板（ヒーロー）**: ロック画面に**戻る先（人生の方向性）を毎日表示** — 朝の目標通知＋デイリーLive Activity（2026-07-02: 常設ウィジェット廃止・手動設置ゼロ化）。SNS断ち × 人生の目標 × ロック画面の掛け合わせは日本語市場で手薄＝ASO/差別化の勝ち筋。

---

## 2. オーナー制約（絶対遵守）

| 項目 | 内容 |
| --- | --- |
| 体制 | 一人社長・外注なし。営業不要／CS軽い／非労働集約 が絶対条件 |
| 集客 | **広告(Meta/TikTok/Google)・ASO・SEO/MEO・第三者インフルエンサー** で組む |
| 使わない | **オーナー個人SNSアカウント/フォロワー資産を集客にも「強み」にも使わない**（[[feedback-no-owner-sns-asset]]） |
| 事業目標 | 月100万円利益級 × 複数 で年間利益1億円。放置で回るサブスクモデル志向 |
| 技術 | TypeScript優先だが本件は **iOSネイティブ SwiftUI 必須**（Screen Time API都合）。型安全・OWASP意識 |

---

## 3. コンセプトの確定方針（doc矛盾の解消）

> **重要**: 2026-07-12の現行SwiftUI実装と`docs/04`/`docs/06`/`docs/07`を正とする。旧「目標2枠」仕様は廃止し、種類なしのフラットリスト（Free 1件 / Pro 複数件）へ統一した。

**目標ヒーロー・軽量版:**

- **二層構造**: 目標表示＝ヒーロー（看板/マーケ主役）、SNSゲート＝エンジン（日次の実用機能）。
- **目標は軽量に留める**: 種類なしのフラットリスト。Freeは1件、Proは複数件。ホーム、通知/ウィジェット、介入時に表示する。
- **入れないもの（アプリ全体）**: アファメーション / 今日の一歩 / 複数タスク / 期限 / チェックリスト / リマインダー / プロジェクト管理 / ビジョンボード / 引き寄せ訴求。
- トーン: 強制でなく冷静な自己制御。黒基調・強いタイポ・直線的な計測バー。**円形リング/魔法陣/神秘的図形は使わない**（願望実現に寄せない）。

参照: [事業設計](./01_business_design.md) / [製品仕様](./03_product_spec.md) / [オンボ設計](./07_onboarding_design_lifefocus.md)

---

## 4. ターゲット・心理（コピー/LP/ペイウォールの土台）

- **Primary ICP**: 20-39歳 iPhoneユーザー。自分磨き（美容/勉強/副業/筋トレ/英語/資格/発信）の目標があるのに、SNSを無意識に開いて時間を失い、翌朝**自己嫌悪**する層。
- **本当のジョブ（裏の不安）**: 「意志が弱い自分を責めずに変わりたい」「気づいたら2時間溶けた自己嫌悪をなくしたい」「完全ブロックで挫折して自己否定したくない」。
- **効く心理原理**: 損失回避（失った時間の可視化）／一貫性（"何も得られなかった"を本人に言わせる）／ピークエンド（夜の振り返りで1日を締める）。
- **文化ドライバー（日本）**: 「禁止して矯正」より「責めずに気づかせる優しい設計」。同質な他者の社会的証明。
- **確定（2026-07-02）**: ICPは特定層に絞らず「SNS依存・ドーパミン中毒層全般」×損失回避訴求。セグメント別訴求（美容/学習/副業等）は広告クリエイティブの切り口として使う（doc01 §4）。

参照: [心理×文化マーケ戦略](./02b_marketing_psychology_strategy.md)

---

## 5. ポジショニング & メッセージ

**ポジショニング一行:**
> `SNSをやめられない自分を責めたくない人` が `ダラダラ見て1日を溶かす自己嫌悪` を `one sec/Opal等のブロック型` より `禁止せず「見た後の正直な気持ち」で自然に減らせる` ことで解決する `SNS依存改善アプリ`。

**H1（国別 transcreation）:**
| | H1 | サブ |
| --- | --- | --- |
| 日本 | また時間溶かした、をやめる。禁止じゃなく、気づきで。 | 見た後に「何も得られなかった」と気づくと自然に開かなくなる |
| 米国 | Stop the doomscroll without forcing yourself. | See how empty that scroll really felt — quit on your own terms |
| 韓国 | 또 시간 날렸다… 막지 않고 스스로 줄이는 법. | SNS 본 뒤 진짜 만족했는지 기록하면 자연히 줄어든다 |

**使う言葉**: 目標を思い出す / 意図的に使う / 無意識スクロールを減らす / 自分の時間を取り戻す / 見た後の満足感を記録する / 自分でやめたくなる。
**避ける言葉（薬機/景表/App Review リスク）**: 願いが叶う / 依存症が治る / 人生が変わる / 脳を書き換える / あなたは依存している / 意志が弱い / 治療。
**画面文言の正本 = [docs/11_ui_copy.md](./11_ui_copy.md)（2026-07-02新設・必読）**: ユーザーに見える文言はすべて docs/11 から転記する（新画面は先に文言を docs/11 に追加してから実装）。禁止: ①内部用語（介入/再介入/シールド/セッション）②医療表現 ③対象が曖昧な表現（「アプリを守る」「あなたを守る」）。使う語彙: 止める（止めるアプリ・止める強さ）/ 開こうとした / 開かずに我慢 / 一呼吸 / 見たあとの気持ち / 取り戻した時間 / 戻る先。SNS依存・ドーパミン中毒の悩みが解決できると一読でわかる自然な日本語にする（ユーザー語彙すぎるスラングも不可）。

---

## 6. スコープ & 画面一覧（全29画面・2026-07-02確定）

MVPは「開く前の遅延・意図確認・使用可視化・必要時間だけ開放・利用後リフレクション」に絞る。旧9画面オンボは**損失顕在化クイズを含む14ステップ**に拡張して確定（ICP=SNS依存全般×損失回避訴求と合致。詳細は doc07）。

**オンボーディング（損失顕在化フロー・14ステップ・2-3分）**
1. Welcome（損失回避「人生の時間は二度と戻らない」）
2. Self Check Q1（開く頻度の自己申告／権限後に実データ差替）
3. Quiz Q2（目的なきスクロール頻度・PHQ型）
4. Quiz Q3（「時間を溶かした」後悔の顕在化）
5. Quiz Result（推計損失リビール「1日2.5h→年38日」※推計明示）
6. Choose Apps（止めたいSNS選択・**汎用アイコン**、実ロゴはライセンス確認まで不使用）
7. Goal Setup（最初の目標1件・スキップ可）
8. Choose Mode（Deep Focus / 通常 / 夜だけ強化。デフォ=Deep Focus）
9. Intervention Preview（開く前の流れを見せる）
10. Why Science（行動科学4原理＋PNAS研究の適法引用 → docs/09 §2）
11. Permission（Screen Time許可）
12. Notification + Live Activity Guide（ロック画面に戻る先を届ける案内）
13. Pre-Paywall Summary（専用プラン要約＝サンクコスト形成→P-01へ）
14. Ready（完了）

**コア（4タブ）**
- Home（朝焼け帯＋目標＋今日/今週の「自分で選べた回数」。推測時間は表示しない）
- Goals（種類なしのフラット目標を軽量編集。Free 1件 / Pro 複数件）
- Stats（試行回数/理由別/時間帯/週次/利用後満足感/幸福感Delta）
- Settings（介入/対象アプリ/ウィジェット/通知/課金/プライバシー）

**目的確認先行の介入フロー**
- Intent Check（最初に6択: 仕事/調べもの/連絡/投稿/暇つぶし/なんとなく）
- 明確目的 → 呼吸を省略 → Time Selection（5/10/15/30分を選択後、CTAで確定）
- 反射的目的 → Breath → Usage Summary → 全目標 → Decision
- Cancel Success（「開かなかった。あなたの勝ち」）
- 時間経過は通知。standardでは他社アプリを自動終了しない
- Post-Use Reflection（満足度の1問。幸福感/集中の変化は回答から導出）

**ロック画面サーフェス（2026-07-02: 常設ウィジェット廃止）**
- Lock Notification / **Daily Live Activity**（フル目標文＋今日の実績・テーマ6種＝doc06 §9）
- Home Widget（Small / Medium・維持）

**マネタイズ**
- P-01 Paywall（3段・年額デフォルト・7日無料）

**現行モック/実装（2026-07-12）**: 視覚正本は `output/imagegen/lifefocus_latest_spec/` の4ボード・21状態。SwiftUI実装済みで、比較結果は `design-qa.md`（passed）。旧`output/mockups/lifefocus_v2/`は履歴参照。

参照: [画面設計](./06_screen_design.md) / [`.claude/plans/one-sec-sns-1-sns-sns-typed-stearns.md`](../.claude/plans/one-sec-sns-1-sns-sns-typed-stearns.md)

---

## 7. 技術アーキテクチャ（実装はCodexへ委譲する前提の設計要約）

- **技術**: iOS Native / SwiftUI 必須。Screen Time API / Shield Extension / WidgetKit / StoreKit 2 との親和性のため。
- **必要Extension**: DeviceActivityMonitor / ShieldConfiguration / ShieldAction / Widget（Homeのみ）/ **ActivityKit（Live Activity）**。
- **Apple API**: FamilyControls（権限・対象選択）/ DeviceActivity（スケジュール・閾値・監視）/ ManagedSettings(+UI)（シールド）/ WidgetKit / StoreKit 2 / UserNotifications / SwiftData or SQLite / App Groups。
- **Extension間共有**: App Group（`group.com.dopabreak.shared`）に goals/rules/attempt_logs/reflection_logs/widget_snapshot/intervention_state を軽量snapshotで置く。Extensionで重いDB処理をしない。

**データモデル（要点）**: `Goal` / `TargetRule`(activitySelectionData=FamilyActivitySelection) / `AttemptLog` / `ReflectionLog`(trigger, satisfaction, happinessDelta) / `WidgetSnapshot`(Home用) + `LockSurfaceState`(通知/Live Activity/テーマ・2026-07-02改訂)。

**介入状態遷移**: `Idle → ShieldPresented → Breathing → UsageSummary → GoalReminder → IntentSelection → Decision →(Cancelled | TimeSelection → TemporarilyAllowed → ReShieldScheduled → PostUseReflection)`。

**ロック画面表示ルール（2026-07-02改訂）**: 常設ウィジェット廃止。朝の目標通知＋デイリーLive Activity（ActivityKit・カスタムUI・テーマ6種・8時間制限は更新で延長・「今日の実績」ライブ更新で審査要件を満たす）。短縮表示名12-16文字はHome Widget/Dynamic Island/介入で使用。タスク/期限/チェックリストは出さない。

**実装順（Codexへの分割単位）**: (1)App Group+ローカル保存 →(2)目標作成 →(3)FamilyControls権限 →(4)FamilyActivityPicker →(5)ManagedSettingsシールド →(6)ShieldConfiguration表示 →(7)ShieldAction(開かない/続ける) →(8)時間選択と一時開放 →(9)利用後リフレクション →(10)AttemptLog/ReflectionLogと統計 →(11)ロック画面サーフェス（朝の通知＋Live Activity＋Home Widget・テーマ6種） →(12)StoreKit 2 →(13)Onboarding/Paywall polish。

参照: [詳細設計](./05_detailed_design.md) / [機能要件](./04_functional_requirements.md)

**最優先の技術検証（第1スプリントで必ず）:**
1. 選択した対象アプリにカスタムシールドを出せるか。
2. ShieldActionで段階的な画面遷移を実現できるか。
3. 指定時間だけ一時開放して再シールドできるか。
4. App GroupからExtensionが目標snapshotを安定して読めるか。
5. Live Activity/Home WidgetとShieldが同じ目標データを表示できるか（Live Activityの8時間更新含む）。
6. 選択時間終了時に利用後リフレクションを表示できるか。

---

## 8. iOS制約 & App Review リスク（設計・コピーの前提）

| 制約/リスク | 内容 | 対策 |
| --- | --- | --- |
| 閉じた瞬間の非検知 | iOSは他社SNSを閉じた瞬間を直接検知できない | 利用後リフレクションは「選択時間終了時/再シールド時/アプリ復帰時/通知」で近似。UIで「閉じた瞬間に必ず出る」と表現しない |
| Screen Time API制約 | 取得/表示できる情報に制限 | ネイティブで先行検証・早期TestFlight |
| App Review | 依存/メンタルヘルス表現が強すぎるとリジェクト | 医療/治療/保証表現を避け「気づき/自分で減らせる」体験ベースで語る |
| one sec 類似/IP | 遅延/深呼吸フローの完全コピーは危険 | 意図確認＋利用後リフレクションを中核に。米国展開前に弁護士確認 |
| プライバシー | 使用情報はセンシティブ | データは原則オンデバイス。Analyticsに本文/アプリ名を入れない。全データ削除機能 |

---

## 9. マネタイズ

**モデル**: フリーミアム + サブスク + 買い切り（StoreKit 2）。商品ID: `dopabreak.pro.monthly` / `.annual` / `.lifetime`（確定）。

**確定価格（2026-07-02・根拠と感度分析は doc01 §8）:**

| プラン | 内容 | 日本 | 米国 |
| --- | --- | --- | --- |
| Free | 目標1件/1制限アプリ/ウィジェット1/当日統計 | 無料 | 無料 |
| Pro Monthly | 複数アプリ/複数目標/理由・リフレクション分析/週次/厳格モード/テーマ/複数ウィジェット | **780円** | $5.99 |
| Pro Annual | 上記＋**7日無料・デフォルト選択・月額比47%OFF** | **4,980円** | $34.99 |
| Lifetime | 買い切り（高位アンカー・年額約3年分） | **14,800円** | $99.99 |

- ローンチ時に年額 **¥3,980 vs ¥4,980** のA/B価格テスト。旧モック価格（年¥2,400）は複合価値に対する過小価格のため廃止。
- **課金の本質**: 「コンテンツ量」でなく「自分の環境を変えた実感」。訴求は複数アプリ/複数目標・ウィジェット/理由別傾向/厳格モード/テーマ。
- **ペイウォール設計**: 3段（Lifetime高位アンカー→年額を「一番お得」）＋年額デフォルト選択。**7日無料→週次「取り戻した時間」レポートを先に持たせてから課金**（保有効果）。自動更新条件の明記必須（審査3.1.2）。
- **課金タイミング**: オンボO-08b経由 / 2個目の対象アプリ追加時 / 2件目以降の目標追加 / 2個目以降のロック画面表示 / 週次レポート詳細 / 厳格モード / テーマ / リフレクション詳細分析。

参照: `paywall-optimization` / `ios-subscriptions` スキル。

---

## 10. 未決定事項（着手前に確認）

**2026-07-02 更新: 5件中4件解消済み。**

1. ~~正式アプリ名~~ → **確定（2026-07-02）: DopaBreak**（旧仮称LifeFocusは名称競合で使用不可。Modoru/AfterScroll/DopaResetの却下経緯は docs/09 §5）。docs一括リネーム・商品ID `dopabreak.pro.*`・App Group `group.com.dopabreak.shared` 反映済み。ドメインは取得見送り（オーナー判断）。商標の正式DB検索は提出前に実施。
2. ~~ICPの重心~~ → **確定**: 特定層でなく「SNS依存・ドーパミン中毒層全般」に損失回避訴求。セグメント別訴求は広告切り口として使用（doc01 §4）。
3. ~~ビジュアルトーン~~ → **確定（2026-07-02）**: E1 Dark Monoをデフォルトに採用。F1墨と灯はProテーマ第1弾候補として保管。
4. ~~Self Checkの実装方式~~ → **確定**: 自己申告先行（権限取得後に実データ差替）。
5. ~~Goal Setupの位置~~ → **確定**: 14ステップ中の7番目（O-04・Quiz Result→Choose Appsの後）。doc04/06/07整合済み。

---

## 11. 成功指標（North Star & KPI）

**North Star: `Conscious Saves`** = 対象SNSを開こうとしたが、開く前の確認 or 利用後リフレクションによって次回以降の利用を自発的に減らす行動につながった回数。

| フェーズ | 指標 | 成功基準 |
| --- | --- | --- |
| Activation | 目標作成率・対象アプリ設定率・ロック画面ウィジェット設置率・初回介入完了率 | セットアップ完了者の40%+がロック画面ウィジェット設置、20%+が複数目標/複数ウィジェット |
| Retention | D1/D7/D30・制限ON継続・リフレクション回答率 | D7 25%+ / D30 10%+ |
| 差別化検証 | 週次で「何も得られなかった」を見て設定を強めた率 | 回答者の30%+ |
| Revenue | Trial開始率・Trial→Paid・ARPPU・解約率 | Trial→Paid 3-5%+ |

---

## 12. GTM / マーケ実行（オーナー集客チャネル前提）

**クリエイティブの主役 = 感情アーク:**
- 自己嫌悪の言語化→共感（「明日こそ早く寝るって決めたのに、気づけばTikTok2時間」）
- 数字の正直さ（「1週間記録したら62%が"何も得られなかった"」）
- Before/After（アプリ実データ：開こうとした127回→68回）
- 画面録画（介入→意図確認→リフレクション→週次レポートを15秒）

**チャネル**: TikTok/Reels/Shorts で切り口選別 → Meta/Google/TikTok広告でスケール → 第三者インフルエンサー（勉強/美容/副業垢・PR明示）→ ASO/SEO で説明需要（「スマホ依存 対策」「SNS 時間 減らす」）→ アプリ内/LPでメール・プッシュ許諾を取りリスト化。

**ASO キーワード（日本）**: スマホ依存 / スクリーンタイム / アプリ制限 / SNS制限 / 集中 / 目標達成 / 習慣化 / デジタルデトックス。

**規制**: ステマ規制（PR明示）・薬機/景表（効果断定回避）・App Review の健康表現。参照: `legal-compliance-jp` スキル。

参照: [マーケ戦略](./02_marketing_strategy.md) / [心理×文化](./02b_marketing_psychology_strategy.md) / **[実行計画・インパクト順](./02c_marketing_impact_plan.md)（2026-07-03新設・実行順序/予算/撤退基準の正本）**

---

## 13. 成功に繋がる重要項目チェックリスト（全洗い出し）

Fableはこの表を「成功要因の抜け漏れ検知」に使う。★＝MVP前の死活項目。

### A. プロダクト核
- [ ] ★ 選択アプリにカスタムシールドを段階表示できる（技術検証1-2）
- [ ] ★ 指定時間だけ一時開放→再シールドできる（技術検証3）
- [ ] ★ 利用後リフレクションが近似トリガーで自然に出る（審査/UX両立）
- [ ] ★ ロック画面（通知/Live Activity）で「戻る先」が主役として読める（可読性・許可率60%+）
- [ ] 介入が「面倒」でなく「役立つ」短さ（D7で制限ON継続25%+）
- [ ] 目標は軽量（ヒーロー1＋1年1）。タスク管理化しない

### B. 差別化・モート
- [ ] ★ 利用後リフレクション＝「何も得られなかった」の可視化が体験として成立
- [ ] one secとの非類似性（意図確認＋リフレクションが中核）
- [ ] 感情設計・ウィジェット・週次レポートで競合追随に対する深さ
- [ ] 参照: `ai-moat-strategy`（次のモデルで強くなるかでなく感情/データ/配信で守る）

### C. マネタイズ
- [ ] ★ 7日無料→失った時間レポート先出し→ペイウォールの導線
- [ ] ★ StoreKit2：購入・**復元必須**・Entitlement同期・サンドボックス/TestFlight検証
- [ ] 3段ペイウォール（Lifetimeアンカー→年額デフォルト）
- [ ] 課金タイミングが「環境を変えた実感」に紐づく

### D. 集客・ASO
- [ ] ★ ASOキーワード×正式名の空き・競合の現在地確認（WebSearch）
- [ ] 感情アーク広告クリエイティブの切り口テスト設計（自己嫌悪 vs 目標）
- [ ] 第三者インフルエンサー起用（オーナー個人SNS不使用）
- [ ] LP（日/英最小）＋Waitlist＋「SNSを一番開く時間」診断リード

### E. 審査・法務・信頼
- [ ] ★ 医療/依存/保証表現の排除（App Review・薬機・景表）
- [ ] ★ Privacy Policy/Terms/特商法（Stripe/App Store基準）
- [ ] ★ オンデバイス保存・Analyticsに本文/アプリ名を入れない・全データ削除
- [ ] Privacy Manifest / ATT（計測する場合）
- [ ] ステマ規制（PR明示）

### F. 計測
- [ ] 匿名イベント設計（本文/アプリ名を送らない・bucket化）
- [ ] North Star `Conscious Saves` と補助KPIをダッシュボード化
- [ ] SKAdNetwork/AdAttributionKit・MMP（広告出稿時）。参照 `mobile-analytics`

### G. リリース運用（一人運用）
- [ ] CS軽い設計（FAQ/アプリ内ヘルプ）・kill-switch
- [ ] EAS or Xcode Cloud のビルド/提出パイプライン（Expo採用時は `expo-production`）
- [ ] レビュー依頼フロー・ローンチチェックリスト（スクショ10枚/15秒プレビュー）

---

## 14. Fableへの依頼タスク一覧（フェーズ別・成果物指定）

各タスクは「クエリ＋目的＋期待出力」を明示（オーナーのサブエージェント運用規約準拠）。実装は Codex 委譲、Fableは設計・検証・レビュー担当。

### Phase 0: 整合・確定（2026-07-02 完了）
- [x] **doc整合**: 全docを「目標ヒーロー軽量版・14ステップ・29画面・確定価格」に統一（docs/CHANGELOG.md）。
- [x] **未決定5件（§10）の解消**: 4件確定・残1件=トーン最終選択。
- [x] **競合/審査の最新確認**: docs/09_market_verification.md（2026-07-02）。

### Phase 1: 設計成果物（2026-07-02 ほぼ完了）
- [x] **UI設計**: 29画面カタログ確定（doc06）。トーンは E1 vs F1墨と灯 の最終比較（`output/mockups/tone_comparison_v2/`）でオーナー選択待ち。
- [x] **オンボ最適化**: 14ステップ・Activation条件・離脱対策・分岐（doc07）。
- [x] **ペイウォール設計**: 3段・年額デフォルト・7日無料・確定価格・レポート先出し（doc01 §8 / doc06 §10）。
- [x] **DB/データモデル確定**: Goal 2枠・SelfCheckSnapshot・Entitlement（doc05）。
- [x] トーン確定（E1採用・2026-07-02）: doc07 §3 / §15 をE1に一本化済み。再スキニング不要。

### Phase 2: 実装（Codex委譲・Fableは検証）
- [ ] §7「実装順(1)〜(13)」を単位に `codex exec --skip-git-repo-check "Implement <機能>. 設計: docs/05_detailed_design.md + docs/FABLE_BRIEF.md §7. 既存規約準拠・完全なコード（省略/TODO禁止）"`。
- [ ] 各実装後に Fable が設計適合を検証 → 不十分なら最大3サイクル追加指示。

### Phase 3: 品質・レビュー（Fable + Codex 両方）
- [ ] セキュリティ/プライバシーレビュー（`security-review`・OWASP・オンデバイス徹底）。
- [ ] `codex exec --skip-git-repo-check "Review all changes... bugs/security/logic only"`。
- [ ] App Store提出前チェック（`/app-store` `/preflight`）。

### Phase 4: マーケ成果物
- [ ] 広告クリエイティブ切り口（感情アーク5本×A/B）＋台本。連携: `/ads` `/creative` `global-marketing-psychology`。
- [ ] LP（日/英最小）＋「SNSを一番開く時間」診断。連携: `/lp-design` `/sales-copy` `humanizer-jp`。
- [ ] ASO/SEO（キーワード・タイトル・サブタイトル・説明文）。連携: `/seo-aso`。
- [ ] 法務（Terms/Privacy/特商法）。連携: `/legal` `legal-compliance-jp`。

---

## 15. デザイントークン

**確定（2026-07-02 オーナー決定）: E1 Dark Mono を全画面のデフォルトトーンとする。**

| Token | Hex | 用途 |
| --- | --- | --- |
| Ink Black | `#0A0B0D` | 画面背景 |
| Card | `#14171C` | カード |
| Paper | `#F4F5F2` | 主テキスト |
| Muted | `#7E8694` | 補足文 |
| Electric Lime | `#C7F94D` | 唯一のアクセント（各画面1役割に限定） |

詳細 `design/BUILD_SPEC_E1.md`。F1「墨と灯」（`output/mockups/tone_comparison_v2/F1_*`）は**Proテーマ第1弾候補**として保管（テーマ課金の実弾）。マスコットIP（動画広告用キャラ）はマーケ側の資産とし、アプリUIは再スキニングしない（通知・空状態など小さな接点のみ）。


角丸12-18px。文字は太く短く。円形リング/光の玉/過度なグラデ/神秘的図形は不使用。SNS実ロゴは使わず汎用アイコン。

---

## 16. 参照ドキュメント索引

| ファイル | 内容 | 位置づけ |
| --- | --- | --- |
| [README](./README.md) | 最新方針サマリ | 現行 |
| [01_business_design](./01_business_design.md) | 事業設計・確定価格・ユニットエコノミクス | 現行（2026-07-02改訂） |
| [02_marketing_strategy](./02_marketing_strategy.md) | マーケ戦略・国別・ASO | 土台 |
| [02b_marketing_psychology_strategy](./02b_marketing_psychology_strategy.md) | 心理×文化・感情ジョブ | **現行の主戦略（訴求の正本）** |
| [02c_marketing_impact_plan](./02c_marketing_impact_plan.md) | インパクト順の実行計画・予算・撤退基準・90日カレンダー | **現行の実行レイヤー（2026-07-03新設）** |
| [03_product_spec](./03_product_spec.md) | 製品仕様・フロー・ウィジェット | 現行（目標入力は軽量版で読む） |
| [04_functional_requirements](./04_functional_requirements.md) | 機能要件 | Screen Time部を優先 |
| [05_detailed_design](./05_detailed_design.md) | iOS詳細設計・データモデル | **実装の土台** |
| [06_screen_design](./06_screen_design.md) | 画面設計（全28画面・v2モック1:1） | 現行（2026-07-02全面改訂） |
| [07_onboarding_design_lifefocus](./07_onboarding_design_lifefocus.md) | オンボ設計（14ステップ損失顕在化） | **現行（2026-07-02改訂）** |
| [09_market_verification](./09_market_verification.md) | 市場・審査・名称の事実確認（2026-07-02） | 現行 |
| [CHANGELOG](./CHANGELOG.md) | 改訂履歴・差分メモ | - |
| [.claude/plans/one-sec-sns-...](../.claude/plans/one-sec-sns-1-sns-sns-typed-stearns.md) | モック計画・確定方針 | 確定判断の根拠 |

---

*このブリーフは docs 群の圧縮ハブ。矛盾を見つけたら現行（README/02b/03/05/07 + plans）を正とし、旧版（01/06）を改訂する。*
</content>
</invoke>
