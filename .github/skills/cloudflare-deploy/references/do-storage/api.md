# DO Storage API リファレンス

## SQL API

```typescript
const cursor = this.sql.exec('SELECT * FROM users WHERE email = ?', email);
for (let row of cursor) {} // Objects: { id, name, email }
cursor.toArray(); cursor.one(); // Single row (throws if != 1)
for (let row of cursor.raw()) {} // Arrays: [1, "Alice", "..."]

// Manual iteration
const iter = cursor[Symbol.iterator]();
const first = iter.next(); // { value: {...}, done: false }

cursor.columnNames; // ["id", "name", "email"]
cursor.rowsRead; cursor.rowsWritten; // Billing

type User = { id: number; name: string; email: string };
const user = this.sql.exec<User>('...', userId).one();
```

## 同期 KV API（SQLite のみ）

```typescript
this.ctx.storage.kv.get("counter"); // undefined if missing
this.ctx.storage.kv.put("counter", 42);
this.ctx.storage.kv.put("user", { name: "Alice", age: 30 });
this.ctx.storage.kv.delete("counter"); // true if existed

for (let [key, value] of this.ctx.storage.kv.list()) {}

// List options: start, prefix, reverse, limit
this.ctx.storage.kv.list({ start: "user:", prefix: "user:", reverse: true, limit: 100 });
```

## 非同期 KV API（両バックエンド）

```typescript
await this.ctx.storage.get("key"); // Single
await this.ctx.storage.get(["key1", "key2"]); // Multiple (max 128)
await this.ctx.storage.put("key", value); // Single
await this.ctx.storage.put({ "key1": "v1", "key2": { nested: true } }); // Multiple (max 128)
await this.ctx.storage.delete("key");
await this.ctx.storage.delete(["key1", "key2"]);
await this.ctx.storage.list({ prefix: "user:", limit: 100 });

// Options: allowConcurrency, noCache, allowUnconfirmed
await this.ctx.storage.get("key", { allowConcurrency: true, noCache: true });
await this.ctx.storage.put("key", value, { allowUnconfirmed: true, noCache: true });
```

### ストレージオプション

| オプション | メソッド | 効果 | 用途 |
|--------|---------|--------|----------|
| `allowConcurrency` | get, list | 入力ゲートをスキップし、読み取り中の同時リクエストを許可 | 厳密な一貫性が不要な、読み取り中心のメトリクス |
| `noCache` | get, put, list | インメモリーキャッシュをスキップし、常にディスクから読み取る | アクセス頻度の低いデータ、またはストレージを直接テストする場合 |
| `allowUnconfirmed` | put, delete | 書き込みの確認前に返す（出力ゲートによる保護は維持） | 確認よりレイテンシーを重視する、重要度の低い書き込み |

## トランザクション

```typescript
// Sync (SQL/sync KV only)
this.ctx.storage.transactionSync(() => {
  this.sql.exec('UPDATE accounts SET balance = balance - ? WHERE id = ?', 100, 1);
  this.sql.exec('UPDATE accounts SET balance = balance + ? WHERE id = ?', 100, 2);
  return "result";
});

// Async
await this.ctx.storage.transaction(async () => {
  const value = await this.ctx.storage.get("counter");
  await this.ctx.storage.put("counter", value + 1);
  if (value > 100) this.ctx.storage.rollback(); // Explicit rollback
});
```

## ポイントインタイムリカバリー

```typescript
await this.ctx.storage.getCurrentBookmark();
await this.ctx.storage.getBookmarkForTime(Date.now() - 2 * 24 * 60 * 60 * 1000);
await this.ctx.storage.onNextSessionRestoreBookmark(bookmark);
this.ctx.abort(); // Restart to apply; bookmarks lexically comparable (earlier < later)
```

## アラーム

```typescript
await this.ctx.storage.setAlarm(Date.now() + 60000); // Timestamp or Date
await this.ctx.storage.getAlarm();
await this.ctx.storage.deleteAlarm();

async alarm() { await this.doScheduledWork(); }
```

## その他

```typescript
await this.ctx.storage.deleteAll(); // Atomic for SQLite; alarm NOT included
this.ctx.storage.sql.databaseSize; // Bytes
```
