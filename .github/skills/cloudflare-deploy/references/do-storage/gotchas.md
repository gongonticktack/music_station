# DO ストレージの注意点とトラブルシューティング

## 並行性モデル（重要）

Durable Objects は、競合状態を防ぐために**入力ゲートと出力ゲート**を使用します。

### 入力ゲート
現在のリクエストによるストレージ読み取り中、新しいリクエストをブロックします。

```typescript
// SAFE: Input gate active during await
async increment() {
  const val = await this.ctx.storage.get("counter"); // Input gate blocks other requests
  await this.ctx.storage.put("counter", val + 1);
  return val;
}
```

### 出力ゲート
現在のリクエストによるすべての書き込みが確定するまで、レスポンスを保留します。

```typescript
// SAFE: Output gate waits for put() to confirm before returning response
async increment() {
  const val = await this.ctx.storage.get("counter");
  this.ctx.storage.put("counter", val + 1); // No await
  return new Response(String(val)); // Response delayed until write confirms
}
```

### 書き込みの集約
同じキーへの複数の書き込みはアトミックに処理されます（最後の書き込みが有効）：

```typescript
// SAFE: All three writes coalesce atomically
this.ctx.storage.put("key", 1);
this.ctx.storage.put("key", 2);
this.ctx.storage.put("key", 3); // Final value: 3
```

### ゲートの破断（危険）

**fetch() は入力ゲートと出力ゲートを破断します** → リクエストの割り込みが可能になります。

```typescript
// UNSAFE: fetch() allows another request to interleave
async unsafe() {
  const val = await this.ctx.storage.get("counter");
  await fetch("https://api.example.com"); // Gate broken!
  await this.ctx.storage.put("counter", val + 1); // Race condition possible
}
```

**解決策:** `blockConcurrencyWhile()` または `transaction()` を使用します。

```typescript
// SAFE: Block concurrent requests explicitly
async safe() {
  return await this.ctx.blockConcurrencyWhile(async () => {
    const val = await this.ctx.storage.get("counter");
    await fetch("https://api.example.com");
    await this.ctx.storage.put("counter", val + 1);
    return val;
  });
}
```

### allowConcurrency オプション

保護が不要な読み取りでは、入力ゲートを無効にできます。

```typescript
// Allow concurrent reads (no consistency guarantee)
const val = await this.ctx.storage.get("metrics", { allowConcurrency: true });
```

## よくあるエラー

### 「並行呼び出しでの競合状態」

**原因:** 同じイベント内から開始された複数の並行ストレージ操作（例: `Promise.all()`）は入力ゲートで保護されません。  
**解決策:** 1つのイベント内での並行ストレージ操作を避けてください。入力ゲートが直列化するのは異なるイベントからのリクエストだけで、同じイベント内の操作は対象外です。

### 「直接の SQL トランザクション文」

**原因:** トランザクションメソッドを使わず、`BEGIN TRANSACTION` を直接使用している。  
**解決策:** 同期操作には `this.ctx.storage.transactionSync()` を、非同期操作には `this.ctx.storage.transaction()` を使用してください。

### 「transactionSync 内の非同期処理」

**原因:** `transactionSync()` のコールバック内で非同期操作を使用している。  
**解決策:** 非同期操作が必要な場合は、`transaction()` ではなく非同期の `transactionSync()` メソッドを使用してください。

### 「実行時の TypeScript 型不一致」

**原因:** クエリが TypeScript の型で指定されたすべてのフィールドを返していない。  
**解決策:** SQL クエリで、TypeScript の型定義に対応するすべての列を選択していることを確認してください。

### 「大きな ID によるサイレントなデータ破損」

**原因:** JavaScript の数値は 53 ビット精度で、SQLite の INTEGER は 64 ビットです。  
**症状:** 9007199254740991（Number.MAX_SAFE_INTEGER）を超える ID は、気付かないうちに切り捨てられるか破損します。  
**解決策:** 大きな ID は TEXT として保存します。

```typescript
// BAD: Snowflake/Twitter IDs will corrupt
this.sql.exec("CREATE TABLE events(id INTEGER PRIMARY KEY)");
this.sql.exec("INSERT INTO events VALUES (?)", 1234567890123456789n); // Corrupts!

// GOOD: Store as TEXT
this.sql.exec("CREATE TABLE events(id TEXT PRIMARY KEY)");
this.sql.exec("INSERT INTO events VALUES (?)", "1234567890123456789");
```

### 「deleteAll() でアラームが削除されない」

**原因:** `deleteAll()` はアラームを自動的に削除しません。  
**解決策:** アラームを削除するには、`deleteAlarm()` の前に `deleteAll()` を明示的に呼び出してください。

### 「パフォーマンスが遅い」

**原因:** 非同期 KV API を使用している。  
**解決策:** 単純なキーと値の操作でパフォーマンスを向上させるには、同期 KV API（`ctx.storage.kv`）を使用してください。

### 「ストレージ操作による請求額の増加」

**原因:** `rowsRead`/`rowsWritten` が過剰、または未使用のオブジェクトがクリーンアップされていない。  
**解決策:** `rowsRead`/`rowsWritten` のメトリクスを監視し、未使用のオブジェクトで `deleteAll()` が呼び出されるようにしてください。

### 「Durable Object の過負荷」

**原因:** 1つの DO が約 1K req/sec のソフトリミットを超えている。  
**解決策:** ランダム ID または別の分散方式を使って、複数の DO に分散してください。

## 制限

| 制限 | 値 | 備考 |
|-------|-------|-------|
| テーブルあたりの最大列数 | 100 | SQL の制限 |
| 1 行あたりの最大文字列/BLOB サイズ | 2 MB | SQL の制限 |
| 最大行サイズ | 2 MB | SQL の制限 |
| SQL 文の最大サイズ | 100 KB | SQL の制限 |
| SQL パラメーターの最大数 | 100 | SQL の制限 |
| LIKE/GLOB パターンの最大サイズ | 50 B | SQL の制限 |
| オブジェクトあたりの SQLite ストレージ | 10 GB | SQLite バックエンドのストレージ |
| SQLite のキーと値の合計サイズ | 2 MB | SQLite バックエンドのストレージ |
| オブジェクトあたりの KV ストレージ | 無制限 | KV 形式のストレージ |
| KV キーのサイズ | 2 KiB | KV 形式のストレージ |
| KV 値のサイズ | 128 KiB | KV 形式のストレージ |
| リクエストのスループット | 約 1K req/sec | DO ごとのソフトリミット |
