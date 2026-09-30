# API リファレンス

概要は [README.md](./README.md)、セットアップは [configuration.md](./configuration.md) を参照してください。

## バインディングインターフェース

```typescript
interface Hyperdrive {
  connectionString: string;  // PostgreSQL
  // MySQL properties:
  host: string;
  port: number;
  user: string;
  password: string;
  database: string;
}

interface Env {
  HYPERDRIVE: Hyperdrive;
}
```

**型を生成する:** `npx wrangler types`（wrangler.jsonc から worker-configuration.d.ts を自動生成）

## PostgreSQL（node-postgres）- 推奨

```typescript
import { Client } from "pg";  // pg@^8.17.2

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const client = new Client({connectionString: env.HYPERDRIVE.connectionString});
    try {
      await client.connect();
      const result = await client.query("SELECT * FROM users WHERE id = $1", [123]);
      return Response.json(result.rows);
    } finally {
      await client.end();
    }
  },
};
```

**⚠️ Workers の接続数上限: Worker の呼び出し 1 回につき 6 接続** - 接続プールを適切に使ってください。

## PostgreSQL（postgres.js）

```typescript
import postgres from "postgres";  // postgres@^3.4.8

const sql = postgres(env.HYPERDRIVE.connectionString, {
  max: 5,             // Limit per Worker (Workers max: 6)
  prepare: true,      // Enabled by default, required for caching
  fetch_types: false, // Reduce latency if not using arrays
});

const users = await sql`SELECT * FROM users WHERE active = ${true} LIMIT 10`;
```

**⚠️ `prepare: true` はデフォルトで有効で、Hyperdrive のキャッシュに必須です。** `false` に設定すると、プリペアドステートメントとキャッシュが無効になります。

## MySQL（mysql2）

```typescript
import { createConnection } from "mysql2/promise";  // mysql2@^3.16.2

const conn = await createConnection({
  host: env.HYPERDRIVE.host,
  user: env.HYPERDRIVE.user,
  password: env.HYPERDRIVE.password,
  database: env.HYPERDRIVE.database,
  port: env.HYPERDRIVE.port,
  disableEval: true,  // ⚠️ REQUIRED for Workers
});

const [results] = await conn.query("SELECT * FROM users WHERE active = ? LIMIT ?", [true, 10]);
ctx.waitUntil(conn.end());
```

**⚠️ MySQL のサポートは PostgreSQL ほど成熟していません**。最適化が少なく、特殊なケースで問題が起きる可能性があります。

## クエリキャッシュ

**キャッシュ可能:**
```sql
SELECT * FROM posts WHERE published = true;
SELECT COUNT(*) FROM users;
```

**キャッシュ不可:**
```sql
-- Writes
INSERT/UPDATE/DELETE

-- Volatile functions
SELECT NOW();
SELECT random();
SELECT LASTVAL();  -- PostgreSQL
SELECT UUID();     -- MySQL
```

**キャッシュ設定:**
- デフォルト: `max_age=60s`, `swr=15s`
- `max_age` の最大値: 3600s
- 無効化: `--caching-disabled=true`

**複数設定のパターン:**
```typescript
// Reads: cached
const sqlCached = postgres(env.HYPERDRIVE_CACHED.connectionString);
const posts = await sqlCached`SELECT * FROM posts ORDER BY views DESC LIMIT 10`;

// Writes/time-sensitive: no cache
const sqlNoCache = postgres(env.HYPERDRIVE_NO_CACHE.connectionString);
const orders = await sqlNoCache`SELECT * FROM orders WHERE created_at > NOW() - INTERVAL 5 MINUTE`;
```

## ORM

**Drizzle:**
```typescript
import { drizzle } from "drizzle-orm/postgres-js";  // drizzle-orm@^0.45.1
import postgres from "postgres";

const client = postgres(env.HYPERDRIVE.connectionString, {max: 5, prepare: true});
const db = drizzle(client);
const users = await db.select().from(users).where(eq(users.active, true)).limit(10);
```

**Kysely:**
```typescript
import { Kysely, PostgresDialect } from "kysely";  // kysely@^0.27+
import postgres from "postgres";

const db = new Kysely({
  dialect: new PostgresDialect({
    postgres: postgres(env.HYPERDRIVE.connectionString, {max: 5, prepare: true}),
  }),
});
const users = await db.selectFrom("users").selectAll().where("active", "=", true).execute();
```

ユースケースは [patterns.md](./patterns.md)、制限は [gotchas.md](./gotchas.md) を参照してください。
