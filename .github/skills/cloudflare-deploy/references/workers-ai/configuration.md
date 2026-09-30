# Workers AI の設定

## wrangler.jsonc

```jsonc
{
  "name": "my-ai-worker",
  "main": "src/index.ts",
  "compatibility_date": "2024-01-01",
  "ai": {
    "binding": "AI"
  }
}
```

## TypeScript

```bash
npm install --save-dev @cloudflare/workers-types
```

```typescript
interface Env {
  AI: Ai;
}

export default {
  async fetch(request: Request, env: Env) {
    const response = await env.AI.run('@cf/meta/llama-3.1-8b-instruct', {
      messages: [{ role: 'user', content: 'Hello' }]
    });
    return Response.json(response);
  }
};
```

## ローカル開発

```bash
wrangler dev --remote  # Required for AI - no local inference
```

## REST API

```typescript
const response = await fetch(
  `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/ai/run/@cf/meta/llama-3.1-8b-instruct`,
  {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${API_TOKEN}` },
    body: JSON.stringify({ messages: [{ role: 'user', content: 'Hello' }] })
  }
);
```

API トークンは次の場所で作成します: dash.cloudflare.com/profile/api-tokens（Workers AI - Read 権限）

## SDK との互換性

**OpenAI SDK:**
```typescript
import OpenAI from 'openai';
const client = new OpenAI({
  apiKey: env.CLOUDFLARE_API_TOKEN,
  baseURL: `https://api.cloudflare.com/client/v4/accounts/${env.ACCOUNT_ID}/ai/v1`
});
```

## 複数モデルの設定

```typescript
const MODELS = {
  chat: '@cf/meta/llama-3.1-8b-instruct',
  embed: '@cf/baai/bge-base-en-v1.5',
  image: '@cf/stabilityai/stable-diffusion-xl-base-1.0'
};
```

## RAG の設定（Vectorize を使用）

```jsonc
{
  "ai": { "binding": "AI" },
  "vectorize": {
    "bindings": [{ "binding": "VECTORIZE", "index_name": "embeddings-index" }]
  }
}
```

## トラブルシューティング

| エラー | 対処方法 |
|-------|-----|
| `env.AI is undefined` | wrangler.jsonc の `ai` バインディングを確認します |
| ローカルで AI が動作しない | `wrangler dev --remote` を使用します |
| 型 'Ai' が見つからない | `@cloudflare/workers-types` をインストールします |
| @cloudflare/ai パッケージのエラー | インストールしないでください - ネイティブバインディングを使用します |
