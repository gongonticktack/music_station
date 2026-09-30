# Cloudflare Tail Workers

ロギング、デバッグ、分析、可観測性のために、Producer Worker から実行イベントを受け取る専用 Worker です。

## このリファレンスを使用する場面

- Cloudflare Workers の可観測性やロギングを実装する
- Worker の実行イベント、ログ、例外を処理する
- カスタム分析やエラー追跡を構築する
- リアルタイムのイベントストリーミングを設定する
- tail ハンドラーまたは tail consumer を使用する

## 基本概念

### Tail Workers とは？

Tail Worker は、Producer Worker（監視対象の Worker）からのイベントを自動的に処理します。次の情報を受け取ります:
- HTTP リクエストとレスポンスの情報
- コンソールログ（`console.log/error/warn/debug`）
- キャッチされなかった例外
- 実行結果（`ok`、`exception`、`exceededCpu` など）
- 診断チャネルのイベント

**主な特徴:**
- Producer の実行完了後に呼び出される
- Service Bindings や Dynamic Dispatch のサブリクエストを含む、リクエスト全体のライフサイクルを記録する
- リクエスト数ではなく CPU 時間に基づいて課金される
- Workers Paid および Enterprise プランで利用できる

### 代替手段: OpenTelemetry エクスポート

**Tail Workers を使う前に、OpenTelemetry を検討してください:**

可観測性ツール（Sentry、Grafana、Honeycomb）へのバッチエクスポートには:
- OTEL エクスポートはログやトレースをバッチで送信する（より効率的）
- 人気のプラットフォームとの組み込み統合がある
- Tail Workers よりオーバーヘッドが小さい
- **カスタムのリアルタイム処理に限り Tail Workers を使用する**

## 判断フロー

```
Need observability for Workers?
├─ Batch export to known tools (Sentry/Grafana/Honeycomb)?
│  └─ Use OpenTelemetry export (not Tail Workers)
├─ Custom real-time processing needed?
│  ├─ Aggregated metrics?
│  │  └─ Use Tail Worker + Analytics Engine
│  ├─ Error tracking?
│  │  └─ Use Tail Worker + external service
│  ├─ Custom logging/debugging?
│  │  └─ Use Tail Worker + KV/HTTP endpoint
│  └─ Complex event processing?
│     └─ Use Tail Worker + Durable Objects
└─ Quick debugging?
   └─ Use `wrangler tail` (different from Tail Workers)
```

## 読む順序

1. **[configuration.md](configuration.md)** - Tail Workers を設定する
2. **[api.md](api.md)** - ハンドラーのシグネチャ、型、秘匿化
3. **[patterns.md](patterns.md)** - よくあるユースケースと統合
4. **[gotchas.md](gotchas.md)** - 落とし穴とデバッグのヒント

## 簡単な例

```typescript
export default {
  async tail(events, env, ctx) {
    // Process events from producer Worker
    ctx.waitUntil(
      fetch(env.LOG_ENDPOINT, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(events),
      })
    );
  }
};
```

## 関連スキル

- **observability** - Workers の一般的な可観測性パターン、OTEL エクスポート
- **analytics-engine** - tail イベントデータ用の集約メトリクスストレージ
- **durable-objects** - ステートフルなイベント処理、tail イベントのバッチ処理
- **logpush** - バッチログエクスポートの代替手段（リアルタイムではない）
- **workers-for-platforms** - tail consumer を使った動的ディスパッチ
