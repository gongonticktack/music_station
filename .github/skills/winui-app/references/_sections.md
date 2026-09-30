# 参考資料のセクション

現在のタスクに合う、最も範囲の狭い参考資料ファイルをこの一覧から選んでください。

## 1. 基礎

- `foundation-setup-and-project-selection.md`
  - 優先度: CRITICAL
  - 初回プロジェクトのセットアップ、パッケージ化と非パッケージ化の選択、WinUI の基本的な前提条件に使用します。
  - 根拠: Microsoft Learn の WinUI および Windows App SDK セットアップ資料。

- `foundation-environment-audit-and-remediation.md`
  - 優先度: CRITICAL
  - マシンの準備状況の確認、不足している前提条件、手順に沿った修復に使用します。
  - 根拠: Microsoft Learn のセットアップ資料とシステム要件資料、および同梱のブートストラップ手順。

- `foundation-winui-app-structure.md`
  - 優先度: HIGH
  - ソリューションのレイアウト、シェルの構成、リソース、バインディング、C# を中心としたプロジェクト構成に使用します。
  - 根拠: WinUI Gallery のソースと Learn の XAML ガイダンス。

- `foundation-template-first-recovery.md`
  - 優先度: CRITICAL
  - 不透明な `MSB3073`、`XamlCompiler.exe`、起動失敗が発生し、代替のベースラインファイルを適用せず、新しい `dotnet new winui` のひな形と比較して復旧すべき場合に使用します。
  - 根拠: Learn のパッケージ化および非パッケージ化に関する展開ガイダンスと、繰り返し確認されているひな形優先の復旧パターン。

- `build-run-and-launch-verification.md`
  - 優先度: CRITICAL
  - ビルドと実行の手順、実際の起動確認、起動時のクラッシュ、パッケージ化と非パッケージ化に応じたローカル実行方法の選択に使用します。
  - 根拠: Learn のセットアップおよび展開ガイダンスと、繰り返し確認されている WinUI のトラブルシューティングパターン。

## 2. シェル、ナビゲーション、ウィンドウ

- `shell-navigation-and-windowing.md`
  - 優先度: HIGH
  - `NavigationView`、ページシェル、タイトルバー、`AppWindow`、複数ウィンドウの設計に使用します。
  - 根拠: Learn の設計ガイダンス、WinUI Gallery のサンプル、Windows App SDK の Windowing サンプル。

## 3. コントロール、レイアウト、アダプティブ UI

- `controls-layout-and-adaptive-ui.md`
  - 優先度: HIGH
  - コントロールの選定、コマンド領域、レスポンシブレイアウト、ページ構成に使用します。
  - 根拠: Learn の設計ガイダンスと WinUI Gallery のコントロールページ。

## 4. スタイル、テーマ、マテリアル、アイコン

- `styling-theming-materials-and-icons.md`
  - 優先度: HIGH
  - Fluent スタイル、テーマリソース、Mica、Acrylic、タイポグラフィ、アイコン表現に使用します。
  - 根拠: Learn の設計およびマテリアル資料、WinUI Gallery の背景効果サンプル、Windows App SDK の Mica サンプル。

- `motion-animations-and-polish.md`
  - 優先度: MEDIUM
  - トランジション、連動アニメーション、控えめな仕上げ、アニメーションの適切な運用に使用します。
  - 根拠: Learn のモーションガイダンス、WinUI Gallery のトランジションサンプル、CommunityToolkit のアニメーション。

## 5. アクセシビリティ、入力、ローカライズ

- `accessibility-input-and-localization.md`
  - 優先度: HIGH
  - キーボード操作、ナレーター、ハイコントラスト、自動化プロパティ、ローカライズに関する考慮事項に使用します。
  - 根拠: Learn のアクセシビリティおよびグローバリゼーションのガイダンス、WinUI Gallery の自動化パターン。

## 6. パフォーマンスと診断

- `performance-diagnostics-and-responsiveness.md`
  - 優先度: HIGH
  - UI スレッドの応答性、大量の項目コレクション、描画コスト、診断ツールに使用します。
  - 根拠: Learn の WinUI パフォーマンス資料と XAML フレーム分析ガイダンス。

## 7. Windows App SDK のシナリオ

- `windows-app-sdk-lifecycle-notifications-and-deployment.md`
  - 優先度: HIGH
  - ライフサイクル、アクティベーション、通知、パッケージ化と非パッケージ化の展開、ランタイムの初期化に使用します。
  - 根拠: Microsoft Learn の Windows App SDK 資料と WindowsAppSDK-Samples。

## 8. CommunityToolkit の拡張機能

- `community-toolkit-controls-and-helpers.md`
  - 優先度: MEDIUM
  - 組み込みの WinUI コントロールだけでは不十分で、Toolkit パッケージで不足を適切に補える可能性がある場合に使用します。
  - 根拠: CommunityToolkit/Windows のパッケージとサンプル。

## 9. テスト、デバッグ、レビュー

- `testing-debugging-and-review-checklists.md`
  - 優先度: HIGH
  - 最終レビュー、デバッグ手順、検証チェックリストに使用します。
  - 根拠: Learn のツール資料と、繰り返し確認されている WinUI のレビューパターン。

- `sample-source-map.md`
  - 優先度: MEDIUM
  - タスクごとに最初に確認すべき標準的なリポジトリやドキュメントを知りたい場合に使用します。
  - 根拠: Learn、WinUI Gallery、WindowsAppSDK-Samples、CommunityToolkit を横断して整理したマップ。
