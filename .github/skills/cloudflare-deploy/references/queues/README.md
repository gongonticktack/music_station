# Cloudflare Queues

少なくとも1回の配信を保証し、バッチ処理を設定できる、非同期タスク処理向けの柔軟なメッセージキューです。

## 概要

Queuesが提供する機能:
- 少なくとも1回の配信保証
- プッシュ型（Worker）とプル型（HTTP）のコンシューマー
- 設定可能なバッチ処理と再試行
- デッドレターキュー（DLQ）
- 最大12時間の遅延

**ユースケース:** 非同期処理、APIのバッファリング、レート制限、イベントワークフロー、遅延ジョブ

## クイックスタート

```bash
wrangler queues create my-queue
wrangler queues consumer add my-queue my-worker
```

```typescript
// Producer
await env.MY_QUEUE.send({ userId: 123, action: 'notify' });

// Consumer (with proper error handling)
export default {
  async queue(batch: MessageBatch, env: Env): Promise<void> {
    for (const msg of batch.messages) {
      try {
        await process(msg.body);
        msg.ack();
      } catch (error) {
        msg.retry({ delaySeconds: 60 });
      }
    }
  }
};
```

## 重大な警告

**Queuesを使用する前に、本番環境でよくある次の失敗を理解してください:**

1. **捕捉されないエラーがあると、失敗したメッセージだけでなくバッチ全体が再試行されます。** メッセージごとに必ずtry/catchを使用してください。
2. **ackもretryもされていないメッセージは、max_retriesに達するまで自動的に何度も再試行されます。** 各メッセージを必ず明示的に処理してください。

詳しい解決方法は[gotchas.md](./gotchas.md)を参照してください。

## 主な操作

| 操作 | 目的 | 上限 |
|-----------|---------|-------|
| `send(body, options?)` | メッセージを公開 | 128 KB |
| `sendBatch(messages)` | 一括公開 | 100件/256 KB |
| `message.ack()` | 成功を確認応答 | - |
| `message.retry(options?)` | 遅延を指定して再試行 | - |
| `batch.ackAll()` | バッチ全体を確認応答 | - |

## アーキテクチャ

```
[Producer Worker] → [Queue] → [Consumer Worker/HTTP] → [Processing]
```

- アカウントあたり最大10,000個のキュー
- キューあたり毎秒5,000件のメッセージ
- 保持期間は4～14日（設定可能）

## 推奨される読み進め方

**Queuesを初めて使う方:** まずはこちらを読んでください。
1. [configuration.md](./configuration.md) - キュー、バインディング、コンシューマーの設定
2. [api.md](./api.md) - メッセージの送信、バッチの処理、ack/retryのパターン
3. [patterns.md](./patterns.md) - 実例と統合方法
4. [gotchas.md](./gotchas.md) - 重大な警告とトラブルシューティング

**タスク別の参照先:**
- キューを設定する → [configuration.md](./configuration.md)
- メッセージを送受信する → [api.md](./api.md)
- 特定のパターンを実装する → [patterns.md](./patterns.md)
- デバッグやトラブルシューティングを行う → [gotchas.md](./gotchas.md)

## このリファレンスの内容

- [configuration.md](./configuration.md) - wrangler.jsoncの設定、プロデューサー/コンシューマーの設定、DLQ、コンテンツタイプ
- [api.md](./api.md) - 送信/バッチメソッド、キューハンドラー、ack/retryのルール、型安全なパターン
- [patterns.md](./patterns.md) - 非同期タスク、バッファリング、レート制限、D1/Workflows/DOとの統合
- [gotchas.md](./gotchas.md) - バッチのエラー処理、冪等性、エラー分類に関する重大な注意点

## 関連項目

- [workers](../workers/) - プロデューサー/コンシューマー向けのWorkerランタイム
- [r2](../r2/) - キュー経由でR2のイベント通知を処理
- [d1](../d1/) - キューコンシューマーからD1へのバッチ書き込み