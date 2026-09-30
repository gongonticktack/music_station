# TURN API リファレンス

Cloudflare TURN サービスの認証情報とキー管理に関する API ドキュメントです。

## 認証

すべてのエンドポイントで、「Calls Write」権限を持つ Cloudflare API トークンが必要です。

ベース URL: `https://api.cloudflare.com/client/v4`

## TURN キーの管理

### TURN キーの一覧

```
GET /accounts/{account_id}/calls/turn_keys
```

### TURN キーの詳細を取得

```
GET /accounts/{account_id}/calls/turn_keys/{key_id}
```

### TURN キーを作成

```
POST /accounts/{account_id}/calls/turn_keys
Content-Type: application/json

{
  "name": "my-turn-key"
}
```

**レスポンスに含まれる項目**:
- `uid`: キー識別子
- `key`: 秘密鍵の実値（作成時にのみ返されるため、すぐに保存してください）
- `name`: 人間が読める名前
- `created`: ISO 8601 タイムスタンプ
- `modified`: ISO 8601 タイムスタンプ

### TURN キーを更新

```
PUT /accounts/{account_id}/calls/turn_keys/{key_id}
Content-Type: application/json

{
  "name": "updated-name"
}
```

### TURN キーを削除

```
DELETE /accounts/{account_id}/calls/turn_keys/{key_id}
```

## 一時的な認証情報を生成

```
POST https://rtc.live.cloudflare.com/v1/turn/keys/{key_id}/credentials/generate
Authorization: Bearer {key_secret}
Content-Type: application/json

{
  "ttl": 86400
}
```

### 認証情報の制約

| パラメーター | 最小値 | 最大値 | デフォルト | 備考 |
|-----------|-----|-----|---------|-------|
| ttl | 1 | 172800（48時間） | 変動 | API は 172800 を超える値を拒否します |

**重要**: TTL の上限は 48 時間（172800 秒）です。この上限を超えるリクエストは API に拒否されます。

### レスポンススキーマ

```json
{
  "iceServers": {
    "urls": [
      "stun:stun.cloudflare.com:3478",
      "turn:turn.cloudflare.com:3478?transport=udp",
      "turn:turn.cloudflare.com:3478?transport=tcp",
      "turn:turn.cloudflare.com:53?transport=udp",
      "turn:turn.cloudflare.com:80?transport=tcp",
      "turns:turn.cloudflare.com:5349?transport=tcp",
      "turns:turn.cloudflare.com:443?transport=tcp"
    ],
    "username": "1738035200:user123",
    "credential": "base64encodedhmac=="
  }
}
```

**ポート 53 に関する注意**: ブラウザクライアントではポート 53 の URL を除外してください（Chrome/Firefox ではブロックされます）。[gotchas.md](./gotchas.md#using-port-53-in-browsers) を参照してください。

## 認証情報を失効

```
POST https://rtc.live.cloudflare.com/v1/turn/keys/{key_id}/credentials/revoke
Authorization: Bearer {key_secret}
Content-Type: application/json

{
  "username": "1738035200:user123"
}
```

**レスポンス**: 204 No Content

課金は直ちに停止します。アクティブな接続は短い遅延（数秒程度）の後に切断されます。

## TypeScript の型

```typescript
interface CloudflareTURNConfig {
  keyId: string;
  keySecret: string;
  ttl?: number; // Max 172800 (48 hours)
}

interface TURNCredentialsRequest {
  ttl?: number; // Max 172800 seconds
}

interface TURNCredentialsResponse {
  iceServers: {
    urls: string[];
    username: string;
    credential: string;
  };
}

interface RTCIceServer {
  urls: string | string[];
  username?: string;
  credential?: string;
  credentialType?: "password";
}

interface TURNKeyResponse {
  uid: string;
  key: string; // Only present on creation
  name: string;
  created: string;
  modified: string;
}
```

## 検証関数

```typescript
function validateRTCIceServer(obj: unknown): obj is RTCIceServer {
  if (!obj || typeof obj !== 'object') {
    return false;
  }

  const server = obj as Record<string, unknown>;

  if (typeof server.urls !== 'string' && !Array.isArray(server.urls)) {
    return false;
  }

  if (server.username && typeof server.username !== 'string') {
    return false;
  }

  if (server.credential && typeof server.credential !== 'string') {
    return false;
  }

  return true;
}
```

## 型安全な認証情報の生成

```typescript
async function fetchTURNServers(
  config: CloudflareTURNConfig
): Promise<RTCIceServer[]> {
  // Validate TTL constraint
  const ttl = config.ttl ?? 3600;
  if (ttl > 172800) {
    throw new Error('TTL cannot exceed 172800 seconds (48 hours)');
  }

  const response = await fetch(
    `https://rtc.live.cloudflare.com/v1/turn/keys/${config.keyId}/credentials/generate`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${config.keySecret}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ ttl })
    }
  );

  if (!response.ok) {
    throw new Error(`TURN credential generation failed: ${response.status}`);
  }

  const data = await response.json();
  
  // Filter port 53 for browser clients
  const filteredUrls = data.iceServers.urls.filter(
    (url: string) => !url.includes(':53')
  );

  const iceServers = [
    { urls: 'stun:stun.cloudflare.com:3478' },
    {
      urls: filteredUrls,
      username: data.iceServers.username,
      credential: data.iceServers.credential,
      credentialType: 'password' as const
    }
  ];

  // Validate before returning
  if (!iceServers.every(validateRTCIceServer)) {
    throw new Error('Invalid ICE server configuration received');
  }

  return iceServers;
}
```

## 関連項目

- [configuration.md](./configuration.md) - Worker の設定、環境変数
- [patterns.md](./patterns.md) - これらの API を使用した実装例
- [gotchas.md](./gotchas.md) - セキュリティのベストプラクティス、よくあるミス
