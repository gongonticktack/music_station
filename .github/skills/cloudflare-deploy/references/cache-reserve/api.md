# Cache Reserve API

## Workers との連携

```
┌────────────────────────────────────────────────────────────────┐
│ CRITICAL: Workers Cache API ≠ Cache Reserve                   │
│                                                                │
│ • Workers caches.default / cache.put() → edge cache ONLY      │
│ • Cache Reserve → zone-level setting, automatic, no per-req   │
│ • You CANNOT selectively write to Cache Reserve from Workers  │
│ • Cache Reserve works with standard fetch(), not cache.put()  │
└────────────────────────────────────────────────────────────────┘
```

Cache Reserve はリクエスト単位の API ではなく、**ゾーンレベルの設定**です。ゾーンで有効にすると、自動的に機能します。

### 標準の fetch（推奨）

```typescript
// Cache Reserve works automatically via standard fetch
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Standard fetch uses Cache Reserve automatically
    return await fetch(request);
  }
};
```

### Cache API の制限

**重要**: `cache.put()` は Cache Reserve または Tiered Cache と**互換性がありません**。

```typescript
// ❌ WRONG: cache.put() bypasses Cache Reserve
const cache = caches.default;
let response = await cache.match(request);
if (!response) {
  response = await fetch(request);
  await cache.put(request, response.clone()); // Bypasses Cache Reserve!
}

// ✅ CORRECT: Use standard fetch for Cache Reserve compatibility
return await fetch(request);

// ✅ CORRECT: Use Cache API only for custom cache namespaces
const customCache = await caches.open('my-custom-cache');
let response = await customCache.match(request);
if (!response) {
  response = await fetch(request);
  await customCache.put(request, response.clone()); // Custom cache OK
}
```

## キャッシュのパージと管理

### URL によるパージ（即時）

```typescript
// Purge specific URL from Cache Reserve immediately
const purgeCacheReserveByURL = async (
  zoneId: string,
  apiToken: string,
  urls: string[]
) => {
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/zones/${zoneId}/purge_cache`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ files: urls })
    }
  );
  return await response.json();
};

// Example usage
await purgeCacheReserveByURL('zone123', 'token456', [
  'https://example.com/image.jpg',
  'https://example.com/video.mp4'
]);
```

### タグ／ホスト／プレフィックスによるパージ（再検証）

```typescript
// Purge by cache tag - forces revalidation, not immediate removal
await fetch(
  `https://api.cloudflare.com/client/v4/zones/${zoneId}/purge_cache`,
  {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${apiToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ tags: ['tag1', 'tag2'] })
  }
);
```

**パージの動作:**
- **URL によるパージ**: Cache Reserve とエッジキャッシュから即時に削除
- **タグ／ホスト／プレフィックスによるパージ**: 再検証のみ。アセットはストレージに残り、料金が発生し続けます

### Cache Reserve データをすべて消去

```typescript
// Requires Cache Reserve OFF first
await fetch(
  `https://api.cloudflare.com/client/v4/zones/${zoneId}/cache/cache_reserve_clear`,
  { method: 'POST', headers: { 'Authorization': `Bearer ${apiToken}` } }
);

// Check status: GET same endpoint returns { state: "In-progress" | "Completed" }
```

**手順**: Cache Reserve を無効にする → 消去エンドポイントを呼び出す → 最大 24 時間待つ → 再度有効にする

## モニタリングと分析

### ダッシュボードの分析

**Caching > Cache Reserve** に移動すると、次の項目を確認できます。

- **エグレス削減量**: Cache Reserve から配信された総バイト数と、オリジンのエグレスコストの削減額
- **配信リクエスト数**: Cache Reserve のヒット数とミス数の内訳
- **使用ストレージ量**: Cache Reserve に現在保存されている GB 数（月次課金）
- **オペレーション数**: Class A（書き込み）と Class B（読み取り）の操作回数
- **コスト追跡**: 現在の使用量に基づく月額費用の見積もり

### Logpush との連携

```typescript
// Logpush field: CacheReserveUsed (boolean) - filter for Cache Reserve hits
// Query Cache Reserve hits in analytics
const logpushQuery = `
  SELECT 
    ClientRequestHost, 
    COUNT(*) as requests, 
    SUM(EdgeResponseBytes) as bytes_served,
    COUNT(CASE WHEN CacheReserveUsed = true THEN 1 END) as cache_reserve_hits,
    COUNT(CASE WHEN CacheReserveUsed = false THEN 1 END) as cache_reserve_misses
  FROM http_requests 
  WHERE Timestamp >= NOW() - INTERVAL '24 hours'
  GROUP BY ClientRequestHost 
  ORDER BY requests DESC
`;

// Filter only Cache Reserve hits
const crHitsQuery = `
  SELECT ClientRequestHost, COUNT(*) as requests, SUM(EdgeResponseBytes) as bytes
  FROM http_requests 
  WHERE CacheReserveUsed = true AND Timestamp >= NOW() - INTERVAL '7 days'
  GROUP BY ClientRequestHost 
  ORDER BY bytes DESC
`;
```

### GraphQL 分析

```graphql
query CacheReserveAnalytics($zoneTag: string, $since: string, $until: string) {
  viewer {
    zones(filter: { zoneTag: $zoneTag }) {
      httpRequests1dGroups(
        filter: { datetime_geq: $since, datetime_leq: $until }
        limit: 1000
      ) {
        dimensions { date }
        sum {
          cachedBytes
          cachedRequests
          bytes
          requests
        }
      }
    }
  }
}
```

## 料金

```typescript
// Storage: $0.015/GB-month | Class A (writes): $4.50/M | Class B (reads): $0.36/M
// Cache miss: 1A + 1B | Cache hit: 1B | Assets >1GB: proportionally more ops
```

## 関連項目

- [README](./README.md) - 概要と基本概念
- [Configuration](./configuration.md) - セットアップと Cache Rules
- [Patterns](./patterns.md) - ベストプラクティスと最適化
- [Gotchas](./gotchas.md) - よくある問題とトラブルシューティング
