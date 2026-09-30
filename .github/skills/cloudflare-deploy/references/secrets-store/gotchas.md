# 注意点

## よくあるエラー

### 「.get() がエラーをスローする」

**原因:** `.get()` は失敗時に null を返すと思い込み、例外をスローすることを想定していない  
**解決策:** エラーを適切に処理できるよう、`.get()` の呼び出しは必ず try/catch ブロックで囲む

```typescript
try {
  const key = await env.API_KEY.get();
} catch (error) {
  return new Response("Configuration error", { status: 500 });
}
```

### 「シークレット値をログに記録する」

**原因:** コンソールやエラーメッセージに誤ってシークレット値を記録する  
**解決策:** メタデータ（例: 「API_KEY を取得しました」）のみを記録し、シークレット値そのものは決して記録しない

### 「モジュールレベルでのシークレットへのアクセス」

**原因:** env が利用可能になる前のモジュール初期化時にシークレットへアクセスしようとする  
**解決策:** シークレットをキャッシュするのはリクエストのスコープ内に限り、モジュールレベルでは行わない

### 「ストアにシークレットが見つからない」

**原因:** シークレット名が存在しない、大文字小文字が一致しない、workers スコープが設定されていない、または store_id が正しくない  
**解決策:** `wrangler secrets-store secret list <store-id> --remote` でシークレットの存在を確認し、名前が完全に一致すること（大文字小文字を区別）を確かめ、シークレットに `workers` スコープが設定されていることを確認し、正しい store_id であることを確かめる

### 「スコープの不一致」

**原因:** シークレットは存在するが、`workers` スコープがなく（`ai-gateway` スコープのみが設定されている）  
**解決策:** シークレットのスコープを更新する: `wrangler secrets-store secret update <store-id> --name SECRET --scopes workers --remote` を実行するか、ダッシュボードから追加する

### 「JSON の解析に失敗する」

**原因:** 無効な JSON をシークレットに保存し、実行時の解析に失敗する  
**解決策:** 保存前に JSON を検証する:

```bash
# Validate before storing
echo '{"key":"value"}' | jq . && \
  echo '{"key":"value"}' | wrangler secrets-store secret create <store-id> \
    --name CONFIG --scopes workers --remote
```

エラー処理を含む実行時の解析:

```typescript
try {
  const configStr = await env.CONFIG.get();
  const config = JSON.parse(configStr);
} catch (error) {
  console.error("Invalid config JSON:", error);
  return new Response("Invalid configuration", { status: 500 });
}
```

### 「ローカル開発環境でシークレットにアクセスできない」

**原因:** ローカル開発環境で本番用シークレットにアクセスしようとする  
**解決策:** 開発用にローカル専用シークレット（`--remote` フラグなし）を作成する: `wrangler secrets-store secret create <store-id> --name API_KEY --scopes workers`

### 「プロパティ 'get' が存在しない」

**原因:** シークレットバインディングの TypeScript 型定義がない  
**解決策:** get メソッドを含むインターフェースを定義する: `interface Env { API_KEY: { get(): Promise<string> }; }`

### 「バインディングがすでに存在する」

**原因:** ダッシュボード内のバインディングが重複している、または wrangler.jsonc とダッシュボードが競合している  
**解決策:** ダッシュボードの Settings → Bindings から重複を削除して競合を確認するか、`wrangler secret delete API_KEY` を使って古い Worker シークレットを削除する

### 「アカウントのシークレット上限を超過した」

**原因:** アカウントのシークレット数が上限の 100 件に達した（ベータ版）  
**解決策:** `wrangler secrets-store quota --remote` で上限を確認し、未使用のシークレットを削除するか、重複を統合するか、Cloudflare に上限引き上げを問い合わせる

## 制限

| 制限 | 値 | 備考 |
|-------|-------|-------|
| アカウントあたりのシークレット最大数 | 100 | ベータ版の上限 |
| アカウントあたりのストア最大数 | 1 | ベータ版の上限 |
| シークレットの最大サイズ | 1024 bytes | シークレットごと |
| ローカルシークレット | 上限に算入されない | 本番用シークレットのみ算入 |
| 利用可能なスコープ | `workers`, `ai-gateway` | アクセスには正しいスコープが必要 |
| スコープ | アカウントレベル | 複数の Worker 間で再利用可能 |
| アクセス方法 | `await env.BINDING.get()` | 非同期のみ。エラー時は例外をスロー |
| 管理 | 一元管理 | secrets-store コマンドを使用 |
| ローカル開発 | 個別のローカルシークレット | `--remote` フラグなしで使用 |
| リージョン別の提供状況 | 中国ネットワークを除く全世界 | 中国ネットワークでは利用不可 |

参照: [configuration.md](./configuration.md)、[api.md](./api.md)、[patterns.md](./patterns.md)
