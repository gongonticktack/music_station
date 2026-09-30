# Vectorize API リファレンス

## 型

```typescript
interface VectorizeVector {
  id: string;                    // Max 64 bytes
  values: number[];              // Must match index dimensions
  namespace?: string;            // Optional partition (max 64 bytes)
  metadata?: Record<string, any>; // Max 10 KiB
}
```

## クエリ

```typescript
const matches = await env.VECTORIZE.query(queryVector, {
  topK: 10,                        // Max 100 (or 20 with returnValues/returnMetadata:"all")
  returnMetadata: "indexed",       // "none" | "indexed" | "all"
  returnValues: false,
  namespace: "tenant-123",
  filter: { category: "docs" }
});
// matches.matches[0] = { id, score, metadata? }
```

**returnMetadata:** `"none"`（最速）→ `"indexed"`（推奨）→ `"all"`（topK の最大値は20）

**queryById（V2 のみ）:** 既存のベクトルをクエリとして検索します。
```typescript
await env.VECTORIZE.queryById("doc-123", { topK: 5 });
```

## 挿入／Upsert

```typescript
// Insert: ignores duplicates (keeps first)
await env.VECTORIZE.insert([{ id, values, metadata }]);

// Upsert: overwrites duplicates (keeps last)
await env.VECTORIZE.upsert([{ id, values, metadata }]);
```

**1回の呼び出しあたり最大500ベクトル。** クエリ可能になるまで5～10秒かかります。

## その他の操作

```typescript
// Get by IDs
const vectors = await env.VECTORIZE.getByIds(["id1", "id2"]);

// Delete (max 1000 IDs per call)
await env.VECTORIZE.deleteByIds(["id1", "id2"]);

// Index info
const info = await env.VECTORIZE.describe();
// { dimensions, metric, vectorCount }
```

## フィルタリング

メタデータインデックスが必要です。フィルター演算子:

| 演算子 | 例 |
|----------|---------|
| `$eq`（暗黙） | `{ category: "docs" }` |
| `$ne` | `{ status: { $ne: "deleted" } }` |
| `$in` / `$nin` | `{ tag: { $in: ["sale"] } }` |
| `$lt`、`$lte`、`$gt`、`$gte` | `{ price: { $lt: 100 } }` |

**制約:** 最大2048バイト、キーにドット/`$`は使用不可、値は文字列／数値／真偽値／null。

## パフォーマンス

| 構成 | topK の上限 | 速度 |
|--------------|------------|-------|
| メタデータなし | 100 | 最速 |
| `returnMetadata: "indexed"` | 100 | 高速 |
| `returnMetadata: "all"` | 20 | 低速 |
| `returnValues: true` | 20 | 低速 |

**バッチ処理:** スループットを最適化するには、常にバッチ処理（1回あたり500件）を使用してください。

```typescript
for (let i = 0; i < vectors.length; i += 500) {
  await env.VECTORIZE.upsert(vectors.slice(i, i + 500));
}
```
