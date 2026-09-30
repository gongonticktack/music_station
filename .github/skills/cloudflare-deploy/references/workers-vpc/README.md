# Workers VPC 接続

TCP ソケットを使用して、Cloudflare Workers をプライベートネットワークや内部インフラストラクチャに接続します。

## 概要

Workers VPC 接続により、Workers から AWS、Azure、GCP、オンプレミスのデータセンター、または任意のプライベートネットワーク内のリソースへ、アウトバウンド TCP 接続を確立できます。これは **TCP Sockets API** (`cloudflare:sockets`) を通じて実現されます。この API は、カスタムプロトコルやサービス向けの低レベルなネットワークアクセスを提供します。

**主な機能:**
- プライベート IP アドレスやホスト名への直接 TCP 接続
- 暗号化接続のための TLS/StartTLS サポート
- セキュアなプライベートネットワークアクセスを実現する Cloudflare Tunnel との統合
- ワイヤプロトコル（データベースプロトコル、SSH、MQTT、カスタム TCP）の完全な制御

**注:** このリファレンスでは TCP Sockets API について説明します。新しい Workers VPC Services 製品（SSRF 保護が組み込まれた HTTP 専用サービスバインディング）については、別途ドキュメントが公開された際にそちらを参照してください。VPC Services は現在ベータ版です（2025 年以降）。

## すばやく選ぶ: どの技術を使うべきか？

Workers からプライベートネットワークに接続する必要がありますか？

| 要件 | 使用するもの | 理由 |
|------------|-----|-----|
| プライベートネットワーク内の HTTP/HTTPS API | VPC Services（ベータ版、別ドキュメント） | SSRF に安全、宣言的なバインディング |
| PostgreSQL/MySQL データベース | [Hyperdrive](../hyperdrive/) | コネクションプーリング、キャッシュ、最適化 |
| カスタム TCP プロトコル（SSH、MQTT、独自プロトコル） | **TCP Sockets（このドキュメント）** | プロトコルを完全に制御できる |
| 最低レイテンシのシンプルな HTTP | TCP Sockets + [Smart Placement](../smart-placement/) | 手動で最適化 |
| オンプレミス環境をインターネットに公開（インバウンド） | [Cloudflare Tunnel](../tunnel/) | Workers 専用ではない |

## TCP Sockets を使う場面

**次のような場合は TCP Sockets を使用してください:**
- ✅ ワイヤプロトコルを直接制御する必要がある（例: Postgres ワイヤプロトコル、SSH、Redis RESP）
- ✅ HTTP 以外のプロトコルを使用する（MQTT、SMTP、カスタムバイナリプロトコル）
- ✅ StartTLS またはカスタム TLS ネゴシエーションが必要
- ✅ TCP 経由でバイナリデータをストリーミングする

**次のような場合は TCP Sockets を使用しないでください:**
- ❌ HTTP/HTTPS だけが必要な場合（`fetch()` または VPC Services を使用）
- ❌ PostgreSQL/MySQL が必要な場合（コネクションプーリングには Hyperdrive を使用）
- ❌ WebSocket が必要な場合（Workers のネイティブ WebSocket を使用）

## クイックスタート

```typescript
import { connect } from 'cloudflare:sockets';

export default {
  async fetch(req: Request): Promise<Response> {
    // Connect to private service
    const socket = connect(
      { hostname: "db.internal.company.net", port: 5432 },
      { secureTransport: "on" }
    );

    try {
      await socket.opened; // Wait for connection
      
      const writer = socket.writable.getWriter();
      await writer.write(new TextEncoder().encode("QUERY\r\n"));
      await writer.close();

      const reader = socket.readable.getReader();
      const { value } = await reader.read();
      
      return new Response(value);
    } finally {
      await socket.close();
    }
  }
};
```

## アーキテクチャパターン: Workers + Tunnel

プライベートネットワークへの接続では、多くの場合 TCP Sockets と Cloudflare Tunnel を組み合わせます:

```
┌─────────┐     ┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│ Worker  │────▶│ TCP Socket  │────▶│   Tunnel     │────▶│   Private   │
│         │     │ (this API)  │     │ (cloudflared)│     │   Network   │
└─────────┘     └─────────────┘     └──────────────┘     └─────────────┘
```

1. Worker が Tunnel のホスト名に TCP ソケットを開く
2. Tunnel エンドポイントがプライベート IP アドレスへルーティングする
3. レスポンスが Tunnel 経由で Worker に返る

Tunnel の設定方法については、[configuration.md](./configuration.md) を参照してください。

## 読む順序

1. **まずここ（README.md）** - 概要と選択ガイド
2. **[api.md](./api.md)** - ソケットのインターフェイス、型、メソッド
3. **[configuration.md](./configuration.md)** - Wrangler の設定、Tunnel との統合
4. **[patterns.md](./patterns.md)** - 実用例（データベース、プロトコル、エラー処理）
5. **[gotchas.md](./gotchas.md)** - 制限、ブロックされるポート、よくあるエラー

## 主な制限

| 制限 | 値 |
|-------|-------|
| リクエストあたりの同時ソケット数の上限 | 6 |
| 接続先としてブロックされるもの | Cloudflare の IP、localhost、ポート 25 |
| スコープ要件 | ハンドラー内で作成する必要がある（グローバルでは作成しない） |

制限とトラブルシューティングの全項目については、[gotchas.md](./gotchas.md) を参照してください。

## ベストプラクティス

1. **ソケットは必ず閉じる** - try/finally ブロックを使用する
2. **接続先を検証する** - ホストを許可リストに登録して SSRF を防ぐ
3. **データベースには Hyperdrive を使用する** - 生の TCP より高いパフォーマンス
4. **HTTP には fetch() を優先する** - 必要な場合にのみ TCP を使用する
5. **Smart Placement と組み合わせる** - プライベートネットワークへのレイテンシを削減する

## 関連技術

- **[Hyperdrive](../hyperdrive/)** - コネクションプーリングを備えた PostgreSQL/MySQL
- **[Cloudflare Tunnel](../tunnel/)** - セキュアなプライベートネットワークアクセス
- **[Smart Placement](../smart-placement/)** - バックエンドの近くに Workers を自動配置
- **VPC Services（ベータ版）** - SSRF 保護を備えた HTTP 専用サービスバインディング（別ドキュメント）

## リファレンス

- [TCP Sockets API ドキュメント](https://developers.cloudflare.com/workers/runtime-apis/tcp-sockets/)
- [データベース接続ガイド](https://developers.cloudflare.com/workers/tutorials/connect-to-postgres/)
- [Cloudflare Tunnel のセットアップ](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
