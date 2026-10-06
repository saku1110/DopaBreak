# ペイウォール見出し v2 — 中央揃え＋「人生の{Y}年」訴求（設計書・2026-09-04）

ステータス: **実装済み・受け入れ済み（2026-09-04・未コミット）**。実装=Opus5サブエージェント（Codex利用上限のため）／レビュー=別インスタンスのOpus5「ACCEPT WITH FIXES」→指摘反映済み／最終確認=Fable（ja/en/ko/en-XXXL のスクショ目視・lint・audit-default-values）。
オーナー決定: **確定（2026-09-04・引用可能な記録）**。オーナー回答「1,A／2,約いらない／3,入れない」＝ 見出し1行目は案A「「あと5分」が人生の{Y}年」・見出しに「約」を入れない・2行目の対抗案は入れない（「開く前にブレーキ」維持）。§2.1b（対抗案B）は実装しない。
実装担当: Codex L1（`gpt-5.6-luna` effort max）。レビュー: Opus5サブエージェント。
関連正本: docs/11 §5（ペイウォール文言）、docs/06 §10（P-01）、docs/07 O-03r（推計の前提・50年換算・切り捨て）、docs/15 §3.3。

---

## 0. 背景（なぜ変えるか）

現行の見出し（2026-07-18確定・`PaywallView.header`）:

```
「あと5分」が1年で{N}日     ← {N}=LossEstimator推計・accent色
開く前にブレーキ
（本文）ずっと我慢するためのアプリではありません。SNSを開く前に一呼吸はさみ、開かずにすんだ回数をホームに残します。
```

問題:

1. **単位が弱い**: 「1年で38日」は帳簿の単位で、生活の実感に接続しない。オーナーは 2026-07-29 に O-03r で同じ判断を下し（「日数は蓄積の実感が弱い。年単位にすると失う対象が『人生そのもの』に変わる」）、オンボーディングの山場を「50年で 人生の約5.2年」へ置換済み。ペイウォールだけが旧単位のまま残っている。
2. **3回目の再掲**: ユーザーは O-03r（1年で 約38日）→ O-08b（年 約38日分）→ ペイウォール（1年で38日）と同じ数字を3回見る。慣れて衝撃が消える。
3. **アンチクライマックス**: O-03r の最終行「人生の約5.2年」が感情のピークなのに、直後のペイウォールで小さい数字（38日）へ戻る。ピークエンドの「エンド」に当たるペイウォールは、ピーク以上の強さで受けるべき。
4. **軽量ユーザーで逆効果**: 「1時間未満」回答者には「年11日」と出る（実スクショで確認）。11日は「大したことない」と読める。人生換算なら1.5年で意味が残る。
5. **左寄せ**: 見出しは `VStack(alignment: .leading)` で左寄せ。CLAUDE.md「オンボーディング・ペイウォール・ヒーロー訴求の見出しは中央揃えが既定」に反し、直前の O-08b（`centeredEyebrow`/`centeredLead`＝中央）から続く唯一の左寄せヒーローになっている。

## 1. レイアウト変更（確定）

`ios/DopaBreak/PaywallView.swift` の `header`:

| 要素 | 現行 | 変更後 |
| --- | --- | --- |
| `header` の VStack | `alignment: .leading` | `alignment: .center` |
| キャラクターカード | 全幅・そのまま | 変更なし |
| `SmallLabel("DOPABREAK PRO")` overlay | `.topLeading` | **`.topLeading` のまま**（2026-09-04 実機スクショで `.top` はキャラクターと重なったため差し戻し） |
| 見出し2行（30pt black） | 左寄せ・各行 `lineLimit(1)` + `minimumScaleFactor(0.78)` | `.multilineTextAlignment(.center)` + `.frame(maxWidth: .infinity)`。1行目・2行目とも既存の `dopaDisplayClamp()`（1行固定・縮小下限0.5・AX2打ち止め。他の大見出しと同じ）。経緯: `lineLimit(2)` は英語で「of life」だけが2行目に落ちて3行見出しになり不採用 → `lineLimit(1)`+0.78 は XXXL で `years g…` と省略されたため、最終的に `dopaDisplayClamp()` へ。英語は文言側も短縮して1行に収める |
| 推計注記（新設） | なし | 見出し直下・12pt medium・`DesignTokens.secondaryText`・中央揃え |
| 本文（14pt） | 左寄せ | `.multilineTextAlignment(.center)` + `.frame(maxWidth: .infinity)` |
| `featureList` / `planList` / `legalArea` / `fixedActionBar` | — | **変更なし**（チェックリストは左揃えのまま） |

外側 `ScrollView > VStack(alignment: .leading)` は他セクションが依存するため触らない。`header` の中だけで中央化する。

## 2. 文言（確定・2026-09-04 オーナー決定）

### 2.1 見出し1行目（`paywall.header.line1.*`・{Y} は accent 色）

| 言語 | prefix | accent | suffix | 備考 |
| --- | --- | --- | --- | --- |
| ja | `「あと5分」が人生の` | `{Y}` | `年` | 13文字。句読点なし・体言止め |
| en | `“5 more min” = ` | `{Y}` | ` years gone` | 29字（2026-09-04 差し戻しで確定。旧 ` years of life` 32字は1行に収まらず「of life」が孤立した）。「gone」は r/nosurf の顧客の言葉「Every year. Gone.」に由来。humanizer-en 全ゲート通過 |
| ko | `'5분만 더'가 인생의 ` | `{Y}` | `년` | humanizer-ko 全ゲート通過 |

{Y} = `LossEstimator.lifetimeYears(fromYearlyDays: yearlyDays)` を `"%.1f"` で整形（切り捨て済みの値。O-03r と同じ `lifetimeYearsText` のロジック）。**固定値のハードコード禁止**。未回答時のフォールバックは現行どおり既定バケット「2-4時間」→ 38日 → 5.2年。

### 2.1b 対抗案B（オーナーがBを選んだ場合のみ・顧客の単位「1日○時間」）

| 言語 | prefix | accent | suffix |
| --- | --- | --- | --- |
| ja | `「あと5分」が1日` | `{T}` | （suffixなし。{T}自体が「2.5時間」「45分」） |
| en | `“5 more min” = ` | `{T}` | ` a day` |
| ko | `'5분만 더'가 하루 ` | `{T}` | （suffixなし） |

{T} = `dailyTimeText(minutes:)` の出力（accent色は数値＋単位ごと）。この場合の注記は `1日{T}が1年続いた場合 約{N}日の推計`（ja）のように年換算を注記側へ回す。Aを選んだ場合はこの節は実装しない。

### 2.2 見出し2行目（変更なし）

`paywall.header.line2`: ja `開く前にブレーキ` / en `Pause before you open` / ko `열기 전 잠깐 멈춤`（オーナー自身の文言・2026-07-18）。

### 2.3 推計注記（新設キー `paywall.header.estimate_note`・本文扱い）

| 言語 | 文言 | %@ |
| --- | --- | --- |
| ja | `1日約%@が50年続いた場合の推計` | 1日の利用時間（例: 2.5時間 / 45分 / 5時間） |
| en | `Estimate: %@ a day, over 50 years` | 2.5 hours / 45 min / 5 hours |
| ko | `하루 약 %@이 50년 이어질 때의 추정치` | 2.5시간 / 45분（시간・분とも받침ありなので助詞「이」で固定可） |

%@ は `snapshot?.estimatedDailyMinutes`（フォールバック 150）を、O-03r が使う `onboarding.result.duration.{minutes,hours,decimal_hours}` と同じ分岐で整形する（`OnboardingFlow.swift` の `dailyTimeText(minutes:)`・2603行付近）。この `dailyTimeText(minutes:)` と `lifetimeYearsText(yearlyDays:)`（同 2620行付近）は **`OnboardingFlow` から切り出して共有ヘルパー（例: `LossEstimatePresentation.swift`・app target）に移し、Onboarding と Paywall の両方から呼ぶ**。重複実装は禁止。

法務根拠（docs/07 O-03r 2026-07-29 決定と同じ）: 50年という前提を文中に明示し、値は四捨五入でなく切り捨て。効果の断定（「取り戻せる」）は書かない。個人の回答からの推計であることを注記で示す。

### 2.4 本文（変更なし）

`paywall.header.body` は現行維持（安心の併用＝日本市場の損失訴求は安心とセットにする方針・docs/02b）。

## 3. データ配線

- `PaywallView.init`: 既存の `yearlyDays = Self.resolvedYearlyDays(snapshot:)` に加え、`dailyMinutes = Self.resolvedDailyMinutes(snapshot:)` を同じフォールバック経路（`LossEstimator.estimate(usageBucket: "2-4時間").dailyMinutes`、最終フォールバック 150）で解決する。
- `MeasurementFoundationTests.swift` 1138行付近の `resolvedYearlyDays` テストと同形式で `resolvedDailyMinutes` のテストを追加（snapshot あり=その値／nil=150）。
- 共有ヘルパーに対するユニットテスト: `lifetimeYearsText(yearlyDays: 38) == "5.2"`、`dailyTimeText(minutes: 150) == "2.5時間"`・`dailyTimeText(minutes: 45) == "45分"`（ja）。

## 4. ドキュメント同期（実装と同じバッチで）

- `docs/11_ui_copy.md` §5: 見出し行を「「あと5分」が人生の{Y}年／開く前にブレーキ」へ更新し、推計注記の行を追加。
- `docs/06_screen_design.md` §10: 表示ブロックの見出し部分を更新（中央揃えの注記を追加）。
- `.claude/specs/i18n-launch-inventory.md` 218-221行: 現行カタログ値とズレている（prefix「「あと5分だけ」が年」・本文の旧文）ので、カタログ正本に合わせて更新し、新キーを追加。
- `.claude/specs/design-decisions.md`: 末尾に 2026-09-04 のエントリ（採用方針・却下案・制約）。
- `docs/CHANGELOG.md`: 1行追加。

## 5. 検証（Codex が実施し結果だけ報告）

1. `xcodegen generate` → `xcodebuild -scheme DopaBreak -destination 'generic/platform=iOS Simulator' build` が BUILD SUCCEEDED。
2. `python3 scripts/lint-display-copy.py` exit 0（既存要確認2件のみ）。`git diff --check` exit 0。
3. 関連ユニットテスト（`MeasurementFoundationTests` のペイウォール節＋新規テスト）が通る。
4. シミュレータで ja / en / ko の3ロケールでペイウォールを開き、見出しの折返し・縮小率・中央揃えを目視。en が `minimumScaleFactor` 下限で切れる場合は §2.1 の短縮案へ差し替えて再確認。スクショを `output/screenshots/paywall-headline-v2/{ja,en,ko}.png` に保存。
5. 変更ファイル一覧と3行要約だけ報告。差分本文は貼らない。

## 6. A/B（今回は実装しない・記録のみ）

- 対抗案（2行目差し替え）: `全部のSNSにブレーキ`（Pro差分＝アプリ無制限を見出しで言う案）。1行目は同じ。
- 判定指標: DL→トライアル開始率（docs/15 §6: SOSA中央値5.7%／目標8%）。placement別の `recordPaywallShown` と購入イベントで算出。
- 実験基盤は未実装。導入時は variant 文字列を `recordPaywallShown(placement:)` に添える形で最小化する。

## 7. 追加スコープ: ペイウォール機能行を4→6行へ（2026-09-04 オーナー指示・引用可能な記録）

オーナー発言: 「ペイウォールの機能欄に ・週単位のスケジュールブロック ・刺激を減らす白黒モード がない」→ 文言確定「刺激を軽減する白黒モード」。
Fableは白黒モードがiOSショートカット（カラーフィルタ）の案内であり権利ゲートで制御できない旨を先に伝え、オーナーが再度指示したため実装する（懸念は上記のとおり記録済み）。

| 順 | キー | ja | en | ko | 根拠 |
| --- | --- | --- | --- | --- | --- |
| 1 | `paywall.feature.unlimited_apps` | 既存 | 既存 | 既存 | — |
| 2 | `paywall.feature.deep_focus` | 既存 | 既存 | 既存 | — |
| 3 | **`paywall.feature.weekly_schedule`（新設）** | 週単位のスケジュールブロック | Block on a weekly schedule | 요일과 시간을 정해 차단 | Deep Focus の毎週の予定（`settings.deep_focus.schedule.*`・曜日/開始/終了・`DeepFocusScheduler`）。Deep Focus は Pro 限定 |
| 4 | `paywall.feature.night_block` | 既存 | 既存 | 既存 | — |
| 5 | **`paywall.feature.grayscale`（新設）** | 刺激を軽減する白黒モード | Grayscale mode to reduce stimulation | 자극을 줄이는 흑백 모드 | `AutomationGuideView` のカラーフィルタ自動化案内。Deep Focus 選択時のみ表示（`shouldShowGrayscaleGuidance`） |
| 6 | `paywall.feature.lock_theme` | 既存 | 既存 | 既存 | — |

- 表示コピー規則: 句読点なし・`\n` なし。en/ko は humanizer 監査で全ゲート通過（2026-09-04）。
- 同期先: docs/15 §3.2b（「4本に集約」「機能リストは4行」→6行）、docs/11 §5、docs/06 §10、i18n-launch-inventory.md の機能行（旧6行の残骸を現行カタログ値へ是正）、design-decisions.md、CHANGELOG.md。
- テスト: `InterventionMergeCopyTests.swift:173-174` は `usage_watch`/`gate_settings` の不在だけを検査しており、行数を固定するテストはない。
- リスク記録: 白黒モードは Free でも iOS 設定で再現できるため、Pro 行として掲出することで「Proを買ったのに自分で設定が要る」型の返金・低評価リスクが残る。ストアスクショ10枚目と同じ訴求である点で整合。
