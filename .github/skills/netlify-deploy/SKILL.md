---
name: netlify-deploy
description: Netlify CLI（`npx netlify`）を使って Web プロジェクトを Netlify にデプロイする。プレビューや本番環境へのデプロイを含め、Netlify でのサイト・リポジトリのデプロイ、ホスティング、公開、リンクをユーザーが求めた場合に使用する。
---

# Netlify デプロイスキル

プロジェクトの設定とデプロイ状況を検出し、Netlify CLI で Web プロジェクトをデプロイする。

## 概要

このスキルは次の手順で Netlify へのデプロイを自動化する。
- Netlify CLI の認証を確認する。
- プロジェクトの設定とフレームワークを検出する。
- 既存サイトにリンクするか、新しいサイトを作成する。
- 本番環境またはプレビュー環境にデプロイする。

## 前提条件

- **Netlify CLI**: npx 経由で使う（グローバルインストールは不要）。
- **認証**: ログイン済みの Netlify アカウント。
- **プロジェクト**: 現在のディレクトリに有効な Web プロジェクトがあること。
- サンドボックスがデプロイ時のネットワーク通信を妨げる場合は、`sandbox_permissions=require_escalated` で再実行する。
- デプロイには数分かかることがあるため、適切なタイムアウトを設定する。

## 認証の方法

このスキルは、**事前に認証済みの Netlify CLI** を使う。

1. `npx netlify status` で認証状態を確認する。
2. 未認証なら `npx netlify login` の手順をユーザーに案内する。
3. 認証できない場合は、分かりやすく失敗を伝える。

認証には次のいずれかを使う。
- **ブラウザーを使った OAuth**（優先）: `netlify login` で認証用のブラウザーを開く。
- **API キー**（代替）: 環境変数 `NETLIFY_AUTH_TOKEN` を設定する。

## 手順

### 1. Netlify CLI の認証を確認する

Netlify にログイン済みか確認する。

```bash
npx netlify status
```

**想定される出力**:
- ✅ 認証済み: ログイン中のメールアドレスとサイトのリンク状態が表示される。
- ❌ 未認証: `Not logged into any site` または認証エラーが表示される。

**未認証の場合**は、ユーザーに次を案内する。

```bash
npx netlify login
```

OAuth 認証用のブラウザーウィンドウが開く。ユーザーがログインを完了するのを待ち、`netlify status` で再確認する。

**代替手段: API キーでの認証**

ブラウザーで認証できない場合は、次を設定できる。

```bash
export NETLIFY_AUTH_TOKEN=your_token_here
```

トークンの作成先: https://app.netlify.com/user/applications#personal-access-tokens

### 2. サイトのリンク状態を確認する

`netlify status` の出力から次を判断する。
- **リンク済み**: サイトがすでに Netlify に接続され、名前や URL が表示される。
- **未リンク**: サイトへのリンクまたは新規作成が必要。

### 3. 既存サイトにリンクするか、新規作成する

**リンク済みなら**手順4へ進む。

**未リンクなら**、Git のリモート URL でリンクを試みる。

```bash
# プロジェクトが Git 管理か確認
git remote show origin

# Git 管理ならリモート URL を取り出す
# 形式: https://github.com/username/repo または git@github.com:username/repo.git

# Git リモートでリンクを試す
npx netlify link --git-remote-url <REMOTE_URL>
```

**リンクに失敗した場合**（Netlify 上にサイトがない場合）:

```bash
# 対話形式で新しいサイトを作成
npx netlify init
```

このコマンドで次の設定を案内する。
1. チームまたはアカウントの選択
2. サイト名の設定
3. ビルド設定
4. 必要に応じた netlify.toml の作成

### 4. 依存関係を確認する

デプロイ前にプロジェクトの依存関係がインストール済みか確認する。

```bash
# npm プロジェクトの場合
npm install

# ほかのパッケージマネージャーでは、適切なコマンドを検出して使う
# yarn install、pnpm install など
```

### 5. Netlify にデプロイする

状況に応じてデプロイの種類を選ぶ。

**プレビュー・ドラフトデプロイ**（既存サイトの既定値）:

```bash
npx netlify deploy
```

テスト用の固有 URL を持つプレビューデプロイを作成する。

**本番環境へのデプロイ**（新規サイト、または本番環境が明示的に指定された場合）:

```bash
npx netlify deploy --prod
```

公開中の本番 URL にデプロイする。

**デプロイの処理**:
1. CLI が netlify.toml からビルド設定を検出するか、ユーザーに尋ねる。
2. プロジェクトをローカルでビルドする。
3. ビルド成果物を Netlify にアップロードする。
4. デプロイ先の URL を返す。

### 6. 結果を報告する

デプロイ後、ユーザーに次を報告する。
- **デプロイ URL**: 今回のデプロイ固有の URL。
- **サイト URL**: 本番環境にデプロイした場合の URL。
- **デプロイログ**: ログを確認できる Netlify ダッシュボードへのリンク。
- **次の手順**: サイトやダッシュボードを見るための `netlify open` を提案する。

## netlify.toml の扱い

`netlify.toml` があれば、CLI は自動的に使用する。なければ、次の設定を尋ねる。
- **ビルドコマンド**: 例: `npm run build`、`next build`。
- **公開ディレクトリ**: 例: `dist`、`build`、`.next`。

一般的なフレームワークの既定値:
- **Next.js**: ビルドコマンドは `npm run build`、公開先は `.next`。
- **React（Vite）**: ビルドコマンドは `npm run build`、公開先は `dist`。
- **静的 HTML**: ビルドコマンドなし、現在のディレクトリを公開。

可能なら `package.json` からフレームワークを検出し、適切な設定を提案する。

## 一連の作業例

```bash
# 1. 認証を確認
npx netlify status

# 未認証の場合:
npx netlify login

# 2. サイトをリンク（必要な場合）
# 最初に Git によるリンクを試す
git remote show origin
npx netlify link --git-remote-url https://github.com/user/repo

# サイトがなければ新規作成:
npx netlify init

# 3. 依存関係をインストール
npm install

# 4. デプロイ（テスト用プレビュー）
npx netlify deploy

# 5. 準備ができたら本番環境へデプロイ
npx netlify deploy --prod
```

## エラーへの対応

よくある問題と対処法:

**"Not logged in"**
→ `npx netlify login` を実行する。

**"No site linked"**
→ `npx netlify link` または `npx netlify init` を実行する。

**"Build failed"**
→ netlify.toml または CLI で設定したビルドコマンドと公開ディレクトリを確認する。
→ 依存関係がインストール済みか確認する。
→ ビルドログで具体的なエラーを確認する。

**"Publish directory not found"**
→ ビルドコマンドが正常に完了したか確認する。
→ 公開ディレクトリのパスが正しいか確認する。

## トラブルシューティング

### ネットワークアクセスの権限昇格

ネットワークの問題（タイムアウト、DNS エラー、接続のリセット）でデプロイに失敗した場合は、昇格した権限で再実行する（`sandbox_permissions=require_escalated`）。サンドボックスが外向き通信をブロックする場合、デプロイには昇格したネットワークアクセスが必要となる。

ユーザーへの案内例:

```
Netlify へのデプロイにはネットワークアクセスの権限昇格が必要です。権限を昇格してコマンドを再実行してもよいですか？
```

## 環境変数

秘密情報と設定について:

1. 秘密情報を Git にコミットしない。
2. Netlify ダッシュボードの Site Settings → Environment Variables で設定する。
3. ビルド中は `process.env.VARIABLE_NAME` で参照する。

## ヒント

- 本番環境へのデプロイ前に、まず `netlify deploy`（`--prod` なし）でテストする。
- Netlify ダッシュボードでサイトを見るには `netlify open` を実行する。
- Netlify Functions を使う場合、関数のログを見るには `netlify logs` を実行する。
- Netlify Functions を使ったローカル開発には `netlify dev` を使う。

## 参照先

- Netlify CLI の文書: https://docs.netlify.com/cli/get-started/
- netlify.toml の文書: https://docs.netlify.com/configure-builds/file-based-configuration/

## 同梱の参考資料（必要な場合に読み込む）

- [CLI コマンド一覧](references/cli-commands.md)
- [デプロイのパターン](references/deployment-patterns.md)
- [netlify.toml のガイド](references/netlify-toml.md)
