# 注意点と制限

## よくあるエラー

### 「Worker が見つかりません」

**原因:** 名前空間に存在しない Worker を取得しようとしている  
**解決策:** エラーを捕捉して 404 を返します。

```typescript
try {
  const userWorker = env.DISPATCHER.get(workerName);
  return userWorker.fetch(request);
} catch (e) {
  if (e.message.startsWith("Worker not found")) {
    return new Response("Worker not found", { status: 404 });
  }
  throw e;  // Re-throw unexpected errors
}
```

### 「CPU 時間の上限を超過しました」

**原因:** ユーザー Worker が設定された CPU 時間の上限を超過した  
**解決策:** Analytics Engine で違反を記録して 429 レスポンスを返します。顧客のプランに応じて制限を調整することも検討してください。

### 「ホスト名のルーティングに関する問題」

**原因:** DNS プロキシ設定によってルーティングの問題が発生している  
**解決策:** プロキシ設定にかかわらずオレンジからオレンジへのルーティングで機能する `*/*` ワイルドルートを使用します。

### 「更新時にバインディングが失われる」

**原因:** Worker の更新時に `keep_bindings` フラグを使用していない  
**解決策:** API リクエストで `keep_bindings: true` を使用して、更新時に既存のバインディングを保持します。

### 「タグのフィルタリングが機能しない」

**原因:** タグフィルター内の特殊文字が URL エンコードされていない  
**解決策:** タグを URL エンコードし（例: `tags=production%3Ayes`）、`,` や `&` などの特殊文字は避けてください。

### 「ES Modules のデプロイに失敗する」

**原因:** ES Modules のアップロード形式が正しくない  
**解決策:** multipart 形式でアップロードし、メタデータに `main_module` を指定して、ファイルタイプを `application/javascript+module` に設定します。

### 「静的アセットのアップロードに失敗する」

**原因:** ハッシュ形式が無効、トークンの有効期限切れ、またはエンコードが正しくない  
**解決策:** ハッシュは SHA-256 の先頭 16 バイト（32 桁の 16 進数）である必要があります。セッション作成から 1 時間以内にアップロードし、アップロード完了から 1 時間以内にデプロイしてください。また、ファイルの内容を Base64 エンコードしてください。

### 「Outbound Worker が呼び出しをインターセプトしない」

**原因:** Outbound Worker は Durable Object または mTLS バインディングの fetch をインターセプトしない  
**解決策:** エグレス制御を考慮して計画してください。すべての fetch 呼び出しがインターセプトされるわけではありません。

### 「TCP ソケット接続に失敗する」

**原因:** Outbound Worker を有効にすると、TCP ソケット用の `connect()` API がブロックされる  
**解決策:** Outbound Worker がインターセプトするのは `fetch()` 呼び出しのみです。Outbound Worker の設定中は TCP ソケット接続を利用できません。TCP が必要な場合は Outbound Worker を削除するか、プロキシパターンを使用してください。

### 「API のレート制限を超過しました」

**原因:** Cloudflare API のレート制限を超過した（アカウントあたり 5 分間に 1200 リクエスト、IP あたり 1 秒間に 200 リクエスト）  
**解決策:** 指数バックオフを実装します。

```typescript
async function deployWithBackoff(deploy: () => Promise<void>, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await deploy();
    } catch (e) {
      if (e.status === 429 && i < maxRetries - 1) {
        await new Promise(r => setTimeout(r, Math.pow(2, i) * 1000));
        continue;
      }
      throw e;
    }
  }
}
```

### 「段階的デプロイはサポートされていません」

**原因:** ユーザー Workers で段階的デプロイを使用しようとした  
**解決策:** Dispatch Namespace 内の Workers では段階的デプロイはサポートされていません。すべて一度にデプロイし、dispatch worker のロジック（フィーチャーフラグ、割合ベースのルーティング）を使って段階的に展開してください。

### 「アセットセッションの有効期限が切れました」

**原因:** アップロード JWT の有効期限（1 時間）が切れた、または完了トークンの有効期限（アップロード後 1 時間）が切れた  
**解決策:** セッション作成から 1 時間以内にアセットのアップロードを完了し、アップロード完了から 1 時間以内に Worker をデプロイしてください。アップロードが大規模な場合は、ファイルをバッチ処理するか、アップロードの並列度を上げてください。

## プラットフォームの制限

| 制限 | 値 | 備考 |
|-------|-------|-------|
| 名前空間あたりの Workers 数 | 無制限 | 通常の Workers（アカウントあたり 500 個）とは異なります |
| アカウントあたりの名前空間数 | 無制限 | ベストプラクティス: 本番用 1 個 + ステージング用 1 個 |
| Worker あたりの最大タグ数 | 8 | フィルタリングと整理に使用 |
| Worker モード | 非信頼（デフォルト） | 信頼モードでない限り `request.cf` にアクセスできません |
| キャッシュ分離 | Worker ごと（非信頼モード） | 信頼モードではキーのプレフィックスを付けて共有されます |
| Durable Object 名前空間数 | 無制限 | WfP にはアカウント単位の制限なし |
| 段階的デプロイ | サポート対象外 | 一括デプロイのみ |
| `caches.default` | 無効（非信頼モード） | カスタムキーを使って Cache API を使用してください |

## アセットのアップロード制限

| 制限 | 値 | 備考 |
|-------|-------|-------|
| アップロードセッション JWT の有効期間 | 1 時間 | この時間内にアップロードを完了する必要があります |
| 完了トークンの有効期間 | 1 時間 | アップロード後、この時間内にデプロイする必要があります |
| アセットハッシュ形式 | SHA-256 の先頭 16 バイト | 32 桁の 16 進数 |
| Base64 エンコード | 必須 | バイナリファイルの場合 |

## API レート制限

| 制限の種類 | 値 | 適用範囲 |
|------------|-------|-------|
| Client API | 1200 リクエスト / 5 分 | アカウントあたり |
| Client API | 200 リクエスト / 秒 | IP アドレスあたり |
| GraphQL | クエリコストによって異なる | クエリの複雑さによる |

詳細については [Cloudflare API Rate Limits](https://developers.cloudflare.com/fundamentals/api/reference/limits/) を参照してください。

## 運用上の制限

| 操作 | 制限 | 備考 |
|-----------|-------|-------|
| CPU 時間（カスタム制限） | Workers プランの上限まで | dispatch worker で呼び出しごとに設定 |
| サブリクエスト（カスタム制限） | Workers プランの上限まで | dispatch worker で呼び出しごとに設定 |
| Outbound Worker のサブリクエスト | DO/mTLS ではインターセプトされない | 通常の fetch() 呼び出しのみ |
| Outbound Worker 使用時の TCP ソケット | 無効 | `connect()` API は使用できません |

[README.md](./README.md)、[configuration.md](./configuration.md)、[api.md](./api.md)、[patterns.md](./patterns.md) を参照してください。
