# 競合監査からの改善実装 — 2026-09-05

依頼: 「LiveActivityはいつ終わる？ 利用中の再介入って実装できる？ 実際の利用時間って情報取れるんだっけ？ 他は実装」

## 今回の範囲

直前の回答に挙げた改善を実装。Live Activity / ロック画面の常設Widget・利用中の再介入・実利用時間レポートは質問への回答対象として保留。監査報告の追加候補すべてを一括で実装したわけではない。対応アプリ追加、ブラウザ拡張、バックアップ、日次上限などは未着手。

## 実装結果

| 対応 | 実装 | 主なファイル |
| --- | --- | --- |
| F01 直接「開かない」 | 理由選択画面に固定CTAを追加。理由なしでキャンセルを記録。二重タップでも1件のみ | `ios/DopaBreak/InterventionFlow{Model,View}.swift` |
| F05 複数予定 | 毎週の予定を最大2件。各曜日・開始・終了・有効/無効を独立編集。追加予定を削除可 | `SettingsView.swift`, `AppContainer.swift`, `DeepFocusScheduler.swift`, Core `SettingsStore`, `DeepFocusShieldSnapshot`, `DeepFocusWindowPolicy` |
| F05 就寝との併用 | 夜だけ強化で「就寝中のブロックに予定を追加」を明示的にオンにした場合のみ併用 | `ShieldController.swift`, Core `ShieldSyncPolicy` |
| F06 強い手動セッション | 有限セッションに任意の強さを追加。通常解除・モード変更・対象変更・別セッションでの上書きを防止。緊急解除は30秒待機 | `StrictSessionExitView.swift`, `DeepFocusScheduler.swift`, `AppContainer.swift`, `HomeView.swift`, `SettingsView.swift` |
| F08 振り返りから行動 | 選択期間に5回答以上、lostTime/feltWorseが60%以上の場合に、回答数を添えて設定見直しを提案。設定へ移動するが自動変更しない | Core `ReflectionInsightPolicy.swift`, `StatsView.swift`, `RootTabView.swift` |
| R01 研究表現 | 利用時間の57%減ではなく、6週間継続参加者の対象アプリの実際の起動回数の平均57%減。one sec対象・本アプリの効果非保証の注記は維持 | `OnboardingFlow.swift`, `Localizable.xcstrings` |
| R02 状態の正確さ | 監視失敗も注意対象にし、ホームで稼働中と断定しない。設定に再試行を追加。部分的に登録できなかった曜日は拡張の控えから除外 | `ShieldArmingState.swift`, `HomeView.swift`, `SettingsView.swift`, 各Scheduler |
| R03 Pro説明 | 白黒設定をPro特典から除外。無料の手順案内は維持。「何個でも」を対応アプリの登録数制限解除へ変更 | `PaywallView.swift`, `Localizable.xcstrings`, docs 06/11/15 |

SwiftUIの既存ダーク色・ライムアクセント・カード・文字組みを維持。ピッカー、Toggle、Buttonなど標準部品で追加。表示文言はja/en/koを揃えた。

## 実装上の制約・移行

- 開く前の一呼吸はShortcuts、完全ブロックはScreen Timeという既存の分離を維持。廃止された常時Gateを復活させていない。
- 予定1は既存の4個の保存キーをそのまま使用。追加予定だけ別キーで保存。旧JSONの`additionalSchedules`なしを正しく読める。
- 毎日2予定で14監視、有限セッション1、夜間1の計16。1件目の活動名は維持し、2件目を別名にした。監視停止時は旧名も含めて止める。
- 複数予定は共通の完全ブロック対象を使う。予定ごとの別アプリグループは未実装。
- 就寝モードで眠っていた古い週次設定が更新後に突然動かないよう、併用フラグの既定値はfalse。フラグはデータ削除対象のキー一覧にも登録。
- Monitor Extensionはコールバックの名前だけで解除せず、保存された全予定と手動セッションの和集合を時刻で検算する。片方の終了で残りまで外さない。
- 部分監視失敗時は、成功した曜日・セッションだけを控えに残す。前面のShield適用も控えから窓を確認する。失敗した予定を、別のコールバックで誤って掛け直さない。
- ホームの残り時間は重なる/隣接する予定・就寝時間・手動セッションを結合して算出。日付計算にCalendarを使う。手動終了通知は他の予定まで解除されたと誤解させない文面に変更。
- 強いセッションは既存の30分/1時間/2時間の選択肢で使える。スケジューラは15〜240分の範囲を検証し、無期限の強いセッションは受け付けない。
- 強いセッションの通常解除拒否は画面だけでなくモデル/スケジューラでも実施。緊急解除の開始日時を保存するため、シートを閉じたりアプリを再起動したりしても待機を飛ばせない。
- 緊急解除は手動セッションのみ。週次/就寝ブロックは独立して継続。この制約を解除画面に明記。回数制限は設けていない。
- iOS設定からの権限取り消し、アプリ削除、ユーザーデータ削除までは封じない。「絶対に回避不能」とは宣伝しない。データ削除権限を奪うための機能ではない。
- 振り返り提案は記録した回答の集計であり、実利用時間、因果推論、医療的診断ではない。アプリ別・時間帯別提案は今後の拡張。
- 既存の未コミット変更を維持し、Git commitは作成していない。

## 質問への回答・保留仕様

### Live Activity

1回につき稼働は最大8時間。その時点でDynamic Islandから消え、ロック画面には追加で最大4時間（開始から最大12時間）残りうる。ユーザー操作やアプリの終了処理でそれより早く消えることもある。

現行`LockSurfaceCoordinator.performLiveActivityRefresh`は前面復帰時に再作成。目標なし・機能オフなどでも終了する。24時間常設を保証するものではない。

出典: [Apple ActivityKit](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)

### 利用中の再介入

実装可能な経路はScreen TimeのDeviceActivityEventしきい値を受け、ManagedSettingsのシールドを出す方法。別アプリ上に自由なSwiftUI全画面を割り込ませる方法ではない。

現在のカタログID/URL schemeと、FamilyActivityPickerのApplicationTokenをユーザーに1アプリずつ結び付けてもらう設計が必要。one secもこの接続を要求している。過去使用分の扱い、OSバージョン分岐、通知と強制制限の違い、閾値コールバックの遅延/不発を実機で検証する必要がある。秒単位の正確な再介入は保証しない。

出典: [one sec再介入](https://tutorials.one-sec.app/en/articles/3035202)、[Apple includesPastActivity](https://developer.apple.com/documentation/deviceactivity/deviceactivityevent/includespastactivity)

### 実際の利用時間

Screen Timeの許可後、DeviceActivityReport Extension内で実利用データを取得・集計し、アプリ画面にレポートを表示できる。ただし通常のAPIのように生データを本体DBやサーバーへ自由に渡せる仕組みではない。レポート拡張にはネットワーク・拡張外への機微データ持ち出しの制限がある。

推奨は記録タブにレポートを埋め込み、現行の「取り戻した時間（推計）」と明確に区別する設計。常時動く計測タイマーや、他アプリのリアルタイム使用状態を本体へ無制限に返すAPIとは異なる。

出典: [Apple DeviceActivityReport](https://developer.apple.com/documentation/deviceactivity/deviceactivityreport)、[WWDC22 Screen Time API](https://developer.apple.com/videos/play/wwdc2022/110336/)

## 実機での検収（未実施）

1. 旧版の予定1だけある端末で更新し、同じ曜日/時間が残り、予定2と就寝併用が勝手に有効にならないこと。
2. 予定1 20:00〜21:00、予定2 20:30〜21:30で、アプリを終了しても20:00開始・21:00継続・21:30解除。
3. 曜日限定・日曜→月曜の跨日・予定削除・設定変更後の古いコールバック・端末再起動を確認。
4. 就寝併用をオン/オフし、夜間と週次の重なりで片方だけ外しても他方が継続すること。
5. 強い手動セッションで通常解除/モード変更/対象変更が拒否され、30秒待機後の緊急解除と時刻終了が働くこと。再起動中の待機も確認。
6. 権限拒否/取り消し、StoreKit未確定、監視失敗時に成功表示しないこと。権限/接続回復後の再試行。
7. 予定・就寝・手動が重なった時のホーム残り時間、手動終了通知の内容、シールド解除を照合。
8. 小型端末と文字サイズ最大、VoiceOver、ja/en/koで理由画面の「開かない」、2予定の編集、緊急解除が操作可能なこと。

SimulatorでScreen TimeのOS強制制限そのものを保証したとは扱わない。App Store公開/実機検収は今回行っていない。

## 検証結果

- Xcode / 全拡張を含むSimulatorビルド: 成功。
- Core: 558テスト、0失敗（旧保存形式、2予定、跨日、隣接/重複、DST、手動枠との結合、就寝併用オプトイン、緊急解除の再読込・期限、振り返りの件数条件）。
- アプリ全体: 343テスト、18スキップ、0失敗。スキップは既存の手動撮影等。
- 最後の変更に関連する再テスト: 101テスト、1スキップ、0失敗。件数は全体との重複を含む。
- 新UI: `output/verify/competitive-improvements/direct-cancel.png` と `emergency-exit.png` をSimulatorでレンダリングして目視。理由6択と下部「開かない」、緊急待機開始と継続の導線を確認。
- ja/en/ko String Catalog、Swift日本語defaultValue: 不一致0、欠落0。コピーlintと`git diff --check`: 成功。
- 専用Simulator: `DopaBreak-Competitive-QA` / `FBF4AE40-1EF6-4F12-A7E1-B1E75DB6FE5F` / iOS 26.5。他の作業のSimulatorを停止・初期化していない。
- 証跡: `.claude/verification-logs/2026-09-05-competitive-improvements/`。実機での検収が済んだとは扱わない。
- 緊急解除の大きな文字サイズに備えたScrollView追加後、画面レンダリングの1テストを再実行し成功（`ui-render-test.log`）。最大文字サイズの全言語・全実機検収は上記の未実施項目に含む。
