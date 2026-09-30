# トラブルシューティングと注意点

## 重要なルール

### ❌ サーバー側の検証を省略する
**問題:** クライアント側のみの検証は簡単に回避されます。

**解決策:** 必ずサーバー側で検証してください。
```javascript
// CORRECT - Server validates token
app.post('/submit', async (req, res) => {
  const token = req.body['cf-turnstile-response'];
  const validation = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
    method: 'POST',
    body: JSON.stringify({ secret: SECRET, response: token })
  }).then(r => r.json());
  
  if (!validation.success) return res.status(403).json({ error: 'CAPTCHA failed' });
});
```

### ❌ シークレットキーを公開する
**問題:** シークレットキーがクライアント側のコードに漏えいしています。

**解決策:** 検証はサーバー側でのみ行います。シークレットをクライアントに送信しないでください。

### ❌ トークンを再利用する（1回限りのルール）
**問題:** トークンは1回しか使用できません。`timeout-or-duplicate` では再検証に失敗します。

**解決策:** 送信のたびに新しいトークンを生成してください。エラー時にはウィジェットをリセットします。
```javascript
if (!response.ok) window.turnstile.reset(widgetId);
```

### ❌ トークンの有効期限を処理しない
**問題:** トークンは5分後に期限切れになります。

**解決策:** 有効期限切れのコールバックを処理するか、自動更新を使用してください。
```javascript
window.turnstile.render('#container', {
  sitekey: 'YOUR_SITE_KEY',
  'refresh-expired': 'auto', // or 'manual' with expired-callback
  'expired-callback': () => window.turnstile.reset(widgetId)
});
```

## よくあるエラー

| エラー | 原因 | 解決策 |
|-------|-------|----------|
| **ウィジェットが表示されない** | sitekey の誤り、CSP によるブロック、file:// プロトコル | sitekey を確認し、challenges.cloudflare.com を CSP に追加して、http:// を使用する |
| **timeout-or-duplicate** | トークンの期限切れ（5分超過）または再利用 | 新しいトークンを生成し、5分を超えてキャッシュしない |
| **invalid-input-secret** | シークレットキーの誤り | ダッシュボードのシークレットを確認し、環境変数を確認する |
| **missing-input-response** | トークンが送信されていない | フォームフィールド名が 'cf-turnstile-response' であることを確認する |

## フレームワーク固有の注意点

### React: ウィジェットの再マウント
**問題:** 状態が変わるとウィジェットが再描画され、トークンが失われます。

**解決策:** useRef でライフサイクルを制御します。
```tsx
function TurnstileWidget({ onToken }) {
  const containerRef = useRef(null);
  const widgetIdRef = useRef(null);
  
  useEffect(() => {
    if (containerRef.current && !widgetIdRef.current) {
      widgetIdRef.current = window.turnstile.render(containerRef.current, {
        sitekey: 'YOUR_SITE_KEY',
        callback: onToken
      });
    }
    return () => {
      if (widgetIdRef.current) {
        window.turnstile.remove(widgetIdRef.current);
        widgetIdRef.current = null;
      }
    };
  }, []);
  
  return <div ref={containerRef} />;
}
```

### React StrictMode: 二重描画
**問題:** StrictMode により、開発時にウィジェットが2回描画されます。

**解決策:** クリーンアップ関数を使用します。
```tsx
useEffect(() => {
  const widgetId = window.turnstile.render('#container', { sitekey });
  return () => window.turnstile.remove(widgetId);
}, []);
```

### Next.js: SSR のハイドレーション
**問題:** SSR 中は `window.turnstile` が未定義です。

**解決策:** `'use client'` を使用するか、`ssr: false` を指定した動的インポートを使用します。
```tsx
'use client';
export default function Turnstile() { /* component */ }
```

### SPA: クリーンアップを伴わない画面遷移
**問題:** 画面遷移すると孤立したウィジェットが残ります。

**解決策:** クリーンアップ時にウィジェットを削除します。
```javascript
// Vue
onBeforeUnmount(() => window.turnstile.remove(widgetId));

// React
useEffect(() => () => window.turnstile.remove(widgetId), []);
```

## ネットワークとセキュリティ

### CSP によるブロック
**問題:** Content Security Policy がスクリプトや iframe をブロックします。

**解決策:** CSP ディレクティブを追加します。
```html
<meta http-equiv="Content-Security-Policy" 
      content="script-src 'self' https://challenges.cloudflare.com; 
               frame-src https://challenges.cloudflare.com;">
```

### IP アドレスの転送
**問題:** サーバーがクライアント IP ではなくプロキシ IP を受信します。

**解決策:** 正しいヘッダーを使用します。
```javascript
// Cloudflare Workers
const ip = request.headers.get('CF-Connecting-IP');

// Behind proxy
const ip = request.headers.get('X-Forwarded-For')?.split(',')[0];
```

### CORS（Siteverify）
**問題:** ブラウザーから siteverify を呼び出すと CORS エラーが発生します。

**解決策:** siteverify をクライアント側から呼び出さないでください。バックエンドを呼び出し、バックエンドから siteverify を呼び出します。

## 制限と制約

| 制限 | 値 | 影響 |
|-------|-------|--------|
| トークンの有効期間 | 5分 | 期限切れ後に再生成が必要 |
| トークンの使用回数 | 1回限り | 同じトークンを再検証できない |
| ウィジェットのサイズ | 300x65px（標準）、130x120px（コンパクト） | レイアウトを計画する |

## デバッグ

### コンソールログ
```javascript
window.turnstile.render('#container', {
  sitekey: 'YOUR_SITE_KEY',
  callback: (token) => console.log('✓ Token:', token),
  'error-callback': (code) => console.error('✗ Error:', code),
  'expired-callback': () => console.warn('⏱ Expired'),
  'timeout-callback': () => console.warn('⏱ Timeout')
});
```

### トークンの状態を確認
```javascript
const token = window.turnstile.getResponse(widgetId);
console.log('Token:', token || 'NOT READY');
console.log('Expired:', window.turnstile.isExpired(widgetId));
```

### テストキー（最初に使用）
本番環境の前に、必ずテストキーを使って開発してください:
- Site: `1x00000000000000000000AA`
- Secret: `1x0000000000000000000000000000000AA`

### ネットワークタブ
- `api.js` が読み込まれることを確認する（200 OK）
- siteverify のリクエストとレスポンスを確認する
- 4xx/5xx エラーを探す

## 設定ミス

### キーペアの不一致
**問題:** あるウィジェットのサイトキーと、別のウィジェットのシークレットを使用しています。

**解決策:** ダッシュボードでサイトキーとシークレットが同じウィジェットのものか確認してください。

### 本番環境でのテストキー使用
**問題:** 本番環境でテストキーを使用しています。

**解決策:** 環境に応じたキーを使用します。
```javascript
const SITE_KEY = process.env.NODE_ENV === 'production'
  ? process.env.TURNSTILE_SITE_KEY
  : '1x00000000000000000000AA';
```

### 環境変数の不足
**問題:** サーバー上でシークレットが未定義です。

**解決策:** .env を確認し、読み込みを確認してください。
```bash
# .env
TURNSTILE_SECRET=your_secret_here

# Verify
console.log('Secret loaded:', !!process.env.TURNSTILE_SECRET);
```

## 参照

- [Turnstile ドキュメント](https://developers.cloudflare.com/turnstile/)
- [ダッシュボード](https://dash.cloudflare.com/?to=/:account/turnstile)
- [エラーコード](https://developers.cloudflare.com/turnstile/troubleshooting/)
