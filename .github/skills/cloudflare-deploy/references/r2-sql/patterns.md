# R2 SQL のパターン

R2 SQL の一般的なパターン、ユースケース、統合例。

## Wrangler CLI でのクエリ

```bash
# Basic query
npx wrangler r2 sql query "my-bucket" "SELECT * FROM default.logs LIMIT 10"

# Multi-line query
npx wrangler r2 sql query "my-bucket" "
  SELECT status, COUNT(*), AVG(response_time)
  FROM logs.http_requests
  WHERE timestamp >= '2025-01-01T00:00:00Z'
  GROUP BY status
  ORDER BY COUNT(*) DESC
  LIMIT 100
"

# Use environment variable
export R2_SQL_WAREHOUSE="my-bucket"
npx wrangler r2 sql query "$R2_SQL_WAREHOUSE" "SELECT * FROM default.logs"
```

## HTTP API でのクエリ

外部システムからプログラムでアクセスする場合（Workers からは不可。gotchas.md を参照）。

```bash
curl -X POST https://api.cloudflare.com/client/v4/accounts/{account_id}/r2/sql/query \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "warehouse": "my-bucket",
    "query": "SELECT * FROM default.my_table WHERE status = 200 LIMIT 100"
  }'
```

レスポンス:
```json
{
  "success": true,
  "result": [{"user_id": "user_123", "timestamp": "2025-01-15T10:30:00Z", "status": 200}],
  "errors": []
}
```

## Pipelines との統合

Pipelines 経由で Iceberg テーブルにデータをストリーミングし、その後 R2 SQL でクエリします。

```bash
# Setup pipeline (select Data Catalog Table destination)
npx wrangler pipelines setup

# Key settings:
# - Destination: Data Catalog Table
# - Compression: zstd (recommended)
# - Roll file time: 300+ sec (production), 10 sec (dev)

# Send data to pipeline
curl -X POST https://{stream-id}.ingest.cloudflare.com \
  -H "Content-Type: application/json" \
  -d '[{"user_id": "user_123", "event_type": "purchase", "timestamp": "2025-01-15T10:30:00Z", "amount": 29.99}]'

# Query ingested data (wait for roll interval)
npx wrangler r2 sql query "my-bucket" "
  SELECT event_type, COUNT(*), SUM(amount)
  FROM default.events
  WHERE timestamp >= '2025-01-15T00:00:00Z'
  GROUP BY event_type
"
```

詳しいセットアップについては、[pipelines/patterns.md](../pipelines/patterns.md) を参照してください。

## PyIceberg との統合

PyIceberg で Iceberg テーブルを作成してデータを投入し、その後 R2 SQL でクエリします。

```python
from pyiceberg.catalog.rest import RestCatalog
import pyarrow as pa
import pandas as pd

# Setup catalog
catalog = RestCatalog(
    name="my_catalog",
    warehouse="my-bucket",
    uri="https://<account-id>.r2.cloudflarestorage.com/iceberg/my-bucket",
    token="<your-token>",
)
catalog.create_namespace_if_not_exists("analytics")

# Create table
schema = pa.schema([
    pa.field("user_id", pa.string(), nullable=False),
    pa.field("event_time", pa.timestamp("us", tz="UTC"), nullable=False),
    pa.field("page_views", pa.int64(), nullable=False),
])
table = catalog.create_table(("analytics", "user_metrics"), schema=schema)

# Append data
df = pd.DataFrame({
    "user_id": ["user_1", "user_2"],
    "event_time": pd.to_datetime(["2025-01-15 10:00:00", "2025-01-15 11:00:00"], utc=True),
    "page_views": [10, 25],
})
table.append(pa.Table.from_pandas(df, schema=schema))
```

R2 SQL でクエリする:
```bash
npx wrangler r2 sql query "my-bucket" "
  SELECT user_id, SUM(page_views)
  FROM analytics.user_metrics
  WHERE event_time >= '2025-01-15T00:00:00Z'
  GROUP BY user_id
"
```

PyIceberg の高度なパターンについては、[r2-data-catalog/patterns.md](../r2-data-catalog/patterns.md) を参照してください。

## ユースケース

### ログ分析
```sql
-- Error rate by endpoint
SELECT path, COUNT(*), SUM(CASE WHEN status >= 400 THEN 1 ELSE 0 END) as errors
FROM logs.http_requests
WHERE timestamp BETWEEN '2025-01-01T00:00:00Z' AND '2025-01-31T23:59:59Z'
GROUP BY path ORDER BY errors DESC LIMIT 20;

-- Response time stats
SELECT method, MIN(response_time_ms), AVG(response_time_ms), MAX(response_time_ms)
FROM logs.http_requests WHERE timestamp >= '2025-01-15T00:00:00Z' GROUP BY method;

-- Traffic by status
SELECT status, COUNT(*) FROM logs.http_requests
WHERE timestamp >= '2025-01-15T00:00:00Z' AND method = 'GET'
GROUP BY status ORDER BY COUNT(*) DESC;
```

### 不正検知
```sql
-- High-value transactions
SELECT location, COUNT(*), SUM(amount), AVG(amount)
FROM fraud.transactions WHERE transaction_timestamp >= '2025-01-01T00:00:00Z' AND amount > 1000.0
GROUP BY location ORDER BY SUM(amount) DESC LIMIT 20;

-- Flagged transactions
SELECT merchant_category, COUNT(*), AVG(amount) FROM fraud.transactions
WHERE is_fraud_flag = true AND transaction_timestamp >= '2025-01-01T00:00:00Z'
GROUP BY merchant_category HAVING COUNT(*) > 10 ORDER BY COUNT(*) DESC;
```

### ビジネスインテリジェンス
```sql
-- Sales by department
SELECT department, SUM(revenue), AVG(revenue), COUNT(*) FROM sales.transactions
WHERE sale_date >= '2024-01-01' GROUP BY department ORDER BY SUM(revenue) DESC LIMIT 10;

-- Product performance
SELECT category, COUNT(DISTINCT product_id), SUM(units_sold), SUM(revenue)
FROM sales.product_sales WHERE sale_date BETWEEN '2024-10-01' AND '2024-12-31'
GROUP BY category ORDER BY SUM(revenue) DESC;
```

## 外部エンジンへの接続

R2 Data Catalog は Iceberg REST API を公開します。Spark、Snowflake、Trino、DuckDB などを接続できます。

```scala
// Apache Spark example
val spark = SparkSession.builder()
  .config("spark.sql.catalog.my_catalog", "org.apache.iceberg.spark.SparkCatalog")
  .config("spark.sql.catalog.my_catalog.catalog-impl", "org.apache.iceberg.rest.RESTCatalog")
  .config("spark.sql.catalog.my_catalog.uri", "https://<account-id>.r2.cloudflarestorage.com/iceberg/my-bucket")
  .config("spark.sql.catalog.my_catalog.token", "<token>")
  .getOrCreate()

spark.sql("SELECT * FROM my_catalog.default.my_table LIMIT 10").show()
```

その他のエンジンについては、[r2-data-catalog/patterns.md](../r2-data-catalog/patterns.md) を参照してください。

## パフォーマンスの最適化

### パーティショニング
- **時系列:** timestamp による日／時間単位
- **地理情報:** 地域／国
- **避ける:** カーディナリティの高いキー（user_id）

```python
from pyiceberg.partitioning import PartitionSpec, PartitionField
from pyiceberg.transforms import DayTransform

PartitionSpec(PartitionField(source_id=1, field_id=1000, transform=DayTransform(), name="day"))
```

### クエリの最適化
- **早期終了のため、常に LIMIT を使用する**
- **まずパーティションキーで絞り込む**
- **より効率よくデータを除外するため、複数のフィルターを使用する**

```sql
-- Better: Multiple filters on partition key
SELECT * FROM logs.requests 
WHERE timestamp >= '2025-01-15T00:00:00Z' AND status = 404 AND method = 'GET' LIMIT 100;
```

### ファイルの整理
- **Pipelines のロールアップ:** 開発環境では 10～30 秒、本番環境では 300 秒以上
- **Parquet の目標サイズ:** 圧縮後 100～500 MB

## 関連項目

- [api.md](api.md) - SQL 構文リファレンス
- [gotchas.md](gotchas.md) - 制限事項とトラブルシューティング
- [r2-data-catalog/patterns.md](../r2-data-catalog/patterns.md) - PyIceberg の高度なパターン
- [pipelines/patterns.md](../pipelines/patterns.md) - ストリーミング取り込みパターン