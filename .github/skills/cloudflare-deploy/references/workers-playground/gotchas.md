# Workers Playground の注意点

## プラットフォームの制限

| 制限事項 | 影響 | 回避策 |
|------------|--------|------------|
| Safari は動作しない | プレビューに失敗 | Chrome/Firefox/Edge を使用 |
| TypeScript は非対応 | TS 構文エラー | プレーンな JS を書くか、JSDoc を使用 |
| バインディングなし | `env` は常に `{}` | モックデータまたは外部 API を使用 |
| 環境変数なし | シークレットにアクセスできない | テスト用にハードコード |

## よくあるランタイムエラー

### 「Response body already read」

```javascript
// ❌ Body consumed twice
const body = await request.text();
await fetch(url, { body: request.body }); // Error!

// ✅ Clone first
const clone = request.clone();
const body = await request.text();
await fetch(url, { body: clone.body });
```

### 「Worker exceeded CPU time」

**上限:** 10ms（無料）、50ms（有料）

```javascript
// ✅ Move slow work to background
ctx.waitUntil(fetch('https://analytics.example.com', {...}));
return new Response('OK'); // Return immediately
```

### 「Too many subrequests」

**上限:** 50（無料）、1000（有料）

```javascript
// ❌ 100 individual fetches
// ✅ Batch into single API call
await fetch('https://api.example.com/batch', {
  body: JSON.stringify({ ids: [...] })
});
```

## ベストプラクティス

```javascript
// Clone before caching
await cache.put(request, response.clone());
return response;

// Validate input early
if (request.method !== 'POST') return new Response('', { status: 405 });

// Handle errors
try { ... } catch (e) {
  return Response.json({ error: e.message }, { status: 500 });
}
```

## 制限値

| リソース | 無料 | 有料 |
|----------|------|------|
| CPU 時間 | 10ms | 50ms |
| メモリ | 128 MB | 128 MB |
| サブリクエスト | 50 | 1000 |

## ブラウザーのサポート

| ブラウザー | 状態 |
|---------|--------|
| Chrome | ✅ 推奨 |
| Firefox | ✅ 動作する |
| Edge | ✅ 動作する |
| Safari | ❌ 動作しない |

## デバッグ

```javascript
console.log('URL:', request.url); // View in browser DevTools Console
```

**注:** `console.log` は Playground で動作します。本番環境では Logpush または Tail Workers を使用してください。
