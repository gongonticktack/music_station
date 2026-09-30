## 構成管理

**Smart Shield の進化に関する注意:** Argo Smart Routing は Smart Shield に統合されつつあります。以下の構成方法は引き続き有効であり、Terraform と IaC のパターンに変更はありません。

### Infrastructure as Code（Terraform）

```hcl
# terraform/argo.tf
# Note: Use Cloudflare Terraform provider

resource "cloudflare_argo" "example" {
  zone_id        = var.zone_id
  smart_routing  = "on"
  tiered_caching = "on"
}

variable "zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

output "argo_enabled" {
  value       = cloudflare_argo.example.smart_routing
  description = "Argo Smart Routing status"
}
```

### 環境ごとの構成

```typescript
// config/argo.ts
interface ArgoEnvironmentConfig {
  enabled: boolean;
  tieredCache: boolean;
  monitoring: {
    usageAlerts: boolean;
    threshold: number;
  };
}

const configs: Record<string, ArgoEnvironmentConfig> = {
  production: {
    enabled: true,
    tieredCache: true,
    monitoring: {
      usageAlerts: true,
      threshold: 1000, // GB
    },
  },
  staging: {
    enabled: true,
    tieredCache: false,
    monitoring: {
      usageAlerts: false,
      threshold: 100, // GB
    },
  },
  development: {
    enabled: false,
    tieredCache: false,
    monitoring: {
      usageAlerts: false,
      threshold: 0,
    },
  },
};

export function getArgoConfig(env: string): ArgoEnvironmentConfig {
  return configs[env] || configs.development;
}
```

### Pulumi の構成

```typescript
// pulumi/argo.ts
import * as cloudflare from '@pulumi/cloudflare';

const zone = new cloudflare.Zone('example-zone', {
  zone: 'example.com',
  plan: 'enterprise',
});

const argoSettings = new cloudflare.Argo('argo-config', {
  zoneId: zone.id,
  smartRouting: 'on',
  tieredCaching: 'on',
});

export const argoEnabled = argoSettings.smartRouting;
export const zoneId = zone.id;
```

## 請求の構成

Argo Smart Routing を有効にする前に、アカウントの請求が設定されていることを確認してください:

**前提条件:**
1. 有効な支払い方法が登録されていること
2. Enterprise 以上のプランであること
3. ゾーンで請求が有効になっていること

**ダッシュボードで請求ステータスを確認する:**
1. Account → Billing に移動
2. 支払い方法が設定されていることを確認
3. ゾーンのサブスクリプション状態を確認

**注意:** 請求を設定せずに Argo を有効にしようとすると、API レスポンスで `editable: false` が返されます。

## 環境変数の設定

**必須の環境変数:**
```bash
# .env
CLOUDFLARE_API_TOKEN=your_api_token_here
CLOUDFLARE_ZONE_ID=your_zone_id_here
CLOUDFLARE_ACCOUNT_ID=your_account_id_here

# Optional
ARGO_ENABLED=true
ARGO_TIERED_CACHE=true
```

**TypeScript 構成ローダー:**
```typescript
// config/env.ts
import { z } from 'zod';

const envSchema = z.object({
  CLOUDFLARE_API_TOKEN: z.string().min(1),
  CLOUDFLARE_ZONE_ID: z.string().min(1),
  CLOUDFLARE_ACCOUNT_ID: z.string().min(1),
  ARGO_ENABLED: z.string().optional().default('false'),
  ARGO_TIERED_CACHE: z.string().optional().default('false'),
});

export const env = envSchema.parse(process.env);

export const argoConfig = {
  enabled: env.ARGO_ENABLED === 'true',
  tieredCache: env.ARGO_TIERED_CACHE === 'true',
};
```

## CI/CD 連携

**GitHub Actions の例:**
```yaml
# .github/workflows/deploy-argo.yml
name: Deploy Argo Configuration

on:
  push:
    branches: [main]
    paths:
      - 'terraform/argo.tf'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        
      - name: Terraform Init
        run: terraform init
        working-directory: ./terraform
        
      - name: Terraform Apply
        run: terraform apply -auto-approve
        working-directory: ./terraform
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          TF_VAR_zone_id: ${{ secrets.CLOUDFLARE_ZONE_ID }}
```

## Enterprise プレビュー プログラム

Argo Smart Routing の機能と Smart Shield 連携を早期に利用するには:

**対象条件:**
- Enterprise プランの顧客
- Cloudflare のサポート契約が有効であること
- 本番トラフィックが月間 100GB を超えること

**参加方法:**
1. Cloudflare のアカウントチームまたはサポートに連絡
2. Argo/Smart Shield のプレビューアクセスをリクエスト
3. プレビュー用ゾーン構成を受け取る

**プレビュー機能:**
- 強化された分析とレポート
- Smart Shield の DDoS 連携
- 高度なルーティングポリシー
- ルーティング問題に対する優先サポート