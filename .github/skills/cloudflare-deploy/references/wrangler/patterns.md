# Wrangler開発パターン

よく使われるワークフローとベストプラクティス。

## 新しいWorkerプロジェクト

```bash
wrangler init my-worker && cd my-worker
wrangler dev              # Develop locally
wrangler deploy           # Deploy
```

## ローカル開発

```bash
wrangler dev              # Local mode (fast, simulated)
wrangler dev --remote     # Remote mode (production-accurate)
wrangler dev --env staging --port 8787
wrangler dev --inspector-port 9229  # Enable debugging
```

デバッグ: chrome://inspect → Configure → localhost:9229

## シークレット

```bash
# Production
echo "secret-value" | wrangler secret put SECRET_KEY

# Local: use .dev.vars (gitignored)
# SECRET_KEY=local-dev-key
```

## KVの追加

```bash
wrangler kv namespace create MY_KV
wrangler kv namespace create MY_KV --preview
# Add to wrangler.jsonc: { "binding": "MY_KV", "id": "abc123" }
wrangler deploy
```

## D1の追加

```bash
wrangler d1 create my-db
wrangler d1 migrations create my-db "initial_schema"
# Edit migration file in migrations/, then:
wrangler d1 migrations apply my-db --local
wrangler deploy
wrangler d1 migrations apply my-db --remote

# Time Travel (restore to point in time)
wrangler d1 time-travel restore my-db --timestamp 2025-01-01T12:00:00Z
```

## 複数環境

```bash
wrangler deploy --env staging
wrangler deploy --env production
```

```jsonc
{ "env": { "staging": { "vars": { "ENV": "staging" } } } }
```

## テスト

### Node.jsテストランナーを使った統合テスト

```typescript
import { startWorker } from "wrangler";
import { describe, it, before, after } from "node:test";
import assert from "node:assert";

describe("API", () => {
  let worker;
  
  before(async () => {
    worker = await startWorker({ 
      config: "wrangler.jsonc",
      remote: "minimal"  // Fast tests with real bindings
    });
  });
  
  after(async () => await worker.dispose());
  
  it("creates user", async () => {
    const response = await worker.fetch("http://example.com/api/users", {
      method: "POST",
      body: JSON.stringify({ name: "Alice" })
    });
    assert.strictEqual(response.status, 201);
  });
});
```

### Vitestを使ったテスト

インストール: `npm install -D vitest @cloudflare/vitest-pool-workers`

**vitest.config.ts:**
```typescript
import { defineWorkersConfig } from "@cloudflare/vitest-pool-workers/config";
export default defineWorkersConfig({
  test: { poolOptions: { workers: { wrangler: { configPath: "./wrangler.jsonc" } } } }
});
```

**tests/api.test.ts:**
```typescript
import { env, SELF } from "cloudflare:test";
import { describe, it, expect } from "vitest";

it("fetches users", async () => {
  const response = await SELF.fetch("https://example.com/api/users");
  expect(response.status).toBe(200);
});

it("uses bindings", async () => {
  await env.MY_KV.put("key", "value");
  expect(await env.MY_KV.get("key")).toBe("value");
});
```

### 複数Workerでの開発（Service Bindings）

```typescript
const authWorker = await startWorker({ config: "./auth/wrangler.jsonc" });
const apiWorker = await startWorker({
  config: "./api/wrangler.jsonc",
  bindings: { AUTH: authWorker }  // Service binding
});

// Test API calling AUTH
const response = await apiWorker.fetch("http://example.com/api/protected");
await authWorker.dispose();
await apiWorker.dispose();
```

### 外部APIのモック

```typescript
const worker = await startWorker({ 
  config: "wrangler.jsonc",
  outboundService: (req) => {
    const url = new URL(req.url);
    if (url.hostname === "api.external.com") {
      return new Response(JSON.stringify({ mocked: true }), {
        headers: { "content-type": "application/json" }
      });
    }
    return fetch(req);  // Pass through other requests
  }
});

// Test Worker that calls external API
const response = await worker.fetch("http://example.com/proxy");
// Worker internally fetches api.external.com - gets mocked response
```

## モニタリングとバージョン

```bash
wrangler tail                 # Real-time logs
wrangler tail --status error  # Filter errors
wrangler versions list
wrangler rollback [id]
```

## TypeScript

```bash
wrangler types  # Generate types from config
```

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    return Response.json({ value: await env.MY_KV.get("key") });
  }
} satisfies ExportedHandler<Env>;
```

## Workers Assets

```jsonc
{ "assets": { "directory": "./dist", "binding": "ASSETS" } }
```

```typescript
export default {
  async fetch(request, env) {
    // API routes first
    if (new URL(request.url).pathname.startsWith("/api/")) {
      return Response.json({ data: "from API" });
    }
    return env.ASSETS.fetch(request);  // Static assets
  }
}
```

## 関連項目

- [README.md](./README.md) - コマンド
- [configuration.md](./configuration.md) - 設定
- [api.md](./api.md) - プログラムから利用するAPI
- [gotchas.md](./gotchas.md) - 問題点