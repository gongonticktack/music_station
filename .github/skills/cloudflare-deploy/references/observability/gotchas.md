## よくあるエラー

### 「ログが表示されない」

**原因:** Observability が無効、Worker が再デプロイされていない、トラフィックがない、サンプリング率が低い、またはログサイズが 256 KB を超えている
**解決策:** 
```bash
# Verify config
cat wrangler.jsonc | jq '.observability'

# Check deployment
wrangler deployments list <WORKER_NAME>

# Test with curl
curl https://your-worker.workers.dev
```
`observability.enabled = true` であることを確認し、Worker を再デプロイして、`head_sampling_rate` とトラフィックを確認します。

### 「トレースがキャプチャされない」

**原因:** トレースが有効になっていない、サンプリング率が正しくない、Worker が再デプロイされていない、または送信先を利用できない
**解決策:**
```jsonc
// Temporarily set to 100% sampling for debugging
{
  "observability": {
    "enabled": true,
    "head_sampling_rate": 1.0,
    "traces": {
      "enabled": true
    }
  }
}
```
`observability.traces.enabled = true` であることを確認し、テスト用に `head_sampling_rate` を 1.0 に設定して再デプロイし、送信先のステータスを確認します。

## 制限事項

| リソース/制限 | 値 | 備考 |
|----------------|-------|-------|
| 最大ログサイズ | 256 KB | これを超えるログは切り詰められます |
| デフォルトのサンプリング率 | 1.0 (100%) | トラフィックの多い Worker では下げてください |
| 最大送信先数 | プランにより異なる | ダッシュボードで確認してください |
| トレースコンテキストの伝播 | 最大 100 スパン | 呼び出し階層が深いとスパンが失われる場合があります |
| Analytics Engine の書き込みレート | リクエストあたり 25 回 | 超過した書き込みは通知なく破棄されます |

## パフォーマンスに関する注意点

### Spectre 対策による時刻精度の低下

**問題:** `Date.now()` と `performance.now()` の精度が低下し (100μs 単位に丸められ) ます
**原因:** V8 における Spectre 脆弱性への対策
**解決策:** 精度低下を許容するか、正確な計測には Workers Traces を使用します
```typescript
// Date.now() is coarsened - trace spans are accurate
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    // For user-facing timing, Date.now() is fine
    const start = Date.now();
    const response = await processRequest(request);
    const duration = Date.now() - start;
    
    // For detailed performance analysis, use Workers Traces instead
    return response;
  }
}
```

### Analytics Engine の _sample_interval 集計

**問題:** `_sample_interval` を掛け合わせないと、クエリが誤った合計値を返します
**原因:** Analytics Engine はサンプリングされたデータポイントを保存し、それぞれが複数のイベントを表します
**解決策:** 集計では常に件数/合計値に `_sample_interval` を掛けます
```sql
-- WRONG: Undercounts actual events
SELECT blob1 AS customer_id, COUNT(*) AS total_calls
FROM api_usage GROUP BY customer_id;

-- CORRECT: Accounts for sampling
SELECT blob1 AS customer_id, SUM(_sample_interval) AS total_calls
FROM api_usage GROUP BY customer_id;
```

### トレースコンテキスト伝播の制限

**問題:** 呼び出し階層が深いと、100 スパンを超えた後にトレースコンテキストが失われます
**原因:** Cloudflare はパフォーマンスへの影響を防ぐため、トレースの深さを制限しています
**解決策:** 階層の浅いアーキテクチャを設計するか、深い呼び出し階層にはカスタム相関 ID を使用します
```typescript
// For deep call chains, add custom correlation ID
const correlationId = crypto.randomUUID();
console.log({ correlationId, event: 'request_start' });

// Pass correlationId through headers to downstream services
await fetch('https://api.example.com', {
  headers: { 'X-Correlation-ID': correlationId }
});
```

## 料金 (2026)

### Workers Traces
- **GA 料金 (2026 年 3 月 1 日開始):**
  - キャプチャしたトレーススパン 100 万件あたり $0.10
  - 保持期間: 14 日間を含む
- **無料枠:** 月 1,000 万トレーススパン
- **注:** ベータ期間中 (2026 年 3 月 1 日より前) の利用は無料です

### Workers Logs
- **含まれる内容:** すべての Workers で無料
- **Logpush:** Business/Enterprise プランが必要

### Analytics Engine
- **含まれる内容:** Paid Workers プランで月 1,000 万回の書き込み
- **追加分:** 含まれる枠を超える書き込み 100 万回あたり $0.25