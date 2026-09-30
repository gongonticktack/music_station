# Smart Placement の設定

## wrangler.jsonc の設定

```jsonc
{
  "$schema": "./node_modules/wrangler/config-schema.json",
  "placement": {
    "mode": "smart"
  }
}
```

## Placement Mode の値

| モード | 動作 |
|------|----------|
| `"smart"` | Smart Placement を有効化します。トラフィック分析に基づいて自動で最適化します |
| `"off"` | Smart Placement を明示的に無効化します。常にユーザーに最も近いエッジで実行します |
| 未指定 | デフォルトの動作です。ユーザーに最も近いエッジで実行します（`"off"` と同じ） |

**注:** Smart Placement と Explicit Placement は別の機能です。Smart Placement（`mode: "smart"`）は自動分析を使用します。手動で配置を制御する方法については、Explicit Placement のオプション（`region`、`host`、`hostname` フィールド。このリファレンスでは扱いません）を参照してください。

## フロントエンドとバックエンドを分ける設定

### フロントエンド Worker（Smart Placement なし）

```jsonc
// frontend-worker/wrangler.jsonc
{
  "name": "frontend",
  "main": "frontend-worker.ts",
  // No "placement" - runs at edge
  "services": [
    {
      "binding": "BACKEND",
      "service": "backend-api"
    }
  ]
}
```

### バックエンド Worker（Smart Placement 有効）

```jsonc
// backend-api/wrangler.jsonc
{
  "name": "backend-api",
  "main": "backend-worker.ts",
  "placement": {
    "mode": "smart"
  },
  "d1_databases": [
    {
      "binding": "DATABASE",
      "database_id": "xxx"
    }
  ]
}
```

## 要件と制限事項

### 要件
- **Wrangler のバージョン:** 2.20.0 以降
- **分析時間:** 最大 15 分
- **トラフィック要件:** 複数ロケーションから継続的にトラフィックがあること
- **Workers プラン:** すべてのプラン（Free、Paid、Enterprise）

### Smart Placement が影響する対象

**重大な制限事項 - Smart Placement が影響するのは `fetch` ハンドラーのみです:**

Smart Placement は、デフォルトの `fetch` ハンドラーを持つ Worker にしか適用されません。これは重要なアーキテクチャ上の制約です。

- ✅ **影響する対象:** `fetch` イベントハンドラーのみ（デフォルトエクスポートの fetch メソッド）
- ❌ **影響しない対象:** 
  - RPC メソッド（`WorkerEntrypoint` を使う Service Bindings。下の例を参照）
  - 名前付きエントリーポイント（`default` 以外のエクスポート）
  - `fetch` ハンドラーを持たない Worker
  - Queue consumer、スケジュール実行ハンドラー、その他のイベント種別

**例 - Smart Placement が影響するのは `fetch` のみ:**
```typescript
// ✅ Smart Placement affects this:
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // This runs close to backend when Smart Placement enabled
    const data = await env.DATABASE.prepare('SELECT * FROM users').all();
    return Response.json(data);
  }
}

// ❌ Smart Placement DOES NOT affect these:
export class MyRPC extends WorkerEntrypoint {
  async myMethod() { 
    // This ALWAYS runs at edge, Smart Placement has NO EFFECT
    const data = await this.env.DATABASE.prepare('SELECT * FROM users').all();
    return data;
  }
}

export async function scheduled(event: ScheduledEvent, env: Env) {
  // NOT affected by Smart Placement
}
```

**その結果:** バックエンドロジックで RPC メソッド（`WorkerEntrypoint`）を使っている場合、Smart Placement ではそれらの呼び出しを最適化できません。Smart Placement を機能させるには、fetch ベースのパターンを使う必要があります。

**解決策:** RPC メソッドを fetch エンドポイントに変換するか、`fetch` ハンドラーを持つラッパー Worker からバックエンドの RPC を呼び出します（ただし、これにより遅延が増加します）。

### ベースラインのトラフィック
Smart Placement は、パフォーマンス比較のベースラインとして、最適化を行わないリクエストを自動で 1% ルーティングします。

### 検証ルール

**同時に指定できないフィールド:**
- `mode` は Explicit Placement のフィールド（`region`、`host`、`hostname`）と併用できません
- Smart Placement と Explicit Placement のどちらか一方を選択してください。両方は使用できません

```jsonc
// ✅ Valid - Smart Placement
{ "placement": { "mode": "smart" } }

// ✅ Valid - Explicit Placement (different feature)
{ "placement": { "region": "us-east1" } }

// ❌ Invalid - Cannot combine
{ "placement": { "mode": "smart", "region": "us-east1" } }
```

## ダッシュボードでの設定

**Workers & Pages** → Worker を選択 → **Settings** → **General** → **Placement: Smart** → 15 分待つ → **Metrics** を確認

## TypeScript の型

```typescript
interface Env {
  BACKEND: Fetcher;
  DATABASE: D1Database;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const data = await env.DATABASE.prepare('SELECT * FROM table').all();
    return Response.json(data);
  }
} satisfies ExportedHandler<Env>;
```

## Cloudflare Pages と Assets に関する警告

**重大なパフォーマンス問題:** Pages プロジェクトで `assets.run_worker_first = true` を有効にすると、アセット配信のパフォーマンスが**大幅に低下します**。これは特によくある設定ミスのひとつです。

**問題となる理由:**
- Smart Placement は静的アセットを含むすべてのリクエストを、エッジからリモートロケーションへルーティングします
- 静的アセット（HTML、CSS、JS、画像）は、常にユーザーに最も近いエッジから配信する必要があります
- 結果としてアセットの読み込みが 2～5 倍遅くなり、ユーザー体験が損なわれます

**問題:** Smart Placement はアセットリクエストをエッジから離れた場所へルーティングしますが、静的アセットは常にユーザーに最も近いエッジから配信する必要があります。

**解決策（推奨順）:**
1. **推奨:** Worker を分割します（フロントエンドはエッジで実行し、バックエンドでは Smart Placement を使用）
2. `"mode": "off"` を設定し、Pages/Assets Worker で Smart Placement を明示的に無効化します
3. `assets.run_worker_first = false` を使用します（アセットを先に配信し、静的コンテンツについては Worker を経由しません）

```jsonc
// ❌ BAD - Degrades asset performance by 2-5x
{
  "name": "pages-app",
  "placement": { "mode": "smart" },
  "assets": { "run_worker_first": true }
}

// ✅ GOOD - Frontend at edge, backend optimized
// frontend-worker/wrangler.jsonc
{
  "name": "frontend",
  "assets": { "run_worker_first": true }
  // No placement - runs at edge
}

// backend-worker/wrangler.jsonc
{
  "name": "backend-api",
  "placement": { "mode": "smart" },
  "d1_databases": [{ "binding": "DB", "database_id": "xxx" }]
}
```

**要点:** `run_worker_first = true` を使って静的アセットを配信する Worker では、Smart Placement を有効にしないでください。

## ローカル開発

Smart Placement は `wrangler dev`（ローカルのみ）では機能しません。デプロイしてテストしてください: `wrangler deploy --env staging`