# AI Search の利用パターン

## search() と aiSearch() の比較

| 用途 | メソッド | 戻り値 |
|-----|--------|---------|
| カスタム UI、分析 | `search()` | 生のチャンクのみ（約 100～300 ミリ秒） |
| チャットボット、質疑応答 | `aiSearch()` | AI による回答とチャンク（約 500～2000 ミリ秒） |

## rewrite_query

| 設定 | 使用する場面 |
|---------|----------|
| `true` | ユーザー入力（誤字や曖昧なクエリがある場合） |
| `false` | LLM が生成したクエリ（最適化済みの場合） |

## マルチテナント構成（フォルダー単位）

```typescript
const answer = await env.AI.autorag("saas-docs").aiSearch({
  query: "refund policy",
  model: "@cf/meta/llama-3.3-70b-instruct-fp8-fast",
  filters: {
    column: "folder",
    operator: "gte",  // "starts with" pattern
    value: `tenants/${tenantId}/`
  }
});
```

## ストリーミング

```typescript
const stream = await env.AI.autorag("docs").aiSearch({
  query, model: "@cf/meta/llama-3.3-70b-instruct-fp8-fast", stream: true
});
return new Response(stream, { headers: { "Content-Type": "text/event-stream" } });
```

## スコアのしきい値

| しきい値 | 用途 |
|-----------|-----|
| 0.3（デフォルト） | 広い範囲から結果を取得する探索的な検索 |
| 0.5 | 精度と網羅性のバランスが取れた、本番環境向けのデフォルト値 |
| 0.7 | 高い精度が必要で、正確性が重要な用途 |

## システムプロンプトのテンプレート

```typescript
const systemPrompt = `You are a documentation assistant.
- Answer ONLY based on provided context
- If context doesn't contain answer, say "I don't have information"
- Include code examples from context`;
```

## 複合フィルター

```typescript
// OR: Multiple folders
filters: {
  operator: "or",
  filters: [
    { column: "folder", operator: "gte", value: "docs/api/" },
    { column: "folder", operator: "gte", value: "docs/auth/" }
  ]
}

// AND: Folder + date
filters: {
  operator: "and",
  filters: [
    { column: "folder", operator: "gte", value: "docs/" },
    { column: "timestamp", operator: "gte", value: oneWeekAgoSeconds }
  ]
}
```

## リランキング

正確性が特に重要な用途では有効にします（遅延が約 300 ミリ秒増加します）:

```typescript
reranking: { enabled: true, model: "@cf/baai/bge-reranker-base" }
```
