# トンネルの設定

## 設定ソース

トンネルでは、次のいずれかの設定ソースを使用します:

| 設定ソース | 保存場所 | 更新方法 | 用途 |
|---------------|---------|---------|----------|
| ローカル | `config.yml` ファイル | ファイルを編集して再起動 | 開発、複数環境、バージョン管理 |
| Cloudflare | ダッシュボード/API | 即時反映、再起動不要 | 本番環境、一元管理 |

**トークンベースのトンネル** = 設定ソース: Cloudflare
**ローカル管理のトンネル** = 設定ソース: ローカル

## 設定ファイルの場所

```
~/.cloudflared/config.yml          # User config
/etc/cloudflared/config.yml        # System-wide (Linux)
```

## 基本構造

```yaml
tunnel: <UUID>
credentials-file: /path/to/<UUID>.json

ingress:
  - hostname: app.example.com
    service: http://localhost:8000
  - service: http_status:404  # Required catch-all
```

## イングレスルール

ルールは**上から順に**評価され、最初に一致したルールが適用されます。

```yaml
ingress:
  # Exact hostname + path regex
  - hostname: static.example.com
    path: \.(jpg|png|css|js)$
    service: https://localhost:8001
  
  # Wildcard hostname
  - hostname: "*.example.com"
    service: https://localhost:8002
  
  # Path only (all hostnames)
  - path: /api/.*
    service: http://localhost:9000
  
  # Catch-all (required)
  - service: http_status:404
```

**検証**:
```bash
cloudflared tunnel ingress validate
cloudflared tunnel ingress rule https://foo.example.com
```

## サービスタイプ

| プロトコル | 形式 | クライアント要件 |
|----------|--------|-------------------|
| HTTP | `http://localhost:8000` | ブラウザー |
| HTTPS | `https://localhost:8443` | ブラウザー |
| TCP | `tcp://localhost:2222` | `cloudflared access tcp` |
| SSH | `ssh://localhost:22` | `cloudflared access ssh` |
| RDP | `rdp://localhost:3389` | `cloudflared access rdp` |
| Unix | `unix:/path/to/socket` | ブラウザー |
| テスト | `hello_world` | ブラウザー |

## オリジンの設定

### 接続設定
```yaml
originRequest:
  connectTimeout: 30s
  tlsTimeout: 10s
  tcpKeepAlive: 30s
  keepAliveTimeout: 90s
  keepAliveConnections: 100
```

### TLS 設定
```yaml
originRequest:
  noTLSVerify: true                      # Disable cert verification
  originServerName: "app.internal"       # Override SNI
  caPool: /path/to/ca.pem                # Custom CA
```

### HTTP 設定
```yaml
originRequest:
  disableChunkedEncoding: true
  httpHostHeader: "app.internal"
  http2Origin: true
```

## プライベートネットワークモード

```yaml
tunnel: <UUID>
credentials-file: /path/to/creds.json

warp-routing:
  enabled: true
```

```bash
cloudflared tunnel route ip add 10.0.0.0/8 my-tunnel
cloudflared tunnel route ip add 192.168.1.100/32 my-tunnel
```

## 設定ソースの比較

### ローカル設定
```yaml
# config.yml
tunnel: <UUID>
credentials-file: /path/to/<UUID>.json

ingress:
  - hostname: app.example.com
    service: http://localhost:8000
  - service: http_status:404
```

```bash
cloudflared tunnel run my-tunnel
```

**利点:** バージョン管理、複数環境、オフラインでの編集
**欠点:** ファイルの配布が必要、手動での再起動が必要

### Cloudflare 設定（トークンベース）
```bash
# No config file needed
cloudflared tunnel --no-autoupdate run --token <TOKEN>
```

ダッシュボードでルートを設定します: **Zero Trust** > **Networks** > **Tunnels** > [トンネル] > **Public Hostname**

**利点:** 一元的な更新、ファイル管理不要、ルート変更が即時反映
**欠点:** ダッシュボード/API へのアクセスが必要、移植性が低い

## 環境変数

```bash
TUNNEL_TOKEN=<token>                    # Token for config source: cloudflare
TUNNEL_ORIGIN_CERT=/path/to/cert.pem   # Override cert path (local config)
NO_AUTOUPDATE=true                      # Disable auto-updates
TUNNEL_LOGLEVEL=debug                   # Log level
```