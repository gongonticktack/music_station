# Cloudflare TURN サービス

WebRTC アプリケーションで Cloudflare TURN サービスを実装するための専門的なガイダンスです。

## 概要

Cloudflare TURN（NAT 越えリレー）は、WebRTC アプリケーション向けのマネージドリレーサービスです。TURN は、特に NAT やファイアウォールによって直接のピアツーピア通信が妨げられる場合に、WebRTC クライアントと SFU 間のトラフィックを中継します。このサービスは、310 以上の都市に広がる Cloudflare のグローバル Anycast ネットワーク上で稼働します。

## 主な特徴

- **Anycast アーキテクチャ**：クライアントを最寄りの Cloudflare 拠点に自動接続
- **グローバルネットワーク**：Cloudflare のネットワーク全域で利用可能（中国ネットワークを除く）
- **設定不要**：リージョンやサーバーを手動で選択する必要なし
- **プロトコル対応**：UDP、TCP、TLS 経由の STUN/TURN
- **無料枠**：Cloudflare Calls SFU と併用する場合は無料。それ以外は送信 1 GB あたり $0.05

## このリファレンスの内容

| ファイル | 用途 |
|------|---------|
| [api.md](./api.md) | 認証情報 API、TURN キー管理、型、制約 |
| [configuration.md](./configuration.md) | Worker の設定、wrangler.jsonc、環境変数、IP 許可リスト |
| [patterns.md](./patterns.md) | 実装パターン、ユースケース、統合例 |
| [gotchas.md](./gotchas.md) | トラブルシューティング、制限、セキュリティ、よくある間違い |

## 読む順序

| 作業 | 読むファイル | 推定トークン数 |
|------|---------------|-------------|
| クイックスタート | README のみ | ~500 |
| 認証情報の生成 | README → api | ~1300 |
| Worker との統合 | README → configuration → patterns | ~2000 |
| 接続のデバッグ | gotchas | ~700 |
| セキュリティレビュー | api → gotchas | ~1500 |
| 企業ファイアウォール | configuration | ~600 |

## サービスのアドレスとポート

### UDP 経由の STUN
- **優先**：`stun.cloudflare.com:3478/udp`
- **代替**：`stun.cloudflare.com:53/udp`（ブラウザーでブロックされるため非推奨）

### UDP 経由の TURN
- **優先**：`turn.cloudflare.com:3478/udp`
- **代替**：`turn.cloudflare.com:53/udp`（ブラウザーでブロックされる）

### TCP 経由の TURN
- **優先**：`turn.cloudflare.com:3478/tcp`
- **代替**：`turn.cloudflare.com:80/tcp`

### TLS 経由の TURN
- **優先**：`turn.cloudflare.com:5349/tcp`
- **代替**：`turn.cloudflare.com:443/tcp`

## クイックスタート

1. **API で TURN キーを作成**：[api.md#create-turn-key](./api.md#create-turn-key) を参照
2. **認証情報を生成**：[api.md#generate-temporary-credentials](./api.md#generate-temporary-credentials) を参照
3. **Worker を設定**：[configuration.md#cloudflare-worker-integration](./configuration.md#cloudflare-worker-integration) を参照
4. **クライアントを実装**：[patterns.md#basic-turn-configuration-browser](./patterns.md#basic-turn-configuration-browser) を参照

## TURN を使用する場面

- **制限の厳しい NAT**：直接接続をブロックする対称型 NAT
- **企業のファイアウォール**：WebRTC ポートをブロックする環境
- **モバイルネットワーク**：キャリアグレード NAT の環境
- **安定した接続が必要な場合**：効率性より信頼性を優先するとき

## 関連する Cloudflare サービス

- **Cloudflare Calls SFU**：マネージド Selective Forwarding Unit（SFU と併用する場合、TURN は無料）
- **Cloudflare Stream**：WHIP/WHEP に対応した動画ストリーミング
- **Cloudflare Workers**：認証情報生成用のバックエンド
- **Cloudflare KV**：認証情報のキャッシュ
- **Cloudflare Durable Objects**：セッション状態の管理

## 追加リソース

- [Cloudflare Calls Documentation](https://developers.cloudflare.com/calls/)
- [Cloudflare TURN Service Docs](https://developers.cloudflare.com/realtime/turn/)
- [Cloudflare API Reference](https://developers.cloudflare.com/api/resources/calls/subresources/turn/)
- [Orange Meets (Open Source Example)](https://github.com/cloudflare/orange)
