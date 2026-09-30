# 注意点とトラブルシューティング

よくある問題 → 原因 → 解決策。

## 権限エラー

### 401 Unauthorized

**エラー:** `"401 Unauthorized"`  
**原因:** トークンに R2 Data Catalog の権限がありません。  
**解決策:** 「Admin Read & Write」トークンを使用します（カタログとストレージの権限が含まれます）。`catalog.list_namespaces()` でテストします。

### 403 Forbidden

**エラー:** データファイルで `"403 Forbidden"`  
**原因:** トークンにストレージ権限がありません。  
**解決策:** トークンには R2 Data Catalog と R2 Storage Bucket Item の両方の権限が必要です。

### トークンのローテーションに関する問題

**エラー:** ローテーション後に新しいトークンが失敗します。  
**解決策:** 新しいトークンを作成 → ステージング環境でテスト → 本番環境を更新 → 24 時間監視 → 古いトークンを失効させます。

## Catalog URI の問題

### 404 Not Found

**エラー:** `"404 Catalog not found"`  
**原因:** カタログが有効になっていないか、URI が正しくありません。  
**解決策:** `wrangler r2 bucket catalog enable <bucket>` を実行します。URI は HTTPS で、`/iceberg/` を含み、バケット名の大文字・小文字が正確に一致している必要があります。

### Warehouse の誤り

**エラー:** テーブルを作成または読み込めません。  
**原因:** Warehouse ≠ バケット名。  
**解決策:** `warehouse="bucket-name"` をバケット名と完全に一致するように設定します。

## テーブルとスキーマの問題

### テーブル／Namespace がすでに存在する

**エラー:** `"TableAlreadyExistsError"`  
**解決策:** try/except を使って既存のものを読み込むか、事前に存在を確認します。

### Namespace が見つからない

**エラー:** テーブルを作成できません。  
**解決策:** 先に Namespace を作成します: `catalog.create_namespace("ns")`

### スキーマ進化エラー

**エラー:** スキーマ更新時に `"422 Validation"`  
**原因:** 互換性のない変更（必須フィールド、型の縮小）。  
**解決策:** NULL 許容列の追加と、互換性のある型の拡張（int→long、float→double）のみを行います。

## データとクエリの問題

### スキャン結果が空

**エラー:** スキャンでデータが返りません。  
**原因:** フィルターまたはパーティション列が正しくありません。  
**解決策:** まずフィルターなしでテストします: `table.scan().to_pandas()`。パーティション列名を確認してください。

### クエリが遅い

**エラー:** 時間の経過とともにパフォーマンスが低下します。  
**原因:** 小さなファイルが多すぎます。  
**解決策:** ファイル数を確認し、1000 を超える場合、または平均サイズが 10MB 未満の場合はコンパクションを実行します。[api.md](api.md#compaction) を参照してください。

### 型の不一致

**エラー:** 追加時に `"Cannot cast"`  
**原因:** PyArrow の型が Iceberg スキーマと一致しません。  
**解決策:** int32 ではなく int64（Iceberg の既定値）にキャストします。`table.schema()` を確認してください。

## コンパクションの問題

### コンパクションの問題

**問題:** ファイル数が変わらない、またはコンパクションに何時間もかかります。  
**原因:** 目標サイズが大きすぎるか、PyIceberg で扱うにはテーブルが大きすぎます。  
**解決策:** 平均サイズが 50MB 未満の場合にのみコンパクションを実行します。1TB を超えるテーブルには Spark を使用します。トラフィックが少ない時間帯に実行してください。

## メンテナンスの問題

### スナップショット／孤立ファイルの問題

**問題:** 期限切れ処理が失敗する、または孤立ファイルのクリーンアップでアクティブなデータが削除されます。  
**原因:** 保持期間が短すぎるか、実行順序が誤っています。  
**解決策:** 必ず `retain_last=10` で先にスナップショットを期限切れにしてから、3 日以上のしきい値を指定して孤立ファイルをクリーンアップします。

## 同時実行の問題

### 同時書き込みの競合

**問題:** 複数の書き込み元で `CommitFailedException`  
**原因:** 楽観的ロックにより、コミットが同時に発生しています。  
**解決策:** 指数バックオフを使った再試行を追加します（[patterns.md](patterns.md#pattern-6-concurrent-writes-with-retry) を参照）。

### 古いメタデータ

**問題:** 外部更新後も古いスキーマ／データが表示されます。  
**原因:** メタデータがキャッシュされています。  
**解決策:** テーブルを再読み込みします: `table = catalog.load_table(("ns", "table"))`

## パフォーマンスの最適化

### パフォーマンスのヒント

**スキャン:** `row_filter` と `selected_fields` を使ってスキャン対象のデータ量を減らします。  
**パーティション:** 100～1000 が最適です。カーディナリティが高すぎる（数百万）または低すぎる（10 未満）状態は避けてください。  
**ファイル:** 平均サイズを 100～500MB に保ちます。10MB 未満またはファイル数が 1 万を超える場合はコンパクションを実行します。

## 制限

| リソース | 推奨値 | 超過した場合の影響 |
|----------|-------------|-------------------|
| テーブル／Namespace | <10k | 一覧表示操作が遅くなる |
| ファイル／テーブル | <100k | クエリ計画が遅くなる |
| パーティション／テーブル | 100～1k | メタデータのオーバーヘッド |
| スナップショット／テーブル | 7 日超で期限切れ | メタデータが肥大化する |

## よくあるエラーメッセージ一覧

| エラーメッセージ | 考えられる原因 | 対処方法 |
|---------------|--------------|-----|
| `401 Unauthorized` | トークンがない、または無効 | トークンにカタログとストレージの権限があることを確認する |
| `403 Forbidden` | トークンにストレージ権限がない | R2 Storage Bucket Item 権限を追加する |
| `404 Not Found` | カタログが有効でないか、URI が正しくない | `wrangler r2 bucket catalog enable` を実行する |
| `409 Conflict` | テーブル／Namespace がすでに存在する | try/except を使うか、既存のものを読み込む |
| `422 Unprocessable Entity` | スキーマ検証に失敗 | 型の互換性と必須フィールドを確認する |
| `CommitFailedException` | 同時書き込みの競合 | バックオフ付きの再試行ロジックを追加する |
| `NamespaceAlreadyExistsError` | Namespace が存在する | try/except を使うか、既存のものを読み込む |
| `NoSuchTableError` | テーブルが存在しない | Namespace とテーブル名を確認し、先に作成する |
| `TypeError: Cannot cast` | PyArrow の型の不一致 | Iceberg スキーマに合わせてデータをキャストする |

## デバッグ用チェックリスト

問題が発生した場合は、次の順に確認してください。

1. ✅ **カタログが有効:** `npx wrangler r2 bucket catalog status <bucket>`
2. ✅ **トークンの権限:** ダッシュボードで R2 Data Catalog と R2 Storage の両方を確認
3. ✅ **接続テスト:** `catalog.list_namespaces()` が成功する
4. ✅ **URI 形式:** HTTPS で、`/iceberg/` を含み、バケット名が正しい
5. ✅ **Warehouse 名:** バケット名と完全に一致する
6. ✅ **Namespace が存在する:** `create_table()` の前に作成する
7. ✅ **デバッグログを有効にする:** `logging.basicConfig(level=logging.DEBUG)`
8. ✅ **PyIceberg のバージョン:** `pip install --upgrade pyiceberg`（≥0.5.0）
9. ✅ **ファイルの状態:** ファイル数が 1000 を超えるか平均サイズが 10MB 未満ならコンパクションを実行
10. ✅ **スナップショット数:** 100 を超える場合は期限切れにする

## デバッグログを有効にする

```python
import logging
logging.basicConfig(level=logging.DEBUG)
# Now operations show HTTP requests/responses
```

## 参考リソース

- [Cloudflare Community](https://community.cloudflare.com/c/developers/workers/40)
- [Cloudflare Discord](https://discord.cloudflare.com) - #r2 チャンネル
- [PyIceberg GitHub](https://github.com/apache/iceberg-python/issues)
- [Apache Iceberg Slack](https://iceberg.apache.org/community/)

## 次のステップ

- [patterns.md](patterns.md) - 実用例
- [api.md](api.md) - API リファレンス
