# Wrangler のよくある問題

## よくあるエラー

### 「バインディング ID と名前の不一致」

**原因:** バインディング名（コード内）とリソース ID の混同
**解決策:** バインディングでは `binding`（コード内の名前）と `id`/`database_id`/`bucket_name`（リソース ID）を使用します。プレビュー用バインディングには個別の ID が必要です: `preview_id`, `preview_database_id`

### 「環境が設定を継承しない」

**原因:** 継承不可のキーが環境ごとに再定義されていない
**解決策:** 継承不可のキー（bindings、vars）は環境ごとに再定義する必要があります。継承可能なキー（routes、compatibility_date）は上書きできます

### 「ローカル開発時の動作が本番環境と異なる」

**原因:** リモート実行ではなくローカルシミュレーションを使用している
**解決策:** 適切なリモートモードを選択してください:
- `wrangler dev`（デフォルト）: ローカルシミュレーション。高速ですが、精度に制限があります
- `wrangler dev --remote`: 完全なリモート実行。本番環境に近い精度ですが、低速です
- 実際のリモートバインディングを使った高速テストには、テストで `remote: "minimal"` を使用します

### 「startWorker が本番環境と一致しない」

**原因:** リモートリソースが必要なのにローカルモードを使用している
**解決策:** `remote` オプションを使用します:
```typescript
const worker = await startWorker({ 
  config: "wrangler.jsonc",
  remote: true  // or "minimal" for faster tests
});
```

### 「予期しないランタイムの変更」

**原因:** compatibility_date が設定されていない
**解決策:** 必ず `compatibility_date` を設定します:
```jsonc
{ "compatibility_date": "2025-01-01" }
```

### 「Durable Object バインディングが動作しない」

**原因:** 外部 DO の script_name が設定されていない
**解決策:** 外部 Durable Objects には必ず `script_name` を指定します:
```jsonc
{
  "durable_objects": {
    "bindings": [
      { "name": "MY_DO", "class_name": "MyDO", "script_name": "my-worker" }
    ]
  }
}
```

同じ Worker 内のローカル DO では、`script_name` は省略可能です。

### 「自動プロビジョニングされたリソースが表示されない」

**原因:** 初回デプロイ時に ID が設定へ書き戻されるが、設定が再読み込みされていない
**解決策:** 自動プロビジョニングを使った初回デプロイ後、設定ファイルに ID が追加されます。更新された設定をコミットしてください。以降のデプロイでは既存のリソースが再利用されます。

### 「ローカル開発でシークレットを利用できない」

**原因:** `wrangler secret put` で設定したシークレットは、デプロイ済み Worker でのみ機能する
**解決策:** ローカル開発では `.dev.vars` を使用します

### 「Node.js 互換性エラー」

**原因:** Node.js 互換性フラグが設定されていない
**解決策:** `pg` を使用する Hyperdrive など、一部のバインディングには次の設定が必要です:
```jsonc
{ "compatibility_flags": ["nodejs_compat_v2"] }
```

### 「Workers Assets で 404 エラーが発生する」

**原因:** アセットのパスが一致しない、または `html_handling` が正しくない
**解決策:** 
- `assets.directory` が正しいビルド出力先を指していることを確認します
- SPA では `html_handling: "auto-trailing-slash"` を設定します
- 404 の場合に index.html を配信するには `not_found_handling: "single-page-application"` を使用します
```jsonc
{
  "assets": {
    "directory": "./dist",
    "html_handling": "auto-trailing-slash",
    "not_found_handling": "single-page-application"
  }
}
```

### 「Placement を設定してもレイテンシが低減しない」

**原因:** Smart Placement に対する誤解
**解決策:** Smart Placement が効果を発揮するのは、Worker が D1 または Durable Objects にアクセスする場合のみです。KV、R2、外部 API のレイテンシには影響しません。
```jsonc
{ "placement": { "mode": "smart" } }  // Only beneficial with D1/DOs
```

### 「unstable_startWorker が見つからない」

**原因:** 古い API を使用している
**解決策:** 代わりに安定版の `startWorker` を使用します:
```typescript
import { startWorker } from "wrangler";  // Not unstable_startWorker
```

### 「outboundService が fetch をモックしない」

**原因:** モック関数が Response を返していない
**解決策:** 必ず Response を返します。パススルーには `fetch(req)` を使用します:
```typescript
const worker = await startWorker({
  outboundService: (req) => {
    if (shouldMock(req)) {
      return new Response("mocked");
    }
    return fetch(req);  // Required for non-mocked requests
  }
});
```

## 制限

| リソース/制限 | 値 | 備考 |
|----------------|-------|-------|
| Worker あたりのバインディング数 | 64 | 全種類の合計 |
| 環境 | 無制限 | 設定内で名前を付けた環境 |
| 設定ファイルのサイズ | 約 1MB | 適切なサイズに保つ |
| Workers Assets のサイズ | 25 MB | デプロイあたり |
| Workers Assets のファイル数 | 20,000 | ファイル数の上限 |
| スクリプトサイズ（圧縮後） | 1 MB | 無料プラン、10 MB は有料プラン |
| CPU 時間 | 10～50ms | 無料プラン、50～500ms は有料プラン |
| サブリクエスト数の上限 | 50 | 無料プラン、1000 は有料プラン |

## トラブルシューティング

### 認証の問題
```bash
wrangler logout
wrangler login
wrangler whoami
```

### 設定エラー
```bash
wrangler check  # Validate config
```
検証には `$schema` を使用できる wrangler.jsonc を使います。

### バインディングを利用できない
- バインディングが設定に存在することを確認します
- 環境を使用する場合、その環境用にバインディングが定義されていることを確認します
- ローカル開発では、一部のバインディングに `--remote` が必要です

### デプロイの失敗
```bash
wrangler tail              # Check logs
wrangler deploy --dry-run  # Validate
wrangler whoami            # Check account limits
```

### ローカル開発の問題
```bash
rm -rf .wrangler/state     # Clear local state
wrangler dev --remote      # Use remote bindings
wrangler dev --persist-to ./local-state  # Custom persist location
wrangler dev --inspector-port 9229  # Enable debugging
```

### テストの問題
```bash
# If tests hang, ensure dispose() is called
worker.dispose()  // Always cleanup

# If bindings don't work in tests
const worker = await startWorker({ 
  config: "wrangler.jsonc",
  remote: "minimal"  // Use remote bindings
});
```

## リソース

- ドキュメント: https://developers.cloudflare.com/workers/wrangler/
- 設定: https://developers.cloudflare.com/workers/wrangler/configuration/
- コマンド: https://developers.cloudflare.com/workers/wrangler/commands/
- 例: https://github.com/cloudflare/workers-sdk/tree/main/templates
- Discord: https://discord.gg/cloudflaredev

## 関連項目

- [README.md](./README.md) - コマンド
- [configuration.md](./configuration.md) - 設定
- [api.md](./api.md) - プログラム API
- [patterns.md](./patterns.md) - ワークフロー
