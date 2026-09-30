# 設定とセットアップ

## インストール

```bash
npm install @cloudflare/puppeteer  # or @cloudflare/playwright
```

**Cloudflare のパッケージを使用してください** - 標準の `puppeteer`/`playwright` は Workers では動作しません。

## wrangler.json

```json
{
  "name": "browser-worker",
  "main": "src/index.ts",
  "compatibility_date": "2025-01-01",
  "compatibility_flags": ["nodejs_compat"],
  "browser": {
    "binding": "MYBROWSER"
  }
}
```

**必須:** `nodejs_compat` フラグと `browser.binding`。

## TypeScript

```typescript
interface Env {
  MYBROWSER: Fetcher;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // ...
  }
} satisfies ExportedHandler<Env>;
```

## 開発

```bash
wrangler dev --remote  # --remote required for browser binding
```

**ローカルモードでは Browser Rendering はサポートされません** - `--remote` を使用する必要があります。

## REST API

wrangler の設定は不要です。「Browser Rendering - Edit」権限を持つ API トークンを取得してください。

```bash
curl -X POST \
  'https://api.cloudflare.com/client/v4/accounts/{accountId}/browser-rendering/screenshot' \
  -H 'Authorization: Bearer TOKEN' \
  -d '{"url": "https://example.com"}' --output screenshot.png
```

## 要件

| 要件 | 値 |
|-------------|-------|
| Node.js 互換性 | `nodejs_compat` フラグ |
| 互換性日付 | 2023-03-01 以降 |
| モジュール形式 | ES modules のみ |
| ブラウザー | Chromium 119 以降（Firefox/Safari は非対応）|

**非対応:** WebGL、WebRTC、拡張機能、`file://` プロトコル、Service Worker 構文。

## トラブルシューティング

| エラー | 解決策 |
|-------|----------|
| `MYBROWSER is undefined` | `wrangler dev --remote` を使用 |
| `nodejs_compat not enabled` | `compatibility_flags` に追加 |
| `Module not found` | `npm install @cloudflare/puppeteer` |
| `Browser Rendering not available` | ダッシュボードで有効化 |
