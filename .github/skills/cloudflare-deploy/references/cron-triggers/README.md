# Cloudflare Cron Triggers

cron 式を使って Workers の実行をスケジュールします。Cloudflare のグローバルネットワーク上で、利用率の低い時間帯に実行されます。

## 主な機能

- **UTC のみで実行** - すべてのスケジュールは UTC 時刻で実行されます
- **5 フィールドの cron 構文** - Quartz スケジューラの拡張機能（L、W、#）
- **グローバルへの反映** - デプロイの反映に 15 分
- **少なくとも 1 回の配信** - まれに重複実行が発生する可能性があります
- **Workflow との連携** - 実行時間の長い複数ステップのタスクをトリガーします
- **Green Compute** - 低炭素の時間帯に炭素排出量を考慮してスケジュールするオプション

## Cron 構文

```
 ┌─────────── minute (0-59)
 │ ┌───────── hour (0-23)
 │ │ ┌─────── day of month (1-31)
 │ │ │ ┌───── month (1-12, JAN-DEC)
 │ │ │ │ ┌─── day of week (1-7, SUN-SAT, 1=Sunday)
 * * * * *
```

**特殊文字:** `*`（任意）、`,`（リスト）、`-`（範囲）、`/`（ステップ）、`L`（最後）、`W`（平日）、`#`（第 n 番目）

## よく使うスケジュール

```bash
*/5 * * * *        # Every 5 minutes
0 * * * *          # Hourly
0 2 * * *          # Daily 2am UTC (off-peak)
0 9 * * MON-FRI    # Weekdays 9am UTC
0 0 1 * *          # Monthly 1st midnight UTC
0 9 L * *          # Last day of month 9am UTC
0 10 * * MON#2     # 2nd Monday 10am UTC
*/10 9-17 * * MON-FRI  # Every 10min, 9am-5pm weekdays
```

## クイックスタート

**wrangler.jsonc:**
```jsonc
{
  "name": "my-cron-worker",
  "triggers": {
    "crons": ["*/5 * * * *", "0 2 * * *"]
  }
}
```

**ハンドラー:**
```typescript
export default {
  async scheduled(
    controller: ScheduledController,
    env: Env,
    ctx: ExecutionContext,
  ): Promise<void> {
    console.log("Cron:", controller.cron);
    console.log("Time:", new Date(controller.scheduledTime));
    
    ctx.waitUntil(asyncTask(env)); // Non-blocking
  },
};
```

**ローカルでテスト:**
```bash
npx wrangler dev
curl "http://localhost:8787/__scheduled?cron=*/5+*+*+*+*"
```

## 制限

- **無料:** Worker あたり 3 個のトリガー、10ms の CPU 時間
- **有料:** トリガー数無制限、50ms の CPU 時間
- **反映:** グローバルへのデプロイに 15 分
- **タイムゾーン:** UTC のみ

## 読む順序

**cron triggers を初めて使いますか？** まずはこちらを読んでください:
1. この README - 概要とクイックスタート
2. [configuration.md](./configuration.md) - 最初の cron trigger を設定する
3. [api.md](./api.md) - ハンドラー API を理解する
4. [patterns.md](./patterns.md) - よくあるユースケースと例

**トラブルシューティングが必要ですか？** [gotchas.md](./gotchas.md) へ進んでください

## このリファレンスの内容
- [configuration.md](./configuration.md) - wrangler の設定、環境ごとのスケジュール、Green Compute
- [api.md](./api.md) - ScheduledController、noRetry()、waitUntil、テストパターン
- [patterns.md](./patterns.md) - ユースケース、モニタリング、キュー連携、Durable Objects
- [gotchas.md](./gotchas.md) - タイムゾーンの問題、冪等性、セキュリティ、テスト

## 関連項目
- [workflows](../workflows/) - 実行時間の長いスケジュールタスク向けの代替手段
- [workers](../workers/) - Worker ランタイムのドキュメント
