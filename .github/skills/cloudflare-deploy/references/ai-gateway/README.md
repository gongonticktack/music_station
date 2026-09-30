# Cloudflare AI Gateway

分析、キャッシュ、レート制限、ルーティング機能を備えた、AI モデルプロバイダー向けの汎用ゲートウェイである Cloudflare AI Gateway を実装するための専門的なガイドです。

## このリファレンスを使う場面

- 任意の AI プロバイダー（OpenAI、Anthropic、Workers AI など）向けに AI Gateway を設定する
- キャッシュ、レート制限、リクエストの再試行やフォールバックを実装する
- A/B テストやモデルのフォールバックを使った動的ルーティングを設定する
- BYOK を使ってプロバイダーの API キーを安全に管理する
- セキュリティ機能（ガードレール、DLP）を追加する
- ログとカスタムメタデータを使って可観測性を確保する
- AI Gateway のリクエストをデバッグし、設定を最適化する

## クイックスタート

**どの構成を使いますか？**

- **Vercel AI SDK を使用** → パターン 1（推奨）- [sdk-integration.md](./sdk-integration.md) を参照
- **OpenAI SDK を使用** → パターン 2 - [sdk-integration.md](./sdk-integration.md) を参照
- **Cloudflare Worker + Workers AI** → パターン 3 - [sdk-integration.md](./sdk-integration.md) を参照
- **直接 HTTP を使用（言語は任意）** → パターン 4 - [configuration.md](./configuration.md) を参照
- **フレームワーク（LangChain など）を使用** → [sdk-integration.md](./sdk-integration.md) を参照

## パターン 1: Vercel AI SDK（推奨）

公式の `ai-gateway-provider` パッケージを使用し、フォールバックを自動で処理する最新の構成です。

```typescript
import { createAiGateway } from 'ai-gateway-provider';
import { createOpenAI } from '@ai-sdk/openai';
import { generateText } from 'ai';

const gateway = createAiGateway({
  accountId: process.env.CF_ACCOUNT_ID,
  gateway: process.env.CF_GATEWAY_ID,
});

const openai = createOpenAI({ 
  apiKey: process.env.OPENAI_API_KEY 
});

// Single model
const { text } = await generateText({
  model: gateway(openai('gpt-4o')),
  prompt: 'Hello'
});

// Automatic fallback array
const { text } = await generateText({
  model: gateway([
    openai('gpt-4o'),              // Try first
    anthropic('claude-sonnet-4-5'), // Fallback
  ]),
  prompt: 'Hello'
});
```

**インストール:** `npm install ai-gateway-provider ai @ai-sdk/openai @ai-sdk/anthropic`

## パターン 2: OpenAI SDK

複数プロバイダーに対応する、OpenAI API のそのまま置き換えられる実装です。

```typescript
import OpenAI from 'openai';

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
  baseURL: `https://gateway.ai.cloudflare.com/v1/${accountId}/${gatewayId}/compat`,
  defaultHeaders: {
    'cf-aig-authorization': `Bearer ${cfToken}` // For authenticated gateways
  }
});

// Switch providers by changing model format: {provider}/{model}
const response = await client.chat.completions.create({
  model: 'openai/gpt-4o', // or 'anthropic/claude-sonnet-4-5'
  messages: [{ role: 'user', content: 'Hello!' }]
});
```

## パターン 3: Workers AI バインディング

Workers AI を使用する Cloudflare Workers 向けです。

```typescript
export default {
  async fetch(request, env, ctx) {
    const response = await env.AI.run(
      '@cf/meta/llama-3-8b-instruct',
      { messages: [{ role: 'user', content: 'Hello!' }] },
      { 
        gateway: { 
          id: 'my-gateway',
          metadata: { userId: '123', team: 'engineering' }
        } 
      }
    );
    
    return Response.json(response);
  }
};
```

## ヘッダーのクイックリファレンス

| ヘッダー | 用途 | 例 | 備考 |
|--------|---------|---------|-------|
| `cf-aig-authorization` | ゲートウェイの認証 | `Bearer {token}` | 認証が必要なゲートウェイでは必須 |
| `cf-aig-metadata` | 追跡 | `{"userId":"x"}` | 最大 5 項目、フラットな構造 |
| `cf-aig-cache-ttl` | キャッシュの有効期間 | `3600` | 秒単位。最小 60、最大 2592000（30 日） |
| `cf-aig-skip-cache` | キャッシュを使わない | `true` | - |
| `cf-aig-cache-key` | カスタムキャッシュキー | `my-key` | レスポンスごとに一意であること |
| `cf-aig-collect-log` | ログ記録をスキップ | `false` | デフォルト: true |
| `cf-aig-cache-status` | キャッシュのヒット／ミス | レスポンスのみ | `HIT` または `MISS` |

## このリファレンスの内容

| ファイル | 内容 |
|------|---------|
| [sdk-integration.md](./sdk-integration.md) | Vercel AI SDK、OpenAI SDK、Workers バインディングの実装パターン |
| [configuration.md](./configuration.md) | ダッシュボードでの設定、wrangler、API トークン |
| [features.md](./features.md) | キャッシュ、レート制限、ガードレール、DLP、BYOK、統合請求 |
| [dynamic-routing.md](./dynamic-routing.md) | フォールバック、A/B テスト、条件付きルーティング |
| [troubleshooting.md](./troubleshooting.md) | デバッグ、エラー、可観測性、注意点 |

## 読む順序

| タスク | ファイル |
|------|-------|
| 初回設定 | README + [configuration.md](./configuration.md) |
| SDK の統合 | README + [sdk-integration.md](./sdk-integration.md) |
| キャッシュの有効化 | README + [features.md](./features.md) |
| フォールバックの設定 | README + [dynamic-routing.md](./dynamic-routing.md) |
| エラーのデバッグ | README + [troubleshooting.md](./troubleshooting.md) |

## アーキテクチャ

AI Gateway は、アプリケーションと AI プロバイダーの間でプロキシとして機能します。

```
Your App → AI Gateway → AI Provider (OpenAI, Anthropic, etc.)
         ↓
    Analytics, Caching, Rate Limiting, Logging
```

**主な URL パターン:**
- 統合 API（OpenAI 互換）: `https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/compat/chat/completions`
- プロバイダー固有: `https://gateway.ai.cloudflare.com/v1/{account_id}/{gateway_id}/{provider}/{endpoint}`
- 動的ルート: モデルの代わりにルート名を使用: `dynamic/{route-name}`

## ゲートウェイの種類

1. **認証なしのゲートウェイ**: 誰でもアクセス可能（本番環境では非推奨）
2. **認証付きゲートウェイ**: Cloudflare API トークンを含む `cf-aig-authorization` ヘッダーが必要（推奨）

## プロバイダー認証の選択肢

1. **統合請求**: AI Gateway の請求を使って推論料金を支払う（キーレスモード。プロバイダーの API キーは不要）
2. **BYOK（キーの保存）**: プロバイダーの API キーを Cloudflare ダッシュボードに保存する
3. **リクエストヘッダー**: 各リクエストにプロバイダーの API キーを含める

## 関連スキル

- [Workers AI](../workers-ai/README.md) - `env.AI.run()` の詳細
- [Agents SDK](../agents-sdk/README.md) - ステートフルな AI の実装パターン
- [Vectorize](../vectorize/README.md) - 埋め込みを使った RAG の実装パターン

## リソース

- [公式ドキュメント](https://developers.cloudflare.com/ai-gateway/)
- [API リファレンス](https://developers.cloudflare.com/api/resources/ai_gateway/)
- [プロバイダー向けガイド](https://developers.cloudflare.com/ai-gateway/usage/providers/)
- [Discord コミュニティ](https://discord.cloudflare.com)
