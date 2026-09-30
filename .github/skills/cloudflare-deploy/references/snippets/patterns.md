# スニペットのパターン

## セキュリティヘッダー

```javascript
export default {
  async fetch(request) {
    const response = await fetch(request);
    const newResponse = new Response(response.body, response);
    newResponse.headers.set("X-Frame-Options", "DENY");
    newResponse.headers.set("X-Content-Type-Options", "nosniff");
    newResponse.headers.delete("X-Powered-By");
    return newResponse;
  }
}
```

**ルール:** `true`（すべてのリクエスト）

## 地域ベースのルーティング

```javascript
export default {
  async fetch(request) {
    const country = request.cf.country;
    if (["GB", "DE", "FR"].includes(country)) {
      const url = new URL(request.url);
      url.hostname = url.hostname.replace(".com", ".eu");
      return Response.redirect(url.toString(), 302);
    }
    return fetch(request);
  }
}
```

## A/B テスト

```javascript
export default {
  async fetch(request) {
    const cookies = request.headers.get("Cookie") || "";
    let variant = cookies.match(/ab_test=([AB])/)?.[1] || (Math.random() < 0.5 ? "A" : "B");
    
    const req = new Request(request);
    req.headers.set("X-Variant", variant);
    const response = await fetch(req);
    
    if (!cookies.includes("ab_test=")) {
      const newResponse = new Response(response.body, response);
      newResponse.headers.append("Set-Cookie", `ab_test=${variant}; Path=/; Secure`);
      return newResponse;
    }
    return response;
  }
}
```

## ボット検出

```javascript
export default {
  async fetch(request) {
    const botScore = request.cf.botManagement?.score;
    if (botScore && botScore < 30) return new Response("Denied", { status: 403 });
    return fetch(request);
  }
}
```

**要件:** Bot Management プラン

## API 認証ヘッダーの挿入

```javascript
export default {
  async fetch(request) {
    if (new URL(request.url).pathname.startsWith("/api/")) {
      const req = new Request(request);
      req.headers.set("X-Internal-Auth", "secret_token");
      req.headers.delete("Authorization");
      return fetch(req);
    }
    return fetch(request);
  }
}
```

## CORS ヘッダー

```javascript
export default {
  async fetch(request) {
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE",
          "Access-Control-Allow-Headers": "Content-Type, Authorization"
        }
      });
    }
    const response = await fetch(request);
    const newResponse = new Response(response.body, response);
    newResponse.headers.set("Access-Control-Allow-Origin", "*");
    return newResponse;
  }
}
```

## メンテナンスモード

```javascript
export default {
  async fetch(request) {
    if (request.headers.get("X-Bypass-Token") === "admin") return fetch(request);
    return new Response("<h1>Maintenance</h1>", {
      status: 503,
      headers: { "Content-Type": "text/html", "Retry-After": "3600" }
    });
  }
}
```

## パターンの選択

| パターン | 複雑さ | 用途 |
|---------|-----------|----------|
| セキュリティヘッダー | 低 | すべてのサイト |
| 地域ルーティング | 低 | 地域別コンテンツ |
| A/B テスト | 中 | 実験 |
| ボット検出 | 中 | Bot Management が必要 |
| API 認証 | 低 | バックエンドの保護 |
| CORS | 低 | API エンドポイント |
| メンテナンス | 低 | デプロイ