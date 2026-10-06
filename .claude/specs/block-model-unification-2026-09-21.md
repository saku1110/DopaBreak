# ブロックの排他モデル廃止（2026-09-21 オーナー決定）

## 問題
`InterventionMode`（standard / deepFocus / nightOnly）が排他的な1値で、`usesShield` の2つ（deepFocus・nightOnly）はどちらもPro。Proを買っても**片方しか使えない**。
- `NightShieldScheduler.swift:102` は `mode == .nightOnly` のルールだけを拾う → deepFocus利用者に就寝中の自動ブロックが無い。
- `DeepFocusScheduler.swift:186` は `mode == .deepFocus || (mode == .nightOnly && weeklySchedulesDuringNightEnabled)` → 破綻を埋める追加フラグが既に入っている。
- オーナー指摘: 「PROにしたらどちらも使えるのになぜ選択させる？」

## あるべき形
- **一呼吸**: 対象アプリに対して常時（無料・現状どおり）。
- **ブロック（Pro）**: 1つの機能。きっかけを独立したスイッチで持つ。
  1. 手動セッション（いま30分〜2時間）
  2. 毎週の予定（曜日と時間帯・最大2件）
  3. 就寝中は自動（起床・就寝設定に連動）
- Proならこの3つすべてが使える。排他選択は無い。

## データモデル
- `InterventionMode` の3値選択を廃止し、`blockEnabled: Bool`（Pro権利と連動）＋ `blockTriggers: Set<BlockTrigger>`（manual / weeklySchedule / night）へ置き換える。
- 互換のため `InterventionMode` 自体は残してよいが、永続化・スケジューラの判定は新モデルを正とする。`usesShield` は `blockEnabled` に読み替える。
- **移行**: 既存の保存値を1回だけ変換する。`deepFocus` → blockEnabled=true, triggers={manual, weeklySchedule}／`nightOnly` → blockEnabled=true, triggers={night}（`weeklySchedulesDuringNightEnabled` が真なら weeklySchedule も）／`standard` → blockEnabled=false。移行後は `weeklySchedulesDuringNightEnabled` を廃止。
- 権利喪失時（Pro解約後の期限切れ）は `blockEnabled=false` に落とし、triggers の選択は保持する（再購入で復帰）。S1の方針と同じ。

## 画面
- **オンボーディング**: 「どこまで止めたい？」を二択にする。「開く前に一呼吸（無料・おすすめ・既定）」／「一呼吸＋ブロック（Pro・3日間¥0で試せる）」。その場でペイウォールは出さない。まとめ画面で出し分ける（既存の第2弾是正に従う）。
- **設定**: 「ブロック」セクションに3つのスイッチ。Pro未購入ならセクションごとロックし、タップでペイウォール。
- **ホーム**: 現在のモード表示を「ブロック: 手動／予定／就寝中」の状態表示に変える。`HomeView` の `currentMode == .nightOnly` 等の分岐を新モデルへ。
- **Live Activity・シールド文言**: きっかけ別の文言（手動＝残り時間、予定＝終了時刻、就寝中＝起床時刻まで）。既存文言を流用し、新規追加は最小限。

## 表示文言（トライアル3日化の反映も同時に）
- `paywall.plan.annual.intro_duration_fallback`（現「7日間」）と `paywall.plan.annual.intro_fallback`（現「7日間無料」）は**数字を書かない**表現へ（例: 「無料期間あり」）。期間はStoreKitの `introductoryOffer.period × periodCount`（`StoreService.swift:756`）から出す。数字のハードコードを二度と置かない。
- 1.0.2のストア説明文（ja/en/ko）の「7日間無料トライアル付き」等を3日間へ。`output/aso/2026-09-20-v1.0.2/` に反映。

## 検証
- 単体: 移行の3ケース、権利喪失と再購入、きっかけ3つの独立動作、Freeでブロックが動かないこと。
- 実機（オーナー）: Proで3つのきっかけが同時に効くこと。就寝中の自動ブロックと日中の手動セッションが両立すること。解約後の期限切れでブロックが止まり、再購入で設定が戻ること。
- release-monetization-check のAブロックに「ブロックのきっかけ3種」を追加する。

## 進め方
1. Core（モデル＋移行＋スケジューラ判定）とテスト
2. 設定・ホーム・Live Activity
3. オンボーディングの二択化
4. Opus5レビュー → 実機検証 → 1.0.2へ同梱

## 追補（2026-09-21 オーナー指摘）: まとめ画面のCTA
`onboarding.summary.action` の「この時間を守る」（en "Protect my time"）は、何の時間か分からず、直前の `onboarding.result.action`「この時間を取り戻す」とも重複する。二択の選択に応じて出し分ける。

| 選択 | ja | en | ko |
|---|---|---|---|
| ブロックも使う（Pro） | 3日間 ¥0 で始める | Start 3 days free | 3일 ₩0으로 시작하기 |
| 一呼吸だけ（無料） | このプランで始める | Start with this plan | 이 플랜으로 시작하기 |

ゼロ価格のみCTAに入れてよい（オーナー恒久指示・2026-08-28承認）。金額は書かない。期間の数字はStoreKitのオファーから出し、ハードコードしない。

## 追補2（2026-09-21 オーナー指摘）: 二択画面が伝わらない
「どこまで止めたい？」は抽象的で判断できない。Pro側のカードに**ブロックの種類**（手動・毎週の予定・就寝中）が出ていない（`onboarding.block.detail` を作ったが画面に出していない）。

差し替え:

| 要素 | ja | en | ko |
|---|---|---|---|
| 見出し | 止め方を選ぶ | Choose how to stop | 멈추는 방법 선택 |
| リード | あとから変えられます | You can change this later | 나중에 바꿀 수 있어요 |
| カード1 見出し | 開く前に一呼吸 | Pause before you open | 열기 전에 한숨 고르기 |
| カード1 補足 | 反射で開く手が止まる | Breaks the reflex to open | 무심코 여는 손을 멈춰요 |
| カード1 バッジ | 無料・おすすめ | Free · Recommended | 무료 · 추천 |
| カード2 見出し | 一呼吸＋完全ブロック | Pause plus full block | 한숨 고르기＋완전 차단 |
| カード2 箇条1 | いま30分〜2時間だけ開けなくする | Block now for 30 min to 2 hours | 지금 30분〜2시간 동안 차단 |
| カード2 箇条2 | 毎週の予定で自動ブロック | Blocks on your weekly schedule | 매주 예정대로 자동 차단 |
| カード2 箇条3 | 就寝中は自動ブロック | Blocks automatically while you sleep | 잠자는 동안 자동 차단 |
| カード2 補足 | %@ で試せる（期間と¥0はStoreKitから） | Try free for %@ | %@ 무료 체험 |
| カード2 バッジ | Pro | Pro | Pro |

- 箇条書きは3行とも表示する。カード2の高さが増えるぶん、画面の余白（現状は下半分が空）を詰める。
- 見出しに「？」は残さない。体言止め・句読点なし・中央揃えの規則に従う。
- 期間と金額は文字列に書かず `Product` の価格書式から出す（現状の実装を維持）。
