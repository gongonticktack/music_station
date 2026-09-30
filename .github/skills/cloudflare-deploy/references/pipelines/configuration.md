# Pipelines の設定

## Worker バインディング

```jsonc
// wrangler.jsonc
{
  "pipelines": [
    { "pipeline": "<STREAM_ID>", "binding": "STREAM" }
  ]
}
```

ストリーム ID の取得: `npx wrangler pipelines streams list`

## スキーマ（構造化ストリーム）

```json
{
  "fields": [
    { "name": "user_id", "type": "string", "required": true },
    { "name": "event_type", "type": "string", "required": true },
    { "name": "amount", "type": "float64", "required": false },
    { "name": "timestamp", "type": "timestamp", "required": true }
  ]
}
```

**型:** `string`, `int32`, `int64`, `float32`, `float64`, `bool`, `timestamp`, `json`, `binary`, `list`, `struct`

## ストリームの設定

```bash
# With schema
npx wrangler pipelines streams create my-stream --schema-file schema.json

# Unstructured (no validation)
npx wrangler pipelines streams create my-stream

# List/get/delete
npx wrangler pipelines streams list
npx wrangler pipelines streams get <ID>
npx wrangler pipelines streams delete <ID>
```

## Sink の設定

**R2 Data Catalog（Iceberg）:**
```bash
npx wrangler pipelines sinks create my-sink \
  --type r2-data-catalog \
  --bucket my-bucket --namespace default --table events \
  --catalog-token $TOKEN \
  --compression zstd --roll-interval 60
```

**R2 Raw（Parquet）:**
```bash
npx wrangler pipelines sinks create my-sink \
  --type r2 --bucket my-bucket --format parquet \
  --path analytics/events \
  --partitioning "year=%Y/month=%m/day=%d" \
  --access-key-id $KEY --secret-access-key $SECRET
```

| オプション | 値 | 指針 |
|--------|--------|----------|
| `--compression` | `zstd`, `snappy`, `gzip` | `zstd` は圧縮率が最良、`snappy` は最速 |
| `--roll-interval` | 秒 | 低レイテンシ: 10～60、クエリ性能: 300 |
| `--roll-size` | MB | 大きいほど圧縮効率が向上 |

## Pipeline の作成

```bash
npx wrangler pipelines create my-pipeline \
  --sql "INSERT INTO my_sink SELECT * FROM my_stream WHERE event_type = 'purchase'"
```

**⚠️ Pipelines は不変です** - SQL を変更できません。削除して再作成する必要があります。

## 認証情報

| 種類 | 権限 | 取得元 |
|------|------------|----------|
| Catalog トークン | R2 Admin Read & Write | Dashboard → R2 → API tokens |
| R2 認証情報 | Object Read & Write | `wrangler r2 bucket create` の出力 |
| HTTP ingest トークン | Workers Pipeline Send | Dashboard → Workers → API tokens |

## 完全な例

```bash
npx wrangler r2 bucket create my-bucket
npx wrangler r2 bucket catalog enable my-bucket
npx wrangler pipelines streams create my-stream --schema-file schema.json
npx wrangler pipelines sinks create my-sink --type r2-data-catalog --bucket my-bucket ...
npx wrangler pipelines create my-pipeline --sql "INSERT INTO my_sink SELECT * FROM my_stream"
npx wrangler deploy
```
