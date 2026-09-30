# Cloudflare Pages

Cloudflare のグローバルネットワーク上でフルスタックアプリを構築するための JAMstack プラットフォーム。

## 主な機能

- **Git ベースのデプロイ**: GitHub/GitLab から自動デプロイ
- **プレビュー環境**: ブランチ/PR ごとに固有の URL を発行
- **Pages Functions**: ファイルベースのサーバーレスルーティング（Workers ランタイム）
- **静的 + 動的**: スマートなアセットキャッシュ + エッジコンピューティング
- **Smart Placement**: トラフィックパターンに基づいて関数を自動最適化
- **フレームワークに最適化**: SvelteKit、Astro、Nuxt、Qwik、Solid Start

## デプロイ方法

### 1. Git 統合（本番環境）
ダッシュボード → Workers & Pages → Create → Connect to Git → Configure build

### 2. 直接アップロード
```bash
npx wrangler pages deploy ./dist --project-name=my-project
npx wrangler pages deploy ./dist --project-name=my-project --branch=staging
```

### 3. C3 CLI
```bash
npm create cloudflare@latest my-app
# Select framework → auto-setup + deploy
```

## Workers との比較

- **Pages**: 静的サイト、JAMstack、フレームワーク、Git ワークフロー、ファイルベースのルーティング
- **Workers**: 独立した API、複雑なルーティング、WebSocket、スケジュールされたタスク、メールハンドラー
- **組み合わせ**: Pages Functions は Workers ランタイムを使用し、Workers にバインドできます

## クイックスタート

```bash
# Create
npm create cloudflare@latest

# Local dev
npx wrangler pages dev ./dist

# Deploy
npx wrangler pages deploy ./dist --project-name=my-project

# Types
npx wrangler types --path='./functions/types.d.ts'

# Secrets
echo "value" | npx wrangler pages secret put KEY --project-name=my-project

# Logs
npx wrangler pages deployment tail --project-name=my-project
```

## リソース

- [Pages ドキュメント](https://developers.cloudflare.com/pages/)
- [Functions API](https://developers.cloudflare.com/pages/functions/api-reference/)
- [フレームワークガイド](https://developers.cloudflare.com/pages/framework-guides/)
- [Discord #functions](https://discord.com/channels/595317990191398933/910978223968518144)

## 読む順序

**Pages を初めて使う場合**: ここから始めてください。
1. README.md（このファイル） - 概要とクイックスタート
2. [configuration.md](./configuration.md) - プロジェクト設定、wrangler.jsonc、バインディング
3. [api.md](./api.md) - Functions API、ルーティング、コンテキスト
4. [patterns.md](./patterns.md) - 一般的な実装
5. [gotchas.md](./gotchas.md) - トラブルシューティングと注意点

**クイックリファレンスが必要な場合**: 上記から該当するファイルに進んでください。

## このリファレンスの内容

- [configuration.md](./configuration.md) - wrangler.jsonc、ビルド、環境変数、Smart Placement
- [api.md](./api.md) - Functions API、バインディング、コンテキスト、高度なモード
- [patterns.md](./patterns.md) - フルスタックのパターン、フレームワーク統合
- [gotchas.md](./gotchas.md) - ビルドの問題、制限、デバッグ、フレームワークに関する注意

## 関連項目

- [pages-functions](../pages-functions/) - ファイルベースのルーティング、ミドルウェア
- [d1](../d1/) - Pages Functions 向け SQL データベース
- [kv](../kv/) - キャッシュ/状態管理用のキー・バリューストレージ