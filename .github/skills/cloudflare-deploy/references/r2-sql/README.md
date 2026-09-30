# Cloudflare R2 SQL スキルリファレンス

Apache Iceberg テーブル向けのサーバーレス分散クエリエンジン、Cloudflare R2 SQL の専門的なガイダンス。

## 読む順序

**R2 SQL を初めて使いますか？** ここから始めてください:
1. 以下の「R2 SQL とは？」と「利用する場面」を読む
2. [configuration.md](configuration.md) - カタログを有効化し、トークンを作成する
3. [patterns.md](patterns.md) - Wrangler CLI と統合の例
4. [api.md](api.md) - SQL 構文とクエリのリファレンス
5. [gotchas.md](gotchas.md) - 制限事項とトラブルシューティング

**すぐに参照したいですか？** 該当箇所へ移動:
- [Wrangler でクエリを実行](patterns.md#wrangler-cli-query)
- [SQL 構文リファレンス](api.md#sql-syntax)
- [ORDER BY の制限](gotchas.md#order-by-limitations)

## R2 SQL とは？

R2 SQL は、R2 Data Catalog 内の Apache Iceberg テーブルをクエリするための、Cloudflare の**サーバーレス分散分析クエリエンジン**です。主な機能:

- **サーバーレス** - 管理するクラスターやインフラストラクチャは不要
- **分散型** - Cloudflare のグローバルネットワークを活用した並列実行
- **SQL インターフェース** - 分析クエリに使い慣れた SQL 構文を使用
- **エグレス料金ゼロ** - データ転送料なしで、任意のクラウド／リージョンからクエリ可能
- **オープンベータ** - ベータ期間中は無料（通常の R2 ストレージ料金は適用）

### Apache Iceberg とは？

オブジェクトストレージ上の大規模分析データセット向けのオープンテーブル形式:
- **ACID トランザクション** - 安全な同時読み取り／書き込み
- **メタデータの最適化** - テーブル全体をスキャンせずに高速にクエリ
- **スキーマの進化** - データを書き換えずに列の追加／名前変更／削除が可能
- **パーティショニング** - 効率よくデータを絞り込めるように整理

## 利用する場面

**R2 SQL が適している用途:**
- **ログ分析** - WHERE フィルターと集計を使ってアプリケーション／システムログをクエリ
- **BI ダッシュボード** - 大規模な分析データセットからレポートを生成
- **不正検知** - GROUP BY/HAVING でトランザクションのパターンを分析
- **マルチクラウド分析** - エグレス料金なしで任意のクラウドのデータをクエリ
- **アドホックな調査** - Wrangler CLI 経由で Iceberg テーブルに SQL クエリを実行

**R2 SQL が適さない用途:**
- **Workers/Pages のランタイム** - R2 SQL には Workers バインディングがありません。外部システムから HTTP API を使用してください
- **リアルタイムクエリ（100 ミリ秒未満）** - OLTP ではなく、分析用のバッチクエリ向けに最適化されています
- **複雑な結合／CTE** - SQL 機能は限定的です（現時点では JOIN、サブクエリ、CTE は利用不可）
- **小規模なデータセット（1 GB 未満）** - セットアップのオーバーヘッドに見合いません

## 判断フロー: R2 Data をクエリする必要がある場合

```
Do you need to query structured data in R2?
├─ YES, data is in Iceberg tables
│  ├─ Need SQL interface? → Use R2 SQL (this reference)
│  ├─ Need Python API? → See r2-data-catalog reference (PyIceberg)
│  └─ Need other engine? → See r2-data-catalog reference (Spark, Trino, etc.)
│
├─ YES, but not in Iceberg format
│  ├─ Streaming data? → Use Pipelines to write to Data Catalog, then R2 SQL
│  └─ Static files? → Use PyIceberg to create Iceberg tables, then R2 SQL
│
└─ NO, just need object storage → Use R2 reference (not R2 SQL)
```

## アーキテクチャの概要

**クエリプランナー:**
- 複数レイヤーの絞り込みを伴う、トップダウン方式のメタデータ調査
- パーティション、列、行グループ単位でデータを絞り込み
- ストリーミングパイプラインにより、プランニングの完了前に実行を開始
- LIMIT による早期終了 - 結果がそろうと処理を停止

**クエリ実行:**
- コーディネーターが Cloudflare ネットワーク全体のワーカーに処理を分配
- ワーカーが Apache DataFusion を実行し、クエリを並列処理
- Parquet の列プルーニング - 必要な列のみを読み取り
- 効率化のため、R2 から範囲読み取りを実行

**集計戦略:**
- Scatter-gather - シンプルな集計（SUM、COUNT、AVG）
- シャッフル - ハッシュパーティショニングを使った ORDER BY／集計に対する HAVING

## クイックスタート

```bash
# 1. Enable R2 Data Catalog on bucket
npx wrangler r2 bucket catalog enable my-bucket

# 2. Create API token (Admin Read & Write)
# Dashboard: R2 → Manage API tokens → Create API token

# 3. Set environment variable
export WRANGLER_R2_SQL_AUTH_TOKEN=<your-token>

# 4. Run query
npx wrangler r2 sql query "my-bucket" "SELECT * FROM default.my_table LIMIT 10"
```

## 重要な制限事項

**重大: Workers バインディングなし**
- R2 SQL は Workers/Pages のコードから直接呼び出せません
- プログラムからアクセスするには、外部システムから HTTP API を使用してください
- または PyIceberg、Spark などを使ってクエリしてください（r2-data-catalog リファレンスを参照）

**SQL の機能:**
- JOIN、CTE、サブクエリ、ウィンドウ関数は使用不可
- ORDER BY は集計列をサポート（パーティションキーだけに限定されない）
- LIMIT は最大 10,000（デフォルトは 500）
- 制限事項の全一覧は [gotchas.md](gotchas.md) を参照

## このリファレンスの内容

- **[configuration.md](configuration.md)** - カタログの有効化、API トークンの作成
- **[api.md](api.md)** - SQL 構文、関数、演算子、データ型
- **[patterns.md](patterns.md)** - Wrangler CLI、HTTP API、Pipelines、PyIceberg
- **[gotchas.md](gotchas.md)** - 制限事項、トラブルシューティング、パフォーマンスのヒント

## 関連項目

- [r2-data-catalog](../r2-data-catalog/) - PyIceberg、REST API、外部エンジン
- [pipelines](../pipelines/) - Iceberg テーブルへのストリーミング取り込み
- [r2](../r2/) - R2 オブジェクトストレージの基礎
- [Cloudflare R2 SQL Docs](https://developers.cloudflare.com/r2-sql/)
- [R2 SQL Deep Dive Blog](https://blog.cloudflare.com/r2-sql-deep-dive/)