---
name: notion-meeting-intelligence
description: Notionの情報とCodexによる調査を活用して会議資料を準備します。背景情報の収集、アジェンダや事前資料の作成、参加者に合わせた資料の調整に使用します。
metadata:
  short-description: Notionの情報を活用し、会議や参加者に合わせたアジェンダを準備
---

# 会議準備の知見

Notionの情報を収集し、アジェンダや事前資料を参加者に合わせて調整し、Codexの調査で内容を充実させて会議を準備します。

## クイックスタート
1) 会議の目的、参加者、日時、必要な意思決定を確認します。
2) 背景情報を集めます：`Notion:notion-search`で検索し、`Notion:notion-fetch`で取得します（過去のメモ、仕様書、OKR、決定事項）。
3) `reference/template-selection-guide.md`を参照して適切なテンプレートを選びます（状況報告、意思決定、計画、振り返り、1対1、ブレインストーミング）。
4) `Notion:notion-create-pages`を使って、出典リンクと担当者・時間枠を含むアジェンダや事前資料をNotionに作成します。
5) Codexの調査（業界の知見、ベンチマーク、リスク）で内容を充実させ、計画の変更に応じて`Notion:notion-update-page`でページを更新します。

## ワークフロー
### 0) Notion MCPが未接続のためにMCP呼び出しが失敗した場合は、作業を一時停止してセットアップします。
1. Notion MCPを追加します。
   - `codex mcp add notion --url https://mcp.notion.com/mcp`
2. リモートMCPクライアントを有効にします。
   - `[features].rmcp_client = true`で`config.toml`を設定するか、`codex --enable rmcp_client`を実行します。
3. OAuthでログインします。
   - `codex mcp login notion`

ログインが成功したら、ユーザーはcodexを再起動する必要があります。回答を完了し、再度試す際にステップ1から続行できることを伝えてください。

### 1) 入力情報を集める
- 目的、望ましい成果や決定事項、参加者、所要時間、日時、既存資料を確認します。
- Notionで関連文書、過去のメモ、仕様書、アクション項目を検索し（`Notion:notion-search`）、重要なページを取得します（`Notion:notion-fetch`）。
- 障害要因やリスク、未解決の質問を最初に洗い出します。

### 2) 形式を選ぶ
- 状況報告／進捗共有 → 状況報告テンプレート。
- 意思決定／承認 → 意思決定テンプレート。
- 計画（スプリント／プロジェクト） → 計画テンプレート。
- 振り返り／フィードバック → 振り返りテンプレート。
- 1対1 → 1対1テンプレート。
- アイデア出し → ブレインストーミングテンプレート。
- `reference/template-selection-guide.md`を使って確認します。

### 3) アジェンダや事前資料を作成する
- `reference/`にある選択したテンプレートを基に、各セクション（背景、目標、アジェンダ、各項目の担当者と所要時間、決定事項、リスク、事前準備の依頼）を調整します。
- 取得したNotionページや、事前に読む必要のある資料へのリンクを含めます。
- 各アジェンダ項目の担当者を割り当て、時間枠と期待する成果を明記します。

### 4) 調査で内容を充実させる
- 有用な場合は、簡潔なCodexの調査結果を加えます：市場や業界の事実、ベンチマーク、リスク、ベストプラクティス。
- 主張には出典リンクを付け、事実と意見を分けます。

### 5) 仕上げて共有する
- 次のステップとフォローアップの担当者を追加します。
- タスクが発生した場合は、該当するNotionデータベースに作成またはリンクします。
- 詳細が変わったら`Notion:notion-update-page`でページを更新します。複数回編集する場合は、簡単な変更履歴を残します。

## 参考資料と例
- `reference/` — テンプレート選択ガイドと会議テンプレート（例：`template-selection-guide.md`、`status-update-template.md`、`decision-meeting-template.md`、`sprint-planning-template.md`、`one-on-one-template.md`、`retrospective-template.md`、`brainstorming-template.md`）。
- `examples/` — 会議準備の一連の例（例：`executive-review.md`、`project-decision.md`、`sprint-planning.md`、`customer-meeting.md`）。
