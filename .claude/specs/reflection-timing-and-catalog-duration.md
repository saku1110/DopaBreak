# 一呼吸フロー: 全経路の時間選択と振り返りの提示位置

決定日: 2026-08-31（/brainstorm 議題タイプC・オーナー承認済み）

## 解決する問題

1. `.catalog` 経路（ショートカット自動化・ホーム・統計からの起動）が時間選択を飛ばしていた。
   時間を決めないため `ReflectionLog` が作られず、満足度が一度も聞かれない。
   `gateAllowed` はPro限定なので、無料ユーザーは `.gateToken` に到達できず時間も満足度も存在しない。
2. 満足度の提示が「DopaBreakを開いたときだけ・満了から30分で失効」で、実質ほぼ到達しない。

## 採用方針

- 満足度は設定時間の経過で**回答対象になる**（従来どおり `promptedAt = allowedUntil`）。
- 聞きに行くのは**次の一呼吸フローの冒頭**。通知は出さない。
- 却下: 時刻ベースのローカル通知（2026-08-28「利用時間の通知は廃止」と同じ体感になる。
  Proはシールドが立つので不要・無料は止められないので知らせても無意味）。
- 保留: DeviceActivityEvent の使用量しきい値による通知（v2以降。集計遅延の実測が必要）。

## 実装

### A. `.catalog` でも時間を選ぶ
- `InterventionFlowModel.proceedToOpenOrDurationSelection()` の `.catalog` 即開き分岐を廃止し、
  両targetとも `.durationSelection` を通す。
- `confirmSelectedDuration()` を `.catalog` にも対応させる。
- `usageSummaryOpenActionTitle` を両targetとも「開く時間を選ぶ」に統一する。

### B. `.catalog` でも ReflectionLog を予約する
- `InterventionEngine` に、Screen Timeトークンを持たない経路用の記録口を用意する。
  `promptedAt = 開いた時刻 + 選択分数`。`trigger` は既存の `.timedSessionEnded` を使う。
- 実際の再シールドはProのみ（トークンがないと不可能）。無料は宣言と振り返りだけ成立させる。
- `.catalog` の時間選択画面に、実際のブロックは起きない旨の一文を出す（誤解防止・3言語）。

### C. 振り返りを次の一呼吸の冒頭で聞く
- `InterventionFlowStage` の先頭に振り返りステージを追加し、`pendingReflection()` が対象を返すときだけ表示する。
- UIは既存 `PostUseReflectionSheet` の選択肢（`PostUseSatisfaction` 5択・1タップ確定・スキップ可）を流用する。
  データモデルは変更しない。
- 「3時間前の10分について」のように**経過時間と決めた分数**を必ず表示する。
- 回答・スキップ後はそのまま `breathing` へ進む。RootTabViewのシート提示と二重に出さない。

### D. 失効窓を延ばす
- `pendingReflection(within:)` の既定30分を延長する（未回答は次の一呼吸まで残す）。
  上限は24時間とし、それを超えたものは対象外にする。

## 制約（変更禁止）

- 再シールドはProのみ。無料に「時間で強制的に止まる」を実装しない。
- 通知を新規に追加しない。
- `PostUseSatisfaction` / `HappinessDelta` / `ReflectionLog` のスキーマを変えない（統計履歴が有料機能のため）。
- 表示コピーに読点を入れない。内部用語（介入・シールド等）をUIに出さない。
- Swift側 defaultValue と Localizable.xcstrings の値を完全一致させ、ja/en/ko を揃える。

## 検証

- `xcodebuild test` 全件失敗0。
- `scripts/lint-display-copy.py` と `scripts/audit-default-values.py` が exit 0。
- 追加テスト: `.catalog` で時間選択を通ること、`.catalog` で ReflectionLog が作られること、
  一呼吸の冒頭で未回答の振り返りが出ること、24時間超は出ないこと。

## 監視する指標（実装後）

一呼吸フローの完了率。振り返り1枚の追加で落ちないことを7日間の自己利用で確認する。
落ちる場合は毎回でなく2回に1回へ間引く。
