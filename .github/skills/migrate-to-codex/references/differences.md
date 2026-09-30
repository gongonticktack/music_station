# 移行時の相違点

## 概要

このリファレンスは、Claude Code から Codex への移行のみを扱います。移行時の相違点、部分的な対応関係、サポートされていない Claude Code の動作を一覧にしています。直接的な 1 対 1 の対応関係は意図的に省いています。コンバーターが Claude 固有の動作をプロンプトの指針として残す場合は、`manual_fix_required` のレポート行を出力し、生成ファイルに `## MANUAL MIGRATION REQUIRED` ブロックを書き込みます。

ドキュメントの最終確認日: 2026-04-20。今日の日付がこれより後の場合は、これらの対応関係を信頼する前に、以下の Codex 公式ドキュメントと Claude Code のドキュメントマップを再確認してください。

## 指示ファイル

| 移行元 | Codex | 移行時の処理 | 注意点 |
| --- | --- | --- | --- |
| `.claude/CLAUDE.md`、`CLAUDE.md`、または `claude.md` | `AGENTS.md` シンボリックリンク | 内容が特定のプロバイダーに依存しないと判断された場合、自動的にリンクします | ドキュメントを複製せず、指示の本文を一つだけ共有します。 |
| ルートの `AGENTS.md` | ルートの `AGENTS.md` | 有効なファイルとして報告します | コンバーターは対象ファイルを上書きしたり、そのファイル自身へのシンボリックリンクに置き換えたりしません。 |
| `/hooks`、`.claude/agents/`、設定ファイルのパス、サブエージェントに関する記述、または権限モードに関する前提を含む指示 | 生成された `AGENTS.md` のコピー | 手動で書き直します | 明らかに Claude 固有の動作について Codex 向けの編集が必要な場合、コンバーターは意図的にシンボリックリンクを作らず、コピーを生成します。 |

## コマンド

| 移行元 | Codex | 移行時の処理 | 注意点 |
| --- | --- | --- | --- |
| `.claude/commands/*.md` | `.agents/skills/source-command-<name>/SKILL.md` | 単一ファイルの Codex スキルに変換します | スラッシュコマンドとしての呼び出し、`argument-hint`、`allowed-tools`、`$ARGUMENTS`、シェル出力の展開、ファイル参照の展開は、手動確認が必要なテキストとして残します。 |
| 実行時の展開を含むコマンドファイル | 単一ファイルの Codex スキルと `manual_fix_required` 行 | プロンプトのテキストとして残します | 引数のプレースホルダー、シェル出力の展開、ファイルの自動展開、モデルやエージェントへの振り分け、実行可能なフックの動作は、実行時の挙動が異なるため手動で確認する必要があります。 |

## スキル

| 移行元 | Codex | 移行時の処理 | 注意点 |
| --- | --- | --- | --- |
| `.claude/skills/<name>/SKILL.md` | `.agents/skills/<name>/SKILL.md` | 変換し、一部の補助ディレクトリをコピーします | スキル内の `scripts/`、`references/`、`assets/` は、移行元スキルのルート配下に実ファイルとして存在する場合にコピーします。 |
| `.claude/skills/<name>.md` | `.agents/skills/<name>/SKILL.md` | 単一ファイルのスキルに変換します | この旧形式では、隣接する補助ディレクトリはコピーしません。 |
| `allowed-tools` | スキルに対する厳格な許可リストはありません | `SKILL.md` にプロンプトの指針として残します | `agents/openai.yaml` でツールへの依存関係を宣言できますが、これは権限の境界ではありません。 |
| `user-invocable` | `policy.allow_implicit_invocation` | 手動確認のみ | 意図は似ていますが、動作は同等ではありません。 |
| `model` / `effort` | スキル単位でモデルを固定する機能はありません | サポート対象外 | このコンバーターでは、Codex のモデル選択はセッションまたはエージェント単位で行います。 |
| `disable-model-invocation` | 直接対応する機能はありません | サポート対象外 | 移行元のスキルがこの動作に依存している場合は、手動で書き直す必要があります。 |
| `argument-hint` / `context` / `agent` / `hooks` / `paths` / `shell` | 直接対応する機能はありません | サポート対象外 | 動作をプロンプトの指針や設定に書き換えられる場合にのみ残してください。 |

## MCP と設定

| 移行元 | Codex | 移行時の処理 | 注意点 |
| --- | --- | --- | --- |
| `.mcp.json` または `.claude.json` の `mcpServers` | `.codex/config.toml` の `[mcp_servers.<name>]` | 変換します | この移行ツールでは、プロジェクトの `.mcp.json` とグローバルの `.claude.json` を同じ移行元形式として扱います。Codex は `cwd`、`enabled_tools`、`disabled_tools`、タイムアウト設定など、追加の MCP サーバーフィールドにも対応していますが、このコンバーターが書き込むのは、Claude の移行元設定から明確に対応付けられるフィールドだけです。 |
| Claude Code のモデル設定、サンドボックス設定、または MCP 設定 | `personality = "friendly"` | 移行ツールが `.codex/config.toml` を生成する際に書き込みます | Codex は `none`、`friendly`、`pragmatic` に対応しています。Claude Code からの移行では、親しみやすいアシスタントの話し方を保つため、既定値を friendly にします。 |
| `type: sse` | SSE はサポートされていません | サポート対象外 | 現行のドキュメントでは、Codex は stdio とストリーミング HTTP に対応しています。 |
| `headers.Authorization: Bearer ${VAR}` | `bearer_token_env_var` | 認証設定を直接書き換えます | この方法で書き換えるのは Bearer トークン形式だけです。`${VAR:-default}` のフォールバックは保持されません。 |
| `${VAR}` を含む `headers` | `env_http_headers` | 部分的に対応付けます | 固定値のヘッダーは `http_headers` に対応付けます。`${VAR:-default}` のフォールバックは保持されません。 |
| `${VAR}` を含む `env` | `env_vars` | 部分的に対応付けます | リテラル値は `env` に残し、自身を参照する値は `env_vars` に変換します。`${VAR:-default}` のフォールバックは保持されません。 |
| `oauth.callbackPort` | `mcp_oauth_callback_port` | 手動確認のみ | `oauth.clientId`、`oauth.authServerMetadataUrl`、`headersHelper` はサポート対象外です。 |
| `enabledMcpjsonServers` / `disabledMcpjsonServers` | サーバーごとの `enabled` | 部分的に対応付けます | このコンバーターには、`enableAllProjectMcpServers` に直接対応する機能はありません。 |
| `allowedMcpServers` / `deniedMcpServers` | `requirements.toml` | ポリシーを手動で対応付けます | このコンバーターでは書き込みません。 |
| `.claude/settings.local.json` | ローカル専用の Codex の相当機能はありません | サポート対象外 | Codex のプロジェクト設定は、信頼済みプロジェクトの動作と結び付いています。 |

## サブエージェント

| 移行元 | Codex | 移行時の処理 | 注意点 |
| --- | --- | --- | --- |
| `.claude/agents/*.md` | `.codex/agents/*.toml` | 変換します | `name` または `description` がない場合は推定し、確認が必要な項目として報告します。 |
| `tools` / `disallowedTools` | 移行元と同様の細かいエージェント権限はありません | `developer_instructions` にプロンプトの指針として残します | 意図が明確な場合は、`sandbox_mode`、`[permissions]`、MCP ツールフィルター、またはアプリのツールフィルターを手動で使用してください。 |
| `skills` | 起動時にスキルを事前読み込みする相当機能はありません | `developer_instructions` にプロンプトの指針として残します | `skills.config` は有効化と無効化の設定であり、事前読み込みの動作ではありません。 |
| `mcpServers` | Codex カスタムエージェントの `mcp_servers` または共有の Codex MCP 設定 | 手動確認のみ | Codex のカスタムエージェントファイルには MCP 設定を含められますが、このコンバーターは Claude サブエージェントの `mcpServers` を自動的には対応付けません。移行元の意図が明確な場合は、共有の Codex MCP 設定を使うか、エージェント固有の `mcp_servers` を手動で追加してください。 |
| `permissionMode` | `sandbox_mode` | 部分的に対応付けます | 対応付けるのは `acceptEdits` と `readOnly` のみです。`default`、`dontAsk`、`bypassPermissions`、`plan` は、手動確認が必要なプロンプトの指針として残します。 |
| `model` + `effort` | `model` + `model_reasoning_effort` | モデルファミリーに応じて部分的に対応付けます | コーディングエージェントとしての動作を考慮し、Sonnet ファミリーの推論レベルは 1 段階高めに設定します。移行元の `max` は Codex の `xhigh` に対応付けます。 |
| `hooks` / `memory` / `background` / `isolation` / `maxTurns` | 直接対応する機能はありません | サポート対象外 | フォアグラウンドとバックグラウンドでの実行、および再開の動作は、Codex のカスタムエージェントファイルにそのまま対応付けられません。 |
| `initialPrompt` | 直接対応する機能はありません | サポート対象外 | エージェントが Claude セッションのメインエージェントとして実行される場合にのみ適用されます。 |
| `description` に基づく自動委任 | Codex サブエージェントの自動または明示的な起動 | 動作が変わります | 1 対 1 の対応ではありません。生成されたエージェントの説明を手動で確認してください。 |
| エージェントごとの独立した権限 | 親のサンドボックスの継承と実行時の上書き | 動作が変わります | Codex のカスタムエージェントファイルは既定値を設定しますが、親のターンから厳密に分離するものではありません。 |

## プラグインマーケットプレイス

| 移行元 | Codex | 移行時の処理 | 注意点 |
| --- | --- | --- | --- |
| `.claude/plugins/` | Codex のプラグイン / スキル / MCP サーバー / アプリ | `manual_fix_required` として報告するだけです | Codex のプラグインにはスキル、MCP サーバー、アプリを同梱できますが、移行ツールはプラグインのディレクトリツリーをコピーしません。プラグインと、同梱されたスキル、コマンド、エージェント、フック、MCP 設定は手動で移行してください。 |
| `.claude/plugin-marketplaces.json` | Codex プラグインのインストールまたはローカルプラグインのパス | `manual_fix_required` として報告するだけです | マーケットプレイスのエントリは、ローカルまたはリモートのプラグインを指す場合があります。移行ツールは取得もインストールもしません。Codex のマーケットプレイスのメタデータは `.agents/plugins/marketplace.json` または `~/.agents/plugins/marketplace.json` に置かれます。 |
| `.claude-plugin/marketplace.json` | Codex プラグインのインストールまたはローカルプラグインのパス | `manual_fix_required` として報告するだけです | マーケットプレイスの移行元資料として扱ってください。旧形式のマーケットプレイスとして Codex にコピーしないでください。ローカルに残す場合は、Codex のプラグインマーケットプレイスの構成に合わせてください。 |
| `metadata.pluginRoot` | 直接対応する機能はありません | サポート対象外 | `metadata.pluginRoot` に依存するプラグイン参照の省略形は、手動でディレクトリ構成を整える必要があります。 |
| マーケットプレイスまたは `plugin.json` にあるカスタムの `skills` / `agents` パス | Codex プラグインのマニフェストと同梱スキルのパス | 手動確認のみ | Codex のプラグインでは、同梱するスキル、MCP サーバー、アプリを宣言できます。Claude プラグインのカスタムパスについては、引き続きディレクトリ構成を手動で確認する必要があります。自動スキャンは行いません。 |
| プラグインの `commands/` | `.agents/skills/<name>/SKILL.md` | 手動で移行します | ファイルを手動でコピーする場合は、ほかのコマンド移行と同様に扱ってください。 |
| `strict`、`hooks`、`mcpServers`、`lspServers`、`outputStyles` | 直接対応する機能はありません | サポート対象外 | プラグイン設定は自動的に取り込みません。 |

## フック

| 移行元 | Codex | 移行時の処理 | 注意点 |
| --- | --- | --- | --- |
| `~/.claude/settings.json`、`.claude/settings.json`、または `.claude/settings.local.json` の `hooks` | `.codex/hooks.json` + `[features].codex_hooks = true` | 部分的に変換します | 移行したフックに依存する前に動作を確認してください。Claude と Codex のフックの実行環境は 1 対 1 で対応していません。 |
| `Notification` | `notify` | 手動での書き換えのみ | `notify` はターン完了時に通知するコマンドであり、一般的なライフサイクルフックや承認要求時のフックではありません。 |
| `PreToolUse` | `.codex/hooks.json` の `PreToolUse` | 部分的に変換します | 現在の Codex では、PreToolUse はシェルコマンドに対してのみ実行され、`permissionDecision: "deny"`、旧形式の `decision: "block"`、または終了コード `2` の場合にのみブロックします。 |
| `PostToolUse` | `.codex/hooks.json` の `PostToolUse` | 部分的に変換します | 現在の Codex では、PostToolUse はシェルコマンドに対してのみ実行されます。`decision: "block"` はモデルへのフィードバックとなり、`continue: false` は実行を停止します。Claude が `Edit` / `Write` に結び付けていた整形や修正処理は、`Stop` フックに移してください。`PostToolUse` では Bash のみがマッチするためです。 |
| `UserPromptSubmit` | `.codex/hooks.json` の `UserPromptSubmit` | 部分的に変換します | Codex はコンテキストを挿入したり、プロンプトをブロックしたりできますが、このイベントでは `matcher` を無視し、移行元の `if` フィルターには対応していません。 |
| `SessionStart` | `.codex/hooks.json` の `SessionStart` | 部分的に変換します | Codex では `startup` と `resume` がマッチします。Claude には、そのほかのセッションの流れもある場合があります。 |
| `Stop` | `.codex/hooks.json` の `Stop` | 部分的に変換します | Codex は Stop に対する `matcher` を無視し、継続用のプロンプトを要求できますが、移行元のサブエージェントやチームメイトの停止に関するライフサイクルをすべて公開しているわけではありません。 |
| `PermissionRequest` / `SubagentStart` / `SubagentStop` / `TaskCreated` / `TaskCompleted` / `StopFailure` / `PreCompact` / `PostCompact` / `SessionEnd` | 直接対応する機能はありません | サポート対象外 | 手動で対応する項目として残してください。現在の Codex には、対応するライフサイクルイベントがありません。 |
| `type: "command"` | `type: "command"` | 部分的に変換します | `command`、`timeout` / `timeoutSec`、`statusMessage` が対応付けられます。空のコマンドは Codex によってスキップされます。 |
| `type: "prompt"` / `type: "agent"` / `type: "http"` / `async: true` | 直接対応する機能はありません | サポート対象外 | Codex は `prompt` / `agent` を解析しますが実行せず、非同期フックもスキップします。HTTP フックにはラッパーコマンドが必要です。 |
| フックの `matcher` と `if` フィルター | 正規表現の `matcher` のみ | 部分的に変換します | Codex が正規表現の `matcher` を保持するのは、`PreToolUse`、`PostToolUse`、`SessionStart` に対してのみです。移行元の `if` フィルターは対応付けられません。 |
| スキル、エージェント、プラグイン内のフック | 直接対応する機能はありません | サポート対象外 | Codex は設定レイヤーからフックを検出します。スキルやサブエージェントのマニフェストからは検出しません。 |

## 計画と検証

| コマンド | 動作 | 注意点 |
| --- | --- | --- |
| `--plan` | ファイルを書き込まずに、準備された移行結果と生成物のパスを表示します | 選択した移行元、移行先、コンポーネントのフラグには引き続き依存します。 |
| `--doctor` | ファイルを書き込まずに、移行の準備状況、リスクの件数、手動確認が必要な項目を表示する | 静的なガイダンスのみを提供する。移行後の設定が動作することを証明するものではない。 |
| `--validate-target` | 移行済みの Codex ターゲットを検証する | TOML を解析できるか、スキルのフロントマター、カスタムエージェントの TOML フィールド、AGENTS.md のサイズ、MCP コマンドを利用できるかを確認する。 |

## 最小限の例

移行元のスキルのメタデータは、プロンプト内のガイダンスになる。

```md
allowed-tools:
  - Read
  - Bash
```

```md
## MANUAL MIGRATION REQUIRED

Claude `allowed-tools` was preserved as prompt guidance, not a Codex permission boundary.

You're allowed to use these tools:

- Read
- Bash
```

移行元のサブエージェントのメタデータは、TOML とプロンプト内のガイダンスになる。

```md
skills:
  - release-notes
tools:
  - Read
disallowedTools:
  - Bash
```

```toml
sandbox_mode = "workspace-write"
developer_instructions = """
## Skills
- $release-notes

## Tools
You're allowed to use these tools:
- Read

Don't use these tools:
- Bash
"""
```

## 出典

- https://docs.claude.com/en/docs/claude-code/claude_code_docs_map
- https://developers.openai.com/codex/config-reference
- https://developers.openai.com/codex/mcp
- https://developers.openai.com/codex/plugins/
- https://developers.openai.com/codex/plugins/build/
- https://developers.openai.com/codex/skills
- https://developers.openai.com/codex/subagents
- https://developers.openai.com/codex/hooks
- https://code.claude.com/docs/en/skills
- https://code.claude.com/docs/en/sub-agents
- https://code.claude.com/docs/en/hooks
- https://code.claude.com/docs/en/hooks-guide
- https://code.claude.com/docs/en/mcp
- https://code.claude.com/docs/en/settings
- https://code.claude.com/docs/en/plugins
- https://code.claude.com/docs/en/plugin-marketplaces
