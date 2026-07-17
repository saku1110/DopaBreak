# DopaBreak iOS App 設計ドキュメント

作成日: 2026-06-27 / 改訂: 2026-07-02（doc間矛盾の解消・目標ヒーロー軽量版へ統一・価格確定・名称調査反映）

> **名称について**: 正式名 **DopaBreak**（2026-07-02 オーナー承認・docs/モック一括リネーム済み）。識別子: bundle `com.dopabreak.app` / App Group `group.com.dopabreak.shared` / 商品ID `dopabreak.pro.*`。ドメイン取得は見送り、商標の正式DB検索は提出前に実施。経緯は [09_market_verification.md](./09_market_verification.md) §5。
>
> **UI文言の正本は [11_ui_copy.md](./11_ui_copy.md)**（2026-07-02新設）。実装は転記のみ。内部用語（介入/シールド等）をUIに出さない。

## 最新方針

DopaBreakは、SNS依存を更生して人生に集中するためのiOSアプリ。

X、Instagram、TikTok、YouTubeなどを開こうとした瞬間に、一呼吸、使用状況、意図確認、必要時間の選択を挟む。one secのような「開くまでの遅延」を土台にしつつ、主目的は時間管理ではなく、無意識スクロールを止めて現実に戻すこと。

## スコープ判断（2026-07-02 確定: 目標ヒーロー軽量版）

入れないもの:

- アファメーション
- 今日の一歩
- 複数タスク
- 期限
- チェックリスト
- リマインダー
- プロジェクト管理
- ビジョンボード
- 引き寄せ訴求

入れるもの（軽量目標・二層構造）:

- **目標表示＝ヒーロー（看板/マーケ主役）**: ヒーロー目標1つ＋1年の目標1つの**2枠のみ**。ロック画面ウィジェットと介入時にだけ表示する。
- **SNSゲート＝エンジン（日次の実用機能）**: 開く前の遅延、意図確認、使用状況の可視化、必要時間だけの開放、利用後リフレクション。

自己啓発やタスク管理に見える要素は入れない。

ロック画面の戻る先表示は**朝の目標通知＋デイリーLive Activity**（2026-07-02: 常設ウィジェット廃止・手動設置ゼロ化）。フル目標文＋今日の実績（止まれた回数・取り戻した時間）を表示し、テーマ6種（Free=E1/Pro=5種）を適用できる。表示するのは「人生の方向性」や「戻る先」であり、タスク、期限、チェックリストにはしない。ホーム画面ウィジェットは維持。

## 最新追記: 利用後リフレクション

SNSを使った後に「見てどうだったか」を短く質問し、ユーザー自身がSNS後の満足感を観察できる機能を追加する。

目的:

- SNSを責めるのではなく、見た後の感覚を記録する。
- 「満足感があった」「楽しかった」「何も得られなかった」「時間を失った感じがする」などを選ばせる。
- 週次で、SNSが幸福感や集中に本当にプラスだったかを可視化する。
- ユーザーが自発的に開く回数を減らしたくなる状態を作る。

iOS制約:

- 他社SNSアプリを閉じた瞬間を、サードパーティアプリが完全に検知することはできない。
- MVPでは、選択時間の終了時、再シールド時、DopaBreakに戻った時、または通知で近似する。
- 画面上の表現は「閉じた瞬間に必ず出る」ではなく「利用後に振り返る」にする。

## ドキュメント一覧

| ファイル | 内容 | 状態 |
| --- | --- | --- |
| [FABLE_BRIEF.md](./FABLE_BRIEF.md) | 単一入口（Single Source of Truth）。まずこれを読む | 現行 |
| [01_business_design.md](./01_business_design.md) | 事業設計・**確定価格**・ユニットエコノミクス | 現行（2026-07-02改訂） |
| [02_marketing_strategy.md](./02_marketing_strategy.md) | マーケティング戦略。国別戦略の土台 | 土台 |
| [02b_marketing_psychology_strategy.md](./02b_marketing_psychology_strategy.md) | 心理×文化マーケ戦略 | 現行の主戦略 |
| [03_product_spec.md](./03_product_spec.md) | 製品仕様。目標は「軽量2枠」で読む | 土台 |
| [04_functional_requirements.md](./04_functional_requirements.md) | 機能要件（目標2枠・クイズ・課金確定を反映） | 現行（2026-07-02改訂） |
| [05_detailed_design.md](./05_detailed_design.md) | iOS詳細設計・データモデル。実装の土台 | 現行 |
| [06_screen_design.md](./06_screen_design.md) | 画面設計（全29画面・v2モックと1:1） | 現行（2026-07-02全面改訂） |
| [07_onboarding_design_lifefocus.md](./07_onboarding_design_lifefocus.md) | オンボーディング設計（14ステップ・損失顕在化フロー） | 現行（2026-07-02改訂） |
| [09_market_verification.md](./09_market_verification.md) | 市場・審査・名称の事実確認（2026-07-02） | 現行 |
| [10_familycontrols_entitlement.md](./10_familycontrols_entitlement.md) | FamilyControls entitlement申請パッケージ（オーナー実行手順＋貼付英文） | 現行（Phase 2最優先） |
| [11_ui_copy.md](./11_ui_copy.md) | **UI文言集（正本）** — 全画面の確定文言・語彙ルール | 現行（2026-07-02新設） |
| [CHANGELOG.md](./CHANGELOG.md) | 改訂履歴・差分メモ | - |

## 重要な設計判断

1. MVPはiOSネイティブ SwiftUI を推奨する。
   Screen Time API、Shield Extension、WidgetKitとの相性を優先するため。

2. one secの完全コピーは避ける。
   遅延/深呼吸だけで勝負せず、「無意識に開く前に止まり、理由を選び、必要時間だけ開く」体験にする。

3. 表の訴求は「SNS依存から人生に戻る」。
   引き寄せや生産性管理ではなく、SNS依存改善、デジタルウェルビーイング、集中回復の文脈で展開する。

4. データは原則オンデバイス。
   使用アプリ情報はセンシティブなため、Screen Time APIのプライバシー前提に合わせ、サーバ送信を最小化する。

5. 利用後リフレクションは行動変容の中核にする。
   開く前の意図確認だけでなく、使った後の満足感を記録し、「次は本当に開くか」をユーザー自身が判断できるようにする。

## 参照した公式情報

- Apple Screen Time API: https://developer.apple.com/videos/play/wwdc2021/10123/
- Apple FamilyControls: https://developer.apple.com/documentation/FamilyControls
- Apple ManagedSettings: https://developer.apple.com/documentation/ManagedSettings
- Apple DeviceActivity: https://developer.apple.com/documentation/DeviceActivity
- Apple WidgetKit: https://developer.apple.com/documentation/widgetkit
