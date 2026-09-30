# Cache Reserve の設定

## ダッシュボードでの設定

**有効化の最小手順:**

```bash
# Navigate to dashboard
https://dash.cloudflare.com/caching/cache-reserve

# Click "Enable Storage Sync" or "Purchase" button
```

**前提条件:**
- 有料の Cache Reserve プランまたは Smart Shield Advanced が必要
- Cache Reserve を最適に機能させるには Tiered Cache が**必須**

## API の設定

### REST API

```bash
# Enable
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/cache/cache_reserve" \
  -H "Authorization: Bearer $API_TOKEN" -H "Content-Type: application/json" \
  -d '{"value": "on"}'

# Check status
curl -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/cache/cache_reserve" \
  -H "Authorization: Bearer $API_TOKEN"
```

### TypeScript SDK

```bash
npm install cloudflare
```

```typescript
import Cloudflare from 'cloudflare';

const client = new Cloudflare({
  apiToken: process.env.CLOUDFLARE_API_TOKEN,
});

// Enable Cache Reserve
await client.cache.cacheReserve.edit({
  zone_id: 'abc123',
  value: 'on',
});

// Get Cache Reserve status
const status = await client.cache.cacheReserve.get({
  zone_id: 'abc123',
});
console.log(status.value); // 'on' or 'off'
```

### Python SDK

```bash
pip install cloudflare
```

```python
from cloudflare import Cloudflare

client = Cloudflare(api_token=os.environ.get("CLOUDFLARE_API_TOKEN"))

# Enable Cache Reserve
client.cache.cache_reserve.edit(
    zone_id="abc123",
    value="on"
)

# Get Cache Reserve status
status = client.cache.cache_reserve.get(zone_id="abc123")
print(status.value)  # 'on' or 'off'
```

### Terraform

```hcl
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_zone_cache_reserve" "example" {
  zone_id = var.zone_id
  enabled = true
}

# Tiered Cache is required for Cache Reserve
resource "cloudflare_tiered_cache" "example" {
  zone_id    = var.zone_id
  cache_type = "smart"
}
```

### Pulumi

```typescript
import * as cloudflare from "@pulumi/cloudflare";

// Enable Cache Reserve
const cacheReserve = new cloudflare.ZoneCacheReserve("example", {
  zoneId: zoneId,
  enabled: true,
});

// Enable Tiered Cache (required)
const tieredCache = new cloudflare.TieredCache("example", {
  zoneId: zoneId,
  cacheType: "smart",
});
```

### 必要な API トークンの権限

- `Zone Settings Read`
- `Zone Settings Write`
- `Zone Read`
- `Zone Write`

## Cache Rules との連携

Cache Rules で Cache Reserve の対象にするかどうかを制御できます。

```typescript
// Enable for static assets
{
  action: 'set_cache_settings',
  action_parameters: {
    cache_reserve: { eligible: true, minimum_file_ttl: 86400 },
    edge_ttl: { mode: 'override_origin', default: 86400 },
    cache: true
  },
  expression: '(http.request.uri.path matches "\\.(jpg|png|webp|pdf|zip)$")'
}

// Disable for APIs
{
  action: 'set_cache_settings',
  action_parameters: { cache_reserve: { eligible: false } },
  expression: '(http.request.uri.path matches "^/api/")'
}

// Create via API: PUT to zones/{zone_id}/rulesets/phases/http_request_cache_settings/entrypoint
```

## Wrangler との連携

Wrangler でデプロイした Workers でも Cache Reserve は自動的に機能します。特別な wrangler.jsonc 設定は不要です。ゾーンの Cache Reserve をダッシュボードまたは API で有効にしてください。

## 関連項目

- [README](./README.md) - 概要と基本概念
- [API Reference](./api.md) - パージとモニタリングの API
- [Patterns](./patterns.md) - ベストプラクティスと最適化
- [Gotchas](./gotchas.md) - よくある問題とトラブルシューティング
