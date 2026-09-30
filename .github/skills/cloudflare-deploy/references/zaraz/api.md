# Zaraz Web API

イベントの追跡、プロパティの設定、同意の管理を行うクライアント側 JavaScript API。

## zaraz.track()

```javascript
zaraz.track('button_click');
zaraz.track('purchase', { value: 99.99, currency: 'USD', item_id: '12345' });
zaraz.track('pageview', { page_path: '/products', page_title: 'Products' }); // SPA
```

**パラメーター:** `eventName`（文字列）、`properties`（オブジェクト、省略可）。呼び出し後は結果を待たずに処理を続行します。

## zaraz.set()

```javascript
zaraz.set('userId', 'user_12345');
zaraz.set({ email: '[email protected]', plan: 'premium', country: 'US' });
```

プロパティはページセッション中に保持されます。ユーザーの識別やセグメント分けに使用します。

## zaraz.ecommerce()

```javascript
zaraz.ecommerce('Product Viewed', { product_id: 'SKU123', name: 'Widget', price: 49.99 });
zaraz.ecommerce('Product Added', { product_id: 'SKU123', quantity: 2, price: 49.99 });
zaraz.ecommerce('Order Completed', {
  order_id: 'ORD-789', total: 149.98, currency: 'USD',
  products: [{ product_id: 'SKU123', quantity: 2, price: 49.99 }]
});
```

**イベント:** `Product Viewed`、`Product Added`、`Product Removed`、`Cart Viewed`、`Checkout Started`、`Order Completed`

ツールは GA4、Facebook CAPI などに自動マッピングされます。

## システムプロパティ（トリガー）

```
{{system.page.url}}   {{system.page.title}}   {{system.page.referrer}}
{{system.device.ip}}  {{system.device.userAgent}}  {{system.device.language}}
{{system.cookies.name}}  {{client.__zarazTrack.userId}}
```

## zaraz.consent

```javascript
// Check
const purposes = zaraz.consent.getAll(); // { analytics: true, marketing: false }

// Set
zaraz.consent.modal = true; // Show modal
zaraz.consent.setAll({ analytics: true, marketing: false });
zaraz.consent.set('marketing', true);

// Listen
zaraz.consent.addEventListener('consentChanged', () => {
  if (zaraz.consent.getAll().marketing) zaraz.track('marketing_consent_granted');
});
```

**手順:** ダッシュボードで目的を設定 → ツールを目的にマッピング → モーダルを表示するか、プログラムで設定 → 許可されるとツールが実行される

## zaraz.debug

```javascript
zaraz.debug = true;
zaraz.track('test_event');
console.log(zaraz.tools); // View loaded tools
```

## Cookie メソッド

```javascript
zaraz.getCookie('session_id');  // Zaraz namespace
zaraz.readCookie('_ga');        // Any cookie
```

## 非同期動作

すべてのメソッドは呼び出し後、結果を待たずに処理を続行します。イベントはまとめて非同期で送信されます。

```javascript
zaraz.track('event1');
zaraz.set('prop', 'value');
zaraz.track('event2'); // All batched
```

## TypeScript 型

```typescript
interface Zaraz {
  track(event: string, properties?: Record<string, unknown>): void;
  set(key: string, value: unknown): void;
  set(properties: Record<string, unknown>): void;
  ecommerce(event: string, properties: Record<string, unknown>): void;
  consent: {
    getAll(): Record<string, boolean>;
    setAll(purposes: Record<string, boolean>): void;
    set(purpose: string, value: boolean): void;
    addEventListener(event: 'consentChanged', callback: () => void): void;
    modal: boolean;
  };
  debug: boolean;
  tools?: string[];
  getCookie(name: string): string | undefined;
  readCookie(name: string): string | undefined;
}
declare global { interface Window { zaraz: Zaraz; } }
```
