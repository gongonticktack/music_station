# Email Workers API リファレンス

Cloudflare Email Workers ランタイムの完全な API リファレンスです。

## ForwardableEmailMessage インターフェース

メールハンドラーに渡されるメインインターフェースです。

```typescript
interface ForwardableEmailMessage {
  readonly from: string;        // Envelope MAIL FROM (SMTP sender)
  readonly to: string;          // Envelope RCPT TO (SMTP recipient)
  readonly headers: Headers;    // Web-standard Headers object
  readonly raw: ReadableStream; // Raw MIME message (single-use stream)
  readonly rawSize: number;     // Total message size in bytes
  
  setReject(reason: string): void;
  forward(rcptTo: string, headers?: Headers): Promise<void>;
  reply(message: EmailMessage): Promise<void>;
}
```

### プロパティ

| Property | Type | Description |
|----------|------|-------------|
| `from` | string | エンベロープ送信者（SMTP MAIL FROM）。セキュリティ用途に使用 |
| `to` | string | エンベロープ受信者（SMTP RCPT TO） |
| `headers` | Headers | メッセージヘッダー（Subject、Message-ID など） |
| `raw` | ReadableStream | 生の MIME メッセージ（**一度のみ使用可能**。先にバッファリングする） |
| `rawSize` | number | メッセージサイズ（バイト） |

### メソッド

#### setReject(reason: string): void

恒久的な SMTP 5xx エラーで拒否します。メールは配信されず、送信者にバウンスメールが届く場合があります。

```typescript
if (blockList.includes(message.from)) {
  message.setReject('Sender blocked');
}
```

#### forward(rcptTo: string, headers?: Headers): Promise<void>

検証済みの宛先に転送します。使用できるカスタムヘッダーは `X-*` のみです。

```typescript
await message.forward('inbox@example.com');

// With custom headers
const h = new Headers();
h.set('X-Processed-By', 'worker');
await message.forward('inbox@example.com', h);
```

#### reply(message: EmailMessage): Promise<void>

元の送信者に返信します（2025年3月の機能）。

```typescript
import { EmailMessage } from 'cloudflare:email';
import { createMimeMessage } from 'mimetext';

const msg = createMimeMessage();
msg.setSender({ name: 'Support', addr: 'support@example.com' });
msg.setRecipient(message.from);
msg.setSubject(`Re: ${message.headers.get('Subject')}`);
msg.setHeader('In-Reply-To', message.headers.get('Message-ID'));
msg.setHeader('References', message.headers.get('References') || '');
msg.addMessage({
  contentType: 'text/plain',
  data: 'Thank you for your message.'
});

await message.reply(new EmailMessage(
  'support@example.com',
  message.from,
  msg.asRaw()
));
```

**要件**:
- 受信メールに有効な DMARC が設定されていること
- イベントごとに1回だけ返信し、宛先は `message.from` にすること
- 送信者のドメインは受信ドメインと同じで、DMARC/SPF/DKIM が設定されていること
- `References` のエントリーは最大100件
- スレッド化: `In-Reply-To`（元の Message-ID）、`References`、新しい `Message-ID`

## EmailMessage コンストラクター

```typescript
import { EmailMessage } from 'cloudflare:email';

new EmailMessage(from: string, to: string, raw: ReadableStream | string)
```

メールの送信（返信、または SendEmail バインディング経由）に使用します。ドメインは検証済みである必要があります。

## SendEmail インターフェース

```typescript
interface SendEmail {
  send(message: EmailMessage): Promise<void>;
}

// Usage
await env.EMAIL.send(new EmailMessage(from, to, mimeContent));
```

## SendEmail バインディングの種類

```jsonc
{
  "send_email": [
    { "name": "EMAIL" },  // Type 1: Any verified address
    { "name": "LOGS", "destination_address": "logs@example.com" },  // Type 2: Single dest
    { "name": "TEAM", "allowed_destination_addresses": ["a@ex.com", "b@ex.com"] },  // Type 3: Dest allowlist
    { "name": "NOREPLY", "allowed_sender_addresses": ["noreply@ex.com"] }  // Type 4: Sender allowlist
  ]
}
```

## postal-mime の解析結果

postal-mime v2.7.3 は受信メールを構造化データに解析します。

```typescript
interface ParsedEmail {
  headers: Array<{ key: string; value: string }>;
  from: { name: string; address: string } | null;
  to: Array<{ name: string; address: string }> | { name: string; address: string } | null;
  cc: Array<{ name: string; address: string }> | null;
  bcc: Array<{ name: string; address: string }> | null;
  subject: string;
  messageId: string | null;
  inReplyTo: string | null;
  references: string | null;
  date: string | null;
  html: string | null;
  text: string | null;
  attachments: Array<{
    filename: string;
    mimeType: string;
    disposition: string | null;
    related: boolean;
    contentId: string | null;
    content: Uint8Array;
  }>;
}
```

### 使用方法

```typescript
import PostalMime from 'postal-mime';

const buffer = await new Response(message.raw).arrayBuffer();
const email = await PostalMime.parse(buffer);

console.log(email.subject);
console.log(email.from?.address);
console.log(email.text);
console.log(email.attachments.length);
```

## mimetext API クイックリファレンス

mimetext v3.0.27 は送信メールを作成します。

```typescript
import { createMimeMessage } from 'mimetext';

const msg = createMimeMessage();

// Sender
msg.setSender({ name: 'John Doe', addr: 'john@example.com' });

// Recipients
msg.setRecipient('alice@example.com');
msg.setRecipients(['bob@example.com', 'carol@example.com']);
msg.setCc('manager@example.com');
msg.setBcc(['audit@example.com']);

// Headers
msg.setSubject('Meeting Notes');
msg.setHeader('In-Reply-To', '<previous-message-id>');
msg.setHeader('References', '<msg1> <msg2>');
msg.setHeader('Message-ID', `<${crypto.randomUUID()}@example.com>`);

// Content
msg.addMessage({
  contentType: 'text/plain',
  data: 'Plain text content'
});

msg.addMessage({
  contentType: 'text/html',
  data: '<p>HTML content</p>'
});

// Attachments
msg.addAttachment({
  filename: 'report.pdf',
  contentType: 'application/pdf',
  data: pdfBuffer // Uint8Array or base64 string
});

// Generate raw MIME
const raw = msg.asRaw(); // Returns string
```

## TypeScript の型

```typescript
import { 
  ForwardableEmailMessage,
  EmailMessage 
} from 'cloudflare:email';

interface Env {
  EMAIL: SendEmail;
  EMAIL_ARCHIVE: KVNamespace;
  ALLOWED_SENDERS: KVNamespace;
}

export default {
  async email(
    message: ForwardableEmailMessage,
    env: Env,
    ctx: ExecutionContext
  ): Promise<void> {
    // Fully typed
  }
};
```
