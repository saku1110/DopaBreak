# DopaBreak リリース前 課金＆継続導線チェック

- 実施日: 2026-08-16
- 実施者: Fable（コード・記録の照合のみ。実機検証は未実施）
- 対象: main @ 7558c39

## 0. App Store Connect 課金カタログ（2026-08-16 構築完了）

backlog の「アプリレコード未作成」は**古い記録だった**。実査したところレコードは既に存在し、
未作成だったのは商品カタログの方だった（グループ0件・IAP 0件）。同日に構築済み。

- App: `6794221254` / com.dopabreak.app / SKU dopabreak-ios
- Group: `22313084` DopaBreak Pro（ja ローカライズ済み）

| 商品 | ASC ID | 価格(JP/KR/US) | ランク | 状態 |
|---|---|---|---|---|
| dopabreak.pro.annual | 6802039504 | ¥4,980 / ₩49,000 / $39.99 | **1（最上位）** | ✅ READY_TO_SUBMIT |
| dopabreak.pro.annual.launch | 6802039512 | ¥3,980 / ₩39,000 / $49.99 | 2 | ✅ READY_TO_SUBMIT |
| dopabreak.pro.monthly | 6802039024 | ¥980 / ₩9,900 / $9.99 | 3 | ✅ READY_TO_SUBMIT |
| dopabreak.pro.lifetime (非消耗) | 6802039793 | ¥14,800（JPN基準・均等化） | — | ✅ READY_TO_SUBMIT |

- 7日間無料トライアル: 年額2本に付与済み（全テリトリー）
- **2026-08-14 監査の P1「.storekit groupNumber 逆転（ASC実体要確認）」を解消**。
  ASC は level 1 が最上位。当初 monthly=1 で作成され月→年がダウングレード扱いになる状態だったため、
  正本 `ios/DopaBreak/DopaBreak.storekit` に合わせて annual=1 / launch=2 / monthly=3 へ是正。
- 再現手順は `scripts/asc-setup-dopabreak.sh` に反映済み（冪等・3回連続実行で副作用なしを確認）。
  今回判明した API の癖: テリトリーは3文字ID必須（"Korea" は ambiguous）／ロケールは `ja`（`ja-JP` は非対応）／
  ローカライズは version スコープのコマンドを使う（`setup` の localization フラグは v1 非推奨で失敗する）。

**MISSING_METADATA は同日中に解消済み**。必要だったのは次の2つだった:
1. 審査用スクリーンショットの添付。シミュレータでオンボーディングを実走してペイウォールを撮影し
   （`output/asc-review-screenshots/paywall-ja.png`）、サブスク3本＋IAPへ添付（全て delivery COMPLETE）
2. **IAPだけは提供地域（availability）が別リソース**で、価格スケジュールとは別に張る必要があった
   （サブスクは `--territories` で同時に張られる）。これが最後の1件だった

ハマりどころ: `asc iap versions images` は審査用スクショではなく**プロモーション画像**の枠。
ペイウォールのスクショを入れると `IMAGE_INCORRECT_DIMENSIONS` で必ず失敗する
（640x920 / 1242x2208 / 1280x1920 / 1920x2880 すべて拒否されることを実測で確認）。
正しい口は `asc iap review-screenshots create`。

→ **サンドボックス購入テストの前提が整った**（商品が READY_TO_SUBMIT でないと sandbox に出ない）。

有料App契約（Paid Apps Agreement）は、IAP作成がAppleに拒否されなかったことから Active と推定。
ASC のビジネス画面での直接確認は未実施。

## A. 課金→有料機能アンロック

**実機検証は1件も実施していない。** 上記のとおりカタログは整ったが、
審査用スクショとビルドが未了で全商品 MISSING_METADATA のため、サンドボックス購入はまだ回せない。

| 有料機能 | エンタイトルメント | 実装 | 実機確認 |
|---|---|---|---|
| 対象アプリ無制限（Free=1個） | pro | ✅ | ❌ 未実施 |
| Deep Focus（完全ブロック） | pro | ✅ 2026-08-14 本実装 | ❌ 未実施 |
| 週次詳細レポート | pro / weeklyReportAllowed | ✅ 2026-08-14 本実装 | ❌ 未実施 |
| 夜だけ強化（nightOnly） | pro | ✅ 2496b3b | ❌ 未実施 |
| 利用時間ウォッチ Pro間隔（15分〜） | pro | ✅ Batch 2 | ❌ 未実施（DeviceActivityはシミュレータ不可） |

境界ケース: 復元 ❌ / オフライン起動 ❌ / トライアル ❌ / 解約後ロック ❌ / 返金 ❌ / 別端末 ❌
検証環境: Sandbox ❌ / TestFlight ❌

補足: 2026-08-14 監査で検出した P0 4件（取得失敗＝無料確定・Grace Period即ロック・
クランプによる対象アプリ永続削除・refresh再入）はコード上は修正済み（5cf4eea）。
ただし**修正の妥当性を実機で確認していないため、A ブロックは全項目❌のまま**。

## B. レビュー・通知・課金誘導

| 項目 | 設計 | 実装 | 実機発火確認 |
|---|---|---|---|
| レビュー誘導（勝ち画面+1.5s・満足度ゲートなし） | ✅ docs/18 | ✅ InterventionFlowView.swift:82-94 | ❌ 未実施 |
| D1/D3/D7 活性化通知 | ✅ | ✅ ActivationNotificationPolicy | ❌ 未実施 |
| 月次/週次レポート通知 | ✅ | ✅ | ❌ 未実施 |
| 課金誘導（年額移行・解約セーブ） | ✅ | ✅ SubscriptionNotificationPolicy | ❌ 未実施 |
| 離脱防止クイックアクション（3枠） | ❌ 未設計 | ❌ 未実装 | — |

## その他の審査ブロッカー

### 解消済み（2026-08-16・Fable独立検証済み）

1. **`PrivacyInfo.xcprivacy` 全5ターゲットへ追加** — 実装 Opus5 / レビュー Fable。
   ビルド成果物から実測して `.app` 本体＋4つの `.appex` の計5箇所に埋め込まれていることを確認。
   `plutil -lint` 5件すべてOK。宣言内容はソースの実使用に基づく（App Group共有 `1C8F.1` /
   アプリ専用 `.standard` `CA92.1` / SystemBootTime `35F9.1`）。
   トラッキングなし・収集なし（`URLSession`・解析SDKのgrepヒットゼロ）。
   ※当初 Fable が「App Group は CA92.1」と誤指示 → 実装者が Apple 原典に照らして是正。
2. **`ITSAppUsesNonExemptEncryption: false`** — project.yml だけでなく
   **ビルド後の Info.plist で false になっていること**を確認。
   CryptoKit/CommonCrypto/Security の import・シンボルともゼロで exempt 該当。
3. **ホーム画面クイックアクション3枠** — 実装済み。オファー枠は
   `QuickActionsConfiguration.offerSlotEnabled = false` で既定OFF（ASCにオファー実体が無い間、
   率を表示するとガイドライン2.3に触れるため枠自体を登録しない）。
   課金者への非表示は `hasResolvedEntitlement` ではなく `hasConfirmedEntitlement` で
   fail-closed に判定。外部決済導線なし（`AppStore.presentOfferCodeRedeemSheet(in:)` のみ）。
   Fableレビューで2件差し戻し → 修正完了 → **Fable受け入れ確定**。
   差し戻した①「対象アプリ0件のとき介入枠が無反応」の修正過程で、より広い欠陥が判明した:
   変更前は `handleAppActive`（onAppear / scenePhase active）だけが再登録経路で、
   **フォアグラウンドのまま設定で対象アプリを全部外すとメニューが古いまま残った**。
   `AppModel.hasInterventionTargets` ＋ `.onChange` を新設して塞いだ。
   読み取り失敗時は0件扱いにせず直前値を保持（一時的失敗で使えていた枠を消さない）。

検証（すべて Fable が自ら再実行して再現）:
アプリ **112テスト0失敗（TEST SUCCEEDED）** ／ Core **389テスト0失敗** ／
`lint-display-copy.py` exit 0 ／ `audit-default-values.py` exit 0
（calls=639・mismatches/missing/unresolved すべて0）。
`QuickActionsTests.swift:175` が実際の `UIApplication.shortcutItems` を使って
「最後の対象を外す→介入枠が消え pending も破棄→再選択で戻る」を通しで検証していることも確認。

⚠️ 規定のクロスモデルレビュー（Opus5実装→Codexレビュー）は **Codex が利用上限
（2026-08-20まで）** のため実行不可。代替として Fable が独立レビューした（実装とは別モデル）。

### 未解消

4. ~~ASC アプリレコード未作成~~ → **記録が誤り。7月から存在**（上記セクション0）
5. ストアスクリーンショットが炎表現削除前のもの → 再生成が必要（審査2.3）
6. ASCのアプリメタデータがほぼ空（ja ロケールのみ・キーワード/説明/スクショ未登録）。
   docs/16 に3言語の確定ドラフトあり
7. DopaBreak用プロビジョニングプロファイル未作成（Xcode自動署名で生成可。
   Bundle ID 5件と FAMILY_CONTROLS_DISTRIBUTION・配布証明書は確認済みで揃っている）
8. **App Privacy（ストアのプライバシー表示）が未公開** — 提出必須。
   `asc web privacy pull` の実測では宣言内容は `DATA_NOT_COLLECTED` で設定済みだが
   `publishState.published = false`。宣言内容自体は実装と一致している
   （`URLSession`・解析SDKのgrepヒットゼロ＝ネットワーク送信なしを確認済み）。
   公開コマンドは**リリースゲートのフック（`release-monetization-gate.py`）がブロック**する。
   これは想定どおりの挙動なので回避しない。A・Bブロックの実機検証を終えて
   証跡を「総合: ✅」にしてから実行すること。

## 総合: ❌ リリース不可

理由: A ブロックが全項目未検証。規則により1件でも未確認があれば不可。
