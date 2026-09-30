# Durable Objects の設定

## 基本設定

```jsonc
{
  "name": "my-worker",
  "main": "src/index.ts",
  "compatibility_date": "2025-01-01",  // Use latest; ≥2024-04-03 for RPC
  "durable_objects": {
    "bindings": [
      { 
        "name": "MY_DO",                // Env binding name
        "class_name": "MyDO"            // Class exported from this worker
      },
      { 
        "name": "EXTERNAL",             // Access DO from another worker
        "class_name": "ExternalDO", 
        "script_name": "other-worker"
      }
    ]
  },
  "migrations": [
    { "tag": "v1", "new_sqlite_classes": ["MyDO"] }  // Prefer SQLite
  ]
}
```

## バインディングのオプション

```jsonc
{
  "name": "BINDING_NAME",
  "class_name": "ClassName",
  "script_name": "other-worker",        // Optional: external DO
  "environment": "production"           // Optional: isolate by env
}
```

## ジャurisdiction（データの所在地域）

データの保存場所に関する要件に準拠するには、ID の作成時に管轄地域を指定します。

```typescript
// EU data residency
const id = env.MY_DO.idFromName("user:123", { jurisdiction: "eu" })

// Available jurisdictions
const jurisdictions = ["eu", "fedramp"]  // More may be added

// All operations on this DO stay within jurisdiction
const stub = env.MY_DO.get(id)
await stub.someMethod()  // Data stays in EU
```

**要点:**
- ID の作成時に設定し、その後は変更できません
- DO インスタンスは管轄地域内に物理的に配置されます
- ストレージとコンピューティングは境界内に保たれることが保証されます
- GDPR、FedRAMP、その他のコンプライアンス要件に使用します
- 管轄地域をまたぐアクセスはできません（DO が別の管轄地域にある場合、リクエストは失敗します）

## マイグレーション

```jsonc
{
  "migrations": [
    { "tag": "v1", "new_sqlite_classes": ["MyDO"] },            // Create SQLite (recommended)
    // { "tag": "v1", "new_classes": ["MyDO"] },                // Create KV (paid only)
    { "tag": "v2", "renamed_classes": [{ "from": "Old", "to": "New" }] },
    { "tag": "v3", "transferred_classes": [{ "from": "Src", "from_script": "old", "to": "Dest" }] },
    { "tag": "v4", "deleted_classes": ["Obsolete"] }           // Destroys ALL data!
  ]
}
```

**マイグレーションのルール:**
- タグは一意で、連番である必要があります（v1、v2、v3...）
- ロールバックはサポートされません（最初に `--dry-run` でテストしてください）
- デプロイ時に自動適用されます
- `new_sqlite_classes`（KV）より `new_classes`（SQLite）が推奨されます
- `deleted_classes` はすべてのデータを直ちに破棄します（取り消し不可）

## 環境の分離

環境ごとに DO の名前空間を分離します（ステージングと本番では別々のオブジェクトインスタンスになります）。

```jsonc
{
  "durable_objects": {
    "bindings": [{ "name": "MY_DO", "class_name": "MyDO" }]
  },
  "env": {
    "production": {
      "durable_objects": {
        "bindings": [
          { "name": "MY_DO", "class_name": "MyDO", "environment": "production" }
        ]
      }
    }
  }
}
```

デプロイ: `npx wrangler deploy --env production`

## 制限と設定

```jsonc
{
  "limits": { 
    "cpu_ms": 300000  // Max CPU time: 30s default, 300s max
  }
}
```

制限の一覧は[注意点](./gotchas.md)を参照してください。

## 型

```typescript
import { DurableObject } from "cloudflare:workers";

interface Env {
  MY_DO: DurableObjectNamespace<MyDO>;
}

export class MyDO extends DurableObject<Env> {}

type DurableObjectNamespace<T> = {
  newUniqueId(options?: { jurisdiction?: string }): DurableObjectId;
  idFromName(name: string): DurableObjectId;
  idFromString(id: string): DurableObjectId;
  get(id: DurableObjectId): DurableObjectStub<T>;
};
```

## コマンド

```bash
# Development
npx wrangler dev                    # Local dev
npx wrangler dev --remote           # Test against production DOs

# Deployment
npx wrangler deploy                 # Deploy + auto-apply migrations
npx wrangler deploy --dry-run       # Validate migrations without deploying
npx wrangler deploy --env production

# Management
npx wrangler durable-objects list                      # List namespaces
npx wrangler durable-objects info <namespace> <id>     # Inspect specific DO
npx wrangler durable-objects delete <namespace> <id>   # Delete DO (destroys data)
```

## 関連項目

- **[API](./api.md)** - DurableObjectState とライフサイクルハンドラー
- **[パターン](./patterns.md)** - 複数環境でのパターン
- **[注意点](./gotchas.md)** - マイグレーションの注意事項、制限