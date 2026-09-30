# よく使うパターン

## 自動ページネーションですべてを列挙する

**問題:** API の結果はページ分割される。デフォルトのページサイズは 20。

**解決策:** SDK の自動ページネーションを使って、すべての結果を反復処理する。

```typescript
// TypeScript
for await (const zone of client.zones.list()) {
  console.log(zone.name);
}
```

```python
# Python
for zone in client.zones.list():
    print(zone.name)
```

```go
// Go
iter := client.Zones.ListAutoPaging(ctx, cloudflare.ZoneListParams{})
for iter.Next() {
    fmt.Println(iter.Current().Name)
}
```

## エラー発生時の再試行

**問題:** レート制限 (429) や一時的なエラーには再試行が必要。

**解決策:** SDK は指数バックオフを使って自動的に再試行する。必要に応じて設定を変更する。

```typescript
// Increase retries for rate-limit-heavy operations
const client = new Cloudflare({ maxRetries: 5 });

try {
  const zone = await client.zones.create({ /* ... */ });
} catch (err) {
  if (err instanceof Cloudflare.RateLimitError) {
    // Already retried 5 times with backoff
    const retryAfter = err.headers['retry-after'];
    console.log(`Rate limited. Retry after ${retryAfter}s`);
  }
}
```

## 複数の操作を並列実行する

**問題:** 複数のリソースをすばやく作成する必要がある。

**解決策:** `Promise.all()` を使ってリクエストを並列実行する（レート制限に注意）。

```typescript
// Create multiple DNS records in parallel
const records = ['www', 'api', 'cdn'].map(subdomain =>
  client.dns.records.create({
    zone_id: 'zone-id',
    type: 'A',
    name: `${subdomain}.example.com`,
    content: '192.0.2.1',
  })
);
await Promise.all(records);
```

**同時実行数を制御する**（レート制限を避けるため）:

```typescript
import pLimit from 'p-limit';
const limit = pLimit(10); // Max 10 concurrent

const subdomains = ['www', 'api', 'cdn', /* many more */];
const records = subdomains.map(subdomain =>
  limit(() => client.dns.records.create({
    zone_id: 'zone-id',
    type: 'A',
    name: `${subdomain}.example.com`,
    content: '192.0.2.1',
  }))
);
await Promise.all(records);
```

## ゾーンの CRUD ワークフロー

```typescript
// Create
const zone = await client.zones.create({
  account: { id: 'account-id' },
  name: 'example.com',
  type: 'full',
});

// Read
const fetched = await client.zones.get({ zone_id: zone.id });

// Update
await client.zones.edit(zone.id, { paused: false });

// Delete
await client.zones.delete(zone.id);
```

## DNS の一括更新

```typescript
// Fetch all A records
const records = [];
for await (const record of client.dns.records.list({
  zone_id: 'zone-id',
  type: 'A',
})) {
  records.push(record);
}

// Update all to new IP
await Promise.all(records.map(record =>
  client.dns.records.update({
    zone_id: 'zone-id',
    dns_record_id: record.id,
    type: 'A',
    name: record.name,
    content: '203.0.113.1', // New IP
    proxied: record.proxied,
    ttl: record.ttl,
  })
));
```

## 結果を絞り込んで収集する

```typescript
// Find all proxied A records
const proxiedRecords = [];
for await (const record of client.dns.records.list({
  zone_id: 'zone-id',
  type: 'A',
})) {
  if (record.proxied) {
    proxiedRecords.push(record);
  }
}
```

## エラーからの復旧パターン

```typescript
async function createZoneWithRetry(name: string, maxAttempts = 3) {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await client.zones.create({
        account: { id: 'account-id' },
        name,
        type: 'full',
      });
    } catch (err) {
      if (err instanceof Cloudflare.RateLimitError && attempt < maxAttempts) {
        const retryAfter = parseInt(err.headers['retry-after'] || '5');
        console.log(`Rate limited, waiting ${retryAfter}s (retry ${attempt}/${maxAttempts})`);
        await new Promise(resolve => setTimeout(resolve, retryAfter * 1000));
      } else {
        throw err;
      }
    }
  }
}
```

## 条件付き更新パターン

```typescript
// Only update if zone is active
const zone = await client.zones.get({ zone_id: 'zone-id' });
if (zone.status === 'active') {
  await client.zones.edit(zone.id, { paused: false });
}
```

## エラー処理を伴う一括操作

```typescript
// Process multiple zones, continue on errors
const results = await Promise.allSettled(
  zoneIds.map(id => client.zones.get({ zone_id: id }))
);

results.forEach((result, i) => {
  if (result.status === 'fulfilled') {
    console.log(`Zone ${i}: ${result.value.name}`);
  } else {
    console.error(`Zone ${i} failed:`, result.reason.message);
  }
});
```

## 関連資料

- [api.md](./api.md) - SDK クライアントの初期化、基本操作
- [gotchas.md](./gotchas.md) - レート制限、よくあるエラー
- [configuration.md](./configuration.md) - SDK の設定項目
