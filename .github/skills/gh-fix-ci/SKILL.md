---
name: "gh-fix-ci"
description: "ユーザーが GitHub Actions で実行される GitHub PR チェックの失敗を調査・修正するよう求めた場合に使用する。`gh` でチェックとログを調べ、失敗の状況を要約して修正計画を作成し、明示的な承認を得てから実装する。Buildkite などの外部サービスは対象外とし、詳細 URL のみ報告する。"
---


# GitHub PR チェックの調査と修正計画

## 概要

gh で失敗した PR チェックを特定し、対応可能な失敗について GitHub Actions のログを取得する。失敗箇所を短く要約して修正計画を提案し、明示的な承認を得てから実装する。
- `create-plan` など計画用のスキルが利用できる場合は使う。利用できなければ簡潔な計画をその場で作成し、実装前に承認を求める。

前提条件: 標準の GitHub CLI で一度認証し（例: `gh auth login`）、`gh auth status` で確認する。通常、repo と workflow のスコープが必要となる。

## 入力

- `repo`: リポジトリ内のパス（既定値 `.`）
- `pr`: PR 番号または URL（省略可。既定値は現在のブランチの PR）
- リポジトリのホストに対する `gh` の認証

## クイックスタート

- `python "<path-to-skill>/scripts/inspect_pr_checks.py" --repo "." --pr "<number-or-url>"`
- 要約に使いやすい機械可読の出力が必要なら `--json` を追加する。

## 手順

1. gh の認証を確認する。
   - リポジトリで `gh auth status` を実行する。
   - 未認証なら、作業を進める前にユーザーへ `gh auth login` の実行を依頼する（repo と workflow のスコープを含める）。
2. PR を特定する。
   - 現在のブランチの PR を優先し、`gh pr view --json number,url` を使う。
   - ユーザーが PR 番号または URL を指定した場合は、その値を直接使う。
3. 失敗したチェックを調べる（GitHub Actions のみ）。
   - 推奨: 同梱スクリプトを実行する（gh のフィールド変更やジョブログ取得の代替手段に対応）。
     - `python "<path-to-skill>/scripts/inspect_pr_checks.py" --repo "." --pr "<number-or-url>"`
     - 機械可読の出力には `--json` を追加する。
   - 手動で調べる場合:
     - `gh pr checks <pr> --json name,state,bucket,link,startedAt,completedAt,workflow`
       - 指定したフィールドが拒否された場合は、`gh` が示す利用可能なフィールドで再実行する。
     - 失敗した各チェックについて、`detailsUrl` から実行 ID を取り出し、次を実行する。
       - `gh run view <run_id> --json name,workflowName,conclusion,status,url,event,headBranch,headSha`
       - `gh run view <run_id> --log`
     - 実行ログが処理中と表示されたら、ジョブログを直接取得する。
       - `gh api "/repos/<owner>/<repo>/actions/jobs/<job_id>/logs" > "<path>"`
4. GitHub Actions 以外のチェックを切り分ける。
   - `detailsUrl` が GitHub Actions の実行を指していなければ、外部チェックとして扱い URL のみ報告する。
   - Buildkite など別サービスは調査しない。
5. 失敗をユーザー向けに要約する。
   - 失敗したチェック名、実行 URL（ある場合）、ログの該当箇所を簡潔に示す。
   - ログが取得できない場合は明記する。
6. 計画を作成する。
   - `create-plan` スキルを使って簡潔な計画を作り、承認を求める。
7. 承認後に実装する。
   - 承認された計画を適用し、差分とテストを要約して、PR を開くか尋ねる。
8. 状態を再確認する。
   - 変更後、関連テストと `gh pr checks` の再実行を提案する。

## 同梱リソース

### scripts/inspect_pr_checks.py

失敗した PR チェックと GitHub Actions のログを取得し、失敗箇所を抽出する。失敗が残る場合はゼロ以外の終了コードを返すため、自動化にも利用できる。

使用例:
- `python "<path-to-skill>/scripts/inspect_pr_checks.py" --repo "." --pr "123"`
- `python "<path-to-skill>/scripts/inspect_pr_checks.py" --repo "." --pr "https://github.com/org/repo/pull/123" --json`
- `python "<path-to-skill>/scripts/inspect_pr_checks.py" --repo "." --max-lines 200 --context 40`
