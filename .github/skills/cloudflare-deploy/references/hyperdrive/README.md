# Hyperdrive

接続プーリング、エッジでの接続セットアップ、クエリキャッシュにより、Workersからのデータベースクエリを高速化します。

## 主な機能

- **接続プーリング**: 永続接続により、TCP/TLS/認証のハンドシェイク（約7往復）をなくします
- **エッジでのセットアップ**: 接続ネゴシエーションはエッジで行い、接続プーリングはオリジンの近くで行います
- **クエリキャッシュ**: 変更を伴わないクエリを自動的にキャッシュします（デフォルトのTTLは60秒）
- **対応データベース**: PostgreSQL、MySQLおよび互換データベース（CockroachDB、Timescale、PlanetScale、Neon、Supabase）

## アーキテクチャ

```
Worker → Edge (setup) → Pool (near DB) → Origin
         ↓ cached reads
         Cache
```

## クイックスタート

```bash
# Create config
npx wrangler hyperdrive create my-db \
  --connection-string="postgres://user:pass@host:5432/db"

# wrangler.jsonc
{
  "compatibility_flags": ["nodejs_compat"],
  "hyperdrive": [{"binding": "HYPERDRIVE", "id": "<ID>"}]
}
```

```typescript
import { Client } from "pg";

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const client = new Client({
      connectionString: env.HYPERDRIVE.connectionString,
    });
    await client.connect();
    const result = await client.query("SELECT * FROM users WHERE id = $1", [123]);
    await client.end();
    return Response.json(result.rows);
  },
};
```

## 使用する場面

✅ 単一リージョンのデータベースへのグローバルアクセス、読み取り比率の高いワークロード、頻繁に使われるクエリ、接続負荷の高いワークロード
❌ 書き込み中心のワークロード、リアルタイムデータ（1秒未満）、データベースに近い単一リージョンのアプリ

**💡 Smart Placementとの併用**: 複数のクエリを実行するWorkersでは、レイテンシを最小限に抑えるため、データベースの近くで実行します。

## ドライバーの選択

| ドライバー | 使用する場面 | 備考 |
|--------|----------|-------|
| **pg** (推奨) | 一般的な用途、TypeScript、エコシステムとの互換性 | 安定して広く使われており、ほとんどのORMで動作します |
| **postgres.js** | 高度な機能、テンプレートリテラル、ストリーミング | pgより軽量で、`prepare: true`がデフォルトです |
| **mysql2** | MySQL/MariaDB/PlanetScale | MySQLのみ対応し、サポートは比較的新しい段階です |

## 読む順序

| Hyperdriveが初めての方 | 実装する方 | トラブルシューティング |
|-------------------|--------------|-----------------|
| 1. README (このファイル) | 1. [configuration.md](./configuration.md) | 1. [gotchas.md](./gotchas.md) |
| 2. [configuration.md](./configuration.md) | 2. [api.md](./api.md) | 2. [patterns.md](./patterns.md) |
| 3. [api.md](./api.md) | 3. [patterns.md](./patterns.md) | 3. [api.md](./api.md) |

## このリファレンスの内容
- [configuration.md](./configuration.md) - セットアップ、wranglerの設定、Smart Placement
- [api.md](./api.md) - バインディングAPI、クエリパターン、ドライバーの使用方法
- [patterns.md](./patterns.md) - ユースケース、ORM、複数クエリの最適化
- [gotchas.md](./gotchas.md) - 制限事項、トラブルシューティング、接続管理

## 関連項目
- [smart-placement](../smart-placement/) - データベースの近くで複数クエリを実行するWorkersを最適化
- [d1](../d1/) - エッジネイティブなアプリ向けのサーバーレスSQLite代替
- [workers](../workers/) - データベースバインディングを備えたWorkerランタイム
