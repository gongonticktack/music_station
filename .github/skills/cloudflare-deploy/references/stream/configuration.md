# Stream の設定

セットアップ、環境変数、wrangler の設定。

## インストール

```bash
# Official Cloudflare SDK (Node.js, Workers, Pages)
npm install cloudflare

# React component library
npm install @cloudflare/stream-react

# TUS resumable uploads (large files)
npm install tus-js-client
```

## 環境変数

```bash
# Required
CF_ACCOUNT_ID=your-account-id
CF_API_TOKEN=your-api-token

# For signed URLs (high volume)
STREAM_KEY_ID=your-key-id
STREAM_JWK=base64-encoded-jwk

# For webhooks
WEBHOOK_SECRET=your-webhook-secret

# Customer subdomain (from dashboard)
STREAM_CUSTOMER_CODE=your-customer-code
```

## Wrangler の設定

```jsonc
{
  "name": "stream-worker",
  "main": "src/index.ts",
  "compatibility_date": "2025-01-01", // Use current date for new projects
  "vars": {
    "CF_ACCOUNT_ID": "your-account-id"
  }
  // Store secrets: wrangler secret put CF_API_TOKEN
  // wrangler secret put STREAM_KEY_ID
  // wrangler secret put STREAM_JWK
  // wrangler secret put WEBHOOK_SECRET
}
```

## 署名キー（大量利用向け）

自己署名トークン用に一度だけ作成します（1 日あたり数千人のユーザー向け）。

**キーを作成**
```bash
curl -X POST \
  "https://api.cloudflare.com/client/v4/accounts/{account_id}/stream/keys" \
  -H "Authorization: Bearer <API_TOKEN>"

# Save `id` and `jwk` (base64) from response
```

**シークレットに保存**
```bash
wrangler secret put STREAM_KEY_ID
wrangler secret put STREAM_JWK
```

## Webhook

**Webhook URL を設定**
```bash
curl -X PUT \
  "https://api.cloudflare.com/client/v4/accounts/{account_id}/stream/webhook" \
  -H "Authorization: Bearer <API_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"notificationUrl": "https://your-worker.workers.dev/webhook"}'

# Save the returned `secret` for signature verification
```

**シークレットを保存**
```bash
wrangler secret put WEBHOOK_SECRET
```

## ダイレクトアップロード／ライブ配信／ウォーターマークの設定

```typescript
// Direct upload
const uploadConfig = {
  maxDurationSeconds: 3600,
  expiry: new Date(Date.now() + 3600000).toISOString(),
  requireSignedURLs: true,
  allowedOrigins: ['https://yourdomain.com'],
  meta: { creator: 'user-123' }
};

// Live input
const liveConfig = {
  recording: { mode: 'automatic', timeoutSeconds: 30 },
  deleteRecordingAfterDays: 30
};

// Watermark
const watermark = {
  name: 'Logo', opacity: 0.7, padding: 20,
  position: 'lowerRight', scale: 0.15
};
```

## アクセスルールとプレーヤーの設定

```typescript
// Access rules: allow US/CA, block CN/RU, or IP allowlist
const geoRestrict = [
  { type: 'ip.geoip.country', action: 'allow', country: ['US', 'CA'] },
  { type: 'any', action: 'block' }
];

// Player params for iframe
const playerParams = new URLSearchParams({
  autoplay: 'true', muted: 'true', preload: 'auto', defaultTextTrack: 'en'
});
```

## このリファレンスの内容

- [README.md](./README.md) - 概要とクイックスタート
- [api.md](./api.md) - オンデマンド動画 API
- [api-live.md](./api-live.md) - ライブストリーミング API
- [patterns.md](./patterns.md) - フルスタックのフロー、ベストプラクティス
- [gotchas.md](./gotchas.md) - エラーコード、トラブルシューティング

## 関連項目

- [wrangler](../wrangler/) - Wrangler CLI と設定
- [workers](../workers/) - Workers で Stream API をデプロイ