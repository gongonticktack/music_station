# トンネルに関する注意点

## よくあるエラー

### 「Error 1016（オリジン DNS エラー）」

**原因:** トンネルが起動していない、または接続されていない
**解決策:**
```bash
cloudflared tunnel info my-tunnel     # Check status
ps aux | grep cloudflared             # Verify running
journalctl -u cloudflared -n 100      # Check logs
```

### 「自己署名証明書が拒否される」

**原因:** オリジンで自己署名証明書を使用している
**解決策:**
```yaml
originRequest:
  noTLSVerify: true      # Dev only
  caPool: /path/to/ca.pem  # Custom CA
```

### 「接続がタイムアウトする」

**原因:** オリジンの応答が遅い、またはタイムアウト設定が低すぎる
**解決策:**
```yaml
originRequest:
  connectTimeout: 60s
  tlsTimeout: 20s
  keepAliveTimeout: 120s
```

### 「トンネルが起動しない」

**原因:** 設定が無効、認証情報がない、またはトンネルが存在しない
**解決策:**
```bash
cloudflared tunnel ingress validate  # Validate config
ls -la ~/.cloudflared/*.json         # Verify credentials
cloudflared tunnel list              # Verify tunnel exists
```

### 「接続はすでに登録されています」

**原因:** 同じコネクター ID を持つレプリカが複数ある、または古い接続が残っている
**解決策:**
```bash
# Check active connections
cloudflared tunnel info my-tunnel

# Wait 60s for stale connection cleanup, or restart with new connector ID
cloudflared tunnel run my-tunnel
```

### 「トンネルの認証情報をローテーションした後、接続に失敗する」

**原因:** 期限切れの認証情報を使用している古い cloudflared プロセス
**解決策:**
```bash
# Stop all cloudflared processes
pkill cloudflared

# Verify stopped
ps aux | grep cloudflared

# Restart with new credentials
cloudflared tunnel run my-tunnel
```

## 制限

| リソース／制限 | 値 | 備考 |
|----------------|-------|-------|
| 無料プラン | トンネル数無制限 | トラフィック無制限 |
| トンネルレプリカ | トンネルあたり 1000 | 同時接続の最大数 |
| 接続時間 | 厳密な上限なし | 数時間から数日 |
| 長時間接続 | 更新中に切断される場合あり | WebSocket、SSH、UDP |
| レプリカ登録 | TTL 約5秒 | ハートビートが5秒間ないと古いレプリカを切断 |
| トークンローテーションの猶予期間 | 24時間 | 猶予期間中は古いトークンも使用可能 |

## ベストプラクティス

### セキュリティ
1. 集中管理のため、トークンベースのトンネル（設定ソース: cloudflare）を使用する
2. 機密性の高いサービスには Access ポリシーを有効にする
3. トンネルの認証情報を定期的にローテーションする
4. ローテーション後、24時間の猶予期間内に古い cloudflared プロセスをすべて停止する
5. TLS 証明書を確認する（`noTLSVerify: false`）
6. `bastion` のサービス種別を制限する

### パフォーマンス
1. 高可用性のために複数のレプリカを実行する（通常は2～4個で、自動的に負荷分散される）
2. レプリカは同じトンネル UUID を共有し、それぞれ一意のコネクター ID を取得する
3. `cloudflared` をオリジンの近く（同じネットワーク内）に配置する
4. gRPC には HTTP/2 を使用する（`http2Origin: true`）
5. 長時間接続向けに keepalive を調整する
6. 接続数を監視する

### 設定
1. シークレットには環境変数を使用する
2. 設定ファイルをバージョン管理する
3. デプロイ前に検証する（`cloudflared tunnel ingress validate`）
4. ルールをテストする（`cloudflared tunnel ingress rule <URL>`）
5. ルールの順序を文書化する（最初に一致したルールが適用される）

### 運用
1. ダッシュボードでトンネルの状態を監視する（アクティブなレプリカが表示される）
2. 切断アラートを設定する（レプリカ数が0になったとき）
3. 設定更新時は正常にシャットダウンする
4. レプリカを順次更新する（1つ更新して待機し、次を更新する）
5. `cloudflared` を最新の状態に保つ（サポート期間は1年間）
6. 本番環境では `--no-autoupdate` を使用し、更新を手動で管理する

## デバッグモード

```bash
cloudflared tunnel --loglevel debug run my-tunnel
cloudflared tunnel ingress rule https://app.example.com
```

## 移行方法

### Ngrok からの移行
```yaml
# Ngrok: ngrok http 8000
# Cloudflare Tunnel:
ingress:
  - hostname: app.example.com
    service: http://localhost:8000
  - service: http_status:404
```

### VPN からの移行
```yaml
# Replace VPN with private network routing
warp-routing:
  enabled: true
```

```bash
cloudflared tunnel route ip add 10.0.0.0/8 my-tunnel
```

ユーザーは VPN の代わりに WARP クライアントをインストールします。
