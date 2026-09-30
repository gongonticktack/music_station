# FAQデータベース

**目的**：よくある質問と回答を整理します。

## スキーマ

| プロパティ | 型 | 選択肢 | 目的 |
|----------|------|---------|---------|
| **Question** | title | - | 質問内容 |
| **Category** | select | Product, Engineering, Support, HR, General | 質問のトピック |
| **Tags** | multi_select | - | 個別のトピック（auth、billing、onboarding など） |
| **Answer Type** | select | Quick Answer, Detailed Guide, Link to Docs | 回答の形式 |
| **Last Reviewed** | date | - | 回答を確認した日付 |
| **Helpful Count** | number | - | 有用性の追跡（任意） |
| **Audience** | select | Internal, External, All | 誰に表示するか |
| **Related Questions** | relation | Links to related FAQs | 類似トピックを関連付ける |

## 使用方法

```
Create FAQ entries with properties:
{
  "Question": "How do I reset my password?",
  "Category": "Support",
  "Tags": "authentication, password, login",
  "Answer Type": "Quick Answer",
  "Last Reviewed": "2025-10-01",
  "Audience": "External"
}
```

## コンテンツのテンプレート

各FAQページには、次の内容を含めてください。
- **短い回答**：1～2文の簡潔な回答
- **詳しい説明**：背景を含む完全な回答
- **手順**（該当する場合）：番号付きの手順
- **スクリーンショット**（役立つ場合）：視覚的な説明
- **関連する質問**：類似するFAQへのリンク
- **追加リソース**：外部のドキュメントや動画

## ビュー

**カテゴリ別**：Category でグループ化
**最近更新された項目**：Last Reviewed の降順で並べ替え
**レビューが必要**：Last Reviewed が180日より前のものに絞り込む
**外部向けFAQ**：Audience に "External" を含むものに絞り込む
**人気**：Helpful Count の降順で並べ替え（追跡する場合）

## ベストプラクティス

1. **質問を分かりやすくする**：ユーザーが実際に尋ねるような言い方で質問を書く
2. **簡潔な回答を示す**：まず直接答え、その後に詳しく説明する
3. **関連FAQをリンクする**：関連情報を見つけやすくする
4. **定期的に見直す**：回答を最新かつ正確に保つ
5. **役立った内容を追跡する**：アクセスの多いFAQを改善するため、フィードバックを活用する

