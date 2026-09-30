# 例: 意思決定記録の作成

**ユーザーの依頼**: 「REST から GraphQL API に移行するという決定を記録してください」

## ワークフロー

### 1. 文脈から決定事項を抽出
会話から以下を特定:
- **決定**: 顧客向け API を REST から GraphQL に移行する
- **背景**: REST エンドポイントが扱いにくくなっている（50 件以上）
- **代替案**: REST を継続する、gRPC を試す、GraphQL を採用する
- **理由**: クライアント体験の向上、型安全性、単一エンドポイント

### 2. 意思決定ログを探す
```
Notion:notion-search
query: "architecture decisions" or "ADR"
```

見つかったもの: 「Architecture Decision Records」データベース

### 3. スキーマを取得
```
Notion:notion-fetch
```

取得したプロパティ: Decision (タイトル)、Date、Status、Domain、Impact、Deciders、Stakeholders

### 4. 意思決定記録を作成
```
Notion:notion-create-pages
parent: { data_source_id: "decision-log-collection-id" }
pages: [{
  properties: {
    "Decision": "Migrate to GraphQL API",
    "date:Date:start": "2025-10-16",
    "date:Date:is_datetime": 0,
    "Status": "Accepted",
    "Domain": "Architecture",
    "Impact": "High"
  },
  content: "[Full decision record with context, rationale, alternatives...]"
}]
```

**内容の例**:

```markdown
# Migrate Customer-Facing API to GraphQL

## Context
Our REST API has grown to 50+ endpoints with inconsistent patterns. Frontend and mobile teams request new endpoints frequently, leading to:
- API bloat and maintenance burden
- Over-fetching/under-fetching data
- Slow iteration on client features
- Inconsistent error handling

## Decision
Migrate customer-facing API from REST to GraphQL while maintaining REST for internal services.

## Rationale
**Why GraphQL**:
- Clients fetch exactly what they need (no over/under-fetching)
- Single endpoint, self-documenting schema
- Type safety with code generation
- Better developer experience
- Industry standard for client-facing APIs

## Options Considered

### Option A: Keep REST (Status Quo)
**Pros**: No migration cost, team familiar
**Cons**: Doesn't solve core problems, maintenance keeps growing
**Decision**: Rejected - doesn't address root cause

### Option B: gRPC
**Pros**: Performance, strong typing
**Cons**: Browser support issues, steeper learning curve, not designed for client-facing
**Decision**: Rejected - better for internal services

### Option C: GraphQL
**Pros**: Solves over/under-fetching, great DX, strong ecosystem
**Cons**: Learning curve, caching complexity, migration effort
**Decision**: **Accepted**

## Consequences

**Positive**:
- Faster frontend/mobile development
- Reduced API maintenance burden
- Better type safety and tooling
- Single endpoint simplifies deployment

**Negative**:
- 3-4 month migration timeline
- Team needs training
- Need to solve caching strategy
- Monitoring/debugging patterns different

## Implementation Plan
1. GraphQL server setup (Apollo Server)
2. Schema design workshop
3. Gradual migration (start with new features)
4. Dual-run period (both REST and GraphQL)
5. Deprecate old REST endpoints

**Timeline**: Start Q4 2025, complete Q1 2026
**Owner**: Backend team lead

## Success Metrics
- API response times improve 30%
- Client fetch efficiency (less data transferred)
- Reduced new endpoint requests
- Developer satisfaction scores
```

### 5. 見つけやすくする
Architecture Wiki にリンクを追加し、Slack でチームに通知しました。

## 成功の主な要因
- 文脈が新鮮なうちに決定を記録
- 検討した代替案を記録
- メリットとデメリットの両方を記載
- 明確な実装計画
- 後で参照できるよう意思決定ログに保存
- チームが見つけやすいように整理
