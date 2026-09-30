# Workers の設定

## wrangler.jsonc（推奨）

```jsonc
{
  "$schema": "./node_modules/wrangler/config-schema.json",
  "name": "my-worker",
  "main": "src/index.ts",
  "compatibility_date": "2025-01-01", // Use current date for new projects
  
  // Bindings (non-inheritable)
  "vars": { "ENVIRONMENT": "production" },
  "kv_namespaces": [{ "binding": "MY_KV", "id": "abc123" }],
  "r2_buckets": [{ "binding": "MY_BUCKET", "bucket_name": "my-bucket" }],
  "d1_databases": [{ "binding": "DB", "database_name": "my-db", "database_id": "xyz789" }],
  
  // Environments
  "env": {
    "staging": {
      "vars": { "ENVIRONMENT": "staging" },
      "kv_namespaces": [{ "binding": "MY_KV", "id": "staging-id" }]
    }
  }
}
```

## 設定ルール

**継承可能**: `name`、`main`、`compatibility_date`、`routes`、`workers_dev`  
**継承不可**: すべてのバインディング（`vars`、`kv_namespaces`、`r2_buckets` など）  
**トップレベルのみ**: `migrations`、`keep_vars`、`send_metrics`

新しいプロジェクトでは、`compatibility_date` に必ず現在の日付を設定してください。

## バインディング

```jsonc
{
  // Environment variables - access via env.VAR_NAME
  "vars": { "ENVIRONMENT": "production" },
  
  // KV (key-value storage)
  "kv_namespaces": [{ "binding": "MY_KV", "id": "abc123" }],
  
  // R2 (object storage)
  "r2_buckets": [{ "binding": "MY_BUCKET", "bucket_name": "my-bucket" }],
  
  // D1 (SQL database)
  "d1_databases": [{ "binding": "DB", "database_name": "my-db", "database_id": "xyz789" }],
  
  // Durable Objects (stateful coordination)
  "durable_objects": {
    "bindings": [{ "name": "COUNTER", "class_name": "Counter" }]
  },
  
  // Queues (message queues)
  "queues": {
    "producers": [{ "binding": "MY_QUEUE", "queue": "my-queue" }],
    "consumers": [{ "queue": "my-queue", "max_batch_size": 10 }]
  },
  
  // Service bindings (worker-to-worker RPC)
  "services": [{ "binding": "SERVICE_B", "service": "service-b" }],
  
  // Analytics Engine
  "analytics_engine_datasets": [{ "binding": "ANALYTICS" }]
}
```

### シークレット

CLI で設定します（設定ファイルには絶対に記述しないでください）。

```bash
npx wrangler secret put API_KEY
```

アクセス方法: `env.API_KEY`

### 自動プロビジョニング（ベータ版）

ID を指定していないバインディングは自動的に作成されます。

```jsonc
{ "kv_namespaces": [{ "binding": "MY_KV" }] }  // ID added on deploy
```

## ルートとトリガー

```jsonc
{
  "routes": [
    { "pattern": "example.com/*", "zone_name": "example.com" }
  ],
  "triggers": {
    "crons": ["0 */6 * * *"]  // Every 6 hours
  }
}
```

## TypeScript の設定

### 型の自動生成（推奨）

```bash
npm install -D @cloudflare/workers-types
npx wrangler types  # Generates .wrangler/types/runtime.d.ts from wrangler.jsonc
```

`tsconfig.json`:

```jsonc
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022"],
    "types": ["@cloudflare/workers-types"]
  },
  "include": [".wrangler/types/**/*.ts", "src/**/*"]
}
```

生成された型をインポートします。

```typescript
import type { Env } from './.wrangler/types/runtime';

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    await env.MY_KV.get('key');  // Fully typed, autocomplete works
    return new Response('OK');
  },
};
```

wrangler.jsonc のバインディングを変更した後は、`npx wrangler types` を再実行してください。

### 手動での型定義（従来方式）

```typescript
interface Env {
  MY_KV: KVNamespace;
  DB: D1Database;
  API_KEY: string;
}
```

## 詳細オプション

```jsonc
{
  // Auto-locate compute near data sources
  "placement": { "mode": "smart" },
  
  // Enable Node.js built-ins (Buffer, process, path, etc.)
  "compatibility_flags": ["nodejs_compat_v2"],
  
  // Observability (10% sampling)
  "observability": { "enabled": true, "head_sampling_rate": 0.1 }
}
```

### Node.js 互換性

`nodejs_compat_v2` により、次の機能が有効になります。
- `Buffer`、`process.env`、`path`、`stream`
- Node モジュール用の CommonJS `require()`
- `node:` インポート（例: `import { Buffer } from 'node:buffer'`）

**注:** コールドスタートに約1～2ミリ秒のオーバーヘッドが加わります。可能な場合は Workers API（R2、KV）を使用してください。

## デプロイコマンド

```bash
npx wrangler deploy              # Production
npx wrangler deploy --env staging
npx wrangler deploy --dry-run    # Validate only
```

## 関連項目

- [API](./api.md) - ランタイム API とバインディングの使用方法
- [パターン](./patterns.md) - デプロイ戦略
- [Wrangler](../wrangler/README.md) - CLI リファレンス
