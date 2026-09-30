# Cloudflare Email Workers

Cloudflare Workers ランタイムを使って、受信メールをプログラムで処理します。

## 概要

Email Workers を使うと、エッジで独自のメール処理ロジックを実行できます。HTTP リクエストに使うものと同じ Workers ランタイムで、スパムフィルター、自動応答、チケットシステム、通知ハンドラーなどを構築できます。

**主な機能**:
- メッセージ全体にアクセスして受信メールを処理
- 検証済みの宛先に転送
- スレッドを適切に維持して返信を送信
- MIME の内容と添付ファイルを解析
- KV、R2、D1、外部 API と連携

## クイックスタート

### 最小限の ES Modules ハンドラー

```typescript
export default {
  async email(message, env, ctx) {
    // Reject spam
    if (message.from.includes('spam.com')) {
      message.setReject('Blocked');
      return;
    }
    
    // Forward to inbox
    await message.forward('inbox@example.com');
  }
};
```

### 基本操作

| 操作 | メソッド | 用途 |
|-----------|--------|----------|
| 転送 | `message.forward(to, headers?)` | 検証済みの宛先に振り分ける |
| 拒否 | `message.setReject(reason)` | SMTP エラーでブロックする |
| 返信 | `message.reply(emailMessage)` | スレッドを維持して自動応答する |
| 解析 | postal-mime ライブラリ | 件名、本文、添付ファイルを抽出する |

## 読む順序

内容を十分に理解するには、次の順序でファイルを読んでください。

1. **README.md**（このファイル）- 概要とクイックスタート
2. **configuration.md** - セットアップ、デプロイ、バインディング
3. **api.md** - API リファレンス全体
4. **patterns.md** - 実際の実装例
5. **gotchas.md** - 重大な落とし穴とデバッグ

## このリファレンスの内容

| ファイル | 説明 | 主なトピック |
|------|-------------|------------|
| [api.md](./api.md) | API リファレンス全体 | ForwardableEmailMessage、SendEmail バインディング、reply() メソッド、postal-mime/mimetext API |
| [configuration.md](./configuration.md) | セットアップと設定 | wrangler.jsonc、バインディング、デプロイ、依存関係 |
| [patterns.md](./patterns.md) | 実際の使用例 | KV の許可リスト、スレッドを維持した自動返信、添付ファイルの抽出、Webhook 通知 |
| [gotchas.md](./gotchas.md) | 落とし穴とデバッグ | ストリームの消費、ctx.waitUntil のエラー、セキュリティ、制限 |

## アーキテクチャ

```
Incoming Email → Email Routing → Email Worker
                                    ↓
                              Process + Decide
                                    ↓
                    ┌───────────────┼───────────────┐
                    ↓               ↓               ↓
                Forward          Reply          Reject
```

**イベントの流れ**:
1. メールがドメインに届く
2. Email Routing がルート（例: `support@example.com`）に一致させる
3. バインドされた Email Worker が `ForwardableEmailMessage` を受け取る
4. Worker が処理し、対応（転送/返信/拒否）を決定する
5. Worker のロジックに基づいてメールが配信または拒否される

## 重要な概念

### エンベロープとヘッダー

- **エンベロープアドレス**（`message.from`、`message.to`）: SMTP の転送用アドレス（信頼できる）
- **ヘッダーアドレス**（本文から解析）: 表示用アドレス（偽装される可能性がある）

セキュリティ上の判断にはエンベロープアドレスを使ってください。

### 1 回限りのストリーム

`message.raw` は ReadableStream で、一度しか読み取れません。複数回使う場合は ArrayBuffer にバッファーしてください。

```typescript
// Buffer first
const buffer = await new Response(message.raw).arrayBuffer();
const email = await PostalMime.parse(buffer);
```

詳しくは [gotchas.md](./gotchas.md#readablestream-can-only-be-consumed-once) を参照してください。

### 検証済みの宛先

`forward()` が機能するのは、Cloudflare Email Routing ダッシュボードで検証済みのアドレスだけです。デプロイ前に宛先を追加してください。

## ユースケース

- **スパムフィルタリング**: 送信者、内容、評判に基づいてブロック
- **自動応答**: スレッドを維持して受領確認の返信を送信
- **チケット作成**: メールを解析してサポートチケットを作成
- **メールのアーカイブ**: KV、R2、D1 に保存
- **通知の振り分け**: Slack、Discord、Webhook に転送
- **添付ファイルの処理**: ファイルを抽出して R2 ストレージに保存
- **マルチテナントの振り分け**: 受信者のサブドメインに基づいて振り分け
- **サイズフィルタリング**: サイズの大きすぎる添付ファイルを拒否

## 制限

| 制限 | 値 |
|-------|-------|
| メッセージの最大サイズ | 25 MiB |
| ルーティングルールの最大数 | 200 |
| 宛先の最大数 | 200 |
| CPU 時間（無料プラン） | 10ms |
| CPU 時間（有料プラン） | 50ms |

制限の全一覧は [gotchas.md](./gotchas.md#limits-reference) を参照してください。

## 前提条件

Email Workers をデプロイする前に、次の作業を行ってください。

1. ドメインの Cloudflare ダッシュボードで **Email Routing を有効にする**
2. 転送先の **宛先アドレスを検証する**
3. 送信ドメインの **DMARC/SPF を設定する**（返信に必須）
4. SendEmail バインディングを使って **wrangler.jsonc を設定する**

詳しいセットアップ方法は [configuration.md](./configuration.md) を参照してください。

## Service Worker 構文（非推奨）

新しいプロジェクトでは、上記の ES modules 形式を使ってください。Service Worker 構文（`addEventListener('email', ...)`）は非推奨ですが、引き続きサポートされています。

## 関連項目

- [Email Routing のドキュメント](https://developers.cloudflare.com/email-routing/)
- [Workers プラットフォーム](https://developers.cloudflare.com/workers/)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/)
- [npm の postal-mime](https://www.npmjs.com/package/postal-mime)
- [npm の mimetext](https://www.npmjs.com/package/mimetext)
