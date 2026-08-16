# 16. ASOメタデータ（3市場同時ローンチ・ja/ko/en）

作成日: 2026-07-24 / 改訂: 2026-08-14（KRネイティブ監査反映・3.1.2 URL追記・ko説明文v2確定）
方針: doc01 §11（3市場同時）。ASO原則は各市場ネイティブの型（英語圏=コロン型 / 日本=記号区切り / 韓国=ダッシュ+ハングル）。
**🔴 訴求の正本は [output/audits/onboarding-copy-strategy-by-country-2026-07-17.md](../output/audits/onboarding-copy-strategy-by-country-2026-07-17.md)（v2.1・WebSearch検証済み）。本書ASOはこれに従属する。**
翻訳QA: Fable作成 → Codex独立レビュー → 人間ネイティブ最終確認（韓国語のlaunch-critical）。**本書のko/enはドラフト（レビュー前）。**

## ⚠️ v2.1整合の是正点（2026-07-25）

- **US**: 差別化軸は「Not another blocker」（dopamine/break the loop は競合飽和）。ASO説明文（未作成）の冒頭で「ブロックしない・開く前に聞く」機構差を宣言する
- **KR**: **「디톡스」は訴求禁止語**（懐疑報道・トレンド移行・v2.1検証済み）。表示コピー（タイトル/サブ）は既に디톡스不使用でOK。ただし**キーワード欄の`디지털디톡스`は要再考**（検索ボリュームは残るが、디톡스目当ての離脱層を呼ぶリスク→ASA実データで判定。当面は`디지털디톡스`を残しつつ`브레이크`/`절제`系を優先追加）。KR訴求の背骨は「차단이 아니라 브레이크」・진단でなく`셀프 체크`

App Store文字数上限: タイトル30字 / サブタイトル30字 / キーワード欄100字（カンマ区切り・スペース無・重複語はカウント1回・競合アプリ名禁止=2.3.7）。

---

## 日本（ja）— 確定（doc02c）

| 項目 | 値 | 字数 |
|---|---|---|
| タイトル | `DopaBreak − SNS依存対策・スクリーンタイム` | 28/30 |
| サブタイトル | `禁止しないアプリ制限・気づきでSNSを減らす` | 22/30 |
| キーワード欄 | `スマホ依存,ドーパミン,デジタルデトックス,集中,習慣化,時間管理,やめたい,目標達成,夜ふかし,インスタ,ブロック` | 要最終化 |

---

## 米国（en-US）— Codexレビュー反映済み（doc02c旧案39字→修正 / positioning整合）

旧案 `DopaBreak: Screen Time & Dopamine Detox`＝39字（不可）。さらにCodex指摘: `app limits`/`stop scrolling` はブロック（強制制限）を想起させ、本アプリのpositioning（強制しない＝開く前の一呼吸）と齟齬。機構を明示する案へ差替え。

| 項目 | 値（確定ドラフト） | 字数 |
|---|---|---|
| タイトル | `DopaBreak: Mindful Screen Time` | 30/30 |
| サブタイトル | `Pause Before Social Media Use` | 29/30 |
| キーワード欄 | `dopamine,detox,focus,phone,addiction,doomscrolling,scrolling,distraction,habit,digital,reduce,urge` | 98/100 |

設計意図:
- タイトル: `screen time`（アンカー）＋ `mindful`（positioning）。旧案の `detox` はキーワード欄へ移動
- サブタイトル `Pause Before Social Media Use` が**介入機構（開く前に一呼吸）を明示**しつつ `social media` キーワード族を獲得。タイトルと語の重複なし
- キーワード欄: `detox` `doomscrolling` `reduce` `urge` を追加。競合アプリ名なし（2.3.7）。`app blocker` は製品実態と異なるため入れない
- ⚠️ `screen time` が最大ボリュームという判断は**未実証** → ASA（オーナー保有）の検索ポピュラリティで要検証
- **クロスローカライゼーション**: USは Spanish (Mexico) も索引。es-MXキーワード欄に英語追加KWで実質+100字（別途）

---

## 韓国（ko）— Codexレビュー＋クロスモデルネイティブ監査反映済み（2026-08-14）

> **ネイティブ確認の実施記録（2026-08-14・オーナー指示「ネイティブかはあなたが確認して」）**: humanizer-ko監査スクリプト全ゲート通過（exit 0・번역투/이중피동ゼロ・文長SD 15.11・読点2.6%）＋ Opus5独立レビュー（어색한 지점 行単位精査）＋ Fable統合判断のクロスモデル体制で実施。人間の韓国語ネイティブによる確認ではない点は留意（LLM 2モデル＋機械測定による代替）。主な是正: `동료 평가를 거친 연구`(peer-reviewedの直訳カルク)→`국제 학술지 PNAS에 실린 연구`、`무심코가 아니라`の文法不安定解消、内部用語`대상 앱`/`강도`の除去（オーナー恒久指示準拠）、`홈 화면`(iOSホーム画面と誤読)→`앱 첫 화면`、`₩9,900`→`9,900원`表記、브레이크를 걸다の慣用形化。

**コロン型にしない**（英語圏専用）。韓国は分かち書き＋ダッシュ/ハングル説明が自然。ブランド `DopaBreak` は英語のままで自然。Codex指摘で旧ドラフトを差替え: `절제`（＝自制/節制）が説教臭い・`도파민 절제` は不自然な連語・`앱차단`（アプリブロック）は製品実態と齟齬・Apple公式は `스크린 타임`（スペース入り）。

| 項目 | 値（確定ドラフト） | 字数 |
|---|---|---|
| タイトル | `DopaBreak - 스크린 타임 줄이기` | 22/30 |
| サブタイトル | `SNS 열기 전 잠깐 멈추는 작은 습관` | 21/30 |
| キーワード欄（ko-KR） | → **v2.1確定版（88/100）を使用**（下記「KW欄の玉突き調整」参照。旧38字版は廃止） | 88/100 |
| キーワード欄（en-GB=韓国の副索引） | `dopamine,detox,screen time,focus,scrolling,habit,digital wellbeing,phone addiction` | 82/100 |

設計意図:
- タイトル `스크린 타임 줄이기`（スクリーンタイムを減らす）＝機能を平易に。Apple公式表記のスペース入りに合わせる
- サブタイトル `SNS 열기 전 잠깐 멈추는 작은 습관`（SNSを開く前に少し止まる小さな習慣）＝**介入機構そのものを明示**しブロック誤認を排除
- キーワード欄: `앱차단`（ブロック誤認）除去・タイトル重複語（스크린타임/절제）除去。**現行仕様=100「文字」でCJKは1字1カウント**（バイトではない・2026 ASO一次情報で確認）→ **余白62字ぶんはネイティブ＋ASA実データで高価値語を追加**
- **韓国は Korean(KO) + English(UK) を索引** → en-GBキーワード欄に英語を入れて二重取り
- **🔴 人間ネイティブ確認ポイント**: `작은 습관` の自然さ・ターゲットが `SNS` か `소셜 미디어` か・`잠깐 멈추는` のトーン・追加ko キーワード候補の選定（CodexもLLMでありネイティブではない）

---

## サブタイトル v2（2026-07-25 ブラッシュアップ・sales-copywriting/seo-aso適用）

前提: iOSの検索索引対象は**タイトル・サブタイトル・キーワード欄のみ**（説明文は索引対象外）。タイトルとサブタイトルの重複語はカウント1回＝重複は索引の無駄。

| 市場 | v1 | **v2（推奨）** | 変更理由 |
|---|---|---|---|
| JP | 禁止しないアプリ制限・気づきでSNSを減らす（22） | **禁止しないアプリ制限・開く前にひと呼吸**（19/30） | ①曖昧な「気づきで」→機構明示「開く前にひと呼吸」（アプリ内コピーと完全一致＝DL後の期待整合）②「SNS」はタイトルと重複で索引無駄→削除 ※doc02c確定値の差し替え=オーナー承認事項 |
| US | Pause Before Social Media Use（29） | **Doomscroll less. Not a blocker**（30/30） | ①`doomscroll`=高意図・競合薄の伸び筋KWをサブタイトル（KW欄より索引が強い）へ昇格 ②`blocker`=大ボリューム語をネガ形で拾いつつ「Not another blocker」差別化を検索結果で宣言 ③v1の`Use`終わりの硬さ解消 |
| KR | SNS 열기 전 잠깐 멈추는 작은 습관（21） | **숏폼·SNS 앱 열기 전 잠깐 멈추는 습관**（23/30・v2.1） | `숏폼`（ショート動画中毒=韓国2026トレンドKW）をKW欄からサブタイトルへ昇格。**2026-08-14ネイティブ監査で`앱`を挿入**（韓国語で숏폼は「보다」でありアプリではないため`숏폼 열기`は連語破綻。`숏폼·SNS 앱`とカテゴリ化して解消）。v1の`작은 습관`は『아주 작은 습관의 힘』(Atomic Habits)想起のクリシェ＋検索価値ゼロ3字のためv2系を採用 |

**KW欄の玉突き調整**（サブタイトルとの重複排除）:
- US v2: `dopamine,detox,focus,phone,addiction,social media,scrolling,distraction,habit,digital,reduce,urge`（97/100・doomscrolling→サブタイトルへ・social media追加）
- **KR v2.1(ko)（2026-08-14ネイティブ監査で余白拡張済み・88/100）**:
  `도파민,디지털디톡스,스마트폰,중독,집중력,생산성,미루기,시간관리,폰중독,앱차단,도파민디톡스,쇼츠,자기관리,습관,공부집중,딴짓,루틴,마음챙김,자기계발,스크린타임`
  - 追加ロジック: 韓国語検索は**スペースなし複合語**で打たれる（`폰중독`は`스마트폰`+`중독`の別トークンでは拾えない保証がない）。`스크린타임`はタイトルの`스크린 타임`(スペースあり・Apple公式表記)と実効トークンが別のためヘッジとして追加
  - **`앱차단`を再追加**（7/25のCodex指摘「ブロック誤認」で除去→覆す）: KW欄は非表示のため誤認リスクはゼロ。`앱차단`を検索する層＝ブロッカーに失望した層こそ「차단이 아니라 브레이크」のドンピシャのターゲット
  - `쇼츠`は商標グレー（YouTube Shorts由来だが一般語化）。審査で指摘されたら`목표관리`に差し替え
  - 残余白12字はローンチ後のASC検索語レポートで`목표관리`/`시간낭비`等を追加
  - 除外判断: `인스타`/`릴스`/`유튜브`=第三者商標(2.3.7)・`소셜미디어`=韓国の日常語はSNSでありユーザーは検索窓に打たない・`명상`=競合過多
- ⚠️ v1→v2はいずれも**ASA検索ポピュラリティでの実証前**。ローンチ後のPPO（プロダクトページ最適化）A/B候補としてv1を保持

---

## 説明文（3市場・2026-07-25作成・humanizer監査済み）

役割: iOSでは索引対象外＝**純粋にCVR**。勝負は折りたたみ前の最初の3行（フック＋カテゴリ＋差別化）。サブスク条件の明示は審査要件。EN/KOはhumanizer-en/ko監査スクリプト**全ゲート通過**（em dashゼロ・번역투ゼロ・exit 0）。

### 日本語（ja）

```
「あと5分だけ」のはずが、気づけば1時間。
DopaBreakは、SNSを禁止せずに減らすアプリです。
開く前にひと呼吸はさむだけ。我慢はいりません。

■ こんな経験はありませんか
・目的もなくInstagramやYouTubeを開いてしまう
・閉じたあと「時間を溶かした」と後悔する
・ブロックアプリは解除して、結局削除した

■ DopaBreakの仕組み
ブロックしません。開く直前に一度だけ問いかけます。
1. 対象アプリを開くと、ひと呼吸の画面が先に出ます
2. 「何のために開く？」を選びます。仕事や連絡ならすぐ通れます
3. 暇つぶしなら、目標を思い出してもう一度選び直せます
4. 開かなかった回数が、毎日ホームに積み上がります

■ ブロックではなくブレーキな理由
ブロックは初日は頼もしい存在です。数日で解除方法を覚え、最後はアプリごと消してしまう。ブレーキは違います。禁止がないから、戦う相手もいません。開く前に気づく瞬間が生まれるだけです。

この一瞬は、思った以上に効きます。開く前にワンクッション置く手法は、査読付き研究（PNAS, 2023）でSNS利用を平均57%減らすことが示されています。
※他社アプリ(one sec)を対象とした研究です。本アプリの効果を保証するものではありません。

■ 主な機能
・開く前のひと呼吸（対象アプリと強さを自分で設定）
・目標のロック画面表示（通知・ウィジェット）
・見たあとの気持ちの記録
・開こうとした回数、開かなかった回数の統計

■ DopaBreak Pro
無料で始められます。Proでは止めるアプリと目標を無制限に追加できます。全期間の記録とロック画面テーマも使えます。
・月額 ¥980 ／ 年額 ¥4,980（7日間無料トライアル付き）／ 買い切り ¥14,800
・購入はApple IDに請求されます。期間終了の24時間前までに解約しない場合、自動更新されます。解約は設定からいつでもできます。
・利用規約: https://saku1110.github.io/dopabreak-legal/terms-ja.html
・プライバシーポリシー: https://saku1110.github.io/dopabreak-legal/privacy-ja.html
```

### 英語（en-US）— humanizer-en全ゲート通過

```
"Just five more minutes." An hour later you look up, and it's gone.

DopaBreak is not another blocker. It puts one breath between you and your feed, right before the app opens. You still decide. You just decide on purpose.

HOW IT WORKS

1. You tap Instagram, YouTube, or wherever your time disappears. DopaBreak opens first.
2. It asks one question: what are you opening this for? Work or messages go right through.
3. Killing time? Take a breath, look at your goal, then choose again.
4. Skip the app and it counts. Your Home screen keeps score of every time you didn't open.

WHY A PAUSE INSTEAD OF A BLOCK

Blockers feel great on day one. By day three you know the workaround, and by day five the blocker is gone. A pause is different. Nothing is forbidden, so there's nothing to fight. There's just a moment to notice what you're doing.

That moment matters more than it sounds. In a peer-reviewed study (PNAS, 2023), adding a short pause before opening cut social media use by 57% on average. The study looked at another app (one sec), and results vary by person, but the mechanism is the same: interrupt the reflex, and the reflex loses its grip.

WHAT YOU GET

- A breath before each app you choose. You pick which apps, and how firm the pause is.
- Your goal on your Lock Screen, so the reason you started stays in sight.
- A quick check-in after you scroll: was it worth it?
- Stats for how often you tried to open and how often you didn't.

DOPABREAK PRO

Free to start. Pro removes the limits: unlimited apps to pause, unlimited goals, full history, and lock screen themes.

- Monthly $9.99 / Yearly $39.99 with a 7-day free trial / Lifetime $119.99
- Payment is charged to your Apple ID. Subscriptions renew automatically unless canceled at least 24 hours before the period ends. You can manage or cancel anytime in Settings.
- Terms of Use: https://saku1110.github.io/dopabreak-legal/terms-en.html
- Privacy Policy: https://saku1110.github.io/dopabreak-legal/privacy-en.html

Your feed already knows how to get your attention. DopaBreak gives you a way to take some of it back.
```

### 韓国語（ko）— v2確定（2026-08-14ネイティブ監査反映・humanizer-ko全ゲート再通過 exit 0）

```
'5분만 봐야지' 하고 열었는데 정신 차려 보니 한 시간이 지나 있죠.

의지가 약해서가 아니에요. 피드가 그렇게 설계돼 있거든요.

DopaBreak는 차단 앱이 아니에요. 막지 않아요. 열기 직전에 브레이크를 한 번 걸어요. 그게 전부예요. 선택은 여전히 내가 해요. 달라지는 건 하나예요. 무심코 열던 앱을 이제 알고 열게 돼요.

■ 이렇게 작동해요

1. 인스타그램이나 유튜브처럼 내가 정해 둔 앱을 열면 숨 고르기 화면이 먼저 떠요
2. 무엇 때문에 여는지 골라요. 일이나 연락이면 바로 통과
3. 심심풀이라면 잠깐 숨 고르고 목표를 본 다음 다시 골라요
4. 열지 않은 횟수는 매일 앱 첫 화면에 쌓여요

■ 차단이 아니라 브레이크인 이유

차단 앱은 첫날엔 든든해요. 며칠 지나면 해제 방법을 찾게 되고 결국 앱까지 지우게 되죠. 브레이크는 달라요. 금지가 없으니 싸울 일도 없어요. 열기 전에 잠깐 알아차리는 순간이 생길 뿐이에요.

이 몇 초가 생각보다 큰 차이를 만들어요. 국제 학술지 PNAS에 실린 2023년 연구에서 앱을 열기 전에 잠깐 멈추게 했더니 SNS 사용량이 평균 57% 줄었어요. 다른 앱(one sec)을 대상으로 한 연구예요. 그래서 DopaBreak에서도 같은 효과가 난다고 보장할 순 없어요. 그래도 원리는 같아요. 먼저 나가는 손을 한 박자만 붙잡으면 그 반사가 힘을 잃거든요.

■ 주요 기능

- 열기 전 숨 고르기. 어떤 앱에서 얼마나 멈출지 직접 정해요
- 잠금 화면에 목표 표시. 알림과 위젯으로 하루 내내 보여요
- 다 보고 난 뒤 기분 기록
- 열려고 한 횟수와 열지 않은 횟수 통계

■ DopaBreak Pro

무료로 시작할 수 있어요. Pro에서는 멈출 앱과 목표를 무제한으로 추가해요. 지난 기록 전체와 잠금 화면 테마까지 다 쓸 수 있어요.

- 월 9,900원 / 연 49,000원 (7일 무료 체험) / 평생 이용권 149,000원
- 요금은 Apple ID 계정으로 청구돼요. 기간 종료 24시간 전까지 해지하지 않으면 자동 갱신돼요. 해지는 기기 설정의 구독 메뉴에서 언제든 할 수 있어요.
- 이용약관: https://saku1110.github.io/dopabreak-legal/terms-ko.html
- 개인정보 처리방침: https://saku1110.github.io/dopabreak-legal/privacy-ko.html
```

v1→v2の主な変更（Opus5独立レビュー指摘のFable採否判断済み）: ①`동료 평가를 거친 연구`=peer-reviewedの直訳カルク→`국제 학술지 PNAS에 실린 연구`＋他動詞`줄였어요`の主語ねじれを`멈추게 했더니 ~ 줄었어요`で解消 ②`무심코가 아니라`（副詞+주격조사の文法不安定）→`무심코 열던 앱을 이제 알고 열게 돼요` ③内部用語`대상 앱`→`내가 정해 둔 앱`/`멈출 앱`、`강도`→`얼마나 멈출지`（オーナー恒久指示「UI文言に内部用語を使わない」準拠） ④`홈 화면`はiOSホーム画面と誤読→`앱 첫 화면` ⑤`브레이크 한 번`の電報調→慣用形`브레이크를 한 번 걸어요` ⑥`₩9,900`→韓国慣行の`9,900원` ⑦`결제는~청구돼요`の重複ねじれ→`요금은 Apple ID 계정으로 청구돼요` ⑧**3.1.2対応: 利用規約/プライバシーポリシーの実URLを記載**（全ページHTTP 200確認済み） ⑨`전체 기간 기록`(all-time直訳)→`지난 기록 전체`・`테마도 열려요`(unlocked直訳)→`다 쓸 수 있어요`。인스타그램/유튜브の言及は説明的用法として維持（KW欄には入れない）。

---

## 検証済み事項（2026-07-24）

- **キーワード欄の上限は100「文字」（バイトではない）**。CJKは1字1カウント＝日本語/韓国語はむしろ有利（複数ASO一次情報で確認）。Codexが挙げた「バイト超過で launch-blocking」懸念は現行仕様では過剰。JP(58字)/KR(38字)とも問題なし。最終検証はASC投入時
- 全フィールド字数検証済み（US:30/29/98・KR:22/21/38/82・JP:28/22）
- Codex独立レビュー実施済み（P1/P2指摘を反映: US機構明示・KR脱説教/脱ブロック誤認・重複語除去）

## 次アクション

1. ~~韓国語のネイティブ最終確認~~ → **✅ 完了（2026-08-14）**: オーナー指示によりクロスモデル体制（humanizer-ko機械測定＋Opus5独立レビュー＋Fable採否判断）で実施。人間ネイティブ確認の代替である点は記録のとおり
2. **🔶 ASA検索ポピュラリティ実査 — オーナー作業でブロック中（2026-08-14調査済み）**:
   - `asc ads auth status` 実測: **Apple Ads API資格情報が未設定**（ASC本体の認証とは別系統）
   - 調査結果（Opus5・公式ドキュメント確認済み）: **広告未配信でSearch Popularity(1-5)を取れる正規ルートは管理画面のキーワード候補ツールのみ**。API側（Impression Share Report `searchPopularity`）は「自分の広告が表示された検索語」が行の起点のため、配信実績ゼロでは中身が空の公算が高い（公式明文なし・要実測）
   - **オーナー作業（最短経路・課金なし）**: Apple Ads管理画面（Advanced）→ キャンペーン作成フロー（下書きのまま）→ キーワード追加UIで JP/KR/US を切り替えてポピュラリティ(1-5)を目視。配信しなければ請求ゼロ
   - 検証対象キーワード: US=`screen time` vs `doomscrolling` vs `dopamine detox`（サブタイトル昇格判断）/ KR=v2.1追加語（`폰중독` `앱차단` `자기계발` 等）/ JP=キーワード欄最終化
   - API化する場合の注意: 鍵ペア生成→Account Settings>API公開鍵登録（オーナーのブラウザ作業）。ただし①custom-reports GETが2026-03以降403を返す既知問題 ②Campaign Management API v5は2027-01-26サンセット（後継=Apple Ads Platform API）のため、恒久実装は後継API確認後
   - **ポピュラリティ未実証でもローンチはブロックしない**（現キーワード欄は定性根拠で妥当。実測後に差し替えで足りる＝ローンチ後PPO/メタデータ更新で反映可能）
3. ~~各言語の説明文作成~~ → **✅ 3市場分作成済み**（ja/en/ko・humanizer全ゲート通過・koは2026-08-14 v2確定・**3言語とも利用規約/プライバシーポリシー実URL記載済み**=3.1.2対応・全URL HTTP 200確認済み 2026-08-14）
4. 確定後ASCへ投入（`asc metadata` / サブスクlocalizations ja/ko/en）— JPサブタイトルv2採用はdoc02c確定値の差し替えのため**オーナー承認待ち**
