# C3 が生成する設定

## 出力構成

```
my-app/
├── src/index.ts          # Worker entry point
├── wrangler.jsonc        # Cloudflare config
├── package.json          # Scripts
├── tsconfig.json
└── .gitignore
```

## wrangler.jsonc

```jsonc
{
  "$schema": "https://raw.githubusercontent.com/cloudflare/workers-sdk/main/packages/wrangler/config-schema.json",
  "name": "my-app",
  "main": "src/index.ts",
  "compatibility_date": "2026-01-27"
}
```

## バインディングのプレースホルダー

C3 は、デプロイ前に置き換える必要がある**プレースホルダー ID**を生成します。

```jsonc
{
  "kv_namespaces": [{ "binding": "MY_KV", "id": "placeholder_kv_id" }],
  "d1_databases": [{ "binding": "DB", "database_id": "00000000-..." }]
}
```

**実際の ID に置き換える:**
```bash
npx wrangler kv namespace create MY_KV   # Returns real ID
npx wrangler d1 create my-database       # Returns real database_id
```

**置き換えない場合のデプロイエラー:**
```
Error: Invalid KV namespace ID "placeholder_kv_id"
```

## スクリプト

```json
{
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy",
    "cf-typegen": "wrangler types"
  }
}
```

## 型の生成

バインディングを追加した後に実行します:
```bash
npm run cf-typegen
```

`.wrangler/types/runtime.d.ts` を生成します:
```typescript
interface Env {
  MY_KV: KVNamespace;
  DB: D1Database;
}
```

## 作成後のチェックリスト

1. `wrangler.jsonc` を確認する - name と compatibility_date を確認
2. プレースホルダーのバインディング ID を実際のリソース ID に置き換える
3. `npm run cf-typegen` を実行する
4. テストする: `npm run dev`
5. デプロイする: `npm run deploy`
6. シークレットを追加する: `npx wrangler secret put SECRET_NAME`