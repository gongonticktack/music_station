# 注意点とトラブルシューティング

## Miniflare の制限

**サポート対象外:**
- Analytics Engine（モックを使用）
- Cloudflare Images/Stream
- Browser Rendering API
- Tail Workers
- Workers for Platforms（一部サポート）

**本番環境との動作の違い:**
- Cloudflare のエッジではなく、ローカルで workerd を実行
- ストレージは分散型ではなく、ローカル（ファイルシステム／メモリ）
- `Request.cf` は実際のエッジデータではなく、キャッシュまたはモック
- パフォーマンスはエッジ環境と異なる
- キャッシュの実装にわずかな違いがある場合がある

## よくあるエラー

### "Cannot find module"
**原因:** モジュールパスが間違っているか、`modulesRules` が設定されていない  
**解決策:**
```js
new Miniflare({
  modules: true,
  modulesRules: [{ type: "ESModule", include: ["**/*.js"] }],
});
```

### "Data not persisting"
**原因:** 永続化パスに指定しているのがディレクトリではなくファイル  
**解決策:**
```js
kvPersist: "./data/kv",  // Directory, not file
```

### "Cannot run TypeScript"
**原因:** Miniflare は TypeScript をトランスパイルしない  
**解決策:** 先に esbuild/tsc でビルドしてから、コンパイル済みの JS を実行する

### "`request.cf` is undefined"
**原因:** CF データが設定されていない  
**解決策:**
```js
new Miniflare({ cf: true }); // Or cf: "./cf.json"
```

### "EADDRINUSE" ポート競合
**原因:** 複数のインスタンスが同じポートを使用している  
**解決策:** `dispatchFetch()`（HTTP サーバーなし）を使うか、自動割り当てには `port: 0` を指定する

### "Durable Object not found"
**原因:** クラスのエクスポート名が設定名と一致していない  
**解決策:**
```js
export class Counter {} // Must match
new Miniflare({ durableObjects: { COUNTER: "Counter" } });
```

## デバッグ

**詳細ログを有効にする:**
```js
import { Log, LogLevel } from "miniflare";
new Miniflare({ log: new Log(LogLevel.DEBUG) });
```

**Chrome DevTools:**
```js
const url = await mf.getInspectorURL();
console.log(`DevTools: ${url}`); // Open in Chrome
```

**バインディングを確認する:**
```js
const env = await mf.getBindings();
console.log(Object.keys(env));
```

**ストレージを確認する:**
```js
const ns = await mf.getKVNamespace("TEST");
const { keys } = await ns.list();
```

## ベストプラクティス

**✓ 推奨:**
- テストには `dispatchFetch()` を使う（HTTP サーバーなし）
- CI ではメモリ内ストレージを使う（persist オプションを省略）
- 分離のため、テストごとに新しいインスタンスを作成する
- インターフェースで型安全なバインディングを定義する
- クリーンアップ時に `await mf.dispose()` を呼び出す

**✗ 避ける:**
- テストでの HTTP サーバー
- クリーンアップせずにインスタンスを共有すること
- 古い互換性日付（2026 年以降を使用）

## 移行ガイド

### Miniflare 2.x から 3+ への移行

v3+ の破壊的変更:

| v2 | v3+ |
|----|-----|
| `getBindings()` は同期 | `getBindings()` は Promise を返す |
| `ready` は void | `ready` は `Promise<URL>` を返す |
| service-worker-mock | workerd ベース |
| オプションが異なる | コンストラクターを再構成 |

**移行例:**
```js
// v2
const bindings = mf.getBindings();
mf.ready; // void

// v3+
const bindings = await mf.getBindings();
const url = await mf.ready; // Promise<URL>
```

### unstable_dev から Miniflare への移行

```js
// Old (deprecated)
import { unstable_dev } from "wrangler";
const worker = await unstable_dev("src/index.ts");

// New
import { Miniflare } from "miniflare";
const mf = new Miniflare({ scriptPath: "src/index.ts" });
```

### Wrangler Dev からの移行

Miniflare は `wrangler.toml` を自動で読み込まない:

```js
// Translate manually:
new Miniflare({
  scriptPath: "dist/worker.js",
  compatibilityDate: "2026-01-01",
  kvNamespaces: ["KV"],
  bindings: { API_KEY: process.env.API_KEY },
});
```

## リソース制限

| 制限 | 値 | 備考 |
|-------|-------|-------|
| CPU 時間 | 既定で 30s | `scriptTimeout` で設定可能 |
| ストレージ | ファイルシステム | パフォーマンスはディスクにより異なる |
| メモリ | システムに依存 | 人為的な制限なし |
| Request.cf | キャッシュ／モック | ライブのエッジデータではない |

テスト例は [patterns.md](./patterns.md) を参照。