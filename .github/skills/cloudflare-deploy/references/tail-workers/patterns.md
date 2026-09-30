# Tail Workers の一般的なパターン

## コミュニティライブラリ

Tail Worker の実装は多くの場合カスタムですが、次のライブラリが役立つことがあります:

**ロギングと可観測性:**
- **Axiom** - `axiom-cloudflare-workers` (npm) - Axiom との直接統合
- **Baselime** - Baselime 可観測性プラットフォーム用 SDK
- **LogFlare** - 構造化ログの集約

**型定義:**
- **@cloudflare/workers-types** - 公式 TypeScript 型（`TraceItem` を使用）

**注:** ほとんどの統合にはカスタム Tail ハンドラーの実装が必要です。以下の統合例を参照してください。

## 基本パターン

### HTTP エンドポイントのロギング

```typescript
export default {
  async tail(events, env, ctx) {
    const payload = events.map(event => ({
      script: event.scriptName,
      timestamp: event.eventTimestamp,
      outcome: event.outcome,
      url: event.event?.request?.url,
      status: event.event?.response?.status,
      logs: event.logs,
      exceptions: event.exceptions,
    }));
    
    ctx.waitUntil(
      fetch(env.LOG_ENDPOINT, {
        method: "POST",
        body: JSON.stringify(payload),
      })
    );
  }
};
```

### エラー追跡のみ

```typescript
export default {
  async tail(events, env, ctx) {
    const errors = events.filter(e => 
      e.outcome === 'exception' || e.exceptions.length > 0
    );
    
    if (errors.length === 0) return;
    
    ctx.waitUntil(
      fetch(env.ERROR_ENDPOINT, {
        method: "POST",
        body: JSON.stringify(errors),
      })
    );
  }
};
```

## ストレージとの統合

### TTL 付き KV ストレージ

```typescript
export default {
  async tail(events, env, ctx) {
    ctx.waitUntil(
      Promise.all(events.map(event =>
        env.LOGS_KV.put(
          `log:${event.scriptName}:${event.eventTimestamp}`,
          JSON.stringify(event),
          { expirationTtl: 86400 }  // 24 hours
        )
      ))
    );
  }
};
```

### Analytics Engine のメトリクス

```typescript
export default {
  async tail(events, env, ctx) {
    ctx.waitUntil(
      Promise.all(events.map(event =>
        env.ANALYTICS.writeDataPoint({
          blobs: [event.scriptName, event.outcome],
          doubles: [1, event.event?.response?.status ?? 0],
          indexes: [event.event?.request?.cf?.colo ?? 'unknown'],
        })
      ))
    );
  }
};
```

## フィルタリングとルーティング

ルート、結果、その他の条件でフィルタリングする:

```typescript
export default {
  async tail(events, env, ctx) {
    // Route filtering
    const apiEvents = events.filter(e => 
      e.event?.request?.url?.includes('/api/')
    );
    
    // Multi-destination routing
    const errors = events.filter(e => e.outcome === 'exception');
    const success = events.filter(e => e.outcome === 'ok');
    
    const tasks = [];
    if (errors.length > 0) {
      tasks.push(fetch(env.ERROR_ENDPOINT, {
        method: "POST",
        body: JSON.stringify(errors),
      }));
    }
    if (success.length > 0) {
      tasks.push(fetch(env.SUCCESS_ENDPOINT, {
        method: "POST",
        body: JSON.stringify(success),
      }));
    }
    
    ctx.waitUntil(Promise.all(tasks));
  }
};
```

## サンプリング

イベントの一部だけを処理してコストを抑える:

```typescript
export default {
  async tail(events, env, ctx) {
    if (Math.random() > 0.1) return;  // 10% sample rate
    ctx.waitUntil(fetch(env.LOG_ENDPOINT, {
      method: "POST",
      body: JSON.stringify(events),
    }));
  }
};
```

## 高度なパターン

### Durable Objects によるバッチ処理

送信前にイベントを蓄積する:

```typescript
export default {
  async tail(events, env, ctx) {
    const batch = env.BATCH_DO.get(env.BATCH_DO.idFromName("batch"));
    ctx.waitUntil(batch.fetch("https://batch/add", {
      method: "POST",
      body: JSON.stringify(events),
    }));
  }
};
```

実装全体については durable-objects スキルを参照してください。

### Workers for Platforms

動的ディスパッチでは、リクエストごとに 2 つのイベントが送信されます。`scriptName` でフィルタリングして、ディスパッチのイベントとユーザー Worker のイベントを区別してください。

### エラー処理

外部呼び出しは必ずラップしてください。フォールバック用ストレージのパターンについては gotchas.md を参照してください。
