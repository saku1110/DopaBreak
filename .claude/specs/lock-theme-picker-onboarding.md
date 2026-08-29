# ロック画面デザイン選択の導線追加（設計正本）

- 決定日: 2026-08-26（オーナー承認済み「案A：ガードを触らない」）
- 背景: `lock-theme-redesign-v2.md` で10テーマ（無料1＋Pro9）を構図から作り分けたが、**購入判断の場で1つも見えていない**。
  - オンボ16ステップにテーマ選択が存在せず、ユーザーはPro9種の存在を知らないままペイウォールへ着く
  - ホームに導線ゼロ
  - 設定は導線こそあるが、実物が出るのは選択中の1テーマだけ。残り9種は色の点＋テキストのチップ
- 目的: 10種の実物をユーザーに見せ、選ばせ、その選択をペイウォールの動機に接続する

---

## 0. 絶対に触らない部分（回帰防止）

| # | 制約 |
|---|---|
| 1 | **`AppContainer.swift` の `lockSurfaceState` にある権利ガードを一切変更しない**。権利のないテーマは描画直前に必ず `.e1` へ落ちる。時限の解放・例外・トライアルを足さない（リバーストライアルは今回不採用） |
| 2 | `EntitlementGate.lockThemeAllowed` の条件（free は `.e1` のみ）を変更しない |
| 3 | `LockThemeLiveActivityView` のレイアウト・160pt上限・`cardInset`・各テーマの意匠を変更しない。**表示するだけ**で中身に手を入れない |
| 4 | `live_activity.*` の確定コピー、Home Widget、Dynamic Island の構造を変更しない |
| 5 | `OnboardingStep.identifier` の既存16個の文字列を変更しない（ファネル計測の互換） |
| 6 | CTA文言に金額を入れない（オーナー恒久指示） |
| 7 | 表示コピーにリズム目的の読点を入れない（対比などの構造的理由のみ可） |

`SettingsStore.lockTheme` に Pro テーマを保存すること自体は安全で、意図的な仕様。保存値は残り、課金した瞬間に反映され、解約すれば自動で `.e1` に戻る。

---

## 1. 共通コンポーネント（新規）

`ios/DopaBreak/LockThemePickerView.swift` を新規作成し、**オンボ・設定・ホームの3面で共有**する。3箇所で別々に組まない。

### 1.1 API

```swift
struct LockThemePickerView: View {
    let selectedTheme: LockTheme
    let goalTitles: [String]
    let cancelledCount: Int
    let attemptCount: Int
    let isThemeAllowed: (LockTheme) -> Bool
    let onSelect: (LockTheme) -> Void
}
```

- 呼び出し側が `onSelect` の中身を決める（オンボ=そのまま保存／設定・ホーム=Proならペイウォール）
- `isThemeAllowed` は `model.entitlementGate.lockThemeAllowed` を渡す

### 1.2 レイアウト

- **縦1列のスクロールリスト**。全10テーマを `LockTheme.allCases` の順で並べる
- 各行は `LockThemeLiveActivityView` の**実物**を出す。ロック画面と同じ見え方にするため、393×160の固定キャンバスで描いてから等比縮小する:
  ```
  LockThemeLiveActivityView(theme:goalTitles:cancelledCount:attemptCount:)
      .frame(width: 393, height: 160)
      .scaleEffect(scale, anchor: .center)
      .frame(width: 393 * scale, height: 160 * scale)
      .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
  ```
  `scale = min(1, containerWidth / 393)`。**幅を可変にして中のレイアウトを崩さないこと**（各テーマは393:160前提で調整済み）
- 画面には常に**2枚以上が同時に見える**こと。「まだ他にもある」と伝わることがこの画面の役目
- 選択中: 角丸に沿ったアクセント枠（2pt）＋右上にチェック
- 未解放（free × Pro テーマ）: 既存キー `settings.status.pro` の「Pro」バッジを右上に出す。**カードを暗くしたりぼかしたりしない**。意匠が見えなければ意味がない
- 行全体をタップ領域にし、最小44pt高を満たす
- `goalTitles` は実際のユーザー目標を渡す。空なら既存の `lock_check.preview.goal_fallback`

---

## 2. オンボーディング（本命）

### 2.1 ステップ追加

`OnboardingStep` に `lockThemePick` を **`.lockScreenCheck` と `.prePaywallSummary` の間**へ挿入する。

```
... → notificationGuide → lockScreenCheck → lockThemePick → prePaywallSummary → ready
```

- `identifier` = `"lock_theme_pick"`
- 順序の理由: 先に `lockScreenCheck` で既定の黒とライムを実機に出して**仕組みを確認**させ、その後にデザインを選ばせる。逆順にすると「選んだのに実機には黒とライムが出た」という矛盾が起きる（権利ガードのため実機には出ない）
- `OnboardingStep` は `Int` の rawValue だが、rawValue は永続化されておらず `next`/`previous`/進捗カウンタの導出にしか使われていない。挿入して問題ない

### 2.2 画面内容

`lockThemePickContent` を `OnboardingFlow.swift` に追加し、既存の `screenScroll` / `centeredEyebrow` / `centeredTitle` / `centeredLead` / `onboardingStagger` の書式に合わせる。

| 要素 | ja 既定値 | 新規キー |
|---|---|---|
| eyebrow | ロック画面のデザイン | `onboarding.lock_theme.eyebrow` |
| title | デザインを選ぶ | `onboarding.lock_theme.title` |
| lead | あとから何度でも変えられます | `onboarding.lock_theme.lead` |
| primary CTA | このデザインで進む | `onboarding.lock_theme.action` |
| Proテーマ選択時の注記 | Proにすると このデザインで表示されます | `onboarding.lock_theme.pro_note` |

- **オンボではProテーマも自由に選べる**。タップでペイウォールを出さない。選択は `settingsStore.lockTheme` に保存する
- Proテーマを選んでいる間だけ、CTAの上に `pro_note` を1行出す（`onboarding.welcome.action_note` と同じ扱い方）。実機には出ないことを隠さない
- secondary action は無し（必ず何かが選ばれている状態なので「あとで」は不要。既定は現在の保存値）
- 選択のたびに `model.refreshLockSurfaces()` を呼ぶ

### 2.3 ペイウォール直前での回収（この施策の肝）

`prePaywallSummaryContent` に分岐を足す。**選択中テーマが `.e1` 以外のとき**だけ、既存の要約に加えて次を出す:

- 選んだテーマの `LockThemePickerView` と同じ縮小カード1枚（実物）
- その下に1行: 「Proにすると このデザインになります」 `onboarding.summary.theme_note`

`.e1` を選んだ人には何も足さない（現状のまま）。

抽象的な機能一覧ではなく、**自分がさっき選んだ具体的なカード**を見せてからペイウォールへ渡すことが目的。

### 2.4 計測

- 既存の `onboardingStepCompleted` に `detail: "lock_theme_pick"` が自動で乗る（`advance(from:)` の既存経路）
- 加えて、選択確定時に `model.recordFunnelEvent(.onboardingStepCompleted, detail: "lock_theme_pick:\(theme.rawValue)")` のような**テーマ別の記録**を1件残す。どのテーマが選ばれたかを後から集計できるようにする
- 新しい `FunnelEventName` は追加しない

> 計測上の注記（2026-08-26）: `confirmLockThemeAndAdvance()` はテーマ別の
> `detail: "lock_theme_pick:<raw>"` を記録し、その後の `advance(from:)` はステップ完了の
> `detail: "lock_theme_pick"` を記録する。このステップだけ同一ユーザーから
> `onboardingStepCompleted` が2件発生するため、イベント名だけの単純集計では1件多くなる。
> 仕様どおりであり、テーマ別detailと通常のステップdetailを区別して集計する。

---

## 3. 設定画面

`ios/DopaBreak/SettingsLockSurfaceView.swift` を書き換える。

- **横スクロールのチップ列（`themeChip`）を廃止**し、`LockThemePickerView` に置き換える
- 単独プレビュー（現在の `LockThemeLiveActivityView` 1枚）も廃止する。リスト内の選択中カードがその役目を兼ねる
- `onSelect`: 権利があれば保存、無ければ `paywallPlacement = .settingsThemeGate`（**現在の挙動を維持**）
- 「ロック画面で確かめる」行と Live Activity トグル行はそのまま残す

### 3.1 併せて直す不整合

現在このプレビューは `selectedLockTheme`（保存値）を描いているため、**free ユーザーが Pro テーマを保存している場合、実機と違うものが表示される**。オンボで Pro テーマを選べるようになると常態化するので、ここで直す。

- リストの**選択枠**は保存値（`selectedLockTheme`）に付ける — ユーザーの意思を保持していることを示す
- ただし Pro テーマが未解放のときは、そのカードに「Pro」バッジを出し続ける
- 「いま実機に出ているのはどれか」が誤解されないよう、未解放テーマを選択中の場合のみ、リスト上部に1行出す:
  「Proにすると このデザインになります」`settings.lock_screen.pro_note`

---

## 4. ホーム画面

`ios/DopaBreak/HomeView.swift` の `goalCard` の**後ろ**に `lockScreenCard` を1枚追加する。

- ホームの主役は `home.hero.lifetime.title`（SNSに消えるはずだった時間）。**このカードがヒーローより目立ってはいけない**
- 内容:
  - 既存キー `settings.entry.lock_surface`（ロック画面の表示）のラベル
  - **`model.lockSurfaceState.theme` の実物カード**を縮小表示（保存値ではなく、実際に出ているテーマ）
  - タップで `LockThemePickerView` のシートを出す
- シート内の `onSelect`: 権利があれば保存、無ければ `paywallPlacement = .homeThemeGate`
- `PaywallPlacement` に `case homeThemeGate = "home_theme_gate"` を追加する（導線別の効果を分離して計測するため。既存 `settingsThemeGate` を流用しない）
- Live Activity が無効なときはこのカードを出さない（出しても実機に何も出ないため）

---

## 5. 文言

- 上表の新規キーを `ios/DopaBreak/Localizable.xcstrings` に **ja / en / ko** で追加する
- **日本語の表示コピーに読点を入れない**。区切りが要る場合は半角スペース
- 英語・韓国語は既存のオンボ文言のトーンに合わせる。新しい訴求概念を発明しない
- `scripts/lint-display-copy.py` と `scripts/audit-default-values.py` を通すこと

---

## 6. テスト（必須）

| # | 内容 |
|---|---|
| 1 | `MeasurementFoundationTests.testOnboardingStepIdentifiersAreStableAndCoverAllSixteenSteps` を**17ステップ**へ更新し、関数名も実数に合わせる。既存16個の identifier 文字列は変更しない |
| 2 | `lockThemePick` が `lockScreenCheck` の次かつ `prePaywallSummary` の前にあること |
| 3 | **free ユーザーがオンボで Pro テーマを選んで保存しても、`AppModel.lockSurfaceState.theme` は `.e1` のままであること**（権利ガードの回帰防止。最重要） |
| 4 | 同じ状態で Pro になると、保存済みテーマが `lockSurfaceState.theme` に復活すること |
| 5 | 設定でfreeユーザーがProテーマをタップすると `settingsThemeGate` が、ホームのシートからだと `homeThemeGate` が立つこと |
| 6 | `LockThemePickerView` が10テーマ全件を描画すること |
| 7 | `prePaywallSummary` で、選択が `.e1` のときテーマカードが出ず、`.e1` 以外のとき出ること |
| 8 | `OnboardingMotionCapture.swift` が引き続きコンパイルされること |

---

## 7. 完了条件

- generic iOS の全ターゲットで `BUILD SUCCEEDED`
- DopaBreakCore と DopaBreakTests が失敗0
- `scripts/lint-display-copy.py` と `scripts/audit-default-values.py` が exit 0
- §0 の7項目に一切触れていないこと
