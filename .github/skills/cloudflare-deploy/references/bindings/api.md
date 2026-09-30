# バインディング API リファレンス

## TypeScript の型

Cloudflare は `npx wrangler types` を使ってバインディングの型を生成します。これにより、Env インターフェースを含む `.wrangler/types/runtime.d.ts` が作成されます。

### 生成される Env インターフェース

`wrangler types` を実行すると、TypeScript がバインディングを認識します。

```typescript
interface Env {
  // From wrangler.jsonc bindings
  MY_KV: KVNamespace;
  MY_BUCKET: R2Bucket;
  DB: D1Database;
  MY_SERVICE: Fetcher;
  AI: Ai;
  
  // From vars
  API_URL: string;
  
  // From secrets (set via wrangler secret put)
  API_KEY: string;
}
```

### バインディングの型

| 設定 | TypeScript の型 | パッケージ |
|--------|-----------------|---------|
| `kv_namespaces` | `KVNamespace` | `@cloudflare/workers-types` |
| `r2_buckets` | `R2Bucket` | `@cloudflare/workers-types` |
| `d1_databases` | `D1Database` | `@cloudflare/workers-types` |
| `durable_objects.bindings` | `DurableObjectNamespace` | `@cloudflare/workers-types` |
| `vectorize` | `VectorizeIndex` | `@cloudflare/workers-types` |
| `queues.producers` | `Queue` | `@cloudflare/workers-types` |
| `services` | `Fetcher` | `@cloudflare/workers-types` |
| `ai` | `Ai` | `@cloudflare/workers-types` |
| `browser` | `Fetcher` | `@cloudflare/workers-types` |
| `analytics_engine_datasets` | `AnalyticsEngineDataset` | `@cloudflare/workers-types` |
| `hyperdrive` | `Hyperdrive` | `@cloudflare/workers-types` |
| `rate_limiting` | `RateLimit` | `@cloudflare/workers-types` |
| `workflows` | `Workflow` | `@cloudflare/workers-types` |
| `mtls_certificates` / `vars` / `text_blobs` / `data_blobs` | `string` | 組み込み |
| `wasm_modules` | `WebAssembly.Module` | 組み込み |

## バインディングへのアクセス

### 方法 1: fetch() ハンドラー（推奨）

```typescript
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const value = await env.MY_KV.get('key');
    return new Response(value);
  }
}
```

**理由:** 型安全で、Workers API に沿っており、waitUntil/passThroughOnException 用の ctx をサポートします。

### 方法 2: Hono フレームワーク

```typescript
import { Hono } from 'hono';

const app = new Hono<{ Bindings: Env }>();

app.get('/', async (c) => {
  const value = await c.env.MY_KV.get('key');
  return c.json({ value });
});

export default app;
```

**理由:** c.env に型が自動的に付与され、ルーティング中心のアプリに使いやすい方法です。

### 方法 3: Module Workers（レガシー）

```typescript
export async function handleRequest(request: Request, env: Env): Promise<Response> {
  const value = await env.MY_KV.get('key');
  return new Response(value);
}

addEventListener('fetch', (event) => {
  // env not directly available - requires workarounds
});
```

**避けてください:** 代わりに fetch() ハンドラーを使ってください（方法 1）。

## 型生成のワークフロー

### 初期設定

```bash
# Install wrangler
npm install -D wrangler

# Generate types from wrangler.jsonc
npx wrangler types
```

### バインディングを変更した後

```bash
# Added/modified binding in wrangler.jsonc
npx wrangler types

# TypeScript now sees updated Env interface
```

**注:** `wrangler types` の出力先は `.wrangler/types/runtime.d.ts` です。`@cloudflare/workers-types` が `tsconfig.json` の `"types"` 配列に含まれていれば、TypeScript はこのファイルを自動的に読み込みます。

## 主なバインディングのメソッド

**KV:**
```typescript
await env.MY_KV.get(key, { type: 'json' });  // text|json|arrayBuffer|stream
await env.MY_KV.put(key, value, { expirationTtl: 3600 });
await env.MY_KV.delete(key);
await env.MY_KV.list({ prefix: 'user:' });
```

**R2:**
```typescript
await env.BUCKET.get(key);
await env.BUCKET.put(key, value);
await env.BUCKET.delete(key);
await env.BUCKET.list({ prefix: 'images/' });
```

**D1:**
```typescript
await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first();
await env.DB.batch([stmt1, stmt2]);
```

**サービス:**
```typescript
await env.MY_SERVICE.fetch(new Request('https://fake/path'));
```

**Workers AI:**
```typescript
await env.AI.run('@cf/meta/llama-3.1-8b-instruct', { prompt: 'Hello' });
```

**キュー:**
```typescript
await env.MY_QUEUE.send({ userId: 123, action: 'process' });
```

**Durable Objects:**
```typescript
const id = env.MY_DO.idFromName('user-123');
const stub = env.MY_DO.get(id);
await stub.fetch(new Request('https://fake/increment'));
```

## 実行時の型とビルド時の型

| 型のソース | 生成時期 | 用途 |
|-------------|----------------|----------|
| `@cloudflare/workers-types` | npm install 時 | Workers の基本 API（Request、Response など） |
| `wrangler types` | 設定変更後 | 固有のバインディング（Env インターフェース） |

**両方をインストール:**
```bash
npm install -D @cloudflare/workers-types
npx wrangler types
```

## 型安全性のベストプラクティス

1. **env に `any` を使わない:**
```typescript
// ❌ BAD
async fetch(request: Request, env: any) { }

// ✅ GOOD
async fetch(request: Request, env: Env) { }
```

2. **設定を変更したら wrangler types を実行する:**
```bash
# After editing wrangler.jsonc
npx wrangler types
```

3. **生成された型が設定と一致しているか確認する:**
```bash
# View generated Env interface
cat .wrangler/types/runtime.d.ts
```

## 関連項目

- [Workers Types Package](https://www.npmjs.com/package/@cloudflare/workers-types)
- [Wrangler Types Command](https://developers.cloudflare.com/workers/wrangler/commands/#types)