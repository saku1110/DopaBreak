# 是正バッチ レビュー指摘の修正（2026-08-29・Opus5レビュー Round 1）

対象: `settings-home-device-fixes-2026-08-28.md`（F1/F2/F4/F3基盤）の実装に対する独立レビュー指摘8件。行番号はズレている可能性があるためシンボル名で特定すること。

## R1. 🔴 F4: 最小間隔1時間が直線軸で、跨日就寝（bed < wake）を破壊する
- 場所: `WakeSleepTimelinePolicy.clamped(wake:bed:)` ＋ `SettingsView.updateTimeline`
- 問題: `maximumWake = snappedBed - 60` / `minimumBed = snappedWake + 60` を0..1440の直線で計算しており、`bed < wake`（例: 就寝1:00・起床7:00）を構造的に禁止する。アプリの他層は跨日を明示サポート（`NightWindowPolicy` の `if bed < wake` 分岐・SettingsViewの跨日描画分岐）。既存ユーザーに `bed < wake` の保存値が実在する
- 実害: wake=7:00/bed=1:00で起床ハンドルを動かすとwakeが0:00へ強制移動。就寝を1:30へ変えるとbedが8:00へ飛び、夜の窓が6時間→23時間へ反転して夜だけ強化が実質終日ブロックになる。「深夜1時就寝」を表現する手段が消える
- 修正の契約: 円環軸で判定する。**夜の弧（bed→wake）と昼の弧（wake→bed）の両方が60分以上**（`((wake - bed) % 1440 + 1440) % 1440 >= 60` かつ逆向きも同様）。クランプはドラッグ中のハンドルを最寄りの有効位置へ止めるだけとし、もう片方のハンドルをテレポートさせない
- テスト: 跨日ケースを必ず追加（23:00→7:00・1:00→5:00・0:00/24:00境界・跨日状態での両ハンドルのクランプ・スナップ境界23:45/0:15）。既存5件も新契約に合わせて見直す

## R2. 🟠 F4: タップ→DatePickerが15分丸めされ「微調整用」が成立しない
- 場所: `wakeTimeBinding` / `bedTimeBinding` の set → `updateTimeline`
- 修正: DatePicker経路はスナップなし・分単位で書く（最小間隔クランプはR1の円環契約で維持）。丸めやクランプで値が巻き戻る場合に無言でPicker表示だけ戻る問題も解消すること
- 元仕様: 「タップ→ポップオーバーは維持（微調整用）」。ドラッグ経路のみ15分スナップ

## R3. 🟠 F4: ButtonとDragGestureの競合抑止がない
- 場所: タイムラインハンドルの `Button` ＋ `.simultaneousGesture(DragGesture(minimumDistance: 6))`
- 問題: 6〜22pt程度の短いドラッグで時刻が変わったうえポップオーバーも開く
- 修正: `didDragTimelineHandle` フラグを onChanged で立て onEnded で遅延リセットし、Button action 先頭でガード

## R4. 🟠 F4: VoiceOverでハンドルをダブルタップしても無反応（a11y退行）
- 場所: ハンドルの `.accessibilityElement(children: .ignore)` ＋ `.accessibilityAction(named:)`
- 修正: 引数なしの `.accessibilityAction { action() }`（既定アクション）を追加。`accessibilityAdjustableAction` の15分刻み操作は維持

## R5. 🟠 F4: ドラッグ中断時に保存だけ進みシールド同期が走らない
- 場所: `updateTimeline`（onChangedで永続化）vs onEndedのみの `model.syncShield()`
- 問題: ScrollViewにジェスチャを奪われて onEnded が来ないと、保存値と `NightShieldScheduler`/DeviceActivityの窓がズレる。ライブ時刻カプセルも出っぱなしになる
- 修正: 同期を値変更に追従させる（`.onChange(of: wakeTimeMinutes/bedTimeMinutes)` で `syncShield()` など）。`draggingTimelineHandle` の後始末も onEnded 非到達で破綻しない形へ

## R6. 🟡 F3基盤: `hasDeepFocusTargets` がbody経路で毎秒ディスクI/O＋`rules` @Stateと二重ソース
- 場所: `AppContainer.hasDeepFocusTargets`（`ruleStore.allRules()` 直読み）＋ `SettingsView.primaryRule`
- 問題: ディープフォーカス欄表示中は1秒tickごとにメインアクタで `Data(contentsOf:)`＋JSONDecodeが走る。`allRules()` がthrowすると `rules` @Stateと食い違い、`saveActivitySelection` が既存ルール更新でなく新規作成へ落ちる・ペイウォール判定が矛盾する
- 修正: 判定をCoreの純関数（`[Rule]` を受ける）に切り出し、SettingsView側は `rules` @Stateから判定する。body・tickerの経路に同期ディスクI/Oを残さない。`DeepFocusTargetGuardTests` は純関数を直接検証する形へ

## R7. 🟢 `@State breathDurationSeconds = 8` がストア既定値3と不一致
- 修正: 初期値を3に合わせる（初回1フレームの表示ブレ解消）

## R8. 🟢 触覚がDatePicker経路でも鳴る
- 修正: `.selection` 触覚はドラッグ中のスナップ時のみ。DatePicker経路では鳴らさない

## R9.（同症状の追補・HomeView解禁済み）
- `HomeView.swift` の body 直読み3箇所（`liveActivityEnabled`・`breathDurationSeconds`・`verifiedAutomationCatalogIDs`）も F1 と同じ方式（@Stateミラー＋更新点で同期）で直す。ホームCTA置き換え（実装済み）の構造は壊さない

## 検証（全て実行して報告）
- `swift test`（Core・跨日テスト含む）／対象アプリテスト TEST SUCCEEDED
- `python3 scripts/lint-display-copy.py` / `python3 scripts/audit-default-values.py` exit 0
- 跨日設定（就寝1:00・起床7:00）でのドラッグ挙動をシミュレータで確認しスクショを `output/verify/` へ
- 報告: 変更ファイル一覧＋3行要約＋検証結果。差分本文は貼らない

---

# Round 1b: ホームCTA置き換えレビューの指摘（同時に修正する）

## R10. 🟠 CTA語彙が着地先に存在しない（仕様不適合）
- 問題: `home.targets.block_settings`「完全ブロックを設定する」の「完全ブロック」が、着地先（止める強さセクション）ではFreeユーザーとPro標準/夜モードのユーザーに1語も表示されない。別バッチがモード説明から完全ブロックの語を外したため不一致が増幅
- 修正: オーナー恒久ルール「ラベルは既存画面の語彙に揃える」に従い、CTAを着地先の見出し語彙へ揃える。ja「止める強さを設定する」。en/koは `settings` の「止める強さ」セクション見出しキーのカタログ値から導出する（語彙を発明しない）。3言語ともカタログ収録・句読点なし
- design-decisions.md に「完全ブロックを設定する→止める強さを設定する（着地先語彙への整合・2026-08-24ルール適用）」を追記

## R11. 🟠 warm経路でスクロール着地が空振りしうる＋検証がTabView実経路を通っていない
- 問題: 設定タブを一度開いた後は `.onChange` がタブ切替と同一トランザクションで先行発火し、レイアウト未確定の `proxy.scrollTo` がno-opでもフラグだけ消費される。`onAppear` 側にリカバリ経路がない
- 修正: フラグの消費をスクロール実行が保証できるタイミングへ寄せる（可視化後の消費・またはscrollTo実行後に消費）。onAppear/onChange二重発火でも一度きり実行は維持
- 検証: シミュレータで「設定タブを開く→ホームへ戻る→CTAタップ」のwarm経路で着地を確認し、スクショを `output/verify/home-block-settings-landing-warm.png` へ保存

## R12. 🟡 新規スナップショットテストにXCTSkipゲートがない
- `SettingsDeviceFixesSnapshotCapture.swift` の `testCaptureHomeBlockSettingsLanding` を、同ファイル既存キャプチャと同じ環境変数ゲート（XCTSkip）に揃える。ソースツリーへの無条件書き込みをやめる

## R13. 🟢 到達不能になったdeepFocusFootnoteの分岐
- `SettingsView.swift` の `deepFocusFootnote` 内 `locked_notice` / `standard_notice` 分岐は描画条件と矛盾し到達不能（Freeへの案内は `deepFocusLockedSection` が別途表示するため重複）。到達不能分岐のみ最小限で除去する。表示中の文言は変えない

## R14. 🟢 build成果物が未追跡のまま
- `.gitignore` に `build/` と `ios/build/` を追加する

---

# Round 2: 修正差分への新規指摘（最終ラウンド）

## R15. 🟠 ドラッグ中の時限クリーンアップ誤発火
- 場所: `SettingsView` の `scheduleTimelineDragCleanup()`（onChanged毎に450ms再スケジュール）
- 問題: 指を置いたまま450ms停止すると①ライブ時刻カプセルが消える ②`didDragTimelineHandle=false` に戻り離した時にポップオーバーが開く ③`timelineDragStartMinutes` が現在値へ再アンカーされる一方 `translation.width` は接地点からの累積のままで、ハンドルが移動済み分だけ二重に飛ぶ
- 修正: onChanged側の時限クリーンアップをやめる。`draggingTimelineHandle` の後始末は onEnded＋十分長いフェイルセーフ（例: 数秒）に限定。再アンカー判定は `== nil` でなくジェスチャ単位のIDで行う

## R16. 🟠 タイムライン変更→syncShieldの連打（デバウンスなし）
- 場所: `SettingsView` の `.onChange(of: wakeTimeMinutes/bedTimeMinutes)` → `model.syncShield()`
- 問題: ドラッグ中は15分ステップ毎に発火し1ドラッグ最大96回。`syncShield` は毎回 NightShieldScheduler の stop/startMonitoring を無条件実行するため、DeviceActivityのレート制限で `startMonitoring` がthrowし夜間ブロックの予定が張られないまま残りうる
- 修正: 250ms程度のキャンセル可能Taskでtrailingデバウンス。最終値の同期は必ず実行される契約にする（デバウンス中のonDisappear/onEndedでも最終syncが落ちないこと）

## R17. 🟢 着地フラグ消費の純ロジックテスト追加
- `pendingDeepFocusSettingsFocus` 消費の回帰検知が既定スキップの撮影テストのみになった。スクショ生成を伴わない純ロジックテストを1本追加: `isSettingsVisible == false` では消費されない／true化後に一度だけ消費される

## R18. 🟢 HomeView の残る body 直読み4箇所
- `currentMode`（pendingInterventionMode）・`isNightBlockActive`・`nightRemainingText`・`bedTimeText` が `settingsStore` を body 直読み。R9と同じ@Stateミラー方式で統一（更新点: onAppear＋既存のミラー更新関数）

## R19. 🟢 孤児キーの削除
- R13で参照ゼロになった `settings.deep_focus.standard_notice` を参照ゼロ確認の上で3言語ともカタログから削除

## 検証（全て実行して報告）
- `swift test`／対象アプリテスト TEST SUCCEEDED
- `python3 scripts/lint-display-copy.py` / `python3 scripts/audit-default-values.py` exit 0
- シミュレータ: ドラッグ中に450ms静止→続けて動かす操作でハンドルが飛ばないこと・カプセルが消えないことを確認
- 報告: 変更ファイル一覧＋3行要約＋検証結果。差分本文は貼らない

---

# Round 3: R15検証で残った境界穴（マイクロ修正・これで収束）

## R20. 🟠 onEnded後120msの再タッチ窓でジェスチャIDが継承される
- 場所: `SettingsView` タイムラインの `DragGesture.onEnded` と `clearTimelineDragState`
- 問題: onEndedが `timelineDragGestureID` を即クリアせず120msタスクに委ねるため、窓内の再タッチが終了済みIDを継承して再アンカーされず、ハンドルが前回開始位置へ飛ぶ。保留中の120msタスクが新ドラッグ中に発火してカプセル消失・二重ジャンプも再現する
- 修正: `onEnded` で `flushPendingTimelineShieldSync()` の後に `clearTimelineDragState(resetTapGuard: false)` を即実行（gestureID・アンカー・カプセルを即時クリア）。120ms遅延タスクは `didDragTimelineHandle = false`（タップガード解除）だけに絞る。ジェスチャ状態のクリア時に保留中のクリーンアップ／フェイルセーフTaskを必ずキャンセルし、新しいジェスチャへ発火が漏れない契約にする
- 対象外（記録のみ・修正しない）: 10秒フェイルセーフ発火時の後始末（仕様どおり）／onEnded非到達時にタップガードが最大10秒残る件／2本指同時ドラッグの共有state競合

## 検証
- `swift test` 全通過・`swiftc -parse` clean
- 報告: 変更ファイル一覧＋3行要約のみ。差分本文は貼るな
