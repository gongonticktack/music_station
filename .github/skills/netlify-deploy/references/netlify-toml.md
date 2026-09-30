# netlify.toml 設定の参考資料

Netlify のビルドとデプロイに使う設定ファイル。

## 基本構造

```toml
[build]
  command = "npm run build"
  publish = "dist"
```

## ビルド設定

### 一般的な設定

```toml
[build]
  # サイトのビルドコマンド
  command = "npm run build"

  # 公開するディレクトリ（リポジトリのルートからの相対パス）
  publish = "dist"

  # 関数のディレクトリ
  functions = "netlify/functions"

  # ベースディレクトリ（リポジトリのルート以外の場合）
  base = "packages/frontend"

  # 特定の条件ではビルドを省略
  ignore = "git diff --quiet HEAD^ HEAD package.json"
```

## 環境変数

```toml
[build.environment]
  NODE_VERSION = "18"
  NPM_FLAGS = "--prefix=/dev/null"

[context.production.environment]
  NODE_ENV = "production"
```

## フレームワークの検出

Netlify はフレームワークを自動検出するが、設定を上書きできる。

### Next.js

```toml
[build]
  command = "npm run build"
  publish = ".next"
```

### React (Vite)

```toml
[build]
  command = "npm run build"
  publish = "dist"
```

### Vue

```toml
[build]
  command = "npm run build"
  publish = "dist"
```

### Astro

```toml
[build]
  command = "npm run build"
  publish = "dist"
```

### SvelteKit

```toml
[build]
  command = "npm run build"
  publish = "build"
```

## リダイレクトとリライト

```toml
[[redirects]]
  from = "/old-path"
  to = "/new-path"
  status = 301

[[redirects]]
  from = "/api/*"
  to = "https://api.example.com/:splat"
  status = 200

# SPA のフォールバック（クライアント側のルーティング用）
[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

## ヘッダー

```toml
[[headers]]
  for = "/*"
  [headers.values]
    X-Frame-Options = "DENY"
    X-XSS-Protection = "1; mode=block"
    Content-Security-Policy = "default-src 'self'"

[[headers]]
  for = "/assets/*"
  [headers.values]
    Cache-Control = "public, max-age=31536000, immutable"
```

## デプロイ環境ごとの設定

デプロイ環境ごとに異なる設定を適用する。

```toml
# 本番環境
[context.production]
  command = "npm run build:prod"
  [context.production.environment]
    NODE_ENV = "production"

# デプロイプレビュー
[context.deploy-preview]
  command = "npm run build:preview"

# ブランチのデプロイ
[context.branch-deploy]
  command = "npm run build:staging"

# 指定したブランチ
[context.staging]
  command = "npm run build:staging"
```

## 関数の設定

```toml
[functions]
  directory = "netlify/functions"
  node_bundler = "esbuild"

[[functions]]
  path = "/api/*"
  function = "api"
```

## ビルドプラグイン

```toml
[[plugins]]
  package = "@netlify/plugin-lighthouse"

  [plugins.inputs]
    output_path = "reports/lighthouse.html"

[[plugins]]
  package = "netlify-plugin-submit-sitemap"

  [plugins.inputs]
    baseUrl = "https://example.com"
    sitemapPath = "/sitemap.xml"
```

## エッジ関数

```toml
[[edge_functions]]
  function = "geolocation"
  path = "/api/location"
```

## 処理設定

```toml
[build.processing]
  skip_processing = false

[build.processing.css]
  bundle = true
  minify = true

[build.processing.js]
  bundle = true
  minify = true

[build.processing.html]
  pretty_urls = true

[build.processing.images]
  compress = true
```

## よくある設定例

### シングルページアプリケーション（SPA）

```toml
[build]
  command = "npm run build"
  publish = "dist"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

### ベースディレクトリを指定するモノレポ

```toml
[build]
  base = "packages/web"
  command = "npm run build"
  publish = "dist"
```

### 国別ルーティングを使った複数のリダイレクト

```toml
[[redirects]]
  from = "/"
  to = "/uk"
  status = 302
  conditions = {Country = ["GB"]}

[[redirects]]
  from = "/"
  to = "/us"
  status = 302
  conditions = {Country = ["US"]}
```

## 検証

netlify.toml を検証する。

```bash
npx netlify build --dry
```

## 参考資料

- 設定に関する完全な資料: https://docs.netlify.com/configure-builds/file-based-configuration/
- フレームワーク別のガイド: https://docs.netlify.com/frameworks/
