# テストパターン

## テスト方法の選択

| 方法 | 用途 | 速度 | セットアップ | 実行環境 |
|----------|----------|-------|-------|---------|
| **getPlatformProxy** | 単体テスト、ロジックのテスト | 高速 | 少ない | Miniflare |
| **Miniflare API** | 統合テスト、完全な制御 | 中程度 | 中程度 | Miniflare |
| **vitest-pool-workers** | Vitest ランナーとの統合 | 中程度 | 中程度 | workerd |

**簡易ガイド:**
- 単体テスト → getPlatformProxy
- 統合テスト → Miniflare API
- Vitest のワークフロー → vitest-pool-workers

## getPlatformProxy

軽量な単体テスト向け。完全な Worker ランタイムなしでバインディングを提供します。

```js
// vitest.config.js
export default { test: { environment: "node" } };
```

```js
import { env } from "cloudflare:test";
import { describe, it, expect } from "vitest";

describe("Business logic", () => {
  it("processes data with KV", async () => {
    await env.KV.put("test", "value");
    expect(await env.KV.get("test")).toBe("value");
  });
});
```

**利点:** 高速、シンプル  
**欠点:** 完全なランタイムがなく、fetch ハンドラーをテストできない

## vitest-pool-workers

Vitest で完全な Workers ランタイムを使用します。`wrangler.toml` を読み込みます。

```bash
npm i -D @cloudflare/vitest-pool-workers
```

```js
// vitest.config.js
import { defineWorkersConfig } from "@cloudflare/vitest-pool-workers/config";

export default defineWorkersConfig({
  test: {
    poolOptions: { workers: { wrangler: { configPath: "./wrangler.toml" } } },
  },
});
```

```js
import { env, SELF } from "cloudflare:test";
import { it, expect } from "vitest";

it("handles fetch", async () => {
  const res = await SELF.fetch("http://example.com/");
  expect(res.status).toBe(200);
});
```

**利点:** 完全なランタイム、wrangler.toml を使用  
**欠点:** Wrangler の設定が必要

## Miniflare API (node:test)

```js
import assert from "node:assert";
import test, { after, before } from "node:test";
import { Miniflare } from "miniflare";

let mf;
before(() => {
  mf = new Miniflare({ scriptPath: "src/index.js", kvNamespaces: ["TEST_KV"] });
});

test("fetch", async () => {
  const res = await mf.dispatchFetch("http://localhost/");
  assert.strictEqual(await res.text(), "Hello");
});

after(() => mf.dispose());
```

## Durable Objects とイベントのテスト

```js
// Durable Objects
const ns = await mf.getDurableObjectNamespace("COUNTER");
const stub = ns.get(ns.idFromName("test-counter"));
await stub.fetch("http://localhost/increment");

// Direct storage
const storage = await mf.getDurableObjectStorage(ns.idFromName("test-counter"));
const count = await storage.get("count");

// Queue
const worker = await mf.getWorker();
await worker.queue("my-queue", [
  { id: "msg1", timestamp: new Date(), body: { userId: 123 }, attempts: 1 },
]);

// Scheduled
await worker.scheduled({ cron: "0 0 * * *" });
```

## テストの分離とモック

```js
// Per-test isolation
beforeEach(() => { mf = new Miniflare({ kvNamespaces: ["TEST"] }); });
afterEach(() => mf.dispose());

// Mock external APIs
new Miniflare({
  workers: [
    { name: "main", serviceBindings: { API: "mock-api" }, script: `...` },
    { name: "mock-api", script: `export default { async fetch() { return Response.json({mock: true}); } }` },
  ],
});
```

## 型安全性

```ts
import type { KVNamespace } from "@cloudflare/workers-types";

interface Env {
  KV: KVNamespace;
  API_KEY: string;
}

const env = await mf.getBindings<Env>();
await env.KV.put("key", "value"); // Typed!

export default {
  async fetch(req: Request, env: Env) {
    return new Response(await env.KV.get("key"));
  }
} satisfies ExportedHandler<Env>;
```

## WebSocket のテスト

```js
const res = await mf.dispatchFetch("http://localhost/ws", {
  headers: { Upgrade: "websocket" },
});
assert.strictEqual(res.status, 101);
```

## unstable_dev からの移行

```js
// Old (deprecated)
import { unstable_dev } from "wrangler";
const worker = await unstable_dev("src/index.ts");

// New
import { Miniflare } from "miniflare";
const mf = new Miniflare({ scriptPath: "src/index.ts" });
```

## CI/CD のヒント

```js
// In-memory storage (faster)
new Miniflare({ kvNamespaces: ["TEST"] }); // No persist = in-memory

// Use dispatchFetch (no port conflicts)
await mf.dispatchFetch("http://localhost/");
```

トラブルシューティングについては [gotchas.md](./gotchas.md) を参照。