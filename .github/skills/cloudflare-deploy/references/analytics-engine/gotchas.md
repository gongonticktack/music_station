# Analytics Engine の注意点

## 重大な問題

### 書き込み量が多い場合のサンプリング

**問題:** 1分あたりの書き込みが100万件を超えると、クエリで返されるデータポイントが書き込んだ数より少なくなります。

**対処法:**
```typescript
// Pre-aggregate before writing
let buffer = { count: 0, total: 0 };
buffer.count++; buffer.total += value;

// Write once per second instead of per request
if (Date.now() % 1000 === 0) {
  env.ANALYTICS.writeDataPoint({ doubles: [buffer.count, buffer.total] });
}
```

**確認方法:** `npx wrangler tail` を実行し、"sampling enabled" を探します。

### writeDataPoint の戻り値は void

```typescript
// ❌ Pointless await
await env.ANALYTICS.writeDataPoint({...});

// ✅ Fire-and-forget
env.ANALYTICS.writeDataPoint({...});
```

書き込みはエラーが表に出ないまま失敗することがあります。tail ログを確認してください。

### Index と Blob の使い分け

| カーディナリティ | 使用するもの | 例 |
|-------------|-----|---------|
| 数百万種類 | **Index** | user_id, api_key |
| 数百種類 | **Blob** | endpoint, status_code, country |

```typescript
// ✅ Correct
{ blobs: [method, path, status], indexes: [userId] }
```

### Workers からはクエリできない

Query API には HTTP 認証が必要です。外部サービスを使用するか、KV/D1 にキャッシュしてください。

### 独自のタイムスタンプは指定できない

タイムスタンプは書き込み時に自動生成されます。必要であれば元のタイムスタンプを Blob に保存してください。

## よくあるエラー

| エラー | 対処法 |
|-------|-----|
| バインディングが見つからない | wrangler.jsonc を確認し、再デプロイする |
| クエリ結果にデータがない | 30秒待ち、データセット名と時間範囲を確認する |
| クエリがタイムアウトする | 時間フィルターを追加し、絞り込みに Index を使用する |

## 制限

| リソース | 上限 |
|----------|-------|
| データポイントあたりの Blob 数 | 20 |
| データポイントあたりの Double 数 | 20 |
| データポイントあたりの Index 数 | 1 |
| Blob/Index のサイズ | 16KB |
| 書き込み速度（サンプリングなし） | 約100万件/分 |
| 保持期間 | 90日 |
| クエリのタイムアウト | 30秒 |

## ベストプラクティス

✅ 書き込み量が多い場合は事前に集計する  
✅ カーディナリティが高い場合（数百万種類）は Index を使用する  
✅ クエリには必ず時間フィルターを含める  
✅ コーディング前にスキーマを設計する  

❌ writeDataPoint を await しない  
❌ カーディナリティが低い場合に Index を使用しない  
❌ 時間範囲を指定せずにクエリしない  
❌ すべての書き込みが成功したと思い込まない
