# 直接作成（MCP）の詳細

MCP による直接作成の例と、作成後の設定については、このリファレンスを参照してください。

## 直接作成のワークフロー

### ステップ1: コードベースを分析する

ランタイム、ビルド／起動コマンド、環境変数、データストアを特定するには、[codebase-analysis.md](codebase-analysis.md) を使用してください。

### ステップ2: MCP 経由でリソースを作成する

**Web サービスを作成:**
```
create_web_service(
  name: "my-api",
  runtime: "node",  # or python, go, rust, ruby, elixir, docker
  repo: "https://github.com/username/repo",
  branch: "main",  # optional, defaults to repo default branch
  buildCommand: "npm ci",
  startCommand: "npm start",
  plan: "free",  # free, starter, standard, pro, pro_max, pro_plus, pro_ultra
  region: "oregon",  # oregon, frankfurt, singapore, ohio, virginia
  envVars: [
    {"key": "NODE_ENV", "value": "production"}
  ]
)
```

**静的サイトを作成:**
```
create_static_site(
  name: "my-frontend",
  repo: "https://github.com/username/repo",
  branch: "main",
  buildCommand: "npm run build",
  publishPath: "dist",  # or build, public, out
  envVars: [
    {"key": "VITE_API_URL", "value": "https://api.example.com"}
  ]
)
```

**Cron ジョブを作成:**
```
create_cron_job(
  name: "daily-cleanup",
  runtime: "node",
  repo: "https://github.com/username/repo",
  schedule: "0 0 * * *",  # Daily at midnight (cron syntax)
  buildCommand: "npm ci",
  startCommand: "node scripts/cleanup.js",
  plan: "free"
)
```

**PostgreSQL データベースを作成:**
```
create_postgres(
  name: "myapp-db",
  plan: "free",  # free, basic_256mb, basic_1gb, basic_4gb, pro_4gb, etc.
  region: "oregon"
)
```

**Key-Value ストア（Redis）を作成:**
```
create_key_value(
  name: "myapp-cache",
  plan: "free",  # free, starter, standard, pro, pro_plus
  region: "oregon",
  maxmemoryPolicy: "allkeys_lru"  # eviction policy
)
```

### ステップ3: 環境変数を設定する

サービスの作成後、環境変数を追加します:

```
update_environment_variables(
  serviceId: "<service-id-from-creation>",
  envVars: [
    {"key": "DATABASE_URL", "value": "<connection-string>"},
    {"key": "JWT_SECRET", "value": "<secret-value>"},
    {"key": "API_KEY", "value": "<api-key>"}
  ]
)
```

**注:** データベース接続文字列を取得するには、ダッシュボードのデータベース詳細、または `get_postgres(postgresId: "<id>")` を使用して内部 URL を確認してください。

### ステップ4: デプロイを確認する

`autoDeploy: "yes"`（デフォルト）が設定されたサービスは、作成時に自動的にデプロイされます。

**デプロイのステータスを確認:**
```
list_deploys(serviceId: "<service-id>", limit: 1)
```

**エラーがないかログを監視:**
```
list_logs(resource: ["<service-id>"], level: ["error"], limit: 50)
```

**ヘルスメトリクスを確認:**
```
get_metrics(
  resourceId: "<service-id>",
  metricTypes: ["http_request_count", "cpu_usage", "memory_usage"]
)
```
