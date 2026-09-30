# Tail Workers API リファレンス

## ハンドラーのシグネチャ

```typescript
export default {
  async tail(
    events: TraceItem[],
    env: Env,
    ctx: ExecutionContext
  ): Promise<void> {
    // Process events
  }
} satisfies ExportedHandler<Env>;
```

**パラメーター:**
- `events`: `TraceItem` オブジェクトの配列（プロデューサーの呼び出しごとに1つ）
- `env`: バインディング（KV、D1、R2、環境変数など）
- `ctx`: 非同期処理用の `waitUntil()` を含むコンテキスト

**重要:** Tail ハンドラーは値を返しません。非同期処理には `ctx.waitUntil()` を使用してください。

## TraceItem 型

```typescript
interface TraceItem {
  scriptName: string;           // Producer Worker name
  eventTimestamp: number;        // Epoch milliseconds
  outcome: 'ok' | 'exception' | 'exceededCpu' | 'exceededMemory' 
         | 'canceled' | 'scriptNotFound' | 'responseStreamDisconnected' | 'unknown';
  
  event?: {
    request?: {
      url: string;               // Redacted by default
      method: string;
      headers: Record<string, string>;  // Sensitive headers redacted
      cf?: IncomingRequestCfProperties;
      getUnredacted(): TraceRequest;    // Bypass redaction (use carefully)
    };
    response?: {
      status: number;
    };
  };
  
  logs: Array<{
    timestamp: number;           // Epoch milliseconds
    level: 'debug' | 'info' | 'log' | 'warn' | 'error';
    message: unknown[];          // Args passed to console function
  }>;
  
  exceptions: Array<{
    timestamp: number;           // Epoch milliseconds
    name: string;                // Error type (Error, TypeError, etc.)
    message: string;             // Error description
  }>;
  
  diagnosticsChannelEvents: Array<{
    channel: string;
    message: unknown;
    timestamp: number;           // Epoch milliseconds
  }>;
}
```

**注:** 公式 SDK では `TailItem` ではなく `TraceItem` を使用します。正確な型を使うには `@cloudflare/workers-types` を使用してください。

## タイムスタンプの扱い

すべてのタイムスタンプは秒ではなく、**エポックミリ秒**です。

```typescript
// ✅ CORRECT - use directly with Date
const date = new Date(event.eventTimestamp);

// ❌ WRONG - don't multiply by 1000
const date = new Date(event.eventTimestamp * 1000);
```

## 自動的な秘匿化

デフォルトでは、機密データは `TraceRequest` から秘匿化されます。

### ヘッダーの秘匿化

以下の部分文字列を含むヘッダー（大文字と小文字を区別しません）:
- `auth`、`key`、`secret`、`token`、`jwt`
- `cookie`、`set-cookie`

秘匿化された値は `"REDACTED"` と表示されます。

### URL の秘匿化

- **16進数 ID:** 32文字以上の16進数 → `"REDACTED"`
- **Base64 ID:** 大文字2文字以上、小文字2文字以上、数字2文字以上を含む21文字以上の文字列 → `"REDACTED"`

## 秘匿化の回避

```typescript
export default {
  async tail(events, env, ctx) {
    for (const event of events) {
      // ⚠️ Use with extreme caution
      const unredacted = event.event?.request?.getUnredacted();
      // unredacted.url and unredacted.headers contain raw values
    }
  }
};
```

**ベストプラクティス:**
- 絶対に必要な場合に限り `getUnredacted()` を呼び出す
- 秘匿化されていない機密データをログに記録しない
- 外部へ送信する前に追加のフィルタリングを実装する
- API キーには環境変数を使用し、ハードコードしない

## 型安全なハンドラー

```typescript
interface Env {
  LOGS_KV: KVNamespace;
  ANALYTICS: AnalyticsEngineDataset;
  LOG_ENDPOINT: string;
  API_TOKEN: string;
}

export default {
  async tail(
    events: TraceItem[],
    env: Env,
    ctx: ExecutionContext
  ): Promise<void> {
    const payload = events.map(event => ({
      script: event.scriptName,
      timestamp: event.eventTimestamp,
      outcome: event.outcome,
      url: event.event?.request?.url,
      status: event.event?.response?.status,
    }));
    
    ctx.waitUntil(
      fetch(env.LOG_ENDPOINT, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      })
    );
  }
} satisfies ExportedHandler<Env>;
```

## Outcome と HTTP ステータスの違い

**重要:** `outcome` はスクリプトの実行状態であり、HTTP ステータスではありません。

- Worker が 500 を返す → スクリプトが正常に完了した場合は `outcome='ok'`
- 捕捉されない例外 → HTTP ステータスに関係なく `outcome='exception'`
- CPU 制限超過 → `outcome='exceededCpu'`

```typescript
// ✅ Check outcome for script execution status
if (event.outcome === 'exception') {
  // Script threw uncaught exception
}

// ✅ Check HTTP status separately
if (event.event?.response?.status === 500) {
  // HTTP 500 returned (script may have handled error)
}
```

## シリアライズに関する考慮事項

`log.message` は `unknown[]` であり、シリアライズできないオブジェクトを含む場合があります。

```typescript
// ❌ May fail with circular references or BigInt
JSON.stringify(events);

// ✅ Safe serialization
const safePayload = events.map(event => ({
  ...event,
  logs: event.logs.map(log => ({
    ...log,
    message: log.message.map(m => {
      try {
        return JSON.parse(JSON.stringify(m));
      } catch {
        return String(m);
      }
    })
  }))
}));
```

**よくあるシリアライズの問題:**
- ログに記録するオブジェクト内の循環参照
- `BigInt` の値（JSON にシリアライズできない）
- console.log の引数に含まれる関数やシンボル
- 本文サイズの上限を超える大きなオブジェクト