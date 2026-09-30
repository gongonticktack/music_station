# よく使うパターン

PyIceberg を使った R2 Data Catalog の実践的なパターンです。

## PyIceberg への接続

```python
import os
from pyiceberg.catalog.rest import RestCatalog
from pyiceberg.exceptions import NamespaceAlreadyExistsError

catalog = RestCatalog(
    name="r2_catalog",
    warehouse=os.getenv("R2_WAREHOUSE"),      # bucket name
    uri=os.getenv("R2_CATALOG_URI"),          # catalog endpoint
    token=os.getenv("R2_TOKEN"),              # API token
)

# Create namespace (idempotent)
try:
    catalog.create_namespace("default")
except NamespaceAlreadyExistsError:
    pass
```

## パターン 1: ログ分析パイプライン

ログを段階的に取り込み、時刻やレベルでクエリします。

```python
import pyarrow as pa
from datetime import datetime
from pyiceberg.schema import Schema
from pyiceberg.types import NestedField, TimestampType, StringType, IntegerType
from pyiceberg.partitioning import PartitionSpec, PartitionField
from pyiceberg.transforms import DayTransform

# Create partitioned table (once)
schema = Schema(
    NestedField(1, "timestamp", TimestampType(), required=True),
    NestedField(2, "level", StringType(), required=True),
    NestedField(3, "service", StringType(), required=True),
    NestedField(4, "message", StringType(), required=False),
)

partition_spec = PartitionSpec(
    PartitionField(source_id=1, field_id=1000, transform=DayTransform(), name="day")
)

catalog.create_namespace("logs")
table = catalog.create_table(("logs", "app_logs"), schema=schema, partition_spec=partition_spec)

# Append logs (incremental)
data = pa.table({
    "timestamp": [datetime(2026, 1, 27, 10, 30, 0)],
    "level": ["ERROR"],
    "service": ["auth-service"],
    "message": ["Failed login"],
})
table.append(data)

# Query by time + level (leverages partitioning)
scan = table.scan(row_filter="level = 'ERROR' AND day = '2026-01-27'")
errors = scan.to_pandas()
```

## パターン 2: タイムトラベルクエリ

```python
from datetime import datetime, timedelta

table = catalog.load_table(("logs", "app_logs"))

# Query specific snapshot
snapshot_id = table.current_snapshot().snapshot_id
data = table.scan(snapshot_id=snapshot_id).to_pandas()

# Query as of timestamp (yesterday)
yesterday_ms = int((datetime.now() - timedelta(days=1)).timestamp() * 1000)
data = table.scan(as_of_timestamp=yesterday_ms).to_pandas()
```

## パターン 3: スキーマの進化

```python
from pyiceberg.types import StringType

table = catalog.load_table(("users", "profiles"))

with table.update_schema() as update:
    update.add_column("email", StringType(), required=False)
    update.rename_column("name", "full_name")
# Old readers ignore new columns, new readers see nulls for old data
```

## パターン 4: パーティション分割されたテーブル

```python
from pyiceberg.partitioning import PartitionSpec, PartitionField
from pyiceberg.transforms import DayTransform, IdentityTransform

# Partition by day + country
partition_spec = PartitionSpec(
    PartitionField(source_id=1, field_id=1000, transform=DayTransform(), name="day"),
    PartitionField(source_id=2, field_id=1001, transform=IdentityTransform(), name="country"),
)
table = catalog.create_table(("events", "user_events"), schema=schema, partition_spec=partition_spec)

# Queries prune partitions automatically
scan = table.scan(row_filter="country = 'US' AND day = '2026-01-27'")
```

## パターン 5: テーブルのメンテナンス

```python
from datetime import datetime, timedelta

table = catalog.load_table(("logs", "app_logs"))

# Compact → expire → cleanup (in order)
table.rewrite_data_files(target_file_size_bytes=128 * 1024 * 1024)
seven_days_ms = int((datetime.now() - timedelta(days=7)).timestamp() * 1000)
table.expire_snapshots(older_than=seven_days_ms, retain_last=10)
three_days_ms = int((datetime.now() - timedelta(days=3)).timestamp() * 1000)
table.delete_orphan_files(older_than=three_days_ms)
```

詳細なパラメーターについては、[api.md](api.md#table-maintenance) を参照してください。

## パターン 6: リトライを伴う並行書き込み

```python
from pyiceberg.exceptions import CommitFailedException
import time

def append_with_retry(table, data, max_retries=3):
    for attempt in range(max_retries):
        try:
            table.append(data)
            return
        except CommitFailedException:
            if attempt == max_retries - 1:
                raise
            time.sleep(2 ** attempt)
```

## パターン 7: Upsert のシミュレーション

```python
import pandas as pd
import pyarrow as pa

# Read → merge → overwrite (not atomic, use Spark MERGE INTO for production)
existing = table.scan().to_pandas()
new_data = pd.DataFrame({"id": [1, 3], "value": [100, 300]})
merged = pd.concat([existing, new_data]).drop_duplicates(subset=["id"], keep="last")
table.overwrite(pa.Table.from_pandas(merged))
```

## パターン 8: DuckDB との連携

```python
import duckdb

arrow_table = table.scan().to_arrow()
con = duckdb.connect()
con.register("logs", arrow_table)
result = con.execute("SELECT level, COUNT(*) FROM logs GROUP BY level").fetchdf()
```

## パターン 9: テーブルの健全性を監視

```python
files = table.scan().plan_files()
avg_mb = sum(f.file_size_in_bytes for f in files) / len(files) / (1024**2)
print(f"Files: {len(files)}, Avg: {avg_mb:.1f}MB, Snapshots: {len(table.snapshots())}")

if avg_mb < 10 or len(files) > 1000:
    print("⚠️ Needs compaction")
```

## ベストプラクティス

| 項目 | ガイドライン |
|------|-----------|
| **パーティション分割** | 時系列データには日単位または時間単位を使用します。パーティション数は 100～1000 にし、カーディナリティが高くならないようにします。 |
| **ファイルサイズ** | 目標は 128～512MB です。平均サイズが 10MB 未満、またはファイル数が 1 万を超えたら圧縮します。 |
| **スキーマ** | 列は NULL 許容として追加します (`required=False`)。変更はまとめて行います。 |
| **メンテナンス** | 書き込みの多いテーブルは毎日または毎週圧縮します。スナップショットは 7～30 日で期限切れにし、その後で孤立ファイルをクリーンアップします。 |
| **並行性** | 読み取りは自動的に処理されます。異なるパーティションへの書き込みは安全です。同じパーティションへの書き込みはリトライします。 |
| **パフォーマンス** | パーティションで絞り込み、必要な列だけを選択します。追加は 100MB 以上の単位でまとめて行います。 |
