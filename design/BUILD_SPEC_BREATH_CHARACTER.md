# BUILD SPEC — 介入呼吸ステージ「ドーパと一緒に呼吸」演出（Codex実装用）

作成: 2026-08-14 / 設計: Fable / 実装: Codex(gpt-5.6-sol, max) / レビュー: Opus5
オーナー承認: 2026-08-14「OKそれでいこう」（経緯は `.claude/brainstorm/2026-08-14_介入呼吸演出_炎の代替.md`）

## 0. 目的と背景

- 炎シェーダーは品質理由で全削除済み（2026-08-14）。現状の呼吸ステージはドーパ（doom表情）の静止表示
- 本演出の目的は「待たされる3秒」を「キャラを安心させた3秒」に反転させること。美しさではなく脱自動化と罰感情の中和
- 新規のリアル系描画（粒子・流体・シェーダー）は禁止。既存キャラPNG資産のみで組む

## 1. 対象ファイル

| ファイル | 変更 |
|---|---|
| `ios/DopaBreak/InterventionFlowView.swift` | 呼吸ステージのビジュアルを新コンポーネントへ差し替え |
| `ios/DopaBreak/BreathingCharacterView.swift`（新規） | 呼吸同期キャラ演出の本体 |
| `ios/DopaBreak/BreathHapticsController.swift`（新規） | CoreHapticsの呼吸パターン制御 |
| `ios/DopaBreakTests/BreathCharacterSnapshotCapture.swift`（新規） | 目視検証ハーネス（旧FlameSnapshotCaptureと同方式） |

`InterventionFlowModel.swift` は原則変更しない（タイマー・世代ガード・ステージ遷移は現行のまま）。

## 2. 呼吸サイクル設計

- 呼吸総時間は `settingsStore.breathDurationSeconds` ∈ {3, 5, 8}（既存）。ビューは `flow.breathTotalSeconds` を受け取る
- **サイクル数は常に1**（1回の介入＝ひと呼吸）。総時間の全体を使って1呼吸させる → 3s:1呼吸 / 5s:1呼吸 / 8s:1呼吸
- 1サイクル = 吸気50% + 呼気50%

### 2026-08-14 改訂: 複数呼吸 → 1呼吸（オーナー決定「Aで進めて」）

旧仕様は `cycleCount = round(total/3)` で3秒あたり1呼吸（20〜24回/分）だった。成人の安静時呼吸数は12〜20回/分、副交感神経を優位にする共鳴周波数呼吸は5.5〜6回/分であり、旧仕様は**忠実に追従すると速い呼吸を誘導する**設計だった。画面文言「ひと呼吸おきましょう」が3呼吸を要求している齟齬もあった。
1呼吸へ統一することで、8秒設定は7.5回/分となり共鳴帯域に近づく。3秒設定も単発なので持続的な速い呼吸にはならない。
※3〜8秒はHRVが変化するには短く、この介入の機序は生理的鎮静ではなく**自動化された行動を意識へ引き上げること**（行動的機序）である。生理効果を訴求文言に使わない。
- 演出タイムラインはビュー内の `TimelineView(.animation)` で自前計時（ステージ表示開始時刻から換算）。モデルのステージ遷移が正であり、ビュー側の計時は描画専用。フロー再開（世代交代）時はビューが再生成される構成にし、状態を持ち越さない

### タイムライン（elapsed = ビュー表示からの経過秒）

| 区間 | スケール | 表情 |
|---|---|---|
| 各サイクル吸気（前半50%） | 1.00 → 1.06（easeInOut） | `blink`（目を閉じる） |
| 各サイクル呼気（後半50%） | 1.06 → 1.00（easeInOut） | `doom` に戻す |
| 最終サイクルの残り0.8s〜完了 | 1.00へ静かに収束 | `relief`（安堵）へ切替 |

- 表情切替は既存 `CharacterView` の expression 変更（クロスフェード内蔵）をそのまま使う。新規アセット禁止
- スケール上限は1.06厳守（PNG拡大ボケ回避）。`scaleEffect` はキャラコンテナに適用
- reliefは**完了の0.8秒前**に出す（完了と同時だと `.usageSummary` 遷移で見えないため）。ステージ遷移タイミングは変更しない
- total=3s（cycleCount=1）の場合: 吸気1.5s → 呼気1.5sの後半0.8sがrelief帯と重なるため、呼気開始〜0.7sで doom を挟まず blink→relief と直接つなぐ（3表情が1.5s内で暴れないように）

## 3. 進捗表示（2026-08-14 改訂: ドット廃止）

- **進捗ドットは表示しない。** 1呼吸に統一した結果ドットは常に1個となり、進捗の意味を持たないため廃止する（`cycleCount >= 2` の条件が成立しなくなる）
- **数字の秒数カウントは表示しない。** 根拠: 注意ゲートモデル（Zakay & Block）では時間そのものへ注意を向けるほど主観的持続時間が伸びる。カウントダウンは3秒を3秒以上に感じさせる
- **有限性は拡縮の弧が担う。** 膨らみ切って収縮へ転じた時点で「折り返した」と分かるため、非数値の連続的な進捗指標として機能する（Maisterの「不確実な待ちは長く感じる」への対処）
- 実装上は進捗ドットのビューと関連ロジックを削除する。ドット用の状態・定数を残さない

## 4. ハプティクス（BreathHapticsController）

- `CHHapticEngine` を使用。`CHHapticDeviceCapability.supportsHaptics == false`（シミュレータ等）では何もしない（クラッシュ・ログ汚染なし）
- パターン: サイクルごとに連続ハプティクス（`.hapticContinuous`）
  - 吸気: intensity 0.2 → 0.6 へランプ（`CHHapticParameterCurve`）、sharpness 0.3固定
  - 呼気: intensity 0.6 → 0.15 へランプ
  - relief切替の瞬間: 軽い単発 transient（intensity 0.5・sharpness 0.5）を1回
- エンジンは呼吸ステージ表示時に start、離脱時（onDisappear・ステージ遷移・バックグラウンド）に stop。`resetHandler`/`stoppedHandler` で再起動を試み、失敗しても演出は視覚のみで続行
- Reduce Motion時もハプティクスは維持（視覚の代替になるため）

## 5. Reduce Motion（2026-08-14 改訂）

- `accessibilityReduceMotion == true`: スケール呼吸を止め、キャラは等倍固定。表情遷移（blink/relief）とハプティクスは残す
- **代替として不透明度の呼吸を入れる**: 吸気で 0.85 → 1.00、呼気で 1.00 → 0.85（拡縮と同じイージング・同じタイムライン）。relief帯は 1.00 固定
  - 理由: ドット全廃（§3）とスケール停止が重なると、Reduce Motion経路では有限性の手がかりが表情変化2回だけになる。§3が有限性を「拡縮の弧」に委ねている以上、その弧を止める経路には非モーションの代替が要る
  - 不透明度のクロスフェードはApple が Reduce Motion 時の標準的な代替表現として認めている手法であり、前庭系を刺激しない
- 進捗ドットは Reduce Motion でも表示しない（§3で全廃済み。**旧記述「進捗ドットは残す」は誤りのため削除**）
- `CharacterView` 内蔵の浮遊・まばたき抑制はそのまま活かす

## 6. 制約・禁止事項

- Metal・パーティクル・Canvas等の新規描画表現は禁止
- 新規画像アセット・新規カラー・新規ローカライズキーの追加は禁止（文言追加なし）
- `InterventionFlowModel` のタイマー刻み（250ms）・世代ガード・`.usageSummary` 遷移条件を変えない
- 呼吸ステージの合計時間を延ばさない（reliefのために遷移を遅らせない）
- CTA・見出し等の既存文言に触らない

## 7. 検証

1. `cd ios && xcodegen generate && xcodebuild -project DopaBreak.xcodeproj -scheme DopaBreak -destination 'generic/platform=iOS Simulator' -derivedDataPath .deriveddata CODE_SIGNING_ALLOWED=NO build` → BUILD SUCCEEDED
2. `MeasurementFoundationTests` 全パス（呼吸タイマー回帰）
3. `BreathCharacterSnapshotCapture`（新規）: 旧FlameSnapshotCaptureと同じ実ウィンドウ+マーカー方式で、`01-inhale`（吸気中）/`02-exhale`（呼気中）/`03-relief`（完了直前）の3ステージを各10秒保持。`BREATH_STAGE_BEGIN <name>` マーカーを出力し、外部から `simctl io screenshot` で撮影できるようにする（total=8s設定・ループ再生）
4. ハプティクスはシミュレータで検証不可のため、実機確認項目としてレポートに明記する
