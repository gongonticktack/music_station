# Cloudflare Vectorize

AIアプリケーション向けのグローバル分散ベクトルデータベースです。ベクトル埋め込みを保存・検索し、セマンティック検索、レコメンデーション、RAG、分類に利用できます。

**ステータス:** 一般提供（GA） | **最終更新日:** 2026-01-27

## クイックスタート

```typescript
// 1. Create index
// npx wrangler vectorize create my-index --dimensions=768 --metric=cosine

// 2. Configure binding (wrangler.jsonc)
// { "vectorize": [{ "binding": "VECTORIZE", "index_name": "my-index" }] }

// 3. Query vectors
const matches = await env.VECTORIZE.query(queryVector, { topK: 5 });
```

## 主な機能

- **インデックスあたり1,000万ベクトル**（V2）
- 次元数は最大1536（32ビット浮動小数点数）
- 距離メトリクスは3種類：コサイン、ユークリッド、内積
- メタデータによるフィルタリング（インデックスは最大10個）
- Namespaceに対応（有料プランは5万、無料プランは1,000）
- Workers AIとシームレスに連携
- グローバル分散

## 読む順序

| 作業 | 読むファイル |
|------|---------------|
| Vectorizeを初めて使う | READMEのみ |
| 機能を実装する | README + api + patterns |
| セットアップ・設定 | README + configuration |
| 問題をデバッグする | gotchas |
| AIと連携する | README + patterns |
| RAGを実装する | README + patterns |

## ファイルガイド

- **README.md**（このファイル）：概要、選択時の要点
- **api.md**：ランタイムAPI、型、操作（query/insert/upsert）
- **configuration.md**：セットアップ、CLI、メタデータインデックス
- **patterns.md**：RAG、Workers AI、OpenAI、LangChain、マルチテナント
- **gotchas.md**：制限、注意点、トラブルシューティング

## 距離メトリクスの選択

用途に応じて選択します。

```
What are you building?
├─ Text/semantic search → cosine (most common)
├─ Image similarity → euclidean
├─ Recommendation system → dot-product
└─ Pre-normalized vectors → dot-product
```

| メトリクス | 適した用途 | スコアの解釈 |
|--------|----------|---------------------|
| `cosine` | テキスト埋め込み、意味的類似性 | 値が大きいほど近い（1.0 = 同一） |
| `euclidean` | 絶対距離、空間データ | 値が小さいほど近い（0.0 = 同一） |
| `dot-product` | レコメンデーション、正規化済みベクトル | 値が大きいほど近い |

**注:** インデックスの設定は変更できません。作成後に次元数やメトリクスを変更することはできません。

## マルチテナント戦略

```
How many tenants?
├─ < 50K tenants → Use namespaces (recommended)
│   ├─ Fastest (filter before vector search)
│   └─ Strict isolation
├─ > 50K tenants → Use metadata filtering
│   ├─ Slower (post-filter after vector search)
│   └─ Requires metadata index
└─ Per-tenant indexes → Only if compliance mandated
    └─ 50K index limit per account (paid plan)
```

## よくあるワークフロー

### セマンティック検索

```typescript
// 1. Generate embedding
const result = await env.AI.run("@cf/baai/bge-base-en-v1.5", { text: [query] });

// 2. Query Vectorize
const matches = await env.VECTORIZE.query(result.data[0], {
  topK: 5,
  returnMetadata: "indexed"
});
```

### RAGパターン

```typescript
// 1. Generate query embedding
const embedding = await env.AI.run("@cf/baai/bge-base-en-v1.5", { text: [query] });

// 2. Search Vectorize
const matches = await env.VECTORIZE.query(embedding.data[0], { topK: 5 });

// 3. Fetch full documents from R2/D1/KV
const docs = await Promise.all(matches.matches.map(m => 
  env.R2.get(m.metadata.key).then(obj => obj?.text())
));

// 4. Generate LLM response with context
const answer = await env.AI.run("@cf/meta/llama-3-8b-instruct", {
  prompt: `Context: ${docs.join("\n\n")}\n\nQuestion: ${query}\n\nAnswer:`
});
```

## 重要な注意点

詳細は`gotchas.md`を参照してください。特に重要な点は次のとおりです。

1. **非同期変更**：挿入したデータを検索できるようになるまで5～10秒かかります
2. **バッチ上限は500件**：Workers APIでは1回の呼び出しにつきベクトル500件までです（未文書化）
3. **メタデータの切り詰め**：`"indexed"`が返すのは先頭64バイトのみです
4. **メタデータ指定時のtopK**：returnValuesまたはreturnMetadata: "all"を使用すると最大20件です（100件ではありません）
5. **先にメタデータインデックスを作成**：ベクトルを挿入する前に作成する必要があります

## リソース

- [公式ドキュメント](https://developers.cloudflare.com/vectorize/)
- [クライアントAPIリファレンス](https://developers.cloudflare.com/vectorize/reference/client-api/)
- [Workers AIモデル](https://developers.cloudflare.com/workers-ai/models/#text-embeddings)
- [Discord: #vectorize](https://discord.cloudflare.com)
