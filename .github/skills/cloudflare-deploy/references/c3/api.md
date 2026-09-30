# C3 CLI リファレンス

## 起動方法

```bash
npm create cloudflare@latest [name] [-- flags]  # NPM requires --
yarn create cloudflare [name] [flags]
pnpm create cloudflare@latest [name] [-- flags]
```

## 基本フラグ

| フラグ | 値 | 説明 |
|------|--------|-------------|
| `--type` | `hello-world`, `web-app`, `demo`, `pre-existing`, `remote-template` | アプリケーションの種類 |
| `--platform` | `workers` (デフォルト), `pages` | 対象プラットフォーム |
| `--framework` | `next`, `remix`, `astro`, `react-router`, `solid`, `svelte`, `qwik`, `vue`, `angular`, `hono` | Web フレームワーク (`--type=web-app` が必要) |
| `--lang` | `ts`, `js`, `python` | 言語 (`--type=hello-world` の場合) |
| `--ts` / `--no-ts` | - | Web アプリで TypeScript を使用するかどうか |

## デプロイ用フラグ

| フラグ | 説明 |
|------|-------------|
| `--deploy` / `--no-deploy` | すぐにデプロイする (対話型では確認を求め、CI ではスキップ) |
| `--git` / `--no-git` | git を初期化する (デフォルト: はい) |
| `--open` | デプロイ後にブラウザーを開く |

## 高度なフラグ

| フラグ | 説明 |
|------|-------------|
| `--template=user/repo` | GitHub テンプレートまたはローカルパス |
| `--existing-script=./src/worker.ts` | 既存のスクリプト (`--type=pre-existing` が必要) |
| `--category=ai\|database\|realtime` | デモの絞り込み (`--type=demo` が必要) |
| `--experimental` | 実験的な機能を有効にする |
| `--wrangler-defaults` | Wrangler の確認をスキップする |

## 環境変数

```bash
CLOUDFLARE_API_TOKEN=xxx    # For deployment
CLOUDFLARE_ACCOUNT_ID=xxx   # Account ID
CF_TELEMETRY_DISABLED=1     # Disable telemetry
```

## 終了コード

`0` 成功、`1` ユーザーによる中止、`2` エラー

## 例

```bash
# TypeScript Worker
npm create cloudflare@latest my-api -- --type=hello-world --lang=ts --no-deploy

# Next.js on Pages
npm create cloudflare@latest my-app -- --type=web-app --framework=next --platform=pages --ts

# Astro blog
npm create cloudflare@latest my-blog -- --type=web-app --framework=astro --ts --deploy

# CI: non-interactive
npm create cloudflare@latest my-app -- --type=web-app --framework=next --ts --no-git --no-deploy

# GitHub template
npm create cloudflare@latest -- --template=cloudflare/templates/worker-openapi

# Convert existing project
npm create cloudflare@latest . -- --type=pre-existing --existing-script=./build/worker.js
```