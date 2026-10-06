# オンボーディング表示条件の確認

- 現行コードは `DopaBreakApp.swift` の `onboarding.isCompleted` が false のとき `OnboardingFlow` を表示する。TestFlightを理由にスキップする分岐はない。
- `OnboardingCoordinator` は App Group の `SettingsStore.onboardingCompleted` を読み込む。キー未保存時は false。完了時に true を保存する。
- 再インストールを検知して完了状態をクリアする処理はない。端末で完了状態が残っている場合は表示されないが、端末の保存値とインストール済みビルドは未確認のため今回の原因とは断定できない。
- 設定の「最初の説明をもう一度見る」は `#if DEBUG` 内にあり、通常のRelease/TestFlightには表示されない。
- 「全データを削除」はオンボーディング完了キーも消す。目標・記録・設定も削除するため、説明再表示だけを目的とする非破壊的な導線にはならない。
- 今回はコード調査のみ。アプリコード変更・実機操作・ビルド配信は行っていない。
