# Cloudflare Sandbox SDK

Cloudflare のエッジ上のコンテナで、安全に隔離されたコード実行を実現します。信頼できないコードの実行、ファイル管理、サービスの公開、AI エージェントとの連携ができます。

**ユースケース**: AI によるコード実行、対話型開発環境、データ分析、CI/CD、コードインタープリター、マルチテナント実行。

## アーキテクチャ

- 各サンドボックス = Durable Object + コンテナ
- リクエストをまたいで永続化（同じ ID = 同じサンドボックス）
- ファイルシステム、プロセス、ネットワークを分離
- コスト最適化のため、スリープ／ウェイクを設定可能

## クイックスタート

```typescript
import { getSandbox, proxyToSandbox, type Sandbox } from '@cloudflare/sandbox';
export { Sandbox } from '@cloudflare/sandbox';

type Env = { Sandbox: DurableObjectNamespace<Sandbox>; };

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // CRITICAL: proxyToSandbox MUST be called first for preview URLs
    const proxyResponse = await proxyToSandbox(request, env);
    if (proxyResponse) return proxyResponse;

    const sandbox = getSandbox(env.Sandbox, 'my-sandbox');
    const result = await sandbox.exec('python3 -c "print(2 + 2)"');
    return Response.json({ output: result.stdout });
  }
};
```

**wrangler.jsonc**:
```jsonc
{
  "name": "my-sandbox-worker",
  "main": "src/index.ts",
  "compatibility_date": "2025-01-01", // Use current date for new projects
  
  "containers": [{
    "class_name": "Sandbox",
    "image": "./Dockerfile",
    "instance_type": "lite",        // lite | standard | heavy
    "max_instances": 5
  }],
  
  "durable_objects": {
    "bindings": [{ "class_name": "Sandbox", "name": "Sandbox" }]
  },
  
  "migrations": [{
    "tag": "v1",
    "new_sqlite_classes": ["Sandbox"]
  }]
}
```

**Dockerfile**:
```dockerfile
FROM docker.io/cloudflare/sandbox:latest
RUN pip3 install --no-cache-dir pandas numpy matplotlib
EXPOSE 8080 3000  # Required for wrangler dev
```

## 主な API

- `getSandbox(namespace, id, options?)` → サンドボックスを取得／作成
- `sandbox.exec(command, options?)` → コマンドを実行
- `sandbox.readFile(path)` / `writeFile(path, content)` → ファイル操作
- `sandbox.startProcess(command, options)` → バックグラウンドプロセス
- `sandbox.exposePort(port, options)` → プレビュー URL を取得
- `sandbox.createSession(options)` → 分離されたセッション
- `sandbox.wsConnect(request, port)` → WebSocket プロキシ
- `sandbox.destroy()` → コンテナを終了
- `sandbox.mountBucket(bucket, path, options)` → S3 ストレージをマウント

## 重要なルール

- 必ず最初に `proxyToSandbox()` を呼び出す
- 同じ ID を指定するとサンドボックスを再利用
- 永続ファイルには `/workspace` を使用
- プレビュー URL には `normalizeId: true` を使用
- `CONTAINER_NOT_READY` の場合は再試行

## このリファレンスの内容
- [configuration.md](./configuration.md) - 設定、CLI、環境のセットアップ
- [api.md](./api.md) - プログラム API、テストパターン
- [patterns.md](./patterns.md) - よくあるワークフロー、CI/CD 連携
- [gotchas.md](./gotchas.md) - 問題点、制限、ベストプラクティス

## 関連項目
- [durable-objects](../durable-objects/) - サンドボックスは DO インフラストラクチャ上で実行
- [containers](../containers/) - コンテナランタイムの基本
- [workers](../workers/) - サンドボックスリクエストのエントリーポイント