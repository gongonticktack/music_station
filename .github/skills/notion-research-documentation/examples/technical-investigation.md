# 例：技術調査

## ユーザーの依頼

> 「現在のキャッシュ戦略を調査して、技術的な概要を作成してください」

## ワークフローの実行

### ステップ 1：キャッシュに関する情報を検索

```
Notion:notion-search
query: "caching strategy architecture"
query_type: "internal"
teamspace_id: "engineering-teamspace-id"
```

**見つかった結果：**
- 「システムアーキテクチャ概要」（エンジニアリング）
- 「Redis実装ガイド」（バックエンドドキュメント）
- 「パフォーマンス最適化 - 2024年第3四半期」（エンジニアリング）
- 「APIキャッシュ決定記録」（アーキテクチャ）

### ステップ 2：関連ページを取得

```
Notion:notion-fetch
id: "system-architecture-page-url"
```

抽出内容：現在のキャッシュアーキテクチャでは、APIレスポンスにRedis、セッションストレージにMemcachedを使用しています。

```
Notion:notion-fetch
id: "redis-implementation-guide-url"
```

抽出内容：実装の詳細、TTL設定、無効化戦略。

```
Notion:notion-fetch
id: "api-caching-decision-record-url"
```

抽出内容：他の選択肢ではなくRedisを選んだ理由と、検討したトレードオフ。

### ステップ 3：調査結果を統合

**特定した主な調査結果：**
- 2層キャッシュ：Redis（APIレスポンス）＋Memcached（セッション）
- TTL戦略：動的データは5分、静的データは1時間
- 無効化：重要な更新にはイベント駆動方式
- パフォーマンスへの影響：データベース負荷を75%削減
- 既知の問題：人気のエンドポイントでキャッシュスタンピードが発生

### ステップ 4：技術概要を作成

```
Notion:notion-create-pages

parent: { page_id: "engineering-docs-parent-id" }

pages: [{
  properties: {
    "title": "Technical Summary: Caching Strategy - Oct 2025"
  },
  content: "[Structured technical summary using template]"
}]
```

## 出力ドキュメント

```markdown
# Technical Summary: Caching Strategy - Oct 2025

## Executive Summary

Our caching infrastructure uses a two-tier approach with Redis for API response caching and Memcached for session management. This strategy has reduced database load by 75% and improved API response times from 200ms to 50ms average.

## Architecture Overview

### Layer 1: API Response Caching (Redis)
**Technology**: Redis 7.0 cluster (3 nodes)
**Purpose**: Cache GET endpoint responses
**TTL Strategy**:
- Dynamic content: 5 minutes
- Static content: 1 hour
- User-specific: 15 minutes

**Source**: <mention-page url="...">System Architecture Overview</mention-page>

### Layer 2: Session Storage (Memcached)
**Technology**: Memcached 1.6
**Purpose**: User session data, temporary state
**TTL**: 24 hours (session lifetime)

## Implementation Details

### Cache Key Format
```
api:v1:{endpoint}:{params_hash}
session:{user_id}:{session_id}
```

### Invalidation Strategy
- **Event-driven**: Critical data changes trigger immediate invalidation
- **Time-based**: TTL expiration for non-critical data
- **Manual**: Admin tools for emergency cache clear

**Source**: <mention-page url="...">Redis Implementation Guide</mention-page>

## Decision Rationale

### Why Redis for API Caching?

**Pros**:
- Advanced data structures (sorted sets, hashes)
- Built-in TTL with automatic eviction
- Pub/sub for cache invalidation events
- Persistence options for durability

**Cons**:
- Higher memory usage than Memcached
- More complex cluster management

**Decision**: Chosen for flexibility and rich feature set needed for API caching.

**Source**: <mention-page url="...">API Caching Decision Record</mention-page>

### Why Memcached for Sessions?

**Pros**:
- Simpler, lighter weight
- Excellent for key-value storage
- Lower memory footprint

**Cons**:
- No persistence
- Limited data structures

**Decision**: Perfect fit for ephemeral session data where simplicity is valued.

## Performance Impact

| Metric | Before Caching | After Caching | Improvement |
|--------|----------------|---------------|-------------|
| Avg Response Time | 200ms | 50ms | 75% faster |
| Database Load | 100% | 25% | 75% reduction |
| Cache Hit Rate | - | 85% | - |
| Peak RPS Handled | 1,000 | 4,000 | 4x increase |

**Source**: <mention-page url="...">Performance Optimization - Q3 2024</mention-page>

## Known Issues & Limitations

### Cache Stampede
**Issue**: When popular cache entries expire, multiple requests hit database simultaneously

**Mitigation**: Implemented probabilistic early expiration and request coalescing

**Status**: Reduced by 90% but not eliminated

### Stale Data Risk
**Issue**: Cached data can be up to TTL duration stale

**Mitigation**: Event-driven invalidation for critical data paths

**Status**: Acceptable trade-off for performance gains

## Monitoring & Observability

**Metrics tracked**:
- Cache hit/miss rates per endpoint
- Memory usage and eviction rates
- Response time distributions
- Invalidation event frequency

**Tools**: DataDog dashboards, CloudWatch alarms

## Future Considerations

1. **Edge Caching**: Evaluate CDN integration for static assets
2. **Cache Warming**: Pre-populate cache for predictable traffic spikes
3. **Adaptive TTLs**: Adjust TTLs based on data change frequency
4. **Regional Caching**: Multi-region cache replication for global performance

## Related Documentation

- <mention-page url="...">System Architecture Overview</mention-page>
- <mention-page url="...">Redis Implementation Guide</mention-page>
- <mention-page url="...">API Caching Decision Record</mention-page>
- <mention-page url="...">Performance Optimization - Q3 2024</mention-page>

## Appendix: Configuration Examples

### Redis Configuration
```yaml
maxmemory: 8gb
maxmemory-policy: allkeys-lru
tcp-keepalive: 60
```

### 一般的なキャッシュ操作
```python
# Set with TTL
cache.set(key, value, ttl=300)

# Get with fallback
value = cache.get(key) or fetch_from_db(key)

# Invalidate pattern
cache.delete_pattern("api:v1:users:*")
```
```

## 成功の鍵

1. **複数の情報源の統合**：アーキテクチャ文書、実装ガイド、決定記録を組み合わせた
2. **技術的な深さ**：設定、コード例、メトリクスを含めた
3. **意思決定の背景**：選択した内容だけでなく、その理由も説明した
4. **実践重視**：実際のパフォーマンス数値と既知の問題を記載した
5. **将来を見据えた内容**：改善の余地がある領域を示した
6. **出典を明記**：主要な項目すべてを出典資料にリンクした

## 実例で示すワークフローのパターン

この例では、調査ワークフローの全体を示しています。
- **範囲を絞った検索**（エンジニアリングのチームスペースで絞り込み）
- **複数ページの統合**（4つの異なる情報源）
- **技術テンプレート**（アーキテクチャに重点を置いた形式）
- **適切な配置**（エンジニアリングのドキュメント配下）
- **包括的な出典**（すべての情報源へのリンク）

