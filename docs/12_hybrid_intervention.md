# ハイブリッド介入方式 設計書（正本）

作成: 2026-07-08 / **オーナー承認済み（方式C: ハイブリッド）**

> **追記（2026-07-08 オーナー指示・MVPスコープ確定）**
> 1. **目標はフラットな複数リスト**（2026-07-08 オーナー指示: 「複数追加できるが、1年/人生では分けない」）。種類ラベル・2枠構造・「Proで表示」バッジ廃止。Free=1件・Pro=無制限（従来の年目標ゲートを件数ゲートに置換。オーナー拒否権あり）
> 1b. **目標の表示（2026-07-08 オーナー指示・確定）**: 「先頭1件」方式は廃止。
>    - **一呼吸（介入フロー）の目標画面**: 見出し「あなたの目標」の下に**全目標を箇条書き**で表示
>    - **Live Activity（SNSを見た後・実装(11)）**: **全目標を表示**（SNS利用後のロック画面で目標一覧が目に入る設計）
>    - ロック画面用の短い表示名は各目標が持ち、Live Activity等の短尺面で使用
> 2. **MVP = one sec方式の一気通貫のみ**（§2のフロー全部）。完全ブロック(シールド)は**v1.1へ保留** — コードは温存し、MVPではshield同期を無効化
> 3. 検収 = オーナー実機で「オートメーション設定→SNSタップ→自動起動→呼吸→理由→復帰/勝ち→統計反映」が途切れず動くこと
> 4. **2026-07-10: Free対象アプリは初回14日=3・以降1（ディベート合意・オーナー承認スコープ）**

## 0. 決定の経緯（2026-07-08 実機検証で判明）

- 実装(3)-(6)のシールド方式は、iOS制約により「静的画面・2ボタン・アニメ不可・自動でDopaBreakへ遷移不可」が体験の上限。
- オーナーの想定体験は one sec 型：**対象アプリを開く → DopaBreakが自動で開く → 呼吸アニメで遅延 → 理由を聞く → 元アプリへ復帰**。
- one sec はシールドではなく**ショートカットのオートメーション**で介入を実現している（本人確認済み）。
- 決定: **方式C ハイブリッド**。毎回の介入= one sec方式、完全ブロック= シールド方式（Pro価値）。

## 1. 方式マップ（InterventionMode の意味を再定義）

| モード | 介入 | 実現手段 |
| --- | --- | --- |
| standard（標準） | 開くたびに介入フロー（呼吸→理由→復帰） | ショートカット・オートメーション → DopaBreak起動 |
| deepFocus（ディープフォーカス・Pro） | 介入フロー ＋ 指定時間帯は完全ブロック | オートメーション ＋ FamilyControlsシールド |
| nightOnly（夜だけ強化） | 日中=介入フロー、夜間=完全ブロック | オートメーション ＋ 夜間のみシールド |

- 実装済みのシールド(3)-(6)は**deepFocus/nightOnlyの強制層として全面活用**（破棄しない）。
- standardモードでは**シールドを適用しない**（ShieldControllerの同期条件を変更）。

## 2. 通常介入フロー（one sec方式）の構成

```
対象アプリ（例: Instagram）をタップ
→ iOSオートメーション発火（「Instagramが開かれたとき」→ DopaBreak介入インテント実行）
→ DopaBreakが前面に起動し介入フロー表示
   S-01 「なんのために開く？」（仕事/調べ物/連絡/投稿/暇つぶし/なんとなく）
   ├ 目的が明確（仕事/調べ物/連絡/投稿）
   │  → 呼吸・回数・目標確認を省略 → 必要時間を選択
   └ 反射的（暇つぶし/なんとなく）
      → 呼吸アニメ（3/5/8秒）→「今日はもう N回目」→目標リマインド→決定
   S-05 決定（反射的な目的のみ）
        [開かずに戻る] → 勝ち画面「開かなかった あなたの勝ち」→ ホームへ
        [時間を決めて開く] → 5/10/15/30分を選択 → [N分だけ開く]で確定 → URLスキームで元アプリへ復帰
→ 時間経過で通知「そろそろ N分。見てどうだった？」
→ DopaBreak復帰時に「見たあとの振り返り」（既存 pendingReflection）
```

### 技術要素
- **AppIntents**: `StartInterventionIntent(appID:)`（`openAppWhenRun = true`）。オートメーションから実行されDopaBreakを前面起動。
- **URLルーティング**: `dopabreak://intervene?app={catalogID}` も受け付ける（ショートカットURL方式のフォールバック）。
- **InterventionEngine は全面再利用**: beginIntervention → advanceStep → recordIntent → recordCancel / recordOpen(duration)。AttemptLog/ReflectionLog/統計/週次レポートはそのまま機能する。
- **復帰**: アプリカタログのURLスキームで `openURL`。スキーム無しアプリは「ホームに戻って開き直し」案内。
- **時間切れ**: UNUserNotificationCenter でローカル通知（強制終了はstandardでは不可。deepFocus/nightOnlyはシールドが再ブロック）。
- **時間選択UI**: プリセットをタップした時点では開かず、選択枠をライムで表示する。下部CTA `[N分だけ開く]` で確定してから`recordOpen`と対象アプリ復帰を実行する。
- **時間表示の誠実性**: 「時間が来たら自動で閉じます」は禁止。standardは「時間になったら通知でお知らせします」と表示する。

## 2b. ビジュアル階層（2026-07-12 モック実装反映）

- 目的確認・呼吸・回数・目標・判断・時間選択は無写真のE1 Dark Mono。
- 理由は2列×3段の6カード。カード高は約118pt、主要タップ領域44pt以上。
- 勝ち画面は丸い成功リングではなく、角丸カード内のチェックを使う。
- 朝焼け写真はHome等の感情的アンカーに限定し、介入中には表示しない。

## 3. 対象アプリカタログ（SNSAppCatalog・Core）

FamilyActivityPickerのトークンは不透明でURLスキームに変換できないため、**通常介入の対象アプリは自前カタログから選択**する（オンボO-03の汎用アイコン選択と整合）。

| catalogID | 表示名 | URLスキーム | オートメーション対象Bundle |
| --- | --- | --- | --- |
| instagram | Instagram | instagram://app | com.burbn.instagram |
| x | X | twitter:// | com.atebits.Tweetie2 |
| tiktok | TikTok | snssdk1233:// | com.zhiliaoapp.musically |
| youtube | YouTube | youtube:// | com.google.ios.youtube |
| facebook | Facebook | fb:// | com.facebook.Facebook |
| threads | Threads | barcelona:// | com.burbn.barcelona |
| line | LINE | line:// | jp.naver.line |
| safari | Safari | なし（案内のみ） | com.apple.mobilesafari |

- FamilyActivityPicker（トークン選択）は**deepFocus/nightOnlyのシールド対象設定**として残す。設定画面では「止めるアプリ」（カタログ・通常介入）と「完全ブロックの対象」（Picker・Pro）を分ける。

## 4. オートメーション設定ガイド（最大の離脱ポイント・one secと同様）

- オンボーディングO-08区画に**アプリごとの設定ガイド**を追加：
  1. ショートカットAppを開く（`shortcuts://` で直接起動）
  2. オートメーション → ＋ → 「App」→ 対象アプリ →「開かれたとき」→「すぐに実行」
  3. アクション「DopaBreakで一呼吸」（AppIntent）を選択
- 設定完了の検知は不可（iOS制約）→「テストする」ボタンで対象アプリを開かせ、介入が出れば完了扱い。
- 設定画面にも同ガイドへの導線（アプリ追加時に都度）。

## 5. 既存実装への影響

| 対象 | 変更 |
| --- | --- |
| ShieldController | standardでは適用しない。deepFocus/nightOnly のルールのみ shield 同期 |
| ShieldConfigurationExtension | 文言を「完全ブロック中」向けに変更（Deep Focus価値の訴求。ボタンは[閉じる]系） |
| 設定画面 | 「止めるアプリ」= カタログ選択に変更。「完全ブロック」= Picker（Pro・deepFocus/nightOnly） |
| オンボO-03 | カタログ選択に接続（現行の汎用アイコン選択と同一UX） |
| ペイウォール | 文言変更なし（「止めるアプリを何個でも追加」はカタログ側の制限に適用。Free=1個） |
| EntitlementGate | 変更なし（targetAppTokensLimit=カタログ選択数に適用） |
| 戻る先バグ | シールドはDeep Focus専用になるため優先度低（シールド文言改訂時に確認） |

## 6. 実装分割（Codex委譲）

- **(H1) 基盤**: SNSAppCatalog（Core・テスト）／InterventionSelectionStore（カタログ選択の保存・Free=1個ゲート）／AppIntent＋URLルーティング／設定画面の対象アプリUI差し替え
- **(H2) 介入フローUI**: S-01〜S-05画面（呼吸アニメ・N回目・目標・理由・決定）／復帰deep link／時間切れ通知／振り返り接続／勝ち画面
- **(H3) シールド再配置**: モード別shield同期・シールド文言改訂・オンボO-08ガイド・完全ブロック設定UI

検収基準（オーナー実機テスト・一気通貫）: オートメーション設定 → Instagramタップ → DopaBreak自動起動 → 呼吸 → N回目 → 目標 → 理由 → [開く]でInstagram復帰 or [開かずに戻る]で勝ち画面 → 統計に反映。
