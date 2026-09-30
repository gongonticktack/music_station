# Miniflare

Cloudflare Workers の開発・テスト向けローカルシミュレーター。ランタイム API を実装した workerd サンドボックスで Workers を実行します。インターネット接続は不要です。

## 機能

- 多機能: KV、Durable Objects、R2、D1、WebSockets、Queues
- 完全ローカル: インターネット接続なしでテストでき、即座にリロード
- TypeScript ネイティブ: 詳細なログ、ソースマップ
- 高度なテスト: HTTP を介さずイベントをディスパッチし、Worker 間の接続をシミュレート

<a id="when-to-use"></a>
## 使用する場面

**Workers のテスト方法を選ぶ:**

```
Need to test Workers?
│
├─ Unit tests for business logic only?
│  └─ getPlatformProxy (Vitest/Jest) → [patterns.md](./patterns.md#getplatformproxy)
│     Fast, no HTTP, direct binding access
│
├─ Integration tests with full runtime?
│  ├─ Single Worker?
│  │  └─ Miniflare API → [Quick Start](#quick-start)
│  │     Full control, programmatic access
│  │
│  ├─ Multiple Workers + service bindings?
│  │  └─ Miniflare workers array → [configuration.md](./configuration.md#multiple-workers)
│  │     Shared storage, inter-worker calls
│  │
│  └─ Vitest test runner integration?
│     └─ vitest-pool-workers → [patterns.md](./patterns.md#vitest-pool-workers)
│        Full Workers env in Vitest
│
└─ Local dev server?
   └─ wrangler dev (not Miniflare)
      Hot reload, automatic config
```

**Miniflare を使う場面:**
- 完全な Worker ランタイムでの統合テスト
- バインディング／ストレージのローカルテスト
- サービスバインディングを使う複数の Worker
- プログラムからイベントをディスパッチ（fetch、queue、scheduled）

**getPlatformProxy を使う場面:**
- ビジネスロジックの高速な単体テスト
- HTTP のオーバーヘッドなしでのテスト
- Vitest/Jest 環境

**Wrangler を使う場面:**
- ローカル開発ワークフロー
- 本番環境へのデプロイ

## セットアップ

```bash
npm i -D miniflare
```

`package.json` で ES modules を有効にする必要があります:
```json
{"type": "module"}
```

<a id="quick-start"></a>
## クイックスタート

```js
import { Miniflare } from "miniflare";

const mf = new Miniflare({
  modules: true,
  script: `
    export default {
      async fetch(request, env, ctx) {
        return new Response("Hello Miniflare!");
      }
    }
  `,
});

const res = await mf.dispatchFetch("http://localhost:8787/");
console.log(await res.text()); // Hello Miniflare!
await mf.dispose();
```

## 読み進める順序

**Miniflare を初めて使う場合:** ここから始めましょう:
1. [クイックスタート](#quick-start) - 2 分で実行
2. [使用する場面](#when-to-use) - テスト方法を選ぶ
3. [patterns.md](./patterns.md) - テストパターン（getPlatformProxy、Vitest、node:test）
4. [configuration.md](./configuration.md) - バインディング、ストレージ、複数 Worker の設定

**トラブルシューティング:**
- [gotchas.md](./gotchas.md) - よくあるエラーとデバッグ

**API リファレンス:**
- [api.md](./api.md) - メソッドの完全なリファレンス

## 関連項目
- [wrangler](../wrangler/) - `wrangler dev` に Miniflare を組み込んだ CLI ツール
- [workerd](../workerd/) - Miniflare の基盤となるランタイム
- [workers](../workers/) - Workers ランタイム API のドキュメント
