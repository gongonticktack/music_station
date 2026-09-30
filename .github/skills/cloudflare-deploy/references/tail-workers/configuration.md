# Tail Workers の設定

## セットアップ手順

### 1. Tail Worker を作成する

`tail()` ハンドラーを持つ Worker を作成します。

```typescript
export default {
  async tail(events, env, ctx) {
    // Process events from producer Worker
    ctx.waitUntil(
      fetch(env.LOG_ENDPOINT, {
        method: "POST",
        body: JSON.stringify(events),
      })
    );
  }
};
```

### 2. プロデューサー Worker を設定する

プロデューサーの `wrangler.jsonc` で設定します。

```jsonc
{
  "name": "my-producer-worker",
  "tail_consumers": [
    {
      "service": "my-tail-worker"
    }
  ]
}
```

### 3. 両方の Worker をデプロイする

```bash
# Deploy Tail Worker first
cd tail-worker
wrangler deploy

# Then deploy producer Worker
cd ../producer-worker
wrangler deploy
```

## Wrangler の設定

### Tail コンシューマーが1つの場合

```jsonc
{
  "name": "producer-worker",
  "tail_consumers": [
    {
      "service": "logging-tail-worker"
    }
  ]
}
```

### Tail コンシューマーが複数の場合

```jsonc
{
  "name": "producer-worker",
  "tail_consumers": [
    {
      "service": "logging-tail-worker"
    },
    {
      "service": "metrics-tail-worker"
    }
  ]
}
```

**注:** 各コンシューマーは、すべてのイベントを個別に受信します。

### Tail コンシューマーを削除する

```jsonc
{
  "tail_consumers": []
}
```

その後、プロデューサー Worker を再デプロイします。

## 環境変数

Tail Workers では、通常の Workers と同じバインディング構文を使用します。

```jsonc
{
  "name": "my-tail-worker",
  "vars": {
    "LOG_ENDPOINT": "https://logs.example.com/ingest"
  },
  "kv_namespaces": [
    {
      "binding": "LOGS_KV",
      "id": "abc123..."
    }
  ]
}
```

## テストと開発

### ローカルテスト

**Tail Workers は `wrangler dev` で完全にはテストできません。** テストにはステージング環境へデプロイしてください。

### テスト戦略

1. プロデューサー Worker をステージング環境へデプロイする
2. Tail Worker をステージング環境へデプロイする
3. プロデューサーで `tail_consumers` を設定する
4. プロデューサー Worker へのリクエストを発生させる
5. Tail Worker がイベントを受信することを確認する（送信先のログまたはストレージを確認）

### Wrangler の tail コマンド

```bash
# Stream logs to terminal (NOT Tail Workers)
wrangler tail my-producer-worker
```

**これは Tail Workers とは異なります:**
- `wrangler tail` はログをターミナルにストリーミングします
- Tail Workers は、イベントをプログラムで処理する Worker です

## デプロイ前チェックリスト

- [ ] Tail Worker に `tail()` ハンドラーがある
- [ ] プロデューサーより先に Tail Worker をデプロイしている
- [ ] プロデューサーの `wrangler.jsonc` に正しい `tail_consumers` が設定されている
- [ ] 環境変数が設定されている
- [ ] ステージング環境でテスト済み
- [ ] Tail Worker 自体の監視が設定されている

## 制限事項

| 制限 | 値 | 備考 |
|-------|-------|-------|
| プロデューサーあたりの Tail コンシューマーの最大数 | 10 | 各コンシューマーはすべてのイベントを個別に受信 |
| イベントのバッチサイズ | 呼び出しあたり最大100件 | これを超えるバッチは複数の呼び出しに分割 |
| Tail Worker の CPU 時間 | 通常の Workers と同じ | 10ms（無料）、30ms（有料）、50ms（有料バンドル） |
| 料金プラン | Workers Paid または Enterprise | 無料プランでは利用不可 |
| リクエスト本文のサイズ | 最大100 MB | 外部エンドポイントへ送信する場合 |
| イベントの保持 | なし | Tail ハンドラーが失敗してもイベントは再試行されない |

## Workers for Platforms

動的ディスパッチ Worker では、ディスパッチとユーザー Worker の両方のイベントが Tail コンシューマーに送信されます。

```jsonc
{
  "name": "dispatch-worker",
  "tail_consumers": [
    {
      "service": "platform-tail-worker"
    }
  ]
}
```

Tail Worker は、リクエストごとに2つの `TraceItem` 要素を受信します:
1. 動的ディスパッチ Worker のイベント
2. ユーザー Worker のイベント

処理方法については [patterns.md](patterns.md) を参照してください。