# 検証ログ — Automation tutorial locales

## 実行モード

standard

## 結果

| フェーズ | 試行 | 結果 | 内容 |
|---|---:|---|---|
| ビルド | 2 | ✅ | sandbox内の初回はXcode/SwiftPMキャッシュ権限で停止。許可済み環境で`xcodegen generate`とgeneric iOS Simulator buildを再実行し`BUILD SUCCEEDED` |
| 型・構文 | 1 | ✅ | 変更Swift 2ファイルの`swiftc -frontend -parse`成功。Xcode full buildでもコンパイル成功 |
| Lint・整形 | 1 | ✅ | 対象差分の`git diff --check`成功 |
| DopaBreakTests | 1 | ✅ | iPhone 17 Pro Max / iOS 26.5、54件成功、失敗0、スキップ0 |
| DopaBreakCore | 2 | ✅ | sandbox内の初回はSwiftPMキャッシュ権限で停止。許可済み環境で204件成功、失敗0 |
| セキュリティ | 1 | ✅ | 変更Swiftにpassword/secret/api_key/token代入なし。外部入力・通信・永続化の追加なし |
| 最終確認 | 1 | ✅ | TODO/FIXME/デバッグ出力なし。動画3本は生成`.app`内に各1コピー、元素材とbyte一致。保護対象2ファイルのSHA-256一致 |

## バンドル

- `automation-tutorial-ja.mp4`: 931,249 bytes、1コピー
- `automation-tutorial-en.mp4`: 744,599 bytes、1コピー
- `automation-tutorial-ko.mp4`: 695,264 bytes、1コピー
- 動画合計: 2,371,112 bytes
- 従来jaのみからのraw増加量: 1,439,863 bytes

## 保護対象

- `ios/DopaBreak/FlameBreathView.swift`: `9a776313bf8fa3124c2f8d5cf4502319e522e4d83a52e76eea584a40879615dc`
- `ios/DopaBreak/Shaders/Flame.metal`: `68bd922e00d387fc5695b77c6cf5de70e8fb523d3fe15fd5cf4a759316ac2b70`

コミットは実行していない。
