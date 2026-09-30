# Figma MCP の設定資料

次の設定で、環境変数から取得したベアラートークンで認証するストリーミング HTTP サーバーとして、Figma MCP サーバーを `~/.codex/config.toml` に登録する。

```toml
[mcp_servers.figma]
url = "https://mcp.figma.com/mcp"
bearer_token_env_var = "FIGMA_OAUTH_TOKEN"
http_headers = { "X-Figma-Region" = "us-east-1" }
```

## 注意点と設定項目
- Codex を起動する環境で、ベアラートークンを `FIGMA_OAUTH_TOKEN` として利用できるようにする。
- リージョンのヘッダーを Figma のリージョンに合わせる。組織が別のリージョンを使う場合は `X-Figma-Region` を一貫して更新する。
- ストリーミング HTTP で OAuth を使うには RMCP クライアントが必要。`config.toml` のトップレベルで `[features].rmcp_client = true`（古いビルドでは `experimental_use_rmcp_client = true`）を設定する。
- 必要ならサーバーごとのタイムアウト `startup_timeout_sec`（既定値 10）と `tool_timeout_sec`（既定値 60）を `[mcp_servers.figma]` 内に設定できる。

## 環境変数の設定（未設定の場合）
- 現在のシェルだけに設定する: `export FIGMA_OAUTH_TOKEN="<token>"`
- 後のセッションにも残す: export の行をシェルのプロファイル（例: `~/.zshrc`、`~/.bashrc`）に追加し、シェルまたは IDE を再起動する。
- Codex 起動前に確認する: `echo $FIGMA_OAUTH_TOKEN` で空でないトークンが表示されるはず。

## 設定と検証のチェックリスト
- 上記の設定を `~/.codex/config.toml` の `[mcp_servers.figma]` に追加し、`[features].rmcp_client = true`（古いリリースでは `experimental_use_rmcp_client = true`）を有効にする。
- 設定や環境変数を更新したら Codex（CLI/IDE）を再起動する。
- Codex に Figma ツールの一覧を表示させるか、簡単な呼び出しを行い、サーバーに到達できることを確認する。

## トラブルシューティング
- トークンが読み込まれない: Codex を起動するシェルで `FIGMA_OAUTH_TOKEN` をエクスポートするか、シェルのプロファイルに追加して再起動する。
- OAuth エラー: `rmcp_client` が有効で、ベアラートークンが有効であることを確認する。Figma からコピーしたトークンには、前後の引用符を含めない。
- ネットワークやヘッダー: `X-Figma-Region` ヘッダーを残す。組織が別のリージョンを使う場合は、設定とリクエストの両方で一貫して更新する。

## 使用時の注意
- サーバーはリンクを使う。Figma のフレームやレイヤーのリンクをコピーし、その URL の実装を MCP クライアントに依頼する。クライアントはリンクからノード ID を抽出し、ページ自体は閲覧しない。
- 出力が一般的すぎる場合は、メインのスキルにあるプロジェクト固有の規則を改めて示し、必須の順序（get_design_context → 必要なら get_metadata → get_screenshot）に従う。
