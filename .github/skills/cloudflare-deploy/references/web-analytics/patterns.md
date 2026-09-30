# Web Analytics のパターン

## Core Web Vitals のデバッグ

ダッシュボード → Core Web Vitals → 指標をクリック → Debug View に問題のある上位 5 要素が表示されます。

### LCP の修正

```html
<!-- Priority hints -->
<img src="hero.jpg" loading="eager" fetchpriority="high" />
<link rel="preload" as="image" href="/hero.jpg" fetchpriority="high" />
```

### CLS の修正

```css
/* Reserve space */
.ad-container { min-height: 250px; }
img { width: 400px; height: 300px; } /* Explicit dimensions */
```

### INP の修正

```typescript
// Debounce expensive operations
const handleInput = debounce(search, 300);

// Yield to main thread
await task(); await new Promise(r => setTimeout(r, 0)); await task2();

// Move to Web Worker for heavy computation
```

| 指標 | 良好 | 不良 |
|--------|------|------|
| LCP | ≤2.5s | >4s |
| INP | ≤200ms | >500ms |
| CLS | ≤0.1 | >0.25 |

## GDPR に基づく同意

```typescript
// Load beacon only after consent
const consent = localStorage.getItem('analytics-consent');
if (consent === 'accepted') {
  const script = document.createElement('script');
  script.src = 'https://static.cloudflareinsights.com/beacon.min.js';
  script.setAttribute('data-cf-beacon', '{"token": "TOKEN", "spa": true}');
  document.body.appendChild(script);
}
```

別の方法: ダッシュボード → 「有効（EU の訪問者データを除外）」

## SPA のナビゲーション

```html
<!-- REQUIRED for React/Vue/etc routing -->
<script data-cf-beacon='{"token": "TOKEN", "spa": true}' ...></script>
```

`spa: true` がない場合、初回のページ読み込みしかトラッキングされません。

## ステージング環境と本番環境の分離

```typescript
// Use env-specific tokens
const token = process.env.NEXT_PUBLIC_CF_ANALYTICS_TOKEN;
// .env.production: production token
// .env.staging: staging token (or empty to disable)
```

## ボットのフィルタリング

ダッシュボード → Filters → 「ボットのトラフィックを除外」

フィルター対象: 検索クローラー、監視サービス、既知のボット。  
フィルター対象外: ヘッドレスブラウザー（Playwright/Puppeteer）。

## 広告ブロッカーの影響

ユーザーの約 25～40% が `cloudflareinsights.com` をブロックする可能性があります。公式の回避策はありません。
ダッシュボードには最低限のベースラインが表示されます。全体像を把握するにはサーバーログを使用してください。

## 制限事項

- UTM パラメーターのトラッキングなし
- Webhook/アラート/API なし
- カスタムビーコンドメインなし
- 非プロキシ経由のサイトは最大 10 件
