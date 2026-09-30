---
name: vercel-deploy
description: アプリや Web サイトを Vercel にデプロイする。「アプリをデプロイして」「デプロイしてリンクを教えて」「公開して」「プレビューデプロイを作成して」など、ユーザーがデプロイ操作を求めた場合に使用する。
---

# Vercel へのデプロイ

プロジェクトを Vercel にデプロイする。ユーザーが本番環境を明示的に指定しない限り、**必ずプレビューとしてデプロイする**。

## 前提条件

- Vercel CLI がインストール済みか、昇格した権限を使わずに確認する（例: `command -v vercel`）。
- サンドボックスがデプロイ時のネットワーク通信を妨げる場合に限り、実際のデプロイコマンドを昇格した権限で実行する（`sandbox_permissions=require_escalated`）。
- デプロイには数分かかることがあるため、適切なタイムアウトを設定する。

## クイックスタート

1. Vercel CLI がインストール済みか確認する（この確認で権限を昇格しない）。

```bash
command -v vercel
```

2. `vercel` がインストール済みなら、10分のタイムアウトで次を実行する。
```bash
vercel deploy [path] -y
```

**重要:** ビルドには時間がかかることがあるため、デプロイコマンドのタイムアウトは10分（600000 ms）にする。

3. `vercel` が未インストール、または CLI が `No existing credentials found` というエラーを返した場合は、以下の代替手段を使う。

## 代替手段（認証なし）

CLI が認証エラーで失敗した場合は、デプロイスクリプトを使う。

```bash
skill_dir="<path-to-skill>"

# 現在のディレクトリをデプロイ
bash "$skill_dir/scripts/deploy.sh"

# 指定したプロジェクトをデプロイ
bash "$skill_dir/scripts/deploy.sh" /path/to/project

# 既存の tarball をデプロイ
bash "$skill_dir/scripts/deploy.sh" /path/to/project.tgz
```

スクリプトがフレームワークの検出、パッケージ化、デプロイを処理する。ビルド完了を待ち、`previewUrl` と `claimUrl` を含む JSON を返す。

**ユーザーへの案内:** 「デプロイが完了しました: [previewUrl]。デプロイを管理するには [claimUrl] から引き取ってください。」

## 本番環境へのデプロイ

ユーザーが明示的に求めた場合のみ実行する。
```bash
vercel deploy [path] --prod -y
```

## 出力

デプロイ先の URL をユーザーに示す。代替手段でデプロイした場合は、引き取り用の URL も示す。

デプロイ先 URL が動作するか確認するために、curl や fetch は**実行しない**。リンクを返すだけにする。

## トラブルシューティング

### ネットワークアクセスの権限昇格

ネットワークの問題（タイムアウト、DNS エラー、接続のリセット）でデプロイに失敗したら、実際のデプロイコマンドを昇格した権限で再実行する（`sandbox_permissions=require_escalated`）。`command -v vercel` によるインストール確認では権限を昇格しない。サンドボックスが外向き通信をブロックする場合、デプロイには昇格したネットワークアクセスが必要となる。

ユーザーへの案内例:

```
Vercel へのデプロイにはネットワークアクセスの権限昇格が必要です。権限を昇格してコマンドを再実行してもよいですか？
```
