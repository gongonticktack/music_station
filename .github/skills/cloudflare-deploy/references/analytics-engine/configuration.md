# Analytics Engine の設定

## セットアップ

1. `wrangler.jsonc` にバインディングを追加する
2. Worker をデプロイする
3. 初回の書き込み時にデータセットが自動作成される
4. SQL API でクエリを実行する

## wrangler.jsonc

```jsonc
{
  "name": "my-worker",
  "analytics_engine_datasets": [
    { "binding": "ANALYTICS", "dataset": "my_events" }
  ]
}
```

用途を分けるために複数のデータセットを使用する場合：
```jsonc
{
  "analytics_engine_datasets": [
    { "binding": "API_ANALYTICS", "dataset": "api_requests" },
    { "binding": "USER_EVENTS", "dataset": "user_activity" }
  ]
}
```

## TypeScript

```typescript
interface Env {
  ANALYTICS: AnalyticsEngineDataset;
}

export default {
  async fetch(request: Request, env: Env) {
    // No await - returns void, fire-and-forget
    env.ANALYTICS.writeDataPoint({
      blobs: [pathname, method, status],      // String dimensions (max 20)
      doubles: [latency, 1],                   // Numeric metrics (max 20)
      indexes: [apiKey]                        // High-cardinality filter (max 1)
    });
    return response;
  }
};
```

## データポイントの制限

| フィールド | 上限 | SQL での参照方法 |
|-------|-------|------------|
| blobs | 文字列 20 個、各 16KB | `blob1`...`blob20` |
| doubles | 数値 20 個 | `double1`...`double20` |
| indexes | 文字列 1 個、16KB | `index1` |

## 書き込み時の動作

| 状況 | 動作 |
|----------|----------|
| 毎分 100 万件未満の書き込み | すべて受け付けられる |
| 毎分 100 万件超の書き込み | 自動サンプリングが行われる |
| 無効なデータ | 通知なしで失敗する（tail ログを確認） |

**サンプリングを抑える方法：** 事前に集計する、複数のデータセットを使用する、重要な指標だけを書き込む。

## クエリの制限

| リソース | 上限 |
|----------|-------|
| クエリのタイムアウト | 30 秒 |
| データ保持期間 | 90 日（デフォルト） |
| 結果のサイズ | 約 10MB |

## 料金

**無料枠：** 月間 1,000 万件の書き込み、月間 100 万件の読み取り

**有料：** 書き込み 100 万件あたり $0.05、読み取り 100 万件あたり $1.00

## 環境ごとの設定

```jsonc
{
  "analytics_engine_datasets": [
    { "binding": "ANALYTICS", "dataset": "prod_events" }
  ],
  "env": {
    "staging": {
      "analytics_engine_datasets": [
        { "binding": "ANALYTICS", "dataset": "staging_events" }
      ]
    }
  }
}
```

## モニタリング

```bash
npx wrangler tail  # Check for sampling/write errors
```

```sql
-- Check write activity
SELECT DATE_TRUNC('hour', timestamp) AS hour, COUNT(*) AS writes
FROM my_dataset
WHERE timestamp >= NOW() - INTERVAL '24' HOUR
GROUP BY hour
```
