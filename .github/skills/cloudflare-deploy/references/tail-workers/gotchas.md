# Tail Workers の注意点とデバッグ

## 重大な落とし穴

### 1. `ctx.waitUntil()` を使用していない

**問題:** 非同期処理が完了しない、または Tail Worker がタイムアウトする  
**原因:** ハンドラーがすぐに終了する。待機すると処理がブロックされる  
**解決策:**

```typescript
// ❌ WRONG - fire and forget
export default {
  async tail(events) {
    fetch(endpoint, { body: JSON.stringify(events) });
  }
};

// ❌ WRONG - blocking await
export default {
  async tail(events, env, ctx) {
    await fetch(endpoint, { body: JSON.stringify(events) });
  }
};

// ✅ CORRECT
export default {
  async tail(events, env, ctx) {
    ctx.waitUntil(
      (async () => {
        await fetch(endpoint, { body: JSON.stringify(events) });
        await processMore();
      })()
    );
  }
};
```

### 2. `tail()` ハンドラーがない

**問題:** Producer のデプロイに失敗する  
**原因:** `tail_consumers` の Worker が `tail()` ハンドラーをエクスポートしていない  
**解決策:** `export default { async tail(events, env, ctx) { ... } }` を確認する

### 3. Outcome と HTTP ステータス

**問題:** 誤ったステータスでフィルタリングしている  
**原因:** `outcome` はスクリプトの実行ステータスであり、HTTP ステータスではない

```typescript
// ❌ WRONG
if (event.outcome === 500) { /* never matches */ }

// ✅ CORRECT
if (event.outcome === 'exception') { /* script threw */ }
if (event.event?.response?.status === 500) { /* HTTP 500 */ }
```

### 4. タイムスタンプの単位

**問題:** 日付が 1000 倍ずれる  
**原因:** タイムスタンプは秒ではなく、Unix エポックからのミリ秒

```typescript
// ❌ WRONG: const date = new Date(event.eventTimestamp * 1000);
// ✅ CORRECT: const date = new Date(event.eventTimestamp);
```

### 5. 型名の不一致

**問題:** `TailItem` 型を使用している  
**原因:** 古いドキュメントでは `TailItem` が使われていたが、SDK では `TraceItem` を使用する

```typescript
import type { TraceItem } from '@cloudflare/workers-types';
export default {
  async tail(events: TraceItem[], env, ctx) { /* ... */ }
};
```

### 6. ログ量が多すぎる

**問題:** 想定外の高コスト  
**原因:** Producer のすべてのリクエストで呼び出される  
**解決策:** イベントをサンプリングする

```typescript
export default {
  async tail(events, env, ctx) {
    if (Math.random() > 0.1) return;  // 10% sample
    ctx.waitUntil(sendToEndpoint(events));
  }
};
```

### 7. シリアライズの問題

**問題:** `JSON.stringify()` が失敗する  
**原因:** `log.message` はシリアライズできない値を含む `unknown[]` である  
**解決策:**

```typescript
const safePayload = events.map(e => ({
  ...e,
  logs: e.logs.map(log => ({
    ...log,
    message: log.message.map(m => {
      try { return JSON.parse(JSON.stringify(m)); }
      catch { return String(m); }
    })
  }))
}));
```

### 8. エラー処理がない

**問題:** Tail Worker がエラーを表に出さずに失敗する  
**原因:** try/catch がない  
**解決策:**

```typescript
ctx.waitUntil((async () => {
  try {
    await fetch(env.ENDPOINT, { body: JSON.stringify(events) });
  } catch (error) {
    console.error("Tail error:", error);
    await env.FALLBACK_KV.put(`failed:${Date.now()}`, JSON.stringify(events));
  }
})());
```

### 9. デプロイの順序

**問題:** Producer のデプロイに失敗する  
**原因:** Tail consumer がまだデプロイされていない  
**解決策:** Tail consumer を先にデプロイする

```bash
cd tail-worker && wrangler deploy
cd ../producer && wrangler deploy
```

### 10. イベントの再試行がない

**問題:** ハンドラーが失敗するとイベントが失われる  
**原因:** 失敗した呼び出しは再試行されない  
**解決策:** フォールバック用ストレージを実装する（#8 を参照）

## デバッグ

**ログを表示:** `wrangler tail my-tail-worker`

**段階的なテスト:**
1. 受信を確認する: `console.log('Events:', events.length)`
2. 構造を調べる: `console.log(JSON.stringify(events[0], null, 2))`
3. `ctx.waitUntil()` を使って外部呼び出しを追加する

**ダッシュボードを監視:** 呼び出し回数（Producer と一致するか）、エラー率、CPU 時間を確認する

## テスト

Producer にテスト用エンドポイントを追加する:

```typescript
export default {
  async fetch(request) {
    if (request.url.includes('/test')) {
      console.log('Test log');
      throw new Error('Test error');
    }
    return new Response('OK');
  }
};
```

トリガー: `curl https://producer.example.workers.dev/test`

## よくあるエラー

| エラー | 原因 | 解決策 |
|-------|-------|----------|
| "Tail consumer not found" | 未デプロイ | Tail Worker を先にデプロイする |
| "No tail handler" | `tail()` がない | default export に追加する |
| "waitUntil is not a function" | `ctx` がない | `ctx` パラメーターを追加する |
| タイムアウト | await によるブロック | `ctx.waitUntil()` を使用する |

## パフォーマンスに関する注意

- 1 回の呼び出しあたり最大 100 イベント
- 各 consumer はすべてのイベントを個別に受信する
- CPU 制限は通常の Workers と同じ
- 大量のイベントには Durable Objects によるバッチ処理を使用する
