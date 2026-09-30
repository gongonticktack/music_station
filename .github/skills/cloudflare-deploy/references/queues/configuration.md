# Queues の設定

## キューの作成

```bash
wrangler queues create my-queue
wrangler queues create my-queue --retention-period-hours=336  # 14 days
wrangler queues create my-queue --delivery-delay-secs=300
```

## プロデューサーのバインディング

**wrangler.jsonc:**
```jsonc
{
  "queues": {
    "producers": [
      {
        "queue": "my-queue-name",
        "binding": "MY_QUEUE",
        "delivery_delay": 60  // Optional: default delay in seconds
      }
    ]
  }
}
```

## コンシューマーの設定（プッシュ型）

**wrangler.jsonc:**
```jsonc
{
  "queues": {
    "consumers": [
      {
        "queue": "my-queue-name",
        "max_batch_size": 10,           // 1-100, default 10
        "max_batch_timeout": 5,         // 0-60s, default 5
        "max_retries": 3,               // default 3, max 100
        "dead_letter_queue": "my-dlq",  // optional
        "retry_delay": 300              // optional: delay retries in seconds
      }
    ]
  }
}
```

## コンシューマーの設定（プル型）

**wrangler.jsonc:**
```jsonc
{
  "queues": {
    "consumers": [
      {
        "queue": "my-queue-name",
        "type": "http_pull",
        "visibility_timeout_ms": 5000,  // default 30000, max 12h
        "max_retries": 5,
        "dead_letter_queue": "my-dlq"
      }
    ]
  }
}
```

## TypeScript の型

```typescript
interface Env {
  MY_QUEUE: Queue<MessageBody>;
  ANALYTICS_QUEUE: Queue<AnalyticsEvent>;
}

interface MessageBody {
  id: string;
  action: 'create' | 'update' | 'delete';
  data: Record<string, any>;
}

export default {
  async queue(batch: MessageBatch<MessageBody>, env: Env): Promise<void> {
    for (const msg of batch.messages) {
      console.log(msg.body.action);
      msg.ack();
    }
  }
} satisfies ExportedHandler<Env>;
```

## コンテンツタイプの選択

コンシューマーの種類とデータ要件に応じてコンテンツタイプを選択してください。

| コンテンツタイプ | 使用するケース | 読み取り可能な対象 | 対応内容 | サイズ |
|--------------|----------|-------------|----------|------|
| `json` | プル型コンシューマー、ダッシュボードでの表示、単純なオブジェクト | すべて（プッシュ/プル/ダッシュボード） | JSON にシリアライズ可能な型のみ | 中 |
| `v8` | プッシュ型コンシューマーのみ、複雑な JS オブジェクト | プッシュ型コンシューマーのみ | Date、Map、Set、BigInt、型付き配列 | 小 |
| `text` | 文字列のみのペイロード | すべて | 文字列のみ | 最小 |
| `bytes` | バイナリデータ（画像、ファイル） | すべて | ArrayBuffer、Uint8Array | 可変 |

**選択の流れ:**
1. ダッシュボードで表示する必要がある、またはプル型コンシューマーを使いますか？ → `json` を使用
2. Date、Map、Set、その他の V8 型が必要ですか？ → `v8` を使用（プッシュ型コンシューマーのみ）
3. 文字列のみですか？ → `text` を使用
4. バイナリデータですか？ → `bytes` を使用

```typescript
// JSON: Good for simple objects, pull consumers, dashboard visibility
await env.QUEUE.send({ id: 123, name: 'test' }, { contentType: 'json' });

// V8: Good for Date, Map, Set (push consumers only)
await env.QUEUE.send({ 
  created: new Date(), 
  tags: new Set(['a', 'b']) 
}, { contentType: 'v8' });

// Text: Simple strings
await env.QUEUE.send('process-user-123', { contentType: 'text' });

// Bytes: Binary data
await env.QUEUE.send(imageBuffer, { contentType: 'bytes' });
```

**デフォルトの動作:** 指定がない場合、Cloudflare は JSON にシリアライズ可能なオブジェクトには `json` を、複雑な型には `v8` を自動選択します。

**重要:** `v8` メッセージはプル型コンシューマーでは読み取れず、ダッシュボードでも表示できません。可視性またはプル型での消費が必要な場合は `json` を使用してください。

## CLI コマンド

```bash
# Consumer management
wrangler queues consumer add my-queue my-worker --batch-size=50 --max-retries=5
wrangler queues consumer http add my-queue
wrangler queues consumer worker remove my-queue my-worker
wrangler queues consumer http remove my-queue

# Queue operations
wrangler queues list
wrangler queues pause my-queue
wrangler queues resume my-queue
wrangler queues purge my-queue
wrangler queues delete my-queue
```