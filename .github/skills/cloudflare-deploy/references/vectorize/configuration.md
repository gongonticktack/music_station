# Vectorize の構成

## インデックスの作成

```bash
npx wrangler vectorize create my-index --dimensions=768 --metric=cosine
```

**⚠️ 次元数とメトリックは変更できません** - 作成後に変更できません。

## Worker バインディング

```jsonc
// wrangler.jsonc
{
  "vectorize": [
    { "binding": "VECTORIZE", "index_name": "my-index" }
  ]
}
```

```typescript
interface Env {
  VECTORIZE: Vectorize;
}
```

## メタデータインデックス

**ベクトルの挿入前に作成する必要があります** - 既存のベクトルには遡及的にインデックスが作成されません。

```bash
wrangler vectorize create-metadata-index my-index --property-name=category --type=string
wrangler vectorize create-metadata-index my-index --property-name=price --type=number
```

| 種類 | 用途 |
|------|---------|
| `string` | カテゴリ、タグ（最初の64バイトがインデックス化されます） |
| `number` | 価格、タイムスタンプ |
| `boolean` | フラグ |

## CLI コマンド

```bash
# Index management
wrangler vectorize list
wrangler vectorize info <index-name>
wrangler vectorize delete <index-name>

# Vector operations
wrangler vectorize insert <index-name> --file=embeddings.ndjson
wrangler vectorize get <index-name> --ids=id1,id2
wrangler vectorize delete-by-ids <index-name> --ids=id1,id2

# Metadata indexes
wrangler vectorize list-metadata-index <index-name>
wrangler vectorize delete-metadata-index <index-name> --property-name=field
```

## 一括アップロード（NDJSON）

```json
{"id": "1", "values": [0.1, 0.2, ...], "metadata": {"category": "docs"}}
{"id": "2", "values": [0.4, 0.5, ...], "namespace": "tenant-abc"}
```

**制限:** 1ファイルあたり最大5000ベクトル、最大100 MB

## カーディナリティに関するベストプラクティス

カーディナリティの高いデータはバケット化します:
```typescript
// ❌ Millisecond timestamps
metadata: { timestamp: Date.now() }

// ✅ 5-minute buckets
metadata: { timestamp_bucket: Math.floor(Date.now() / 300000) * 300000 }
```

## 本番環境のチェックリスト

1. 適切な次元数でインデックスを作成する
2. メタデータインデックスを最初に作成する
3. 一括アップロードをテストする
4. バインディングを構成する
5. Worker をデプロイする
6. クエリを確認する
