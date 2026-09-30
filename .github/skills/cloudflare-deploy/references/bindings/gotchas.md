# バインディングの注意点とトラブルシューティング

## 重大な注意点：グローバルスコープの変更

### ❌ 最大の落とし穴：env をグローバルスコープにキャッシュする

```typescript
// ❌ DANGEROUS - env cached at deploy time
const apiKey = env.API_KEY;  // ERROR: env not available in global scope

export default {
  async fetch(request: Request, env: Env) {
    // Uses undefined or stale value!
  }
}
```

**動作しない理由:**
- `env` はグローバルスコープでは利用できない
- 回避策を使うと、再デプロイするまでシークレットが更新されないことがある
- 「Cannot read property 'X' of undefined」エラーが発生する

**✅ リクエストごとに必ず env にアクセスする:**
```typescript
export default {
  async fetch(request: Request, env: Env) {
    const apiKey = env.API_KEY;  // Fresh every request
  }
}
```

## よくあるエラー

### 「env.MY_KV is undefined」

**原因:** 名前の不一致、または未設定  
**解決策:** wrangler.jsonc を確認する（大文字と小文字を区別）、`npx wrangler types` を実行し、`npx wrangler kv namespace list` で確認する

### 「Property 'MY_KV' does not exist on type 'Env'」

**原因:** 型が生成されていない  
**解決策:** `npx wrangler types`

### 「preview_id is required for --remote」

**原因:** プレビュー用バインディングが不足している  
**解決策:** `"preview_id": "dev-id"` を追加するか、`npx wrangler dev`（ローカルモード）を使う

### 「Secret updated but Worker still uses old value」

**原因:** グローバルスコープにキャッシュされている、または再デプロイしていない  
**解決策:** グローバルキャッシュを避け、シークレット変更後に再デプロイする

### 「KV get() returns null for existing key」

**原因:** 結果整合性（60秒）、名前空間の誤り、環境の誤り  
**解決策:**
```bash
# Check key exists
npx wrangler kv key get --binding=MY_KV "your-key"

# Verify namespace ID
npx wrangler kv namespace list

# Check environment
npx wrangler deployments list
```

### 「D1 database not found」

**解決策:** `npx wrangler d1 list` を実行し、wrangler.jsonc の ID を確認する

### 「Service binding returns 'No such service'」

**原因:** 対象の Worker がデプロイされていない、名前の不一致、環境の不一致  
**解決策:**
```bash
# List deployed Workers
npx wrangler deployments list --name=target-worker

# Check service binding config
cat wrangler.jsonc | grep -A2 services

# Deploy target first
cd ../target-worker && npx wrangler deploy
```

### KV 書き込み時の「Rate limit exceeded」

**原因:** キーごとに毎秒 1 回を超える書き込み  
**解決策:** 別のキー、Durable Objects、または Queues を使う

## 型安全性に関する注意点

### @cloudflare/workers-types が見つからない

**エラー:** `Cannot find name 'Request'`  
**解決策:** `npm install -D @cloudflare/workers-types` を実行し、tsconfig.json の `"types"` に追加する

### バインディングの型の不一致

```typescript
// ❌ Wrong - KV returns string | null
const value: string = await env.MY_KV.get('key');

// ✅ Handle null
const value = await env.MY_KV.get('key');
if (!value) return new Response('Not found', { status: 404 });
```

## 環境に関する注意点

### 誤った環境へのデプロイ

**解決策:** `npx wrangler deployments list` で確認し、`--env` フラグを使う

### シークレットが環境ごとに設定されていない

**解決策:** 環境ごとに設定する: `npx wrangler secret put API_KEY --env staging`

## 開発に関する注意点

**wrangler dev と deploy の違い:**
- dev: `preview_id` またはローカルバインディングを使用。シークレットは利用できない
- deploy: 本番の `id` を使用。シークレットを利用できる

**dev でシークレットにアクセス:** `npx wrangler dev --remote`  
**ローカルデータを保持:** `npx wrangler dev --persist`

## パフォーマンスに関する注意点

### バインディング呼び出しの逐次実行

```typescript
// ❌ Slow
const user = await env.DB.prepare('...').first();
const config = await env.MY_KV.get('config');

// ✅ Parallel
const [user, config] = await Promise.all([
  env.DB.prepare('...').first(),
  env.MY_KV.get('config')
]);
```

## セキュリティに関する注意点

**❌ ログへのシークレット出力:** `console.log('Key:', env.API_KEY)` - ダッシュボードで見える  
**✅** `console.log('Key:', env.API_KEY ? '***' : 'missing')`

**❌ env の公開:** `return Response.json(env)` - すべてのバインディングを公開する  
**✅** レスポンスで env オブジェクトを返さない

## 制限事項一覧

| リソース | 制限 | 影響 | プラン |
|----------|-------|--------|------|
| **Worker あたりのバインディング** | 合計 64 個 | すべての種類のバインディングを合算 | All |
| **環境変数** | 最大 64 個、各 5KB | Worker ごと | All |
| **シークレットのサイズ** | 1KB | シークレットあたり | All |
| **KV キーのサイズ** | 512 bytes | UTF-8 エンコード | All |
| **KV 値のサイズ** | 25 MB | 値あたり | All |
| **キーあたりの KV 書き込み** | 1 回/秒 | キーあたり。超過すると 429 エラー | All |
| **KV list() の結果** | 1000 キー | 呼び出しあたり。続きにはカーソルを使う | All |
| **KV 操作** | 1 日あたり 1000 回の読み取り | 無料プランのみ | Free |
| **R2 オブジェクトのサイズ** | 5 TB | オブジェクトあたり | All |
| **R2 操作** | 月 100 万回の Class A 操作まで無料 | 書き込み | All |
| **D1 データベースのサイズ** | 10 GB | データベースあたり | All |
| **D1 クエリあたりの行数** | 100,000 | 結果セットの上限 | All |
| **D1 データベース数** | 10 個 | 無料プラン | Free |
| **キューのバッチサイズ** | 100 メッセージ | コンシューマーバッチあたり | All |
| **キューメッセージのサイズ** | 128 KB | メッセージあたり | All |
| **サービスバインディングの呼び出し** | 無制限 | CPU 時間に算入 | All |
| **Durable Objects** | 月 100 万リクエストまで無料 | 最初の 100 万件 | Free |

## デバッグのヒント

```bash
# Check configuration
npx wrangler deploy --dry-run       # Validate config without deploying
npx wrangler kv namespace list      # List KV namespaces
npx wrangler secret list            # List secrets (not values)
npx wrangler deployments list       # Recent deployments

# Inspect bindings
npx wrangler kv key list --binding=MY_KV
npx wrangler kv key get --binding=MY_KV "key-name"
npx wrangler r2 object get my-bucket/file.txt
npx wrangler d1 execute my-db --command="SELECT * FROM sqlite_master"

# Test locally
npx wrangler dev                  # Local mode
npx wrangler dev --remote         # Production bindings
npx wrangler dev --persist        # Persist data across restarts

# Verify types
npx wrangler types
cat .wrangler/types/runtime.d.ts | grep "interface Env"

# Debug specific binding issues
npx wrangler tail                 # Stream logs in real-time
npx wrangler tail --format=pretty # Formatted logs
```

## 関連項目

- [Workers Limits](https://developers.cloudflare.com/workers/platform/limits/)
- [Wrangler Commands](https://developers.cloudflare.com/workers/wrangler/commands/)
