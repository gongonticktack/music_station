## よくあるユースケース

### 1. SSH サーバーの保護

**Terraform:**
```hcl
resource "cloudflare_spectrum_application" "ssh" {
  zone_id  = var.zone_id
  protocol = "tcp/22"

  dns {
    type = "CNAME"
    name = "ssh.example.com"
  }

  origin_direct      = ["tcp://10.0.1.5:22"]
  ip_firewall        = true
  argo_smart_routing = true
}
```

**メリット:** オリジン IP を隠す、DDoS 保護、IP ファイアウォール、Argo によるレイテンシの低減

### 2. ゲームサーバー

**TypeScript (Minecraft):**
```typescript
const app = await client.spectrum.apps.create({
  zone_id: 'your-zone-id',
  protocol: 'tcp/25565',
  dns: { type: 'CNAME', name: 'mc.example.com' },
  origin_direct: ['tcp://192.168.1.10:25565'],
  proxy_protocol: 'v1',  // Preserves player IPs
  argo_smart_routing: true,
});
```

**メリット:** DDoS 保護、オリジン IP を隠す、プレイヤー IP と BAN に対応する Proxy Protocol、Argo によるレイテンシの低減

### 3. MQTT ブローカー

IoT デバイス間の通信。

**TypeScript:**
```typescript
const mqttApp = await client.spectrum.apps.create({
  zone_id: 'your-zone-id',
  protocol: 'tcp/8883',  // Use 1883 for plain MQTT
  dns: { type: 'CNAME', name: 'mqtt.example.com' },
  origin_direct: ['tcp://mqtt-broker.internal:8883'],
  tls: 'full',  // Use 'off' for plain MQTT
});
```

**メリット:** DDoS 保護、ブローカー IP を隠す、エッジでの TLS 終端

### 4. SMTP リレー

メール送信（ポート 587）。**警告**: [gotchas.md](gotchas.md#smtp-reverse-dns) を参照してください。

**Terraform:**
```hcl
resource "cloudflare_spectrum_application" "smtp" {
  zone_id  = var.zone_id
  protocol = "tcp/587"

  dns {
    type = "CNAME"
    name = "smtp.example.com"
  }

  origin_direct = ["tcp://mail-server.internal:587"]
  tls           = "full"  # STARTTLS support
}
```

**制限事項:**
- Spectrum の IP には逆引き DNS（PTR レコード）がありません
- 多くのメールサーバーは、有効な rDNS がない接続を拒否します
- 内部または信頼できるリレーでのみ使用するのが最適です

### 5. データベースプロキシ

MySQL/PostgreSQL。**慎重に使用してください** - セキュリティ上、重要な設定です。

**PostgreSQL:**
```typescript
const postgresApp = await client.spectrum.apps.create({
  zone_id: 'your-zone-id',
  protocol: 'tcp/5432',
  dns: { type: 'CNAME', name: 'postgres.example.com' },
  origin_dns: { name: 'db-primary.internal.example.com' },
  origin_port: 5432,
  tls: 'strict',      // REQUIRED
  ip_firewall: true,  // REQUIRED
});
```

**MySQL:**
```hcl
resource "cloudflare_spectrum_application" "mysql" {
  zone_id  = var.zone_id
  protocol = "tcp/3306"

  dns {
    type = "CNAME"
    name = "mysql.example.com"
  }

  origin_dns {
    name = "mysql-primary.internal.example.com"
  }

  origin_port = 3306
  tls         = "strict"
  ip_firewall = true
}
```

**セキュリティ:**
- 必ず `tls: "strict"` を使用してください
- 必ず `ip_firewall: true` を使用してください
- ゾーンファイアウォールで既知の IP に制限してください
- 強力な DB 認証を使用してください
- 代わりに VPN または Cloudflare Access の使用を検討してください

### 6. RDP（リモートデスクトップ）

**IP ファイアウォールが必要です。**

**Terraform:**
```hcl
resource "cloudflare_spectrum_application" "rdp" {
  zone_id  = var.zone_id
  protocol = "tcp/3389"

  dns {
    type = "CNAME"
    name = "rdp.example.com"
  }

  origin_direct = ["tcp://windows-server.internal:3389"]
  tls           = "off"       # RDP has own encryption
  ip_firewall   = true        # REQUIRED
}
```

**セキュリティ:** 必ず `ip_firewall: true` を実施し、管理者 IP を許可リストに登録してください。RDP は DDoS や総当たり攻撃の標的になります。

### 7. 複数オリジンのフェイルオーバー

ロードバランサーによる高可用性。

**Terraform:**
```hcl
resource "cloudflare_load_balancer" "database_lb" {
  zone_id          = var.zone_id
  name             = "db-lb.example.com"
  default_pool_ids = [cloudflare_load_balancer_pool.db_primary.id]
  fallback_pool_id = cloudflare_load_balancer_pool.db_secondary.id
}

resource "cloudflare_load_balancer_pool" "db_primary" {
  name    = "db-primary-pool"
  origins { name = "db-1"; address = "192.0.2.1" }
  monitor = cloudflare_load_balancer_monitor.postgres_monitor.id
}

resource "cloudflare_load_balancer_pool" "db_secondary" {
  name    = "db-secondary-pool"
  origins { name = "db-2"; address = "192.0.2.2" }
  monitor = cloudflare_load_balancer_monitor.postgres_monitor.id
}

resource "cloudflare_load_balancer_monitor" "postgres_monitor" {
  type = "tcp"; port = 5432; interval = 30; timeout = 5
}

resource "cloudflare_spectrum_application" "postgres_ha" {
  zone_id     = var.zone_id
  protocol    = "tcp/5432"
  dns         { type = "CNAME"; name = "postgres.example.com" }
  origin_dns  { name = cloudflare_load_balancer.database_lb.name }
  origin_port = 5432
  tls         = "strict"
  ip_firewall = true
}
```

**メリット:** 自動フェイルオーバー、ヘルスモニタリング、トラフィック分散、ダウンタイムなしのデプロイ

## 関連項目

- [configuration.md](configuration.md) - オリジンタイプの設定
- [gotchas.md](gotchas.md) - プロトコルの制限事項
- [api.md](api.md) - SDK リファレンス