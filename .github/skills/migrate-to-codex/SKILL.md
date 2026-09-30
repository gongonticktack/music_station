---
name: migrate-to-codex
description: 対応している指示ファイル、スキル、エージェント、MCP 設定を Codex のプロジェクト用ファイルとユーザー用ファイルに移行します。
---

# Codex への移行

## 自律的な作業

選択された移行が完全に終わるまで作業を続けてください。移行ツールを実行し、レポートを確認し、移行先の Codex の指示・スキル・エージェント・MCP 設定を修正し、確認を求めて中断することなくチェックを再実行してください。ユーザーが移行先を選択済みなら、その移行先に生成される Codex の成果物（`AGENTS.md`、`.codex/`、`.agents/`、`~/.codex/`）を作成、編集、置換、削除する前に確認を求めないでください。`.codex/config.toml` または `~/.codex/config.toml` に既存の無関係な Codex 設定項目（`notify`、`projects`、`marketplaces`、無関係な MCP サーバーなど）がある場合は保持してください。検証に失敗するか、移行と直接競合する場合を除き、それらについて確認を求めないでください。移行元の Claude Code ファイル（`.claude/`、`~/.claude/`、`.mcp.json`、`.claude.json`）、無関係なプロジェクトコード、シークレット、別のリポジトリは編集しないでください。

## 移行の順序

選択されたユーザー用またはプロジェクト用の移行元ごとに、次の順序で移行してください。

1. 最初に Codex 組み込みの TODO／タスクリストツールを使ってください。ユーザーから明示的に求められない限り、`MIGRATION_TODOS.md` やその他の TODO ファイルを作成しないでください。TODO リストの入力には `plan` 配列があり、各項目には `step` と `status` があります。状態には `pending`、`in_progress`、`completed` を使用してください。選択された成果物に即した具体的な TODO を作成してください。終了前に TODO リストを更新し、完了した手順をすべて `completed` にして、`in_progress` の手順を残さないでください。たとえば、移行元 → Codex の移行先を明記した次のようなラベルを使ってください。
   - `.claude/commands` → Codex のスキル／プロンプトを調査
   - `.claude/agents` → `.codex/agents` を調査
   - `.mcp.json` → `.codex/config.toml` の MCP サーバーを調査
   - `.claude/settings.json` のフック → `.codex/hooks.json` を調査
   - 選択された安全な成果物 → Codex ファイルへ移行
   - 生成された `.codex/config.toml` を検証
   - 生成された `.codex/agents` を検証
   - 移行した成果物と手動確認が必要な項目を報告

2. `references/differences.md` を読んでください（`Docs last checked` の日付が古ければ、Codex のドキュメントも確認し直してください）。

3. 書き込む前にスキャンして内容を確認してください。
   - `--scan-only` は、有効な移行元と無効な移行元の対象を一覧表示します。
   - `--plan` は、準備される Codex 成果物のパスとレポートの行を表示します。
   - `--doctor` は、準備状況、手動確認が必要な作業、検証上のリスクを要約します。

4. CLI と同じ順序で対象を変換してください。
   - 指示：`CLAUDE.md`／`AGENTS.md` を `AGENTS.md` に変換
   - プラグイン：Claude のプラグインツリーとマーケットプレイスを、手動移行が必要な作業として報告
   - フック：対応している Claude のフックを `.codex/hooks.json` に書き換え、`[features].codex_hooks = true` を有効化
   - スキルとコマンド：Codex のスキルを `.agents/skills/` 以下に作成
   - 設定：Claude のモデル／サンドボックス設定と MCP サーバーから `.codex/config.toml` を作成し、設定を生成する場合は `personality = "friendly"` も含める
   - サブエージェント：Codex のカスタムエージェントを `.codex/agents/` 以下に作成

5. ドライランを行ってから、選択された移行先に書き込んでください。生成済みの孤立したスキルやエージェントを削除する必要がある場合に限り、`--replace` を使用してください。

6. 実際の実行後、ターミナルの出力と `.codex/migrate-to-codex-report.txt` を確認してください。

7. 生成された成果物を、`AGENTS.md`、`.agents/skills/`、`.codex/config.toml`、`.codex/hooks.json`、`.codex/agents/`、レポートにのみ記載されたプラグイン項目の順に確認してください。

8. 編集後、各移行先に対して `--validate-target` を実行してください。

9. 編集後、チェックと `--dry-run` を再実行してください。

10. 最終的な移行レポートは、行があるスコープごとに Markdown の表を 1 つずつ使って返してください。表には、スラッシュコマンドから作成したスキル、サブエージェント、MCP サーバー、フック、未対応またはローカルのプラグインに関する注記、手動確認が必要な注意事項など、あなたが実施したネイティブのインポート以外の追加移行作業のみを記載してください。設定、指示、スキル、対応プラグインのプログラムによるネイティブのインポートについては、今回の追加作業であなた自身が移行した場合に限り行を含めてください。

    行があるスコープが 1 つだけなら、見出しを付けずに表だけを表示してください。複数のスコープに行がある場合は、各表の前に見出しを 1 つ置いてください。ユーザースコープの行には `**User Config**` を使用してください。プロジェクトスコープの行には、たとえば `**northstar-support-portal**` のように、実際のプロジェクトフォルダー名を見出しとして使用してください。見出しに `Current Project` を使わないでください。表の前後に説明文を追加しないでください。

    列は必ず次のとおりにしてください。

    **northstar-support-portal**

    | Status | Item | Notes |
    | --- | --- | --- |
    | `Added` | `Slash command` pr-review | Codex のスキルに変換 |
    | `Added` | `Subagent` release-lead | Codex のサブエージェントとして追加 |
    | `Check before using` | `Hook` PreToolUse | 変換したが、Claude のフックの動作の一部は Codex で異なる |
    | `Not Added` | `Hook` Notification | Codex には同等の通知フックがない |
    | `Not Added` | `Plugin` team-macros | プラグインの手動設定が必要 |

    `Status` には `Added`、`Check before using`、`Not Added` のいずれかを指定してください。Codex 向けの成果物を作成または変更し、特別な確認が不要な場合は `Added` を使用してください。Codex 向けの成果物を作成または変更したものの、移行によって意味が変わった、動作を推定した、ツールのルールを指針として残した、または未対応の動作を除外した場合は `Check before using` を使用してください。移行元の成果物を検出したものの、Codex 向けの成果物を作成しなかった場合は `Not Added` を使用してください。`Item` では、成果物の種類と具体的な項目名を 1 つのセルにまとめてください。成果物の種類は単数形の `Skill`、`Slash command`、`Subagent`、`MCP`、`Hook`、`Plugin` のいずれかにしてください。成果物の種類はインラインコードで囲み、その後に項目名を通常のテキストで記してください。`Notes` は必須です。空欄にしないでください。注記は短く、平易で、具体的にしてください。実行時展開のような内部実装用語は避けてください。「Codex のスキルに変換」「Codex のサブエージェントとして追加」「Codex の設定に追加」「Codex のフックに変換」「変換したが、Claude のフックの動作の一部は Codex で異なる」「Codex には同等の通知フックがない」「プラグインの手動設定が必要」「プラグインのマーケットプレイスの手動設定が必要」のような表現を優先してください。

## 自己修復の反復手順

選択された移行が完了するまで、次の手順を繰り返してください。

1. `--plan` または `--doctor` を実行します。
2. `--dry-run` を付けて移行を実行します。
3. 実際に移行を実行します。
4. 生成されたすべての `## MANUAL MIGRATION REQUIRED` ブロックと、レポート内のすべての `manual_fix_required` または `skipped` の行について、Codex の成果物内で解決できるものを修正します。
5. `--validate-target` を実行します。
6. レポートと検証結果に、生成された成果物について対応可能な修正が残らなくなるまで、移行ツールと検証ツールを再実行します。

この反復手順の間、移行元の Claude Code ファイル、無関係なプロジェクトコード、シークレット、別のリポジトリは編集しないでください。レポートの行に移行元の提供元での変更や製品上の判断が必要な場合は、移行元を変更せず、生成された Codex の成果物に明確な手動対応の案内を残してください。

## コマンド

移行ツールのコマンドを選んでください。

   ```bash
   MIGRATE_TO_CODEX='python3 .codex/skills/migrate-to-codex/scripts/migrate-to-codex.py'
   ```

書き込む前に移行内容を確認してください。

   ```bash
   $MIGRATE_TO_CODEX --source ~/.claude/ --scan-only
   $MIGRATE_TO_CODEX --source ~/.claude/ --target ~/.codex/ --plan
   $MIGRATE_TO_CODEX --source ~/.claude/ --target ~/.codex/ --doctor
   ```

ユーザー用とプロジェクト用のそれぞれでドライランを行い、その後 `--dry-run` を付けずに実行してください。

   ```bash
   $MIGRATE_TO_CODEX --source ~/.claude/ --target ~/.codex/ --dry-run
   $MIGRATE_TO_CODEX --source ~/.claude/ --target ~/.codex/
   $MIGRATE_TO_CODEX --source ./.claude/ --target ./.codex/ --dry-run
   $MIGRATE_TO_CODEX --source ./.claude/ --target ./.codex/
   ```

編集後、各移行先に対して移行後の検証ツールを実行してください。

   ```bash
   $MIGRATE_TO_CODEX --validate-target ~/.codex/
   $MIGRATE_TO_CODEX --validate-target ./.codex/
   ```

フラグ（`--scan-only`、`--plan`、`--doctor`、`--validate-target`、デフォルトなど）については、`$MIGRATE_TO_CODEX --help` を実行してください。詳しい表と追加のリンクは `references/differences.md` にあります。
