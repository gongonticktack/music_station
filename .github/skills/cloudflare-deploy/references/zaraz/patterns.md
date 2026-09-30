# Zarazのパターン

## SPAのトラッキング

**History Changeトリガー（推奨）:** ダッシュボードで設定します。コードは不要で、Zarazがルートの変更を自動検出します。

**手動トラッキング（React/Vue/Next.js）：**
```javascript
// On route change
zaraz.track('pageview', { page_path: pathname, page_title: document.title });
```

## ユーザーの識別

```javascript
// Login
zaraz.set({ userId: user.id, email: user.email, plan: user.plan });
zaraz.track('login', { method: 'oauth' });

// Logout - set to null (cannot clear)
zaraz.set('userId', null);
```

## Eコマースのファネル

| イベント | 方法 |
|-------|--------|
| 表示 | `zaraz.ecommerce('Product Viewed', { product_id, name, price })` |
| カートに追加 | `zaraz.ecommerce('Product Added', { product_id, quantity })` |
| チェックアウト | `zaraz.ecommerce('Checkout Started', { cart_id, products: [...] })` |
| 購入 | `zaraz.ecommerce('Order Completed', { order_id, total, products })` |

## A/Bテスト

```javascript
zaraz.set('experiment_checkout', variant);
zaraz.track('experiment_viewed', { experiment_id: 'checkout', variant });
// On conversion
zaraz.track('experiment_conversion', { experiment_id, variant, value });
```

## Workerとの連携

**Context Enricher** - ツールの実行前にコンテキストを変更します。
```typescript
export default {
  async fetch(request, env) {
    const body = await request.json();
    body.system.userRegion = request.cf?.region;
    return Response.json(body);
  }
};
```
設定場所: Zaraz > Settings > Context Enrichers

**Worker Variables** - サーバー側で動的な値を計算し、`{{worker.variable_name}}`として使用します。

## GTMからの移行

| GTM | Zaraz |
|-----|-------|
| `dataLayer.push({event: 'purchase'})` | `zaraz.ecommerce('Order Completed', {...})` |
| `{{Page URL}}` | `{{system.page.url}}` |
| `{{Page Title}}` | `{{system.page.title}}` |
| Page Viewトリガー | Pageviewトリガー |
| Clickトリガー | Click（selector: `*`） |

## ベストプラクティス

1. インラインコードよりダッシュボードのトリガーを使用する
2. SPAではHistory Changeを有効にする（手動コードは不要）
3. `zaraz.debug = true`でデバッグする
4. 同意管理を早い段階で実装する（GDPR/CCPA）
5. 機密データやサーバー側データにはContext Enricherを使用する
