## 重大な注意点

### ⚠️ WebSocket: fetch() と containerFetch() の使い分け

**問題:** WebSocket 接続が何も通知されずに失敗する

**原因:** `containerFetch()` は WebSocket のアップグレードに対応していない

**対処:** WebSocket には必ず `fetch()` を使う

```typescript
// ❌ WRONG
return container.containerFetch(request);

// ✅ CORRECT
return container.fetch(request);
```

### ⚠️ startAndWaitForPorts() と start() の違い

**問題:** `start()` の後に「connection refused」が発生する

**原因:** `start()` はプロセスの起動時に戻る。ポートの準備完了を待つわけではない

**対処:** リクエストを送る前に `startAndWaitForPorts()` を使う

```typescript
// ❌ WRONG
await container.start();
return container.fetch(request);

// ✅ CORRECT
await container.startAndWaitForPorts();
return container.fetch(request);
```

### ⚠️ 長時間の処理中のアクティビティタイムアウト

**問題:** 長時間の処理中にコンテナが停止する

**原因:** `sleepAfter` は内部処理ではなく、リクエストのアクティビティに基づいている

**対処:** ストレージに書き込んでタイムアウトを延長する

```typescript
const interval = setInterval(() => {
  this.ctx.storage.put("keepalive", Date.now());
}, 60000);

try {
  await this.doLongWork(data);
} finally {
  clearInterval(interval);
}
```

### ⚠️ 起動時の blockConcurrencyWhile

**問題:** 初期化中に競合状態が発生する

**対処:** 初期化をアトミックに行うため、`blockConcurrencyWhile` を使う

```typescript
await this.ctx.blockConcurrencyWhile(async () => {
  if (!this.initialized) {
    await this.startAndWaitForPorts();
    this.initialized = true;
  }
});
```

### ⚠️ ライフサイクルフックがリクエストをブロックする

**問題:** `onStart()` の実行中にコンテナが応答しなくなる

**原因:** フックは `blockConcurrencyWhile` 内で実行されるため、並行リクエストを処理できない

**対処:** フックは短時間で終わるようにし、時間のかかる処理を避ける

### ⚠️ schedule() を使う場合は alarm() をオーバーライドしない

**問題:** スケジュールされたタスクが実行されない

**原因:** `schedule()` は内部で `alarm()` を使う

**対処:** スケジュールされたタスクを処理する `alarm()` を実装する

## よくあるエラー

### 「Container start timeout」

**原因:** コンテナの起動に 8 秒（`start()`）または 20 秒（`startAndWaitForPorts()`）を超えた

**解決策:**
- イメージを最適化する（より小さいベースイメージ、より少ないレイヤー）
- `entrypoint` が正しいことを確認する
- アプリが正しいポートで待ち受けていることを確認する
- 必要に応じてタイムアウトを延長する

### 「Port not available」

**原因:** ポートの準備が整う前に `fetch()` を呼び出している

**解決策:** `startAndWaitForPorts()` を使う

### 「Container memory exceeded」

**原因:** インスタンスタイプの上限を超えるメモリを使用している

**解決策:**
- より大きいインスタンスタイプ（standard-2、standard-3、standard-4）を使う
- アプリのメモリ使用量を最適化する
- カスタムインスタンスタイプを使う

```jsonc
"instance_type_custom": {
  "vcpu": 2,
  "memory_mib": 8192
}
```

### 「Max instances reached」

**原因:** すべての `max_instances` 枠が使用中

**解決策:**
- `max_instances` を増やす
- 適切な `sleepAfter` を設定する
- 振り分けに `getRandom()` を使う
- インスタンスのリークがないか確認する

### 「No container instance available」

**原因:** アカウントの容量上限に達している

**解決策:**
- アカウントの上限を確認する
- コンテナ全体のインスタンスタイプを見直す
- Cloudflare サポートに問い合わせる

## 制限事項

| リソース | 上限 | 備考 |
|----------|-------|-------|
| コールドスタート | 2-3s | イメージはグローバルに事前取得される |
| グレースフルシャットダウン | 15 min | SIGTERM → SIGKILL |
| `start()` のタイムアウト | 8s | プロセスの起動 |
| `startAndWaitForPorts()` のタイムアウト | 20s | ポートの準備完了 |
| コンテナあたりの最大 vCPU | 4 | standard-4 または custom |
| コンテナあたりの最大メモリ | 12 GiB | standard-4 または custom |
| コンテナあたりの最大ディスク | 20 GB | 一時領域。リセットされる |
| アカウント全体のメモリ | 400 GiB | 全コンテナ合計 |
| アカウント全体の vCPU | 100 | 全コンテナ合計 |
| アカウント全体のディスク | 2 TB | 全コンテナ合計 |
| イメージストレージ | 50 GB | アカウント単位 |
| ディスクの永続化 | なし | DO ストレージを使う |

## ベストプラクティス

1. **既定では `startAndWaitForPorts()` を使う** - ポート関連のエラーを防ぐ
2. **適切な `sleepAfter` を設定する** - リソース消費とコールドスタートのバランスを取る
3. **WebSocket には `fetch()` を使う** - `containerFetch()` は使わない
4. **再起動を前提に設計する** - ディスクは一時領域のため、グレースフルシャットダウンを実装する
5. **リソースを監視する** - アカウントの上限内に収める
6. **フックを短時間で終わらせる** - `blockConcurrencyWhile` 内で実行される
7. **長時間の処理ではアクティビティを延長する** - ストレージに書き込んでタイムアウトを防ぐ

## ベータ版に関する注意事項

⚠️ Containers は**ベータ版**です:

- **API は予告なく変更される場合があります**
- **SLA による保証はありません**
- **当初は利用可能なリージョンが限られます**
- **自動スケーリングはありません** - `getRandom()` による手動対応が必要です
- **ローリングデプロイのみ**です（Workers のように即時反映されません）

API の変更に備え、本番環境に適用する前に十分にテストしてください。
