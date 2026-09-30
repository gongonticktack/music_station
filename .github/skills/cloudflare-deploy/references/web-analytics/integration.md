# フレームワークとの統合

**Web Analytics はダッシュボードからのみ利用可能** - プログラムで利用できる API はありません。このガイドではビーコンの統合方法を説明します。

## 基本的な HTML

```html
<script defer src='https://static.cloudflareinsights.com/beacon.min.js' 
        data-cf-beacon='{"token": "YOUR_TOKEN", "spa": true}'></script>
```

閉じタグ `</body>` の直前に配置します。

## フレームワーク別の例

| フレームワーク | 配置場所 | 備考 |
|-----------|----------|-------|
| React/Vite | `public/index.html` | `spa: true` を追加 |
| Next.js App Router | `app/layout.tsx` | `<Script strategy="afterInteractive">` を使用 |
| Next.js Pages | `pages/_document.tsx` | `<Script>` を使用 |
| Nuxt 3 | `app.vue` と `useHead()` | またはプラグインを使用 |
| Vue 3/Vite | `index.html` | `spa: true` を追加 |
| Gatsby | `gatsby-browser.js` | `onClientEntry` フック |
| SvelteKit | `src/app.html` | `</body>` の前 |
| Astro | レイアウトコンポーネント | `</body>` の前 |
| Angular | `src/index.html` | `spa: true` を追加 |
| Docusaurus | `docusaurus.config.js` | `scripts` 配列内 |

## 設定

```json
{
  "token": "YOUR_TOKEN",
  "spa": true
}
```

**次の場合は `spa: true` を使用します:** React Router、Vue Router、Next.js、Nuxt、Gatsby、SvelteKit、Angular

**次の場合は `spa: false` を使用します:** 従来型のサーバーサイドレンダリング（PHP、Django、Rails、WordPress）

## CSP ヘッダー

```
script-src 'self' https://static.cloudflareinsights.com;
connect-src 'self' https://cloudflareinsights.com;
```

## GDPR に基づく同意

```typescript
// Load conditionally based on consent
if (localStorage.getItem('analytics-consent') === 'true') {
  const script = document.createElement('script');
  script.src = 'https://static.cloudflareinsights.com/beacon.min.js';
  script.defer = true;
  script.setAttribute('data-cf-beacon', '{"token": "YOUR_TOKEN", "spa": true}');
  document.body.appendChild(script);
}
```
