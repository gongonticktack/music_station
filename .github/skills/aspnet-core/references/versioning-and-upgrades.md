# バージョン管理とアップグレード

主なドキュメント:
- https://learn.microsoft.com/aspnet/core/release-notes/
- https://learn.microsoft.com/aspnet/core/release-notes/aspnetcore-10.0
- https://learn.microsoft.com/aspnet/core/release-notes/aspnetcore-9.0
- https://github.com/dotnet/AspNetCore.Docs/tree/main/aspnetcore/breaking-changes

## バージョン選択の基本方針

- 2026 年 3 月時点で、新しい本番用アプリには `net10.0` を優先する
- 既存のアプリでは、タスクが明示的にアップグレードでない限り、リポジトリのターゲットフレームワークに合わせる
- 新しい API を使用する前に、対象のターゲットフレームワークに存在することを確認する

## アップグレードの手順

1. 現在のターゲットフレームワークと SDK を確認する
2. バージョンを一つ上げるごとに、「新機能」と破壊的変更のページを読む
3. ビルドし、非推奨になった箇所を意図を持って修正する
4. 統合テストと認証・認可のフローを再実行する
5. プロキシ、Cookie、静的アセットなど、デプロイ環境固有の動作を再テストする

## 優先して確認する破壊的変更

ASP.NET Core 10 に移行する際は、次の点に注意してください。

- 既知の API エンドポイントで Cookie ログインへのリダイレクトが無効になること
- `WithOpenApi` の非推奨化
- `WebHostBuilder`、`IWebHost`、`WebHost` の非推奨化
- Razor の実行時コンパイルの非推奨化

ASP.NET Core 9 に移行する際は、次の点に注意してください。

- `HostBuilder` を使用する場合、開発環境で `ValidateOnBuild` と `ValidateScopes` が有効になること
- ミドルウェアのコンストラクターに関する要件と DI 検証の変更

ASP.NET Core 8 に移行する際は、次の点に注意してください。

- Minimal API の `IFormFile` に関する偽造防止の要件
- 対応するミドルウェアを使用する場合の `AddRateLimiter()` と `AddHttpLogging()` の要件

## 移行の原則

- 起動処理を大幅に変更する場合は、最新のホスティングモデルへの移行を優先する
- 互換性維持のためのコードは、テストで動作を確認してから削除する
- 移行途中の状態で、新しいフレームワークの書き方と古い起動処理の構成を混在させない
- 複数のターゲットを意図的に設定している場合を除き、プロジェクトファイル内の正式なターゲットフレームワークは一つにする

## プレビュー機能に関するルール

ユーザーがプレビュー版の採用を明示的に求めている場合、またはリポジトリですでにプレビュー版 SDK を使用している場合を除き、プレビュー版専用の API やドキュメントの指針を導入しないでください。
