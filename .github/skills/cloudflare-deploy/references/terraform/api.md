# Terraform データソースリファレンス

既存の Cloudflare リソースを照会し、構成内で参照します。

## v5 データソース名

| v4 名 | v5 名 | 備考 |
|---------|---------|-------|
| `cloudflare_record` | `cloudflare_dns_record` | |
| `cloudflare_worker_script` | `cloudflare_workers_script` | 注: 複数形 |
| `cloudflare_access_*` | `cloudflare_zero_trust_*` | Access → Zero Trust |

## Zone データソース

```hcl
# Get zone by name
data "cloudflare_zone" "example" {
  name = "example.com"
}

# Use in resources
resource "cloudflare_dns_record" "www" {
  zone_id = data.cloudflare_zone.example.id
  name = "www"
  # ...
}
```

## Account データソース

```hcl
# List all accounts
data "cloudflare_accounts" "main" {
  name = "My Account"
}

# Use account ID
resource "cloudflare_worker_script" "api" {
  account_id = data.cloudflare_accounts.main.accounts[0].id
  # ...
}
```

## Worker データソース

```hcl
# Get existing worker script (v5: cloudflare_workers_script)
data "cloudflare_workers_script" "existing" {
  account_id = var.account_id
  name = "existing-worker"
}

# Reference in service bindings
resource "cloudflare_workers_script" "consumer" {
  service_binding {
    name = "UPSTREAM"
    service = data.cloudflare_workers_script.existing.name
  }
}
```

## KV データソース

```hcl
# Get KV namespace
data "cloudflare_workers_kv_namespace" "existing" {
  account_id = var.account_id
  namespace_id = "abc123"
}

# Use in worker binding
resource "cloudflare_workers_script" "api" {
  kv_namespace_binding {
    name = "KV"
    namespace_id = data.cloudflare_workers_kv_namespace.existing.id
  }
}
```

## Lists データソース

```hcl
# Get IP lists for WAF rules
data "cloudflare_list" "blocked_ips" {
  account_id = var.account_id
  name = "blocked_ips"
}
```

## IP ranges データソース

```hcl
# Get Cloudflare IP ranges (for firewall rules)
data "cloudflare_ip_ranges" "cloudflare" {}

output "ipv4_cidrs" {
  value = data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks
}

output "ipv6_cidrs" {
  value = data.cloudflare_ip_ranges.cloudflare.ipv6_cidr_blocks
}

# Use in security group rules (AWS example)
resource "aws_security_group_rule" "allow_cloudflare" {
  type = "ingress"
  from_port = 443
  to_port = 443
  protocol = "tcp"
  cidr_blocks = data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks
  security_group_id = aws_security_group.web.id
}
```

## よく使うパターン

### インポート ID の形式

| リソース | インポート ID の形式 |
|----------|------------------|
| `cloudflare_zone` | `<zone-id>` |
| `cloudflare_dns_record` | `<zone-id>/<record-id>` |
| `cloudflare_workers_script` | `<account-id>/<script-name>` |
| `cloudflare_workers_kv_namespace` | `<account-id>/<namespace-id>` |
| `cloudflare_r2_bucket` | `<account-id>/<bucket-name>` |
| `cloudflare_d1_database` | `<account-id>/<database-id>` |
| `cloudflare_pages_project` | `<account-id>/<project-name>` |

```bash
# Example: Import DNS record
terraform import cloudflare_dns_record.example <zone-id>/<record-id>
```

### モジュール間での参照

```hcl
# modules/worker/main.tf
data "cloudflare_zone" "main" {
  name = var.domain
}

resource "cloudflare_worker_route" "api" {
  zone_id = data.cloudflare_zone.main.id
  pattern = "api.${var.domain}/*"
  script_name = cloudflare_worker_script.api.name
}
```

### 重要な値を出力する

```hcl
output "zone_id" {
  value = cloudflare_zone.main.id
  description = "Zone ID for DNS management"
}

output "worker_url" {
  value = "https://${cloudflare_worker_domain.api.hostname}"
  description = "Worker API endpoint"
}

output "kv_namespace_id" {
  value = cloudflare_workers_kv_namespace.app.id
  sensitive = false
}

output "name_servers" {
  value = cloudflare_zone.main.name_servers
  description = "Name servers for domain registration"
}
```

## 関連項目

- [README](./README.md) - プロバイダーのセットアップ
- [Configuration Reference](./configuration.md) - すべてのリソースタイプ
- [Patterns](./patterns.md) - アーキテクチャのパターン
- [Troubleshooting](./gotchas.md) - よくある問題
