# App Storeスクショ 03-lockscreen の目標文言を4件構成へ差し替え（2026-09-04）

## オーナー決定（2026-09-04）
- 目標は **4件構成**（人生 → 期限つき → 習慣 → 今日 の梯子）。3件には戻さない
- 各国の実データ（新年の抱負・生活目標調査）で多数派が掲げる目標に差し替える。3ロケールは翻訳関係にない
- 期限つき枠は ja=TOEIC、ko=受験（토익）にする（簿記3級は弱すぎるため却下）
- 全文言は Live Activity 実機の1行幅（15pt bold・使用可能幅332pt）に**縮まず**収まることを実測済み

## 確定文言（この文字列を1文字も変えずに使う）

| 時間軸 | ja | en-US | ko |
|---|---|---|---|
| 1 人生 | 1000万円貯める | More time with family and friends | 종잣돈 1억 모으기 |
| 2 期限つき | 12月までにTOEIC800点を取る | Save $10,000 by December | 12월까지 토익 900점 넘기기 |
| 3 習慣 | 毎朝30分歩く | Hit the gym three times a week | 아침에 30분 걷기 |
| 4 今日 | 今日は0時までに寝る | In bed by 11 tonight | 오늘은 12시 전에 자기 |

カテゴリ（`goalSeeds` 用）: 1=.other 2=.study 3=.health 4=.sleep（3ロケール共通）。`lockScreenTitle` は全て nil。

## 変更箇所（3点＋再生成）

1. `scripts/generate-appstore-screenshots-v2.py` の `LOCK_GOALS`（L565付近）を上表の4件×3ロケールに置換。順序は表の1→4
2. `ios/DopaBreakTests/CoreScreensSnapshotCapture.swift` の `goalSeeds`（L91付近）を同じ4件×3ロケール・上記カテゴリに置換。`LOCK_GOALS` と文字列完全一致を保つ
3. `ios/DopaBreak/Localizable.xcstrings` の `live_activity.goal.eyebrow` の **en だけ** `Your goal` → `Your goals`（ja/ko は単複がないので触らない。他キーも触らない）
4. `scripts/generate-appstore-screenshots-v2.py` を ja / en-US / ko の3ロケールで実行し、`output/app-store-screenshots/v2/<locale>/iphone-69/03-lockscreen.png` と対応する `slots-<locale>.json`・contact sheet を再生成する。03 は `mock_lock()` によるPython生成なのでシミュレータ撮影は不要。**他のパネル（01/02/04〜10）のPNGは差分が出ないこと**（SHA-256で前後比較）

## 実装上の注意
- `mock_lock()` は `LOCK_GOALS[locale]` をループ描画しているので4件でも描けるはずだが、**カード高さ・下部の拡大コールアウト枝線・`goal_boxes` の幾何が3件前提で固定されていないか**を確認し、4件で崩れるなら最小修正する（幾何の定数を変える場合は変更前後の値を報告）
- スクリプトの実行方法・ロケール指定は同ファイル冒頭の docstring / argparse を読んで従う
- 既存の検証ロジック（`copy_geometry.lime_surface_validation` 等）が失敗したら握りつぶさず報告する
- `.claude/worktrees/` 配下は触らない

## 完了条件
- 3ロケールの `03-lockscreen.png` を目視で確認: 4行が1行ずつ省略なしで並び、コールアウト拡大側も同じ4行
- 他パネルのPNGに差分なし
- `xcodebuild` で `CoreScreensSnapshotCapture.swift` がコンパイルを通る（テスト実行は不要。ビルドだけ）
- 報告は「変更ファイル一覧・幾何を変えたなら前後値・3行要約」。差分本文は貼らない
