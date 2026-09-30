# API 操作

## ユーザー Worker のデプロイ

```bash
curl -X PUT \
  "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/dispatch/namespaces/$NAMESPACE/scripts/$SCRIPT_NAME" \
  -H "Authorization: Bearer $API_TOKEN" \
  -F 'metadata={"main_module": "worker.mjs"};type=application/json' \
  -F 'worker.mjs=@worker.mjs;type=application/javascript+module'
```

### TypeScript SDK
```typescript
import Cloudflare from "cloudflare";

const client = new Cloudflare({ apiToken: process.env.API_TOKEN });

const scriptFile = new File([scriptContent], `${scriptName}.mjs`, {
  type: "application/javascript+module",
});

await client.workersForPlatforms.dispatch.namespaces.scripts.update(
  namespace, scriptName,
  {
    account_id: accountId,
    metadata: { main_module: `${scriptName}.mjs` },
    files: [scriptFile],
  }
);
```

## TypeScript 型

```typescript
import type { DispatchNamespace } from '@cloudflare/workers-types';

interface DispatchNamespace {
  get(name: string, options?: Record<string, unknown>, dispatchOptions?: DynamicDispatchOptions): Fetcher;
}

interface DynamicDispatchOptions {
  limits?: DynamicDispatchLimits;
  outbound?: Record<string, unknown>;
}

interface DynamicDispatchLimits {
  cpuMs?: number;        // Max CPU milliseconds
  subRequests?: number;  // Max fetch() calls
}

// Usage
const userWorker = env.DISPATCHER.get('customer-123', {}, {
  limits: { cpuMs: 50, subRequests: 20 },
  outbound: { customerId: '123', url: request.url }
});
```

## バインディング付きでデプロイ
```bash
curl -X PUT ".../scripts/$SCRIPT_NAME" \
  -F 'metadata={
    "main_module": "worker.mjs",
    "bindings": [
      {"type": "kv_namespace", "name": "MY_KV", "namespace_id": "'$KV_ID'"}
    ],
    "tags": ["customer-123", "production"],
    "compatibility_date": "2026-01-01"  // Use current date for new projects
  };type=application/json' \
  -F 'worker.mjs=@worker.mjs;type=application/javascript+module'
```

## Worker の一覧表示／削除

```bash
# List
curl "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/dispatch/namespaces/$NAMESPACE/scripts" \
  -H "Authorization: Bearer $API_TOKEN"

# Delete by name
curl -X DELETE ".../scripts/$SCRIPT_NAME" -H "Authorization: Bearer $API_TOKEN"

# Delete by tag
curl -X DELETE ".../scripts?tags=customer-123%3Ayes" -H "Authorization: Bearer $API_TOKEN"
```

**ページネーション:** SDK は非同期イテレーションに対応しています。手動の場合は `?per_page=100&page=1` クエリパラメーターを追加します。

## 静的アセット

**3 段階の手順:** セッションを作成 → ファイルをアップロード → Worker をデプロイ

### 1. アップロードセッションを作成
```bash
curl -X POST ".../scripts/$SCRIPT_NAME/assets-upload-session" \
  -H "Authorization: Bearer $API_TOKEN" \
  -d '{
    "manifest": {
      "/index.html": {"hash": "08f1dfda4574284ab3c21666d1ee8c7d4", "size": 1234}
    }
  }'
# Returns: jwt, buckets
```

**ハッシュ:** SHA-256 を先頭 16 バイト（32 桁の 16 進数）に切り詰めたもの

### 2. ファイルをアップロード
```bash
curl -X POST ".../workers/assets/upload?base64=true" \
  -H "Authorization: Bearer $UPLOAD_JWT" \
  -F '08f1dfda4574284ab3c21666d1ee8c7d4=<BASE64_CONTENT>'
# Returns: completion jwt
```

**複数のバケット:** 返されたすべてのバケット URL（通常は冗長化のため 2 つ）に、同じ JWT とハッシュを使ってアップロードします。

### 3. アセット付きでデプロイ
```bash
curl -X PUT ".../scripts/$SCRIPT_NAME" \
  -F 'metadata={
    "main_module": "index.js",
    "assets": {"jwt": "<COMPLETION_TOKEN>"},
    "bindings": [{"type": "assets", "name": "ASSETS"}]
  };type=application/json' \
  -F 'index.js=export default {...};type=application/javascript+module'
```

**アセットの分離:** デフォルトでは、アセットは名前空間内で共有されます。顧客ごとに分離するには、ハッシュにソルトを追加します: `sha256(customerId + fileContents).slice(0, 32)`

## Dispatch Workers

### サブドメインルーティング
```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const userWorkerName = new URL(request.url).hostname.split(".")[0];
    const userWorker = env.DISPATCHER.get(userWorkerName);
    return await userWorker.fetch(request);
  },
};
```

### パスルーティング
```typescript
const pathParts = new URL(request.url).pathname.split("/").filter(Boolean);
const userWorker = env.DISPATCHER.get(pathParts[0]);
return await userWorker.fetch(request);
```

### KV ルーティング
```typescript
const hostname = new URL(request.url).hostname;
const userWorkerName = await env.ROUTING_KV.get(hostname);
const userWorker = env.DISPATCHER.get(userWorkerName);
return await userWorker.fetch(request);
```

## アウトバウンド Worker

ユーザー Worker からの外部 fetch を制御します:

### 設定
```typescript
const userWorker = env.DISPATCHER.get(
  workerName, {},
  { outbound: { customer_context: { customer_name: workerName, url: request.url } } }
);
```

### 実装
```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const customerName = env.customer_name;
    const url = new URL(request.url);
    
    // Block domains
    if (["malicious.com"].some(d => url.hostname.includes(d))) {
      return new Response("Blocked", { status: 403 });
    }
    
    // Inject auth
    if (url.hostname === "api.example.com") {
      const headers = new Headers(request.headers);
      headers.set("Authorization", `Bearer ${generateJWT(customerName)}`);
      return fetch(new Request(request, { headers }));
    }
    
    return fetch(request);
  },
};
```

**注:** DO／mTLS の fetch はインターセプトしません。

[README.md](./README.md)、[configuration.md](./configuration.md)、[patterns.md](./patterns.md)、[gotchas.md](./gotchas.md) を参照