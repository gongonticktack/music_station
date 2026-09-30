# デプロイの詳細

サービスの検出、設定パターン、すぐに使えるコマンド、よくある問題については、このリファレンスを参照してください。

## サービスの検出

**すべてのサービスを一覧表示:**
```
list_services()
```
ID、名前、種類、ステータスを含むすべてのサービスを返します。

**特定のサービスの詳細を取得:**
```
get_service(serviceId: "<id>")
```
環境変数やビルド／起動コマンドを含む完全な設定を返します。

**PostgreSQL データベースを一覧表示:**
```
list_postgres_instances()
```

**Key-Value ストアを一覧表示:**
```
list_key_value()
```

## 設定の詳細

### 環境変数

**すべての環境変数は render.yaml で宣言する必要があります。**

**環境変数の3つの設定パターン:**

1. **ハードコード値**（機密情報ではない設定）:
```yaml
envVars:
  - key: NODE_ENV
    value: production
  - key: API_URL
    value: https://api.example.com
```

2. **データベース接続**（自動生成）:
```yaml
envVars:
  - key: DATABASE_URL
    fromDatabase:
      name: postgres
      property: connectionString
  - key: REDIS_URL
    fromDatabase:
      name: redis
      property: connectionString
```

3. **シークレット**（ユーザーがダッシュボードで入力）:
```yaml
envVars:
  - key: JWT_SECRET
    sync: false
  - key: API_KEY
    sync: false
  - key: STRIPE_SECRET_KEY
    sync: false
```

環境変数の完全ガイド: [configuration-guide.md](configuration-guide.md)

### ポートのバインド

**重要:** Web サービスは `0.0.0.0:$PORT` にバインドする必要があります（`localhost` ではありません）。Render は `PORT` 環境変数を設定します。

**Node.js の例:**
```javascript
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});
```

**Python の例:**
```python
import os

port = int(os.environ.get('PORT', 5000))
app.run(host='0.0.0.0', port=port)
```

**Go の例:**
```go
port := os.Getenv("PORT")
if port == "" {
    port = "3000"
}
http.ListenAndServe(":"+port, handler)
```

### プランのデフォルト

**ユーザーから別の指定がない限り、`plan: free` を使用してください。** 現在の制限と容量については、Render の料金情報を参照してください。

### ビルドコマンド

**ビルドがハングしないよう、非対話型のフラグを使用してください:**
- npm: `npm ci`
- yarn: `yarn install --frozen-lockfile`
- pnpm: `pnpm install --frozen-lockfile`
- bun: `bun install --frozen-lockfile`
- pip: `pip install -r requirements.txt`
- uv: `uv sync`
- apt: `apt-get install -y <package>`
- bundler: `bundle install --jobs=4 --retry=3`

### データベース接続

同じ Render アカウント内のデータベースにサービスを接続するときは、内部 URL に `fromDatabase` 参照を使用してください。

### ヘルスチェック

任意ですが、デプロイの検出を速めるために `/health` エンドポイントを追加することを推奨します。

## クイックリファレンス

### MCP ツール（推奨）
```
# Service Discovery
list_services()
get_service(serviceId: "<id>")
list_postgres_instances()
list_key_value()

# Service Creation
create_web_service(name, runtime, buildCommand, startCommand, ...)
create_static_site(name, buildCommand, publishPath, ...)
create_cron_job(name, runtime, schedule, buildCommand, startCommand, ...)
create_postgres(name, plan, region)
create_key_value(name, plan, region)

# Environment Variables
update_environment_variables(serviceId, envVars: [{key, value}, ...])

# Deployment & Monitoring
list_deploys(serviceId, limit)
list_logs(resource: ["<id>"], level: ["error"])
get_metrics(resourceId, metricTypes: [...])

# Workspace
get_selected_workspace()
list_workspaces()
```

### CLI コマンド
```bash
# Validate Blueprint
render blueprints validate

# Check workspace
render workspace current -o json
render workspace set

# List services
render services -o json

# View deployment logs
render logs -r <service-id> -o json

# Create deployment
render deploys create <service-id> --wait
```

### フレームワーク別テンプレート
- Node.js Express: [../assets/node-express.yaml](../assets/node-express.yaml)
- Next.js + Postgres: [../assets/nextjs-postgres.yaml](../assets/nextjs-postgres.yaml)
- Django + Worker: [../assets/python-django.yaml](../assets/python-django.yaml)
- Static Site: [../assets/static-site.yaml](../assets/static-site.yaml)
- Go API: [../assets/go-api.yaml](../assets/go-api.yaml)
- Docker: [../assets/docker.yaml](../assets/docker.yaml)

### ドキュメント
- Blueprint の完全な仕様: [blueprint-spec.md](blueprint-spec.md)
- サービスの種類の説明: [service-types.md](service-types.md)
- ランタイムの選択肢: [runtimes.md](runtimes.md)
- 設定ガイド: [configuration-guide.md](configuration-guide.md)

## よくある問題

**問題:** ポートのバインドエラーでデプロイに失敗する

**解決策:** アプリが `0.0.0.0:$PORT` にバインドされていることを確認してください（上記の「ポートのバインド」セクションを参照）。

---

**問題:** ビルドがハングする、またはタイムアウトする

**解決策:** 非対話型のビルドコマンドを使用してください（上記の「ビルドコマンド」セクションを参照）。

---

**問題:** ダッシュボードに環境変数が表示されない

**解決策:** すべての環境変数は render.yaml で宣言する必要があります。シークレットには `sync: false` を指定して、不足している変数を追加してください。

---

**問題:** データベースへの接続に失敗する

**解決策:** 内部接続文字列には `fromDatabase` 参照を使用してください。

---

**問題:** 静的サイトのルートで404が表示される

**解決策:** SPA のルーティング用に render.yaml へリライトルールを追加してください:
```yaml
routes:
  - type: rewrite
    source: /*
    destination: /index.html
```

詳細なトラブルシューティングについては、デバッグスキルまたは [configuration-guide.md](configuration-guide.md) を参照してください。
