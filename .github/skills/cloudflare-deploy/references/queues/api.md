# Queues API リファレンス

## プロデューサー: メッセージの送信

```typescript
// Basic send
await env.MY_QUEUE.send({ url: request.url, timestamp: Date.now() });

// Options: delay (max 43200s), contentType (json|text|bytes|v8)
await env.MY_QUEUE.send(message, { delaySeconds: 600 });
await env.MY_QUEUE.send(message, { delaySeconds: 0 }); // Override queue default

// Batch (up to 100 msgs or 256 KB)
await env.MY_QUEUE.sendBatch([
  { body: 'msg1' },
  { body: 'msg2' },
  { body: 'msg3', options: { delaySeconds: 300 } }
]);

// Non-blocking with ctx.waitUntil - send continues after response
ctx.waitUntil(env.MY_QUEUE.send({ data: 'async' }));

// Background tasks in queue consumer
export default {
  async queue(batch: MessageBatch, env: Env, ctx: ExecutionContext): Promise<void> {
    for (const msg of batch.messages) {
      await processMessage(msg.body);
      
      // Fire-and-forget analytics (doesn't block ack)
      ctx.waitUntil(
        env.ANALYTICS_QUEUE.send({ messageId: msg.id, processedAt: Date.now() })
      );
      
      msg.ack();
    }
  }
};
```

## コンシューマー: プッシュ型（Worker）

```typescript
// Type-safe handler with ExportedHandler
interface Env {
  MY_QUEUE: Queue;
  DB: D1Database;
}

export default {
  async queue(batch: MessageBatch<MessageBody>, env: Env, ctx: ExecutionContext): Promise<void> {
    // batch.queue, batch.messages.length
    for (const msg of batch.messages) {
      // msg.id, msg.body, msg.timestamp, msg.attempts
      try {
        await processMessage(msg.body);
        msg.ack();
      } catch (error) {
        msg.retry({ delaySeconds: 600 });
      }
    }
  }
} satisfies ExportedHandler<Env>;
```

**重要な警告:**

1. **明示的に ack または retry されていないメッセージは、`max_retries` に達するまで無期限に自動再試行されます。** 各メッセージに対して必ず `msg.ack()` または `msg.retry()` を呼び出してください。

2. **捕捉されないエラーをスローすると、失敗したメッセージだけでなくバッチ全体が再試行されます。** 個々のメッセージの処理は必ず try/catch で囲み、メッセージごとに明示的に `msg.retry()` を呼び出してください。

```typescript
// ❌ BAD: Uncaught error retries entire batch
async queue(batch: MessageBatch): Promise<void> {
  for (const msg of batch.messages) {
    await riskyOperation(msg.body); // If this throws, entire batch retries
    msg.ack();
  }
}

// ✅ GOOD: Catch per message, handle individually
async queue(batch: MessageBatch): Promise<void> {
  for (const msg of batch.messages) {
    try {
      await riskyOperation(msg.body);
      msg.ack();
    } catch (error) {
      msg.retry({ delaySeconds: 60 });
    }
  }
}
```

## Ack/Retry の優先順位ルール

1. **メッセージごとの呼び出しが優先される**: `msg.ack()` と `msg.retry()` の両方を呼び出した場合は、最後の呼び出しが有効になります
2. **バッチ呼び出しで上書きされない**: `batch.ackAll()` は、明示的な ack/retry がないメッセージにのみ適用されます
3. **何もしない場合は自動再試行**: 明示的な操作がないメッセージは、設定された遅延時間で再試行されます

```typescript
async queue(batch: MessageBatch): Promise<void> {
  for (const msg of batch.messages) {
    msg.ack();        // Message marked for ack
    msg.retry();      // Overrides ack - message will retry
  }
  
  batch.ackAll();     // Only affects messages not explicitly handled above
}
```

## バッチ操作

```typescript
// Acknowledge entire batch
try {
  await bulkProcess(batch.messages);
  batch.ackAll();
} catch (error) {
  batch.retryAll({ delaySeconds: 300 });
}
```

## 指数バックオフ

```typescript
async queue(batch: MessageBatch, env: Env): Promise<void> {
  for (const msg of batch.messages) {
    try {
      await processMessage(msg.body);
      msg.ack();
    } catch (error) {
      // 30s, 60s, 120s, 240s, 480s, ... up to 12h max
      const delay = Math.min(30 * (2 ** msg.attempts), 43200);
      msg.retry({ delaySeconds: delay });
    }
  }
}
```

## 複数キュー、単一コンシューマー

```typescript
export default {
  async queue(batch: MessageBatch, env: Env): Promise<void> {
    switch (batch.queue) {
      case 'high-priority': await processUrgent(batch.messages); break;
      case 'low-priority': await processDeferred(batch.messages); break;
      case 'email': await sendEmails(batch.messages); break;
      default: batch.retryAll();
    }
  }
};
```

## コンシューマー: プル型（HTTP）

```typescript
// Pull messages
const response = await fetch(
  `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/queues/${QUEUE_ID}/messages/pull`,
  {
    method: 'POST',
    headers: { 'authorization': `Bearer ${API_TOKEN}`, 'content-type': 'application/json' },
    body: JSON.stringify({ visibility_timeout_ms: 6000, batch_size: 50 })
  }
);

const data = await response.json();

// Acknowledge
await fetch(
  `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/queues/${QUEUE_ID}/messages/ack`,
  {
    method: 'POST',
    headers: { 'authorization': `Bearer ${API_TOKEN}`, 'content-type': 'application/json' },
    body: JSON.stringify({
      acks: [{ lease_id: msg.lease_id }],
      retries: [{ lease_id: msg2.lease_id, delay_seconds: 600 }]
    })
  }
);
```

## インターフェース

```typescript
interface MessageBatch<Body = unknown> {
  readonly queue: string;
  readonly messages: Message<Body>[];
  ackAll(): void;
  retryAll(options?: QueueRetryOptions): void;
}

interface Message<Body = unknown> {
  readonly id: string;
  readonly timestamp: Date;
  readonly body: Body;
  readonly attempts: number;
  ack(): void;
  retry(options?: QueueRetryOptions): void;
}

interface QueueSendOptions {
  contentType?: 'text' | 'bytes' | 'json' | 'v8';
  delaySeconds?: number; // 0-43200
}
```