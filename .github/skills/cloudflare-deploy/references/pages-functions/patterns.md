# よく使うパターン

## バックグラウンドタスク（waitUntil）

レスポンス送信後に実行する非ブロッキングタスク（分析、クリーンアップ、Webhook）：

```typescript
export async function onRequest(ctx: EventContext<Env>) {
  const res = Response.json({ success: true });
  
  ctx.waitUntil(ctx.env.KV.put('last-visit', new Date().toISOString()));
  ctx.waitUntil(Promise.all([
    ctx.env.ANALYTICS.writeDataPoint({ event: 'view' }),
    fetch('https://webhook.site/...', { method: 'POST' })
  ]));
  
  return res; // Returned immediately
}
```

## ミドルウェアと認証

```typescript
// functions/_middleware.js (global) or functions/users/_middleware.js (scoped)
export async function onRequest(ctx) {
  try { return await ctx.next(); } 
  catch (err) { return new Response(err.message, { status: 500 }); }
}

// Chained: export const onRequest = [errorHandler, auth, logger];

// Auth
async function auth(ctx: EventContext<Env>) {
  const token = ctx.request.headers.get('authorization')?.replace('Bearer ', '');
  if (!token) return new Response('Unauthorized', { status: 401 });
  const session = await ctx.env.KV.get(`session:${token}`);
  if (!session) return new Response('Invalid', { status: 401 });
  ctx.data.user = JSON.parse(session);
  return ctx.next();
}
```

## CORS とレート制限

```typescript
// CORS middleware
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'GET, POST' };
export async function onRequestOptions() { return new Response(null, { headers: cors }); }
export async function onRequest(ctx) {
  const res = await ctx.next();
  Object.entries(cors).forEach(([k, v]) => res.headers.set(k, v));
  return res;
}

// Rate limiting (KV-based)
async function rateLimit(ctx: EventContext<Env>) {
  const ip = ctx.request.headers.get('CF-Connecting-IP') || 'unknown';
  const count = parseInt(await ctx.env.KV.get(`rate:${ip}`) || '0');
  if (count >= 100) return new Response('Rate limited', { status: 429 });
  await ctx.env.KV.put(`rate:${ip}`, (count + 1).toString(), { expirationTtl: 3600 });
  return ctx.next();
}
```

## フォーム、キャッシュ、リダイレクト

```typescript
// JSON & file upload
export async function onRequestPost(ctx) {
  const ct = ctx.request.headers.get('content-type') || '';
  if (ct.includes('application/json')) return Response.json(await ctx.request.json());
  if (ct.includes('multipart/form-data')) {
    const file = (await ctx.request.formData()).get('file') as File;
    await ctx.env.BUCKET.put(file.name, file.stream());
    return Response.json({ uploaded: file.name });
  }
}

// Cache API
export async function onRequest(ctx) {
  let res = await caches.default.match(ctx.request);
  if (!res) {
    res = new Response('Data');
    res.headers.set('Cache-Control', 'public, max-age=3600');
    ctx.waitUntil(caches.default.put(ctx.request, res.clone()));
  }
  return res;
}

// Redirects
export async function onRequest(ctx) {
  if (new URL(ctx.request.url).pathname === '/old') {
    return Response.redirect(new URL('/new', ctx.request.url), 301);
  }
  return ctx.next();
}
```

## テスト

**ユニットテスト**（Vitest + cloudflare:test）：
```typescript
import { env } from 'cloudflare:test';
import { it, expect } from 'vitest';
import { onRequest } from '../functions/api';

it('returns JSON', async () => {
  const req = new Request('http://localhost/api');
  const ctx = { request: req, env, params: {}, data: {} } as EventContext;
  const res = await onRequest(ctx);
  expect(res.status).toBe(200);
});
```

**インテグレーション：** `wrangler pages dev` + Playwright/Cypress

## アドバンスモード（_worker.js）

複雑なルーティングには `_worker.js` を使用します（`/functions` を置き換えます）：

```typescript
interface Env { ASSETS: Fetcher; KV: KVNamespace; }

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname.startsWith('/api/')) {
      return Response.json({ data: await env.KV.get('key') });
    }
    return env.ASSETS.fetch(request); // Static files
  }
} satisfies ExportedHandler<Env>;
```

**使用するケース：** 既存の Worker、フレームワークが生成するもの（Next.js/SvelteKit）、カスタムルーティングロジック

**関連項目：** `env.ASSETS.fetch()` については [api.md](./api.md) | デバッグについては [gotchas.md](./gotchas.md)