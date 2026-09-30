## Container クラス API

```typescript
import { Container } from "@cloudflare/containers";

export class MyContainer extends Container {
  defaultPort = 8080;
  requiredPorts = [8080];
  sleepAfter = "30m";
  enableInternet = true;
  pingEndpoint = "/health";
  envVars = {};
  entrypoint = [];

  onStart() { /* container started */ }
  onStop() { /* container stopping */ }
  onError(error: Error) { /* container error */ }
  onActivityExpired(): boolean { /* timeout, return true to stay alive */ }
  async alarm() { /* scheduled task */ }
}
```

## ルーティング

**getByName(id)** - セッションアフィニティやユーザーごとの状態管理向けの名前付きインスタンス
**getRandom()** - ステートレスサービスの負荷分散向けのランダムなインスタンス

```typescript
const container = env.MY_CONTAINER.getByName("user-123");
const container = env.MY_CONTAINER.getRandom();
```

## 起動メソッド

### start() - 基本的な起動（タイムアウト 8 秒）

```typescript
await container.start();
await container.start({ envVars: { KEY: "value" } });
```

**プロセスの起動時**に返ります。ポートの準備完了を待ちません。完了を待たずに処理を開始する場合に使用します。

### startAndWaitForPorts() - 推奨（タイムアウト 20 秒）

```typescript
await container.startAndWaitForPorts();  // Uses requiredPorts
await container.startAndWaitForPorts({ ports: [8080, 9090] });
await container.startAndWaitForPorts({ 
  ports: [8080],
  startOptions: { envVars: { KEY: "value" } }
});
```

**ポートがリッスン状態になった時点**で返ります。HTTP/TCP リクエストを送る前に使用します。

**ポートの決定順序:** 明示的に指定したポート → requiredPorts → defaultPort → port 33

### waitForPort() - 指定したポートを待機

```typescript
await container.waitForPort(8080);
await container.waitForPort(8080, { timeout: 30000 });
```

## 通信

### fetch() - WebSocket 対応の HTTP

```typescript
// ✅ Supports WebSocket upgrades
const response = await container.fetch(request);
const response = await container.fetch("http://container/api", {
  method: "POST",
  body: JSON.stringify({ data: "value" })
});
```

**用途:** すべての HTTP 通信。特に WebSocket 通信。

### containerFetch() - HTTP のみ（WebSocket 非対応）

```typescript
// ❌ No WebSocket support
const response = await container.containerFetch(request);
```

**⚠️ 重要:** WebSocket には `fetch()` ではなく `containerFetch()` を使用してください。

### TCP 接続

```typescript
const port = this.ctx.container.getTcpPort(8080);
const conn = port.connect();
await conn.opened;

if (request.body) await request.body.pipeTo(conn.writable);
return new Response(conn.readable);
```

### switchPort() - デフォルトポートを変更

```typescript
this.switchPort(8081);  // Subsequent fetch() uses this port
```

## ライフサイクルフック

### onStart()

コンテナのプロセスが起動したときに呼び出されます（ポートの準備はまだできていない場合があります）。`blockConcurrencyWhile` 内で実行されるため、リクエストは並行処理されません。

```typescript
onStart() {
  console.log("Container starting");
}
```

### onStop()

SIGTERM を受信したときに呼び出されます。SIGKILL まで 15 分あります。正常なシャットダウンに使用します。

```typescript
onStop() {
  // Save state, close connections, flush logs
}
```

### onError()

コンテナがクラッシュしたとき、または起動に失敗したときに呼び出されます。

```typescript
onError(error: Error) {
  console.error("Container error:", error);
}
```

### onActivityExpired()

`sleepAfter` のタイムアウトに達したときに呼び出されます。稼働を続ける場合は `true`、停止する場合は `false` を返します。

```typescript
onActivityExpired(): boolean {
  if (this.hasActiveConnections()) return true;  // Keep alive
  return false;  // OK to stop
}
```

## スケジュール設定

```typescript
export class ScheduledContainer extends Container {
  async fetch(request: Request) {
    await this.schedule(Date.now() + 60000);  // 1 minute
    await this.schedule("2026-01-28T00:00:00Z");  // ISO string
    return new Response("Scheduled");
  }

  async alarm() {
    // Called when schedule fires (SQLite-backed, survives restarts)
  }
}
```

**⚠️ `alarm()` ヘルパーを使用する場合、`schedule()` を直接オーバーライドしないでください。**

## 状態の確認

### 外部からの状態確認

```typescript
const state = await container.getState();
// state.status: "starting" | "running" | "stopping" | "stopped"
```

### 内部での状態確認

```typescript
export class MyContainer extends Container {
  async fetch(request: Request) {
    if (this.ctx.container.running) { ... }
  }
}
```

**⚠️ 外部から確認する場合は `getState()`、内部から確認する場合は `ctx.container.running` を使用してください。**
