# 仕様からのタスク作成

## タスクデータベースを見つける

タスクを作成する前に、タスクデータベースを見つけます。

```
1. Search for task database:
   Notion:notion-search
   query: "Tasks" or "Task Management" or "[Project] Tasks"
   
2. Fetch database schema:
   Notion:notion-fetch
   id: "database-id-from-search"
   
3. Identify data source:
   - Look for <data-source url="collection://..."> tags
   - Extract collection ID for parent parameter
   
4. Note schema:
   - Required properties
   - Property types and options
   - Relation properties for linking

Example:
Notion:notion-search
query: "Engineering Tasks"
query_type: "internal"

Notion:notion-fetch
id: "tasks-database-id"
```

結果: 親パラメーターとして使う `collection://abc-123-def`

## タスクの分解方針

### タスクのサイズの目安

**適切なサイズのタスク**:
- 1～2日で完了できる
- 成果物が1つで明確
- 単独でテストできる
- 依存関係が最小限

**大きすぎるタスク**:
- 3日を超える
- 成果物が複数ある
- 依存関係が多い
- さらに分解する

**小さすぎるタスク**:
- 2時間未満で完了する
- 細分化しすぎている
- 関連作業とまとめる

### フェーズごとの粒度

**初期フェーズ**: 大きめのタスクでも可
- 「データベーススキーマを設計する」
- 「APIの構成を整える」

**中期フェーズ**: 中程度のサイズのタスク
- 「ユーザー認証を実装する」
- 「ダッシュボードUIを構築する」

**後期フェーズ**: 小さく、範囲が明確なタスク
- 「フォームのバリデーションバグを修正する」
- 「ボタンに読み込み状態を追加する」

## タスク作成の手順

要件または作業項目ごとに、次の手順を実行します。

```
1. Identify the work
2. Determine task size
3. Create task in database
4. Set properties
5. Write task description
6. Link to spec/plan
```

### タスクを作成する

```
Use Notion:notion-create-pages:

parent: {
  type: "data_source_id",
  data_source_id: "collection://tasks-db-uuid"
}

properties: {
  "[Title Property]": "Task: [Clear task name]",
  "Status": "To Do",
  "Priority": "[High/Medium/Low]",
  "[Project/Related]": ["spec-page-id", "plan-page-id"],
  "Assignee": "[Person]" (if known),
  "date:Due Date:start": "[Date]" (if applicable),
  "date:Due Date:is_datetime": 0
}

content: "[Task description using template]"
```

## タスク説明のテンプレート

```markdown
# [Task Name]

## Context
Implementation task for <mention-page url="...">Feature Spec</mention-page>

Part of <mention-page url="...">Implementation Plan</mention-page> - Phase [N]

## Objective
[What this task accomplishes]

## Requirements
Based on spec requirements:
- [Relevant requirement 1]
- [Relevant requirement 2]

## Acceptance Criteria
- [ ] [Specific, testable criterion]
- [ ] [Specific, testable criterion]
- [ ] [Specific, testable criterion]

## Technical Approach
[Suggested implementation approach]

### Components Affected
- [Component 1]
- [Component 2]

### Key Decisions
- [Decision point 1]
- [Decision point 2]

## Dependencies

### Blocked By
- <mention-page url="...">Prerequisite Task</mention-page> or None

### Blocks
- <mention-page url="...">Dependent Task</mention-page> or None

## Resources
- [Link to design mockup]
- [Link to API spec]
- [Link to relevant code]

## Estimated Effort
[Time estimate]

## Progress
[To be updated during implementation]
```

## タスクの種類

### インフラ・セットアップタスク

```
Title: "Setup: [What's being set up]"
Examples:
- "Setup: Configure database connection pool"
- "Setup: Initialize authentication middleware"
- "Setup: Create CI/CD pipeline"

Focus: Getting environment/tooling ready
```

### 機能実装タスク

```
Title: "Implement: [Feature name]"
Examples:
- "Implement: User login flow"
- "Implement: File upload functionality"
- "Implement: Dashboard widget"

Focus: Building specific functionality
```

### 統合タスク

```
Title: "Integrate: [What's being integrated]"
Examples:
- "Integrate: Connect frontend to API"
- "Integrate: Add payment provider"
- "Integrate: Link user profile to dashboard"

Focus: Connecting components
```

### テストタスク

```
Title: "Test: [What's being tested]"
Examples:
- "Test: Write unit tests for auth service"
- "Test: E2E testing for checkout flow"
- "Test: Performance testing for API"

Focus: Validation and quality assurance
```

### ドキュメント作成タスク

```
Title: "Document: [What's being documented]"
Examples:
- "Document: API endpoints"
- "Document: Setup instructions"
- "Document: Architecture decisions"

Focus: Creating documentation
```

### バグ修正タスク

```
Title: "Fix: [Bug description]"
Examples:
- "Fix: Login error on Safari"
- "Fix: Memory leak in image processing"
- "Fix: Race condition in payment flow"

Focus: Resolving issues
```

### リファクタリングタスク

```
Title: "Refactor: [What's being refactored]"
Examples:
- "Refactor: Extract auth logic to service"
- "Refactor: Optimize database queries"
- "Refactor: Simplify component hierarchy"

Focus: Code quality improvement
```

## タスクの順序付け

### クリティカルパス

先に完了させる必要があるタスクを特定します。

```
1. Database schema
2. API foundation
3. Core business logic
4. Frontend integration
5. Testing
6. Deployment
```

### 並行作業トラック

同時に進められるタスク:

```
Track A: Backend development
- API endpoints
- Business logic
- Database operations

Track B: Frontend development
- UI components
- State management
- Routing

Track C: Infrastructure
- CI/CD setup
- Monitoring
- Documentation
```

### フェーズごとの順序付け

実装フェーズごとにまとめます。

```
Phase 1 (Foundation):
- Setup tasks
- Infrastructure tasks

Phase 2 (Core):
- Feature implementation tasks
- Integration tasks

Phase 3 (Polish):
- Testing tasks
- Documentation tasks
- Optimization tasks
```

## 優先度の設定

### P0/重大
- 他のすべての作業をブロックする
- 中核機能
- セキュリティ要件
- データの整合性

### P1/高
- 重要な機能
- ユーザー向け機能
- パフォーマンス要件

### P2/中
- あると望ましい機能
- 最適化
- 小規模な改善

### P3/低
- 将来の拡張
- エッジケースへの対応
- 外観上の改善

## 見積もり

### ストーリーポイント

ストーリーポイントを使う場合:
- 1ポイント: 数時間
- 2ポイント: 半日
- 3ポイント: 1日
- 5ポイント: 2日
- 8ポイント: 3～4日（分解を検討）

### 所要時間の見積もり

所要時間を直接見積もる場合:
- 2～4時間: 小規模なタスク
- 1日: 中規模なタスク
- 2日: 大規模なタスク
- 3日以上: さらに分解する

### 見積もり時の考慮事項

以下を考慮します。
- 複雑さ
- 不明点
- 依存関係
- テスト要件
- ドキュメントの必要性

## タスク間の関係

### 親タスクのパターン

大きな機能の場合:

```
Parent: "Feature: User Authentication"
Children:
- "Setup: Configure auth library"
- "Implement: Login flow"
- "Implement: Password reset"
- "Test: Auth functionality"
```

### 依存関係チェーンのパターン

順番に進める作業の場合:

```
Task A: "Design database schema"
↓ (blocks)
Task B: "Implement data models"
↓ (blocks)
Task C: "Create API endpoints"
↓ (blocks)
Task D: "Integrate with frontend"
```

### 関連タスクのパターン

並行作業の場合:

```
Central: "Feature: Dashboard"
Related:
- "Backend API for dashboard data"
- "Frontend dashboard component"
- "Dashboard data caching"
```

## タスクの一括作成

多数のタスクを作成する場合:

```
For each work item in breakdown:
  1. Determine task properties
  2. Create task page
  3. Link to spec/plan
  4. Set relationships

Then:
  1. Update plan with task links
  2. Review sequencing
  3. Assign tasks (if known)
```

## タスクの命名規則

**具体的にする**:
✓ 「メールアドレスとパスワードによるユーザーログインを実装する」
✗ 「ログインを追加する」

**文脈を含める**:
✓ 「ダッシュボード: 売上チャートウィジェットを追加する」
✗ 「チャートを追加する」

**動作を表す言葉を使う**:
- 実装する、構築する、作成する
- 統合する、接続する、連携する
- 修正する、解決する、デバッグする
- テストする、検証する、確認する
- ドキュメント化する、記述する、更新する
- リファクタリングする、最適化する、改善する

## 検証チェックリスト

タスクを確定する前に:

☐ 各タスクの目的が明確である
☐ 受け入れ条件がテスト可能である
☐ 依存関係が特定されている
☐ 適切なサイズである（1～2日）
☐ 優先度が設定されている
☐ 仕様書・計画にリンクされている
☐ 順序が適切である
☐ リソースが記載されている

