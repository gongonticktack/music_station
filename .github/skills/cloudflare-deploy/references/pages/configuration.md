# 設定

## wrangler.jsonc

```jsonc
{
  "name": "my-pages-project",
  "pages_build_output_dir": "./dist",
  "compatibility_date": "2026-01-01", // Use current date for new projects
  "compatibility_flags": ["nodejs_compat"],
  "placement": {
    "mode": "smart"  // Optional: Enable Smart Placement
  },
  "kv_namespaces": [{"binding": "KV", "id": "abcd1234..."}],
  "d1_databases": [{"binding": "DB", "database_id": "xxxx-xxxx", "database_name": "production-db"}],
  "r2_buckets": [{"binding": "BUCKET", "bucket_name": "my-bucket"}],
  "durable_objects": {"bindings": [{"name": "COUNTER", "class_name": "Counter", "script_name": "counter-worker"}]},
  "services": [{"binding": "API", "service": "api-worker"}],
  "queues": {"producers": [{"binding": "QUEUE", "queue": "my-queue"}]},
  "vectorize": [{"binding": "VECTORIZE", "index_name": "my-index"}],
  "ai": {"binding": "AI"},
  "analytics_engine_datasets": [{"binding": "ANALYTICS"}],
  "vars": {"API_URL": "https://api.example.com", "ENVIRONMENT": "production"},
  "env": {
    "preview": {
      "vars": {"API_URL": "https://staging-api.example.com"},
      "kv_namespaces": [{"binding": "KV", "id": "preview-namespace-id"}]
    }
  }
}
```

## ビルド設定

**Gitデプロイ**: Dashboard → Project → Settings → Build settings  
ビルドコマンド、出力ディレクトリ、環境変数を設定します。フレームワークの自動検出により、自動的に設定されます。

## 環境変数

### ローカル（.dev.vars）
```bash
# .dev.vars (never commit)
SECRET_KEY="local-secret-key"
API_TOKEN="dev-token-123"
```

### 本番環境
```bash
echo "secret-value" | npx wrangler pages secret put SECRET_KEY --project-name=my-project
npx wrangler pages secret list --project-name=my-project
npx wrangler pages secret delete SECRET_KEY --project-name=my-project
```

アクセス方法: `env.SECRET_KEY`

## 静的設定ファイル

### _redirects
ビルド出力先（例: `dist/_redirects`）に配置します:

```txt
/old-page /new-page 301          # 301 redirect
/blog/* /news/:splat 301         # Splat wildcard
/users/:id /members/:id 301      # Placeholders
/api/* /api-v2/:splat 200        # Proxy (no redirect)
```

**上限**: 合計2,100件（静的2,000件 + 動的100件）、1行あたり1,000文字  
**注**: Functionsが優先されます

### _headers
```txt
/secure/*
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff

/api/*
  Access-Control-Allow-Origin: *

/static/*
  Cache-Control: public, max-age=31536000, immutable
```

**上限**: 100ルール、1行あたり2,000文字  
**注**: 静的アセットのみが対象です。FunctionsではResponse内でヘッダーを設定します

### _routes.json
Functionsを呼び出すリクエストを制御します（ほとんどのフレームワークでは自動生成）:

```json
{
  "version": 1,
  "include": ["/*"],
  "exclude": ["/build/*", "/static/*", "/assets/*", "/*.{ico,png,jpg,css,js}"]
}
```

**目的**: Functionsは従量課金の対象ですが、静的リクエストは無料です。`exclude`が優先されます。最大100ルール、1ルールあたり100文字です。

## TypeScript

```bash
npx wrangler types --path='./functions/types.d.ts'
```

生成されたファイルを`types`の`functions/tsconfig.json`に指定します。

## Smart Placement

リクエストパターンに基づいて、関数の実行場所を自動的に最適化します。

```jsonc
{
  "placement": {
    "mode": "smart"  // Enable optimization (default: off)
  }
}
```

**仕組み**: システムは数時間から数日かけてトラフィックを分析し、関数の実行場所を次のいずれかに近づけます:
- ユーザーの集中地域（例: 地域ごとのトラフィック）
- データソース（例: D1データベースのプライマリロケーション）

**メリット**: 
- データベースを一元管理する読み取り中心のアプリでレイテンシが低下
- 地域ごとのトラフィックパターンがあるアプリでパフォーマンスが向上

**トレードオフ**:
- 初期学習期間: システムが最適化する間、最初のリクエストは遅くなることがあります
- 最適化にかかる時間: 24～48時間でパフォーマンスが向上します

**有効にする場面**: 特定の地域にD1/Durable Objectsを配置しているグローバルアプリや、地理的に集中したトラフィックがあるアプリ。

**有効にしない場面**: データのローカリティ制約がなく、トラフィックが世界中に均等に分散している場合。

## リモートバインディング（ローカル開発）

ローカルのモックではなく、本番バインディングに接続してローカル開発サーバーを実行します:

```bash
# All bindings remote
npx wrangler pages dev ./dist --remote

# Specific bindings remote (others local)
npx wrangler pages dev ./dist --remote --kv=KV --d1=DB
```

**用途**:
- 本番データに対するテスト（読み取り専用操作）
- バインディング固有の動作のデバッグ
- デプロイ前の変更の検証

**⚠️ 警告**: 
- 書き込みは**実際の本番データ**に反映されます
- 読み取り中心のデバッグ、または本番以外のアカウントでのみ使用してください
- 代わりに独立したプレビュー環境を作成することを検討してください

**要件**: バインディングへのアクセス権を持つアカウントでログインしている必要があります（`npx wrangler login`）。

## ローカル開発

```bash
# Basic
npx wrangler pages dev ./dist

# With bindings
npx wrangler pages dev ./dist --kv KV --d1 DB=local-db-id

# Remote bindings (production data)
npx wrangler pages dev ./dist --remote

# Persistence
npx wrangler pages dev ./dist --persist-to=./.wrangler/state/v3

# Proxy mode (SSR frameworks)
npx wrangler pages dev -- npm run dev
```

## 上限（2026年1月時点）

| リソース | Free | Paid |
|----------|------|------|
| **Functionsのリクエスト数** | 100k/日 | 無制限（従量課金） |
| **FunctionのCPU時間** | 10ms/リクエスト | 30ms/リクエスト（Workers Paid） |
| **Functionのメモリ** | 128MB | 128MB |
| **スクリプトサイズ** | 1MB（圧縮後） | 10MB（圧縮後） |
| **デプロイ数** | 500/月 | 5,000/月 |
| **デプロイあたりのファイル数** | 20,000 | 20,000 |
| **ファイルサイズ** | 25MB | 25MB |
| **ビルド時間** | 20分 | 20分 |
| **リダイレクト** | 2,100件（静的2,000件 + 動的100件） | 同じ |
| **ヘッダールール** | 100 | 100 |
| **ルートルール** | 100 | 100 |
| **サブリクエスト** | 50/リクエスト | 1,000/リクエスト（Workers Paid） |

**注**:
- FunctionsはWorkersランタイムを使用します。Workers Paidプランでは上限が引き上げられます
- ほとんどのプロジェクトではFreeプランで十分です
- 静的リクエストは常に無料です（上限の対象外）

[上限の詳細](https://developers.cloudflare.com/pages/platform/limits/)
