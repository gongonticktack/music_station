## オリジンの種類

### 直接 IP オリジン

オリジンが静的 IP を持つ単一のサーバーである場合に使用します。

**TypeScript SDK:**
```typescript
const app = await client.spectrum.apps.create({
  zone_id: 'your-zone-id',
  protocol: 'tcp/22',
  dns: { type: 'CNAME', name: 'ssh.example.com' },
  origin_direct: ['tcp://192.0.2.1:22'],
  ip_firewall: true,
  tls: 'off',
});
```

**Terraform:**
```hcl
resource "cloudflare_spectrum_application" "ssh" {
  zone_id  = var.zone_id
  protocol = "tcp/22"

  dns {
    type = "CNAME"
    name = "ssh.example.com"
  }

  origin_direct      = ["tcp://192.0.2.1:22"]
  ip_firewall        = true
  tls                = "off"
  argo_smart_routing = true
}
```

### CNAME オリジン

オリジンがホスト名（静的 IP ではない）の場合に使用します。Spectrum は DNS を動的に解決します。

**TypeScript SDK:**
```typescript
const app = await client.spectrum.apps.create({
  zone_id: 'your-zone-id',
  protocol: 'tcp/3306',
  dns: { type: 'CNAME', name: 'db.example.com' },
  origin_dns: { name: 'db-primary.internal.example.com' },
  origin_port: 3306,
  tls: 'full',
});
```

**Terraform:**
```hcl
resource "cloudflare_spectrum_application" "database" {
  zone_id  = var.zone_id
  protocol = "tcp/3306"

  dns {
    type = "CNAME"
    name = "db.example.com"
  }

  origin_dns {
    name = "db-primary.internal.example.com"
  }

  origin_port        = 3306
  tls                = "full"
  argo_smart_routing = true
}
```

### ロードバランサーオリジン

高可用性とフェイルオーバーに使用します。

**Terraform:**
```hcl
resource "cloudflare_load_balancer" "game_lb" {
  zone_id          = var.zone_id
  name             = "game-lb.example.com"
  default_pool_ids = [cloudflare_load_balancer_pool.game_pool.id]
}

resource "cloudflare_load_balancer_pool" "game_pool" {
  name    = "game-primary"
  origins { name = "game-1"; address = "192.0.2.1" }
  monitor = cloudflare_load_balancer_monitor.tcp_monitor.id
}

resource "cloudflare_load_balancer_monitor" "tcp_monitor" {
  type = "tcp"; port = 25565; interval = 60; timeout = 5
}

resource "cloudflare_spectrum_application" "game" {
  zone_id  = var.zone_id
  protocol = "tcp/25565"
  dns { type = "CNAME"; name = "game.example.com" }
  origin_dns { name = cloudflare_load_balancer.game_lb.name }
  origin_port = 25565
}
```

## TLS 設定

| モード | 説明 | 用途 | オリジン証明書 |
|------|-------------|----------|-------------|
| `off` | TLS なし | 非暗号化通信（SSH、ゲーム） | 不要 |
| `flexible` | クライアント→CF は TLS、CF→オリジンは平文 | テスト | 不要 |
| `full` | エンドツーエンド TLS、自己署名証明書も可 | 本番環境 | 必要（任意） |
| `strict` | Full に加え、有効な証明書を検証 | 最高レベルのセキュリティ | 必要（CA 発行） |

**例:**
```typescript
const app = await client.spectrum.apps.create({
  zone_id: 'your-zone-id',
  protocol: 'tcp/3306',
  dns: { type: 'CNAME', name: 'db.example.com' },
  origin_direct: ['tcp://192.0.2.1:3306'],
  tls: 'strict',  // Validates origin certificate
});
```

## Proxy Protocol

実際のクライアント IP をオリジンに転送します。オリジンはその解析に対応している必要があります。

| バージョン | プロトコル | 用途 |
|---------|----------|----------|
| `off` | - | オリジンでクライアント IP が不要な場合 |
| `v1` | TCP | ほとんどの TCP アプリ（SSH、データベース） |
| `v2` | TCP | 高性能な TCP 通信 |
| `simple` | UDP | UDP アプリケーション |

**互換性:**
- **v1**: HAProxy、nginx、SSH、ほとんどのデータベース
- **v2**: HAProxy 1.5 以降、nginx 1.11 以降
- **simple**: Cloudflare 独自の UDP 形式

**有効化:**
```typescript
const app = await client.spectrum.apps.create({
  // ...
  proxy_protocol: 'v1',  // Origin must parse PROXY header
});
```

**オリジンの設定（nginx）:**
```nginx
stream {
    server {
        listen 22 proxy_protocol;
        proxy_pass backend:22;
    }
}
```

## IP アクセスルール

`ip_firewall: true` を有効にしてから、ゾーンレベルのファイアウォールルールを設定します。

```typescript
const app = await client.spectrum.apps.create({
  // ...
  ip_firewall: true,  // Applies zone firewall rules
});
```

## ポート範囲（Enterprise のみ）

```hcl
resource "cloudflare_spectrum_application" "game_cluster" {
  zone_id  = var.zone_id
  protocol = "tcp/25565-25575"

  dns {
    type = "CNAME"
    name = "games.example.com"
  }

  origin_direct = ["tcp://192.0.2.1"]
  
  origin_port {
    start = 25565
    end   = 25575
  }
}
```

## 関連項目

- [patterns.md](patterns.md) - プロトコル別の例
- [api.md](api.md) - REST/SDK リファレンス