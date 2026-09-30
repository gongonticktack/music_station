## API リファレンス

**Smart Shield に関する注意:** Argo Smart Routing は Cloudflare の Smart Shield 製品に統合されつつあります。API エンドポイントは引き続き安定しており、既存の統合は変更なしで動作します。

### ベースエンドポイント
```
https://api.cloudflare.com/client/v4
```

### 認証
Zone:Argo Smart Routing:Edit 権限を持つ API トークンを使用します:

```bash
# Headers required
X-Auth-Email: user@example.com
Authorization: Bearer YOUR_API_TOKEN
```

### Argo Smart Routing のステータスを取得

**エンドポイント:** `GET /zones/{zone_id}/argo/smart_routing`

**説明:** Argo Smart Routing の現在の有効状態を取得します。

**cURL の例:**
```bash
curl -X GET "https://api.cloudflare.com/client/v4/zones/{zone_id}/argo/smart_routing" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json"
```

**レスポンス:**
```json
{
  "result": {
    "id": "smart_routing",
    "value": "on",
    "editable": true,
    "modified_on": "2024-01-11T12:00:00Z"
  },
  "success": true,
  "errors": [],
  "messages": []
}
```

**TypeScript SDK の例:**
```typescript
import Cloudflare from 'cloudflare';

const client = new Cloudflare({
  apiToken: process.env.CLOUDFLARE_API_TOKEN
});

const status = await client.argo.smartRouting.get({ zone_id: 'your-zone-id' });
console.log(`Argo status: ${status.value}, editable: ${status.editable}`);
```

**Python SDK の例:**
```python
from cloudflare import Cloudflare

client = Cloudflare(api_token=os.environ.get('CLOUDFLARE_API_TOKEN'))

status = client.argo.smart_routing.get(zone_id='your-zone-id')
print(f"Argo status: {status.value}, editable: {status.editable}")
```

### Argo Smart Routing のステータスを更新

**エンドポイント:** `PATCH /zones/{zone_id}/argo/smart_routing`

**説明:** ゾーンの Argo Smart Routing を有効または無効にします。

**リクエスト本文:**
```json
{
  "value": "on"  // or "off"
}
```

**cURL の例:**
```bash
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/{zone_id}/argo/smart_routing" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"value": "on"}'
```

**TypeScript SDK の例:**
```typescript
const result = await client.argo.smartRouting.edit({
  zone_id: 'your-zone-id',
  value: 'on',
});
console.log(`Updated: ${result.value} at ${result.modified_on}`);
```

**Python SDK の例:**
```python
result = client.argo.smart_routing.edit(
    zone_id='your-zone-id',
    value='on'
)
print(f"Updated: {result.value} at {result.modified_on}")
```

## 更新前に編集可能か確認する

**重要:** Argo の有効化または無効化を試みる前に、必ず `editable` フィールドを確認してください。`editable: false` の場合、ゾーンに制限があります（請求が設定されていない、権限が不十分、またはプラン上の制約）。

**パターン:**
```typescript
async function safelyEnableArgo(client: Cloudflare, zoneId: string): Promise<boolean> {
  const status = await client.argo.smartRouting.get({ zone_id: zoneId });
  
  if (!status.editable) {
    console.error('Cannot modify Argo: editable=false (check billing/permissions)');
    return false;
  }
  
  if (status.value === 'on') {
    console.log('Argo already enabled');
    return true;
  }
  
  await client.argo.smartRouting.edit({ zone_id: zoneId, value: 'on' });
  console.log('Argo enabled successfully');
  return true;
}
```

**Python のパターン:**
```python
def safely_enable_argo(client: Cloudflare, zone_id: str) -> bool:
    status = client.argo.smart_routing.get(zone_id=zone_id)
    
    if not status.editable:
        print('Cannot modify Argo: editable=false (check billing/permissions)')
        return False
    
    if status.value == 'on':
        print('Argo already enabled')
        return True
    
    client.argo.smart_routing.edit(zone_id=zone_id, value='on')
    print('Argo enabled successfully')
    return True
```

## エラー処理

TypeScript SDK は堅牢なエラー処理のために、型付きのエラークラスを提供します:

```typescript
import Cloudflare from 'cloudflare';
import { APIError, APIConnectionError, RateLimitError } from 'cloudflare';

async function enableArgoWithErrorHandling(client: Cloudflare, zoneId: string) {
  try {
    const result = await client.argo.smartRouting.edit({
      zone_id: zoneId,
      value: 'on',
    });
    return result;
  } catch (error) {
    if (error instanceof RateLimitError) {
      console.error('Rate limited. Retry after:', error.response?.headers.get('retry-after'));
      // Implement exponential backoff
    } else if (error instanceof APIError) {
      console.error('API error:', error.status, error.message);
      if (error.status === 403) {
        console.error('Permission denied - check API token scopes');
      } else if (error.status === 400) {
        console.error('Bad request - verify zone_id and payload');
      }
    } else if (error instanceof APIConnectionError) {
      console.error('Connection failed:', error.message);
      // Retry with exponential backoff
    } else {
      console.error('Unexpected error:', error);
    }
    throw error;
  }
}
```

**Python のエラー処理:**
```python
from cloudflare import Cloudflare, APIError, RateLimitError

def enable_argo_with_error_handling(client: Cloudflare, zone_id: str):
    try:
        result = client.argo.smart_routing.edit(zone_id=zone_id, value='on')
        return result
    except RateLimitError as e:
        print(f"Rate limited. Retry after: {e.response.headers.get('retry-after')}")
        raise
    except APIError as e:
        print(f"API error: {e.status} - {e.message}")
        if e.status == 403:
            print('Permission denied - check API token scopes')
        elif e.status == 400:
            print('Bad request - verify zone_id and payload')
        raise
    except Exception as e:
        print(f"Unexpected error: {e}")
        raise
```

## レスポンススキーマ

Argo Smart Routing API のすべてのレスポンスは、次の構造に従います:

```typescript
interface ArgoSmartRoutingResponse {
  result: {
    id: 'smart_routing';
    value: 'on' | 'off';
    editable: boolean;
    modified_on: string; // ISO 8601 timestamp
  };
  success: boolean;
  errors: Array<{
    code: number;
    message: string;
  }>;
  messages: Array<string>;
}
```

## 主なレスポンスフィールド

| フィールド | 型 | 説明 |
|-------|------|-------------|
| `value` | `"on" \| "off"` | 現在の有効状態 |
| `editable` | `boolean` | 変更が許可されているか（PATCH の前に確認） |
| `modified_on` | `string` | 最終変更時刻の ISO タイムスタンプ |
| `success` | `boolean` | リクエストが成功したか |
| `errors` | `Array` | `success: false` の場合のエラー詳細 |