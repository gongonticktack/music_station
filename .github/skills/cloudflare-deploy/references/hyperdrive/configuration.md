# 設定

概要については[README.md](./README.md)を参照してください。

## 設定の作成

**PostgreSQL:**
```bash
# Basic
npx wrangler hyperdrive create my-db \
  --connection-string="postgres://user:pass@host:5432/db"

# Custom cache
npx wrangler hyperdrive create my-db \
  --connection-string="postgres://..." \
  --max-age=120 --swr=30

# No cache
npx wrangler hyperdrive create my-db \
  --connection-string="postgres://..." \
  --caching-disabled=true
```

**MySQL:**
```bash
npx wrangler hyperdrive create my-db \
  --connection-string="mysql://user:pass@host:3306/db"
```

## wrangler.jsonc

```jsonc
{
  "compatibility_date": "2025-01-01", // Use latest for new projects
  "compatibility_flags": ["nodejs_compat"],
  "hyperdrive": [
    {
      "binding": "HYPERDRIVE",
      "id": "<HYPERDRIVE_ID>",
      "localConnectionString": "postgres://user:pass@localhost:5432/dev"
    }
  ]
}
```

**TypeScript 型の生成:** `npx wrangler types` を実行すると、wrangler.jsonc から `worker-configuration.d.ts` が自動生成されます。

**複数の設定:**
```jsonc
{
  "hyperdrive": [
    {"binding": "HYPERDRIVE_CACHED", "id": "<ID1>"},
    {"binding": "HYPERDRIVE_NO_CACHE", "id": "<ID2>"}
  ]
}
```

## 管理

```bash
npx wrangler hyperdrive list
npx wrangler hyperdrive get <ID>
npx wrangler hyperdrive update <ID> --max-age=180
npx wrangler hyperdrive delete <ID>
```

## 設定オプション

Hyperdrive の作成・更新に使う CLI フラグ:

| オプション | デフォルト | 説明 |
|--------|---------|-------|
| `--caching-disabled` | `false` | キャッシュを無効にする |
| `--max-age` | `60` | キャッシュの TTL（最大 3600 秒） |
| `--swr` | `15` | 古いキャッシュを返しながら再検証する期間 |
| `--origin-connection-limit` | 20/100 | Free/有料プラン |
| `--access-client-id` | - | トンネル認証 |
| `--access-client-secret` | - | トンネル認証 |
| `--sslmode` | `require` | PostgreSQL のみ |

## Smart Placement との連携

1 リクエスト内で**複数のクエリ**を実行する Worker では、データベースの近くで処理するために Smart Placement を有効にします。

```jsonc
{
  "compatibility_date": "2025-01-01",
  "compatibility_flags": ["nodejs_compat"],
  "placement": {
    "mode": "smart"
  },
  "hyperdrive": [
    {
      "binding": "HYPERDRIVE",
      "id": "<HYPERDRIVE_ID>"
    }
  ]
}
```

**メリット:** 複数クエリを実行する Worker が DB に近い場所で動作するため、ラウンドトリップ遅延が減少します。例は[patterns.md](./patterns.md)を参照してください。

## トンネル経由でのプライベート DB 接続

```
Worker → Hyperdrive → Access → Tunnel → Private Network → DB
```

**セットアップ:**
```bash
# 1. Create tunnel
cloudflared tunnel create my-db-tunnel

# 2. Configure hostname in Zero Trust dashboard
#    Domain: db-tunnel.example.com
#    Service: TCP -> localhost:5432

# 3. Create service token (Zero Trust > Service Auth)
#    Save Client ID/Secret

# 4. Create Access app (db-tunnel.example.com)
#    Policy: Service Auth token from step 3

# 5. Create Hyperdrive
npx wrangler hyperdrive create my-private-db \
  --host=db-tunnel.example.com \
  --user=dbuser --password=dbpass --database=prod \
  --access-client-id=<ID> --access-client-secret=<SECRET>
```

**⚠️ Tunnel を使う場合、`--port` を指定しないでください** - ポートはトンネルのサービス設定で構成します。

## ローカル開発

**方法 1: ローカル（推奨）:**
```bash
# Env var (takes precedence)
export CLOUDFLARE_HYPERDRIVE_LOCAL_CONNECTION_STRING_HYPERDRIVE="postgres://user:pass@localhost:5432/dev"
npx wrangler dev

# wrangler.jsonc
{"hyperdrive": [{"binding": "HYPERDRIVE", "localConnectionString": "postgres://..."}]}
```

**ローカルからリモート DB に接続:**
```bash
# PostgreSQL
export CLOUDFLARE_HYPERDRIVE_LOCAL_CONNECTION_STRING_HYPERDRIVE="postgres://user:pass@remote:5432/db?sslmode=require"

# MySQL
export CLOUDFLARE_HYPERDRIVE_LOCAL_CONNECTION_STRING_HYPERDRIVE="mysql://user:pass@remote:3306/db?sslMode=REQUIRED"
```

**方法 2: リモート実行:**
```bash
npx wrangler dev --remote  # Uses deployed config, affects production
```

[api.md](./api.md)、[patterns.md](./patterns.md)、[gotchas.md](./gotchas.md)を参照してください。
