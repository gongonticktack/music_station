# Workers AI API リファレンス

## コアメソッド

```typescript
const response = await env.AI.run(model, input);
```

## テキスト生成

```typescript
const result = await env.AI.run('@cf/meta/llama-3.1-8b-instruct', {
  messages: [
    { role: 'system', content: 'You are helpful' },
    { role: 'user', content: 'Hello' }
  ],
  temperature: 0.7,  // 0-1
  max_tokens: 100
});
console.log(result.response);
```

**ストリーミング:**
```typescript
const stream = await env.AI.run(model, { messages, stream: true });
return new Response(stream, { headers: { 'Content-Type': 'text/event-stream' } });
```

## 埋め込み

```typescript
const result = await env.AI.run('@cf/baai/bge-base-en-v1.5', {
  text: ['Query', 'Doc 1', 'Doc 2'] // Batch for efficiency
});
const [queryEmbed, doc1Embed, doc2Embed] = result.data; // 768-dim vectors
```

## 関数呼び出し

```typescript
const tools = [{
  type: 'function',
  function: {
    name: 'getWeather',
    description: 'Get weather for location',
    parameters: {
      type: 'object',
      properties: { location: { type: 'string' } },
      required: ['location']
    }
  }
}];

const response = await env.AI.run(model, { messages, tools });
if (response.tool_calls) {
  const args = JSON.parse(response.tool_calls[0].function.arguments);
  // Execute function, send result back
}
```

## 画像生成

```typescript
const image = await env.AI.run('@cf/stabilityai/stable-diffusion-xl-base-1.0', {
  prompt: 'Mountain sunset',
  num_steps: 20,   // 1-20
  guidance: 7.5    // 1-20
});
return new Response(image, { headers: { 'Content-Type': 'image/png' } });
```

## 音声認識

```typescript
const audioArray = Array.from(new Uint8Array(await request.arrayBuffer()));
const result = await env.AI.run('@cf/openai/whisper', { audio: audioArray });
console.log(result.text);
```

## 翻訳

```typescript
const result = await env.AI.run('@cf/meta/m2m100-1.2b', {
  text: 'Hello',
  source_lang: 'en',
  target_lang: 'es'
});
console.log(result.translated_text);
```

## REST API

```bash
curl https://api.cloudflare.com/client/v4/accounts/{account_id}/ai/run/@cf/meta/llama-3.1-8b-instruct \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"messages":[{"role":"user","content":"Hello"}]}'
```

## エラーコード

| コード | 意味 | 対処方法 |
|------|---------|-----|
| 7502 | モデルが見つかりません | スペルを確認してください |
| 7504 | 検証に失敗しました | 入力スキーマを確認してください |
| 7505 | レート制限中 | リクエスト頻度を下げるか、プランをアップグレードしてください |
| 7506 | コンテキスト上限を超過しました | 入力サイズを小さくしてください |

## パフォーマンスのヒント

1. **埋め込みをバッチ処理する** - 複数のテキストを1回のリクエストで送信します
2. **長い応答をストリーミングする** - 体感レイテンシを低減します
3. **コールドスタートを許容する** - 最初のリクエストは約1～3秒、以降は約100～500ミリ秒です
