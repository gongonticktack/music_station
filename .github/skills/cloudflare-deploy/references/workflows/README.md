# Cloudflare Workflows

自動再試行、状態の永続化、長時間実行に対応した、耐久性のあるマルチステップアプリケーション。

## 概要

- 自動再試行ロジックを使ってステップを連結する
- ステップ間で状態を永続化する（数分から数週間）
- 進行状況を失わずに障害を処理する
- 外部イベントや承認を待機する
- リソースを消費せずにスリープする

**利用可能:** Free および Paid Workers プラン

## 主な概念

**ワークフロー**: `WorkflowEntrypoint` を継承し、`run` メソッドを持つクラス
**インスタンス**: 一意の ID と独立した状態を持つ単一の実行
**ステップ**: `step.do()` を介して個別に再試行できる単位 — API 呼び出し、DB クエリ、AI 呼び出し
**状態**: ステップの戻り値から永続化される。ステップ名がキャッシュキーになる

## クイックスタート

```typescript
import { WorkflowEntrypoint, WorkflowStep, WorkflowEvent } from 'cloudflare:workers';

type Env = { MY_WORKFLOW: Workflow; DB: D1Database };
type Params = { userId: string };

export class MyWorkflow extends WorkflowEntrypoint<Env, Params> {
  async run(event: WorkflowEvent<Params>, step: WorkflowStep) {
    const user = await step.do('fetch user', async () => {
      return await this.env.DB.prepare('SELECT * FROM users WHERE id = ?')
        .bind(event.params.userId).first();
    });
    
    await step.sleep('wait 7 days', '7 days');
    
    await step.do('send reminder', async () => {
      await sendEmail(user.email, 'Reminder!');
    });
  }
}
```

## 主な機能

- **耐久性**: ステップが失敗しても、成功済みのステップは再実行されない
- **再試行**: バックオフを設定可能（一定／線形／指数）
- **イベント**: Webhook や承認に `waitForEvent()` を使用（タイムアウト: 1時間〜365日）
- **スリープ**: スケジュールには `sleep()` / `sleepUntil()` を使用（最大365日）
- **並列処理**: 並行ステップには `Promise.all()` を使用
- **冪等性**: チェックしてから実行するパターン

## 読む順序

**はじめに:** configuration.md → api.md → patterns.md  
**トラブルシューティング:** gotchas.md

## このリファレンスの内容
- [configuration.md](./configuration.md) - wrangler.jsonc の設定、ステップ設定、バインディング
- [api.md](./api.md) - ステップ API、インスタンス管理、スリープ／パラメーター
- [patterns.md](./patterns.md) - 一般的なワークフロー、テスト、オーケストレーション
- [gotchas.md](./gotchas.md) - タイムアウト、制限、デバッグ方法

## 関連項目
- [durable-objects](../durable-objects/) - 代替となるステートフルな方式
- [queues](../queues/) - メッセージ駆動型ワークフロー
- [workers](../workers/) - ワークフローインスタンスのエントリーポイント