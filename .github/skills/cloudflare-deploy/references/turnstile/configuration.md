# 設定

## スクリプトの読み込み

### 基本（暗黙的なレンダリング）
```html
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
```
ページの読み込み時に、`class="cf-turnstile"` を含むウィジェットを自動的にレンダリングします。

### 明示的なレンダリング
```html
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit"></script>
```
`window.turnstile.render()` を使って、ウィジェットをレンダリングするタイミングと場所を手動で制御できます。

### 読み込みコールバックを使用
```html
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js?onload=myCallback"></script>
<script>
function myCallback() {
  // API ready
  window.turnstile.render('#container', { sitekey: 'YOUR_SITE_KEY' });
}
</script>
```

### 互換モード
```html
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js?compat=recaptcha"></script>
```
Google reCAPTCHA のドロップイン置き換え用に、`grecaptcha` API を提供します。

## ウィジェットの設定

### オプションオブジェクト全体

```javascript
{
  // Required
  sitekey: 'YOUR_SITE_KEY',        // Widget sitekey from dashboard

  // Callbacks
  callback: (token) => {},          // Success - token ready
  'error-callback': (code) => {},   // Error occurred
  'expired-callback': () => {},     // Token expired (>5min)
  'timeout-callback': () => {},     // Challenge timeout
  'before-interactive-callback': () => {}, // Before showing checkbox
  'after-interactive-callback': () => {},  // After user interacts
  'unsupported-callback': () => {}, // Browser doesn't support Turnstile

  // Appearance
  theme: 'auto',                    // 'light' | 'dark' | 'auto'
  size: 'normal',                   // 'normal' | 'compact' | 'flexible'
  tabindex: 0,                      // Tab order (accessibility)
  language: 'auto',                 // ISO 639-1 code or 'auto'

  // Behavior
  execution: 'render',              // 'render' (auto) | 'execute' (manual)
  appearance: 'always',             // 'always' | 'execute' | 'interaction-only'
  retry: 'auto',                    // 'auto' | 'never'
  'retry-interval': 8000,           // Retry interval (ms), default 8000
  'refresh-expired': 'auto',        // 'auto' | 'manual' | 'never'

  // Form Integration
  'response-field': true,           // Add hidden input (default: true)
  'response-field-name': 'cf-turnstile-response', // Hidden input name

  // Analytics & Data
  action: 'login',                  // Action name (for analytics)
  cData: 'user-session-123',        // Custom data (returned in siteverify)
}
```

### 主なオプションの説明

**`execution`：**
- `'render'`（デフォルト）：レンダリング時にチャレンジを直ちに開始
- `'execute'`：`turnstile.execute()` の呼び出しを待つ

**`appearance`：**
- `'always'`（デフォルト）：ウィジェットを常に表示
- `'execute'`：`execute()` が呼び出されるまで非表示
- `'interaction-only'`：ユーザー操作が必要になるまで非表示

**`refresh-expired`：**
- `'auto'`（デフォルト）：期限切れトークンを自動更新
- `'manual'`：期限切れ後にアプリ側で `reset()` を呼び出す必要あり
- `'never'`：更新せず、expired-callback を呼び出す

**`retry`：**
- `'auto'`（デフォルト）：失敗したチャレンジを自動再試行
- `'never'`：再試行せず、error-callback を呼び出す

## HTML データ属性

暗黙的なレンダリングでは、`<div class="cf-turnstile">` にデータ属性を指定します。

| JavaScript プロパティ | HTML データ属性 | 例 |
|---------------------|---------------------|---------|
| `sitekey` | `data-sitekey` | `data-sitekey="YOUR_KEY"` |
| `action` | `data-action` | `data-action="login"` |
| `cData` | `data-cdata` | `data-cdata="session-123"` |
| `callback` | `data-callback` | `data-callback="onSuccess"` |
| `error-callback` | `data-error-callback` | `data-error-callback="onError"` |
| `expired-callback` | `data-expired-callback` | `data-expired-callback="onExpired"` |
| `timeout-callback` | `data-timeout-callback` | `data-timeout-callback="onTimeout"` |
| `theme` | `data-theme` | `data-theme="dark"` |
| `size` | `data-size` | `data-size="compact"` |
| `tabindex` | `data-tabindex` | `data-tabindex="0"` |
| `response-field` | `data-response-field` | `data-response-field="false"` |
| `response-field-name` | `data-response-field-name` | `data-response-field-name="token"` |
| `retry` | `data-retry` | `data-retry="never"` |
| `retry-interval` | `data-retry-interval` | `data-retry-interval="5000"` |
| `language` | `data-language` | `data-language="en"` |
| `execution` | `data-execution` | `data-execution="execute"` |
| `appearance` | `data-appearance` | `data-appearance="interaction-only"` |
| `refresh-expired` | `data-refresh-expired` | `data-refresh-expired="manual"` |

**例：**
```html
<div class="cf-turnstile"
     data-sitekey="YOUR_SITE_KEY"
     data-theme="dark"
     data-callback="onTurnstileSuccess"
     data-error-callback="onTurnstileError"></div>
```

## コンテンツセキュリティポリシー

CSP ヘッダーまたは meta タグに、次のディレクティブを追加します。

```
script-src https://challenges.cloudflare.com;
frame-src https://challenges.cloudflare.com;
```

**全体例：**
```html
<meta http-equiv="Content-Security-Policy" 
      content="default-src 'self'; 
               script-src 'self' https://challenges.cloudflare.com; 
               frame-src https://challenges.cloudflare.com;">
```

## フレームワーク別の設定

### React
```bash
npm install @marsidev/react-turnstile
```
```jsx
import Turnstile from '@marsidev/react-turnstile';

<Turnstile
  siteKey="YOUR_SITE_KEY"
  onSuccess={(token) => console.log(token)}
/>
```

### Vue
```bash
npm install vue-turnstile
```
```vue
<template>
  <VueTurnstile site-key="YOUR_SITE_KEY" @success="onSuccess" />
</template>
<script setup>
import VueTurnstile from 'vue-turnstile';
</script>
```

### Svelte
```bash
npm install svelte-turnstile
```
```svelte
<script>
import Turnstile from 'svelte-turnstile';
</script>
<Turnstile siteKey="YOUR_SITE_KEY" on:turnstile-callback={handleToken} />
```

### Next.js（App Router）
```tsx
// app/components/TurnstileWidget.tsx
'use client';
import { useEffect, useRef } from 'react';

export default function TurnstileWidget({ sitekey, onSuccess }) {
  const ref = useRef<HTMLDivElement>(null);
  
  useEffect(() => {
    if (ref.current && window.turnstile) {
      const widgetId = window.turnstile.render(ref.current, {
        sitekey,
        callback: onSuccess
      });
      return () => window.turnstile.remove(widgetId);
    }
  }, [sitekey, onSuccess]);
  
  return <div ref={ref} />;
}
```

## Cloudflare Pages プラグイン

```bash
npm install @cloudflare/pages-plugin-turnstile
```

```typescript
// functions/_middleware.ts
import turnstilePlugin from '@cloudflare/pages-plugin-turnstile';

export const onRequest = turnstilePlugin({
  secret: 'YOUR_SECRET_KEY',
  onError: () => new Response('CAPTCHA failed', { status: 403 })
});
```