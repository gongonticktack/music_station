# パターンとユースケース

## スキーマとJWTでAPIを保護する

```bash
# 1. Upload OpenAPI schema
POST /zones/{zone_id}/api_gateway/user_schemas

# 2. Configure JWT validation
POST /zones/{zone_id}/api_gateway/token_validation
{
  "name": "Auth0",
  "location": {"header": "Authorization"},
  "jwks": "{...}"
}

# 3. Create JWT rule
POST /zones/{zone_id}/api_gateway/jwt_validation_rules

# 4. Set schema validation action
PUT /zones/{zone_id}/api_gateway/settings/schema_validation
{"validation_default_mitigation_action": "block"}
```

## 段階的な適用

```
1. Log mode: Observe false positives
   - Schema: Action = Log
   - JWT: Action = Log

2. Block subset: Protect critical endpoints
   - Change specific endpoint actions to Block
   - Monitor firewall events

3. Full enforcement: Block all violations
   - Change default action to Block
   - Handle fallthrough with custom rule
```

## BOLAの検出

### 列挙の検出
リソースへの連続したアクセス（例: `/users/1`、`/users/2`、`/users/3`）を検出します。

```javascript
// Block BOLA enumeration attempts
(cf.api_gateway.cf-risk-bola-enumeration and http.host eq "api.example.com")
// Action: Block or Challenge
```

### パラメーター汚染
リクエスト内の重複したパラメーターや過剰なパラメーターを検出します。

```javascript
// Block parameter pollution
(cf.api_gateway.cf-risk-bola-pollution and http.host eq "api.example.com")
// Action: Block
```

### BOLAに対する複合的な保護
```javascript
// Comprehensive BOLA rule
(cf.api_gateway.cf-risk-bola-enumeration or cf.api_gateway.cf-risk-bola-pollution)
and http.host eq "api.example.com"
// Action: Block
```

## 認証状況

### 認証の欠如を検出する
```javascript
// Log endpoints lacking authentication
(cf.api_gateway.cf-risk-missing-auth and http.host eq "api.example.com")
// Action: Log (for audit)
```

### 認証方式の混在を検出する
```javascript
// Alert on inconsistent auth patterns
(cf.api_gateway.cf-risk-mixed-auth and http.host eq "api.example.com")
// Action: Log (review required)
```

## フォールスルーの検出（シャドーAPI）

```javascript
// WAF Custom Rule
(cf.api_gateway.fallthrough_triggered and http.host eq "api.example.com")
// Action: Log (discover unknown) or Block (strict)
```

## ユーザー単位のレート制限

```javascript
// Rate Limiting Rule (modern syntax)
(http.host eq "api.example.com" and
 is_jwt_valid(http.request.jwt.payload["{config_id}"][0]))

// Rate: 100 req/60s
// Counting expression: lookup_json_string(http.request.jwt.payload["{config_id}"][0], "sub")
```

## 大量の不正リクエストへの対応

```javascript
// Detect abnormal traffic spikes
(cf.api_gateway.volumetric_abuse_detected and http.host eq "api.example.com")
// Action: Challenge or Rate Limit

// Combined with rate limiting
(cf.api_gateway.volumetric_abuse_detected or
 cf.threat_score gt 50) and http.host eq "api.example.com"
// Action: JS Challenge
```

## GraphQLの保護

```javascript
// Block oversized queries
(http.request.uri.path eq "/graphql" and
 cf.api_gateway.graphql_query_size gt 100000)
// Action: Block

// Block deep nested queries
(http.request.uri.path eq "/graphql" and
 cf.api_gateway.graphql_query_depth gt 10)
// Action: Block
```

## アーキテクチャのパターン

**公開API:** ディスカバリー + Schema Validation 2.0 + JWT + レート制限 + Bot Management  
**パートナー向けAPI:** mTLS + スキーマ検証 + Sequence Mitigation  
**内部API:** ディスカバリー + スキーマ学習 + 認証状況

## OWASP API Security Top 10との対応（2026年）

| OWASPの問題 | API Shieldの対策 |
|-------------|---------------------|
| API1:2023 オブジェクトレベルの認可の不備 | **BOLAの検出**（列挙とパラメーター汚染）、シーケンス緩和、スキーマ、JWT、レート制限 |
| API2:2023 認証の不備 | **認証状況**、mTLS、JWT検証、Bot Management |
| API3:2023 オブジェクトプロパティレベルの認可の不備 | スキーマ検証、JWT検証 |
| API4:2023 リソースへの無制限なアクセス | レート制限、**大量の不正リクエストの検出**、**GraphQLの保護**、Bot Management |
| API5:2023 機能レベルの認可の不備 | スキーマ検証、JWT検証、認証状況 |
| API6:2023 制限のないビジネスフロー | シーケンス緩和、Bot Management |
| API7:2023 SSRF | スキーマ検証、WAFのマネージドルール |
| API8:2023 セキュリティ設定の不備 | **Schema Validation 2.0**、認証状況、WAFルール |
| API9:2023 インベントリ管理の不備 | **APIディスカバリー**、スキーマ学習、認証状況 |
| API10:2023 安全でないAPIの利用 | JWT検証、スキーマ検証、WAFのマネージドルール |

## 監視

**セキュリティイベント:** `Security > Events` → フィルター: Action = block、Service = API Shield  
**ファイアウォール分析:** `Analytics > Security` → `cf.api_gateway.*` フィールドでフィルタリング  
**Logpushのフィールド:** APIGatewayAuthIDPresent、APIGatewayRequestViolatesSchema、APIGatewayFallthroughDetected、JWTValidationResult

## 提供状況（2026年）

| 機能 | 提供対象 | 備考 |
|---------|-------------|-------|
| mTLS（Cloudflare管理のCA） | すべてのプラン | セルフサービス |
| エンドポイント管理 | すべてのプラン | 操作数に制限あり |
| Schema Validation 2.0 | すべてのプラン | 操作数に制限あり |
| APIディスカバリー | Enterprise | 10,000件以上の操作 |
| JWT検証 | Enterpriseのアドオン | 完全な検証 |
| BOLAの検出 | Enterpriseのアドオン | セッションIDが必要 |
| 認証状況 | Enterpriseのアドオン | セキュリティ監査 |
| 大量の不正リクエストの検出 | Enterpriseのアドオン | トラフィック分析 |
| GraphQLの保護 | Enterpriseのアドオン | クエリの制限 |
| Sequence Mitigation | Enterprise（ベータ版） | 担当チームにお問い合わせください |
| 全機能セット | Enterpriseのアドオン | すべての機能 |

**Enterpriseの制限:** 10,000件の操作（上限を引き上げる場合はお問い合わせください）。契約前の評価向けにプレビューアクセスを利用できます。

## 関連項目

- [configuration.md](configuration.md) - ルールを作成する前にすべての機能を設定する
- [api.md](api.md) - ファイアウォールのフィールドとAPIエンドポイントのリファレンス
- [gotchas.md](gotchas.md) - よくある問題と制限
