# 注意点とベストプラクティス

## フィットモード

| モード | 適した用途 | 動作 |
|------|----------|----------|
| `cover` | ヒーロー画像、サムネイル | 領域を埋め、はみ出した部分を切り抜く |
| `contain` | 商品画像、アートワーク | 画像全体を保持し、余白が追加される場合がある |
| `scale-down` | ユーザーがアップロードした画像 | 拡大しない |
| `crop` | 正確な切り抜き | 重心を使用する |
| `pad` | 固定アスペクト比 | 背景を追加する |

## フォーマットの選択

```typescript
format: 'auto' // Recommended - negotiates best format
```

**対応状況:** AVIF（Chrome 85+、Firefox 93+、Safari 16.4+）、WebP（Chrome 23+、Firefox 65+、Safari 14+）

## 品質設定

| 用途 | 品質 |
|----------|---------|
| サムネイル | 75-80 |
| 標準 | 85（デフォルト） |
| 高品質 | 90-95 |

## よくあるエラー

### 5403: "Image transformation failed"
- `width`/`height` が 12000 以下であることを確認します
- `quality` が 1-100、`dpr` が 1-3 であることを確認します
- 互換性のないオプションを組み合わせないでください

### 9413: "Rate limit exceeded"
キャッシュと指数バックオフを実装します:
```typescript
for (let i = 0; i < 3; i++) {
  try { return await env.IMAGES.input(buffer).transform({...}).output(); }
  catch { await new Promise(r => setTimeout(r, 2 ** i * 1000)); }
}
```

### 5401: "Image too large"
アップロード前に画像を前処理します（最大 100MB、12000×12000px）

### 5400: "Invalid image format"
対応形式: JPEG、PNG、GIF、WebP、AVIF、SVG

### 401/403: "Unauthorized"
API トークンに `Cloudflare Images → Edit` 権限があることを確認します

## 制限

| リソース | 上限 |
|----------|-------|
| 最大入力サイズ | 100MB |
| 最大寸法 | 12000×12000px |
| 品質の範囲 | 1-100 |
| DPR の範囲 | 1-3 |
| API レート制限 | 約1200 req/min |

## AVIF の注意点

- **エンコードが遅い**: 最初のリクエストではレイテンシが高くなる場合があります
- **ブラウザーの検出**:
```typescript
const format = /image\/avif/.test(request.headers.get('Accept') || '') ? 'avif' : 'webp';
```

## 避けるべきパターン

```typescript
// ❌ No caching - transforms every request
return env.IMAGES.input(buffer).transform({...}).output().response();

// ❌ cover without both dimensions
transform({ width: 800, fit: 'cover' })

// ✅ Always set both for cover
transform({ width: 800, height: 600, fit: 'cover' })

// ❌ Exposes API token to client
// ✅ Use Direct Creator Upload (patterns.md)
```

## デバッグ

```typescript
// Check response headers
console.log('Content-Type:', response.headers.get('Content-Type'));

// Test with curl
// curl -I "https://imagedelivery.net/{hash}/{id}/width=800,format=avif"

// Monitor logs
// npx wrangler tail
```
