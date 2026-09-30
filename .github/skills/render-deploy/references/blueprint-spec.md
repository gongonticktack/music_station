# Render Blueprint 仕様

render.yaml Blueprint ファイルの完全なリファレンスです。Blueprint は、Render 上で再現可能なデプロイを行うためのインフラストラクチャをコードとして定義します。

## 概要

Blueprint は、リポジトリのルートに配置する YAML ファイル（通常は `render.yaml`）で、次の内容を記述します。
- サービス（web、worker、cron、static、private）
- データベース（PostgreSQL、Redis）
- 環境変数とシークレット
- スケーリングとリソース構成
- プロジェクトの構成

## ルートレベルの構造

```yaml
# Top-level fields
services: []         # Array of service definitions
databases: []        # Array of PostgreSQL databases
envVarGroups: []     # Reusable environment variable groups (optional)
projects: []         # Project organization (optional)
ungrouped: []        # Resources outside projects (optional)
previews:            # Preview environment configuration (optional)
  generation: auto_preview | manual | none
```

## サービスの種類

### Web サービス（`type: web`）

HTTP サービス、API、Web アプリケーションです。HTTPS 経由で公開されます。

**必須フィールド:**
- `name`: サービスを一意に識別する名前
- `type`: `web` を指定する必要があります
- `runtime`: 言語／実行環境（「ランタイム」セクションを参照）
- `buildCommand`: アプリケーションをビルドするコマンド
- `startCommand`: サーバーを起動するコマンド

**よく使われる任意フィールド:**
- `plan`: インスタンスタイプ（既定値: `free`）
- `region`: デプロイ先リージョン（既定値: `oregon`）
- `branch`: デプロイする Git ブランチ（既定値: `main`）
- `autoDeploy`: push 時に自動デプロイするか（既定値: `true`）
- `envVars`: 環境変数の配列
- `healthCheckPath`: ヘルスチェックのエンドポイント（既定値: `/`）
- `numInstances`: インスタンス数（手動スケーリング）
- `scaling`: オートスケーリングの構成

**例:**
```yaml
services:
  - type: web
    name: api-server
    runtime: node
    plan: free
    buildCommand: npm ci
    startCommand: npm start
    branch: main
    autoDeploy: true
    envVars:
      - key: NODE_ENV
        value: production
      - key: PORT
        value: 10000
```

### Worker サービス（`type: worker`）

バックグラウンドジョブの処理やキューの消費を行います。一般には公開されません。

**必須フィールド:**
- `name`: サービスを一意に識別する名前
- `type`: `worker` を指定する必要があります
- `runtime`: 言語／実行環境
- `buildCommand`: ビルドするコマンド
- `startCommand`: ワーカープロセスを起動するコマンド

**Web サービスとの主な違い:**
- 公開 URL がありません
- ヘルスチェックはありません
- ポートのバインドは不要です

**例:**
```yaml
services:
  - type: worker
    name: job-processor
    runtime: python
    plan: free
    buildCommand: pip install -r requirements.txt
    startCommand: celery -A tasks worker --loglevel=info
    envVars:
      - key: REDIS_URL
        fromDatabase:
          name: redis
          property: connectionString
```

### Cron ジョブ（`type: cron`）

Cron スケジュールに従って実行される定期タスクです。

**必須フィールド:**
- `name`: サービスを一意に識別する名前
- `type`: `cron` を指定する必要があります
- `runtime`: 言語／実行環境
- `schedule`: Cron 式
- `buildCommand`: ビルドするコマンド
- `startCommand`: スケジュールに従って実行するコマンド

**スケジュール形式:** 標準的な Cron 構文（分 時 日 月 曜日）

**例:**
- `0 0 * * *` - 毎日 UTC の午前 0 時
- `*/15 * * * *` - 15 分ごと
- `0 9 * * 1` - 毎週月曜日の UTC 午前 9 時

**例:**
```yaml
services:
  - type: cron
    name: daily-backup
    runtime: node
    schedule: "0 2 * * *"
    buildCommand: npm ci
    startCommand: node scripts/backup.js
    envVars:
      - key: DATABASE_URL
        fromDatabase:
          name: postgres
          property: connectionString
```

### 静的サイト（`type: static`、または `runtime: static` を指定した `type: web`）

静的な HTML／CSS／JS ファイルを CDN 経由で配信します。

**必須フィールド:**
- `name`: サービスを一意に識別する名前
- `type`: `web`
- `runtime`: `static`
- `buildCommand`: 静的アセットをビルドするコマンド
- `staticPublishPath`: ビルド済みファイルへのパス（例: `./build`、`./dist`）

**任意の構成:**
- `routes`: SPA 用のルーティングルール
- `headers`: カスタム HTTP ヘッダー
- `buildFilter`: ビルドのトリガーとなるパスのフィルター

**例:**
```yaml
services:
  - type: web
    name: react-app
    runtime: static
    buildCommand: npm ci && npm run build
    staticPublishPath: ./dist
    routes:
      - type: rewrite
        source: /*
        destination: /index.html
    headers:
      - path: /*
        name: Cache-Control
        value: public, max-age=31536000, immutable
```

### プライベートサービス（`type: pserv`）

Render アカウント内からのみアクセスできる内部サービスです。

**必須フィールド:**
- `name`: サービスを一意に識別する名前
- `type`: `pserv` を指定する必要があります
- `runtime`: 言語／実行環境
- `buildCommand`: ビルドするコマンド
- `startCommand`: 起動するコマンド

**用途:**
- 内部 API
- データベースプロキシ
- インターネットに公開しないマイクロサービス

**例:**
```yaml
services:
  - type: pserv
    name: internal-api
    runtime: go
    plan: free
    buildCommand: go build -o bin/app
    startCommand: ./bin/app
```

## ランタイム

### ネイティブランタイム

**Node.js（`runtime: node`）:**
- バージョン: 14、16、18、20、21
- 既定のバージョン: 20
- バージョンは `package.json` の engines フィールドで指定します

**Python（`runtime: python`）:**
- バージョン: 3.8、3.9、3.10、3.11、3.12
- 既定のバージョン: 3.11
- バージョンは `runtime.txt` または `Pipfile` で指定します

**Go（`runtime: go`）:**
- バージョン: 1.20、1.21、1.22、1.23
- Go モジュールを使用します
- バージョンは `go.mod` から取得します

**Ruby（`runtime: ruby`）:**
- バージョン: 3.0、3.1、3.2、3.3
- Bundler を使用します
- バージョンは `.ruby-version` または `Gemfile` から取得します

**Rust（`runtime: rust`）:**
- 最新の安定バージョン
- Cargo を使用します

**Elixir（`runtime: elixir`）:**
- 最新の安定バージョン
- Mix を使用します

### Docker ランタイム

**Docker（`runtime: docker`）:**
リポジトリ内の Dockerfile からビルドします。

**追加フィールド:**
- `dockerfilePath`: Dockerfile へのパス（既定値: `./Dockerfile`）
- `dockerContext`: ビルドコンテキストのディレクトリ（既定値: `.`）

**例:**
```yaml
services:
  - type: web
    name: docker-app
    runtime: docker
    dockerfilePath: ./docker/Dockerfile
    dockerContext: .
    plan: free
```

**イメージ（`runtime: image`）:**
レジストリにあるビルド済み Docker イメージをデプロイします。

**追加フィールド:**
- `image`: イメージ URL（例: `registry.com/image:tag`）
- `registryCredential`: プライベートレジストリの認証情報

**例:**
```yaml
services:
  - type: web
    name: prebuilt-app
    runtime: image
    image: myregistry.com/app:v1.2.3
    plan: free
```

## サービスプラン

利用可能なインスタンスタイプ:

| プラン | RAM | CPU | 料金 |
|------|-----|-----|-------|
| `free` | 512 MB | 0.5 | 無料（月 750 時間） |
| `starter` | 512 MB | 0.5 | $7/月 |
| `standard` | 2 GB | 1 | $25/月 |
| `pro` | 4 GB | 2 | $85/月 |
| `pro_plus` | 8 GB | 4 | $175/月 |

**ユーザーから別の指定がない限り、既定では常に `plan: free` を使用してください。**

## リージョン

利用可能なデプロイ先リージョン:

- `oregon`（米国西部） - 既定
- `ohio`（米国東部）
- `virginia`（米国東部）
- `frankfurt`（EU）
- `singapore`（アジア）

**例:**
```yaml
services:
  - type: web
    name: my-app
    runtime: node
    region: frankfurt
```

## 環境変数

環境変数を定義する方法は 3 種類あります。

### 1. 値を直接指定

機密情報ではない設定に使用します。

```yaml
envVars:
  - key: NODE_ENV
    value: production
  - key: API_URL
    value: https://api.example.com
  - key: LOG_LEVEL
    value: info
```

### 2. シークレットを生成

Render は Base64 エンコードされた 256 ビットのランダム値を生成します。

```yaml
envVars:
  - key: SESSION_SECRET
    generateValue: true
  - key: ENCRYPTION_KEY
    generateValue: true
```

### 3. ユーザーが指定するシークレット

Blueprint の作成時にユーザーに値を入力してもらいます。

```yaml
envVars:
  - key: STRIPE_SECRET_KEY
    sync: false
  - key: JWT_SECRET
    sync: false
  - key: API_KEY
    sync: false
```

**`sync: false` フラグは、「ユーザーが Dashboard でこの値を入力する」ことを意味します。**

### 4. データベース参照

データベースの接続文字列を参照します。

```yaml
envVars:
  - key: DATABASE_URL
    fromDatabase:
      name: postgres
      property: connectionString
  - key: REDIS_URL
    fromDatabase:
      name: redis
      property: connectionString
```

**利用可能なプロパティ:**
- `connectionString`: 接続 URL 全体
- `host`: データベースのホスト
- `port`: データベースのポート
- `user`: データベースのユーザー名
- `password`: データベースのパスワード
- `database`: データベース名
- `hostport`: `host:port` を結合した値

### 5. サービス参照

他のサービスを参照します。

```yaml
envVars:
  - key: API_URL
    fromService:
      name: api-server
      type: web
      property: host
```

### 6. 環境変数グループ

複数のサービスで共有できる再利用可能なグループです。

```yaml
envVarGroups:
  - name: shared-config
    envVars:
      - key: LOG_LEVEL
        value: info
      - key: ENVIRONMENT
        value: production

services:
  - type: web
    name: web-app
    runtime: node
    envVars:
      - fromGroup: shared-config
      - key: PORT
        value: 10000
```

## データベース

### PostgreSQL

```yaml
databases:
  - name: postgres
    databaseName: myapp_prod
    user: myapp_user
    plan: free
    postgresMajorVersion: "15"
    ipAllowList: []
```

**プラン:**
- `free`: ストレージ 1 GB、RAM 97 MB、CPU 0.1
- `basic-256mb`、`basic-512mb`、`basic-1gb`、`basic-4gb`
- `pro-4gb`、`pro-8gb`、`pro-16gb` など
- `accelerated-4gb`、`accelerated-8gb` など（SSD ベース）

**主なフィールド:**
- `name`: 参照用の識別子
- `databaseName`: PostgreSQL の実際のデータベース名
- `user`: データベースのユーザー名
- `postgresMajorVersion`: PostgreSQL のバージョン（11～16）
- `ipAllowList`: CIDR ブロックの配列（空の場合は内部からのみアクセス可能）
- `diskSizeGB`: ストレージ容量（有料プランのみ）

**高可用性（有料プラン）:**
```yaml
databases:
  - name: postgres
    databaseName: myapp_prod
    plan: pro-4gb
    highAvailabilityEnabled: true
```

**読み取りレプリカ（有料プラン）:**
```yaml
databases:
  - name: postgres
    databaseName: myapp_prod
    plan: pro-4gb
    readReplicas:
      - name: read-replica-1
        region: ohio
      - name: read-replica-2
        region: frankfurt
```

### Redis（キーと値のストア）

```yaml
databases:
  - name: redis
    plan: free
    maxmemoryPolicy: allkeys-lru
    ipAllowList: []
```

**プラン:** PostgreSQL と同じ

**`maxmemoryPolicy` の選択肢:**
- `allkeys-lru`: 最も長く使われていないキーを削除
- `volatile-lru`: TTL が設定されたキーのうち、最も長く使われていないものを削除
- `allkeys-random`: ランダムなキーを削除
- `volatile-random`: TTL が設定されたキーをランダムに削除
- `volatile-ttl`: TTL が最も短いキーを削除
- `noeviction`: メモリがいっぱいの場合にエラーを返す

## スケーリング

### 手動スケーリング

インスタンス数を固定します。

```yaml
services:
  - type: web
    name: my-app
    runtime: node
    plan: standard
    numInstances: 3
```

### オートスケーリング

CPU／メモリに応じて動的にスケーリングします（Professional ワークスペースが必要です）。

```yaml
services:
  - type: web
    name: my-app
    runtime: node
    plan: standard
    scaling:
      minInstances: 1
      maxInstances: 5
      targetCPUPercent: 60
      targetMemoryPercent: 70
```

**注意:**
- プレビュー環境ではオートスケーリングは無効です
- プレビュー環境では `minInstances` の数だけインスタンスが起動します
- Professional 以上のワークスペースが必要です

## ヘルスチェック

ヘルスチェックのエンドポイントを設定します。

```yaml
services:
  - type: web
    name: my-app
    runtime: node
    healthCheckPath: /health
```

**既定値:** `/`（ルートパス）

**推奨:** `200 OK` を返す専用の `/health` エンドポイントを追加してください。

## ビルドフィルター

変更されたファイルに応じて、ビルドを実行するタイミングを制御します。

```yaml
services:
  - type: web
    name: frontend
    runtime: static
    buildFilter:
      paths:
        - frontend/**
      ignoredPaths:
        - frontend/README.md
        - frontend/**/*.test.js
```

**動作:**
- `paths` を指定した場合: そのパス内のファイルが変更されたときにのみビルドします
- `ignoredPaths` を指定した場合: 除外対象のファイルだけが変更されたときはビルドしません

## プロジェクトと環境

複数の環境を持つプロジェクトにサービスを整理します。

```yaml
projects:
  - name: my-application
    environments:
      - name: production
        services:
          - type: web
            name: prod-api
            runtime: node
            plan: pro
            buildCommand: npm ci
            startCommand: npm start
        databases:
          - name: prod-postgres
            plan: pro-4gb
        networking:
          isolation: enabled
        permissions:
          protection: enabled

      - name: staging
        services:
          - type: web
            name: staging-api
            runtime: node
            plan: starter
            buildCommand: npm ci
            startCommand: npm start
        databases:
          - name: staging-postgres
            plan: free
```

**環境の機能:**
- `networking.isolation`: 環境間のネットワーク分離を有効にする
- `permissions.protection`: 環境の変更に承認を必須とする

## プレビュー環境

プルリクエスト用のプレビュー環境を自動的に設定します:

```yaml
previews:
  generation: auto_preview  # auto_preview | manual | none
```

**オプション:**
- `auto_preview`: 各PRのプレビュー環境を自動的に作成する
- `manual`: ユーザーが手動でプレビュー環境の作成を開始する
- `none`: プレビュー環境を無効にする

## 完全な例

複数のサービスとデータベースを含む、すべての機能を備えたBlueprint:

```yaml
services:
  # Web service
  - type: web
    name: web-app
    runtime: node
    plan: free
    region: oregon
    buildCommand: npm ci && npm run build
    startCommand: npm start
    branch: main
    autoDeploy: true
    healthCheckPath: /health
    envVars:
      - key: NODE_ENV
        value: production
      - key: DATABASE_URL
        fromDatabase:
          name: postgres
          property: connectionString
      - key: REDIS_URL
        fromDatabase:
          name: redis
          property: connectionString
      - key: JWT_SECRET
        sync: false

  # Background worker
  - type: worker
    name: queue-worker
    runtime: node
    plan: free
    buildCommand: npm ci
    startCommand: node worker.js
    envVars:
      - key: REDIS_URL
        fromDatabase:
          name: redis
          property: connectionString

  # Cron job
  - type: cron
    name: daily-cleanup
    runtime: node
    schedule: "0 3 * * *"
    buildCommand: npm ci
    startCommand: node scripts/cleanup.js
    envVars:
      - key: DATABASE_URL
        fromDatabase:
          name: postgres
          property: connectionString

  # Static frontend
  - type: web
    name: frontend
    runtime: static
    buildCommand: npm ci && npm run build
    staticPublishPath: ./dist
    routes:
      - type: rewrite
        source: /*
        destination: /index.html

databases:
  - name: postgres
    databaseName: app_production
    user: app_user
    plan: free
    postgresMajorVersion: "15"
    ipAllowList: []

  - name: redis
    plan: free
    maxmemoryPolicy: allkeys-lru
    ipAllowList: []
```

## 検証

デプロイ前にBlueprintを検証します（CLIコマンドが利用可能な場合）:

```bash
render blueprint validate
```

**よくある検証エラー:**
- 必須フィールドがない
- ランタイム値が無効
- 環境変数の参照が正しくない
- cron式が無効
- YAML構文が無効

## ベストプラクティス

1. **デフォルトでは常に `plan: free` を使用する** - 必要に応じてユーザーがアップグレードできるようにする
2. **すべてのシークレットに `sync: false` を指定する** - 機密値をハードコードしない
3. **データベースURLには `fromDatabase` を使用する** - 内部接続文字列を自動的に設定する
4. **ヘルスチェック用エンドポイントを追加する** - デプロイをより速く検出できる
5. **対話を必要としないビルドコマンドを使う** - ビルドの停止を防ぐ
6. **`0.0.0.0:$PORT` にバインドする** - Webサービスで必須
7. **環境変数グループを使用する** - サービス間で設定を共有する
8. **`autoDeploy: true` を有効にする** - push時に自動でデプロイする
9. **適切なリージョンを設定する** - ユーザーに最も近い場所を選ぶ
10. **ビルドフィルターを使用する** - モノレポでビルドのトリガーを最適化する

## 追加リソース

- Blueprintの公式仕様: https://render.com/docs/blueprint-spec
- Render CLIのドキュメント: https://render.com/docs/cli
- 環境変数ガイド: https://render.com/docs/environment-variables
