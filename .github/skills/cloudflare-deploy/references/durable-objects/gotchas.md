# Durable Objects の注意点

## よくあるエラー

### 「休止状態からの復帰でインメモリ状態が消えた」

**問題:** 休止後に変数が失われる  
**原因:** アイドル状態になると DO は自動的に休止し、インメモリ状態は永続化されない  
**解決策:** 重要なデータには `ctx.storage` を、接続ごとのメタデータには `ws.serializeAttachment()` を使用します

```typescript
// ❌ Wrong - lost on hibernation
private userCount = 0;
async webSocketMessage(ws: WebSocket, msg: string) {
  this.userCount++;  // Lost!
}

// ✅ Right - persisted
async webSocketMessage(ws: WebSocket, msg: string) {
  const count = this.ctx.storage.kv.get("userCount") || 0;
  this.ctx.storage.kv.put("userCount", count + 1);
}
```

### 「再起動後に `setTimeout` が発火しなかった」

**問題:** 退避時にスケジュール済みの処理が失われる  
**原因:** `setTimeout` はインメモリのみで、退避されるとタイマーが消去される  
**解決策:** 確実なスケジューリングには `ctx.storage.setAlarm()` を使用します

```typescript
// ❌ Wrong - lost on eviction
setTimeout(() => this.cleanup(), 3600000);

// ✅ Right - survives eviction
await this.ctx.storage.setAlarm(Date.now() + 3600000);
async alarm() { await this.cleanup(); }
```

### 「コンストラクターが起動のたびに実行される」

**問題:** 初期化コストの高い処理により、すべてのリクエストが遅くなる  
**原因:** 起動のたびにコンストラクターが実行される（退避後の最初のリクエスト、または休止状態からの復帰後）  
**解決策:** 遅延初期化するか、ストレージにキャッシュします

**重要なポイント:** コンストラクターは次の2つの状況で実行されます。
1. **コールドスタート** - DO がメモリから退避され、最初のリクエストで新しいインスタンスが作成される
2. **休止状態からの復帰** - WebSocket を持つ DO が休止状態に入り、メッセージまたはアラームで起動する

```typescript
// ❌ Wrong - expensive on every wake
constructor(ctx: DurableObjectState, env: Env) {
  super(ctx, env);
  this.heavyData = this.loadExpensiveData();  // Slow!
}

// ✅ Right - lazy load
private heavyData?: HeavyData;
private getHeavyData() {
  if (!this.heavyData) this.heavyData = this.loadExpensiveData();
  return this.heavyData;
}
```

### 「Durable Object の過負荷（503 エラー）」

**問題:** 負荷時に 503 エラーが発生する  
**原因:** 単一の DO がスループット上限の約 1K リクエスト/秒を超過している  
**解決策:** 複数の DO にシャーディングします（[パターン: シャーディング](./patterns.md)を参照）

### 「ストレージ割り当て量の超過（書き込み失敗）」

**問題:** 書き込み操作が失敗する  
**原因:** DO ストレージが 10GB の上限またはアカウントの割り当て量を超過している  
**解決策:** アラームでクリーンアップし、古いデータには `deleteAll()` を使用するか、プランをアップグレードします

### 「CPU 時間の超過（処理の終了）」

**問題:** 実行中にリクエストが終了される  
**原因:** 処理時間がデフォルトの CPU 時間上限である 30 秒を超過している  
**解決策:** wrangler.jsonc の `limits.cpu_ms` を増やす（最大 300 秒）か、処理を分割します

### 「退避時に WebSocket が切断される」

**問題:** 接続が予期せず切断される  
**原因:** 休止 API を使用せずに DO がメモリから退避される  
**解決策:** WebSocket の休止ハンドラーと、クライアント側の再接続ロジックを使用します

### 「マイグレーション失敗（デプロイエラー）」

**原因:** タグが一意でない、連番でない、またはマイグレーション内のクラス名が無効  
**解決策:** タグの一意性と連番の順序を確認し、クラス名が正しいことを確かめます

### 「RPC メソッドが見つからない」

**原因:** compatibility_date が 2024-04-03 より前で、RPC を使用できない  
**解決策:** compatibility_date を >= 2024-04-03 に更新するか、RPC の代わりに fetch() を使用します

### 「アラームは1つのみ」

**原因:** 複数のスケジュール済みタスクが必要だが、DO ごとにサポートされるアラームは1つのみ  
**解決策:** イベントキューのパターンを使用し、単一のアラームで複数のタスクをスケジュールします

### 「シングルスレッドでも競合状態が発生する」

**問題:** 同時リクエストが不整合な状態を参照する  
**原因:** 非同期操作ではリクエストが交互に実行されることがある（await は処理の譲渡点）  
**解決策:** 重要なセクションでは `blockConcurrencyWhile()` を使用するか、アトミックなストレージ操作を行います

```typescript
// ❌ Wrong - race condition
async incrementCounter() {
  const count = await this.ctx.storage.get("count") || 0;
  // ⚠️ Another request could execute here during await
  await this.ctx.storage.put("count", count + 1);
}

// ✅ Right - atomic operation
async incrementCounter() {
  return this.ctx.storage.sql.exec(
    "INSERT INTO counters (id, value) VALUES (1, 1) ON CONFLICT(id) DO UPDATE SET value = value + 1 RETURNING value"
  ).one().value;
}

// ✅ Right - explicit locking
async criticalOperation() {
  await this.ctx.blockConcurrencyWhile(async () => {
    const count = await this.ctx.storage.get("count") || 0;
    await this.ctx.storage.put("count", count + 1);
  });
}
```

### 「マイグレーションのロールバックはサポートされない」

**原因:** デプロイ後にマイグレーションをロールバックしようとしている  
**解決策:** デプロイ前に `--dry-run` でテストしてください。マイグレーションはロールバックできません

### 「`deleted_classes` はデータを破棄する」

**問題:** マイグレーションによってすべてのデータが削除された  
**原因:** `deleted_classes` マイグレーションは、すべての DO インスタンスとデータを直ちに破棄する  
**解決策:** `--dry-run` でテストしてください。移行中にデータを保持するには `transferred_classes` を使用します

### 「コールドスタートが遅い」

**問題:** 退避後の最初のリクエストに時間がかかる  
**原因:** コールドスタート時に DO のコンストラクターと初回のストレージアクセスが発生する  
**解決策:** 想定された動作です。コンストラクターを最適化し、クライアントではコネクションプーリングを使用します。重要な DO にはウォームアップ戦略も検討してください

```typescript
// Warming strategy (periodically ping critical DOs)
export default {
  async scheduled(event: ScheduledEvent, env: Env) {
    const criticalIds = ["auth", "sessions", "locks"];
    await Promise.all(criticalIds.map(name => {
      const id = env.MY_DO.idFromName(name);
      const stub = env.MY_DO.get(id);
      return stub.ping();  // Keep warm
    }));
  }
};
```

## 制限

| 制限 | 無料 | 有料 | 備考 |
|-------|------|------|-------|
| DO ごとの SQLite ストレージ | 10 GB | 10 GB | Durable Object インスタンスごと |
| SQLite の合計ストレージ | 5 GB | 無制限 | アカウント全体の割り当て量 |
| キーと値のサイズ | 2 MB | 2 MB | 単一の KV ペア（SQLite/async） |
| CPU 時間のデフォルト | 30s | 30s | リクエストごと。変更可能 |
| CPU 時間の上限 | 300s | 300s | `limits.cpu_ms` で設定 |
| DO クラス | 100 | 500 | 個別の DO クラス定義 |
| SQL 列 | 100 | 100 | テーブルごと |
| SQL 文のサイズ | 100 KB | 100 KB | SQL クエリの最大サイズ |
| WebSocket メッセージサイズ | 32 MiB | 32 MiB | メッセージごと |
| リクエストスループット | 約1K リクエスト/秒 | 約1K リクエスト/秒 | DO ごと（ソフト上限。さらに必要な場合はシャーディング） |
| DO ごとのアラーム | 1 | 1 | 複数イベントにはキューパターンを使用 |
| DO の合計数 | 無制限 | 無制限 | 必要な数だけインスタンスを作成可能 |
| WebSocket | 無制限 | 無制限 | DO ごとのメモリ上限 128MB 以内 |
| DO ごとのメモリ | 128 MB | 128 MB | インメモリ状態と WebSocket バッファ |

## 休止に関する注意事項

1. **メモリの消去** - すべてのインメモリ変数が失われます。ストレージまたは `deserializeAttachment()` から再構築してください
2. **コンストラクターの再実行** - 復帰時に実行されます。コストの高い処理を避け、遅延初期化を使用してください
3. **保証なし** - DO は休止ではなく退避される場合があります。どちらにも対応できるよう設計してください
4. **Attachment の上限** - `serializeAttachment()` のデータは JSON でシリアライズ可能でなければなりません。サイズを小さく保ってください
5. **アラームによる DO の起動** - アラームハンドラーの完了までは休止しません
6. **WebSocket の状態は自動保存されない** - `serializeAttachment()` またはストレージを使って明示的に永続化する必要があります

## 関連項目

- **[パターン](./patterns.md)** - よくある制限への対処方法
- **[API](./api.md)** - ストレージの上限と割り当て量
- **[設定](./configuration.md)** - CPU 上限の設定