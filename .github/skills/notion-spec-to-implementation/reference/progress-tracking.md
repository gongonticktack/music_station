# 進捗管理

## 更新頻度

### 日次更新

実装作業を進行中の場合：

**更新する内容**:
- 変更があった場合はタスクのステータス
- タスクに進捗メモを追加
- ブロッカーを更新

**タイミング**:
- 作業日の終わり
- 重要な作業を完了した後
- ブロッカーに直面したとき

### マイルストーン更新

フェーズまたはマイルストーンの完了時：

**更新する内容**:
- 計画でフェーズを完了としてマーク
- マイルストーンの概要を追加
- 必要に応じてタイムラインを更新
- ステークホルダーに報告

**タイミング**:
- フェーズの完了時
- 主要な成果物の準備ができたとき
- スプリント終了時
- リリース時

### ステータス変更時の更新

タスクの状態が遷移するとき：

**更新する内容**:
- タスクのステータスプロパティ
- 遷移メモを追加
- 関係者に通知

**タイミング**:
- 作業開始時 (To Do → In Progress)
- レビュー準備完了時 (In Progress → In Review)
- 完了時 (In Review → Done)
- ブロック時 (Any → Blocked)

## 進捗メモの形式

### 日次進捗メモ

```markdown
## Progress: [Date]

### Completed
- [Specific accomplishment with details]
- [Specific accomplishment with details]

### In Progress
- [Current work item]
- Current status: [Percentage or description]

### Next Steps
1. [Next planned action]
2. [Next planned action]

### Blockers
- [Blocker description and who/what needed to unblock]
- Or: None

### Decisions Made
- [Any technical/product decisions]

### Notes
[Additional context, learnings, issues encountered]
```

例：

```markdown
## Progress: Oct 14, 2025

### Completed
- Implemented user authentication API endpoints (login, logout, refresh)
- Added JWT token generation and validation
- Wrote unit tests for auth service (95% coverage)

### In Progress
- Frontend login form integration
- Currently: Form submits but need to handle error states

### Next Steps
1. Complete error handling in login form
2. Add loading states
3. Implement "remember me" functionality

### Blockers
None

### Decisions Made
- Using HttpOnly cookies for refresh tokens (more secure than localStorage)
- Session timeout set to 24 hours based on security review

### Notes
- Found edge case with concurrent login attempts, added to backlog
- Performance of auth check is good (<10ms)
```

### マイルストーンの概要

```markdown
## Phase [N] Complete: [Date]

### Overview
[Brief description of what was accomplished in this phase]

### Completed Tasks
- <mention-page url="...">Task 1</mention-page> ✅
- <mention-page url="...">Task 2</mention-page> ✅
- <mention-page url="...">Task 3</mention-page> ✅

### Deliverables
- [Deliverable 1]: [Link/description]
- [Deliverable 2]: [Link/description]

### Key Accomplishments
- [Major achievement]
- [Major achievement]

### Metrics
- [Relevant metric]: [Value]
- [Relevant metric]: [Value]

### Challenges Overcome
- [Challenge and how it was solved]

### Learnings
**What went well**:
- [Success factor]

**What to improve**:
- [Area for improvement]

### Impact on Timeline
- On schedule / [X days ahead/behind]
- Reason: [If deviation, explain why]

### Next Phase
- **Starting**: [Next phase name]
- **Target start date**: [Date]
- **Focus**: [Main objectives]
```

## 実装計画の更新

### 進捗インジケーター

計画ページを定期的に更新します：

```markdown
## Status Overview

**Overall Progress**: 45% complete

### Phase Status
- ✅ Phase 1: Foundation - Complete
- 🔄 Phase 2: Core Features - In Progress (60%)
- ⏳ Phase 3: Integration - Not Started

### Task Summary
- ✅ Completed: 12 tasks
- 🔄 In Progress: 5 tasks
- 🚧 Blocked: 1 task
- ⏳ Not Started: 8 tasks

**Last Updated**: [Date]
```

### タスクリストの更新

完了したタスクに印を付けます：

```markdown
## Implementation Phases

### Phase 1: Foundation
- [x] <mention-page url="...">Database schema</mention-page>
- [x] <mention-page url="...">API scaffolding</mention-page>
- [x] <mention-page url="...">Auth setup</mention-page>

### Phase 2: Core Features
- [x] <mention-page url="...">User management</mention-page>
- [ ] <mention-page url="...">Dashboard</mention-page>
- [ ] <mention-page url="...">Reporting</mention-page>
```

### タイムラインの更新

マイルストーンの日付を更新します：

```markdown
## Timeline

| Milestone | Original | Current | Status |
|-----------|----------|---------|--------|
| Phase 1 | Oct 15 | Oct 14 | ✅ Complete (1 day early) |
| Phase 2 | Oct 30 | Nov 2 | 🔄 In Progress (3 days delay) |
| Phase 3 | Nov 15 | Nov 18 | ⏳ Planned (adjusted) |
| Launch | Nov 20 | Nov 22 | ⏳ Planned (adjusted) |

**Timeline Status**: Slightly behind due to [reason]
```

## タスクのステータス管理

### ステータスの定義

**To Do**: 未着手
- タスクは着手可能な状態
- 依存関係は満たされている
- 担当者が割り当て済み (または対応可能)

**In Progress**: 作業中
- 作業を開始している
- 担当者が割り当てられている
- 定期的な更新が必要

**Blocked**: 進行不可
- 依存関係が満たされていない
- 外部要因によるブロッカーがある
- 判断またはリソース待ち

**In Review**: レビュー待ち
- 実装者の観点では作業完了
- コードレビュー、QA、または承認が必要
- レビュアーが特定されている

**Done**: 完了
- すべての受け入れ基準を満たしている
- レビューと承認が完了している
- デプロイまたは納品済み

### タスクのステータス更新

更新時の手順：

```
1. Update Status property
2. Add progress note explaining change
3. Update related tasks if needed
4. Notify relevant people via comment

Example:
properties: { "Status": "In Progress" }

Content update:
## Progress: Oct 14, 2025
Started implementation. Set up basic structure and wrote initial tests.
```

## ブロッカーの追跡

### ブロッカーの記録

ブロッカーに直面したとき：

```markdown
## Blockers

### [Date]: [Blocker Description]
**Status**: 🚧 Active
**Impact**: [What's blocked]
**Needed to unblock**: [Action/person/decision needed]
**Owner**: [Who's responsible for unblocking]
**Target resolution**: [Date or timeframe]
```

### ブロッカーの解消

ブロッカーが解消されたとき：

```markdown
## Blockers

### [Date]: [Blocker Description]
**Status**: ✅ Resolved on [Date]
**Resolution**: [How it was resolved]
**Impact**: [Any timeline/scope impact]
```

### ブロッカーのエスカレーション

ブロッカーのエスカレーションが必要な場合：

```
1. Update blocker status in task
2. Add comment tagging stakeholder
3. Update plan with blocker impact
4. Propose mitigation if possible
```

## メトリクスの追跡

### ベロシティの追跡

完了率を記録します：

```markdown
## Velocity

### Week 1
- Tasks completed: 8
- Story points: 21
- Velocity: Strong

### Week 2
- Tasks completed: 6
- Story points: 18
- Velocity: Moderate (1 blocker)

### Week 3
- Tasks completed: 9
- Story points: 24
- Velocity: Strong (blocker resolved)
```

### 品質メトリクス

品質指標を記録します：

```markdown
## Quality Metrics

- Test coverage: 87%
- Code review approval rate: 95%
- Bug count: 3 (2 minor, 1 cosmetic)
- Performance: All targets met
- Security: No issues found
```

### 進捗メトリクス

定量的な進捗：

```markdown
## Progress Metrics

- Requirements implemented: 15/20 (75%)
- Acceptance criteria met: 42/56 (75%)
- Test cases passing: 128/135 (95%)
- Code complete: 80%
- Documentation: 60%
```

## ステークホルダーとのコミュニケーション

### 週次ステータスレポート

```markdown
## Weekly Status: [Week of Date]

### Summary
[One paragraph overview of progress and status]

### This Week's Accomplishments
- [Key accomplishment]
- [Key accomplishment]
- [Key accomplishment]

### Next Week's Plan
- [Planned work]
- [Planned work]

### Status
- On track / At risk / Behind schedule
- [If at risk or behind, explain and provide mitigation plan]

### Blockers & Needs
- [Active blocker or need for help]
- Or: None

### Risks
- [New or evolving risk]
- Or: None currently identified
```

### エグゼクティブサマリー

経営層への状況報告用：

```markdown
## Implementation Status: [Feature Name]

**Overall Status**: 🟢 On Track / 🟡 At Risk / 🔴 Behind

**Progress**: [X]% complete

**Key Updates**:
- [Most important update]
- [Most important update]

**Timeline**: [Status vs original plan]

**Risks**: [Top 1-2 risks]

**Next Milestone**: [Upcoming milestone and date]
```

## 進捗の自動追跡

### クエリによるステータス集計

タスクデータベースからステータスを生成します：

```
Query task database:
SELECT 
  "Status",
  COUNT(*) as count
FROM "collection://tasks-uuid"
WHERE "Related Tasks" CONTAINS 'plan-page-id'
GROUP BY "Status"

Generate summary:
- To Do: 8
- In Progress: 5
- Blocked: 1
- In Review: 2
- Done: 12

Overall: 44% complete (12/28 tasks)
```

### タイムラインの計算

完了予定を算出します：

```
Average velocity: 6 tasks/week
Remaining tasks: 14
Projected completion: 2.3 weeks from now

Compares to target: [On schedule/Behind/Ahead]
```

## ベストプラクティス

1. **定期的に更新する**: 更新をため込まない
2. **具体的に書く**: 「ログインを完了」対「進捗あり」
3. **進捗を数値化する**: パーセンテージ、件数、メトリクスを使う
4. **ブロッカーをすぐに記録する**: 報告を先延ばしにしない
5. **作業へのリンクを付ける**: PR、デプロイ、デモを参照する
6. **判断を記録する**: 何をしたかだけでなく、理由も記録する
7. **正直に報告する**: 楽観的な見込みではなく、実際の状況を報告する
8. **一か所で更新する**: 実装計画を信頼できる唯一の情報源として保つ

