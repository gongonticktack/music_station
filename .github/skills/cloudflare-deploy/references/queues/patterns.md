# Queuesのパターンとベストプラクティス

## 非同期タスク処理

```typescript
// Producer: Accept request, queue work
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { userId, reportType } = await request.json();
    await env.REPORT_QUEUE.send({ userId, reportType, requestedAt: Date.now() });
    return Response.json({ message: 'Report queued', status: 'pending' });
  }
};

// Consumer: Process reports
export default {
  async queue(batch: MessageBatch, env: Env): Promise<void> {
    for (const msg of batch.messages) {
      const { userId, reportType } = msg.body;
      const report = await generateReport(userId, reportType, env);
      await env.REPORTS_BUCKET.put(`${userId}/${reportType}.pdf`, report);
      msg.ack();
    }
  }
};
```

## API呼び出しのバッファリング

```typescript
// Producer: Queue log entries
ctx.waitUntil(env.LOGS_QUEUE.send({
  method: request.method,
  url: request.url,
  timestamp: Date.now()
}));

// Consumer: Batch write to external API
async queue(batch: MessageBatch, env: Env): Promise<void> {
  const logs = batch.messages.map(m => m.body);
  await fetch(env.LOG_ENDPOINT, { method: 'POST', body: JSON.stringify({ logs }) });
  batch.ackAll();
}
```

## 上流へのレート制限

```typescript
async queue(batch: MessageBatch, env: Env): Promise<void> {
  for (const msg of batch.messages) {
    try {
      await callRateLimitedAPI(msg.body);
      msg.ack();
    } catch (error) {
      if (error.status === 429) {
        const retryAfter = parseInt(error.headers.get('Retry-After') || '60');
        msg.retry({ delaySeconds: retryAfter });
      } else throw error;
    }
  }
}
```

## イベント駆動ワークフロー

```typescript
// R2 event → Queue → Worker
export default {
  async queue(batch: MessageBatch, env: Env): Promise<void> {
    for (const msg of batch.messages) {
      const event = msg.body;
      if (event.action === 'PutObject') {
        await processNewFile(event.object.key, env);
      } else if (event.action === 'DeleteObject') {
        await cleanupReferences(event.object.key, env);
      }
      msg.ack();
    }
  }
};
```

## デッドレターキューパターン

```typescript
// Main queue: After max_retries, goes to DLQ automatically
export default {
  async queue(batch: MessageBatch, env: Env): Promise<void> {
    for (const msg of batch.messages) {
      try {
        await riskyOperation(msg.body);
        msg.ack();
      } catch (error) {
        console.error(`Failed after ${msg.attempts} attempts:`, error);
      }
    }
  }
};

// DLQ consumer: Log and store failed messages
export default {
  async queue(batch: MessageBatch, env: Env): Promise<void> {
    for (const msg of batch.messages) {
      await env.FAILED_KV.put(msg.id, JSON.stringify(msg.body));
      msg.ack();
    }
  }
};
```

## 優先度付きキュー

優先度高: `max_batch_size: 5, max_batch_timeout: 1`。優先度低: `max_batch_size: 100, max_batch_timeout: 30`。

## 遅延ジョブ処理

```typescript
await env.EMAIL_QUEUE.send({ to, template, userId }, { delaySeconds: 3600 });
```

## ファンアウトパターン

```typescript
async fetch(request: Request, env: Env): Promise<Response> {
  const event = await request.json();
  
  // Send to multiple queues for parallel processing
  await Promise.all([
    env.ANALYTICS_QUEUE.send(event),
    env.NOTIFICATIONS_QUEUE.send(event),
    env.AUDIT_LOG_QUEUE.send(event)
  ]);
  
  return Response.json({ status: 'processed' });
}
```

## 冪等性パターン

```typescript
async queue(batch: MessageBatch, env: Env): Promise<void> {
  for (const msg of batch.messages) {
    // Check if already processed
    const processed = await env.PROCESSED_KV.get(msg.id);
    if (processed) {
      msg.ack();
      continue;
    }
    
    await processMessage(msg.body);
    await env.PROCESSED_KV.put(msg.id, '1', { expirationTtl: 86400 });
    msg.ack();
  }
}
```

## 統合: D1のバッチ書き込み

```typescript
async queue(batch: MessageBatch, env: Env): Promise<void> {
  // Collect all inserts for single D1 batch
  const statements = batch.messages.map(msg => 
    env.DB.prepare('INSERT INTO events (id, data, created) VALUES (?, ?, ?)')
      .bind(msg.id, JSON.stringify(msg.body), Date.now())
  );
  
  try {
    await env.DB.batch(statements);
    batch.ackAll();
  } catch (error) {
    console.error('D1 batch failed:', error);
    batch.retryAll({ delaySeconds: 60 });
  }
}
```

## 統合: Workflows

```typescript
// Queue triggers Workflow for long-running tasks
async queue(batch: MessageBatch, env: Env): Promise<void> {
  for (const msg of batch.messages) {
    try {
      const instance = await env.MY_WORKFLOW.create({
        id: msg.id,
        params: msg.body
      });
      console.log('Workflow started:', instance.id);
      msg.ack();
    } catch (error) {
      msg.retry({ delaySeconds: 30 });
    }
  }
}
```

## 統合: Durable Objects

```typescript
// Queue distributes work to Durable Objects by ID
async queue(batch: MessageBatch, env: Env): Promise<void> {
  for (const msg of batch.messages) {
    const { userId, action } = msg.body;
    
    // Route to user-specific DO
    const id = env.USER_DO.idFromName(userId);
    const stub = env.USER_DO.get(id);
    
    try {
      await stub.fetch(new Request('https://do/process', {
        method: 'POST',
        body: JSON.stringify({ action, messageId: msg.id })
      }));
      msg.ack();
    } catch (error) {
      msg.retry({ delaySeconds: 60 });
    }
  }
}
```