# marker-fix レビュー指摘（Opus5・2026-08-29）全件修正必須

対象: ios/WidgetsExtension/LockThemeLiveActivityView.swift / ios/DopaBreakTests/LockThemeLiveActivityViewTests.swift

## 中核問題: 整列もテストも「箱の中央」で自己成立しており、視覚的な中央揃えを実現・検証していない

1. **非e1の6テーマで新テストが循環（絶対にfailしない）** — `.goal(index)` と `.goalFirstLine(index)` を同一Viewへ連鎖アンカーしており両者は恒等。かつ各行はHStack既定 `.center` なので marker.midY == text.midY が構造上保証される。旧固定サイズのままでもpassする。

2. **e1も同じ穴** — バー位置と `goalFirstLine` オーバーレイが同一定数 `firstLineHeight` から導出され代数的に一致。描画された実1行目を観測していない。21組み合わせ全て同語反復。

3. **e1の定数行高が実描画とズレる（実害・未検証）** — `UIFont.systemFont.lineHeight` はラテン基準。日本語はHiraginoフォールバックで行高が大きく、バーが実1行目中心より上に出る。`minimumScaleFactor(0.6)` で縮小時は逆に下に出る。

4. **仕様は「キャップハイト中心」だが実装は「行ボックス中心」** — 20ptで約1.5〜2pt下にズレる。特にグリフ型マーカー（♥ :442 / ✽ :595 / ★ :385）は自前のベースライン上に乗る小さな行ボックスをボックス中央合わせしても光学中心が合わない。**オーナーの元指摘の残存原因はここの可能性が高い。**
   → 修正は `.firstTextBaseline` 揃え＋`alignmentGuide`/`baselineOffset` で行う（図形は baseline − capHeight/2 に中心、グリフは baselineOffset で光学中心補正）。ボックス中央合わせで済ませない。

5. **既存e1アサーションの弱体化** — :374/:409 で `.e1Goal(index)`（minHeight持ちの行枠）→ `.goal(index)`（内側テキスト枠）に差し替えられ、divider衝突検査が緩くなった。両方のアンカーで検査すること（:430のインク高検査の差し替えは可）。

6. **`testAdaptiveDensityUsesApprovedTypographyIncreases` の下限が緩い** — 1件時 `≥49` は60pt床を消してもpass。実装値に意味のある下限（例: 60・`lineHeight*2`の実値）へ。

7. **gaming 1件時の縦スパン120pt床がマージン2pt未満で脆い** — 余裕を確保するか、意図的なら根拠をコメントで残す。

## 受け入れ条件（再）
- マーカーの縦位置は**キャップハイト中心**基準で `.firstTextBaseline`＋ガイド補正により実装する
- テストは循環しない測定にする。**検証方法: マーカー整列の修正を一時的に旧固定配置へ戻すと新テストがfailすることを実際に確認し、その事実を報告に含めること**
- LockThemeLiveActivityViewTests 全件成功
