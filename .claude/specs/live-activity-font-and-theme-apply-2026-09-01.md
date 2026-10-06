# Live Activityのフォント同梱先変更（0MB）＋ 購入後のテーマ適用ルール — 設計（2026-09-01）

オーナー指示（2026-09-01）:
- ②「黒背景の有料デザインでLive Activityが真っ黒」を**早く**直す
- テーマ適用ルール変更: 「オンボーディングから選択して購入したら選択したデザインにして。オンボーディング以外のペイウォールからならデフォルトスタート。デザイン選択画面で選択して出たペイウォールは選択したものが購入後デフォルト選択になるようにして」

---

## A. Live Activityでバンドルフォントのテーマが真っ黒になる

### 根拠（推測ではなく実測）
- オーナー実機で**ゲーミングのLive Activityが枠だけ黒く中身なし**（2026-09-01・スクリーンショット確認）
- 端末の `systemCrashLogs` を `devicectl` で全件取得。**WidgetsExtension のクラッシュは1件も無い**（DopaBreak関連は2026-08-11の1件のみ、今日のクラッシュはゼロ）。つまり描画プロセスは落ちていない
- シミュレータの実機ロック画面で **e1（システムフォント）は正常に描画される**ことを確認済み
- バンドルフォントを使うテーマは **ゲーミング（DotGothic16 / ko: Galmuri11）と手書きノート（ZenKurenaido / ko: NanumPenScript）の2つだけ**
- ゲーミングの背景は `rgb(10, 10, 20)`、罫線は `.white.opacity(0.035)`。**文字が描かれなければ実質真っ黒に見える**
- ビルド成果物の実測: フォント4件は `DopaBreak.app` 直下のみ。`WidgetsExtension.appex` 内は**0件**。アプリ・Extension とも `UIAppFonts` の宣言**なし**

### 原因
フォントは `CTFontManagerRegisterFontsForURL(..., .process, ...)` による**実行時・プロセス単位**の登録しかない。
アプリ本体とWidget Extensionのプロセスでは登録が効くのでアプリ内プレビューは正しく出る。
しかしLive Activityの実表示は**Extensionが書き出したアーカイブをシステム側の描画プロセスが描く**。
そのプロセスにフォントは登録されていないため、カスタムフォント指定のTextが描画されない。

### 修正: フォントの同梱先をExtensionへ移す（容量増加0MB）

**複製しない。** アプリ直下からExtension内へ「移す」。合計サイズは14.26MBのまま変わらない。

1. `ios/project.yml`
   - フォント4件（`DotGothic16.ttf` / `ZenKurenaido.ttf` / `Galmuri11.ttf` / `NanumPenScript.ttf`）の同梱先を
     `DopaBreak` ターゲットから `WidgetsExtension` ターゲットへ移す
   - `WidgetsExtension` の Info.plist に `UIAppFonts` を追加し、4ファイルを列挙する。
     これでシステムがExtensionのコンテンツとしてフォントを登録し、Live Activityの描画時に解決できる

2. `ios/Packages/DopaBreakCore/Sources/DopaBreakCore/Services/BundledFontRegistrar.swift`
   - `resourceRoots(explicitURL:)` は現在「`Bundle.main` から6階層**上**へ遡る」だけ。
     アプリ本体から見るとフォントは `PlugIns/WidgetsExtension.appex/` の**下**になるため見つからない
   - 探索先に**子孫方向**を追加する:
     `Bundle.main.bundleURL/PlugIns/WidgetsExtension.appex/` と同 `Fonts/` サブディレクトリ
   - 既存の上方向の探索は残す（Extensionプロセスからの解決経路をそのまま活かすため）
   - 探索順は「自バンドル → 子孫(PlugIns) → 祖先」。**最初に見つかったものを使う**

3. `ios/DopaBreak/DopaBreakApp.swift` の `registerBundledFonts(resourceBundleURL: Bundle.main.bundleURL)` は
   **明示URLを渡すのをやめ、引数なしで呼ぶ**。明示URLを渡すと `resourceRoots` が
   「そのURLだけ」に絞られる実装のため、PlugIns配下を探せなくなる

4. テスト
   - `ios/DopaBreakTests/BundledFontIntegrationTests.swift` はフォントの実在場所を検証している。
     新しい同梱先（appex内）に合わせて更新する。**「アプリ直下に無いこと」も明示的に検証する**（複製が復活したら落ちるように）
   - アプリプロセスで4フォントすべてが `registeredName(for:)` で解決できることを検証する回帰を残す

### 受け入れ条件
- ビルド成果物で `.ttf` が `WidgetsExtension.appex` 内に4件、`DopaBreak.app` 直下に**0件**
- アプリ内のテーマプレビュー（設定・ホーム・オンボーディング）でゲーミングと手書きノートの書体が従来どおり出る
- 実機のLive Activityでゲーミングと手書きノートの文字が出る（**オーナー実機確認が最終判定**）
- バンドル総サイズが実質増えない（複製していないこと）

### これで直らなかった場合の次手（今回は実装しない）
描画負荷の線。ゲーミング固有の `RepeatingLines(spacing: 4)`（全面約40本）と `.shadow` 3箇所を疑う。
その場合は spacing を粗くするのではなく、**Shapeを丸ごと外して実機で見る**ことで
「本数が閾値」か「Shapeの描画自体が失敗」かを切り分ける。

---

## B. 購入後にどのテーマを適用するか

### 現状と問題
`.claude/specs/lock-theme-pending-selection.md`（2026-08-26オーナー承認）で
「ロック済みテーマをタップしたら**常に保存**し、権利ガードで無料の間だけ隠す」方式にした。
そのため**過去にどこかで一度タップしたProテーマが永続的に残り**、
別の入口のペイウォールで購入した瞬間に、意図しないテーマ（ゲーミング）が適用される。
オーナーが2026-09-01に「なんでProにしたら自動的にゲーミングデザインが選択される？」と指摘。

### 新ルール（2026-09-01オーナー指示・8/26設計を上書き）

| 購入の入口 | 購入後に適用されるテーマ |
|---|---|
| オンボーディングのテーマ選択から | **選んだテーマ** |
| デザイン選択画面（設定・ホーム）でロック済みを選んで出たペイウォール | **選んだテーマ** |
| それ以外のペイウォール（週次・ブロック設定・クイックアクション等） | **既定（黒とライム / e1）** |

### 実装方針: 永続状態を増やさない

8/26設計の「新しい永続フィールドを作らない」制約は維持する。
**ロック済みテーマは保存しない。** 選択は**メモリ上の保留**として持ち、購入が成立したときだけ確定させる。

1. `ios/DopaBreak/AppContainer.swift`（`AppModel`）
   ```swift
   /// ロック済みテーマをピッカーで選んだときの保留。永続化しない。
   /// プロセスが終われば消えるため、別入口のペイウォールで買った場合は既定のままになる。
   var pendingProThemeSelection: LockTheme?
   ```

2. 選択ハンドラ（`HomeLockThemeSelectionHandler` / `SettingsLockThemeSelectionHandler` / オンボーディングの選択）
   - 許可されているテーマ → 従来どおり `model.updateLockTheme(theme)` で保存し、保留はクリアする
   - **許可されていないテーマ → 保存しない。** `model.pendingProThemeSelection = theme` を立て、
     ペイウォールを出す（placementの出し分けは現状維持）

3. ピッカーの選択表示
   - チェックマークと「Proにすると このデザインになります」の注記は
     `model.pendingProThemeSelection ?? model.savedLockTheme` を基準にする。
     **無料のままでも、選んだ見た目が選択状態に見える体験は8/26のまま維持する**

4. 購入成立時の確定
   - `RootTabView` が既に監視している `storeService.isPro` / `entitlementRevision` の変化点で、
     `isPro == true` になったら `pendingProThemeSelection` を `updateLockTheme(_:)` で確定し、保留をクリアする
   - 保留が無ければ何もしない（＝既定の黒とライムのまま）

5. 既存の保存値の後始末
   - 旧方式で既に `lockThemeRawValue` にProテーマが保存されている端末がある（オーナー実機がその状態）。
     **`migrateStoredValues()` では触らない。** 保存済みのテーマはユーザーが一度選んだものなので、
     Proなら従来どおり反映してよい。今回の変更は「今後、無料時のタップを永続化しない」ことだけを保証する

6. テスト
   - 無料でProテーマをタップ → `settingsStore.lockTheme` が変わらないこと
   - その状態で `isPro` を true にする → 保留が確定して反映されること
   - 保留なしで `isPro` を true にする → 既定（e1）のままであること
   - オンボーディング経路でも同じであること

### 受け入れ条件
- 無料でProテーマをタップしてペイウォールを閉じ、アプリを再起動して別のペイウォールから購入 → **黒とライム**
- デザイン選択画面でProテーマをタップ → そのままペイウォールで購入 → **選んだテーマ**
- オンボーディングでテーマを選んで購入 → **選んだテーマ**

---

## 共通ルール
- 省略・TODO・死んだコード禁止
- 表示コピーは変更しない
- ビルド確認: `xcodebuild -project ios/DopaBreak.xcodeproj -scheme DopaBreak -destination 'platform=iOS Simulator,id=DF6A380F-D0EC-42CA-A508-0D02CEE9F404' build`
- **シミュレータのアプリを起動・終了しない**（並行セッションのテストホストを殺すため）
- 担当外ファイルに触らない: `WinScreenView.swift` / `ReclaimedTimePresentation.swift` / `WakeSleepTimelinePolicy.swift` / `SettingsView.swift` は別セッションの担当
