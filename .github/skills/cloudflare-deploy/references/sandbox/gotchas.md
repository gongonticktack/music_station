# 注意点とベストプラクティス

## よくあるエラー

### 「コンテナがいつまでも実行され続ける」

**原因:** `keepAlive: true` を呼び出さずに `destroy()` している
**解決策:** keepAlive コンテナの処理が終わったら、必ず `destroy()` を呼び出してください

```typescript
const sandbox = getSandbox(env.Sandbox, 'temp', { keepAlive: true });
try {
  const result = await sandbox.exec('python script.py');
  return result.stdout;
} finally {
  await sandbox.destroy();  // REQUIRED to free resources
}
```

### 「CONTAINER_NOT_READY」

**原因:** コンテナの準備中（初回リクエスト時、またはスリープ後）
**解決策:** 2〜3 秒後に再試行してください

```typescript
async function execWithRetry(sandbox, cmd) {
  for (let i = 0; i < 3; i++) {
    try {
      return await sandbox.exec(cmd);
    } catch (e) {
      if (e.code === 'CONTAINER_NOT_READY') {
        await new Promise(r => setTimeout(r, 2000));
        continue;
      }
      throw e;
    }
  }
}
```

### 「Connection refused: container port not found」

**原因:** Dockerfile に `EXPOSE` ディレクティブがない
**解決策:** Dockerfile に `EXPOSE <port>` を追加してください（`wrangler dev` でのみ必要。本番環境では自動的に公開されます）

### 「プレビュー URL が機能しない」

**原因:** カスタムドメインが設定されていない、ワイルドカード DNS がない、`normalizeId` が設定されていない、または `proxyToSandbox()` が呼び出されていない
**解決策:** 次を確認してください。
1. カスタムドメインは設定されていますか？（`.workers.dev` ではありません）
2. ワイルドカード DNS は設定されていますか？（`*.domain.com → worker.domain.com`）
3. getSandbox 内に `normalizeId: true` がありますか？
4. fetch 内で最初に `proxyToSandbox()` が呼び出されていますか？

### 「初回リクエストが遅い」

**原因:** コールドスタート（コンテナの準備）
**解決策:**
- 新しいサンドボックスを作成する代わりに `sleepAfter` を使用する
- cron トリガーで事前にウォームアップする
- 重要なサンドボックスには `keepAlive: true` を設定する

### 「ファイルが保持されない」

**原因:** `/tmp` またはその他の一時的なパスにあるファイル
**解決策:** 永続化するファイルには `/workspace` を使用してください

### 「バケットのマウントがローカルで機能しない」

**原因:** バケットのマウントには FUSE が必要ですが、`wrangler dev` では利用できません
**解決策:** バケットのマウントは本番環境のみでテストしてください。ローカルではモックデータを使用してください。

### 「normalizeId が異なると別のサンドボックスになる」

**原因:** `normalizeId` オプションを変更すると Durable Object ID が変わる
**解決策:** `normalizeId` を一貫して設定してください。`normalizeId: true` は ID を小文字に変換します。

```typescript
// These create DIFFERENT sandboxes:
getSandbox(env.Sandbox, 'MyApp');              // DO ID: hash('MyApp')
getSandbox(env.Sandbox, 'MyApp', { normalizeId: true });  // DO ID: hash('myapp')
```

### 「コードコンテキストの変数が消えた」

**原因:** コンテナの再起動でコードコンテキストの状態が消去される
**解決策:** コードコンテキストは一時的なものです。コンテナのスリープ／復帰後にコンテキストを再作成してください。

## パフォーマンスの最適化

### サンドボックス ID の戦略

```typescript
// ❌ BAD: New sandbox every time (slow)
const sandbox = getSandbox(env.Sandbox, `user-${Date.now()}`);

// ✅ GOOD: Reuse per user
const sandbox = getSandbox(env.Sandbox, `user-${userId}`);
```

### スリープとトラフィックの設定

```typescript
// Cost-optimized
getSandbox(env.Sandbox, 'id', { sleepAfter: '30m', keepAlive: false });

// Always-on (requires destroy())
getSandbox(env.Sandbox, 'id', { keepAlive: true });
```

```jsonc
// High traffic: increase max_instances
{ "containers": [{ "class_name": "Sandbox", "max_instances": 50 }] }
```

## セキュリティのベストプラクティス

### サンドボックスの分離
- 各サンドボックスは分離されたコンテナです（ファイルシステム、ネットワーク、プロセス）
- マルチテナントアプリでは、テナントごとに一意のサンドボックス ID を使用してください
- サンドボックス同士は直接通信できません

### 入力の検証

```typescript
// ❌ DANGEROUS: Command injection
const result = await sandbox.exec(`python3 -c "${userCode}"`);

// ✅ SAFE: Write to file, execute file
await sandbox.writeFile('/workspace/user_code.py', userCode);
const result = await sandbox.exec('python3 /workspace/user_code.py');
```

### リソース制限

```typescript
// Timeout long-running commands
const result = await sandbox.exec('python3 script.py', {
  timeout: 30000  // 30 seconds
});
```

### シークレット管理

```typescript
// ❌ NEVER hardcode secrets
const token = 'ghp_abc123';

// ✅ Use environment secrets
const token = env.GITHUB_TOKEN;

// Pass to sandbox via exec env
const result = await sandbox.exec('git clone ...', {
  env: { GIT_TOKEN: token }
});
```

### プレビュー URL のセキュリティ
プレビュー URL には自動生成されたトークンが含まれます:
```
https://8080-sandbox-abc123def456.yourdomain.com
```
トークンは公開操作のたびに変更され、不正アクセスを防ぎます。

## 制限

| リソース | Lite | Standard | Heavy |
|----------|------|----------|-------|
| RAM | 256MB | 512MB | 1GB |
| vCPU | 0.5 | 1 | 2 |

| 操作 | デフォルトのタイムアウト | 上書き |
|-----------|----------------|----------|
| コンテナのプロビジョニング | 30s | `SANDBOX_INSTANCE_TIMEOUT_MS` |
| ポートの準備完了 | 90s | `SANDBOX_PORT_TIMEOUT_MS` |
| exec() | 120s | `timeout` オプション |
| sleepAfter | 10m | `sleepAfter` オプション |

**パフォーマンス**:
- **初回デプロイ**: コンテナのビルドに 2～3 分
- **コールドスタート**: スリープから復帰する際に 2～3 秒
- **バケットのマウント**: 本番環境のみ（開発環境では FUSE は利用不可）

## 本番環境ガイド

参照: https://developers.cloudflare.com/sandbox/guides/production-deployment/

## リソース

- [公式ドキュメント](https://developers.cloudflare.com/sandbox/)
- [API リファレンス](https://developers.cloudflare.com/sandbox/api/)
- [例](https://github.com/cloudflare/sandbox-sdk/tree/main/examples)
- [npm パッケージ](https://www.npmjs.com/package/@cloudflare/sandbox)
- [Discord サポート](https://discord.cloudflare.com)
