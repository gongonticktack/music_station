# AI Gateway のトラブルシューティング

## よくあるエラー

| エラー | 原因 | 対処法 |
|-------|-------|-----|
| 401 | `cf-aig-authorization` ヘッダーがない | CF API トークンを含むヘッダーを追加する |
| 403 | プロバイダーのキーが無効、または BYOK のキーが期限切れ | ダッシュボードでプロバイダーのキーを確認する |
| 429 | レート制限を超過した | 制限値を引き上げるか、バックオフを実装する |

### 401 エラーの対処法

```typescript
const client = new OpenAI({
  baseURL: `https://gateway.ai.cloudflare.com/v1/${accountId}/${gatewayId}/openai`,
  defaultHeaders: { 'cf-aig-authorization': `Bearer ${CF_API_TOKEN}` }
});
```

### 429 エラーの再試行パターン

```typescript
async function requestWithRetry(fn, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try { return await fn(); }
    catch (e) {
      if (e.status === 429 && i < maxRetries - 1) {
        await new Promise(r => setTimeout(r, Math.pow(2, i) * 1000));
        continue;
      }
      throw e;
    }
  }
}
```

## 注意点

| 項目 | 実際の仕様 |
|-------|---------|
| メタデータの制限 | 最大 5 項目。フラットな構造のみ（ネスト不可） |
| キャッシュキーの衝突 | 想定するレスポンスごとに一意のキーを使用する |
| BYOK と統合請求 | 併用できない |
| レート制限の適用範囲 | ユーザーごとではなくゲートウェイごと（ユーザーごとの制限には動的ルーティングを使用する） |
| ログの遅延 | 30～60 秒の遅延は通常どおり |
| ストリーミングとキャッシュ | **併用できない** |
| モデル名（統合 API） | プレフィックスが必要: `gpt-4o` ではなく `openai/gpt-4o` |

## キャッシュが機能しない場合

**原因:**
- リクエストのパラメーター（temperature など）が異なる
- ストリーミングが有効になっている
- 設定でキャッシュが無効になっている

**確認方法:** `response.headers.get('cf-aig-cache-status')` → HIT または MISS

## ログが表示されない場合

1. ログ記録が有効か確認する: ダッシュボード → ゲートウェイ → 設定
2. `cf-aig-collect-log: false` ヘッダーを削除する
3. 30～60 秒待つ
4. ログの上限（デフォルトは 1,000 万件）を確認する

## デバッグ

```bash
# Test connectivity
curl -v https://gateway.ai.cloudflare.com/v1/{account}/{gateway}/openai/models \
  -H "Authorization: Bearer $OPENAI_KEY" \
  -H "cf-aig-authorization: Bearer $CF_TOKEN"
```

```typescript
// Check response headers
console.log('Cache:', response.headers.get('cf-aig-cache-status'));
console.log('Request ID:', response.headers.get('cf-ray'));
```

## 分析

ダッシュボード → AI Gateway → ゲートウェイを選択

**指標:** リクエスト数、トークン数、レイテンシー（p50/p95/p99）、キャッシュヒット率、コスト

**ログフィルター:** `status: error`、`provider: openai`、`cost > 0.01`、`duration > 1000`

**エクスポート:** Logpush を使って S3/GCS/Datadog/Splunk に送信
