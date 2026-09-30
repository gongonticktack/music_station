# Netlify デプロイのパターン

Netlify スキルでよくあるデプロイの場面と推奨手順。

## デプロイの判断フロー

```
認証済みか？
├─ いいえ → `netlify login` を実行
└─ はい → サイトはリンク済みか？
    ├─ いいえ → Git リポジトリか？
    │   ├─ はい → `netlify link --git-remote-url` を試す
    │   │   ├─ 成功 → デプロイに進む
    │   │   └─ 失敗 → `netlify init` を実行
    │   └─ いいえ → `netlify init` を実行
    └─ はい → 初回デプロイか、既存サイトか？
        ├─ 初回デプロイ・新規サイト → `netlify deploy --prod`
        └─ 既存サイト → `netlify deploy`（プレビュー）
```

## 場面1: 初回デプロイ（新しいプロジェクト）

**状況**: ユーザーのプロジェクトは Netlify にデプロイされたことがない。

**手順**:
1. 認証を確認する: `npx netlify status`
2. 未認証ならログインする: `npx netlify login`
3. 新しいサイトを初期化する: `npx netlify init`
   - ユーザーに設定手順を案内する。
   - 必要に応じて netlify.toml を作成する。
4. 依存関係をインストールする: `npm install`
5. 本番環境にデプロイする: `npx netlify deploy --prod`

**例**:
```bash
npx netlify status
# サイトにリンクされていない

npx netlify login
# 認証用のブラウザーを開く

npx netlify init
# サイト作成を案内する

npm install
npx netlify deploy --prod
```

## 場面2: 既存の Git リポジトリを既存サイトへリンク

**状況**: Netlify にすでにサイトがあり、ユーザーがローカルのリポジトリをリンクしたい。

**手順**:
1. 認証を確認する: `npx netlify status`
2. Git リモートを取得する: `git remote show origin`
3. URL を取り出す（例: `https://github.com/user/repo.git`）。
4. リモート URL でリンクする: `npx netlify link --git-remote-url <URL>`
5. サイトが見つかればリンク完了。見つからなければ `netlify init` を実行する。

**例**:
```bash
git remote show origin
# * リモート origin
#   取得 URL: https://github.com/user/my-app.git

npx netlify link --git-remote-url https://github.com/user/my-app.git
# サイトのリンクに成功
```

## 場面3: プレビューデプロイ（変更のテスト）

**状況**: ユーザーが本番環境に反映する前に変更をテストしたい。

**手順**:
1. サイトがリンク済みか確認する: `npx netlify status`
2. コードを変更する。
3. プレビューをデプロイする: `npx netlify deploy`
4. プレビュー URL を確認する。
5. 承認されたら本番環境にデプロイする: `npx netlify deploy --prod`

**例**:
```bash
# コードを変更

npx netlify deploy
# ドラフトデプロイ URL: https://507f1f77bcf86cd799439011-my-app.netlify.app

# プレビューをテストしてから実行:
npx netlify deploy --prod
```

## 場面4: フレームワーク別のデプロイ

### Next.js

```bash
# Next.js の出力先は通常 .next
npx netlify deploy --prod

# netlify.toml に次を設定:
# [build]
#   command = "npm run build"
#   publish = ".next"
```

### React (Vite)

```bash
# Vite の既定の出力先は dist
npm run build
npx netlify deploy --dir=dist --prod

# netlify.toml:
# [build]
#   command = "npm run build"
#   publish = "dist"
```

### 静的 HTML

```bash
# ビルドは不要
npx netlify deploy --dir=. --prod
```

## 場面5: モノレポのデプロイ

**状況**: プロジェクトがモノレポのサブディレクトリにある。

**手順**:
1. プロジェクトのサブディレクトリに移動する: `cd packages/frontend`
2. または netlify.toml でベースディレクトリを設定する。
   ```toml
   [build]
     base = "packages/frontend"
     command = "npm run build"
     publish = "dist"
   ```
3. 通常どおりデプロイする: `npx netlify deploy --prod`

## 場面6: 環境変数

**状況**: プロジェクトで秘密情報や環境ごとの設定が必要。

**手順**:
1. 秘密情報を Git にコミットしない。
2. Netlify ダッシュボードまたは CLI で設定する。
   ```bash
   npx netlify env:set API_KEY "secret_value"
   npx netlify env:set NODE_ENV "production"
   ```
3. コードでは `process.env.API_KEY` で参照する。
4. デプロイする: `npx netlify deploy --prod`

## 場面7: 独自ドメインの設定

**状況**: ユーザーが独自ドメインを使いたい。

**手順**:
1. 先にサイトをデプロイする: `npx netlify deploy --prod`
2. ダッシュボードまたは CLI でドメインを追加する。
   ```bash
   npx netlify open:admin
   # ドメイン設定に移動
   ```
3. Netlify の案内に従って DNS レコードを更新する。
4. DNS の伝播を待つ（最大48時間かかることがある）。

## 推奨手順

### 1. 最初にプレビューする

```bash
# プレビューをデプロイ
npx netlify deploy

# 十分にテスト
# その後、本番環境へデプロイ
npx netlify deploy --prod
```

### 2. netlify.toml で設定を統一する

リポジトリのルートに `netlify.toml` を作成する。

```toml
[build]
  command = "npm run build"
  publish = "dist"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

すべてのデプロイで一貫したビルドを行える。

### 3. フレームワークの検出

可能な場合は Netlify の自動検出を使う。ビルド設定を明示するのは次の場合のみ。
- Netlify がフレームワークを検出できない。
- 独自のビルドコマンドが必要。
- プロジェクトの構造が標準と異なる。

### 4. 依存関係のインストール

デプロイ前に必ず依存関係がインストール済みか確認する。

```bash
npm install  # または yarn install、pnpm install
npx netlify deploy
```

### 5. 先にローカルでビルドする

デプロイ前にローカルでビルドをテストする。

```bash
npm run build
# ビルド成果物があるか確認

npx netlify deploy --dir=dist
```

### 6. デプロイメッセージを使う

デプロイに変更内容の情報を付ける。

```bash
npx netlify deploy --prod --message="Fix login bug"
```

## エラーからの復旧方法

### "Publish directory not found"

**原因**: ビルドコマンドが想定された出力ディレクトリを作成しなかった。

**対処法**:
1. ローカルでビルドする: `npm run build`
2. 出力ディレクトリ名を確認する。
3. netlify.toml または CLI の入力を正しいパスに更新する。

### "Command failed with exit code 1"

**原因**: ビルドコマンドが失敗した。

**対処法**:
1. ビルドログで具体的なエラーを確認する。
2. ローカルでビルドして再現する: `npm run build`
3. ビルドエラーを修正する。
4. 再度デプロイする。

### "Not logged in"

**原因**: 認証トークンの期限が切れた、またはトークンがない。

**対処法**:
```bash
npx netlify logout
npx netlify login
```

### "No site linked"

**原因**: プロジェクトが Netlify サイトに接続されていない。

**対処法**:
```bash
# 既存サイトへのリンクを試す
npx netlify link

# または新しいサイトを作成
npx netlify init
```

## パフォーマンスに関するヒント

1. 自動最適化のため、netlify.toml で**処理設定を有効にする**。
   ```toml
   [build.processing.css]
     bundle = true
     minify = true
   ```

2. 静的アセットに**キャッシュヘッダーを使う**。
   ```toml
   [[headers]]
     for = "/assets/*"
     [headers.values]
       Cache-Control = "public, max-age=31536000, immutable"
   ```

3. デプロイ前に**画像を最適化**するか、Netlify Image CDN を使う。

4. サーバーレスのバックエンドには **Netlify Functions を使う**（可能なら外部 API 呼び出しを避ける）。

## 参考資料

- Netlify CLI の文書: https://docs.netlify.com/cli/get-started/
- フレームワーク統合のガイド: https://docs.netlify.com/frameworks/
- ビルドの設定: https://docs.netlify.com/configure-builds/
