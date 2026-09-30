# 設定

## Wrangler との統合

### Workers バインディングの設定

`wrangler.toml` に追加します:

```toml
name = "my-image-worker"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[images]
binding = "IMAGES"
```

Worker 内でアクセスします:

```typescript
interface Env {
  IMAGES: ImageBinding;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    return await env.IMAGES
      .input(imageBuffer)
      .transform({ width: 800 })
      .output()
      .response();
  }
};
```

### スクリプト経由でのアップロード

Wrangler には Images 用の組み込みコマンドがないため、REST API を使用します:

```typescript
// scripts/upload-image.ts
import fs from 'fs';
import FormData from 'form-data';

async function uploadImage(filePath: string) {
  const accountId = process.env.CLOUDFLARE_ACCOUNT_ID!;
  const apiToken = process.env.CLOUDFLARE_API_TOKEN!;
  
  const formData = new FormData();
  formData.append('file', fs.createReadStream(filePath));
  
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountId}/images/v1`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiToken}`,
      },
      body: formData,
    }
  );
  
  const result = await response.json();
  console.log('Uploaded:', result);
}

uploadImage('./photo.jpg');
```

### 環境変数

URL の構築に使うアカウントハッシュを保存します:

```toml
[vars]
IMAGES_ACCOUNT_HASH = "your-account-hash"
ACCOUNT_ID = "your-account-id"
```

Worker 内でアクセスします:

```typescript
const imageUrl = `https://imagedelivery.net/${env.IMAGES_ACCOUNT_HASH}/${imageId}/public`;
```

## バリアントの設定

バリアントは変換用の名前付きプリセットです。

### バリアントの作成（ダッシュボード）

1. Images → Variants に移動します
2. "Create Variant" をクリックします
3. 名前を設定します（例: `thumbnail`）
4. 次のように設定します: `width=200,height=200,fit=cover`

### バリアントの作成（API）

```bash
curl -X POST \
  https://api.cloudflare.com/client/v4/accounts/{account_id}/images/v1/variants \
  -H "Authorization: Bearer {api_token}" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "thumbnail",
    "options": {
      "width": 200,
      "height": 200,
      "fit": "cover"
    },
    "neverRequireSignedURLs": true
  }'
```

### バリアントの使用

```
https://imagedelivery.net/{account_hash}/{image_id}/thumbnail
```

### よく使われるバリアントのプリセット

```json
{
  "thumbnail": {
    "width": 200,
    "height": 200,
    "fit": "cover"
  },
  "avatar": {
    "width": 128,
    "height": 128,
    "fit": "cover",
    "gravity": "face"
  },
  "hero": {
    "width": 1920,
    "height": 1080,
    "fit": "cover",
    "quality": 90
  },
  "mobile": {
    "width": 640,
    "fit": "scale-down",
    "quality": 80,
    "format": "avif"
  }
}
```

## 認証

### API トークン（推奨）

発行場所: Dashboard → My Profile → API Tokens

必要な権限:
- Account → Cloudflare Images → Edit

```bash
curl -H "Authorization: Bearer {api_token}" \
  https://api.cloudflare.com/client/v4/accounts/{account_id}/images/v1
```

### API キー（レガシー）

```bash
curl -H "X-Auth-Email: {email}" \
     -H "X-Auth-Key: {api_key}" \
  https://api.cloudflare.com/client/v4/accounts/{account_id}/images/v1
```

## 署名付き URL

非公開画像の場合は、署名付き URL を有効にします:

```bash
# Upload with signed URLs required
curl -X POST \
  https://api.cloudflare.com/client/v4/accounts/{account_id}/images/v1 \
  -H "Authorization: Bearer {api_token}" \
  -F file=@private.jpg \
  -F requireSignedURLs=true
```

署名付き URL を生成します:

```typescript
import { createHmac } from 'crypto';

function signUrl(imageId: string, variant: string, expiry: number, key: string): string {
  const path = `/${imageId}/${variant}`;
  const toSign = `${path}${expiry}`;
  const signature = createHmac('sha256', key)
    .update(toSign)
    .digest('hex');
  
  return `https://imagedelivery.net/{hash}${path}?exp=${expiry}&sig=${signature}`;
}

// Sign URL valid for 1 hour
const signedUrl = signUrl('image-id', 'public', Date.now() + 3600, env.SIGNING_KEY);
```

## ローカル開発

```bash
npx wrangler dev --remote
```

Images バインディングにアクセスするには `--remote` を使用する必要があります。
