# Live Activityカード 文字サイズ拡大・余白圧縮 v1（2026-08-29 オーナー指示）

## 背景（オーナー指摘）
「LiveActivityのデフォルトデザインもそうだけど文字サイズが小さくて上下の余白が多い。他のデザインも無駄な余白が多ければ改善して」

原因: `ios/WidgetsExtension/LockThemeLiveActivityView.swift` の各テーマは393×160pt固定キャンバスに対し、
本文が内在サイズ（目標行15pt前後・行高21〜26pt）のまま `maxHeight: .infinity` で上下中央寄せされる。
目標1〜2件時に上下デッドスペースが大きく、3件時もタイポが小さい。

## 設計方針（Fable決定）

### 原則
1. **160ptキャンバスを常に使い切る。** コンテンツ中央寄せによる上下デッドスペース禁止。
   縦の余りは「行高・セクション間隔の拡大」へ分配する（単に上寄せにするのではない）。
2. **目標行が主役。** 目標本数でアダプティブにサイズを変える:
   - 1件: 目標フォント 現行+5pt（例: E1 15→20）、行高を比例拡大
   - 2件: 現行+4pt（例: 15→19）
   - 3件: 現行+2pt（例: 15→17）。長文3件でも160ptに収まることが絶対条件
3. サマリー行（開かなかった/開こうとした）: 現行10.5〜12pt → +1〜1.5pt（可読性向上、主役は目標のまま）
4. eyebrow（あなたの目標）は現行サイズ維持でよい（小さくてよい要素）。
5. `minimumScaleFactor` / `lineLimit` の既存ルールは維持（長文の防御を弱めない）。

### 全テーマ共通で維持する既存制約（design-decisions.md 既決事項）
- カード本体160pt・四辺描画、`.frame(minHeight: maximumHeight)` を背景より外へ動かさない
- 水平インセット16pt（note左46ptのみ例外）
- e1: `lineLimit(2)`・uppercase eyebrow・3件時dense分岐
- asagiri: 目標中央揃え、K-POP: 全幅実績帯、blueprint: セル内4pt以上の余白（テストが検査）
- `isMeasuring` 経路へ固定height/clipを足さない
- フォント配線（DotGothic/Zen Kurenaido/Galmuri11/NanumPen/HiraMaru）、Home Widget・Dynamic Island構造、
  `live_activity.*` コピー、EntitlementGate条件は変更しない

### blueprint の例外許可
サマリーのフォント拡大で現行の固定セル幅（外寸285pt・左174pt）が窮屈になる場合、
テスト（テキストとセル境界4pt以上）を満たす範囲でセル幅の拡大を許可する。

## 受け入れ条件
- `LockThemeLiveActivityViewTests` 全件（90枚描画・160pt上限・カード境界・blueprint/note個別検査）成功
- 目標1件・2件・3件の各ケースで、コンテンツ縦占有率が明確に改善している
  （目安: contentBounds.height ≥ 120pt を1件時でも満たす）
- 必要ならテストへ「1件時のcontentBounds高さ下限」等の回帰を追加する
