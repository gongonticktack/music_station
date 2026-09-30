# R2 の設定

## Workers バインディング

**wrangler.jsonc:**
```jsonc
{
  "r2_buckets": [
    {
      "binding": "MY_BUCKET",
      "bucket_name": "my-bucket-name"
    }
  ]
}
```

## TypeScript 型

```typescript
interface Env { MY_BUCKET: R2Bucket; }

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const object = await env.MY_BUCKET.get('file.txt');
    return new Response(object?.body);
  }
}
```

## S3 SDK のセットアップ

```typescript
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';

const s3 = new S3Client({
  region: 'auto',
  endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: env.R2_ACCESS_KEY_ID,
    secretAccessKey: env.R2_SECRET_ACCESS_KEY
  }
});

await s3.send(new PutObjectCommand({
  Bucket: 'my-bucket',
  Key: 'file.txt',
  Body: data,
  StorageClass: 'STANDARD' // or 'STANDARD_IA'
}));
```

## ロケーションのヒント

```bash
wrangler r2 bucket create my-bucket --location=enam

# Hints: wnam, enam, weur, eeur, apac, oc
# Jurisdictions (override hint): --jurisdiction=eu (or fedramp)
```

## CORS の設定

CORS は S3 SDK またはダッシュボードで設定する必要があります（Workers API では利用できません）：

```typescript
import { S3Client, PutBucketCorsCommand } from '@aws-sdk/client-s3';

const s3 = new S3Client({
  region: 'auto',
  endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: env.R2_ACCESS_KEY_ID,
    secretAccessKey: env.R2_SECRET_ACCESS_KEY
  }
});

await s3.send(new PutBucketCorsCommand({
  Bucket: 'my-bucket',
  CORSConfiguration: {
    CORSRules: [{
      AllowedOrigins: ['https://example.com'],
      AllowedMethods: ['GET', 'PUT', 'HEAD'],
      AllowedHeaders: ['*'],
      ExposeHeaders: ['ETag'],
      MaxAgeSeconds: 3600
    }]
  }
}));
```

## オブジェクトのライフサイクル

```typescript
import { PutBucketLifecycleConfigurationCommand } from '@aws-sdk/client-s3';

await s3.send(new PutBucketLifecycleConfigurationCommand({
  Bucket: 'my-bucket',
  LifecycleConfiguration: {
    Rules: [
      {
        ID: 'expire-old-logs',
        Status: 'Enabled',
        Prefix: 'logs/',
        Expiration: { Days: 90 }
      },
      {
        ID: 'transition-to-ia',
        Status: 'Enabled',
        Prefix: 'archives/',
        Transitions: [{ Days: 30, StorageClass: 'STANDARD_IA' }]
      }
    ]
  }
}));
```

## API トークンのスコープ

R2 トークンを作成する際は、必要最小限の権限を設定します：

| 権限 | 用途 |
|------------|----------|
| オブジェクトの読み取り | 公開配信、ダウンロード |
| オブジェクトの書き込み | アップロードのみ |
| オブジェクトの読み取りと書き込み | オブジェクトの全操作 |
| 管理者の読み取りと書き込み | バケット管理、CORS、ライフサイクル |

**ベストプラクティス：** Workers 用（読み取り／書き込み）と管理タスク用（CORS、ライフサイクル）のトークンを分けます。

## イベント通知

```jsonc
// wrangler.jsonc
{
  "r2_buckets": [
    {
      "binding": "MY_BUCKET",
      "bucket_name": "my-bucket",
      "event_notifications": [
        {
          "queue": "r2-events",
          "actions": ["PutObject", "DeleteObject", "CompleteMultipartUpload"]
        }
      ]
    }
  ],
  "queues": {
    "producers": [{ "binding": "R2_EVENTS", "queue": "r2-events" }],
    "consumers": [{ "queue": "r2-events", "max_batch_size": 10 }]
  }
}
```

## バケット管理

```bash
wrangler r2 bucket create my-bucket --location=enam --storage-class=Standard
wrangler r2 bucket list
wrangler r2 bucket info my-bucket
wrangler r2 bucket delete my-bucket  # Must be empty
wrangler r2 bucket update-storage-class my-bucket --storage-class=InfrequentAccess

# Public bucket via dashboard
wrangler r2 bucket domain add my-bucket --domain=files.example.com
```