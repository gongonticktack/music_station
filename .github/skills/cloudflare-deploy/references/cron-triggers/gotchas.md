# Cronトリガーの注意点

## よくあるエラー

### 「タイムゾーンの問題」

**問題:** cronが現地時間に対して誤った時刻に実行される  
**原因:** すべてのcronはUTCで実行され、現地タイムゾーンには対応していない  
**解決策:** 現地時刻を手動でUTCに変換する

**変換式:** `utcHour = (localHour - utcOffset + 24) % 24`

**例:**
- PST午前9時（UTC-8）→ `(9 - (-8) + 24) % 24 = 17` → `0 17 * * *`
- EST午前2時（UTC-5）→ `(2 - (-5) + 24) % 24 = 7` → `0 7 * * *`
- JST午後6時（UTC+9）→ `(18 - 9 + 24) % 24 = 33 % 24 = 9` → `0 9 * * *`

**夏時間:** 夏時間が切り替わるときに手動で調整するか、夏時間の影響を受けない時刻（例：現地時間の午前2時〜4時は通常安全）にスケジュールしてください。

### 「cronが実行されない」

**原因:** `scheduled()` エクスポートの欠落、構文エラー、反映待ち（15分未満）、またはプランの制限  
**解決策:** エクスポートが存在することを確認し、crontab.guruで検証し、デプロイ後15分以上待ってからプランの制限を確認する

### 「重複実行」

**原因:** 少なくとも1回の配信  
**解決策:** KVに実行IDを記録する - 下記の冪等性パターンを参照

### 「実行の失敗」

**原因:** CPU制限超過、未処理の例外、ネットワークタイムアウト、バインディングエラー  
**解決策:** try-catch、AbortControllerによるタイムアウト、長時間の処理には `ctx.waitUntil()`、または負荷の高いタスクにはWorkflowsを使用する

### 「ローカルテストが動作しない」

**問題:** `/__scheduled` エンドポイントが404を返す、またはハンドラーが起動しない  
**原因:** `scheduled()` エクスポートの欠落、wranglerが実行されていない、またはエンドポイント形式が正しくない  
**解決策:**

1. `scheduled()` がエクスポートされていることを確認します。
```typescript
export default {
  async scheduled(controller, env, ctx) {
    console.log("Cron triggered");
  },
};
```

2. 開発サーバーを起動します。
```bash
npx wrangler dev
```

3. 正しいエンドポイント形式を使用します（スペースは `+` にURLエンコードします）。
```bash
# Correct
curl "http://localhost:8787/__scheduled?cron=*/5+*+*+*+*"

# Wrong (will fail)
curl "http://localhost:8787/__scheduled?cron=*/5 * * * *"
```

4. Wranglerが古い場合は更新します。
```bash
npm install -g wrangler@latest
```

### 「waitUntil()のタスクが完了しない」

**問題:** `ctx.waitUntil()` 内のバックグラウンドタスクが、エラーを通知せず失敗する、または実行されない  
**原因:** Promiseがエラー処理されずに拒否される、またはPromiseの完了前にハンドラーが戻る  
**解決策:** waitUntilのPromiseは必ずawaitするか、エラーを処理します。

```typescript
export default {
  async scheduled(controller, env, ctx) {
    // BAD: Silent failures
    ctx.waitUntil(riskyOperation());
    
    // GOOD: Explicit error handling
    ctx.waitUntil(
      riskyOperation().catch(err => {
        console.error("Background task failed:", err);
        return logError(err, env);
      })
    );
  },
};
```

### 「冪等性の問題」

**問題:** 少なくとも1回の配信により、副作用が重複する（二重請求、メールの重複送信など）  
**原因:** 重複排除の仕組みがない  
**解決策:** KVを使って実行IDを記録します。

```typescript
export default {
  async scheduled(controller, env, ctx) {
    const executionId = `${controller.cron}-${controller.scheduledTime}`;
    const existing = await env.EXECUTIONS.get(executionId);
    
    if (existing) {
      console.log("Already executed, skipping");
      controller.noRetry();
      return;
    }
    
    await env.EXECUTIONS.put(executionId, "1", { expirationTtl: 86400 }); // 24h TTL
    await performIdempotentOperation(env);
  },
};
```

### 「セキュリティ上の懸念」

**問題:** 本番環境で `__scheduled` エンドポイントが公開され、許可されていないcronの起動が可能になる  
**原因:** デプロイ済みのWorkersでテスト用エンドポイントが利用可能  
**解決策:** 本番環境では `__scheduled` をブロックします。

```typescript
export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    
    // Block __scheduled in production
    if (url.pathname === "/__scheduled" && env.ENVIRONMENT === "production") {
      return new Response("Not Found", { status: 404 });
    }
    
    return handleRequest(request, env, ctx);
  },
  
  async scheduled(controller, env, ctx) {
    // Your cron logic
  },
};
```

**併せて:** シークレットには `env.API_KEY` を使用します（ハードコードしないでください）。

**別の方法:** ミドルウェアを追加してリクエストの送信元を検証します。
```typescript
export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    
    if (url.pathname === "/__scheduled") {
      // Check Cloudflare headers to verify internal request
      const cfRay = request.headers.get("cf-ray");
      if (!cfRay && env.ENVIRONMENT === "production") {
        return new Response("Not Found", { status: 404 });
      }
    }
    
    return handleRequest(request, env, ctx);
  },
  
  async scheduled(controller, env, ctx) {
    // Your cron logic
  },
};
```

## 制限とクォータ

| 制限 | Free | Paid | 備考 |
|-------|------|------|-------|
| Workerあたりのトリガー数 | 3 | 無制限 | Workerあたりのcronスケジュールの最大数 |
| CPU時間 | 10ms | 50ms | `ctx.waitUntil()` またはWorkflowsが必要になる場合があります |
| 実行保証 | 少なくとも1回 | 少なくとも1回 | 重複する可能性あり - 冪等性を使用してください |
| 反映時間 | 最大15分 | 最大15分 | 変更が全世界で有効になるまでの時間 |
| 最短間隔 | 1分 | 1分 | これより短い間隔ではスケジュールできません |
| cronの精度 | ±1分 | ±1分 | 実行時刻には多少のずれが生じる場合があります |

## テストのベストプラクティス

**ユニットテスト:**
- `ScheduledController`、`ExecutionContext`、バインディングをモックする
- cron式をそれぞれ個別にテストする
- 想定どおり `noRetry()` が呼び出されることを確認する
- 実環境に近い環境には、`@cloudflare/vitest-pool-workers` とVitestを使用する

**統合テスト:**
- 開発環境で `/__scheduled` エンドポイント経由でテストする
- `scheduledTime` の値が重複する場合の冪等性ロジックを検証する
- エラー処理と再試行の動作をテストする

**本番環境:** 長い間隔（`*/30 * * * *`）で開始し、Cron Eventsを24時間監視してから、間隔を短くする前にアラートを設定します。

## リソース

- [Cron Triggers Docs](https://developers.cloudflare.com/workers/configuration/cron-triggers/)
- [Scheduled Handler API](https://developers.cloudflare.com/workers/runtime-apis/handlers/scheduled/)
- [Cloudflare Workflows](https://developers.cloudflare.com/workflows/)
- [Workers Limits](https://developers.cloudflare.com/workers/platform/limits/)
- [Crontab Guru](https://crontab.guru/) - バリデーター
- [Vitest Pool Workers](https://github.com/cloudflare/workers-sdk/tree/main/fixtures/vitest-pool-workers-examples)
