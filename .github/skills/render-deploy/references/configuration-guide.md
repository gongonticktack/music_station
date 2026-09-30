# Render の設定ガイド

Render へのデプロイでよく使われる設定パターン、ベストプラクティス、トラブルシューティング。

## 環境変数

### 必須変数と任意変数

**値を後からユーザーが指定する場合も含め、すべての環境変数を必ず render.yaml に宣言してください。**

**3 つのカテゴリ:**

1. **設定値**（ハードコード）:
```yaml
envVars:
  - key: NODE_ENV
    value: production
  - key: LOG_LEVEL
    value: info
  - key: API_URL
    value: https://api.example.com
```

2. **シークレット**（ユーザーが指定）:
```yaml
envVars:
  - key: JWT_SECRET
    sync: false
  - key: STRIPE_SECRET_KEY
    sync: false
  - key: API_KEY
    sync: false
```

3. **自動生成**（Render が指定）:
```yaml
envVars:
  - key: SESSION_SECRET
    generateValue: true
  - key: ENCRYPTION_KEY
    generateValue: true
```

### データベース接続パターン

**PostgreSQL:**
```yaml
envVars:
  - key: DATABASE_URL
    fromDatabase:
      name: postgres
      property: connectionString
```

**Redis:**
```yaml
envVars:
  - key: REDIS_URL
    fromDatabase:
      name: redis
      property: connectionString
```

**複数のデータベース:**
```yaml
envVars:
  - key: PRIMARY_DB_URL
    fromDatabase:
      name: postgres-primary
      property: connectionString
  - key: ANALYTICS_DB_URL
    fromDatabase:
      name: postgres-analytics
      property: connectionString
  - key: CACHE_URL
    fromDatabase:
      name: redis
      property: connectionString
```

### サービス間の参照

アカウント内の他のサービスを参照します:

```yaml
services:
  - type: web
    name: frontend
    runtime: node
    envVars:
      - key: API_URL
        fromService:
          name: backend-api
          type: web
          property: host  # or hostport, port

  - type: web
    name: backend-api
    runtime: node
```

**利用可能なプロパティ:**
- `host`: サービスのホスト名
- `port`: サービスのポート
- `hostport`: `host:port` を結合した値

### 環境変数グループ

複数のサービス間で共通の設定を共有します:

```yaml
envVarGroups:
  - name: common-config
    envVars:
      - key: NODE_ENV
        value: production
      - key: LOG_LEVEL
        value: info
      - key: TZ
        value: UTC

services:
  - type: web
    name: web-app
    runtime: node
    envVars:
      - fromGroup: common-config
      - key: PORT
        value: 10000

  - type: worker
    name: worker
    runtime: node
    envVars:
      - fromGroup: common-config
```

---

## ポートのバインド

### ポートバインドの要件

**重要:** Web サービスは `0.0.0.0:$PORT` にバインドする必要があります。

**これが重要な理由:**
- Render は `PORT` 環境変数を設定します（デフォルト: 10000）
- サービスは `0.0.0.0` にバインドする必要があります（`localhost` や `127.0.0.1` ではありません）
- ポートのバインドが正しくないとヘルスチェックに失敗します
- デプロイに失敗するか、サービスがトラフィックを受け取れなくなります

### 言語別のコード例

**Node.js / Express:**
```javascript
const express = require('express');
const app = express();

const PORT = process.env.PORT || 3000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});
```

**Python / Flask:**
```python
import os
from flask import Flask

app = Flask(__name__)

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)
```

**Python / Django:**

`settings.py` 内:
```python
# Django runs on port specified by environment
ALLOWED_HOSTS = ['*']
```

render.yaml の起動コマンド:
```yaml
startCommand: gunicorn config.wsgi:application --bind 0.0.0.0:$PORT
```

**Python / FastAPI:**
```python
import os
import uvicorn
from fastapi import FastAPI

app = FastAPI()

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
```

起動コマンド:
```yaml
startCommand: uvicorn main:app --host 0.0.0.0 --port $PORT
```

**Go:**
```go
package main

import (
    "fmt"
    "net/http"
    "os"
)

func main() {
    port := os.Getenv("PORT")
    if port == "" {
        port = "3000"
    }

    http.HandleFunc("/", handler)
    fmt.Printf("Server starting on port %s\n", port)
    http.ListenAndServe(":"+port, nil)
}
```

**Ruby / Rails:**

`config/puma.rb` 内:
```ruby
port ENV.fetch("PORT") { 3000 }
bind "tcp://0.0.0.0:#{ENV.fetch('PORT', 3000)}"
```

**Rust / Actix:**
```rust
use actix_web::{App, HttpServer};
use std::env;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let port = env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let addr = format!("0.0.0.0:{}", port);

    HttpServer::new(|| App::new())
        .bind(&addr)?
        .run()
        .await
}
```

---

## ビルドコマンド

### 非対話型フラグ

入力待ちでビルドが停止しないように、**必ず非対話型フラグを使用してください。**

**npm（Node.js）:**
```yaml
buildCommand: npm ci
# NOT: npm install
```

**pip（Python）:**
```yaml
buildCommand: pip install -r requirements.txt
# Already non-interactive
```

**apt（システムパッケージ）:**
```yaml
buildCommand: apt-get update && apt-get install -y libpq-dev
# Use -y flag to auto-confirm
```

**bundler（Ruby）:**
```yaml
buildCommand: bundle install --jobs=4 --retry=3
```

### 追加手順を含むビルド

**ビルド手順を含む Node.js:**
```yaml
buildCommand: npm ci && npm run build
```

**静的ファイルを含む Python Django:**
```yaml
buildCommand: pip install -r requirements.txt && python manage.py collectstatic --no-input
```

**アセットを含む Ruby Rails:**
```yaml
buildCommand: bundle install && bundle exec rails assets:precompile
```

### ビルドのタイムアウト

**無料プラン:** 15 分
**有料プラン:** 設定可能

**ビルドがタイムアウトする場合:**
1. 依存関係を最適化する（未使用のパッケージを削除する）
2. ビルドキャッシュを使用する
3. CI/CD での事前ビルドを検討する
4. タイムアウト時間を延ばすため、有料プランにアップグレードする

---

## データベース接続

### 内部 URL と外部 URL

**パフォーマンス向上のため、内部 URL を使用してください:**

`fromDatabase` を使用すると、Render は `.render-internal.com` の内部 URL を自動的に提供します:

```yaml
envVars:
  - key: DATABASE_URL
    fromDatabase:
      name: postgres
      property: connectionString
```

次の URL が提供されます: `postgresql://user:pass@postgres.render-internal.com:5432/db`

**メリット:**
- レイテンシが低い（同じデータセンター内）
- 外部帯域幅の料金がかからない
- 内部 DNS が自動設定される

### コネクションプーリング

**Node.js / PostgreSQL:**
```javascript
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  max: 20, // Maximum pool size
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

**Python / PostgreSQL:**
```python
import psycopg2.pool

pool = psycopg2.pool.SimpleConnectionPool(
    minconn=1,
    maxconn=20,
    dsn=os.environ['DATABASE_URL']
)
```

**Django の設定:**
```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'URL': os.environ['DATABASE_URL'],
        'CONN_MAX_AGE': 600,  # Connection pooling
    }
}
```

### データベースのマイグレーション

**ビルド中にマイグレーションを実行します:**

**Django:**
```yaml
buildCommand: pip install -r requirements.txt && python manage.py migrate
```

**Rails:**
```yaml
buildCommand: bundle install && bundle exec rails db:migrate
```

**Node.js / Prisma:**
```yaml
buildCommand: npm ci && npx prisma migrate deploy
```

---

## 無料プランの制限

### 含まれるもの

**無料プランの内容:**
- Web サービス 1 つ
- PostgreSQL データベース 1 つ（ストレージ 1 GB、RAM 97 MB）
- 月 750 時間のコンピューティング時間
- サービスごとに RAM 512 MB
- サービスごとに CPU 0.5 個
- 月 100 GB の帯域幅

### リソースの制限

**メモリ（512 MB）:**
- ログでメモリ使用量を監視する
- メモリが制約される環境向けに最適化する
- 軽量な依存関係を使用する

**CPU（0.5 コア）:**
- トラフィックの少ないアプリケーションに適しています
- トラフィックが増えた場合はアップグレードを検討してください

**スピンダウン（無料サービス）:**
- 15 分間操作がないとサービスはスピンダウンします
- スピンダウン後の最初のリクエストには約 30 秒かかります（コールドスタート）
- 常時稼働するサービスには有料プランにアップグレードしてください

### アップグレードするタイミング

**次の場合は有料プランにアップグレードしてください:**
- Web サービスを 2 つ以上必要とする
- 常時稼働するサービス（スピンダウンなし）が必要
- トラフィックが無料プランの制限を超える
- より多くのメモリまたは CPU が必要
- ビルド時間の短縮が必要
- プレビュー環境が必要

---

## ヘルスチェック

### ヘルスチェック用エンドポイントの追加

**Node.js / Express:**
```javascript
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString()
  });
});
```

**Python / Flask:**
```python
@app.route('/health')
def health():
    return {'status': 'ok'}, 200
```

**Python / FastAPI:**
```python
@app.get("/health")
async def health():
    return {"status": "ok"}
```

**Go:**
```go
http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    w.Write([]byte(`{"status":"ok"}`))
})
```

### render.yaml での設定

```yaml
services:
  - type: web
    name: my-app
    runtime: node
    healthCheckPath: /health
```

**メリット:**
- デプロイ完了をより早く検出できる
- 監視が強化される
- ヘルスチェックに失敗すると自動的に再起動する

---

## よくあるデプロイの問題

### 問題 1: 環境変数が不足している

**症状:** 「undefined variable」エラーでサービスがクラッシュする

**解決策:** 必須の環境変数をすべて render.yaml に追加します:
```yaml
envVars:
  - key: DATABASE_URL
    fromDatabase:
      name: postgres
      property: connectionString
  - key: JWT_SECRET
    sync: false  # User fills in Dashboard
```

### 問題 2: ポートのバインドエラー

**症状:** `EADDRINUSE` またはヘルスチェックのタイムアウトエラーが発生する

**解決策:** アプリが `0.0.0.0:$PORT` にバインドすることを確認します:
```javascript
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0');
```

### 問題 3: ビルドが停止する

**症状:** ビルドが 15 分後にタイムアウトする

**解決策:** 非対話型のビルドコマンドを使用します:
```yaml
buildCommand: npm ci  # NOT npm install
```

### 問題 4: データベース接続に失敗する

**症状:** ポート 5432 への接続で `ECONNREFUSED` が発生する

**解決策:**
1. `fromDatabase` を使用して内部 URL を自動取得する
2. 外部接続の場合は SSL を有効にする
3. `ipAllowList` の設定を確認する

### 問題 5: 静的サイトで 404 が発生する

**症状:** クライアント側のルートが 404 を返す

**解決策:** SPA のリライトルールを追加します:
```yaml
routes:
  - type: rewrite
    source: /*
    destination: /index.html
```

### 問題 6: メモリ不足（OOM）

**症状:** `JavaScript heap out of memory` でサービスがクラッシュする

**解決策:**
1. アプリケーションのメモリ使用量を最適化する
2. 依存関係のサイズを小さくする
3. RAM がより多い上位プランにアップグレードする

---

## ベストプラクティスのチェックリスト

**環境変数:**
- [ ] すべての環境変数を render.yaml に宣言している
- [ ] シークレットに `sync: false` を指定している
- [ ] データベース URL に `fromDatabase` 参照を使用している

**ポートのバインド:**
- [ ] アプリが `process.env.PORT` にバインドしている
- [ ] `0.0.0.0` にバインドしている（`localhost` ではありません）

**ビルドコマンド:**
- [ ] 非対話型フラグ（`npm ci`、`-y` など）を使用している
- [ ] ビルドが 15 分以内に完了する（無料プラン）

**起動コマンド:**
- [ ] コマンドが HTTP サーバーを正しく起動する
- [ ] サーバーが正しいポートにバインドする

**ヘルスチェック:**
- [ ] `/health` エンドポイントを実装している
- [ ] 200 ステータスコードを返す

**データベース:**
- [ ] コネクションプーリングを設定している
- [ ] 内部 URL（`.render-internal.com`）を使用している
- [ ] 必要に応じて SSL を有効にしている

**プラン:**
- [ ] デフォルトで `plan: free` を使用している
- [ ] ユーザー向けにアップグレード方法を説明している

**Git リポジトリ:**
- [ ] render.yaml をリポジトリにコミットしている
- [ ] Git リモート（GitHub/GitLab/Bitbucket）にプッシュしている
- [ ] （main 以外の場合）render.yaml でブランチを指定している

---

## 追加リソース

- Blueprint の仕様: [blueprint-spec.md](blueprint-spec.md)
- サービスの種類: [service-types.md](service-types.md)
- ランタイム: [runtimes.md](runtimes.md)
- Render 公式ドキュメント: https://render.com/docs