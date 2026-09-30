# コードベースの分析（デプロイ）

Renderへのデプロイを準備する際、フレームワーク固有の検出とビルド／起動コマンドの選択にはこのリファレンスを使用します。

## Node.jsプロジェクト
- `package.json` を読み、フレームワーク（Express、Next.js、Nest.js、Fastifyなど）を検出する
- `scripts` セクションでビルド／起動コマンドを確認する
- Nodeのバージョンは `engines` フィールド、`.node-versions`、または `.nvmrc` で確認する
- パッケージマネージャーを検出する:
  - `bun.lockb` (Bun) -> `bun install --frozen-lockfile` / `bun run start`
  - `pnpm-lock.yaml` (pnpm) -> `pnpm install --frozen-lockfile` / `pnpm start`
  - `yarn.lock` (Yarn) -> `yarn install --frozen-lockfile` / `yarn start`
  - `package-lock.json` (npm) -> `npm ci` / `npm start`
  - `package.json` のみ（npmへのフォールバック） -> `npm install` / `npm start`

## Pythonプロジェクト
- 依存関係ファイルを確認し、パッケージマネージャーを検出する:
  - `uv.lock` (uv) -> `uv sync` / `uv run gunicorn app:app`
  - `poetry.lock` (Poetry) -> `poetry install --no-dev` / `poetry run gunicorn app:app`
  - `Pipfile.lock` (pipenv) -> `pipenv install --deploy` / `pipenv run gunicorn app:app`
  - `requirements.txt` (pip) -> `pip install -r requirements.txt` / `gunicorn app:app`
  - `pyproject.toml` のみ -> `[tool.uv]`、`[tool.poetry]` を確認するか、pipを使用する
- フレームワークを検出する: Django、Flask、FastAPI、Celeryなど
- Pythonのバージョンを確認する:
  - `.python-version` (uv/pyenv)
  - `runtime.txt` (Render固有)
  - `pyproject.toml` (`requires-python` フィールド)

## Goプロジェクト
- 依存関係は `go.mod` を読み取る
- Webフレームワークを特定する（Gin、Echo、Chi、Fiber、net/http）
- `go.mod` からGoのバージョンを確認する

## 静的サイト
- ビルド出力ディレクトリ（`build/`、`dist/`、`site/`、`public/`）を探す
- フレームワークを検出する: React、Vue、Gatsby、Next.js（静的エクスポート）
- `package.json` のビルドスクリプトを確認する

## Dockerプロジェクト
- `Dockerfile` を探す
- 公開ポートとビルドステージを確認する
- `docker-compose.yml` のパターンを確認する

## 抽出する主な情報
- ビルドコマンド（例: `npm ci`、`pip install -r requirements.txt`、`go build`）
- 起動コマンド（例: `npm start`、`gunicorn app:app`、`./bin/app`）
- コード内で使われている環境変数（APIキー、データベースURL、シークレット）
- データベース要件（PostgreSQL、Redis、MongoDB）
- ポートのバインド（アプリが実行するポートに環境変数を使っているか確認する）
