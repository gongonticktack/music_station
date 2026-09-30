# AI Search の設定

## Worker の設定

```jsonc
// wrangler.jsonc
{
  "ai": { "binding": "AI" }
}
```

```typescript
interface Env {
  AI: Ai;
}

const answer = await env.AI.autorag("my-instance").aiSearch({
  query: "How do I configure caching?",
  model: "@cf/meta/llama-3.3-70b-instruct-fp8-fast"
});
```

## データソース

### R2 バケット

ダッシュボード: AI Search → Create Instance → Select R2 bucket

**対応形式:** `.md`、`.txt`、`.html`、`.pdf`、`.doc`、`.docx`、`.csv`、`.json`

**自動的にインデックス化されるメタデータ:** `filename`、`folder`、`timestamp`

### ウェブサイトクローラー

要件:
- ドメインが Cloudflare 上にあること
- ルートに `sitemap.xml` があること
- ボット対策で `CloudflareAISearch` ユーザーエージェントを許可すること

## パスのフィルタリング（R2）

```
docs/**/*.md          # All .md in docs/ recursively
**/*.draft.md         # Exclude (use in exclude patterns)
```

## インデックス化

- **自動:** 6 時間ごと
- **強制同期:** ダッシュボードのボタン（同期の間隔には 30 秒のレート制限あり）
- **一時停止:** Settings → Pause Indexing（既存のインデックスは引き続き検索可能）

## Service API トークン

ダッシュボード: AI Search → Instance → Use AI Search → API → Create Token

権限:
- **Read** - 検索操作
- **Edit** - インスタンスの管理

安全に保管します:
```bash
wrangler secret put AI_SEARCH_TOKEN
```

## 複数環境

```toml
# wrangler.toml
[env.production.vars]
AI_SEARCH_INSTANCE = "prod-docs"

[env.staging.vars]
AI_SEARCH_INSTANCE = "staging-docs"
```

```typescript
const answer = await env.AI.autorag(env.AI_SEARCH_INSTANCE).aiSearch({ query });
```

## 監視

```typescript
const instances = await env.AI.autorag("_").listInstances();
console.log(instances.find(i => i.name === "docs"));
```

ダッシュボードには、インデックス化されたファイル数、ステータス、最終インデックス化時刻、ストレージ使用量が表示されます。
