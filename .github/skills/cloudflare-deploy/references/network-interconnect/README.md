# Cloudflare Network Interconnect (CNI)

Cloudflareネットワークへのプライベートで高性能な接続です。**Enterprise限定**です。

## 接続タイプ

**Direct**: 共有データセンター内の物理ファイバー接続。10/100 Gbps。クロスコネクトを注文します。

**Partner**: Console Connect、Equinix、Megaportなどを介した仮想接続。パートナーのSDN経由で管理します。

**Cloud**: AWS Direct ConnectまたはGCP Cloud Interconnect。Magic WAN専用です。

## データプレーンのバージョン

**v1 (Classic)**: GREトンネルに対応。VLAN/BFD/LACPに対応。MTUは方向によって異なる（1500↓/1476↑）。ピアリングに対応。

**v2 (Beta)**: GRE非対応。双方向ともMTU 1500。VLAN/BFD/LACPは未対応。代わりにECMPを使用します。

## ユースケース

- **Magic Transit DSR**: DDoS保護、ISP経由の送信（v1/v2）
- **Magic Transit + Egress**: DDoS保護 + CF経由の送信（v1/v2）
- **Magic WAN + Zero Trust**: プライベートバックボーン（v1ではGREが必要、v2ではネイティブ対応）
- **ピアリング**: PoPでのパブリックルート（v1のみ）
- **アプリケーションセキュリティ**: WAF/Cache/LB（Magic Transit経由のv1/v2）

## 前提条件

- Enterpriseプラン
- IPv4 /24以上またはIPv6 /48以上のプレフィックス
- v1ではBGP ASN
- [拠点一覧PDF](https://developers.cloudflare.com/network-interconnect/static/cni-locations-2026-01.pdf)を参照

## 仕様

- /31ポイントツーポイントサブネット
- 光接続の最大距離は10km
- 10G: 10GBASE-LRシングルモード
- 100G: 100GBASE-LR4シングルモード
- **SLAなし**（無料サービス）
- バックアップ用のインターネット接続が必要

## スループット

| 方向 | 10G | 100G |
|-----------|-----|------|
| CF → Customer | 10 Gbps | 100 Gbps |
| Customer → CF (peering) | 10 Gbps | 100 Gbps |
| Customer → CF (Magic) | 1 Gbps/tunnel or CNI | 1 Gbps/tunnel or CNI |

## タイムライン

通常2～4週間です。手順: 申請 → 構成のレビュー → 接続を注文 → 設定 → テスト → ヘルスチェックを有効化 → 有効化 → 監視。

## このリファレンスの内容
- [configuration.md](./configuration.md) - BGP、ルーティング、セットアップ
- [api.md](./api.md) - APIエンドポイント、SDK
- [patterns.md](./patterns.md) - HA、ハイブリッドクラウド、フェイルオーバー
- [gotchas.md](./gotchas.md) - トラブルシューティング、制限事項

## タスク別の読み進め方

| タスク | 読み込むファイル |
|------|---------------|
| 初期セットアップ | README → configuration.md → api.md |
| API経由でインターコネクトを作成 | api.md → gotchas.md |
| HAアーキテクチャを設計 | patterns.md → README |
| 接続のトラブルシューティング | gotchas.md → configuration.md |
| クラウド統合（AWS/GCP） | configuration.md → patterns.md |
| 監視 + アラート | configuration.md |

## 自動化の範囲

**APIで自動化可能:**
- インターコネクトの一覧表示/作成/削除（Direct、Partner）
- 利用可能なスロットの一覧表示
- インターコネクトのステータス取得
- LOA PDFのダウンロード
- CNIオブジェクト（BGP設定）の作成/更新
- 設定の照会

**アカウントチームへの依頼が必要:**
- 初回申請の承認
- AWS Direct Connectのセットアップ（LOA+VLANをCFに送付）
- GCP Cloud Interconnectの最終有効化
- パートナーインターコネクトの承認（Equinix、Megaport）
- VLANの割り当て（v1）
- 構成ドキュメントの生成（v1）
- エスカレーション + トラブルシューティングのサポート

**自動化できない作業:**
- 物理クロスコネクトの設置（Direct）
- パートナーポータルでの操作（仮想回線の注文）
- AWS/GCPポータルでの操作
- メンテナンス時間帯の調整

## 関連項目
- [tunnel](../tunnel/) - プライベートネットワーク接続の代替手段
- [spectrum](../spectrum/) - TCP/UDPトラフィック向けレイヤー4プロキシ
