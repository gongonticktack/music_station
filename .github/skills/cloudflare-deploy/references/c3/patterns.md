# C3 の使用パターン

## クイックワークフロー

```bash
# TypeScript API Worker
npm create cloudflare@latest my-api -- --type=hello-world --lang=ts --deploy

# Next.js on Pages
npm create cloudflare@latest my-app -- --type=web-app --framework=next --platform=pages --ts --deploy

# Astro static site  
npm create cloudflare@latest my-blog -- --type=web-app --framework=astro --platform=pages --ts
```

## CI/CD (GitHub Actions)

```yaml
- name: Deploy
  run: npm run deploy
  env:
    CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

**非対話型で実行する場合に必要:**
```bash
--type=<value>       # Required
--no-git             # Recommended (CI already in git)
--no-deploy          # Deploy separately with secrets
--framework=<value>  # For web-app
--ts / --no-ts       # Required
```

## モノレポ

C3 はワークスペース設定 (`package.json` の workspaces または `pnpm-workspace.yaml`) を検出します。

```bash
cd packages/
npm create cloudflare@latest my-worker -- --type=hello-world --lang=ts --no-deploy
```

## カスタムテンプレート

```bash
# GitHub repo
npm create cloudflare@latest -- --template=username/repo
npm create cloudflare@latest -- --template=cloudflare/templates/worker-openapi

# Local path
npm create cloudflare@latest my-app -- --template=../my-template
```

**テンプレートには `c3.config.json` が必要:**
```json
{
  "name": "my-template",
  "category": "hello-world",
  "copies": [{ "path": "src/" }, { "path": "wrangler.jsonc" }],
  "transforms": [{ "path": "package.json", "jsonc": { "name": "{{projectName}}" }}]
}
```

## 既存プロジェクト

```bash
# Add Cloudflare to existing Worker
npm create cloudflare@latest . -- --type=pre-existing --existing-script=./dist/index.js

# Add to existing framework app
npm create cloudflare@latest . -- --type=web-app --framework=next --platform=pages --ts
```

## 作成後のチェックリスト

1. `wrangler.jsonc` を確認する - `compatibility_date` を設定し、`name` を検証する
2. バインディングを作成する: `wrangler kv namespace create`、`wrangler d1 create`、`wrangler r2 bucket create`
3. 型を生成する: `npm run cf-typegen`
4. テストする: `npm run dev`
5. デプロイする: `npm run deploy`
6. シークレットを設定する: `wrangler secret put SECRET_NAME`