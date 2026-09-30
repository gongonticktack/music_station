---
name: skill-installer
description: 厳選リストまたは GitHub リポジトリのパスから、Codex スキルを $CODEX_HOME/skills にインストールする。ユーザーがインストール可能なスキルの一覧、厳選スキルのインストール、または別のリポジトリ（非公開リポジトリを含む）からのインストールを求めたときに使用する。
metadata:
  short-description: openai/skills などのリポジトリから厳選スキルをインストール
---

# スキルインストーラー

スキルのインストールを支援する。既定の取得元は https://github.com/openai/skills/tree/main/skills/.curated だが、ユーザーが別の場所を指定することもできる。

依頼に応じて補助スクリプトを使う。

- 利用可能なスキルを尋ねられた場合、またはスキルの使用だけを指定されて具体的な作業がない場合は、一覧を表示する。既定の一覧は `.curated`。実験的なスキルを尋ねられた場合は `--path skills/.experimental` を渡す。
- スキル名が指定された場合は、厳選リストからインストールする。
- GitHub のリポジトリやパスが指定された場合は、そのリポジトリからインストールする。非公開リポジトリも対象となる。

インストールには補助スクリプトを使用する。

## ユーザーへの案内

一覧表示時は、依頼の文脈に応じておおむね次の形式で出力する。実験的なスキルを尋ねられた場合は、`.curated` の代わりに `.experimental` を表示し、取得元もそれに合わせて明記する。

"""
{repo} のスキル:
1. skill-1
2. skill-2（インストール済み）
3. ...
どれをインストールしますか？
"""

インストール後は、次のターンから利用できることをユーザーに伝える。

## スクリプト

これらのスクリプトはすべてネットワークを使用する。サンドボックス内で実行する場合は権限昇格を申請する。

- `scripts/list-skills.py`（インストール済みの注記付きで一覧を表示）
- `scripts/list-skills.py --format json`
- 例（実験的なスキル一覧）: `scripts/list-skills.py --path skills/.experimental`
- `scripts/install-skill-from-github.py --repo <owner>/<repo> --path <path/to/skill> [<path/to/skill> ...]`
- `scripts/install-skill-from-github.py --url https://github.com/<owner>/<repo>/tree/<ref>/<path>`
- 例（実験的なスキル）: `scripts/install-skill-from-github.py --repo openai/skills --path skills/.experimental/<skill-name>`

## 動作とオプション

- 公開 GitHub リポジトリには、既定で直接ダウンロードを使用する。
- 認証や権限のエラーでダウンロードに失敗した場合は、git sparse checkout に切り替える。
- インストール先のスキルディレクトリがすでに存在する場合は中止する。
- `$CODEX_HOME/skills/<skill-name>` にインストールする（既定は `~/.codex/skills`）。
- 複数の `--path` を指定すると、1回で複数のスキルをインストールする。`--name` を指定しない限り、各スキル名にはパスの末尾の名前を使う。
- オプション: `--ref <ref>`（既定は `main`）、`--dest <path>`、`--method auto|download|git`。

## 補足

- 厳選リストは GitHub API を介して `https://github.com/openai/skills/tree/main/skills/.curated` から取得する。利用できない場合はエラーを説明して終了する。
- 非公開 GitHub リポジトリには、既存の git 認証情報、またはダウンロード用の任意の `GITHUB_TOKEN` / `GH_TOKEN` を使用できる。
- git への切り替え時は、最初に HTTPS、次に SSH を試す。
- https://github.com/openai/skills/tree/main/skills/.system のスキルはプリインストールされている。ユーザーがインストールを求めた場合はその旨を説明する。強く希望する場合はダウンロードして上書きできる。
- インストール済みの注記は `$CODEX_HOME/skills` に基づく。
