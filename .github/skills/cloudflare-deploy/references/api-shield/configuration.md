# 設定

## Schema Validation 2.0 の設定

> ⚠️ **従来の Schema Validation は非推奨です。** Schema Validation 2.0 を使用してください。

**スキーマのアップロード（ダッシュボード）：**
```
Security > API Shield > Schema Validation > Add validation
- Upload .yml/.yaml/.json (OpenAPI v3.0)
- Endpoints auto-added to Endpoint Management
- Action: Log | Block | None
- Body inspection: JSON payloads
```

**検証アクションの変更：**
```
Security > API Shield > Settings > Schema Validation
Per-endpoint: Filter → ellipses → Change action
Default action: Set global mitigation action
```

**従来の方式からの移行：**
```
1. Export existing schema (if available)
2. Delete all Classic schema validation rules
3. Wait 5 min for cache clear
4. Re-upload via Schema Validation 2.0 interface
5. Verify in Security > Events
```

**フォールスルールール**（未知のエンドポイントをすべて対象にする）：
```
Security > API Shield > Settings > Fallthrough > Use Template
- Select hostnames
- Create rule with cf.api_gateway.fallthrough_triggered
- Action: Log (discover) or Block (strict)
```

**リクエストボディの検査：** `application/json`、`*/*`、`application/*` に対応しています。回避を防ぐため、オリジンでの MIME スニッフィングを無効にしてください。

## JWT 検証

**トークン設定の作成：**
```
Security > API Shield > Settings > JWT Settings > Add configuration
- Name: "Auth0 JWT Config"
- Location: Header/Cookie + name (e.g., "Authorization")
- JWKS: Paste public keys from IdP
```

**検証ルールの作成：**
```
Security > API Shield > API Rules > Add rule
- Hostname: api.example.com
- Deselect endpoints to ignore
- Token config: Select config
- Enforce presence: Ignore or Mark as non-compliant
- Action: Log/Block/Challenge
```

**JWT クレームに基づくレート制限：**
```wirefilter
lookup_json_string(http.request.jwt.claims["{config_id}"][0], "sub")
```

**特別なケース：**
- JWT が 2 つあり、IdP が異なる場合：設定を 2 つ作成し、両方を選択して「Validate all」を指定します
- IdP の移行：設定を 2 つ、ルールを 2 つ作成し、移行段階に応じてアクションを調整します
- Bearer プレフィックス：API Shield はプレフィックスの有無に対応します
- 入れ子になったクレーム：ドット表記 `user.email` を使用します

## 相互 TLS（mTLS）

**設定：**
```
SSL/TLS > Client Certificates > Create Certificate
- Generate CF-managed CA (all plans)
- Upload custom CA (Enterprise, max 5)
```

**mTLS ルールの設定：**
```
Security > API Shield > mTLS
- Select hostname(s)
- Choose certificate(s)
- Action: Block/Log/Challenge
```

**テスト：**
```bash
openssl req -x509 -newkey rsa:4096 -keyout client-key.pem -out client-cert.pem -days 365
curl https://api.example.com/endpoint --cert client-cert.pem --key client-key.pem
```

## セッション識別子

BOLA Detection、Sequence Mitigation、分析に不可欠です。API ユーザーを一意に識別できるヘッダーまたは Cookie を設定してください。

**例：** JWT の sub クレーム、セッショントークン、API キー、ユーザー ID を格納するカスタムヘッダー

**設定：**
```
Security > API Shield > Settings > Session Identifiers
- Type: Header/Cookie
- Name: "X-User-ID" or "Authorization"
```

## BOLA 検出

オブジェクトレベルの認可の不備を悪用する攻撃（列挙やパラメーター汚染）を検出します。

**有効化：**
```
Security > API Shield > Schema Validation > [Select Schema] > BOLA Detection
- Enable detection
- Threshold: Sensitivity level (Low/Medium/High)
- Action: Log or Block
```

**要件：**
- Schema Validation 2.0 が有効になっていること
- セッション識別子が設定されていること
- 最低トラフィック量：エンドポイントごとに 1 日 1,000 件以上のリクエスト

## 認証状況

保護されていないエンドポイントや、保護の適用が一貫していないエンドポイントを特定します。

**レポートの表示：**
```
Security > API Shield > Authentication Posture
- Shows endpoints lacking JWT/mTLS
- Highlights mixed authentication patterns
```

**対処方法：**
1. 指摘されたエンドポイントを確認します
2. JWT 検証ルールを追加します
3. 機密性の高いエンドポイントに mTLS を設定します
4. 認証状況のスコアを監視します

## 大量リクエストによる悪用と GraphQL

**大量リクエストによる悪用の検出：**
`Security > API Shield > Settings > Volumetric Abuse Detection`
- エンドポイントごとの監視を有効にし、しきい値とアクション（Log | Challenge | Block）を設定します

**GraphQL の保護：**
`Security > API Shield > Settings > GraphQL Protection`
- クエリの最大深さ：10、最大サイズ：100KB、イントロスペクションをブロック（本番環境）

## Terraform

```hcl
# Session identifier
resource "cloudflare_api_shield" "main" {
  zone_id = var.zone_id
  auth_id_characteristics {
    type = "header"
    name = "Authorization"
  }
}

# Add endpoint
resource "cloudflare_api_shield_operation" "users_get" {
  zone_id  = var.zone_id
  method   = "GET"
  host     = "api.example.com"
  endpoint = "/api/users/{id}"
}

# JWT validation rule
resource "cloudflare_ruleset" "jwt_validation" {
  zone_id = var.zone_id
  name    = "API JWT Validation"
  kind    = "zone"
  phase   = "http_request_firewall_custom"

  rules {
    action = "block"
    expression = "(http.host eq \"api.example.com\" and not is_jwt_valid(http.request.jwt.payload[\"{config_id}\"][0]))"
    description = "Block invalid JWTs"
  }
}
```

## 関連項目

- [api.md](api.md) - API エンドポイントと Workers の統合
- [patterns.md](patterns.md) - ファイアウォールルールとデプロイのパターン
- [gotchas.md](gotchas.md) - トラブルシューティングと制限事項
