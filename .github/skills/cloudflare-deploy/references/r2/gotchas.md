# R2 の注意点とトラブルシューティング

## リストの切り詰め

```typescript
// ❌ WRONG: Don't compare object count when using include
while (listed.objects.length < options.limit) { ... }

// ✅ CORRECT: Always use truncated property
while (listed.truncated) {
  const next = await env.MY_BUCKET.list({ cursor: listed.cursor });
  // ...
}
```

**理由:** メタデータ付きの `include` は、メタデータを収めるために1ページあたりのオブジェクト数が少なくなることがあります。

## ETag の形式

```typescript
// ❌ WRONG: Using etag (unquoted) in headers
headers.set('etag', object.etag); // Missing quotes

// ✅ CORRECT: Use httpEtag (quoted)
headers.set('etag', object.httpEtag);
```

## チェックサムの制限

1回の PUT で使用できるチェックサムアルゴリズムは1つだけです。

```typescript
// ❌ WRONG: Multiple checksums
await env.MY_BUCKET.put(key, data, { md5: hash1, sha256: hash2 }); // Error

// ✅ CORRECT: Pick one
await env.MY_BUCKET.put(key, data, { sha256: hash });
```

## マルチパートの要件

- 最後のパートを除き、すべてのパートのサイズを統一する必要があります
- パート番号は1から始まります（0ではありません）
- 未完了のアップロードは7日後に自動的に中止されます
- `resumeMultipartUpload` は uploadId の存在を検証しません

## 条件付き操作

```typescript
// Precondition failure returns object WITHOUT body
const object = await env.MY_BUCKET.get(key, {
  onlyIf: { etagMatches: '"wrong"' }
});

// Check for body, not just null
if (!object) return new Response('Not found', { status: 404 });
if (!object.body) return new Response(null, { status: 304 }); // Precondition failed
```

## キーの検証

```typescript
// ❌ DANGEROUS: Path traversal
const key = url.pathname.slice(1); // Could be ../../../etc/passwd
await env.MY_BUCKET.get(key);

// ✅ SAFE: Validate keys
if (!key || key.includes('..') || key.startsWith('/')) {
  return new Response('Invalid key', { status: 400 });
}
```

## ストレージクラスの落とし穴

- InfrequentAccess: 早期に削除しても、30日分の最低料金が発生します
- ライフサイクルを使って IA から Standard へ移行することはできません（S3 CopyObject を使用してください）
- IA の読み取りには取得料金がかかります

## ストリームの長さに関する要件

```typescript
// ❌ WRONG: Streaming unknown length fails silently
const response = await fetch(url);
await env.MY_BUCKET.put(key, response.body); // May fail without error

// ✅ CORRECT: Buffer or use Content-Length
const data = await response.arrayBuffer();
await env.MY_BUCKET.put(key, data);

// OR: Pass Content-Length if known
const object = await env.MY_BUCKET.put(key, request.body, {
  httpMetadata: {
    contentLength: parseInt(request.headers.get('content-length') || '0')
  }
});
```

**理由:** R2 ではストリームの長さが既知である必要があります。長さが不明だと、気付かないうちにデータが切り詰められることがあります。

## S3 SDK のリージョン設定

```typescript
// ❌ WRONG: Missing region breaks ALL S3 SDK calls
const s3 = new S3Client({
  endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
  credentials: { ... }
});

// ✅ CORRECT: MUST set region='auto'
const s3 = new S3Client({
  region: 'auto', // REQUIRED
  endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
  credentials: { ... }
});
```

**理由:** S3 SDK ではリージョンが必須です。R2 ではプレースホルダーとして 'auto' を使用します。

## ローカル開発の制限

```typescript
// ❌ Miniflare/wrangler dev: Limited R2 support
// - No multipart uploads
// - No presigned URLs (requires S3 SDK + network)
// - Memory-backed storage (lost on restart)

// ✅ Use remote bindings for full features
wrangler dev --remote

// OR: Conditional logic
if (env.ENVIRONMENT === 'development') {
  // Fallback for local dev
} else {
  // Full R2 features
}
```

## 署名付き URL の有効期限

```typescript
// ❌ WRONG: URL expires but no client validation
const url = await getSignedUrl(s3, command, { expiresIn: 60 });
// 61 seconds later: 403 Forbidden

// ✅ CORRECT: Return expiry to client
return Response.json({
  uploadUrl: url,
  expiresAt: new Date(Date.now() + 60000).toISOString()
});
```

## 制限値

| 制限 | 値 |
|-------|-------|
| オブジェクトサイズ | 5 TB |
| マルチパートのパート数 | 10,000 |
| マルチパートのパート最小サイズ | 5 MB（最後のパートを除く） |
| 一括削除 | 1,000 個のキー |
| リストの上限 | 1リクエストあたり1,000件 |
| キーのサイズ | 1024 bytes |
| カスタムメタデータ | オブジェクトあたり2 KB |
| 署名付き URL の最大有効期限 | 7日 |

## よくあるエラー

### 「Stream upload failed」/「Silent Truncation」

**原因:** ストリームの長さが不明、または Content-Length がない  
**解決策:** データをバッファーに格納するか、Content-Length を明示的に指定してください

### 「Invalid credentials」/ S3 SDK

**原因:** S3Client の設定に `region: 'auto'` がない  
**解決策:** R2 では必ず `region: 'auto'` を設定してください

### 「Object not found」

**原因:** オブジェクトキーが存在しないか、削除されています  
**解決策:** オブジェクトキーが正しいことを確認し、削除されていないか、バケットが正しいか確認してください

### 「List compatibility error」

**原因:** compatibility_date がない、古い、またはフラグが有効になっていない  
**解決策:** `compatibility_date >= 2022-08-04` を設定するか、`r2_list_honor_include` フラグを有効にしてください

### 「Multipart upload failed」

**原因:** パートのサイズが統一されていないか、パート番号が正しくない  
**解決策:** 最後のパートを除いてサイズが統一されていることを確認し、パート番号が1から始まっていることを確認してください
