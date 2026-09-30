# Email Workers の注意点

## 重大な問題

### ReadableStream は一度しか使用できない

```typescript
// ❌ WRONG: Stream consumed twice
const email = await PostalMime.parse(await new Response(message.raw).arrayBuffer());
const rawText = await new Response(message.raw).text(); // EMPTY!

// ✅ CORRECT: Buffer first
const buffer = await new Response(message.raw).arrayBuffer();
const email = await PostalMime.parse(buffer);
const rawText = new TextDecoder().decode(buffer);
```

### ctx.waitUntil() のエラーは通知されない

```typescript
// ❌ Errors dropped silently
ctx.waitUntil(fetch(webhookUrl, { method: 'POST', body: data }));

// ✅ Catch and log
ctx.waitUntil(
  fetch(webhookUrl, { method: 'POST', body: data })
    .catch(err => env.ERROR_LOG.put(`error:${Date.now()}`, err.message))
);
```

## セキュリティ

### エンベロープの From とヘッダーの From（なりすまし）

```typescript
const envelopeFrom = message.from;               // SMTP MAIL FROM (trusted)
const headerFrom = (await PostalMime.parse(buffer)).from?.address; // (untrusted)
// Use envelope for security decisions
```

### 入力の検証

```typescript
if (message.rawSize > 5_000_000) { message.setReject('Too large'); return; }
if ((message.headers.get('Subject') || '').length > 1000) {
  message.setReject('Invalid subject'); return;
}
```

### 返信時の DMARC

DMARC がないと返信は通知なく失敗します。確認方法: `dig TXT _dmarc.example.com`

## 解析

### アドレスの解析

```typescript
const email = await PostalMime.parse(buffer);
const fromAddress = email.from?.address || 'unknown';
const toAddresses = Array.isArray(email.to) ? email.to.map(t => t.address) : [email.to?.address];
```

### 文字エンコーディング

デコードは postal-mime に任せてください。`email.subject`、`email.text`、`email.html` は UTF-8 です。

## API の動作

### setReject() と throw

```typescript
// setReject() for SMTP rejection
if (blockList.includes(message.from)) { message.setReject('Blocked'); return; }

// throw for worker errors
if (!env.KV) throw new Error('KV not configured');
```

### forward() で使えるのは X-* ヘッダーのみ

```typescript
headers.set('X-Processed-By', 'worker');  // ✅ Works
headers.set('Subject', 'Modified');        // ❌ Dropped
```

### 返信には検証済みドメインが必要

```typescript
// Use same domain as receiving address
const receivingDomain = message.to.split('@')[1];
await message.reply(new EmailMessage(`noreply@${receivingDomain}`, message.from, rawMime));
```

## パフォーマンス

### CPU 制限

```typescript
// Skip parsing large emails
if (message.rawSize > 5_000_000) {
  await message.forward('inbox@example.com');
  return;
}
```

監視: `npx wrangler tail`

## 制限

| Limit | Value |
|-------|-------|
| 最大メッセージサイズ | 25 MiB |
| ゾーンごとのルール数上限 | 200 |
| CPU 時間（無料/有料） | 10ms / 50ms |
| 返信の References 上限 | 100 |

## よくあるエラー

| Error | Fix |
|-------|-----|
| "Address not verified" | Email Routing ダッシュボードに追加します |
| "Exceeded CPU time" | `ctx.waitUntil()` を使用するか、プランをアップグレードします |
| "Stream is locked" | `message.raw` を先にバッファリングします |
| 返信が通知なく失敗する | DMARC レコードを確認します |
