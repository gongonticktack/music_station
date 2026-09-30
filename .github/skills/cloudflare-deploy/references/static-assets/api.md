# API リファレンス

## ASSETS バインディング

`ASSETS` バインディングを使用すると、`Fetcher` インターフェース経由で静的アセットにアクセスできます。

### 型定義

```typescript
interface Env {
  ASSETS: Fetcher;
}

interface Fetcher {
  fetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response>;
}
```

### メソッドシグネチャ

```typescript
// 1. Forward entire request
await env.ASSETS.fetch(request);

// 2. String path (hostname ignored, only path matters)
await env.ASSETS.fetch("https://any-host/path/to/asset.png");

// 3. URL object
await env.ASSETS.fetch(new URL("/index.html", request.url));

// 4. Constructed Request object
await env.ASSETS.fetch(new Request(new URL("/logo.png", request.url), {
  method: "GET",
  headers: request.headers
}));
```

**主な動作:**

- 文字列または URL の入力ではホスト/オリジンは無視されます（パスのみが使用されます）
- メソッドは GET である必要があります（それ以外は 405 を返します）
- リクエストヘッダーは引き継がれます（レスポンスに影響します）
- 標準の `Response` オブジェクトを返します

## リクエスト処理

### パス解決

```typescript
// All resolve to same asset:
env.ASSETS.fetch("https://example.com/logo.png")
env.ASSETS.fetch("https://ignored.host/logo.png")
env.ASSETS.fetch("/logo.png")
```

アセットは、設定済みの `assets.directory` を基準に解決されます。

### ヘッダー

レスポンスに影響するリクエストヘッダー:

| ヘッダー | 効果 |
|--------|--------|
| `Accept-Encoding` | 圧縮（gzip、brotli）を制御します |
| `Range` | 部分コンテンツ（206 レスポンス）を有効にします |
| `If-None-Match` | ETag による条件付きリクエスト |
| `If-Modified-Since` | 更新日時による条件付きリクエスト |

カスタムヘッダーは引き継がれますが、アセットの配信には影響しません。

### 対応メソッド

| メソッド | 対応状況 | レスポンス |
|--------|-----------|----------|
| `GET` | ✅ 対応 | アセットの内容 |
| `HEAD` | ✅ 対応 | ヘッダーのみ、本文なし |
| `POST`, `PUT` など | ❌ 非対応 | 405 Method Not Allowed |

## レスポンスの動作

### Content-Type の推定

ファイル拡張子に基づいて自動的に設定されます。

| 拡張子 | Content-Type |
|-----------|--------------|
| `.html` | `text/html; charset=utf-8` |
| `.css` | `text/css` |
| `.js` | `application/javascript` |
| `.json` | `application/json` |
| `.png` | `image/png` |
| `.jpg`, `.jpeg` | `image/jpeg` |
| `.svg` | `image/svg+xml` |
| `.woff2` | `font/woff2` |

### デフォルトヘッダー

レスポンスには次のものが含まれます。

```
Content-Type: <inferred>
ETag: "<hash>"
Cache-Control: public, max-age=3600
Content-Encoding: br  (if supported and beneficial)
```

**Cache-Control のデフォルト値:**

- ほとんどのアセットで 1 時間（`max-age=3600`）
- Worker のレスポンス変換で上書きできます（patterns.md:27-35 を参照）

### 圧縮

`Accept-Encoding` に基づいて自動的に圧縮されます。

- **Brotli**（`br`）: 優先される方式で、最も高い圧縮率
- **Gzip**（`gzip`）: フォールバック
- **なし**: クライアントが対応していない場合、またはアセットが小さすぎる場合

### ETag の生成

ETag はコンテンツベースのハッシュです。

```
ETag: "a3b2c1d4e5f6..."
```

条件付きリクエスト（`If-None-Match`）に使用されます。一致した場合は `304 Not Modified` を返します。

## エラーレスポンス

| ステータス | 条件 | 動作 |
|--------|-----------|----------|
| `404` | アセットが見つからない | 本文は `not_found_handling` の設定によって異なります |
| `405` | GET/HEAD 以外のメソッド | `{ "error": "Method not allowed" }` |
| `416` | Range ヘッダーが無効 | 範囲を満たせません |

### 404 の処理

設定によって異なります（configuration.md:45-52 を参照）。

```typescript
// not_found_handling: "single-page-application"
// Returns /index.html with 200 status

// not_found_handling: "404-page"
// Returns /404.html if exists, else 404 response

// not_found_handling: "none"
// Returns 404 response
```

## 高度な使い方

### レスポンスの変更

```typescript
const response = await env.ASSETS.fetch(request);

// Clone and modify
return new Response(response.body, {
  status: response.status,
  headers: {
    ...Object.fromEntries(response.headers),
    'Cache-Control': 'public, max-age=31536000',
    'X-Custom': 'value'
  }
});
```

完全な例については patterns.md:27-35 を参照してください。

### エラー処理

```typescript
const response = await env.ASSETS.fetch(request);

if (!response.ok) {
  // Asset not found or error
  return new Response('Custom error page', { status: 404 });
}

return response;
```

### 条件付き配信

```typescript
const url = new URL(request.url);

// Serve different assets based on conditions
if (url.pathname === '/') {
  return env.ASSETS.fetch('/index.html');
}

return env.ASSETS.fetch(request);
```

一連のパターンについては patterns.md を参照してください。