# 設定

R2 Data Catalog を有効にして認証を設定する方法。

## 前提条件

- [R2 サブスクリプション](https://developers.cloudflare.com/r2/pricing/)がある Cloudflare アカウント
- R2 バケットが作成済みであること
- Cloudflare ダッシュボードまたは Wrangler CLI へのアクセス

## バケットでカタログを有効にする

次のいずれかの方法を選択します。

### Wrangler 経由（推奨）

```bash
npx wrangler r2 bucket catalog enable <BUCKET_NAME>
```

**出力:**
```
✅ Data Catalog enabled for bucket 'my-bucket'
   Catalog URI: https://<account-id>.r2.cloudflarestorage.com/iceberg/my-bucket
   Warehouse: my-bucket
```

### ダッシュボード経由

1. **R2** に移動 → バケットを選択 → **Settings** タブ
2. 「R2 Data Catalog」セクションまでスクロール → **Enable** をクリック
3. 表示された **Catalog URI** と **Warehouse name** を控えます

**結果:**
- Catalog URI: `https://<account-id>.r2.cloudflarestorage.com/iceberg/<bucket-name>`
- Warehouse: `<bucket-name>`（バケット名と同じ）

### API 経由（プログラムからの操作）

```bash
curl -X POST \
  "https://api.cloudflare.com/client/v4/accounts/<account-id>/r2/buckets/<bucket>/catalog" \
  -H "Authorization: Bearer <api-token>" \
  -H "Content-Type: application/json"
```

**レスポンス:**
```json
{
  "result": {
    "catalog_uri": "https://<account-id>.r2.cloudflarestorage.com/iceberg/<bucket>",
    "warehouse": "<bucket>"
  },
  "success": true
}
```

## カタログの状態を確認する

```bash
npx wrangler r2 bucket catalog status <BUCKET_NAME>
```

**出力:**
```
Catalog Status: enabled
Catalog URI: https://<account-id>.r2.cloudflarestorage.com/iceberg/my-bucket
Warehouse: my-bucket
```

## カタログを無効にする（必要な場合）

```bash
npx wrangler r2 bucket catalog disable <BUCKET_NAME>
```

⚠️ **警告:** 無効にしてもテーブルやデータは削除されません。ファイルはバケットに残ります。再度有効にするまでメタデータにアクセスできなくなります。

## API トークンの作成

R2 Data Catalog には、R2 Storage と R2 Data Catalog の**両方**の権限を持つ API トークンが必要です。

### ダッシュボードでの方法（推奨）

1. **R2** → **Manage R2 API Tokens** → **Create API Token** の順に開きます
2. 権限レベルを選択します。
   - **Admin Read & Write** - カタログとストレージへの完全なアクセス（読み取り／書き込み）
   - **Admin Read only** - 読み取り専用アクセス（クエリエンジン向け）
3. トークン値をすぐにコピーします（表示されるのは一度だけです）

**含まれる権限グループ:**
- `Workers R2 Data Catalog Write`（または Read）
- `Workers R2 Storage Bucket Item Write`（または Read）

### API での方法（プログラムからの操作）

Cloudflare API を使用して、プログラムからトークンを作成します。必要な権限:
- `Workers R2 Data Catalog Write`（または Read）
- `Workers R2 Storage Bucket Item Write`（または Read）

## クライアントの設定

### PyIceberg

```python
from pyiceberg.catalog.rest import RestCatalog

catalog = RestCatalog(
    name="my_catalog",
    warehouse="<bucket-name>",           # Same as bucket name
    uri="<catalog-uri>",                 # From enable command
    token="<api-token>",                 # From token creation
)
```

**認証情報を含む完全な例:**
```python
import os
from pyiceberg.catalog.rest import RestCatalog

# Store credentials in environment variables
WAREHOUSE = os.getenv("R2_WAREHOUSE")      # e.g., "my-bucket"
CATALOG_URI = os.getenv("R2_CATALOG_URI")  # e.g., "https://abc123.r2.cloudflarestorage.com/iceberg/my-bucket"
TOKEN = os.getenv("R2_TOKEN")              # API token

catalog = RestCatalog(
    name="r2_catalog",
    warehouse=WAREHOUSE,
    uri=CATALOG_URI,
    token=TOKEN,
)

# Test connection
print(catalog.list_namespaces())
```

### Spark / Trino / DuckDB

他のクエリエンジンとの統合例は [patterns.md](patterns.md) を参照してください。

## 接続文字列の形式

早見表:

```
Catalog URI:  https://<account-id>.r2.cloudflarestorage.com/iceberg/<bucket>
Warehouse:    <bucket-name>
Token:        <r2-api-token>
```

**値の確認場所:**

| 値 | 取得元 |
|-------|--------|
| `<account-id>` | ダッシュボードの URL または `wrangler whoami` |
| `<bucket>` | R2 バケット名 |
| Catalog URI | `wrangler r2 bucket catalog enable` の出力 |
| Token | R2 API Token の作成ページ |

## セキュリティのベストプラクティス

1. **トークンを安全に保管する** - 環境変数またはシークレット管理サービスを使い、コードに直接埋め込まない
2. **最小権限を使用する** - クエリエンジンには読み取り専用トークンを使い、書き込みトークンは必要な場所だけで使用する
3. **トークンを定期的にローテーションする** - 新しいトークンを作成してテストしてから、古いトークンを失効させる
4. **アプリケーションごとにトークンを分ける** - 侵害された場合に追跡や失効が容易になります
5. **トークンの使用状況を監視する** - R2 Analytics で想定外のパターンがないか確認する
6. **バケット単位のトークンを使う** - アカウント全体ではなく、バケットごとにトークンを作成する

## 環境変数の使用パターン

```bash
# .env (never commit)
R2_CATALOG_URI=https://<account-id>.r2.cloudflarestorage.com/iceberg/<bucket>
R2_WAREHOUSE=<bucket-name>
R2_TOKEN=<api-token>
```

```python
import os
from pyiceberg.catalog.rest import RestCatalog

catalog = RestCatalog(
    name="r2",
    uri=os.getenv("R2_CATALOG_URI"),
    warehouse=os.getenv("R2_WAREHOUSE"),
    token=os.getenv("R2_TOKEN"),
)
```

## トラブルシューティング

| 問題 | 解決策 |
|---------|----------|
| 404 "catalog not found" | `wrangler r2 bucket catalog enable <bucket>` を実行する |
| 401 "unauthorized" | トークンにカタログとストレージの両方の権限があることを確認する |
| データファイルで 403 | トークンに両方の権限グループが必要です |

詳しいトラブルシューティングは [gotchas.md](gotchas.md) を参照してください。
