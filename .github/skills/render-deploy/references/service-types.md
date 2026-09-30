# Renderのサービスタイプ

Renderで利用できる各サービスタイプの詳しい説明です。アプリケーションのニーズに応じて、適切なサービスタイプを選んでください。

## Webサービス（`type: web`）

### 目的

Webサービスは、インターネットからの受信リクエストを処理するHTTPサーバーです。HTTPS URLを通じてパブリックにアクセスできます。

### ユースケース

- **REST API**: モバイルアプリやフロントエンドアプリケーション向けのJSON API
- **GraphQLサーバー**: クライアントのクエリを処理するGraphQLエンドポイント
- **Webアプリケーション**: サーバーサイドでレンダリングするWebサイト（Django、Rails、Express）
- **フルスタックフレームワーク**: Next.js、Nuxt.js、Remix、SvelteKit
- **WebSocketサーバー**: リアルタイム通信を行うサーバー
- **SSRアプリケーション**: サーバーサイドでレンダリングするReact、Vue、Angularアプリ

### 主な特徴

- **パブリックURL**: `https://[service-name].onrender.com` が自動的に割り当てられます
- **ポートへのバインドが必要**: `0.0.0.0:$PORT` にバインドする必要があります
- **ヘルスチェック**: Renderがサービスにpingを送信し、稼働していることを確認します
- **HTTPS**: SSL/TLS証明書が自動的に適用されます
- **ロードバランシング**: 複数のインスタンスにトラフィックを分散します
- **カスタムドメイン**: 独自のドメイン名を利用できます

### 必須の設定

```yaml
type: web
name: my-api
runtime: node
buildCommand: npm ci
startCommand: npm start
```

### ベストプラクティス

1. **環境変数PORTにバインドする**:
```javascript
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0');
```

2. **ヘルスチェック用エンドポイントを追加する**:
```javascript
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});
```

3. **適切なタイムアウトを設定する**: Webリクエストは30秒以内に完了するようにします

4. **正常なシャットダウンを実装する**: SIGTERMシグナルを適切に処理します

---

## Workerサービス（`type: worker`）

### 目的

Workerサービスは、HTTPリクエストを処理せずにバックグラウンドタスクを実行します。パブリックにはアクセスできません。

### ユースケース

- **キュー処理**: Redisキュー、BullMQ、Celery、Sidekiq
- **バックグラウンドジョブ**: メール送信、画像処理、データのエクスポート
- **イベントコンシューマー**: メッセージキューのコンシューマー（Kafka、RabbitMQなど）
- **データパイプラインのワーカー**: ETL処理、データ変換
- **スケジュールされたバックグラウンドタスク**: 継続的に実行するプロセス（cronではないもの）
- **WebSocketバックエンド**: 専用のWebSocketハンドラーサービス

### 主な特徴

- **パブリックURLなし**: インターネットからアクセスできません
- **ポートへのバインド不要**: ポートでリッスンする必要はありません
- **ヘルスチェックなし**: Renderは別の方法でプロセスの健全性を監視します
- **長時間実行**: 無期限に実行できます
- **プライベート通信**: 内部ネットワーク経由でアクセスできます
- **クラッシュ時に再起動**: プロセスが停止すると自動的に再起動します

### 必須の設定

```yaml
type: worker
name: queue-processor
runtime: python
buildCommand: pip install -r requirements.txt
startCommand: celery -A tasks worker --loglevel=info
```

### ベストプラクティス

1. **メッセージキューに接続する**:
```python
import redis
r = redis.from_url(os.environ['REDIS_URL'])
```

2. **リトライ処理を実装する**: 障害を適切に処理します

3. **キューの深さを監視する**: 保留中のジョブを追跡します

4. **処理状況をログに記録する**: デバッグしやすくなります

5. **正常にシャットダウンする**: 終了前に現在のジョブを完了させます

### よくあるパターン

**BullMQを使ったNode.js:**
```yaml
type: worker
name: job-processor
runtime: node
buildCommand: npm ci
startCommand: node worker.js
envVars:
  - key: REDIS_URL
    fromDatabase:
      name: redis
      property: connectionString
```

**Celeryを使ったPython:**
```yaml
type: worker
name: celery-worker
runtime: python
buildCommand: pip install -r requirements.txt
startCommand: celery -A app.celery worker
envVars:
  - key: REDIS_URL
    fromDatabase:
      name: redis
      property: connectionString
```

---

## Cronジョブ（`type: cron`）

### 目的

Cronジョブは、繰り返し実行するスケジュール済みタスクです。実行後、処理を完了して終了します。

### ユースケース

- **データベースのバックアップ**: 定期的な自動バックアップ
- **レポート生成**: 日次／週次レポート
- **データのクリーンアップ**: 古いレコードを定期的に削除
- **キャッシュのウォームアップ**: キャッシュに事前にデータを格納
- **メールダイジェスト**: スケジュールに沿ってメールの要約を送信
- **データ同期**: システム間でデータを同期
- **バッチ処理**: 蓄積されたデータを処理

### 主な特徴

- **スケジュール実行**: cronスケジュールに従って実行されます
- **自動終了**: 処理完了後に終了します
- **ポートの継続的な待ち受けなし**: リッスン状態のポートを維持しません
- **ヘルスチェックなし**: タスクが完了するか、失敗するかのいずれかです
- **タイムゾーンはUTC**: すべてのスケジュールはUTCです
- **最大実行時間**: 設定した制限時間を超えるとジョブはタイムアウトします

### 必須の設定

```yaml
type: cron
name: daily-backup
runtime: node
schedule: "0 2 * * *"  # Daily at 2 AM UTC
buildCommand: npm ci
startCommand: node scripts/backup.js
```

### スケジュール形式

標準的なcron構文: `minute hour day month weekday`

**よく使われるスケジュール:**

| スケジュール | 説明 |
|----------|-------------|
| `*/5 * * * *` | 5分ごと |
| `0 * * * *` | 毎時 |
| `0 0 * * *` | 毎日午前0時（UTC） |
| `0 9 * * 1-5` | 平日の午前9時（UTC） |
| `0 0 1 * *` | 毎月1日 |
| `0 9 * * 1` | 毎週月曜日の午前9時（UTC） |

### ベストプラクティス

1. **障害を適切に処理する**: ジョブは冪等にします

2. **完了状況をログに記録する**: 成功または失敗を追跡します

3. **適切なタイムアウトを設定する**: 想定されるジョブの実行時間に合わせます

4. **UTC時刻を使う**: すべてのスケジュールはUTCに基づきます

5. **十分にテストする**: さまざまなデータ状況でテストします

### ユースケースの例

**データベースの日次バックアップ:**
```yaml
type: cron
name: db-backup
runtime: python
schedule: "0 1 * * *"  # 1 AM UTC daily
buildCommand: pip install -r requirements.txt
startCommand: python scripts/backup.py
envVars:
  - key: DATABASE_URL
    fromDatabase:
      name: postgres
      property: connectionString
  - key: S3_BUCKET
    value: my-backups
```

**キャッシュの毎時更新:**
```yaml
type: cron
name: cache-refresh
runtime: node
schedule: "0 * * * *"  # Top of every hour
buildCommand: npm ci
startCommand: node scripts/refresh-cache.js
```

---

## 静的サイト（`type: web` + `runtime: static`）

### 目的

CDN経由で静的なHTML、CSS、JavaScriptファイルを配信します。バックエンドのランタイムはありません。

### ユースケース

- **シングルページアプリケーション（SPA）**: React、Vue、Angularアプリ
- **静的サイトジェネレーター**: Gatsby、Next.js（静的エクスポート）、Hugo
- **ドキュメントサイト**: MkDocs、Docusaurus、VitePress
- **ランディングページ**: マーケティングサイト
- **ポートフォリオサイト**: 個人サイト
- **JAMstackサイト**: APIと連携する静的サイト

### 主な特徴

- **CDN配信**: 世界各地のエッジでキャッシュ
- **バックエンドのランタイムなし**: ビルド済みファイルのみを配信します
- **ビルド出力のみ**: ビルドディレクトリの内容を配信します
- **ルーティング対応**: SPAルーティング用のリライトルールを設定できます
- **カスタムヘッダー**: キャッシュ制御やセキュリティヘッダーを設定できます
- **高速デプロイ**: 素早くビルドしてデプロイできます

### 必須の設定

```yaml
type: web
name: frontend
runtime: static
buildCommand: npm ci && npm run build
staticPublishPath: ./dist  # or ./build, ./out, ./public
```

### SPAのルーティング

シングルページアプリケーションでは、クライアント側のルーティングを処理するためにリライトルールが必要です:

```yaml
type: web
name: react-app
runtime: static
buildCommand: npm ci && npm run build
staticPublishPath: ./build
routes:
  - type: rewrite
    source: /*
    destination: /index.html
```

### カスタムヘッダー

キャッシュ制御ヘッダーとセキュリティヘッダーを追加します:

```yaml
type: web
name: static-site
runtime: static
buildCommand: npm ci && npm run build
staticPublishPath: ./dist
headers:
  # Cache static assets
  - path: /static/*
    name: Cache-Control
    value: public, max-age=31536000, immutable

  # Security headers
  - path: /*
    name: X-Frame-Options
    value: DENY
  - path: /*
    name: X-Content-Type-Options
    value: nosniff
```

### ビルドフィルター

モノレポでは、フロントエンドのファイルが変更された場合のみビルドするようにできます:

```yaml
type: web
name: frontend
runtime: static
buildCommand: npm ci && npm run build
staticPublishPath: ./dist
buildFilter:
  paths:
    - frontend/**
  ignoredPaths:
    - frontend/**/*.test.js
    - frontend/README.md
```

### ベストプラクティス

1. **ビルド出力を最適化する**: 縮小、圧縮、ツリーシェイキングを行います

2. **適切なキャッシュヘッダーを使う**: ハッシュ付きアセットには長いキャッシュ期間を設定します

3. **セキュリティヘッダーを追加する**: よくある攻撃から保護します

4. **SPAルーティングを設定する**: クライアント側のルーティング用にリライトルールを追加します

5. **404を処理する**: カスタムの404.htmlページを作成します

---

## Privateサービス（`type: pserv`）

### 目的

Renderアカウント内からのみアクセスできる内部サービスです。インターネットには公開されません。

### ユースケース

- **内部API**: 他のサービスからのみアクセスされるサービス
- **データベースプロキシ**: 接続プール、読み取りレプリカ
- **マイクロサービス**: サービスメッシュアーキテクチャ
- **管理ツール**: 内部ダッシュボード
- **キャッシュ層**: 内部キャッシュサービス
- **メッセージブローカー**: 内部メッセージキュー

### 主な特徴

- **パブリックURLなし**: 内部DNS経由でのみアクセスできます
- **内部ネットワーク**: 高速で低レイテンシの接続
- **ポートへのバインドが必要**: `0.0.0.0:$PORT` にバインドする必要があります
- **プライベートDNS**: `[service-name].render-internal.com`
- **同一アカウント内のみ**: 同じアカウントからのみアクセスできます
- **インターネットアクセスなし**: トラフィックはRenderネットワーク内にとどまります

### 必須の設定

```yaml
type: pserv
name: internal-api
runtime: node
buildCommand: npm ci
startCommand: npm start
```

### Privateサービスへのアクセス

同じアカウント内の他のサービスからアクセスする場合:

```javascript
// Use .render-internal.com domain
const API_URL = 'http://internal-api.render-internal.com:10000';
```

または、サービス参照を使います:

```yaml
services:
  - type: web
    name: frontend
    runtime: node
    envVars:
      - key: INTERNAL_API_URL
        fromService:
          name: internal-api
          type: pserv
          property: hostport
```

### ベストプラクティス

1. **内部DNSを使う**: 常に`.render-internal.com`ドメインを使います

2. **認証は不要**: すでにアカウント内に隔離されています

3. **高速な通信**: サービス間のレイテンシが低くなります

4. **アーキテクチャを簡素化する**: 外部ロードバランサーが不要です

---

## 比較表

| 機能 | Web | Worker | Cron | Static | Private |
|---------|-----|--------|------|--------|---------|
| パブリックURL | ✅ あり | ❌ なし | ❌ なし | ✅ あり | ❌ なし |
| ポートへのバインド | ✅ 必須 | ❌ 不要 | ❌ 不要 | ❌ 該当なし | ✅ 必須 |
| ヘルスチェック | ✅ あり | ❌ なし | ❌ なし | ❌ 該当なし | ✅ あり |
| ランタイム | ✅ あり | ✅ あり | ✅ あり | ❌ なし | ✅ あり |
| 継続稼働 | ✅ あり | ✅ あり | ❌ なし | ✅ あり | ✅ あり |
| スケーリング | ✅ あり | ✅ あり | ❌ なし | ✅ あり | ✅ あり |
| ユースケース | HTTPサーバー | バックグラウンドジョブ | スケジュール済みタスク | 静的ファイル | 内部サービス |

## 適切なサービスタイプの選び方

**Webサービスを使う場合:**
- アプリがHTTPリクエストを処理する
- ユーザーがURL経由でアクセスする必要がある
- ロードバランシングとスケーリングが必要である

**Workerサービスを使う場合:**
- バックグラウンドジョブを処理する
- メッセージキューからデータを受信する
- HTTPを使わずに長時間稼働するプロセスを実行する

**Cronジョブを使う場合:**
- スケジュールされたタスクを実行する
- 処理を常時稼働させる必要がない
- タスクを定期的に実行する（毎時、毎日、毎週）

**静的サイトを使う場合:**
- ビルド済みのHTML/CSS/JSを配信する
- バックエンド処理が不要である
- CDNキャッシュを利用して高速に配信したい

**Privateサービスを使う場合:**
- 他のサービスからのみアクセスされるサービスである
- 内部通信のみを行いたい
- マイクロサービスアーキテクチャを構築する
