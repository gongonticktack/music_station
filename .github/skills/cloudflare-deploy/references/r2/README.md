# Cloudflare R2 オブジェクトストレージ

大容量ファイルの保存と配信に最適化された、下り転送料金が無料の S3 互換オブジェクトストレージです。

## 概要

R2 が提供する機能:
- S3 互換 API（Workers API + S3 REST）
- 世界中で下り転送料金が無料
- 書き込み／削除に対する強い整合性
- ストレージクラス（Standard／Infrequent Access）
- SSE-C 暗号化のサポート

**ユースケース:** メディアストレージ、バックアップ、静的アセット、ユーザーアップロード、データレイク

## クイックスタート

```bash
wrangler r2 bucket create my-bucket --location=enam
wrangler r2 object put my-bucket/file.txt --file=./local.txt
```

```typescript
// Upload
await env.MY_BUCKET.put(key, data, {
  httpMetadata: { contentType: 'image/jpeg' }
});

// Download
const object = await env.MY_BUCKET.get(key);
if (object) return new Response(object.body);
```

## 主な操作

| メソッド | 用途 | 戻り値 |
|--------|---------|---------|
| `put(key, value, options?)` | オブジェクトをアップロード | `R2Object \| null` |
| `get(key, options?)` | オブジェクトをダウンロード | `R2ObjectBody \| R2Object \| null` |
| `head(key)` | メタデータのみを取得 | `R2Object \| null` |
| `delete(keys)` | オブジェクトを削除 | `Promise<void>` |
| `list(options?)` | オブジェクトを一覧表示 | `R2Objects` |

## ストレージクラス

- **Standard**: 頻繁にアクセスするデータ向け。読み取りのレイテンシが低い
- **InfrequentAccess**: 最低 30 日間の保存期間が必要。取得料金が発生し、ストレージ料金は低い

## イベント通知

R2 は Cloudflare Queues と連携し、イベント駆動型のワークフローを実現します:

```typescript
// wrangler.jsonc
{
  "event_notifications": [{
    "queue": "r2-notifications",
    "actions": ["PutObject", "DeleteObject"]
  }]
}

// Consumer
async queue(batch: MessageBatch, env: Env) {
  for (const message of batch.messages) {
    const event = message.body; // { action, bucket, object, timestamps }
    if (event.action === 'PutObject') {
      // Process upload: thumbnail generation, virus scan, etc.
    }
  }
}
```

## 読む順序

**初めて利用する方:** README → configuration.md → api.md → patterns.md  
**特定のタスク:**
- セットアップ: configuration.md
- クライアントからのアップロード: patterns.md（署名付き URL）
- 公開静的サイト: patterns.md（パブリックアクセス + カスタムドメイン）
- アップロードの処理: README（イベント通知）+ queues リファレンス
- デバッグ: gotchas.md

## このリファレンスの内容

- [configuration.md](./configuration.md) - バインディング、S3 SDK、CORS、ライフサイクル、トークンのスコープ
- [api.md](./api.md) - Workers API、マルチパート、条件付きリクエスト、署名付き URL
- [patterns.md](./patterns.md) - ストリーミング、キャッシュ、クライアントからのアップロード、公開バケット
- [gotchas.md](./gotchas.md) - リストの切り捨て、etag 形式、ストリーム長、S3 SDK のリージョン

## 関連項目

- [workers](../workers/) - Worker ランタイムと fetch ハンドラー
- [kv](../kv/) - R2 オブジェクトのメタデータストレージ
- [d1](../d1/) - R2 URL をリレーショナルデータベースに保存
- [queues](../queues/) - R2 のアップロードを非同期に処理
