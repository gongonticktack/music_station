# R2 SQL API リファレンス

R2 SQL クエリの SQL 構文、関数、演算子、データ型。

## SQL 構文

```sql
SELECT column_list | aggregation_function
FROM [namespace.]table_name
WHERE conditions
[GROUP BY column_list]
[HAVING conditions]
[ORDER BY column | aggregation_function [DESC | ASC]]
[LIMIT number]
```

## スキーマの検出

```sql
SHOW DATABASES;           -- List namespaces
SHOW NAMESPACES;          -- Alias for SHOW DATABASES
SHOW SCHEMAS;             -- Alias for SHOW DATABASES
SHOW TABLES IN namespace; -- List tables in namespace
DESCRIBE namespace.table; -- Show table schema, partition keys
```

## SELECT 句

```sql
-- All columns
SELECT * FROM logs.http_requests;

-- Specific columns
SELECT user_id, timestamp, status FROM logs.http_requests;
```

**制限事項:** 列エイリアス、式、ネストした列へのアクセスには対応していません

## WHERE 句

### 演算子

| 演算子 | 例 |
|----------|---------|
| `=`, `!=`, `<`, `<=`, `>`, `>=` | `status = 200` |
| `LIKE` | `user_agent LIKE '%Chrome%'` |
| `BETWEEN` | `timestamp BETWEEN '2025-01-01T00:00:00Z' AND '2025-01-31T23:59:59Z'` |
| `IS NULL`, `IS NOT NULL` | `email IS NOT NULL` |
| `AND`, `OR` | `status = 200 AND method = 'GET'` |

優先順位を指定するには括弧を使います: `(status = 404 OR status = 500) AND method = 'POST'`

## 集計関数

| 関数 | 説明 |
|----------|-------------|
| `COUNT(*)` | すべての行をカウント |
| `COUNT(column)` | NULL 以外の値をカウント |
| `COUNT(DISTINCT column)` | 一意な値をカウント |
| `SUM(column)`, `AVG(column)` | 数値の集計 |
| `MIN(column)`, `MAX(column)` | 最小値/最大値 |

```sql
-- Multiple aggregations with GROUP BY
SELECT region, COUNT(*), SUM(amount), AVG(amount)
FROM sales.transactions
WHERE sale_date >= '2024-01-01'
GROUP BY region;
```

## HAVING 句

集計結果を（GROUP BY の後に）絞り込みます:

```sql
SELECT category, SUM(amount)
FROM sales.transactions
GROUP BY category
HAVING SUM(amount) > 10000;
```

## ORDER BY 句

次の項目で結果を並べ替えます:
- **パーティションキーカラム** - 常に対応
- **集計関数** - シャッフル戦略を介して対応

```sql
-- Order by partition key
SELECT * FROM logs.requests ORDER BY timestamp DESC LIMIT 100;

-- Order by aggregation (repeat function, aliases not supported)
SELECT region, SUM(amount)
FROM sales.transactions
GROUP BY region
ORDER BY SUM(amount) DESC;
```

**制限事項:** パーティション以外の列では並べ替えできません。[gotchas.md](gotchas.md#order-by-limitations) を参照してください

## LIMIT 句

```sql
SELECT * FROM logs.requests LIMIT 100;
```

| 設定 | 値 |
|---------|-------|
| 最小値 | 1 |
| 最大値 | 10,000 |
| デフォルト | 500 |

**必ず LIMIT を使用してください。** 早期終了の最適化が有効になります。

## データ型

| 型 | SQL リテラル | 例 |
|------|-------------|---------|
| `integer` | 引用符なしの数値 | `42`, `-10` |
| `float` | 小数 | `3.14`, `-0.5` |
| `string` | シングルクォート | `'hello'`, `'GET'` |
| `boolean` | キーワード | `true`, `false` |
| `timestamp` | RFC3339 形式の文字列 | `'2025-01-01T00:00:00Z'` |
| `date` | ISO 8601 形式の日付 | `'2025-01-01'` |

### 型の安全性

- 文字列はシングルクォートで囲みます: `'value'`
- タイムスタンプは RFC3339 形式である必要があります: `'2025-01-01T00:00:00Z'`（タイムゾーンを含める）
- 日付は ISO 8601 形式である必要があります: `'2025-01-01'`（YYYY-MM-DD）
- 暗黙の型変換はありません

```sql
-- ✅ Correct
WHERE status = 200 AND method = 'GET' AND timestamp > '2025-01-01T00:00:00Z'

-- ❌ Wrong
WHERE status = '200'              -- string instead of integer
WHERE timestamp > '2025-01-01'    -- missing time/timezone
WHERE method = GET                -- unquoted string
```

## クエリ結果の形式

オブジェクトの JSON 配列:

```json
[
  {"user_id": "user_123", "timestamp": "2025-01-15T10:30:00Z", "status": 200},
  {"user_id": "user_456", "timestamp": "2025-01-15T10:31:00Z", "status": 404}
]
```

## 関連項目

- [patterns.md](patterns.md) - クエリの例とユースケース
- [gotchas.md](gotchas.md) - SQL の制限とエラー処理
- [configuration.md](configuration.md) - セットアップと認証
