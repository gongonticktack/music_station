# Cloudflare WAF エキスパートスキルリファレンス

**専門分野**: Cloudflare Web Application Firewall（WAF）の設定、カスタムルール、マネージドルールセット、レート制限、攻撃検知、API 統合

## 概要

Cloudflare WAF は、マネージドルールセットとカスタムルールによって Web アプリケーションを攻撃から保護します。

**検知（マネージドルールセット）**
- Cloudflare が管理する事前設定済みルール
- CVE ベースのルール、OWASP Top 10 を網羅
- 主なルールセットは 3 種類: Cloudflare Managed、OWASP CRS、Exposed Credentials
- アクション: log、block、challenge、js_challenge、managed_challenge

**緩和（カスタムルールとレート制限）**
- Wirefilter 構文を使ったカスタム式
- 攻撃スコアに基づくブロック（`cf.waf.score`）
- IP、ユーザー、またはカスタム特性ごとのレート制限
- アクション: block、challenge、js_challenge、managed_challenge、log、skip

## クイックスタート

### Cloudflare Managed Ruleset をデプロイする
```typescript
import Cloudflare from 'cloudflare';

const client = new Cloudflare({ apiToken: process.env.CF_API_TOKEN });

// Deploy managed ruleset to zone
await client.rulesets.create({
  zone_id: 'zone_id',
  kind: 'zone',
  phase: 'http_request_firewall_managed',
  name: 'Deploy Cloudflare Managed Ruleset',
  rules: [{
    action: 'execute',
    action_parameters: {
      id: 'efb7b8c949ac4650a09736fc376e9aee', // Cloudflare Managed Ruleset
    },
    expression: 'true',
    enabled: true,
  }],
});
```

### カスタムルールを作成する
```typescript
// Block requests with attack score >= 40
await client.rulesets.create({
  zone_id: 'zone_id',
  kind: 'zone',
  phase: 'http_request_firewall_custom',
  name: 'Custom WAF Rules',
  rules: [{
    action: 'block',
    expression: 'cf.waf.score gt 40',
    description: 'Block high attack scores',
    enabled: true,
  }],
});
```

### レート制限を作成する
```typescript
await client.rulesets.create({
  zone_id: 'zone_id',
  kind: 'zone',
  phase: 'http_ratelimit',
  name: 'API Rate Limits',
  rules: [{
    action: 'block',
    expression: 'http.request.uri.path eq "/api/login"',
    action_parameters: {
      ratelimit: {
        characteristics: ['cf.colo.id', 'ip.src'],
        period: 60,
        requests_per_period: 10,
        mitigation_timeout: 600,
      },
    },
    enabled: true,
  }],
});
```

## マネージドルールセットのクイックリファレンス

| ルールセット名 | ID | 対象範囲 |
|--------------|----|---------| 
| Cloudflare Managed | `efb7b8c949ac4650a09736fc376e9aee` | OWASP Top 10、CVE |
| OWASP Core Ruleset | `4814384a9e5d4991b9815dcfc25d2f1f` | OWASP ModSecurity CRS |
| Exposed Credentials Check | `c2e184081120413c86c3ab7e14069605` | 認証情報の詰め込み攻撃 |

## フェーズ

WAF ルールは特定のフェーズで実行されます:
- `http_request_firewall_managed` - マネージドルールセット
- `http_request_firewall_custom` - カスタムルール
- `http_ratelimit` - レート制限ルール
- `http_request_sbfm` - Super Bot Fight Mode（Pro 以上）

## 読む順序

1. **[api.md](api.md)** - SDK メソッド、式、アクション、パラメーター
2. **[configuration.md](configuration.md)** - Wrangler、Terraform、Pulumi を使ったセットアップ
3. **[patterns.md](patterns.md)** - 一般的なパターン: マネージドルールのデプロイ、レート制限、スキップ、オーバーライド
4. **[gotchas.md](gotchas.md)** - 実行順序、制限、式のエラー

## 関連項目

- [Cloudflare WAF Docs](https://developers.cloudflare.com/waf/)
- [Ruleset Engine](https://developers.cloudflare.com/ruleset-engine/)
- [Expression Reference](https://developers.cloudflare.com/ruleset-engine/rules-language/)