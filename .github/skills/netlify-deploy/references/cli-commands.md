# Netlify CLI コマンド一覧

デプロイでよく使う Netlify CLI コマンドの早見表。

## 認証

```bash
# ブラウザーの OAuth でログイン
npx netlify login

# 認証状態とサイトのリンクを確認
npx netlify status

# ログアウト
npx netlify logout
```

## サイトの管理

```bash
# 現在のディレクトリを既存サイトにリンク
npx netlify link

# Git リモート URL でリンク
npx netlify link --git-remote-url <url>

# 新しいサイトを作成してリンク
npx netlify init

# 現在のサイトとのリンクを解除
npx netlify unlink

# Netlify ダッシュボードでサイトを開く
npx netlify open

# サイトの管理画面を開く
npx netlify open:admin

# ブラウザーでサイトを開く
npx netlify open:site
```

## デプロイ

```bash
# プレビュー・ドラフトをデプロイ（テスト用）
npx netlify deploy

# 本番環境へデプロイ
npx netlify deploy --prod

# 指定したディレクトリをデプロイ
npx netlify deploy --dir=dist

# メッセージを付けてデプロイ
npx netlify deploy --message="Deploy message"

# すべてのデプロイを一覧表示
npx netlify deploy:list
```

## 開発

```bash
# Netlify の機能を使えるローカル開発サーバーを起動
npx netlify dev

# 指定したポートでローカル開発サーバーを起動
npx netlify dev --port 3000
```

## サイト情報

```bash
# サイト情報を取得
npx netlify sites:list

# 現在のサイト情報を取得
npx netlify api getSite --data '{"site_id": "YOUR_SITE_ID"}'
```

## 環境変数

```bash
# 環境変数を一覧表示
npx netlify env:list

# 環境変数を設定
npx netlify env:set KEY value

# 環境変数の値を取得
npx netlify env:get KEY

# ファイルから環境変数を取り込む
npx netlify env:import .env
```

## ビルド

```bash
# ビルド設定を表示
npx netlify build --dry

# ローカルでビルド
npx netlify build
```

## 関数（サーバーレス）

```bash
# 関数を一覧表示
npx netlify functions:list

# 関数をローカルで呼び出す
npx netlify functions:invoke FUNCTION_NAME

# 新しい関数を作成
npx netlify functions:create FUNCTION_NAME
```

## ログ

```bash
# 関数のログを逐次表示
npx netlify logs

# 指定した関数のログを表示
npx netlify logs:function FUNCTION_NAME
```

## トラブルシューティング用コマンド

```bash
# CLI のバージョンを確認
npx netlify --version

# コマンドのヘルプを表示
npx netlify help [command]

# 詳細な出力で状態を確認
npx netlify status --verbose
```

## 終了コード

- `0` - 成功
- `1` - 一般的なエラー
- `2` - 認証エラー
- `3` - サイトが見つからない
- `4` - ビルド失敗

## よく使うオプション

- `--json` - JSON 形式で出力
- `--silent` - 出力を抑制
- `--debug` - デバッグ情報を表示
- `--force` - 確認プロンプトを省略

## 参考資料

- CLI の完全な文書: https://docs.netlify.com/cli/get-started/
- CLI の GitHub リポジトリ: https://github.com/netlify/cli
