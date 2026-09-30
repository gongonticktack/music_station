# Durable Objectsのパターン

## パターンの選び方

| 必要なもの | パターン | ID戦略 |
|------|---------|-------------|
| ユーザー/IPごとのレート制限 | レート制限 | `idFromName(identifier)` |
| 相互排他 | 分散ロック | `idFromName(resource)` |
| 1K req/sを超えるスループット | シャーディング | `newUniqueId()` またはハッシュ |
| リアルタイム更新 | WebSocket共同編集 | `idFromName(room)` |
| ユーザーセッション | セッション管理 | `idFromName(sessionId)` |
| バックグラウンドのクリーンアップ | アラームベース | 任意 |

## RPCとfetch()

**RPC**（compat ≥2024-04-03）：型安全でシンプル。新規プロジェクトでは標準の選択肢です  
**fetch()**：旧式の互換性、HTTPセマンティクス、プロキシ処理

```typescript
const count = await stub.increment();  // RPC
const count = await (await stub.fetch(req)).json();  // fetch()
```

## シャーディング（高スループット）

単一のDOの最大処理性能は約1K req/sです。より高いスループットが必要な場合はシャードに分割します。

```typescript
export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const userId = new URL(req.url).searchParams.get("user");
    const hash = hashCode(userId) % 100;  // 100 shards
    const id = env.COUNTER.idFromName(`shard:${hash}`);
    return env.COUNTER.get(id).fetch(req);
  }
};

function hashCode(str: string): number {
  let hash = 0;
  for (let i = 0; i < str.length; i++) hash = ((hash << 5) - hash) + str.charCodeAt(i);
  return Math.abs(hash);
}
```

**設計上の判断:**
- **シャード数**：通常は10～1000（まず100から始め、計測して調整）
- **シャードキー**：ユーザーID、IP、セッション。均等に分散する必要があります（ハッシュを使用）
- **集約**：Coordinator DOまたは外部システム（D1、R2）

## レート制限

```typescript
async checkLimit(key: string, limit: number, windowMs: number): Promise<boolean> {
  const req = this.ctx.storage.sql.exec("SELECT COUNT(*) as count FROM requests WHERE key = ? AND timestamp > ?", key, Date.now() - windowMs).one();
  if (req.count >= limit) return false;
  this.ctx.storage.sql.exec("INSERT INTO requests (key, timestamp) VALUES (?, ?)", key, Date.now());
  return true;
}
```

## 分散ロック

```typescript
private held = false;
async acquire(timeoutMs = 5000): Promise<boolean> {
  if (this.held) return false;
  this.held = true;
  await this.ctx.storage.setAlarm(Date.now() + timeoutMs);
  return true;
}
async release() { this.held = false; await this.ctx.storage.deleteAlarm(); }
async alarm() { this.held = false; }  // Auto-release on timeout
```

## ハイバネーション対応パターン

ハイバネーション後も状態を保持します。

```typescript
async fetch(req: Request): Promise<Response> {
  const [client, server] = Object.values(new WebSocketPair());
  const userId = new URL(req.url).searchParams.get("user");
  server.serializeAttachment({ userId });  // Survives hibernation
  this.ctx.acceptWebSocket(server, ["room:lobby"]);
  server.send(JSON.stringify({ type: "init", state: this.ctx.storage.kv.get("state") }));
  return new Response(null, { status: 101, webSocket: client });
}

async webSocketMessage(ws: WebSocket, msg: string) {
  const { userId } = ws.deserializeAttachment();  // Retrieve after wake
  const state = this.ctx.storage.kv.get("state") || {};
  state[userId] = JSON.parse(msg);
  this.ctx.storage.kv.put("state", state);
  for (const c of this.ctx.getWebSockets("room:lobby")) c.send(msg);
}
```

## リアルタイム共同編集

接続中のすべてのクライアントに更新をブロードキャストします。

```typescript
async webSocketMessage(ws: WebSocket, msg: string) {
  const data = JSON.parse(msg);
  this.ctx.storage.kv.put("doc", data.content);  // Persist
  for (const c of this.ctx.getWebSockets()) if (c !== ws) c.send(msg);  // Broadcast
}
```

### WebSocketの再接続

**クライアント側**（指数バックオフ）：
```typescript
class ResilientWS {
  private delay = 1000;
  connect(url: string) {
    const ws = new WebSocket(url);
    ws.onclose = () => setTimeout(() => {
      this.connect(url);
      this.delay = Math.min(this.delay * 2, 30000);
    }, this.delay);
  }
}
```

**サーバー側**（切断時にクリーンアップ）：
```typescript
async webSocketClose(ws: WebSocket, code: number, reason: string, wasClean: boolean) {
  const { userId } = ws.deserializeAttachment();
  this.ctx.storage.sql.exec("UPDATE users SET online = false WHERE id = ?", userId);
  for (const c of this.ctx.getWebSockets()) c.send(JSON.stringify({ type: "user_left", userId }));
}
```

## セッション管理

```typescript
async createSession(userId: string, data: object): Promise<string> {
  const id = crypto.randomUUID(), exp = Date.now() + 86400000;
  this.ctx.storage.sql.exec("INSERT INTO sessions VALUES (?, ?, ?, ?)", id, userId, JSON.stringify(data), exp);
  await this.ctx.storage.setAlarm(exp);
  return id;
}

async getSession(id: string): Promise<object | null> {
  const row = this.ctx.storage.sql.exec("SELECT data FROM sessions WHERE id = ? AND expires_at > ?", id, Date.now()).one();
  return row ? JSON.parse(row.data) : null;
}

async alarm() { this.ctx.storage.sql.exec("DELETE FROM sessions WHERE expires_at <= ?", Date.now()); }
```

## 複数イベント（単一アラーム）

複数のイベントをスケジュールするキューパターンです。

```typescript
async scheduleEvent(id: string, runAt: number) {
  await this.ctx.storage.put(`event:${id}`, { id, runAt });
  const curr = await this.ctx.storage.getAlarm();
  if (!curr || runAt < curr) await this.ctx.storage.setAlarm(runAt);
}

async alarm() {
  const events = await this.ctx.storage.list({ prefix: "event:" }), now = Date.now();
  let next = null;
  for (const [key, ev] of events) {
    if (ev.runAt <= now) {
      await this.processEvent(ev);
      await this.ctx.storage.delete(key);
    } else if (!next || ev.runAt < next) next = ev.runAt;
  }
  if (next) await this.ctx.storage.setAlarm(next);
}
```

## 安全なクリーンアップ

`ctx.waitUntil()`を使うと、レスポンスを返した後も処理を完了できます。

```typescript
async myMethod() {
  const response = { success: true };
  this.ctx.waitUntil(this.ctx.storage.sql.exec("DELETE FROM old_data WHERE timestamp < ?", cutoff));
  return response;
}
```

## ベストプラクティス

- **設計**：調整には`idFromName()`、シャーディングには`newUniqueId()`を使い、コンストラクターの処理を最小限にする
- **ストレージ**：SQLiteを優先し、トランザクションでまとめて処理し、クリーンアップ用にアラームを設定し、リスクの高い操作の前にPITRを使う
- **パフォーマンス**：DOあたり最大約1K req/s。さらに必要ならシャーディングし、メモリにキャッシュし、後回しにする処理にはアラームを使う
- **信頼性**：503には再試行とバックオフで対処し、コールドスタートを想定して設計し、`--dry-run`でマイグレーションをテストする
- **セキュリティ**：Workersで入力を検証し、DOの作成をレート制限し、コンプライアンス対応にはjurisdictionを使う

## 関連項目

- **[API](./api.md)** - ctxメソッド、WebSocketハンドラー
- **[Gotchas](./gotchas.md)** - ハイバネーション時の注意点、よくあるエラー
- **[DO Storage](../do-storage/README.md)** - ストレージパターンとトランザクション
