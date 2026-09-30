# ハウツーガイドデータベース

**目的**：よくあるタスクの手順を文書化します。

## スキーマ

| プロパティ | 型 | 選択肢 | 目的 |
|----------|------|---------|---------|
| **Title** | title | - | 「[タスク]の方法」 |
| **Complexity** | select | Beginner, Intermediate, Advanced | 必要なスキルレベル |
| **Time Required** | number | - | 完了までの推定時間（分） |
| **Prerequisites** | relation | Links to other guides | 必要な知識 |
| **Category** | select | Development, Deployment, Testing, Tools | タスクのカテゴリ |
| **Last Tested** | date | - | 手順を確認した日付 |
| **Tags** | multi_select | - | 技術／ツールのタグ |

## 使用方法

```
Create how-to guides with properties:
{
  "Title": "How to Set Up Local Development Environment",
  "Complexity": "Beginner",
  "Time Required": 30,
  "Category": "Development",
  "Last Tested": "2025-10-01",
  "Tags": "setup, environment, docker"
}
```

## ベストプラクティス

1. **一貫した命名を使う**：必ず「How to...」で始める
2. **手順をテストする**：公開前に手順が正しく動くことを確認する
3. **所要時間の目安を含める**：ユーザーが時間を計画しやすくする
4. **前提条件をリンクする**：依存関係を明確にする
5. **定期的に更新する**：ツールやシステムが変わったら手順を再テストする

