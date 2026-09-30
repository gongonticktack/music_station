# Durable Objects API

## クラス構造

```typescript
import { DurableObject } from "cloudflare:workers";

export class MyDO extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    // Runs on EVERY wake - keep light!
  }
  
  // RPC methods (called directly from worker)
  async myMethod(arg: string): Promise<string> { return arg; }
  
  // fetch handler (legacy/HTTP semantics)
  async fetch(req: Request): Promise<Response> { /* ... */ }
  
  // Lifecycle handlers
  async alarm() { /* alarm fired */ }
  async webSocketMessage(ws: WebSocket, msg: string | ArrayBuffer) { /* ... */ }
  async webSocketClose(ws: WebSocket, code: number, reason: string, wasClean: boolean) { /* ... */ }
  async webSocketError(ws: WebSocket, error: unknown) { /* ... */ }
}
```

## DurableObjectState コンテキストメソッド

### 並行処理の制御

```typescript
// Complete work after response sent (e.g., cleanup, logging)
this.ctx.waitUntil(promise: Promise<any>): void

// Critical section - blocks all other requests until complete
await this.ctx.blockConcurrencyWhile(async () => {
  // No other requests processed during this block
  // Use for initialization or critical operations
})
```

**使用する場面:**
- `waitUntil()`: レスポンス後のバックグラウンドクリーンアップ、ログ記録、重要でない処理
- `blockConcurrencyWhile()`: 初回初期化、スキーマ移行、重要な状態のセットアップ

### ライフサイクル

```typescript
this.ctx.id              // DurableObjectId of this instance
this.ctx.abort()         // Force eviction (use after PITR restore to reload state)
```

### ストレージへのアクセス

```typescript
this.ctx.storage.sql     // SQLite API (recommended)
this.ctx.storage.kv      // Sync KV API (SQLite DOs only)
this.ctx.storage         // Async KV API (legacy/KV-only DOs)
```

ストレージ API の全リファレンスについては **[DO Storage](../do-storage/README.md)** を参照してください。

### WebSocket の管理

```typescript
this.ctx.acceptWebSocket(ws: WebSocket, tags?: string[])  // Enable hibernation
this.ctx.getWebSockets(tag?: string): WebSocket[]         // Get by tag or all
this.ctx.getTags(ws: WebSocket): string[]                 // Get tags for connection
```

### アラーム

```typescript
await this.ctx.storage.setAlarm(timestamp: number | Date)  // Schedule (overwrites existing)
await this.ctx.storage.getAlarm(): number | null           // Get next alarm time
await this.ctx.storage.deleteAlarm(): void                 // Cancel alarm
```

**制限:** DO ごとにアラームは 1 つです。複数のイベントにはキューパターンを使用してください（[Patterns](./patterns.md) を参照）。

## ストレージ API

SQLite クエリ、KV 操作、トランザクション、Point-in-Time Recovery を含む詳細なストレージドキュメントについては、**[DO Storage](../do-storage/README.md)** を参照してください。

クイックリファレンス:

```typescript
// SQLite (recommended)
this.ctx.storage.sql.exec("SELECT * FROM users WHERE id = ?", userId).one()

// Sync KV (SQLite DOs only)
this.ctx.storage.kv.get("key")

// Async KV (legacy)
await this.ctx.storage.get("key")
```

## アラーム

退去後も維持される将来の処理をスケジュールします:

```typescript
// Set alarm (overwrites any existing alarm)
await this.ctx.storage.setAlarm(Date.now() + 3600000)  // 1 hour from now
await this.ctx.storage.setAlarm(new Date("2026-02-01"))  // Absolute time

// Check next alarm
const nextRun = await this.ctx.storage.getAlarm()  // null if none

// Cancel alarm
await this.ctx.storage.deleteAlarm()

// Handler called when alarm fires
async alarm() {
  // Runs once alarm triggers
  // DO wakes from hibernation if needed
  // Use for cleanup, notifications, scheduled tasks
}
```

**制限事項:**
- DO ごとにアラームは最大 1 つ
- 設定すると以前のアラームを上書き
- 複数のスケジュール済みイベントにはキューパターンを使用（[Patterns](./patterns.md) を参照）

**信頼性:**
- アラームは DO の退去や再起動後も維持される
- Cloudflare は失敗したアラームを自動的に再試行する
- 厳密に 1 回だけ実行される保証はない（冪等に処理する）

## WebSocket のハイバネーション

ハイバネーションを使うと、WebSocket 接続を開いたままの DO は、メッセージが届くまで計算資源とメモリを消費しません。

```typescript
async fetch(req: Request): Promise<Response> {
  const [client, server] = Object.values(new WebSocketPair());
  this.ctx.acceptWebSocket(server, ["room:123"]);  // Tags for filtering
  server.serializeAttachment({ userId: "abc" });    // Persisted metadata
  return new Response(null, { status: 101, webSocket: client });
}

// Called when message arrives (DO wakes from hibernation)
async webSocketMessage(ws: WebSocket, msg: string | ArrayBuffer) {
  const data = ws.deserializeAttachment();          // Retrieve metadata
  for (const c of this.ctx.getWebSockets("room:123")) c.send(msg);
}

// Called on close (optional handler)
async webSocketClose(ws: WebSocket, code: number, reason: string, wasClean: boolean) {
  // Cleanup logic, remove from lists, etc.
}

// Called on error (optional handler)
async webSocketError(ws: WebSocket, error: unknown) {
  console.error("WebSocket error:", error);
  // Handle error, close connection, etc.
}
```

**主な概念:**
- **自動ハイバネーション:** アクティブなリクエストやアラームがないとき、DO はハイバネーションに入る
- **コストゼロ:** ハイバネーション中の DO は、接続を維持したまま料金が発生しない
- **メモリのクリア:** ハイバネーション時にメモリ上の状態はすべて失われる
- **Attachment の永続化:** ハイバネーション後も維持する接続ごとのメタデータには `serializeAttachment()` を使用
- **フィルタリング用タグ:** 接続をルーム、チャンネル、ユーザーごとにグループ化して対象を絞ったブロードキャストを実行

**ハンドラーのライフサイクル:**
- `webSocketMessage`: DO が復帰してメッセージを処理し、その後ハイバネーションに入る場合がある
- `webSocketClose`: クライアントが閉じたときに呼び出される（任意。クリーンアップ用に実装）
- `webSocketError`: 接続エラー時に呼び出される（任意。エラー処理用に実装）

**メタデータの永続化:**
```typescript
// Store connection metadata (survives hibernation)
ws.serializeAttachment({ userId: "abc", room: "lobby" })

// Retrieve after hibernation
const { userId, room } = ws.deserializeAttachment()
```

## 関連項目

- **[DO Storage](../do-storage/README.md)** - ストレージ API の完全なリファレンス
- **[Patterns](./patterns.md)** - 実際の使用パターン
- **[Gotchas](./gotchas.md)** - ハイバネーションの注意点と制限