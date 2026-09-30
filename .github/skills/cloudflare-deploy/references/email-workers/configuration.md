# Email Workers の設定

## wrangler.jsonc

```jsonc
{
  "name": "email-worker",
  "main": "src/index.ts",
  "compatibility_date": "2025-01-27",
  "send_email": [
    { "name": "EMAIL" },                                    // Unrestricted
    { "name": "EMAIL_LOGS", "destination_address": "logs@example.com" },  // Single dest
    { "name": "EMAIL_TEAM", "allowed_destination_addresses": ["a@ex.com", "b@ex.com"] },
    { "name": "EMAIL_NOREPLY", "allowed_sender_addresses": ["noreply@ex.com"] }
  ],
  "kv_namespaces": [{ "binding": "ARCHIVE", "id": "xxx" }],
  "r2_buckets": [{ "binding": "ATTACHMENTS", "bucket_name": "email-attachments" }],
  "vars": { "WEBHOOK_URL": "https://hooks.example.com" }
}
```

## TypeScript の型

```typescript
interface Env {
  EMAIL: SendEmail;
  ARCHIVE: KVNamespace;
  ATTACHMENTS: R2Bucket;
  WEBHOOK_URL: string;
}

export default {
  async email(message: ForwardableEmailMessage, env: Env, ctx: ExecutionContext) {}
};
```

## 依存関係

```bash
npm install postal-mime mimetext
npm install -D @cloudflare/workers-types wrangler typescript
```

postal-mime v2.x、mimetext v3.x を使用してください。

## tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2022", "module": "ES2022", "lib": ["ES2022"],
    "types": ["@cloudflare/workers-types"],
    "moduleResolution": "bundler", "strict": true
  }
}
```

## ローカル開発

```bash
npx wrangler dev

# Test receiving
curl --request POST 'http://localhost:8787/cdn-cgi/handler/email' \
  --url-query 'from=sender@example.com' --url-query 'to=recipient@example.com' \
  --header 'Content-Type: text/plain' --data-raw 'Subject: Test\n\nHello'
```

送信メールはローカルの `.eml` ファイルに書き込まれます。

## デプロイ前チェックリスト

- [ ] ダッシュボードで Email Routing を有効にする
- [ ] 宛先アドレスを検証する
- [ ] 送信に使う DMARC/SPF/DKIM を設定する
- [ ] 必要に応じて KV/R2 リソースを作成する
- [ ] 本番用 ID で wrangler.jsonc を更新する

```bash
npx wrangler deploy
npx wrangler deployments list
```

## ダッシュボードの設定

1. **Email Routing:** Domain → Email → Enable Email Routing
2. **アドレスの検証:** Email → Destination addresses → Add & verify
3. **Worker のバインド:** Email → Email Workers → Create route → Select pattern & Worker
4. **DMARC:** TXT `_dmarc.domain.com` を追加: `v=DMARC1; p=quarantine;`

## シークレット

```bash
npx wrangler secret put API_KEY
# Access: env.API_KEY
```

## モニタリング

```bash
npx wrangler tail
npx wrangler tail --status error
npx wrangler tail --format json
```

## トラブルシューティング

| Error | Fix |
|-------|-----|
| "Binding not found" | `send_email` の名前がコードと一致しているか確認します |
| "Invalid destination" | Email Routing ダッシュボードで検証します |
| Type errors | `@cloudflare/workers-types` をインストールします |
