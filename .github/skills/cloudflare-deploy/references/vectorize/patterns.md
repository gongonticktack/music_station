# Vectorizeのパターン

## Workers AIとの連携

```typescript
// Generate embedding + query
const result = await env.AI.run("@cf/baai/bge-base-en-v1.5", { text: [query] });
const matches = await env.VECTORIZE.query(result.data[0], { topK: 5 }); // Pass data[0]!
```

| モデル | 次元数 |
|-------|------------|
| `@cf/baai/bge-small-en-v1.5` | 384 |
| `@cf/baai/bge-base-en-v1.5` | 768（推奨） |
| `@cf/baai/bge-large-en-v1.5` | 1024 |

## OpenAIとの連携

```typescript
const response = await openai.embeddings.create({ model: "text-embedding-ada-002", input: query });
const matches = await env.VECTORIZE.query(response.data[0].embedding, { topK: 5 });
```

## RAGパターン

```typescript
// 1. Embed query
const emb = await env.AI.run("@cf/baai/bge-base-en-v1.5", { text: [query] });

// 2. Search vectors
const matches = await env.VECTORIZE.query(emb.data[0], { topK: 5, returnMetadata: "indexed" });

// 3. Fetch full docs from R2/D1/KV
const docs = await Promise.all(matches.matches.map(m => env.R2.get(m.metadata.key).then(o => o?.text())));

// 4. Generate with context
const answer = await env.AI.run("@cf/meta/llama-3-8b-instruct", {
  prompt: `Context:\n${docs.filter(Boolean).join("\n\n")}\n\nQuestion: ${query}\n\nAnswer:`
});
```

## マルチテナント

### Namespace（テナント数が5万未満の場合。最速）

```typescript
await env.VECTORIZE.upsert([{ id: "1", values: emb, namespace: `tenant-${id}` }]);
await env.VECTORIZE.query(vec, { namespace: `tenant-${id}`, topK: 10 });
```

### メタデータフィルター（テナント数が5万を超える場合）

```bash
wrangler vectorize create-metadata-index my-index --property-name=tenantId --type=string
```

```typescript
await env.VECTORIZE.upsert([{ id: "1", values: emb, metadata: { tenantId: id } }]);
await env.VECTORIZE.query(vec, { filter: { tenantId: id }, topK: 10 });
```

## ハイブリッド検索

```typescript
const matches = await env.VECTORIZE.query(vec, {
  topK: 20,
  filter: {
    category: { $in: ["tech", "science"] },
    published: { $gte: lastMonthTimestamp }
  }
});
```

## バッチ取り込み

```typescript
const BATCH = 500;
for (let i = 0; i < vectors.length; i += BATCH) {
  await env.VECTORIZE.upsert(vectors.slice(i, i + BATCH));
}
```

## ベストプラクティス

1. **`data[0]`を渡す**。`data`やレスポンス全体は渡さない
2. upsert 1回につきベクトルを500件まとめる
3. 挿入前にメタデータインデックスを作成する
4. テナント分離にはnamespaceを使う（フィルターより高速）
5. 速度とデータ品質のバランスを最適にするには**`returnMetadata: "indexed"`**を使う
6. 非同期処理では、変更が反映されるまで5～10秒かかることを考慮する
