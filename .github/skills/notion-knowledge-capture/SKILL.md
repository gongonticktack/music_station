---
name: notion-knowledge-capture
description: 会話や決定事項を構造化されたNotionページに記録します。チャットやメモを適切にリンクされたWiki項目、ハウツー、決定事項、FAQにまとめる場合に使用します。
metadata:
  short-description: 会話を構造化されたNotionページに記録する
---

# ナレッジの記録

会話やメモを、簡単に再利用できる構造化されたリンク可能なNotionページにまとめます。

## クイックスタート
1) 記録する内容（決定事項、ハウツー、FAQ、学び、ドキュメント）と対象読者を明確にします。
2) `reference/` 内から適切なデータベース／テンプレート（チームWiki、ハウツー、FAQ、決定ログ、学び、ドキュメント）を特定します。
3) `Notion:notion-search` → `Notion:notion-fetch` を使って、Notionから既存の関連情報を取得します（更新またはリンクする既存ページを探します）。
4) データベースのスキーマに沿って `Notion:notion-create-pages` でページを下書きし、要約、背景、ソースへのリンク、タグ／担当者を含めます。
5) ハブページや関連レコードからリンクし、情報の更新に応じて `Notion:notion-update-page` でステータス／担当者を更新します。

## ワークフロー
### 0) Notion MCPが接続されていないためにMCP呼び出しが失敗した場合は、いったん停止して設定します。
1. Notion MCPを追加します。
   - `codex mcp add notion --url https://mcp.notion.com/mcp`
2. リモートMCPクライアントを有効にします。
   - `[features].rmcp_client = true` の `config.toml` を設定するか、`codex --enable rmcp_client` を実行します。
3. OAuthでログインします。
   - `codex mcp login notion`

ログインに成功したら、ユーザーはcodexを再起動する必要があります。その旨を伝え、再試行時にはステップ1から続けられることを案内して、回答を終えてください。

### 1) 記録する内容を定義する
- 目的、対象読者、情報の鮮度、および新規作成か更新かを確認します。
- コンテンツの種類を判断します。決定事項、ハウツー、FAQ、概念／Wiki項目、学び／メモ、ドキュメントページなどです。

### 2) 保存先を特定する
- `reference/*-database.md` のガイドを使って適切なデータベースを選び、必須プロパティ（タイトル、タグ、担当者、ステータス、日付、リレーション）を確認します。
- 候補となるデータベースが複数ある場合は、どれを使うかユーザーに尋ねます。そうでなければ、主要なWiki／ドキュメントデータベースに作成します。

### 3) 内容を抽出して構成する
- 会話から事実、決定事項、対応、根拠を抽出します。
- 決定事項については、選択肢、根拠、結果を記録します。
- ハウツー／ドキュメントについては、手順、前提条件、アセット／コードへのリンク、例外的なケースを記録します。
- FAQについては、簡潔な回答と詳細ドキュメントへのリンクを添えたQ&A形式にします。

### 4) Notionで作成／更新する
- 適切な `Notion:notion-create-pages` を指定して `data_source_id` を使用し、プロパティ（タイトル、タグ、担当者、ステータス、日付、リレーション）を設定します。
- `reference/` のテンプレートに沿って内容を構成します（セクション見出し、チェックリストなど）。
- 既存ページを更新する場合は、取得してから `Notion:notion-update-page` で編集します。

### 5) リンクして見つけやすくする
- ハブページ、関連する仕様書／ドキュメント、チームへのリレーション／バックリンクを追加します。
- 将来の読者に向けて、短い要約／変更履歴を追加します。
- フォローアップタスクがある場合は、該当するデータベースにタスクを作成してリンクします。

## 参考資料と例
- `reference/` — データベースのスキーマとテンプレート（例: `team-wiki-database.md`、`how-to-guide-database.md`、`faq-database.md`、`decision-log-database.md`、`documentation-database.md`、`learning-database.md`、`database-best-practices.md`）。
- `examples/` — 実際の記録パターン（例: `decision-capture.md`、`how-to-guide.md`、`conversation-to-faq.md`）。
