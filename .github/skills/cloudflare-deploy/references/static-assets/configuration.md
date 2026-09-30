## 設定

### 基本設定

最小限の設定に必要なのは `assets.directory` のみです。

```jsonc
{
  "name": "my-worker",
  "compatibility_date": "2025-01-01",  // Use current date for new projects
  "assets": {
    "directory": "./dist"
  }
}
```

### すべての設定オプション

```jsonc
{
  "name": "my-worker",
  "main": "src/index.ts",
  "compatibility_date": "2025-01-01",
  "assets": {
    "directory": "./dist",
    "binding": "ASSETS",
    "not_found_handling": "single-page-application",
    "html_handling": "auto-trailing-slash",
    "run_worker_first": ["/api/*", "!/api/docs/*"]
  }
}
```

**設定キー:**

- `directory`（文字列、必須）：アセットフォルダーのパス（例：`./dist`、`./public`、`./build`）
- `binding`（文字列、任意）：Worker コード内でアセットにアクセスするための名前（例：`env.ASSETS`）。デフォルト：`"ASSETS"`
- `not_found_handling`（文字列、任意）：アセットが見つからない場合の動作
  - `"single-page-application"`：アセット以外のパスに対して `/index.html` を返す（SPA のデフォルト）
  - `"404-page"`：存在する場合は `/404.html` を返し、存在しない場合は 404 を返す
  - `"none"`：アセットが見つからない場合は 404 を返す
- `html_handling`（文字列、任意）：URL の末尾のスラッシュに関する動作
- `run_worker_first`（ブール値 | 文字列配列、任意）：アセットを確認する前に Worker を実行するルート

### not_found_handling のモード

| モード | 動作 | 用途 |
|------|----------|----------|
| `"single-page-application"` | アセット以外のリクエストに対して `/index.html` を返す | React、Vue、Angular の SPA |
| `"404-page"` | 存在する場合は `/404.html` を返し、存在しない場合は 404 を返す | 独自のエラーページを持つ静的サイト |
| `"none"` | アセットが見つからない場合は 404 を返す | API 優先または独自ルーティングを使う場合 |

### html_handling のモード

HTML ファイルの末尾のスラッシュに関する動作を制御します。

| モード | `/page` | `/page/` | 用途 |
|------|---------|----------|----------|
| `"auto-trailing-slash"` | `/page/index.html` が存在する場合は `/page/` にリダイレクト | `/page/index.html` を返す | デフォルト、SEO に適した設定 |
| `"force-trailing-slash"` | 常に `/page/` にリダイレクト | 存在する場合は返す | 末尾のスラッシュを統一 |
| `"drop-trailing-slash"` | 存在する場合は返す | `/page` にリダイレクト | URL をすっきりさせる |
| `"none"` | 変更なし | 変更なし | 独自のルーティングロジック |

**デフォルト：** `"auto-trailing-slash"`

### run_worker_first の設定

アセットを確認する前に Worker を実行するリクエストを制御します。

**ブール値の構文：**

```jsonc
{
  "assets": {
    "run_worker_first": true  // ALL requests invoke Worker
  }
}
```

**配列の構文（推奨）：**

```jsonc
{
  "assets": {
    "run_worker_first": [
      "/api/*",           // Positive pattern: match API routes
      "/admin/*",         // Match admin routes
      "!/admin/assets/*"  // Negative pattern: exclude admin assets
    ]
  }
}
```

**パターンのルール:**

- グロブパターン：`*`（任意の文字）、`**`（任意のパスセグメント）
- 除外パターン：除外するには先頭に `!` を付けます
- 優先順位：除外パターンは一致するパターンより優先されます
- デフォルト：`false`（アセットを直接配信）

**選択の目安:**

- API 優先のアプリ（静的アセットが少ない）では `true` を使用します
- ハイブリッドアプリ（API と静的アセット）では配列パターンを使用します
- 静的コンテンツ優先のサイト（動的ルートが最小限）では `false` を使用します

### .assetsignore ファイル

`.assetsignore` を使ってアップロード対象からファイルを除外します（`.gitignore` と同じ構文）：

```
# .assetsignore
_worker.js
*.map
*.md
node_modules/
.git/
```

**よく使うパターン:**

- `_worker.js` - Worker コードをアセットから除外
- `*.map` - ソースマップを除外
- `*.md` - Markdown ファイルを除外
- 開発用生成物

### Vite プラグインとの統合

Vite ベースのプロジェクトでは、`@cloudflare/vite-plugin` を使用します。

```typescript
// vite.config.ts
import { defineConfig } from 'vite';
import { cloudflare } from '@cloudflare/vite-plugin';

export default defineConfig({
  plugins: [
    cloudflare({
      assets: {
        directory: './dist',
        binding: 'ASSETS'
      }
    })
  ]
});
```

**機能:**

- 開発時にアセットを自動検出
- アセットのホットモジュール置換
- 本番ビルドとの統合
- 要件：Wrangler 4.0.0 以降、`@cloudflare/vite-plugin` 1.0.0 以降

### 主な互換性日付

| 日付 | 機能 | 影響 |
|------|---------|--------|
| `2025-04-01` | ナビゲーションリクエストの最適化 | SPA ではナビゲーション時に Worker を呼び出さないため、コストを削減できます |

新規プロジェクトでは現在の日付を使用してください。全一覧は[互換性日付](https://developers.cloudflare.com/workers/configuration/compatibility-dates/)を参照してください。

### 環境ごとの設定

設定を切り替えるには、`wrangler.jsonc` 環境を使用します。

```jsonc
{
  "name": "my-worker",
  "assets": { "directory": "./dist" },
  "env": {
    "staging": {
      "assets": {
        "not_found_handling": "404-page"
      }
    },
    "production": {
      "assets": {
        "not_found_handling": "single-page-application"
      }
    }
  }
}
```

次のコマンドでデプロイします：`wrangler deploy --env staging`