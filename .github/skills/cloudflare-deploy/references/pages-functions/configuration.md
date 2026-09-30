# 設定

## TypeScript の設定

**wrangler.jsonc から型を生成する**（非推奨の `@cloudflare/workers-types` を置き換えます）:

```bash
npx wrangler types
```

バインディングに基づく型付きの `Env` インターフェースを含む `worker-configuration.d.ts` が作成されます。

```typescript
// functions/api.ts
export const onRequest: PagesFunction<Env> = async (ctx) => {
  // ctx.env.KV, ctx.env.DB, etc. are fully typed
  return Response.json({ ok: true });
};
```

**手動で型を定義する場合**（`wrangler types` を使用しない場合）:

```typescript
interface Env {
  KV: KVNamespace;
  DB: D1Database;
  API_KEY: string;
}
export const onRequest: PagesFunction<Env> = async (ctx) => { /* ... */ };
```

## wrangler.jsonc

```jsonc
{
  "$schema": "./node_modules/wrangler/config-schema.json",
  "name": "my-pages-app",
  "pages_build_output_dir": "./dist",
  "compatibility_date": "2025-01-01",
  "compatibility_flags": ["nodejs_compat"],
  
  "vars": { "API_URL": "https://api.example.com" },
  "kv_namespaces": [{ "binding": "KV", "id": "abc123" }],
  "d1_databases": [{ "binding": "DB", "database_name": "prod-db", "database_id": "xyz789" }],
  "r2_buckets": [{ "binding": "BUCKET", "bucket_name": "my-bucket" }],
  "durable_objects": { "bindings": [{ "name": "COUNTER", "class_name": "Counter", "script_name": "counter-worker" }] },
  "services": [{ "binding": "AUTH", "service": "auth-worker" }],
  "ai": { "binding": "AI" },
  "vectorize": [{ "binding": "VECTORIZE", "index_name": "my-index" }],
  "analytics_engine_datasets": [{ "binding": "ANALYTICS" }]
}
```

## 環境ごとのオーバーライド

トップレベル → ローカル開発、`env.preview` → プレビュー、`env.production` → 本番環境

```jsonc
{
  "vars": { "API_URL": "http://localhost:8787" },
  "env": {
    "production": { "vars": { "API_URL": "https://api.example.com" } }
  }
}
```

**注意:** `vars`、`kv_namespaces`、`d1_databases` などをオーバーライドする場合は、すべて再定義する必要があります（継承されません）。

## ローカルシークレット（.dev.vars）

**ローカル開発専用** - デプロイされません:

```bash
# .dev.vars (add to .gitignore)
SECRET_KEY="my-secret-value"
```

`ctx.env.SECRET_KEY` 経由でアクセスします。本番環境のシークレットを設定するには:
```bash
echo "value" | npx wrangler pages secret put SECRET_KEY --project-name=my-app
```

## 静的設定ファイル

**_routes.json** - カスタムルーティング:
```json
{ "version": 1, "include": ["/api/*"], "exclude": ["/static/*"] }
```

**_headers** - 静的ヘッダー:
```
/static/*
  Cache-Control: public, max-age=31536000
```

**_redirects** - リダイレクト:
```
/old  /new  301
```

## ローカル開発とデプロイ

```bash
# Dev server
npx wrangler pages dev ./dist

# With bindings
npx wrangler pages dev ./dist --kv=KV --d1=DB=db-id --r2=BUCKET

# Durable Objects (2 terminals)
cd do-worker && npx wrangler dev
cd pages-project && npx wrangler pages dev ./dist --do COUNTER=Counter@do-worker

# Deploy
npx wrangler pages deploy ./dist
npx wrangler pages deploy ./dist --branch preview

# Download config
npx wrangler pages download config my-project
```

**関連項目:** バインディングの使用例については [api.md](./api.md) を参照してください。