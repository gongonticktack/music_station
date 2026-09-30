# Terraformのトラブルシューティングとベストプラクティス

よくある問題、セキュリティ上の考慮事項、ベストプラクティス。

## State Driftの問題

一部のリソースでは既知のState Driftが発生します。差分が継続して表示されるのを防ぐため、lifecycleブロックを追加してください。

| リソース | Drift属性 | 回避策 |
|----------|------------------|------------|
| `cloudflare_pages_project` | `deployment_configs.*` | `ignore_changes = [deployment_configs]` |
| `cloudflare_workers_script` | シークレットがREDACTEDとして返される | `ignore_changes = [secret_text_binding]` |
| `cloudflare_load_balancer` | `adaptive_routing`, `random_steering` | `ignore_changes = [adaptive_routing, random_steering]` |
| `cloudflare_workers_kv` | キー内の特殊文字（5.16.0未満） | 5.16.0以降にアップグレード |

```hcl
# Example: Ignore secret drift
resource "cloudflare_workers_script" "api" {
  account_id = var.account_id
  name = "api-worker"
  content = file("worker.js")
  secret_text_binding { name = "API_KEY"; text = var.api_key }
  
  lifecycle {
    ignore_changes = [secret_text_binding]
  }
}
```

## v5の破壊的変更

現在のプロバイダーはv5です（OpenAPIから自動生成）。v4からv5への移行には破壊的変更があります。

**リソース名の変更:**

| v4のリソース | v5のリソース | 備考 |
|-------------|-------------|-------|
| `cloudflare_record` | `cloudflare_dns_record` | |
| `cloudflare_worker_script` | `cloudflare_workers_script` | 注: 複数形 |
| `cloudflare_worker_*` | `cloudflare_workers_*` | すべてのWorkerリソース |
| `cloudflare_access_*` | `cloudflare_zero_trust_*` | AccessからZero Trustへ |

**属性の変更:**

| v4の属性 | v5の属性 | リソース |
|--------------|--------------|-----------|
| `zone` | `name` | zone |
| `account_id` | `account.id` | zone（オブジェクト構文） |
| `key` | `key_name` | KV |
| `location_hint` | `location` | R2 |

**Stateの移行:**

```bash
# Rename resources in state after v5 upgrade
terraform state mv cloudflare_record.example cloudflare_dns_record.example
terraform state mv cloudflare_worker_script.api cloudflare_workers_script.api
```

## リソース固有の注意点

### R2のロケーションの大文字・小文字

**問題:** TerraformでR2バケットを作成できるが、次回以降のapplyに失敗する  
**原因:** ロケーションは大文字で指定する必要がある  
**解決策:** `WNAM`, `ENAM`, `WEUR`, `EEUR`, `APAC`を使用する（`wnam`, `enam`などは使用しない）

```hcl
resource "cloudflare_r2_bucket" "assets" {
  account_id = var.account_id
  name = "assets"
  location = "WNAM"  # UPPERCASE required
}
```

### KVの特殊文字（5.16.0未満）

**問題:** `+`, `#`, `%`を含むキーでエンコードの問題が発生する  
**原因:** 5.16.0未満のプロバイダーにURLエンコードのバグがある  
**解決策:** 5.16.0以降にアップグレードするか、キー内の特殊文字を避ける

### D1のマイグレーション

**問題:** Terraformでデータベースは作成されるが、スキーマが空のままになる  
**原因:** Terraformが作成するのはD1リソースのみで、スキーマは作成しない  
**解決策:** Terraformのapply後にwranglerでマイグレーションを実行する

```bash
# After terraform apply
wrangler d1 migrations apply <db-name>
```

### Workerスクリプトのサイズ制限

**問題:** 「script too large」エラーでWorkerのデプロイに失敗する  
**原因:** Workerスクリプトと依存関係の合計が10 MBの上限を超えている  
**解決策:** コード分割、外部依存関係、またはミニファイを使用する

### PagesプロジェクトのDrift

**問題:** Pagesプロジェクトで`deployment_configs`に関する差分が継続して表示される  
**原因:** Cloudflare APIがTerraformのstateにないデフォルト値を追加する  
**解決策:** lifecycleのignoreブロックを追加する（上記のState Drift表を参照）

## よくあるエラー

### 「Error: couldn't find resource」

**原因:** リソースがTerraformの外部で削除された  
**解決策:** `terraform import cloudflare_zone.example <zone-id>`でリソースをstateに再インポートするか、`terraform state rm cloudflare_zone.example`でstateから削除する

### 「worker deploymentで409 Conflict」

**原因:** Terraformとwranglerの両方でWorkerを同時にデプロイしている  
**解決策:** デプロイ方法を1つ選ぶ。Terraformを使用する場合は、wranglerでのデプロイを削除する

### 「DNS record already exists」

**原因:** 既存のDNSレコードがTerraformのstateにインポートされていない  
**解決策:** CloudflareダッシュボードでレコードIDを確認し、`terraform import cloudflare_dns_record.example <zone-id>/<record-id>`でインポートする

### 「Invalid provider configuration」

**原因:** APIトークンがない、無効、または必要な権限が不足している  
**解決策:** 環境変数`CLOUDFLARE_API_TOKEN`を設定するか、ダッシュボードでトークンの権限を確認する

### 「State locking errors」

**原因:** 複数のTerraform実行が同時に行われている、またはクラッシュしたプロセスによる古いロックが残っている  
**解決策:** `terraform force-unlock <lock-id>`で古いロックを削除する（注意して使用）

## 制限

| リソース | 制限 | 備考 |
|----------|-------|-------|
| APIトークンのレート制限 | プランによって異なる | デバッグには`api_client_logging = true`を使用
| Workerスクリプトのサイズ | 10 MB | すべての依存関係を含む
| namespaceあたりのKVキー数 | 無制限 | 操作ごとに課金
| R2ストレージ | 無制限 | GBごとに課金
| D1データベース | アカウントあたり50,000 | 無料枠は10
| Pagesプロジェクト | アカウントあたり500 | 無料アカウントは100
| DNSレコード | zoneあたり3,500 | 無料プラン

## 関連項目

- [README](./README.md) - プロバイダーのセットアップ
- [Configuration](./configuration.md) - リソース
- [API](./api.md) - データソース
- [Patterns](./patterns.md) - ユースケース
- プロバイダーのドキュメント: https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs