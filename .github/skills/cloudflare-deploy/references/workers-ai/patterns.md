# Workers AI のパターン

## RAG（検索拡張生成）

```typescript
// 1. Embed query
const embedding = await env.AI.run('@cf/baai/bge-base-en-v1.5', { text: query });

// 2. Search vectors
const results = await env.VECTORIZE.query(embedding.data[0], {
  topK: 5, returnMetadata: true
});

// 3. Build context
const context = results.matches.map(m => m.metadata?.text).join('\n\n');

// 4. Generate with context
const response = await env.AI.run('@cf/meta/llama-3.1-8b-instruct', {
  messages: [
    { role: 'system', content: `Answer based on:\n\n${context}` },
    { role: 'user', content: query }
  ]
});
```

## ストリーミング（SSE）

```typescript
const stream = await env.AI.run('@cf/meta/llama-3.1-8b-instruct', {
  messages, stream: true
});

const { readable, writable } = new TransformStream();
const writer = writable.getWriter();

(async () => {
  for await (const chunk of stream) {
    await writer.write(new TextEncoder().encode(`data: ${JSON.stringify(chunk)}\n\n`));
  }
  await writer.write(new TextEncoder().encode('data: [DONE]\n\n'));
  await writer.close();
})();

return new Response(readable, {
  headers: { 'Content-Type': 'text/event-stream' }
});
```

## エラー処理と再試行

```typescript
async function runWithRetry(env, model, input, maxRetries = 3) {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await env.AI.run(model, input);
    } catch (error) {
      if (error.message?.includes('7505') && attempt < maxRetries - 1) {
        await new Promise(r => setTimeout(r, Math.pow(2, attempt) * 1000));
        continue;
      }
      throw error;
    }
  }
}
```

## モデルのフォールバック

```typescript
try {
  return await env.AI.run('@cf/meta/llama-3.1-70b-instruct', { messages });
} catch {
  return await env.AI.run('@cf/meta/llama-3.1-8b-instruct', { messages });
}
```

## プロンプトのパターン

```typescript
// System prompts
const PROMPTS = {
  json: 'Respond with valid JSON only.',
  concise: 'Keep responses brief.',
  cot: 'Think step by step before answering.'
};

// Few-shot
messages: [
  { role: 'system', content: 'Extract as JSON' },
  { role: 'user', content: 'John bought 3 apples for $5' },
  { role: 'assistant', content: '{"name":"John","item":"apples","qty":3}' },
  { role: 'user', content: actualInput }
]
```

## 並列実行

```typescript
const [sentiment, summary, embedding] = await Promise.all([
  env.AI.run('@cf/mistral/mistral-7b-instruct-v0.1', { messages: sentimentPrompt }),
  env.AI.run('@cf/meta/llama-3.1-8b-instruct', { messages: summaryPrompt }),
  env.AI.run('@cf/baai/bge-base-en-v1.5', { text })
]);
```

## コストの最適化

| タスク | モデル | ニューロン数 |
|------|-------|---------|
| 分類 | `@cf/mistral/mistral-7b-instruct-v0.1` | ~50 |
| チャット | `@cf/meta/llama-3.1-8b-instruct` | ~200 |
| 複雑な処理 | `@cf/meta/llama-3.1-70b-instruct` | ~2000 |
| 埋め込み | `@cf/baai/bge-base-en-v1.5` | ~10 |

```typescript
// Batch embeddings
const response = await env.AI.run('@cf/baai/bge-base-en-v1.5', {
  text: textsArray // Process multiple at once
});
```
