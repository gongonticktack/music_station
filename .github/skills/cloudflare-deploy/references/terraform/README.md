# Cloudflare Terraform プロバイダー

**Cloudflare Terraform プロバイダーに関する専門的なガイダンス — Cloudflare リソースをコードとして管理するためのものです。**

## 基本原則

- **プロバイダー優先**: すべてのインフラストラクチャに Terraform プロバイダーを使用し、同じリソースに対して wrangler.jsonc と併用しない
- **状態管理**: チーム環境では常にリモート状態（S3、Terraform Cloud など）を使用する
- **モジュール化アーキテクチャ**: 共通パターン（ゾーン、Workers、Pages）向けに再利用可能なモジュールを作成する
- **バージョンの固定**: アップグレードを予測可能にするため、常に `~>` を使ってプロバイダーのバージョンを固定する
- **シークレット管理**: 機密データには変数と環境変数を使用し、API トークンをハードコードしない

## プロバイダーのバージョン

| バージョン | 状態 | 備考 |
|---------|--------|-------|
| 5.x | 現行 | OpenAPI から自動生成。v4 からの破壊的変更あり |
| 4.x | レガシー | 手動保守、非推奨 |

**重要:** v5 では多くのリソース名が変更されました（`cloudflare_record` → `cloudflare_dns_record`、`cloudflare_worker_*` → `cloudflare_workers_*`）。移行の詳細は [gotchas.md](./gotchas.md#v5-breaking-changes) を参照してください。

## プロバイダーのセットアップ

### 基本設定

```hcl
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.15.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token  # or CLOUDFLARE_API_TOKEN env var
}
```

### 認証方法（優先順）

1. **API トークン（推奨）**: `api_token` または `CLOUDFLARE_API_TOKEN`
   - 作成場所: ダッシュボード → マイプロフィール → API トークン
   - セキュリティのため、特定のアカウント／ゾーンにスコープを限定する
   
2. **グローバル API キー（レガシー）**: `api_key` + `api_email` または `CLOUDFLARE_API_KEY` + `CLOUDFLARE_EMAIL`
   - 安全性が低いため、代わりにトークンを使用する
   
3. **ユーザーサービスキー**: Origin CA 証明書用の `user_service_key`



## クイックリファレンス: よく使うコマンド

```bash
terraform init          # Initialize provider
terraform plan          # Plan changes
terraform apply         # Apply changes
terraform destroy       # Destroy resources
terraform import cloudflare_zone.example <zone-id>  # Import existing
terraform state list    # List resources in state
terraform output        # Show outputs
terraform fmt -recursive  # Format code
terraform validate      # Validate configuration
```

## 既存リソースのインポート

cf-terraforming を使って、既存の Cloudflare リソースから設定を生成します:

```bash
# Install
brew install cloudflare/cloudflare/cf-terraforming

# Generate HCL from existing resources
cf-terraforming generate --resource-type cloudflare_dns_record --zone <zone-id>

# Import into Terraform state
cf-terraforming import --resource-type cloudflare_dns_record --zone <zone-id>
```

## 読む順序

1. プロバイダーのセットアップと認証については [README.md](./README.md) から始めてください
2. リソースの設定については [configuration.md](./configuration.md) を確認してください
3. データソースと既存リソースのクエリについては [api.md](./api.md) を確認してください
4. 複数環境および CI/CD のパターンについては [patterns.md](./patterns.md) を参照してください
5. 状態のドリフト、v5 の破壊的変更、トラブルシューティングについては [gotchas.md](./gotchas.md) を読んでください

## このリファレンスの内容
- [configuration.md](./configuration.md) - ゾーン、DNS、Workers、KV、R2、D1、Pages、ルールセット向けリソース
- [api.md](./api.md) - 既存リソース向けデータソース
- [patterns.md](./patterns.md) - アーキテクチャパターン、複数環境のセットアップ、CI/CD 統合
- [gotchas.md](./gotchas.md) - よくある問題、セキュリティ、ベストプラクティス

## 関連項目
- [pulumi](../pulumi/) - Cloudflare 用の代替 IaC ツール
- [wrangler](../wrangler/) - CLI によるデプロイの代替手段
- [workers](../workers/) - Worker ランタイムのドキュメント