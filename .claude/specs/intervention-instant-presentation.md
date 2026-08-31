# 介入画面の即時表示（ホームちらつき解消・2026-08-31 オーナー承認）

## 背景

SNSタップ→オートメーション→DopaBreak前面化のとき、一瞬ホームが見えてから一呼吸画面がスライドインする。原因は3段: ①インテントが別インスタンスでUserDefaultsに起動要求を書くだけ ②ルートは常にタブ（ホーム）で、要求の読み取りがscenePhase active後 ③介入はfullScreenCoverのアニメ付き提示。第一印象（自動起動の説得力）に直結するため「即呼吸」へ直す。

## 実装要件

### 1. 起動要求の同期読み取り（最初のフレームを介入にする）

- コールドスタート時、**最初のbody評価より前**（AppContainer/モデル初期化時またはRootTabView init）にSettingsStoreの起動要求（`pendingStartInterventionCatalogID` / `pendingStartInterventionAutoResolve`）を同期で読み取り、`pendingInterventionTarget` へ反映する
- 既存のscenePhase active・onChange経由の読み取りは「遅れて届いた要求」用としてそのまま残す（インテント書き込みとアプリ前面化の順序はOS依存のため）
- 既存の消費セマンティクス（1回で消費・再入時の扱い）を変えない

### 2. 提示機構をfullScreenCoverからルート直置きオーバーレイへ

- `presentedInterventionTarget != nil` の間、RootTabViewのZStack最前面に `InterventionFlowView` を**無アニメ**で直置きする（全画面・不透明・ignoresSafeArea）。fullScreenCoverによる介入提示は廃止
- 表示開始は**アニメーションなし**（状態変更を `Transaction(disablesAnimations: true)` 等で包む）。フロー内部（呼吸アニメ・勝ち画面等）のアニメーションは変更しない
- 消える側（勝ち/復帰→ホームへ戻る）は約0.2秒のopacityフェード（ease-out）。スライドは使わない
- 現行のonDismissロジック（`pendingInterventionTarget = nil` クリア等・RootTabView.swift:129-141相当）と、ロック画面チェック・ペイウォールとの排他/順序制御（先行カバーのonDismissで介入を提示する既存シーケンス）を等価に維持する
- オーバーレイには対象ターゲットで `.id()` を付け、**提示中に別ターゲットへ変わった場合はフローを作り直す**（既存レビューで指摘済みの古いターゲット残留バグをこの書き換えで解消する）
- ステータスバー・safe area・キーボード等、fullScreenCover廃止による表示差異が出ないこと

### 3. LaunchScreenをダーク単色へ

- Info.plist（xcodegen管理なので `ios/project.yml` 側の設定）の `UILaunchScreen` を、介入画面（E1 Dark Mono）の背景と同色の単色ダークにする。ロゴ・画像は置かない
- アプリ全体のダーク基調と同色にし、コールドスタートが「ダーク→呼吸」で繋がるようにする
- 注意: LaunchScreenはiOS側でキャッシュされるため、実機検証は再インストールが必要な場合がある（報告に明記）

## テスト

- 起動要求が保存された状態でモデル初期化→body評価前に `pendingInterventionTarget` が非nilであること
- 提示状態の遷移（オーバーレイ表示⇔ホーム復帰・ロック画面チェック/ペイウォールとの排他）の既存テストを新機構へ追従
- ターゲット切替でフローが作り直されること

## 制約

- 呼吸ファースト仕様（.claude/specs/intervention-breath-first.md）の順序・エンジン整合を壊さない
- InterventionFlowView内部・InterventionFlowModelのステート遷移は原則変更しない（提示側の書き換えが主）
- 省略・TODO禁止。xcodebuildでビルドと関連テストを通すこと
