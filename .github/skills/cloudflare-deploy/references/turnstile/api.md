# APIリファレンス

## クライアントサイドJavaScript API

スクリプトの読み込み後、Turnstile JavaScript APIは`window.turnstile`で利用できます。

### `turnstile.render(container, options)`

Turnstileウィジェットをコンテナ要素に描画します。

**パラメーター:**
- `container` (string | HTMLElement): CSSセレクターまたはDOM要素
- `options` (TurnstileOptions): 設定オブジェクト（[configuration.md](configuration.md)を参照）

**戻り値:** `string` - 他のAPIメソッドで使用するウィジェットID

**例:**
```javascript
const widgetId = window.turnstile.render('#my-container', {
  sitekey: 'YOUR_SITE_KEY',
  callback: (token) => console.log('Success:', token),
  'error-callback': (code) => console.error('Error:', code)
});
```

### `turnstile.reset(widgetId)`

ウィジェットをリセットします（トークンを消去し、チャレンジの状態をリセットします）。フォームの検証に失敗した場合に便利です。

**パラメーター:**
- `widgetId` (string): `render()`から取得したウィジェットID、またはコンテナ要素

**戻り値:** `void`

**例:**
```javascript
// Reset on form error
if (!validateForm()) {
  window.turnstile.reset(widgetId);
}
```

### `turnstile.remove(widgetId)`

ウィジェットをDOMから完全に削除します。

**パラメーター:**
- `widgetId` (string): `render()`から取得したウィジェットID

**戻り値:** `void`

**例:**
```javascript
// Cleanup on navigation
window.turnstile.remove(widgetId);
```

### `turnstile.getResponse(widgetId)`

ウィジェットから現在のトークンを取得します（チャレンジが完了している場合）。

**パラメーター:**
- `widgetId` (string): `render()`から取得したウィジェットID、またはコンテナ要素

**戻り値:** `string | undefined` - トークン文字列。準備ができていない場合はundefined

**例:**
```javascript
const token = window.turnstile.getResponse(widgetId);
if (token) {
  submitForm(token);
}
```

### `turnstile.isExpired(widgetId)`

ウィジェットのトークンが有効期限切れ（5分超過）かどうかを確認します。

**パラメーター:**
- `widgetId` (string): `render()`から取得したウィジェットID

**戻り値:** `boolean` - 期限切れの場合はtrue

**例:**
```javascript
if (window.turnstile.isExpired(widgetId)) {
  window.turnstile.reset(widgetId);
}
```

## コールバックのシグネチャ

```typescript
type TurnstileCallback = (token: string) => void;
type ErrorCallback = (errorCode: string) => void;
type TimeoutCallback = () => void;
type ExpiredCallback = () => void;
type BeforeInteractiveCallback = () => void;
type AfterInteractiveCallback = () => void;
type UnsupportedCallback = () => void;
```

## Siteverify API（サーバーサイド）

**エンドポイント:** `https://challenges.cloudflare.com/turnstile/v0/siteverify`

### リクエスト

**メソッド:** POST  
**Content-Type:** `application/json`または`application/x-www-form-urlencoded`

```typescript
interface SiteverifyRequest {
  secret: string;    // Your secret key (never expose client-side)
  response: string;  // Token from cf-turnstile-response
  remoteip?: string; // User's IP (optional but recommended)
  idempotency_key?: string; // Unique key for idempotent validation
}
```

**例:**
```javascript
// Cloudflare Workers
const result = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    secret: env.TURNSTILE_SECRET,
    response: token,
    remoteip: request.headers.get('CF-Connecting-IP')
  })
});
const data = await result.json();
```

### レスポンス

```typescript
interface SiteverifyResponse {
  success: boolean;           // Validation result
  challenge_ts?: string;      // ISO timestamp of challenge
  hostname?: string;          // Hostname where widget was solved
  'error-codes'?: string[];   // Error codes if success=false
  action?: string;            // Action name from widget config
  cdata?: string;             // Custom data from widget config
}
```

**成功例:**
```json
{
  "success": true,
  "challenge_ts": "2024-01-15T10:30:00Z",
  "hostname": "example.com",
  "action": "login",
  "cdata": "user123"
}
```

**失敗例:**
```json
{
  "success": false,
  "error-codes": ["timeout-or-duplicate"]
}
```

## エラーコード

| コード | 原因 | 解決策 |
|------|-------|----------|
| `missing-input-secret` | シークレットキーが指定されていない | リクエストに`secret`を含める |
| `invalid-input-secret` | シークレットキーが誤っている | ダッシュボードでシークレットキーを確認する |
| `missing-input-response` | トークンが指定されていない | `response`トークンを含める |
| `invalid-input-response` | トークンが無効または不正な形式 | ウィジェットから取得したトークンを確認する |
| `timeout-or-duplicate` | トークンの有効期限切れ（5分超過）または再利用 | 新しいトークンを生成し、1回だけ検証する |
| `internal-error` | Cloudflareサーバーエラー | 指数バックオフで再試行する |
| `bad-request` | リクエストの形式が不正 | JSONまたはフォームのエンコーディングを確認する |

## TypeScriptの型

```typescript
interface TurnstileOptions {
  sitekey: string;
  action?: string;
  cData?: string;
  callback?: (token: string) => void;
  'error-callback'?: (errorCode: string) => void;
  'expired-callback'?: () => void;
  'timeout-callback'?: () => void;
  'before-interactive-callback'?: () => void;
  'after-interactive-callback'?: () => void;
  'unsupported-callback'?: () => void;
  theme?: 'light' | 'dark' | 'auto';
  size?: 'normal' | 'compact' | 'flexible';
  tabindex?: number;
  'response-field'?: boolean;
  'response-field-name'?: string;
  retry?: 'auto' | 'never';
  'retry-interval'?: number;
  language?: string;
  execution?: 'render' | 'execute';
  appearance?: 'always' | 'execute' | 'interaction-only';
  'refresh-expired'?: 'auto' | 'manual' | 'never';
}

interface Turnstile {
  render(container: string | HTMLElement, options: TurnstileOptions): string;
  reset(widgetId: string): void;
  remove(widgetId: string): void;
  getResponse(widgetId: string): string | undefined;
  isExpired(widgetId: string): boolean;
  execute(container?: string | HTMLElement, options?: TurnstileOptions): void;
}

declare global {
  interface Window {
    turnstile: Turnstile;
    onloadTurnstileCallback?: () => void;
  }
}
```

## スクリプトの読み込み

```html
<!-- Standard -->
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>

<!-- Explicit render mode -->
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit"></script>

<!-- With load callback -->
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js?onload=onloadTurnstileCallback"></script>
<script>
window.onloadTurnstileCallback = () => {
  window.turnstile.render('#container', { sitekey: 'YOUR_SITE_KEY' });
};
</script>
```