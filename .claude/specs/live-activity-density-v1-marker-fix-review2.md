# marker-fix 2周目レビュー指摘（Opus5・2026-08-29）最終サイクル・全件修正必須

対象: ios/WidgetsExtension/LockThemeLiveActivityView.swift / ios/DopaBreakTests/LockThemeLiveActivityViewTests.swift

前提: 中核は合格（ガイド数式正しい・インク境界テストは実効的=42アサーション・22/42完全一致、残りも1px以内）。以下の残課題のみ修正する。

1. **gaming 3件時がトレランス境界ちょうど（|Δ|=1.0 / accuracy:1・マージンゼロ）** — 実際に約1ptキャップ中心からズレている（角枠ストロークのインク15pxと約13.6ptフレームの差）。残オフセットを補正し、境界ぎりぎりでなく余裕を持ってpassさせること。

2. **note 3件時はテキストインクが2px高（Zen Kurenaido 17.5ptのアンチエイリアスがchannelTolerance=48で落ち、Hの横棒しか検出されていない）** — `inkBounds` に妥当性ガードを追加（例: capインク高 ≥ 期待capHeight×0.6 でなければXCTFail）。基準側が黙って劣化してもfailしない現状を塞ぐ。

3. **kpopの★が未補正・未検証** — ♥/✽と違い `glyphCapCenterOffset`（baselineOffset補正）が適用されておらず、フレーム内で行ボックス中央のまま（前回指摘4と同種の欠陥）。さらにテストのマーカークロップは縦バーのRectangleがフレームを満たすため★自体の光学中心を測っていない。★にも補正を適用し、バーのx範囲を除外したクロップで★を独立測定すること。

4. **出荷ケース（日本語・縮小）が未検証＋整列計算が非縮小ラテンメトリクス依存** — ガイドはフルサイズ `UIFont.systemFont.capHeight` を使うが、目標文字には `minimumScaleFactor(0.5〜0.6)` があり、縮小時は最大約3.5ptズレうる。CJK（Hiragino/Nanum）の視覚中心差も未検証。テストは "HHHHHHHH"×en_US のみで両リスクを回避している。
   → 少なくとも「長い日本語タイトル×3件」のマーカー整列ケースを追加し、縮小・CJKで許容内に収まることを実測で保証する。縮小時のズレが許容を超えるなら、縮小適用後の実効フォントに追随する補正を入れる。

5. **`testAdaptiveDensityUsesApprovedTypographyIncreases` の2〜3件分岐が恒真**（プロダクション式の再計算と比較していて `max(0,x) >= x`）— 実装値のハードコード期待値と比較する形へ。1件時の `>= 60` は現状維持で可。

6. （対応不要・記録のみ）`CGContext(data:&bytes,…)` のinoutエスケープは既存パターン・低リスク。channelTolerance=48でnoteのマーカー色とテキスト色が相互マッチしうるが現状クロップが分離しているため安全。

## 完了条件
- 上記1〜5を修正し、LockThemeLiveActivityViewTests 全件成功
- 追加した日本語×3件ケースを含め、全整列アサーションが accuracy 境界ちょうどでなくマージンを持ってpassすること（境界値になったテーマは実装側のオフセットを直す）
