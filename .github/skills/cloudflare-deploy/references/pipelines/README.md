# Cloudflare Pipelines

SQL変換を使って、データをR2に取り込み、変換し、ロードするETLストリーミングプラットフォームです。

## 概要

Pipelinesが提供するもの:
- **Streams**: 永続的なイベントバッファ（HTTP/Workersによる取り込み）
- **Pipelines**: SQLベースの変換
- **Sinks**: R2の出力先（IcebergテーブルまたはParquet/JSONファイル）

**ステータス**: オープンベータ（Workers有料プラン）  
**料金**: 標準のR2ストレージ/操作料金以外は無料

## アーキテクチャ

```
Data Sources → Streams → Pipelines (SQL) → Sinks → R2
                 ↑          ↓                ↓
            HTTP/Workers  Transform     Iceberg/Parquet
```

| コンポーネント | 目的 | 主な機能 |
|-----------|---------|-------------|
| Streams | イベントの取り込み | 構造化（検証済み）または非構造化 |
| Pipelines | SQLによる変換 | 作成後は変更不可 |
| Sinks | R2への書き込み | 厳密に1回だけ配信 |

## クイックスタート

```bash
# Interactive setup (recommended)
npx wrangler pipelines setup
```

**最小構成のWorker例:**
```typescript
interface Env {
  STREAM: Pipeline;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const event = { user_id: "123", event_type: "purchase", amount: 29.99 };
    
    // Fire-and-forget pattern
    ctx.waitUntil(env.STREAM.send([event]));
    
    return new Response('OK');
  }
} satisfies ExportedHandler<Env>;
```

## Sinkの種類の選び方

```
Need SQL queries on data?
  → R2 Data Catalog (Iceberg)
    ✅ ACID transactions, time-travel, schema evolution
    ❌ More setup complexity (namespace, table, catalog token)

Just file storage/archival?
  → R2 Storage (Parquet)
    ✅ Simple, direct file access
    ❌ No built-in SQL queries

Using external tools (Spark/Athena)?
  → R2 Storage (Parquet with partitioning)
    ✅ Standard format, partition pruning for performance
    ❌ Must manage schema compatibility yourself
```

## よくあるユースケース

- **分析パイプライン**: クリックストリーム、テレメトリ、サーバーログ
- **データウェアハウス**: クエリ可能なIcebergテーブルへのETL
- **イベント処理**: エンリッチメントを伴うモバイル/IoTデータ
- **Eコマース分析**: ユーザーイベント、購入、閲覧

## 推奨する読み進め方

**Pipelinesを初めて使いますか？** ここから始めてください:
1. [configuration.md](./configuration.md) - ストリーム、シンク、パイプラインの設定
2. [api.md](./api.md) - イベントの送信、TypeScript型、SQL関数
3. [patterns.md](./patterns.md) - ベストプラクティス、統合、完全な例
4. [gotchas.md](./gotchas.md) - 重要な警告、トラブルシューティング

**タスク別の案内:**
- パイプラインを設定する → [configuration.md](./configuration.md)
- データを送信/クエリする → [api.md](./api.md)
- パターンを実装する → [patterns.md](./patterns.md)
- 問題をデバッグする → [gotchas.md](./gotchas.md)

## このリファレンスの内容

- [configuration.md](./configuration.md) - wrangler.jsoncのバインディング、スキーマ定義、シンクのオプション、CLIコマンド
- [api.md](./api.md) - Pipelineバインディングのインターフェース、send()メソッド、HTTP取り込み、SQL関数リファレンス
- [patterns.md](./patterns.md) - Fire-and-forget、Zodによるスキーマ検証、統合、パフォーマンス調整
- [gotchas.md](./gotchas.md) - 検証エラーが黙って失敗する問題、不変のパイプライン、レイテンシの見込み、制限事項

## 関連項目

- [r2](../r2/) - シンク用のR2ストレージバックエンド
- [queues](../queues/) - 非同期処理におけるQueuesとの比較
- [workers](../workers/) - イベント取り込み用のWorkerランタイム
