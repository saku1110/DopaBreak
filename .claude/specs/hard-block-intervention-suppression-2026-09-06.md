# ハードブロック中の通常介入の休止（2026-09-06）

## 決定

完全ブロック・夜間ブロックがアプリまたはカテゴリへ適用される時間帯は、通常の一呼吸介入と利用許可中の通過画面を休止する。ブロックの終了後は、新しい起動要求から通常介入へ戻す。抑止した要求を後から再生しない。

通常介入はカタログID、Screen Timeの選択は匿名トークンで管理され、本体内で確実に同一アプリと照合できない。そのため休止はブロック時間帯の通常介入全体に適用する。ブロック対象外のSNSの一呼吸もこの間は休止する。既存の利用時間超過による再介入抑止は対象ごとの判定を維持する。

## 実装

- `ios/Shared/ReinterventionShield.swift`: 拡張と共通の保存済みスナップショット・時間窓の判定から休止を判断。アプリまたはカテゴリ選択が必要で、Webドメインだけ・空・不正な選択は通常介入を止めない。
- `ios/DopaBreak/StartInterventionIntent.swift`: 休止中は要求を保存せず、残存要求を消去。
- `ios/DopaBreak/AppContainer.swift`: ショートカット・URL・直接要求・通過表示を同じ条件で抑止。
- `ios/DopaBreak/RootTabView.swift`: 初期表示と復帰時に残存介入の提示を抑止。
- `ios/DopaBreakTests/InterventionRoutingTests.swift`: 手動セッション、予定、夜間、終了境界、残存要求、利用許可、カテゴリ、Webのみ・空・不正データを検証。

## 採用しなかった案・制約

- 本体でApplication(token:).bundleIdentifierを使って対象照合する案は、ShieldConfiguration拡張以外ではnilとなるため不採用。Apple資料: https://developer.apple.com/documentation/managedsettings/application/bundleidentifier
- ブロック時間の設定値だけで休止する案は、監視失敗・権利変更で実際の適用準備ができていない場合まで介入を止めるため不採用。適用用スナップショットを利用する。
- AppIntentの`openAppWhenRun = true`は維持するため、DopaBreak自体の前面起動は起きうる。今回保証するのは介入画面・通過画面の抑止。実機のオートメーション発火順序とシールド表示は別途実機確認が必要。

## 検証

 iOS 18.3シミュレーターでInterventionRoutingTests（36件）・ShieldArmingStateTests（8件）・ReinterventionSchedulerTests（8件）を実行し、52件すべて成功。本体・拡張のビルドも成功。初回は追加テストのManagedSettings import不足でビルドが失敗したが修正後に同じ対象を再実行した。ログ: `/tmp/dopabreak-hard-block-tests.log`。関連する追跡済みファイルの`git diff --check`も成功。
