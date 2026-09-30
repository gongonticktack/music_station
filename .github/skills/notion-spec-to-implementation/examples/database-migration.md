# 例：データベース移行の実装

**ユーザーの依頼**: 「ユーザー設定スキーマのデータベース移行を計画して実装する」

## ワークフロー

### 1. 仕様を検索して取得
```
Notion:notion-search → Found "User Preferences Schema Migration Spec"
Notion:notion-fetch → Extracted requirements
```

**仕様の概要**: パフォーマンスとデータ整合性を向上させるため、JSON blob から構造化スキーマに移行する。

### 2. 要件を解析
- **現状**: JSONB の preferences 列
- **移行先**: `user_preferences` テーブルと `notification_preferences` テーブルを分離
- **必須条件**: 移行中の後方互換性を維持
- **パフォーマンス**: ダウンタイムなしで100万人以上のユーザーに対応

### 3. 実装計画を作成
```
Notion:notion-create-pages
pages: [{
  properties: {
    title: "Implementation Plan: User Preferences Migration"
  },
  content: "[Full implementation plan with phases]"
}]
```

**計画の内容**:
- **フェーズ1**: インデックス付きの新しいテーブルを作成
- **フェーズ2**: JSONB からデータをバックフィル
- **フェーズ3**: デュアルライトモード（旧形式と新形式の両方に書き込み）
- **フェーズ4**: 読み取り先を新スキーマに切り替え
- **フェーズ5**: 古い JSONB 列を削除

### 4. タスクデータベースを検索してタスクを作成
```
Notion:notion-search → Found "Engineering Tasks" database
Notion:notion-fetch → Got schema (Task, Status, Priority, Assignee, etc.)

Notion:notion-create-pages
parent: { data_source_id: "collection://xyz" }
pages: [
  {
    properties: {
      "Task": "Write migration SQL scripts",
      "Status": "To Do",
      "Priority": "High",
      "Sprint": "Sprint 25"
    },
    content: "## Context\nPart of User Preferences Migration...\n\n## Acceptance Criteria\n- [ ] Migration script creates tables\n- [ ] Indexes defined..."
  },
  // ... 4 more tasks
]
```

**作成したタスク**:
1. 移行用 SQL スクリプトを作成
2. バックフィルジョブを実装
3. API にデュアルライト処理を追加
4. 読み取りクエリを更新
5. ロールバック計画と監視

### 5. 進捗を追跡
ステータス、ブロッカー、完了メモを含め、実装計画を定期的に更新する。

## 主な成果物

**実装計画ページ**（仕様にリンク）
**データベース内の5件のタスク**（依存関係と受け入れ基準を含む）
**進捗の追跡**（作業の進行に応じて更新）

## 成功のポイント
- 複雑な移行を明確なフェーズに分割
- 具体的な受け入れ基準を含むタスクを作成
- 依存関係を設定（フェーズ1 → 2 → 3 → 4 → 5）
- ロールバック計画を備えたゼロダウンタイム方式
- すべての作業を元の仕様にリンク
