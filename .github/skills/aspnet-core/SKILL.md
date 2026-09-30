---
name: aspnet-core
description: 現行の .NET Web 開発に関する公式ガイダンスに沿って、ASP.NET Core Web アプリケーションを構築、レビュー、リファクタリング、設計します。Blazor Web Apps、Razor Pages、MVC、Minimal APIs、コントローラーベースの Web API、SignalR、gRPC、ミドルウェア、依存性の注入、構成、認証、認可、テスト、パフォーマンス、デプロイ、ASP.NET Core のアップグレードに取り組む際に使用します。
---

# ASP.NET Core

## 概要

適切な ASP.NET Core アプリケーションモデルを選び、ホストとリクエストパイプラインを正しく構成し、現在 Microsoft が文書化しているフレームワークの作法に沿って機能を実装します。

タスクに必要な最小限のリファレンスを読み込んでください。既定ですべてのリファレンスを読み込まないでください。

## ワークフロー

1. ターゲットフレームワーク、SDK、現在のアプリケーションモデルを確認する。
2. 新規アプリや大規模なリファクタリングでは、最初に [references/stack-selection.md](references/stack-selection.md) を開く。
3. `Program.cs`、DI、構成、ミドルウェア、ルーティング、ログ、静的アセットについては、次に [references/program-and-pipeline.md](references/program-and-pipeline.md) を開く。
4. 主要なアプリケーションモデルのリファレンスを、次の中から一つだけ開く。
   - [references/ui-blazor.md](references/ui-blazor.md)
   - [references/ui-razor-pages.md](references/ui-razor-pages.md)
   - [references/ui-mvc.md](references/ui-mvc.md)
   - [references/apis-minimal-and-controllers.md](references/apis-minimal-and-controllers.md)
5. 分野横断的なリファレンスは、必要な場合にのみ追加する。
   - [references/data-state-and-services.md](references/data-state-and-services.md)
   - [references/security-and-identity.md](references/security-and-identity.md)
   - [references/realtime-grpc-and-background-work.md](references/realtime-grpc-and-background-work.md)
   - [references/testing-performance-and-operations.md](references/testing-performance-and-operations.md)
6. 古いソリューションに新しいプラットフォーム API を導入する前、またはメジャーバージョン間で移行する際は、[references/versioning-and-upgrades.md](references/versioning-and-upgrades.md) を開く。
7. 対象を絞ったリファレンスに記載されていないタスクに対応する Microsoft Learn のセクションが必要な場合は、[references/source-map.md](references/source-map.md) を使用する。

## 既定の運用方針

- リポジトリまたはユーザーの依頼で古いバージョンが指定されていない限り、最新の安定版 ASP.NET Core と .NET を優先する。
- 2026 年 3 月時点では、新しい本番用の開発に .NET 10 / ASP.NET Core 10 を優先する。ユーザーがプレビュー機能を明示的に求めていない限り、ASP.NET Core 11 はプレビュー版として扱う。
- `WebApplicationBuilder` と `WebApplication` を優先する。コードベースですでに使用している場合や、タスクが移行である場合を除き、古い `Startup` と `WebHost` のパターンは避ける。
- サードパーティーの基盤を追加する前に、組み込みの DI、オプションと構成、ログ、ProblemDetails、OpenAPI、ヘルスチェック、レート制限、出力キャッシュ、Identity を優先する。
- ページ、コンポーネント、エンドポイント、コントローラー、検証、サービス、データアクセス、テストの対応関係を追いやすいように、機能単位のまとまりを保つ。
- 既存のアプリケーションモデルを尊重する。明確な理由なく Razor Pages を MVC に、またはコントローラーを Minimal APIs に書き換えない。

## リファレンスガイド

- [references/_sections.md](references/_sections.md): 簡易索引と読む順序。
- [references/stack-selection.md](references/stack-selection.md): 適切な ASP.NET Core アプリケーションモデルとテンプレートの選択。
- [references/program-and-pipeline.md](references/program-and-pipeline.md): `Program.cs`、サービス、ミドルウェア、ルーティング、構成、ログ、静的アセットの構成。
- [references/ui-blazor.md](references/ui-blazor.md): Blazor Web Apps の構築、レンダリングモードの選択、コンポーネント、フォーム、JS 相互運用の正しい使用。
- [references/ui-razor-pages.md](references/ui-razor-pages.md): ハンドラー、モデルバインディング、規約を使用した、ページ中心でサーバー側レンダリングを行うアプリの構築。
- [references/ui-mvc.md](references/ui-mvc.md): 関心事を明確に分離したコントローラーとビューによるアプリケーションの構築。
- [references/apis-minimal-and-controllers.md](references/apis-minimal-and-controllers.md): 検証とレスポンスのパターンを含む、Minimal APIs またはコントローラーを使用した HTTP API の構築。
- [references/data-state-and-services.md](references/data-state-and-services.md): EF Core、`DbContext`、オプション、`IHttpClientFactory`、セッション、一時データ、アプリケーションの状態の適切な使用。
- [references/security-and-identity.md](references/security-and-identity.md): 認証、認可、Identity、シークレット、データ保護、CORS、CSRF、HTTPS に関する指針の適用。
- [references/realtime-grpc-and-background-work.md](references/realtime-grpc-and-background-work.md): SignalR、gRPC、ホステッドサービスの使用。
- [references/testing-performance-and-operations.md](references/testing-performance-and-operations.md): 統合テスト、ブラウザーテスト、キャッシュ、圧縮、ヘルスチェック、レート制限、デプロイに関する考慮事項の追加。
- [references/versioning-and-upgrades.md](references/versioning-and-upgrades.md): ターゲットフレームワーク、破壊的変更、非推奨 API、移行への対応。
- [references/source-map.md](references/source-map.md): ASP.NET Core 公式ドキュメントの構成と、このスキル内のリファレンスとの対応付け。

## 実行時の注意事項

- 新しいコードを生成する際は、適切な `dotnet new` テンプレートから始め、生成された構成が分かるように保つ。
- 既存のソリューションを編集する際は、まずそのソリューションの規約に従い、フレームワークの誤用や古いパターンを避けるためにこれらのリファレンスを使用する。
- タスクに「最新」とある場合は、記憶に頼る前に Microsoft Learn または ASP.NET Core のドキュメントリポジトリでその機能を確認する。
