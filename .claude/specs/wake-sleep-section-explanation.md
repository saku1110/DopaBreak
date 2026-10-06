# 起床・就寝時刻セクションに説明を常時出す（案A・オーナー承認済み 2026-09-01）

> **⚠️ 2026-09-02 に一部失効。** オーナー指示により、起床・就寝時刻セクションは
> **`selectedMode == .nightOnly` のときだけ表示する**ようになった。
> これに伴い、本書の「セクションの表示条件を変えない（今までどおり常に表示する）」という制約と、
> 標準・ディープフォーカス向けの新規キー `settings.schedule.description` は無効。
> 同キーはカタログから削除済み。**復活させないこと。**
> 現行の正は `.claude/specs/design-decisions.md` の
> 「2026-09-02 — 起床・就寝時刻セクションを夜だけ強化時のみ表示」の項。

## 背景（調査済みの事実）
`wakeSleepTimelineSection` は**モードに関係なく常に表示される**が、この設定が実際に効くのは
「夜だけ強化」を選んでいるときだけ。標準・ディープフォーカスでは一呼吸画面のバナー文言が
起床後30分以内／就寝前60分以内に変わるだけで、ブロック挙動は一切変わらない。

いま画面に出る説明は `InterventionMode.nightOnly.detailText` のみで、しかも
`selectedMode == .nightOnly` のときだけ。標準モードで見ると見出しとバーしかなく、
何に効くのか読み取れない。オーナーから「設定して意味あるのか不明」と指摘された。

## 変更内容

`ios/DopaBreak/SettingsView.swift` の `wakeSleepTimelineSection` の
時刻ラベル行（`"0:00" / 起床 / 就寝`）の**下**に、モードで出し分ける説明文を1つ追加する。
既存の他セクションのfootnoteと同じ体裁にする（`.dopaFont(13, weight: .medium, lineSpacing: 3)`、
`DesignTokens.secondaryText`、`.fixedSize(horizontal: false, vertical: true)`）。

- `selectedMode == .nightOnly` のとき: 既存キー **`settings.night_only.description`** を再利用する
  （ja「選んだアプリは就寝時刻から起床時刻まで開けません。日中は、開く前に一呼吸をはさみます。」・
  3言語とも翻訳済み。新規キーを作らない）
- それ以外（標準・ディープフォーカス・Free）のとき: **新規キー `settings.schedule.description`** を出す

## 新規キー `settings.schedule.description`（3言語すべて `ios/DopaBreak/Localizable.xcstrings` へ追加）

- ja: `夜だけ強化を選ぶと、この時間が完全ブロックの範囲になります。ほかの強さでは、起きたあとと眠る前の一呼吸で言葉が変わります。`
- en: `Pick Stronger at night and this becomes the block window. In the other modes it changes what the pause says after you wake up and before you sleep.`
- ko: `밤에만 강하게를 고르면 이 시간이 완전 차단 구간이 돼요. 다른 강도에서는 일어난 뒤와 잠들기 전 숨 고르기 문구만 바뀌어요.`

モード名は既存の `intervention_mode.night_only.title`（ja 夜だけ強化 / en Stronger at night / ko 밤에만 강하게）と
文字列を一致させること。ハードコードした訳語がカタログとズれないようにする。

## 制約（守ること）
- **文言は上の3行をそのまま使う。creativeに書き換えない。** 日本語の読点は1文に1個までで確定済み。
- バー・ハンドル・ラベル行・ポップオーバー・ドラッグ挙動は一切変更しない。今回は説明文の追加だけ。
- 起床・就寝にオンオフのトグルを**追加しない**（オンオフはモード選択そのもの。別途判断する）。
- セクションの表示条件を変えない（今までどおり常に表示する）。
- `deepFocusFootnote`（SettingsView.swift:2037）には触らない。
- 夜専用の時間帯設定を新設しない（design-decisions.md:298）。
- 表示コピーの体裁は既存footnote（`settings.gate.description` の出し方）に合わせる。

## 検証
- `cd ios/Packages/DopaBreakCore && swift test` が失敗0であること
- `xcodebuild build -project ios/DopaBreak.xcodeproj -scheme DopaBreak -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` が BUILD SUCCEEDED
- `python3 scripts/lint-display-copy.py` と `python3 scripts/audit-default-values.py` があれば実行し、新規の指摘を出さないこと
- `Localizable.xcstrings` が ja/en/ko の3言語すべて埋まっていること（未翻訳stateを残さない）
