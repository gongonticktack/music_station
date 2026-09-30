# C3 のトラブルシューティング

## デプロイの問題

### プレースホルダー ID

**エラー:** "Invalid namespace ID"  
**修正方法:** wrangler.jsonc 内のプレースホルダーを実際の ID に置き換えます:
```bash
npx wrangler kv namespace create MY_KV  # Get real ID
```

### 認証

**エラー:** "Not authenticated"  
**修正方法:** `npx wrangler login` を実行するか、`CLOUDFLARE_API_TOKEN` を設定します。

### 名前の競合

**エラー:** "Worker already exists"  
**修正方法:** wrangler.jsonc の `name` を変更します。

## プラットフォームの選択

| 必要なもの | プラットフォーム |
|------|----------|
| Git 連携、ブランチのプレビュー | `--platform=pages` |
| Durable Objects、D1、Queues | Workers (デフォルト) |

プラットフォームを間違えた場合は、正しい `--platform` フラグを指定して作り直します。

## TypeScript の問題

**"Cannot find name 'KVNamespace'"**
```bash
npm run cf-typegen  # Regenerate types
# Restart TS server in editor
```

**設定変更後に型が見つからない:** `npm run cf-typegen` を再実行します。

## パッケージマネージャー

**複数のロックファイルによる問題:**
```bash
rm pnpm-lock.yaml  # If using npm
rm package-lock.json  # If using pnpm
```

## CI/CD

**CI がプロンプトで停止する:**
```bash
npm create cloudflare@latest my-app -- \
  --type=hello-world --lang=ts --no-git --no-deploy
```

**CI での認証:**
```yaml
env:
  CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
  CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

## フレームワーク固有

| フレームワーク | 問題 | 修正方法 |
|-----------|-------|-----|
| Next.js | create-next-app が失敗する | `npm cache clean --force` を実行し、再試行する |
| Astro | アダプターが見つからない | `@astrojs/cloudflare` をインストールする |
| Remix | モジュールエラー | `@remix-run/cloudflare*` を更新する |

## 互換性日付

**"Feature X requires compatibility_date >= ..."**  
**修正方法:** wrangler.jsonc の `compatibility_date` を今日の日付に更新します。

## Node.js のバージョン

**"Node.js version not supported"**  
**修正方法:** Node.js 18 以降をインストールします (`nvm install 20`)。

## クイックリファレンス

| エラー | 原因 | 修正方法 |
|-------|-------|-----|
| Invalid namespace ID | プレースホルダーのバインディング | リソースを作成し、設定を更新する |
| Not authenticated | ログインしていない | `npx wrangler login` |
| Cannot find KVNamespace | 型がない | `npm run cf-typegen` |
| Worker already exists | 名前の競合 | `name` を変更する |
| CI hangs | フラグが不足している | --type、--lang、--no-deploy を追加する |
| Template not found | 名前が正しくない | cloudflare/templates を確認する |