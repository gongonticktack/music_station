## Wrangler の設定

### 基本的な Container 設定

```jsonc
{
  "name": "my-worker",
  "main": "src/index.ts",
  "compatibility_date": "2026-01-10",
  "containers": [
    {
      "class_name": "MyContainer",
      "image": "./Dockerfile",  // Path to Dockerfile or directory with Dockerfile
      "instance_type": "standard-1",  // Predefined or custom (see below)
      "max_instances": 10
    }
  ],
  "durable_objects": {
    "bindings": [
      {
        "name": "MY_CONTAINER",
        "class_name": "MyContainer"
      }
    ]
  },
  "migrations": [
    {
      "tag": "v1",
      "new_sqlite_classes": ["MyContainer"]  // Must use new_sqlite_classes
    }
  ]
}
```

主な設定要件:
- `image` - Dockerfile、または Dockerfile を含むディレクトリへのパス
- `class_name` - Container クラスのエクスポート名と一致する必要があります
- `max_instances` - 同時に実行できるコンテナインスタンスの最大数
- Durable Objects バインディングとマイグレーションの両方を設定する必要があります

### インスタンスタイプ

#### 定義済みタイプ

| タイプ | vCPU | メモリ | ディスク |
|------|------|--------|------|
| lite | 1/16 | 256 MiB | 2 GB |
| basic | 1/4 | 1 GiB | 4 GB |
| standard-1 | 1/2 | 4 GiB | 8 GB |
| standard-2 | 1 | 6 GiB | 12 GB |
| standard-3 | 2 | 8 GiB | 16 GB |
| standard-4 | 4 | 12 GiB | 20 GB |

```jsonc
{
  "containers": [
    {
      "class_name": "MyContainer",
      "image": "./Dockerfile",
      "instance_type": "standard-2"  // Use predefined type
    }
  ]
}
```

#### カスタムタイプ（2026 年 1 月の機能）

```jsonc
{
  "containers": [
    {
      "class_name": "MyContainer",
      "image": "./Dockerfile",
      "instance_type_custom": {
        "vcpu": 2,              // 1-4 vCPU
        "memory_mib": 8192,     // 512-12288 MiB (up to 12 GiB)
        "disk_mib": 16384       // 2048-20480 MiB (up to 20 GB)
      }
    }
  ]
}
```

**カスタムタイプの制約:**
- vCPU 1 つあたり最低 3 GiB のメモリ
- メモリ 1 GiB あたり最大 2 GB のディスク
- コンテナあたり最大 4 vCPU、12 GiB のメモリ、20 GB のディスク

### アカウントの上限

| リソース | 上限 | 備考 |
|----------|-------|-------|
| メモリ合計（全コンテナ） | 400 GiB | 実行中の全コンテナの合計 |
| vCPU 合計（全コンテナ） | 100 | 実行中の全コンテナの合計 |
| ディスク合計（全コンテナ） | 2 TB | 実行中の全コンテナの合計 |
| アカウントあたりのイメージストレージ | 50 GB | 保存されるコンテナイメージ |

### Container クラスのプロパティ

```typescript
import { Container } from "@cloudflare/containers";

export class MyContainer extends Container {
  // Port Configuration
  defaultPort = 8080;             // Default port for fetch() calls
  requiredPorts = [8080, 9090];   // Ports to wait for in startAndWaitForPorts()

  // Lifecycle
  sleepAfter = "30m";             // Inactivity timeout (5m, 30m, 2h, etc.)

  // Network
  enableInternet = true;          // Allow outbound internet access

  // Health Check
  pingEndpoint = "/health";       // Health check endpoint path

  // Environment
  envVars = {                     // Environment variables passed to container
    NODE_ENV: "production",
    LOG_LEVEL: "info"
  };

  // Startup
  entrypoint = ["/bin/start.sh"]; // Override image entrypoint (optional)
}
```

**プロパティの詳細:**

- **`defaultPort`**: 明示的なポートを指定せずに `container.fetch()` を呼び出した場合に使われるポートです。設定されていない場合はポート 33 にフォールバックします。

- **`requiredPorts`**: `startAndWaitForPorts()` が返る前にリッスン状態になっている必要があるポートの配列です。`defaultPort` が設定されていない場合は、最初のポートがデフォルトになります。

- **`sleepAfter`**: 期間を表す文字列（例: "5m"、"30m"、"2h"）。この時間、非アクティブ状態が続くとコンテナは停止します。リクエストのたびにタイマーがリセットされます。

- **`enableInternet`**: 真偽値です。`true` の場合、コンテナから外部への HTTP/TCP リクエストが可能です。

- **`pingEndpoint`**: ヘルスチェックに使用するパスです。2xx ステータスを返すようにしてください。

- **`envVars`**: 環境変数のオブジェクトです。実行時に提供される変数とマージされます（下記参照）。

- **`entrypoint`**: 文字列の配列です。コンテナイメージの CMD/ENTRYPOINT を上書きします。

### 実行時環境変数

Cloudflare は以下の環境変数をコンテナに自動で提供します。

| 変数 | 説明 |
|----------|-------------|
| `CLOUDFLARE_APPLICATION_ID` | Worker アプリケーション ID |
| `CLOUDFLARE_COUNTRY_A2` | リクエスト元の 2 文字の国コード |
| `CLOUDFLARE_LOCATION` | Cloudflare データセンターのロケーション |
| `CLOUDFLARE_REGION` | リージョン識別子 |
| `CLOUDFLARE_DURABLE_OBJECT_ID` | コンテナの Durable Object ID |

Container クラスのカスタム `envVars` はこれらとマージされます。名前が重複する場合はカスタム変数が実行時変数を上書きします。

### イメージ管理

**配布モデル:** デプロイ前にイメージが世界中のすべてのロケーションへ事前に取得されます。これによりコールドスタートが通常 2～3 秒と高速になります。

**ローリングデプロイ:** 即時反映される Workers とは異なり、コンテナのデプロイは段階的に展開されます。展開中も旧バージョンは引き続き実行されます。

**一時ディスク:** コンテナのディスクは一時的なもので、停止するたびにリセットされます。データを永続化するには Durable Object ストレージ（`this.ctx.storage`）を使用してください。

## wrangler.toml 形式

```toml
name = "my-worker"
main = "src/index.ts"
compatibility_date = "2026-01-10"

[[containers]]
class_name = "MyContainer"
image = "./Dockerfile"
instance_type = "standard-2"
max_instances = 10

[[durable_objects.bindings]]
name = "MY_CONTAINER"
class_name = "MyContainer"

[[migrations]]
tag = "v1"
new_sqlite_classes = ["MyContainer"]
```

`wrangler.jsonc` と `wrangler.toml` の両方がサポートされています。コメントを記述でき、IDE でのサポートも優れている `wrangler.jsonc` を使用してください。
