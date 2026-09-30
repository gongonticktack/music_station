# Cloudflare Turnstile 実装スキル リファレンス

従来の CAPTCHA パズルを表示せずにウェブサイトをボットから保護する、スマートな CAPTCHA 代替手段 Cloudflare Turnstile の実装に関する専門的なガイダンスです。

## 概要

Turnstile は、ユーザーの操作なしにバックグラウンドでチャレンジを実行する、ユーザーフレンドリーな CAPTCHA 代替手段です。ブラウザーの動作、デバイスのフィンガープリント、機械学習などのシグナルを使って、訪問者を自動的に検証します。

## ウィジェットの種類

| 種類 | 操作 | 用途 |
|------|-------------|----------|
| **Managed**（デフォルト） | 必要に応じてチェックボックスを表示 | フォーム、ログイン - UX とセキュリティの両立 |
| **Non-Interactive** | 非表示で自動実行 | 摩擦のない UX、リスクの低い操作 |
| **Invisible** | 非表示でプログラムから起動 | 事前クリアランス、API 呼び出し、ヘッドレス |

## クイックスタート

### 暗黙的レンダリング（HTML ベース）
```html
<!-- 1. Add script -->
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>

<!-- 2. Add widget to form -->
<form action="/submit" method="POST">
  <div class="cf-turnstile" data-sitekey="YOUR_SITE_KEY"></div>
  <button type="submit">Submit</button>
</form>
```

### 明示的レンダリング（JavaScript ベース）
```html
<div id="turnstile-container"></div>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit"></script>
<script>
window.turnstile.render('#turnstile-container', {
  sitekey: 'YOUR_SITE_KEY',
  callback: (token) => console.log('Token:', token)
});
</script>
```

### サーバー側の検証（必須）
```javascript
// Cloudflare Workers
export default {
  async fetch(request) {
    const formData = await request.formData();
    const token = formData.get('cf-turnstile-response');
    
    const result = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        secret: env.TURNSTILE_SECRET,
        response: token,
        remoteip: request.headers.get('CF-Connecting-IP')
      })
    });
    
    const validation = await result.json();
    if (!validation.success) {
      return new Response('Invalid CAPTCHA', { status: 400 });
    }
    // Process form...
  }
}
```

## テストキー

**開発・テストで重要:**

| 種類 | キー | 動作 |
|------|-----|----------|
| **サイトキー（常に通過）** | `1x00000000000000000000AA` | ウィジェットが成功し、トークンが検証されます |
| **サイトキー（常にブロック）** | `2x00000000000000000000AB` | ウィジェットが目に見える形で失敗します |
| **サイトキー（チャレンジを強制）** | `3x00000000000000000000FF` | 常に対話型チャレンジを表示します |
| **シークレットキー（テスト用）** | `1x0000000000000000000000000000000AA` | テストトークンを検証します |

**注:** テストキーは `localhost` および任意のドメインで動作します。本番環境では使用しないでください。

## 主な制約

- **トークンの有効期限:** 生成から5分
- **単回使用:** 各トークンは一度しか検証できません
- **サーバー側の検証が必須:** クライアント側のチェックだけでは不十分です

## 読む順序

1. **[configuration.md](configuration.md)** - セットアップ、ウィジェットのオプション、スクリプトの読み込み
2. **[api.md](api.md)** - JavaScript API、siteverify エンドポイント、TypeScript 型
3. **[patterns.md](patterns.md)** - フォーム連携、フレームワークの例、検証パターン
4. **[gotchas.md](gotchas.md)** - よくあるエラー、デバッグ、制限事項

## 関連項目

- [Cloudflare Turnstile Docs](https://developers.cloudflare.com/turnstile/)
- [Dashboard](https://dash.cloudflare.com/?to=/:account/turnstile)
