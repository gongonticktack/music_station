# スタックの選択

主なドキュメント:
- https://learn.microsoft.com/aspnet/core/
- https://learn.microsoft.com/aspnet/core/blazor/
- https://learn.microsoft.com/aspnet/core/razor-pages/
- https://learn.microsoft.com/aspnet/core/mvc/overview
- https://learn.microsoft.com/aspnet/core/web-api/
- https://learn.microsoft.com/aspnet/core/fundamentals/minimal-apis

## 既定のバージョン選択

- 新しい本番環境向けの開発には、最新の安定版 .NET と ASP.NET Core を優先する。
- 2026 年 3 月時点では、リポジトリやユーザーの依頼に別段の指定がない限り、`net10.0` を意味する。
- ASP.NET Core 11 はプレビュー版として扱う。プレビュー版の API を既定で採用しない。
- リポジトリがすでに `net8.0`、`net9.0`、または別のフレームワークを対象としている場合は、タスクが明示的なアップグレードでない限り、そのターゲットを維持する。

## テンプレートの短縮名

現在の .NET 10 SDK のテンプレートには、次が含まれる:

- `dotnet new blazor`
- `dotnet new webapp`
- `dotnet new mvc`
- `dotnet new webapi`
- `dotnet new webapiaot`
- `dotnet new grpc`
- `dotnet new web`
- `dotnet new razorclasslib`

環境が異なる場合は、`dotnet new list` でテンプレート名を確認する。

## アプリケーションモデルの比較表

| モデル | 適した用途 | 注意点 | 一般的な出発点 |
| --- | --- | --- | --- |
| Blazor Web App | SSR と必要に応じた対話機能を組み合わせた、フルスタックの .NET UI を構築する | 対話型サーバーレンダリングには常時接続が必要。WebAssembly を使うと転送量が増える | `dotnet new blazor` |
| Razor Pages | ページ中心の CRUD、フォーム、ダッシュボード、業務アプリを構築する | ページハンドラーごとに認可を適用できない。ハンドラー単位の制御が重要なら MVC を使う | `dotnet new webapp` |
| MVC | コントローラーとビューの明確な分離、フィルター、アクションベースのパターンを備えた大規模なサーバーレンダリングアプリを構築する | 単純なページ遷移には Razor Pages より記述や設定が多い | `dotnet new mvc` |
| Minimal APIs | 用途を絞った HTTP API、内部サービス、軽量なバックエンド、小規模な API 群を構築する | 構造を設けずにビジネスロジックやメタデータが増えると、ルートハンドラーの管理が難しくなる | `dotnet new webapi` または `dotnet new web` |
| コントローラーベースの Web API | `[ApiController]`、コンテンツネゴシエーション、フィルター、フォーマッター、成熟したコントローラーの規約が有用な API を構築する | 小規模なエンドポイントには Minimal APIs より記述や設定が多い | `dotnet new webapi` |
| SignalR | サーバーからのプッシュ配信、リアルタイム更新、チャット、共同作業用 UI、通知を追加する | 接続のライフサイクル管理とスケールアウトの計画が必要 | 既存の ASP.NET Core アプリに追加する |
| gRPC | HTTP/2 上でサービス間 RPC やストリーミング RPC を構築する | ブラウザーのサポートは通常の JSON API とは異なる。gRPC-Web は必要な場合にのみ使う | `dotnet new grpc` |

## すばやく判断するための目安

- UI 自体を .NET コンポーネントモデルで構築したい場合は、Blazor Web App を選ぶ。
- アプリの中心がページとフォームの場合は、Razor Pages を選ぶ。
- アクション、ビュー、フィルター、コントローラーの規約が設計の中心になる場合は、MVC を選ぶ。
- 小規模から中規模の HTTP サービスには、まず Minimal APIs を選ぶ。
- API に、属性による高度な動作制御、カスタムフォーマッター、または既存の MVC/Web API の規約との強い整合性が必要な場合は、コントローラーに切り替える。
- 既存のコードベースでは、現在のアプリケーションモデルとの不整合が実際に複雑さを生んでいない限り、そのモデルを維持する。

## 複数モデルを組み合わせる際の指針

ASP.NET Core では、1 つのホストで複数のモデルを組み合わせられる。一般的な組み合わせは次のとおり:

- サーバーレンダリング UI に Razor Pages または MVC を使い、AJAX やモバイル向けエンドポイントに Minimal APIs を使う
- Blazor Web App に、外部連携用エンドポイントとして Minimal APIs を組み合わせる
- MVC または Razor Pages に、リアルタイム更新用の SignalR を組み合わせる
- Web API に、内部のサービス間呼び出し用の gRPC を組み合わせる

モデルを組み合わせるのは、公開するインターフェースが簡潔になる場合だけにする。ASP.NET Core で可能だからという理由だけで、2 つ目のアプリケーションモデルを追加しない。