## ベストプラクティスのまとめ

**Smart Shield に関する注意:** Argo Smart Routing は Smart Shield へと統合されつつあります。以下のベストプラクティスは引き続き適用されます。Smart Shield の更新情報は Cloudflare の変更履歴を確認してください。

1. Argo の有効化／無効化を試みる前に、必ず編集可能か確認する
2. 予期しない費用を避けるため、請求通知を設定する
3. パフォーマンス向上の効果を最大化するため、Tiered Cache と併用する
4. 本番環境でのみ使用する。費用を抑えるため、開発／ステージング環境では無効にする
5. 分析データを確認する。詳細なメトリクスには、48時間以内に500件以上のリクエストが必要
6. エラーに適切に対処する。請求、権限、ゾーンの互換性を確認する
7. 設定変更は本番環境に適用する前にステージング環境でテストする
8. 型安全性と優れた開発者体験のために TypeScript SDK を使用する
9. 本番システムでは API 呼び出しに再試行ロジックを実装する
10. チーム内で確認できるよう、ゾーン固有の設定を文書化する

## よくあるエラー

### 「Argo を利用できません」

**問題:** API がエラー「Argo Smart Routing is unavailable for this zone」を返す

**原因:** ゾーンが対象外、または請求が設定されていない

**解決方法:**
1. ゾーンのプランが Enterprise 以上であることを確認する
2. Account → Billing で請求が設定されていることを確認する
3. 支払い方法が有効で、最新の状態であることを確認する
4. 利用資格が不明な場合は Cloudflare サポートに問い合わせる

### 「有効化／無効化できない」

**問題:** API 呼び出しは成功するがステータスが変わらない、または GET レスポンスで `editable: false` となる

**原因:** 権限不足またはゾーンの制限

**解決方法:**
1. API トークンに `Zone:Argo Smart Routing:Edit` 権限があることを確認する
2. PATCH を試みる前に、GET レスポンスで `editable: true` であることを確認する
3. `editable: false` の場合は、次を確認する:
   - アカウントに請求が設定されている
   - ゾーンのプランに Argo が含まれている（Enterprise 以上）
   - ゾーンに保留や停止の措置が適用されていない
   - API トークンに適切なスコープが設定されている

### `editable: false` エラー

**問題:** GET リクエストが `"editable": false` を返し、有効化／無効化できない

**原因:** 請求、プラン、権限によるゾーン単位の制限

**解決パターン:**
```typescript
const status = await client.argo.smartRouting.get({ zone_id: zoneId });

if (!status.editable) {
  // Don't attempt to modify - will fail
  console.error('Cannot modify Argo settings:');
  console.error('- Check billing is configured');
  console.error('- Verify zone has Enterprise+ plan');
  console.error('- Confirm API token has Edit permission');
  throw new Error('Argo is not editable for this zone');
}

// Safe to proceed with enable/disable
await client.argo.smartRouting.edit({ zone_id: zoneId, value: 'on' });
```

### レート制限

**問題:** API から `429 Too Many Requests` エラーが返る

**原因:** API のレート制限を超過した（通常、5分あたり1200リクエスト）

**解決方法:**
```typescript
import { RateLimitError } from 'cloudflare';

try {
  await client.argo.smartRouting.edit({ zone_id: zoneId, value: 'on' });
} catch (error) {
  if (error instanceof RateLimitError) {
    const retryAfter = error.response?.headers.get('retry-after');
    console.log(`Rate limited. Retry after ${retryAfter} seconds`);
    
    // Implement exponential backoff
    await new Promise(resolve => setTimeout(resolve, (retryAfter || 60) * 1000));
    // Retry request
  }
}
```

## 制限事項

| リソース／制限 | 値 | 備考 |
|----------------|-------|-------|
| 分析に必要な最小リクエスト数 | 48時間以内に500件 | GraphQL 経由で詳細なメトリクスを取得する場合 |
| 対応ゾーン | Enterprise 以上 | ダッシュボードでゾーンのプランを確認 |
| 請求要件 | 設定必須 | 有効化する前に設定し、支払い方法を確認 |
| API レート制限 | 5分あたり1200リクエスト | すべてのエンドポイントを通じた API トークンごとの制限 |
| Spectrum アプリ | 固定の上限なし | 各アプリで個別に Argo を有効化可能 |
| トラフィックのカウント | プロキシ経由のみ | オレンジ色の雲が設定された DNS レコードのみが対象 |
| DDoS／WAF の免除 | あり | 軽減されたトラフィックは請求対象外 |
| 分析データの遅延 | 1～5分 | リアルタイムのメトリクスは利用不可 |

## 参考資料

- [Official Argo Smart Routing Docs](https://developers.cloudflare.com/argo-smart-routing/)
- [Cloudflare Smart Shield](https://developers.cloudflare.com/smart-shield/)
- [API Authentication](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)
- [Cloudflare TypeScript SDK](https://github.com/cloudflare/cloudflare-typescript)
- [Cloudflare Python SDK](https://github.com/cloudflare/cloudflare-python)
