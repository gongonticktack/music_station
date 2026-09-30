# Apps SDK ドキュメントのワークフロー

このリファレンスを使って、コード生成を最新の OpenAI Apps SDK ドキュメントに沿ったものにしてください。

## 常に取得するページ（基本）

- `https://developers.openai.com/apps-sdk/build/mcp-server/`
- `https://developers.openai.com/apps-sdk/build/chatgpt-ui/`
- `https://developers.openai.com/apps-sdk/build/examples/`
- `https://developers.openai.com/apps-sdk/plan/tools/`
- `https://developers.openai.com/apps-sdk/reference/`

## 条件に応じて取得するページ（新規開発／初回実装）

- 最初の実装のひな型作成や、標準的な接続方法を確認する場合は `https://developers.openai.com/apps-sdk/quickstart/`
- タスクにトンネル経由の ChatGPT でのローカルテスト、ホスティング、本番環境へのデプロイ計画が含まれる場合は `https://developers.openai.com/apps-sdk/deploy/`
- タスクに一般公開、アプリ審査、公開手順が含まれる場合は `https://developers.openai.com/apps-sdk/deploy/submission/`
- タスクに提出準備、ポリシーや信頼性の確認、審査リスクの軽減が含まれる場合は `https://developers.openai.com/apps-sdk/app-submission-guidelines/`

## 推奨する `openai-docs` / MCP クエリ

取得前に、対象を絞って検索してください。

- `ChatGPT Apps SDK build MCP server register resource template resourceUri outputTemplate`
- `ChatGPT Apps SDK build ChatGPT UI MCP Apps bridge ui/notifications/tool-result`
- `ChatGPT Apps SDK examples React widget upload modal Pizzaz`
- `Apps SDK define tools annotations readOnlyHint destructiveHint openWorldHint`
- `Apps SDK reference tool descriptor _meta ui.resourceUri openai/outputTemplate`
- `ChatGPT Apps SDK quickstart build web component tools/call`
- `ChatGPT app company knowledge compatibility search fetch tools`
- `platform MCP search tool fetch tool schema`
- `ChatGPT Apps SDK deploy app local development tunnel ngrok refresh connector`
- `ChatGPT Apps SDK submit app review prerequisites app submission guidelines`

## ドキュメントに基づくチェックリスト（現行の指針）

### アプリの類型／構成

- 例やひな型を選ぶ前に、依頼を主となるアプリ類型に分類する
- プロンプトごとに新しい構成を考案するのではなく、その類型に合ったリポジトリ構成にする

### サーバー

- MCP Apps UI の MIME タイプ（`text/html;profile=mcp-app`）または `RESOURCE_MIME_TYPE` を使う場合は `@modelcontextprotocol/ext-apps/server` で、ウィジェットのリソース／テンプレートを登録する
- ウィジェットの HTML、JS、CSS に互換性を損なう変更を加えた場合は、テンプレート URI にバージョンを付ける（URI をキャッシュキーとして扱う）
- レンダリング用ツールに `_meta.ui.resourceUri` を設定し、必要に応じて ChatGPT との互換性のために `_meta["openai/outputTemplate"]` も設定する
- モデルが呼び出しを再試行する可能性があるため、ツールハンドラーは冪等になるよう設計する
- `structuredContent` は簡潔に保ち、ウィジェット専用のペイロードは `_meta` に移す

### ツール設計

- 1つのツールにつき、ユーザーの意図を1つにする
- アクションが明確な名前と、正確な説明を使う
- ツールの影響を示すヒント（`readOnlyHint`、`destructiveHint`、`openWorldHint`）を正確に設定する
- データ取得用ツールとレンダリング用ツールを分け、ウィジェット UI を表示するかどうかを選ぶ前に、モデルがデータを取得して確認できるようにする
- ウィジェットにファーストパーティのデータのみをレンダリングさせたい場合は、ウィジェットの入力を一意な識別子のリストにする（例：近隣物件を取得するツールが返す ID を受け取る物件マップのレンダリング用ウィジェットでは `propertyIds`）。モデルが生成したデータでウィジェットをレンダリングできるようにしたい場合は、ウィジェットの入力を意味的に関連のあるものにする（例：フラッシュカード用ウィジェットでは `questionAndAnswerPairs`）
- コネクター型、データ専用、同期指向、または社内ナレッジ型のアプリでは、既定で標準の `search` ツールと `fetch` ツールを優先する

### UI

- 新しいアプリでは MCP Apps ブリッジ（`ui/*` 通知と `tools/call`）を優先する
- 基本的な例でのフォローアップメッセージには `ui/message` を優先し、`window.openai.sendFollowUpMessage` は ChatGPT 固有の任意の互換機能として扱う
- `window.openai` は互換性と、任意の ChatGPT 拡張機能のためのものとして扱う
- `structuredContent` からレンダリングし、ホストから渡されるデータは信頼できない入力として扱う
- `ui/update-model-context` は、モデルが推論に使うべき UI 状態にのみ使用する

### 出発点の選定

- 新規開発のひな型を一から生成する前に、`apps-sdk/build/examples` と公式のサンプルリポジトリを確認する
- 要望された技術スタックと操作パターンに合う、上流の最小限のサンプルを優先する
- 上流のサンプルが要望に合わない、または適さない場合に限り、ローカルの代替ひな型を使う

### リソースのメタデータ／セキュリティ

- `_meta.ui.csp.connectDomains` と `_meta.ui.csp.resourceDomains` を正確に設定する
- iframe の埋め込みが体験の中心でない限り、`frameDomains` は避ける
- 提出可能なアプリでは `_meta.ui.domain` を設定する
- ウィジェットの用途をモデルに伝えるため、常に `openai/widgetDescription` を設定する

### 開発者モード／ローカルテスト

- MCP サーバーを `http://localhost:<port>/mcp` でローカル実行する
- 開発中に ChatGPT からアクセスできるよう、公開 HTTPS トンネルで公開する
- ChatGPT の設定でアプリを追加する際は、公開 URL に `/mcp` を付けたものを使う
- 実装を引き継ぐ際に、ChatGPT の開発者モードの設定とアプリ作成手順を記載する
- MCP ツールやメタデータを変更した後は、アプリを更新するようユーザーに伝える
- 必要に応じて用語の違いにも触れる。一部のドキュメントやスクリーンショットでは、製品 UI が「アプリ」と呼ぶものを「コネクター」と表記している場合がある

### 検証

- ファイルが作成されたかだけでなく、最低限動作するリポジトリの要件に照らして検証する
- まず、最も手軽で有用な構文チェックまたはコンパイルチェックを実行する
- 可能であれば、結果を「動作する」と呼ぶ前に、ローカルの `/mcp` ルートが応答することを確認する
- さらに詳しい検証を実行できない場合は、その旨を明記する
- アプリがコネクター型または同期指向の場合は、`search` ツールと `fetch` ツールの形式が標準に合っていることを確認する

### 本番環境のホスティング／デプロイ

- 信頼できる TLS と低遅延のストリーミング `/mcp` を備えた、安定した公開 HTTPS エンドポイントを優先する
- プラットフォーム固有のシークレット管理方法と環境変数を記載する
- 本番環境でツール呼び出しをデバッグするために必要なログとメトリクスを記載する
- 提出前に、ChatGPT の開発者モードでホスト済みのエンドポイントを再テストする

### 提出／審査

- `deploy/submission` と `app-submission-guidelines` の両方を確認する（手順とポリシー要件）
- 提出手順を作成する前に、組織の確認状況と Owner ロールの前提条件を確認する
- エンドポイントが公開された本番インフラ上にあり、localhost、トンネル、テスト用 URL ではないことを確認する
- 提出に向けて CSP が定義され、正確であることを確認する
- 提出物（メタデータ、スクリーンショット、プライバシーポリシー／サポート連絡先、テスト用プロンプトと応答）を準備する
- 認証が必要な場合は、審査で使用できるデモ用認証情報を準備し、社内ネットワークの外部で有効性を確認する

## 生成手順

1. アプリの類型を分類する。
2. `$openai-docs` でドキュメントを取得する。
3. ひな型を一から考案する前に、公式サンプルを確認する。
4. 関連する制約とメタデータキーを要約する。
5. ツールの構成案とアーキテクチャを提案する。
6. 最も近いサンプルを調整するか、ローカルの代替ひな型を使う。
7. サーバーのひな型を生成または修正する。
8. ウィジェットのひな型を生成または修正する。
9. 最低限動作するリポジトリの要件に照らして検証する。
10. ローカル実行、トンネル、ChatGPT 開発者モードでのアプリ設定手順を追加する。
11. タスクが本番公開を想定している場合は、ホスティング／デプロイのガイダンスを追加する。
12. ユーザーが一般公開を予定している場合は、提出／準備手順を追加する。
13. 互換性のための別名と MCP Apps 標準フィールドの違いを明記する。

## ひな型スクリプト

- ユーザーが新規の Node + `./scripts/scaffold_node_ext_apps.mjs <output-dir> --app-name <name>` のスターターを希望し、上流のサンプルにより適したものがない場合に限り、`@modelcontextprotocol/ext-apps` を使う。
- 現在の環境でファイルを実行できない場合は、`node scripts/scaffold_node_ext_apps.mjs <output-dir> --app-name <name>` を使う。
- このスクリプトは `package.json`、`tsconfig.json`、`public/widget.html`、`src/server.ts` を生成する。
- 既定では MCP Apps ブリッジを使用し、フォローアップメッセージには `ui/message` を使い、`window.openai` は任意のホストシグナル／拡張機能に限定する。
- 生成後は、出力を取得済みのドキュメントと照合し、ドキュメントに変更があれば、パッケージのバージョン、メタデータ、トランスポートの詳細、URI のバージョン管理を調整する。