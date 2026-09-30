# Cloudflare Tunnel

インフラストラクチャと Cloudflare のグローバルネットワーク間に、外向き専用の安全な接続を確立します。

## 概要

Cloudflare Tunnel（旧称 Argo Tunnel）では、次のことができます。
- **外向き専用の接続** - インバウンドポートの開放やファイアウォールの変更は不要
- **パブリックホスト名によるルーティング** - ローカルサービスをインターネットに公開
- **プライベートネットワークへのアクセス** - WARP 経由で内部ネットワークに接続
- **Zero Trust との統合** - アクセスポリシーを標準で利用可能

**アーキテクチャ**: Tunnel（永続オブジェクト）→ Replica（`cloudflared` プロセス）→ オリジンサービス

**用語:**
- **Tunnel**: UUID を持つ、名前付きの永続オブジェクト
- **Replica**: Tunnel に接続された個々の `cloudflared` プロセス
- **設定ソース**: イングレスルールの保存先（ローカルファイルまたは Cloudflare ダッシュボード）
- **Connector**: Replica の旧称

## クイックスタート

### ローカル設定
```bash
# Install cloudflared
brew install cloudflared  # macOS

# Authenticate
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create my-tunnel

# Route DNS
cloudflared tunnel route dns my-tunnel app.example.com

# Run tunnel
cloudflared tunnel run my-tunnel
```

### ダッシュボード設定（推奨）
1. **Zero Trust** > **Networks** > **Tunnels** > **Create** の順に選択
2. Tunnel に名前を付け、トークンをコピー
3. ダッシュボードでルートを設定
4. 実行: `cloudflared tunnel --no-autoupdate run --token <TOKEN>`

## 選択フロー

**設定ソースを選ぶ:**
```
Need centralized config updates?
├─ Yes → Token-based (dashboard config)
└─ No → Local config file

Multiple environments (dev/staging/prod)?
├─ Yes → Local config (version controlled)
└─ No → Either works

Need firewall approval?
└─ See networking.md first
```

## 主なコマンド

```bash
# Tunnel lifecycle
cloudflared tunnel create <name>
cloudflared tunnel list
cloudflared tunnel info <name>
cloudflared tunnel delete <name>

# DNS routing
cloudflared tunnel route dns <tunnel> <hostname>
cloudflared tunnel route list

# Private network
cloudflared tunnel route ip add 10.0.0.0/8 <tunnel>

# Run tunnel
cloudflared tunnel run <name>
```

## 設定例

```yaml
# ~/.cloudflared/config.yml
tunnel: 6ff42ae2-765d-4adf-8112-31c55c1551ef
credentials-file: /root/.cloudflared/6ff42ae2-765d-4adf-8112-31c55c1551ef.json

ingress:
  - hostname: app.example.com
    service: http://localhost:8000
  - hostname: api.example.com
    service: https://localhost:8443
    originRequest:
      noTLSVerify: true
  - service: http_status:404
```

## 読む順序

**Cloudflare Tunnel を初めて使う場合:**
1. この README（概要、クイックスタート）
2. [networking.md](./networking.md) - ファイアウォールルール、接続前の確認
3. [configuration.md](./configuration.md) - 設定ファイルのオプション、イングレスルール
4. [patterns.md](./patterns.md) - Docker、Kubernetes、本番環境へのデプロイ
5. [gotchas.md](./gotchas.md) - トラブルシューティング、ベストプラクティス

**エンタープライズ環境へのデプロイ:**
1. [networking.md](./networking.md) - 企業ファイアウォールの要件
2. [gotchas.md](./gotchas.md) - HA 構成、セキュリティのベストプラクティス
3. [patterns.md](./patterns.md) - Kubernetes、ローリングアップデート

**プログラムからの制御:**
1. [api.md](./api.md) - REST API、TypeScript SDK

## このリファレンスの内容

- [networking.md](./networking.md) - ファイアウォールルール、ポート、接続前の確認
- [configuration.md](./configuration.md) - 設定ファイルのオプション、イングレスルール、TLS 設定
- [api.md](./api.md) - REST API、TypeScript SDK、トークンベースの Tunnel
- [patterns.md](./patterns.md) - Docker、Kubernetes、Terraform、HA、ユースケース
- [gotchas.md](./gotchas.md) - トラブルシューティング、制限事項、ベストプラクティス

## 関連項目

- [workers](../workers/) - Tunnel と統合した Workers
- [access](../access/) - Zero Trust アクセスポリシー
- [warp](../warp/) - プライベートネットワーク用 WARP クライアント
