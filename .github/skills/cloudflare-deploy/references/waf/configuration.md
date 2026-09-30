# 設定

## 前提条件

**APIトークン**: https://dash.cloudflare.com/profile/api-tokens で作成
- 権限: `Zone.WAF Edit` または `Zone.Firewall Services Edit`
- ゾーンリソース: 特定のゾーンまたはすべてのゾーンを含める

**ゾーンID**: ダッシュボードの「Overview」>「API」セクション（右サイドバー）で確認できます

```bash
# Set environment variables
export CF_API_TOKEN="your_api_token_here"
export ZONE_ID="your_zone_id_here"
```

## TypeScript SDKの使用方法

```bash
npm install cloudflare
```

```typescript
import Cloudflare from 'cloudflare';

const client = new Cloudflare({ apiToken: process.env.CF_API_TOKEN });

// Custom rules
await client.rulesets.create({
  zone_id: process.env.ZONE_ID,
  kind: 'zone',
  phase: 'http_request_firewall_custom',
  name: 'Custom WAF',
  rules: [
    { action: 'block', expression: 'cf.waf.score gt 50', enabled: true },
    { action: 'challenge', expression: 'http.request.uri.path eq "/admin"', enabled: true },
  ],
});

// Managed ruleset
await client.rulesets.create({
  zone_id: process.env.ZONE_ID,
  phase: 'http_request_firewall_managed',
  rules: [{
    action: 'execute',
    action_parameters: { id: 'efb7b8c949ac4650a09736fc376e9aee' },
    expression: 'true',
  }],
});

// Rate limiting
await client.rulesets.create({
  zone_id: process.env.ZONE_ID,
  phase: 'http_ratelimit',
  rules: [{
    action: 'block',
    expression: 'http.request.uri.path starts_with "/api"',
    action_parameters: {
      ratelimit: {
        characteristics: ['cf.colo.id', 'ip.src'],
        period: 60,
        requests_per_period: 100,
        mitigation_timeout: 600,
      },
    },
  }],
});
```

## Terraformの設定

```hcl
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_ruleset" "waf_custom" {
  zone_id = var.zone_id
  kind    = "zone"
  phase   = "http_request_firewall_custom"

  rules {
    action     = "block"
    expression = "cf.waf.score gt 50"
  }
}
```

**マネージドルールセットとレート制限**:
```hcl
resource "cloudflare_ruleset" "waf_managed" {
  zone_id = var.zone_id
  name    = "Managed Ruleset"
  kind    = "zone"
  phase   = "http_request_firewall_managed"

  rules {
    action = "execute"
    action_parameters {
      id = "efb7b8c949ac4650a09736fc376e9aee"
      overrides {
        rules {
          id = "5de7edfa648c4d6891dc3e7f84534ffa"
          action = "log"
        }
      }
    }
    expression = "true"
  }
}

resource "cloudflare_ruleset" "rate_limiting" {
  zone_id = var.zone_id
  phase   = "http_ratelimit"

  rules {
    action = "block"
    expression = "http.request.uri.path starts_with \"/api\""
    ratelimit {
      characteristics     = ["cf.colo.id", "ip.src"]
      period              = 60
      requests_per_period = 100
      mitigation_timeout  = 600
    }
  }
}
```

## Pulumiの設定

```typescript
import * as cloudflare from '@pulumi/cloudflare';

const zoneId = 'zone_id';

// Custom rules
const wafCustom = new cloudflare.Ruleset('waf-custom', {
  zoneId,
  phase: 'http_request_firewall_custom',
  rules: [
    { action: 'block', expression: 'cf.waf.score gt 50', enabled: true },
    { action: 'challenge', expression: 'http.request.uri.path eq "/admin"', enabled: true },
  ],
});

// Managed ruleset
const wafManaged = new cloudflare.Ruleset('waf-managed', {
  zoneId,
  phase: 'http_request_firewall_managed',
  rules: [{
    action: 'execute',
    actionParameters: { id: 'efb7b8c949ac4650a09736fc376e9aee' },
    expression: 'true',
  }],
});

// Rate limiting
const rateLimiting = new cloudflare.Ruleset('rate-limiting', {
  zoneId,
  phase: 'http_ratelimit',
  rules: [{
    action: 'block',
    expression: 'http.request.uri.path starts_with "/api"',
    ratelimit: {
      characteristics: ['cf.colo.id', 'ip.src'],
      period: 60,
      requestsPerPeriod: 100,
      mitigationTimeout: 600,
    },
  }],
});
```

## ダッシュボードでの設定

1. **Security** > **WAF** に移動
2. タブを選択:
   - **Managed rules** - マネージドルールセットをデプロイ／設定
   - **Custom rules** - カスタムルールを作成
   - **Rate limiting rules** - レート制限を設定
3. **Deploy** または **Create rule** をクリック

**テスト**: デプロイ前にSecurity Eventsを使用して式をテストします。

## Wranglerとの連携

WAFの設定はゾーン単位です（Worker固有ではありません）。設定方法:
- ダッシュボードUI
- SDK経由のCloudflare API
- Terraform/Pulumi（IaC）

**WorkersはWAFの恩恵を自動的に受けます** - Workerコードの変更は不要です。

**例: WorkerからWAF APIをクエリする**:
```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    return fetch(`https://api.cloudflare.com/client/v4/zones/${env.ZONE_ID}/rulesets`, {
      headers: { 'Authorization': `Bearer ${env.CF_API_TOKEN}` },
    });
  },
};
```