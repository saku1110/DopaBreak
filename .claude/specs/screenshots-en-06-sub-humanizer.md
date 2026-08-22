# en-US スクショ06サブコピー差し替え＋humanizer-en再監査＋upload-order更新（2026-08-22）

## 背景
振り返り1問化で「focus」を聞かなくなったため en-US #6 sub から focus を抜く必要がある。ただし "Track satisfaction, attempts, and skipped opens" は3項目列挙（rule of three）で humanizer-en の triads ゲートに抵触しうる。非3項目列挙の形に差し替える。

## 実施
1. en-US #6 sub を次のいずれかに差し替え（`scripts/generate-appstore-screenshots-v2.py` と承認正本 `scripts/generate-appstore-screenshots.py` の**両方**・同一文言・validate_legacy_copy_reuse 通過）:
   - 第一候補: "Log how you felt, then see your attempts and skipped opens"
   - 代替: "See how you felt, plus every attempt and skipped open"
   monitor行の幅に収まるか（既存06の描画で折返し・はみ出しがないか）を再生成画像で確認し、収まらなければ語を削って2行以内に収める
2. humanizer-en 監査（`~/.claude/skills/humanizer-en/scripts/audit.py`）: en-US 10枚分の全キャプション（eyebrow/headline/sub）を1行1文にしたテキストで、**before（差し替え前の現行scriptsコピー）→ after** の2回計測。全ゲート通過（exit 0）・triads不増を確認し、両方の数値（SD含む）を報告
3. en-US を再生成（10枚・contact sheet・slots）。他のen-USコピー（#1 sub/#3 sub/#4/#6 eyebrow 等の既存変更）は一切触らない
4. `output/app-store-screenshots/v2/upload-order/en-US/iphone-69/08-habit-tracker.png`（＝生成番号06）を新しい 06-reflection-stats.png で差し替える。他9枚は据え置き
5. `.claude/specs/appstore-screenshots-v2-diagonal.md` の en-US 2026-08-22 追記に #6 sub 変更を1行追記

## 検証（報告に含める）
- humanizer-en before/after の数値・exit code
- `python3 scripts/lint-display-copy.py` exit 0、`git diff --check`
- en-US 10枚＋contact sheet＋slots（total ≤ 1）、upload-order の差し替え結果（ファイルのハッシュ一致で確認）
- 変更ファイル一覧とコンタクトシートのパス
