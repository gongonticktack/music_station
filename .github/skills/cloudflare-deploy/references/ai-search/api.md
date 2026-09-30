# AI Search API リファレンス

## Workers バインディング

```typescript
const answer = await env.AI.autorag("instance-name").aiSearch(options);
const results = await env.AI.autorag("instance-name").search(options);
const instances = await env.AI.autorag("_").listInstances();
```

## aiSearch() のオプション

```typescript
interface AiSearchOptions {
  query: string;                          // User query
  model: string;                          // Workers AI model ID
  system_prompt?: string;                 // LLM instructions
  rewrite_query?: boolean;                // Fix typos (default: false)
  max_num_results?: number;               // Max chunks (default: 10)
  ranking_options?: { score_threshold?: number }; // 0.0-1.0 (default: 0.3)
  reranking?: { enabled: boolean; model: string };
  stream?: boolean;                       // Stream response (default: false)
  filters?: Filter;                       // Metadata filters
  page?: string;                          // Pagination token
}
```

## レスポンス

```typescript
interface AiSearchResponse {
  search_query: string;      // Query used (rewritten if enabled)
  response: string;          // AI-generated answer
  data: SearchResult[];      // Retrieved chunks
  has_more: boolean;
  next_page?: string;
}

interface SearchResult {
  id: string;
  score: number;
  content: string;
  metadata: { filename: string; folder: string; timestamp: number };
}
```

## フィルター

```typescript
// Comparison
{ column: "folder", operator: "gte", value: "docs/" }

// Compound
{ operator: "and", filters: [
  { column: "folder", operator: "gte", value: "docs/" },
  { column: "timestamp", operator: "gte", value: 1704067200 }
]}
```

**演算子:** `eq`、`ne`、`gt`、`gte`、`lt`、`lte`

**組み込みメタデータ:** `filename`、`folder`、`timestamp`（Unix 秒）

## ストリーミング

```typescript
const stream = await env.AI.autorag("docs").aiSearch({ query, model, stream: true });
return new Response(stream, { headers: { "Content-Type": "text/event-stream" } });
```

## エラーの種類

| エラー | 原因 |
|-------|-------|
| `AutoRAGNotFoundError` | インスタンスが存在しない |
| `AutoRAGUnauthorizedError` | トークンが無効、または指定されていない |
| `AutoRAGValidationError` | パラメーターが無効 |

## REST API

```bash
curl https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/autorag/rags/{NAME}/ai-search \
  -H "Authorization: Bearer {TOKEN}" \
  -d '{"query": "...", "model": "@cf/meta/llama-3.3-70b-instruct-fp8-fast"}'
```

「AI Search - Read」権限を持つ Service API トークンが必要です。
