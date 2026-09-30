# よくある落とし穴とデバッグ

## エラーの診断

| 症状 | 考えられる原因 | 解決策 |
|---------|--------------|----------|
| **関数が呼び出されない** | `/functions` の場所が誤っている、拡張子が誤っている、または `_routes.json` でパスが除外されている | `pages_build_output_dir` を確認し、`.js`/`.ts` を使用して、`_routes.json` を検証する |
| **`ctx.env.BINDING` が undefined** | バインディングが設定されていない、または名前が一致しない | `wrangler.jsonc` に追加し、名前（大文字と小文字を区別）を正確に確認して、再デプロイする |
| **`ctx.env` で TypeScript エラーが発生する** | 型定義がない | `wrangler types` を実行するか、`interface Env {}` を定義する |
| **ミドルウェアが実行されない** | ファイル名または場所が誤っている、あるいは `ctx.next()` がない | ファイル名を正確に `_middleware.js` とし、`onRequest` をエクスポートして、`ctx.next()` を呼び出す |
| **本番環境でシークレットが見つからない** | `.dev.vars` はデプロイされない | `.dev.vars` はローカル専用です。ダッシュボードまたは `wrangler secret put` で本番環境のシークレットを設定する |
| **バインディングの型が一致しない** | インターフェースの型が誤っている | 正しい型については [api.md](./api.md) のバインディング表を参照する |
| **「KV key not found」と表示されるが、キーは存在する** | キーが誤った名前空間または環境にある | 名前空間のバインディングを確認し、プレビュー環境と本番環境を確認する |
| **関数がタイムアウトする** | 同期処理で待機している、または `await` がない | すべてのI/Oを async/await で処理し、バックグラウンドタスクには `ctx.waitUntil()` を使用する |

## よくあるエラー

### TypeScript の型エラー

**問題:** `ctx.env.MY_BINDING` で型エラーが表示される  
**原因:** `Env` の型定義がない  
**解決策:** `npx wrangler types` を実行するか、次のように手動で定義する:
```typescript
interface Env { MY_BINDING: KVNamespace; }
export const onRequest: PagesFunction<Env> = async (ctx) => { /* ... */ };
```

### 本番環境でシークレットを利用できない

**問題:** 本番環境で `ctx.env.SECRET_KEY` が undefined になる  
**原因:** `.dev.vars` はローカル専用で、デプロイされない  
**解決策:** 本番環境のシークレットを設定する:
```bash
echo "value" | npx wrangler pages secret put SECRET_KEY --project-name=my-app
```

## デバッグ

```typescript
// Console logging
export async function onRequest(ctx) {
  console.log('Request:', ctx.request.method, ctx.request.url);
  const res = await ctx.next();
  console.log('Status:', res.status);
  return res;
}
```

```bash
# Stream real-time logs
npx wrangler pages deployment tail
npx wrangler pages deployment tail --status error
```

```jsonc
// Source maps (wrangler.jsonc)
{ "upload_source_maps": true }
```

## 制限

| リソース | 無料 | 有料 |
|----------|------|------|
| CPU時間 | 10ms | 50ms |
| メモリ | 128 MB | 128 MB |
| スクリプトサイズ | 圧縮時10 MB | 圧縮時10 MB |
| 環境変数 | 1変数あたり5 KB、最大64個 | 1変数あたり5 KB、最大64個 |
| リクエスト | 1日あたり100k | 無制限（100万件あたり$0.50） |

## ベストプラクティス

**パフォーマンス:** 依存関係を最小限に抑え（コールドスタート対策）、キャッシュにはKV、リレーショナルデータにはD1、大容量ファイルにはR2を使用し、`Cache-Control` ヘッダーを設定し、DB操作をまとめて実行し、エラーを適切に処理する

**セキュリティ:** シークレットを絶対にコミットしない（`.dev.vars` を使用し、gitignore に追加する）。入力を検証し、DBに渡す前にサニタイズし、認証ミドルウェアを実装し、CORSヘッダーを設定し、IPごとにレート制限する

## 移行

**Workers → Pages Functions:**
- `export default { fetch(req, env) {} }` → `export function onRequest(ctx) { const { request, env } = ctx; }`
- 複雑なルーティングには `_worker.js` を使用する。静的ファイルには `env.ASSETS.fetch(request)` を使用する

**他のプラットフォーム → Pages:**
- ファイルベースのルーティング: `/functions/api/users.js` → `/api/users`
- 動的ルート: `[param]` ではなく `:param` を使用する
- Node.js の依存関係を Workers API に置き換えるか、`nodejs_compat` フラグを追加する

## リソース

- [公式ドキュメント](https://developers.cloudflare.com/pages/functions/)
- [Workers API](https://developers.cloudflare.com/workers/runtime-apis/)
- [サンプル](https://github.com/cloudflare/pages-example-projects)
- [Discord](https://discord.gg/cloudflaredev)

**関連項目:** TypeScript の設定については [configuration.md](./configuration.md)、ミドルウェアと認証については [patterns.md](./patterns.md)、バインディングについては [api.md](./api.md) を参照してください。