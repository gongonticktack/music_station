# ワークフローの構成

## wrangler.jsonc の設定

```jsonc
{
  "name": "my-worker",
  "main": "src/index.ts",
  "compatibility_date": "2025-01-01",  // Use current date for new projects
  "observability": {
    "enabled": true  // Enables Workflows dashboard + structured logs
  },
  "workflows": [
    {
      "name": "my-workflow",           // Workflow name
      "binding": "MY_WORKFLOW",        // Env binding
      "class_name": "MyWorkflow"      // TS class name
      // "script_name": "other-worker" // For cross-script calls
    }
  ],
  "limits": {
    "cpu_ms": 300000  // 5 min max (default 30s)
  }
}
```

## ステップの構成

```typescript
// Basic step
const data = await step.do('step name', async () => ({ result: 'value' }));

// With retry config
await step.do('api call', {
  retries: {
    limit: 10,              // Default: 5, or Infinity
    delay: '10 seconds',    // Default: 10000ms
    backoff: 'exponential'  // constant | linear | exponential
  },
  timeout: '30 minutes'     // Per-attempt timeout (default: 10min)
}, async () => {
  const res = await fetch('https://api.example.com/data');
  if (!res.ok) throw new Error('Failed');
  return res.json();
});
```

### 並列ステップ
```typescript
const [user, settings] = await Promise.all([
  step.do('fetch user', async () => this.env.KV.get(`user:${id}`)),
  step.do('fetch settings', async () => this.env.KV.get(`settings:${id}`))
]);
```

### 条件付きステップ
```typescript
const config = await step.do('fetch config', async () => 
  this.env.KV.get('flags', { type: 'json' })
);

// ✅ Deterministic (based on step output)
if (config.enableEmail) {
  await step.do('send email', async () => sendEmail());
}

// ❌ Non-deterministic (Date.now outside step)
if (Date.now() > deadline) { /* BAD */ }
```

### 動的ステップ（ループ）
```typescript
const files = await step.do('list files', async () => 
  this.env.BUCKET.list()
);

for (const file of files.objects) {
  await step.do(`process ${file.key}`, async () => {
    const obj = await this.env.BUCKET.get(file.key);
    return processData(await obj.arrayBuffer());
  });
}
```

## 複数のワークフロー

```jsonc
{
  "workflows": [
    {"name": "user-onboarding", "binding": "USER_ONBOARDING", "class_name": "UserOnboarding"},
    {"name": "data-processing", "binding": "DATA_PROCESSING", "class_name": "DataProcessing"}
  ]
}
```

各クラスは、それぞれ独自の `Params` 型を持つ `WorkflowEntrypoint` を継承します。

## スクリプト間のバインディング

Worker A でワークフローを定義します。Worker B は `script_name` を追加して呼び出します。

```jsonc
// Worker B (caller)
{
  "workflows": [{
    "name": "billing-workflow",
    "binding": "BILLING",
    "script_name": "billing-worker"  // Points to Worker A
  }]
}
```

## バインディング

ワークフローは `this.env` を介して Cloudflare バインディングにアクセスします。

```typescript
type Env = {
  MY_WORKFLOW: Workflow;
  KV: KVNamespace;
  DB: D1Database;
  BUCKET: R2Bucket;
  AI: Ai;
  VECTORIZE: VectorizeIndex;
};

await step.do('use bindings', async () => {
  const kv = await this.env.KV.get('key');
  const db = await this.env.DB.prepare('SELECT * FROM users').first();
  const file = await this.env.BUCKET.get('file.txt');
  const ai = await this.env.AI.run('@cf/meta/llama-2-7b-chat-int8', { prompt: 'Hi' });
});
```

## Pages Functions のバインディング

Pages Functions はサービスバインディングを介してワークフローをトリガーできます。

```typescript
// functions/_middleware.ts
export const onRequest: PagesFunction<Env> = async ({ env, request }) => {
  const instance = await env.MY_WORKFLOW.create({
    params: { url: request.url }
  });
  return new Response(`Started ${instance.id}`);
};
```

wrangler.jsonc の `service_bindings` の下で設定します。

参照: [api.md](./api.md)、[patterns.md](./patterns.md)
