## ルーティングパターン

### セッションアフィニティ（ステートフル）

```typescript
export class SessionBackend extends Container {
  defaultPort = 3000;
  sleepAfter = "30m";
}

export default {
  async fetch(request: Request, env: Env) {
    const sessionId = request.headers.get("X-Session-ID") || crypto.randomUUID();
    const container = env.SESSION_BACKEND.getByName(sessionId);
    await container.startAndWaitForPorts();
    return container.fetch(request);
  }
};
```

**用途:** ユーザーセッション、WebSocket、ステートフルなゲーム、ユーザーごとのキャッシュ。

### 負荷分散（ステートレス）

```typescript
export default {
  async fetch(request: Request, env: Env) {
    const container = env.STATELESS_API.getRandom();
    await container.startAndWaitForPorts();
    return container.fetch(request);
  }
};
```

**用途:** ステートレスな HTTP API、CPU 負荷の高い処理、読み取り専用クエリ。

### シングルトンパターン

```typescript
export default {
  async fetch(request: Request, env: Env) {
    const container = env.GLOBAL_SERVICE.getByName("singleton");
    await container.startAndWaitForPorts();
    return container.fetch(request);
  }
};
```

**用途:** グローバルキャッシュ、集中管理コーディネーター、信頼できる唯一の情報源。

## WebSocket の転送

```typescript
export default {
  async fetch(request: Request, env: Env) {
    if (request.headers.get("Upgrade") === "websocket") {
      const sessionId = request.headers.get("X-Session-ID") || crypto.randomUUID();
      const container = env.WS_BACKEND.getByName(sessionId);
      await container.startAndWaitForPorts();
      
      // ⚠️ MUST use fetch(), not containerFetch()
      return container.fetch(request);
    }
    return new Response("Not a WebSocket request", { status: 400 });
  }
};
```

**⚠️ 重要:** WebSocket には必ず `fetch()` を使ってください。

## グレースフルシャットダウン

```typescript
export class GracefulContainer extends Container {
  private connections = new Set<WebSocket>();

  onStop() {
    // SIGTERM received, 15 minutes until SIGKILL
    for (const ws of this.connections) {
      ws.close(1001, "Server shutting down");
    }
    this.ctx.storage.put("shutdown-time", Date.now());
  }

  onActivityExpired(): boolean {
    return this.connections.size > 0;  // Keep alive if connections
  }
}
```

## 並行リクエストの処理

```typescript
export class SafeContainer extends Container {
  private initialized = false;

  async fetch(request: Request) {
    await this.ctx.blockConcurrencyWhile(async () => {
      if (!this.initialized) {
        await this.startAndWaitForPorts();
        this.initialized = true;
      }
    });
    return super.fetch(request);
  }
}
```

**用途:** 一度だけ行う初期化、起動処理の並行実行の防止。

## アクティビティタイムアウトの延長

```typescript
export class LongRunningContainer extends Container {
  sleepAfter = "5m";

  async processLongJob(data: unknown) {
    const interval = setInterval(() => {
      this.ctx.storage.put("keepalive", Date.now());
    }, 60000);

    try {
      await this.doLongWork(data);
    } finally {
      clearInterval(interval);
    }
  }
}
```

**用途:** `sleepAfter` を超える長時間の処理。

## 複数ポートのルーティング

```typescript
export class MultiPortContainer extends Container {
  requiredPorts = [8080, 8081, 9090];

  async fetch(request: Request) {
    const path = new URL(request.url).pathname;
    if (path.startsWith("/grpc")) this.switchPort(8081);
    else if (path.startsWith("/metrics")) this.switchPort(9090);
    return super.fetch(request);
  }
}
```

**用途:** 複数プロトコルのサービス（HTTP + gRPC）、メトリクス用の独立したエンドポイント。

## Workflow との統合

```typescript
import { WorkflowEntrypoint } from "cloudflare:workers";

export class ProcessingWorkflow extends WorkflowEntrypoint {
  async run(event, step) {
    const container = this.env.PROCESSOR.getByName(event.payload.jobId);
    
    await step.do("start", async () => {
      await container.startAndWaitForPorts();
    });
    
    const result = await step.do("process", async () => {
      return container.fetch("/process", {
        method: "POST",
        body: JSON.stringify(event.payload.data)
      }).then(r => r.json());
    });
    
    return result;
  }
}
```

**用途:** 複数ステップにわたるコンテナ処理のオーケストレーション、耐久性のある実行。

## Queue Consumer との統合

```typescript
export default {
  async queue(batch, env) {
    for (const msg of batch.messages) {
      try {
        const container = env.PROCESSOR.getByName(msg.body.jobId);
        await container.startAndWaitForPorts();
        
        const response = await container.fetch("/process", {
          method: "POST",
          body: JSON.stringify(msg.body)
        });
        
        response.ok ? msg.ack() : msg.retry();
      } catch (err) {
        console.error("Queue processing error:", err);
        msg.retry();
      }
    }
  }
};
```

**用途:** 非同期ジョブ処理、バッチ処理、イベント駆動型の実行。
