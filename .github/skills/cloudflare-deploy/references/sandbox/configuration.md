# 設定

## getSandbox のオプション

```typescript
const sandbox = getSandbox(env.Sandbox, 'sandbox-id', {
  normalizeId: true,         // lowercase ID (required for preview URLs)
  sleepAfter: '10m',         // sleep after inactivity: '5m', '1h', '2d' (default: '10m')
  keepAlive: false,          // false = auto-timeout, true = never sleep
  
  containerTimeouts: {
    instanceGetTimeoutMS: 30000,  // 30s for provisioning (default: 30000)
    portReadyTimeoutMS: 90000     // 90s for container startup (default: 90000)
  }
});
```

**スリープ設定**:
- `sleepAfter`: 期間を表す文字列（例: '5m'、'10m'、'1h'）- デフォルト: '10m'
- `keepAlive: false`: 自動スリープ（デフォルト、コスト最適化）
- `keepAlive: true`: スリープしない（コスト高、明示的な `destroy()` が必要）
- スリープ中のサンドボックスは自動的に起動します（コールドスタート）

## インスタンスタイプ

wrangler.jsonc `instance_type`:
- `lite`: RAM 256MB、0.5 vCPU（デフォルト）
- `standard`: RAM 512MB、1 vCPU
- `heavy`: RAM 1GB、2 vCPU

## Dockerfile のパターン

**基本**:
```dockerfile
FROM docker.io/cloudflare/sandbox:latest
RUN pip3 install --no-cache-dir pandas numpy
EXPOSE 8080  # Required for wrangler dev
```

**科学計算**:
```dockerfile
FROM docker.io/cloudflare/sandbox:latest
RUN pip3 install --no-cache-dir \
    jupyter-server ipykernel matplotlib \
    pandas seaborn plotly scipy scikit-learn
```

**Node.js**:
```dockerfile
FROM docker.io/cloudflare/sandbox:latest
RUN npm install -g typescript ts-node
```

**重要**: `EXPOSE` は `wrangler dev` のポートアクセスに必要です。本番環境ではすべてのポートが自動的に公開されます。

## CLI コマンド

```bash
# Dev
wrangler dev                    # Start local dev server
wrangler deploy                 # Deploy to production
wrangler tail                   # Monitor logs
wrangler containers list        # Check container status
wrangler secret put KEY         # Set secret
```

## 環境変数とシークレット

**wrangler.jsonc**:
```jsonc
{
  "vars": {
    "ENVIRONMENT": "production",
    "API_URL": "https://api.example.com"
  },
  "r2_buckets": [{
    "binding": "DATA_BUCKET",
    "bucket_name": "my-data-bucket"
  }]
}
```

**使用方法**:
```typescript
const token = env.GITHUB_TOKEN;  // From wrangler secret
await sandbox.exec('git clone ...', {
  env: { GIT_TOKEN: token }
});
```

## プレビュー URL の設定

**前提条件**:
- ワイルドカード DNS を設定したカスタムドメイン: `*.yourdomain.com → worker.yourdomain.com`
- `.workers.dev` ドメインはサポートされていません
- getSandbox 内の `normalizeId: true`
- fetch ハンドラーで `proxyToSandbox()` を最初に呼び出す

## Cron トリガー（事前ウォームアップ）

```jsonc
{
  "triggers": {
    "crons": ["*/5 * * * *"]  // Every 5 minutes
  }
}
```

```typescript
export default {
  async scheduled(event: ScheduledEvent, env: Env) {
    const sandbox = getSandbox(env.Sandbox, 'main');
    await sandbox.exec('echo "keepalive"');  // Wake sandbox
  }
};
```

## ロギングの設定

**wrangler.jsonc**:
```jsonc
{
  "vars": {
    "SANDBOX_LOG_LEVEL": "debug",  // debug | info | warn | error (default: info)
    "SANDBOX_LOG_FORMAT": "pretty" // json | pretty (default: json)
  }
}
```

**開発環境**: `debug` + `pretty`。**本番環境**: `info`/`warn` + `json`。

## タイムアウトの環境変数による上書き

環境変数でデフォルトのタイムアウトを上書きします:

```jsonc
{
  "vars": {
    "SANDBOX_INSTANCE_TIMEOUT_MS": "60000",  // Override instanceGetTimeoutMS
    "SANDBOX_PORT_TIMEOUT_MS": "120000"      // Override portReadyTimeoutMS
  }
}
```
