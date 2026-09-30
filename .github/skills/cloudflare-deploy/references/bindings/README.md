# Cloudflare Bindings スキルリファレンス

Cloudflare Workers Bindings に関する専門的なガイダンス。Workers と Cloudflare プラットフォームのリソースを接続するランタイム API です。

## Bindings とは？

Bindings を使うと、Workers は `env` オブジェクト経由で Cloudflare リソース（ストレージ、コンピューティング、サービス）にアクセスできます。`wrangler.jsonc` で設定し、TypeScript による型安全性があり、ランタイム時のオーバーヘッドはありません。

## 読む順序

1. **このファイル** - Binding の一覧と選び方
2. **[api.md](api.md)** - TypeScript の型と env へのアクセスパターン
3. **[configuration.md](configuration.md)** - wrangler.jsonc の完全な例
4. **[patterns.md](patterns.md)** - ベストプラクティスと一般的なパターン
5. **[gotchas.md](gotchas.md)** - 重大な注意点とトラブルシューティング

## Binding 一覧

### ストレージ Bindings

| Binding | 用途 | アクセスパターン |
|---------|----------|----------------|
| **KV** | キー・バリューキャッシュ、CDN 経由の読み取り | `env.MY_KV.get(key)` |
| **R2** | オブジェクトストレージ（S3 互換） | `env.MY_BUCKET.get(key)` |
| **D1** | SQL データベース（SQLite） | `env.DB.prepare(sql).all()` |
| **Durable Objects** | 調整、リアルタイム状態 | `env.MY_DO.get(id)` |
| **Vectorize** | ベクトル埋め込み検索 | `env.VECTORIZE.query(vector)` |
| **Queues** | 非同期メッセージ処理 | `env.MY_QUEUE.send(msg)` |

### コンピューティング Bindings

| Binding | 用途 | アクセスパターン |
|---------|----------|----------------|
| **Service** | Worker 間 RPC | `env.MY_SERVICE.fetch(req)` |
| **Workers AI** | LLM 推論 | `env.AI.run(model, input)` |
| **Browser Rendering** | ヘッドレス Chrome | `env.BROWSER.fetch(url)` |

### プラットフォーム Bindings

| Binding | 用途 | アクセスパターン |
|---------|----------|----------------|
| **Analytics Engine** | カスタムメトリクス | `env.ANALYTICS.writeDataPoint(data)` |
| **mTLS** | クライアント証明書 | `env.MY_CERT` (string) |
| **Hyperdrive** | データベース接続プーリング | `env.HYPERDRIVE.connectionString` |
| **Rate Limiting** | リクエストのスロットリング | `env.RATE_LIMITER.limit(id)` |
| **Workflows** | 長時間実行されるワークフロー | `env.MY_WORKFLOW.create()` |

### 設定 Bindings

| Binding | 用途 | アクセスパターン |
|---------|----------|----------------|
| **Environment Variables** | 機密ではない設定 | `env.API_URL` (string) |
| **Secrets** | 機密値 | `env.API_KEY` (string) |
| **Text/Data Blobs** | 静的ファイル | `env.MY_BLOB` (string) |
| **WASM** | WebAssembly モジュール | `env.MY_WASM` (WebAssembly.Module) |

## クイック選択ガイド

**永続ストレージが必要ですか？**
- 25MB 未満のキー・バリュー → **KV**
- ファイル／オブジェクト → **R2**
- リレーショナルデータ → **D1**
- リアルタイムの調整 → **Durable Objects**

**AI／コンピューティングが必要ですか？**
- LLM 推論 → **Workers AI**
- スクレイピング／PDF → **Browser Rendering**
- 別の Worker の呼び出し → **Service binding**

**非同期処理が必要ですか？**
- バックグラウンドジョブ → **Queues**

**設定が必要ですか？**
- 公開値 → **Environment Variables**
- シークレット → **Secrets**（決してコミットしない）

## クイックスタート

1. **wrangler.jsonc に binding を追加:**
```jsonc
{
  "kv_namespaces": [
    { "binding": "MY_KV", "id": "your-kv-id" }
  ]
}
```

2. **型を生成:**
```bash
npx wrangler types
```

3. **Worker からアクセス:**
```typescript
export default {
  async fetch(request, env, ctx) {
    await env.MY_KV.put('key', 'value');
    return new Response('OK');
  }
}
```

## 型安全性

Bindings は `wrangler types` によって完全に型付けされます。詳細は [api.md](api.md) を参照してください。

## 制限

- Worker あたり最大 64 個の binding（全種類合計）
- binding ごとの制限は [gotchas.md](gotchas.md) を参照

## 重要な概念

**オーバーヘッドのないアクセス:** Bindings は Worker にコンパイルされ、アクセス時にネットワーク呼び出しは発生しません
**型安全:** `wrangler types` による TypeScript の完全なサポート
**環境ごとの設定:** dev/staging/production では異なる ID を使用
**Secrets と Vars:** Secrets は保存時に暗号化され、設定ファイルには決して記載しません

## 関連項目

- [Cloudflare Docs: Bindings](https://developers.cloudflare.com/workers/runtime-apis/bindings/)
- [Wrangler Configuration](https://developers.cloudflare.com/workers/wrangler/configuration/)
