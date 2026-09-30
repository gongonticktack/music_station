# プログラム API

## Miniflare クラス

```typescript
class Miniflare {
  constructor(options: MiniflareOptions);
  
  // Lifecycle
  ready: Promise<URL>; // Resolves when server ready, returns URL
  dispose(): Promise<void>; // Cleanup resources
  setOptions(options: MiniflareOptions): Promise<void>; // Reload config
  
  // Event dispatching
  dispatchFetch(url: string | URL | Request, init?: RequestInit): Promise<Response>;
  getWorker(name?: string): Promise<Worker>;
  
  // Bindings access
  getBindings<Bindings = Record<string, unknown>>(name?: string): Promise<Bindings>;
  getCf(name?: string): Promise<IncomingRequestCfProperties | undefined>;
  getKVNamespace(name: string): Promise<KVNamespace>;
  getR2Bucket(name: string): Promise<R2Bucket>;
  getDurableObjectNamespace(name: string): Promise<DurableObjectNamespace>;
  getDurableObjectStorage(id: DurableObjectId): Promise<DurableObjectStorage>;
  getD1Database(name: string): Promise<D1Database>;
  getCaches(): Promise<CacheStorage>;
  getQueueProducer(name: string): Promise<QueueProducer>;
  
  // Debugging
  getInspectorURL(): Promise<URL>; // Chrome DevTools inspector URL
}
```

## イベントのディスパッチ

**Fetch（HTTP サーバーなし）:**
```js
const res = await mf.dispatchFetch("http://localhost:8787/path", {
  method: "POST",
  headers: { "Authorization": "Bearer token" },
  body: JSON.stringify({ data: "value" }),
});
```

**カスタム Host ルーティング:**
```js
const res = await mf.dispatchFetch("http://localhost:8787/", {
  headers: { "Host": "api.example.com" },
});
```

**スケジュール実行:**
```js
const worker = await mf.getWorker();
const result = await worker.scheduled({ cron: "30 * * * *" });
// result: { outcome: "ok", noRetry: false }
```

**キュー:**
```js
const worker = await mf.getWorker();
const result = await worker.queue("queue-name", [
  { id: "msg1", timestamp: new Date(), body: "data", attempts: 1 },
]);
// result: { outcome: "ok", retryAll: false, ackAll: false, ... }
```

## バインディングへのアクセス

**環境変数:**
```js
// Basic usage
const bindings = await mf.getBindings();
console.log(bindings.SECRET_KEY);

// With type safety (recommended):
interface Env {
  SECRET_KEY: string;
  API_URL: string;
  KV: KVNamespace;
}
const env = await mf.getBindings<Env>();
env.SECRET_KEY; // string (typed!)
env.KV.get("key"); // KVNamespace methods available
```

**Request.cf オブジェクト:**
```js
const cf = await mf.getCf();
console.log(cf?.colo); // "DFW"
console.log(cf?.country); // "US"
```

**KV:**
```js
const ns = await mf.getKVNamespace("TEST_NAMESPACE");
await ns.put("key", "value");
const value = await ns.get("key");
```

**R2:**
```js
const bucket = await mf.getR2Bucket("BUCKET");
await bucket.put("file.txt", "content");
const object = await bucket.get("file.txt");
```

**Durable Objects:**
```js
const ns = await mf.getDurableObjectNamespace("COUNTER");
const id = ns.idFromName("test");
const stub = ns.get(id);
const res = await stub.fetch("http://localhost/");

// Access storage directly:
const storage = await mf.getDurableObjectStorage(id);
await storage.put("key", "value");
```

**D1:**
```js
const db = await mf.getD1Database("DB");
await db.exec(`CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)`);
await db.prepare("INSERT INTO users (name) VALUES (?)").bind("Alice").run();
```

**キャッシュ:**
```js
const caches = await mf.getCaches();
const defaultCache = caches.default;
await defaultCache.put("http://example.com", new Response("cached"));
```

**キュープロデューサー:**
```js
const producer = await mf.getQueueProducer("QUEUE");
await producer.send({ body: "message data" });
```

## ライフサイクル

**再読み込み:**
```js
await mf.setOptions({
  scriptPath: "worker.js",
  bindings: { VERSION: "2.0" },
});
```

**監視（手動）:**
```js
import { watch } from "fs";

const config = { scriptPath: "worker.js" };
const mf = new Miniflare(config);

watch("worker.js", async () => {
  console.log("Reloading...");
  await mf.setOptions(config);
});
```

**クリーンアップ:**
```js
await mf.dispose();
```

## デバッグ

**DevTools 用 Inspector URL:**
```js
const url = await mf.getInspectorURL();
console.log(`DevTools: ${url}`);
// Open in Chrome DevTools for breakpoints, profiling
```

**サーバーの起動完了を待つ:**
```js
const mf = new Miniflare({ scriptPath: "worker.js" });
const url = await mf.ready; // Promise<URL>
console.log(`Server running at ${url}`); // http://127.0.0.1:8787

// Note: dispatchFetch() waits automatically, no need to await ready
const res = await mf.dispatchFetch("http://localhost/"); // Works immediately
```

すべてのコンストラクターオプションについては、[configuration.md](./configuration.md) を参照してください。