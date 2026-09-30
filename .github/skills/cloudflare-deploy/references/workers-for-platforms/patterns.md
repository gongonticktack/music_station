# マルチテナントのパターン

## プラン別の課金

```typescript
interface Env {
  DISPATCHER: DispatchNamespace;
  CUSTOMERS_KV: KVNamespace;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const userWorkerName = new URL(request.url).hostname.split(".")[0];
    const customerPlan = await env.CUSTOMERS_KV.get(userWorkerName);
    
    const plans = {
      enterprise: { cpuMs: 50, subRequests: 50 },
      pro: { cpuMs: 20, subRequests: 20 },
      free: { cpuMs: 10, subRequests: 5 },
    };
    const limits = plans[customerPlan as keyof typeof plans] || plans.free;
    
    const userWorker = env.DISPATCHER.get(userWorkerName, {}, { limits });
    return await userWorker.fetch(request);
  },
};
```

## リソースの分離

**完全な分離:** 顧客ごとに固有のリソースを作成する
- 顧客ごとにKV名前空間を用意
- 顧客ごとにD1データベースを用意
- 顧客ごとにR2バケットを用意

```typescript
const bindings = [{
  type: "kv_namespace",
  name: "USER_KV",
  namespace_id: `customer-${customerId}-kv`
}];
```

## ホスト名によるルーティング

### ワイルドカードルート（推奨）
SaaSドメイン上の`*/*`ルートを設定 → ディスパッチWorkerへ

**メリット:**
- サブドメインと独自のバニティドメインに対応
- ルートごとの上限なし（通常のWorkersは100ルートまで）
- プログラムから制御可能
- どのDNSプロキシ設定でも動作

**設定手順:**
1. Cloudflare for SaaSのカスタムホスト名を設定
2. フォールバックオリジン（Workerがオリジンの場合はダミーの`A 192.0.2.0`）を設定
3. SaaSドメインを指すDNS CNAMEを設定
4. `*/*`ルートを設定 → ディスパッチWorkerへ
5. ディスパッチWorkerにルーティングロジックを実装

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const hostname = new URL(request.url).hostname;
    const hostnameData = await env.ROUTING_KV.get(`hostname:${hostname}`, { type: "json" });
    
    if (!hostnameData?.workerName) {
      return new Response("Hostname not configured", { status: 404 });
    }
    
    const userWorker = env.DISPATCHER.get(hostnameData.workerName);
    return await userWorker.fetch(request);
  },
};
```

### サブドメインのみ
1. ワイルドカードDNS: `*.saas.com` → オリジン
2. ルート: `*.saas.com/*` → ディスパッチWorker
3. ルーティング用にサブドメインを抽出

### Orange-to-Orange（O2O）の動作

顧客がCloudflareを使用し、WorkersドメインにCNAMEを設定している場合:

| シナリオ | 動作 | ルートパターン |
|----------|----------|---------------|
| 顧客がCloudflareを使用していない | 標準ルーティング | `*/*`または`*.domain.com/*` |
| 顧客がCloudflareを使用（プロキシ済みCNAME） | エッジでWorkerを呼び出す | `*/*`が必要 |
| 顧客がCloudflareを使用（DNSのみのCNAME） | 標準ルーティング | どのルートでも動作 |

**推奨:** O2Oの動作を一貫させるため、常に`*/*`ワイルドカードを使用してください。

### カスタムメタデータによるルーティング

Cloudflare for SaaSの場合: カスタムホスト名の`custom_metadata`にWorker名を保存し、ディスパッチWorkerで取得してリクエストをルーティングします。カスタムホスト名は自分のドメインのサブドメインである必要があります。

## 可観測性

### Logpush
- ディスパッチWorkerで有効にすると、すべてのユーザーWorkerのログを収集
- `Outcome`または`Script Name`で絞り込み

### Tail Workers
- カスタム形式によるリアルタイムログ
- HTTPステータス、`console.log()`、例外、診断情報を受信

### Analytics Engine
```typescript
// Track violations
env.ANALYTICS.writeDataPoint({
  indexes: [customerName],
  blobs: ["cpu_limit_exceeded"],
});
```

### GraphQL
```graphql
query {
  viewer {
    accounts(filter: {accountTag: $accountId}) {
      workersInvocationsAdaptive(filter: {dispatchNamespaceName: "production"}) {
        sum { requests errors cpuTime }
      }
    }
  }
}
```

## ユースケースの実装

### AIコード実行
```typescript
async function deployGeneratedCode(name: string, code: string) {
  const file = new File([code], `${name}.mjs`, { type: "application/javascript+module" });
  await client.workersForPlatforms.dispatch.namespaces.scripts.update("production", name, {
    account_id: accountId,
    metadata: { main_module: `${name}.mjs`, tags: [name, "ai-generated"] },
    files: [file],
  });
}

// Short limits for untrusted code
const userWorker = env.DISPATCHER.get(sessionId, {}, { limits: { cpuMs: 5, subRequests: 3 } });
```

**VibeSDK:** AIを活用したコード生成とデプロイのプラットフォームについては、[VibeSDK](https://github.com/cloudflare/vibesdk)を参照してください。AIによる生成、サンドボックスでの実行、ライブプレビュー、デプロイに対応しています。

参考: [AI Vibe Coding Platform Architecture](https://developers.cloudflare.com/reference-architecture/diagrams/ai/ai-vibe-coding-platform/)

### エッジ関数プラットフォーム
```typescript
// Route: /customer-id/function-name
const [customerId, functionName] = new URL(request.url).pathname.split("/").filter(Boolean);
const workerName = `${customerId}-${functionName}`;
const userWorker = env.DISPATCHER.get(workerName);
```

### ウェブサイトビルダー
- 静的アセットとWorkerコードをデプロイ
- 実装の詳細は[api.md](./api.md#static-assets)を参照
- アセット分離にはソルト付きハッシュを使用

## ベストプラクティス

### アーキテクチャ
- 環境（本番、ステージング）ごとに名前空間を1つ用意
- プラットフォームのロジック（認証、レート制限、検証）はディスパッチWorkerに配置
- 分離は自動的に行われる（共有キャッシュなし、信頼しないモード）

### ルーティング
- `*/*`ワイルドカードルートを使用
- マッピングをKVに保存
- Workerが見つからない場合も適切に処理

### 制限とセキュリティ
- プランごとにカスタム制限を設定
- Analytics Engineで違反を追跡
- エグレス制御にはアウトバウンドWorkerを使用
- レスポンスをサニタイズ

[README.md](./README.md)、[configuration.md](./configuration.md)、[api.md](./api.md)、[gotchas.md](./gotchas.md)を参照
