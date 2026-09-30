# D1 API リファレンス

## Prepared Statements（セキュリティ上必須）

```typescript
// ❌ NEVER: Direct string interpolation (SQL injection risk)
const result = await env.DB.prepare(`SELECT * FROM users WHERE id = ${userId}`).all();

// ✅ CORRECT: Prepared statements with bind()
const result = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId).all();

// Multiple parameters
const result = await env.DB.prepare('SELECT * FROM users WHERE email = ? AND active = ?').bind(email, true).all();
```

## クエリ実行メソッド

```typescript
// .all() - Returns all rows
const { results, success, meta } = await env.DB.prepare('SELECT * FROM users WHERE active = ?').bind(true).all();
// results: Array of row objects; success: boolean
// meta: { duration: number, rows_read: number, rows_written: number }

// .first() - Returns first row or null
const user = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first();

// .first(columnName) - Returns single column value
const email = await env.DB.prepare('SELECT email FROM users WHERE id = ?').bind(userId).first('email');
// Returns string | number | null

// .run() - For INSERT/UPDATE/DELETE (no row data returned)
const result = await env.DB.prepare('UPDATE users SET last_login = ? WHERE id = ?').bind(Date.now(), userId).run();
// result.meta: { duration, rows_read, rows_written, last_row_id, changes }

// .raw() - Returns array of arrays (efficient for large datasets)
const rawResults = await env.DB.prepare('SELECT id, name FROM users').raw();
// [[1, 'Alice'], [2, 'Bob']]
```

## 一括操作

```typescript
// Execute multiple queries in single round trip (atomic transaction)
const results = await env.DB.batch([
  env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(1),
  env.DB.prepare('SELECT * FROM posts WHERE author_id = ?').bind(1),
  env.DB.prepare('UPDATE users SET last_access = ? WHERE id = ?').bind(Date.now(), 1)
]);
// results is array: [result1, result2, result3]

// Batch with same prepared statement, different params
const userIds = [1, 2, 3];
const stmt = env.DB.prepare('SELECT * FROM users WHERE id = ?');
const results = await env.DB.batch(userIds.map(id => stmt.bind(id)));
```

## トランザクション（batch 経由）

```typescript
// D1 executes batch() as atomic transaction - all succeed or all fail
const results = await env.DB.batch([
  env.DB.prepare('INSERT INTO accounts (id, balance) VALUES (?, ?)').bind(1, 100),
  env.DB.prepare('INSERT INTO accounts (id, balance) VALUES (?, ?)').bind(2, 200),
  env.DB.prepare('UPDATE accounts SET balance = balance - ? WHERE id = ?').bind(50, 1),
  env.DB.prepare('UPDATE accounts SET balance = balance + ? WHERE id = ?').bind(50, 2)
]);
```

## Sessions API（有料プラン）

30秒のタイムアウトを超える操作向けの長時間セッション（最大15分）。

```typescript
const session = env.DB.withSession({ timeout: 600 }); // 10 min (1-900s)
try {
  await session.prepare('CREATE INDEX idx_large ON big_table(column)').run();
  await session.prepare('ANALYZE').run();
} finally {
  session.close(); // CRITICAL: always close to prevent leaks
}
```

**用途**: マイグレーション、ANALYZE、大規模なインデックス作成、一括変換

## 読み取りレプリケーション（有料プラン）

低レイテンシーを実現するため、クエリを最寄りのレプリカにルーティングする。書き込みは常にプライマリに送られる。

```typescript
interface Env {
  DB: D1Database;          // Primary (writes)
  DB_REPLICA: D1Database;  // Replica (reads)
}

// Reads: use replica
const user = await env.DB_REPLICA.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first();

// Writes: use primary
await env.DB.prepare('UPDATE users SET last_login = ? WHERE id = ?').bind(Date.now(), userId).run();

// Read-after-write: use primary for consistency (replication lag <100ms-2s)
await env.DB.prepare('INSERT INTO posts (title) VALUES (?)').bind(title).run();
const post = await env.DB.prepare('SELECT * FROM posts WHERE title = ?').bind(title).first(); // Primary
```

## エラー処理

```typescript
async function getUser(userId: number, env: Env): Promise<Response> {
  try {
    const result = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId).all();
    if (!result.success) return new Response('Database error', { status: 500 });
    if (result.results.length === 0) return new Response('User not found', { status: 404 });
    return Response.json(result.results[0]);
  } catch (error) {
    return new Response('Internal error', { status: 500 });
  }
}

// Constraint violations
try {
  await env.DB.prepare('INSERT INTO users (email, name) VALUES (?, ?)').bind(email, name).run();
} catch (error) {
  if (error.message?.includes('UNIQUE constraint failed')) return new Response('Email exists', { status: 409 });
  throw error;
}
```

## REST API（HTTP）アクセス

Cloudflare API を使用して、外部サービス（Worker 以外のコンテキスト）から D1 にアクセスする。

```typescript
// Single query
const response = await fetch(
  `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/d1/database/${DATABASE_ID}/query`,
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${CLOUDFLARE_API_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      sql: 'SELECT * FROM users WHERE id = ?',
      params: [userId]
    })
  }
);

const { result, success, errors } = await response.json();
// result: [{ results: [...], success: true, meta: {...} }]

// Batch queries via HTTP
const response = await fetch(
  `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/d1/database/${DATABASE_ID}/query`,
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${CLOUDFLARE_API_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify([
      { sql: 'SELECT * FROM users WHERE id = ?', params: [1] },
      { sql: 'SELECT * FROM posts WHERE author_id = ?', params: [1] }
    ])
  }
);
```

**用途**: サーバーサイドスクリプト、CI/CD マイグレーション、管理ツール、Worker 以外との連携

## テストとデバッグ

```typescript
// Vitest with unstable_dev
import { unstable_dev } from 'wrangler';
describe('D1', () => {
  let worker: Awaited<ReturnType<typeof unstable_dev>>;
  beforeAll(async () => { worker = await unstable_dev('src/index.ts'); });
  afterAll(async () => { await worker.stop(); });
  it('queries users', async () => { expect((await worker.fetch('/users')).status).toBe(200); });
});

// Debug query performance
const result = await env.DB.prepare('SELECT * FROM users').all();
console.log('Duration:', result.meta.duration, 'ms');

// Query plan analysis
const plan = await env.DB.prepare('EXPLAIN QUERY PLAN SELECT * FROM users WHERE email = ?').bind(email).all();
```

```bash
# Inspect local database
sqlite3 .wrangler/state/v3/d1/<database-id>.sqlite
.tables; .schema users; PRAGMA table_info(users);
```
