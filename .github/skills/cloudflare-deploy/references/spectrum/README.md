# Cloudflare Spectrum スキルリファレンス

## 概要

Cloudflare Spectrum は、TCP または UDP ベースのあらゆるアプリケーションにセキュリティと高速化を提供します。Cloudflare のエッジノード上で動作するグローバルなレイヤー 4（L4）リバースプロキシであり、MQTT、メール、ファイル転送、バージョン管理、ゲームなどのトラフィックを Cloudflare 経由でルーティングし、オリジンを隠して DDoS 攻撃から保護します。

**Spectrum を使用する場面**: プロトコルが HTTP/HTTPS ではない場合（HTTP には Cloudflare プロキシを使用してください）。Spectrum はそれ以外のすべてに対応します。SSH、ゲーム、データベース、MQTT、SMTP、RDP、カスタムプロトコルなどが対象です。

## プラン別の機能

| 機能 | Pro/Business | Enterprise |
|------------|--------------|------------|
| TCP プロトコル | 選択されたポートのみ | すべてのポート（1-65535） |
| UDP プロトコル | 選択されたポートのみ | すべてのポート（1-65535） |
| ポート範囲 | ❌ | ✅ |
| Argo Smart Routing | ✅ | ✅ |
| IP ファイアウォール | ✅ | ✅ |
| ロードバランサーのオリジン | ✅ | ✅ |

## 判断フロー

**何をしようとしていますか？**

1. **Spectrum アプリを作成・管理する**
   - ダッシュボード経由 → [Cloudflare Dashboard](https://dash.cloudflare.com) を参照
   - API 経由 → REST エンドポイントについては [api.md](api.md) を参照
   - SDK 経由 → TypeScript/Python/Go の例については [api.md](api.md) を参照
   - IaC 経由 → Terraform/Pulumi については [configuration.md](configuration.md) を参照

2. **特定のプロトコルを保護する**
   - SSH → [patterns.md](patterns.md#1-ssh-server-protection) を参照
   - ゲーム（Minecraft など） → [patterns.md](patterns.md#2-game-server) を参照
   - MQTT/IoT → [patterns.md](patterns.md#3-mqtt-broker) を参照
   - SMTP/メール → [patterns.md](patterns.md#4-smtp-relay) を参照
   - データベース → [patterns.md](patterns.md#5-database-proxy) を参照
   - RDP → [patterns.md](patterns.md#6-rdp-remote-desktop) を参照

3. **オリジンタイプを選択する**
   - 直接 IP（単一サーバー） → [configuration.md](configuration.md#direct-ip-origin) を参照
   - CNAME（ホスト名） → [configuration.md](configuration.md#cname-origin) を参照
   - ロードバランサー（HA/フェイルオーバー） → [configuration.md](configuration.md#load-balancer-origin) を参照

## 読む順序

1. 使用するプロトコルに応じて [patterns.md](patterns.md) から始めてください
2. 次に、オリジンタイプについて [configuration.md](configuration.md) を確認してください
3. 本番環境に移行する前に [gotchas.md](gotchas.md) を確認してください
4. プログラムから利用する場合は [api.md](api.md) を参照してください

## 関連項目

- [Cloudflare Docs](https://developers.cloudflare.com/spectrum/)