# Cloudflare Workers Analytics Engine リファレンス

Cloudflare Workers Analytics Engine を使用し、大規模環境でカーディナリティに上限のない分析を実装するための専門的なガイドです。

## Analytics Engine とは？

カーディナリティの高いデータ（数百万種類の異なるディメンション値）向けに設計された時系列分析データベースです。Workers からデータポイントを書き込み、SQL API を通じてクエリします。用途は次のとおりです。
- ユーザー向けの独自分析ダッシュボード
- 使用量に基づく請求と計測
- 顧客別・機能別の監視
- パフォーマンスに影響を与えない高頻度の計測

**主な機能:** パフォーマンスを低下させずに、一意の値が無制限にある指標（数百万件のユーザー ID や API キーなど）を追跡できます。

## 基本概念

| 概念 | 説明 | 例 |
|---------|-------------|---------|
| **Dataset** | 関連する指標をまとめる論理テーブル | `api_requests`、`user_events` |
| **Data Point** | タイムスタンプ付きの単一の測定値 | 1件の API リクエストの指標 |
| **Blobs** | 文字列のディメンション（最大20個） | endpoint, method, status, user_id |
| **Doubles** | 数値（最大20個） | latency_ms, request_count, bytes |
| **Indexes** | 効率的なクエリのために絞り込みに使用する Blob | customer_id, api_key |

## 読む順番

| 作業 | 最初に読むもの | 次に読むもの |
|------|------------|-----------|
| **初回セットアップ** | [configuration.md](configuration.md) → [api.md](api.md) → [patterns.md](patterns.md) | |
| **データの書き込み** | [api.md](api.md) → [gotchas.md](gotchas.md)（サンプリング） | |
| **データのクエリ** | [api.md](api.md)（SQL API）→ [patterns.md](patterns.md)（例） | |
| **デバッグ** | [gotchas.md](gotchas.md) → [api.md](api.md)（制限） | |
| **最適化** | [patterns.md](patterns.md)（アンチパターン）→ [gotchas.md](gotchas.md) | |

## Analytics Engine を使用する場面

```
Need to track metrics? → Yes
  ↓
Millions of unique dimension values? → Yes
    ↓
  Need real-time queries? → Yes
      ↓
    Use Analytics Engine ✓

Alternative scenarios:
- Low cardinality (<10k unique values) → Workers Analytics (free tier)
- Complex joins/relations → D1 Database
- Logs/debugging → Tail Workers (logpush)
- External tools → Send to external analytics (Datadog, etc.)
```

## クイックスタート

1. `wrangler.jsonc` にバインディングを追加します。
```jsonc
{
  "analytics_engine_datasets": [
    { "binding": "ANALYTICS", "dataset": "my_events" }
  ]
}
```

2. データポイントを書き込みます（完了を待たず、await は使用しません）。
```typescript
env.ANALYTICS.writeDataPoint({
  blobs: ["/api/users", "GET", "200"],
  doubles: [145.2, 1],  // latency_ms, count
  indexes: [customerId]
});
```

3. SQL API（HTTP）経由でクエリします。
```sql
SELECT blob1, SUM(double2) AS total_requests
FROM my_events
WHERE index1 = 'customer_123'
  AND timestamp >= NOW() - INTERVAL '7' DAY
GROUP BY blob1
ORDER BY total_requests DESC
```

## このリファレンスの内容

- **[configuration.md](configuration.md)** - セットアップ、バインディング、TypeScript の型、制限
- **[api.md](api.md)** - `writeDataPoint()`、SQL API、クエリ構文
- **[patterns.md](patterns.md)** - ユースケース、例、アンチパターン
- **[gotchas.md](gotchas.md)** - サンプリング、Index の選択、トラブルシューティング

## 関連資料

- [Cloudflare Analytics Engine のドキュメント](https://developers.cloudflare.com/analytics/analytics-engine/)
