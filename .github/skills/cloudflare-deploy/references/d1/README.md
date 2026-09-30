# Cloudflare D1データベース

水平スケールアウト向けに設計されたサーバーレスSQLiteデータベース、Cloudflare D1に関する専門的なガイダンスです。

## 概要

D1はCloudflareが管理するサーバーレスデータベースで、次の機能を備えています。
- SQLiteのSQLセマンティクスと互換性
- Time Travelによる組み込みの災害復旧（30日間の時点指定復旧）
- 水平スケールアウトアーキテクチャ（データベースあたり10 GB）
- WorkerおよびHTTP APIからのアクセス
- クエリ料金とストレージ料金のみを基準とする料金体系

**アーキテクチャの考え方**: D1は、単一の大規模データベースよりも、ユーザー単位、テナント単位、またはエンティティ単位のデータベースパターンに最適化されています。

## クイックスタート

```bash
# Create database
wrangler d1 create <database-name>

# Execute migration
wrangler d1 migrations apply <db-name> --remote

# Local development
wrangler dev
```

## 基本的なクエリメソッド

```typescript
// .all() - Returns all rows; .first() - First row or null; .first(col) - Single column value
// .run() - INSERT/UPDATE/DELETE; .raw() - Array of arrays (efficient)
const { results, success, meta } = await env.DB.prepare('SELECT * FROM users WHERE active = ?').bind(true).all();
const user = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first();
```

## バッチ処理

```typescript
// Multiple queries in single round trip (atomic transaction)
const results = await env.DB.batch([
  env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(1),
  env.DB.prepare('SELECT * FROM posts WHERE author_id = ?').bind(1),
  env.DB.prepare('UPDATE users SET last_access = ? WHERE id = ?').bind(Date.now(), 1)
]);
```

## Sessions API（有料プラン）

```typescript
// Create long-running session for analytics/migrations (up to 15 minutes)
const session = env.DB.withSession();
try {
  await session.prepare('CREATE INDEX idx_heavy ON large_table(column)').run();
  await session.prepare('ANALYZE').run();
} finally {
  session.close(); // Always close to release resources
}
```

## 読み取りレプリケーション（有料プラン）

```typescript
// Read from nearest replica for lower latency (automatic failover)
const user = await env.DB_REPLICA.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first();

// Writes always go to primary
await env.DB.prepare('UPDATE users SET last_login = ? WHERE id = ?').bind(Date.now(), userId).run();
```

## プラットフォームの制限

| 制限 | 無料プラン | 有料プラン |
|-------|-----------|------------|
| データベースサイズ | 500 MB | データベースあたり10 GB |
| 行サイズ | 最大1 MB | 最大1 MB |
| クエリのタイムアウト | 30秒 | 30秒 |
| バッチサイズ | 1,000ステートメント | 10,000ステートメント |
| Time Travelの保持期間 | 7日 | 30日 |
| 読み取りレプリカ | 利用不可 | あり（有料アドオン）|

**料金**: 無料枠を超えるデータベースは1つあたり月額$5 + 読み取り1,000回あたり$0.001 + 書き込み100万回あたり$1 + ストレージ1 GBあたり月額$0.75

## CLIコマンド

```bash
# Database management
wrangler d1 create <db-name>
wrangler d1 list
wrangler d1 delete <db-name>

# Migrations
wrangler d1 migrations create <db-name> <migration-name>    # Create new migration file
wrangler d1 migrations apply <db-name> --remote             # Apply pending migrations
wrangler d1 migrations apply <db-name> --local              # Apply locally
wrangler d1 migrations list <db-name> --remote              # Show applied migrations

# Direct SQL execution
wrangler d1 execute <db-name> --remote --command="SELECT * FROM users"
wrangler d1 execute <db-name> --local --file=./schema.sql

# Backups & Import/Export
wrangler d1 export <db-name> --remote --output=./backup.sql  # Full export with schema
wrangler d1 export <db-name> --remote --no-schema --output=./data.sql  # Data only
wrangler d1 time-travel restore <db-name> --timestamp="2024-01-15T14:30:00Z"  # Point-in-time recovery

# Development
wrangler dev --persist-to=./.wrangler/state
```

## 推奨する読み進め方

**まずはこちら**: 上記のクイックスタート → configuration.md（セットアップ）→ api.md（クエリ）

**よくある作業**:
- 初回セットアップ: configuration.md → マイグレーションを実行
- クエリの追加: api.md → プリペアドステートメント
- ページネーション／キャッシュ: patterns.md
- 本番環境の最適化: 読み取りレプリケーション + Sessions API（このファイル）
- デバッグ: gotchas.md

## このリファレンスの内容

- [configuration.md](./configuration.md) - wrangler.jsoncのセットアップ、マイグレーション、TypeScript型、ORM、ローカル開発
- [api.md](./api.md) - クエリメソッド（.all/.first/.run/.raw）、バッチ処理、セッション、読み取りレプリカ、エラー処理
- [patterns.md](./patterns.md) - ページネーション、一括処理、キャッシュ、マルチテナント、セッション、分析
- [gotchas.md](./gotchas.md) - SQLインジェクション、プラン別の制限、パフォーマンス、よくあるエラー

## 関連項目

- [workers](../workers/) - Workerランタイムとfetchハンドラのパターン
- [hyperdrive](../hyperdrive/) - 外部データベースのコネクションプーリング
