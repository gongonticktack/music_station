# 意思決定ログデータベース（ADR - アーキテクチャ意思決定記録）

**目的**：背景や根拠とともに、重要な意思決定を記録します。

## スキーマ

| プロパティ | 型 | 選択肢 | 目的 |
|----------|------|---------|---------|
| **Decision** | title | - | 何を決定したか |
| **Date** | date | - | 決定した日付 |
| **Status** | select | Proposed, Accepted, Superseded, Deprecated | 現在の決定のステータス |
| **Domain** | select | Architecture, Product, Business, Design, Operations | 意思決定のカテゴリ |
| **Impact** | select | High, Medium, Low | 予想される影響の大きさ |
| **Deciders** | people | - | 誰が決定したか |
| **Stakeholders** | people | - | 誰が決定の影響を受けるか |
| **Related Decisions** | relation | Links to other decisions | 背景と依存関係 |

## 使用方法

```
Create decision records with properties:
{
  "Decision": "Use PostgreSQL for Primary Database",
  "Date": "2025-10-15",
  "Status": "Accepted",
  "Domain": "Architecture",
  "Impact": "High",
  "Deciders": [tech_lead, architect],
  "Stakeholders": [eng_team]
}
```

## コンテンツのテンプレート

各意思決定ページには、次の内容を含めてください。
- **背景**：この決定が必要だった理由
- **決定**：何を決定したか
- **根拠**：この選択肢を選んだ理由
- **検討した選択肢**：代替案とそれぞれのトレードオフ
- **結果**：予想される影響（良い面と悪い面）
- **実施方法**：決定をどのように実行するか

## ビュー

**最近の意思決定**：日付の降順で並べ替え
**有効な意思決定**：Status = "Accepted" で絞り込む
**ドメイン別**：Domain でグループ化
**影響大**：Impact = "High" で絞り込む
**保留中**：Status = "Proposed" で絞り込む

## ベストプラクティス

1. **すぐに記録する**：背景を鮮明に覚えているうちに、決定した時点で記録する
2. **代替案を含める**：検討した内容と、選ばなかった理由を示す
3. **置き換えられた決定を追跡する**：決定が変わったらステータスを更新する
4. **関連する意思決定をリンクする**：リレーションを使って依存関係を示す
5. **定期的に見直す**：古い決定が今も有効か確認する

