# 例：プロジェクトの意思決定会議の準備

## ユーザーの依頼

> "明日のアーキテクチャ会議の準備をしてください。データベース移行の方針を決める必要があります。"

## ワークフローの実行

### ステップ 1：背景情報を検索

```
Notion:notion-search
query: "database migration"
query_type: "internal"
teamspace_id: "engineering-teamspace-id"
filters: {
  created_date_range: {
    start_date: "2024-01-01"
  }
}
```

**見つかった結果：**
- 「データベース移行の提案」（エンジニアリング）
- 「現行データベースのパフォーマンス上の問題」（エンジニアリング）
- 「移行オプションの分析」（アーキテクチャ）
- 「以前の移行の事後分析」（エンジニアリング）

### ステップ 2：関連ページを取得

```
Notion:notion-fetch
id: "database-migration-proposal-page-id"
```

**抽出内容**：MongoDB から PostgreSQL への移行を提案し、スケジュールとリスクを概説

```
Notion:notion-fetch
id: "database-performance-issues-page-id"
```

**抽出内容**：現在の問題点 — クエリの遅さ、スキーマの柔軟性に起因する問題、トランザクションの制限

```
Notion:notion-fetch
id: "migration-options-analysis-page-id"
```

**抽出内容**：3つの選択肢を分析：
1. 最適化を行い、MongoDB を使い続ける
2. PostgreSQL に移行する
3. ハイブリッド方式（MongoDB + PostgreSQL）

```
Notion:notion-fetch
id: "previous-migration-postmortem-page-id"
```

**抽出内容**：2023年の Redis 移行から得た教訓 — ロールバック計画とテスト戦略の重要性

### ステップ 3：事前資料をまとめる

**特定した重要情報：**
- **問題**：MongoDB のパフォーマンスが低下しており、スキーマの柔軟性がデータの一貫性の問題を引き起こしている
- **選択肢**：トレードオフの異なる3つのアプローチ
- **推奨案**：エンジニアリングチームは PostgreSQL への移行を支持
- **懸念事項**：必要なダウンタイム、データ移行の複雑さ、必要となるアプリケーションの変更
- **過去の経緯**：以前の移行には6週間かかり、ロールバックで問題が発生した

### ステップ 4：会議の議題を作成

```
Notion:notion-create-pages

parent: { page_id: "meetings-parent-id" }

pages: [{
  properties: {
    "title": "Architecture Decision: Database Migration Strategy - Oct 15, 2025"
  },
  content: "[Decision meeting agenda]"
}]
```

**作成した議題：**

```markdown
# Architecture Decision: Database Migration Strategy

## Meeting Details
**Date & Time**: October 15, 2025 at 2:00 PM  
**Duration**: 90 minutes  
**Location**: Conference Room B / Zoom  
**Facilitator**: Sarah Chen (Engineering Lead)  
**Attendees**:
- Sarah Chen (Engineering Lead)
- David Kim (CTO)
- Alice Wang (Backend Team Lead)
- Bob Martinez (DevOps Lead)
- Carol Johnson (Product Director)

## Pre-Read Summary

### Background

Our MongoDB database is experiencing performance degradation as we scale. Query response times have increased from 50ms to 400ms average over the past 6 months. The schema-less nature that initially provided flexibility is now causing data consistency issues and making application logic more complex.

**Source**: <mention-page url="...">Current Database Performance Issues</mention-page>

### Current Situation

**Performance metrics**:
- Average query time: 400ms (was 50ms 6 months ago)
- p95 query time: 1.2s (was 200ms)
- Database size: 500GB (growing 20GB/month)
- Connection pool exhaustion during peak traffic

**Technical debt**:
- 15+ application-layer validation rules compensating for lack of schema
- Complex data migration scripts for schema changes
- Limited transaction support causing race conditions

**Source**: <mention-page url="...">Database Migration Proposal</mention-page>

### Historical Context

We successfully migrated from Redis to Memcached in 2023, which took 6 weeks. Key learnings:
- Underestimated application code changes (3 weeks instead of 1 week)
- Rollback plan was crucial when we discovered compatibility issues
- Parallel running period (dual writes) was essential for safe migration

**Source**: <mention-page url="...">Previous Migration Post-mortem</mention-page>

## Decision Required

**Question**: Which database migration strategy should we adopt?

**Timeline**: Need decision by end of week to include in Q4 planning

**Impact**: 
- Engineering team (4-8 weeks of work)
- Application architecture
- Operations & monitoring
- Future feature development velocity

## Options Analysis

### Option A: Stay on MongoDB with Optimizations

**Description**: Invest in MongoDB performance tuning, add indexes, upgrade to latest version, implement better query patterns.

**Pros**:
- ✅ No migration complexity
- ✅ Team familiar with MongoDB
- ✅ Can implement immediately
- ✅ Lower risk
- ✅ Estimated 2 weeks effort

**Cons**:
- ❌ Doesn't solve fundamental schema flexibility issues
- ❌ Still limited transaction support
- ❌ Performance improvements may be temporary
- ❌ Continues technical debt accumulation

**Cost/Effort**: 2 weeks engineering + $5K/year additional MongoDB infrastructure

**Risk**: Medium - Improvements may not be sufficient

**Source**: <mention-page url="...">Migration Options Analysis</mention-page>

### Option B: Migrate to PostgreSQL

**Description**: Full migration from MongoDB to PostgreSQL. Redesign schema with proper constraints, implement dual-write period, then cut over.

**Pros**:
- ✅ Solves schema consistency issues
- ✅ Full ACID transactions
- ✅ Better performance for relational queries
- ✅ Lower long-term complexity
- ✅ Industry standard, easier hiring

**Cons**:
- ❌ High migration effort (6-8 weeks)
- ❌ Requires schema redesign
- ❌ Application code changes extensive
- ❌ Risk of data loss during migration
- ❌ Downtime required (4-6 hours estimated)

**Cost/Effort**: 8 weeks engineering + $8K migration costs - $15K/year MongoDB savings = net $7K/year savings

**Risk**: High - Complex migration, application changes required

**Recommendation**: ✅ **Favored by engineering team**

**Source**: <mention-page url="...">Database Migration Proposal</mention-page>

### Option C: Hybrid Approach

**Description**: Keep MongoDB for document-heavy data (logs, analytics), migrate transactional data to PostgreSQL. Run both databases.

**Pros**:
- ✅ Phased migration (lower risk)
- ✅ Use best tool for each data type
- ✅ Can migrate incrementally
- ✅ Smaller initial scope (4 weeks)

**Cons**:
- ❌ Increased operational complexity
- ❌ Two databases to maintain
- ❌ Data consistency between databases challenging
- ❌ Higher infrastructure costs
- ❌ Complex application logic

**Cost/Effort**: 4 weeks initial + ongoing complexity + $10K/year additional infrastructure

**Risk**: Medium - Operational complexity increases

**Source**: <mention-page url="...">Migration Options Analysis</mention-page>

### Option D: Do Nothing

**Description**: Accept current performance and continue with MongoDB as-is.

**Implications**:
- Performance continues to degrade
- Technical debt increases
- Feature development slows
- Customer experience suffers
- Eventually forced into emergency migration

**Not recommended**

## Discussion Topics

### Technical Feasibility
1. Can we achieve < 4 hours downtime for Option B?
2. What's the rollback plan if PostgreSQL migration fails?
3. How do we handle data migration for 500GB?
4. Schema design - what constraints do we need?

### Business Impact
5. What's the customer impact of 4-6 hours downtime?
6. Can we schedule migration during low-traffic period?
7. How does this affect Q4 feature roadmap?
8. Cost-benefit analysis over 2-year horizon?

### Risk Management
9. What are the biggest risks with Option B?
10. How do we test thoroughly before cutover?
11. What's the rollback procedure and time?
12. Do we have necessary expertise on team?

### Timeline & Resources
13. Can we allocate 2 engineers full-time for 8 weeks?
14. Do we need external consultants?
15. What's the impact on other Q4 projects?
16. When could we realistically complete this?

## Decision Framework

**Evaluation criteria**:
1. **Performance improvement**: Will this solve our performance issues?
2. **Technical debt**: Does this reduce or increase complexity?
3. **Risk**: What's the probability and impact of failure?
4. **Cost**: Total cost of ownership (effort + infrastructure)
5. **Timeline**: Can we complete in Q4?
6. **Reversibility**: Can we roll back if needed?

**Decision makers**:
- Primary: David Kim (CTO)
- Consulted: Sarah Chen (Engineering), Bob Martinez (DevOps)
- Informed: Product, Executive team

## Decision

*[To be filled during meeting]*

**Selected Option**: ___________________

**Rationale**:

**Timeline**:

**Owner**: ___________________

**Success Criteria**:

## Action Items

*[To be filled during meeting]*

- [ ] [Action item] - @[Owner] - Due: [Date]
- [ ] [Action item] - @[Owner] - Due: [Date]

## Next Steps

**Immediate**:
- Document decision rationale
- Create detailed implementation plan
- Schedule kickoff meeting

**Follow-up meeting**: [Date] to review migration plan

## Related Resources

### Primary Sources
- <mention-page url="...">Database Migration Proposal</mention-page>
- <mention-page url="...">Current Database Performance Issues</mention-page>
- <mention-page url="...">Migration Options Analysis</mention-page>
- <mention-page url="...">Previous Migration Post-mortem</mention-page>

### Supporting Documents
- MongoDB performance metrics dashboard
- PostgreSQL evaluation results
- Cost analysis spreadsheet
```

### ステップ 5：議題を共有

```
Notion:notion-create-comment
parent: { page_id: "agenda-page-id" }
rich_text: [{
  type: "text",
  text: { content: "📋 Meeting agenda ready! Please review the pre-read before tomorrow's meeting. cc: @Sarah @David @Alice @Bob @Carol" }
}]
```

## ユーザーに提示した要約

```markdown
## Meeting Prep Complete ✅

### Meeting Details
- **Topic**: Database Migration Strategy Decision
- **Date**: October 15, 2025 at 2:00 PM
- **Duration**: 90 minutes
- **Attendees**: 5 (Engineering leads + CTO + Product)

### Agenda Created
<mention-page url="...">Architecture Decision: Database Migration Strategy</mention-page>

### Pre-Read Summary

**Problem**: MongoDB performance degrading (50ms → 400ms queries), schema flexibility causing issues

**Decision needed**: Choose between:
1. Stay on MongoDB (optimizations) - 2 weeks, low risk
2. Migrate to PostgreSQL - 8 weeks, high value, high risk ✅ Recommended
3. Hybrid approach - 4 weeks, medium complexity
4. Do nothing - Not recommended

**Recommendation**: Engineering team favors PostgreSQL migration

### Key Information Included

✅ **Background context** from 4 relevant pages
✅ **Options analysis** with pros/cons for each
✅ **Cost-benefit** breakdown
✅ **Risk assessment** for each option
✅ **Discussion topics** (16 questions organized by theme)
✅ **Decision framework** with evaluation criteria
✅ **Historical context** from previous migration
✅ **Empty sections** for decision and action items

### Discussion Topics Prepared

**Technical** (4 questions):
- Downtime achievability
- Rollback planning
- Data migration approach
- Schema design

**Business** (4 questions):
- Customer impact
- Scheduling
- Roadmap impact
- Cost analysis

**Risk** (4 questions):
- Risk identification
- Testing strategy
- Rollback procedure
- Expertise availability

**Resources** (4 questions):
- Team allocation
- External help needs
- Project trade-offs
- Timeline realism

### Success Factors

1. **Comprehensive research**: 4 relevant pages analyzed
2. **Clear options**: Pros/cons for each approach
3. **Structured discussion**: 16 questions organized by theme
4. **Decision framework**: Clear criteria for evaluation
5. **Historical context**: Lessons from previous migration
6. **Ready for outcomes**: Sections prepared for decision and actions

**Meeting is well-prepared for productive decision-making! 📊**
```

## 示されている主な機能

### 背景情報の収集
- **対象を絞った検索**：エンジニアリングのチームスペース、最近のドキュメント
- **複数の視点**：パフォーマンスデータ、提案、分析、過去の教訓
- **包括的な統合**：技術、ビジネス、過去の経緯に関する情報を統合

### 選択肢の分析
- **構造化された比較**: 各選択肢の長所と短所
- **費用対効果**: 作業量とインフラコストを含む
- **リスク評価**: 発生確率と影響を明記
- **推奨案**: エンジニアリング上の明確な推奨を提示

### 意思決定の支援
- **議題**: テーマ別に整理した16の質問
- **意思決定の枠組み**: 評価基準を定義
- **意思決定者**: 役割と責任を明確化
- **結果の記録**: 決定事項とアクションを記入できるセクション

### 会議の構成
- **事前資料**: 包括的な背景情報（10分で読める分量）
- **選択肢**: すばやく決定できる明確な比較
- **議論**: 構造化された議題で話が脱線するのを防止
- **記録**: 決定事項とアクションのテンプレート

最適な用途: アーキテクチャ上の意思決定、技術的なトレードオフ、戦略的な選択

