# 注意点とベストプラクティス

## よくあるエラー

### 「setState() が同期されない」

**原因:** 状態を直接変更しているか、変更後に `setState()` を呼び出していない  
**対策:** 常に `setState()` を使い、状態を変更せずに更新する:
```ts
// ❌ this.state.count++
// ✅ this.setState({...this.state, count: this.state.count + 1})
```

### 「メッセージ履歴が際限なく増える（AIChatAgent）」

**原因:** `AIChatAgent` の `this.messages` にすべてのメッセージが無期限に蓄積される  
**対策:** 古いメッセージを定期的に手動で削除する:
```ts
export class ChatAgent extends AIChatAgent<Env> {
  async onChatMessage(onFinish) {
    // Keep only last 50 messages
    if (this.messages.length > 50) {
      this.messages = this.messages.slice(-50);
    }
    
    return this.streamText({ model: openai("gpt-4"), messages: this.messages, onFinish });
  }
}
```

### 「SQL インジェクションの脆弱性」

**原因:** SQL クエリ内で文字列を直接補間している
**対策:** パラメータ化されたクエリを使う:
```ts
// ❌ this.sql`...WHERE id = '${userId}'`
// ✅ this.sql`...WHERE id = ${userId}`
```

### 「WebSocket 接続のタイムアウト」

**原因:** `onConnect` で `conn.accept()` を呼び出していない
**対策:** 必ず接続を受け入れる:
```ts
async onConnect(conn: Connection, ctx: ConnectionContext) { conn.accept(); conn.setState({userId: "123"}); }
```

### 「スケジュール数の上限超過」

**原因:** エージェントごとのスケジュール済みタスクが 1000 件を超えている
**対策:** 古いスケジュールを削除し、作成頻度を制限する:
```ts
async checkSchedules() { if ((await this.getSchedules()).length > 800) console.warn("Near limit!"); }
```

### 「AI Gateway が利用できない」

**原因:** AI サービスのタイムアウト、または割り当て量の超過  
**対策:** エラー処理と代替手段を追加する:
```ts
try { 
  return await this.env.AI.run(model, {prompt}); 
} catch (e) { 
  console.error("AI error:", e);
  return {error: "Unavailable"}; 
}
```

### 「@callable メソッドが undefined を返す」

**原因:** メソッドが JSON にシリアライズできる値を返していないか、シリアライズできない型を含んでいる  
**対策:** 戻り値をプレーンなオブジェクト、配列、またはプリミティブ値にする:
```ts
// ❌ Returns class instance
@callable()
async getData() { return new Date(); }

// ✅ Returns serializable object
@callable()
async getData() { return { timestamp: Date.now() }; }
```

### 「再開可能なストリームが再開されない」

**原因:** 再開を機能させるには、ストリーム ID が決定的である必要がある  
**対策:** AIChatAgent（自動処理）を使うか、ストリーム ID が一貫するようにする:
```ts
// AIChatAgent handles this automatically
export class ChatAgent extends AIChatAgent<Env> {
  // Resumption works out of the box
}
```

### 「休止状態になると MCP 接続が切れる」

**原因:** MCP サーバーへの接続は休止状態をまたいで維持されない  
**対策:** `onStart()` でサーバーを再登録するか、接続状態を確認する:
```ts
onStart() {
  // Re-register MCP servers after hibernation
  await this.mcp.registerServer("github", { url: env.MCP_URL, auth: {...} });
}
```

### 「エージェントが見つからない」

**原因:** Durable Object のバインディングがないか、クラス名が正しくない  
**対策:** wrangler.jsonc の DO バインディングとクラス名が一致することを確認する

## レート制限と割り当て量

| リソース／制限 | 値 | 備考 |
|----------------|-------|-------|
| リクエストあたりの CPU 時間 | 30 秒（標準）、300 秒（最大） | wrangler.jsonc で設定 |
| インスタンスあたりのメモリ | 128 MB | WebSocket と共有 |
| エージェントあたりのストレージ | 10 GB | SQLite ストレージ |
| スケジュール済みタスク | エージェントあたり 1000 件 | `getSchedules()` で監視 |
| WebSocket 接続 | 無制限 | メモリ制限の範囲内 |
| SQL の列数 | 100 | テーブルあたり |
| SQL の行サイズ | 2 MB | キーと値の合計 |
| WebSocket メッセージ | 32 MiB | 最大サイズ |
| DO のリクエスト数／秒 | 約 1000 | 個々の DO インスタンスあたり。必要に応じてレート制限する |
| AI Gateway（Workers AI） | モデルによって異なる | ダッシュボードで制限を確認 |
| MCP リクエスト | サーバーによって異なる | 再試行とバックオフを実装する |

## ベストプラクティス

### 状態管理
- 状態を変更せずに更新する: `setState({...this.state, key: newValue})`
- 際限なく増える配列（メッセージ、ログ）は定期的に切り詰める
- 大きなデータは状態ではなく SQL に保存する

### SQL の使用
- テーブルは `onRequest()` ではなく `onStart()` で作成する
- パラメータ化されたクエリを使う: `` sql`WHERE id = ${id}` ``（`` sql`WHERE id = '${id}'` `` は使わない）
- 頻繁に検索する列にはインデックスを付ける

### スケジューリング
- スケジュール数を監視する: `await this.getSchedules()`
- 完了したタスクをキャンセルし、1000 件の上限を超えないようにする
- 定期実行するタスクには cron 文字列を使う

### WebSocket
- `onConnect()` では必ず `conn.accept()` を呼び出す
- クライアントの切断を適切に処理する
- `this.connections` へのブロードキャストを効率的に行う

### AI との連携
- チャットインターフェースには `AIChatAgent` を使う（自動ストリーミングと再開機能）
- トークン制限を避けるため、メッセージ履歴を切り詰める
- try/catch と代替手段で AI のエラーを処理する

### 本番環境へのデプロイ
- **レート制限:** トラフィックの多いエージェント（毎秒 1000 リクエスト超）では、リクエストの流量を制御する
- **監視:** 重大なエラーを記録し、スケジュール数とストレージ使用量を監視する
- **機能の縮退:** AI サービスが停止した場合に備え、代替手段を用意する
- **メッセージの切り詰め:** AIChatAgent で履歴の最大長（例: 100 メッセージ）を適用する
- **MCP の信頼性:** 休止状態からの復帰時にサーバーを再登録し、再試行処理を実装する
