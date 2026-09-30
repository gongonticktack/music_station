# 設定

## Wrangler のセットアップ

```jsonc
{
  "name": "my-agents-app",
  "durable_objects": {
    "bindings": [
      {"name": "MyAgent", "class_name": "MyAgent"}
    ]
  },
  "migrations": [
    {"tag": "v1", "new_sqlite_classes": ["MyAgent"]}
  ],
  "ai": {
    "binding": "AI"
  }
}
```

## 環境バインディング

**型安全な書き方:**

```typescript
interface Env {
  AI?: Ai;                              // Workers AI
  MyAgent?: DurableObjectNamespace<MyAgent>;
  ChatAgent?: DurableObjectNamespace<ChatAgent>;
  DB?: D1Database;                      // D1 database
  KV?: KVNamespace;                     // KV storage
  R2?: R2Bucket;                        // R2 bucket
  OPENAI_API_KEY?: string;              // Secrets
  GITHUB_CLIENT_ID?: string;            // MCP OAuth credentials
  GITHUB_CLIENT_SECRET?: string;
  QUEUE?: Queue;                        // Queues
}
```

**推奨事項:** 型安全性を確保するため、すべての DO バインディングを Env インターフェースで定義します。

## デプロイ

```bash
# Local dev
npx wrangler dev

# Deploy production
npx wrangler deploy

# Set secrets
npx wrangler secret put OPENAI_API_KEY
```

## Agent のルーティング

**推奨: ルーティングヘルパーを使用する**

```typescript
import { routeAgent } from "agents";

export default {
  fetch(request: Request, env: Env) {
    return routeAgent(request, env);
  }
}
```

このヘルパーは、URL パターンに基づいてリクエストを自動的に Agent へルーティングします。

**手動ルーティング（高度な設定）:**

```typescript
export default {
  async fetch(request: Request, env: Env) {
    const url = new URL(request.url);
    
    // Named ID (deterministic)
    const id = env.MyAgent.idFromName("user-123");
    
    // Random ID (from URL param)
    // const id = env.MyAgent.idFromString(url.searchParams.get("id"));
    
    const stub = env.MyAgent.get(id);
    return stub.fetch(request);
  }
}
```

**複数 Agent のセットアップ:**

```typescript
import { routeAgent } from "agents";

export default {
  fetch(request: Request, env: Env) {
    const url = new URL(request.url);
    
    // Route by path
    if (url.pathname.startsWith("/chat")) {
      return routeAgent(request, env, "ChatAgent");
    }
    if (url.pathname.startsWith("/task")) {
      return routeAgent(request, env, "TaskAgent");
    }
    
    return new Response("Not found", { status: 404 });
  }
}
```

## メールのルーティング

**コードの設定:**

```typescript
import { routeAgentEmail } from "agents";

export default {
  fetch: (req: Request, env: Env) => routeAgent(req, env),
  email: (message: ForwardableEmailMessage, env: Env) => {
    return routeAgentEmail(message, env);
  }
}
```

**ダッシュボードの設定:**

Cloudflare ダッシュボードでメールのルーティングを設定します。

```
Destination: Workers with Durable Objects
Worker: my-agents-app
```

続いて、Agent 内でメールを処理します。

```typescript
export class EmailAgent extends Agent<Env> {
  async onEmail(email: AgentEmail) {
    const text = await email.text();
    // Process email
  }
}
```

## AI Gateway（任意）

```typescript
// Enable caching/routing through AI Gateway
const response = await this.env.AI.run(
  "@cf/meta/llama-3.1-8b-instruct",
  { prompt },
  {
    gateway: {
      id: "my-gateway-id",
      skipCache: false,
      cacheTtl: 3600
    }
  }
);
```

## MCP の設定（任意）

Model Context Protocol を介してツールを公開する場合:

```typescript
// wrangler.jsonc - Add MCP OAuth secrets
{
  "vars": {
    "MCP_SERVER_URL": "https://mcp.example.com"
  }
}

// Set secrets via CLI
// npx wrangler secret put GITHUB_CLIENT_ID
// npx wrangler secret put GITHUB_CLIENT_SECRET
```

続いて、Agent のコードで登録します（api.md の MCP セクションを参照）。
