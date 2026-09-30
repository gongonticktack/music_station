# 設定

## 環境変数

### 変数を設定する

| プラットフォーム | コマンド |
|----------|---------|
| Linux/macOS | `export CLOUDFLARE_API_TOKEN='token'` |
| PowerShell | `$env:CLOUDFLARE_API_TOKEN = 'token'` |
| Windows CMD | `set CLOUDFLARE_API_TOKEN=token` |

**セキュリティ:** トークンをコミットしないでください。`.env` ファイル（gitignore の対象）またはシークレットマネージャーを使用してください。

### .env ファイルの例

```bash
# .env (add to .gitignore)
CLOUDFLARE_API_TOKEN=your-token-here
CLOUDFLARE_ACCOUNT_ID=your-account-id
```

```typescript
// TypeScript
import 'dotenv/config';

const client = new Cloudflare({
  apiToken: process.env.CLOUDFLARE_API_TOKEN,
});
```

```python
# Python
from dotenv import load_dotenv
load_dotenv()

client = Cloudflare(api_token=os.environ["CLOUDFLARE_API_TOKEN"])
```

## SDK の設定

### TypeScript

```typescript
const client = new Cloudflare({
  apiToken: process.env.CLOUDFLARE_API_TOKEN,
  timeout: 120000,        // 2 min (default 60s), in milliseconds
  maxRetries: 5,          // default 2
  baseURL: 'https://...', // proxy (rare)
});

// Per-request overrides
await client.zones.get(
  { zone_id: 'zone-id' },
  { timeout: 5000, maxRetries: 0 }
);
```

### Python

```python
client = Cloudflare(
    api_token=os.environ["CLOUDFLARE_API_TOKEN"],
    timeout=120,         # seconds (default 60)
    max_retries=5,       # default 2
    base_url="https://...",  # proxy (rare)
)

# Per-request overrides
client.with_options(timeout=5, max_retries=0).zones.get(zone_id="zone-id")
```

### Go

```go
client := cloudflare.NewClient(
    option.WithAPIToken(os.Getenv("CLOUDFLARE_API_TOKEN")),
    option.WithMaxRetries(5),  // default 10 (higher than TS/Python)
    option.WithRequestTimeout(2 * time.Minute),  // default 60s
    option.WithBaseURL("https://..."),  // proxy (rare)
)

// Per-request overrides
client.Zones.Get(ctx, "zone-id", option.WithMaxRetries(0))
```

## 設定項目

| 項目 | TypeScript | Python | Go | デフォルト |
|--------|-----------|--------|-----|---------|
| タイムアウト | `timeout`（ミリ秒） | `timeout`（秒） | `WithRequestTimeout` | 60秒 |
| 再試行回数 | `maxRetries` | `max_retries` | `WithMaxRetries` | 2（Go: 10） |
| ベース URL | `baseURL` | `base_url` | `WithBaseURL` | api.cloudflare.com |

**注:** Go SDK のデフォルトの再試行回数（10回）は、TypeScript/Python（2回）より多く設定されています。

## タイムアウトの設定

**延長する場合:**
- 大規模なゾーン転送
- DNS の一括操作
- Worker スクリプトのアップロード

```typescript
const client = new Cloudflare({
  timeout: 300000, // 5 minutes
});
```

## 再試行回数の設定

**増やす場合:** レート制限に達しやすいワークフロー、ネットワークが不安定な場合

**減らす場合:** 失敗を素早く検出する必要がある場合、ユーザー向けのリクエスト

```typescript
// Increase retries for batch operations
const client = new Cloudflare({ maxRetries: 10 });

// Disable retries for fast-fail
const fastClient = new Cloudflare({ maxRetries: 0 });
```

## Wrangler CLI との連携

```bash
# Configure authentication
wrangler login
# Or
export CLOUDFLARE_API_TOKEN='token'

# Common commands that use API
wrangler deploy              # Uploads worker via API
wrangler kv:key put          # KV operations
wrangler r2 bucket create    # R2 operations
wrangler d1 execute          # D1 operations
wrangler pages deploy        # Pages operations

# Get API configuration
wrangler whoami              # Shows authenticated user
```

### wrangler.toml

```toml
name = "my-worker"
main = "src/index.ts"
compatibility_date = "2024-01-01"
account_id = "your-account-id"

# Can also use env vars:
# CLOUDFLARE_ACCOUNT_ID
# CLOUDFLARE_API_TOKEN
```

## 関連項目

- [api.md](./api.md) - クライアントの初期化、認証
- [gotchas.md](./gotchas.md) - レート制限、タイムアウトエラー
- [Wrangler リファレンス](../wrangler/) - CLI ツールの詳細
