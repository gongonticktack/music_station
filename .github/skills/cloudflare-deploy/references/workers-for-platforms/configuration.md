# 設定

## Dispatch Namespace バインディング

### wrangler.jsonc
```jsonc
{
  "$schema": "./node_modules/wrangler/config-schema.json",
  "dispatch_namespaces": [{
    "binding": "DISPATCHER",
    "namespace": "production"
  }]
}
```

## Worker 分離モード

セキュリティのため、名前空間内の Workers はデフォルトで**非信頼モード**で実行されます。
- `request.cf` オブジェクトにはアクセスできません
- Worker ごとにキャッシュが分離されます（共有キャッシュなし）
- `caches.default` は無効です

### 信頼モードを有効にする

すべてのコードを管理できる内部プラットフォームの場合:

```bash
curl -X PUT \
  "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/dispatch/namespaces/$NAMESPACE" \
  -H "Authorization: Bearer $API_TOKEN" \
  -d '{"name": "'$NAMESPACE'", "trusted_workers": true}'
```

**注意事項:**
- 名前空間内の Workers はキャッシュを共有します（キャッシュキーのプレフィックスを使用してください: `customer-${id}:${key}`）
- `request.cf` オブジェクトにアクセスできます
- 信頼モードを有効にした後、既存の Workers を再デプロイしてください

**使用する場面:** 内部プラットフォーム、A/B テスト用プラットフォーム、位置情報データが必要な場合


### Outbound Worker を使用する場合
```jsonc
{
  "dispatch_namespaces": [{
    "binding": "DISPATCHER",
    "namespace": "production",
    "outbound": {
      "service": "outbound-worker",
      "parameters": ["customer_context"]
    }
  }]
}
```

## Wrangler コマンド

```bash
wrangler dispatch-namespace list
wrangler dispatch-namespace get production
wrangler dispatch-namespace create production
wrangler dispatch-namespace delete staging
wrangler dispatch-namespace rename old new
```

## カスタム制限

呼び出しごとに CPU 時間とサブリクエストの上限を設定します。

```typescript
const userWorker = env.DISPATCHER.get(
  workerName,
  {},
  {
    limits: { 
      cpuMs: 10,        // Max CPU ms
      subRequests: 5    // Max fetch() calls
    }
  }
);
```

制限超過を処理します。
```typescript
try {
  return await userWorker.fetch(request);
} catch (e) {
  if (e.message.includes("CPU time limit")) {
    return new Response("CPU limit exceeded", { status: 429 });
  }
  throw e;
}
```

## 静的アセット

Workers と一緒に HTML/CSS/画像をデプロイします。アップロード手順については [api.md](./api.md#static-assets) を参照してください。

### Wrangler
```jsonc
{
  "name": "customer-site",
  "main": "./src/index.js",
  "assets": {
    "directory": "./public",
    "binding": "ASSETS"
  }
}
```

```bash
npx wrangler deploy --name customer-site --dispatch-namespace production
```

### ダッシュボードからのデプロイ

CLI の代わりに、次の手順で行います。

1. ダッシュボードで Worker ファイルをアップロードする
2. `--dispatch-namespace` フラグを追加する: `wrangler deploy --dispatch-namespace production`
3. または、wrangler.jsonc の `dispatch_namespaces` の下で設定する

REST API または SDK を使ったプログラムによるデプロイについては、[api.md](./api.md) を参照してください。

## タグ

Workers を整理・検索します（スクリプトあたり最大 8 個）。

```bash
# Set tags
curl -X PUT ".../tags" -d '["customer-123", "pro", "production"]'

# Filter by tag
curl ".../scripts?tags=production%3Ayes"

# Delete by tag
curl -X DELETE ".../scripts?tags=customer-123%3Ayes"
```

よく使われるパターン: `customer-123`, `free|pro|enterprise`, `production|staging`

## バインディング

**サポートされているバインディングの種類:** KV、D1、R2、Durable Objects、Analytics Engine、Service、Assets、Queue、Vectorize、Hyperdrive、Workflow、AI、Browser など、合計 29 種類です。

API メタデータで追加します（[api.md](./api.md#deploy-with-bindings) を参照）:
```json
{
  "bindings": [
    {"type": "kv_namespace", "name": "USER_KV", "namespace_id": "..."},
    {"type": "r2_bucket", "name": "STORAGE", "bucket_name": "..."},
    {"type": "d1", "name": "DB", "id": "..."}
  ]
}
```

既存のバインディングを保持します。
```json
{
  "bindings": [{"type": "r2_bucket", "name": "STORAGE", "bucket_name": "new"}],
  "keep_bindings": ["kv_namespace", "d1"]  // Preserves existing bindings of these types
}
```

バインディングの種類の完全な一覧については、[bindings](../bindings/) のドキュメントを参照してください。

[README.md](./README.md)、[api.md](./api.md)、[patterns.md](./patterns.md)、[gotchas.md](./gotchas.md) を参照してください。
