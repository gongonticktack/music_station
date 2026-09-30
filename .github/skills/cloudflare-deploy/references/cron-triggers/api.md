# Cron Triggers API

## 基本ハンドラー

```typescript
export default {
  async scheduled(controller: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    console.log("Cron executed:", new Date(controller.scheduledTime));
  },
};
```

**JavaScript:** 型を除けば同じシグネチャ  
**Python:** `class Default(WorkerEntrypoint): async def scheduled(self, controller, env, ctx)`

## ScheduledController

```typescript
interface ScheduledController {
  scheduledTime: number;  // Unix ms when scheduled to run
  cron: string;           // Expression that triggered (e.g., "*/5 * * * *")
  type: string;           // Always "scheduled"
  noRetry(): void;        // Prevent automatic retry on failure
}
```

**失敗時の再試行を防ぐ:**
```typescript
export default {
  async scheduled(controller, env, ctx) {
    try {
      await riskyOperation(env);
    } catch (error) {
      // Don't retry - failure is expected/acceptable
      controller.noRetry();
      console.error("Operation failed, not retrying:", error);
    }
  },
};
```

**noRetry() を使う場合:**
- 制御できない外部 API の障害（障害中のサービスへの過剰なリクエストを避ける）
- レート制限エラー（再試行してもすぐに再び失敗する）
- 重複実行が検出された場合（冪等性チェックに失敗）
- スキップしても問題のない重要度の低い処理（分析、キャッシュ）
- 再試行しても解消しない検証エラー

## ハンドラーのパラメーター

**`controller: ScheduledController`**
- cron 式とスケジュール時刻にアクセス

**`env: Env`**
- すべてのバインディング: KV、R2、D1、シークレット、サービスバインディング

**`ctx: ExecutionContext`**
- `ctx.waitUntil(promise)` - 非同期タスク（ログ記録、クリーンアップ、外部 API）の実行時間を延長
- 最初の `waitUntil` の失敗が Cron Events に記録される

## 複数のスケジュール

```typescript
export default {
  async scheduled(controller, env, ctx) {
    switch (controller.cron) {
      case "*/3 * * * *": ctx.waitUntil(updateRecentData(env)); break;
      case "0 * * * *": ctx.waitUntil(processHourlyAggregation(env)); break;
      case "0 2 * * *": ctx.waitUntil(performDailyMaintenance(env)); break;
      default: console.warn(`Unhandled: ${controller.cron}`);
    }
  },
};
```

## ctx.waitUntil の使い方

```typescript
export default {
  async scheduled(controller, env, ctx) {
    const data = await fetchCriticalData(); // Critical path
    
    // Non-blocking background tasks
    ctx.waitUntil(Promise.all([
      logToAnalytics(data),
      cleanupOldRecords(env.DB),
      notifyWebhook(env.WEBHOOK_URL, data),
    ]));
  },
};
```

## Workflow との統合

```typescript
import { WorkflowEntrypoint } from "cloudflare:workers";

export class DataProcessingWorkflow extends WorkflowEntrypoint {
  async run(event, step) {
    const data = await step.do("fetch-data", () => fetchLargeDataset());
    const processed = await step.do("process-data", () => processDataset(data));
    await step.do("store-results", () => storeResults(processed));
  }
}

export default {
  async scheduled(controller, env, ctx) {
    const instance = await env.MY_WORKFLOW.create({
      params: { scheduledTime: controller.scheduledTime, cron: controller.cron },
    });
    console.log(`Started workflow: ${instance.id}`);
  },
};
```

## ハンドラーのテスト

**ローカル開発（/__scheduled エンドポイント）:**
```bash
# Start dev server
npx wrangler dev

# Trigger any cron
curl "http://localhost:8787/__scheduled?cron=*/5+*+*+*+*"

# Trigger specific cron with custom time
curl "http://localhost:8787/__scheduled?cron=0+2+*+*+*&scheduledTime=1704067200000"
```

**クエリパラメーター:**
- `cron` - 必須。URL エンコードされた cron 式（空白には `+` を使用）
- `scheduledTime` - 任意。ミリ秒単位の Unix タイムスタンプ（既定値は現在時刻）

**本番環境のセキュリティ:** `/__scheduled` エンドポイントは本番環境でも利用でき、誰でも起動できます。ブロックするか、認証を実装してください。[gotchas.md](./gotchas.md#security-concerns) を参照してください。

**ユニットテスト（Vitest）:**
```typescript
// test/scheduled.test.ts
import { describe, it, expect } from "vitest";
import { env } from "cloudflare:test";
import worker from "../src/index";

describe("Scheduled Handler", () => {
  it("processes scheduled event", async () => {
    const controller = { scheduledTime: Date.now(), cron: "*/5 * * * *", type: "scheduled" as const, noRetry: () => {} };
    const ctx = { waitUntil: (p: Promise<any>) => p, passThroughOnException: () => {} };
    await worker.scheduled(controller, env, ctx);
    expect(await env.MY_KV.get("last_run")).toBeDefined();
  });
  
  it("handles multiple crons", async () => {
    const ctx = { waitUntil: () => {}, passThroughOnException: () => {} };
    await worker.scheduled({ scheduledTime: Date.now(), cron: "*/5 * * * *", type: "scheduled", noRetry: () => {} }, env, ctx);
    expect(await env.MY_KV.get("last_type")).toBe("frequent");
  });
});
```

## エラー処理

**自動再試行:**
- `noRetry()` を呼び出さない限り、失敗した cron の実行は自動的に再試行される
- 再試行は遅延後（通常は数分後）に行われる
- 最初の `waitUntil()` の失敗のみが Cron Events に記録される

**ベストプラクティス:**
```typescript
export default {
  async scheduled(controller, env, ctx) {
    try {
      await criticalOperation(env);
    } catch (error) {
      // Log error details
      console.error("Cron failed:", {
        cron: controller.cron,
        scheduledTime: controller.scheduledTime,
        error: error.message,
        stack: error.stack,
      });
      
      // Decide: retry or skip
      if (error.message.includes("rate limit")) {
        controller.noRetry(); // Skip retry for rate limits
      }
      // Otherwise allow automatic retry
      throw error;
    }
  },
};
```

## 関連項目

- [README.md](./README.md) - 概要
- [patterns.md](./patterns.md) - ユースケース、例
- [gotchas.md](./gotchas.md) - よくあるエラー、テストに関する問題
