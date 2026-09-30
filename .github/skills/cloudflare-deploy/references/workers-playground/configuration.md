# 設定

## はじめに

[workers.cloudflare.com/playground](https://workers.cloudflare.com/playground) にアクセスします。

- テストに**アカウントは不要**
- **CLI やローカル環境のセットアップは不要**
- コードは実際の Cloudflare Workers ランタイムで実行される
- URL でコードを共有できる（有効期限なし）

## Playground の制約

⚠️ **重要な制限事項**

| 制約 | Playground | 本番環境の Workers |
|------------|------------|-------------------|
| **モジュール形式** | ES モジュールのみ | ES モジュールまたは Service Worker |
| **TypeScript** | 非対応（JS のみ） | ビルド手順を通じて対応 |
| **バインディング** | 利用不可 | KV、D1、R2、Durable Objects など |
| **wrangler.toml** | 使用しない | 設定に必要 |
| **環境変数** | 利用不可 | 完全対応 |
| **シークレット** | 利用不可 | 完全対応 |
| **カスタムドメイン** | 利用不可 | 完全対応 |

**Playground は迅速なプロトタイピング専用です。** 本番アプリには `wrangler` CLI を使用してください。

## コードエディター

### 構文要件

`fetch` ハンドラーを持つオブジェクトを default export する必要があります。

```javascript
export default {
  async fetch(request, env, ctx) {
    return new Response('Hello World');
  }
};
```

**要点:**
- ES モジュール（`export default`）を使用する必要がある
- `fetch` メソッドは `(request, env, ctx)` を受け取る
- `Response` オブジェクトを返す必要がある
- TypeScript は非対応（プレーンな JavaScript を使用）

### 複数モジュールのコード

外部 URL またはインラインモジュールからインポートできます。

```javascript
// Import from CDN
import { Hono } from 'https://esm.sh/hono@3';

// Or paste library code and import relatively
// (See patterns.md for multi-module examples)

export default {
  async fetch(request) {
    const app = new Hono();
    app.get('/', (c) => c.text('Hello'));
    return app.fetch(request);
  }
};
```

## プレビュー パネル

### ブラウザータブ

アドレスバー付きの既定の対話型プレビュー:
- 任意の URL パスを入力
- コード変更時に自動で再読み込み
- DevTools を利用可能（右クリック → 検証）

### HTTP テストパネル

生の HTTP テストを行うには **HTTP** タブに切り替えます:
- HTTP メソッドを変更（GET、POST、PUT、DELETE、PATCH など）
- リクエストヘッダーを追加・編集
- リクエストボディを変更（JSON、フォームデータ、テキスト）
- レスポンスヘッダーと本文を表示
- さまざまなコンテンツタイプをテスト

HTTP テストの例:
```
Method: POST
URL: /api/users
Headers:
  Content-Type: application/json
  Authorization: Bearer token123
Body:
{
  "name": "Alice",
  "email": "alice@example.com"
}
```

## コードの共有

**Copy Link** ボタンで共有可能な URL を生成します:
- コードは URL フラグメントに埋め込まれる
- リンクに有効期限はない
- アカウントは不要
- 後で使えるようブックマーク可能

例: `https://workers.cloudflare.com/playground#abc123...`

## Playground からのデプロイ

**Deploy** ボタンをクリックして、本番環境にコードを移します:

1. Cloudflare アカウントに**ログイン**（必要に応じて無料アカウントを作成）
2. Worker 名とコードを**確認**
3. グローバルネットワークに**デプロイ**（約 30 秒）
4. **URL を取得**: `<name>.workers.dev` サブドメインにデプロイ
5. ダッシュボードから**管理**: バインディング、カスタムドメイン、分析機能を追加

**デプロイ後:**
- コードは Cloudflare のグローバルネットワーク（300 以上の都市）で実行される
- KV、D1、R2、Durable Objects のバインディングを追加可能
- カスタムドメインとルートを設定可能
- 分析情報とログを表示可能
- 環境変数とシークレットを設定可能

**注:** デプロイされた Workers は本番環境で使用できますが、Free プラン（1 日あたり 100,000 リクエスト）で開始します。

## ブラウザー互換性

| ブラウザー | 状態 | 備考 |
|---------|--------|-------|
| Chrome/Edge | ✅ 完全対応 | 推奨 |
| Firefox | ✅ 完全対応 | 問題なく動作 |
| Safari | ⚠️ 動作不良 | プレビューで「PreviewRequestFailed」が発生 |

**Safari ユーザー:** Workers Playground では Chrome、Firefox、または Edge を使用してください。

## DevTools との連携

1. ブラウザータブで**プレビューを開く**
2. **右クリック** → 要素を検証
3. **Console タブ**に Worker のログが表示される:
   - `console.log()` の出力
   - 捕捉されていないエラー
   - ネットワークリクエスト（サブリクエスト）

**注:** DevTools に表示されるのはクライアント側のコンソールで、Worker の実行ログではありません。本番環境のログには Logpush または Tail Workers を使用してください。

## Playground の制限値

本番環境の Free プランと同じです:

| リソース | 上限 | 備考 |
|----------|-------|-------|
| CPU 時間 | 10ms | リクエストごと |
| メモリ | 128 MB | リクエストごと |
| スクリプトサイズ | 1 MB | 圧縮後 |
| サブリクエスト | 50 | 外部への fetch 呼び出し |
| リクエストサイズ | 100 MB | 受信 |
| レスポンスサイズ | 無制限 | 送信（ストリーミング） |

**CPU 時間の上限を超えると**、直ちにエラーが発生します。頻繁に実行される処理を最適化するか、Paid プラン（CPU 時間 50ms）にアップグレードしてください。
