# R2 SQL の注意点

R2 SQL の制限、トラブルシューティング、よくある落とし穴。

## 重大な制限事項

### Workers バインディングは利用不可

**Workers/Pages のコードから R2 SQL を呼び出すことはできません** - バインディングがありません。

```typescript
// ❌ This doesn't exist
export default {
  async fetch(request, env) {
    const result = await env.R2_SQL.query("SELECT * FROM table");  // Not possible
    return Response.json(result);
  }
};
```

**解決方法：**
- 外部システムから HTTP API を使用する（Workers からは使用不可）
- r2-data-catalog REST API 経由で PyIceberg/Spark を使用する
- Workers では D1 または外部データベースを使用する

### ORDER BY の制限

次の項目でのみ並べ替えられます。
1. **パーティションキー列** - 常にサポートされます
2. **集計関数** - shuffle 戦略を介してサポートされます

**パーティション列以外の通常の列では並べ替えられません。**

```sql
-- ✅ Valid: ORDER BY partition key
SELECT * FROM logs.requests ORDER BY timestamp DESC LIMIT 100;

-- ✅ Valid: ORDER BY aggregation
SELECT region, SUM(amount) FROM sales.transactions
GROUP BY region ORDER BY SUM(amount) DESC;

-- ❌ Invalid: ORDER BY non-partition column
SELECT * FROM logs.requests ORDER BY user_id;

-- ❌ Invalid: ORDER BY alias (must repeat function)
SELECT region, SUM(amount) as total FROM sales.transactions
GROUP BY region ORDER BY total;  -- Use ORDER BY SUM(amount)
```

パーティション仕様を確認します：`DESCRIBE namespace.table_name`

## SQL 機能の制限

| 機能 | サポート | 備考 |
|---------|-----------|-------|
| SELECT、WHERE、GROUP BY、HAVING | ✅ | 標準サポート |
| COUNT、SUM、AVG、MIN、MAX | ✅ | 標準の集計関数 |
| パーティション/集計による ORDER BY | ✅ | 上記を参照 |
| LIMIT | ✅ | 最大 10,000 |
| 列エイリアス | ❌ | AS エイリアスは不可 |
| SELECT 内の式 | ❌ | col1 + col2 は不可 |
| パーティション列以外による ORDER BY | ❌ | 実行時に失敗 |
| JOIN、サブクエリ、CTE | ❌ | 書き込み時に非正規化してください |
| ウィンドウ関数、UNION | ❌ | 外部エンジンを使用してください |
| INSERT/UPDATE/DELETE | ❌ | PyIceberg/Pipelines を使用してください |
| ネストされた列、配列、JSON | ❌ | 書き込み時にフラット化してください |

**回避策：**
- JOIN 不可：データを非正規化するか、Spark/PyIceberg を使用します
- サブクエリ不可：複数のクエリに分割します
- エイリアス不可：生成された名前をそのまま使用し、アプリ側で変換します

## よくあるエラー

### 「Column not found」
**原因：** タイプミス、存在しない列、または大文字と小文字の不一致  
**解決方法：** `DESCRIBE namespace.table_name` でスキーマを確認します

### 「Type mismatch」
```sql
-- ❌ Wrong types
WHERE status = '200'              -- string instead of integer
WHERE timestamp > '2025-01-01'    -- missing time/timezone

-- ✅ Correct types
WHERE status = 200
WHERE timestamp > '2025-01-01T00:00:00Z'
```

### 「ORDER BY column not in partition key」
**原因：** パーティション列以外で並べ替えようとしています  
**解決方法：** パーティションキーまたは集計を使うか、ORDER BY を削除します。確認方法：`DESCRIBE table`

### 「Token authentication failed」
```bash
# Check/set token
echo $WRANGLER_R2_SQL_AUTH_TOKEN
export WRANGLER_R2_SQL_AUTH_TOKEN=<your-token>

# Or .env file
echo "WRANGLER_R2_SQL_AUTH_TOKEN=<your-token>" > .env
```

### 「Table not found」
```sql
-- Verify catalog and tables
SHOW DATABASES;
SHOW TABLES IN namespace_name;
```

カタログを有効にします：`npx wrangler r2 bucket catalog enable <bucket>`

### 「LIMIT exceeds maximum」
LIMIT の最大値は 10,000 です。ページネーションには、パーティションキーを使った WHERE フィルターを使用してください。

### 「No data returned」（予期しない場合）
**デバッグ手順：**
1. `SELECT COUNT(*) FROM table` - データが存在することを確認します
2. WHERE フィルターを一つずつ外します
3. `SELECT * FROM table LIMIT 10` - 実際のデータと型を調べます

## パフォーマンスの問題

### クエリが遅い

**原因：** パーティションが多すぎる、LIMIT が大きすぎる、フィルターがない、ファイルが小さい

```sql
-- ❌ Slow: No filters
SELECT * FROM logs.requests LIMIT 10000;

-- ✅ Fast: Filter on partition key
SELECT * FROM logs.requests 
WHERE timestamp >= '2025-01-15T00:00:00Z' AND timestamp < '2025-01-16T00:00:00Z'
LIMIT 1000;

-- ✅ Faster: Multiple filters
SELECT * FROM logs.requests 
WHERE timestamp >= '2025-01-15T00:00:00Z' AND status = 404 AND method = 'GET'
LIMIT 1000;
```

**ファイルの最適化：**
- Parquet の目標サイズ：圧縮後 100～500 MB
- Pipelines のロール間隔：本番環境では 300 秒以上、開発環境では 10 秒
- コンパクションを実行して小さなファイルを統合します

### クエリのタイムアウト

**解決方法：** WHERE フィルターを絞り込み、時間範囲を短くし、小さな間隔でクエリを実行します。

```sql
-- ❌ Times out: Year-long aggregation
SELECT status, COUNT(*) FROM logs.requests 
WHERE timestamp >= '2024-01-01T00:00:00Z' GROUP BY status;

-- ✅ Faster: Month-long aggregation
SELECT status, COUNT(*) FROM logs.requests 
WHERE timestamp >= '2025-01-01T00:00:00Z' AND timestamp < '2025-02-01T00:00:00Z'
GROUP BY status;
```

## ベストプラクティス

### パーティショニング
- **時系列データ：** タイムスタンプを日または時間単位でパーティション分割します
- **避ける：** カーディナリティの高いキー（user_id）、10,000 を超えるパーティション

```python
from pyiceberg.partitioning import PartitionSpec, PartitionField
from pyiceberg.transforms import DayTransform

PartitionSpec(PartitionField(source_id=1, field_id=1000, transform=DayTransform(), name="day"))
```

### クエリの記述
- **必ず LIMIT を使う** - 早期に処理を終了できます
- **最初にパーティションキーをフィルターする** - プルーニングに役立ちます
- **AND でフィルターを組み合わせる** - プルーニングを強化できます

```sql
-- Good
WHERE timestamp >= '2025-01-15T00:00:00Z' AND status = 404 AND method = 'GET' LIMIT 100
```

### 型の安全性
- 文字列は `'GET'` のように引用符で囲みます（`GET` のようにはしません）
- RFC3339 タイムスタンプは `'2025-01-01T00:00:00Z'` を使います（`'2025-01-01'` ではありません）
- ISO 日付は `'2025-01-15'` を使います（`'01/15/2025'` ではありません）

### データの整理
- **Pipelines：** 開発環境では `roll_file_time: 10`、本番環境では `roll_file_time: 300+`
- **圧縮：** `zstd` を使用します
- **メンテナンス：** 小さなファイルにはコンパクションを行い、古いスナップショットを期限切れにします

## デバッグ用チェックリスト

1. `npx wrangler r2 bucket catalog enable <bucket>` - カタログを確認します
2. `echo $WRANGLER_R2_SQL_AUTH_TOKEN` - トークンを確認します
3. `SHOW DATABASES` - 名前空間を一覧表示します
4. `SHOW TABLES IN namespace` - テーブルを一覧表示します
5. `DESCRIBE namespace.table` - スキーマを確認します
6. `SELECT COUNT(*) FROM namespace.table` - データを確認します
7. `SELECT * FROM namespace.table LIMIT 10` - 簡単なクエリをテストします
8. フィルターを一つずつ追加します

## 関連項目

- [api.md](api.md) - SQL 構文
- [patterns.md](patterns.md) - クエリの最適化
- [configuration.md](configuration.md) - セットアップ
- [Cloudflare R2 SQL Docs](https://developers.cloudflare.com/r2-sql/)