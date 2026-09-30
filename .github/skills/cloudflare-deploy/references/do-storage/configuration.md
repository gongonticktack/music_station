# DO ストレージの設定

## SQLite バックエンド（推奨）

**wrangler.jsonc:**
```jsonc
{
  "migrations": [
    {
      "tag": "v1",
      "new_sqlite_classes": ["Counter", "Session", "RateLimiter"]
    }
  ]
}
```

**マイグレーションのライフサイクル:** マイグレーションはデプロイごとに1回実行されます。既存の DO インスタンスには、次回の呼び出し時に新しいストレージバックエンドが適用されます。クラスの名前変更や削除には、`renamed_classes` または `deleted_classes` のエントリが必要です。

## KV バックエンド（レガシー）

**wrangler.jsonc:**
```jsonc
{
  "migrations": [
    {
      "tag": "v1",
      "new_classes": ["OldCounter"]
    }
  ]
}
```

## TypeScript の設定

```typescript
export class MyDurableObject extends DurableObject {
  sql: SqlStorage;
  
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;
    
    // Initialize schema
    this.sql.exec(`
      CREATE TABLE IF NOT EXISTS users(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT UNIQUE
      );
    `);
  }
}

// Binding
interface Env {
  MY_DO: DurableObjectNamespace;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const id = env.MY_DO.idFromName('singleton');
    const stub = env.MY_DO.get(id);
    
    // Modern RPC: call methods directly (recommended)
    const result = await stub.someMethod();
    return Response.json(result);
    
    // Legacy: forward request (still works)
    // return stub.fetch(request);
  }
}
```

## CPU 制限

```jsonc
{
  "limits": {
    "cpu_ms": 300000  // 5 minutes (default 30s)
  }
}
```

## ロケーションの制御

```typescript
// Jurisdiction (GDPR/FedRAMP)
const euNamespace = env.MY_DO.jurisdiction("eu");
const id = euNamespace.newUniqueId();
const stub = euNamespace.get(id);

// Location hint (best effort)
const stub = env.MY_DO.get(id, { locationHint: "enam" });
// Hints: wnam, enam, sam, weur, eeur, apac, oc, afr, me
```

## 初期化

```typescript
export class Counter extends DurableObject {
  value: number;
  
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    
    // Block concurrent requests during init
    ctx.blockConcurrencyWhile(async () => {
      this.value = (await ctx.storage.get("value")) || 0;
    });
  }
}
```
