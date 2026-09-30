# Zaraz の注意点

## イベントが実行されない

**確認項目:**
1. ダッシュボードでツールが有効になっている（緑の点）
2. トリガー条件が満たされている
3. ツールの目的について同意が得られている
4. ツールの認証情報が正しい（GA4: `G-XXXXXXXXXX`、FB: 数字のみ）

**デバッグ:**
```javascript
zaraz.debug = true;
console.log('Tools:', zaraz.tools);
console.log('Consent:', zaraz.consent.getAll());
```

## 同意に関する問題

**モーダルが表示されない:**
```javascript
// Clear consent cookie
document.cookie = 'zaraz-consent=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
location.reload();
```

**同意前にツールが実行される:** 「同意が得られるまで読み込まない」を指定して、ツールを同意目的にマッピングします。

## SPA のトラッキング

**ルート変更が追跡されない:**
1. ダッシュボードで履歴変更トリガーを設定
2. ハッシュルーティング（`#/path`）では手動トラッキングが必要です:
```javascript
window.addEventListener('hashchange', () => {
  zaraz.track('pageview', { page_path: location.pathname + location.hash });
});
```

**React での修正:**
```javascript
const location = useLocation();
useEffect(() => {
  zaraz.track('pageview', { page_path: location.pathname });
}, [location]); // Include dependency
```

## パフォーマンス

**ページの読み込みが遅い:**
- ツールの数を確認する（50 個以上でパフォーマンスが低下）
- 必要な場合を除き、処理をブロックするトリガーを無効にする
- イベントペイロードのサイズを小さくする（100KB 未満）

## ツール固有の問題

| ツール | 問題 | 対処法 |
|------|-------|-----|
| GA4 | イベントがリアルタイムで表示されない | 5～10 分待つか、DebugView を使用 |
| Facebook | Pixel ID が無効 | 数字のみを使用（`fbpx_` のプレフィックスは付けない） |
| Google Ads | コンバージョンが正しく計上されない | `send_to: 'AW-XXX/LABEL'` を含める |

## データレイヤー

- プロパティはページごとにのみ保持されるため、ページの読み込みごとに設定する
- ネストされたプロパティへのアクセス: `{{client.__zarazTrack.user.plan}}`

## 上限

| リソース | 上限 |
|----------|-------|
| リクエストサイズ | 100KB |
| 同意の目的 | 20 |
| API レート | 1000 リクエスト/秒 |

## Zaraz を使用しないケース

- サーバー間トラッキング（Workers を使用）
- リアルタイムの双方向通信
- バイナリデータの送信
- 認証フロー
