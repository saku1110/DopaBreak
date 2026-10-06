# 2026-09-08: App Review 3.1.2(c)

ユーザー提供のApple返信: 同じ提出ID、1.0 (7)、iPad Air 11-inch (M3)。今回の指摘はアプリ内で機能するTerms of Use (EULA)とPrivacy Policyのリンク。既に存在する場合は画面録画を添えて返信し、今後のReview Notesにも記載するよう明示されている。今回の文面にFamily Controlsの再指摘はないが、個別の解決宣言もない。

現在のソースのPaywallView.swift:535–536に2つのSwiftUI Linkが存在する。legalAreaはScrollViewの末尾、固定購入ボタンはsafeAreaInset。リンクは11ptのsecondaryTextで、英語表記はTerms / Privacy。AppURLs.swiftはja/en/koのGitHub Pagesへ誘導する。現行ソースだけでは提出済みbuild 7の画面動作を証明できない。

次の必要な検証: build 7のiPad上で購入画面を開き、必要ならスクロールし、両リンクをタップして各ページの読み込み完了まで録画する。App Store ConnectのPrivacy Policy欄と説明文/EULA欄も照合する。現在、録画・ビルド7でのリンク動作・メタデータ再確認は未実施。Web取得ツールは両英語ページを取得できなかったが、これはリンク切れの証明ではない。

動作するなら録画と導線説明を返信。見切れ・タップ不能・リンク先不良があれば原因に応じて修正し、アプリ変更が必要なら新ビルドで提出する。外部返信・再提出は未実施。

## 追加検証・録画

2026-09-08、iPad Air 11-inch (M2) / iOS 26.5シミュレータで現在のローカルソースをDebugビルドし、オンボーディング最終付近から購入画面に進み、少し下へスクロールしてTermsとPrivacyを開く96秒の動画を保存。両方とも実際の英語ページがSafariに表示されることを目視確認した。ビルド成功。操作中に購入・復元は行っていない。

成果物: `output/review/2026-09-08-legal-links/`。現在ソースの検証ビルドであり、アップロード済みビルド7そのものの録画とは主張できない。App Store Connectのメタデータ確認、録画送信、審査メモ更新は今回未実施。

## ユーザー依頼による固定配置の修正

PaywallViewの法務リンクを購入ボタン直下のsafeAreaInsetへ移動。14pt・下線・44ptタップ領域とし、初期表示から見える。iPadシミュレータで修正後ビルド成功・表示・両リンク遷移を確認。修正版動画は `output/review/2026-09-08-legal-links/ipad-fixed-links-share.mp4`。提出済みビルドには未反映であり、審査へこの変更を反映するには新ビルドが必要。

## 再提出完了

ユーザー承認により1.0(8)をビルド・署名確認・アップロードし、既存提出IDの4項目を維持したまま2026-09-08 19:40 JSTに再提出。WAITING_FOR_REVIEW確認。審査メモ更新と動画添付COMPLETE確認。返信文はApp Store Connectで下書き保存し、未送信。証跡は `.claude/verification-logs/2026-09-08-appstore-b8/result.md`。
