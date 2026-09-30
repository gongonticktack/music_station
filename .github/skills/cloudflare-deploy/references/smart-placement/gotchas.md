# Smart Placement の注意点

## よくあるエラー

### "INSUFFICIENT_INVOCATIONS"

**原因:** Smart Placement の分析に必要なトラフィックが不足しています
**解決策:**
- Worker が継続的にグローバルなトラフィックを受信するようにする
- さらに時間を置く（分析には最大15分かかります）
- 複数のグローバルな場所からテストトラフィックを送信する
- Worker に fetch イベントハンドラーがあることを確認する

### "UNSUPPORTED_APPLICATION"

**原因:** Smart Placement によって Worker の速度が低下しました
**理由:**
- Worker がバックエンドを呼び出していない（エッジで実行したほうが速い）
- バックエンド呼び出しがキャッシュされている（ユーザーまでのネットワーク遅延のほうが重要）
- バックエンドサービスがグローバルに適切に分散されている
- Worker が静的アセットまたは Pages のコンテンツを配信している

**解決策:**
- Smart Placement を無効にする: `{ "placement": { "mode": "off" } }`
- Worker が Smart Placement による実際のメリットを得られるか確認する
- バックエンド呼び出しを減らすキャッシュ戦略を検討する
- Pages/Assets Worker の場合は、Smart Placement を有効にした別のバックエンド Worker を使用する

### "No request duration metrics"

**原因:** Smart Placement が有効になっていない、経過時間が不十分、トラフィックが不十分、または分析が完了していません
**解決策:**
- config で Smart Placement が有効になっていることを確認する
- デプロイ後15分以上待つ
- Worker に十分なトラフィックがあることを確認する
- `placement_status` が `SUCCESS` であることを確認する

### "cf-placement header missing"

**原因:** Smart Placement が有効になっていない、ベータ機能が削除された、または Worker の分析がまだ完了していません
**解決策:** Smart Placement が有効になっていることを確認し、分析を待ち（15分）、ベータ機能がまだ利用可能か確認する

## Pages/Assets と Smart Placement によるパフォーマンス低下

**問題:** `run_worker_first = true` を有効にして Smart Placement を使うと、静的アセットの読み込みが2～5倍遅くなります。

**原因:** Smart Placement は静的アセット（HTML、CSS、JS、画像など）を含むすべてのリクエストを遠隔地にルーティングします。静的コンテンツは常にユーザーに最も近いエッジから配信する必要があります。

**解決策:** Worker を分割するか、Smart Placement を無効にします:
```jsonc
// ❌ BAD - Assets routed away from user
{
  "name": "pages-app",
  "placement": { "mode": "smart" },
  "assets": { "run_worker_first": true }
}

// ✅ GOOD - Assets at edge, API optimized
// frontend/wrangler.jsonc
{
  "name": "frontend",
  "assets": { "run_worker_first": true }
  // No placement field - stays at edge
}

// backend/wrangler.jsonc
{
  "name": "backend-api",
  "placement": { "mode": "smart" }
}
```

これは、Smart Placement の設定ミスの中でも特に多く、影響の大きいものです。

## モノリシックなフルスタック Worker

**問題:** フロントエンドとバックエンドのロジックを1つの Worker にまとめ、Smart Placement を有効にしています。

**原因:** Smart Placement はバックエンドの遅延を最適化する一方で、ユーザー向けの応答時間を増加させます。

**解決策:** 2つの Worker に分割します:
```jsonc
// frontend/wrangler.jsonc
{
  "name": "frontend",
  "placement": { "mode": "off" },  // Explicit: stay at edge
  "services": [{ "binding": "BACKEND", "service": "backend-api" }]
}

// backend/wrangler.jsonc
{
  "name": "backend-api",
  "placement": { "mode": "smart" },
  "d1_databases": [{ "binding": "DB", "database_id": "xxx" }]
}
```

## ローカル開発時の注意

**問題:** Smart Placement は `wrangler dev` では機能しません。

**説明:** Smart Placement は本番デプロイでのみ有効になり、ローカル開発では有効になりません。

**解決策:** ステージング環境で Smart Placement をテストします: `wrangler deploy --env staging`

## ベースラインのトラフィックと分析時間

**注:** 比較のため、Smart Placement は最適化なしでリクエストの1%をルーティングします（想定どおりの動作です）。

**分析時間:** 最大15分です。分析中、Worker はエッジで実行されます。`placement_status` を監視してください。

## RPC メソッドには影響しない（重要な制限）

**問題:** バックエンドで Smart Placement を有効にしたのに、RPC 呼び出しが遅いままです。

**原因:** Smart Placement の影響を受けるのは `fetch` ハンドラーだけです。RPC メソッド（`WorkerEntrypoint` を使った Service Bindings）は影響を受けません。

**理由:** RPC は `fetch` ハンドラーを経由しないため、Smart Placement がルーティングできるのは `fetch` リクエストだけです。

**解決策:** fetch ベースの Service Bindings に変換します:

```typescript
// ❌ RPC - Smart Placement has NO EFFECT
export class BackendRPC extends WorkerEntrypoint {
  async getData() {
    // ALWAYS runs at edge
    return await this.env.DATABASE.prepare('SELECT * FROM table').all();
  }
}

// ✅ Fetch - Smart Placement WORKS
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Runs close to DATABASE when Smart Placement enabled
    const data = await env.DATABASE.prepare('SELECT * FROM table').all();
    return Response.json(data);
  }
}
```

## 要件

- **Wrangler 2.20.0 以降**が必要
- 分析には**複数リージョンからの継続的なトラフィック**が必要
- **fetch ハンドラーにのみ影響**します。RPC メソッドと名前付きエントリポイントには影響しません

## 上限

| リソース/上限 | 値 | 備考 |
|----------------|-------|-------|
| 分析時間 | 最大15分 | 有効化後 |
| ベースラインのトラフィック | 1% | 最適化なしでルーティング |
| Wrangler の最小バージョン | 2.20.0 以降 | 必須 |
| トラフィック要件 | 複数リージョン | 継続的なトラフィックが必要 |

## Smart Placement を無効にする

```jsonc
{ "placement": { "mode": "off" } }  // Explicit disable
// OR remove "placement" field entirely (same effect)
```

どちらの動作も同じで、Worker はユーザーに最も近いエッジで実行されます。

## Smart Placement を使わないほうがよい場合

- 静的コンテンツまたはキャッシュ済みの応答のみを配信する Worker
- バックエンドとの通信がほとんどない Worker
- 純粋なエッジロジック（認証チェック、リダイレクト、単純な変換）
- fetch イベントハンドラーのない Worker
- `run_worker_first = true` を使う Pages/Assets Worker
- fetch ハンドラーではなく RPC メソッドを使う Worker

これらのケースでは Smart Placement のメリットがなく、パフォーマンスが低下する可能性があります。
