# よくある問題

## Functions が実行されない

**問題**: Function のエンドポイントが 404 を返す、または実行されない  
**原因**: `_routes.json` でパスが除外されている、ファイル拡張子が誤っている（`.jsx`/`.tsx`）、Functions ディレクトリが出力ルートにない  
**解決策**: `_routes.json` を確認し、拡張子を `.ts`/`.js` に変更して、ビルド出力の構成を確認する

## 静的アセットで 404 が発生する

**問題**: 静的ファイルが配信されない  
**原因**: ビルド出力ディレクトリの設定ミス、Functions がリクエストを横取りしている、Advanced モードで `env.ASSETS.fetch()` が不足している  
**解決策**: 出力ディレクトリを確認し、`_routes.json` に除外設定を追加して、`_worker.js` で `env.ASSETS.fetch()` を呼び出す

## バインディングが動作しない

**問題**: `env.BINDING` が undefined になる、またはエラーが発生する  
**原因**: `wrangler.jsonc` の構文エラー、バインディング ID の誤り、`.dev.vars` がない、型定義が同期されていない  
**解決策**: 設定を検証し、ID を確認して、`.dev.vars` を作成し、`npx wrangler types` を実行する

## ビルドの失敗

**問題**: ビルド中にデプロイが失敗する  
**原因**: ビルドコマンドまたは出力ディレクトリの誤り、Node バージョンの非互換、環境変数の不足、20 分のタイムアウト、OOM  
**解決策**: Dashboard → Deployments → Build log を確認し、設定を検証して、`.nvmrc` を追加し、ビルドを最適化する

## Middleware が実行されない

**問題**: Middleware が実行されない  
**原因**: ファイル名が誤っている（`_middleware.ts` ではない）、`onRequest` のエクスポートがない、`next()` を呼び出していない  
**解決策**: ファイル名の先頭にアンダースコアを付け、ハンドラーをエクスポートし、`next()` を呼び出すか Response を返す

## ヘッダーやリダイレクトが動作しない

**問題**: `_headers` または `_redirects` が適用されない  
**原因**: 静的アセットでしか機能しない、Functions が上書きしている、構文エラー、上限超過  
**解決策**: Functions では Response オブジェクトにヘッダーを設定し、構文を確認して、上限（ヘッダー 100 件、リダイレクト 2,100 件）を確認する

## TypeScript エラー

**問題**: Functions のコードで型エラーが発生する  
**原因**: 型が生成されていない、Env インターフェースが `wrangler.jsonc` と一致しない  
**解決策**: `npx wrangler types --path='./functions/types.d.ts'` を実行し、Env インターフェースを更新する

## ローカル開発の問題

**問題**: 開発サーバーでエラーが発生する、またはバインディングが動作しない  
**原因**: ポートの競合、バインディングが渡されていない、ローカル環境と HTTPS の違い  
**解決策**: `--port=3000` を使い、CLI または wrangler.jsonc 経由でバインディングを渡し、HTTP/HTTPS の違いを考慮する

## パフォーマンスの問題

**問題**: 応答が遅い、または CPU 上限エラーが発生する  
**原因**: 静的アセットに対して Functions が呼び出される、コールドスタート、CPU 時間の上限 10ms、大きなバンドル  
**解決策**: `_routes.json` で静的アセットを除外し、頻繁に実行される処理を最適化して、バンドルを 1MB 未満に保つ

## フレームワーク固有の情報

### ⚠️ 非推奨のフレームワーク

**Next.js**: 公式アダプター（`@cloudflare/next-on-pages`）は**非推奨**で、メンテナンスされていません。
- **問題**: 2024 年以降更新されていない、Next.js 15 以降と非互換、App Router の機能が不足
- **原因**: Cloudflare が公式サポートを終了した。コミュニティのフォークはあるが、機能が限られている
- **解決策**:
  1. **推奨**: Vercel（Next.js 公式ホスティング）を使う
  2. **上級者向け**: カスタムアダプターを使って Workers でセルフホストする（複雑で、サポート対象外）
  3. **移行**: SvelteKit/Nuxt に切り替える（似た DX で、Pages を全面的にサポート）

**Remix**: 公式アダプター（`@remix-run/cloudflare-pages`）は**非推奨**です。
- **問題**: Remix チームによるメンテナンスがなく、Remix v2 以降との互換性に問題がある
- **原因**: Remix チームがすべてのフレームワークアダプターを非推奨にした
- **解決策**:
  1. **推奨**: SvelteKit に移行する（ファイルベースのルーティングが似ており、DX がより優れている）
  2. **代替案**: Astro を使う（静的サイトを優先し、必要に応じて SSR に対応）
  3. **回避策**: 非推奨のアダプターを使い続ける（今後のサポートなし）

### ✅ サポート対象のフレームワーク

**SvelteKit**:
- `@sveltejs/adapter-cloudflare` を使う
- サーバーの load 関数で `platform.env` 経由でバインディングにアクセスする
- `svelte.config.js` で `platform: 'cloudflare'` を設定する

**Astro**:
- Cloudflare アダプターを標準搭載
- `Astro.locals.runtime.env` 経由でバインディングにアクセスする

**Nuxt**:
- `nuxt.config.ts` で `nitro.preset: 'cloudflare-pages'` を設定する
- `event.context.cloudflare.env` 経由でバインディングにアクセスする

**Qwik、Solid Start**:
- 標準または公式の Cloudflare アダプターを利用可能
- バインディングへのアクセス方法は各フレームワークのドキュメントを確認する

## デバッグ

```typescript
// Log request details
console.log('Request:', { method: request.method, url: request.url });
console.log('Env:', Object.keys(env));
console.log('Params:', params);
```

**ログの表示**: `npx wrangler pages deployment tail --project-name=my-project`

## Smart Placement の問題

### コールドスタートの遅延増加

**問題**: Smart Placement を有効にした後、初回のリクエストが遅くなる  
**原因**: システムがトラフィックパターンを学習する間の初期最適化期間  
**解決策**: 最初の 24～48 時間は想定される動作。時間の経過に伴うレイテンシの傾向を監視する

### 応答時間が一定しない

**問題**: 初期デプロイ中、リクエストごとにレイテンシが大きく異なる  
**原因**: Smart Placement が最適な配置を見つけるため、異なる実行場所をテストしている  
**解決策**: 学習フェーズ中は通常の動作。トラフィックパターンが明らかになると（1～2 日後に）安定する

### パフォーマンスが改善しない

**問題**: Smart Placement を有効にしても、レイテンシの低下が見られない  
**原因**: トラフィックが世界中に均等に分散している、またはデータの局所性に関する制約がない  
**解決策**: Smart Placement は、データが集中している場合（D1/DO）や地域に限定されたトラフィックがある場合に最も効果的。効果がなければ無効にする

## Remote Bindings の問題

### 本番データを誤って変更した

**問題**: `--remote` を使ったローカル開発で、本番のデータベース/KV を変更した  
**原因**: Remote Bindings は本番リソースに直接接続するため、書き込みは実際に反映される  
**解決策**: 
- `--remote` は読み取り中心のデバッグに限って使う
- テスト用に個別のプレビュー環境を作成する
- 開発中の書き込み操作では `--remote` を絶対に使わない

### Remote Binding の認証エラー

**問題**: `npx wrangler pages dev --remote` が "Unauthorized" または認証エラーで失敗する  
**原因**: ログインしていない、セッションの期限切れ、またはアカウント権限が不足している  
**解決策**: 
1. `npx wrangler login` を実行して再認証する
2. アカウントがプロジェクトとバインディングにアクセスできることを確認する
3. バインディング ID が本番の設定と一致することを確認する

### Remote Bindings 使用時にローカル開発が遅い

**問題**: `--remote` を使うとローカル開発サーバーが遅い  
**原因**: リクエストごとに本番のバインディングへネットワーク経由で接続する  
**解決策**: 開発ではローカルバインディングを使い、`--remote` は最終検証用に限る

## よくあるエラー

### "Module not found"
**原因**: 依存関係がバンドルされていない、またはビルド出力が正しくない  
**解決策**: ビルド出力ディレクトリを確認し、依存関係がバンドルされていることを確かめる

### "Binding not found"
**原因**: バインディングが設定されていない、または型が同期されていない  
**解決策**: wrangler.jsonc を確認し、`npx wrangler types` を実行する

### "Request exceeded CPU limit"
**原因**: コード実行が遅すぎる、または計算負荷が高い  
**解決策**: 頻繁に実行される処理を最適化するか、Workers Paid にアップグレードする

### "Script too large"
**原因**: バンドルサイズが上限を超えている  
**解決策**: ツリーシェイキングを行い、動的インポートを使い、コードを分割する

### "Too many subrequests"
**原因**: サブリクエストの上限 50 件を超えている  
**解決策**: fetch 呼び出しをまとめるか、回数を減らす

### "KV key not found"
**原因**: キーが存在しない、または名前空間が誤っている  
**解決策**: 名前空間が環境と一致することを確認する

### "D1 error"
**原因**: database_id が誤っている、またはマイグレーションが不足している  
**解決策**: 設定を確認し、`wrangler d1 migrations list` を実行する

## 上限の一覧（2026 年 1 月）

| リソース | 無料 | 有料 |
|----------|------|------|
| Functions リクエスト | 100k/日 | 無制限 |
| CPU 時間 | 10ms/リクエスト | 30ms/リクエスト |
| メモリ | 128MB | 128MB |
| スクリプトサイズ | 1MB | 10MB |
| サブリクエスト | 50/リクエスト | 1,000/リクエスト |
| デプロイ | 500/月 | 5,000/月 |

**ヒント**: CPU 上限に達した場合は、頻繁に実行される処理を最適化するか、Workers Paid プランにアップグレードしてください。

[上限の詳細](https://developers.cloudflare.com/pages/platform/limits/)

## サポートを受ける

1. [Pages Docs](https://developers.cloudflare.com/pages/) を確認する
2. [Discord #functions](https://discord.com/channels/595317990191398933/910978223968518144) で検索する
3. [Workers Examples](https://developers.cloudflare.com/workers/examples/) を確認する
4. フレームワーク固有のドキュメントやアダプターを確認する