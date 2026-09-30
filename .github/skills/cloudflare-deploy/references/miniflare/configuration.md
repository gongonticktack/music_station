# Configuration

## スクリプトの読み込み

```js
// Inline
new Miniflare({ modules: true, script: `export default { ... }` });

// File-based
new Miniflare({ scriptPath: "worker.js" });

// Multi-module
new Miniflare({
  scriptPath: "src/index.js",
  modules: true,
  modulesRules: [
    { type: "ESModule", include: ["**/*.js"] },
    { type: "Text", include: ["**/*.txt"] },
  ],
});
```

## 互換性

```js
new Miniflare({
  compatibilityDate: "2026-01-01", // Use recent date for latest features
  compatibilityFlags: [
    "nodejs_compat",        // Node.js APIs (process, Buffer, etc)
    "streams_enable_constructors", // Stream constructors
  ],
  upstream: "https://example.com", // Fallback for unhandled requests
});
```

**重要:** 本番ランタイムに合わせるため、`compatibilityDate: "2026-01-01"` または最新の日付を使用してください。古い日付では利用できる API が制限されます。

## HTTP サーバーと Request.cf

```js
new Miniflare({
  port: 8787,              // Default: 8787
  host: "127.0.0.1",
  https: true,             // Self-signed cert
  liveReload: true,        // Auto-reload HTML
  
  cf: true,                // Fetch live Request.cf data (cached)
  // cf: "./cf.json",      // Or load from file
  // cf: { colo: "DFW" },  // Or inline mock
});
```

**注:** テストでは `dispatchFetch()` を使用してください（ポートの競合がありません）。

## ストレージバインディング

```js
new Miniflare({
  // KV
  kvNamespaces: ["TEST_NAMESPACE", "CACHE"],
  kvPersist: "./kv-data", // Optional: persist to disk
  
  // R2
  r2Buckets: ["BUCKET", "IMAGES"],
  r2Persist: "./r2-data",
  
  // Durable Objects
  modules: true,
  durableObjects: {
    COUNTER: "Counter", // className
    API_OBJECT: { className: "ApiObject", scriptName: "api-worker" },
  },
  durableObjectsPersist: "./do-data",
  
  // D1
  d1Databases: ["DB"],
  d1Persist: "./d1-data",
  
  // Cache
  cache: true, // Default
  cachePersist: "./cache-data",
});
```

## バインディング

```js
new Miniflare({
  // Environment variables
  bindings: {
    SECRET_KEY: "my-secret-value",
    API_URL: "https://api.example.com",
    DEBUG: true,
  },
  
  // Other bindings
  wasmBindings: { ADD_MODULE: "./add.wasm" },
  textBlobBindings: { TEXT: "./data.txt" },
  queueProducers: ["QUEUE"],
});
```

## 複数の Worker

```js
new Miniflare({
  workers: [
    {
      name: "main",
      kvNamespaces: { DATA: "shared" },
      serviceBindings: { API: "api-worker" },
      script: `export default { ... }`,
    },
    {
      name: "api-worker",
      kvNamespaces: { DATA: "shared" }, // Shared storage
      script: `export default { ... }`,
    },
  ],
});
```

**ルーティングあり:**
```js
workers: [
  { name: "api", scriptPath: "./api.js", routes: ["api.example.com/*"] },
  { name: "web", scriptPath: "./web.js", routes: ["example.com/*"] },
],
```

## ログとパフォーマンス

```js
import { Log, LogLevel } from "miniflare";

new Miniflare({
  log: new Log(LogLevel.DEBUG), // DEBUG | INFO | WARN | ERROR | NONE
  scriptTimeout: 30000,         // CPU limit (ms)
  workersConcurrencyLimit: 10,  // Max concurrent workers
});
```

## Workers Sites

```js
new Miniflare({
  sitePath: "./public",
  siteInclude: ["**/*.html", "**/*.css"],
  siteExclude: ["**/*.map"],
});
```

## wrangler.toml から設定

Miniflare は `wrangler.toml` を自動で読み込みません。

```toml
# wrangler.toml
name = "my-worker"
main = "src/index.ts"
compatibility_date = "2026-01-01"
[[kv_namespaces]]
binding = "KV"
```

```js
// Miniflare equivalent
new Miniflare({
  scriptPath: "src/index.ts",
  compatibilityDate: "2026-01-01",
  kvNamespaces: ["KV"],
});
```