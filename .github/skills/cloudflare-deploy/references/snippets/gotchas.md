# 注意点とベストプラクティス

## よくあるエラー

### 1000: 「スニペットの実行に失敗しました」
ランタイムエラーまたは構文エラーです。コードを try/catch で囲みます:
```javascript
try { return await fetch(request); }
catch (error) { return new Response(`Error: ${error.message}`, { status: 500 }); }
```

### 1100: 「実行制限を超過しました」
CPU 時間が 5ms を超えています。ロジックを簡素化するか、Workers に移行してください。

### 1201: 「複数のオリジンへの fetch」
`fetch(request)` をちょうど 1 回呼び出します:
```javascript
// ❌ Multiple origin fetches
const r1 = await fetch(request); const r2 = await fetch(request);
// ✅ Single fetch, reuse response
const response = await fetch(request);
```

### 1202: 「サブリクエスト数の上限を超過しました」
Pro: 2 件、Business/Enterprise: 5 件です。fetch 呼び出しを減らしてください。

### 「不変オブジェクトのプロパティを設定できません」
変更する前に複製します:
```javascript
const modifiedRequest = new Request(request);
modifiedRequest.headers.set("X-Custom", "value");
```

### 「caches が定義されていません」
Snippets では Cache API を利用できません。Workers を使用してください。

### 「モジュールが見つかりません」
Snippets は `import` をサポートしていません。インラインコードを使うか、Workers を使用してください。

## ベストプラクティス

### パフォーマンス
- コードは 10KB 未満に保つ（上限は 32KB）
- CPU 時間 5ms に収まるよう最適化する
- 変更する場合に限り複製する
- サブリクエストを最小限にする

### セキュリティ
- すべての入力を検証する
- ハッシュには Web Crypto API を使う
- オリジンに送る前にヘッダーをサニタイズする
- シークレットをログに記録しない

### デバッグ
```javascript
newResponse.headers.set("X-Debug-Country", request.cf.country);
```
```bash
curl -H "X-Test: true" https://example.com -v
```

## 利用可能な API

**✅ 利用可能:** `fetch()`、`Request`、`Response`、`Headers`、`URL`、`crypto.subtle`、`crypto.randomUUID()`、`atob()`/`btoa()`、`JSON`

**❌ 利用不可:** `caches`、`KV`、`D1`、`R2`、`Durable Objects`、`WebSocket`、`HTMLRewriter`、`import`、Node.js API

## 制限

| リソース | 上限 |
|----------|-------|
| スニペットのサイズ | 32KB |
| 実行時間 | CPU 5ms |
| サブリクエスト（Pro/Biz） | 2/5 |
| ゾーンあたりのスニペット数 | 20 |

## パフォーマンスの測定値

| 処理 | 時間 |
|-----------|------|
| ヘッダー設定 | <0.1ms |
| URL の解析 | <0.2ms |
| fetch() | 1-3ms |
| SHA-256 | 0.5-1ms |

**次の場合は Workers に移行してください:** 5ms を超える実行時間が必要、5 件を超えるサブリクエストが必要、ストレージ（KV/D1/R2）が必要、npm パッケージが必要、コードが 32KB を超える