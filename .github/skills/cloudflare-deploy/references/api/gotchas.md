# 注意点とトラブルシューティング

## レート制限と 429 エラー

**実際の制限値:**
- ユーザー／トークンごとに **5分間で1200リクエスト**（全体に適用）
- IP アドレスごとに **1秒間で200リクエスト**
- **GraphQL: 5分間で320**（コストベース）

**SDK の動作:**
- 指数バックオフを使って自動的に再試行する（デフォルトは2回、Go は10回）
- `Retry-After` ヘッダーに従う
- 再試行をすべて使い切ると `RateLimitError` をスローする

**対処方法:**

```typescript
// Increase retries for rate-limit-heavy workflows
const client = new Cloudflare({ maxRetries: 5 });

// Add application-level throttling
import pLimit from 'p-limit';
const limit = pLimit(10); // Max 10 concurrent requests
```

## SDK 固有の問題

### Go: 必須フィールドのラッパー

**問題:** Go SDK では、省略可能なフィールドに `cloudflare.F()` ラッパーが必要です。

```go
// ❌ WRONG - Won't compile or send field
client.Zones.New(ctx, cloudflare.ZoneNewParams{
    Name: "example.com",
})

// ✅ CORRECT
client.Zones.New(ctx, cloudflare.ZoneNewParams{
    Name: cloudflare.F("example.com"),
    Account: cloudflare.F(cloudflare.ZoneNewParamsAccount{
        ID: cloudflare.F("account-id"),
    }),
})
```

**理由:** ゼロ値、null、省略されたフィールドを区別するためです。

### Python: 非同期クライアントと同期クライアント

**問題:** 非同期コンテキストで同期クライアントを使用する、またはその逆の使い方をすることです。

```python
# ❌ WRONG - Can't await sync client
from cloudflare import Cloudflare
client = Cloudflare()
await client.zones.list()  # TypeError

# ✅ CORRECT - Use AsyncCloudflare
from cloudflare import AsyncCloudflare
client = AsyncCloudflare()
await client.zones.list()
```

## トークンの権限エラー（403）

**問題:** 有効なトークンを使用しているのに、API が 403 Forbidden を返します。

**原因:** トークンに必要な権限（スコープ）がありません。

**必要なスコープ:**

| 操作 | 必要なスコープ |
|-----------|----------------|
| ゾーンの一覧表示 | Zone:Read（ゾーン単位またはアカウント単位） |
| ゾーンの作成 | Zone:Edit（アカウント単位） |
| DNS の編集 | DNS:Edit（ゾーン単位） |
| Worker のデプロイ | Workers Script:Edit（アカウント単位） |
| KV の読み取り | Workers KV Storage:Read |
| KV への書き込み | Workers KV Storage:Edit |

**対処方法:** Dashboard → My Profile → API Tokens で、適切な権限を付与したトークンを再作成してください。

## ページネーションによる結果の欠落

**問題:** 最初の20件しか取得できません（デフォルトのページサイズ）。

**対処方法:** 自動ページネーションに対応したイテレーターを使用してください。

```typescript
// ❌ WRONG - Only first page (20 items)
const page = await client.zones.list();

// ✅ CORRECT - All results
const zones = [];
for await (const zone of client.zones.list()) {
  zones.push(zone);
}
```

## Workers のサブリクエスト

**問題:** Workers で予想より早くレート制限に達します。

**原因:** Workers のサブリクエストは、それぞれ個別の API 呼び出しとしてカウントされます。

**対処方法:** Workers では REST API の代わりにバインディングを使用してください（../bindings/ を参照）。

```typescript
// ❌ WRONG - REST API in Workers (counts against rate limit)
const client = new Cloudflare({ apiToken: env.CLOUDFLARE_API_TOKEN });
const zones = await client.zones.list();

// ✅ CORRECT - Use bindings (no rate limit)
// Access via env.MY_BINDING
```

## 認証エラー（401）

**問題:** 「Authentication failed」または「Invalid token」が表示されます。

**原因:**
- トークンの有効期限が切れている
- トークンが削除または取り消されている
- 環境変数にトークンが設定されていない
- トークンの形式が間違っている

**対処方法:**

```typescript
// Verify token is set
if (!process.env.CLOUDFLARE_API_TOKEN) {
  throw new Error('CLOUDFLARE_API_TOKEN not set');
}

// Test token
const user = await client.user.tokens.verify();
console.log('Token valid:', user.status);
```

## タイムアウトエラー

**問題:** リクエストがタイムアウトします（デフォルトは60秒）。

**原因:** 大規模な操作（DNS の一括操作、ゾーン転送）。

**対処方法:** タイムアウトを延長するか、操作を分割してください。

```typescript
// Increase timeout
const client = new Cloudflare({
  timeout: 300000, // 5 minutes
});

// Or split operations
const batchSize = 100;
for (let i = 0; i < records.length; i += batchSize) {
  const batch = records.slice(i, i + batchSize);
  await processBatch(batch);
}
```

## ゾーンが見つからない（404）

**問題:** ゾーン ID は有効なのに 404 が返されます。

**原因:**
- ゾーンがトークンに関連付けられたアカウントにない
- ゾーンが削除されている
- ゾーン ID の形式が間違っている

**対処方法:**

```typescript
// List all zones to find correct ID
for await (const zone of client.zones.list()) {
  console.log(zone.id, zone.name);
}
```

## 制限値一覧

| リソース／制限 | 値 | 備考 |
|----------------|-------|-------|
| API のレート制限 | 1200/5min | ユーザー／トークンごと |
| IP のレート制限 | 200/sec | IP ごと |
| GraphQL のレート制限 | 320/5min | コストベース |
| 並列リクエスト数（推奨） | < 10 | API に過度な負荷をかけないため |
| デフォルトのページサイズ | 20 | 自動ページネーションを使用 |
| 最大ページサイズ | 50 | 一部のエンドポイント |

## ベストプラクティス

**セキュリティ:**
- トークンをコミットしない
- 権限を必要最小限にする
- トークンを定期的にローテーションする
- トークンに有効期限を設定する

**パフォーマンス:**
- 操作をまとめて実行する
- ページネーションを適切に使用する
- レスポンスをキャッシュする
- レート制限に対処する

**コードの構成:**

```typescript
// Create reusable client instance
export const cfClient = new Cloudflare({
  apiToken: process.env.CLOUDFLARE_API_TOKEN,
  maxRetries: 5,
});

// Wrap common operations
export async function getZoneDetails(zoneId: string) {
  return await cfClient.zones.get({ zone_id: zoneId });
}
```

## 関連項目

- [api.md](./api.md) - エラーの種類、認証
- [configuration.md](./configuration.md) - タイムアウトと再試行の設定
- [patterns.md](./patterns.md) - エラー処理のパターン
