# Pipelines API リファレンス

## Pipeline バインディングインターフェース

```typescript
// From @cloudflare/workers-types
interface Pipeline {
  send(data: object | object[]): Promise<void>;
}

interface Env {
  STREAM: Pipeline;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // send() returns Promise<void> - no result data
    await env.STREAM.send([event]);
    return new Response('OK');
  }
} satisfies ExportedHandler<Env>;
```

**要点:**
- `send()` は単一のオブジェクトまたは配列を受け取ります
- 常に `Promise<void>` を返します（確認データは返しません）
- ネットワークエラーまたは検証エラーが発生すると例外をスローします（try/catch で囲んでください）
- fire-and-forget パターンには `ctx.waitUntil()` を使用します

## イベントの書き込み

### 単一イベント

```typescript
await env.STREAM.send([{
  user_id: "12345",
  event_type: "purchase",
  product_id: "widget-001",
  amount: 29.99
}]);
```

### イベントの一括送信

```typescript
const events = [
  { user_id: "user1", event_type: "view" },
  { user_id: "user2", event_type: "purchase", amount: 50 }
];
await env.STREAM.send(events);
```

**制限:**
- リクエストあたり最大 1 MB
- ストリームあたり 5 MB/s

### Fire-and-Forget パターン

```typescript
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const event = { /* ... */ };
    
    // Don't block response on send
    ctx.waitUntil(env.STREAM.send([event]));
    
    return new Response('OK');
  }
};
```

### エラー処理

```typescript
try {
  await env.STREAM.send([event]);
} catch (error) {
  console.error('Pipeline send failed:', error);
  // Log to another system, retry, or return error response
  return new Response('Failed to track event', { status: 500 });
}
```

## HTTP Ingest API

### エンドポイント形式

```
https://{stream-id}.ingest.cloudflare.com
```

`{stream-id}` は次のコマンドで取得します: `npx wrangler pipelines streams list`

### リクエスト形式

**重要:** 単一オブジェクトではなく配列を送信する必要があります

```bash
# ✅ Correct
curl -X POST https://{stream-id}.ingest.cloudflare.com \
  -H "Content-Type: application/json" \
  -d '[{"user_id": "123", "event_type": "purchase"}]'

# ❌ Wrong - will fail
curl -X POST https://{stream-id}.ingest.cloudflare.com \
  -H "Content-Type: application/json" \
  -d '{"user_id": "123", "event_type": "purchase"}'
```

### 認証

```bash
curl -X POST https://{stream-id}.ingest.cloudflare.com \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -d '[{"event": "data"}]'
```

**必要な権限:** Workers Pipeline Send

トークンの作成: Dashboard → Workers → API tokens → Pipeline Send 権限を付与して作成

### レスポンスコード

| コード | 意味 | 対応 |
|------|---------|--------|
| 200 | 受け付けました | 成功 |
| 400 | 形式が無効です | JSON 配列とスキーマの一致を確認 |
| 401 | 認証に失敗しました | トークンが有効か確認 |
| 413 | ペイロードが大きすぎます | 1 MB 未満の小さなバッチに分割 |
| 429 | レート制限に達しました | 待機し、遅延を入れて再試行 |
| 5xx | サーバーエラー | 指数バックオフで再試行 |

## SQL 関数クイックリファレンス

`INSERT INTO sink SELECT ... FROM stream` による変換で使用できます:

| 関数 | 例 | 用途 |
|----------|---------|----------|
| `UPPER(s)` | `UPPER(event_type)` | 文字列の正規化 |
| `LOWER(s)` | `LOWER(email)` | 大文字小文字を区別しない照合 |
| `CONCAT(...)` | `CONCAT(user_id, '_', product_id)` | 複合キーの生成 |
| `CASE WHEN ... THEN ... END` | `CASE WHEN amount > 100 THEN 'high' ELSE 'low' END` | 条件に応じたデータの拡張 |
| `CAST(x AS type)` | `CAST(timestamp AS string)` | 型変換 |
| `COALESCE(x, y)` | `COALESCE(amount, 0.0)` | デフォルト値の設定 |
| 算術演算子 | `amount * 1.1`, `price / quantity` | 計算 |
| 比較 | `amount > 100`, `status IN ('active', 'pending')` | 絞り込み |

**CAST で使用できる文字列型:** `string`, `int32`, `int64`, `float32`, `float64`, `bool`, `timestamp`

詳細なリファレンス: [Pipelines SQL Reference](https://developers.cloudflare.com/pipelines/sql-reference/)

## SQL 変換の例

### イベントの絞り込み

```sql
INSERT INTO my_sink
SELECT * FROM my_stream
WHERE event_type = 'purchase' AND amount > 100
```

### 特定のフィールドの選択

```sql
INSERT INTO my_sink
SELECT user_id, event_type, timestamp, amount
FROM my_stream
```

### 変換とデータの拡張

```sql
INSERT INTO my_sink
SELECT
  user_id,
  UPPER(event_type) as event_type,
  timestamp,
  amount * 1.1 as amount_with_tax,
  CONCAT(user_id, '_', product_id) as unique_key,
  CASE
    WHEN amount > 1000 THEN 'high_value'
    WHEN amount > 100 THEN 'medium_value'
    ELSE 'low_value'
  END as customer_tier
FROM my_stream
WHERE event_type IN ('purchase', 'refund')
```

## 結果のクエリ（R2 Data Catalog）

```bash
export WRANGLER_R2_SQL_AUTH_TOKEN=YOUR_CATALOG_TOKEN

npx wrangler r2 sql query "warehouse_name" "
SELECT 
  event_type,
  COUNT(*) as event_count,
  SUM(amount) as total_revenue
FROM default.my_table
WHERE event_type = 'purchase'
  AND timestamp >= '2025-01-01'
GROUP BY event_type
ORDER BY total_revenue DESC
LIMIT 100"
```

**注:** Iceberg テーブルでは、GROUP BY、JOIN、WHERE、ORDER BY などの標準 SQL クエリをサポートしています。
