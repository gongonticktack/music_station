# R2 SQL の設定

R2 SQL クエリのセットアップと設定。

## 前提条件

- Data Catalog が有効な R2 バケット
- R2 権限を持つ API トークン
- Wrangler CLI がインストールされていること（CLI クエリを実行する場合）

## R2 Data Catalog を有効にする

R2 SQL は、R2 Data Catalog 内の Apache Iceberg テーブルにクエリを実行します。最初にバケットでカタログを有効にする必要があります。

### Wrangler CLI を使う

```bash
npx wrangler r2 bucket catalog enable <bucket-name>
```

出力には次の情報が含まれます。
- **Warehouse 名** - 通常はバケット名と同じです
- **Catalog URI** - カタログ操作用の REST エンドポイント

出力例：
```
Catalog enabled successfully
Warehouse: my-bucket
Catalog URI: https://abc123.r2.cloudflarestorage.com/iceberg/my-bucket
```

### ダッシュボードを使う

1. **R2 Object Storage** に移動し、対象のバケットを選択します
2. **Settings** タブをクリックします
3. **R2 Data Catalog** セクションまでスクロールします
4. **Enable** をクリックします
5. **Catalog URI** と **Warehouse** 名を控えます

**重要：** カタログを有効にすると、バケット内にメタデータ用ディレクトリが作成されますが、既存のオブジェクトは変更されません。

## API トークンを作成する

R2 SQL には、R2 権限を持つ API トークンが必要です。

### 必要な権限

**R2 Admin Read & Write**（R2 SQL Read 権限を含む）

### ダッシュボードを使う

1. **R2 Object Storage** に移動します
2. 右上の **Manage API tokens** をクリックします
3. **Create API token** をクリックします
4. **Admin Read & Write** 権限を選択します
5. **Create API Token** をクリックします
6. **トークン値をコピーします** - この値が表示されるのは一度だけです

### 権限の範囲

| 権限 | アクセスできる操作 |
|------------|------------------|
| R2 Admin Read & Write | R2 ストレージ操作 + R2 SQL クエリ + Data Catalog 操作 |
| R2 SQL Read | SQL クエリのみ（ストレージへの書き込みは不可） |

**注：** R2 SQL Read 権限はまだダッシュボードから設定できません。Admin Read & Write を使用してください。

## 環境を設定する

### Wrangler CLI

Wrangler が使用する環境変数を設定します。

```bash
export WRANGLER_R2_SQL_AUTH_TOKEN=<your-token>
```

または、プロジェクトディレクトリに `.env` ファイルを作成します。

```
WRANGLER_R2_SQL_AUTH_TOKEN=<your-token>
```

コマンドの実行時に、Wrangler は `.env` ファイルを自動的に読み込みます。

### HTTP API

（Wrangler を使わずに）プログラムからアクセスする場合は、Authorization ヘッダーにトークンを指定します。

```bash
curl -X POST https://api.cloudflare.com/client/v4/accounts/{account_id}/r2/sql/query \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "warehouse": "my-bucket",
    "query": "SELECT * FROM default.my_table LIMIT 10"
  }'
```

**注：** HTTP API のエンドポイント URL は異なる場合があります。最新のエンドポイントは [patterns.md](patterns.md#http-api-query) を参照してください。

## セットアップを確認する

システムテーブルにクエリを実行して、設定を確認します。

```bash
# List namespaces
npx wrangler r2 sql query "my-bucket" "SHOW DATABASES"

# List tables in namespace
npx wrangler r2 sql query "my-bucket" "SHOW TABLES IN default"
```

成功すると、結果の JSON 配列が返されます。

## トラブルシューティング

### 「Token authentication failed」

**原因：** トークンが無効か、設定されていません。

**解決方法：**
- `WRANGLER_R2_SQL_AUTH_TOKEN` 環境変数が設定されていることを確認します
- トークンに Admin Read & Write 権限があることを確認します
- 期限切れの場合は、新しいトークンを作成します

### 「Catalog not enabled on bucket」

**原因：** Data Catalog が有効になっていません。

**解決方法：**
- `npx wrangler r2 bucket catalog enable <bucket-name>` を実行します
- または、ダッシュボード（R2 → バケット → Settings → R2 Data Catalog）で有効にします

### 「Permission denied」

**原因：** トークンに必要な権限がありません。

**解決方法：**
- トークンに **Admin Read & Write** 権限があることを確認します
- 正しい権限を付与した新しいトークンを作成します

## 関連項目

- [r2-data-catalog/configuration.md](../r2-data-catalog/configuration.md) - トークンの詳細な設定と PyIceberg の接続
- [patterns.md](patterns.md) - 設定を使ったクエリ例
- [gotchas.md](gotchas.md) - よくある設定エラー