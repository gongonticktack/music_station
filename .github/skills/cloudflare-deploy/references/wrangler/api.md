# Wrangler プログラマティック API

テストおよび開発向けの Node.js API。

## startWorker（テスト）

統合テスト用に実際のローカルバインディングで Worker を起動します。安定版 API（`unstable_startWorker` を置き換えます）。

```typescript
import { startWorker } from "wrangler";
import { describe, it, before, after } from "node:test";
import assert from "node:assert";

describe("worker", () => {
  let worker;
  
  before(async () => {
    worker = await startWorker({
      config: "wrangler.jsonc",
      environment: "development"
    });
  });
  
  after(async () => {
    await worker.dispose();
  });
  
  it("responds with 200", async () => {
    const response = await worker.fetch("http://example.com");
    assert.strictEqual(response.status, 200);
  });
});
```

### オプション

| オプション | 型 | 説明 |
|--------|------|-------------|
| `config` | `string` | wrangler.jsonc へのパス |
| `environment` | `string` | 設定で指定した環境名 |
| `persist` | `boolean \| { path: string }` | 永続状態を有効にする |
| `bundle` | `boolean` | バンドルを有効にする（デフォルト: true） |
| `remote` | `false \| true \| "minimal"` | リモートモード: `false`（ローカル）、`true`（全面リモート）、`"minimal"`（リモートバインディングのみ） |

### リモートモード

```typescript
// Local mode (default) - fast, simulated
const worker = await startWorker({ config: "wrangler.jsonc" });

// Full remote mode - production-like, slower
const worker = await startWorker({ 
  config: "wrangler.jsonc",
  remote: true 
});

// Minimal remote mode - remote bindings, local Worker
const worker = await startWorker({ 
  config: "wrangler.jsonc",
  remote: "minimal"
});
```

## getPlatformProxy

Worker を起動せずに、Node.js でバインディングをエミュレートします。

```typescript
import { getPlatformProxy } from "wrangler";

const { env, dispose, caches } = await getPlatformProxy<Env>({
  configPath: "wrangler.jsonc",
  environment: "production",
  persist: { path: ".wrangler/state" }
});

// Use bindings
const value = await env.MY_KV.get("key");
await env.DB.prepare("SELECT * FROM users").all();
await env.ASSETS.put("file.txt", "content");

// Platform APIs
await caches.default.put("https://example.com", new Response("cached"));

await dispose();
```

ユニットテスト（Worker 全体ではなく関数をテスト）や、バインディングを必要とするスクリプトに使用します。

## 型の生成

設定から型を生成します: `wrangler types` → `worker-configuration.d.ts` を作成

## イベントシステム

高度なワークフロー向けに、Worker のライフサイクルイベントをリッスンします。

```typescript
import { startWorker } from "wrangler";

const worker = await startWorker({
  config: "wrangler.jsonc",
  bundle: true
});

// Bundle events
worker.on("bundleStart", (details) => {
  console.log("Bundling started:", details.config);
});

worker.on("bundleComplete", (details) => {
  console.log("Bundle ready:", details.duration);
});

// Reconfiguration events
worker.on("reloadStart", () => {
  console.log("Worker reloading...");
});

worker.on("reloadComplete", () => {
  console.log("Worker reloaded");
});

await worker.dispose();
```

### 動的な再設定

```typescript
import { startWorker } from "wrangler";

const worker = await startWorker({ config: "wrangler.jsonc" });

// Replace entire config
await worker.setConfig({
  config: "wrangler.staging.jsonc",
  environment: "staging"
});

// Patch specific fields
await worker.patchConfig({
  vars: { DEBUG: "true" }
});

await worker.dispose();
```

## unstable_dev（非推奨）

代わりに `startWorker` を使用してください。

## マルチ Worker レジストリ

サービスバインディングを使う複数の Worker をテストします。

```typescript
import { startWorker } from "wrangler";

const auth = await startWorker({ config: "./auth/wrangler.jsonc" });
const api = await startWorker({
  config: "./api/wrangler.jsonc",
  bindings: { AUTH: auth }  // Service binding
});

const response = await api.fetch("http://example.com/api/login");
// API Worker calls AUTH Worker via env.AUTH.fetch()

await api.dispose();
await auth.dispose();
```

## ベストプラクティス

- 統合テスト（Worker 全体をテスト）には `startWorker` を使用する
- ユニットテスト（個々の関数をテスト）には `getPlatformProxy` を使用する
- 本番環境固有の問題をデバッグするときは `remote: true` を使用する
- 実際のバインディングを使った高速なテストには `remote: "minimal"` を使用する
- デバッグ用に `persist: true` を有効にする（実行間で状態が維持される）
- 設定を変更した後は `wrangler types` を実行する
- リソースリークを防ぐため、必ず `dispose()` を実行する
- ビルドを監視するため、バンドルイベントをリッスンする
- サービスバインディングのテストにはマルチ Worker レジストリを使用する

## 関連項目

- [README.md](./README.md) - CLI コマンド
- [configuration.md](./configuration.md) - 設定
- [patterns.md](./patterns.md) - テストのパターン