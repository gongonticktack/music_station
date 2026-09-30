# Queues の注意点とトラブルシューティング

## 重大：本番環境でよくある重大なミス

### 1.「単一のエラーでバッチ全体が再試行される」

**問題：** キューハンドラーで捕捉されないエラーをスローすると、失敗したメッセージだけでなくバッチ全体が再試行される  
**原因：** 捕捉されない例外がランタイムに伝播し、バッチ単位の再試行が発生する  
**解決策：** 個々のメッセージ処理は必ず try/catch で囲み、明示的に `msg.retry()` を呼び出す

```typescript
// ❌ BAD: Throws error, retries entire batch
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

### 2.「メッセージが永久に再試行される」

**問題：** 明示的に ack も retry もされないメッセージは、自動的に無期限で再試行される  
**原因：** ランタイムの既定の動作では、`max_retries` に達するまで未処理のメッセージが再試行される  
**解決策：** 各メッセージに対して必ず `msg.ack()` または `msg.retry()` を呼び出す。メッセージを未処理のままにしない。

```typescript
// ❌ BAD: Skipped messages auto-retry forever
async queue(batch: MessageBatch): Promise<void> {
  for (const msg of batch.messages) {
    if (shouldProcess(msg.body)) {
      await process(msg.body);
      msg.ack();
    }
    // Missing: msg.ack() for skipped messages - they will retry!
  }
}

// ✅ GOOD: Explicitly handle all messages
async queue(batch: MessageBatch): Promise<void> {
  for (const msg of batch.messages) {
    if (shouldProcess(msg.body)) {
      await process(msg.body);
      msg.ack();
    } else {
      msg.ack(); // Explicitly ack even if not processing
    }
  }
}
```

## よくあるエラー

###「メッセージの重複処理」

**問題：** 同じメッセージが複数回処理される  
**原因：** 少なくとも1回の配信が保証されるため、再試行時に重複が発生する可能性がある  
**解決策：** 有効期限 TTL を設定した KV に処理済みメッセージ ID を記録し、コンシューマーが冪等になるよう設計する

```typescript
async queue(batch: MessageBatch, env: Env): Promise<void> {
  for (const msg of batch.messages) {
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

###「Pull コンシューマーがメッセージをデコードできない」

**問題：** Pull コンシューマーまたはダッシュボードに、判読できないメッセージ本文が表示される  
**原因：** `v8` コンテンツタイプで送信されたメッセージをデコードできるのは Workers の Push コンシューマーのみ  
**解決策：** Pull コンシューマーまたはダッシュボードで表示する場合は、`json` コンテンツタイプを使用する

```typescript
// Use json for pull consumers
await env.MY_QUEUE.send(data, { contentType: 'json' });

// Use v8 only for push consumers with complex JS types
await env.MY_QUEUE.send({ date: new Date(), tags: new Set() }, { contentType: 'v8' });
```

###「メッセージが配信されない」

**問題：** メッセージは送信されているが、コンシューマーが処理していない  
**原因：** キューが一時停止中、コンシューマーが設定されていない、またはコンシューマーでエラーが発生している  
**解決策：** `wrangler queues list` でキューの状態を確認し、`wrangler queues consumer add` でコンシューマーが設定されていることを確認して、`wrangler tail` でログを確認する

###「デッドレターキューの割合が高い」

**問題：** 多数のメッセージが DLQ に入る  
**原因：** 最大再試行回数に達した後も、コンシューマーがメッセージの処理に繰り返し失敗している  
**解決策：** コンシューマーのエラーログを確認し、外部依存先が利用可能か、メッセージ形式が想定どおりかを確認するか、再試行の遅延時間を増やす

## エラー分類のパターン

再試行するか DLQ に送るかを判断するため、エラーを分類します。

```typescript
async queue(batch: MessageBatch, env: Env): Promise<void> {
  for (const msg of batch.messages) {
    try {
      await processMessage(msg.body);
      msg.ack();
    } catch (error) {
      // Transient errors: retry with backoff
      if (isRetryable(error)) {
        const delay = Math.min(30 * (2 ** msg.attempts), 43200);
        msg.retry({ delaySeconds: delay });
      } 
      // Permanent errors: ack to avoid infinite retries
      else {
        console.error('Permanent error, sending to DLQ:', error);
        await env.ERROR_LOG.put(msg.id, JSON.stringify({ msg: msg.body, error: String(error) }));
        msg.ack(); // Prevent further retries
      }
    }
  }
}

function isRetryable(error: unknown): boolean {
  if (error instanceof Response) {
    // Retry: rate limits, timeouts, server errors
    return error.status === 429 || error.status >= 500;
  }
  if (error instanceof Error) {
    // Don't retry: validation, auth, not found
    return !error.message.includes('validation') && 
           !error.message.includes('unauthorized') &&
           !error.message.includes('not found');
  }
  return false; // Unknown errors don't retry
}
```

###「コンシューマーで CPU 時間超過」

**問題：** CPU 時間制限の超過によりコンシューマーが失敗する  
**原因：** コンシューマーの処理時間が、既定の CPU 時間制限である 30 秒を超えている  
**解決策：** wrangler.jsonc で CPU 制限を増やす：`{ "limits": { "cpu_ms": 300000 } }`（最大5分）

## コンテンツタイプの選択ガイド

**各コンテンツタイプを使用する場面：**

| コンテンツタイプ | 使用場面 | 読み取り可能な対象 | 対応する内容 |
|--------------|----------|-------------|----------|
| `json`（既定） | Pull コンシューマー、ダッシュボードでの表示、単純なオブジェクト | すべて（Push／Pull／ダッシュボード） | JSON にシリアライズ可能な型のみ |
| `v8` | Push コンシューマーのみ、複雑な JS オブジェクト | Push コンシューマーのみ | Date、Map、Set、BigInt、型付き配列 |
| `text` | 文字列のみのペイロード | すべて | 文字列のみ |
| `bytes` | バイナリデータ（画像、ファイル） | すべて | ArrayBuffer、Uint8Array |

**判断フロー：**
1. ダッシュボードで表示する、または Pull コンシューマーを使う必要がある？ → `json` を使用
2. Date、Map、Set、またはその他の V8 型が必要？ → `v8` を使用（Push コンシューマーのみ）
3. 文字列だけ？ → `text` を使用
4. バイナリデータ？ → `bytes` を使用

```typescript
// Dashboard/pull: use json
await env.QUEUE.send({ id: 123, name: 'test' }, { contentType: 'json' });

// Complex JS types (push only): use v8
await env.QUEUE.send({ 
  created: new Date(), 
  tags: new Set(['a', 'b']) 
}, { contentType: 'v8' });
```

## 制限事項

| 制限 | 値 | 備考 |
|-------|-------|-------|
| キューの最大数 | 10,000 | アカウントあたり |
| メッセージサイズ | 128 KB | メッセージあたりの最大値 |
| バッチサイズ（コンシューマー） | 100件 | バッチあたりのメッセージ最大数 |
| バッチサイズ（sendBatch） | 100件または256 KB | 先に達した方が適用される |
| スループット | 5,000件/秒 | キューあたり |
| 保持期間 | 4～14日 | 設定可能な保持期間 |
| 最大バックログ | 25 GB | キューのバックログサイズの上限 |
| 最大遅延 | 12時間（43,200秒） | メッセージ遅延の上限 |
| 最大再試行回数 | 100 | 再試行回数の上限 |
| CPU 時間の既定値 | 30秒 | コンシューマーの呼び出しあたり |
| CPU 時間の最大値 | 300秒（5分） | `limits.cpu_ms` で設定可能 |
| メッセージあたりの操作数 | 3（書き込み＋読み取り＋削除） | メッセージあたりの基本コスト |
| 料金 | 100万操作あたり0.40ドル | 100万回の無料操作を超えた分 |
| メッセージの課金単位 | 64 KB 単位 | メッセージは64 KB単位で課金される |
