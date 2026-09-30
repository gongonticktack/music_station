# Streamのパターン

一般的なワークフロー、フルスタックの処理フロー、ベストプラクティス。

## React Stream Player

`npm install @cloudflare/stream-react`

```tsx
import { Stream } from '@cloudflare/stream-react';

export function VideoPlayer({ videoId, token }: { videoId: string; token?: string }) {
  return <Stream controls src={token ? `${videoId}?token=${token}` : videoId} responsive />;
}
```

## フルスタックのアップロードフロー

**バックエンドAPI（Workers/Pages）**
```typescript
import Cloudflare from 'cloudflare';

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { videoName } = await request.json();
    const client = new Cloudflare({ apiToken: env.CF_API_TOKEN });
    const { uploadURL, uid } = await client.stream.directUpload.create({
      account_id: env.CF_ACCOUNT_ID,
      maxDurationSeconds: 3600,
      requireSignedURLs: true,
      meta: { name: videoName }
    });
    return Response.json({ uploadURL, uid });
  }
};
```

**フロントエンドコンポーネント**
```tsx
import { useState } from 'react';

export function VideoUploader() {
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  
  async function handleUpload(file: File) {
    setUploading(true);
    const { uploadURL, uid } = await fetch('/api/upload-url', {
      method: 'POST',
      body: JSON.stringify({ videoName: file.name })
    }).then(r => r.json());
    
    const xhr = new XMLHttpRequest();
    xhr.upload.onprogress = (e) => setProgress((e.loaded / e.total) * 100);
    xhr.onload = () => { setUploading(false); window.location.href = `/videos/${uid}`; };
    xhr.open('POST', uploadURL);
    const formData = new FormData();
    formData.append('file', file);
    xhr.send(formData);
  }
  
  return (
    <div>
      <input type="file" accept="video/*" onChange={(e) => e.target.files?.[0] && handleUpload(e.target.files[0])} disabled={uploading} />
      {uploading && <progress value={progress} max={100} />}
    </div>
  );
}
```

## TUSによる再開可能なアップロード

大容量ファイル（>500MB）向け。`npm install tus-js-client`

```typescript
import * as tus from 'tus-js-client';

async function uploadWithTUS(file: File, uploadURL: string, onProgress?: (pct: number) => void) {
  return new Promise<string>((resolve, reject) => {
    const upload = new tus.Upload(file, {
      endpoint: uploadURL,
      retryDelays: [0, 3000, 5000, 10000, 20000],
      chunkSize: 50 * 1024 * 1024,
      metadata: { filename: file.name, filetype: file.type },
      onError: reject,
      onProgress: (up, total) => onProgress?.((up / total) * 100),
      onSuccess: () => resolve(upload.url?.split('/').pop() || '')
    });
    upload.start();
  });
}
```

## 動画の状態をポーリング

```typescript
async function waitForVideoReady(client: Cloudflare, accountId: string, videoId: string) {
  for (let i = 0; i < 60; i++) {
    const video = await client.stream.videos.get(videoId, { account_id: accountId });
    if (video.readyToStream || video.status.state === 'error') return video;
    await new Promise(resolve => setTimeout(resolve, 5000));
  }
  throw new Error('Video processing timeout');
}
```

## Webhookハンドラー

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const signature = request.headers.get('Webhook-Signature');
    const body = await request.text();
    if (!signature || !await verifyWebhook(signature, body, env.WEBHOOK_SECRET)) {
      return new Response('Unauthorized', { status: 401 });
    }
    const payload = JSON.parse(body);
    if (payload.readyToStream) console.log(`Video ${payload.uid} ready`);
    return new Response('OK');
  }
};

async function verifyWebhook(sig: string, body: string, secret: string): Promise<boolean> {
  const parts = Object.fromEntries(sig.split(',').map(p => p.split('=')));
  const timestamp = parseInt(parts.time || '0', 10);
  if (Math.abs(Date.now() / 1000 - timestamp) > 300) return false;
  
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']
  );
  const computed = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${timestamp}.${body}`));
  const hex = Array.from(new Uint8Array(computed), b => b.toString(16).padStart(2, '0')).join('');
  return hex === parts.sig1;
}
```

## JWTの自己署名（大量のトークン向け）

1日あたり>1kトークンの場合。前提条件: 署名キーを作成します（configuration.mdを参照）。

```typescript
async function selfSignToken(keyId: string, jwkBase64: string, videoId: string, expiresIn = 3600) {
  const key = await crypto.subtle.importKey(
    'jwk', JSON.parse(atob(jwkBase64)), { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']
  );
  const now = Math.floor(Date.now() / 1000);
  const header = btoa(JSON.stringify({ alg: 'RS256', kid: keyId })).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const payload = btoa(JSON.stringify({ sub: videoId, kid: keyId, exp: now + expiresIn, nbf: now }))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const message = `${header}.${payload}`;
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(message));
  const b64Sig = btoa(String.fromCharCode(...new Uint8Array(sig))).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  return `${message}.${b64Sig}`;
}

// With access rules (geo-restriction)
const payloadWithRules = {
  sub: videoId, kid: keyId, exp: now + 3600, nbf: now,
  accessRules: [{ type: 'ip.geoip.country', action: 'allow', country: ['US'] }]
};
```

## ベストプラクティス

- **Direct Creator Uploadsを使用する** - サーバー経由のプロキシを避ける
- **requireSignedURLsを有効にする** - 非公開コンテンツへのアクセスを制御する
- **大規模運用ではトークンに自己署名する** - 1日あたり>1k件の場合は署名キーを使用する
- **allowedOriginsを設定する** - ホットリンクを防ぐ
- **ポーリングよりWebhookを使用する** - ステータス更新を効率化する
- **maxDurationSecondsを設定する** - 不正利用を防ぐ
- **ライブ録画を有効にする** - 配信後に自動でVOD化する

## このリファレンスの内容

- [README.md](./README.md) - 概要とクイックスタート
- [configuration.md](./configuration.md) - セットアップと設定
- [api.md](./api.md) - オンデマンド動画API
- [api-live.md](./api-live.md) - ライブ配信API
- [gotchas.md](./gotchas.md) - エラーコードとトラブルシューティング

## 関連項目

- [workers](../workers/) - WorkersでStream APIをデプロイする
- [pages](../pages/) - StreamをPagesと統合する
