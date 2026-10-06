# ASA診断の是正バッチ（2026-09-20）— 設計書

根拠: `docs/marketing/2026-09-20-asa-funnel-diagnosis.md` §2〜5。オーナー指示「全て修正して」。**料金の線（無料=対象アプリ1つ・目標無制限・記録全期間／Pro=ブロック各モード・対象上限解除・テーマ）は変えない。** Deep Focusは引き続きPro。

## 0. オーナー判断が要る1点（S6）

「制限」で来た人に課金前にブロックを見せる方法。

- **案A（推奨・料金の線を変えない）**: モード選択でDeep Focusを既定・推奨に戻す（設計書どおり）。Deep Focusを選んだ人には、その場でScreen Time許可 → 選んだ対象アプリ1つに**3分間の体験シールド**を張る（ManagedSettings・専用シールド画面「Deep Focus体験中」）。「対象アプリを開いてみてください」と促し、戻ってきたら「体験完了」→ ペイウォール（7日¥0）。買わなければシールドを外し standard（一呼吸）で続行。体験は1回限り（フラグ永続化）。
- 案B（料金を変える）: 対象1アプリ分のDeep Focusを恒久的に無料化。Pro=複数アプリ・週次予定・夜だけ強化・テーマ。
- 案Aで進める前提で設計する。案Bにする場合は `EntitlementGate` と docs/15 の改訂が別途必要。

## 1. 料金に関係なく直す項目（先に着手・Codex L2）

### S1 blockSetup「あとで」でモードを戻さない（課金事故）
- 現状: `OnboardingFlow.swift:2555 persistStandardModeAndLeaveBlockSetup()` が `.standard` を適用し、購入直後のDeep Focusが消える。
- 変更: 「あとで」は選択中モード（deepFocus/nightOnly）を保持したまま `.blockSetup` を離れる。`pendingInterventionMode` も保持。ホームに「ブロック未設定」の案内行（既存の自動化案内バナーと同じ様式）を出し、タップで設定画面のブロック設定へ。シールドは対象アプリ選択が完了するまで張らない（ゲートは既存の判定を使う）。
- テスト: 「あとで」後に `interventionMode == .deepFocus` が保たれること／Pro判定が変わらないこと。

### S2 商品未取得時に空ペイウォールを出さない
- 現状: `Product.products` 失敗時に価格「—」・CTA「年額プランを始める」のまま表示（`PaywallView.swift:515,705`）。
- 変更: `StoreService` の読み込み状態（loading / loaded / failed）を `PaywallView` が読む。failed のときはプランカードの価格に「読み込めませんでした」、CTAは無効化し「再読み込み」ボタンを表示。loading はスケルトン。復元ボタンは常時有効のまま。
- テスト: 失敗注入で CTA が無効・再読み込みで復帰。

### S3 オンボーディング進捗の永続化＋最終到達画面の計測
- 現状: `OnboardingFlow.swift:186` の `step` は非永続。外部に出る属性は3つだけ。
- 変更: `SettingsStore.onboardingStepRaw`（Int）を追加し、`advance()` ごとに保存。起動時に `onboardingCompleted == false` かつ保存値があればその画面から再開（welcomeとselfCheckは再開対象外＝先頭からで良い）。完了時にクリア。
- 計測: `AppleAdsMeasurement` に `onboarding_last_step`（`OnboardingStep.analyticsIdentifier`）を属性として送る（各ステップで上書き・1秒デバウンス）。既存の3属性と同じ経路・同じプライバシー区分（製品の操作／分析）。
- テスト: 保存→再起動で同じstep／完了でクリア／属性の値。

### S4 到達可能なレビュー依頼
- 現状: `ReviewPromptPolicy`: 開かなかった回数≥5・初回起動から3日・90日クールダウン・年3回・win画面のみ。
- 変更: `minimumCancelledCount` 5→**2**、`minimumAccountAge` 3日→**0**（当日可）。90日クールダウン・年3回・win画面1.5秒後は維持（Appleの3/365内）。初回起動直後・購入直後の失敗・エラー直後には出さない既存条件も維持。
- テスト: 2回目の成功で `shouldRequest == true`、3回目は cooldown で false。

### S5 オンボーディング中に一呼吸を1回完走させる
- 現状: `.permission` の検証発火で `consumeAutomationVerificationOnly`（`OnboardingFlow.swift:2486`）→ 結果を捨て、チェックマークだけ。
- 変更: 検証発火時は同じ `InterventionFlowView`（standardモード・体験用フラグ）をオンボーディング上にフルスクリーンで提示し、呼吸 → 理由/時間 → win まで通す。win で「これが一呼吸です」の1行を追加表示（既存のwin文言の下）。閉じたら `.notificationGuide` へ進む。`breathing_completed` 属性はこの経路でも立てる。発火しなかった場合の現行経路は維持。
- テスト: 体験フローから戻った後にオンボが次のstepにいること／二重提示しないこと。

### S7 通知許可を価値体験の後へ
- 変更: `.notificationGuide` を S5 の体験完了直後（同じ位置＝permissionの次）のまま維持でよい。体験が入ることで「価値の後」になる。追加変更なし（記録のみ）。

## 2. 案A採用後に実装（オーナー承認待ち・Codex L2）

### S6 Deep Focus既定＋3分体験シールド
- `OnboardingFlow.swift:204` の既定を `.deepFocus`、モード一覧でDeep Focusに「おすすめ」表示（既存のバッジ様式）。
- Deep Focus選択 → FamilyControls許可（拒否なら standard へ案内・行き止まりにしない）→ 対象アプリ1つに3分のシールド（`ManagedSettings`・専用シールド文言「Deep Focus体験中 3:00」）。画面には「対象アプリを開いてみてください」。復帰または3分経過で解除し「体験完了」→ `onboardingModeGate` のペイウォール。購入で deepFocus 確定、非購入で standard。
- 体験フラグ `deepFocusTrialShown` を永続化（1回限り）。Proユーザー・既存ユーザーには出さない。
- `onboardingModeGate` の即時ペイウォールは体験後に移す。

## 3. ストア側（審査なしで先行できるもの／1.0.2に同梱するもの）

- S8 年額の7日間トライアルを全テリトリーへ（ASC・API）。※ 現状 JP/KR/US のみ。
- S9 スクショ順を deepfocus → night → breath → home → lockscreen → intent → reflection → grayscale に変更（3市場）。`output/app-store-screenshots/v2/upload-order/*/README` と slots を実配信に合わせて修正。**1.0.2の版に載せる**（公開中の版はスクショ編集不可）。
- S10 1枚目（breath）の見出しを否定形から肯定形へ。候補は別途オーナー承認（表示コピー規則: 句読点なし・1行・中央）。KRサブタイトルに 차단／잠금 系を追加（30字以内）。
- S11 「制限」クラスタ用カスタムプロダクトページ（deepfocus/night先頭・Proバッジ一覧を除外）。1.0.2公開後にASAへ紐付け。

## 4. 進め方
- 実装は Codex（`gpt-6-astra` effort medium）へ。S1〜S5 を1バッチ、S6 は承認後に別バッチ。レビューは Opus5 サブエージェント。ビルド・テストは `xcodebuild` シミュレータで通す。
- 実機検証（オーナー）: S1（購入→あとで→Deep Focus維持）、S5（体験フローの完走）、S6（体験シールド）。release-monetization-check の A ブロックに追記。
- 広告の再開は 1.0.2 公開＋スクショ差し替え後。

## S6（改・オーナー決定 2026-09-20）: 呼吸画面に目標を表示
- 案A（3分シールド体験）は却下。差別化軸は「対象アプリを開いた瞬間に自分の目標が出る」。
- `InterventionFlowView.breathingScreen` に、呼吸アニメーションの下（CTAより上）に見出し「目標を思い出しましょう」（en: "Remember your goals"／ko: "목표를 떠올려 보세요"）と、ユーザーの目標（最大5件・`flow.goals`・usageSummaryScreen と同じ並びと文字サイズ規則）を表示する。目標が0件のときは見出しも一覧も出さない（既存の空プロンプトは usageSummaryScreen に残す）。
- 呼吸の所要時間・進行・タップ操作は変えない。usageSummaryScreen の目標表示は維持（編集導線はそこに残す）。
- 文言は句読点なし・1行・中央揃え。Localizable.xcstrings に3言語で追加。
- テスト: 目標あり/なしでの表示分岐のスナップショットまたはビュー検査を1件。

## S9/S10（改・オーナー承認 2026-09-20）: スクショ9枚の新構成（3市場共通）
| # | 内容 | 素材 |
|---|---|---|
| 1 | SNSを開いた瞬間に自分の目標が出る | 新規: 呼吸画面（目標3件表示）を実機サイズで撮影（`output/verify/asa-fix-2026-09-20/breathing-goals-*.png` と同じ状態） |
| 2 | ロック画面に目標 | 既存 02-lockscreen |
| 3 | 一呼吸と開く理由 | 既存 01-breath（見出しを肯定形へ。「SNSをブロックしない」は削除） |
| 4 | 完全ブロック | 既存 03-deepfocus |
| 5 | 夜だけ強化 | 既存 04-night |
| 6 | 白黒ホーム | 既存 08-grayscale-home |
| 7 | 見たあとの本音 | 既存 07-reflection |
| 8 | 取り戻した時間 | 既存 05-home |
| 9 | テーマ | 既存 lock-designs |
- コピー規則: 句読点なし・見出しは1行優先（入らない時だけ意味の切れ目で改行）・体言止め・中央揃え。CTAや価格は入れない。ja→humanizer-jp、en→humanizer-en、ko→humanizer-ko の順で検査。
- 06-intent（開く理由）は3枚目の副文に統合し単独枠から外す。
