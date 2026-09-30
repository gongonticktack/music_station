# API リファレンス

R2 Data Catalog は標準の [Apache Iceberg REST Catalog API](https://github.com/apache/iceberg/blob/main/open-api/rest-catalog-open-api.yaml) を公開します。

## クイックリファレンス

**よく使う操作:**

| タスク | PyIceberg コード |
|------|----------------|
| 接続 | `RestCatalog(name="r2", warehouse=bucket, uri=uri, token=token)` |
| 名前空間の一覧表示 | `catalog.list_namespaces()` |
| 名前空間の作成 | `catalog.create_namespace("logs")` |
| テーブルの作成 | `catalog.create_table(("ns", "table"), schema=schema)` |
| テーブルの読み込み | `catalog.load_table(("ns", "table"))` |
| データの追加 | `table.append(pyarrow_table)` |
| データのクエリ | `table.scan().to_pandas()` |
| ファイルのコンパクション | `table.rewrite_data_files(target_file_size_bytes=128*1024*1024)` |
| スナップショットの期限切れ | `table.expire_snapshots(older_than=timestamp_ms, retain_last=10)` |

## REST エンドポイント

ベース: `https://<account-id>.r2.cloudflarestorage.com/iceberg/<bucket-name>`

| 操作 | メソッド | パス |
|-----------|--------|------|
| カタログ設定 | GET | `/v1/config` |
| 名前空間の一覧表示 | GET | `/v1/namespaces` |
| 名前空間の作成 | POST | `/v1/namespaces` |
| 名前空間の削除 | DELETE | `/v1/namespaces/{ns}` |
| テーブルの一覧表示 | GET | `/v1/namespaces/{ns}/tables` |
| テーブルの作成 | POST | `/v1/namespaces/{ns}/tables` |
| テーブルの読み込み | GET | `/v1/namespaces/{ns}/tables/{table}` |
| テーブルの更新 | POST | `/v1/namespaces/{ns}/tables/{table}` |
| テーブルの削除 | DELETE | `/v1/namespaces/{ns}/tables/{table}` |
| テーブル名の変更 | POST | `/v1/tables/rename` |

**認証:** ヘッダーに Bearer トークンを指定: `Authorization: Bearer <token>`

## PyIceberg クライアント API

ほとんどのユーザーは生の REST ではなく、PyIceberg を使用します。

### 接続

```python
from pyiceberg.catalog.rest import RestCatalog

catalog = RestCatalog(
    name="my_catalog",
    warehouse="<bucket-name>",
    uri="<catalog-uri>",
    token="<api-token>",
)
```

### 名前空間の操作

```python
from pyiceberg.exceptions import NamespaceAlreadyExistsError

namespaces = catalog.list_namespaces()  # [('default',), ('logs',)]
catalog.create_namespace("logs", properties={"owner": "team"})
catalog.drop_namespace("logs")  # Must be empty
```

### テーブルの操作

```python
from pyiceberg.schema import Schema
from pyiceberg.types import NestedField, StringType, IntegerType

schema = Schema(
    NestedField(1, "id", IntegerType(), required=True),
    NestedField(2, "name", StringType(), required=False),
)
table = catalog.create_table(("logs", "app_logs"), schema=schema)
tables = catalog.list_tables("logs")
table = catalog.load_table(("logs", "app_logs"))
catalog.rename_table(("logs", "old"), ("logs", "new"))
```

### データ操作

```python
import pyarrow as pa

data = pa.table({"id": [1, 2], "name": ["Alice", "Bob"]})
table.append(data)
table.overwrite(data)

# Read with filters
scan = table.scan(row_filter="id > 100", selected_fields=["id", "name"])
df = scan.to_pandas()
```

### スキーマの変更

```python
from pyiceberg.types import IntegerType, LongType

with table.update_schema() as update:
    update.add_column("user_id", IntegerType(), doc="User ID")
    update.rename_column("msg", "message")
    update.delete_column("old_field")
    update.update_column("id", field_type=LongType())  # int→long only
```

### タイムトラベル

```python
from datetime import datetime, timedelta

# Query specific snapshot or timestamp
scan = table.scan(snapshot_id=table.snapshots()[-2].snapshot_id)
yesterday_ms = int((datetime.now() - timedelta(days=1)).timestamp() * 1000)
scan = table.scan(as_of_timestamp=yesterday_ms)
```

### パーティショニング

```python
from pyiceberg.partitioning import PartitionSpec, PartitionField
from pyiceberg.transforms import DayTransform
from pyiceberg.types import TimestampType

partition_spec = PartitionSpec(
    PartitionField(source_id=1, field_id=1000, transform=DayTransform(), name="day")
)
table = catalog.create_table(("events", "actions"), schema=schema, partition_spec=partition_spec)
scan = table.scan(row_filter="day = '2026-01-27'")  # Prunes partitions
```

## テーブルのメンテナンス

### コンパクション

```python
files = table.scan().plan_files()
avg_mb = sum(f.file_size_in_bytes for f in files) / len(files) / (1024**2)
print(f"Files: {len(files)}, Avg: {avg_mb:.1f} MB")

table.rewrite_data_files(target_file_size_bytes=128 * 1024 * 1024)
```

**実施条件:** 平均サイズが 10 MB 未満、またはファイル数が 1000 超。 **頻度:** 書き込みが多い場合は毎日、中程度の場合は毎週。

### スナップショットの期限切れ

```python
from datetime import datetime, timedelta

seven_days_ms = int((datetime.now() - timedelta(days=7)).timestamp() * 1000)
table.expire_snapshots(older_than=seven_days_ms, retain_last=10)
```

**保持期間:** 本番環境は 7～30 日、開発環境は 1～7 日、監査用は 90 日以上。

### 孤立ファイルのクリーンアップ

```python
three_days_ms = int((datetime.now() - timedelta(days=3)).timestamp() * 1000)
table.delete_orphan_files(older_than=three_days_ms)
```

⚠️ 必ず先にスナップショットを期限切れにし、3 日以上のしきい値を使用して、トラフィックの少ない時間帯に実行してください。

### メンテナンス全般

```python
# Compact → Expire → Cleanup (in order)
if len(table.scan().plan_files()) > 1000:
    table.rewrite_data_files(target_file_size_bytes=128 * 1024 * 1024)
seven_days_ms = int((datetime.now() - timedelta(days=7)).timestamp() * 1000)
table.expire_snapshots(older_than=seven_days_ms, retain_last=10)
three_days_ms = int((datetime.now() - timedelta(days=3)).timestamp() * 1000)
table.delete_orphan_files(older_than=three_days_ms)
```

## メタデータの確認

```python
table = catalog.load_table(("logs", "app_logs"))
print(table.schema())
print(table.current_snapshot())
print(table.properties)
print(f"Files: {len(table.scan().plan_files())}")
```

## エラーコード

| コード | 意味 | よくある原因 |
|------|---------|---------------|
| 401 | 未認証 | トークンが無効、または指定されていない |
| 404 | 見つかりません | カタログが有効化されていない、名前空間／テーブルが存在しない |
| 409 | 競合 | すでに存在する、同時更新 |
| 422 | 検証エラー | スキーマが無効、互換性のない型 |

詳しいトラブルシューティングは [gotchas.md](gotchas.md) を参照してください。
