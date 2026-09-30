# Analytics Engine のパターン

## ユースケース

| ユースケース | 主な指標 | Index に指定する項目 |
|----------|-------------|----------|
| API の使用量計測 | requests, bytes, compute_units | api_key |
| 機能の利用状況 | feature, action, duration | user_id |
| エラー追跡 | error_type, endpoint, count | customer_id |
| パフォーマンス | latency_ms, cache_status | endpoint |
| A/B テスト | variant, conversions | user_id |

## API の使用量計測（請求）

```typescript
env.ANALYTICS.writeDataPoint({
  blobs: [pathname, method, status, tier],
  doubles: [1, computeUnits, bytes, latencyMs],
  indexes: [apiKey]
});

// Query: Monthly usage by customer
// SELECT index1 AS api_key, SUM(double2) AS compute_units
// FROM usage WHERE timestamp >= DATE_TRUNC('month', NOW()) GROUP BY index1
```

## エラー追跡

```typescript
env.ANALYTICS.writeDataPoint({
  blobs: [endpoint, method, errorName, errorMessage.slice(0, 1000)],
  doubles: [1, timeToErrorMs],
  indexes: [customerId]
});
```

## パフォーマンス監視

```typescript
env.ANALYTICS.writeDataPoint({
  blobs: [pathname, method, cacheStatus, status],
  doubles: [latencyMs, 1],
  indexes: [userId]
});

// Query: P95 latency by endpoint
// SELECT blob1, quantile(0.95)(double1) AS p95_ms FROM perf GROUP BY blob1
```

## アンチパターン

| ❌ 誤り | ✅ 正しい方法 |
|----------|-----------|
| `await writeDataPoint()` | `writeDataPoint()`（実行後に完了を待たない） |
| `indexes: [method]`（カーディナリティが低い） | `blobs: [method]`、`indexes: [userId]` |
| `blobs: [JSON.stringify(obj)]` | ID を Blob に、オブジェクト全体を D1/KV に保存する |
| 1分あたり1000万件のリクエストをすべて書き込む | 1秒ごとに事前集計する |
| Worker からクエリする | 外部サービス/API からクエリする |

## ベストプラクティス

1. **最初にスキーマを設計する** - Blob/Double/Index への割り当てを文書化する
2. **件数の指標を必ず含める** - AVG の計算には `doubles: [latency, 1]` を使用する
3. **Blob には列挙値を使用する** - `Status.SUCCESS` のような一貫した値を使用する
4. **サンプリングに対応する** - 比率を使用する（avg_latency = SUM(latency)/SUM(count)）
5. **早い段階でクエリをテストする** - 大量に書き込む前にスキーマを検証する

## スキーマのテンプレート

```typescript
/**
 * Dataset: my_metrics
 * 
 * Blobs:
 *   blob1: endpoint, blob2: method, blob3: status
 * 
 * Doubles:
 *   double1: latency_ms, double2: count (always 1)
 * 
 * Indexes:
 *   index1: customer_id (high cardinality)
 */
```
