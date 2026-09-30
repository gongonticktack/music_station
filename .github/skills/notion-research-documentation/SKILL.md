---
name: notion-research-documentation
description: Notion全体を調査して構造化文書にまとめる。引用付きのブリーフ、比較資料、レポートを作成するために、複数のNotion情報源から情報を収集する際に使用する。
metadata:
  short-description: Notionの内容を調査し、ブリーフやレポートを作成する
---

# 調査と文書作成

関連するNotionページを取得し、調査結果をまとめ、情報源への引用とリンクを添えた明確なブリーフやレポートを公開します。

## クイックスタート
1) `Notion:notion-search`で絞り込んだクエリを使って情報源を探し、対象範囲をユーザーに確認します。
2) `Notion:notion-fetch`でページを取得し、主要なセクションを確認して、引用情報を記録します（`reference/citations.md`）。
3) `reference/format-selection-guide.md`を使って出力形式（ブリーフ、サマリー、比較資料、包括的なレポート）を選びます。
4) 対応するテンプレート（クイック、サマリー、比較、包括的）を使い、`Notion:notion-create-pages`でNotion上に草案を作成します。
5) 情報源へのリンクと参照・引用セクションを追加し、新しい情報が入ったら`Notion:notion-update-page`で更新します。

## ワークフロー
### 0) Notion MCPへの接続が原因でMCP呼び出しに失敗した場合は、いったん停止してセットアップします:
1. Notion MCPを追加します:
   - `codex mcp add notion --url https://mcp.notion.com/mcp`
2. リモートMCPクライアントを有効にします:
   - `[features].rmcp_client = true`の`config.toml`を設定するか、`codex --enable rmcp_client`を実行します。
3. OAuthでログインします:
   - `codex mcp login notion`

ログインに成功した後、ユーザーはcodexを再起動する必要があります。その場合は回答を完了し、再試行時にステップ1から続行できることを伝えてください。

### 1) 情報源を集める
- まず検索し（`Notion:notion-search`）、クエリを調整します。複数の結果がある場合は、ユーザーに確認します。
- 関連ページ（`Notion:notion-fetch`）を取得し、事実、指標、主張、制約、日付を確認します。
- 後で引用できるよう、各情報源のURLまたはIDを記録します。重要な事実には直接引用を優先します。

### 2) 形式を選ぶ
- 手早い報告 → クイックブリーフ。
- 1つのテーマを掘り下げる → 調査サマリー。
- 選択肢の比較検討 → 比較資料。
- 詳細な調査／経営幹部向け資料 → 包括的なレポート。
- 形式の選び方については`reference/format-selection-guide.md`を参照してください。

### 3) 統合する
- 執筆前に概要を作り、調査結果をテーマや問いごとにまとめます。
- 情報源IDとともに根拠を記録し、情報の欠落や矛盾があれば明示します。
- 意思決定、要約、計画、提言など、ユーザーの目的を意識します。

### 4) 文書を作成する
- `reference/`にある対応テンプレート（ブリーフ、サマリー、比較資料、包括的なレポート）を選び、必要に応じて調整します。
- `Notion:notion-create-pages`でページを作成し、タイトル、要約、主な調査結果、裏付けとなる根拠、該当する場合は提言や次のステップを含めます。
- 本文中に引用を追加し、参照セクションを設けて、情報源のページにリンクします。

### 5) 最終確認と引き継ぎ
- 主なポイント、リスク、未解決の問いを追加します。
- ユーザーにフォローアップが必要な場合は、ページにタスクまたはチェックリストを作成します。該当する場合は、タスクデータベースのエントリにリンクします。
- 更新時は`Notion:notion-update-page`を使い、簡単な変更履歴またはステータスを記載します。

## 参考資料と例
- `reference/` — 検索方法、形式の選び方、テンプレート、引用ルール（例: `advanced-search.md`、`format-selection-guide.md`、`research-summary-template.md`、`comparison-template.md`、`citations.md`）。
- `examples/` — 最初から最後までの手順例（例: `competitor-analysis.md`、`technical-investigation.md`、`market-research.md`、`trip-planning.md`）。
