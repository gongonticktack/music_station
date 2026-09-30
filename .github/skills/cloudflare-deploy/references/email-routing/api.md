# Email Routing API リファレンス

## Worker ランタイム API

### Email ハンドラーのインターフェース

```typescript
interface ExportedHandler<Env = unknown> {
  email?(message: ForwardableEmailMessage, env: Env, ctx: ExecutionContext): void | Promise<void>;
}
```

### ForwardableEmailMessage

受信メールを扱うための主要なインターフェースです。

```typescript
interface ForwardableEmailMessage {
  readonly from: string;          // Envelope sender (e.g., "sender@example.com")
  readonly to: string;             // Envelope recipient (e.g., "you@yourdomain.com")
  readonly headers: Headers;       // Web API Headers object
  readonly raw: ReadableStream;    // Raw MIME message stream
  
  setReject(reason: string): void;
  forward(rcptTo: string, headers?: Headers): Promise<void>;
}
```

**主なプロパティ:**

| プロパティ | 型 | 説明 |
|----------|------|-------------|
| `from` | `string` | エンベロープの送信者（MAIL FROM）。ヘッダーの From ではありません |
| `to` | `string` | エンベロープの宛先（RCPT TO）。ヘッダーの To ではありません |
| `headers` | `Headers` | メールヘッダー（Subject、From、To など） |
| `raw` | `ReadableStream` | MIME メッセージの生データ（一度だけ読み取り可能） |

**メソッド:**

- `setReject(reason)`: バウンスメッセージを付けてメールを拒否する
- `forward(rcptTo, headers?)`: 検証済みの宛先に転送し、任意でヘッダーを追加する

### Headers オブジェクト

標準の Web API Headers インターフェースです。

```typescript
// Access headers
const subject = message.headers.get("subject");
const from = message.headers.get("from");
const messageId = message.headers.get("message-id");

// Check spam score
const spamScore = parseFloat(message.headers.get("x-cf-spamh-score") || "0");
if (spamScore > 5) {
  message.setReject("Spam detected");
}
```

### よく使われるヘッダー

`subject`、`from`、`to`、`x-cf-spamh-score`（スパムスコア）、`message-id`（重複排除）、`dkim-signature`（認証）

### エンベロープとヘッダーのアドレス

**重要な違い:**

```typescript
// Envelope addresses (routing, auth checks)
message.from // "bounce@sender.com" (actual sender)
message.to   // "you@yourdomain.com" (your address)

// Header addresses (display, user-facing)
message.headers.get("from") // "Alice <alice@sender.com>"
message.headers.get("to")   // "Bob <you@yourdomain.com>"
```

**エンベロープアドレスを使う用途:**
- 認証/SPF チェック
- ルーティングの判断
- バウンス処理

**ヘッダーアドレスを使う用途:**
- ユーザーへの表示
- Reply-To の処理
- ユーザー向けのフィルタリング

## SendEmail バインディング

トランザクションメールを送信するための API です。

### 設定

```jsonc
// wrangler.jsonc
{
  "send_email": [
    { "name": "EMAIL" }
  ]
}
```

### TypeScript の型

```typescript
interface Env {
  EMAIL: SendEmail;
}

interface SendEmail {
  send(message: EmailMessage): Promise<void>;
}

interface EmailMessage {
  from: string | { name?: string; email: string };
  to: string | { name?: string; email: string } | Array<string | { name?: string; email: string }>;
  subject: string;
  text?: string;
  html?: string;
  headers?: Headers;
  reply_to?: string | { name?: string; email: string };
}
```

### メール送信の例

```typescript
interface Env {
  EMAIL: SendEmail;
}

export default {
  async fetch(request, env, ctx): Promise<Response> {
    await env.EMAIL.send({
      from: { name: "Acme Corp", email: "noreply@yourdomain.com" },
      to: [
        { name: "Alice", email: "alice@example.com" },
        "bob@example.com"
      ],
      subject: "Your order #12345 has shipped",
      text: "Track your package at: https://track.example.com/12345",
      html: "<p>Track your package at: <a href='https://track.example.com/12345'>View tracking</a></p>",
      reply_to: { name: "Support", email: "support@yourdomain.com" }
    });
    
    return new Response("Email sent");
  }
} satisfies ExportedHandler<Env>;
```

### SendEmail の制約

- **From アドレス**: 検証済みドメイン（Email Routing が有効な自分のドメイン）上のアドレスである必要があります
- **送信量の制限**: トランザクションメール専用です。一括メールやマーケティングメールには使えません
- **レート制限**: Free プランでは毎分 100 通。有料プランでは上限が引き上げられます
- **添付ファイル不可**: 代わりにホスト済みファイルへのリンクを使ってください
- **DKIM の制御不可**: Cloudflare が自動的に署名します

## REST API 操作

ベース URL: `https://api.cloudflare.com/client/v4`

### 認証

```bash
curl -H "Authorization: Bearer $API_TOKEN" https://api.cloudflare.com/client/v4/...
```

### 主なエンドポイント

| 操作 | メソッド | エンドポイント |
|-----------|--------|----------|
| ルーティングを有効化 | POST | `/zones/{zone_id}/email/routing/enable` |
| ルーティングを無効化 | POST | `/zones/{zone_id}/email/routing/disable` |
| ルールを一覧表示 | GET | `/zones/{zone_id}/email/routing/rules` |
| ルールを作成 | POST | `/zones/{zone_id}/email/routing/rules` |
| 宛先を検証 | POST | `/zones/{zone_id}/email/routing/addresses` |
| 宛先を一覧表示 | GET | `/zones/{zone_id}/email/routing/addresses` |

### ルーティングルール作成の例

```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/email/routing/rules" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "enabled": true,
    "name": "Forward sales",
    "matchers": [{"type": "literal", "field": "to", "value": "sales@yourdomain.com"}],
    "actions": [{"type": "forward", "value": ["alice@company.com"]}],
    "priority": 0
  }'
```

Matcher の種類: `literal`（完全一致）、`all`（すべてを対象）。