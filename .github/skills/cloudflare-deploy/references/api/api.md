# API リファレンス

## クライアントの初期化

### TypeScript

```typescript
import Cloudflare from 'cloudflare';

const client = new Cloudflare({
  apiToken: process.env.CLOUDFLARE_API_TOKEN,
});
```

### Python

```python
from cloudflare import Cloudflare

client = Cloudflare(api_token=os.environ.get("CLOUDFLARE_API_TOKEN"))

# For async:
from cloudflare import AsyncCloudflare
client = AsyncCloudflare(api_token=os.environ["CLOUDFLARE_API_TOKEN"])
```

### Go

```go
import (
    "github.com/cloudflare/cloudflare-go/v4"
    "github.com/cloudflare/cloudflare-go/v4/option"
)

client := cloudflare.NewClient(
    option.WithAPIToken(os.Getenv("CLOUDFLARE_API_TOKEN")),
)
```

## 認証

### API トークン（推奨）

**トークンの作成**: Dashboard → My Profile → API Tokens → Create Token

```bash
export CLOUDFLARE_API_TOKEN='your-token-here'

curl "https://api.cloudflare.com/client/v4/zones" \
  --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
```

**トークンの権限範囲**: 常に必要最小限の権限を使用してください（対象ゾーンの限定、有効期間の制限）。

### API キー（旧方式）

```bash
curl "https://api.cloudflare.com/client/v4/zones" \
  --header "X-Auth-Email: user@example.com" \
  --header "X-Auth-Key: $CLOUDFLARE_API_KEY"
```

**非推奨:** アカウント全体にアクセスでき、権限範囲を限定できません。

## 自動ページネーション

すべての SDK は、一覧取得操作で自動ページネーションに対応しています。

```typescript
// TypeScript: for await...of
for await (const zone of client.zones.list()) {
  console.log(zone.id);
}
```

```python
# Python: iterator protocol
for zone in client.zones.list():
    print(zone.id)
```

```go
// Go: ListAutoPaging
iter := client.Zones.ListAutoPaging(ctx, cloudflare.ZoneListParams{})
for iter.Next() {
    zone := iter.Current()
    fmt.Println(zone.ID)
}
```

## エラー処理

```typescript
try {
  const zone = await client.zones.get({ zone_id: 'xxx' });
} catch (err) {
  if (err instanceof Cloudflare.NotFoundError) {
    // 404
  } else if (err instanceof Cloudflare.RateLimitError) {
    // 429 - SDK auto-retries with backoff
  } else if (err instanceof Cloudflare.APIError) {
    console.log(err.status, err.message);
  }
}
```

**主なエラーの種類:**
- `AuthenticationError` (401) - 無効なトークン
- `PermissionDeniedError` (403) - 権限範囲が不十分
- `NotFoundError` (404) - リソースが見つからない
- `RateLimitError` (429) - レート制限を超過
- `InternalServerError` (≥500) - Cloudflare 側のエラー

## ゾーンの管理

```typescript
// List zones
const zones = await client.zones.list({
  account: { id: 'account-id' },
  status: 'active',
});

// Create zone
const zone = await client.zones.create({
  account: { id: 'account-id' },
  name: 'example.com',
  type: 'full', // or 'partial'
});

// Update zone
await client.zones.edit('zone-id', {
  paused: false,
});

// Delete zone
await client.zones.delete('zone-id');
```

```go
// Go: requires cloudflare.F() wrapper
zone, err := client.Zones.New(ctx, cloudflare.ZoneNewParams{
    Account: cloudflare.F(cloudflare.ZoneNewParamsAccount{
        ID: cloudflare.F("account-id"),
    }),
    Name: cloudflare.F("example.com"),
    Type: cloudflare.F(cloudflare.ZoneNewParamsTypeFull),
})
```

## DNS の管理

```typescript
// Create DNS record
await client.dns.records.create({
  zone_id: 'zone-id',
  type: 'A',
  name: 'subdomain.example.com',
  content: '192.0.2.1',
  ttl: 1, // auto
  proxied: true, // Orange cloud
});

// List DNS records (with auto-pagination)
for await (const record of client.dns.records.list({
  zone_id: 'zone-id',
  type: 'A',
})) {
  console.log(record.name, record.content);
}

// Update DNS record
await client.dns.records.update({
  zone_id: 'zone-id',
  dns_record_id: 'record-id',
  type: 'A',
  name: 'subdomain.example.com',
  content: '203.0.113.1',
  proxied: true,
});

// Delete DNS record
await client.dns.records.delete({
  zone_id: 'zone-id',
  dns_record_id: 'record-id',
});
```

```python
# Python example
client.dns.records.create(
    zone_id="zone-id",
    type="A",
    name="subdomain.example.com",
    content="192.0.2.1",
    ttl=1,
    proxied=True,
)
```

## 関連資料

- [configuration.md](./configuration.md) - SDK の設定、環境変数
- [patterns.md](./patterns.md) - 実際の利用パターンとワークフロー
- [gotchas.md](./gotchas.md) - レート制限、トラブルシューティング
