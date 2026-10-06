# Family Controls 審査停止の調査（2026-09-08）

## 結論

ユーザーが受領した自動通知は、Screen Time APIを検出したがFamily Controls entitlement付きの提出と認識できないため審査を進められない、という内容。配布権限未申請と断定できない。修復・再提出は未実施。

## 確認した証拠

- `docs/10_familycontrols_entitlement.md` は2026-07-03の承認と2026-07-08の4 App IDの配布用Capability有効化を記録している。ただし今回ポータルで再確認できた事実ではない。
- 本体、ShieldConfig、ShieldAction、Monitorのentitlements、`ios/project.yml`、生成されたXcodeプロジェクトにFamily Controlsの設定がある。
- `.claude/verification-logs/2026-09-07-appstore-b7/archive.log` にも4ターゲットの `com.apple.developer.family-controls = 1` がある。これはexport後のIPAの署名の証明ではない。
- WidgetsにはFamily Controls entitlementがなく、Widgetsと共有Coreソースには該当APIのimportを検出しなかった。最終バイナリのリンク状況は未確認。
- 直近提出記録: DopaBreak / app 6794221254 / version 1.0 / build 7（325f7c3e-901f-4a35-b7c9-21c4adfce18c）/ submission b125a39d-ac39-41ad-93ff-139192750d77。今回通知がこの提出に対応するかは最新状態との照合が必要。

## 制約と次の確認

記録された `/private/tmp/DopaBreak-appstore-20260907-b7.ipa` とxcarchiveは現環境に存在しない。`asc validate` と `asc review status` は `One or more parameters passed to the function were not valid. (-50)` で失敗し、現時点の審査状態は取得できなかった。

1. Developer Portalで本体と3拡張のFamily Controls (Distribution)が現在も有効か確認する。
2. 提出IPAが取得できれば、各バンドルのcodesign entitlementとembedded.mobileprovisionを照合する。なければ正しい配布用profileで新しいIPAを生成して同様に検証する。WidgetsのScreen Timeフレームワークリンクも調べる。
3. 不足があればprofile再生成・再署名した新ビルドを提出する。署名がすべて正しければ承認記録と各Bundle IDを添え、Appleに検出対象の確認を依頼する。

設定に不足の証拠がないため、コードやentitlementを推測で変更しなかった。APIの削除は集中時間・夜間ブロック機能に影響するため、この通知だけを根拠には選ばない。

公式資料: https://developer.apple.com/documentation/FamilyControls/requesting-the-family-controls-entitlement

## ブラウザで追加確認（2026-09-08）

App Store Connectの実画面で提出 b125a39d-ac39-41ad-93ff-139192750d77、1.0 (7) が2.5.1で却下されていることを確認した。TestFlightの当該ビルド「ビルドのメタデータ > エンタイトルメント」には、本体・Monitor・ShieldAction・ShieldConfigすべてで `com.apple.developer.family-controls: true` と `get-task-allow: false` が表示されている。先の「提出後署名は未確認」という制約に対し、Apple側のアップロード済みビルドの表示による証拠が得られた。古いprofileによる権限欠落を原因とする証拠はない。

Developer Portalでは本体、Monitor、ShieldActionのFamily Controls (Distribution)がチェック済みであることを確認。App Store Connectに上記ビルドメタデータの事実と検出対象の実行ファイル・Bundle IDの確認を依頼する英文返信を下書き保存した。「下書きを続ける」「下書きを削除」の表示を確認。返信は未送信。再ビルド、再提出、Capability変更は行っていない。

続いてShieldConfigでもFamily Controls (Distribution)のチェック済みを確認。これで対象4 App IDすべての配布用Capabilityを実画面で確認済み。
