# Wrangler の設定

wrangler.jsonc（推奨）の設定リファレンス。

## 設定形式

**wrangler.jsonc を推奨**（v3.91.0 以降）- スキーマ検証を利用できます。

```jsonc
{
  "$schema": "./node_modules/wrangler/config-schema.json",
  "name": "my-worker",
  "main": "src/index.ts",
  "compatibility_date": "2025-01-01",  // Use current date
  "vars": { "API_KEY": "dev-key" },
  "kv_namespaces": [{ "binding": "MY_KV", "id": "abc123" }]
}
```

## フィールドの継承

継承可能: `name`, `main`, `compatibility_date`, `routes`, `triggers`
継承不可（環境ごとに定義）: `vars`, バインディング（KV、D1、R2 など）

## 環境

```jsonc
{
  "name": "my-worker",
  "vars": { "ENV": "dev" },
  "env": {
    "production": {
      "name": "my-worker-prod",
      "vars": { "ENV": "prod" },
      "route": { "pattern": "example.com/*", "zone_name": "example.com" }
    }
  }
}
```

デプロイ: `wrangler deploy --env production`

## ルーティング

```jsonc
// Custom domain (recommended)
{ "routes": [{ "pattern": "api.example.com", "custom_domain": true }] }

// Zone-based
{ "routes": [{ "pattern": "api.example.com/*", "zone_name": "example.com" }] }

// workers.dev
{ "workers_dev": true }
```

## バインディング

```jsonc
// Variables
{ "vars": { "API_URL": "https://api.example.com" } }

// KV
{ "kv_namespaces": [{ "binding": "CACHE", "id": "abc123" }] }

// D1
{ "d1_databases": [{ "binding": "DB", "database_id": "abc-123" }] }

// R2
{ "r2_buckets": [{ "binding": "ASSETS", "bucket_name": "my-assets" }] }

// Durable Objects
{ "durable_objects": { 
  "bindings": [{ 
    "name": "COUNTER", 
    "class_name": "Counter",
    "script_name": "my-worker"  // Required for external DOs
  }] 
} }
{ "migrations": [{ "tag": "v1", "new_sqlite_classes": ["Counter"] }] }

// Service Bindings
{ "services": [{ "binding": "AUTH", "service": "auth-worker" }] }

// Queues
{ "queues": {
  "producers": [{ "binding": "TASKS", "queue": "task-queue" }],
  "consumers": [{ "queue": "task-queue", "max_batch_size": 10 }]
} }

// Vectorize
{ "vectorize": [{ "binding": "VECTORS", "index_name": "embeddings" }] }

// Hyperdrive (requires nodejs_compat_v2 for pg/postgres)
{ "hyperdrive": [{ "binding": "HYPERDRIVE", "id": "hyper-id" }] }
{ "compatibility_flags": ["nodejs_compat_v2"] }  // For pg/postgres

// Workers AI
{ "ai": { "binding": "AI" } }

// Workflows
{ "workflows": [{ "binding": "WORKFLOW", "name": "my-workflow", "class_name": "MyWorkflow" }] }

// Secrets Store (centralized secrets)
{ "secrets_store": [{ "binding": "SECRETS", "id": "store-id" }] }

// Constellation (AI inference)
{ "constellation": [{ "binding": "MODEL", "project_id": "proj-id" }] }
```

## Workers Assets（静的ファイル）

静的ファイルの配信にはこちらを推奨します（旧 `site` 設定を置き換えます）。

```jsonc
{
  "assets": {
    "directory": "./public",
    "binding": "ASSETS",
    "html_handling": "auto-trailing-slash",  // or "none", "force-trailing-slash"
    "not_found_handling": "single-page-application"  // or "404-page", "none"
  }
}
```

Worker 内でのアクセス:
```typescript
export default {
  async fetch(request, env) {
    // Try serving static asset first
    const asset = await env.ASSETS.fetch(request);
    if (asset.status !== 404) return asset;
    
    // Custom logic for non-assets
    return new Response("API response");
  }
}
```

## Placement

Workers を実行する地理的な場所を制御します。

```jsonc
{
  "placement": {
    "mode": "smart"  // or "off"
  }
}
```

- `"smart"`: Worker をデータソース（D1、Durable Objects）の近くで実行し、レイテンシを低減します
- `"off"`: デフォルトの分散設定（あらゆる場所で実行）

## 自動プロビジョニング（ベータ）

リソース ID を省略すると、Wrangler がリソースを作成し、デプロイ時に設定へ書き戻します。

```jsonc
{ "kv_namespaces": [{ "binding": "MY_KV" }] }  // No id - auto-provisioned
```

デプロイ後、ID が設定に自動で追加されます。

## 詳細設定

```jsonc
// Cron Triggers
{ "triggers": { "crons": ["0 0 * * *"] } }

// Observability (tracing)
{ "observability": { "enabled": true, "head_sampling_rate": 0.1 } }

// Runtime Limits
{ "limits": { "cpu_ms": 100 } }

// Browser Rendering
{ "browser": { "binding": "BROWSER" } }

// mTLS Certificates
{ "mtls_certificates": [{ "binding": "CERT", "certificate_id": "cert-uuid" }] }

// Logpush (stream logs to R2/S3)
{ "logpush": true }

// Tail Consumers (process logs with another Worker)
{ "tail_consumers": [{ "service": "log-worker" }] }

// Unsafe bindings (access to arbitrary bindings)
{ "unsafe": { "bindings": [{ "name": "MY_BINDING", "type": "plain_text", "text": "value" }] } }
```

## 関連項目

- [README.md](./README.md) - 概要とコマンド
- [api.md](./api.md) - プログラム API
- [patterns.md](./patterns.md) - ワークフロー
- [gotchas.md](./gotchas.md) - よくある問題
