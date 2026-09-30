# Cloudflare Email Routing スキルのリファレンス

## 概要

Cloudflare Email Routing を使うと、ドメイン用のカスタムメールアドレスを作成し、確認済みの転送先アドレスへメールを転送できます。無料で、プライバシーに配慮した設計（メールの保存やアクセスは行いません）であり、プログラムからメールを処理する Email Workers も利用できます。

**Cloudflare を権威 DNS サーバーとして利用するすべての Cloudflare 顧客が利用できます。**

## クイックスタート

```typescript
// Basic email handler
export default {
  async email(message, env, ctx) {
    // CRITICAL: Must consume stream before response
    const parser = new PostalMime.default();
    const email = await parser.parse(await message.raw.arrayBuffer());
    
    // Process email
    console.log(`From: ${message.from}, Subject: ${email.subject}`);
    
    // Forward or reject
    await message.forward("verified@destination.com");
  }
} satisfies ExportedHandler<Env>;
```

## 読む順序

**目的に応じて、ここから読み始めてください:**

1. **Email Routing は初めてですか？** → [configuration.md](configuration.md) → [patterns.md](patterns.md)
2. **Workers を追加しますか？** → [api.md](api.md) § Worker Runtime API → [patterns.md](patterns.md)
3. **メールを送信しますか？** → [api.md](api.md) § SendEmail Binding
4. **API 経由で管理しますか？** → [api.md](api.md) § REST API Operations
5. **問題をデバッグしますか？** → [gotchas.md](gotchas.md)

## 判断フロー

```
Need to receive emails?
├─ Simple forwarding only? → Dashboard rules (configuration.md)
├─ Complex logic/filtering? → Email Workers (api.md + patterns.md)
└─ Parse attachments/body? → postal-mime library (patterns.md § Parse Email)

Need to send emails?
├─ From Worker? → SendEmail binding (api.md § SendEmail)
└─ From external app? → Use external SMTP/API service

Having issues?
├─ Email not arriving? → gotchas.md § Mail Authentication
├─ Worker crashing? → gotchas.md § Stream Consumption
└─ Forward failing? → gotchas.md § Destination Verification
```

## 重要な概念

**ルーティングルール**: Dashboard/API で設定する、パターンベースの転送機能です。シンプルですが、機能は限定的です。

**Email Workers**: メールに完全にアクセスできる、カスタム TypeScript ハンドラーです。複雑なロジック、解析、保存、拒否を処理します。

**SendEmail Binding**: Workers 用の送信メール API です。トランザクションメール専用（マーケティング／一括送信には対応しません）です。

**ForwardableEmailMessage**: 受信メール用のランタイムインターフェースです。ヘッダー、raw ストリーム、転送／拒否メソッドを提供します。

## このリファレンスの内容

- **[configuration.md](configuration.md)** - セットアップ、デプロイ、wrangler の設定
- **[api.md](api.md)** - REST API + Worker ランタイム API + 型
- **[patterns.md](patterns.md)** - 動作する例を含む一般的なパターン
- **[gotchas.md](gotchas.md)** - 重大な落とし穴、トラブルシューティング、制限

## アーキテクチャ

```
Internet → MX Records → Cloudflare Email Routing
                            ├─ Routing Rules (dashboard)
                            └─ Email Worker (your code)
                                ├─ Forward to destination
                                ├─ Reject with reason
                                ├─ Store in R2/KV/D1
                                └─ Send outbound (SendEmail)
```

## 関連項目

- [Cloudflare Docs: Email Routing](https://developers.cloudflare.com/email-routing/)
- [Cloudflare Docs: Email Workers](https://developers.cloudflare.com/email-routing/email-workers/)
- [postal-mime npm package](https://www.npmjs.com/package/postal-mime)
