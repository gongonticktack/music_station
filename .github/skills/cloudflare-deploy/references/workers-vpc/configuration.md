# 設定

Cloudflare Workers の TCP ソケットのセットアップと設定。

## Wrangler の設定

### 基本設定

TCP ソケットは Workers ランタイムでデフォルトで利用できます。`wrangler.jsonc` で特別な設定は不要です:

```jsonc
{
  "name": "private-network-worker",
  "main": "src/index.ts",
  "compatibility_date": "2025-01-01"
}
```

### 環境変数

接続情報を環境変数として保存します:

```jsonc
{
  "vars": { "DB_HOST": "10.0.1.50", "DB_PORT": "5432" }
}
```

```typescript
interface Env { DB_HOST: string; DB_PORT: string; }

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const socket = connect({ hostname: env.DB_HOST, port: parseInt(env.DB_PORT) });
  }
};
```

### 環境ごとの設定

```jsonc
{
  "vars": { "DB_HOST": "localhost" },
  "env": {
    "staging": { "vars": { "DB_HOST": "staging-db.internal.net" } },
    "production": { "vars": { "DB_HOST": "prod-db.internal.net" } }
  }
}
```

デプロイ: `wrangler deploy --env staging` または `wrangler deploy --env production`

## Cloudflare Tunnel との連携

Workers をプライベートネットワークに接続するには、TCP ソケットと Cloudflare Tunnel を組み合わせます:

```
Worker (TCP Socket) → Tunnel hostname → cloudflared → Private Network
```

### クイックセットアップ

1. プライベートネットワーク内のサーバーに **cloudflared をインストール**します
2. **トンネルを作成**します: `cloudflared tunnel create my-private-network`
3. `config.yml` で **ルーティングを設定**します:

```yaml
tunnel: <TUNNEL_ID>
credentials-file: /path/to/<TUNNEL_ID>.json
ingress:
  - hostname: db.internal.example.com
    service: tcp://10.0.1.50:5432
  - service: http_status:404  # Required catch-all
```

4. **トンネルを実行**します: `cloudflared tunnel run my-private-network`
5. **Worker から接続**します:

```typescript
const socket = connect(
  { hostname: "db.internal.example.com", port: 5432 },  // Tunnel hostname
  { secureTransport: "on" }
);
```

Tunnel の詳細なセットアップについては、[Tunnel の設定リファレンス](../tunnel/configuration.md)を参照してください。

## Smart Placement との連携

バックエンドの近くに Workers を自動配置して、レイテンシを削減します:

```jsonc
{ "placement": { "mode": "smart" } }
```

接続レイテンシを観測した後、Workers は TCP ソケットの接続先に近い場所へ自動的に移動します。[Smart Placement のリファレンス](../smart-placement/)を参照してください。

## シークレット管理

機密性の高い認証情報はシークレットとして保存します（wrangler.jsonc には保存しません）:

```bash
wrangler secret put DB_PASSWORD  # Enter value when prompted
```

Worker では `env.DB_PASSWORD` を使ってアクセスします。プロトコルのハンドシェイクまたは認証で使用します。

## ローカル開発

`wrangler dev` を使ってテストします。注: ローカルモードではプライベートネットワークにアクセスできない場合があります。開発には公開エンドポイントまたはモックサーバーを使用します:

```typescript
const config = process.env.NODE_ENV === 'dev' 
  ? { hostname: 'localhost', port: 5432 }  // Mock
  : { hostname: 'db.internal.example.com', port: 5432 };  // Production
```

## 接続文字列のパターン

接続文字列を解析してホストとポートを取り出します:

```typescript
function parseConnectionString(connStr: string): SocketAddress {
  const url = new URL(connStr); // e.g., "postgres://10.0.1.50:5432/mydb"
  return { hostname: url.hostname, port: parseInt(url.port) || 5432 };
}
```

## Hyperdrive との連携

PostgreSQL/MySQL では、生の TCP ソケットより Hyperdrive を推奨します（接続プーリングを含みます）:

```jsonc
{ "hyperdrive": [{ "binding": "DB", "id": "<HYPERDRIVE_ID>" }] }
```

完全なセットアップについては、[Hyperdrive のリファレンス](../hyperdrive/)を参照してください。

## 互換性

TCP ソケットはすべての最新の Workers で利用できます。現在の日付を使用します: `"compatibility_date": "2025-01-01"`。特別なフラグは不要です。

## 関連する設定

- **[Tunnel の設定](../tunnel/configuration.md)** - cloudflared の詳細なセットアップ
- **[Smart Placement](../smart-placement/configuration.md)** - 配置モードのオプション
- **[Hyperdrive](../hyperdrive/configuration.md)** - データベース接続プーリングのセットアップ
