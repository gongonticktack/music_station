# Workerd のパターン

## マルチサービスアーキテクチャ
```capnp
const config :Workerd.Config = (
  services = [
    (name = "frontend", worker = (
      modules = [(name = "index.js", esModule = embed "frontend/index.js")],
      compatibilityDate = "2024-01-15",
      bindings = [(name = "API", service = "api")]
    )),
    (name = "api", worker = (
      modules = [(name = "index.js", esModule = embed "api/index.js")],
      compatibilityDate = "2024-01-15",
      bindings = [(name = "DB", service = "postgres"), (name = "CACHE", kvNamespace = "kv")]
    )),
    (name = "postgres", external = (address = "db.internal:5432", http = ())),
    (name = "kv", disk = (path = "/var/kv", writable = true))
  ],
  sockets = [(name = "http", address = "*:8080", http = (), service = "frontend")]
);
```

## Durable Objects
```capnp
const worker :Workerd.Worker = (
  modules = [(name = "index.js", esModule = embed "index.js"), (name = "room.js", esModule = embed "room.js")],
  compatibilityDate = "2024-01-15",
  bindings = [(name = "ROOMS", durableObjectNamespace = "Room")],
  durableObjectNamespaces = [(className = "Room", uniqueKey = "v1")],
  durableObjectStorage = (localDisk = "/var/do")
);
```

## 開発環境と本番環境の設定
```capnp
# Use parameter bindings for env-specific config
const baseWorker :Workerd.Worker = (
  modules = [(name = "index.js", esModule = embed "src/index.js")],
  compatibilityDate = "2024-01-15",
  bindings = [(name = "API_URL", parameter = (type = text))]
);

const prodWorker :Workerd.Worker = (
  inherit = "base-service",
  bindings = [(name = "API_URL", text = "https://api.prod.com")]
);
```

## HTTP リバースプロキシ
```capnp
services = [
  (name = "proxy", worker = (serviceWorkerScript = embed "proxy.js", compatibilityDate = "2024-01-15", bindings = [(name = "BACKEND", service = "backend")])),
  (name = "backend", external = (address = "internal:8080", http = ()))
]
```

## ローカル開発

**推奨:** Wrangler を使用する
```bash
wrangler dev  # Uses workerd internally
```

**workerd を直接使用する場合:**
```bash
workerd serve config.capnp --socket-addr http=*:3000 --verbose
```

**環境変数:**
```capnp
bindings = [(name = "DATABASE_URL", fromEnvironment = "DATABASE_URL")]
```

## テスト
```bash
workerd test config.capnp
workerd test config.capnp --test-only=test.js
```

テストファイルは `modules = [...]` 設定に含める必要があります。

## 本番環境へのデプロイ

### コンパイル済みバイナリ（推奨）
```bash
workerd compile config.capnp myConfig -o production-server
./production-server
```

### Docker
```dockerfile
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates
COPY workerd /usr/local/bin/
COPY config.capnp /etc/workerd/
COPY src/ /etc/workerd/src/
EXPOSE 8080
CMD ["workerd", "serve", "/etc/workerd/config.capnp"]
```

### Systemd
```ini
# /etc/systemd/system/workerd.service
[Service]
ExecStart=/usr/bin/workerd serve /etc/workerd/config.capnp --socket-fd http=3
Restart=always
User=nobody
```

完全なセットアップについては、systemd のソケットアクティベーションに関するドキュメントを参照してください。

## フレームワークとの統合

### Hono
```javascript
import { Hono } from 'hono';

const app = new Hono();

app.get('/', (c) => c.text('Hello Hono!'));
app.get('/api/:id', async (c) => {
  const id = c.req.param('id');
  const data = await c.env.KV.get(id);
  return c.json({ id, data });
});

export default app;
```

### itty-router
```javascript
import { Router } from 'itty-router';

const router = Router();

router.get('/', () => new Response('Hello itty!'));
router.get('/api/:id', async (request, env) => {
  const { id } = request.params;
  const data = await env.KV.get(id);
  return Response.json({ id, data });
});

export default {
  fetch: (request, env, ctx) => router.handle(request, env, ctx)
};
```

## ベストプラクティス

1. サービスワーカー構文より **ES モジュールを使用する**
2. **バインディングを明示する** - グローバル名前空間を前提にしない
3. **型安全性を確保する** - `Env` インターフェースを定義する（`wrangler types` を使用）
4. **サービスを分離する** - 関心事を複数のサービスに分割する
5. テスト後、本番環境では **互換性日付を固定する**
6. バックグラウンドタスクには **ctx.waitUntil() を使用する**
7. try/catch を使って **エラーを適切に処理する**
8. キャッシュやストレージの **リソース制限を設定する**

## よく使われるパターン

### エラー処理
```javascript
export default {
  async fetch(request, env, ctx) {
    try {
      return await handleRequest(request, env);
    } catch (error) {
      console.error("Request failed", error);
      return new Response("Internal Error", {status: 500});
    }
  }
};
```

### バックグラウンドタスク
```javascript
export default {
  async fetch(request, env, ctx) {
    const response = new Response("OK");
    
    // Fire-and-forget background work
    ctx.waitUntil(
      env.ANALYTICS.put(request.url, Date.now())
    );
    
    return response;
  }
};
```

設定構文については [configuration.md](./configuration.md)、ランタイム API については [api.md](./api.md)、よくあるエラーについては [gotchas.md](./gotchas.md) を参照してください。
