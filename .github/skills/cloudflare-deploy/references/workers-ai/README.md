# Cloudflare Workers AI

Cloudflare Workers AI に関する専門的なガイダンス — エッジでサーバーレスの GPU 駆動 AI 推論を実行します。

## 概要

Workers AI が提供する機能:
- 事前学習済みモデル 50 種以上（LLM、埋め込み、画像生成、音声からテキストへの変換、翻訳）
- Workers のネイティブバインディング（外部 API 呼び出し不要）
- 従量課金制（推論ごとにニューロンを消費）
- OpenAI 互換の REST API
- テキスト生成のストリーミング対応
- 互換モデルでの関数呼び出し

**アーキテクチャ**: 推論は Cloudflare の GPU ネットワーク上で実行されます。モデルは最初のリクエスト時に読み込まれ（コールドスタートは 1～3 秒）、以降のリクエストはより高速になります。

## クイックスタート

```typescript
interface Env {
  AI: Ai;
}

export default {
  async fetch(request: Request, env: Env) {
    const response = await env.AI.run('@cf/meta/llama-3.1-8b-instruct', {
      messages: [{ role: 'user', content: 'What is Cloudflare?' }]
    });
    return Response.json(response);
  }
};
```

```bash
# Setup - add binding to wrangler.jsonc
wrangler dev --remote  # Must use --remote for AI
wrangler deploy
```

## モデル選択の判断ツリー

### テキスト生成（チャット／補完）

**品質優先**:
- **最高品質**: `@cf/meta/llama-3.1-70b-instruct`（高コスト、約 2000 ニューロン）
- **バランス重視**: `@cf/meta/llama-3.1-8b-instruct`（良好な品質、約 200 ニューロン）
- **最速／最安**: `@cf/mistral/mistral-7b-instruct-v0.1`（約 50 ニューロン）

**関数呼び出し**:
- `@cf/meta/llama-3.1-8b-instruct` または `@cf/meta/llama-3.1-70b-instruct` を使用（ネイティブのツール対応）

**コード生成**:
- `@cf/deepseek-ai/deepseek-coder-6.7b-instruct` を使用（コード生成に特化）

### 埋め込み（セマンティック検索／RAG）

**英語テキスト**:
- **最高品質**: `@cf/baai/bge-large-en-v1.5`（1024 次元、最高品質）
- **バランス重視**: `@cf/baai/bge-base-en-v1.5`（768 次元、良好な品質）
- **高速**: `@cf/baai/bge-small-en-v1.5`（384 次元、品質は低めだが高速）

**多言語**:
- `@hf/sentence-transformers/paraphrase-multilingual-minilm-l12-v2` を使用

### 画像生成

- **Stable Diffusion**: `@cf/stabilityai/stable-diffusion-xl-base-1.0`（約 10,000 ニューロン）
- **ポートレート**: `@cf/lykon/dreamshaper-8-lcm`（顔向けに最適化）

### その他のタスク

- **音声からテキストへの変換**: `@cf/openai/whisper`
- **翻訳**: `@cf/meta/m2m100-1.2b`（100 言語）
- **画像分類**: `@cf/microsoft/resnet-50`

## SDK の選択に関する判断ツリー

### ネイティブバインディング（推奨）

**利用場面**: TypeScript で Workers／Pages を構築する場合  
**理由**: 外部依存関係がなく、最高のパフォーマンスとネイティブ型を利用できる

```typescript
await env.AI.run(model, input);
```

### REST API

**利用場面**: 外部サービス、Workers 以外の環境、テスト  
**理由**: 標準的な HTTP で、どこでも動作する

```bash
curl https://api.cloudflare.com/client/v4/accounts/<ACCOUNT_ID>/ai/run/@cf/meta/llama-3.1-8b-instruct \
  -H "Authorization: Bearer <API_TOKEN>" \
  -d '{"messages":[{"role":"user","content":"Hello"}]}'
```

### Vercel AI SDK との統合

**利用場面**: Vercel AI SDK の機能（ストリーミング UI、ツール呼び出しの抽象化）を使う場合  
**理由**: プロバイダーをまたいで統一されたインターフェースを利用できる

```typescript
import { openai } from '@ai-sdk/openai';

const model = openai('model-name', {
  baseURL: 'https://api.cloudflare.com/client/v4/accounts/<ACCOUNT_ID>/ai/v1',
  headers: { Authorization: 'Bearer <API_TOKEN>' }
});
```

## RAG と直接生成の使い分け

### 次の場合は RAG（Vectorize + Workers AI）を使用:
- 特定のドキュメントやデータに関する質問に回答する
- 既知のコーパスに基づく事実の正確さが必要
- コンテキストがモデルのウィンドウを超える（4K トークン超）
- ナレッジベースのチャットを構築する

### 次の場合は直接生成を使用:
- 創作、ブレインストーミング
- 一般知識に関する質問
- 小さなコンテキストがプロンプトに収まる（4K トークン未満）
- コストを最適化する（RAG では埋め込みとベクトル検索のコストが追加される）

## プラットフォームの制限

| 制限 | 無料プラン | 有料プラン |
|-------|-----------|------------|
| ニューロン／日 | 10,000 | 従量課金 |
| レート制限 | モデルによって異なる | より高い上限（サポートに問い合わせ） |
| コンテキストウィンドウ | モデルに依存（2K～8K） | 同じ |
| ストリーミング | ✅ 対応 | ✅ 対応 |
| 関数呼び出し | ✅ 対応（一部モデル） | ✅ 対応 |

**料金**: 1 日あたり 10K ニューロンまで無料。その後は消費したニューロン数に応じた従量課金（モデルによって異なる）

## よくあるタスク

```typescript
// Streaming text generation
const stream = await env.AI.run(model, { messages, stream: true });
for await (const chunk of stream) {
  console.log(chunk.response);
}

// Embeddings for RAG
const { data } = await env.AI.run('@cf/baai/bge-base-en-v1.5', {
  text: ['Query text', 'Document 1', 'Document 2']
});

// Function calling
const response = await env.AI.run('@cf/meta/llama-3.1-8b-instruct', {
  messages: [{ role: 'user', content: 'What is the weather?' }],
  tools: [{
    type: 'function',
    function: { name: 'getWeather', parameters: { ... } }
  }]
});
```

## 開発ワークフロー

```bash
# Always use --remote for AI (local doesn't have models)
wrangler dev --remote

# Deploy to production
wrangler deploy

# View model catalog
# https://developers.cloudflare.com/workers-ai/models/
```

## 読み進める順序

**まずはこちら**: 上記のクイックスタート → configuration.md（セットアップ）

**よくあるタスク**:
- 初回セットアップ: configuration.md → バインディングを追加してデプロイ
- モデルを選ぶ: モデル選択の判断ツリー（上記） → api.md
- RAG を構築: patterns.md → Vectorize との統合
- コストを最適化: モデル選択 + gotchas.md（レート制限）
- デバッグ: gotchas.md → よくあるエラー

## このリファレンスの内容

- [configuration.md](./configuration.md) - wrangler.jsonc の設定、TypeScript 型、バインディング、環境変数
- [api.md](./api.md) - env.AI.run()、ストリーミング、関数呼び出し、REST API、レスポンス型
- [patterns.md](./patterns.md) - Vectorize を使った RAG、プロンプトエンジニアリング、バッチ処理、エラー処理、キャッシュ
- [gotchas.md](./gotchas.md) - 非推奨の @cloudflare/ai パッケージ、レート制限、料金、よくあるエラー

## 関連項目

- [vectorize](../vectorize/) - RAG パターン向けのベクトルデータベース
- [ai-gateway](../ai-gateway/) - AI リクエストのキャッシュ、レート制限、分析
- [workers](../workers/) - Worker ランタイムと fetch ハンドラのパターン
