# CNI の設定

概要については [README.md](README.md) を参照してください。

## ワークフロー（2～4 週間）

1. **リクエストを送信**（第1週）：アカウントチームに連絡し、種類、場所、用途を伝える
2. **設定を確認**（第1～2週、v1 のみ）：IP／VLAN／仕様書を承認する
3. **接続を発注**（第2～3週）：
   - **Direct**：LOA を受け取り、施設にクロスコネクトを発注する
   - **Partner**：パートナーポータルで仮想回線を発注する
   - **Cloud**：Direct Connect／Cloud Interconnect を発注し、LOA と VLAN を CF に送付する
4. **設定**（第3週）：仕様書に従って両側を設定する
5. **テスト**（第3～4週）：ping を実行し、BGP を確認して、ルートをチェックする
6. **ヘルスチェック**（第4週）：[Magic Transit](https://developers.cloudflare.com/magic-transit/how-to/configure-tunnel-endpoints/#add-tunnels) または [Magic WAN](https://developers.cloudflare.com/magic-wan/configuration/manually/how-to/configure-tunnel-endpoints/#add-tunnels) のヘルスチェックを設定する
7. **有効化**（第4週）：トラフィックをルーティングし、通信を確認する
8. **監視**：[メンテナンス通知](https://developers.cloudflare.com/network-interconnect/monitoring-and-alerts/#enable-cloudflare-status-maintenance-notification)を有効にする

## BGP の設定

**v1 の要件：**
- BGP ASN（セットアップ時に提示）
- ピアリング用の /31 サブネット
- 任意：BGP パスワード

**v2：**設定が簡素化され、必要な BGP 設定が少なくなっています。

**CNI 経由の BGP（2024年12月）：**Magic WAN/Transit は CNI v2 経由で BGP を直接ピアリングできるようになりました（GRE トンネルは不要です）。

**v1 の BGP 設定例：**
```
Router ID: 192.0.2.1
Peer IP: 192.0.2.0
Remote ASN: 13335
Local ASN: 65000
Password: [optional]
VLAN: 100
```

## Cloud Interconnect の設定

### AWS Direct Connect（ベータ）

**要件：**Magic WAN、AWS Dedicated Direct Connect 1/10 Gbps。

**手順：**
1. CF アカウントチームに連絡する
2. ロケーションを選択する
3. AWS ポータルで発注する
4. AWS から LOA と VLAN ID が提供される
5. CF アカウントチームに送付する
6. 約4週間待つ

**設定後：**Magic WAN に[静的ルート](https://developers.cloudflare.com/magic-wan/configuration/manually/how-to/configure-routes/#configure-static-routes)を追加します。[双方向ヘルスチェック](https://developers.cloudflare.com/magic-wan/configuration/manually/how-to/configure-tunnel-endpoints/#legacy-bidirectional-health-checks)を有効にします。

### GCP Cloud Interconnect（ベータ）

**ダッシュボードからの設定：**
1. Interconnects → Create → Cloud Interconnect → Google
2. 名前、MTU（GCP VLAN アタッチメントに合わせる）、速度（パートナー相互接続では 50M～50G の細かな選択肢を利用可能）を指定する
3. VLAN アタッチメントのペアリングキーを入力する
4. 注文を確定する

**GCP へのルーティング：**[静的ルート](https://developers.cloudflare.com/magic-wan/configuration/manually/how-to/configure-routes/#configure-static-routes)を追加します。GCP Cloud Router からの BGP ルートは**無視されます**。

**CF へのルーティング：**Cloud Router で[カスタム学習ルート](https://cloud.google.com/network-connectivity/docs/router/how-to/configure-custom-learned-routes)を設定します。プレフィックスを CF アカウントチームに問い合わせてください。

## 監視

**ダッシュボードのステータス：**

| ステータス | 意味 |
|--------|---------|
| **Healthy** | リンクは稼働中で、トラフィックが流れ、ヘルスチェックに合格しています |
| **Active** | リンクはアップしており、十分な光レベルがあり、Ethernet のネゴシエーションが完了しています |
| **Unhealthy** | リンクがダウンしている、光レベルがない／低い（<-20 dBm）、またはネゴシエーションできません |
| **Pending** | クロスコネクトが未完了、デバイスが応答しない、または RX/TX が逆になっています |
| **Down** | 物理リンクがダウンしており、接続できません |

**アラート：**

**CNI 接続メンテナンス**（Magic Networking のみ）：
```
Dashboard → Notifications → Add
Product: Cloudflare Network Interconnect
Type: Connection Maintenance Alert
```
最大2週間前に警告します。新規追加には6時間の遅延があります。

**Cloudflare Status のメンテナンス**（PoP 全体）：
```
Dashboard → Notifications → Add
Product: Cloudflare Status
Filter PoPs: gru,fra,lhr
```

**PoP コードの確認方法：**
```
Dashboard → Magic Transit/WAN → Configuration → Interconnects
Select CNI → Note Data Center (e.g., "gru-b")
Use first 3 letters: "gru"
```

## ベストプラクティス

**設定に関する重要なプラクティス：**
- BGP には /31 サブネットが必要
- BGP パスワードを推奨
- 高速フェイルオーバーには BFD を使用（v1 のみ）
- BGP の前に ping で接続性をテストする
- 有効化後すぐにメンテナンス通知を有効にする
- API 経由でプログラムからステータスを監視する

設計パターン、高可用性アーキテクチャ、セキュリティのベストプラクティスについては、[patterns.md](./patterns.md)を参照してください。
