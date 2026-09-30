---
name: notion-spec-to-implementation
description: Notionの仕様書を実装計画、タスク、進捗管理に変換します。PRDや機能仕様を実装する場合や、それらを基にNotionの計画とタスクを作成する場合に使用します。
metadata:
  short-description: Notionの仕様書を実装計画、タスク、進捗管理に変換します
---

# 仕様から実装へ

Notionの仕様書を、相互にリンクされた実装計画、タスク、継続的なステータス更新に変換します。

## クイックスタート
1) `Notion:notion-search` で仕様書を探し、`Notion:notion-fetch` で取得します。
2) `reference/spec-parsing.md` を使って要件と曖昧な点を整理します。
3) `Notion:notion-create-pages` で計画ページを作成します（テンプレートは簡易版または完全版を選択）。
4) タスクデータベースを見つけ、スキーマを確認してから、`Notion:notion-create-pages` でタスクを作成します。
5) 仕様書 ↔ 計画 ↔ タスクをリンクし、`Notion:notion-update-page` でステータスを最新に保ちます。

## ワークフロー

### 0) Notion MCPが接続されていないためにMCP呼び出しが失敗した場合は、一時停止してセットアップします。
1. Notion MCPを追加します。
   - `codex mcp add notion --url https://mcp.notion.com/mcp`
2. リモートMCPクライアントを有効にします。
   - `[features].rmcp_client = true` の `config.toml` を設定するか、`codex --enable rmcp_client` を実行します。
3. OAuthでログインします。
   - `codex mcp login notion`

ログインに成功した後、ユーザーはCodexを再起動する必要があります。その旨を伝えて回答を終え、再試行時にはステップ1から続行できるようにします。

### 1) 仕様書を見つけて読む
- まず検索します（`Notion:notion-search`）。複数の候補が見つかった場合は、どれを使うかユーザーに尋ねます。
- ページを取得し（`Notion:notion-fetch`）、要件、受け入れ条件、制約、優先度を確認します。抽出パターンは `reference/spec-parsing.md` を参照してください。
- 不足情報や前提事項を、作業を進める前に確認事項ブロックへ記録します。

### 2) 計画の詳細度を選ぶ
- 簡単な変更 → `reference/quick-implementation-plan.md` を使います。
- 複数フェーズにわたる機能・移行 → `reference/standard-implementation-plan.md` を使います。
- `Notion:notion-create-pages` で計画を作成し、概要、リンクされた仕様書、要件の要約、フェーズ、依存関係・リスク、成功基準を含めます。仕様書へのリンクを設定します。

### 3) タスクを作成する
- タスクデータベースを見つけ（`Notion:notion-search` → `Notion:notion-fetch`）、データソースと必須プロパティを確認します。作成パターンは `reference/task-creation.md` を参照してください。
- タスクは1～2日で完了できるサイズにします。内容には `reference/task-creation-template.md` を使います（背景、目的、受け入れ条件、依存関係、リソース）。
- プロパティを設定します。タイトル・動作を表す語、ステータス、優先度、仕様書と計画への関連付けを設定し、提供されている場合は期限、ストーリーポイント、担当者も設定します。
- データベースの `Notion:notion-create-pages` を使って、`data_source_id` でページを作成します。

### 4) 成果物をリンクする
- 計画から仕様書へリンクし、タスクから計画と仕様書の両方へリンクします。
- 必要に応じて `Notion:notion-update-page` で仕様書を更新し、計画とタスクを示す簡単な「実装」セクションを追加します。

### 5) 進捗を管理する
- `reference/progress-tracking.md` の頻度に従います。
- `reference/progress-update-template.md` を使って更新を投稿し、フェーズの完了時には `reference/milestone-summary-template.md` を使います。
- 計画とタスクのチェックリストおよびステータス項目を同期し、ブロッカーと決定事項を記録します。

## 参考資料と例
- `reference/` — 解析パターン、計画・タスクのテンプレート、進捗管理の頻度（例: `spec-parsing.md`、`standard-implementation-plan.md`、`task-creation.md`、`progress-tracking.md`）。
- `examples/` — 最初から最後までの手順例（例: `ui-component.md`、`api-feature.md`、`database-migration.md`）。