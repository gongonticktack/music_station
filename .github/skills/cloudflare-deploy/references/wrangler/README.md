# Cloudflare Wrangler

Cloudflare Workersの公式CLI。コマンドラインからWorkersを開発、管理、デプロイできます。

## Wranglerとは？

WranglerはCloudflare Developer PlatformのCLIで、次の操作ができます。
- Workersの作成、開発、デプロイ
- バインディング（KV、D1、R2、Durable Objectsなど）の管理
- ルーティングと環境の設定
- ローカル開発サーバーの起動
- マイグレーションの実行とリソースの管理
- 統合テストの実施

## インストール

```bash
npm install wrangler --save-dev
# or globally
npm install -g wrangler
```

コマンドの実行: `npx wrangler <command>`（または`pnpm`/`yarn wrangler`）

## 読む順序

| 次の操作を行う場合... | こちらを参照 |
|----------------------|------------|
| Workerをすばやく作成／デプロイする | 以下の「基本コマンド」→ [patterns.md](./patterns.md) §新しいWorker |
| バインディング（KV、D1、R2）を設定する | [configuration.md](./configuration.md) §バインディング |
| 統合テストを書く | [api.md](./api.md) §startWorker |
| 本番環境の問題をデバッグする | [gotchas.md](./gotchas.md) + 「基本コマンド」§モニタリング |
| 複数環境のワークフローを設定する | [configuration.md](./configuration.md) §環境 |

## 基本コマンド

### プロジェクトと開発
```bash
wrangler init [name]              # Create new project
wrangler dev                      # Local dev server (fast, simulated)
wrangler dev --remote             # Dev with remote resources (production-like)
wrangler deploy                   # Deploy to production
wrangler deploy --env staging     # Deploy to environment
wrangler versions list            # List versions
wrangler rollback [id]            # Rollback deployment
wrangler login                    # OAuth login
wrangler whoami                   # Check auth status
```

## リソース管理

### KV
```bash
wrangler kv namespace create NAME
wrangler kv key put "key" "value" --namespace-id=<id>
wrangler kv key get "key" --namespace-id=<id>
```

### D1
```bash
wrangler d1 create NAME
wrangler d1 execute NAME --command "SQL"
wrangler d1 migrations create NAME "description"
wrangler d1 migrations apply NAME
```

### R2
```bash
wrangler r2 bucket create NAME
wrangler r2 object put BUCKET/key --file path
wrangler r2 object get BUCKET/key
```

### その他のリソース
```bash
wrangler queues create NAME
wrangler vectorize create NAME --dimensions N --metric cosine
wrangler hyperdrive create NAME --connection-string "..."
wrangler workflows create NAME
wrangler constellation create NAME
wrangler pages project create NAME
wrangler pages deployment create --project NAME --branch main
```

### シークレット
```bash
wrangler secret put NAME          # Set Worker secret
wrangler secret list              # List Worker secrets
wrangler secret delete NAME       # Delete Worker secret
wrangler secret bulk FILE.json    # Bulk upload from JSON

# Secrets Store (centralized, reusable across Workers)
wrangler secret-store:secret put STORE_NAME SECRET_NAME
wrangler secret-store:secret list STORE_NAME
```

### モニタリング
```bash
wrangler tail                     # Real-time logs
wrangler tail --env production    # Tail specific env
wrangler tail --status error      # Filter by status
```

## このリファレンスの内容

- [auth.md](./auth.md) - 認証の設定（`wrangler login`、APIトークン）
- [configuration.md](./configuration.md) - wrangler.jsoncの設定、環境、バインディング
- [api.md](./api.md) - プログラムから利用するAPI（`startWorker`、`getPlatformProxy`、イベント）
- [patterns.md](./patterns.md) - よく使われるワークフローと開発パターン
- [gotchas.md](./gotchas.md) - よくある落とし穴、制限事項、トラブルシューティング

## クイック判断フロー

```
Need to test your Worker?
├─ Testing full Worker with bindings → api.md §startWorker
├─ Testing individual functions → api.md §getPlatformProxy
└─ Testing with Vitest → patterns.md §Testing with Vitest

Need to configure something?
├─ Bindings (KV, D1, R2, etc.) → configuration.md §Bindings
├─ Multiple environments → configuration.md §Environments
├─ Static files → configuration.md §Workers Assets
└─ Routing → configuration.md §Routing

Development not working?
├─ Local differs from production → Use `wrangler dev --remote`
├─ Bindings not available → gotchas.md §Binding Not Available
└─ Auth issues → auth.md

Authentication issues?
├─ "Not logged in" / "Unauthorized" → auth.md
├─ First time deploying → `wrangler login` (one-time OAuth)
└─ CI/CD setup → auth.md §API Token
```

## 関連項目

- [workers](../workers/) - WorkersランタイムAPIリファレンス
- [miniflare](../miniflare/) - Miniflareを使ったローカルテスト
- [workerd](../workerd/) - `wrangler dev`を支えるランタイム