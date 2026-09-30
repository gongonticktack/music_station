# バインディングのパターンとベストプラクティス

## サービスバインディングのパターン

### サービスバインディング経由の RPC

```typescript
// auth-worker
export default {
  async fetch(request: Request, env: Env) {
    const token = request.headers.get('Authorization');
    return new Response(JSON.stringify({ valid: await validateToken(token) }));
  }
}

// api-worker
const response = await env.AUTH_SERVICE.fetch(
  new Request('https://fake-host/validate', {
    headers: { 'Authorization': token }
  })
);
```

**RPC を使う理由:** レイテンシゼロ（同じデータセンター内）、DNS 不要、無料、型安全。

**HTTP とサービスバインディング:**
```typescript
// ❌ HTTP (slow, paid, cross-region latency)
await fetch('https://auth-worker.example.com/validate');

// ✅ Service binding (fast, free, same isolate)
await env.AUTH_SERVICE.fetch(new Request('https://fake-host/validate'));
```

**URL は関係しない:** サービスバインディングはホスト名やプロトコルを無視し、バインディング名を通じてルーティングされる。

### 型付きサービス RPC

```typescript
// shared-types.ts
export interface AuthRequest { token: string; }
export interface AuthResponse { valid: boolean; userId?: string; }

// auth-worker
export default {
  async fetch(request: Request): Promise<Response> {
    const body: AuthRequest = await request.json();
    const response: AuthResponse = { valid: true, userId: '123' };
    return Response.json(response);
  }
}

// api-worker
const response = await env.AUTH_SERVICE.fetch(
  new Request('https://fake/validate', {
    method: 'POST',
    body: JSON.stringify({ token } satisfies AuthRequest)
  })
);
const data: AuthResponse = await response.json();
```

## シークレット管理

```bash
# Set secret
npx wrangler secret put API_KEY
cat api-key.txt | npx wrangler secret put API_KEY
npx wrangler secret put API_KEY --env staging
```

```typescript
// Use secret
const response = await fetch('https://api.example.com', {
  headers: { 'Authorization': `Bearer ${env.API_KEY}` }
});
```

**シークレットを絶対にコミットしない:**
```jsonc
// ❌ NEVER
{ "vars": { "API_KEY": "sk_live_abc123" } }
```

## モックバインディングを使ったテスト

### Vitest モック

```typescript
import { vi } from 'vitest';

const mockKV: KVNamespace = {
  get: vi.fn(async (key) => key === 'test' ? 'value' : null),
  put: vi.fn(async () => {}),
  delete: vi.fn(async () => {}),
  list: vi.fn(async () => ({ keys: [], list_complete: true, cursor: '' })),
  getWithMetadata: vi.fn(),
} as unknown as KVNamespace;

const mockEnv: Env = { MY_KV: mockKV };
const mockCtx: ExecutionContext = {
  waitUntil: vi.fn(),
  passThroughOnException: vi.fn(),
};

const response = await worker.fetch(
  new Request('http://localhost/test'),
  mockEnv,
  mockCtx
);
```

## バインディングへのアクセスパターン

### 遅延アクセス

```typescript
// ✅ Access only when needed
if (url.pathname === '/cached') {
  const cached = await env.MY_KV.get('data');
  if (cached) return new Response(cached);
}
```

### 並列アクセス

```typescript
// ✅ Parallelize independent calls
const [user, config, cache] = await Promise.all([
  env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first(),
  env.MY_KV.get('config'),
  env.CACHE.get('data')
]);
```

## ストレージの選択

### KV：CDN による読み取り

```typescript
const config = await env.MY_KV.get('app-config', { type: 'json' });
```

**用途:** 読み取り中心、25 MB 未満、グローバル配信、結果整合性を許容できる場合  
**レイテンシ:** 読み取りは 10 ms 未満（キャッシュ時）、書き込みは最終的に整合（60 秒）

### D1：リレーショナルクエリ

```typescript
const results = await env.DB.prepare(`
  SELECT u.name, COUNT(o.id) FROM users u
  LEFT JOIN orders o ON u.id = o.user_id GROUP BY u.id
`).all();
```

**用途:** リレーショナルデータ、JOIN、ACID トランザクション  
**制限:** データベースサイズ 10 GB、クエリあたり 10 万行

### R2：大容量オブジェクト

```typescript
const object = await env.MY_BUCKET.get('large-file.zip');
return new Response(object.body);
```

**用途:** 25 MB を超えるファイル、S3 互換 API が必要な場合  
**制限:** オブジェクトあたり 5 TB、ストレージ容量は無制限

### Durable Objects：調整

```typescript
const id = env.COUNTER.idFromName('global');
const stub = env.COUNTER.get(id);
await stub.fetch(new Request('https://fake/increment'));
```

**用途:** 強い整合性、リアルタイム調整、WebSocket の状態管理  
**保証:** 単一スレッド実行、トランザクション対応ストレージ

## アンチパターン

**❌ 認証情報のハードコード:** `const apiKey = 'sk_live_abc123'`  
**✅** `npx wrangler secret put API_KEY`

**❌ REST API の使用:** `fetch('https://api.cloudflare.com/.../kv/...')`  
**✅** `env.MY_KV.get('key')`

**❌ ストレージのポーリング:** `setInterval(() => env.KV.get('config'), 1000)`  
**✅** リアルタイム状態には Durable Objects を使う

**❌ vars への大きなデータの格納:** `{ "vars": { "HUGE_CONFIG": "..." } }`（最大 5 KB）  
**✅** `env.MY_KV.put('config', data)`

**❌ env のグローバルキャッシュ:** fetch() の外で `const apiKey = env.API_KEY` とする  
**✅** fetch() 内でリクエストごとに `env.API_KEY` にアクセスする

## 関連項目

- [Service Bindings Docs](https://developers.cloudflare.com/workers/runtime-apis/bindings/service-bindings/)
- [Miniflare Testing](https://miniflare.dev/)