# TURN の設定

Workers およびアプリケーションで Cloudflare TURN サービスをセットアップして設定します。

## 環境変数

```bash
# .env
CLOUDFLARE_ACCOUNT_ID=your_account_id
CLOUDFLARE_API_TOKEN=your_api_token
TURN_KEY_ID=your_turn_key_id
TURN_KEY_SECRET=your_turn_key_secret
```

zod で検証します:

```typescript
import { z } from 'zod';

const envSchema = z.object({
  CLOUDFLARE_ACCOUNT_ID: z.string().min(1),
  CLOUDFLARE_API_TOKEN: z.string().min(1),
  TURN_KEY_ID: z.string().min(1),
  TURN_KEY_SECRET: z.string().min(1)
});

export const config = envSchema.parse(process.env);
```

## wrangler.jsonc

```jsonc
{
  "name": "turn-credentials-api",
  "main": "src/index.ts",
  "compatibility_date": "2025-01-01",
  "vars": {
    "TURN_KEY_ID": "your-turn-key-id"  // Non-sensitive, can be in vars
  },
  "env": {
    "production": {
      "kv_namespaces": [
        {
          "binding": "CREDENTIALS_CACHE",
          "id": "your-kv-namespace-id"
        }
      ]
    }
  }
}
```

**シークレットは別途保存します**:
```bash
wrangler secret put TURN_KEY_SECRET
```

## Cloudflare Worker との統合

### Worker バインディングの型

```typescript
interface Env {
  TURN_KEY_ID: string;
  TURN_KEY_SECRET: string;
  CREDENTIALS_CACHE?: KVNamespace;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // See patterns.md for implementation
  }
}
```

### Worker の基本例

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.url.endsWith('/turn-credentials')) {
      // Validate client auth
      const authHeader = request.headers.get('Authorization');
      if (!authHeader) {
        return new Response('Unauthorized', { status: 401 });
      }

      const response = await fetch(
        `https://rtc.live.cloudflare.com/v1/turn/keys/${env.TURN_KEY_ID}/credentials/generate`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${env.TURN_KEY_SECRET}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({ ttl: 3600 })
        }
      );

      if (!response.ok) {
        return new Response('Failed to generate credentials', { status: 500 });
      }

      const data = await response.json();

      // Filter port 53 for browser clients
      const filteredUrls = data.iceServers.urls.filter(
        (url: string) => !url.includes(':53')
      );

      return Response.json({
        iceServers: [
          { urls: 'stun:stun.cloudflare.com:3478' },
          {
            urls: filteredUrls,
            username: data.iceServers.username,
            credential: data.iceServers.credential
          }
        ]
      });
    }

    return new Response('Not found', { status: 404 });
  }
};
```

## IP 許可リスト（Enterprise／ファイアウォール）

厳格なファイアウォールでは、`turn.cloudflare.com` 用に次の IP を許可リストに追加します:

| 種類 | アドレス | プロトコル |
|------|---------|----------|
| IPv4 | 141.101.90.1/32 | すべて |
| IPv4 | 162.159.207.1/32 | すべて |
| IPv6 | 2a06:98c1:3200::1/128 | すべて |
| IPv6 | 2606:4700:48::1/128 | すべて |

**重要**: これらの IP は 14 日前の通知をもって変更される場合があります。DNS を監視してください:

```bash
# Check A and AAAA records
dig turn.cloudflare.com A
dig turn.cloudflare.com AAAA
```

IP の変更を検出し、14 日以内に許可リストを更新する自動監視を設定してください。

## IPv6 のサポート

- **クライアントから TURN への接続**: IPv4 と IPv6 の両方をサポート
- **リレーアドレス**: IPv4 のみ（RFC 6156 は非対応）
- **TCP リレー**: 非対応（RFC 6062）

クライアントは IPv6 経由で接続できますが、中継されるトラフィックには IPv4 アドレスが使用されます。

## TLS の設定

### サポートされる TLS バージョン
- TLS 1.1
- TLS 1.2
- TLS 1.3

### 推奨暗号スイート（TLS 1.3）
- AEAD-AES128-GCM-SHA256
- AEAD-AES256-GCM-SHA384
- AEAD-CHACHA20-POLY1305-SHA256

### 推奨暗号スイート（TLS 1.2）
- ECDHE-ECDSA-AES128-GCM-SHA256
- ECDHE-RSA-AES128-GCM-SHA256
- ECDHE-RSA-AES128-SHA（TLS 1.1 でも使用）
- AES128-GCM-SHA256

## 関連項目

- [api.md](./api.md) - TURN キーの作成、認証情報生成 API
- [patterns.md](./patterns.md) - Worker の実装パターン全般
- [gotchas.md](./gotchas.md) - セキュリティのベストプラクティス、トラブルシューティング