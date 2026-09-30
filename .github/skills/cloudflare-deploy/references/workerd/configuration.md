# Workerdの設定

## 基本構造
```capnp
using Workerd = import "/workerd/workerd.capnp";

const config :Workerd.Config = (
  services = [(name = "main", worker = .mainWorker)],
  sockets = [(name = "http", address = "*:8080", http = (), service = "main")]
);

const mainWorker :Workerd.Worker = (
  modules = [(name = "index.js", esModule = embed "src/index.js")],
  compatibilityDate = "2024-01-15",
  bindings = [...]
);
```

## サービス
**Worker**: JS/Wasmコードを実行
```capnp
(name = "api", worker = (
  modules = [(name = "index.js", esModule = embed "index.js")],
  compatibilityDate = "2024-01-15",
  bindings = [...]
))
```

**Network**: インターネットアクセス
```capnp
(name = "internet", network = (allow = ["public"], tlsOptions = (trustBrowserCas = true)))
```

**External**: リバースプロキシ
```capnp
(name = "backend", external = (address = "api.com:443", http = (style = tls)))
```

**Disk**: 静的ファイル
```capnp
(name = "assets", disk = (path = "/var/www", writable = false))
```

## ソケット
```capnp
(name = "http", address = "*:8080", http = (), service = "main")
(name = "https", address = "*:443", https = (options = (), tlsOptions = (keypair = (...))), service = "main")
(name = "app", address = "unix:/tmp/app.sock", http = (), service = "main")
```

## Workerの形式
```capnp
# ES Modules (recommended)
modules = [(name = "index.js", esModule = embed "src/index.js"), (name = "wasm.wasm", wasm = embed "build/module.wasm")]

# Service Worker (legacy)
serviceWorkerScript = embed "worker.js"

# CommonJS
(name = "legacy.js", commonJsModule = embed "legacy.js", namedExports = ["foo"])
```

## バインディング
バインディングはリソースをWorkerに公開します。ESモジュール: `env.BINDING`、Service Worker: グローバル変数。

### プリミティブ型
```capnp
(name = "API_KEY", text = "secret")                    # String
(name = "CONFIG", json = '{"key":"val"}')              # Parsed JSON
(name = "DATA", data = embed "data.bin")               # ArrayBuffer
(name = "DATABASE_URL", fromEnvironment = "DB_URL")    # System env var
```

### サービスバインディング
```capnp
(name = "AUTH", service = "auth-worker")               # Basic
(name = "API", service = (
  name = "backend",
  entrypoint = "adminApi",                             # Named export
  props = (json = '{"role":"admin"}')                  # ctx.props
))
```

### ストレージ
```capnp
(name = "CACHE", kvNamespace = "kv-service")           # KV
(name = "STORAGE", r2Bucket = "r2-service")            # R2
(name = "ROOMS", durableObjectNamespace = (
  serviceName = "room-service",
  className = "Room"
))
(name = "FAST", memoryCache = (
  id = "cache-id",
  limits = (maxKeys = 1000, maxValueSize = 1048576)
))
```

### その他
```capnp
(name = "TASKS", queue = "queue-service")
(name = "ANALYTICS", analyticsEngine = "analytics")
(name = "LOADER", workerLoader = (id = "dynamic"))
(name = "KEY", cryptoKey = (format = raw, algorithm = (name = "HMAC", hash = "SHA-256"), keyData = embed "key.bin", usages = [sign, verify], extractable = false))
(name = "TRACED", wrapped = (moduleName = "tracing", entrypoint = "makeTracer", innerBindings = [(name = "backend", service = "backend")]))
```

## 互換性
```capnp
compatibilityDate = "2024-01-15"                       # Always set!
compatibilityFlags = ["nodejs_compat", "streams_enable_constructors"]
```

バージョン = 互換性日付の最大値。テスト後に慎重に更新してください。

## パラメータバインディング（継承）
```capnp
const base :Workerd.Worker = (
  modules = [...], compatibilityDate = "2024-01-15",
  bindings = [(name = "API_URL", parameter = (type = text)), (name = "DB", parameter = (type = service))]
);

const derived :Workerd.Worker = (
  inherit = "base-service",
  bindings = [(name = "API_URL", text = "https://api.com"), (name = "DB", service = "postgres")]
);
```

## Durable Objectsの設定
```capnp
const worker :Workerd.Worker = (
  modules = [...],
  compatibilityDate = "2024-01-15",
  bindings = [(name = "ROOMS", durableObjectNamespace = "Room")],
  durableObjectNamespaces = [(className = "Room", uniqueKey = "v1")],
  durableObjectStorage = (localDisk = "/var/do")
);
```

## リモートバインディング（開発）

ローカルのworkerdを本番のCloudflareリソースに接続します。

```capnp
bindings = [
  # Remote KV (requires API token)
  (name = "PROD_KV", kvNamespace = (
    remote = (
      accountId = "your-account-id",
      namespaceId = "your-namespace-id",
      apiToken = .envVar("CF_API_TOKEN")
    )
  )),
  
  # Remote R2
  (name = "PROD_R2", r2Bucket = (
    remote = (
      accountId = "your-account-id",
      bucketName = "my-bucket",
      apiToken = .envVar("CF_API_TOKEN")
    )
  )),
  
  # Remote Durable Object
  (name = "PROD_DO", durableObjectNamespace = (
    remote = (
      accountId = "your-account-id",
      scriptName = "my-worker",
      className = "MyDO",
      apiToken = .envVar("CF_API_TOKEN")
    )
  ))
]
```

**注:** リモートバインディングにはネットワークアクセスと有効なCloudflare API認証情報が必要です。

## ログとデバッグ
```capnp
logging = (structuredLogging = true, stdoutPrefix = "OUT: ", stderrPrefix = "ERR: ")
v8Flags = ["--expose-gc", "--max-old-space-size=2048"]  # ⚠️ Unsupported in production
```

複数サービスの例は[patterns.md](./patterns.md)を、設定エラーは[gotchas.md](./gotchas.md)を参照してください。
