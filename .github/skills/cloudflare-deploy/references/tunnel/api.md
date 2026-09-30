# Tunnel API

## Cloudflare API へのアクセス

**ベース URL**: `https://api.cloudflare.com/client/v4`

**認証**:
```bash
Authorization: Bearer ${CF_API_TOKEN}
```

## TypeScript SDK

インストール: `npm install cloudflare`

```typescript
import Cloudflare from 'cloudflare';

const cf = new Cloudflare({
  apiToken: process.env.CF_API_TOKEN,
});

const accountId = process.env.CF_ACCOUNT_ID;
```

## トンネルの作成

### cURL
```bash
curl -X POST "https://api.cloudflare.com/client/v4/accounts/{account_id}/tunnels" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{
    "name": "my-tunnel",
    "tunnel_secret": "<base64-secret>"
  }'
```

### TypeScript
```typescript
const tunnel = await cf.zeroTrust.tunnels.create({
  account_id: accountId,
  name: 'my-tunnel',
  tunnel_secret: Buffer.from(crypto.randomBytes(32)).toString('base64'),
});

console.log(`Tunnel ID: ${tunnel.id}`);
```

## トンネルの一覧表示

### cURL
```bash
curl -X GET "https://api.cloudflare.com/client/v4/accounts/{account_id}/tunnels" \
  -H "Authorization: Bearer ${CF_API_TOKEN}"
```

### TypeScript
```typescript
const tunnels = await cf.zeroTrust.tunnels.list({
  account_id: accountId,
});

for (const tunnel of tunnels.result) {
  console.log(`${tunnel.name}: ${tunnel.id}`);
}
```

## トンネル情報の取得

### cURL
```bash
curl -X GET "https://api.cloudflare.com/client/v4/accounts/{account_id}/tunnels/{tunnel_id}" \
  -H "Authorization: Bearer ${CF_API_TOKEN}"
```

### TypeScript
```typescript
const tunnel = await cf.zeroTrust.tunnels.get(tunnelId, {
  account_id: accountId,
});

console.log(`Status: ${tunnel.status}`);
console.log(`Connections: ${tunnel.connections?.length || 0}`);
```

## トンネル設定の更新

### cURL
```bash
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/{account_id}/tunnels/{tunnel_id}/configurations" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{
    "config": {
      "ingress": [
        {"hostname": "app.example.com", "service": "http://localhost:8000"},
        {"service": "http_status:404"}
      ]
    }
  }'
```

### TypeScript
```typescript
const config = await cf.zeroTrust.tunnels.configurations.update(
  tunnelId,
  {
    account_id: accountId,
    config: {
      ingress: [
        { hostname: 'app.example.com', service: 'http://localhost:8000' },
        { service: 'http_status:404' },
      ],
    },
  }
);
```

## トンネルの削除

### cURL
```bash
curl -X DELETE "https://api.cloudflare.com/client/v4/accounts/{account_id}/tunnels/{tunnel_id}" \
  -H "Authorization: Bearer ${CF_API_TOKEN}"
```

### TypeScript
```typescript
await cf.zeroTrust.tunnels.delete(tunnelId, {
  account_id: accountId,
});
```

## トークンベースのトンネル（設定ソース: Cloudflare）

トークンベースのトンネルでは、ローカルファイルではなく Cloudflare ダッシュボードに設定を保存します。

### ダッシュボード経由
1. **Zero Trust** > **Networks** > **Tunnels**
2. **トンネルを作成** > **Cloudflared**
3. ダッシュボードでルートを設定する
4. トークンをコピーする
5. オリジンで実行する:
```bash
cloudflared service install <TOKEN>
```

### トークン経由
```bash
# Run with token (no config file needed)
cloudflared tunnel --no-autoupdate run --token ${TUNNEL_TOKEN}

# Docker
docker run cloudflare/cloudflared:latest tunnel --no-autoupdate run --token ${TUNNEL_TOKEN}
```

### トンネルトークンの取得（TypeScript）
```typescript
// Get tunnel to retrieve token
const tunnel = await cf.zeroTrust.tunnels.get(tunnelId, {
  account_id: accountId,
});

// Token available in tunnel.token (only for config source: cloudflare)
const token = tunnel.token;
```

## DNS ルート API

```bash
# Create DNS route
curl -X POST "https://api.cloudflare.com/client/v4/accounts/{account_id}/tunnels/{tunnel_id}/connections" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  --data '{"hostname": "app.example.com"}'

# Delete route
curl -X DELETE "https://api.cloudflare.com/client/v4/accounts/{account_id}/tunnels/{tunnel_id}/connections/{route_id}" \
  -H "Authorization: Bearer ${CF_API_TOKEN}"
```

## プライベートネットワークルート API

```bash
# Add IP route
curl -X POST "https://api.cloudflare.com/client/v4/accounts/{account_id}/tunnels/{tunnel_id}/routes" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  --data '{"ip_network": "10.0.0.0/8"}'

# List IP routes
curl -X GET "https://api.cloudflare.com/client/v4/accounts/{account_id}/tunnels/{tunnel_id}/routes" \
  -H "Authorization: Bearer ${CF_API_TOKEN}"
```