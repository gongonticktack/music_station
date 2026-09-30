# Cloudflare Durable Objects ストレージ

SQLite と KV バックエンド、PITR、自動的な並行処理制御を備えた Durable Objects 向け永続ストレージ API。

## 概要

DO Storage が提供する機能:
- SQLite ベース（推奨）または KV ベース
- SQL API と同期／非同期 KV API
- 自動入力／出力ゲート（競合状態を防止）
- 30 日間のポイントインタイムリカバリ（PITR）
- トランザクションとアラーム

**ユースケース:** 状態を伴う調整、リアルタイム共同作業、カウンター、セッション、レート制限

**課金:** リクエスト数、GB-month 単位のストレージ、および SQL 操作の rowsRead／rowsWritten に基づいて課金

## クイックスタート

```typescript
export class Counter extends DurableObject {
  sql: SqlStorage;
  
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;
    this.sql.exec('CREATE TABLE IF NOT EXISTS data(key TEXT PRIMARY KEY, value INTEGER)');
  }
  
  async increment(): Promise<number> {
    const result = this.sql.exec(
      'INSERT INTO data VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = value + 1 RETURNING value',
      'counter', 1
    ).one();
    return result?.value || 1;
  }
}
```

## ストレージバックエンド

| バックエンド | 作成方法 | API | PITR |
|---------|---------------|------|------|
| SQLite（推奨） | `new_sqlite_classes` | SQL + 同期 KV + 非同期 KV | ✅ |
| KV（レガシー） | `new_classes` | 非同期 KV のみ | ❌ |

## 主な API

- **SQL API** (`ctx.storage.sql`): 拡張機能（FTS5、JSON、数学関数）を備えた完全な SQLite
- **同期 KV** (`ctx.storage.kv`): 同期キー・バリュー API（SQLite のみ）
- **非同期 KV** (`ctx.storage`): 非同期キー・バリュー API（両方のバックエンド）
- **トランザクション** (`transactionSync()`, `transaction()`)
- **PITR** (`getBookmarkForTime()`, `onNextSessionRestoreBookmark()`)
- **アラーム** (`setAlarm()`, `alarm()` ハンドラー)

## 読む順序

**DO ストレージを初めて使う場合:** configuration.md → api.md → patterns.md → gotchas.md  
**機能を構築する場合:** patterns.md → api.md → gotchas.md  
**問題をデバッグする場合:** gotchas.md → api.md  
**テストを書く場合:** testing.md

## このリファレンスの内容

- [configuration.md](./configuration.md) - wrangler.jsonc のマイグレーション、SQLite と KV の設定、RPC バインディング
- [api.md](./api.md) - SQL の exec／カーソル、KV メソッド、ストレージオプション、トランザクション、アラーム、PITR
- [patterns.md](./patterns.md) - スキーマのマイグレーション、キャッシュ、レート制限、バッチ処理、親子間の連携
- [gotchas.md](./gotchas.md) - 並行処理ゲート、INTEGER の精度、トランザクションの規則、SQL の制限
- [testing.md](./testing.md) - vitest-pool-workers のセットアップ、SQL／アラーム／PITR を使った DO のテスト

## 関連項目

- [durable-objects](../durable-objects/) - DO の基本と連携パターン
- [workers](../workers/) - DO スタブ向けの Worker ランタイム
- [d1](../d1/) - DO ごとのストレージに代わる共有データベース