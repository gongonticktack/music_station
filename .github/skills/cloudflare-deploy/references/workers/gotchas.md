# Workers の落とし穴

## よくあるエラー

### 「CPU 時間を使いすぎています」

**原因:** Worker が CPU 時間の制限（標準は 10ms、アンバウンドは 30ms）を超過しました  
**解決策:** バックグラウンド処理には `ctx.waitUntil()` を使い、重い計算は Durable Objects に委譲するか、機械学習のワークロードには Workers AI を検討してください。

### 「モジュールレベルの状態が失われる」

**原因:** Workers はリクエスト間でステートレスなため、モジュールレベルの変数は予期せずリセットされます  
**解決策:** 永続状態には KV、D1、または Durable Objects を使い、モジュールレベルの変数に依存しないでください。

### 「本文はすでに使用されています」

**原因:** レスポンス本文を 2 回読み取ろうとしています（本文はストリームです）  
**解決策:** 読み取る前にレスポンスを複製します: `response.clone()`。または 1 回だけ読み取り、テキストを使って新しい Response を作成します。

### 「Node.js モジュールが見つかりません」

**原因:** Node.js の組み込み機能はデフォルトでは利用できません  
**解決策:** Workers API（例: ファイルストレージには R2）を使うか、`"compatibility_flags": ["nodejs_compat_v2"]` で Node.js 互換性を有効にしてください。

### 「グローバルスコープでは fetch を使えません」

**原因:** モジュールの初期化中に fetch を使おうとしています  
**解決策:** fetch 呼び出しを、使用が許可されているハンドラー関数（fetch、scheduled など）の中に移してください。

### 「サブリクエストの深さ制限を超えました」

**原因:** ネストされたサブリクエストが多すぎて、呼び出しチェーンが深くなっています  
**解決策:** リクエストチェーンをフラット化するか、サービスバインディングを使って Worker 間で直接通信してください。

### 「D1 の読み取り後書き込みに不整合がある」

**原因:** D1 は結果整合性であり、読み取り結果に直近の書き込みが反映されない場合があります  
**解決策:** D1 Sessions（2024 年以降）を使うと、セッション内で読み取り後書き込みの一貫性を保証できます:

```typescript
const session = env.DB.withSession();
await session.prepare('INSERT INTO users (name) VALUES (?)').bind('Alice').run();
const user = await session.prepare('SELECT * FROM users WHERE name = ?').bind('Alice').first(); // Guaranteed to see Alice
```

**セッションを使う場面:** 書き込み → 読み取りのパターン、一貫性が必要なトランザクション

### 「wrangler types で TypeScript 定義が生成されない」

**原因:** 型生成が設定されていないか、設定が古くなっています  
**解決策:** wrangler.jsonc のバインディングを変更した後に `npx wrangler types` を実行してください:

```bash
npx wrangler types  # Generates .wrangler/types/runtime.d.ts
```

`tsconfig.json` に追加: `"include": [".wrangler/types/**/*.ts"]`

次のようにインポートします: `import type { Env } from './.wrangler/types/runtime';`

### 「非推奨の fetch パターンで Durable Object の RPC エラーが発生する」

**原因:** RPC（2024 年以降）ではなく、古い `stub.fetch()` パターンを使っています  
**解決策:** メソッドを直接エクスポートし、RPC 経由で呼び出してください:

```typescript
// ❌ Old fetch pattern
export class MyDO {
  async fetch(request: Request) {
    const { method } = await request.json();
    if (method === 'increment') return new Response(String(await this.increment()));
  }
  async increment() { return ++this.value; }
}
const stub = env.DO.get(id);
const res = await stub.fetch('http://x', { method: 'POST', body: JSON.stringify({ method: 'increment' }) });

// ✅ RPC pattern (type-safe, no serialization overhead)
export class MyDO {
  async increment() { return ++this.value; }
}
const stub = env.DO.get(id);
const count = await stub.increment(); // Direct method call
```

### 「WebSocket 接続が予期せず切断される」

**原因:** WebSocket 接続を維持している間に Worker が CPU 制限に達しています  
**解決策:** WebSocket ハイバネーション（2024 年以降）を使って、アイドル状態の接続をオフロードしてください:

```typescript
export class WebSocketDO {
  async webSocketMessage(ws: WebSocket, message: string) {
    // Handle message
  }
  async webSocketClose(ws: WebSocket, code: number) {
    // Cleanup
  }
}
```

ハイバネーションは非アクティブな接続を自動的に一時停止し、イベント発生時に再開します。

### 「フレームワークのミドルウェアが Workers で動作しない」

**原因:** フレームワークが Node.js のプリミティブを前提としています（例: Express は Node のストリームを使用します）  
**解決策:** Workers ネイティブのフレームワーク（Hono、itty-router、Worktop）を使うか、ミドルウェアを適合させてください:

```typescript
// ✅ Hono (Workers-native)
import { Hono } from 'hono';
const app = new Hono();
app.use('*', async (c, next) => { /* middleware */ await next(); });
```

詳しいパターンは [frameworks.md](./frameworks.md) を参照してください。

## 制限

| 制限 | 値 | 備考 |
|-------|-------|-------|
| リクエストサイズ | 100 MB | 受信リクエストの最大サイズ |
| レスポンスサイズ | 無制限 | ストリーミングに対応 |
| CPU 時間（標準） | 10ms | 標準 Workers |
| CPU 時間（アンバウンド） | 30ms | アンバウンド Workers |
| サブリクエスト | 1000 | リクエストあたり |
| KV 読み取り | 1000 | リクエストあたり |
| KV 書き込みサイズ | 25 MB | 1 回の書き込みあたりの最大サイズ |
| 環境サイズ | 5 MB | env バインディングの合計サイズ |

## 関連項目

- [パターン](./patterns.md) - ベストプラクティス
- [API](./api.md) - ランタイム API
- [設定](./configuration.md) - セットアップ
- [フレームワーク](./frameworks.md) - Hono、ルーティング、検証
