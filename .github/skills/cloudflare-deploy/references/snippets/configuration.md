# スニペット設定ガイド

## 設定方法

### 1. ダッシュボード（GUI）
**最適な用途**: 手早いテスト、単一のスニペット、視覚的なルール作成

```
1. Go to zone → Rules → Snippets
2. Click "Create Snippet" or select template
3. Enter snippet name (a-z, 0-9, _ only, cannot change later)
4. Write JavaScript code (32KB max)
5. Configure snippet rule:
   - Expression Builder (visual) or Expression Editor (text)
   - Use Ruleset Engine filter expressions
6. Test with Preview/HTTP tabs
7. Deploy or Save as Draft
```

### 2. REST API
**最適な用途**: CI/CD、自動化、プログラムによる管理

```bash
# Create/update snippet
curl "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/snippets/$SNIPPET_NAME" \
  --request PUT \
  --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  --form "files=@example.js" \
  --form "metadata={\"main_module\": \"example.js\"}"

# Create snippet rule
curl "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/snippets/snippet_rules" \
  --request PUT \
  --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{
    "rules": [
      {
        "description": "Trigger snippet on /api paths",
        "enabled": true,
        "expression": "starts_with(http.request.uri.path, \"/api/\")",
        "snippet_name": "api_snippet"
      }
    ]
  }'

# List snippets
curl "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/snippets" \
  --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN"

# Delete snippet
curl "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/snippets/$SNIPPET_NAME" \
  --request DELETE \
  --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
```

### 3. Terraform
**最適な用途**: Infrastructure as Code、複数ゾーンへのデプロイ

```hcl
# Configure Terraform provider
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Create snippet
resource "cloudflare_snippet" "security_headers" {
  zone_id = var.zone_id
  name    = "security_headers"
  
  main_module = "security_headers.js"
  files {
    name    = "security_headers.js"
    content = file("${path.module}/snippets/security_headers.js")
  }
}

# Create snippet rule
resource "cloudflare_snippet_rules" "security_rules" {
  zone_id = var.zone_id
  
  rules {
    description  = "Apply security headers to all requests"
    enabled      = true
    expression   = "true"
    snippet_name = cloudflare_snippet.security_headers.name
  }
}
```

### 4. Pulumi
**最適な用途**: マルチクラウド IaC、TypeScript/Python/Go のワークフロー

```typescript
import * as cloudflare from "@pulumi/cloudflare";
import * as fs from "fs";

// Create snippet
const securitySnippet = new cloudflare.Snippet("security-headers", {
  zoneId: zoneId,
  name: "security_headers",
  mainModule: "security_headers.js",
  files: [{
    name: "security_headers.js",
    content: fs.readFileSync("./snippets/security_headers.js", "utf8"),
  }],
});

// Create snippet rule
const snippetRule = new cloudflare.SnippetRules("security-rules", {
  zoneId: zoneId,
  rules: [{
    description: "Apply security headers",
    enabled: true,
    expression: "true",
    snippetName: securitySnippet.name,
  }],
});
```

## フィルター式

スニペットは、実行するタイミングを判定するために Cloudflare の Ruleset Engine の式言語を使用します。

### よく使われる式のパターン

```javascript
// Host matching
http.host eq "example.com"
http.host in {"example.com" "www.example.com"}
http.host contains "example"

// Path matching
http.request.uri.path eq "/api/users"
starts_with(http.request.uri.path, "/api/")
ends_with(http.request.uri.path, ".json")
matches(http.request.uri.path, "^/api/v[0-9]+/")

// Query parameters
http.request.uri.query contains "debug=true"

// Headers
http.headers["user-agent"] contains "Mobile"
http.headers["accept-language"] eq "en-US"

// Cookies
http.cookie contains "session="

// Geolocation
ip.geoip.country eq "US"
ip.geoip.continent eq "EU"

// Bot detection (requires Bot Management)
cf.bot_management.score lt 30

// Method
http.request.method eq "POST"
http.request.method in {"POST" "PUT" "PATCH"}

// Combine with logical operators
http.host eq "example.com" and starts_with(http.request.uri.path, "/api/")
ip.geoip.country eq "US" or ip.geoip.country eq "CA"
not http.headers["user-agent"] contains "bot"
```

### 式の関数

| 関数 | 例 | 説明 |
|----------|---------|-------------|
| `starts_with()` | `starts_with(http.request.uri.path, "/api/")` | 接頭辞を確認 |
| `ends_with()` | `ends_with(http.request.uri.path, ".json")` | 接尾辞を確認 |
| `contains()` | `contains(http.headers["user-agent"], "Mobile")` | 部分文字列を確認 |
| `matches()` | `matches(http.request.uri.path, "^/api/")` | 正規表現で照合 |
| `lower()` | `lower(http.host) eq "example.com"` | 小文字に変換 |
| `upper()` | `upper(http.headers["x-api-key"])` | 大文字に変換 |
| `len()` | `len(http.request.uri.path) gt 100` | 文字列の長さ |

## デプロイのワークフロー

### 開発
1. スニペットのコードをローカルで記述する
2. `node snippet.js` または TypeScript コンパイラーで構文を確認する
3. ダッシュボードにデプロイするか、`Save as Draft` を使って API からデプロイする
4. ダッシュボードの Preview/HTTP タブでテストする
5. 準備ができたらルールを有効にする

### 本番環境
1. スニペットのコードをバージョン管理に保存する
2. 再現可能なデプロイには Terraform/Pulumi を使う
3. まずステージングゾーンにデプロイする
4. 実際のトラフィックでテストする（トラフィックの少ないサブドメインを使用）
5. 本番ゾーンに適用する
6. Analytics/Logpush で監視する

## 制限と要件

| リソース | 上限 | 備考 |
|----------|-------|-------|
| スニペットのサイズ | 32 KB | スニペットごと、圧縮後 |
| スニペット名 | 64 chars | `a-z`、`0-9`、`_` のみ、変更不可 |
| ゾーンあたりのスニペット数 | 20 | ソフトリミット。追加についてはサポートに問い合わせてください |
| ゾーンあたりのルール数 | 20 | 通常、スニペットごとに 1 つのルール |
| 式の長さ | 4096 chars | ルール式ごと |

## 認証

### API トークン（推奨）
```bash
# Create token at: https://dash.cloudflare.com/profile/api-tokens
# Required permissions: Zone.Snippets:Edit, Zone.Rules:Edit
export CLOUDFLARE_API_TOKEN="your_token_here"
```

### API キー（旧方式）
```bash
export CLOUDFLARE_EMAIL="your@email.com"
export CLOUDFLARE_API_KEY="your_global_api_key"
``` 