# Cloudflare Workers Smart Placement

エンドユーザーではなくバックエンドインフラに近い場所で Workers を実行し、レイテンシを最小限に抑えるためのワークロード配置の自動最適化。

## 基本概念

Smart Placement は、Cloudflare のグローバルネットワーク全体で Worker のリクエスト処理時間を自動分析し、最適なデータセンターの場所へリクエストをインテリジェントにルーティングします。エンドユーザーに最も近い場所を既定とする代わりに、リクエスト全体の処理時間を短縮できる場合は、バックエンドインフラに近い場所へリクエストを転送できます。

### 使用する場面

**次の場合は Smart Placement を有効にします:**
- Worker がバックエンドサービスやデータベースへの往復通信を複数回行う
- バックエンドインフラが地理的に集中している
- リクエスト処理時間の大部分を、ユーザーからのネットワークレイテンシではなくバックエンドのレイテンシが占める
- Workers でバックエンドロジックを実行する（API、データ集約、DB 呼び出しを伴う SSR）
- Worker が `fetch` ハンドラーを使用する（RPC メソッドではない）

**次の場合は有効にしないでください:**
- 静的コンテンツまたはキャッシュ済みレスポンスのみを配信する Workers
- バックエンドとの通信がほとんどない Workers
- 純粋なエッジロジック（認証チェック、リダイレクト、単純な変換）
- fetch イベントハンドラーのない Workers
- RPC メソッドまたは名前付きエントリポイントを持つ Workers（影響を受けるのは `fetch` ハンドラーのみ）
- `run_worker_first = true` を使用する Pages/Assets Workers（アセット配信の性能が低下します）

### 判断フロー

```
Does your Worker have a fetch handler?
├─ No → Smart Placement won't work (skip)
└─ Yes
   │
   Does it make multiple backend calls (DB/API)?
   ├─ No → Don't enable (won't help)
   └─ Yes
      │
      Is backend geographically concentrated?
      ├─ No (globally distributed) → Probably won't help
      └─ Yes or uncertain
         │
         Does it serve static assets with run_worker_first=true?
         ├─ Yes → Don't enable (will hurt performance)
         └─ No → Enable Smart Placement
            │
            After 15min, check placement_status
            ├─ SUCCESS → Monitor metrics
            ├─ INSUFFICIENT_INVOCATIONS → Need more traffic
            └─ UNSUPPORTED_APPLICATION → Disable (hurting performance)
```

### 主なアーキテクチャパターン

**推奨:** フルスタックアプリケーションを個別の Workers に分割します:
```
User → Frontend Worker (at edge, close to user)
         ↓ Service Binding
       Backend Worker (Smart Placement enabled, close to DB/API)
         ↓
       Database/Backend Service
```

これにより、高速で応答性の高いフロントエンドを維持しながら、バックエンドのレイテンシを最適化できます。

## クイックスタート

```jsonc
// wrangler.jsonc
{
  "placement": {
    "mode": "smart"  // or "off" to explicitly disable
  }
}
```

デプロイ後、分析が完了するまで 15 分待ちます。API またはダッシュボードのメトリクスでステータスを確認します。

**無効にするには:** `"mode": "off"` を設定するか、`placement` フィールドを完全に削除します（どちらも同じです）。

## 要件

- Wrangler 2.20.0 以降
- 分析時間: 有効化後、最大 15 分
- トラフィック要件: 複数のグローバルな場所から継続的にトラフィックがあること
- すべての Workers プラン（Free、Paid、Enterprise）で利用可能

## 配置ステータスの値

```typescript
type PlacementStatus = 
  | undefined  // Not yet analyzed
  | 'SUCCESS'  // Successfully optimized
  | 'INSUFFICIENT_INVOCATIONS'  // Not enough traffic
  | 'UNSUPPORTED_APPLICATION';  // Made Worker slower (reverted)
```

## CLI コマンド

```bash
# Deploy with Smart Placement
wrangler deploy

# Check placement status
curl -H "Authorization: Bearer $TOKEN" \
  https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/workers/services/$WORKER_NAME \
  | jq .result.placement_status

# Monitor
wrangler tail your-worker-name --header cf-placement
```

## 読む順序

**初めての方:** こちらから始めてください:
1. この README - 基本概念と Smart Placement を使う場面を理解する
2. [configuration.md](./configuration.md) - wrangler.jsonc を設定し、制限事項を理解する
3. [patterns.md](./patterns.md) - 用途に合った実践例を確認する
4. [api.md](./api.md) - Smart Placement の動作を監視、確認する
5. [gotchas.md](./gotchas.md) - よくある問題をトラブルシューティングする

**すぐに調べる:**
- 「Smart Placement を有効にすべきか？」 → 上記の「使用する場面」を参照
- 「設定方法は？」 → [configuration.md](./configuration.md)
- 「フロントエンドとバックエンドを分割するには？」 → [patterns.md](./patterns.md)
- 「動作しないのはなぜ？」 → [gotchas.md](./gotchas.md)

## このリファレンスの内容

- [configuration.md](./configuration.md) - wrangler.jsonc の設定、モード値、検証ルール
- [api.md](./api.md) - Placement Status API、cf-placement ヘッダー、監視
- [patterns.md](./patterns.md) - フロントエンドとバックエンドの分割、データベース Worker、SSR パターン
- [gotchas.md](./gotchas.md) - INSUFFICIENT_INVOCATIONS のトラブルシューティング、パフォーマンスの問題

## 関連項目

- [workers](../workers/) - Worker ランタイムと fetch ハンドラー
- [d1](../d1/) - Smart Placement のメリットを得られる D1 データベース
- [durable-objects](../durable-objects/) - バックエンドロジックを含む Durable Objects
- [bindings](../bindings/) - フロントエンドとバックエンドの分割に使うサービスバインディング
