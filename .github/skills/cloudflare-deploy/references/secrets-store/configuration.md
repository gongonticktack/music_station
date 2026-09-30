# 設定

## Wrangler の設定

### 基本的なバインディング

**wrangler.jsonc**:

```jsonc
{
  "secrets_store_secrets": [
    {
      "binding": "API_KEY",
      "store_id": "abc123",
      "secret_name": "stripe_api_key"
    }
  ]
}
```

**wrangler.toml**（代替形式）:

```toml
[[secrets_store_secrets]]
binding = "API_KEY"
store_id = "abc123"
secret_name = "stripe_api_key"
```

フィールド:
- `binding`: `env` でアクセスする際の変数名
- `store_id`: `wrangler secrets-store store list` から取得
- `secret_name`: 識別子（スペース不可）

### 環境ごとの設定

**wrangler.jsonc**:

```jsonc
{
  "env": {
    "production": {
      "secrets_store_secrets": [
        {
          "binding": "API_KEY",
          "store_id": "prod-store",
          "secret_name": "prod_api_key"
        }
      ]
    },
    "staging": {
      "secrets_store_secrets": [
        {
          "binding": "API_KEY",
          "store_id": "staging-store",
          "secret_name": "staging_api_key"
        }
      ]
    }
  }
}
```

**wrangler.toml**（代替形式）:

```toml
[env.production]
[[env.production.secrets_store_secrets]]
binding = "API_KEY"
store_id = "prod-store"
secret_name = "prod_api_key"

[env.staging]
[[env.staging.secrets_store_secrets]]
binding = "API_KEY"
store_id = "staging-store"
secret_name = "staging_api_key"
```

## Wrangler コマンド

### ストア管理

```bash
wrangler secrets-store store list
wrangler secrets-store store create my-store --remote
wrangler secrets-store store delete <store-id> --remote
```

### シークレット管理（本番環境）

```bash
# Create (interactive)
wrangler secrets-store secret create <store-id> \
  --name MY_SECRET --scopes workers --remote

# Create (piped)
cat secret.txt | wrangler secrets-store secret create <store-id> \
  --name MY_SECRET --scopes workers --remote

# List/get/update/delete
wrangler secrets-store secret list <store-id> --remote
wrangler secrets-store secret get <store-id> --name MY_SECRET --remote
wrangler secrets-store secret update <store-id> --name MY_SECRET --new-value "val" --remote
wrangler secrets-store secret delete <store-id> --name MY_SECRET --remote

# Duplicate
wrangler secrets-store secret duplicate <store-id> \
  --name ORIG --new-name COPY --remote
```

### ローカル開発

**重要**: 本番環境のシークレット（`--remote`）はローカル開発では利用できません。

```bash
# Create local-only (no --remote)
wrangler secrets-store secret create <store-id> --name DEV_KEY --scopes workers

wrangler dev    # Uses local secrets
wrangler deploy # Uses production secrets
```

ベストプラクティス: ローカル環境と本番環境で別々の名前を使用します。

```jsonc
{
  "env": {
    "development": {
      "secrets_store_secrets": [
        { "binding": "API_KEY", "store_id": "store", "secret_name": "dev_api_key" }
      ]
    },
    "production": {
      "secrets_store_secrets": [
        { "binding": "API_KEY", "store_id": "store", "secret_name": "prod_api_key" }
      ]
    }
  }
}
```

## ダッシュボード

### シークレットの作成

1. **Secrets Store** → **Create secret**
2. 入力項目: Name（スペース不可）、Value、Scope（`Workers`）、Comment
3. **Save**（保存後、値は非表示になります）

### バインディングの追加

**方法 1**: Worker → Settings → Bindings → Add → Secrets Store
**方法 2**: Worker の設定のドロップダウンからシークレットを直接作成

デプロイ方法:
- **Deploy**: 即時に 100% へ反映
- **Save version**: 段階的にロールアウト

## CI/CD

### GitHub Actions

```yaml
- name: Create secret
  env:
    CLOUDFLARE_API_TOKEN: ${{ secrets.CF_TOKEN }}
  run: |
    echo "${{ secrets.API_KEY }}" | \
    npx wrangler secrets-store secret create $STORE_ID \
      --name API_KEY --scopes workers --remote

- name: Deploy
  run: npx wrangler deploy
```

### GitLab CI

```yaml
script:
  - echo "$API_KEY_VALUE" | npx wrangler secrets-store secret create $STORE_ID --name API_KEY --scopes workers --remote
  - npx wrangler deploy
```

参照: [api.md](./api.md)、[patterns.md](./patterns.md)