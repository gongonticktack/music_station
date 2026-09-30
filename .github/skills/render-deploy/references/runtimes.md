# Render のランタイムオプション

Render で利用できるランタイムの完全ガイドです。各言語のバージョン、設定、ベストプラクティスを説明します。

## ネイティブ言語ランタイム

### Node.js (`runtime: node`)

**サポート対象バージョン:** 14, 16, 18, 20, 21
**デフォルトバージョン:** 20

**バージョンの指定:**

`package.json` で Node のバージョンを指定します。
```json
{
  "engines": {
    "node": "20.x"
  }
}
```

**パッケージマネージャー:**
- **npm**: デフォルト。`package-lock.json` を使用
- **Yarn**: `yarn.lock` がある場合に自動検出
- **pnpm**: `pnpm-lock.yaml` がある場合に自動検出

**よく使われるビルドコマンド:**
```bash
npm ci                          # Recommended (faster, reproducible)
npm ci && npm run build         # Build step included
yarn install --frozen-lockfile  # Yarn equivalent
pnpm install --frozen-lockfile  # pnpm equivalent
```

**よく使われる起動コマンド:**
```bash
npm start                       # Uses "start" script in package.json
node server.js                  # Direct file execution
node dist/main.js               # Built output
```

**主なフレームワーク:**
- Express.js、Fastify、Koa（API）
- Next.js（フルスタック React）
- Nest.js（エンタープライズ向け TypeScript）
- Remix（フルスタック React）
- Nuxt.js（フルスタック Vue）

**設定例:**
```yaml
type: web
name: node-app
runtime: node
buildCommand: npm ci && npm run build
startCommand: npm start
```

---

### Python (`runtime: python`)

**サポート対象バージョン:** 3.8, 3.9, 3.10, 3.11, 3.12
**デフォルトバージョン:** 3.11

**バージョンの指定:**

方法 1 - `runtime.txt`:
```
python-3.11.5
```

方法 2 - `Pipfile`:
```toml
[requires]
python_version = "3.11"
```

**パッケージマネージャー:**
- **pip**: デフォルト。`requirements.txt` を使用
- **Poetry**: `pyproject.toml` がある場合に自動検出
- **Pipenv**: `Pipfile` がある場合に自動検出

**よく使われるビルドコマンド:**
```bash
pip install -r requirements.txt
pip install -r requirements.txt && python manage.py collectstatic --no-input
poetry install --no-dev
pipenv install --deploy
```

**よく使われる起動コマンド:**
```bash
gunicorn app:app                                    # Flask
gunicorn config.wsgi:application                    # Django
uvicorn main:app --host 0.0.0.0 --port $PORT       # FastAPI
celery -A tasks worker                              # Celery worker
```

**主なフレームワーク:**
- Django（フルスタックの Web フレームワーク）
- Flask（マイクロフレームワーク）
- FastAPI（モダンな非同期 API フレームワーク）
- Celery（タスクキュー）

**設定例:**
```yaml
type: web
name: python-app
runtime: python
buildCommand: pip install -r requirements.txt
startCommand: gunicorn app:app --bind 0.0.0.0:$PORT
```

---

### Go (`runtime: go`)

**サポート対象バージョン:** 1.20, 1.21, 1.22, 1.23
**デフォルトバージョン:** 最新の安定版

**バージョンの指定:**

`go.mod` で指定します。
```go
module myapp

go 1.22
```

**ビルドシステム:** Go モジュールを使用

**よく使われるビルドコマンド:**
```bash
go build -o bin/app .
go build -o bin/app cmd/server/main.go
go build -tags netgo -ldflags '-s -w' -o bin/app
```

**よく使われる起動コマンド:**
```bash
./bin/app
./bin/server
```

**主なフレームワーク:**
- net/http（標準ライブラリ）
- Gin（高速な Web フレームワーク）
- Echo（高性能フレームワーク）
- Chi（軽量ルーター）
- Fiber（Express に着想を得たフレームワーク）
- Gorilla Mux（高機能ルーター）

**設定例:**
```yaml
type: web
name: go-app
runtime: go
buildCommand: go build -o bin/app .
startCommand: ./bin/app
```

---

### Ruby (`runtime: ruby`)

**サポート対象バージョン:** 3.0, 3.1, 3.2, 3.3
**デフォルトバージョン:** 3.3

**バージョンの指定:**

方法 1 - `.ruby-version`:
```
3.3.0
```

方法 2 - `Gemfile`:
```ruby
ruby '3.3.0'
```

**パッケージマネージャー:** Bundler（`Gemfile` と `Gemfile.lock` を使用）

**よく使われるビルドコマンド:**
```bash
bundle install --jobs=4 --retry=3
bundle install && bundle exec rails assets:precompile
```

**よく使われる起動コマンド:**
```bash
bundle exec rails server -b 0.0.0.0 -p $PORT
bundle exec puma -C config/puma.rb
bundle exec rackup -o 0.0.0.0 -p $PORT
bundle exec sidekiq                                  # Worker
```

**主なフレームワーク:**
- Ruby on Rails（フルスタックフレームワーク）
- Sinatra（マイクロフレームワーク）
- Sidekiq（バックグラウンドジョブ）

**設定例:**
```yaml
type: web
name: rails-app
runtime: ruby
buildCommand: bundle install && bundle exec rails assets:precompile
startCommand: bundle exec puma -C config/puma.rb
```

---

### Rust (`runtime: rust`)

**サポート対象バージョン:** 最新の安定版
**デフォルトバージョン:** 最新の安定版

**ビルドシステム:** Cargo

**よく使われるビルドコマンド:**
```bash
cargo build --release
cargo build --release --locked
```

**よく使われる起動コマンド:**
```bash
./target/release/myapp
```

**主なフレームワーク:**
- Actix Web（高機能で高性能）
- Rocket（使いやすさを重視した Web フレームワーク）
- Axum（モダンで使いやすいフレームワーク）
- Warp（組み合わせ可能な Web フレームワーク）

**設定例:**
```yaml
type: web
name: rust-app
runtime: rust
buildCommand: cargo build --release
startCommand: ./target/release/myapp
```

---

### Elixir (`runtime: elixir`)

**サポート対象バージョン:** 最新の安定版
**デフォルトバージョン:** 最新の安定版

**ビルドシステム:** Mix

**よく使われるビルドコマンド:**
```bash
mix deps.get --only prod
mix deps.get && mix compile
mix do deps.get, compile, assets.deploy
```

**よく使われる起動コマンド:**
```bash
mix phx.server
elixir --name myapp -S mix phx.server
```

**主なフレームワーク:**
- Phoenix（フルスタックの Web フレームワーク）
- Phoenix LiveView（リアルタイムアプリケーション）

**設定例:**
```yaml
type: web
name: elixir-app
runtime: elixir
buildCommand: mix deps.get --only prod && mix compile
startCommand: mix phx.server
```

---

## コンテナランタイム

### Docker (`runtime: docker`)

リポジトリ内の Dockerfile からアプリケーションをビルドします。

**追加設定:**
- `dockerfilePath`: Dockerfile のパス（デフォルト: `./Dockerfile`）
- `dockerContext`: ビルドコンテキストのディレクトリ（デフォルト: `.`）

**設定例:**
```yaml
type: web
name: docker-app
runtime: docker
dockerfilePath: ./Dockerfile
dockerContext: .
```

**マルチステージ Dockerfile の例:**
```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY package*.json ./
RUN npm ci --only=production
EXPOSE 10000
CMD ["node", "dist/main.js"]
```

**ベストプラクティス:**
- マルチステージビルドを使ってイメージサイズを削減する
- ソースコードより先に `package.json` をコピーする（キャッシュ効率が向上）
- 不要なファイルを除外するために `.dockerignore` を使う
- `$PORT` 環境変数を使ってポートを動的に公開する
- セキュリティのため、root 以外のユーザーで実行する

---

### ビルド済みイメージ (`runtime: image`)

コンテナレジストリからビルド済みの Docker イメージをデプロイします。

**追加設定:**
- `image`: タグまたはダイジェストを含むイメージの完全な URL
- `registryCredential`: プライベートレジストリの認証情報

**パブリックイメージの例:**
```yaml
type: web
name: prebuilt-app
runtime: image
image: ghcr.io/myorg/myapp:v1.2.3
```

**プライベートレジストリの例:**
```yaml
type: web
name: private-app
runtime: image
image: myregistry.com/myapp:latest
registryCredential:
  username: my-username
  password:
    sync: false  # User provides in Dashboard
```

**用途:**
- CI/CD パイプラインでビルドしたイメージをデプロイする
- コンテナレジストリのイメージを使用する
- Docker Hub のイメージをデプロイする
- プライベートレジストリのイメージを使用する

---

## 静的ランタイム (`runtime: static`)

バックエンドランタイムを使わずに、ビルド済みの静的ファイルを配信します。ファイルは CDN 経由で配信されます。

**追加設定:**
- `staticPublishPath`: ビルド済みファイルを含むディレクトリ（例: `./dist`, `./build`）

**フレームワーク別のよく使われるビルドコマンド:**

**React (Create React App):**
```bash
npm ci && npm run build
# Outputs to: ./build
```

**Vue:**
```bash
npm ci && npm run build
# Outputs to: ./dist
```

**Next.js (Static Export):**
```bash
npm ci && npm run build && npm run export
# Outputs to: ./out
```

**Gatsby:**
```bash
npm ci && npm run build
# Outputs to: ./public
```

**Vite:**
```bash
npm ci && npm run build
# Outputs to: ./dist
```

**設定例:**
```yaml
type: web
name: react-app
runtime: static
buildCommand: npm ci && npm run build
staticPublishPath: ./build
```

---

## ランタイムの比較

| ランタイム | ビルド速度 | コールドスタート | 最適な用途 |
|---------|-------------|------------|----------|
| Node.js | 高速 | 高速 | API、フルスタックアプリ |
| Python | 中程度 | 中程度 | データアプリ、API、Web |
| Go | 高速 | 非常に高速 | 高性能 API |
| Ruby | 遅い | 中程度 | Rails アプリ、従来型 Web アプリ |
| Rust | 非常に遅い | 非常に高速 | 性能が重要なサービス |
| Elixir | 中程度 | 高速 | リアルタイム、並行処理アプリ |
| Docker | さまざま | 中程度 | あらゆる言語、カスタム設定 |
| Static | 非常に高速 | 該当なし | SPA、ドキュメント、マーケティングサイト |

---

## 適切なランタイムの選び方

**Node.js を選ぶ場合:**
- JavaScript ベースのアプリケーションを構築する
- npm の豊富なエコシステムが必要
- 素早く反復開発し、デプロイしたい
- フルスタックアプリケーション（Next.js、Remix）を構築する

**Python を選ぶ場合:**
- データを多く扱うアプリケーションを構築する
- 機械学習ライブラリが必要
- Django または Flask の知識がある
- データ処理パイプラインを構築する

**Go を選ぶ場合:**
- 高い性能と低いリソース使用量が必要
- マイクロサービスを構築する
- シンプルなデプロイ（単一バイナリ）を望む
- 高い並行性を処理する

**Ruby を選ぶ場合:**
- 従来型の Web アプリケーションを構築する
- Ruby on Rails の知識がある
- 迅速な開発を優先する

**Rust を選ぶ場合:**
- 最大限の性能が必要
- システムプログラミングを行う
- リソースに制約のある環境で動かす

**Docker を選ぶ場合:**
- カスタムのシステム依存関係が必要
- 複数言語を使うアプリケーション
- 既存の Dockerfile がある
- 環境を完全に制御したい

**Static を選ぶ場合:**
- SPA または静的サイトを構築する
- バックエンド処理が不要
- CDN キャッシュと高速な配信を利用したい
- ドキュメントサイトまたはマーケティングサイトを構築する
