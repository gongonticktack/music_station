# Workers フレームワーク

## Hono（推奨）

Workers ネイティブの Web フレームワーク。優れた TypeScript サポートとミドルウェアのエコシステムを備えています。

```bash
npm install hono
```

### 基本設定

```typescript
import { Hono } from 'hono';

const app = new Hono();

app.get('/', (c) => c.text('Hello World!'));
app.post('/api/users', async (c) => {
  const body = await c.req.json();
  return c.json({ id: 1, ...body }, 201);
});

export default app;
```

### 型付き環境

```typescript
import type { Env } from './.wrangler/types/runtime';

const app = new Hono<{ Bindings: Env }>();

app.get('/data', async (c) => {
  const value = await c.env.MY_KV.get('key');  // Fully typed
  return c.text(value || 'Not found');
});
```

### ミドルウェア

```typescript
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';

app.use('*', logger());
app.use('/api/*', cors({ origin: '*' }));

// Custom middleware
app.use('/protected/*', async (c, next) => {
  const auth = c.req.header('Authorization');
  if (!auth?.startsWith('Bearer ')) return c.text('Unauthorized', 401);
  await next();
});
```

### リクエストの検証（Zod）

```typescript
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';

const schema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
});

app.post('/users', zValidator('json', schema), async (c) => {
  const validated = c.req.valid('json');  // Type-safe, validated data
  return c.json({ id: 1, ...validated });
});
```

**エラー処理**: 検証エラーを含む 400 レスポンスを自動的に返します。

### ルートグループ

```typescript
const api = new Hono().basePath('/api');

api.get('/users', (c) => c.json([]));
api.post('/users', (c) => c.json({ id: 1 }));

app.route('/', api);  // Mounts at /api/*
```

### エラー処理

```typescript
app.onError((err, c) => {
  console.error(err);
  return c.json({ error: err.message }, 500);
});

app.notFound((c) => c.json({ error: 'Not Found' }, 404));
```

### ExecutionContext へのアクセス

```typescript
export default {
  fetch(request: Request, env: Env, ctx: ExecutionContext) {
    return app.fetch(request, env, ctx);
  },
};

// In route handlers:
app.get('/log', (c) => {
  c.executionCtx.waitUntil(logRequest(c.req));
  return c.text('OK');
});
```

### OpenAPI/Swagger（Hono OpenAPI）

```typescript
import { OpenAPIHono, createRoute, z } from '@hono/zod-openapi';

const app = new OpenAPIHono();

const route = createRoute({
  method: 'get',
  path: '/users/{id}',
  request: { params: z.object({ id: z.string() }) },
  responses: {
    200: { description: 'User found', content: { 'application/json': { schema: z.object({ id: z.string() }) } } },
  },
});

app.openapi(route, (c) => {
  const { id } = c.req.valid('param');
  return c.json({ id });
});

app.doc('/openapi.json', { openapi: '3.0.0', info: { version: '1.0.0', title: 'API' } });
```

### Hono でのテスト

```typescript
import { describe, it, expect } from 'vitest';
import app from '../src/index';

describe('API', () => {
  it('GET /', async () => {
    const res = await app.request('/');
    expect(res.status).toBe(200);
    expect(await res.text()).toBe('Hello World!');
  });
});
```

## その他のフレームワーク

### itty-router（ミニマリスト向け）

```typescript
import { Router } from 'itty-router';

const router = Router();

router.get('/users/:id', ({ params }) => new Response(params.id));

export default { fetch: router.handle };
```

**用途**: バンドルサイズを極小（約 500 バイト）に抑えたい場合や、シンプルなルーティングが必要な場合

### Worktop（高度な用途向け）

```typescript
import { Router } from 'worktop';

const router = new Router();

router.add('GET', '/users/:id', (req, res) => {
  res.send(200, { id: req.params.id });
});

router.listen();
```

**用途**: 高度なルーティングや、組み込みの CORS／キャッシュユーティリティが必要な場合

## フレームワークの比較

| フレームワーク | バンドルサイズ | TypeScript | ミドルウェア | 検証 | 最適な用途 |
|-----------|-------------|------------|------------|------------|----------|
| Hono | 約 12 KB | 優れている | 豊富 | Zod | 本番アプリ |
| itty-router | 約 500 B | 良好 | 基本的 | 手動 | 最小限の API |
| Worktop | 約 8 KB | 良好 | 高度 | 手動 | 複雑なルーティング |

## 関連項目

- [パターン](./patterns.md) - よくあるワークフロー
- [API](./api.md) - ランタイム API
- [落とし穴](./gotchas.md) - フレームワーク固有の問題
