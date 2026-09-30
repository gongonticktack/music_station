# Cloudflare Workers

Cloudflare Workers アプリケーションの構築、デプロイ、最適化に関する専門的なガイダンス。

## 概要

Cloudflare Workers は V8 アイソレート上で実行されます（コンテナ／VM ではありません）。
- コールドスタートが非常に高速（1 ミリ秒未満）
- 300 以上の拠点にグローバル展開
- Web 標準に準拠（fetch、URL、Headers、Request、Response）
- JS/TS、Python、Rust、WebAssembly をサポート

**重要な原則**: Workers は、移植性を高めるため、可能な限り Web プラットフォーム API を使用します。

## Module Worker パターン（推奨）

```typescript
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    return new Response('Hello World!');
  },
};
```

**ハンドラーのパラメーター**:
- `request`: 受信した HTTP リクエスト（標準の Request オブジェクト）
- `env`: 環境バインディング（KV、D1、R2、シークレット、変数）
- `ctx`: 実行コンテキスト（`waitUntil`、`passThroughOnException`）

## 基本的なコマンド

```bash
npx wrangler dev                    # Local dev
npx wrangler dev --remote           # Remote dev (actual resources)
npx wrangler deploy                 # Production
npx wrangler deploy --env staging   # Specific environment
npx wrangler tail                   # Stream logs
npx wrangler secret put API_KEY     # Set secret
```

## Workers を使用する場面

- エッジでの API エンドポイント
- リクエスト／レスポンスの変換
- 認証／認可レイヤー
- 静的アセットの最適化
- A/B テストと機能フラグ
- レート制限とセキュリティ
- プロキシ／ルーティングロジック
- WebSocket アプリケーション

## クイックスタート

```bash
npm create cloudflare@latest my-worker -- --type hello-world
cd my-worker
npx wrangler dev
```

## ハンドラーのシグネチャ

```typescript
// HTTP requests
async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response>

// Cron triggers
async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void>

// Queue consumer
async queue(batch: MessageBatch, env: Env, ctx: ExecutionContext): Promise<void>

// Tail consumer
async tail(events: TraceItem[], env: Env, ctx: ExecutionContext): Promise<void>
```

## リソース

**ドキュメント**: https://developers.cloudflare.com/workers/  
**例**: https://developers.cloudflare.com/workers/examples/  
**ランタイム API**: https://developers.cloudflare.com/workers/runtime-apis/

## このリファレンスについて

- [設定](./configuration.md) - wrangler.jsonc のセットアップ、バインディング、環境
- [API](./api.md) - ランタイム API、バインディング、実行コンテキスト
- [パターン](./patterns.md) - 一般的なワークフロー、テスト、最適化
- [フレームワーク](./frameworks.md) - Hono、ルーティング、バリデーション
- [注意点](./gotchas.md) - よくある問題、制限、トラブルシューティング

## 読む順序

| タスク | 最初に読む | 次に読む |
|------|------------|-----------|
| 初めての Worker | README → 設定 → API | パターン |
| フレームワークを追加する | フレームワーク | 設定（バインディング） |
| ストレージ／バインディングを追加する | 設定 → API（バインディングの使用方法） | 「関連項目」のリンクを参照 |
| 問題をデバッグする | 注意点 | API（該当するバインディングのドキュメント） |
| 本番環境で最適化する | パターン | API（キャッシュ、ストリーミング） |
| 型安全性 | 設定（TypeScript） | フレームワーク（Hono の型付け） |

## 関連項目

- [KV](../kv/README.md) - キーと値のストレージ
- [D1](../d1/README.md) - SQL データベース
- [R2](../r2/README.md) - オブジェクトストレージ
- [Durable Objects](../durable-objects/README.md) - 状態を持つ連携機能
- [Queues](../queues/README.md) - メッセージキュー
- [Wrangler](../wrangler/README.md) - CLI ツールのリファレンス
