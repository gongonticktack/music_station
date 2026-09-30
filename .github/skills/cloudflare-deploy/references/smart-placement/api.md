# Smart Placement API

## Placement Status API

Cloudflare API を使って Worker の配置状況を確認します。

```bash
curl -X GET "https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/workers/services/{WORKER_NAME}" \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json"
```

レスポンスには `placement_status` フィールドが含まれます。

```typescript
type PlacementStatus = 
  | undefined  // Not yet analyzed
  | 'SUCCESS'  // Successfully optimized
  | 'INSUFFICIENT_INVOCATIONS'  // Not enough traffic
  | 'UNSUPPORTED_APPLICATION';  // Made Worker slower (reverted)
```

## ステータスの意味

**`undefined`（存在しない）**
- Worker の分析はまだ行われていません
- 常にユーザーに最も近いデフォルトのエッジロケーションで実行されます

**`SUCCESS`**
- 分析が完了し、Smart Placement が有効です
- Worker は最適なロケーション（エッジまたはリモートの場合があります）で実行されます

**`INSUFFICIENT_INVOCATIONS`**
- 配置を判断するにはリクエスト数が不足しています
- 複数リージョンから継続的にトラフィックがある必要があります
- 常にデフォルトのエッジロケーションで実行されます

**`UNSUPPORTED_APPLICATION`**（まれ、Worker の 1% 未満）
- Smart Placement により Worker の処理が遅くなりました
- 配置の判断は取り消されました
- 常にエッジロケーションで実行されます
- 再デプロイするまで再分析されません

## cf-placement ヘッダー（ベータ版）

Smart Placement はルーティングの判断を示すレスポンスヘッダーを追加します。

```typescript
// Remote placement (Smart Placement routed request)
"cf-placement: remote-LHR"  // Routed to London

// Local placement (default edge routing)  
"cf-placement: local-EWR"   // Stayed at Newark edge
```

形式: `{placement-type}-{IATA-code}`
- `remote-*` = Smart Placement によりリモートロケーションへルーティングされました
- `local-*` = デフォルトのエッジロケーションに留まりました
- IATA コード = データセンターに最も近い空港

**警告:** ベータ機能のため、一般提供（GA）前に削除される可能性があります。

## コードで Smart Placement を検出する

**注:** `cf-placement` ヘッダーはベータ機能のため、変更または削除される可能性があります。

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const placementHeader = request.headers.get('cf-placement');
    
    if (placementHeader?.startsWith('remote-')) {
      const location = placementHeader.split('-')[1];
      console.log(`Smart Placement routed to ${location}`);
    } else if (placementHeader?.startsWith('local-')) {
      const location = placementHeader.split('-')[1];
      console.log(`Running at edge location ${location}`);
    }
    
    return new Response('OK');
  }
} satisfies ExportedHandler<Env>;
```

## リクエスト時間のメトリクス

Smart Placement が有効な場合、Cloudflare ダッシュボードで確認できます。

**Workers & Pages → [Your Worker] → Metrics → Request Duration**

次の比較をヒストグラムで表示します。
- Smart Placement を使用したリクエスト時間（トラフィックの 99%）
- Smart Placement を使用しないリクエスト時間（ベースラインの 1%）

**リクエスト時間と実行時間の違い:**
- **リクエスト時間:** リクエストの到着からレスポンスの配信までの合計時間（ネットワーク遅延を含む）
- **実行時間:** Worker のコードが実際に実行されている時間（ネットワーク待ち時間を除く）

Smart Placement の影響を測定するには、リクエスト時間を使用してください。

### メトリクスの解釈

| メトリクスの比較 | 解釈 | 対応 |
|-------------------|------|------|
| WITH < WITHOUT | Smart Placement が効果を発揮 | 有効のままにする |
| WITH ≈ WITHOUT | 影響は中立 | リソースを空けるため、無効化を検討する |
| WITH > WITHOUT | Smart Placement により性能が低下 | `mode: "off"` で無効化する |

**Smart Placement によって性能が低下する可能性がある理由:**
- Worker が主に静的アセットまたはキャッシュ済みコンテンツを配信している
- バックエンドサービスがグローバルに分散している（単一の最適なロケーションがない）
- Worker とバックエンドとの通信がほとんどない
- `assets.run_worker_first = true` を使った Pages プロジェクトである

**Smart Placement が効果を発揮する場合の一般的な改善幅:**
- データベースへのアクセスが多い Worker では、リクエスト時間が 20～50% 短縮
- 複数のバックエンド API を呼び出す Worker では、30～60% 短縮
- バックエンドが地理的に集中している場合は、さらに大きく改善

## 監視用コマンド

```bash
# Tail Worker logs
wrangler tail your-worker-name

# Tail with filters
wrangler tail your-worker-name --status error
wrangler tail your-worker-name --header cf-placement

# Check placement status via API
curl -H "Authorization: Bearer $TOKEN" \
  https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/services/$WORKER_NAME \
  | jq .result.placement_status
```

## TypeScript の型

```typescript
// Placement status returned by API (field may be absent)
type PlacementStatus = 
  | 'SUCCESS'
  | 'INSUFFICIENT_INVOCATIONS'
  | 'UNSUPPORTED_APPLICATION'
  | undefined;

// Placement configuration in wrangler.jsonc
type PlacementMode = 'smart' | 'off';

interface PlacementConfig {
  mode: PlacementMode;
  // Legacy fields (deprecated/removed):
  // hint?: string;  // REMOVED - no longer supported
}

// Explicit placement (separate feature from Smart Placement)
interface ExplicitPlacementConfig {
  region?: string;
  host?: string;
  hostname?: string;
  // Cannot combine with mode field
}

// Worker metadata from API response
interface WorkerMetadata {
  placement?: PlacementConfig | ExplicitPlacementConfig;
  placement_status?: PlacementStatus;
}

// Service Binding for backend Worker
interface Env {
  BACKEND_SERVICE: Fetcher;  // Service Binding to backend Worker
  DATABASE: D1Database;
}

// Example Worker with Service Binding
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Forward to backend Worker with Smart Placement enabled
    const response = await env.BACKEND_SERVICE.fetch(request);
    return response;
  }
} satisfies ExportedHandler<Env>;
```