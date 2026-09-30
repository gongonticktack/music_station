# Snippets API リファレンス

## Request オブジェクト

### HTTP プロパティ
```javascript
request.method    // GET, POST, PUT, DELETE, etc.
request.url       // Full URL string
request.headers   // Headers object
request.body      // ReadableStream (for POST/PUT)
request.cf        // Cloudflare properties (see below)
```

### URL 操作
```javascript
const url = new URL(request.url);
url.hostname             // "example.com"
url.pathname             // "/path/to/page"
url.search               // "?query=value"
url.searchParams.get("q") // "value"
url.searchParams.set("q", "new")
url.searchParams.delete("q")
```

### ヘッダー操作
```javascript
// Read headers
request.headers.get("User-Agent")
request.headers.has("Authorization")
request.headers.getSetCookie() // Get all Set-Cookie headers

// Modify headers (create new request)
const modifiedRequest = new Request(request);
modifiedRequest.headers.set("X-Custom", "value")
modifiedRequest.headers.delete("X-Remove")
```

### Cloudflare プロパティ (`request.cf`)
リクエストに関する Cloudflare 固有のメタデータにアクセスします:

```javascript
// Geolocation
request.cf.city            // "San Francisco"
request.cf.continent       // "NA"
request.cf.country         // "US"
request.cf.region          // "California" or "CA"
request.cf.regionCode      // "CA"
request.cf.postalCode      // "94102"
request.cf.latitude        // "37.7749"
request.cf.longitude       // "-122.4194"
request.cf.timezone        // "America/Los_Angeles"
request.cf.metroCode       // "807" (DMA code)

// Network
request.cf.colo            // "SFO" (airport code of datacenter)
request.cf.asn             // 13335 (ASN number)
request.cf.asOrganization  // "Cloudflare, Inc."

// Bot Management (if enabled)
request.cf.botManagement.score        // 1-99 (1=bot, 99=human)
request.cf.botManagement.verified_bot // true/false
request.cf.botManagement.static_resource // true/false

// TLS/HTTP version
request.cf.tlsVersion      // "TLSv1.3"
request.cf.tlsCipher       // "AEAD-AES128-GCM-SHA256"
request.cf.httpProtocol    // "HTTP/2"

// Request metadata
request.cf.requestPriority // "weight=192;exclusive=0"
```

**用途**: 地理的ルーティング、ボット検出、セキュリティ判断、分析。

## Response オブジェクト

### Response コンストラクター
```javascript
// Plain text
new Response("Hello", { status: 200 })

// JSON
Response.json({ key: "value" }, { status: 200 })

// HTML
new Response("<h1>Hi</h1>", { 
  status: 200,
  headers: { "Content-Type": "text/html" }
})

// Redirect
Response.redirect("https://example.com", 301) // or 302

// Stream (pass through)
new Response(response.body, response)
```

### Response ヘッダー
```javascript
// Create modified response
const newResponse = new Response(response.body, response);

// Set/modify headers
newResponse.headers.set("X-Custom", "value")
newResponse.headers.append("Set-Cookie", "session=abc; Path=/")
newResponse.headers.delete("Server")

// Common headers
newResponse.headers.set("Cache-Control", "public, max-age=3600")
newResponse.headers.set("Content-Type", "application/json")
```

### Response プロパティ
```javascript
response.status       // 200, 404, 500, etc.
response.statusText   // "OK", "Not Found", etc.
response.headers      // Headers object
response.body         // ReadableStream
response.ok           // true if status 200-299
response.redirected   // true if redirected
```

## REST API 操作

### Snippets の一覧
```bash
GET /zones/{zone_id}/snippets
```

### Snippet の取得
```bash
GET /zones/{zone_id}/snippets/{snippet_name}
```

### Snippet の作成/更新
```bash
PUT /zones/{zone_id}/snippets/{snippet_name}
Content-Type: multipart/form-data

files=@snippet.js
metadata={"main_module":"snippet.js"}
```

### Snippet の削除
```bash
DELETE /zones/{zone_id}/snippets/{snippet_name}
```

### Snippet ルールの一覧
```bash
GET /zones/{zone_id}/rulesets/phases/http_request_snippets/entrypoint
```

### Snippet ルールの更新
```bash
PUT /zones/{zone_id}/snippets/snippet_rules
Content-Type: application/json

{
  "rules": [{
    "description": "Apply snippet",
    "enabled": true,
    "expression": "http.host eq \"example.com\"",
    "snippet_name": "my_snippet"
  }]
}
```

## Snippets で利用可能な API

### ✅ サポート対象
- `fetch()` - HTTP リクエスト（プランによりサブリクエスト 2～5 件）
- `Request` / `Response` - 標準 Web API
- `URL` / `URLSearchParams` - URL 操作
- `Headers` - ヘッダー操作
- `TextEncoder` / `TextDecoder` - テキストエンコーディング
- `crypto.subtle` - Web Crypto API（ハッシュ化、署名）
- `crypto.randomUUID()` - UUID 生成

### ❌ Snippets ではサポート対象外
- `caches` API - 利用不可（Workers を使用してください）
- `KV`、`D1`、`R2` - ストレージ API（Workers を使用してください）
- `Durable Objects` - ステートフルオブジェクト（Workers を使用してください）
- `WebSocket` - WebSocket アップグレード（Workers を使用してください）
- `HTMLRewriter` - HTML 解析（Workers を使用してください）
- `import` 文 - モジュールのインポートなし
- `addEventListener` - `export default { async fetch() {}` パターンを使用してください

## Snippet の構造
```javascript
export default {
  async fetch(request) {
    // Your logic here
    const response = await fetch(request);
    return response; // or modified response
  }
}
```