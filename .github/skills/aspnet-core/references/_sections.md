# 参照資料のセクション

このファイルを、スキルのほかの資料を参照するための案内表として使用してください。

## 最初に読む資料

- 新規アプリまたは大規模な再設計: `stack-selection.md` -> `program-and-pipeline.md` -> 主要なアプリモデルの参照資料を 1 つ -> `security-and-identity.md` -> `testing-performance-and-operations.md`
- 既存アプリへの機能追加: 主要なアプリモデルの参照資料 -> `program-and-pipeline.md` -> 必要な横断的な参照資料
- API を中心とした作業: `apis-minimal-and-controllers.md` -> `security-and-identity.md` -> `data-state-and-services.md` -> `testing-performance-and-operations.md`
- 認証、認可、シークレット: `security-and-identity.md`
- リアルタイム通信、ストリーミング、バックグラウンド処理: `realtime-grpc-and-background-work.md`
- アップグレードまたは移行: `versioning-and-upgrades.md`

## 主要な参照資料

| ファイル | 開く場面 |
| --- | --- |
| `stack-selection.md` | Blazor、Razor Pages、MVC、Minimal APIs、コントローラー、SignalR、gRPC のいずれかを選ぶとき |
| `program-and-pipeline.md` | `Program.cs`、サービス、構成、ミドルウェア、ルーティング、ログ、静的ファイル、アプリの起動を設計するとき |
| `ui-blazor.md` | Blazor Web Apps やコンポーネントベースの UI を構築またはレビューするとき |
| `ui-razor-pages.md` | ページ中心のサーバーレンダリングアプリケーションを構築またはレビューするとき |
| `ui-mvc.md` | コントローラーとビューを使うアプリケーションを構築またはレビューするとき |
| `apis-minimal-and-controllers.md` | HTTP API を構築またはレビューするとき |

## 横断的な参照資料

| ファイル | 開く場面 |
| --- | --- |
| `data-state-and-services.md` | サービスの登録、EF Core の使用、オプションや構成の処理、アプリの状態管理を行うとき |
| `security-and-identity.md` | Identity、Cookie、ベアラー認証、ポリシー、CORS、CSRF、HTTPS、シークレットの取り扱いを追加するとき |
| `realtime-grpc-and-background-work.md` | SignalR、gRPC、ストリーミング、ホステッドサービスを追加するとき |
| `testing-performance-and-operations.md` | テスト、キャッシュ、圧縮、ヘルスチェック、レート制限、デプロイ、プロキシの構成を追加するとき |
| `versioning-and-upgrades.md` | ASP.NET Core のバージョン間で移行するとき、廃止された API を避けるとき、プレビュー機能を意図的に対象とするとき |
| `source-map.md` | 作業に対応する ASP.NET Core の公式ドキュメントを探すとき |

## 読み進め方

- コードベースで複数のモデルが実際に混在している場合を除き、アプリモデルの参照資料は一度に 1 つずつ開いてください。
- まずフレームワークに組み込まれた抽象化を優先してください。
- リポジトリが対象とするフレームワークに存在しない可能性のある API を導入する前に、`versioning-and-upgrades.md` を確認してください。
