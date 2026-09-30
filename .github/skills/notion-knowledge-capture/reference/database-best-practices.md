# データベースのベストプラクティス

知識を記録するデータベースの作成と保守に関する一般的な指針です。

## 基本原則

### 1. シンプルに保つ
- 基本的なプロパティから始める
- 必要になった場合にのみ追加する
- 過度に複雑にしない

### 2. 一貫した命名を使う
- 主な識別子にはタイトルプロパティを使う
- ライフサイクルの追跡にはステータスを使う
- 柔軟な分類にはタグを使う
- 説任の所在を明確にするには担当者を使う

### 3. メタデータを含める
- 作成日時／更新日時
- 担当者または保守担当者
- 最終レビュー日
- ステータスの指標

### 4. 見つけやすくする
- タグを積極的に使う
- 役立つビューを作成する
- 関連コンテンツをリンクする
- 分かりやすいタイトルを付ける

### 5. 拡張を見据える
- 早い段階からフィルターを検討する
- 関連付けにはリレーションを使う
- 検索について考慮する
- カテゴリで整理する

## データベースの作成

### `Notion:notion-create-database` を使う

ドキュメントデータベースの例：

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

### データベースのスキーマを取得する

ページを作成する前に、必ずデータベースを取得してスキーマを確認してください。

```
Notion:notion-fetch
id: "database-url-or-id"
```

これにより、使用する正確なプロパティ名と型が返されます。

## データベース選択ガイド

| 必要な用途 | 使用するデータベース |
|------|-------------------|
| 一般的なドキュメント | [Documentation Database](documentation-database.md) |
| 意思決定の記録 | [Decision Log](decision-log-database.md) |
| Q&Aナレッジベース | [FAQ Database](faq-database.md) |
| チーム固有のコンテンツ | [Team Wiki](team-wiki-database.md) |
| 手順を順番に示すガイド | [How-To Guide Database](how-to-guide-database.md) |
| インシデント／プロジェクトからの学び | [Learning Database](learning-database.md) |

## ヒント

1. **一般的なドキュメントデータベースから始める** - 最も柔軟に使えます
2. **必要に応じて専用データベースを追加する**（FAQ、意思決定など）
3. **リレーションを使って**関連ドキュメントをつなぐ
4. **よくある用途に合わせてビューを作成する**
5. **プロパティを四半期ごとに見直す** - 使われていないものは削除する
6. **データベースの説明にスキーマを記載する**
7. **プロパティの使い方や規約についてチームに周知する**

