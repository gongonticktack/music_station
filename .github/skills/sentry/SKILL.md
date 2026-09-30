---
name: "sentry"
description: "Sentry の課題やイベントの調査、最近の本番環境エラーの要約、Sentry CLI による基本的な稼働状況の取得を求められたときに使う。`sentry` コマンドで読み取り専用の問い合わせを行う。"
---


# Sentry（読み取り専用の監視）

## クイックスタート

- 未認証なら、ユーザーに `sentry auth login` の実行か、環境変数 `SENTRY_AUTH_TOKEN` の設定を依頼する。
- CLI は `.env` ファイルの DSN、ソースコード、設定の既定値、ディレクトリ名から組織とプロジェクトを自動検出する。失敗した場合や対象を誤った場合にのみ `<org>/<project>` を指定する。
- 既定値: 期間 `24h`、環境 `production`、上限 20 件。
- 出力をプログラムで処理するときは常に `--json` を使う。`--json --fields` で必要な項目だけを選び、出力を減らす。
- API エンドポイントをすばやく調べるには `sentry schema <resource>` を使う。

CLI が未インストールなら、ユーザーに次の手順を案内する。
1. Sentry CLI をインストールする: `curl https://cli.sentry.dev/install -fsS | bash`
2. 認証する: `sentry auth login`
3. 認証状態を確認する: `sentry auth status`
- トークン全文をチャットに貼るよう求めてはならない。ローカルで設定し、準備ができたら知らせてもらう。

## 主な作業（Sentry CLI を使用）

すべての問い合わせに `sentry` CLI を使う。認証、組織・プロジェクトの検出、ページ分割、再試行を自動で処理する。機械処理可能な出力には `--json` を使う。

### 1) 課題の一覧（新しい順）

```bash
sentry issue list \
  --query "is:unresolved environment:production" \
  --period 24h \
  --limit 20 \
  --json --fields shortId,title,priority,level,status
```

自動検出で組織とプロジェクトが決まらなければ、明示的に渡す。
```bash
sentry issue list {your-org}/{your-project} \
  --query "is:unresolved environment:production" \
  --period 24h \
  --limit 20 \
  --json
```

### 2) 課題の短縮 ID から詳細を取得する

```bash
sentry issue view {ABC-123} --json
```

数値 ID ではなく短縮 ID 形式（例: `ABC-123`）を使う。

### 3) 課題の詳細

```bash
sentry issue view {ABC-123}
```

### 4) 課題のイベント

```bash
sentry issue events {ABC-123} --limit 20 --json
```

### 5) イベントの詳細

```bash
sentry event view {your-org}/{your-project}/{event_id} --json
```

### 6) AI による根本原因の分析

```bash
sentry issue explain {ABC-123}
```

### 7) AI による修正計画

```bash
sentry issue plan {ABC-123}
```

## 代替手段: 任意の API へのアクセス

専用の CLI コマンドがないエンドポイントには `sentry api` を使う。
```bash
sentry api /api/0/organizations/{your-org}/ --method GET
```

利用可能な API エンドポイントは `sentry schema` で調べる。
```bash
sentry schema issues
```

## 入力と既定値

- `org_slug`, `project_slug`: CLI が DSN、環境変数、ディレクトリ名から自動検出する。失敗したら位置引数 `{your-org}/{your-project}` で指定する。
- `time_range`: 既定値は `24h`（`--period 24h` として渡す）。
- `environment`: 既定値は `prod`（例: `environment:production` のように `--query` に含める）。
- `limit`: 既定値は 20（`--limit` で渡す）。
- `search_query`: 任意の `--query` パラメーター。Sentry の検索構文を使う（例: `is:unresolved`、`assigned:me`）。
- `issue_short_id`: `sentry issue view` に直接渡す。

## 出力形式の規則

- 課題一覧: title、short_id、status、first_seen、last_seen、count、environments、top_tags を新しい順に示す。
- イベント詳細: culprit、timestamp、environment、release、url を含める。
- 結果がない場合は明示する。
- 出力中の個人情報（メールアドレス、IP アドレス）を伏せる。生のスタックトレースを表示しない。
- 認証トークンを決して出力しない。

## 基準テストの入力

- 組織: `{your-org}`
- プロジェクト: `{your-project}`
- 課題の短縮 ID: `{ABC-123}`

依頼の例: 「過去24時間の本番環境で、未解決の課題を上位10件挙げて」
期待される結果: タイトル、短縮 ID、件数、最終発生日時を含む順位付き一覧。
