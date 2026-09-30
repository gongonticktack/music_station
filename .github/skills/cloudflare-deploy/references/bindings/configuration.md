# バインディング設定リファレンス

## ストレージバインディング

```jsonc
{
  "kv_namespaces": [{ "binding": "MY_KV", "id": "..." }],
  "r2_buckets": [{ "binding": "MY_BUCKET", "bucket_name": "my-bucket" }],
  "d1_databases": [{ "binding": "DB", "database_name": "my-db", "database_id": "..." }],
  "durable_objects": { "bindings": [{ "name": "MY_DO", "class_name": "MyDO" }] },
  "vectorize": [{ "binding": "VECTORIZE", "index_name": "my-index" }],
  "queues": { "producers": [{ "binding": "MY_QUEUE", "queue": "my-queue" }] }
}
```

**作成コマンド:**
```bash
npx wrangler kv namespace create MY_KV
npx wrangler r2 bucket create my-bucket
npx wrangler d1 create my-db
npx wrangler vectorize create my-index --dimensions=768 --metric=cosine
npx wrangler queues create my-queue

# List existing resources
npx wrangler kv namespace list
npx wrangler r2 bucket list
npx wrangler d1 list
npx wrangler vectorize list
npx wrangler queues list
```

## コンピュートバインディング

```jsonc
{
  "services": [{ 
    "binding": "MY_SERVICE", 
    "service": "other-worker",
    "environment": "production"  // Optional: target specific env
  }],
  "ai": { "binding": "AI" },
  "browser": { "binding": "BROWSER" },
  "workflows": [{ "binding": "MY_WORKFLOW", "name": "my-workflow" }]
}
```

**ワークフローの作成:**
```bash
npx wrangler workflows create my-workflow
```

## プラットフォームバインディング

```jsonc
{
  "analytics_engine_datasets": [{ "binding": "ANALYTICS" }],
  "mtls_certificates": [{ "binding": "MY_CERT", "certificate_id": "..." }],
  "hyperdrive": [{ "binding": "HYPERDRIVE", "id": "..." }],
  "unsafe": {
    "bindings": [{ "name": "RATE_LIMITER", "type": "ratelimit", "namespace_id": "..." }]
  }
}
```

## 設定バインディング

```jsonc
{
  "vars": {
    "API_URL": "https://api.example.com",
    "MAX_RETRIES": "3"
  },
  "text_blobs": { "MY_TEXT": "./data/template.html" },
  "data_blobs": { "MY_DATA": "./data/config.bin" },
  "wasm_modules": { "MY_WASM": "./build/module.wasm" }
}
```

**シークレット（設定ファイルには絶対に記載しない）:**
```bash
npx wrangler secret put API_KEY
```

## 環境別の設定

```jsonc
{
  "name": "my-worker",
  "vars": { "ENV": "production" },
  "kv_namespaces": [{ "binding": "CACHE", "id": "prod-kv-id" }],
  
  "env": {
    "staging": {
      "vars": { "ENV": "staging" },
      "kv_namespaces": [{ "binding": "CACHE", "id": "staging-kv-id" }]
    }
  }
}
```

**デプロイ:**
```bash
npx wrangler deploy              # Production
npx wrangler deploy --env staging
```

## ローカル開発

```jsonc
{
  "kv_namespaces": [{
    "binding": "MY_KV",
    "id": "prod-id",
    "preview_id": "dev-id"  // Used in wrangler dev
  }]
}
```

**またはリモートを使用:**
```bash
npx wrangler dev --remote  # Uses production bindings
```

## 完全な例

```jsonc
{
  "$schema": "./node_modules/wrangler/config-schema.json",
  "name": "my-app",
  "main": "src/index.ts",
  "compatibility_date": "2025-01-01",
  
  "vars": { "API_URL": "https://api.example.com" },
  "kv_namespaces": [{ "binding": "CACHE", "id": "abc123" }],
  "r2_buckets": [{ "binding": "ASSETS", "bucket_name": "my-assets" }],
  "d1_databases": [{ "binding": "DB", "database_name": "my-db", "database_id": "xyz789" }],
  "services": [{ "binding": "AUTH", "service": "auth-worker" }],
  "ai": { "binding": "AI" }
}
```

## バインディング固有の設定

### クラスをエクスポートする Durable Objects

```jsonc
{
  "durable_objects": {
    "bindings": [
      { "name": "COUNTER", "class_name": "Counter", "script_name": "my-worker" }
    ]
  }
}
```

```typescript
// In same Worker or script_name Worker
export class Counter {
  constructor(private state: DurableObjectState, private env: Env) {}
  async fetch(request: Request) { /* ... */ }
}
```

### キューコンシューマー

```jsonc
{
  "queues": {
    "producers": [{ "binding": "MY_QUEUE", "queue": "my-queue" }],
    "consumers": [{ "queue": "my-queue", "max_batch_size": 10 }]
  }
}
```

キューコンシューマーのハンドラー: `export default { async queue(batch, env) { /* process batch.messages */ } }`

## 要点

- **バインディング上限は64個**（全タイプの合計）
- **シークレット**: 必ず `wrangler secret put` を使い、絶対にコミットしない
- **型**: 設定変更後に `npx wrangler types` を実行する
- **環境**: ステージング／本番の切り替えには `env` フィールドを使う
- **開発**: `preview_id` または `--remote` フラグを使う
- **ID と名前**: バインディングによって `id`（KV、D1）を使うものと、`name`（R2、キュー）を使うものがある

## 関連項目

- [Wrangler Configuration](https://developers.cloudflare.com/workers/wrangler/configuration/)