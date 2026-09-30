# Workers AI の注意点

## 重要: @cloudflare/ai は非推奨です

```typescript
// ❌ WRONG - Don't install @cloudflare/ai
import Ai from '@cloudflare/ai';

// ✅ CORRECT - Use native binding
export default {
  async fetch(request: Request, env: Env) {
    await env.AI.run('@cf/meta/llama-3.1-8b-instruct', { messages: [...] });
  }
}
```

## 開発

### 「AI 推論がローカルで動作しない」
```bash
# ❌ Local AI doesn't work
wrangler dev
# ✅ Use remote
wrangler dev --remote
```

### 「env.AI が undefined になる」
wrangler.jsonc にバインディングを追加します:
```jsonc
{ "ai": { "binding": "AI" } }
```

## API レスポンス

### 埋め込みレスポンスの形式は一定ではありません
```typescript
// @cf/baai/bge-base-en-v1.5 returns: { data: [[0.1, 0.2, ...]] }
const embedding = response.data[0]; // Get first element
```

### ストリームは ReadableStream を返します
```typescript
const stream = await env.AI.run(model, { messages: [...], stream: true });
for await (const chunk of stream) { console.log(chunk.response); }
```

## レート制限と料金

| モデルの種類 | リクエストあたりのニューロン数 |
|------------|-----------------|
| 小規模テキスト (7B) | ~50-200 |
| 大規模テキスト (70B) | ~500-2000 |
| 埋め込み | ~5-20 |
| 画像生成 | ~10,000+ |

**無料枠**: 1 日あたり 10,000 ニューロン

```typescript
// ❌ EXPENSIVE - 70B model
await env.AI.run('@cf/meta/llama-3.1-70b-instruct', ...);
// ✅ CHEAPER - Use smallest that works
await env.AI.run('@cf/meta/llama-3.1-8b-instruct', ...);
```

## モデル固有

### 関数呼び出し
ツールをサポートしているのは `@cf/meta/llama-3.1-*` と `mistral-7b-instruct-v0.2` のみです。

### 空のレスポンス
コンテキスト制限（2K-8K トークン）を確認します。入力構造を検証します。

### 一貫しないレスポンス
決定論的な出力にするには `temperature: 0` を設定します。

### コールドスタートの遅延
最初のリクエスト: 1-3 秒。頻繁に使うプロンプトには AI Gateway のキャッシュを使用します。

## TypeScript

```typescript
interface Env {
  AI: Ai; // From @cloudflare/workers-types
}

interface TextGenerationResponse { response: string; }
interface EmbeddingResponse { data: number[][]; shape: number[]; }
```

## よくあるエラー

### 7502: モデルが見つかりません
developers.cloudflare.com/workers-ai/models/ で正確なモデル名を確認します。

### 7504: 入力の検証に失敗しました
```typescript
// Text gen requires messages array
await env.AI.run('@cf/meta/llama-3.1-8b-instruct', {
  messages: [{ role: 'user', content: 'Hello' }]  // ✅
});

// Embeddings require text
await env.AI.run('@cf/baai/bge-base-en-v1.5', { text: 'Hello' });  // ✅
```

## Vercel AI SDK との統合

```typescript
import { openai } from '@ai-sdk/openai';
const model = openai('gpt-3.5-turbo', {
  baseURL: 'https://api.cloudflare.com/client/v4/accounts/<ACCOUNT_ID>/ai/v1',
  headers: { Authorization: 'Bearer <API_TOKEN>' }
});
```
