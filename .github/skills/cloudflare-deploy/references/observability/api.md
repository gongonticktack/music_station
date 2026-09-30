## APIリファレンス

### GraphQL Analytics API

**エンドポイント**: `https://api.cloudflare.com/client/v4/graphql`

**Workersメトリクスのクエリ**:
```graphql
query {
  viewer {
    accounts(filter: { accountTag: $accountId }) {
      workersInvocationsAdaptive(
        limit: 100
        filter: {
          datetime_geq: "2025-01-01T00:00:00Z"
          datetime_leq: "2025-01-31T23:59:59Z"
          scriptName: "my-worker"
        }
      ) {
        sum {
          requests
          errors
          subrequests
        }
        quantiles {
          cpuTimeP50
          cpuTimeP99
          wallTimeP50
          wallTimeP99
        }
      }
    }
  }
}
```

### Analytics Engine SQL API

**エンドポイント**: `https://api.cloudflare.com/client/v4/accounts/{account_id}/analytics_engine/sql`

**認証**: `Authorization: Bearer <API_TOKEN>`（Account Analytics Read権限）

**一般的なクエリ**:

```sql
-- List all datasets
SHOW TABLES;

-- Time-series aggregation (5-minute buckets)
SELECT
  intDiv(toUInt32(timestamp), 300) * 300 AS time_bucket,
  blob1 AS endpoint,
  SUM(_sample_interval) AS total_requests,
  AVG(double1) AS avg_response_time_ms
FROM api_metrics
WHERE timestamp >= NOW() - INTERVAL '24' HOUR
GROUP BY time_bucket, endpoint
ORDER BY time_bucket DESC;

-- Top customers by usage
SELECT
  index1 AS customer_id,
  SUM(_sample_interval * double1) AS total_api_calls,
  AVG(double2) AS avg_response_time_ms
FROM api_usage
WHERE timestamp >= NOW() - INTERVAL '7' DAY
GROUP BY customer_id
ORDER BY total_api_calls DESC
LIMIT 100;

-- Error rate analysis
SELECT
  blob1 AS error_type,
  COUNT(*) AS occurrences,
  MAX(timestamp) AS last_seen
FROM error_tracking
WHERE timestamp >= NOW() - INTERVAL '1' HOUR
GROUP BY error_type
ORDER BY occurrences DESC;
```

### Console Logging API

**メソッド**:
```typescript
// Standard methods (all appear in Workers Logs)
console.log('info message');
console.info('info message');
console.warn('warning message');
console.error('error message');
console.debug('debug message');

// Structured logging (recommended)
console.log({
  level: 'info',
  user_id: '123',
  action: 'checkout',
  amount: 99.99,
  currency: 'USD'
});
```

**ログレベル**: すべてのconsoleメソッドがログを生成します。絞り込みには構造化フィールドを使用してください。
```typescript
console.log({ 
  level: 'error', 
  message: 'Payment failed', 
  error_code: 'CARD_DECLINED' 
});
```

### Analytics Engineバインディングの型

```typescript
interface AnalyticsEngineDataset {
  writeDataPoint(event: AnalyticsEngineDataPoint): void;
}

interface AnalyticsEngineDataPoint {
  // Indexed strings (use for filtering/grouping)
  indexes?: string[];
  
  // Non-indexed strings (metadata, IDs, URLs)
  blobs?: string[];
  
  // Numeric values (counts, durations, amounts)
  doubles?: number[];
}
```

**フィールドの上限**:
- インデックスは最大20個
- blobsは最大20個
- doublesは最大20個
- 1リクエストあたりの`writeDataPoint`呼び出しは最大25回

### Tail Consumerのイベント型

```typescript
interface TraceItem {
  event: TraceEvent;
  logs: TraceLog[];
  exceptions: TraceException[];
  scriptName?: string;
}

interface TraceEvent {
  outcome: 'ok' | 'exception' | 'exceededCpu' | 'exceededMemory' | 'unknown';
  cpuTime: number; // microseconds
  wallTime: number; // microseconds
}

interface TraceLog {
  timestamp: number;
  level: 'log' | 'info' | 'debug' | 'warn' | 'error';
  message: any; // string or structured object
}

interface TraceException {
  name: string;
  message: string;
  timestamp: number;
}
```