# 設定とセットアップ

## ゲートウェイの作成

### ダッシュボード
AI > AI Gateway > ゲートウェイを作成 > 設定（認証、キャッシュ、レート制限、ログ記録）

### API
```bash
curl -X POST https://api.cloudflare.com/client/v4/accounts/{account_id}/ai-gateway/gateways \
  -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" \
  -d '{"id":"my-gateway","cache_ttl":3600,"rate_limiting_interval":60,"rate_limiting_limit":100,"collect_logs":true}'
```

**命名規則:** 小文字の英数字とハイフンを使用します（例: `prod-api`、`dev-chat`）。

## Wrangler との連携

```toml
[ai]
binding = "AI"

[[ai.gateway]]
id = "my-gateway"
```

```bash
wrangler secret put CF_API_TOKEN
wrangler secret put OPENAI_API_KEY  # If not using BYOK
```

## 認証

### ゲートウェイ認証（ゲートウェイへのアクセスを保護）
```typescript
const client = new OpenAI({
  baseURL: `https://gateway.ai.cloudflare.com/v1/${accountId}/${gatewayId}/openai`,
  defaultHeaders: { 'cf-aig-authorization': `Bearer ${cfToken}` }
});
```

### プロバイダーの認証方法

**1. 統合請求（キー不要）** - プロバイダーのキーを使わず、Cloudflare 経由で支払います。
```typescript
const client = new OpenAI({
  baseURL: `https://gateway.ai.cloudflare.com/v1/${accountId}/${gatewayId}/openai`,
  defaultHeaders: { 'cf-aig-authorization': `Bearer ${cfToken}` }
});
```
対応プロバイダー: OpenAI、Anthropic、Google AI Studio

**2. BYOK** - キーをダッシュボード（Provider Keys > Add）に保存し、コードには記載しません。

**3. リクエストヘッダー** - リクエストごとにプロバイダーのキーを渡します。
```typescript
const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
  baseURL: `https://gateway.ai.cloudflare.com/v1/${accountId}/${gatewayId}/openai`,
  defaultHeaders: { 'cf-aig-authorization': `Bearer ${cfToken}` }
});
```

## API トークンの権限

- **ゲートウェイの管理:** AI Gateway - Read + Edit
- **ゲートウェイへのアクセス:** AI Gateway - Read（最低限必要）

## ゲートウェイ管理 API

```bash
# List
curl https://api.cloudflare.com/client/v4/accounts/{account_id}/ai-gateway/gateways \
  -H "Authorization: Bearer $CF_API_TOKEN"

# Get
curl .../gateways/{gateway_id}

# Update
curl -X PUT .../gateways/{gateway_id} \
  -d '{"cache_ttl":7200,"rate_limiting_limit":200}'

# Delete
curl -X DELETE .../gateways/{gateway_id}
```

## ID の確認方法

- **アカウント ID:** Dashboard > Overview > Copy
- **ゲートウェイ ID:** AI Gateway > Gateway name 列

## Python の例

```python
from openai import OpenAI
import os

client = OpenAI(
    api_key=os.environ.get("OPENAI_API_KEY"),
    base_url=f"https://gateway.ai.cloudflare.com/v1/{os.environ['CF_ACCOUNT_ID']}/{os.environ['GATEWAY_ID']}/openai",
    default_headers={"cf-aig-authorization": f"Bearer {os.environ['CF_API_TOKEN']}"}
)
```

## ベストプラクティス

1. **本番環境では必ずゲートウェイを認証で保護する**
2. **BYOK または統合請求を使用する** - シークレットをコードに含めずに済みます。
3. **環境ごとにゲートウェイを用意する** - 開発、ステージング、本番を分離します。
4. **レート制限を設定する** - コストの際限ない増加を防ぎます。
5. **ログ記録を有効にする** - 使用状況の追跡と問題のデバッグに役立ちます。
