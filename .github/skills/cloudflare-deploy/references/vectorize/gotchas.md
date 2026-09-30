# Vectorize の注意事項

## 重要な警告

### 非同期の変更操作
挿入／upsert／削除はすぐに戻りますが、ベクトルがクエリ可能になるまで5～10秒かかります。

### バッチサイズの上限
**Workers API: 1回の呼び出しにつき最大500ベクトル**（未公開の制限で、警告なしに切り詰められます）

```typescript
// ✅ Chunk into 500
for (let i = 0; i < vectors.length; i += 500) {
  await env.VECTORIZE.upsert(vectors.slice(i, i + 500));
}
```

### メタデータの切り詰め
`returnMetadata: "indexed"` が返すのは文字列の最初の64バイトのみです。メタデータ全体を取得するには `"all"` を使用してください（ただし topK の上限は20になります）。

### topK の上限

| returnMetadata | returnValues | topK の最大値 |
|----------------|--------------|----------|
| `"none"` / `"indexed"` | `false` | 100 |
| `"all"` | 任意 | **20** |
| 任意 | `true` | **20** |

### メタデータインデックスを先に作成
挿入前に作成してください - 既存のベクトルには遡及的にインデックスが作成されません。

```bash
# ✅ Create index FIRST
wrangler vectorize create-metadata-index my-index --property-name=category --type=string
wrangler vectorize insert my-index --file=data.ndjson
```

### インデックス構成は変更不可
作成後に次元数／メトリックを変更できません。新しいインデックスを作成し、移行する必要があります。

## 制限（V2）

| リソース | 上限 |
|----------|-------|
| インデックスあたりのベクトル数 | 10,000,000 |
| 最大次元数 | 1536 |
| バッチ upsert（Workers） | **500** |
| インデックス化される文字列メタデータ | **64バイト** |
| メタデータインデックス | 10 |
| Namespace | 50,000（有料）／1,000（無料）|

## よくある間違い

1. **埋め込みの形式が誤っている:** Workers AI から `result.data[0]` を取り出す
2. **データ挿入後にメタデータインデックスを作成:** すべてのベクトルを再度 upsert する
3. **Insert と upsert の違い:** `insert` は重複を無視し、`upsert` は上書きします
4. **バッチ処理をしない:** 個別の挿入は約1K件／分、バッチ処理は約200K件以上／分

## トラブルシューティング

**結果がありませんか？**
- 挿入後に5～10秒待つ
- Namespace の綴りを確認する（大文字と小文字を区別）
- メタデータインデックスが存在することを確認する
- 次元数の不一致を確認する

**メタデータフィルターが機能しませんか？**
- データ挿入前にインデックスが存在している必要があります
- 64バイトを超える文字列は切り詰められます
- ネストされたデータにはドット記法を使用する: `"product.category"`

## モデルの次元数

- `@cf/baai/bge-small-en-v1.5`: 384
- `@cf/baai/bge-base-en-v1.5`: 768
- `@cf/baai/bge-large-en-v1.5`: 1024
