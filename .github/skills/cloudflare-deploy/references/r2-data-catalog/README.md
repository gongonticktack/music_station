# Cloudflare R2 Data Catalog スキルリファレンス

Cloudflare R2 Data Catalog（R2 バケットに組み込まれた Apache Iceberg カタログ）に関する専門的なガイダンス。

## 読む順序

**R2 Data Catalog を初めて使う場合:** まずはこちらから:
1. 以下の「R2 Data Catalog とは？」と「利用する場面」を読む
2. [configuration.md](configuration.md) - カタログを有効にし、トークンを作成する
3. [patterns.md](patterns.md) - PyIceberg のセットアップと一般的なパターン
4. [api.md](api.md) - 必要に応じて REST API リファレンスを参照する
5. [gotchas.md](gotchas.md) - 問題が起きたときのトラブルシューティング

**すぐに参照したい場合:**
- [バケットでカタログを有効にする](configuration.md#enable-catalog-on-bucket)
- [PyIceberg の接続パターン](patterns.md#pyiceberg-connection-pattern)
- [権限エラー](gotchas.md#permission-errors)

## R2 Data Catalog とは？

R2 Data Catalog は、R2 バケットに直接組み込まれた**マネージド Apache Iceberg REST カタログ**です。次の機能を提供します:

- **Apache Iceberg テーブル** - ACID トランザクション、スキーマ進化、タイムトラベルクエリ
- **エグレス費用ゼロ** - データ転送料なしで、どのクラウドやリージョンからでもクエリを実行
- **標準 REST API** - Spark、PyIceberg、Snowflake、Trino、DuckDB で利用可能
- **インフラ不要** - 完全マネージドで、カタログサーバーの運用は不要
- **パブリックベータ** - すべての R2 サブスクライバーが利用可能。R2 ストレージ以外の追加料金なし

### Apache Iceberg とは？

オブジェクトストレージ上の分析データセット向けのオープンテーブル形式です。次の機能があります:
- **ACID トランザクション** - 読み取りと書き込みを安全に並行実行
- **メタデータの最適化** - 全件スキャンなしで高速にクエリを実行
- **スキーマ進化** - データを書き換えずに列を追加・名前変更・削除
- **タイムトラベル** - 過去のスナップショットをクエリ
- **パーティショニング** - 効率的なクエリのためにデータを整理

## 利用する場面

**次の場合に R2 Data Catalog を使用します:**
- **ログ分析** - アプリケーションやシステムのログを保存してクエリする
- **データレイク/ウェアハウス** - 複数のエンジンからクエリされる分析データセット
- **BI パイプライン** - ダッシュボードやレポート用にデータを集計する
- **マルチクラウド分析** - エグレス料金なしでクラウド間のデータを共有する
- **時系列データ** - イベントストリーム、メトリクス、センサーデータ

**次の場合には使用しません:**
- **トランザクション処理** - 代わりに D1 または外部データベースを使用する
- **1 秒未満のレイテンシが必要** - Iceberg はバッチ/分析クエリ向けに最適化されている
- **小規模なデータセット（<1GB）** - セットアップの手間に見合わない
- **非構造化データ** - Iceberg テーブルとしてではなく、ファイルを R2 に直接保存する

## アーキテクチャ

```
┌─────────────────────────────────────────────────┐
│  Query Engines                                  │
│  (PyIceberg, Spark, Trino, Snowflake, DuckDB)  │
└────────────────┬────────────────────────────────┘
                 │
                 │ REST API (OAuth2 token)
                 ▼
┌─────────────────────────────────────────────────┐
│  R2 Data Catalog (Managed Iceberg REST Catalog)│
│  • Namespace/table metadata                     │
│  • Transaction coordination                     │
│  • Snapshot management                          │
└────────────────┬────────────────────────────────┘
                 │
                 │ Vended credentials
                 ▼
┌─────────────────────────────────────────────────┐
│  R2 Bucket Storage                              │
│  • Parquet data files                           │
│  • Metadata files                               │
│  • Manifest files                               │
└─────────────────────────────────────────────────┘
```

**主な概念:**
- **カタログ URI** - カタログ操作用の REST エンドポイント（例: `https://<account-id>.r2.cloudflarestorage.com/iceberg/<bucket>`）
- **ウェアハウス** - テーブルの論理的なグループ（通常はバケット名と同じ）
- **ネームスペース** - テーブルを含むスキーマ/データベース（例: `logs`, `analytics`）
- **テーブル** - スキーマ、データファイル、スナップショットを持つ Iceberg テーブル
- **提供クレデンシャル** - データアクセス用にカタログが発行する一時的な S3 クレデンシャル

## 制限

| リソース | 制限 | 備考 |
|----------|-------|-------|
| カタログあたりのネームスペース数 | 厳密な上限なし | テーブルを論理的に整理する |
| ネームスペースあたりのテーブル数 | <10,000 を推奨 | これを超えるとパフォーマンスが低下 |
| テーブルあたりのファイル数 | <100,000 を推奨 | 定期的にコンパクションを実行する |
| テーブルあたりのスナップショット数 | 保持期間を設定可能 | 7 日を超えたものを期限切れにする |
| テーブルあたりのパーティション数 | 100～1,000 が最適 | 多すぎるとメタデータ操作が遅くなる |
| テーブルサイズ | R2 バケットと同じ | 10GB～10TB 以上が一般的 |
| API レート制限 | 標準の R2 API 制限 | R2 ストレージ操作と共有 |
| 目標ファイルサイズ | 128～512 MB | コンパクション後 |

## 現在のステータス

**パブリックベータ**（2026 年 1 月時点）
- すべての R2 サブスクライバーが利用可能
- 標準の R2 ストレージ/操作料金以外の追加料金なし
- 本番環境で使用可能。ただし、互換性を損なう変更が行われる可能性あり
- 対応機能: ネームスペース、テーブル、スナップショット、コンパクション、タイムトラベル、テーブルメンテナンス

## 判断フロー: R2 Data Catalog は適していますか？

```
Start → Need analytics on object storage data?
         │
         ├─ No → Use R2 directly for object storage
         │
         └─ Yes → Dataset >1GB with structured schema?
                  │
                  ├─ No → Too small, use R2 + ad-hoc queries
                  │
                  └─ Yes → Need ACID transactions or schema evolution?
                           │
                           ├─ No → Consider simpler solutions (Parquet on R2)
                           │
                           └─ Yes → Need multi-cloud/multi-tool access?
                                    │
                                    ├─ No → D1 or external DB may be simpler
                                    │
                                    └─ Yes → ✅ Use R2 Data Catalog
```

**簡易チェック:** 次のすべてに「はい」と答える場合:
- データセットが 1GB を超え、増加し続けている
- 構造化/表形式データ（ログ、イベント、メトリクス）である
- 複数のクエリツールまたはクラウド環境を使う
- バージョン管理、スキーマ変更、または同時アクセスが必要

→ R2 Data Catalog が適しています。

## このリファレンスの内容

- **[configuration.md](configuration.md)** - カタログを有効にする、API トークンを作成する、クライアントを接続する
- **[api.md](api.md)** - REST エンドポイント、操作、メンテナンス
- **[patterns.md](patterns.md)** - PyIceberg の例、一般的なユースケース
- **[gotchas.md](gotchas.md)** - トラブルシューティング、ベストプラクティス、制限事項

## 関連項目

- [Cloudflare R2 Data Catalog ドキュメント](https://developers.cloudflare.com/r2/data-catalog/)
- [Apache Iceberg ドキュメント](https://iceberg.apache.org/)
- [PyIceberg ドキュメント](https://py.iceberg.apache.org/)
