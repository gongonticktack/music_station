## ベストプラクティス

### 1. Worker を選択的に優先するルーティングを使う

`run_worker_first = true` の代わりに、配列パターンを使用します。

```jsonc
{
  "assets": {
    "run_worker_first": [
      "/api/*",           // API routes
      "/admin/*",         // Admin area
      "!/admin/assets/*"  // Except admin assets
    ]
  }
}
```

**利点:**
- Worker の呼び出し回数を削減
- コストを削減
- アセット配信のパフォーマンスを向上

### 2. ナビゲーションリクエストの最適化を活用する

SPA では `compatibility_date = "2025-04-01"` 以降を使用します。

```jsonc
{
  "compatibility_date": "2025-04-01",
  "assets": {
    "not_found_handling": "single-page-application"
  }
}
```

ナビゲーションリクエストでは Worker の呼び出しが省略され、コストが削減されます。

### 3. バインディングで型安全性を確保する

必ず環境に型を指定します。

```typescript
interface Env {
  ASSETS: Fetcher;
}
```

## よくあるエラー

### 「アセットが見つかりません」

**原因：** アセットが assets ディレクトリにない、パスが間違っている、またはアセットがデプロイされていない  
**解決策：** アセットの存在とパスの大文字・小文字を確認し、必要に応じて再デプロイします。

### 「アセットに対して Worker が呼び出されない」

**原因：** アセットが直接配信されており、`run_worker_first` が設定されていない  
**解決策：** アセットのルートを含むように `run_worker_first` パターンを設定します（configuration.md:66-106 を参照）。

### 「無料プランで 429 Too Many Requests が発生する」

**原因：** `run_worker_first` パターンが多数のリクエストで Worker を呼び出し、無料プランの上限（1 日あたり 100k リクエスト）に達している  
**解決策：** 除外パターンを使って対象を絞るか、有料プランにアップグレードします。

### 「Smart Placement によりレイテンシが増加する」

**原因：** `run_worker_first=true` と Smart Placement の組み合わせにより、すべてのリクエストが Smart Placement の単一ロケーションを経由する  
**解決策：** 選択的なパターン（配列構文）を使うか、アセットの多いアプリでは Smart Placement を無効にします。

### 「CF-Cache-Status ヘッダーが安定しない」

**原因：** プライバシー上の理由から、このヘッダーは確率的に追加される  
**解決策：** 重要なルーティングロジックで `CF-Cache-Status` に依存しないでください。ETag や age など、ほかのシグナルを使います。

### 「デプロイ中に JWT の有効期限が切れる」

**原因：** 大量のアセットのデプロイに JWT トークンの有効期間を超える時間がかかる  
**解決策：** Wrangler 4.34.0 以降に更新してトークンを自動更新するか、アセット数を減らします。

### 「'assets' と 'site' を併用できない」

**原因：** 古い `site` 設定と新しい `assets` 設定が競合している  
**解決策：** `site` から `assets` に移行します（configuration.md を参照）。wrangler.jsonc から `site` キーを削除します。

### 「デプロイ後にアセットが更新されない」

**原因：** ブラウザーまたは CDN のキャッシュにより古いアセットが配信されている  
**解決策：** 
- ブラウザーを強制再読み込みします（Cmd+Shift+R / Ctrl+F5）
- キャッシュバスティングを使用します（ハッシュ付きファイル名）
- デプロイが完了したことを確認します：`wrangler tail`

## 上限

| リソース／上限 | 無料 | 有料 | 備考 |
|----------------|------|------|-------|
| アセットの最大サイズ | 25 MiB | 25 MiB | ファイル単位 |
| アセット総数 | 20,000 | **100,000** | Wrangler 4.34.0 以降が必要（2025 年 9 月） |
| Worker 呼び出し数 | 100k/日 | 10M/月 | `run_worker_first` パターンで最適化 |
| アセットストレージ | 無制限 | 無制限 | 料金に含まれる |

### バージョン要件

| 機能 | Wrangler の最小バージョン |
|---------|--------------------------|
| ファイル数上限 100k（有料） | 4.34.0 |
| Vite プラグイン | 4.0.0 + @cloudflare/vite-plugin 1.0.0 |
| ナビゲーション最適化 | 4.0.0 + compatibility_date: "2025-04-01" |

## パフォーマンスのヒント

### 1. ハッシュ付きファイル名を使う

コンテンツハッシュ付きのファイル名で長期キャッシュを有効にします。

```
app.a3b2c1d4.js
styles.e5f6g7h8.css
```

ほとんどのバンドラー（Vite、Webpack、Parcel）はこれを自動で行います。

### 2. Worker の呼び出し回数を最小限にする

可能な場合はアセットを直接配信します。

```jsonc
{
  "assets": {
    // Only invoke Worker for dynamic routes
    "run_worker_first": ["/api/*", "/auth/*"]
  }
}
```

### 3. ブラウザーキャッシュを活用する

適切な `Cache-Control` ヘッダーを設定します。

```typescript
// Versioned assets
'Cache-Control': 'public, max-age=31536000, immutable'

// HTML (revalidate often)
'Cache-Control': 'public, max-age=0, must-revalidate'
```

実装については patterns.md:169-189 を参照してください。

### 4. .assetsignore を使う

不要なファイルを除外してアップロード時間を短縮します。

```
*.map
*.md
.DS_Store
node_modules/
```

詳細は configuration.md:107-126 を参照してください。