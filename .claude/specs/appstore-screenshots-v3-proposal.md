# App Store スクショ v3 — 8枚アップロード構成・訴求ベース再編（生成画像9枚・2026-08-25反映）

反映済み: 2026-08-25（生成スクリプト・v2設計正本・3ロケール成果物・upload-orderへ反映）

根拠: オーナー指示「1〜3枚目はCVR直結。訴求ベースでインパクトとベネフィット重視」「端末内保存の枠は不要」「モックは画面が切れなければ筐体が切れてもいいので拡大」＋ 整合性監査（11件）の反映。
humanizer監査: en/ko とも audit.py exit 0（全ゲート通過）。ja は表示コピー規則（読点・句点なし）適合。

> **2026-08-25 オーナー確定**: アップロード対象は 1=一呼吸 → 2=ロック画面の目標 → 3=集中・勉強のタイマー → 4=ホーム → 5=夜だけ強化 → 6=理由選択 → 7=振り返り → 8=白黒ホーム。生成ID05の記録(stats)画像・raw・撮影経路は保持するが、ホームと内容が重複するためアップロード構成から不採用（オーナー指示 2026-08-25）。上位3枚＝差別化機能（一呼吸→ロック画面の目標→集中タイマー[勉強70/集中60]）。成果の数字（ホーム312時間）は4枚目。

改訂案適用日: 2026-08-25（オーナー指示により先頭の改訂案を正本として適用）

## パネル構成（アップロード順）と画面ソース

| 順 | 生成ID | 画面(raw) | 備考 |
|---|---|---|---|
| 1 | 01 | breath.png | 画面内キャラ1体。残り秒数字まで見える位置 |
| 2 | 03 | mock_lock | 9:41と目標Live Activityを表示。eyebrowから「通知・ウィジェット」を削除 |
| 3 | 06 | deepfocus.png | sub に「解除するまで」追加 |
| 4 | 02 | home.png | 取り戻した時間・累計312時間・13日分・連続7日が写る |
| 5 | 04 | nightmode.png | raw-coreの最新をバッチ最後に生成 |
| 6 | 08 | intent.png | 時間選択は別画面のため理由のみの訴求へ |
| 7 | 09 | reflection.png | 統計の主張を外し本音の記録に絞る |
| 8 | 10 | **mock_home_grayscale()**（PILで描くiOSホーム画面モック・SNS8タイル＋Dock・全面白黒） | **2026-08-25オーナー指示で grayscale.png（ガイド実画面）から差し替え済み。** 正本 `.claude/specs/appstore-screenshot-10-grayscale-home-2026-08-25.md`。`SOURCE_PATHS[10]=None`・`MOCK_SOURCE_NAMES[10]`・`source_for()` の10分岐・`UPLOAD_ORDER (10,"grayscale-home")` を巻き戻さないこと |

### 不採用の生成ID05（記録・stats）

`stats.png` は生成番号05の画像・`raw-core/{locale}/stats.png`・撮影経路として保持し、`SCREEN_CHARACTER_COUNTS` のraw実態5体とstats専用の可視領域ガードも維持する。ホームと内容が重複するため、オーナー指示（2026-08-25）により不採用とし、`UPLOAD_ORDER`、3ロケールの`upload-order/{locale}/iphone-69/`、contact-sheet、slotsの8件には含めない。生成番号のファイル自体は削除しない。

ロック画面を2枚目、集中タイマーを3枚目へ繰り上げ、上位5枚の訴求を差別化機能→成果の数字→夜の機能へつなげる。

## コピー（確定候補・3言語）

### 1 一呼吸
- ja: 禁止しないアプリ制限 / SNSをブロックしない／開く前にひと呼吸 / 反射で開く瞬間にだけ短いブレーキ
- en-US: NOT ANOTHER APP BLOCKER / Don’t block social media／Pause before you open / A short break interrupts the reflex. You still choose.
- ko: 차단이 아니라 브레이크 / SNS를 막지 않아요／열기 전에 숨 고르기 / 반사적으로 여는 순간에만 잠깐 브레이크를 걸어요

### 2 ホーム
- ja: SNSに消えるはずだった時間 / 「溶けた時間」が／人生の時間に変わる / 積み上がった時間が何日分かまでホームに
- en-US: DOPAMINE DETOX, COUNTED IN HOURS / Hours you would have lost to scrolling／are yours again / See how many days it adds up to, right on the home screen.
- ko: SNS에 뺏기지 않은 시간 / 녹아 없어질 뻔한 시간이／내 인생의 시간으로 돌아와요 / 쌓인 시간이 며칠치인지까지 홈에서 봐요

### 3 ロック画面
- ja: ロック画面の目標 / SNSを開くたびに／目標を確認 / ロック画面に目標と開くのをやめた回数を表示
- en: LOCK SCREEN GOALS / Your goals, every time／you reach for social media / Your goals and skipped opens sit on the lock screen
- ko: 잠금 화면 목표 / SNS를 열 때마다／목표를 확인해요 / 잠금 화면에 목표와 열지 않은 횟수가 보여요

### 4 集中タイマー
- ja sub: 30分から解除するまで 曜日と時間帯の予約も（eyebrow/headline 現行維持）
- en sub: From 30 minutes to until you lift it, plus weekly time slots
- ko sub: 30분부터 해제할 때까지 요일과 시간대 예약도 돼요

### 5 夜だけ強化（変更なし・現行コピー維持）

### 不採用: 生成ID05 記録（stats）
- ja: 今日の記録 / 開こうとした15回のうち／12回はやめられた / どのアプリを何回やめたか まで残る
- en: TODAY'S RECORD / Reached for it 15 times／stopped 12 of them / Which app, and how many times. It all stays.
- ko: 오늘의 기록 / 열려고 한 15번 중／12번은 참았어요 / 어떤 앱을 몇 번 참았는지까지 남아요

### 6 理由選択
- ja: 理由を選ぶ / 何のために開く？／理由を決めてから使う / 目的を言葉にして反射で開くのを止める
- en: CHOOSE A REASON / Know why you're opening／then decide to use it / Put the purpose into words and the reflex loses its grip
- ko: 이유 선택 / 왜 여는지 먼저 확인／이유를 정하고 써요 / 목적을 말로 정하면 무심코 여는 손이 멈춰요

### 7 振り返り
- ja: 見たあとの本音 / SNSを見たあと／本音を一つ選ぶだけ / 5つの気持ちから選ぶ 次に開く前の材料になる
- en: HONEST CHECK-IN / After you scroll／pick one honest feeling / Five moods to choose from. It shapes your next decision.
- ko: 본 뒤의 솔직한 기분 / SNS를 본 뒤／솔직한 기분 하나만 골라요 / 다섯 가지 기분에서 하나를 고르면 다음에 열기 전 판단 재료가 돼요

### 8 白黒 → **test-project-16 の正本に従う（2026-08-25 オーナー別指示）**
- 画面: AutomationGuideView 実画面ではなく PILモック `mock_home_grayscale()`（SNSアイコンが並ぶiPhoneホーム画面を全面白黒化）。slug `grayscale-home`
- コピー・モック仕様の正本: `.claude/specs/appstore-screenshot-10-grayscale-home-2026-08-25.md`（ja: 白黒フィルタ連携 / 色を消して／SNSをつまらなくする / SNSを開くと自動で白黒に サイドボタン3回の手動切替も）
- 生成スクリプト保存前に 16 の4点（SOURCE_PATHS[10]=None×2 / MOCK_SOURCE_NAMES 10 / source_for panel==10 / UPLOAD_ORDER (10,"grayscale-home")）を機械チェックする

## 法務メモ
- 1枚目の旧「あと5分だけ」／「1年で35日になる」などの35日の損失フックは不採用。承認済みコピーは、アプリをブロックせず、開く直前に短いブレーキを置く機能事実へ戻した。
- 不採用の生成ID05 statsにある「15回のうち12回」はデモシードの記録値と一致するが、アップロード対象には含めない

## 判断待ち
- 3/5 が設定画面（「設定画面は使わない」ルールとの衝突）→ オーナー指示由来の枠のため残す前提。外すならオーナー判断

## 旧案 2026-08-25: ホーム主役指標の変更に伴う 2枚目コピー（下記の確定案Aで失効）
この節のコピーは履歴としてのみ残し、生成・実装には使用しない。
根拠: `.claude/specs/home-hero-lifetime-time-2026-08-25.md`（オーナー決定）。「取り戻した時間」週カードと「1年で約N日分」予測が削除され、ヒーローは永久累計「SNSに消えるはずだった時間」＋「今日 +N分」＋根拠行になる。
humanizer: en/ko とも audit.py exit 0。ja は読点・句点なし。数字はコピーに入れず画面内表示に任せる。
- ja: 消えるはずだった時間 / SNSに消えるはずだった時間が／減らずに積み上がる / 積み上がった時間と 日数換算をホームに
- en: TIME SOCIAL MEDIA DIDN'T TAKE / Every minute you kept／keeps adding up / Hours keep stacking up, with the days they add up to.
- ko: SNS에 뺏기지 않은 시간 / 지켜낸 시간이／줄지 않고 쌓여요 / 쌓인 시간과 일수 환산을 홈에서 봐요
※ 改訂2（2026-08-25）: 累計は日・年へ繰り上げず常に時間表記＋横に日数換算。sub を上記へ更新（en/ko audit exit 0）。オーナー指示: スクショの累計は100時間以上（例 312時間→13日分）。
適用手順: 46の改訂2確定 → home.png 3ロケール再撮影 → 上記コピーへ差し替え → パネル2再生成（保護6群チェック維持）


## 確定 2026-08-25: 2枚目（ホーム）見出し＝案A（オーナー決定・/sales-copy 5案から選定）
- ja: SNSに消えるはずだった時間 / 「溶けた時間」が／人生の時間に変わる / 積み上がった時間が何日分かまでホームに
- en-US: DOPAMINE DETOX, COUNTED IN HOURS / Hours you would have lost to scrolling／are yours again / See how many days it adds up to, right on the home screen.
- ko: SNS에 뺏기지 않은 시간 / 녹아 없어질 뻔한 시간이／내 인생의 시간으로 돌아와요 / 쌓인 시간이 며칠치인지까지 홈에서 봐요
- 根拠: VoC「気づいたら2時間溶けてた」「また時間溶かした」。en は "lost to scrolling"（英語圏の生の表現）へ transcreation、ko は「시간 녹았다」がスラングとして定着しているため 녹다 を維持。humanizer en/ko audit exit 0
- 却下: 「減らずに積み上がる」（仕組みの説明で得が無い・オーナー指摘）
