# R2 のパターンとベストプラクティス

## 大容量ファイルのストリーミング

```typescript
const object = await env.MY_BUCKET.get(key);
if (!object) return new Response('Not found', { status: 404 });

const headers = new Headers();
object.writeHttpMetadata(headers);
headers.set('etag', object.httpEtag);

return new Response(object.body, { headers });
```

## 条件付き GET（304 Not Modified）

```typescript
const ifNoneMatch = request.headers.get('if-none-match');
const object = await env.MY_BUCKET.get(key, {
  onlyIf: { etagDoesNotMatch: ifNoneMatch?.replace(/"/g, '') || '' }
});

if (!object) return new Response('Not found', { status: 404 });
if (!object.body) return new Response(null, { status: 304, headers: { 'etag': object.httpEtag } });

return new Response(object.body, { headers: { 'etag': object.httpEtag } });
```

## 検証付きアップロード

```typescript
const key = url.pathname.slice(1);
if (!key || key.includes('..')) return new Response('Invalid key', { status: 400 });

const object = await env.MY_BUCKET.put(key, request.body, {
  httpMetadata: { contentType: request.headers.get('content-type') || 'application/octet-stream' },
  customMetadata: { uploadedAt: new Date().toISOString(), ip: request.headers.get('cf-connecting-ip') || 'unknown' }
});

return Response.json({ key: object.key, size: object.size, etag: object.httpEtag });
```

## 進捗表示付きマルチパート

```typescript
const PART_SIZE = 5 * 1024 * 1024; // 5MB
const partCount = Math.ceil(file.size / PART_SIZE);
const multipart = await env.MY_BUCKET.createMultipartUpload(key, { httpMetadata: { contentType: file.type } });

const uploadedParts: R2UploadedPart[] = [];
try {
  for (let i = 0; i < partCount; i++) {
    const start = i * PART_SIZE;
    const part = await multipart.uploadPart(i + 1, file.slice(start, start + PART_SIZE));
    uploadedParts.push(part);
    onProgress?.(Math.round(((i + 1) / partCount) * 100));
  }
  return await multipart.complete(uploadedParts);
} catch (error) {
  await multipart.abort();
  throw error;
}
```

## 一括削除

```typescript
async function deletePrefix(prefix: string, env: Env) {
  let cursor: string | undefined;
  let truncated = true;

  while (truncated) {
    const listed = await env.MY_BUCKET.list({ prefix, limit: 1000, cursor });
    if (listed.objects.length > 0) {
      await env.MY_BUCKET.delete(listed.objects.map(o => o.key));
    }
    truncated = listed.truncated;
    cursor = listed.cursor;
  }
}
```

## チェックサムの検証とストレージクラスの移行

```typescript
// Upload with checksum
const hash = await crypto.subtle.digest('SHA-256', data);
await env.MY_BUCKET.put(key, data, { sha256: hash });

// Transition storage class (requires S3 SDK)
import { S3Client, CopyObjectCommand } from '@aws-sdk/client-s3';
await s3.send(new CopyObjectCommand({
  Bucket: 'my-bucket', Key: key,
  CopySource: `/my-bucket/${key}`,
  StorageClass: 'STANDARD_IA'
}));
```

## クライアント側アップロード（署名付き URL）

```typescript
import { S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { PutObjectCommand } from '@aws-sdk/client-s3';

// Worker: Generate presigned upload URL
const s3 = new S3Client({
  region: 'auto',
  endpoint: `https://${env.ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: { accessKeyId: env.R2_ACCESS_KEY_ID, secretAccessKey: env.R2_SECRET_ACCESS_KEY }
});

const url = await getSignedUrl(s3, new PutObjectCommand({ Bucket: 'my-bucket', Key: key }), { expiresIn: 3600 });
return Response.json({ uploadUrl: url });

// Client: Upload directly
const { uploadUrl } = await fetch('/api/upload-url').then(r => r.json());
await fetch(uploadUrl, { method: 'PUT', body: file });
```

## Cache API によるキャッシュ

```typescript
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const cache = caches.default;
    const url = new URL(request.url);
    const cacheKey = new Request(url.toString(), request);

    // Check cache first
    let response = await cache.match(cacheKey);
    if (response) return response;

    // Fetch from R2
    const key = url.pathname.slice(1);
    const object = await env.MY_BUCKET.get(key);
    if (!object) return new Response('Not found', { status: 404 });

    const headers = new Headers();
    object.writeHttpMetadata(headers);
    headers.set('etag', object.httpEtag);
    headers.set('cache-control', 'public, max-age=31536000, immutable');

    response = new Response(object.body, { headers });

    // Cache for subsequent requests
    ctx.waitUntil(cache.put(cacheKey, response.clone()));

    return response;
  }
};
```

## カスタムドメインを使用したパブリックバケット

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'access-control-allow-origin': '*',
          'access-control-allow-methods': 'GET, HEAD',
          'access-control-max-age': '86400'
        }
      });
    }

    const key = new URL(request.url).pathname.slice(1);
    if (!key) return Response.redirect('/index.html', 302);

    const object = await env.MY_BUCKET.get(key);
    if (!object) return new Response('Not found', { status: 404 });

    const headers = new Headers();
    object.writeHttpMetadata(headers);
    headers.set('etag', object.httpEtag);
    headers.set('access-control-allow-origin', '*');
    headers.set('cache-control', 'public, max-age=31536000, immutable');

    return new Response(object.body, { headers });
  }
};
```

## r2.dev のパブリック URL

簡単に公開アクセスできるよう、ダッシュボードで r2.dev を有効にします: `https://pub-${hashId}.r2.dev/${key}`  
または、ダッシュボードからカスタムドメインを追加します: `https://files.example.com/${key}`

**制限事項:** 認証なし、バケット単位の CORS、キャッシュのオーバーライドなし。
