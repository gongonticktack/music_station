# C3 (create-cloudflare)

テンプレート、TypeScript、即時デプロイに対応した、Cloudflare Workers および Pages プロジェクトのスキャフォールディングを行う公式 CLI です。

## クイックスタート

```bash
# Interactive (recommended for first-time)
npm create cloudflare@latest my-app

# Worker (API/WebSocket/Cron)
npm create cloudflare@latest my-api -- --type=hello-world --ts

# Pages (static/SSG/full-stack)
npm create cloudflare@latest my-site -- --type=web-app --framework=astro --platform=pages
```

## プラットフォーム選択フロー

```
What are you building?

├─ API / WebSocket / Cron / Email handler
│   └─ Workers (default) - no --platform flag needed
│       npm create cloudflare@latest my-api -- --type=hello-world

├─ Static site / SSG / Documentation
│   └─ Pages - requires --platform=pages
│       npm create cloudflare@latest my-site -- --type=web-app --framework=astro --platform=pages

├─ Full-stack app (Next.js/Remix/SvelteKit)
│   ├─ Need Durable Objects, Queues, or Workers-only features?
│   │   └─ Workers (default)
│   └─ Otherwise use Pages for git integration and branch previews
│       └─ Add --platform=pages

└─ Convert existing project
    └─ npm create cloudflare@latest . -- --type=pre-existing --existing-script=./src/worker.ts
```

**重要:** Pages プロジェクトでは `--platform=pages` フラグが必要です。指定しない場合、C3 はデフォルトで Workers を選択します。

## 対話型フロー

フラグを指定せずに実行すると、C3 は次の順序で質問します:

1. **プロジェクト名** - 作成するディレクトリ (`.` を指定すると現在のディレクトリがデフォルト)
2. **アプリケーションの種類** - `hello-world`、`web-app`、`demo`、`pre-existing`、`remote-template`
3. **プラットフォーム** - `workers` (デフォルト) または `pages` (Web アプリの場合のみ)
4. **フレームワーク** - web-app の場合: `next`、`remix`、`astro`、`react-router`、`solid`、`svelte` など
5. **TypeScript** - `yes` (推奨) または `no`
6. **Git** - リポジトリを初期化しますか？ `yes` または `no`
7. **デプロイ** - 今すぐデプロイしますか？ `yes` または `no` (`wrangler login` が必要)

## インストール方法

```bash
# NPM
npm create cloudflare@latest

# Yarn
yarn create cloudflare

# PNPM
pnpm create cloudflare@latest
```

## このリファレンスの内容

| ファイル | 目的 | 使用する場面 |
|------|---------|----------|
| **api.md** | CLI フラグの完全なリファレンス | スクリプト作成、CI/CD、高度な使い方 |
| **configuration.md** | 生成ファイル、バインディング、型 | 出力の理解、カスタマイズ |
| **patterns.md** | ワークフロー、CI/CD、モノレポ | 実用的な連携 |
| **gotchas.md** | 問題のトラブルシューティング | デプロイがブロックされた場合、エラーが発生した場合 |

## 読む順序

| 作業 | 読むファイル |
|------|------|
| 初めてのプロジェクトを作成する | README のみ |
| CI/CD を設定する | README → api → patterns |
| デプロイ失敗をデバッグする | gotchas |
| 生成ファイルを理解する | configuration |
| CLI の全リファレンスを確認する | api |
| カスタムテンプレートを作成する | patterns → configuration |
| 既存プロジェクトを変換する | README → patterns |

## 作成後

```bash
cd my-app

# Local dev with hot reload
npm run dev

# Generate TypeScript types for bindings
npm run cf-typegen

# Deploy to Cloudflare
npm run deploy
```

## 関連項目

- **workers/README.md** - Workers ランタイム、バインディング、API
- **workers-ai/README.md** - AI/ML モデル
- **pages/README.md** - Pages 固有の機能
- **wrangler/README.md** - 初期設定後に使う Wrangler CLI
- **d1/README.md** - SQLite データベース
- **r2/README.md** - オブジェクトストレージ