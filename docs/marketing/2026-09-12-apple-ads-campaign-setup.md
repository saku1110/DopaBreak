# Apple Ads キャンペーン設定記録（日本・英語圏・韓国）— 2026-09-12

**状態: 3市場とも作成済み・一時停止（PAUSED）。有効化はオーナー判断待ち。** 広告費はまだ発生していない。日予算は各キャンペーン¥1,000（3本すべてONなら合計¥3,000/日）。

オーナー指示「ブラウザでApple Adsの設定。1日1,000円を優先度の高いキーワードから」「日本だけでいいの？」に対する実施記録。最初に日本だけを作ったのは9/11媒体順序案（初回は1国固定）に沿った私の判断で、指摘を受けて英語圏・韓国を同構成で追加した。Chromeの ads.apple.com が未ログイン（Apple IDのサインイン画面）だったため、同じ広告アカウントに認証済みのApple Ads API（`asc ads`・ad account 21218040・API Campaign Manager）で作成した。管理画面にログインすると同じキャンペーンが見える。

## 作成した構成

| 項目 | 値 |
|---|---|
| キャンペーン | `DopaBreak JP CP2 解決語 2026-09-12`（ID 2144654752） |
| 配信国／面 | 日本／App Store検索結果（APPSTORE_SEARCH_RESULTS） |
| 日予算 | ¥1,000（JPY・PAYG） |
| 課金／入札 | タップ課金（TAPS）・手動CPT |
| 状態 | PAUSED（systemStatusReasons: PAUSED_BY_USER, APP_NOT_CATEGORIZED） |
| 除外キーワード | キャンペーン単位・完全一致 39語（調査レポート§4の日本除外語） |

| 広告グループ | ID | 上限CPT | キーワード（完全一致） | 端末／対象／Search Match |
|---|---|---|---|---|
| a 制限・スクリーンタイム | 2151029370 | ¥100 | スマホ制限／スクリーンタイム／アプリ制限／アプリロック／スマホ制限アプリ／スクリーンタイム制限／アプリ 時間制限／使用時間 制限／アプリ 使用時間／スマホ 制限 時間／スマホ ブロック／アプリ ブロック（12語） | iPhone／新規ユーザー（自アプリのDL済みを除外）／OFF |
| b 依存・やめたい | 2151031332 | ¥80 | スマホ依存／スマホ依存症／スマホ中毒／SNS制限／SNS依存／SNSやめたい／スマホ やめたい／デジタルデトックス（8語） | 同上 |
| c 夜・寝る前 | 2151032672 | ¥80 | 夜 スマホ／寝る前 スマホ／夜ふかし／夜更かし（4語） | 同上 |

根拠: `docs/marketing/2026-09-11-apple-ads-keywords-3markets.md` §5.3（初回実験・日本）。「集中」「ドーパミン」「競合指名」「Search Match」は初回に含めない（9/11媒体順序案どおり）。


## 英語圏（US・GB・CA・AU・NZ・IE・SG を1キャンペーン）

| 項目 | 値 |
|---|---|
| キャンペーン | `DopaBreak EN CP2 解決語 2026-09-12`（ID 2144655991） |
| 配信国 | US／GB／CA／AU／NZ／IE／SG（1キャンペーンにまとめ、国別の成績はレポートの国別内訳で見る。国ごとに入札を分けたくなったら分割） |
| 日予算 | ¥1,000 |
| 除外キーワード | キャンペーン単位・完全一致 39語（調査レポート§2の英語圏除外語＋AU opal card/opal travel/opal travel nsw・GB forest bike/nottingham forest・CA freedom mobile） |

| 広告グループ | ID | 上限CPT | キーワード（完全一致） |
|---|---|---|---|
| a screen time・app blocker | 2151030945 | ¥130（調査§5.2の許容上限 $0.9≒¥147 の内側） | screen time／screen time app／screen time control／screen time tracker／screen time blocker／reduce screen time／limit screen time／screen time limit／limit apps／app blocker／app blocker for iphone／block apps／app limit／app limits／block social media／social media blocker（16語） |
| b addiction・scrolling | 2151030813 | ¥100 | phone addiction／phone addiction app／digital detox／dopamine detox／social media detox／block youtube／stop scrolling／stop doomscrolling／doomscrolling／doom scrolling／block reels／block shorts／reels blocker／shorts blocker／distraction blocker／phone usage／digital wellbeing／quit tiktok／quit instagram（19語） |

端末iPhone・新規ユーザー（自アプリDL済み除外）・Search Match OFF。読み戻し（2026-09-12 02:44 UTC）: キーワード35語すべてEXACT・ENABLED・入札¥130×16／¥100×19、除外39語。

## 韓国

| 項目 | 値 |
|---|---|
| キャンペーン | `DopaBreak KR CP2 解決語 2026-09-12`（ID 2144656547） |
| 配信国 | KR |
| 日予算 | ¥1,000 |
| 除外キーワード | キャンペーン単位・完全一致 32語（調査レポート§3の韓国除外語） |

| 広告グループ | ID | 上限CPT | キーワード（完全一致） |
|---|---|---|---|
| a 스크린타임・앱 잠금 | 2151031837 | ¥100（許容 ₩620〜1,100≒¥69〜122 の内側） | 스크린타임／스크린 타임／스크린타임 줄이기／앱차단／앱 차단／앱 잠금／앱잠금／폰 잠금／핸드폰 잠금／앱 제한／앱 사용 제한／폰 사용 제한（12語） |
| b 폰중독・차단 | 2151032787 | ¥80 | 폰중독／폰 중독／스마트폰 중독／핸드폰 중독／디지털 디톡스／도파민／도파민 디톡스／숏폼 중독／쇼츠 차단／릴스 차단／유튜브 차단／sns 차단／sns 중독／폰 사용시간／사용시간 줄이기／폰 끊기／폰 줄이기（17語） |

端末iPhone・新規ユーザー・Search Match OFF。読み戻し: キーワード29語すべてEXACT・ENABLED・入札¥100×12／¥80×17、除外32語。

## 予算の考え方（オーナー判断）

- 3本すべてON: 合計¥3,000/日。市場ごとに1日10タップ前後の学習ができる。
- 合計を¥1,000/日に抑える: 1本だけONにして2週間ごとに市場を替える（調査では競合の壁が最も低いのは韓国、検索量が最も大きいのは日本、CPTが最も高いのは英語圏）。各¥333に割ると1日3タップで判断材料にならない。
- 予算変更は管理画面または `asc ads campaigns update --confirm` で可能。

## 検証（日本・API読み戻し・2026-09-12 02:24 UTC）

- キャンペーン: 日本／検索結果／¥1,000／PAUSED を確認。
- 広告グループ3件: status ENABLED・systemStatus RUNNING・入札¥100/¥80/¥80・iPhone・appDownloader exclude 6794221254・automatedKeywordsOptIn false を確認（作成直後の PENDING_AUDIENCE_VERIFICATION は数秒で解消）。
- キーワード: 24語すべて EXACT・ENABLED・入札額どおり（`readback_keywords.json`）。
- 除外キーワード: 39語すべて作成成功（`readback_negatives.json`）。
- `APP_NOT_CATEGORIZED` はAppleが広告システム上でアプリを分類するまでの一時的な状態。開発者フォーラムでは作成後10分〜10時間で自動解消の報告（https://developer.apple.com/forums/thread/679442）。有効化後にこの理由だけが残る場合は待つ。

## 有効化の手順（どちらか）

1. 管理画面: Chromeで https://app.searchads.apple.com/ にサインイン → ONにするキャンペーンを選ぶ（JP 2144654752／EN 2144655991／KR 2144656547）。
2. API: 次のコマンドを市場ごとに実行（このセッションでは権限判定でブロックされたため未実行）。

```bash
asc ads campaigns resume --ad-account 21218040 --campaign 2144654752 --confirm
```

```bash
asc ads campaigns resume --ad-account 21218040 --campaign 2144655991 --confirm
```

```bash
asc ads campaigns resume --ad-account 21218040 --campaign 2144656547 --confirm
```

## 留意点

- 公開中の1.0には計測SDKが入っていない。1.0.1（審査中）の公開前に配信すると、タップ・DL数は取れるが試用・課金の帰属はRevenueCatに残らない（`docs/marketing/2026-09-11-apple-ads-measurement-setup.md`）。
- 剪定: CPA(試用)≤¥1,000／CPA(有料)≤¥3,500・CPT上限を2週連続超過で停止（調査レポート§5.4）。検索語レポートは配信後に `asc ads reports` で取得する。
- 予算¥1,000／CPT¥100 で1日あたり最大10タップ程度。週次で語ごとのタップ・TTR・CPTを見て、b/cの上限を¥100へ上げるかを判断する。

## 証跡

`output/asa/2026-09-12-campaign-setup/`: 日本は `campaign.json`／`adgroup_{a,b,c}.json`／`keywords.json`／`negatives.json`、英語圏・韓国は `campaign_{EN,KR}.json`／`adgroup_{EN,KR}_{a,b}.json`／`keywords_{EN,KR}.json`／`negatives_{EN,KR}.json`（送信本文）。`*.response.json`（応答）、`readback_*.json`（読み戻し）。

## 2026-09-13 — 有効化後の初動と学習用入札

- オーナーが2026-09-12 15:10 UTCに3本とも有効化。保留理由（APP_NOT_CATEGORIZED）は解消し、3本ともRUNNING。
- 初日（13日 JST・約11時間）: 日本 34表示・3タップ・¥220（TTR 8.8%・実CPT平均¥73）。表示語は スクリーンタイム制限10／アプリ制限8／スマホ ブロック6／スマホ制限アプリ5／アプリロック4／スマホ依存症1。英語圏・韓国は表示0（全語RUNNING・国別レポート空）。
- 判断: 英語圏・韓国は入札が相場を下回り落札できていない。9/8検証設計の「上限つき学習費」として48時間だけ入札を上げる（日予算¥1,000が上限）。
- 反映（オーナー指示「APIで実行」・`targeting-keywords update-bulk`・66語成功）: EN a ¥130→¥250／b ¥100→¥180、KR a ¥100→¥160／b ¥80→¥130、JP「スクリーンタイム」「スマホ制限」¥100→¥150。
- 次回（9/15）: 表示が出た語は実CPT×1.2まで下げ、出ない語は停止。英語圏の¥250は許容CPT（$0.5〜0.9）を超える学習費なので、本運用の許容CACに混ぜない。
