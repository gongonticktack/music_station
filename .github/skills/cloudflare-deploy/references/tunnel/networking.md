# トンネルのネットワーク

## 接続要件

### アウトバウンドポート

Cloudflared には次のアウトバウンドアクセスが必要です。

| ポート | プロトコル | 用途 | 必須 |
|------|----------|---------|----------|
| 7844 | TCP/UDP | トンネルの主要プロトコル（QUIC） | はい |
| 443 | TCP | フォールバック（HTTP/2） | はい |

**ネットワーク経路:**
```
cloudflared → edge.argotunnel.com:7844 (preferred)
cloudflared → region.argotunnel.com:443 (fallback)
```

### ファイアウォールルール

#### 最小構成（本番環境）
```bash
# Outbound only
ALLOW tcp/udp 7844 to *.argotunnel.com
ALLOW tcp 443 to *.argotunnel.com
```

#### 完全構成（推奨）
```bash
# Tunnel connectivity
ALLOW tcp/udp 7844 to *.argotunnel.com
ALLOW tcp 443 to *.argotunnel.com

# API access (for token-based tunnels)
ALLOW tcp 443 to api.cloudflare.com

# Updates (optional)
ALLOW tcp 443 to github.com
ALLOW tcp 443 to objects.githubusercontent.com
```

### IP 範囲

Cloudflare Anycast IP（トンネルのエンドポイント）:
```
# IPv4
198.41.192.0/24
198.41.200.0/24

# IPv6
2606:4700::/32
```

**注:** IP をハードコードする代わりに、`*.argotunnel.com` の DNS 名前解決を使用してください。Cloudflare はエッジ拠点を追加する場合があります。

## デプロイ前チェック

デプロイ前に接続をテストします。

```bash
# Test DNS resolution
dig edge.argotunnel.com +short

# Test port 7844 (QUIC/UDP)
nc -zvu edge.argotunnel.com 7844

# Test port 443 (HTTP/2 fallback)
nc -zv edge.argotunnel.com 443

# Test with cloudflared
cloudflared tunnel --loglevel debug run my-tunnel
# Look for "Registered tunnel connection"
```

### よくある接続エラー

| エラー | 原因 | 解決策 |
|-------|-------|----------|
| 「そのようなホストはありません」 | DNS がブロックされている | UDP/TCP のポート53を許可する |
| 「コンテキストの期限を超過しました」 | ポート7844がブロックされている | UDP/TCP の7844を許可する |
| 「TLS ハンドシェイクがタイムアウトしました」 | ポート443がブロックされている | TCP 443を許可し、SSL 検査を無効にする |

## プロトコルの選択

Cloudflared はプロトコルを自動的に選択します。

| プロトコル | ポート | 優先順位 | 用途 |
|----------|------|----------|----------|
| QUIC | 7844 UDP | 1番目（優先） | 低遅延、最高のパフォーマンス |
| HTTP/2 | 443 TCP | 2番目（フォールバック） | ファイアウォールで QUIC がブロックされる場合 |

**HTTP/2 フォールバックを強制する:**
```bash
cloudflared tunnel --protocol http2 run my-tunnel
```

**有効なプロトコルを確認する:**
```bash
cloudflared tunnel info my-tunnel
# Shows "connections" with protocol type
```

## プライベートネットワークのルーティング

### WARP クライアントの要件

WARP 経由でプライベート IP にアクセスするユーザーには、次が必要です。

```bash
# Outbound (WARP client)
ALLOW udp 500,4500 to 162.159.*.* (IPsec)
ALLOW udp 2408 to 162.159.*.* (WireGuard)
ALLOW tcp 443 to *.cloudflareclient.com
```

### スプリットトンネルの設定

プライベートネットワークのみをトンネル経由でルーティングします。

```yaml
# warp-routing config
warp-routing:
  enabled: true
```

```bash
# Add specific routes
cloudflared tunnel route ip add 10.0.0.0/8 my-tunnel
cloudflared tunnel route ip add 172.16.0.0/12 my-tunnel
cloudflared tunnel route ip add 192.168.0.0/16 my-tunnel
```

WARP ユーザーは VPN なしでこれらの IP にアクセスできます。

## ネットワーク診断

### 接続診断

```bash
# Check edge selection and connection health
cloudflared tunnel info my-tunnel --output json | jq '.connections[]'

# Enable metrics endpoint
cloudflared tunnel --metrics localhost:9090 run my-tunnel
curl localhost:9090/metrics | grep cloudflared_tunnel

# Test latency
curl -w "time_total: %{time_total}\n" -o /dev/null https://myapp.example.com
```

## 企業ネットワークでの考慮事項

Cloudflared はプロキシ環境変数（`HTTP_PROXY`、`HTTPS_PROXY`、`NO_PROXY`）を尊重します。

企業プロキシが TLS を傍受する場合は、企業のルート CA をシステムの信頼ストアに追加してください。

## 帯域幅とレート制限

| 制限 | 値 | 備考 |
|-------|-------|-------|
| リクエストサイズ | 100 MB | 単一の HTTP リクエスト |
| アップロード速度 | 厳密な上限なし | ネットワーク／プランに依存 |
| 同時接続数 | トンネルあたり1000 | すべてのレプリカ合計 |
| 1秒あたりのリクエスト数 | 制限なし | DDoS 検出の対象 |

**大容量ファイルの転送:**
トンネル経由でストリーミングする代わりに、R2 または Workers とチャンク分割アップロードを使用してください。
