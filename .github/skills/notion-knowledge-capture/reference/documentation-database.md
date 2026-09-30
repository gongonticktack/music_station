# 一般ドキュメントデータベース

**目的**：あらゆる種類のドキュメントを、検索しやすく整理されたデータベースに保存します。

## スキーマ

| プロパティ | 型 | 選択肢 | 目的 |
|----------|------|---------|---------|
| **Title** | title | - | ドキュメント名 |
| **Type** | select | How-To, Concept, Reference, FAQ, Decision, Post-Mortem | コンテンツの種類を分類 |
| **Category** | select | Engineering, Product, Design, Operations, General | 部門／トピック別に整理 |
| **Tags** | multi_select | - | 追加の分類（言語、ツール、トピック） |
| **Status** | select | Draft, In Review, Final, Deprecated | ドキュメントのライフサイクルを追跡 |
| **Owner** | people | - | ドキュメントの保守担当者 |
| **Created** | created_time | - | 自動入力される作成日 |
| **Last Updated** | last_edited_time | - | 自動入力される最終編集日時 |
| **Last Reviewed** | date | - | 手動で記録するレビュー日 |

## 使用方法

```
Create pages with properties:
{
  "Title": "How to Deploy to Production",
  "Type": "How-To",
  "Category": "Engineering",
  "Tags": "deployment, production, DevOps",
  "Status": "Final",
  "Owner": [current_user],
  "Last Reviewed": "2025-10-01"
}
```

## ビュー

**種類別**：Type プロパティでグループ化
**カテゴリ別**：Category プロパティでグループ化  
**最近の更新**：Last Updated の降順で並べ替え
**レビューが必要**：Last Reviewed が90日より前のものに絞り込む
**下書きドキュメント**：Status = "Draft" で絞り込む

## このデータベースの作成

`Notion:notion-create-database` を使います。

```javascript
{
  "parent": {"page_id": "wiki-page-id"},
  "title": [{"text": {"content": "Team Documentation"}}],
  "properties": {
    "Type": {
      "select": {
        "options": [
          {"name": "How-To", "color": "blue"},
          {"name": "Concept", "color": "green"},
          {"name": "Reference", "color": "gray"},
          {"name": "FAQ", "color": "yellow"}
        ]
      }
    },
    "Category": {
      "select": {
        "options": [
          {"name": "Engineering", "color": "red"},
          {"name": "Product", "color": "purple"},
          {"name": "Design", "color": "pink"}
        ]
      }
    },
    "Tags": {"multi_select": {"options": []}},
    "Owner": {"people": {}},
    "Status": {
      "select": {
        "options": [
          {"name": "Draft", "color": "gray"},
          {"name": "Final", "color": "green"},
          {"name": "Deprecated", "color": "red"}
        ]
      }
    }
  }
}
```

## ベストプラクティス

1. **このスキーマから始める** - 一般的なドキュメントに最も柔軟に対応できます
2. **リレーションを使って**関連ドキュメントをつなぐ
3. **よくある用途に合わせてビューを作成する**
4. **プロパティを四半期ごとに見直す** - 使われていないものは削除する
5. **データベースの説明にスキーマを記載する**
6. **プロパティの使い方や規約についてチームに周知する**

