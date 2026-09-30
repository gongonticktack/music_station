# Cloudflare Workers Playground スキルリファレンス

## 概要

Cloudflare Workers Playground は、認証やセットアップなしで Cloudflare Workers をすぐに試し、テストし、デプロイできるブラウザベースのサンドボックスです。このスキルでは、Workers Playground の開発に特化したパターン、API、ベストプラクティスを紹介します。

**URL:** [workers.cloudflare.com/playground](https://workers.cloudflare.com/playground)

## ⚠️ Playground の制約

**Playground は本番環境と同等ではありません:**
- ✅ 実際の Workers ランタイム、即時テスト、共有可能な URL
- ❌ TypeScript 非対応（JavaScript のみ）
- ❌ バインディング非対応（KV、D1、R2、Durable Objects）
- ❌ 環境変数やシークレット非対応
- ❌ ES モジュールのみ（Service Worker 形式は非対応）
- ⚠️ Safari では動作しません（Chrome または Firefox を使用してください）

**本番環境では:** `wrangler` CLI を使用してください。Playground は迅速なプロトタイピング向けです。

## クイックスタート

最小構成の Worker:

```javascript
export default {
  async fetch(request, env, ctx) {
    return new Response('Hello World');
  }
};
```

JSON API:

```javascript
export default {
  async fetch(request, env, ctx) {
    const data = { message: 'Hello', timestamp: Date.now() };
    return Response.json(data);
  }
};
```

変更を加えるプロキシ:

```javascript
export default {
  async fetch(request, env, ctx) {
    const response = await fetch('https://example.com');
    const modified = new Response(response.body, response);
    modified.headers.set('X-Custom-Header', 'added-by-worker');
    return modified;
  }
};
```

CDN からインポート:

```javascript
import { Hono } from 'https://esm.sh/hono@3';

export default {
  async fetch(request) {
    const app = new Hono();
    app.get('/', (c) => c.text('Hello Hono!'));
    return app.fetch(request);
  }
};
```

## 読む順序

1. **[configuration.md](configuration.md)** - まずはこちら: Playground のセットアップ、制約、デプロイ
2. **[api.md](api.md)** - コア API: Request、Response、ExecutionContext、fetch、Cache
3. **[patterns.md](patterns.md)** - 一般的な用途: ルーティング、プロキシ、A/B テスト、複数モジュールのコード
4. **[gotchas.md](gotchas.md)** - トラブルシューティング: エラー、ブラウザーの問題、制限、ベストプラクティス

## このリファレンスの内容

- **[configuration.md](configuration.md)** - セットアップ、デプロイ、設定
- **[api.md](api.md)** - API エンドポイント、メソッド、インターフェース
- **[patterns.md](patterns.md)** - よく使われるパターン、用途、例
- **[gotchas.md](gotchas.md)** - トラブルシューティング、ベストプラクティス、制限事項

## 主な機能

**セットアップ不要:**
- URL を開いてすぐにコーディングを開始
- CLI、アカウント、設定ファイルは不要
- コードは実際の Cloudflare Workers ランタイムで実行

**即時プレビュー:**
- ブラウザータブまたは HTTP テスターを備えたライブプレビューパネル
- コード変更時に自動再読み込み
- DevTools との連携（右クリック → 検証）

**共有とデプロイ:**
- Copy Link で永続的に共有可能な URL を生成
- Deploy ボタンで約 30 秒で本番環境に公開
- `*.workers.dev` サブドメインをすぐに取得

## よくある用途

- **API 開発:** wrangler のセットアップ前にエンドポイントをテスト
- **Workers の学習:** ローカル環境なしで API を試す
- **プロトタイピング:** エッジロジックの簡易 POC を作成
- **例の共有:** バグ報告やデモ用の共有リンクを生成
- **フレームワークのテスト:** CDN からインポート（Hono、itty-router など）

## 本番環境との違い

| 機能 | Playground | 本番環境（wrangler） |
|---------|------------|----------------------|
| 言語 | JavaScript のみ | JS + TypeScript |
| バインディング | なし | KV、D1、R2、DO、AI など |
| 環境変数 | なし | 完全対応 |
| モジュール形式 | ES のみ | ES + Service Worker |
| CPU 時間 | 10ms（Free プラン） | 10ms（Free）/ 50ms（Paid） |
| カスタムドメイン | なし | あり |
| 分析 | なし | あり |

## 関連項目

- [Cloudflare Workers Docs](https://developers.cloudflare.com/workers/)
- [Workers Examples](https://developers.cloudflare.com/workers/examples/)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/)
- [Workers API Reference](https://developers.cloudflare.com/workers/runtime-apis/)
