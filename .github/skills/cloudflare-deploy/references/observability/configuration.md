## 設定パターン

### Workers Logsを有効化

```jsonc
{
  "observability": {
    "enabled": true,
    "head_sampling_rate": 1  // 100% sampling (default)
  }
}
```

**ベストプラクティス**: インデックス作成を改善するため、構造化JSONログを使用してください。

```typescript
// Good - structured logging
console.log({ 
  user_id: 123, 
  action: "login", 
  status: "success",
  duration_ms: 45
});

// Avoid - unstructured string
console.log("user_id: 123 logged in successfully in 45ms");
```

### Workers Tracesを有効化

```jsonc
{
  "observability": {
    "traces": {
      "enabled": true,
      "head_sampling_rate": 0.05  // 5% sampling
    }
  }
}
```

**注**: デフォルトのサンプリング率は100%です。トラフィックの多いWorkersでは、より低いサンプリング率（0.01～0.1）を使用してください。

### Analytics Engineを設定

**Workerにバインド**:
```toml
# wrangler.toml
analytics_engine_datasets = [
  { binding = "ANALYTICS", dataset = "api_metrics" }
]
```

**データポイントを書き込む**:
```typescript
export interface Env {
  ANALYTICS: AnalyticsEngineDataset;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Track metrics
    env.ANALYTICS.writeDataPoint({
      blobs: ['customer_123', 'POST', '/api/v1/users'],
      doubles: [1, 245.5], // request_count, response_time_ms
      indexes: ['customer_123'] // for efficient filtering
    });
    
    return new Response('OK');
  }
}
```

### Tail Workersを設定

Tail Workersは、他のWorkersからログ/トレースを受け取り、絞り込み、変換、エクスポートを行います。

**セットアップ**:
```toml
# wrangler.toml
name = "log-processor"
main = "src/tail.ts"

[[tail_consumers]]
service = "my-worker" # Worker to tail
```

**Tail Workerの例**:
```typescript
export default {
  async tail(events: TraceItem[], env: Env, ctx: ExecutionContext) {
    // Filter errors only
    const errors = events.filter(event => 
      event.outcome === 'exception' || event.outcome === 'exceededCpu'
    );
    
    if (errors.length > 0) {
      // Send to external monitoring
      ctx.waitUntil(
        fetch('https://monitoring.example.com/errors', {
          method: 'POST',
          body: JSON.stringify(errors)
        })
      );
    }
  }
}
```

### Logpushを設定

ログを外部ストレージ（S3、R2、GCS、Azure、Datadogなど）に送信します。Business/Enterpriseプランが必要です。

**ダッシュボード経由**:
1. Analytics → Logs → Logpushに移動
2. 宛先の種類を選択
3. 認証情報とバケット/エンドポイントを入力
4. データセット（例: Workers Trace Events）を選択
5. フィルターとフィールドを設定

**API経由**:
```bash
curl -X POST "https://api.cloudflare.com/client/v4/accounts/{account_id}/logpush/jobs" \
  -H "Authorization: Bearer <API_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "workers-logs-to-s3",
    "destination_conf": "s3://my-bucket/logs?region=us-east-1",
    "dataset": "workers_trace_events",
    "enabled": true,
    "frequency": "high",
    "filter": "{\"where\":{\"and\":[{\"key\":\"ScriptName\",\"operator\":\"eq\",\"value\":\"my-worker\"}]}}"
  }'
```

### 環境ごとの設定

**開発環境**（詳細なログ、全件サンプリング）:
```jsonc
// wrangler.dev.jsonc
{
  "observability": {
    "enabled": true,
    "head_sampling_rate": 1.0,
    "traces": {
      "enabled": true
    }
  }
}
```

**本番環境**（サンプリング率を下げ、構造化ログを使用）:
```jsonc
// wrangler.prod.jsonc
{
  "observability": {
    "enabled": true,
    "head_sampling_rate": 0.1, // 10% sampling
    "traces": {
      "enabled": true
    }
  }
}
```

環境固有の設定でデプロイ:
```bash
wrangler deploy --config wrangler.prod.jsonc --env production
```