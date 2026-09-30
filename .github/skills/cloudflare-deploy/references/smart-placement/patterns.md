# Smart Placement のパターン

## データベースにアクセスするバックエンド Worker

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const user = await env.DATABASE.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first();
    const orders = await env.DATABASE.prepare('SELECT * FROM orders WHERE user_id = ?').bind(userId).all();
    return Response.json({ user, orders });
  }
};
```

```jsonc
{ "placement": { "mode": "smart" }, "d1_databases": [{ "binding": "DATABASE", "database_id": "xxx" }] }
```

## フロントエンドとバックエンドの分離（Service Bindings）

**フロントエンド:** ユーザーへの高速な応答のため、エッジで実行
**バックエンド:** データベースの近くで Smart Placement により実行

```typescript
// Frontend Worker - routes requests to backend
interface Env {
  BACKEND: Fetcher;  // Service Binding to backend Worker
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (new URL(request.url).pathname.startsWith('/api/')) {
      return env.BACKEND.fetch(request);  // Forward to backend
    }
    return new Response('Frontend content');
  }
};

// Backend Worker - database operations
interface BackendEnv {
  DATABASE: D1Database;
}

export default {
  async fetch(request: Request, env: BackendEnv): Promise<Response> {
    const data = await env.DATABASE.prepare('SELECT * FROM table').all();
    return Response.json(data);
  }
};
```

**重要:** 上記に示した fetch ベースの Service Bindings を使用してください。`WorkerEntrypoint` を使った RPC の場合、Smart Placement はそれらのメソッド呼び出しを最適化しません。影響を受けるのは `fetch` ハンドラーだけです。

**RPC と Fetch の違い（重要）:** Smart Placement が機能するのは fetch ベースのバインディングのみで、RPC では機能しません。

```typescript
// ❌ RPC - Smart Placement has NO EFFECT on backend RPC methods
export class BackendRPC extends WorkerEntrypoint {
  async getData() {
    // ALWAYS runs at edge, Smart Placement ignored
    return await this.env.DATABASE.prepare('SELECT * FROM table').all();
  }
}

// ✅ Fetch - Smart Placement WORKS
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Runs close to DATABASE when Smart Placement enabled
    const data = await env.DATABASE.prepare('SELECT * FROM table').all();
    return Response.json(data);
  }
};
```

## 外部 API との連携

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const apiUrl = 'https://api.partner.com';
    const headers = { 'Authorization': `Bearer ${env.API_KEY}` };
    
    const [profile, transactions] = await Promise.all([
      fetch(`${apiUrl}/profile`, { headers }),
      fetch(`${apiUrl}/transactions`, { headers })
    ]);
    
    return Response.json({ 
      profile: await profile.json(), 
      transactions: await transactions.json()
    });
  }
};
```

## SSR / API ゲートウェイのパターン

```typescript
// Frontend (edge) - auth/routing close to user
export default {
  async fetch(request: Request, env: Env) {
    if (!request.headers.get('Authorization')) {
      return new Response('Unauthorized', { status: 401 });
    }
    const data = await env.BACKEND.fetch(request);
    return new Response(renderPage(await data.json()), { 
      headers: { 'Content-Type': 'text/html' } 
    });
  }
};

// Backend (Smart Placement) - DB operations close to data
export default {
  async fetch(request: Request, env: Env) {
    const data = await env.DATABASE.prepare('SELECT * FROM pages WHERE id = ?').bind(pageId).first();
    return Response.json(data);
  }
};
```

## Smart Placement を使った Durable Objects

**重要な原則:** Smart Placement は Durable Objects が実行される場所を制御しません。DO は常に、指定されたリージョン（管轄区域または smart location のヒントに基づく）で実行されます。

**Smart Placement が影響する対象:** 複数の DO を呼び出すコーディネーター Worker の `fetch` ハンドラーの実行場所です。

**パターン:** 複数の DO からデータを集約するコーディネーター Worker で Smart Placement を有効にします:

```typescript
// Worker with Smart Placement - aggregates data from multiple DOs
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const userId = new URL(request.url).searchParams.get('user');
    
    // Get DO stubs
    const userDO = env.USER_DO.get(env.USER_DO.idFromName(userId));
    const analyticsID = env.ANALYTICS_DO.idFromName(`analytics-${userId}`);
    const analyticsDO = env.ANALYTICS_DO.get(analyticsID);
    
    // Fetch from multiple DOs
    const [userData, analyticsData] = await Promise.all([
      userDO.fetch(new Request('https://do/profile')),
      analyticsDO.fetch(new Request('https://do/stats'))
    ]);
    
    return Response.json({
      user: await userData.json(),
      analytics: await analyticsData.json()
    });
  }
};
```

```jsonc
// wrangler.jsonc
{
  "placement": { "mode": "smart" },
  "durable_objects": {
    "bindings": [
      { "name": "USER_DO", "class_name": "UserDO" },
      { "name": "ANALYTICS_DO", "class_name": "AnalyticsDO" }
    ]
  }
}
```

**効果がある場合:** 
- Worker の `fetch` ハンドラーが DO のリージョンに近い場所で実行され、複数の DO 呼び出しによるネットワーク遅延が減少する
- DO が地理的に集中している場合や、特定の管轄区域にある場合に最も効果的
- コーディネーターが複数の DO を逐次または並行して呼び出す場合に有効

**効果がない場合:**
- DO が世界中に分散している（Worker の最適な実行場所を1か所に定められない）
- Worker が呼び出す DO が1つだけ
- DO の呼び出し頻度が低い、またはキャッシュされている

## ベストプラクティス

- フルスタックアプリを分割する: フロントエンドはエッジで、バックエンドは Smart Placement を有効にして実行
- fetch ベースの Service Bindings を使う（RPC ではなく）
- バックエンドのロジック（API、データ集約、DB 操作）で有効にする
- 静的コンテンツ、エッジロジック、RPC メソッド、`run_worker_first` を使う Pages では有効にしない
- 分析に15分以上待ち、`placement_status = SUCCESS` を確認する
