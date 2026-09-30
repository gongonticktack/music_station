# Cloudflare Pages Functions

Workers ランタイムを使用して Cloudflare Pages 上で動作するサーバーレス関数です。ファイルベースのルーティングによるフルスタック開発が可能です。

## クイックナビゲーション

**次の操作を行うには...**
| タスク | 参照先 |
|------|-------|
| TypeScript の型を設定する | [configuration.md](./configuration.md) - TypeScript のセットアップ |
| バインディング（KV、D1、R2）を設定する | [configuration.md](./configuration.md) - wrangler.jsonc |
| リクエスト、環境、パラメーターにアクセスする | [api.md](./api.md) - EventContext |
| ミドルウェアまたは認証を追加する | [patterns.md](./patterns.md) - ミドルウェア、認証 |
| バックグラウンドタスク（waitUntil） | [patterns.md](./patterns.md) - バックグラウンドタスク |
| エラーをデバッグする、または制限を確認する | [gotchas.md](./gotchas.md) - よくあるエラー、制限 |

## 判定ツリー：これは Pages Functions ですか？

```
Need serverless backend? 
├─ Yes, for a static site → Pages Functions
├─ Yes, standalone API → Workers
└─ Just static hosting → Pages (no functions)

Have existing Worker?
├─ Complex routing logic → Use _worker.js (Advanced Mode)
└─ Simple routes → Migrate to /functions (File-Based)

Framework-based?
├─ Next.js/SvelteKit/Remix → Uses _worker.js automatically
└─ Vanilla/HTML/React SPA → Use /functions
```

## ファイルベースのルーティング

```
/functions
  ├── index.js              → /
  ├── api.js                → /api
  ├── users/
  │   ├── index.js          → /users/
  │   ├── [user].js         → /users/:user
  │   └── [[catchall]].js   → /users/*
  └── _middleware.js        → runs on all routes
```

**ルール：**
- `index.js` → ディレクトリのルート
- 末尾のスラッシュは省略可能
- 個別のルートがキャッチオールより優先されます
- 一致しない場合は静的コンテンツにフォールバックします

## 動的ルート

**単一セグメント** `[param]` → 文字列：
```js
// /functions/users/[user].js
export function onRequest(context) {
  return new Response(`Hello ${context.params.user}`);
}
// Matches: /users/nevi
```

**複数セグメント** `[[param]]` → 配列：
```js
// /functions/users/[[catchall]].js
export function onRequest(context) {
  return new Response(JSON.stringify(context.params.catchall));
}
// Matches: /users/nevi/foobar → ["nevi", "foobar"]
```

## 主な機能

- **メソッドハンドラー：** `onRequestGet`、`onRequestPost` など
- **ミドルウェア：** 横断的な処理には `_middleware.js` を使用
- **バインディング：** KV、D1、R2、Durable Objects、Workers AI、サービスバインディング
- **TypeScript：** `wrangler types` コマンドによる完全な型サポート
- **アドバンスモード：** カスタムルーティングロジックには `_worker.js` を使用

## 読む順序

**Pages Functions を初めて使う場合：** ここから始めてください。
1. [README.md](./README.md) - 概要、ルーティング、判定ツリー（現在のページ）
2. [configuration.md](./configuration.md) - TypeScript のセットアップ、wrangler.jsonc、バインディング
3. [api.md](./api.md) - EventContext、ハンドラー、バインディングのリファレンス
4. [patterns.md](./patterns.md) - ミドルウェア、認証、CORS、レート制限、キャッシュ
5. [gotchas.md](./gotchas.md) - よくあるエラー、デバッグ、制限

**クイックリファレンス：**
- バインディングの表 → [api.md](./api.md)
- エラーの診断 → [gotchas.md](./gotchas.md)
- TypeScript のセットアップ → [configuration.md](./configuration.md)

## 関連項目
- [pages](../pages/) - Pages プラットフォームの概要と静的サイトのデプロイ
- [workers](../workers/) - Workers ランタイム API リファレンス
- [d1](../d1/) - Pages Functions と D1 データベースの統合