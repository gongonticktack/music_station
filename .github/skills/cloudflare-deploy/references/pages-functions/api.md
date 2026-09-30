# Function API

## EventContext

```typescript
interface EventContext<Env = any> {
  request: Request;              // Incoming request
  functionPath: string;          // Request path
  waitUntil(promise: Promise<any>): void;  // Background tasks (non-blocking)
  passThroughOnException(): void;          // Fallback to static on error
  next(input?: Request | string, init?: RequestInit): Promise<Response>;
  env: Env;                      // Bindings, vars, secrets
  params: Record<string, string | string[]>;  // Route params ([user] or [[catchall]])
  data: any;                     // Middleware shared state
}
```

**TypeScript:** `wrangler types` の設定については [configuration.md](./configuration.md) を参照してください。

## ハンドラー

```typescript
// Generic (fallback for any method)
export async function onRequest(ctx: EventContext): Promise<Response> {
  return new Response('Any method');
}

// Method-specific (takes precedence over generic)
export async function onRequestGet(ctx: EventContext): Promise<Response> {
  return Response.json({ message: 'GET' });
}

export async function onRequestPost(ctx: EventContext): Promise<Response> {
  const body = await ctx.request.json();
  return Response.json({ received: body });
}
// Also: onRequestPut, onRequestPatch, onRequestDelete, onRequestHead, onRequestOptions
```

## バインディングのリファレンス

| バインディングの種類 | インターフェース | 設定キー | 用途 |
|--------------|-----------|----------|----------|
| KV | `KVNamespace` | `kv_namespaces` | キーバリューキャッシュ、セッション、設定 |
| D1 | `D1Database` | `d1_databases` | リレーショナルデータ、SQLクエリ |
| R2 | `R2Bucket` | `r2_buckets` | 大容量ファイル、ユーザーアップロード、アセット |
| Durable Objects | `DurableObjectNamespace` | `durable_objects.bindings` | ステートフルな連携、WebSocket |
| Workers AI | `Ai` | `ai.binding` | LLM推論、埋め込み |
| Vectorize | `VectorizeIndex` | `vectorize` | ベクトル検索、埋め込み |
| サービスバインディング | `Fetcher` | `services` | Worker間RPC |
| Analytics Engine | `AnalyticsEngineDataset` | `analytics_engine_datasets` | イベントログ、メトリクス |
| 環境変数 | `string` | `vars` | 機密情報ではない設定 |

wrangler.jsonc の例については [configuration.md](./configuration.md) を参照してください。

## バインディング

### KV

```typescript
interface Env { KV: KVNamespace; }
export const onRequest: PagesFunction<Env> = async (ctx) => {
  await ctx.env.KV.put('key', 'value', { expirationTtl: 3600 });
  const val = await ctx.env.KV.get('key', { type: 'json' });
  const keys = await ctx.env.KV.list({ prefix: 'user:' });
  return Response.json({ val });
};
```

### D1

```typescript
interface Env { DB: D1Database; }
export const onRequest: PagesFunction<Env> = async (ctx) => {
  const user = await ctx.env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(123).first();
  return Response.json(user);
};
```

### R2

```typescript
interface Env { BUCKET: R2Bucket; }
export const onRequest: PagesFunction<Env> = async (ctx) => {
  const obj = await ctx.env.BUCKET.get('file.txt');
  if (!obj) return new Response('Not found', { status: 404 });
  await ctx.env.BUCKET.put('file.txt', ctx.request.body);
  return new Response(obj.body);
};
```

### Durable Objects

```typescript
interface Env { COUNTER: DurableObjectNamespace; }
export const onRequest: PagesFunction<Env> = async (ctx) => {
  const stub = ctx.env.COUNTER.get(ctx.env.COUNTER.idFromName('global'));
  return stub.fetch(ctx.request);
};
```

### Workers AI

```typescript
interface Env { AI: Ai; }
export const onRequest: PagesFunction<Env> = async (ctx) => {
  const resp = await ctx.env.AI.run('@cf/meta/llama-3.1-8b-instruct', { prompt: 'Hello' });
  return Response.json(resp);
};
```

### サービスバインディングと環境変数

```typescript
interface Env { AUTH: Fetcher; API_KEY: string; }
export const onRequest: PagesFunction<Env> = async (ctx) => {
  // Service binding: forward to another Worker
  return ctx.env.AUTH.fetch(ctx.request);
  
  // Environment variable
  return Response.json({ key: ctx.env.API_KEY });
};
```

## 高度なモード（env.ASSETS）

`_worker.js` を使用する場合は、`env.ASSETS.fetch()` 経由で静的アセットにアクセスします。

```typescript
interface Env { ASSETS: Fetcher; KV: KVNamespace; }

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname.startsWith('/api/')) {
      return Response.json({ data: await env.KV.get('key') });
    }
    return env.ASSETS.fetch(request); // Fallback to static
  }
} satisfies ExportedHandler<Env>;
```

**関連項目:** TypeScript の設定については [configuration.md](./configuration.md)、ミドルウェアと認証のパターンについては [patterns.md](./patterns.md) を参照してください。