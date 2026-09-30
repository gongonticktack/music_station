# ワークフローのパターン

## 画像処理パイプライン

```typescript
export class ImageProcessingWorkflow extends WorkflowEntrypoint<Env, Params> {
  async run(event, step) {
    const imageData = await step.do('fetch', async () => (await this.env.BUCKET.get(event.params.imageKey)).arrayBuffer());
    const description = await step.do('generate description', async () => 
      await this.env.AI.run('@cf/llava-hf/llava-1.5-7b-hf', {image: Array.from(new Uint8Array(imageData)), prompt: 'Describe this image', max_tokens: 50})
    );
    await step.waitForEvent('await approval', { event: 'approved', timeout: '24h' });
    await step.do('publish', async () => await this.env.BUCKET.put(`public/${event.params.imageKey}`, imageData));
  }
}
```

## ユーザーのライフサイクル

```typescript
export class UserLifecycleWorkflow extends WorkflowEntrypoint<Env, Params> {
  async run(event, step) {
    await step.do('welcome email', async () => await sendEmail(event.params.email, 'Welcome!'));
    await step.sleep('trial period', '7 days');
    const hasConverted = await step.do('check conversion', async () => {
      const user = await this.env.DB.prepare('SELECT subscription_status FROM users WHERE id = ?').bind(event.params.userId).first();
      return user.subscription_status === 'active';
    });
    if (!hasConverted) await step.do('trial expiration email', async () => await sendEmail(event.params.email, 'Trial ending'));
  }
}
```

## データパイプライン

```typescript
export class DataPipelineWorkflow extends WorkflowEntrypoint<Env, Params> {
  async run(event, step) {
    const rawData = await step.do('extract', {retries: { limit: 10, delay: '30s', backoff: 'exponential' }}, async () => {
      const res = await fetch(event.params.sourceUrl);
      if (!res.ok) throw new Error('Fetch failed');
      return res.json();
    });
    const transformed = await step.do('transform', async () => 
      rawData.map(item => ({ id: item.id, normalized: normalizeData(item) }))
    );
    const dataRef = await step.do('store', async () => {
      const key = `processed/${Date.now()}.json`;
      await this.env.BUCKET.put(key, JSON.stringify(transformed));
      return { key };
    });
    await step.do('load', async () => {
      const data = await (await this.env.BUCKET.get(dataRef.key)).json();
      for (let i = 0; i < data.length; i += 100) {
        await this.env.DB.batch(data.slice(i, i + 100).map(item => 
          this.env.DB.prepare('INSERT INTO records VALUES (?, ?)').bind(item.id, item.normalized)
        ));
      }
    });
  }
}
```

## 人による承認

```typescript
export class ApprovalWorkflow extends WorkflowEntrypoint<Env, Params> {
  async run(event, step) {
    await step.do('create approval', async () => await this.env.DB.prepare('INSERT INTO approvals (id, user_id, status) VALUES (?, ?, ?)').bind(event.instanceId, event.params.userId, 'pending').run());
    try {
      const approval = await step.waitForEvent<{ approved: boolean }>('wait for approval', { event: 'approval-response', timeout: '48h' });
      if (approval.approved) { await step.do('process approval', async () => {}); } 
      else { await step.do('handle rejection', async () => {}); }
    } catch (e) {
      await step.do('auto reject', async () => await this.env.DB.prepare('UPDATE approvals SET status = ? WHERE id = ?').bind('auto-rejected', event.instanceId).run());
    }
  }
}
```

## ワークフローのテスト

### セットアップ

```typescript
// vitest.config.ts
import { defineWorkersConfig } from '@cloudflare/vitest-pool-workers/config';

export default defineWorkersConfig({
  test: {
    poolOptions: {
      workers: {
        wrangler: { configPath: './wrangler.jsonc' }
      }
    }
  }
});
```

### 内省 API

```typescript
import { introspectWorkflowInstance } from 'cloudflare:test';

const instance = await env.MY_WORKFLOW.create({ params: { userId: '123' } });
const introspector = await introspectWorkflowInstance(env.MY_WORKFLOW, instance.id);

// Wait for step completion
const result = await introspector.waitForStepResult({ name: 'fetch user', index: 0 });

// Mock step behavior
await introspector.modify(async (m) => {
  await m.mockStepResult({ name: 'api call' }, { mocked: true });
});
```

## ベストプラクティス

### ✅ 推奨

1. **細分化したステップ**: 1ステップにつき API 呼び出しを1回にする（冪等性を証明できる場合を除く）
2. **冪等性**: 確認してから実行する。冪等性キーを使う
3. **決定論的な名前**: 静的な名前、またはステップの出力に基づく名前を使う
4. **状態を返す**: 変数ではなく、ステップの戻り値で永続化する
5. **必ず await を付ける**: `await step.do()`。未完了の Promise を残さない
6. **決定論的な条件分岐**: `event.payload` またはステップの出力に基づく
7. **大きなデータは外部に保存する**: 1 MiB を超えるデータは R2/KV に保存し、参照を返す
8. **まとめて作成する**: 複数のインスタンスには `createBatch()` を使う

### ❌ 非推奨

1. **巨大な1ステップ**: 耐久性とリトライ制御が損なわれる
2. **ステップ外の状態**: ハイバネーション時に失われる
3. **イベントを変更する**: イベントは不変。新しい状態を返す
4. **ステップ外の非決定論的なロジック**: `Math.random()`、`Date.now()` はステップ内に置く必要がある
5. **ステップ外の副作用**: 再起動時に重複する可能性がある
6. **非決定論的なステップ名**: キャッシュが無効になる
7. **タイムアウトを無視する**: `waitForEvent` は例外をスローするため、try-catch を使う
8. **インスタンス ID を再利用する**: 保持期間内で一意でなければならない

## オーケストレーションのパターン

### ファンアウト（並列処理）
```typescript
const files = await step.do('list', async () => this.env.BUCKET.list());
await Promise.all(files.objects.map((file, i) => step.do(`process ${i}`, async () => processFile(await (await this.env.BUCKET.get(file.key)).arrayBuffer()))));
```

### 親子ワークフロー
```typescript
const child = await step.do('start child', async () => await this.env.CHILD_WORKFLOW.create({id: `child-${event.instanceId}`, params: { data: result.data }}));
await step.do('other work', async () => console.log(`Child started: ${child.id}`));
```

### 競争パターン
```typescript
const winner = await Promise.race([
  step.do('option A', async () => slowOperation()),
  step.do('option B', async () => fastOperation())
]);
```

### スケジュールされたワークフローの連鎖
```typescript
export default { async scheduled(event, env) { await env.DAILY_WORKFLOW.create({id: `daily-${event.scheduledTime}`, params: { timestamp: event.scheduledTime }}); }};
export class DailyWorkflow extends WorkflowEntrypoint<Env, Params> {
  async run(event, step) {
    await step.do('daily task', async () => {});
    await step.sleep('wait 7 days', '7 days');
    await step.do('weekly followup', async () => {});
  }
}
```

参照先: [configuration.md](./configuration.md)、[api.md](./api.md)、[gotchas.md](./gotchas.md)
