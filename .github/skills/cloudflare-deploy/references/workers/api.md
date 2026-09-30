# Workers ランタイム API

## Fetch ハンドラー

```typescript
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === 'POST' && url.pathname === '/api') {
      const body = await request.json();
      return new Response(JSON.stringify({ id: 1 }), {
        headers: { 'Content-Type': 'application/json' }
      });
    }
    return fetch(request);  // Subrequest to origin
  },
};
```

## 実行コンテキスト

```typescript
ctx.waitUntil(logAnalytics(request));  // Background work, don't block response
ctx.passThroughOnException();  // Failover to origin on error
```

バックグラウンド処理には **決して** `await` を使わず、`ctx.waitUntil()` を使用してください。

## バインディング

```typescript
// KV
await env.MY_KV.get('key');
await env.MY_KV.put('key', 'value', { expirationTtl: 3600 });

// R2
const obj = await env.MY_BUCKET.get('file.txt');
await env.MY_BUCKET.put('file.txt', 'content');

// D1
const result = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(1).first();

// D1 Sessions (2024+) - read-after-write consistency
const session = env.DB.withSession();
await session.prepare('INSERT INTO users (name) VALUES (?)').bind('Alice').run();
const user = await session.prepare('SELECT * FROM users WHERE name = ?').bind('Alice').first(); // Guaranteed fresh

// Queues
await env.MY_QUEUE.send({ timestamp: Date.now() });

// Secrets/vars
const key = env.API_KEY;
```

## Cache API

```typescript
const cache = caches.default;
let response = await cache.match(request);

if (!response) {
  response = await fetch(request);
  response = new Response(response.body, response);
  response.headers.set('Cache-Control', 'max-age=3600');
  ctx.waitUntil(cache.put(request, response.clone()));  // Clone before caching
}
```

## HTMLRewriter

```typescript
return new HTMLRewriter()
  .on('a[href]', {
    element(el) {
      const href = el.getAttribute('href');
      if (href?.startsWith('http://')) {
        el.setAttribute('href', href.replace('http://', 'https://'));
      }
    }
  })
  .transform(response);
```

**用途**: A/B テスト、分析機能の挿入、リンクの書き換え

## WebSocket

### 標準の WebSocket

```typescript
const [client, server] = Object.values(new WebSocketPair());

server.accept();
server.addEventListener('message', event => {
  server.send(`Echo: ${event.data}`);
});

return new Response(null, { status: 101, webSocket: client });
```

### WebSocket の休止（アイドル接続に推奨）

```typescript
// In Durable Object
export class WebSocketDO {
  async webSocketMessage(ws: WebSocket, message: string) {
    ws.send(`Echo: ${message}`);
  }
  
  async webSocketClose(ws: WebSocket, code: number, reason: string) {
    // Cleanup on close
  }
  
  async webSocketError(ws: WebSocket, error: Error) {
    console.error('WebSocket error:', error);
  }
}
```

休止機能は、非アクティブな接続を自動的に一時停止します（CPU コストはかかりません）。イベント発生時に再開します。

## Durable Objects

### RPC パターン（2024年以降に推奨）

```typescript
export class Counter {
  private value = 0;
  
  constructor(private state: DurableObjectState) {
    state.blockConcurrencyWhile(async () => {
      this.value = (await state.storage.get('value')) || 0;
    });
  }
  
  // Export methods directly - called via RPC (type-safe, zero serialization)
  async increment(): Promise<number> {
    this.value++;
    await this.state.storage.put('value', this.value);
    return this.value;
  }
  
  async getValue(): Promise<number> {
    return this.value;
  }
}

// Worker usage:
const stub = env.COUNTER.get(env.COUNTER.idFromName('global'));
const count = await stub.increment(); // Direct method call, full type safety
```

### 従来の Fetch パターン（2024年以前）

```typescript
async fetch(request: Request): Promise<Response> {
  const url = new URL(request.url);
  if (url.pathname === '/increment') {
    await this.state.storage.put('value', ++this.value);
  }
  return new Response(String(this.value));
}
// Usage: await stub.fetch('http://x/increment')
```

**DO の用途**: リアルタイム共同作業、レート制限、強整合性のある状態管理

## その他のハンドラー

```typescript
// Cron: async scheduled(event, env, ctx) { ctx.waitUntil(doCleanup(env)); }
// Queue: async queue(batch) { for (const msg of batch.messages) { await process(msg.body); msg.ack(); } }
// Tail: async tail(events, env) { for (const e of events) if (e.outcome === 'exception') await log(e); }
```

## サービスバインディング

```typescript
// Worker-to-worker RPC (zero latency, no internet round-trip)
return env.SERVICE_B.fetch(request);

// With RPC (2024+) - same as Durable Objects RPC
export class ServiceWorker {
  async getData() { return { data: 'value' }; }
}
// Usage: const data = await env.SERVICE_B.getData();
```

**利点**: 型安全なメソッド呼び出し、HTTP オーバーヘッドなし、Workers 間でのコード共有

## 関連項目

- [設定](./configuration.md) - バインディングの設定
- [パターン](./patterns.md) - 一般的なワークフロー
- [KV](../kv/README.md)、[D1](../d1/README.md)、[R2](../r2/README.md)、[Durable Objects](../durable-objects/README.md)、[Queues](../queues/README.md)
