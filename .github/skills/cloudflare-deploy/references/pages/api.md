# Functions API

## ファイルベースのルーティング

```
/functions/index.ts              → example.com/
/functions/api/users.ts          → example.com/api/users
/functions/api/users/[id].ts     → example.com/api/users/:id
/functions/api/users/[[path]].ts → example.com/api/users/* (catchall)
/functions/_middleware.ts        → Runs before all routes
```

**ルール**: `[param]` = 単一セグメント、`[[param]]` = 複数セグメントのキャッチオール、より具体的なルートが優先されます。

## リクエストハンドラー

```typescript
import type { PagesFunction } from '@cloudflare/workers-types';

interface Env {
  DB: D1Database;
  KV: KVNamespace;
}

// All methods
export const onRequest: PagesFunction<Env> = async (context) => {
  return new Response('All methods');
};

// Method-specific
export const onRequestGet: PagesFunction<Env> = async (context) => {
  const { request, env, params, data } = context;
  
  const user = await env.DB.prepare(
    'SELECT * FROM users WHERE id = ?'
  ).bind(params.id).first();
  
  return Response.json(user);
};

export const onRequestPost: PagesFunction<Env> = async (context) => {
  const body = await context.request.json();
  return Response.json({ success: true });
};

// Also: onRequestPut, onRequestPatch, onRequestDelete, onRequestHead, onRequestOptions
```

## コンテキストオブジェクト

```typescript
interface EventContext<Env, Params, Data> {
  request: Request;              // HTTP request
  env: Env;                      // Bindings (KV, D1, R2, etc.)
  params: Params;                // Route parameters
  data: Data;                    // Middleware-shared data
  waitUntil: (promise: Promise<any>) => void;  // Background tasks
  next: () => Promise<Response>; // Next handler
  passThroughOnException: () => void;  // Error fallback (not in advanced mode)
}
```

## 動的ルート

```typescript
// Single segment: functions/users/[id].ts
export const onRequestGet: PagesFunction = async ({ params }) => {
  // /users/123 → params.id = "123"
  return Response.json({ userId: params.id });
};

// Multi-segment: functions/files/[[path]].ts
export const onRequestGet: PagesFunction = async ({ params }) => {
  // /files/docs/api/v1.md → params.path = ["docs", "api", "v1.md"]
  const filePath = (params.path as string[]).join('/');
  return new Response(filePath);
};
```

## ミドルウェア

```typescript
// functions/_middleware.ts
// Single
export const onRequest: PagesFunction = async (context) => {
  const response = await context.next();
  response.headers.set('X-Custom-Header', 'value');
  return response;
};

// Chained (runs in order)
const errorHandler: PagesFunction = async (context) => {
  try {
    return await context.next();
  } catch (err) {
    return new Response(err.message, { status: 500 });
  }
};

const auth: PagesFunction = async (context) => {
  const token = context.request.headers.get('Authorization');
  if (!token) return new Response('Unauthorized', { status: 401 });
  context.data.userId = await verifyToken(token);
  return context.next();
};

export const onRequest = [errorHandler, auth];
```

**適用範囲**: `functions/_middleware.ts` → すべて、`functions/api/_middleware.ts` → `/api/*` のみ

## バインディングの使用

```typescript
export const onRequestGet: PagesFunction<Env> = async ({ env }) => {
  // KV
  const cached = await env.KV.get('key', 'json');
  await env.KV.put('key', JSON.stringify({data: 'value'}), {expirationTtl: 3600});
  
  // D1
  const result = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first();
  
  // R2, Queue, AI - see respective reference docs
  
  return Response.json({success: true});
};
```

## Advanced Mode

Workers API全体を使用し、ファイルベースのルーティングをバイパスします:

```javascript
// functions/_worker.js
export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    
    // Custom routing
    if (url.pathname.startsWith('/api/')) {
      return new Response('API response');
    }
    
    // REQUIRED: Serve static assets
    return env.ASSETS.fetch(request);
  }
};
```

**使用する場面**: WebSocket、複雑なルーティング、スケジュール実行ハンドラー、メールハンドラー。

## Smart Placement

トラフィックパターンに基づいて、関数の実行場所を自動的に最適化します。

**設定**（wrangler.jsonc内）:
```jsonc
{
  "placement": {
    "mode": "smart"  // Enables optimization (default: off)
  }
}
```

**仕組み**: 時間の経過とともにトラフィックパターンを分析し、ユーザーまたはデータソース（D1データベースなど）に近い場所に関数を配置します。コードの変更は不要です。

**トレードオフ**: 学習期間中（数時間から数日）は、初期のリクエストでレイテンシがやや高くなることがあります。システムが最適化されるにつれて、パフォーマンスは向上します。

**使用する場面**: データベースを一元管理しているグローバルアプリや、トラフィックの発生元が特定の地域に集中しているアプリ。

## getRequestContext（フレームワークSSR）

フレームワークのコードからバインディングにアクセスします:

```typescript
// SvelteKit
import type { RequestEvent } from '@sveltejs/kit';
export async function load({ platform }: RequestEvent) {
  const data = await platform.env.DB.prepare('SELECT * FROM users').all();
  return { users: data.results };
}

// Astro
const { DB } = Astro.locals.runtime.env;
const data = await DB.prepare('SELECT * FROM users').all();

// Solid Start (server function)
import { getRequestEvent } from 'solid-js/web';
const event = getRequestEvent();
const data = await event.locals.runtime.env.DB.prepare('SELECT * FROM users').all();
```

**✅ 対応アダプター**（2026年）:
- **SvelteKit**: `@sveltejs/adapter-cloudflare`
- **Astro**: Cloudflareアダプターを内蔵
- **Nuxt**: `nitro.preset: 'cloudflare-pages'`で`nuxt.config.ts`を設定
- **Qwik**: Cloudflareアダプターを内蔵
- **Solid Start**: `@solidjs/start-cloudflare-pages`

**❌ 非推奨/非対応**:
- **Next.js**: 公式アダプター（`@cloudflare/next-on-pages`）は非推奨です。Vercelを使うか、Workersにセルフホストしてください。
- **Remix**: 公式アダプター（`@remix-run/cloudflare-pages`）は非推奨です。対応しているフレームワークに移行してください。

移行方法については[gotchas.md](./gotchas.md#framework-specific)を参照してください。
